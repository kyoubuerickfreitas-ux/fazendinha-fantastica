#!/usr/bin/env python3
"""
Arte PROVISÓRIA da pesca:
  assets/sprites/fishing/<id>.png      ícones 32x32 dos peixes lendários (recolorindo peixes do atlas HD),
                                      dos tesouros e da isca de tesouro
  assets/sprites/craft/trophy_<x>.png  troféus (objetos de decoração) + icon_trophy_<x>.png

Para trocar pela arte definitiva, substitua o PNG mantendo o nome.
Uso: python3 tools/generate_fishing_art.py   (depois de tools/import_icons.py)
"""
import colorsys
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw  # noqa: E402
from generate_placeholder_art import hx, outline, ell, WOOD, WOOD_L, WOOD_D, CREAM  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "fishing")
CRAFT = os.path.join(ROOT, "assets", "sprites", "craft")
GOLD, GOLD_L, GOLD_D = hx("F2C14E"), hx("F8DE8C"), hx("B8862E")

# lendário: (peixe base no atlas, matiz alvo 0..1 ou None, saturação, brilho, cor da aura)
LEGENDS = {
    "fish_moss_king": ("fish_perch", 0.27, 1.25, 1.05, hx("9FE07A")),
    "fish_silver_moon": ("fish_eel", 0.58, 0.35, 1.35, hx("DDE8FF")),
    "fish_winter_heart": ("fish_betta", 0.53, 1.1, 1.2, hx("A8E6FF")),
    "fish_guardian": ("fish_shark", 0.12, 3.0, 1.15, hx("F2C14E")),
    "fish_dream": ("fish_goldfish", 0.80, 1.2, 1.2, hx("E7A8FF")),
}


def atlas_cell(name):
    idx = json.load(open(os.path.join(ROOT, "data", "items_hd.json")))[name]
    atlas = Image.open(os.path.join(ROOT, "assets", "sprites", "items_hd.png")).convert("RGBA")
    return atlas.crop(((idx % 16) * 32, (idx // 16) * 32, (idx % 16) * 32 + 32, (idx // 16) * 32 + 32))


def recolor(img, hue, sat, val):
    out = img.copy()
    px = out.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0 or r + g + b < 120:   # contorno escuro fica
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if hue is not None:
                h = (hue + (h - 0.08) * 0.25) % 1.0
            s = min(1.0, s * sat)
            v = min(1.0, v * val)
            r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v)
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return out


def aura(img, color):
    """Brilho em volta (2px) e umas estrelinhas: marca de peixe lendário."""
    base = Image.new("RGBA", img.size, (0, 0, 0, 0))
    src, dst = img.load(), base.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            for r, a in ((1, 170), (2, 80)):
                if any(0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy][3]
                       for dx, dy in ((r, 0), (-r, 0), (0, r), (0, -r))):
                    dst[x, y] = color[:3] + (a,)
                    break
    base.alpha_composite(img)
    d = ImageDraw.Draw(base)
    for sx, sy in ((3, 4), (27, 26), (28, 5)):
        d.point([(sx, sy), (sx - 1, sy), (sx + 1, sy), (sx, sy - 1), (sx, sy + 1)], fill=(255, 255, 240, 230))
    return base


def canvas():
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def treasure(kind):
    img, d = canvas()
    if kind in ("chest_small", "chest_gold"):
        body = WOOD_L if kind == "chest_small" else hx("8E3F2B")
        band = WOOD_D if kind == "chest_small" else GOLD
        d.rectangle((5, 15, 27, 27), fill=body)
        d.pieslice((5, 6, 27, 24), 180, 360, fill=body)
        d.rectangle((5, 14, 27, 16), fill=band)
        d.rectangle((9, 8, 11, 27), fill=band)
        d.rectangle((21, 8, 23, 27), fill=band)
        d.rectangle((14, 14, 18, 19), fill=GOLD)
        d.point((16, 17), fill=hx("2B2118"))
    elif kind == "old_coin":
        ell(d, 16, 16, 11, 11, GOLD_D)
        ell(d, 16, 15, 10, 10, GOLD)
        ell(d, 16, 15, 6, 6, GOLD_L)
        d.line((13, 12, 19, 18), fill=GOLD_D)
        d.line((19, 12, 13, 18), fill=GOLD_D)
    elif kind == "message_bottle":
        d.polygon([(6, 24), (20, 10), (25, 15), (11, 29)], fill=hx("9CC7B8"))
        d.polygon([(20, 10), (24, 6), (29, 11), (25, 15)], fill=hx("7FAF9F"))
        d.rectangle((25, 4, 28, 7), fill=WOOD)
        d.polygon([(10, 23), (18, 15), (21, 18), (13, 26)], fill=CREAM)
    elif kind == "map_piece":
        d.polygon([(5, 7), (26, 4), (28, 25), (20, 22), (9, 28)], fill=hx("E8D3A2"))
        d.line((9, 12, 15, 16, 21, 13), fill=hx("A8784F"))
        d.line((18, 19, 22, 23), fill=hx("C8382E"), width=2)
        d.line((22, 19, 18, 23), fill=hx("C8382E"), width=2)
    elif kind == "fungo_glasses":
        d.ellipse((4, 12, 14, 22), outline=hx("553926"), width=2, fill=hx("CDE7F0"))
        d.ellipse((18, 12, 28, 22), outline=hx("553926"), width=2, fill=hx("CDE7F0"))
        d.line((14, 16, 18, 16), fill=hx("553926"), width=2)
        d.point([(7, 14), (21, 14)], fill=(255, 255, 255, 255))
    elif kind == "relic_shell":
        d.pieslice((5, 6, 27, 30), 180, 360, fill=hx("F2C9B8"))
        d.rectangle((12, 18, 20, 24), fill=hx("E4A891"))
        for x in (9, 13, 16, 19, 23):
            d.line((16, 18, x, 8), fill=hx("D48F78"))
    elif kind == "relic_statue":
        d.rectangle((9, 24, 23, 28), fill=hx("6B6A5E"))
        d.rectangle((12, 12, 20, 24), fill=hx("78945B"))
        ell(d, 16, 9, 5, 5, hx("78945B"))
        d.point([(14, 8), (18, 8)], fill=hx("F2C14E"))
        d.rectangle((10, 15, 12, 20), fill=hx("4E6B3A"))
        d.rectangle((20, 15, 22, 20), fill=hx("4E6B3A"))
    elif kind == "relic_compass":
        ell(d, 16, 16, 12, 12, GOLD_D)
        ell(d, 16, 16, 10, 10, CREAM)
        d.polygon([(16, 7), (19, 16), (16, 25), (13, 16)], fill=hx("4C88A3"))
        d.polygon([(16, 7), (19, 16), (13, 16)], fill=hx("C8382E"))
        ell(d, 16, 16, 1, 1, GOLD_D)
    elif kind == "pearl":
        ell(d, 16, 17, 9, 9, hx("EDE6F2"))
        ell(d, 13, 14, 3, 3, (255, 255, 255, 255))
        d.arc((7, 8, 25, 26), 20, 120, fill=hx("C9BFD6"))
    elif kind == "old_boot":
        d.polygon([(9, 4), (19, 4), (19, 20), (28, 22), (28, 28), (9, 28)], fill=hx("6B5240"))
        d.rectangle((9, 25, 28, 28), fill=hx("3E2E22"))
        d.line((11, 8, 17, 8), fill=hx("8E6E52"))
        d.line((11, 12, 17, 12), fill=hx("8E6E52"))
        ell(d, 23, 9, 3, 2, hx("78945B"))
    elif kind == "driftwood":
        d.polygon([(3, 20), (24, 10), (29, 13), (8, 25)], fill=hx("A89880"))
        d.line((7, 21, 25, 12), fill=hx("D2C3A8"))
        d.line((18, 15, 22, 7), fill=hx("A89880"), width=2)
    elif kind == "bait_treasure":
        ell(d, 16, 18, 8, 8, GOLD)
        ell(d, 14, 16, 3, 3, GOLD_L)
        d.line((16, 10, 16, 3), fill=hx("B0B4BA"), width=2)
        d.arc((14, 24, 22, 31), 180, 360, fill=hx("B0B4BA"))
        for sx, sy in ((6, 9), (26, 10), (25, 26)):
            d.point([(sx, sy), (sx - 1, sy), (sx + 1, sy), (sx, sy - 1), (sx, sy + 1)], fill=(255, 250, 220, 255))
    return outline(img)


TREASURES = ["chest_small", "chest_gold", "old_coin", "message_bottle", "map_piece", "fungo_glasses",
             "relic_shell", "relic_statue", "relic_compass", "pearl", "old_boot", "driftwood", "bait_treasure"]


def trophy(fish_icon):
    """Placa de madeira com o peixe empalhado e uma plaquinha dourada (32x40)."""
    img = Image.new("RGBA", (36, 44), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((15, 30, 20, 41), fill=WOOD_D)          # pé
    d.rectangle((9, 39, 26, 42), fill=WOOD)
    d.rounded_rectangle((2, 3, 33, 31), radius=5, fill=WOOD)
    d.rounded_rectangle((4, 5, 31, 29), radius=4, fill=WOOD_L)
    d.rectangle((11, 25, 24, 28), fill=GOLD)
    fish = fish_icon.resize((26, 26), Image.NEAREST)
    img.alpha_composite(fish, (5, 2))
    return outline(img)


def cup():
    img = Image.new("RGBA", (30, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((6, 33, 23, 38), fill=WOOD)
    d.rectangle((12, 24, 17, 33), fill=GOLD_D)
    d.pieslice((4, -6, 25, 26), 0, 180, fill=GOLD)
    d.rectangle((4, 3, 25, 10), fill=GOLD)
    d.arc((0, 5, 9, 16), 90, 270, fill=GOLD_D, width=2)
    d.arc((20, 5, 29, 16), 270, 90, fill=GOLD_D, width=2)
    d.rectangle((8, 5, 10, 16), fill=GOLD_L)
    d.rectangle((10, 34, 19, 36), fill=GOLD_L)
    return outline(img)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for fid, (base, hue, sat, val, glow) in LEGENDS.items():
        icon = aura(recolor(atlas_cell(base), hue, sat, val), glow)
        icon.save(os.path.join(OUT, fid + ".png"))
        tr = trophy(recolor(atlas_cell(base), hue, sat, val))
        name = "trophy_" + fid.removeprefix("fish_")
        tr.save(os.path.join(CRAFT, name + ".png"))
        ic = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        small = tr.resize((26, 32), Image.NEAREST)
        ic.alpha_composite(small, (3, 0))
        ic.save(os.path.join(CRAFT, "icon_" + name + ".png"))
    c = cup()
    c.save(os.path.join(CRAFT, "trophy_tournament.png"))
    ic = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    ic.alpha_composite(c.resize((24, 32), Image.NEAREST), (4, 0))
    ic.save(os.path.join(CRAFT, "icon_trophy_tournament.png"))
    for t in TREASURES:
        treasure(t).save(os.path.join(OUT, t + ".png"))
    print("arte da pesca gerada em", OUT)
