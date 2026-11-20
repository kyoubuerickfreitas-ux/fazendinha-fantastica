#!/usr/bin/env python3
"""
Sintetizador simples (numpy) usado pelos geradores de música e efeitos sonoros.
Instrumentos por síntese aditiva (sem aliasing), corda dedilhada (Karplus-Strong),
sininho, pad, bateria leve, reverb por convolução e exportação em WAV/OGG.
"""
import os
import subprocess
import wave

import numpy as np

SR = 44100
NOTE_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(name):
    """'C#5', 'Bb4', 'A4' -> número MIDI."""
    n = NOTE_NAMES[name[0].upper()]
    i = 1
    while i < len(name) and name[i] in "#b":
        n += 1 if name[i] == "#" else -1
        i += 1
    return n + 12 * (int(name[i:]) + 1)


def freq(note):
    m = note if isinstance(note, (int, float)) else midi(note)
    return 440.0 * 2 ** ((m - 69) / 12)


def seq(text):
    """'D5:1 B4:.5 r:1' -> [(nota|None, batidas), ...]"""
    out = []
    for tok in text.split():
        n, b = tok.split(":")
        out.append((None if n == "r" else n, float(b)))
    return out


# ------------------------------------------------------------------ envelopes e osciladores
def adsr(n, sr, a=0.01, d=0.1, s=0.7, r=0.1, hold=None):
    """Envelope de n amostras. hold = quanto tempo (s) a nota fica 'apertada' antes do release."""
    t = np.arange(n) / sr
    hold = (n / sr - r) if hold is None else hold
    env = np.where(t < a, t / max(a, 1e-6), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-6)))
    rel = np.clip(1 - (t - hold) / max(r, 1e-6), 0, 1)
    return env * np.where(t > hold, rel, 1.0)


def phase_of(f, n, sr, vib=0.0, vib_hz=5.0, vib_delay=0.0, glide_to=None):
    t = np.arange(n) / sr
    fr = np.full(n, float(f))
    if glide_to is not None:
        fr = f * (glide_to / f) ** (t / (n / sr))
    if vib:
        depth = np.clip((t - vib_delay) / 0.25, 0, 1) * vib
        fr = fr * (1 + depth * np.sin(2 * np.pi * vib_hz * t))
    return 2 * np.pi * np.cumsum(fr) / sr, fr


def additive(f, n, sr, harm, **kw):
    """harm: lista de amplitudes por harmônico (1, 2, 3...). Corta o que passa de Nyquist."""
    ph, fr = phase_of(f, n, sr, **kw)
    out = np.zeros(n)
    top = fr.max()
    for k, a in enumerate(harm, start=1):
        if a == 0 or k * top >= sr * 0.45:
            continue
        out += a * np.sin(k * ph)
    return out


def pulse_harm(duty, count=24):
    return [np.sin(np.pi * k * duty) * 2 / (np.pi * k) for k in range(1, count + 1)]


TRI_HARM = [(8 / np.pi ** 2) * ((-1) ** ((k - 1) // 2)) / k ** 2 if k % 2 else 0 for k in range(1, 16)]
SAW_HARM = [1 / k for k in range(1, 30)]


def pluck(f, n, sr, bright=0.6, decay=0.997, seed=0):
    """Corda dedilhada (Karplus-Strong), afinada por reamostragem."""
    rng = np.random.default_rng(seed)
    N = max(2, int(sr / f))
    total = n + N + 1
    y = np.zeros(total + N)
    burst = rng.uniform(-1, 1, N)
    # brilho: mistura o ruído com uma versão suavizada
    smooth = np.convolve(burst, np.ones(3) / 3, mode="same")
    y[1:N + 1] = bright * burst + (1 - bright) * smooth
    i = N + 1
    while i < total:
        j = min(i + N, total)
        y[i:j] = decay * 0.5 * (y[i - N:j - N] + y[i - N - 1:j - N - 1])
        i = j
    y = y[1:total]
    actual = sr / (N + 0.5)
    pos = np.arange(n) * (f / actual)
    return np.interp(pos, np.arange(len(y)), y)


def noise(n, seed=0):
    return np.random.default_rng(seed).uniform(-1, 1, n)


# ------------------------------------------------------------------ filtros (no domínio da frequência)
def lowpass(x, fc, sr=SR, order=2):
    X = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / sr)
    X /= np.sqrt(1 + (fr / fc) ** (2 * order))
    return np.fft.irfft(X, len(x))


def highpass(x, fc, sr=SR, order=2):
    X = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / sr)
    X *= 1 - 1 / np.sqrt(1 + (fr / max(fc, 1e-3)) ** (2 * order))
    return np.fft.irfft(X, len(x))


def bandpass(x, lo, hi, sr=SR):
    return highpass(lowpass(x, hi, sr), lo, sr)


# ------------------------------------------------------------------ instrumentos (nota -> amostras)
def inst_flute(f, dur, sr, vel=1.0):
    n = int((dur + 0.25) * sr)
    s = additive(f, n, sr, [1, 0.35, 0.12, 0.05], vib=0.006, vib_hz=5.2, vib_delay=0.18)
    s += 0.025 * lowpass(noise(n, int(f)), 3000, sr)
    return s * adsr(n, sr, a=0.04, d=0.2, s=0.85, r=0.2, hold=dur) * vel


def inst_ocarina(f, dur, sr, vel=1.0):
    n = int((dur + 0.2) * sr)
    s = additive(f, n, sr, [1, 0.08, 0.04], vib=0.005, vib_hz=5.5, vib_delay=0.2)
    return s * adsr(n, sr, a=0.03, d=0.15, s=0.9, r=0.15, hold=dur) * vel


def inst_pulse(f, dur, sr, vel=1.0, duty=0.25):
    n = int((dur + 0.1) * sr)
    s = additive(f, n, sr, pulse_harm(duty, 16), vib=0.004, vib_hz=5.0, vib_delay=0.2)
    return s * adsr(n, sr, a=0.005, d=0.12, s=0.6, r=0.08, hold=dur) * vel * 0.8


def inst_pluck(f, dur, sr, vel=1.0, bright=0.55):
    n = int((min(dur, 1.6) + 0.6) * sr)
    s = pluck(f, n, sr, bright=bright, decay=0.996, seed=int(f * 7))
    return s * adsr(n, sr, a=0.002, d=0.5, s=0.6, r=0.3, hold=dur + 0.1) * vel


def inst_bell(f, dur, sr, vel=1.0):
    """Caixinha de música / sininho."""
    n = int((dur + 1.4) * sr)
    t = np.arange(n) / sr
    s = np.sin(2 * np.pi * f * t) * np.exp(-t * 2.2)
    s += 0.35 * np.sin(2 * np.pi * f * 3.0 * t) * np.exp(-t * 6)
    s += 0.18 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 11)
    return s * adsr(n, sr, a=0.002, d=1, s=1, r=0.4, hold=dur + 1.0) * vel


def inst_epiano(f, dur, sr, vel=1.0):
    """Piano elétrico (FM simples)."""
    n = int((dur + 0.8) * sr)
    t = np.arange(n) / sr
    mod = np.sin(2 * np.pi * f * t) * 1.6 * np.exp(-t * 3)
    s = np.sin(2 * np.pi * f * t + mod) * np.exp(-t * 0.9)
    s += 0.2 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 2)
    return s * adsr(n, sr, a=0.003, d=1, s=1, r=0.35, hold=dur) * vel


def inst_marimba(f, dur, sr, vel=1.0):
    n = int(0.9 * sr)
    t = np.arange(n) / sr
    s = np.sin(2 * np.pi * f * t) * np.exp(-t * 6)
    s += 0.25 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 18)
    return s * adsr(n, sr, a=0.002, d=1, s=1, r=0.1) * vel


def inst_bass(f, dur, sr, vel=1.0):
    n = int((dur + 0.08) * sr)
    # harmônicos para o baixo ser ouvido também no alto-falante do celular
    s = additive(f, n, sr, [1, 0.55, 0.32, 0.2, 0.12, 0.08, 0.05])
    return s * adsr(n, sr, a=0.006, d=0.25, s=0.7, r=0.06, hold=dur) * vel


def inst_pad(f, dur, sr, vel=1.0):
    n = int((dur + 0.9) * sr)
    s = np.zeros(n)
    for det in (-0.004, 0.0, 0.0045):
        s += additive(f * (1 + det), n, sr, [1 / k ** 1.3 for k in range(1, 10)])
    return s / 3 * adsr(n, sr, a=0.5, d=0.5, s=0.9, r=0.8, hold=dur) * vel


def inst_kick(_f, _dur, sr, vel=1.0):
    n = int(0.3 * sr)
    t = np.arange(n) / sr
    f = 45 + 80 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / sr) * np.exp(-t * 12) * vel


def inst_snare(_f, _dur, sr, vel=1.0):
    n = int(0.18 * sr)
    t = np.arange(n) / sr
    s = bandpass(noise(n, 3), 900, 6000, sr) * np.exp(-t * 22)
    s += 0.3 * np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30)
    return s * vel


def inst_shaker(_f, _dur, sr, vel=1.0):
    n = int(0.07 * sr)
    t = np.arange(n) / sr
    return highpass(noise(n, 5), 6000, sr) * np.exp(-t * 60) * (1 - np.exp(-t * 400)) * vel


def inst_tom(f, _dur, sr, vel=1.0):
    n = int(0.5 * sr)
    t = np.arange(n) / sr
    fr = f * (1 + 0.6 * np.exp(-t * 18))
    return np.sin(2 * np.pi * np.cumsum(fr) / sr) * np.exp(-t * 7) * vel


# ------------------------------------------------------------------ montagem
class Song:
    """Faixa em loop. Os eventos que passam do fim voltam para o começo (loop sem emenda)."""

    def __init__(self, bpm, beats, sr=SR):
        self.sr = sr
        self.spb = 60.0 / bpm
        self.length = int(round(beats * self.spb * sr))
        self.tail = int(4 * sr)
        self.bus = {}      # nome -> [esquerdo, direito]
        self.send = {}     # nome -> envio para o reverb

    def track(self, name, pan=0.0, reverb=0.25):
        if name not in self.bus:
            n = self.length + self.tail
            self.bus[name] = [np.zeros(n), np.zeros(n), pan]
            self.send[name] = reverb
        return name

    def note(self, track, inst, note, beat, beats, vel=1.0, pan=None, **kw):
        if note is None:
            return
        f = freq(note) if isinstance(note, (str, int, float)) else note
        s = inst(f, beats * self.spb, self.sr, vel, **kw)
        start = int(round(beat * self.spb * self.sr))
        L, R, p = self.bus[track]
        p = p if pan is None else pan
        gl, gr = np.cos((p + 1) * np.pi / 4), np.sin((p + 1) * np.pi / 4)
        end = min(start + len(s), len(L))
        L[start:end] += s[:end - start] * gl
        R[start:end] += s[:end - start] * gr

    def melody(self, track, inst, notes, beat=0.0, vel=1.0, transpose=0, legato=0.95, **kw):
        for n, b in notes:
            if n is not None:
                m = midi(n) + transpose
                self.note(track, inst, m, beat, b * legato, vel, **kw)
            beat += b
        return beat

    def echo(self, track, delay_beats, fb=0.35, taps=3):
        L, R, _ = self.bus[track]
        d = int(delay_beats * self.spb * self.sr)
        oL, oR = L.copy(), R.copy()
        for k in range(1, taps + 1):
            g = fb ** k
            # pingue-pongue: alterna os lados
            src = oR if k % 2 else oL
            dst = L if k % 2 else R
            dst[d * k:] += src[:len(src) - d * k] * g

    def fold(self, x):
        out = np.zeros(self.length)
        for i in range(0, len(x), self.length):
            c = x[i:i + self.length]
            out[: len(c)] += c
        return out

    def render(self, master=0.85, reverb_len=2.2, reverb_mix=1.0, seed=1):
        n = self.length + self.tail
        L, R = np.zeros(n), np.zeros(n)
        wl, wr = np.zeros(n), np.zeros(n)
        for name, (l, r, _) in self.bus.items():
            L += l
            R += r
            wl += l * self.send[name]
            wr += r * self.send[name]
        if reverb_mix > 0:
            irn = int(reverb_len * self.sr)
            t = np.arange(irn) / self.sr
            rng = np.random.default_rng(seed)
            outs = []
            for wet, dry in ((wl, L), (wr, R)):
                ir = rng.uniform(-1, 1, irn) * np.exp(-t * 6.9 / reverb_len)
                ir = lowpass(ir, 5000, self.sr)
                ir[: int(0.012 * self.sr)] = 0     # pré-atraso
                ir /= np.sqrt(np.sum(ir ** 2))
                size = 1 << int(np.ceil(np.log2(n + irn)))
                w = np.fft.irfft(np.fft.rfft(wet, size) * np.fft.rfft(ir, size), size)[: n + irn]
                full = w * 0.55 * reverb_mix
                full[:n] += dry
                outs.append(full)
            L, R = outs
        # loop sem emenda: tudo o que passa do fim volta para o começo
        L2, R2 = self.fold(L), self.fold(R)
        st = np.stack([L2, R2], axis=1)
        st /= max(1e-9, np.abs(st).max())
        return np.tanh(st * 1.1) / np.tanh(1.1) * master


# ------------------------------------------------------------------ exportar
def write_wav(path, data, sr):
    data = np.asarray(data)
    if data.ndim == 1:
        data = data[:, None]
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(data.shape[1])
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def write_ogg(path, data, sr, quality=4):
    tmp = path + ".tmp.wav"
    write_wav(tmp, data, sr)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(quality), path],
                   check=True)
    os.remove(tmp)


def normalize(x, peak=0.85):
    return x / max(1e-9, np.abs(x).max()) * peak
