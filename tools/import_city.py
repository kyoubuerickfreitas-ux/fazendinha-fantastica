#!/usr/bin/env python3
"""
Cidade a partir da folha assets/source/city_sheet.png (fundo verde, vistas de frente).
Saída: assets/sprites/city/<nome>.png, todas na mesma escala da casa do jogador (SCALE), base na base da imagem.
  Prédios: house_red, fish_shop, restaurant, blacksmith, tailor, well, market, barn_house, windmill, inn, bakery
  Enfeites: notice_board, lamp_post, banner_post, signpost, bench, barrel, crate, patch_a, patch_b
  Chão: cobble.png (132x132, emenda nas bordas) feito com as cores do calçamento da folha
A fumaça pintada nas chaminés é apagada (no jogo ela é um efeito animado); imprime onde fica o topo
de cada chaminé (para CityWorld.CHIMNEYS).
Uso: python3 tools/import_city.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from import_hud import key_flood  # noqa: E402
from import_animals import components  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "city_sheet.png")
OUT = os.path.join(ROOT, "assets", "sprites", "city")
SCALE = 0.33          # a casa vermelha fica do tamanho da casa do jogador

PIECES = {
    "house_red": (9, 5, 383, 363), "fish_shop": (393, 13, 782, 371), "restaurant": (793, 9, 1141, 370),
    "blacksmith": (1150, 37, 1526, 366), "tailor": (12, 381, 405, 655), "well": (430, 400, 674, 652),
    "market": (690, 427, 938, 654), "barn_house": (943, 395, 1279, 666), "windmill": (1282, 376, 1524, 660),
    "inn": (9, 674, 414, 999), "bakery": (431, 682, 734, 993), "notice_board": (733, 720, 947, 952),
    "lamp_post": (963, 691, 1026, 942), "banner_post": (1032, 712, 1136, 943), "signpost": (1126, 742, 1265, 945),
    "bench": (963, 967, 1080, 1018), "barrel": (1097, 956, 1148, 1019), "crate": (1167, 967, 1234, 1019),
    "patch_a": (1276, 896, 1404, 1012), "patch_b": (1407, 900, 1526, 1001),
}
# fumaça pintada: (peça, caixa a apagar na folha, ponto do topo da chaminé na folha)
SMOKE = [("house_red", (262, 0, 350, 62), (295, 64)),
         ("restaurant", (1015, 0, 1085, 56), (1045, 58)),
         ("inn", (333, 660, 388, 715), (355, 717))]
COBBLE = (1300, 700, 1500, 870)      # miolo do calçamento (sem a grama da borda)


def drop_strays(p, frac=0.06):
    """Tira pedacinhos soltos de peças vizinhas que entraram na caixa (fica o que for >= frac da maior parte)."""
    comps = components(p, 1)
    big = max(c["area"] for c in comps)
    px = p.load()
    for c in comps:
        if c["area"] < big * frac:
            for x, y in c["pts"]:
                px[x, y] = (0, 0, 0, 0)
    return p


def shrink(p, s, opaque=False):
    small = p.resize((max(1, round(p.width * s)), max(1, round(p.height * s))), Image.LANCZOS)
    sp = small.load()
    for y in range(small.height):
        for x in range(small.width):
            r, g, b, a = sp[x, y]
            sp[x, y] = (r, g, b, 255) if (a >= 110 or (opaque and a > 0)) else (0, 0, 0, 0)
    return small


def cobble(im, size=132, seed=7):
    """Calçamento 128x128 que emenda nas bordas: pedras arredondadas em fileiras desencontradas, com as
    cores das pedras da arte (o miolo do calçamento da folha) e um pouco de musgo nas juntas."""
    import random
    rng = random.Random(seed)
    src = im.crop(COBBLE).convert("RGB").quantize(12).convert("RGB")
    cols = sorted(set(src.getdata()), key=lambda c: -list(src.getdata()).count(c))
    stones = [c for c in cols if sum(c) > 330 and not (c[1] > c[0] + 10 and c[1] > c[2] + 10)][:6]
    mortar = (112, 96, 80)
    moss = [(96, 128, 52), (122, 150, 64)]
    tile = Image.new("RGB", (size, size), mortar)
    px = tile.load()
    row_h = 11
    for r in range(size // row_h):
        y0 = r * row_h
        x = rng.randrange(0, 12)
        widths = []
        total = 0
        while total < size:
            w = rng.randrange(10, 18)
            widths.append(w)
            total += w
        widths[-1] -= total - size        # a fileira fecha certinho (emenda na horizontal)
        if widths[-1] < 7:
            widths[-2] += widths.pop()
        for w in widths:
            base = rng.choice(stones)
            jitter = rng.randrange(-8, 9)
            base = tuple(max(0, min(255, c + jitter)) for c in base)
            light = tuple(min(255, c + 22) for c in base)
            dark = tuple(max(0, c - 26) for c in base)
            top = rng.randrange(1, 3)          # pedras de alturas um pouco diferentes
            bot = row_h - rng.randrange(1, 3)
            for dy in range(top, bot):
                for dx in range(1, w):
                    ex = min(dx - 1, w - 1 - dx)
                    ey = min(dy - top, bot - 1 - dy)
                    if ex + ey < 2:
                        continue          # canto arredondado
                    c = base
                    if ey == 0 and dy == top or ex == 0 and dx == 1:
                        c = light
                    elif dy == bot - 1 or dx == w - 1 or (ey == 1 and dy > row_h // 2):
                        c = dark
                    px[(x + dx) % size, (y0 + dy) % size] = c
            x += w
    for _ in range(40):                   # musgo nas juntas
        mx, my = rng.randrange(size), rng.randrange(size)
        if px[mx, my] == mortar:
            px[mx, my] = rng.choice(moss)
    return tile.convert("RGBA")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    raw = Image.open(SRC).convert("RGBA")
    im = key_flood(raw.copy())
    px = im.load()
    for y in range(im.height):          # verde de fundo preso (entre pernas, janelas)
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and g > 190 and r < 90 and b < 90:
                px[x, y] = (0, 0, 0, 0)
    for _, box, _ in SMOKE:
        for y in range(box[1], box[3]):
            for x in range(box[0], box[2]):
                px[x, y] = (0, 0, 0, 0)
    for name, box in PIECES.items():
        p = drop_strays(im.crop(box), 0.06 if box[2] - box[0] < 250 else 0.01)
        bb = p.getbbox()
        p = p.crop(bb)
        small = shrink(p, SCALE)
        small.save(os.path.join(OUT, name + ".png"))
        line = f"{name} {small.size}"
        for sname, _, top in SMOKE:
            if sname == name:
                ox = (top[0] - box[0] - bb[0]) * SCALE
                oy = (top[1] - box[1] - bb[1]) * SCALE
                line += f"  chaminé na imagem: ({ox:.0f}, {oy:.0f})"
        print(line)
    cobble(raw).save(os.path.join(OUT, "cobble.png"))
    print("cobble (132, 132)")
