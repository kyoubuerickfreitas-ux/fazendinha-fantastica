#!/usr/bin/env python3
"""
Troca a terra arada (seca e molhada) em assets/sprites/tiles.png pela arte de
assets/source/tiles/tilled.webp (fundo preto removido, reduzida para 32x32).
A versão molhada é a mesma arte escurecida.

Rode depois de tools/generate_placeholder_art.py (que recria tiles.png).
Uso: python3 tools/import_soil.py
"""
import os
from collections import deque
from PIL import Image, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "tiles", "tilled.webp")
TILES = os.path.join(ROOT, "assets", "sprites", "tiles.png")
T_TILLED, T_WET = 4, 5


def remove_black(im):
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
        if r + g + b > 30:
            continue
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                q.append((nx, ny))
    return im


def to_tile(im):
    im = im.crop(im.getbbox()).resize((32, 32), Image.LANCZOS)
    px = im.load()
    for y in range(32):
        for x in range(32):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
    return im


def wet(tile):
    rgb = ImageEnhance.Brightness(tile.convert("RGB")).enhance(0.62)
    rgb = ImageEnhance.Color(rgb).enhance(0.85)
    out = rgb.convert("RGBA")
    out.putalpha(tile.getchannel("A"))
    # mantém os brotinhos verdes com a cor original
    sp, op = tile.load(), out.load()
    for y in range(32):
        for x in range(32):
            r, g, b, a = sp[x, y]
            if a and g > r + 15 and g > b + 15:
                op[x, y] = sp[x, y]
    return out


if __name__ == "__main__":
    dry = to_tile(remove_black(Image.open(SRC).convert("RGBA")))
    sheet = Image.open(TILES).convert("RGBA")
    for idx, t in ((T_TILLED, dry), (T_WET, wet(dry))):
        sheet.paste((0, 0, 0, 0), (idx * 32, 0, idx * 32 + 32, 32))
        sheet.alpha_composite(t, (idx * 32, 0))
    sheet.save(TILES)
    print("terra arada atualizada em", TILES)
