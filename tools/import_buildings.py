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

def remove_ground(im, box):
    """Tira o chão (grama e pedras) de um trecho, mantendo a madeira (postes, caixa de correio, floreiras)
    e o contorno escuro colado nela."""
    import colorsys
    px = im.load()
    x0, y0, x1, y1 = box
    wood = set()
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, a = px[x, y]
            if not a:
                continue
            h, sat, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if r > g + 25 and sat > 0.45 and 0.25 < v < 0.8 and (h < 0.11 or h > 0.95):
                wood.add((x, y))
    near = set()
    for x, y in wood:
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                near.add((x + dx, y + dy))
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, a = px[x, y]
            if not a or (x, y) in wood:
                continue
            if (r + g + b) / 3 < 60 and (x, y) in near:
                continue                    # contorno da madeira
            px[x, y] = (0, 0, 0, 0)
    # sobras soltas (contornos das pedras): pedaços pequenos que não encostam no resto da casa
    from import_animals import components
    region = im.crop(box)
    for c in components(region, 1):
        touches_top = c["bbox"][1] == 0
        if c["area"] < 400 and not touches_top:
            for x, y in c["pts"]:
                px[x + x0, y + y0] = (0, 0, 0, 0)


if __name__ == "__main__":
    im = key_flood(Image.open(SRC).convert("RGBA"))
    px = im.load()
    for y in range(im.height):          # verde de fundo preso (entre as bandeirinhas e o telhado)
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and g > 190 and r < 90 and b < 90:
                px[x, y] = (0, 0, 0, 0)
    remove_ground(im, (0, 776, im.width // 2 + 10, im.height))   # casa: sem o chão de grama e pedrinhas na porta
    for y in range(778, im.height):                               # embaixo da escada (até a caixa de correio)
        for x in range(400, 702):
            im.putpixel((x, y), (0, 0, 0, 0))
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
