#!/usr/bin/env python3
"""
Arte PROVISÓRIA dos objetos de fabricação e construção (assets/sprites/craft/).
Para trocar pela arte definitiva, substitua o PNG mantendo o nome; o tamanho pode
mudar (o jogo alinha a base da imagem com a base do objeto).

Uso: python3 tools/generate_craft_art.py
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw  # noqa: E402
from generate_placeholder_art import (  # noqa: E402
    hx, outline, ell, speckle, WOOD, WOOD_L, WOOD_D, CREAM, GREEN, GREEN_L, MOSS, MOSS_D, LEAF,
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "craft")
STONE, STONE_L, STONE_D = hx("8B8A7C"), hx("AAA898"), hx("6B6A5E")
RED, RED_D = hx("B5553A"), hx("8E3F2B")
SHADOW = (30, 20, 10, 70)


def canvas(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def finish(img, shadow=None):
    img = outline(img)
    if shadow:
        base = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(base).ellipse(shadow, fill=SHADOW)
        base.alpha_composite(img)
        img = base
    return img


def planks(d, x0, y0, x1, y1, vertical=False, step=6):
    d.rectangle((x0, y0, x1, y1), fill=WOOD_L)
    if vertical:
        for x in range(x0 + step, x1, step):
            d.line((x, y0, x, y1), fill=WOOD)
    else:
        for y in range(y0 + step, y1, step):
            d.line((x0, y, x1, y), fill=WOOD)


def moss(img, rng, box, n=40):
    speckle(img, rng, [MOSS, LEAF, GREEN_L], n, box=box)


def workbench():
    rng = random.Random(1)
    img, d = canvas(64, 48)
    d.rectangle((6, 22, 10, 44), fill=WOOD_D)
    d.rectangle((54, 22, 58, 44), fill=WOOD_D)
    d.rectangle((8, 34, 56, 37), fill=WOOD)
    planks(d, 2, 14, 62, 24, vertical=True, step=8)
    d.rectangle((2, 14, 62, 16), fill=hx("C99A6A"))
    # ferramentas e serrote em cima
    d.rectangle((10, 8, 24, 13), fill=STONE_L)
    d.line((10, 13, 24, 13), fill=STONE_D)
    d.rectangle((24, 9, 30, 12), fill=WOOD_D)
    d.line((36, 4, 44, 13), fill=WOOD_D, width=2)
    d.polygon([(42, 4), (48, 2), (47, 7)], fill=STONE)
    ell(d, 54, 11, 4, 3, hx("F2C86B"))
    moss(img, rng, (2, 14, 62, 26), 25)
    return finish(img, (4, 40, 60, 47))


def cheese_press():
    rng = random.Random(2)
    img, d = canvas(36, 44)
    planks(d, 4, 18, 32, 40, vertical=True, step=7)
    d.rectangle((4, 18, 32, 20), fill=WOOD)
    d.rectangle((16, 4, 20, 20), fill=WOOD_D)
    d.rectangle((6, 4, 30, 8), fill=WOOD)
    ell(d, 18, 26, 9, 4, CREAM)
    ell(d, 18, 25, 7, 2, hx("F4EBC8"))
    d.rectangle((2, 36, 34, 41), fill=STONE)
    moss(img, rng, (4, 30, 32, 41), 15)
    return finish(img, (2, 38, 34, 44))


def loom():
    rng = random.Random(3)
    img, d = canvas(44, 48)
    d.rectangle((4, 4, 8, 44), fill=WOOD_D)
    d.rectangle((36, 4, 40, 44), fill=WOOD_D)
    d.rectangle((4, 4, 40, 8), fill=WOOD)
    d.rectangle((4, 30, 40, 33), fill=WOOD)
    for x in range(11, 35, 3):
        d.line((x, 9, x, 29), fill=hx("E9DDBB"))
    d.rectangle((10, 14, 34, 24), fill=hx("C96F4A"))
    for y in range(15, 24, 3):
        d.line((10, y, 34, y), fill=hx("E3A06F"))
    d.rectangle((2, 40, 42, 44), fill=WOOD)
    moss(img, rng, (4, 36, 40, 44), 12)
    return finish(img, (2, 42, 42, 48))


def preserves_jar():
    img, d = canvas(32, 40)
    d.rectangle((6, 12, 26, 34), fill=hx("C9E3DA"))
    d.rectangle((8, 18, 24, 33), fill=hx("C8382E"))
    d.rectangle((8, 18, 24, 20), fill=hx("E05A4B"))
    d.rectangle((9, 13, 12, 30), fill=hx("F3FFFA"))
    d.rectangle((4, 8, 28, 12), fill=WOOD)
    d.rectangle((6, 6, 26, 8), fill=hx("D9C49A"))
    d.line((6, 8, 26, 8), fill=hx("BBA97F"))
    d.rectangle((12, 22, 20, 28), fill=CREAM)
    d.rectangle((2, 34, 30, 38), fill=WOOD_D)
    return finish(img, (2, 36, 30, 40))


def feeder():
    rng = random.Random(4)
    img, d = canvas(40, 30)
    d.polygon([(2, 8), (38, 8), (34, 26), (6, 26)], fill=WOOD_L)
    for x in range(8, 34, 6):
        d.line((x, 9, x - 1, 25), fill=WOOD)
    d.rectangle((2, 6, 38, 9), fill=WOOD)
    return finish(img, (2, 24, 38, 30))


def feeder_hay(img):
    rng = random.Random(5)
    d = ImageDraw.Draw(img)
    for _ in range(26):
        x = rng.randrange(6, 34)
        d.line((x, 8, x + rng.randrange(-3, 4), rng.randrange(1, 6)), fill=rng.choice([hx("E8C766"), hx("D6AE45"), hx("F2DA8A")]))
    return img


def scarecrow():
    img, d = canvas(36, 56)
    d.rectangle((16, 18, 19, 54), fill=WOOD_D)
    d.rectangle((3, 22, 33, 25), fill=WOOD)
    d.polygon([(9, 22), (27, 22), (29, 40), (7, 40)], fill=hx("6F8A4A"))
    for x in range(10, 28, 4):
        d.line((x, 23, x, 39), fill=MOSS_D)
    ell(d, 18, 14, 7, 7, hx("D9C49A"))
    d.point((15, 13), fill=hx("2B2118"))
    d.point((21, 13), fill=hx("2B2118"))
    ell(d, 18, 7, 13, 3, hx("A8784F"))
    ell(d, 18, 4, 7, 4, hx("C99A6A"))
    for x in (4, 31):
        d.line((x, 24, x - 2, 28), fill=hx("E8C766"))
    return finish(img, (8, 51, 28, 56))


def fence():
    img, d = canvas(34, 30)
    for x in (4, 26):
        d.rectangle((x, 4, x + 4, 28), fill=WOOD)
        d.rectangle((x, 4, x + 4, 6), fill=WOOD_L)
    d.rectangle((0, 10, 34, 13), fill=WOOD_L)
    d.rectangle((0, 19, 34, 22), fill=WOOD_L)
    d.line((0, 13, 34, 13), fill=WOOD)
    d.line((0, 22, 34, 22), fill=WOOD)
    return finish(img)


def stone_path():
    rng = random.Random(6)
    img, d = canvas(32, 32)
    for cx, cy, rx, ry in ((9, 9, 7, 6), (23, 8, 6, 5), (8, 23, 6, 6), (22, 22, 8, 7), (16, 15, 3, 3)):
        ell(d, cx, cy, rx, ry, STONE)
        ell(d, cx - 1, cy - 1, rx - 2, ry - 2, STONE_L)
    speckle(img, rng, [STONE_D], 25)
    return outline(img)


def building(w, h, roof, wall, door_w, seed):
    rng = random.Random(seed)
    img, d = canvas(w, h)
    roof_h = int(h * 0.45)
    # paredes de tábua
    planks(d, 6, roof_h - 4, w - 7, h - 4, vertical=True, step=7)
    d.rectangle((6, roof_h - 4, w - 7, roof_h), fill=WOOD)
    # porta dupla
    cx = w // 2
    d.rectangle((cx - door_w // 2, h - 4 - int(h * 0.32), cx + door_w // 2, h - 4), fill=wall)
    d.line((cx, h - 4 - int(h * 0.32), cx, h - 4), fill=WOOD_D)
    d.line((cx - door_w // 2, h - 4 - int(h * 0.32), cx + door_w // 2, h - 4), fill=WOOD_D)
    d.line((cx + door_w // 2, h - 4 - int(h * 0.32), cx - door_w // 2, h - 4), fill=WOOD_D)
    # telhado
    d.polygon([(0, roof_h), (w, roof_h), (w - 14, 4), (14, 4)], fill=roof)
    for y in range(8, roof_h, 6):
        d.line((14 - (y - 4) * 14 // (roof_h - 4), y, w - 14 + (y - 4) * 14 // (roof_h - 4), y), fill=tuple(max(0, c - 30) for c in roof[:3]) + (255,))
    moss(img, rng, (4, 4, w - 4, roof_h), w)
    d.rectangle((0, roof_h, w, roof_h + 3), fill=WOOD_D)
    # janelinha redonda
    ell(d, cx, roof_h // 2 + 4, 5, 5, WOOD_D)
    ell(d, cx, roof_h // 2 + 4, 3, 3, hx("F2C86B"))
    d.rectangle((2, h - 5, w - 3, h - 2), fill=STONE)
    return finish(img)


def icon_cheese():
    img, d = canvas(32, 32)
    d.polygon([(4, 14), (28, 8), (28, 24), (4, 26)], fill=hx("F2C86B"))
    d.polygon([(4, 14), (28, 8), (26, 6), (6, 11)], fill=hx("F8DD94"))
    for cx, cy, r in ((10, 19, 2), (18, 15, 2), (22, 20, 1), (14, 23, 1)):
        ell(d, cx, cy, r, r, hx("D9A83A"))
    return outline(img)


def icon_cloth():
    img, d = canvas(32, 32)
    for i, col in enumerate((hx("C96F4A"), hx("E3A06F"), hx("C96F4A"))):
        d.rectangle((4, 8 + i * 6, 28, 13 + i * 6), fill=col)
    d.line((4, 13, 28, 13), fill=hx("8E3F2B"))
    d.line((4, 19, 28, 19), fill=hx("8E3F2B"))
    for x in range(6, 28, 4):
        d.point((x, 10), fill=CREAM)
        d.point((x + 2, 22), fill=CREAM)
    return outline(img)


def icon_jam():
    img = preserves_jar().crop((0, 0, 32, 36)).resize((28, 32), Image.NEAREST)
    out, _ = canvas(32, 32)
    out.alpha_composite(img, (2, 0))
    return out


def icon_hay():
    rng = random.Random(7)
    img, d = canvas(32, 32)
    ell(d, 16, 18, 13, 10, hx("D6AE45"))
    for _ in range(40):
        x = rng.randrange(5, 27)
        y = rng.randrange(10, 26)
        d.line((x, y, x + rng.randrange(-4, 5), y + rng.randrange(-3, 3)), fill=rng.choice([hx("E8C766"), hx("F2DA8A"), hx("B8902E")]))
    d.rectangle((6, 16, 26, 19), fill=WOOD)
    return outline(img)


def icon_shears():
    img, d = canvas(32, 32)
    for a, b in (((6, 26), (22, 6)), ((10, 6), (26, 26))):
        d.line(a + b, fill=hx("A9AEB3"), width=3)
    d.line((8, 24, 20, 8), fill=hx("D6DADD"), width=1)
    ell(d, 8, 26, 4, 4, WOOD)
    ell(d, 24, 26, 4, 4, WOOD)
    ell(d, 8, 26, 2, 2, (0, 0, 0, 0))
    ell(d, 24, 26, 2, 2, (0, 0, 0, 0))
    ell(d, 16, 17, 2, 2, hx("6B6A5E"))
    return outline(img)


def fit_icon(img):
    w, h = img.size
    s = 30 / max(w, h)
    small = img.resize((max(1, round(w * s)), max(1, round(h * s))), Image.NEAREST)
    out, _ = canvas(32, 32)
    out.alpha_composite(small, ((32 - small.width) // 2, (32 - small.height) // 2))
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sprites = {
        "workbench": workbench(),
        "cheese_press": cheese_press(),
        "loom": loom(),
        "preserves_jar": preserves_jar(),
        "feeder": feeder(),
        "feeder_full": feeder_hay(feeder()),
        "scarecrow": scarecrow(),
        "fence": fence(),
        "stone_path": stone_path(),
        "barn": building(128, 112, hx("8E3F2B"), RED_D, 30, 8),
        "coop": building(88, 72, hx("6F8A4A"), WOOD, 18, 9),
    }
    for name, img in sprites.items():
        img.save(os.path.join(OUT, name + ".png"))
        if name != "feeder_full":
            fit_icon(img).save(os.path.join(OUT, "icon_" + name + ".png"))
    for name, img in {"cheese": icon_cheese(), "cloth": icon_cloth(), "jam": icon_jam(), "hay": icon_hay(), "shears": icon_shears()}.items():
        img.save(os.path.join(OUT, "icon_" + name + ".png"))
    print("arte de fabricação gerada em", OUT)
