#!/usr/bin/env python3
"""
Interior da casa a partir da folha assets/source/house_interior.png (fundo verde).
Saída: assets/sprites/house_in/<nome>.png, todas na mesma escala (SCALE), com a base na base da imagem.
Substitui a arte provisória de tools/generate_house_interior.py (os nomes novos são usados por
scripts/world/house_world.gd).
Uso: python3 tools/import_house_interior.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from import_hud import key_flood  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "house_interior.png")
OUT = os.path.join(ROOT, "assets", "sprites", "house_in")
SCALE = 0.28          # a cama (≈235 px) fica com 2 quadrados de largura

PIECES = {
    "bed": (45, 23, 282, 291), "sofa": (334, 53, 655, 242), "coffee_table": (697, 87, 863, 222),
    "rug": (899, 62, 1209, 253), "tv": (1240, 43, 1500, 260),
    "kitchen": (32, 300, 389, 505), "cupboard": (425, 287, 567, 506), "side_table": (608, 304, 831, 499),
    "armchair": (867, 320, 1032, 499), "nightstand": (1065, 318, 1187, 499), "bookshelf": (1223, 287, 1381, 508),
    "tv_side": (1426, 308, 1514, 508),
    "wall_window": (22, 534, 374, 749), "wall_plain": (394, 534, 696, 749), "door": (729, 523, 909, 749),
    "window_small": (944, 551, 1061, 686), "lantern_post": (1253, 553, 1402, 756), "pillar": (1441, 533, 1498, 756),
    "floor_big": (24, 770, 459, 990), "floor_tile": (482, 771, 677, 989), "floor_corner": (709, 771, 907, 988),
    "wall_tile": (937, 776, 1116, 985), "crate": (1144, 776, 1350, 985), "flower_box": (1375, 772, 1509, 877),
    "plant_pot": (1396, 890, 1485, 996),
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    im = key_flood(Image.open(SRC).convert("RGBA"))
    px = im.load()
    for y in range(im.height):          # verde de fundo preso (entre pernas de móvel, janelas)
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and g > 190 and r < 90 and b < 90:
                px[x, y] = (0, 0, 0, 0)
    for name, box in PIECES.items():
        p = im.crop(box)
        p = p.crop(p.getbbox())
        small = p.resize((max(1, round(p.width * SCALE)), max(1, round(p.height * SCALE))), Image.LANCZOS)
        sp = small.load()
        opaque = name.startswith("floor") or name.startswith("wall")
        for y in range(small.height):
            for x in range(small.width):
                r, g, b, a = sp[x, y]
                sp[x, y] = (r, g, b, 255) if (a >= 110 or (opaque and a > 0)) else (0, 0, 0, 0)
        small.save(os.path.join(OUT, name + ".png"))
        print(name, small.size)
