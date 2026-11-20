#!/usr/bin/env python3
"""
Recorta os estágios de crescimento das plantas de assets/source/crop_stages.webp
(2 blocos de 11 linhas x 5 estágios, fundo preto) e gera assets/sprites/crops/<id>.png
no formato do jogo: tira horizontal de quadros de 32 x altura (32 ou 48), base alinhada embaixo.

Plantas com 3 estágios (4 quadros) usam os estágios 0, 1, 3 e 4 da arte.
Uso: python3 tools/import_crops.py  (imprime a altura de cada planta: confira sprite_height em crops_table.py)
"""
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from crops_table import CROPS  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "crop_stages.webp")
OUT = os.path.join(ROOT, "assets", "sprites", "crops")

# linhas da folha, de cima para baixo
LEFT = ["apple", "pear", "grape", "strawberry", "blueberry", "cherry", "watermelon", "melon", "pineapple", "coconut", "banana"]
RIGHT = ["orange", "lemon", "raspberry", "plum", "peach", "pomegranate", "carrot", "radish", "beet", "tomato", "mushroom"]
# faixas x das 5 colunas de cada bloco
COLS = [[(30, 150), (150, 262), (262, 416), (416, 540), (540, 712)],
        [(798, 915), (915, 1035), (1035, 1172), (1172, 1312), (1312, 1470)]]
FRAME_W = 32


def bands(prof, minlen=6, gap=1):
    out, start, empty, end = [], None, 0, 0
    for i, v in enumerate(prof):
        if v:
            if start is None:
                start = i
            empty, end = 0, i
        elif start is not None:
            empty += 1
            if empty > gap:
                if end - start >= minlen:
                    out.append((start, end))
                start = None
    if start is not None and end - start >= minlen:
        out.append((start, end))
    return out


def components(mask):
    h, w = mask.shape
    lab = np.zeros((h, w), int)
    comps = []
    for y in range(h):
        for x in range(w):
            if mask[y, x] and not lab[y, x]:
                n = len(comps) + 1
                q = deque([(y, x)])
                lab[y, x] = n
                pts = []
                while q:
                    cy, cx = q.popleft()
                    pts.append((cy, cx))
                    for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                            lab[ny, nx] = n
                            q.append((ny, nx))
                ys = [p[0] for p in pts]
                xs = [p[1] for p in pts]
                comps.append({"n": n, "pts": pts, "box": (min(xs), min(ys), max(xs), max(ys))})
    return lab, comps


def cut_cells(rgb, mask):
    """Devolve {nome: [5 imagens RGBA recortadas]}"""
    out = {}
    for names, cols in ((LEFT, COLS[0]), (RIGHT, COLS[1])):
        # base de cada linha = fim do montinho na coluna da semente
        seed_col = mask[:, cols[0][0]:cols[0][1]]
        bottoms = [b for a, b in bands(seed_col.sum(1) > 1)]
        assert len(bottoms) == len(names), (len(bottoms), names)
        for name in names:
            out[name] = []
        for x0, x1 in cols:
            taken = np.zeros_like(mask)       # pixels já usados pela linha de cima nesta coluna
            for i, name in enumerate(names):
                bottom = bottoms[i] + 4
                top = max(0, bottoms[i] - 150)
                prev = (bottoms[i - 1] + 4 - top) if i > 0 else -999
                sub = mask[top:bottom, x0:x1] & ~taken[top:bottom, x0:x1]
                lab, comps = components(sub)
                base_y = sub.shape[0] - 30
                # partes que encostam na faixa do montinho (base) desta linha
                main = [c for c in comps if c["box"][3] >= base_y and len(c["pts"]) > 30]
                if not main:
                    raise SystemExit(f"nada encontrado para {name} em x={x0}")
                bx0 = min(c["box"][0] for c in main)
                bx1 = max(c["box"][2] for c in main)
                keep = {c["n"] for c in main}
                # pedaços soltos (folhas, frutas, pétalas) em cima da planta, abaixo do montinho de cima
                for c in comps:
                    if c["n"] in keep or len(c["pts"]) < 6:
                        continue
                    cx0, cy0, cx1, cy1 = c["box"]
                    if cx0 >= bx0 - 6 and cx1 <= bx1 + 6 and cy1 > prev + 8:
                        keep.add(c["n"])
                sel = np.isin(lab, list(keep))
                taken[top:bottom, x0:x1] |= sel
                ys, xs = np.nonzero(sel)
                y0, y1, xa, xb = ys.min(), ys.max(), xs.min(), xs.max()
                img = np.zeros((y1 - y0 + 1, xb - xa + 1, 4), np.uint8)
                region = rgb[top + y0:top + y1 + 1, x0 + xa:x0 + xb + 1]
                img[..., :3] = region
                img[..., 3] = np.where(sel[y0:y1 + 1, xa:xb + 1], 255, 0)
                out[name].append(Image.fromarray(img, "RGBA"))
    return out


def shrink(img, s):
    w, h = max(1, round(img.width * s)), max(1, round(img.height * s))
    small = img.resize((w, h), Image.LANCZOS)
    px = small.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 120 else (0, 0, 0, 0)
    return small


if __name__ == "__main__":
    rgb = np.array(Image.open(SRC).convert("RGB"))
    mask = rgb.astype(int).sum(2) > 60
    cells = cut_cells(rgb, mask)
    table = {c["id"]: c for c in CROPS}
    for name, frames in cells.items():
        if name not in table:
            continue
        n = len(table[name]["stage_days"]) + 1
        pick = [0, 1, 2, 3, 4] if n == 5 else [0, 1, 3, 4]
        frames = [frames[i] for i in pick]
        # mesma escala para todos os estágios: a planta cresce de verdade
        s = min((FRAME_W - 2) / max(f.width for f in frames), 46 / max(f.height for f in frames), 0.4)
        small = [shrink(f, s) for f in frames]
        h = 32 if max(f.height for f in small) <= 31 else 48
        strip = Image.new("RGBA", (FRAME_W * n, h), (0, 0, 0, 0))
        for i, f in enumerate(small):
            strip.alpha_composite(f, (i * FRAME_W + (FRAME_W - f.width) // 2, h - f.height))
        strip.save(os.path.join(OUT, name + ".png"))
        want = table[name].get("sprite_height", 32)
        print(f"{name}: {n} quadros, altura {h}" + ("" if h == want else f"  <-- ajuste sprite_height={h}"))
