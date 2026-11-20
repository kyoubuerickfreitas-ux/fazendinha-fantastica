#!/usr/bin/env python3
"""
Arte PROVISÓRIA da cozinha:
  assets/sprites/food/<receita>.png   ícones 32x32 dos pratos (tools/recipe_table.py)
  assets/sprites/food/recipe_scroll.png  receita (pergaminho) vendida pelo Fungo
  assets/sprites/craft/stove.png + icon_stove.png  o Fogão

Para trocar pela arte definitiva, substitua o PNG mantendo o nome.
Uso: python3 tools/generate_food_art.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw  # noqa: E402
from generate_placeholder_art import hx, outline, ell, WOOD, WOOD_L, WOOD_D, CREAM  # noqa: E402
from recipe_table import RECIPES  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "food")
CRAFT = os.path.join(ROOT, "assets", "sprites", "craft")
PLATE, PLATE_D = hx("F2EBD8"), hx("CFC3A4")
BOWL, BOWL_D = hx("C9A27A"), hx("8E6A48")
STEAM = (255, 255, 255, 150)

# receita -> (recipiente, cor principal, cores de cobertura, com vapor?)
SPEC = {
    "salad_kale": ("bowl", "78945B", ["B6C995", "4E6B3A", "C8382E"], False),
    "omelette": ("plate", "F2D16B", ["E8B84A", "78945B"], True),
    "grilled_fish": ("plate_fish", "C8843E", ["9A5A2E", "F2E26B"], True),
    "fruit_juice": ("glass", "F29A3A", ["F2C14E"], False),
    "carrot_soup": ("bowl", "E8873A", ["F2C14E", "78945B"], True),
    "beet_soup": ("bowl", "9E2A45", ["E9DDBB", "78945B"], True),
    "mashed_potato": ("bowl", "EADBA8", ["F2D16B", "78945B"], True),
    "fruit_salad": ("bowl", "F2C14E", ["C8382E", "78945B", "F29A3A", "8E6BC8"], False),
    "cheese_grapes": ("board", "F2D16B", ["6E3A8A", "9A5ABE"], False),
    "lemonade": ("glass", "F2E26B", ["B6C995"], False),
    "blueberry_pancake": ("pancake", "D9A25A", ["4C5FA8", "7D8FD8"], True),
    "tropical_pop": ("pop", "F2C14E", ["F29A3A", "E9DDBB"], False),
    "strawberry_cake": ("cake", "F2C9D0", ["C8382E", "E9DDBB"], False),
    "apple_pie": ("pie", "D9A25A", ["B5553A", "8E3F2B"], True),
    "mushroom_risotto": ("bowl", "E9DDBB", ["A8784F", "D9C49A", "78945B"], True),
    "starflower_tea": ("cup", "C8DCEB", ["F2D16B"], True),
    "lake_stew": ("bowl", "C8843E", ["E9DDBB", "E8873A", "78945B"], True),
    "lake_sushi": ("sushi", "F2EBD8", ["E8873A", "2E3A2E"], False),
    "truffle_pasta": ("plate", "EADBA8", ["4A3426", "D9C49A", "78945B"], True),
    "legend_feast": ("feast", "F2C14E", ["C8382E", "78945B", "F2D16B"], True),
}


def canvas(w=32, h=32):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def dots(d, colors, box, n=7, r=2, seed=0):
    x0, y0, x1, y1 = box
    for i in range(n):
        x = x0 + ((i * 7 + seed * 3) % max(1, x1 - x0))
        y = y0 + ((i * 5 + seed) % max(1, y1 - y0))
        ell(d, x, y, r, r - 1 if r > 1 else r, hx(colors[i % len(colors)]))


def steam(d):
    for x in (12, 18):
        d.line([(x, 8), (x - 1, 6), (x + 1, 4), (x, 2)], fill=STEAM, width=1)


def dish(rid):
    kind, main, tops, hot = SPEC[rid]
    img, d = canvas()
    m = hx(main)
    if kind == "bowl":
        d.pieslice((4, 8, 28, 30), 0, 180, fill=BOWL)
        d.arc((4, 8, 28, 30), 0, 180, fill=BOWL_D)
        ell(d, 16, 19, 12, 4, m)
        dots(d, tops, (8, 17, 25, 21), n=6, r=2, seed=len(rid))
    elif kind in ("plate", "plate_fish"):
        ell(d, 16, 21, 14, 7, PLATE_D)
        ell(d, 16, 20, 13, 6, PLATE)
        if kind == "plate_fish":
            d.polygon([(6, 19), (11, 15), (21, 15), (25, 18), (29, 14), (29, 23), (25, 20), (21, 23), (11, 23)], fill=m)
            for x in (13, 17, 21):
                d.line((x, 16, x - 1, 22), fill=hx(tops[0]))
            ell(d, 24, 23, 2, 1, hx(tops[1]))
            d.point((9, 18), fill=hx("2B2118"))
        else:
            ell(d, 16, 18, 9, 4, m)
            dots(d, tops, (9, 16, 23, 20), n=6, r=2, seed=len(rid))
    elif kind == "glass":
        d.polygon([(9, 7), (23, 7), (21, 29), (11, 29)], fill=(220, 236, 240, 170))
        d.polygon([(10, 12), (22, 12), (20.5, 28), (11.5, 28)], fill=m)
        ell(d, 22, 9, 4, 4, hx(tops[0]))
        d.line((19, 3, 15, 22), fill=hx("C8382E"), width=2)
    elif kind == "cup":
        d.rectangle((7, 12, 23, 27), fill=hx("F2EBD8"))
        d.arc((20, 14, 29, 23), 270, 90, fill=hx("CFC3A4"), width=2)
        ell(d, 15, 13, 8, 2, m)
        ell(d, 15, 13, 2, 1, hx(tops[0]))
        ell(d, 16, 29, 12, 2, PLATE_D)
    elif kind == "board":
        d.rounded_rectangle((3, 16, 29, 27), radius=3, fill=WOOD_L)
        d.line((5, 26, 27, 26), fill=WOOD)
        d.polygon([(6, 18), (16, 13), (16, 22), (6, 22)], fill=m)
        for x, y in ((19, 15), (23, 15), (21, 18), (25, 18), (19, 21), (23, 21), (21, 24)):
            ell(d, x, y, 2, 2, hx(tops[(x + y) % 2]))
    elif kind == "pancake":
        ell(d, 16, 26, 14, 4, PLATE)
        for i, y in enumerate((23, 19, 15)):
            ell(d, 16, y, 11, 4, m if i % 2 == 0 else hx("C88E48"))
        ell(d, 16, 13, 8, 3, hx(tops[0]))
        dots(d, tops, (11, 11, 21, 15), n=4, r=2, seed=2)
    elif kind == "pop":
        d.rectangle((14, 22, 17, 31), fill=WOOD_L)
        d.rounded_rectangle((8, 3, 23, 24), radius=6, fill=m)
        d.rectangle((8, 3, 23, 9), fill=hx(tops[0]))
        d.rectangle((8, 16, 23, 24), fill=hx(tops[1]))
        d.line((11, 6, 11, 20), fill=(255, 255, 255, 150))
    elif kind == "cake":
        d.polygon([(4, 20), (18, 13), (28, 18), (28, 27), (14, 31), (4, 27)], fill=m)
        d.polygon([(4, 20), (18, 13), (28, 18), (14, 24)], fill=hx(tops[1]))
        d.line((4, 23, 14, 27, 28, 21), fill=hx("C8382E"), width=2)
        ell(d, 16, 17, 3, 3, hx(tops[0]))
        d.point((16, 13), fill=hx("78945B"))
    elif kind == "pie":
        ell(d, 16, 22, 14, 7, hx("A8784F"))
        ell(d, 16, 20, 12, 6, m)
        for x in range(8, 26, 5):
            d.line((x, 15, x + 3, 25), fill=hx(tops[0]))
        d.line((6, 20, 26, 20), fill=hx(tops[1]))
    elif kind == "sushi":
        d.rounded_rectangle((3, 20, 29, 27), radius=2, fill=WOOD_L)
        for x in (5, 13, 21):
            d.rounded_rectangle((x, 12, x + 7, 21), radius=2, fill=m)
            d.rectangle((x, 12, x + 7, 15), fill=hx(tops[0]))
            d.rectangle((x + 2, 16, x + 5, 21), fill=hx(tops[1]))
    elif kind == "feast":
        ell(d, 16, 22, 15, 8, GOLD_RIM)
        ell(d, 16, 21, 13, 6, PLATE)
        d.polygon([(5, 19), (11, 13), (22, 13), (26, 17), (30, 12), (30, 24), (26, 20), (22, 25), (11, 25)], fill=hx("4C88A3"))
        d.polygon([(11, 14), (22, 14), (24, 17), (11, 18)], fill=hx("7DB4C9"))
        dots(d, tops, (8, 22, 24, 26), n=5, r=2, seed=3)
        d.point((8, 18), fill=hx("2B2118"))
        for sx, sy in ((4, 6), (27, 5)):
            d.point([(sx, sy), (sx - 1, sy), (sx + 1, sy), (sx, sy - 1), (sx, sy + 1)], fill=(255, 250, 220, 255))
    if hot:
        steam(d)
    return outline(img)


GOLD_RIM = hx("F2C14E")


def scroll():
    img, d = canvas()
    d.rectangle((7, 6, 25, 26), fill=hx("E8D3A2"))
    ell(d, 7, 16, 3, 10, hx("D9C08A"))
    ell(d, 25, 16, 3, 10, hx("D9C08A"))
    for y in (10, 14, 18, 22):
        d.line((11, y, 21, y), fill=hx("A8784F"))
    d.rectangle((14, 24, 18, 30), fill=hx("C8382E"))
    ell(d, 16, 24, 3, 3, hx("C8382E"))
    return outline(img)


def stove():
    img, d = canvas(32, 44)
    d.rectangle((3, 14, 28, 41), fill=hx("6B6A5E"))
    d.rectangle((3, 14, 28, 18), fill=hx("8B8A7C"))
    d.rectangle((7, 24, 24, 37), fill=hx("2B2118"))
    d.rectangle((8, 31, 23, 36), fill=hx("C8382E"))
    d.rectangle((10, 30, 21, 31), fill=hx("F2C14E"))
    for x in (9, 15, 21):
        ell(d, x, 15, 3, 1, hx("4A4A40"))
    d.rectangle((20, 0, 25, 13), fill=hx("6B6A5E"))     # chaminé
    d.rectangle((6, 8, 15, 13), fill=hx("8E6A48"))      # panelinha
    d.rectangle((5, 7, 16, 8), fill=hx("553926"))
    return outline(img)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for r in RECIPES:
        dish(r["id"]).save(os.path.join(OUT, r["id"] + ".png"))
    scroll().save(os.path.join(OUT, "recipe_scroll.png"))
    s = stove()
    s.save(os.path.join(CRAFT, "stove.png"))
    ic, _ = canvas()
    small = s.resize((22, 30), Image.NEAREST)
    ic.alpha_composite(small, (5, 1))
    ic.save(os.path.join(CRAFT, "icon_stove.png"))
    print(len(RECIPES), "pratos em", OUT)
