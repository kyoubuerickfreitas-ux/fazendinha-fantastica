#!/usr/bin/env python3
"""
Trilha sonora original da Fazendinha Fantástica (sintetizada, sem samples de terceiros).
Gera assets/music/*.ogg (loops sem emenda):
  farm_day    "Manhã na Fazendinha"   sol maior, 104 bpm   (flauta, violão dedilhado, baixo, chocalho)
  farm_night  "Noite Estrelada"       fá maior, valsa 3/4  (caixinha de música, pad, baixo)
  farm_rain   "Dia de Chuva"          lá menor, 84 bpm     (piano elétrico, sininho, bateria escovada)
  mine        "Lá no Fundo da Mina"   ré menor, 88 bpm     (corda com eco, pad grave, gotas, tambor)
e os ambientes assets/music/amb_*.ogg (passarinhos, grilos, chuva, caverna).
Uso: python3 tools/generate_music.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
from synth import (SR, Song, seq, midi, write_ogg, inst_flute, inst_ocarina, inst_pluck, inst_bell,  # noqa: E402
                   inst_epiano, inst_marimba, inst_bass, inst_pad, inst_kick, inst_snare, inst_shaker,
                   inst_tom, inst_pulse, noise, lowpass, highpass, bandpass)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "music")

QUAL = {"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10],
        "sus4": [0, 5, 7], "add9": [0, 4, 7, 14]}


def chord(sym, octave=3):
    """'Em' -> notas MIDI (fundamental na oitava pedida)."""
    root = sym[0]
    i = 1
    if len(sym) > 1 and sym[1] in "#b":
        root += sym[1]
        i = 2
    base = midi(root + str(octave))
    return [base + x for x in QUAL[sym[i:]]]


# ================================================================== Manhã na Fazendinha
def farm_day():
    A_CH = ["G", "D", "Em", "C", "G", "C", "D", "G"]
    B_CH = ["C", "D", "Bm", "Em", "Am", "D", "G", "D"]
    A_MEL = seq("D5:1 B4:.5 D5:.5 G5:1.5 F#5:.5 "
                "E5:1 D5:1 A4:2 "
                "B4:.5 C5:.5 D5:1 E5:1 G5:1 "
                "E5:3 r:1 "
                "D5:1 B4:.5 D5:.5 G5:1 A5:1 "
                "G5:.5 E5:.5 C5:1 E5:1 G5:1 "
                "F#5:1 E5:.5 F#5:.5 A5:1 F#5:1 "
                "G5:3 r:1")
    B_MEL = seq("E5:.5 G5:.5 C6:1 B5:1 G5:1 "
                "A5:1.5 G5:.5 F#5:1 D5:1 "
                "F#5:1 D5:.5 F#5:.5 B5:1 A5:1 "
                "G5:2 E5:2 "
                "C5:.5 E5:.5 A5:1 G5:1 E5:1 "
                "F#5:1 A5:1 D6:1 C6:1 "
                "B5:1.5 A5:.5 G5:1 D5:1 "
                "E5:1 F#5:1 A5:2")
    form = [("A", 0), ("A", 1), ("B", 0), ("A", 2)]
    s = Song(104, 32 * 4)
    s.track("lead", 0.05, 0.3)
    s.track("bell", 0.25, 0.35)
    s.track("guitar", -0.35, 0.2)
    s.track("bass", 0.0, 0.05)
    s.track("drums", 0.1, 0.1)
    bar = 0
    for part, var in form:
        chords, mel = (A_CH, A_MEL) if part == "A" else (B_CH, B_MEL)
        beat = bar * 4
        s.melody("lead", inst_flute, mel, beat, vel=0.5)
        if var >= 1 or part == "B":
            s.melody("bell", inst_bell, mel, beat, vel=0.12, transpose=12, legato=0.5)
        for k, ch in enumerate(chords):
            b0 = (bar + k) * 4
            notes = chord(ch, 3)
            root = notes[0]
            # violão: arpejo em colcheias  (1-5-8-3-5-8-3-5)
            pat = [notes[0], notes[2], notes[0] + 12, notes[1] + 12, notes[2] + 12, notes[0] + 12, notes[1] + 12, notes[2]]
            for i, m in enumerate(pat):
                s.note("guitar", inst_pluck, m, b0 + i * 0.5, 0.5, 0.26 if i % 2 == 0 else 0.18)
            # baixo: fundamental e quinta
            s.note("bass", inst_bass, root - 12, b0, 1.4, 0.3)
            s.note("bass", inst_bass, root - 5, b0 + 2, 0.9, 0.25)
            s.note("bass", inst_bass, root - 12, b0 + 3, 0.45, 0.2)
            if var >= 1 or part == "B":
                for i in range(8):
                    s.note("drums", inst_shaker, 0, b0 + i * 0.5, 0.1, 0.12 if i % 2 else 0.07)
                s.note("drums", inst_kick, 0, b0, 0.2, 0.3)
                s.note("drums", inst_kick, 0, b0 + 2.5, 0.2, 0.17)
                if var == 2 or part == "B":
                    s.note("drums", inst_snare, 0, b0 + 1, 0.2, 0.1)
                    s.note("drums", inst_snare, 0, b0 + 3, 0.2, 0.12)
        bar += 8
    return s.render(reverb_len=1.6)


# ================================================================== Noite Estrelada (valsa)
def farm_night():
    CH = ["Fmaj7", "Am7", "Bbmaj7", "C", "Dm", "Bb", "Gm", "C",
          "Fmaj7", "Am7", "Bbmaj7", "Gm7", "Dm", "Bb", "C", "F"]
    MEL = seq("C5:1 F5:1 A5:1 G5:2 E5:1 D5:1 F5:1 A5:1 G5:3 "
              "F5:1 A5:1 D6:1 C6:1.5 Bb5:.5 A5:1 Bb5:1 A5:1 G5:1 E5:3 "
              "C5:1 F5:1 A5:1 C6:2 A5:1 D6:1 C6:1 Bb5:1 A5:2 G5:1 "
              "F5:1 E5:1 D5:1 F5:1 D5:1 Bb4:1 C5:1 E5:1 G5:1 F5:3")
    s = Song(76, 32 * 3)
    s.track("box", 0.2, 0.45)
    s.track("flute", -0.15, 0.4)
    s.track("pad", 0.0, 0.5)
    s.track("bass", 0.0, 0.1)
    s.track("arp", -0.3, 0.4)
    for rep in range(2):
        b = rep * 48
        if rep == 0:
            s.melody("box", inst_bell, MEL, b, vel=0.32, legato=0.8)
        else:
            s.melody("flute", inst_ocarina, MEL, b, vel=0.28, transpose=-12)
            s.melody("box", inst_bell, MEL, b + 0.02, vel=0.12, legato=0.6)
        for k, ch in enumerate(CH):
            b0 = b + k * 3
            notes = chord(ch, 3)
            s.note("bass", inst_bass, notes[0] - 12, b0, 2.6, 0.2)
            for m in notes[1:]:
                s.note("pad", inst_pad, m + 12, b0, 2.9, 0.09)
            # arpejo suave nos tempos 2 e 3
            s.note("arp", inst_marimba, notes[1] + 12, b0 + 1, 0.5, 0.12)
            s.note("arp", inst_marimba, notes[2] + 12, b0 + 2, 0.5, 0.1)
    s.echo("box", 1.5, 0.28, 2)
    return s.render(reverb_len=3.0)


# ================================================================== Dia de Chuva
def farm_rain():
    CH = ["Am", "F", "C", "G", "Am", "F", "G", "E", "F", "G", "Em", "Am", "Dm", "G7", "C", "E"]
    MEL = seq("E5:1.5 C5:.5 A4:1 B4:1 C5:2 A4:1 C5:1 E5:1.5 D5:.5 C5:1 E5:1 D5:3 r:1 "
              "E5:1.5 A5:.5 G5:1 E5:1 F5:1.5 E5:.5 C5:2 D5:1 B4:1 G4:1 B4:1 G#4:3 r:1 "
              "A4:1 C5:1 F5:1 E5:1 D5:1.5 B4:.5 G4:2 G5:1 E5:1 B4:1 E5:1 C5:3 r:1 "
              "F5:1.5 E5:.5 D5:1 A4:1 B4:1 D5:1 G5:1 F5:1 E5:2 G5:1 E5:1 D5:1 B4:1 G#4:2")
    s = Song(84, 32 * 4)
    s.track("keys", -0.1, 0.35)
    s.track("lead", 0.15, 0.35)
    s.track("bass", 0.0, 0.05)
    s.track("drums", 0.0, 0.15)
    for rep in range(2):
        b = rep * 64
        s.melody("lead", inst_epiano if rep == 0 else inst_bell, MEL, b, vel=0.42 if rep == 0 else 0.2,
                 transpose=0 if rep == 0 else 12, legato=0.9)
        for k, ch in enumerate(CH):
            b0 = b + k * 4
            notes = chord(ch, 3)
            for m in notes[1:]:
                s.note("keys", inst_epiano, m, b0, 1.6, 0.16)
                s.note("keys", inst_epiano, m, b0 + 2.5, 1.2, 0.12)
            s.note("bass", inst_bass, notes[0] - 12, b0, 1.8, 0.24)
            s.note("bass", inst_bass, notes[0] - 12, b0 + 2.5, 1.2, 0.18)
            s.note("drums", inst_kick, 0, b0, 0.2, 0.2)
            s.note("drums", inst_kick, 0, b0 + 2.5, 0.2, 0.13)
            s.note("drums", inst_snare, 0, b0 + 1, 0.2, 0.06)
            s.note("drums", inst_snare, 0, b0 + 3, 0.2, 0.07)
            for i in range(8):
                s.note("drums", inst_shaker, 0, b0 + i * 0.5 + (0.08 if i % 2 else 0), 0.1, 0.05)
    return s.render(reverb_len=2.4)


# ================================================================== Lá no Fundo da Mina
def mine():
    CH = ["Dm", "C", "Bb", "C", "Dm", "Am", "Bb", "A"]
    MEL = seq("D5:1 r:.5 A4:.5 F5:1.5 E5:.5 E5:2 G4:1 C5:1 D5:1.5 F5:.5 Bb5:1 A5:1 G5:3 r:1 "
              "A5:1 F5:.5 E5:.5 D5:2 C5:1 E5:1 A4:2 Bb4:1 D5:1 F5:1 G5:1 E5:1 C#5:1 A4:2")
    s = Song(88, 32 * 4)
    s.track("lead", 0.1, 0.4)
    s.track("glass", -0.3, 0.5)
    s.track("pad", 0.0, 0.5)
    s.track("bass", 0.0, 0.1)
    s.track("drums", 0.0, 0.25)
    s.track("drip", 0.0, 0.6)
    for rep in range(4):
        b = rep * 32
        if rep in (1, 3):
            s.melody("lead", inst_pluck, MEL, b, vel=0.55, transpose=0, bright=0.5)
        if rep == 2:
            s.melody("glass", inst_bell, MEL, b, vel=0.2, legato=0.7)
        if rep == 3:
            s.melody("glass", inst_pulse, MEL, b, vel=0.07, transpose=12, legato=0.5, duty=0.125)
        for k, ch in enumerate(CH):
            b0 = b + k * 4
            notes = chord(ch, 3)
            s.note("bass", inst_bass, notes[0] - 12, b0, 3.6, 0.075)
            for m in notes:
                s.note("pad", inst_pad, m, b0, 3.8, 0.04)
            # arpejo lento e misterioso
            for i, m in enumerate([notes[0] + 12, notes[2] + 12, notes[1] + 24, notes[2] + 12]):
                s.note("lead", inst_pluck, m, b0 + i, 0.9, 0.24, bright=0.45)
            s.note("drums", inst_tom, 45, b0, 0.4, 0.12)
            if k % 2 == 1:
                s.note("drums", inst_tom, 52, b0 + 2.5, 0.4, 0.1)
                s.note("drums", inst_tom, 50, b0 + 3, 0.4, 0.11)
    s.echo("lead", 0.75, 0.32, 3)
    # gotas d'água (sininhos agudos em lugares fixos para o loop ser sempre igual)
    rng = np.random.default_rng(11)
    for _ in range(26):
        beat = rng.uniform(0, 128)
        s.note("drip", inst_bell, int(rng.choice([86, 89, 91, 93, 96])), beat, 0.1, 0.05,
               pan=float(rng.uniform(-0.8, 0.8)))
    return s.render(reverb_len=3.2)


# ================================================================== ambientes (loops de 24 s)
def loop_noise(seconds, seed, fade=1.0):
    """Ruído com emenda suave (o fim se mistura no começo)."""
    n, f = int(seconds * SR), int(fade * SR)
    x = noise(n + f, seed)
    w = np.linspace(0, 1, f)
    x[:f] = x[:f] * w + x[n:n + f] * (1 - w)
    return x[:n]


def place(buf, snd, at):
    """Soma snd em buf a partir de at, dando a volta no fim (loop)."""
    n = len(buf)
    for i in range(0, len(snd), n):
        part = snd[i:i + n]
        a = (at + i) % n
        k = min(len(part), n - a)
        buf[a:a + k] += part[:k]
        if k < len(part):
            buf[: len(part) - k] += part[k:]


def stereo(l, r=None):
    r = l if r is None else r
    st = np.stack([l, r], axis=1)
    return st / max(1e-9, np.abs(st).max())


def amb_rain():
    l = lowpass(highpass(loop_noise(24, 1), 400), 5000) * 0.5
    r = lowpass(highpass(loop_noise(24, 2), 400), 5000) * 0.5
    rng = np.random.default_rng(3)
    for buf in (l, r):
        for _ in range(900):
            n = int(0.012 * SR)
            t = np.arange(n) / SR
            d = np.sin(2 * np.pi * rng.uniform(1800, 4200) * t) * np.exp(-t * 400) * rng.uniform(0.1, 0.5)
            place(buf, d, int(rng.uniform(0, len(buf))))
    return stereo(l, r) * 0.7


def amb_night():
    n = int(24 * SR)
    l, r = np.zeros(n), np.zeros(n)
    rng = np.random.default_rng(5)
    # grilos: pulsos rápidos de ~4,5 kHz
    for _ in range(70):
        f = rng.uniform(4200, 4900)
        reps = int(rng.integers(3, 7))
        chirp = np.zeros(int(reps * 0.045 * SR))
        for k in range(reps):
            m = int(0.028 * SR)
            t = np.arange(m) / SR
            p = np.sin(2 * np.pi * f * t) * np.sin(np.pi * t / t[-1]) ** 2
            s0 = int(k * 0.045 * SR)
            chirp[s0:s0 + m] += p
        at = int(rng.uniform(0, n))
        pan = rng.uniform(0, 1)
        place(l, chirp * (1 - pan) * rng.uniform(0.2, 0.6), at)
        place(r, chirp * pan * rng.uniform(0.2, 0.6), at)
    # sapinho de vez em quando
    for _ in range(5):
        m = int(0.16 * SR)
        t = np.arange(m) / SR
        croak = np.sign(np.sin(2 * np.pi * 120 * t)) * np.sin(np.pi * t / t[-1]) * 0.3
        croak = lowpass(croak, 900)
        at = int(rng.uniform(0, n))
        place(l, croak, at)
        place(r, croak * 0.6, at)
    wind = lowpass(loop_noise(24, 9), 400) * 0.06
    return stereo(l + wind, r + wind) * 0.6


def amb_birds():
    n = int(24 * SR)
    l, r = np.zeros(n), np.zeros(n)
    rng = np.random.default_rng(8)
    for _ in range(16):
        notes = int(rng.integers(2, 6))
        base = rng.uniform(2200, 3600)
        song = []
        for k in range(notes):
            m = int(rng.uniform(0.05, 0.12) * SR)
            t = np.arange(m) / SR
            f0, f1 = base * rng.uniform(0.85, 1.2), base * rng.uniform(0.9, 1.4)
            fr = f0 + (f1 - f0) * t / t[-1] + 120 * np.sin(2 * np.pi * 35 * t)
            song.append(np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.sin(np.pi * t / t[-1]))
            song.append(np.zeros(int(0.04 * SR)))
        snd = np.concatenate(song)
        at = int(rng.uniform(0, n))
        pan = rng.uniform(0.1, 0.9)
        v = rng.uniform(0.2, 0.5)
        place(l, snd * (1 - pan) * v, at)
        place(r, snd * pan * v, at)
    wind = lowpass(loop_noise(24, 4), 600) * 0.05
    return stereo(l + wind, r + wind) * 0.5


def amb_cave():
    n = int(24 * SR)
    rumble = lowpass(loop_noise(24, 6), 160, order=3) * 0.8
    l, r = rumble.copy(), rumble.copy()
    rng = np.random.default_rng(12)
    for _ in range(14):
        m = int(0.35 * SR)
        t = np.arange(m) / SR
        f = rng.uniform(900, 1700)
        fr = f * (1 + 0.8 * np.exp(-t * 40))
        d = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t * 14) * rng.uniform(0.3, 0.7)
        # eco da caverna
        echo = np.zeros(m + int(0.6 * SR))
        echo[:m] += d
        for k, g in ((int(0.19 * SR), 0.4), (int(0.41 * SR), 0.2)):
            echo[k:k + m] += d * g
        at = int(rng.uniform(0, n))
        pan = rng.uniform(0.1, 0.9)
        place(l, echo * (1 - pan), at)
        place(r, echo * pan, at)
    return stereo(l, r) * 0.6


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    tracks = {"farm_day": farm_day, "farm_night": farm_night, "farm_rain": farm_rain, "mine": mine,
              "amb_rain": amb_rain, "amb_night": amb_night, "amb_birds": amb_birds, "amb_cave": amb_cave}
    only = sys.argv[1:]
    for name, fn in tracks.items():
        if only and name not in only:
            continue
        data = fn()
        if not name.startswith("amb"):
            # mesmo volume percebido em todas as músicas (~ -17 dBFS RMS), com limitador suave
            rms = np.sqrt(np.mean(data ** 2))
            data = data * (10 ** (-17 / 20) / max(rms, 1e-9))
            data = np.tanh(data * 1.2) / 1.2
        write_ogg(os.path.join(OUT, name + ".ogg"), data, SR, quality=3 if name.startswith("amb") else 4)
        print("%-11s %5.1f s" % (name, len(data) / SR))
