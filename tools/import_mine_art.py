#!/usr/bin/env python3
"""
Importa a arte da Mina de assets/source/mine_art.webp (fundo transparente) para assets/sprites/mine/
(substitui a arte provisória de tools/generate_mine_art.py, com os mesmos nomes de arquivo).

Cada peça é achada pelo centro aproximado na folha (1500x1000). Se trocar a folha por outra com o
mesmo arranjo, é só rodar de novo: python3 tools/import_mine_art.py
"""
import colorsys
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from import_animals import components  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "mine_art.webp")
OUT = os.path.join(ROOT, "assets", "sprites", "mine")
ITEMS = os.path.join(OUT, "items")
CRAFT = os.path.join(ROOT, "assets", "sprites", "craft")

# nome -> centro aproximado da peça na folha
PIECES = {
    "entrance_a": (122, 107), "entrance": (346, 105), "entrance_c": (563, 105), "entrance_d": (786, 106),
    "ore_copper": (989, 101), "ore_iron": (1131, 101), "gem_ruby": (1276, 101), "gem_amethyst": (1419, 100),
    "ore_crystal_small": (991, 237), "gem_emerald": (1136, 237), "gem_moon": (1281, 236), "ore_topaz": (1425, 237),
    "furnace_tall": (871, 323),
    "chest_brown": (77, 338), "chest_brown_open": (219, 332), "chest_blue": (369, 333), "chest_blue_open": (506, 331),
    "furnace": (640, 339), "furnace_b": (754, 345),
    "crystal_purple": (1005, 373), "ore_crystal": (1149, 374), "crystal_green": (1284, 370), "crystal_white": (1423, 374),
    "chest_gold": (77, 504), "chest_gold_open": (209, 499), "chest_purple": (347, 508), "chest_purple_open": (482, 502),
    "gem_i_purple": (588, 514), "gem_i_blue": (660, 512), "gem_i_green": (732, 514), "gem_i_white": (803, 514),
    "gem_i_orange": (877, 514), "bars": (1036, 521),
    "ladder_up": (1213, 539), "ladder_moss": (1320, 537), "ladder_down": (1434, 537),
}
THEMES = ["brown", "dark", "blue", "sand", "purple", "teal", "moss", "lava"]
FLOOR_X = [106, 292, 479, 660, 841, 1028, 1215, 1401]
FLOOR_Y, WALL_Y = 719, 891


def pieces(im):
    comps = components(im)
    big = max(c["area"] for c in comps)
    main = [c for c in comps if c["area"] >= big * 0.05]
    small = [c for c in comps if 30 <= c["area"] < big * 0.05]
    for s in small:
        sx, sy = (s["bbox"][0] + s["bbox"][2]) / 2, (s["bbox"][1] + s["bbox"][3]) / 2

        def dist(c):
            b = c["bbox"]
            return max(b[0] - sx, 0, sx - b[2]) ** 2 + max(b[1] - sy, 0, sy - b[3]) ** 2
        m = min(main, key=dist)
        if dist(m) < 40 ** 2:
            m["pts"] += s["pts"]
            b = m["bbox"]
            m["bbox"] = [min(b[0], s["bbox"][0]), min(b[1], s["bbox"][1]), max(b[2], s["bbox"][2]), max(b[3], s["bbox"][3])]
    return main


def find(comps, center):
    cx, cy = center
    best = min(comps, key=lambda c: ((c["bbox"][0] + c["bbox"][2]) / 2 - cx) ** 2 + ((c["bbox"][1] + c["bbox"][3]) / 2 - cy) ** 2)
    return best


def crop(im, c):
    x0, y0, x1, y1 = c["bbox"]
    out = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    src, dst = im.load(), out.load()
    for x, y in c["pts"]:
        dst[x - x0, y - y0] = src[x, y]
    return out


def fit(img, w=None, h=None):
    s = min((w / img.width) if w else 99, (h / img.height) if h else 99)
    nw, nh = max(1, round(img.width * s)), max(1, round(img.height * s))
    small = img.resize((nw, nh), Image.LANCZOS)
    px = small.load()
    for y in range(nh):
        for x in range(nw):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 120 else (0, 0, 0, 0)
    return small


def icon(img):
    """32x32 com a peça centralizada (até 30 px)."""
    small = fit(img, 30, 30)
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    out.alpha_composite(small, ((32 - small.width) // 2, (32 - small.height) // 2))
    return out


def dark_mouth(img):
    """Troca o fogo pintado na boca da fornalha por um interior escuro (mais claro embaixo, brasas apagadas)."""
    out = img.copy()
    px = out.load()
    pts = []
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s > 0.45 and v > 0.45 and (h < 0.17 or h > 0.95) and y > out.height * 0.45:
                pts.append((x, y))
    if not pts:
        return out
    # dentro da área da boca, também os vermelhos escuros (brasa da borda)
    bx0, bx1 = min(p[0] for p in pts) - 1, max(p[0] for p in pts) + 1
    by0, by1 = min(p[1] for p in pts) - 2, max(p[1] for p in pts) + 1
    for y in range(max(0, by0), min(out.height, by1 + 1)):
        for x in range(max(0, bx0), min(out.width, bx1 + 1)):
            r, g, b, a = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            ember = s > 0.35 and v > 0.18 and (h < 0.12 or h > 0.93)
            spark = s > 0.2 and v > 0.6 and h < 0.2          # faísca amarela
            if a and (ember or spark) and (x, y) not in pts:
                pts.append((x, y))
    y0 = min(p[1] for p in pts)
    y1 = max(p[1] for p in pts)
    for x, y in pts:
        t = (y - y0) / max(1, y1 - y0)
        px[x, y] = (int(26 + 22 * t), int(18 + 12 * t), int(14 + 8 * t), 255)
    return out


def hue_shift(img, target, sat=1.0):
    out = img.copy()
    px = out.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s < 0.15:
                continue
            r2, g2, b2 = colorsys.hsv_to_rgb(target, min(1.0, s * sat), v)
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return out


def tint_gray(img, target, sat):
    """Pinta uma peça cinza/branca (barra de prata) com uma cor."""
    out = img.copy()
    px = out.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            _, _, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            r2, g2, b2 = colorsys.hsv_to_rgb(target, sat, v * 0.95)
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return out


if __name__ == "__main__":
    os.makedirs(ITEMS, exist_ok=True)
    im = Image.open(SRC).convert("RGBA")
    comps = pieces(im)
    p = {n: crop(im, find(comps, c)) for n, c in PIECES.items()}

    # objetos no mapa (a base fica embaixo; o jogo alinha pela base)
    fit(p["entrance"], 100).save(os.path.join(OUT, "entrance.png"))
    for n in ["ore_copper", "ore_iron", "gem_ruby", "gem_amethyst", "gem_emerald", "gem_moon"]:
        fit(p[n], 34).save(os.path.join(OUT, n + ".png"))
    fit(p["ore_crystal"], 30, 34).save(os.path.join(OUT, "ore_crystal.png"))
    for n in ["crystal_purple", "crystal_green", "crystal_white"]:
        fit(p[n], 30, 34).save(os.path.join(OUT, n + ".png"))
    for n in ["chest_brown", "chest_blue", "chest_gold", "chest_purple"]:
        fit(p[n], 28).save(os.path.join(OUT, n + ".png"))
        fit(p[n + "_open"], 28).save(os.path.join(OUT, n + "_open.png"))
    fit(p["chest_brown"], 28).save(os.path.join(OUT, "chest.png"))
    fit(p["ladder_up"], None, 34).save(os.path.join(OUT, "ladder_up.png"))
    fit(p["ladder_down"], None, 34).save(os.path.join(OUT, "ladder_down.png"))
    # chão e paredes: 8 temas (o chão é o miolo do quadrado, sem a borda arredondada)
    for i, t in enumerate(THEMES):
        fl = crop(im, find(comps, (FLOOR_X[i], FLOOR_Y)))
        m = int(min(fl.size) * 0.16)
        fl = fl.crop((m, m, fl.width - m, fl.height - m)).resize((32, 32), Image.LANCZOS).convert("RGBA")
        px = fl.load()
        for y in range(32):
            for x in range(32):
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 255)
        fl.save(os.path.join(OUT, "floor_%s.png" % t))
        wall = crop(im, find(comps, (FLOOR_X[i], WALL_Y)))
        fit(wall, 36).save(os.path.join(OUT, "wall_%s.png" % t))
        # pedra comum do tema: o mesmo bloco, menor
        fit(wall, 30).save(os.path.join(OUT, "rock_%s.png" % t))
    # fornalha
    f = dark_mouth(fit(p["furnace"], 34))     # sem o fogo pintado: o jogo anima o fogo quando ela trabalha
    f.save(os.path.join(CRAFT, "furnace.png"))
    icon(p["furnace"]).save(os.path.join(CRAFT, "icon_furnace.png"))
    # ícones de itens
    icon(p["gem_i_purple"]).save(os.path.join(ITEMS, "amethyst.png"))
    icon(p["gem_i_green"]).save(os.path.join(ITEMS, "emerald.png"))
    icon(p["gem_i_white"]).save(os.path.join(ITEMS, "moonstone.png"))
    icon(hue_shift(p["gem_i_orange"], 0.0, 1.1)).save(os.path.join(ITEMS, "ruby.png"))
    icon(p["gem_i_blue"]).save(os.path.join(ITEMS, "crystal.png"))
    bars = p["bars"]
    q = bars.width // 4
    white_bar = bars.crop((q * 3, 0, bars.width, bars.height))
    icon(white_bar).save(os.path.join(ITEMS, "iron_bar.png"))
    icon(tint_gray(white_bar, 0.07, 0.7)).save(os.path.join(ITEMS, "copper_bar.png"))
    icon(p["ore_copper"]).save(os.path.join(ITEMS, "copper_ore.png"))
    icon(p["ore_iron"]).save(os.path.join(ITEMS, "iron_ore.png"))
    print("arte da mina importada:", len(PIECES), "peças +", len(THEMES), "temas de chão/parede")
