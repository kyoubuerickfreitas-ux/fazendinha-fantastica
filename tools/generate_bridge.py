#!/usr/bin/env python3
"""
Ponte de madeira da estrada sobre o rio (assets/sprites/bridge.png, 32x44: um pedaço que se repete na
horizontal). As tábuas ficam atravessadas (em pé), com corrimão em cima e embaixo; o tabuleiro ocupa
y 6..37 (o quadrado da estrada) e os corrimãos saem um pouco para cima e para baixo.
Uso: python3 tools/generate_bridge.py
"""
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "bridge.png")


def hx(s):
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


PLANKS = [hx("a87548"), hx("9a6a40"), hx("b07a4a")]
DARK, DD, LIGHT = hx("6e4628"), hx("3e2614"), hx("c99566")

if __name__ == "__main__":
    rng = random.Random(4)
    img = Image.new("RGBA", (32, 44), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # tabuleiro: tábuas de 4 px em pé
    for i, x in enumerate(range(0, 32, 4)):
        c = PLANKS[i % 3]
        d.rectangle((x, 6, x + 3, 37), fill=c)
        d.line((x + 3, 6, x + 3, 37), fill=DARK)
        d.line((x, 6, x, 37), fill=LIGHT if i % 2 else c)
        for _ in range(2):
            d.point((x + rng.randrange(1, 3), rng.randrange(8, 36)), fill=DARK)
        d.point((x + 1, 9), fill=DD)          # pregos
        d.point((x + 1, 34), fill=DD)
    # sombra embaixo do tabuleiro
    d.line((0, 37, 31, 37), fill=DD)
    # corrimão de cima (atrás) e de baixo (na frente), com postes a cada 16 px
    for y0 in (0, 36):
        d.rectangle((0, y0 + 1, 31, y0 + 3), fill=hx("8a5a34"))
        d.line((0, y0 + 1, 31, y0 + 1), fill=LIGHT)
        d.line((0, y0 + 4, 31, y0 + 4), fill=DD)
        for px in (2, 18):
            d.rectangle((px, y0, px + 3, y0 + 7), fill=hx("7a4c2a"))
            d.line((px, y0, px + 3, y0), fill=LIGHT)
            d.line((px + 3, y0, px + 3, y0 + 7), fill=DD)
    img.save(OUT)
    print("ponte", img.size, OUT)
