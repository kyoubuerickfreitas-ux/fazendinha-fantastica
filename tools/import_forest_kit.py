#!/usr/bin/env python3
"""
Converte os sprites do Forest Map Kit (assets/source/forest_kit/) para a escala do jogo.

No kit, uma pessoa tem ~63 px; no jogo, ~40 px. Por isso reduzimos para 60%,
recortamos as bordas vazias e deixamos a base do objeto na última linha da imagem.
Saída: assets/sprites/forest/<nome>.png

Uso: python3 tools/import_forest_kit.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "forest_kit")
OUT = os.path.join(ROOT, "assets", "sprites", "forest")
SCALE = 0.6

# nome no jogo: (arquivo do kit, escala extra)
MAP = {
    # árvores que podem ser cortadas
    "tree_a": ("broadleaf-tree_001", 1.0),
    "tree_b": ("broadleaf-tree_007", 1.0),
    "tree_c": ("broadleaf-tree_008", 1.0),
    "tree_d": ("broadleaf-tree_010", 1.0),
    "tree_e": ("broadleaf-tree_011", 1.0),
    # árvores antigas da borda (não podem ser cortadas)
    "old_tree_a": ("broadleaf-tree_004", 0.8),
    "old_tree_b": ("broadleaf-tree_005", 0.8),
    "old_tree_c": ("broadleaf-tree_006", 0.8),
    "old_tree_d": ("broadleaf-tree_012", 0.8),
    "old_tree_e": ("broadleaf-tree_013", 0.8),
    "pine_a": ("pine_003", 1.0),
    "pine_b": ("pine_005", 1.0),
    # pedras
    "rock_small": ("big-rock_005", 0.75),
    "boulder_a": ("big-rock_001", 1.0),
    "boulder_b": ("big-rock_002", 1.0),
    "boulder_c": ("big-rock_003", 1.0),
    "boulder_d": ("big-rock_006", 1.0),
    # mato (foice) e arbustos
    "weed_a": ("bush_004", 1.0),
    "weed_b": ("bush_005", 1.0),
    "weed_c": ("bush_006", 1.0),
    "weed_d": ("bush_007", 1.0),
    "weed_e": ("bush_008", 1.0),
    "bush_a": ("bush_009", 1.0),
    "bush_b": ("bush_010", 1.0),
    "bush_c": ("bush_011", 1.0),
    "bush_d": ("bush_014", 1.0),
    "bush_e": ("bush_015", 1.0),
    "bush_f": ("bush_017", 1.0),
    "sapling_a": ("bush_001", 1.0),
    "sapling_b": ("bush_019", 1.0),
    # cogumelos gigantes
    "mushroom_a": ("giant-mushroom_002", 1.0),
    "mushroom_b": ("giant-mushroom_008", 1.0),
    "mushroom_c": ("giant-mushroom_012", 1.0),
    "mushroom_d": ("giant-mushroom_016", 1.0),
    # acampamento / decoração
    "campfire": ("camp_002", 1.0),
    "tent": ("camp_003", 1.0),
    "crate_veggies": ("camp_004", 1.0),
    "barrel": ("camp_005", 1.0),
    "crate": ("camp_006", 1.0),
    "fence": ("camp_010", 1.0),
}


def convert(src_name, extra):
    im = Image.open(os.path.join(SRC, src_name + ".png")).convert("RGBA")
    s = SCALE * extra
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    # bordas nítidas: alfa binário
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
    bbox = im.getbbox()
    return im.crop(bbox) if bbox else im


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, (src, extra) in MAP.items():
        img = convert(src, extra)
        img.save(os.path.join(OUT, name + ".png"))
        print(f"{name:14s} {img.width}x{img.height}")
