#!/usr/bin/env python3
"""
Arte PROVISÓRIA dos estágios das plantas: assets/sprites/crops/<id>.png
Tira horizontal com (dias de estágio + 1) quadros de 32 x altura; o último quadro é a planta pronta.
Quadro 0 = semente, 1 = broto, os do meio = crescendo, último = pronta (com o fruto/legume).

Para trocar pela arte definitiva: substitua o PNG mantendo a mesma quantidade de quadros
(veja stage_days em data/crops/<id>.tres).

Uso: python3 tools/generate_crop_art.py
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw  # noqa: E402
from crops_table import CROPS  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "crops")
HD = Image.open(os.path.join(ROOT, "assets", "sprites", "items_hd.png")).convert("RGBA")
SMALL = Image.open(os.path.join(ROOT, "assets", "sprites", "icons.png")).convert("RGBA")
INK = (43, 33, 24, 255)
MOUND = (94, 63, 38, 255)
LEAF = [(76, 106, 48, 255), (95, 138, 60, 255), (134, 168, 90, 255), (182, 201, 149, 255)]


def outline(img):
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] >= 200:
                    dst[x, y] = INK
                    break
    return out


def produce_icon(c, size):
    if "hd" in c:
        k = c["hd"]
        ic = HD.crop(((k % 16) * 32, (k // 16) * 32, (k % 16) * 32 + 32, (k // 16) * 32 + 32))
    else:
        k = c["small"]
        ic = SMALL.crop(((k % 16) * 16, (k // 16) * 16, (k % 16) * 16 + 16, (k // 16) * 16 + 16))
    ic = ic.crop(ic.getbbox())
    s = size / max(ic.size)
    ic = ic.resize((max(1, round(ic.width * s)), max(1, round(ic.height * s))), Image.NEAREST)
    return ic


def foliage(d, rng, cx, base, size, cat):
    """Tufo de folhas proporcional a `size` (0..1)."""
    h = int(4 + size * 16)
    if cat == "fungus":
        return
    d.line((cx, base, cx, base - h), fill=LEAF[0], width=2)
    n = 2 + int(size * 5)
    for i in range(n):
        t = (i + 1) / (n + 1)
        y = base - int(h * t)
        side = -1 if i % 2 == 0 else 1
        r = 2 + int(size * 4)
        d.ellipse((cx + side * r - r, y - r // 2 - 1, cx + side * r + r, y + r // 2), fill=LEAF[1 + (i % 3)])
    if cat in ("fruit",) and size > 0.6:
        d.ellipse((cx - 9, base - h - 2, cx + 9, base - h + 8), fill=LEAF[1])
        d.ellipse((cx - 6, base - h - 4, cx + 4, base - h + 3), fill=LEAF[2])


def frame(c, stage, frames, height):
    rng = random.Random(hash(c["id"]) % 1000 + stage)
    img = Image.new("RGBA", (32, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base = height - 6
    cx = 16
    d.ellipse((8, base - 2, 24, base + 3), fill=MOUND)
    cat = c.get("category", "vegetable")
    last = frames - 1
    if stage == 0:
        for x in (12, 16, 20):
            d.point((x, base), fill=(233, 221, 187, 255))
        return outline(img)
    if stage == 1:
        d.line((cx, base, cx, base - 6), fill=LEAF[1])
        d.ellipse((cx - 5, base - 8, cx - 1, base - 5), fill=LEAF[2])
        d.ellipse((cx + 1, base - 9, cx + 5, base - 6), fill=LEAF[3])
        return outline(img)
    size = stage / last
    if cat == "fungus":
        n = 1 + stage
        ic = produce_icon(c, 6 + stage * 3)
        for i in range(min(n, 3)):
            img.alpha_composite(ic, (cx - ic.width // 2 + (i - 1) * 7, base - ic.height + 1 - (i % 2) * 2))
        return outline(img) if stage < last else img
    foliage(d, rng, cx, base, size, cat)
    img = outline(img)
    if stage == last:
        if cat == "fruit":
            ic = produce_icon(c, 11)
            spots = [(cx - 9, base - 18), (cx + 2, base - 22), (cx - 3, base - 11)]
            if c["id"] in ("watermelon", "melon"):
                ic = produce_icon(c, 17)
                spots = [(cx - 8, base - 15)]
            for x, y in spots:
                img.alpha_composite(ic, (x, y))
        elif cat == "flower":
            ic = produce_icon(c, 14)
            img.alpha_composite(ic, (cx - ic.width // 2, base - 24))
        else:   # legume/raiz: aparece saindo da terra
            ic = produce_icon(c, 15)
            img.alpha_composite(ic, (cx - ic.width // 2, base - ic.height + 4))
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for c in CROPS:
        frames = len(c["stage_days"]) + 1
        h = c.get("sprite_height", 32)
        strip = Image.new("RGBA", (32 * frames, h), (0, 0, 0, 0))
        for s in range(frames):
            strip.alpha_composite(frame(c, s, frames, h), (32 * s, 0))
        strip.save(os.path.join(OUT, c["id"] + ".png"))
    print(len(CROPS), "tiras de plantas em", OUT)
