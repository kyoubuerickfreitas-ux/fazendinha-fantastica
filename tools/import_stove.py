#!/usr/bin/env python3
"""
Fogão recortado do mockup da cozinha (assets/source/stove_mockup.png: tampo cinza com uma boca e o botão,
armário com a portinha de folha) e a bancada da pia separada dele.
  assets/sprites/house_in/stove.png    o fogão de casa (1 quadrado de largura)
  assets/sprites/house_in/counter.png  a bancada com a pia (a parte esquerda da cozinha antiga, 2 quadrados)
  assets/sprites/craft/stove.png       o fogão colocável (saves antigos), mesma arte
Também imprime onde fica a boca do fogão (para HouseWorld.STOVE_OFFSET).
Uso: python3 tools/import_stove.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from collections import deque  # noqa: E402
from import_hud import key_flood  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HIN = os.path.join(ROOT, "assets", "sprites", "house_in")
HEIGHT = 46                  # a mesma altura da bancada da pia
CROP = (915, 191, 1047, 411)  # o fogão no mockup (contorno escuro incluso)
FEET = ((919, 942), (1023, 1046))   # abaixo de FEET_Y só ficam os pés (tira o pé da mesa que aparece no meio)
FEET_Y = 402
BURNER = (980, 234)          # centro da boca no mockup
# fogão atual: arte própria de fundo verde (assets/source/stove_green.jpg); o recorte do mockup fica de reserva
GREEN_SRC = os.path.join(ROOT, "assets", "source", "stove_green.jpg")
GREEN_BURNER = (688, 165)


def cut_green():
    im = key_flood(Image.open(GREEN_SRC).convert("RGBA"))
    px = im.load()
    for y in range(im.height):          # verde preso / franja do JPG
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and g > 190 and r < 90 and b < 90:
                px[x, y] = (0, 0, 0, 0)
    return im


def cut_stove():
    """Recorta o fogão: limpa o vão entre os pés e apaga, a partir da borda, tudo que não é contorno escuro."""
    im = Image.open(os.path.join(ROOT, "assets", "source", "stove_mockup.png")).convert("RGBA").crop(CROP)
    px = im.load()
    w, h = im.size
    for y in range(FEET_Y - CROP[1], h):
        for x in range(w):
            gx = x + CROP[0]
            if not any(a <= gx <= b for a, b in FEET):
                px[x, y] = (0, 0, 0, 0)
    q = deque([(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)]
              + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)])
    seen = set()
    while q:
        x, y = q.popleft()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        if px[x, y][3] and sum(px[x, y][:3]) < 200:
            continue
        px[x, y] = (0, 0, 0, 0)
        q.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    return im


def shrink(im, w):
    s = w / im.width
    small = im.resize((w, round(im.height * s)), Image.LANCZOS)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 120 else (0, 0, 0, 0)
    return small, s


if __name__ == "__main__":
    use_green = os.path.exists(GREEN_SRC)
    im = cut_green() if use_green else cut_stove()
    bb = im.getbbox()
    im = im.crop(bb)
    if not use_green:
        bb = (bb[0] + CROP[0], bb[1] + CROP[1])
    else:
        BURNER = GREEN_BURNER
    small, s = shrink(im, round(im.width * HEIGHT / im.height))
    small.save(os.path.join(HIN, "stove.png"))
    bx = (BURNER[0] - bb[0]) * s - small.width / 2.0
    by = (BURNER[1] - bb[1]) * s - small.height
    print("fogão", small.size, "boca em relação à base: (%.0f, %.0f)" % (bx, by))
    craft, _ = shrink(im, 22)
    craft.save(os.path.join(ROOT, "assets", "sprites", "craft", "stove.png"))
    # bancada com a pia: a cozinha antiga sem o fogão (fecha com a borda direita original)
    k = Image.open(os.path.join(HIN, "kitchen.png")).convert("RGBA")
    left = k.crop((0, 0, 62, k.height))
    edge = k.crop((96, 0, k.width, k.height))
    out = Image.new("RGBA", (left.width + edge.width, k.height), (0, 0, 0, 0))
    out.paste(left, (0, 0))
    out.paste(edge, (left.width, 0))
    out.save(os.path.join(HIN, "counter.png"))
    print("bancada", out.size)
