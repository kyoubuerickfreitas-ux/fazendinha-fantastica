#!/usr/bin/env python3
"""
Monta o atlas de ícones em alta resolução dos itens (32x32 por ícone).

Origem (assets/source/icons/):
  tools_forest.webp : ferramentas no estilo da floresta (fundo branco, removido aqui), em 2 linhas:
                      picareta, regador, enxada / foice, vara de pesca, machado
  tools_row.png     : só o broto e o feixe de trigo (fibra) são usados daqui

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
    atlas = Image.new("RGBA", (CELL * len(ORDER), CELL), (0, 0, 0, 0))
    for i, n in enumerate(ORDER):
        atlas.alpha_composite(fit(icons[n]), (i * CELL, 0))
        print(f"{i}: {n}")
    atlas.save(OUT)
