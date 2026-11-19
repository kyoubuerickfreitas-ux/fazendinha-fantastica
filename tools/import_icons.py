#!/usr/bin/env python3
"""
Monta o atlas de ícones em alta resolução dos itens (32x32 por ícone).

Origem (assets/source/icons/):
  tools_forest.webp : ferramentas no estilo da floresta (fundo branco, removido aqui), em 2 linhas:
                      picareta, regador, enxada / foice, vara de pesca, machado
  tools_row.png     : só o broto e o feixe de trigo (fibra) são usados daqui

Saída: assets/sprites/items_hd.png (ícones 32x32, 16 por linha, na ordem de ORDER).
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

ORDER = ["watering_can", "hoe", "axe", "pickaxe", "scythe", "fiber", "sprout", "fishing_rod",
         "seed_bag", "seed_kale", "seed_carrot", "seed_tomato", "seed_starflower"]

# frutas e legumes (produce.webp, 4 linhas x 6), em ordem de leitura
PRODUCE = ["apple", "pear", "grape", "strawberry", "blueberry", "cherry",
           "orange", "lemon", "raspberry", "plum", "peach", "pomegranate",
           "watermelon", "melon", "pineapple", "coconut", "banana", "grape_dark",
           "carrot", "radish", "beet", "tomato", "potato", "mushroom"]
ORDER += PRODUCE

# selinho no canto do saco de sementes: nome de um ícone HD, ou índice em icons.png (16x16)
SEED_BADGES = {"seed_kale": 10, "seed_carrot": "carrot", "seed_tomato": "tomato", "seed_starflower": 11}


def remove_white(im):
    """Apaga o fundo branco ligado às bordas."""
    from collections import deque
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    q = deque([(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] +
              [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)])
    while q:
        x, y = q.popleft()
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        r, g, b, a = px[x, y]
        if min(r, g, b) < 228 or max(r, g, b) - min(r, g, b) > 25:
            continue
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                q.append((nx, ny))
    return im


def pieces(path, names, checker=False, white=False, rows=1):
    im = Image.open(path).convert("RGBA")
    if checker:
        im = remove_fake_checker(im)
    if white:
        im = remove_white(im)
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
    main.sort(key=lambda c: (c["bbox"][1] + c["bbox"][3]) / 2)
    per = len(main) // rows
    main = [c for r in range(rows) for c in sorted(main[r * per:(r + 1) * per], key=lambda c: c["bbox"][0])]
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
    old = pieces(os.path.join(SRC, "tools_row.png"),
                 ["watering_can", "pickaxe", "axe", "sprout", "fiber", "fishing_rod"])
    icons["sprout"], icons["fiber"] = old["sprout"], old["fiber"]
    icons.update(pieces(os.path.join(SRC, "tools_forest.webp"),
                        ["pickaxe", "watering_can", "hoe", "scythe", "fishing_rod", "axe"], white=True, rows=2))
    icons.update(pieces(os.path.join(SRC, "seed_bag.webp"), ["seed_bag"], white=True))
    icons.update(pieces(os.path.join(SRC, "produce.webp"), PRODUCE, white=True, rows=4))
    small_icons = Image.open(os.path.join(ROOT, "assets", "sprites", "icons.png")).convert("RGBA")
    per_row = 16
    atlas = Image.new("RGBA", (CELL * per_row, CELL * ((len(ORDER) + per_row - 1) // per_row)), (0, 0, 0, 0))
    for i, n in enumerate(ORDER):
        if n in SEED_BADGES:
            cell = fit(icons["seed_bag"])
            from PIL import ImageDraw
            d = ImageDraw.Draw(cell)
            d.ellipse((15, 15, 31, 31), fill=(43, 33, 24, 255))
            d.ellipse((16, 16, 30, 30), fill=(233, 221, 187, 255))
            k = SEED_BADGES[n]
            if isinstance(k, str):
                badge = fit(icons[k]).resize((12, 12), Image.LANCZOS)
                bp = badge.load()
                for yy in range(12):
                    for xx in range(12):
                        r, g, b, a = bp[xx, yy]
                        bp[xx, yy] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
            else:
                badge = small_icons.crop(((k % 16) * 16, (k // 16) * 16, (k % 16) * 16 + 16, (k // 16) * 16 + 16))
                badge = badge.resize((12, 12), Image.NEAREST)
            cell.alpha_composite(badge, (17, 17))
        else:
            cell = fit(icons[n])
        atlas.alpha_composite(cell, ((i % per_row) * CELL, (i // per_row) * CELL))
        print(f"{i}: {n}")
    atlas.save(OUT)
