#!/usr/bin/env python3
"""Panela em cima do fogão (assets/source/pot.png, fundo transparente) -> assets/sprites/house_in/pot.png.
Uso: python3 tools/import_pot.py"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WIDTH = 30          # largura no jogo (com o cabo)

if __name__ == "__main__":
    im = Image.open(os.path.join(ROOT, "assets", "source", "pot.png")).convert("RGBA")
    a = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    im.putalpha(a)
    im = im.crop(a.getbbox())
    s = WIDTH / im.width
    small = im.resize((WIDTH, round(im.height * s)), Image.LANCZOS)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            r, g, b, al = px[x, y]
            px[x, y] = (r, g, b, 255) if al >= 120 else (0, 0, 0, 0)
    small.save(os.path.join(ROOT, "assets", "sprites", "house_in", "pot.png"))
    print("panela", small.size)
