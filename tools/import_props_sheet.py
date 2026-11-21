#!/usr/bin/env python3
"""
Importa a folha de objetos (assets/source/props_sheet.png, fundo verde) que substitui a arte provisória de
construções, máquinas, ícones, comidas e pesca. As peças estão na MESMA ORDEM da folha de referência
(linha a linha, da esquerda para a direita): veja ORDER.

Cada peça é recortada, o verde é removido e ela é reduzida para caber no tamanho do PNG provisório que
substitui (mesma largura x altura máxima, base embaixo), então o jogo não muda de escala.
Uso: python3 tools/import_props_sheet.py
"""
import colorsys
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from import_animals import components  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "props_sheet.png")
SPR = os.path.join(ROOT, "assets", "sprites")

C = "craft/"
F = "fishing/"
ORDER = (
    [C + n for n in "workbench feeder feeder_full fence stone_path scarecrow barn coop silo incubator cheese_press "
     "butter_churn loom spinning_wheel oil_press preserves_jar sprinkler sprinkler_q sprinkler_c stove smoker "
     "aquarium_small aquarium_large fish_pond grass_a grass_b grass_c".split()]
    + [C + "icon_" + n for n in "cheese butter cloth yarn jam pickles truffle_oil hay fert_basic fert_growth fert_water "
       "fert_quality fert_fish fertile_egg herbal_tea brush shears".split()]
    + [F + "bait_treasure", F + "smoked_fish"]
    + ["food/" + n for n in "apple_pie beet_soup blueberry_pancake carrot_soup cheese_grapes fruit_juice fruit_salad "
       "grilled_fish lake_stew lake_sushi legend_feast lemonade mashed_potato mushroom_risotto omelette salad_kale "
       "starflower_tea strawberry_cake tropical_pop truffle_pasta recipe_scroll".split()]
    + [F + n for n in "fish_moss_king fish_silver_moon fish_winter_heart fish_guardian fish_dream fish_cave_blind "
       "fish_cave_glow fish_cave_crystal old_boot old_coin pearl relic_compass relic_shell relic_statue message_bottle "
       "map_piece chest_small chest_gold driftwood fungo_glasses".split()]
    # troféus: a folha veio com 7 (repetidos); os que faltam são recoloridos abaixo
    + ["trophy:moss_king", "trophy:silver_moon", "trophy:purple_a", "trophy:cup_a", "trophy:purple_b",
       "trophy:cup_b", "trophy:purple_c"]
)
# peças que não ficaram boas na folha: continuam com a arte provisória
SKIP = {C + "feeder_full", F + "driftwood"}


def key_green(im):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if g > 120 and g - max(r, b) > 70:
                px[x, y] = (0, 0, 0, 0)
            elif g > r + 25 and g > b + 25 and g > 150:
                # borda esverdeada (anti-serrilhado): tira o verde
                px[x, y] = (r, max(r, b), b, a)
    return im


def pieces(im):
    comps = components(im)
    main = [c for c in comps if c["area"] >= 900]
    for s in comps:
        if s in main or s["area"] < 6:
            continue
        sx, sy = (s["bbox"][0] + s["bbox"][2]) / 2, (s["bbox"][1] + s["bbox"][3]) / 2

        def dist(c):
            b = c["bbox"]
            return max(b[0] - sx, 0, sx - b[2]) ** 2 + max(b[1] - sy, 0, sy - b[3]) ** 2
        m = min(main, key=dist)
        if dist(m) < 34 ** 2:
            m["pts"] += s["pts"]
            b = m["bbox"]
            m["bbox"] = [min(b[0], s["bbox"][0]), min(b[1], s["bbox"][1]), max(b[2], s["bbox"][2]), max(b[3], s["bbox"][3])]
    # linhas: pelo centro vertical
    main.sort(key=lambda c: (c["bbox"][1] + c["bbox"][3]) / 2)
    rows, cur = [], []
    for c in main:
        cy = (c["bbox"][1] + c["bbox"][3]) / 2
        if cur and cy - sum((k["bbox"][1] + k["bbox"][3]) / 2 for k in cur) / len(cur) > 45:
            rows.append(cur)
            cur = []
        cur.append(c)
    rows.append(cur)
    out = []
    for r in rows:
        out += sorted(r, key=lambda c: c["bbox"][0])
    return out, [len(r) for r in rows]


def crop(im, c):
    x0, y0, x1, y1 = c["bbox"]
    out = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    src, dst = im.load(), out.load()
    for x, y in c["pts"]:
        dst[x - x0, y - y0] = src[x, y]
    return out


def fit_like(img, ref_path):
    """Reduz para caber no tamanho do PNG provisório (base embaixo, centralizado)."""
    ref = Image.open(ref_path)
    W, H = ref.size
    bb = ref.getbbox() or (0, 0, W, H)
    bw, bh = bb[2] - bb[0], bb[3] - bb[1]
    s = min(bw / img.width, bh / img.height)
    nw, nh = max(1, round(img.width * s)), max(1, round(img.height * s))
    small = img.resize((nw, nh), Image.LANCZOS)
    px = small.load()
    for y in range(nh):
        for x in range(nw):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.alpha_composite(small, ((bb[0] + bb[2] - nw) // 2, bb[3] - nh))
    return out


def recolor(img, hue_from, hue_to, sat_mult=1.0):
    """Troca uma faixa de matiz (ex.: peixe roxo do troféu -> azul)."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s > 0.25 and hue_from[0] <= h <= hue_from[1]:
                r2, g2, b2 = colorsys.hsv_to_rgb(hue_to, min(1, s * sat_mult), v)
                px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return out


def icon(img):
    s = min(30 / img.width, 30 / img.height)
    small = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    out.alpha_composite(small, ((32 - small.width) // 2, (32 - small.height) // 2))
    return out


if __name__ == "__main__":
    im = key_green(Image.open(SRC).convert("RGBA"))
    found, per_row = pieces(im)
    print("peças por linha:", per_row, "total", len(found), "esperado", len(ORDER))
    assert len(found) == len(ORDER), "a folha não tem o número de peças esperado"
    got = {}
    for name, c in zip(ORDER, found):
        got[name] = crop(im, c)
    trophies = {
        "moss_king": got["trophy:moss_king"],
        "silver_moon": got["trophy:silver_moon"],
        "winter_heart": recolor(got["trophy:purple_a"], (0.7, 0.95), 0.6),     # peixe azul-gelo
        "guardian": recolor(got["trophy:purple_b"], (0.7, 0.95), 0.3, 0.9),    # peixe verde
        "dream": got["trophy:purple_c"],
        "tournament": got["trophy:cup_a"],
    }
    n = 0
    for name, img in got.items():
        if name.startswith("trophy:") or name in SKIP:
            continue
        path = os.path.join(SPR, name + ".png")
        fit_like(img, path).save(path)
        n += 1
        # construções e máquinas também têm o ícone da mochila
        if name.startswith(C) and not name.startswith(C + "icon_") and not name.startswith(C + "grass"):
            ip = os.path.join(SPR, C + "icon_" + name[len(C):] + ".png")
            if os.path.exists(ip):
                icon(img).save(ip)
    for k, img in trophies.items():
        for path in (os.path.join(SPR, C + "trophy_%s.png" % k), os.path.join(SPR, C + "icon_trophy_%s.png" % k)):
            fit_like(img, path).save(path) if "icon_" not in path else icon(img).save(path)
        n += 1
    # comedouro cheio (a folha trouxe uma cerca no lugar): o comedouro novo com um monte de feno por cima
    feeder = Image.open(os.path.join(SPR, C + "feeder.png")).convert("RGBA")
    full = feeder.copy()
    x0, y0, x1, y1 = feeder.getbbox()
    rng = __import__("random").Random(4)
    px = full.load()
    hay = [(226, 190, 92, 255), (240, 211, 120, 255), (196, 152, 64, 255)]
    top = y0 + 2
    for x in range(x0 + 2, x1 - 2):
        rise = int(4 * (1 - abs((x - (x0 + x1) / 2) / ((x1 - x0) / 2)) ** 2)) + rng.randint(0, 1)
        for y in range(max(0, top - rise), top + 2):
            px[x, y] = hay[rng.randrange(3)]
        px[x, max(0, top - rise - 1)] = (120, 86, 40, 255)        # contorno
    full.save(os.path.join(SPR, C + "feeder_full.png"))
    print("importadas:", n, "peças")
