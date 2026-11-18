#!/usr/bin/env python3
"""
Gera a arte PROVISÓRIA (placeholder) do jogo em pixel art, já no formato final.

Para trocar pela arte definitiva, basta substituir os PNGs em assets/sprites/
mantendo o MESMO tamanho de arquivo e a MESMA organização de quadros
(veja assets/sprites/LEIAME.md).

Uso:
    python3 tools/generate_placeholder_art.py
Requer: Pillow (pip install pillow)
"""
import os
import random
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites")
os.makedirs(OUT, exist_ok=True)


def hx(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


# ---------------------------------------------------------------- paleta
WOOD = hx("765137")
WOOD_L = hx("A8784F")
WOOD_D = hx("553926")
GREEN = hx("78945B")
GREEN_L = hx("B6C995")
CREAM = hx("E9DDBB")
EARTH = hx("776B52")
OUTLINE = hx("2B2118")

MOSS_D = hx("4C6A30")
MOSS = hx("5F8A3C")
MOSS_M = hx("6F8A4A")
LEAF = hx("86A85A")

SKIN = hx("4B423A")
SKIN_D = hx("3A322B")
EYE_W = hx("F4EFE0")
EYE_B = hx("15110D")
SHADOW = (30, 20, 10, 70)

TRANSPARENT = (0, 0, 0, 0)


def new(w, h):
    img = Image.new("RGBA", (w, h), TRANSPARENT)
    return img, ImageDraw.Draw(img)


def outline(img, color=OUTLINE):
    """Adiciona contorno de 1px em volta dos pixels opacos."""
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] >= 200:
                    dst[x, y] = color
                    break
    return out


def with_shadow(img, box):
    """Coloca uma sombra elíptica por baixo do sprite."""
    base, d = new(*img.size)
    d.ellipse(box, fill=SHADOW)
    base.alpha_composite(img)
    return base


def ell(d, cx, cy, rx, ry, fill):
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=fill)


def speckle(img, rng, colors, count, box=None, mask_alpha=True):
    w, h = img.size
    px = img.load()
    x0, y0, x1, y1 = box if box else (0, 0, w, h)
    for _ in range(count):
        x = rng.randrange(x0, x1)
        y = rng.randrange(y0, y1)
        if mask_alpha and px[x, y][3] == 0:
            continue
        px[x, y] = rng.choice(colors)


# ================================================================ CRIATURAS
def draw_eyes(d, cx, cy, look_dx=0, sleepy=False):
    for ex in (cx - 5 + look_dx, cx + 5 + look_dx):
        ell(d, ex, cy, 4, 4, EYE_W)
        ell(d, ex + (1 if look_dx > 0 else (-1 if look_dx < 0 else 0)), cy, 3, 3, EYE_B)
        if sleepy:
            d.rectangle((ex - 4, cy - 4, ex + 4, cy - 1), fill=SKIN)
        d.point((ex - 1, cy - 2), fill=EYE_W)


def draw_creature(direction, frame, style):
    """
    direction: 0 baixo, 1 esquerda, 2 direita, 3 cima
    style: 'player' (chapéu de folha) ou 'fungo' (chapéu de cogumelo)
    Quadro 64x64, pés em y=58.
    """
    img, d = new(64, 64)
    cx = 32
    bob = -1 if frame in (1, 3) else 0
    walk = [0, -2, 0, 2][frame]

    # pernas
    leg = WOOD_D if style == "player" else hx("6B4A2E")
    if direction in (0, 3):
        d.rectangle((cx - 6, 49, cx - 3, 57 + min(0, walk)), fill=leg)
        d.rectangle((cx + 3, 49, cx + 6, 57 - max(0, walk)), fill=leg)
        d.rectangle((cx - 7, 56 + min(0, walk), cx - 3, 57 + min(0, walk)), fill=SKIN_D)
        d.rectangle((cx + 3, 56 - max(0, walk), cx + 7, 57 - max(0, walk)), fill=SKIN_D)
    else:
        d.rectangle((cx - 4 + walk, 49, cx - 1 + walk, 57), fill=leg)
        d.rectangle((cx + 1 - walk, 49, cx + 4 - walk, 57), fill=leg)

    # corpo / capa
    if style == "player":
        cloak, cloak_d, mantle = hx("8A5A3A"), hx("6E4630"), MOSS_M
    else:
        cloak, cloak_d, mantle = hx("D9C9A0"), hx("BBA97F"), hx("C96F4A")
    d.polygon([(cx - 8, 36 + bob), (cx + 8, 36 + bob), (cx + 12, 52 + bob), (cx - 12, 52 + bob)], fill=cloak)
    for i in range(-8, 9, 4):
        d.line((cx + i, 40 + bob, cx + int(i * 1.4), 51 + bob), fill=cloak_d)
    # braços
    arm = [0, 1, 0, -1][frame]
    if direction != 3:
        ell(d, cx - 11, 44 + bob + arm, 3, 4, SKIN)
        ell(d, cx + 11, 44 + bob - arm, 3, 4, SKIN)
    # manto de folhas nos ombros
    ell(d, cx, 37 + bob, 12, 5, mantle)
    for i in range(-11, 12, 4):
        d.polygon([(cx + i - 2, 39 + bob), (cx + i + 2, 39 + bob), (cx + i, 43 + bob)], fill=mantle)

    # cabeça
    ell(d, cx, 28 + bob, 10, 10, SKIN)
    if direction == 0:
        draw_eyes(d, cx, 29 + bob)
        d.point((cx - 9, 33 + bob), fill=hx("7A4A3A"))
        d.point((cx + 9, 33 + bob), fill=hx("7A4A3A"))
    elif direction == 1:
        draw_eyes(d, cx - 2, 29 + bob, look_dx=-1)
    elif direction == 2:
        draw_eyes(d, cx + 2, 29 + bob, look_dx=1)

    # chapéu
    if style == "player":
        brim, brim_d, crown = MOSS_M, MOSS_D, hx("7D9A52")
        ell(d, cx, 20 + bob, 16, 5, brim_d)
        ell(d, cx, 19 + bob, 16, 4, brim)
        ell(d, cx, 14 + bob, 9, 7, crown)
        d.rectangle((cx - 9, 16 + bob, cx + 9, 18 + bob), fill=WOOD_L)
        # broto de folha
        d.polygon([(cx + 1, 8 + bob), (cx + 7, 2 + bob), (cx + 5, 8 + bob)], fill=LEAF)
        d.polygon([(cx - 1, 8 + bob), (cx - 6, 4 + bob), (cx - 2, 9 + bob)], fill=GREEN_L)
        d.point((cx - 5, 15 + bob), fill=GREEN_L)
        d.point((cx + 4, 13 + bob), fill=GREEN_L)
        if direction == 3:
            ell(d, cx, 30 + bob, 11, 9, mantle)  # capuz por trás
    else:
        cap, cap_d = hx("B5553A"), hx("8E3F2B")
        ell(d, cx, 17 + bob, 17, 10, cap_d)
        ell(d, cx, 15 + bob, 17, 9, cap)
        for sx, sy, r in ((-9, 13, 3), (2, 9, 3), (10, 15, 2), (-2, 17, 2), (7, 20, 1)):
            ell(d, cx + sx, sy + bob, r, r, CREAM)
        d.rectangle((cx - 13, 23 + bob, cx + 13, 24 + bob), fill=hx("E3CFA6"))

    img = outline(img)
    return with_shadow(img, (cx - 11, 54, cx + 11, 61))


def creature_sheet(style, name):
    sheet = Image.new("RGBA", (256, 256), TRANSPARENT)
    for row in range(4):
        for col in range(4):
            sheet.alpha_composite(draw_creature(row, col, style), (col * 64, row * 64))
    sheet.save(os.path.join(OUT, name))


def npc_sheet():
    sheet = Image.new("RGBA", (128, 64), TRANSPARENT)
    sheet.alpha_composite(draw_creature(0, 0, "fungo"), (0, 0))
    sheet.alpha_composite(draw_creature(0, 1, "fungo"), (64, 0))
    sheet.save(os.path.join(OUT, "npc_fungo.png"))


# ================================================================ TILES
# Paleta do chão tirada do tile de terreno do projeto idle (assets/source/terrain_ref.png)
G_BASE, G_D1, G_D2, G_D3 = hx("526A23"), hx("465C22"), hx("3F531F"), hx("2A3918")
G_H1, G_H2, G_H3, G_H4 = hx("5E7725"), hx("6E8727"), hx("89A22F"), hx("99B435")
D_BASE, D_L1, D_L2, D_D1, D_D2, D_PEB = hx("855728"), hx("93602D"), hx("A46C35"), hx("794F23"), hx("6A441D"), hx("C19865")


def grass_tuft(px, x, y, rng, big=False):
    """Tufo de grama: sombra escura embaixo, folhas claras em cima."""
    w = 4 if big else 3
    for dx in range(-1, w + 1):
        if 0 <= x + dx < 32 and y + 1 < 32:
            px[(x + dx) % 32, (y + 1) % 32] = G_D3 if dx in (-1, w) else G_D2
    for dx in range(w):
        px[(x + dx) % 32, y % 32] = G_H2
        px[(x + dx) % 32, (y - 1) % 32] = G_H1 if dx in (0, w - 1) else G_H3
    px[(x + 1) % 32, (y - 2) % 32] = G_H4 if big else G_H3


def tile_grass(seed, flowers=False, clover=False):
    rng = random.Random(seed)
    img, d = new(32, 32)
    d.rectangle((0, 0, 31, 31), fill=G_BASE)
    speckle(img, rng, [G_D1, G_D1, G_D2], 90)
    speckle(img, rng, [G_H1], 30)
    px = img.load()
    for _ in range(9 if not clover else 13):
        grass_tuft(px, rng.randrange(0, 32), rng.randrange(2, 31), rng, big=rng.random() < 0.4)
    if flowers:
        for _ in range(3):
            x, y = rng.randrange(3, 28), rng.randrange(3, 28)
            c = rng.choice([CREAM, hx("E8B4B8"), hx("F2D16B")])
            for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                px[x + dx, y + dy] = c
            px[x, y] = hx("E3A23B")
            px[x, y + 2] = G_D3
    return img


def tile_path(seed):
    rng = random.Random(seed)
    img, d = new(32, 32)
    d.rectangle((0, 0, 31, 31), fill=D_BASE)
    speckle(img, rng, [D_L1, D_D1], 160)
    speckle(img, rng, [D_L2], 25)
    px = img.load()
    for _ in range(8):
        x, y = rng.randrange(1, 31), rng.randrange(1, 30)
        px[x, y] = D_PEB
        px[x, y + 1] = D_D2
    return img


def tile_tilled(wet):
    img, d = new(32, 32)
    if wet:
        base, furrow, hi = hx("553820"), hx("3E2815"), hx("6A4626")
    else:
        base, furrow, hi = D_D1, D_D2, D_L1
    d.rectangle((0, 0, 31, 31), fill=base)
    for y in range(4, 32, 7):
        d.line((2, y, 29, y), fill=furrow)
        d.line((2, y + 1, 29, y + 1), fill=hi)
    d.rectangle((0, 0, 31, 31), outline=furrow)
    rng = random.Random(9 if wet else 8)
    speckle(img, rng, [furrow, hi], 30)
    if wet:
        speckle(img, rng, [hx("6B8FA0", 180)], 6)
    return img


def tile_water(seed, bank=False):
    rng = random.Random(seed)
    img, d = new(32, 32)
    d.rectangle((0, 0, 31, 31), fill=hx("4C88A3"))
    speckle(img, rng, [hx("3E7590")], 40)
    for _ in range(5):
        x, y = rng.randrange(2, 24), rng.randrange(8 if bank else 2, 30)
        d.line((x, y, x + rng.randrange(3, 7), y), fill=hx("7DB4C9"))
    if bank:
        d.rectangle((0, 0, 31, 3), fill=G_BASE)
        d.rectangle((0, 4, 31, 7), fill=D_D2)
        d.line((0, 8, 31, 8), fill=hx("3B6A82"))
        speckle(img, rng, [G_D2, G_H1], 14, box=(0, 0, 32, 4))
    return img


def tiles_sheet():
    tiles = [
        tile_grass(1),                    # 0 grama
        tile_grass(2, flowers=True),      # 1 grama com flores
        tile_grass(3, clover=True),       # 2 grama com trevos
        tile_path(4),                     # 3 caminho de terra
        tile_tilled(False),               # 4 terra arada
        tile_tilled(True),                # 5 terra arada molhada
        tile_water(5),                    # 6 água
        tile_water(6, bank=True),         # 7 água com margem (borda de cima)
    ]
    sheet = Image.new("RGBA", (32 * len(tiles), 32), TRANSPARENT)
    for i, t in enumerate(tiles):
        sheet.alpha_composite(t, (i * 32, 0))
    sheet.save(os.path.join(OUT, "tiles.png"))


# ================================================================ PLANTAÇÕES
def mound(d):
    ell(d, 16, 25, 8, 3, hx("5E3F26"))


def crop_stage(kind, stage):
    img, d = new(32, 32)
    if stage == 0:
        mound(d)
        for x in (12, 16, 20):
            d.point((x, 24), fill=CREAM)
        return outline(img)
    if stage == 1:
        mound(d)
        d.line((16, 25, 16, 19), fill=MOSS)
        ell(d, 13, 19, 3, 2, LEAF)
        ell(d, 19, 18, 3, 2, GREEN_L)
        return outline(img)

    if kind == "carrot":
        h = 12 if stage == 2 else 16
        for i, dx in enumerate((-5, -2, 1, 4)):
            d.line((16, 25, 16 + dx * 2, 25 - h + (i % 2) * 3), fill=LEAF, width=2)
            ell(d, 16 + dx * 2, 25 - h + (i % 2) * 3, 2, 2, MOSS)
        if stage == 3:
            d.polygon([(11, 23), (21, 23), (16, 30)], fill=hx("E07B2C"))
            d.line((13, 25, 18, 25), fill=hx("B85E1E"))
            d.point((14, 24), fill=hx("F5A65C"))
    elif kind == "tomato":
        h = 14 if stage == 2 else 20
        d.line((16, 28, 16, 28 - h), fill=hx("4E7A2E"), width=2)
        ell(d, 16, 28 - h // 2 - 2, 8, h // 2 + 1, MOSS)
        ell(d, 14, 28 - h // 2 - 4, 4, 4, LEAF)
        if stage == 3:
            for x, y in ((11, 15), (19, 13), (15, 20), (21, 20)):
                ell(d, x, y, 3, 3, hx("C8382E"))
                d.point((x - 1, y - 1), fill=hx("F07A6A"))
    elif kind == "kale":
        r = 6 if stage == 2 else 9
        ell(d, 16, 26 - r, r + 2, r, MOSS_D)
        ell(d, 16, 25 - r, r, r - 1, MOSS)
        ell(d, 15, 24 - r, r - 3, r - 3, LEAF)
        if stage == 3:
            ell(d, 15, 23 - r, 3, 2, GREEN_L)
            for x in (8, 24):
                d.polygon([(x, 22), (16, 20), (16, 26)], fill=MOSS_D)
    elif kind == "starflower":
        h = 12 if stage == 2 else 18
        d.line((16, 28, 16, 28 - h), fill=MOSS, width=1)
        d.line((16, 24, 11, 18), fill=MOSS)
        d.line((16, 22, 21, 16), fill=MOSS)
        ell(d, 13, 23, 3, 1, LEAF)
        ell(d, 19, 21, 3, 1, LEAF)
        if stage == 3:
            for x, y in ((16, 28 - h), (11, 17), (21, 15)):
                for dx, dy in ((0, -3), (-3, 0), (3, 0), (0, 3), (-2, -2), (2, -2), (-2, 2), (2, 2)):
                    d.point((x + dx, y + dy), fill=hx("F6E7A8"))
                ell(d, x, y, 2, 2, hx("F2D16B"))
                d.point((x, y), fill=hx("FFF8D8"))
        else:
            ell(d, 16, 28 - h, 2, 2, GREEN_L)
    mound(d)
    return outline(img)


def crops_sheet():
    kinds = ["carrot", "tomato", "kale", "starflower"]
    sheet = Image.new("RGBA", (128, 32 * len(kinds)), TRANSPARENT)
    for row, k in enumerate(kinds):
        for st in range(4):
            sheet.alpha_composite(crop_stage(k, st), (st * 32, row * 32))
    sheet.save(os.path.join(OUT, "crops.png"))


# ================================================================ OBJETOS
def tree(seed, dark=False):
    rng = random.Random(seed)
    img, d = new(64, 96)
    trunk, trunk_d = WOOD, WOOD_D
    d.polygon([(26, 92), (38, 92), (36, 60), (28, 60)], fill=trunk)
    d.polygon([(22, 93), (26, 88), (28, 93)], fill=trunk)
    d.polygon([(42, 93), (38, 88), (36, 93)], fill=trunk)
    d.line((31, 64, 31, 90), fill=trunk_d)
    d.line((34, 70, 34, 86), fill=trunk_d)
    base = hx("3F5C2A") if dark else MOSS_D
    mid = hx("527A33") if dark else MOSS
    hi = hx("6E9447") if dark else LEAF
    ell(d, 32, 40, 27, 28, base)
    for cx, cy, r in ((20, 44, 13), (44, 44, 13), (32, 26, 15), (22, 30, 10), (42, 30, 10), (32, 50, 14)):
        ell(d, cx, cy, r, r - 2, mid)
    for cx, cy, r in ((26, 22, 7), (38, 20, 6), (18, 36, 5), (30, 38, 5)):
        ell(d, cx, cy, r, r - 1, hi)
    speckle(img, rng, [GREEN_L, hi], 25, box=(10, 12, 54, 60))
    if not dark:
        for _ in range(3):
            x, y = rng.randrange(14, 50), rng.randrange(20, 56)
            ell(d, x, y, 1, 1, hx("C8382E"))
    img = outline(img)
    return with_shadow(img, (12, 86, 52, 95))


def stump():
    img, d = new(32, 32)
    d.rectangle((9, 16, 23, 26), fill=WOOD)
    ell(d, 16, 26, 7, 3, WOOD)
    ell(d, 16, 16, 7, 3, WOOD_L)
    ell(d, 16, 16, 4, 1, hx("C99A6A"))
    d.line((12, 19, 12, 26), fill=WOOD_D)
    d.line((19, 19, 19, 27), fill=WOOD_D)
    d.point((10, 22), fill=GREEN_L)
    d.point((21, 18), fill=LEAF)
    img = outline(img)
    return with_shadow(img, (6, 24, 26, 31))


def rock():
    img, d = new(32, 32)
    d.polygon([(6, 26), (8, 16), (14, 10), (22, 11), (27, 18), (26, 26)], fill=hx("8B8A7C"))
    d.polygon([(10, 16), (14, 12), (21, 13), (18, 18)], fill=hx("AAA898"))
    d.polygon([(6, 26), (26, 26), (24, 22), (9, 23)], fill=hx("6B6A5E"))
    ell(d, 21, 13, 4, 2, MOSS)
    d.point((19, 12), fill=LEAF)
    d.line((15, 19, 18, 22), fill=hx("6B6A5E"))
    img = outline(img)
    return with_shadow(img, (5, 24, 28, 31))


def weed(seed):
    rng = random.Random(seed)
    img, d = new(32, 32)
    for _ in range(7):
        x = rng.randrange(8, 24)
        top = rng.randrange(10, 18)
        c = rng.choice([MOSS, LEAF, MOSS_D])
        d.line((x, 27, x + rng.randrange(-4, 5), top), fill=c, width=2)
    ell(d, 16, 27, 7, 2, MOSS_D)
    return outline(img)


def shipping_bin():
    img, d = new(32, 32)
    d.rectangle((5, 12, 26, 28), fill=WOOD_L)
    for y in (16, 21, 26):
        d.line((5, y, 26, y), fill=WOOD)
    d.rectangle((4, 9, 27, 12), fill=WOOD)
    d.line((5, 10, 26, 10), fill=WOOD_L)
    ell(d, 15, 20, 4, 3, CREAM)
    d.polygon([(13, 21), (16, 17), (18, 21)], fill=GREEN)
    img = outline(img)
    return with_shadow(img, (3, 26, 29, 31))


def house():
    rng = random.Random(42)
    img, d = new(160, 144)
    # paredes
    d.rectangle((22, 66, 138, 136), fill=CREAM)
    speckle(img, rng, [hx("DCCCA4")], 120, box=(22, 66, 139, 137))
    for x in (22, 60, 100, 136):
        d.rectangle((x, 66, x + 2, 136), fill=WOOD)
    d.rectangle((22, 92, 138, 94), fill=WOOD)
    d.rectangle((20, 132, 140, 137), fill=hx("8B8A7C"))
    # telhado de musgo
    d.polygon([(4, 72), (156, 72), (128, 14), (32, 14)], fill=hx("5E6F3C"))
    for y in range(20, 72, 7):
        x0 = 32 - (y - 14) * 28 // 58
        x1 = 128 + (y - 14) * 28 // 58
        d.line((x0, y, x1, y), fill=hx("4E5C31"))
    speckle(img, rng, [MOSS, LEAF, GREEN_L], 260, box=(6, 14, 154, 72))
    for _ in range(14):
        x, y = rng.randrange(10, 150), rng.randrange(18, 70)
        if img.getpixel((x, y))[3]:
            ell(d, x, y, 3, 2, MOSS)
    d.rectangle((4, 70, 156, 74), fill=WOOD_D)
    # frontão com janela redonda
    d.polygon([(52, 72), (108, 72), (80, 34)], fill=CREAM)
    d.line((52, 72, 80, 34), fill=WOOD, width=3)
    d.line((108, 72, 80, 34), fill=WOOD, width=3)
    ell(d, 80, 58, 8, 8, WOOD)
    ell(d, 80, 58, 6, 6, hx("F2C86B"))
    d.line((74, 58, 86, 58), fill=WOOD)
    d.line((80, 52, 80, 64), fill=WOOD)
    # chaminé
    d.rectangle((112, 8, 124, 30), fill=hx("8B8A7C"))
    d.rectangle((110, 6, 126, 10), fill=hx("6B6A5E"))
    # porta arredondada
    d.rectangle((68, 108, 92, 134), fill=WOOD)
    ell(d, 80, 108, 12, 10, WOOD)
    for x in (74, 80, 86):
        d.line((x, 100, x, 134), fill=WOOD_D)
    d.point((88, 120), fill=hx("F2C86B"))
    # janelas acesas
    for wx in (34, 112):
        d.rectangle((wx - 1, 99, wx + 15, 117), fill=WOOD)
        d.rectangle((wx + 1, 101, wx + 13, 115), fill=hx("F2C86B"))
        d.line((wx + 7, 101, wx + 7, 115), fill=WOOD)
        d.line((wx + 1, 108, wx + 13, 108), fill=WOOD)
        d.rectangle((wx - 2, 117, wx + 16, 120), fill=WOOD_L)
        for fx in range(wx, wx + 15, 4):
            ell(d, fx, 116, 2, 2, rng.choice([LEAF, hx("E8B4B8"), CREAM]))
    # lanterna
    d.rectangle((96, 102, 100, 108), fill=hx("F2C86B"))
    d.rectangle((95, 100, 101, 101), fill=WOOD_D)
    # degraus
    d.rectangle((64, 135, 96, 139), fill=WOOD_L)
    d.rectangle((66, 139, 94, 142), fill=WOOD)
    img = outline(img)
    return img


def save(img, name):
    img.save(os.path.join(OUT, name))


# ================================================================ ÍCONES 16x16
def icon_canvas():
    return new(16, 16)


def ic_watering_can():
    img, d = icon_canvas()
    ell(d, 7, 10, 5, 4, hx("5E8F86"))
    d.rectangle((3, 7, 11, 10), fill=hx("6FA59B"))
    d.line((11, 9, 15, 5), fill=hx("5E8F86"), width=2)
    d.arc((3, 2, 10, 9), 180, 360, fill=WOOD_D, width=1)
    d.point((5, 9), fill=GREEN_L)
    return outline(img)


def tool_icon(head):
    img, d = icon_canvas()
    d.line((3, 14, 11, 4), fill=WOOD_L, width=2)
    if head == "hoe":
        d.rectangle((9, 2, 14, 3), fill=hx("A9AEB3"))
        d.rectangle((13, 2, 14, 8), fill=hx("A9AEB3"))
        d.point((14, 8), fill=hx("D6DADD"))
    elif head == "axe":
        d.polygon([(9, 2), (14, 3), (14, 9), (10, 6)], fill=hx("A9AEB3"))
        d.line((14, 3, 14, 9), fill=hx("D6DADD"))
    elif head == "pickaxe":
        d.arc((4, 1, 16, 11), 200, 340, fill=hx("A9AEB3"), width=2)
    elif head == "scythe":
        d.arc((2, 0, 14, 10), 180, 300, fill=hx("A9AEB3"), width=2)
        d.line((3, 14, 9, 2), fill=WOOD_L, width=2)
    return outline(img)


def ic_simple(kind):
    img, d = icon_canvas()
    if kind == "wood":
        d.rectangle((2, 6, 13, 11), fill=WOOD)
        ell(d, 13, 8, 2, 3, WOOD_L)
        d.point((13, 8), fill=WOOD_D)
        d.line((3, 8, 10, 8), fill=WOOD_D)
    elif kind == "stone":
        d.polygon([(2, 12), (4, 6), (9, 3), (13, 6), (14, 12)], fill=hx("8B8A7C"))
        d.polygon([(5, 6), (9, 4), (11, 7)], fill=hx("AAA898"))
    elif kind == "fiber":
        for x in (5, 7, 9, 11):
            d.line((8, 14, x, 2), fill=LEAF)
        d.rectangle((6, 9, 10, 10), fill=WOOD_L)
    elif kind == "carrot":
        d.polygon([(4, 6), (10, 4), (13, 14)], fill=hx("E07B2C"))
        d.line((7, 4, 4, 1), fill=LEAF, width=2)
        d.line((8, 4, 10, 0), fill=MOSS, width=2)
    elif kind == "tomato":
        ell(d, 8, 9, 6, 5, hx("C8382E"))
        d.point((5, 7), fill=hx("F07A6A"))
        d.polygon([(6, 4), (10, 4), (8, 6)], fill=MOSS)
    elif kind == "kale":
        ell(d, 8, 9, 6, 5, MOSS)
        ell(d, 7, 8, 3, 3, LEAF)
        d.point((6, 7), fill=GREEN_L)
    elif kind == "starflower":
        for dx, dy in ((0, -5), (-5, 0), (5, 0), (0, 5), (-3, -3), (3, -3), (-3, 3), (3, 3)):
            d.line((8, 8, 8 + dx, 8 + dy), fill=hx("F6E7A8"))
        ell(d, 8, 8, 2, 2, hx("F2D16B"))
    elif kind == "coin":
        ell(d, 8, 8, 6, 6, hx("D9A83A"))
        ell(d, 8, 8, 4, 4, hx("F2C86B"))
        d.line((8, 6, 8, 10), fill=hx("B5852A"))
    elif kind == "sun":
        for dx, dy in ((0, -7), (-7, 0), (7, 0), (0, 7), (-5, -5), (5, -5), (-5, 5), (5, 5)):
            d.line((8, 8, 8 + dx, 8 + dy), fill=hx("F2B33B"))
        ell(d, 8, 8, 4, 4, hx("F2D16B"))
    elif kind == "rain":
        ell(d, 6, 6, 4, 3, hx("C8D3DA"))
        ell(d, 10, 5, 4, 4, hx("DDE5EA"))
        d.rectangle((3, 6, 13, 8), fill=hx("C8D3DA"))
        for x in (4, 8, 12):
            d.line((x, 11, x - 1, 14), fill=hx("4C88A3"))
    elif kind == "cloud":
        ell(d, 6, 9, 4, 3, hx("C8D3DA"))
        ell(d, 10, 7, 5, 4, hx("DDE5EA"))
        d.rectangle((3, 9, 14, 11), fill=hx("C8D3DA"))
    elif kind == "moon":
        ell(d, 8, 8, 6, 6, hx("F1E7C2"))
        ell(d, 11, 6, 5, 5, TRANSPARENT)
    elif kind == "heart":
        ell(d, 5, 6, 3, 3, hx("C8503C"))
        ell(d, 11, 6, 3, 3, hx("C8503C"))
        d.polygon([(2, 7), (14, 7), (8, 14)], fill=hx("C8503C"))
        d.point((4, 5), fill=hx("F08A78"))
    elif kind == "bolt":
        d.polygon([(9, 1), (3, 9), (8, 9), (6, 15), (13, 6), (8, 6)], fill=hx("9CC46B"))
    elif kind == "backpack":
        d.rectangle((3, 4, 12, 14), fill=WOOD)
        d.rectangle((4, 9, 11, 13), fill=WOOD_L)
        d.arc((5, 1, 10, 7), 180, 360, fill=WOOD_D)
        d.point((7, 10), fill=hx("F2C86B"))
    elif kind == "hand":
        d.rounded_rectangle((3, 7, 11, 14), radius=2, fill=CREAM)
        for x, top in ((3, 4), (5, 2), (7, 2), (9, 3)):
            d.rectangle((x, top, x + 1, 8), fill=CREAM)
        for x in (5, 7, 9):
            d.line((x, 4, x, 8), fill=hx("C9B98F"))
        d.polygon([(11, 10), (14, 6), (15, 7), (12, 12)], fill=CREAM)
        d.line((4, 12, 10, 12), fill=hx("C9B98F"))
    elif kind == "bubble":
        d.rounded_rectangle((1, 3, 14, 11), radius=3, fill=hx("FAF6EA"))
        d.polygon([(4, 11), (7, 11), (3, 14)], fill=hx("FAF6EA"))
        for x in (4, 7, 10):
            d.point((x, 7), fill=OUTLINE)
            d.point((x + 1, 7), fill=OUTLINE)
    return outline(img)


def seed_bag(color):
    img, d = icon_canvas()
    d.polygon([(4, 5), (12, 5), (13, 14), (3, 14)], fill=hx("D9C49A"))
    d.rectangle((5, 3, 11, 5), fill=hx("BBA97F"))
    ell(d, 8, 10, 3, 3, color)
    d.point((7, 9), fill=CREAM)
    return outline(img)


def icons_sheet():
    icons = [
        ic_watering_can(),              # 0
        tool_icon("hoe"),               # 1
        tool_icon("axe"),               # 2
        tool_icon("pickaxe"),           # 3
        tool_icon("scythe"),            # 4
        ic_simple("wood"),              # 5
        ic_simple("stone"),             # 6
        ic_simple("fiber"),             # 7
        ic_simple("carrot"),            # 8
        ic_simple("tomato"),            # 9
        ic_simple("kale"),              # 10
        ic_simple("starflower"),        # 11
        seed_bag(hx("E07B2C")),         # 12 sementes cenoura
        seed_bag(hx("C8382E")),         # 13 sementes tomate
        seed_bag(MOSS),                 # 14 sementes couve
        seed_bag(hx("F2D16B")),         # 15 sementes flor-estrela
        ic_simple("coin"),              # 16
        ic_simple("sun"),               # 17
        ic_simple("rain"),              # 18
        ic_simple("heart"),             # 19
        ic_simple("bolt"),              # 20
        ic_simple("backpack"),          # 21
        ic_simple("hand"),              # 22
        ic_simple("bubble"),            # 23
        ic_simple("moon"),              # 24
        ic_simple("cloud"),             # 25
    ]
    cols = 16
    rows = (len(icons) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * 16, rows * 16), TRANSPARENT)
    for i, ic in enumerate(icons):
        sheet.alpha_composite(ic, ((i % cols) * 16, (i // cols) * 16))
    sheet.save(os.path.join(OUT, "icons.png"))


def app_icon():
    img = Image.new("RGBA", (256, 256), TRANSPARENT)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, 255, 255), radius=48, fill=GREEN)
    d.rounded_rectangle((12, 12, 243, 243), radius=40, fill=G_BASE)
    face = draw_creature(0, 0, "player").crop((8, 0, 56, 48)).resize((192, 192), Image.NEAREST)
    img.alpha_composite(face, (32, 44))
    img.save(os.path.join(ROOT, "icon.png"))


if __name__ == "__main__":
    creature_sheet("player", "player.png")
    npc_sheet()
    tiles_sheet()
    crops_sheet()
    save(stump(), "stump.png")
    save(house(), "house.png")
    icons_sheet()
    app_icon()
    print("Arte provisória gerada em", OUT)
