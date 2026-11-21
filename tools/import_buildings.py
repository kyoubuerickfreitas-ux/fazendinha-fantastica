#!/usr/bin/env python3
"""
Casa do jogador e barraca do Fungo (assets/source/house_shop.png, fundo verde: casa à esquerda, barraca à direita).
Cada uma é reduzida para caber no espaço da arte anterior (128x128, base embaixo).
Uso: python3 tools/import_buildings.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from import_hud import key_flood  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "house_shop.png")
SPR = os.path.join(ROOT, "assets", "sprites")
SIZE = 128

if __name__ == "__main__":
    im = key_flood(Image.open(SRC).convert("RGBA"))
    px = im.load()
    for y in range(im.height):          # verde de fundo preso (entre as bandeirinhas e o telhado)
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and g > 190 and r < 90 and b < 90:
                px[x, y] = (0, 0, 0, 0)
    half = im.width // 2 + 20
    for name, box in (("house", (0, 0, half - 30, im.height)), ("shop", (half - 30, 0, im.width, im.height))):
        p = im.crop(box)
        p = p.crop(p.getbbox())
        s = min((SIZE - 4) / p.width, (SIZE - 4) / p.height)
        small = p.resize((round(p.width * s), round(p.height * s)), Image.LANCZOS)
        px = small.load()
        for y in range(small.height):
            for x in range(small.width):
                r, g, b, a = px[x, y]
                px[x, y] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
        out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        out.alpha_composite(small, ((SIZE - small.width) // 2, SIZE - 4 - small.height))
        out.save(os.path.join(SPR, name + ".png"))
        print(name, small.size, "escala %.3f" % s)
