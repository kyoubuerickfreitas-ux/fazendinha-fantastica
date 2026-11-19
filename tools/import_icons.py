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

# produtos dos animais (animal_products.webp, 1 linha)
ANIMAL_PRODUCTS = ["milk", "wool", "egg"]
ORDER += ANIMAL_PRODUCTS + ["truffle"]

# peixes (fish.webp, 4 linhas x 5, fundo preto)
FISH = ["fish_orange", "fish_mackerel", "fish_goldfish", "fish_perch", "fish_catfish",
        "fish_silver", "fish_puffer", "fish_angel", "fish_snapper", "fish_eel",
        "fish_shark", "fish_clown", "fish_sword", "fish_axolotl", "fish_yellow",
        "fish_betta", "fish_angler", "fish_ghost", "fish_lion", "fish_sunfish"]
ORDER += FISH

# iscas: desenhadas aqui mesmo (provisórias), até chegar arte própria
BAITS = ["bait_worm", "bait_corn", "bait_cricket", "bait_mushroom", "bait_fly"]
ORDER += BAITS


def draw_bait(name):
    from PIL import ImageDraw
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if name == "bait_worm":
        pts = [(5, 22), (9, 18), (13, 21), (17, 17), (21, 20), (25, 15), (27, 11)]
        d.line(pts, fill=(196, 112, 108, 255), width=5, joint="curve")
        d.line(pts, fill=(226, 150, 140, 255), width=2, joint="curve")
        for x, y in pts[1:-1]:
            d.point((x, y + 2), fill=(150, 80, 78, 255))
        d.point((27, 10), fill=(43, 33, 24, 255))
    elif name == "bait_corn":
        d.ellipse((7, 7, 25, 25), fill=(226, 178, 70, 255))
        d.ellipse((9, 8, 19, 16), fill=(244, 210, 120, 255))
        for x, y in ((12, 18), (17, 13), (20, 19), (14, 22), (21, 11), (10, 13)):
            d.rectangle((x, y, x + 1, y + 1), fill=(190, 136, 48, 255))
    elif name == "bait_cricket":
        d.ellipse((7, 12, 23, 22), fill=(110, 128, 66, 255))
        d.ellipse((20, 11, 27, 18), fill=(90, 106, 52, 255))
        d.ellipse((9, 12, 18, 16), fill=(150, 168, 96, 255))
        d.line((12, 21, 7, 27), fill=(78, 92, 44, 255), width=2)
        d.line((17, 21, 21, 27), fill=(78, 92, 44, 255), width=2)
        d.line((8, 16, 3, 10), fill=(78, 92, 44, 255), width=2)
        d.line((26, 12, 30, 6), fill=(78, 92, 44, 255), width=1)
        d.line((25, 12, 27, 5), fill=(78, 92, 44, 255), width=1)
        d.point((25, 14), fill=(20, 16, 12, 255))
    elif name == "bait_mushroom":
        for r, a in ((15, 40), (12, 70), (9, 110)):
            d.ellipse((16 - r, 14 - r, 16 + r, 14 + r), fill=(120, 230, 210, a))
        d.rectangle((13, 15, 19, 26), fill=(226, 236, 214, 255))
        d.pieslice((6, 5, 26, 25), 180, 360, fill=(70, 196, 190, 255))
        d.ellipse((10, 8, 14, 11), fill=(200, 255, 245, 255))
        d.ellipse((18, 10, 21, 13), fill=(200, 255, 245, 255))
    elif name == "bait_fly":
        d.arc((12, 14, 24, 28), 0, 200, fill=(176, 180, 186, 255), width=2)
        d.line((24, 21, 24, 6), fill=(176, 180, 186, 255), width=2)
        d.polygon([(24, 6), (10, 2), (14, 10)], fill=(200, 80, 60, 255))
        d.polygon([(24, 8), (8, 12), (16, 14)], fill=(120, 150, 80, 255))
        d.polygon([(24, 7), (14, 4), (20, 12)], fill=(242, 200, 107, 255))
        d.ellipse((21, 5, 27, 11), fill=(85, 57, 38, 255))
    # contorno escuro, como nos outros ícones
    out = img.copy()
    src, dst = img.load(), out.load()
    for y in range(32):
        for x in range(32):
            if src[x, y][3] >= 200:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < 32 and 0 <= ny < 32 and src[nx, ny][3] >= 200:
                    if src[x, y][3] == 0:
                        dst[x, y] = (43, 33, 24, 255)
                    break
    return out

# selinho no canto do saco de sementes: nome de um ícone HD, ou índice em icons.png (16x16)
SEED_BADGES = {"seed_kale": 10, "seed_carrot": "carrot", "seed_tomato": "tomato", "seed_starflower": 11}


def remove_white(im, black=False):
    """Apaga o fundo branco (ou preto, com black=True) ligado às bordas."""
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
        if black:
            if r + g + b > 18:   # o contorno (marrom bem escuro) fica
                continue
        elif min(r, g, b) < 228 or max(r, g, b) - min(r, g, b) > 25:
            continue
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                q.append((nx, ny))
    return im


def pieces(path, names, checker=False, white=False, rows=1, black=False):
    im = Image.open(path).convert("RGBA")
    if checker:
        im = remove_fake_checker(im)
    if white or black:
        im = remove_white(im, black=black)
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


def add_outline(cell, color=(43, 33, 24, 255)):
    out = cell.copy()
    src, dst = cell.load(), out.load()
    w, h = cell.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3]:
                    dst[x, y] = color
                    break
    return out


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
    icons.update(pieces(os.path.join(SRC, "animal_products.webp"), ANIMAL_PRODUCTS, white=True))
    icons.update(pieces(os.path.join(SRC, "truffle.webp"), ["truffle"], black=True))
    icons.update(pieces(os.path.join(SRC, "fish.webp"), FISH, black=True, rows=4))
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
        elif n in BAITS:
            cell = draw_bait(n)
        else:
            cell = fit(icons[n])
            if n in FISH:
                cell = add_outline(cell)   # os peixes vieram sem contorno; deixa igual aos outros ícones
        atlas.alpha_composite(cell, ((i % per_row) * CELL, (i // per_row) * CELL))
        print(f"{i}: {n}")
    atlas.save(OUT)
