#!/usr/bin/env python3
"""
Arte PROVISÓRIA da Mina (assets/sprites/mine/):
  tiles.png            chão (3 variações), parede, frente da parede — 32x32 cada, em linha
  rock_a/b, ore_copper, ore_iron, ore_crystal, gem_rock   rochas para quebrar com a picareta
  ladder_down, ladder_up, chest, entrance                   escadas, baú e a entrada (no mapa da fazenda)
  items/<id>.png       ícones 32x32: minérios, barras, cristal e gemas
  ../craft/furnace.png + icon_furnace.png                   a Fornalha

Para trocar pela arte definitiva, substitua o PNG mantendo o nome.
Uso: python3 tools/generate_mine_art.py
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw  # noqa: E402
from generate_placeholder_art import hx, outline, ell, WOOD, WOOD_L, WOOD_D  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "mine")
ITEMS = os.path.join(OUT, "items")
CRAFT = os.path.join(ROOT, "assets", "sprites", "craft")

FLOOR = [hx("4A3F38"), hx("54483F"), hx("3F3530")]
WALL, WALL_L, WALL_D = hx("2E2826"), hx("443B36"), hx("1C1816")
STONE, STONE_L, STONE_D = hx("8B8A7C"), hx("AAA898"), hx("5E5D53")
ORE = {"copper": (hx("D9873A"), hx("F2B36B")), "iron": (hx("A9B8C8"), hx("E2EAF2")),
       "crystal": (hx("6FE0E8"), hx("D8FBFF"))}


def canvas(w=32, h=32):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def speckle(img, rng, colors, n):
    px = img.load()
    for _ in range(n):
        x, y = rng.randrange(img.width), rng.randrange(img.height)
        if px[x, y][3]:
            px[x, y] = rng.choice(colors)


def tiles():
    rng = random.Random(7)
    sheet = Image.new("RGBA", (32 * 5, 32), (0, 0, 0, 0))
    for i in range(3):
        t = Image.new("RGBA", (32, 32), FLOOR[i])
        speckle(t, rng, [hx("5E5148"), hx("392F2A"), hx("665A50")], 70)
        d = ImageDraw.Draw(t)
        for _ in range(2):
            x, y = rng.randrange(4, 28), rng.randrange(4, 28)
            ell(d, x, y, 2, 1, hx("665A50"))
        sheet.alpha_composite(t, (32 * i, 0))
    wall = Image.new("RGBA", (32, 32), WALL)
    speckle(wall, rng, [WALL_D, WALL_L], 90)
    sheet.alpha_composite(wall, (96, 0))
    face = Image.new("RGBA", (32, 32), WALL_L)
    d = ImageDraw.Draw(face)
    d.rectangle((0, 0, 31, 9), fill=WALL)
    for x in range(0, 32, 8):
        d.line((x + rng.randrange(0, 4), 10, x + rng.randrange(0, 4), 31), fill=WALL_D)
    d.rectangle((0, 28, 31, 31), fill=WALL_D)
    speckle(face, rng, [hx("50463F"), WALL_D], 50)
    sheet.alpha_composite(face, (128, 0))
    sheet.save(os.path.join(OUT, "tiles.png"))


def rock(seed, ore=None, gems=False):
    rng = random.Random(seed)
    img, d = canvas(34, 28)
    d.polygon([(3, 26), (2, 15), (8, 6), (17, 3), (27, 6), (32, 15), (31, 26)], fill=STONE)
    d.polygon([(8, 7), (17, 4), (26, 7), (22, 12), (11, 12)], fill=STONE_L)
    d.line((5, 25, 30, 25), fill=STONE_D, width=2)
    speckle(img, rng, [STONE_D, STONE_L], 25)
    if ore:
        c, l = ORE[ore]
        for _ in range(6 if ore != "crystal" else 4):
            x, y = rng.randrange(7, 27), rng.randrange(9, 22)
            if ore == "crystal":
                d.polygon([(x, y + 4), (x + 2, y - 4), (x + 4, y + 4)], fill=c)
                d.line((x + 2, y - 3, x + 2, y + 2), fill=l)
            else:
                d.rectangle((x, y, x + 2, y + 2), fill=c)
                d.point((x, y), fill=l)
    if gems:
        for x, y, col in ((10, 14, "9A5ABE"), (17, 9, "C8382E"), (23, 15, "4FA86A")):
            d.polygon([(x, y + 5), (x + 3, y - 3), (x + 6, y + 5)], fill=hx(col))
            d.point((x + 3, y), fill=(255, 255, 255, 255))
    return outline(img)


def ladder(down):
    img, d = canvas(32, 32)
    if down:
        ell(d, 16, 18, 14, 10, hx("140F0D"))
        ell(d, 16, 18, 12, 8, hx("050403"))
        for x in (9, 22):
            d.rectangle((x, 8, x + 2, 26), fill=WOOD)
        for y in range(11, 26, 5):
            d.rectangle((9, y, 24, y + 1), fill=WOOD_L)
    else:
        d.polygon([(6, 30), (10, 2), (22, 2), (26, 30)], fill=(240, 220, 160, 70))
        for x in (9, 21):
            d.rectangle((x, 0, x + 2, 30), fill=WOOD)
        for y in range(3, 30, 6):
            d.rectangle((9, y, 23, y + 1), fill=WOOD_L)
    return outline(img)


def chest():
    img, d = canvas(28, 24)
    d.rectangle((2, 10, 25, 22), fill=hx("8E3F2B"))
    d.pieslice((2, 2, 25, 18), 180, 360, fill=hx("8E3F2B"))
    d.rectangle((2, 9, 25, 11), fill=hx("F2C14E"))
    d.rectangle((12, 9, 15, 15), fill=hx("F2C14E"))
    return outline(img)


def entrance():
    img, d = canvas(96, 64)
    d.polygon([(0, 63), (6, 26), (20, 8), (48, 0), (76, 8), (90, 26), (95, 63)], fill=STONE_D)
    d.polygon([(10, 63), (14, 30), (26, 14), (48, 8), (70, 14), (82, 30), (86, 63)], fill=STONE)
    speckle(img, random.Random(3), [STONE_L, STONE_D], 140)
    d.polygon([(28, 63), (30, 34), (40, 24), (56, 24), (66, 34), (68, 63)], fill=hx("140F0D"))
    for x in (30, 63):
        d.rectangle((x, 26, x + 4, 63), fill=WOOD)
    d.rectangle((28, 22, 68, 27), fill=WOOD_L)
    d.line((28, 27, 68, 27), fill=WOOD_D)
    return outline(img)


def furnace():
    img, d = canvas(32, 44)
    d.rounded_rectangle((3, 10, 28, 41), radius=6, fill=STONE)
    d.rectangle((12, 0, 19, 12), fill=STONE_D)
    ell(d, 16, 28, 8, 7, hx("2B2118"))
    ell(d, 16, 30, 6, 4, hx("E8873A"))
    ell(d, 16, 31, 3, 2, hx("F2E26B"))
    speckle(img, random.Random(5), [STONE_L, STONE_D], 40)
    return outline(img)


def item(kind):
    img, d = canvas()
    if kind.endswith("_ore"):
        c, l = ORE[kind[:-4]]
        d.polygon([(5, 24), (4, 14), (11, 6), (22, 5), (28, 13), (27, 25), (15, 28)], fill=STONE)
        for x, y in ((10, 12), (18, 9), (21, 18), (12, 20)):
            d.rectangle((x, y, x + 3, y + 3), fill=c)
            d.point((x, y), fill=l)
    elif kind.endswith("_bar"):
        c, l = ORE[kind[:-4]]
        d.polygon([(4, 22), (10, 12), (28, 12), (22, 22)], fill=l)
        d.polygon([(4, 22), (22, 22), (22, 27), (4, 27)], fill=c)
        d.polygon([(22, 22), (28, 12), (28, 17), (22, 27)], fill=c)
        d.line((11, 14, 20, 14), fill=(255, 255, 255, 200))
    elif kind == "crystal":
        c, l = ORE["crystal"]
        for x, h in ((9, 14), (15, 22), (21, 16)):
            d.polygon([(x - 4, 28), (x, 28 - h), (x + 4, 28)], fill=c)
            d.line((x, 28 - h + 3, x, 26), fill=l)
    else:
        col = {"amethyst": "9A5ABE", "ruby": "C8382E", "emerald": "4FA86A", "moonstone": "DDE6F2"}[kind]
        c = hx(col)
        d.polygon([(16, 4), (27, 12), (16, 29), (5, 12)], fill=c)
        d.polygon([(16, 4), (21, 12), (16, 29), (11, 12)], fill=tuple(min(255, v + 50) for v in c[:3]) + (255,))
        d.line((5, 12, 27, 12), fill=tuple(max(0, v - 40) for v in c[:3]) + (255,))
        d.point((14, 8), fill=(255, 255, 255, 255))
    return outline(img)


ITEM_IDS = ["copper_ore", "iron_ore", "crystal", "copper_bar", "iron_bar", "amethyst", "ruby", "emerald", "moonstone"]

if __name__ == "__main__":
    os.makedirs(ITEMS, exist_ok=True)
    tiles()
    sprites = {"rock_a": rock(1), "rock_b": rock(2), "ore_copper": rock(3, "copper"), "ore_iron": rock(4, "iron"),
               "ore_crystal": rock(5, "crystal"), "gem_rock": rock(6, gems=True),
               "ladder_down": ladder(True), "ladder_up": ladder(False), "chest": chest(), "entrance": entrance()}
    for n, img in sprites.items():
        img.save(os.path.join(OUT, n + ".png"))
    for k in ITEM_IDS:
        item(k).save(os.path.join(ITEMS, k + ".png"))
    f = furnace()
    f.save(os.path.join(CRAFT, "furnace.png"))
    ic, _ = canvas()
    ic.alpha_composite(f.resize((22, 30), Image.NEAREST), (5, 1))
    ic.save(os.path.join(CRAFT, "icon_furnace.png"))
    print("arte da mina gerada em", OUT)
