#!/usr/bin/env python3
"""
Peças tiradas da imagem de referência da cidade (assets/source/city_reference.png), que não existiam
em outra arte: o chafariz da praça, o coreto e o barco do cais. Escala da cidade (SCALE: os prédios da
referência ficam do tamanho dos nossos). Saída: assets/sprites/city/<nome>.png
  fountain: máscara em elipse (a borda de pedra) + o jato d'água
  gazebo: tira a grama e a terra em volta (enchendo a partir da borda)
  boat: tira a água em volta
  sand.png: chão de terra clara dos caminhos (64x64, emenda nas bordas), com as cores da terra da referência
Uso: python3 tools/import_city_extras.py
"""
import os
import sys
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402
from import_animals import components  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "city_reference.png")
OUT = os.path.join(ROOT, "assets", "sprites", "city")
SCALE = 0.54


def flood_out(a, is_bg):
    """Tira o que é fundo (is_bg) e está ligado à borda."""
    h, w = a.shape[:2]
    seen = np.zeros((h, w), bool)
    q = deque([(y, x) for x in range(w) for y in (0, h - 1)] + [(y, x) for y in range(h) for x in (0, w - 1)])
    while q:
        y, x = q.popleft()
        if not (0 <= y < h and 0 <= x < w) or seen[y, x] or not is_bg[y, x]:
            continue
        seen[y, x] = True
        q.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    a[seen, 3] = 0
    return a


def keep_big(a, frac=0.05):
    img = Image.fromarray(a)
    comps = components(img, 128)
    big = max(c["area"] for c in comps)
    for c in comps:
        if c["area"] < big * frac:
            for x, y in c["pts"]:
                a[y, x, 3] = 0
    return a


def finish(a, name, scale=SCALE):
    img = Image.fromarray(a)
    img = img.crop(img.getbbox())
    small = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    b = np.array(small)
    b[..., 3] = np.where(b[..., 3] >= 128, 255, 0)
    b[b[..., 3] == 0] = 0
    Image.fromarray(b).save(os.path.join(OUT, name + ".png"))
    print(name, small.size)


def sand(size=64, seed=5):
    import random
    rng = random.Random(seed)
    base = np.array([214, 172, 108], float)
    a = np.zeros((size, size, 3), float)
    a[:] = base
    for _ in range(900):                     # grãos claros e escuros
        x, y = rng.randrange(size), rng.randrange(size)
        a[y, x] += rng.choice([14, 9, -10, -16])
    for _ in range(14):                      # pedrinhas
        x, y = rng.randrange(size), rng.randrange(size)
        for dx, dy, v in ((0, 0, 30), (1, 0, 24), (0, 1, -30), (1, 1, -38)):
            a[(y + dy) % size, (x + dx) % size] = base + v
    for _ in range(10):                      # manchinhas mais escuras
        x, y = rng.randrange(size), rng.randrange(size)
        for dy in range(-2, 3):
            for dx in range(-3, 4):
                if dx * dx / 9 + dy * dy / 4 <= 1:
                    a[(y + dy) % size, (x + dx) % size] -= 9
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert("RGBA")
    img.save(os.path.join(OUT, "sand.png"))
    print("sand", img.size)


if __name__ == "__main__":
    sand()
    im = Image.open(SRC).convert("RGBA")
    # chafariz: elipse da borda de pedra + o jato (azul/branco) acima dela
    box = (712, 365, 876, 500)
    c = np.array(im.crop(box))
    m = Image.new("L", (box[2] - box[0], box[3] - box[1]), 0)
    d = ImageDraw.Draw(m)
    d.ellipse((9, 25, 155, 130), fill=255)
    mk = np.array(m) > 0
    rgb = c[..., :3].astype(int)
    jet = (rgb[..., 2] > rgb[..., 0] + 30) | (rgb.min(-1) > 200)
    jet[40:] = False
    mk |= jet
    c[~mk, 3] = 0
    finish(keep_big(c), "fountain", 0.8)        # o chafariz fica maior: é o centro da praça
    # coreto: tira grama, terra e arbustos ligados à borda
    box = (392, 788, 508, 922)
    c = np.array(im.crop(box))
    rgb = c[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    green = (g > r + 8) & (g > b + 20)
    dirt = (r > 140) & (g > 95) & (b < 150) & (r - b > 45) & (r - g < 75)
    finish(keep_big(flood_out(c, green | dirt)), "gazebo", 0.66)
    # barco: tira a água
    box = (1448, 478, 1530, 560)
    c = np.array(im.crop(box))
    rgb = c[..., :3].astype(int)
    water = rgb[..., 2] > rgb[..., 0] + 40
    finish(keep_big(flood_out(c, water), 0.3), "boat")
