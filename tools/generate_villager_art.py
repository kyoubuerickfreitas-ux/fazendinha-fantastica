#!/usr/bin/env python3
"""Arte PROVISÓRIA dos moradores: recolore o Fungo (chapéu, cachecol e saia) para cada um
de tools/npc_table.py e salva assets/sprites/npc_<id>.png.  Uso: python3 tools/generate_villager_art.py"""
import colorsys
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from npc_table import NPCS  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# a arte antiga do Fungo serve de base (os moradores com arte própria vêm de tools/import_npcs.py)
SRC = os.path.join(ROOT, "assets", "source", "npc_fungo_old.png")
REAL_ART = {"pipoca", "raiz", "estrelo", "carpa"}
# cor original -> parte do corpo (paleta do Fungo)
PARTS = {(181, 85, 58): "cap", (142, 63, 43): "cap", (122, 74, 58): "cap",
         (201, 111, 74): "scarf",
         (217, 201, 160): "skirt", (187, 169, 127): "skirt"}
BASE = {"cap": (181, 85, 58), "scarf": (201, 111, 74), "skirt": (217, 201, 160)}


def hexrgb(s):
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def shade(orig, base, target):
    """Mantém a variação de brilho do original em relação à cor base da parte."""
    vo = colorsys.rgb_to_hsv(*[c / 255 for c in orig])[2]
    vb = colorsys.rgb_to_hsv(*[c / 255 for c in base])[2]
    h, s, v = colorsys.rgb_to_hsv(*[c / 255 for c in target])
    v = max(0.0, min(1.0, v * (vo / vb)))
    return tuple(int(round(c * 255)) for c in colorsys.hsv_to_rgb(h, s, v))


if __name__ == "__main__":
    src = Image.open(SRC).convert("RGBA")
    for n in NPCS:
        if n["id"] in REAL_ART:
            continue
        out = src.copy()
        px = out.load()
        for y in range(out.height):
            for x in range(out.width):
                r, g, b, a = px[x, y]
                part = PARTS.get((r, g, b))
                if a and part:
                    px[x, y] = shade((r, g, b), BASE[part], hexrgb(n[part])) + (a,)
        out.save(os.path.join(ROOT, "assets", "sprites", "npc_%s.png" % n["id"]))
    print(len(NPCS), "moradores desenhados")
