#!/usr/bin/env python3
"""
Estágios de crescimento da folha nova (assets/source/crop_stages_2.png, fundo verde): frutas, legumes e flores.
Gera assets/sprites/crops/<id>.png (tira de quadros de 32 x 32/48, como tools/import_crops.py) e o ícone do
produto assets/sprites/crops/icons/<id>.png (último estágio), usado quando a planta não tem ícone HD.

Rode DEPOIS de tools/import_crops.py (esta folha substitui a arte daquelas plantas).
Se a planta tem menos estágios no jogo que na arte, os quadros são escolhidos espaçados (o 1º e o último sempre).
Uso: python3 tools/import_crops2.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from import_hud import key_flood  # noqa: E402
from import_animals import components  # noqa: E402
from crops_table import CROPS  # noqa: E402
from import_crops import shrink, FRAME_W  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "crop_stages_2.png")
OUT = os.path.join(ROOT, "assets", "sprites", "crops")

SCALE = 0.19
SCALE_FLOWER = 0.25      # as flores da folha são pequenas: um pouco maiores no jogo

# linhas (faixa y do centro das peças) e, em cada linha, plantas: (id, x inicial, x final, nº de estágios na arte)
ROWS = [
    ((0, 195), [("apple", 0, 790, 6), ("orange", 790, 1536, 5)]),
    ((195, 315), [("grape", 0, 790, 6), ("strawberry", 790, 1536, 5)]),
    ((315, 430), [("blueberry", 0, 790, 6), ("cherry", 790, 1536, 5)]),
    ((430, 560), [("peach", 0, 790, 6), ("pear", 790, 1536, 5)]),
    ((560, 670), [("watermelon", 0, 790, 6), ("pumpkin", 790, 1536, 5)]),
    ((670, 790), [("carrot", 0, 790, 6), ("onion", 790, 1536, 5)]),
    ((790, 905), [("daisy", 0, 445, 5), ("sunflower", 445, 800, 4), ("tulip", 800, 1215, 5), ("pink_tulip", 1215, 1536, 4)]),
    ((905, 1024), [("lavender", 0, 445, 5), ("hydrangea", 445, 800, 4), ("rose", 800, 1215, 5)]),
]


def pieces_in(comps, xr, yr, want):
    """Peças da planta, da esquerda para a direita; junta pedacinhos e separa as que ficaram grudadas."""
    sel = [c for c in comps if xr[0] <= (c["bbox"][0] + c["bbox"][2]) / 2 < xr[1]
           and yr[0] <= (c["bbox"][1] + c["bbox"][3]) / 2 < yr[1]]
    big = [c for c in sel if c["area"] >= 600]
    for s in sel:
        if s in big:
            continue
        cx = (s["bbox"][0] + s["bbox"][2]) / 2
        m = min(big, key=lambda c: abs((c["bbox"][0] + c["bbox"][2]) / 2 - cx))
        m["pts"] += s["pts"]
        b = m["bbox"]
        m["bbox"] = [min(b[0], s["bbox"][0]), min(b[1], s["bbox"][1]), max(b[2], s["bbox"][2]), max(b[3], s["bbox"][3])]
    big.sort(key=lambda c: c["bbox"][0])
    while len(big) < want:          # duas peças grudadas: corta a mais larga ao meio
        w = max(big, key=lambda c: c["bbox"][2] - c["bbox"][0])
        mid = (w["bbox"][0] + w["bbox"][2]) // 2
        a = {"pts": [p for p in w["pts"] if p[0] < mid]}
        b = {"pts": [p for p in w["pts"] if p[0] >= mid]}
        for c in (a, b):
            xs = [p[0] for p in c["pts"]]
            ys = [p[1] for p in c["pts"]]
            c["bbox"] = [min(xs), min(ys), max(xs) + 1, max(ys) + 1]
            c["area"] = len(c["pts"])
        i = big.index(w)
        big[i:i + 1] = [a, b]
    return big


def crop(im, c):
    x0, y0, x1, y1 = c["bbox"]
    out = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    src, dst = im.load(), out.load()
    for x, y in c["pts"]:
        dst[x - x0, y - y0] = src[x, y]
    return out


if __name__ == "__main__":
    os.makedirs(os.path.join(OUT, "icons"), exist_ok=True)
    im = key_flood(Image.open(SRC).convert("RGBA"))
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and g > 190 and r < 90 and b < 90:
                px[x, y] = (0, 0, 0, 0)
    comps = [c for c in components(im) if c["area"] > 40]
    table = {c["id"]: c for c in CROPS}
    for yr, plants in ROWS:
        for pid, x0, x1, m in plants:
            got = pieces_in(comps, (x0, x1), yr, m)
            assert len(got) == m, (pid, len(got))
            frames = [crop(im, c) for c in got]
            if pid not in table:
                print("  (sem ficha em crops_table.py, pulando)", pid)
                continue
            n = len(table[pid]["stage_days"]) + 1
            pick = [round(i * (m - 1) / (n - 1)) for i in range(n)]
            frames = [frames[i] for i in pick]
            # a mesma escala para a folha toda (flores ficam menores que árvores); só reduz mais se não couber
            sc = SCALE_FLOWER if table[pid].get("category") == "flower" else SCALE
            s = min(sc, (FRAME_W - 2) / max(f.width for f in frames), 46 / max(f.height for f in frames))
            small = [shrink(f, s) for f in frames]
            h = 32 if max(f.height for f in small) <= 31 else 48
            strip = Image.new("RGBA", (FRAME_W * n, h), (0, 0, 0, 0))
            for i, f in enumerate(small):
                strip.alpha_composite(f, (i * FRAME_W + (FRAME_W - f.width) // 2, h - f.height))
            strip.save(os.path.join(OUT, pid + ".png"))
            # ícone do produto: a planta pronta, centrada em 32x32
            last = frames[-1]
            k = 30 / max(last.size)
            ic = shrink(last, k)
            icon = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
            icon.alpha_composite(ic, ((32 - ic.width) // 2, (32 - ic.height) // 2))
            icon.save(os.path.join(OUT, "icons", pid + ".png"))
            want = table[pid].get("sprite_height", 32)
            print(f"{pid}: {n} quadros (de {m}), altura {h}" + ("" if h == want else f"  <-- ajuste sprite_height={h}"))
