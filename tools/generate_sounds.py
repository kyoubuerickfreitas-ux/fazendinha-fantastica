#!/usr/bin/env python3
"""
Sons PROVISÓRIOS sintetizados (assets/sounds/*.wav): vozes dos animais e efeitos.
Para trocar, substitua o .wav com o mesmo nome.
Uso: python3 tools/generate_sounds.py
"""
import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sounds")
SR = 22050


def save(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    data = b"".join(struct.pack("<h", int(max(-1, min(1, s / peak * 0.8)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def env(t, dur, a=0.02, r=0.15):
    if t < a:
        return t / a
    if t > dur - r:
        return max(0.0, (dur - t) / r)
    return 1.0


def voice(dur, f0, f1, harm, vib=0.0, vib_hz=6.0, noise=0.0, seed=1):
    rng = random.Random(seed)
    out = []
    ph = 0.0
    for i in range(int(dur * SR)):
        t = i / SR
        k = t / dur
        f = f0 + (f1 - f0) * k + vib * math.sin(2 * math.pi * vib_hz * t)
        ph += 2 * math.pi * f / SR
        s = sum(a * math.sin(ph * (n + 1)) for n, a in enumerate(harm))
        s += noise * (rng.random() * 2 - 1)
        out.append(s * env(t, dur))
    return out


def chirp(dur, f0, f1, reps=2, gap=0.05):
    out = []
    for r in range(reps):
        out += voice(dur, f0, f1, [1, 0.3], vib=30, vib_hz=40, seed=r)
        out += [0.0] * int(gap * SR)
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("moombor", voice(0.9, 150, 115, [1, 0.6, 0.35, 0.2, 0.1], vib=4, noise=0.03))
    save("fofranca", voice(0.7, 330, 300, [1, 0.5, 0.3], vib=28, vib_hz=11, noise=0.04))
    save("catarrapio", voice(0.12, 210, 160, [1, 0.8, 0.5], noise=0.4) + [0.0] * 800
         + voice(0.14, 230, 170, [1, 0.8, 0.5], noise=0.4, seed=2))
    save("piuplum", chirp(0.09, 1700, 2300, reps=3))
    save("pop", voice(0.08, 600, 900, [1, 0.3]))
    save("collect", voice(0.07, 880, 880, [1]) + voice(0.12, 1320, 1320, [1, 0.2]))
    save("brush", [((random.random() * 2 - 1) * 0.5) * env(i / SR, 0.35) * (0.6 + 0.4 * math.sin(i / SR * 60))
                   for i in range(int(0.35 * SR))])
    print("sons gerados em", OUT)
