#!/usr/bin/env python3
"""
Trator (assets/source/tractor.png, fundo verde, 4 vistas): frente (baixo), costas (cima),
virado para a esquerda (capô à esquerda) e para a direita. Saída: assets/sprites/tractor/<direção>.png,
todas na mesma escala, com as rodas na base da imagem.
Também importa a caçamba (assets/source/trailer.png, mesma organização: em cima à esquerda vista com o
engate para baixo, embaixo à esquerda para cima, à direita engate para a esquerda e para a direita)
em assets/sprites/tractor/trailer_<direção do trator>.png.
Uso: python3 tools/import_tractor.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from import_hud import key_flood  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "tractor.png")
OUT = os.path.join(ROOT, "assets", "sprites", "tractor")
VIEWS = {"down": (0, 0, 700, 500), "left": (700, 0, 1536, 512), "up": (0, 500, 700, 1024), "right": (700, 512, 1536, 1024)}
SCALE = 0.13

def import_sheet(src, views, prefix, scale=SCALE):
    im = key_flood(Image.open(src).convert("RGBA"))
    px = im.load()
    for y in range(im.height):         # verde de fundo preso dentro da cabine
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and g > 190 and r < 90 and b < 90:
                px[x, y] = (0, 0, 0, 0)
    for name, box in views.items():
        p = im.crop(box)
        p = p.crop(p.getbbox())
        small = p.resize((round(p.width * scale), round(p.height * scale)), Image.LANCZOS)
        sp = small.load()
        for y in range(small.height):
            for x in range(small.width):
                r, g, b, a = sp[x, y]
                sp[x, y] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
        small.save(os.path.join(OUT, prefix + name + ".png"))
        print(prefix + name, small.size)


# caçamba: nome = direção do TRATOR (o engate aponta para ele)
TRAILER_VIEWS = {"down": (0, 0, 700, 500), "left": (700, 0, 1536, 500), "up": (0, 500, 700, 1024),
                 "right": (700, 500, 1536, 1024)}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    import_sheet(SRC, VIEWS, "")
    import_sheet(os.path.join(ROOT, "assets", "source", "trailer.png"), TRAILER_VIEWS, "trailer_", 0.105)
