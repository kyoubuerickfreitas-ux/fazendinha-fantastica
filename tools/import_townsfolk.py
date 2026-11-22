#!/usr/bin/env python3
"""
Moradores que passeiam pela cidade (assets/source/townsfolk.png, fundo verde): 12 personagens em
4 linhas x 3, cada um com 4 vistas (frente, 3/4 de frente, 3/4 de costas, costas) em células de 128x256.
Saída: assets/sprites/townsfolk/<n>.png  4 quadros de 64x64 nessa ordem (andar: frente = descer,
3/4 = para os lados (espelhado para a esquerda), costas = subir).
Uso: python3 tools/import_townsfolk.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from import_hud import key_flood  # noqa: E402
from import_shop_npcs import frame_of  # noqa: E402
from import_city import drop_strays  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "townsfolk.png")
OUT = os.path.join(ROOT, "assets", "sprites", "townsfolk")
HEIGHT = 50            # um pouco menores que os donos de loja (gente comum, crianças)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    im = key_flood(Image.open(SRC).convert("RGBA"))
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and g > 190 and r < 90 and b < 90:
                px[x, y] = (0, 0, 0, 0)
    cw, ch = im.width // 12, im.height // 4
    n = 0
    for row in range(4):
        for who in range(3):
            crops = []
            for v in range(4):
                col = who * 4 + v
                cell = drop_strays(im.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch)), 0.08)
                crops.append(cell.crop(cell.getbbox()))
            s = HEIGHT / max(c.height for c in crops)
            sheet = Image.new("RGBA", (64 * 4, 64), (0, 0, 0, 0))
            for v, c in enumerate(crops):
                sheet.alpha_composite(frame_of(c, s), (v * 64, 0))
            sheet.save(os.path.join(OUT, "%d.png" % n))
            n += 1
    print(n, "moradores")
