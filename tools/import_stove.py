#!/usr/bin/env python3
"""
Fogão novo (assets/source/stove.png, fundo xadrez pintado) e a bancada da pia separada dele.
  assets/sprites/house_in/stove.png    o fogão de casa (1 quadrado de largura)
  assets/sprites/house_in/counter.png  a bancada com a pia (a parte esquerda da cozinha antiga, 2 quadrados)
  assets/sprites/craft/stove.png       o fogão colocável (saves antigos), mesma arte
Também imprime onde fica a boca do fogão (para HouseWorld.STOVE_OFFSET).
Uso: python3 tools/import_stove.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from import_animals import remove_fake_checker  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HIN = os.path.join(ROOT, "assets", "sprites", "house_in")
WIDTH = 40
BURNER = (615, 400)          # centro da boca na arte original


def shrink(im, w):
    s = w / im.width
    small = im.resize((w, round(im.height * s)), Image.LANCZOS)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 120 else (0, 0, 0, 0)
    return small, s


if __name__ == "__main__":
    im = remove_fake_checker(Image.open(os.path.join(ROOT, "assets", "source", "stove.png")).convert("RGBA"))
    bb = im.getbbox()
    im = im.crop(bb)
    small, s = shrink(im, WIDTH)
    small.save(os.path.join(HIN, "stove.png"))
    bx = (BURNER[0] - bb[0]) * s - small.width / 2.0
    by = (BURNER[1] - bb[1]) * s - small.height
    print("fogão", small.size, "boca em relação à base: (%.0f, %.0f)" % (bx, by))
    craft, _ = shrink(im, 28)
    craft.save(os.path.join(ROOT, "assets", "sprites", "craft", "stove.png"))
    # bancada com a pia: a cozinha antiga sem o fogão (fecha com a borda direita original)
    k = Image.open(os.path.join(HIN, "kitchen.png")).convert("RGBA")
    left = k.crop((0, 0, 62, k.height))
    edge = k.crop((96, 0, k.width, k.height))
    out = Image.new("RGBA", (left.width + edge.width, k.height), (0, 0, 0, 0))
    out.paste(left, (0, 0))
    out.paste(edge, (left.width, 0))
    out.save(os.path.join(HIN, "counter.png"))
    print("bancada", out.size)
