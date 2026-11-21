#!/usr/bin/env python3
"""
Arte PROVISÓRIA do interior da casa (assets/sprites/house_in/). Para trocar pela definitiva, substitua os
PNGs com o mesmo nome (o tamanho pode mudar um pouco; a base da imagem fica na base do móvel).

  floor.png      piso de madeira 32x32 (repete)
  wall.png       parede do fundo 32x64 (reboco em cima, lambri embaixo; repete na horizontal)
  wall_side.png  parede lateral/da frente 16x32 (madeira escura)
  window.png     janela da parede do fundo
  bed.png  table.png  chair.png  fireplace.png  rug.png  shelf.png  counter.png  plant.png  mat.png  frame.png
O baú usa assets/sprites/mine/chest_brown.png e o fogão assets/sprites/craft/stove.png.
Uso: python3 tools/generate_house_interior.py
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw  # noqa: E402
from generate_placeholder_art import hx, outline, ell  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "house_in")

PLANK = [hx("9a6a40"), hx("a87548"), hx("8f5f38")]
PLANK_D = hx("6e4628")
PLASTER, PLASTER_D = hx("ead9b4"), hx("d6c094")
WOOD, WOOD_L, WOOD_D, WOOD_DD = hx("8a5a34"), hx("b07a4a"), hx("5f3b20"), hx("3e2614")
RED, RED_D = hx("c5473a"), hx("8e2f27")
GREEN, GREEN_D, GREEN_L = hx("5f9e4a"), hx("3f6e30"), hx("8cc46a")
CREAM = hx("f4ead2")
STONE, STONE_L, STONE_D = hx("8f8a80"), hx("b2ada2"), hx("615c55")


def canvas(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def floor():
    img, d = canvas(32, 32)
    rng = random.Random(3)
    for i, y in enumerate(range(0, 32, 8)):
        d.rectangle((0, y, 31, y + 7), fill=PLANK[i % 3])
        d.line((0, y + 7, 31, y + 7), fill=PLANK_D)
        x = (i * 13) % 32
        d.line((x, y, x, y + 6), fill=PLANK_D)
        for _ in range(4):
            gx, gy = rng.randrange(32), y + rng.randrange(1, 6)
            d.point((gx, gy), fill=PLANK_D)
    return img


def wall():
    img, d = canvas(32, 64)
    d.rectangle((0, 0, 31, 6), fill=WOOD_D)                 # viga do teto
    d.line((0, 6, 31, 6), fill=WOOD_DD)
    d.rectangle((0, 7, 31, 38), fill=PLASTER)               # reboco
    rng = random.Random(5)
    for _ in range(10):
        d.point((rng.randrange(32), rng.randrange(8, 38)), fill=PLASTER_D)
    d.rectangle((0, 39, 31, 41), fill=WOOD_L)               # moldura do lambri
    d.rectangle((0, 42, 31, 61), fill=WOOD)                 # lambri
    for x in (0, 16):
        d.line((x, 42, x, 61), fill=WOOD_D)
    d.rectangle((0, 62, 31, 63), fill=WOOD_DD)              # rodapé
    return img


def wall_side():
    img, d = canvas(16, 32)
    d.rectangle((0, 0, 15, 31), fill=WOOD_D)
    d.line((5, 0, 5, 31), fill=WOOD_DD)
    d.line((11, 0, 11, 31), fill=WOOD_DD)
    return img


def window():
    img, d = canvas(28, 26)
    d.rectangle((0, 0, 27, 25), fill=WOOD)
    d.rectangle((3, 3, 24, 22), fill=hx("9fd3f0"))
    d.rectangle((3, 15, 24, 22), fill=hx("8cc46a"))          # o pasto lá fora
    d.line((13, 3, 13, 22), fill=WOOD)
    d.line((3, 12, 24, 12), fill=WOOD)
    d.polygon([(3, 3), (9, 3), (5, 22), (3, 22)], fill=RED)  # cortinas
    d.polygon([(24, 3), (18, 3), (22, 22), (24, 22)], fill=RED)
    return outline(img)


def bed():
    img, d = canvas(40, 58)
    d.rectangle((1, 2, 38, 12), fill=WOOD)                    # cabeceira
    d.rectangle((3, 4, 36, 10), fill=WOOD_L)
    d.rectangle((3, 12, 36, 52), fill=WOOD_D)                 # estrado
    d.rectangle((5, 13, 34, 26), fill=CREAM)                  # lençol
    ell(d, 13, 19, 7, 4, hx("ffffff"))                        # travesseiros
    ell(d, 27, 19, 7, 4, hx("ffffff"))
    d.rectangle((4, 25, 35, 50), fill=RED)                    # colcha
    for y in range(29, 50, 6):
        for x in range(8, 34, 8):
            d.rectangle((x, y, x + 3, y + 2), fill=hx("f2c14e"))
    d.line((4, 25, 35, 25), fill=CREAM)
    d.rectangle((1, 50, 38, 56), fill=WOOD)                   # pés
    return outline(img)


def table():
    img, d = canvas(44, 34)
    ell(d, 22, 13, 20, 11, WOOD_L)
    ell(d, 22, 12, 19, 9, hx("c08a56"))
    d.rectangle((19, 22, 25, 32), fill=WOOD_D)
    d.rectangle((13, 30, 31, 32), fill=WOOD_D)
    ell(d, 22, 11, 6, 3, CREAM)                               # toalhinha
    ell(d, 22, 9, 3, 3, RED)                                  # maçã
    return outline(img)


def chair():
    img, d = canvas(16, 24)
    d.rectangle((2, 0, 13, 11), fill=WOOD)
    d.rectangle((4, 2, 11, 9), fill=WOOD_L)
    d.rectangle((1, 11, 14, 15), fill=WOOD_L)
    d.rectangle((2, 15, 4, 23), fill=WOOD_D)
    d.rectangle((11, 15, 13, 23), fill=WOOD_D)
    return outline(img)


def fireplace():
    img, d = canvas(56, 62)
    d.rectangle((4, 0, 51, 61), fill=STONE)
    rng = random.Random(9)
    for y in range(2, 60, 7):
        off = (y // 7) % 2 * 5
        for x in range(4 + off, 52, 11):
            d.rectangle((x, y, x + 9, y + 5), fill=rng.choice([STONE_L, STONE, hx("9c968a")]))
    d.rectangle((0, 14, 55, 19), fill=WOOD)                   # prateleira
    d.rectangle((0, 14, 55, 15), fill=WOOD_L)
    d.rectangle((14, 30, 41, 61), fill=hx("2a1a12"))          # boca
    ell(d, 27, 60, 12, 3, hx("4a2a18"))
    d.polygon([(18, 60), (22, 44), (26, 52), (29, 38), (33, 50), (37, 44), (39, 60)], fill=hx("f08a2c"))
    d.polygon([(22, 60), (25, 50), (29, 46), (33, 52), (35, 60)], fill=hx("f6d04d"))
    ell(d, 12, 11, 3, 3, hx("f2c14e"))                        # potinho
    ell(d, 44, 10, 3, 4, GREEN)                               # plantinha
    return outline(img)


def rug():
    img, d = canvas(84, 46)
    for i, c in enumerate([RED_D, RED, hx("f2c14e"), RED, CREAM, GREEN]):
        ell(d, 42, 23, 41 - i * 6, 22 - i * 3.3, c)
    return img


def shelf():
    img, d = canvas(30, 52)
    d.rectangle((0, 0, 29, 51), fill=WOOD_D)
    d.rectangle((2, 2, 27, 49), fill=WOOD)
    rng = random.Random(4)
    for sy in (14, 28, 42):
        d.rectangle((2, sy, 27, sy + 2), fill=WOOD_L)
        x = 3
        while x < 25:
            w = rng.randrange(2, 5)
            h = rng.randrange(7, 11)
            d.rectangle((x, sy - h, x + w - 1, sy - 1), fill=rng.choice([RED, GREEN, hx("4f7fc4"), hx("f2c14e"), CREAM]))
            x += w + 1
    return outline(img)


def counter():
    img, d = canvas(64, 38)
    d.rectangle((0, 8, 63, 37), fill=WOOD)
    d.rectangle((0, 6, 63, 11), fill=hx("d9c9a8"))            # tampo
    for x in (2, 22, 42):
        d.rectangle((x + 2, 15, x + 17, 33), fill=WOOD_L)     # portinhas
        d.point((x + 15, 24), fill=WOOD_DD)
    ell(d, 12, 3, 6, 3, hx("4f7fc4"))                         # tigela
    d.rectangle((40, 0, 46, 6), fill=CREAM)                   # jarra
    ell(d, 54, 4, 4, 3, RED)
    return outline(img)


def plant():
    img, d = canvas(20, 30)
    d.polygon([(4, 18), (16, 18), (14, 29), (6, 29)], fill=hx("b5502a"))
    for x, y, rx in ((10, 9, 6), (5, 13, 4), (15, 12, 4), (10, 4, 3)):
        ell(d, x, y, rx, rx, GREEN)
    ell(d, 9, 8, 2, 2, GREEN_L)
    return outline(img)


def mat():
    img, d = canvas(40, 16)
    d.rounded_rectangle((0, 0, 39, 15), radius=4, fill=hx("b08a4a"))
    d.rounded_rectangle((3, 3, 36, 12), radius=3, fill=hx("c9a35e"))
    return img


def frame():
    img, d = canvas(22, 18)
    d.rectangle((0, 0, 21, 17), fill=WOOD_L)
    d.rectangle((2, 2, 19, 15), fill=hx("9fd3f0"))
    d.polygon([(2, 15), (8, 7), (12, 12), (15, 9), (19, 15)], fill=GREEN)
    ell(d, 15, 5, 2, 2, hx("f6d04d"))
    return outline(img)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    parts = {"floor": floor(), "wall": wall(), "wall_side": wall_side(), "window": window(), "bed": bed(),
             "table": table(), "chair": chair(), "fireplace": fireplace(), "rug": rug(), "shelf": shelf(),
             "counter": counter(), "plant": plant(), "mat": mat(), "frame": frame()}
    for n, im in parts.items():
        im.save(os.path.join(OUT, n + ".png"))
    print("interior da casa:", len(parts), "peças em", OUT)
