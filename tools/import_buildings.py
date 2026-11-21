#!/usr/bin/env python3
"""
Casa do jogador e barraca do Fungo (assets/source/house_shop.png, fundo verde, vistas de frente:
casa à esquerda, barraca à direita). As pedrinhas soltas embaixo (caminho) saem; o resto é reduzido
para caber no espaço da arte anterior (128x128, base embaixo).
Uso: python3 tools/import_buildings.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from import_hud import key_flood  # noqa: E402
from import_animals import components  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "house_shop.png")
SPR = os.path.join(ROOT, "assets", "sprites")
SIZE = 128


def drop_loose_stones(p):
    """Tira os pedaços pequenos soltos na parte de baixo (pedrinhas do caminho, florzinhas no chão).
    A fumaça da chaminé (solta, mas em cima) fica."""
    comps = components(p, 1)
    big = max(c["area"] for c in comps)
    px = p.load()
    for c in comps:
        cy = (c["bbox"][1] + c["bbox"][3]) / 2
        if c["area"] < big * 0.05 and cy > p.height * 0.6:
            for x, y in c["pts"]:
                px[x, y] = (0, 0, 0, 0)
    return p


if __name__ == "__main__":
    im = key_flood(Image.open(SRC).convert("RGBA"))
    px = im.load()
    for y in range(im.height):          # verde de fundo preso (atrás das placas, dentro da fumaça)
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and g > 190 and r < 90 and b < 90:
                px[x, y] = (0, 0, 0, 0)
    # pedrinhas do caminho embaixo das construções (encostam na grama: corte por faixas)
    for (x0, y0, x1) in ((0, 807, 887), (290, 799, 630), (100, 793, 235),     # casa
                         (887, 813, 1774)):                                    # barraca
        for y in range(y0, im.height):
            for x in range(x0, x1):
                px[x, y] = (0, 0, 0, 0)
    mid = im.width // 2
    for name, box in (("house", (0, 0, mid, im.height)), ("shop", (mid, 0, im.width, im.height))):
        p = drop_loose_stones(im.crop(box))
        p = p.crop(p.getbbox())
        s = min((SIZE - 4) / p.width, (SIZE - 4) / p.height)
        small = p.resize((round(p.width * s), round(p.height * s)), Image.LANCZOS)
        spx = small.load()
        for y in range(small.height):
            for x in range(small.width):
                r, g, b, a = spx[x, y]
                spx[x, y] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
        out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        out.alpha_composite(small, ((SIZE - small.width) // 2, SIZE - 4 - small.height))
        out.save(os.path.join(SPR, name + ".png"))
        print(name, small.size, "escala %.3f" % s)
