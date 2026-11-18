#!/usr/bin/env python3
"""
Monta o atlas de ícones em alta resolução dos itens (32x32 por ícone).

Origem (assets/source/icons/):
  tools_row.png  : regador, picareta, machado, broto, feixe de trigo, vara de pesca (com transparência)
  hoe_sickle.png : enxada e foice (fundo xadrez pintado, removido aqui)

Saída: assets/sprites/items_hd.png (uma linha de ícones 32x32, na ordem de ORDER).
O índice de cada ícone é usado em "hd" nos itens de scripts/data/item_db.gd.

Uso: python3 tools/import_icons.py
"""
import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_animals import components, cut, remove_fake_checker  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "icons")
OUT = os.path.join(ROOT, "assets", "sprites", "items_hd.png")
CELL = 32
FIT = 30

ORDER = ["watering_can", "hoe", "axe", "pickaxe", "scythe", "fiber", "sprout", "fishing_rod"]


def pieces(path, names, checker=False):
    im = Image.open(path).convert("RGBA")
    if checker:
        im = remove_fake_checker(im)
    comps = components(im)
    big = max(c["area"] for c in comps)
    main = [c for c in comps if c["area"] >= big * 0.08]
    small = [c for c in comps if big * 0.0005 <= c["area"] < big * 0.08]
    for s in small:  # linha da vara, brilhos soltos...
        sx, sy = (s["bbox"][0] + s["bbox"][2]) / 2, (s["bbox"][1] + s["bbox"][3]) / 2

        def dist(c):
            b = c["bbox"]
            return max(b[0] - sx, 0, sx - b[2]) ** 2 + max(b[1] - sy, 0, sy - b[3]) ** 2
        m = min(main, key=dist)
        if dist(m) < 60 ** 2:
            m["pts"] += s["pts"]
            b = m["bbox"]
            m["bbox"] = [min(b[0], s["bbox"][0]), min(b[1], s["bbox"][1]),
                         max(b[2], s["bbox"][2]), max(b[3], s["bbox"][3])]
    assert len(main) == len(names), f"{path}: esperava {len(names)} ícones, achei {len(main)}"
    main.sort(key=lambda c: c["bbox"][0])
    return {n: cut(im, c) for n, c in zip(names, main)}


def fit(img):
    s = FIT / max(img.width, img.height)
    w, h = max(1, round(img.width * s)), max(1, round(img.height * s))
    small = img.resize((w, h), Image.LANCZOS)
    px = small.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    cell.alpha_composite(small, ((CELL - w) // 2, (CELL - h) // 2))
    return cell


if __name__ == "__main__":
    icons = {}
    icons.update(pieces(os.path.join(SRC, "tools_row.png"),
                        ["watering_can", "pickaxe", "axe", "sprout", "fiber", "fishing_rod"]))
    icons.update(pieces(os.path.join(SRC, "hoe_sickle.png"), ["hoe", "scythe"], checker=True))
    atlas = Image.new("RGBA", (CELL * len(ORDER), CELL), (0, 0, 0, 0))
    for i, n in enumerate(ORDER):
        atlas.alpha_composite(fit(icons[n]), (i * CELL, 0))
        print(f"{i}: {n}")
    atlas.save(OUT)
