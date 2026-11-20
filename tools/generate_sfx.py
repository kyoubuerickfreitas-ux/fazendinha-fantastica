#!/usr/bin/env python3
"""
Efeitos sonoros sintetizados (assets/sounds/<nome>.wav, mono 22 kHz).
As vozes dos animais continuam em tools/generate_sounds.py.
Para trocar um som, substitua o .wav com o mesmo nome.
Uso: python3 tools/generate_sfx.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
from synth import additive, pulse_harm, pluck, noise, lowpass, highpass, bandpass, freq, write_wav  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sounds")
SR = 22050


def T(dur):
    return np.arange(int(dur * SR)) / SR


def dec(dur, k):
    return np.exp(-T(dur) * k)


def att(dur, a=0.004):
    t = T(dur)
    return np.clip(t / a, 0, 1)


def tone(f, dur, k=8.0, harm=(1,), glide=None, a=0.003):
    n = int(dur * SR)
    s = additive(f, n, SR, list(harm), glide_to=glide)
    return s * dec(dur, k) * att(dur, a)


def square(f, dur, k=6.0, duty=0.25, a=0.002):
    return tone(f, dur, k, pulse_harm(duty, 14), a=a)


def bell(f, dur, k=5.0):
    t = T(dur)
    s = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 3 * t) * np.exp(-t * 8)
    return s * dec(dur, k) * att(dur, 0.002)


def nz(dur, lo, hi, k, seed=0):
    return bandpass(noise(int(dur * SR), seed), lo, hi, SR) * dec(dur, k) * att(dur, 0.002)


def cat(*parts, gap=0.0):
    out = []
    for p in parts:
        out.append(p)
        if gap:
            out.append(np.zeros(int(gap * SR)))
    return np.concatenate(out)


def mix(length, *items):
    """items: (som, início em s, ganho)"""
    out = np.zeros(int(length * SR))
    for s, at, g in items:
        i = int(at * SR)
        k = min(len(s), len(out) - i)
        if k > 0:
            out[i:i + k] += s[:k] * g
    return out


def add(*xs):
    """Soma sons de tamanhos diferentes."""
    out = np.zeros(max(len(x) for x in xs))
    for x in xs:
        out[:len(x)] += x
    return out


def arp(notes, step, dur, inst=bell, gain=1.0, k=5.0):
    total = step * (len(notes) - 1) + dur
    return mix(total, *[(inst(freq(n), dur, k), i * step, gain) for i, n in enumerate(notes)])


def fin(x, peak=0.8, fade=0.01):
    x = np.asarray(x, dtype=float)
    f = int(fade * SR)
    if f and len(x) > f:
        x[-f:] *= np.linspace(1, 0, f)
    return x / max(1e-9, np.abs(x).max()) * peak


def build():
    s = {}
    # ---------------------------------------------------------------- interface
    s["ui_click"] = fin(tone(1250, 0.05, 70, (1, 0.2)) + 0.3 * nz(0.05, 2000, 8000, 120), 0.6)
    s["ui_open"] = fin(cat(tone(660, 0.06, 40, (1, 0.3)), tone(990, 0.1, 30, (1, 0.3))), 0.55)
    s["ui_close"] = fin(cat(tone(880, 0.06, 40, (1, 0.3)), tone(587, 0.1, 30, (1, 0.3))), 0.5)
    s["deny"] = fin(cat(square(196, 0.09, 18, 0.5), square(165, 0.13, 14, 0.5), gap=0.02), 0.5)
    s["success"] = fin(mix(0.6, (square(freq("C6"), 0.12, 14), 0, 0.6), (square(freq("G6"), 0.4, 7), 0.1, 0.7),
                           (bell(freq("C7"), 0.5, 7), 0.1, 0.3)), 0.6)
    # ---------------------------------------------------------------- lavoura
    s["till"] = fin(lowpass(noise(int(0.2 * SR), 1), 1400, SR) * dec(0.2, 22) * att(0.2)
                    + 0.8 * tone(110, 0.2, 25, glide=70) + 0.25 * nz(0.2, 1500, 5000, 40, 2))
    water = bandpass(noise(int(0.5 * SR), 3), 700, 5000, SR) * np.sin(np.pi * T(0.5) / 0.5) ** 0.6
    water *= 0.75 + 0.25 * np.sin(2 * np.pi * 23 * T(0.5))
    bubbles = mix(0.5, *[(tone(f, 0.06, 50, glide=f * 1.6), at, 0.4) for f, at in ((700, 0.05), (900, 0.17), (650, 0.29), (1000, 0.38))])
    s["water"] = fin(water + bubbles, 0.6)
    s["fill"] = fin(mix(0.7, *[(tone(400 + 90 * i, 0.08, 40, glide=(400 + 90 * i) * 1.7), i * 0.07, 0.8) for i in range(9)])
                    + 0.3 * bandpass(noise(int(0.7 * SR), 4), 300, 2000, SR) * dec(0.7, 3), 0.6)
    s["plant"] = fin(tone(520, 0.1, 35, glide=900) + 0.5 * nz(0.1, 1500, 6000, 50, 5), 0.6)
    s["harvest"] = fin(mix(0.45, (tone(700, 0.08, 40, glide=1300), 0, 0.8),
                           (bell(freq("E6"), 0.35, 9), 0.06, 0.5), (bell(freq("B6"), 0.3, 10), 0.12, 0.35)), 0.65)
    rust = highpass(noise(int(0.28 * SR), 6), 2500, SR) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 38 * T(0.28))))
    s["weed"] = fin(rust * dec(0.28, 9) * att(0.28), 0.55)
    # ---------------------------------------------------------------- madeira e pedra
    s["chop"] = fin(nz(0.18, 300, 2500, 30, 7) + tone(300, 0.18, 26, (1, 0.4, 0.2), glide=170)
                    + 0.5 * pluck(220, int(0.18 * SR), SR, 0.8) * dec(0.18, 20))
    s["pick"] = fin(add(bell(1850, 0.25, 22), 0.5 * bell(2780, 0.2, 30), 0.7 * nz(0.05, 2000, 8000, 90, 8),
                        0.5 * tone(160, 0.1, 40)))
    s["break_wood"] = fin(mix(0.5, (nz(0.12, 500, 6000, 25, 9), 0, 1.0), (s["chop"], 0.0, 0.6),
                              (tone(140, 0.35, 10, (1, 0.5), glide=80), 0.08, 0.9), (nz(0.3, 200, 1200, 10, 10), 0.1, 0.5)))
    grains = [(nz(0.12, 200, 2500, 30, 20 + i), 0.035 * i, 0.9 - 0.08 * i) for i in range(9)]
    s["break_stone"] = fin(mix(0.55, *grains, (tone(90, 0.3, 14, glide=55), 0, 0.8)))
    s["gem"] = fin(add(arp(["C6", "E6", "G6", "C7"], 0.06, 0.4, gain=0.6, k=7),
                   mix(0.58, (highpass(noise(int(0.4 * SR), 11), 7000, SR) * dec(0.4, 10), 0.15, 0.15))), 0.6)
    s["build"] = fin(cat(s["chop"], s["chop"] * 0.8, gap=0.07), 0.7)
    # ---------------------------------------------------------------- pesca
    sweep = noise(int(0.35 * SR), 12)
    sweep = bandpass(sweep, 600, 4000, SR) * np.sin(np.pi * T(0.35) / 0.35) ** 2
    s["cast"] = fin(sweep + 0.25 * tone(900, 0.35, 4, glide=1500), 0.5)
    s["splash"] = fin(add(tone(700, 0.12, 30, glide=220), mix(0.3, (nz(0.25, 800, 5000, 14, 13), 0.02, 0.8))), 0.65)
    s["bite"] = fin(cat(square(freq("E6"), 0.07, 20), square(freq("A6"), 0.12, 14), gap=0.02), 0.6)
    s["reel"] = fin(tone(2100, 0.03, 120) + 0.4 * nz(0.03, 3000, 9000, 150, 14), 0.4)
    s["catch"] = fin(mix(1.0, *[(square(freq(n), 0.16, 12), i * 0.08, 0.6) for i, n in enumerate(["G5", "C6", "E6"])],
                         (square(freq("G6"), 0.6, 5), 0.24, 0.7), (bell(freq("C7"), 0.7, 5), 0.24, 0.35),
                         (square(freq("E6"), 0.6, 5), 0.24, 0.35)), 0.65)
    s["escape"] = fin(cat(square(freq("E5"), 0.12, 10), square(freq("C5"), 0.12, 10), square(freq("A4"), 0.3, 7), gap=0.03), 0.5)
    s["treasure"] = fin(add(arp(["G5", "B5", "D6", "G6", "B6", "D7"], 0.07, 0.8, gain=0.6, k=4),
                        mix(1.2, (highpass(noise(int(0.9 * SR), 15), 6000, SR) * dec(0.9, 4) * 0.2, 0.2, 1.0))), 0.65)
    # ---------------------------------------------------------------- dinheiro, comida, casa
    s["coin"] = fin(cat(square(freq("B5"), 0.07, 6, 0.5), square(freq("E6"), 0.3, 9, 0.5)), 0.5)
    s["buy"] = fin(square(freq("E6"), 0.18, 14, 0.5) + 0.4 * bell(freq("B6"), 0.18, 16), 0.45)
    siz = highpass(noise(int(0.9 * SR), 16), 3000, SR) * (0.6 + 0.4 * np.random.default_rng(1).random(int(0.9 * SR)) ** 8)
    s["cook"] = fin(mix(1.2, (siz * np.sin(np.pi * T(0.9) / 0.9) * 0.5, 0, 1.0), (bell(freq("A6"), 0.4, 6), 0.8, 0.6)), 0.6)
    munch = [(lowpass(noise(int(0.09 * SR), 30 + i), 1800, SR) * dec(0.09, 30) * att(0.09), 0.14 * i, 1.0) for i in range(3)]
    s["eat"] = fin(mix(0.48, *munch), 0.6)
    creak = additive(260, int(0.35 * SR), SR, [1, 0.6, 0.4, 0.3, 0.2], vib=0.05, vib_hz=30, glide_to=200) * np.sin(np.pi * T(0.35) / 0.35)
    s["door"] = fin(mix(0.55, (creak, 0, 0.35), (s["chop"], 0.36, 0.7)), 0.6)
    s["sleep"] = fin(arp(["E6", "C6", "A5", "F5", "C6"], 0.22, 0.6, gain=0.6, k=4), 0.55)
    s["levelup"] = fin(mix(1.1, *[(square(freq(n), 0.14, 10), i * 0.075, 0.55) for i, n in enumerate(["C5", "E5", "G5", "C6", "E6"])],
                           (square(freq("G6"), 0.7, 4), 0.375, 0.6), (bell(freq("C7"), 0.7, 4), 0.375, 0.4)), 0.65)
    s["chest"] = fin(mix(0.9, (creak, 0, 0.3), (arp(["C6", "G6", "C7"], 0.07, 0.5, gain=0.5, k=6), 0.25, 1.0)), 0.6)
    knock = lambda f: tone(f, 0.12, 30, (1, 0.5, 0.25)) + 0.4 * nz(0.12, 400, 3000, 40, int(f))  # noqa: E731
    s["ladder"] = fin(mix(0.7, (knock(330), 0, 1), (knock(290), 0.18, 0.9), (knock(250), 0.36, 0.8)), 0.6)
    # fala dos moradores: três "sílabas"; o jogo muda o tom para cada morador
    syl = [tone(f, 0.07, 20, (1, 0.5, 0.3, 0.15), glide=f * g, a=0.006) for f, g in ((520, 1.1), (610, 0.9), (560, 1.15))]
    s["talk"] = fin(cat(*syl, gap=0.03), 0.5)
    s["gift"] = fin(mix(0.8, (bell(freq("G6"), 0.4, 6), 0, 0.6), (bell(freq("D7"), 0.5, 5), 0.12, 0.5),
                        (highpass(noise(int(0.5 * SR), 17), 6000, SR) * dec(0.5, 8) * 0.25, 0.1, 1.0)), 0.6)
    # ---------------------------------------------------------------- passos
    s["step_grass"] = fin(highpass(noise(int(0.07 * SR), 18), 1800, SR) * dec(0.07, 45) * att(0.07, 0.006), 0.35)
    s["step_path"] = fin(bandpass(noise(int(0.07 * SR), 19), 500, 4000, SR) * dec(0.07, 55) * att(0.07), 0.35)
    s["step_stone"] = fin(tone(380, 0.05, 70, (1, 0.6, 0.3)) + 0.5 * nz(0.05, 1500, 6000, 80, 21), 0.35)
    return s


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sounds = build()
    for name, data in sounds.items():
        write_wav(os.path.join(OUT, name + ".wav"), data, SR)
    print(len(sounds), "efeitos em", OUT)
