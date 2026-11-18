#!/usr/bin/env python3
"""
Monta as spritesheets dos animais a partir das folhas originais (assets/source/animals/).

Origem: 4 linhas x 4 quadros, em posições irregulares. Linhas: 0 frente, 1 costas,
2 virado para a esquerda, 3 virado para a direita.
Cada quadro é encontrado sozinho (componentes conectados), reduzido para a escala do jogo
e colocado numa célula de 64x64 com os pés em y=58.

Saída: assets/sprites/animals/<nome>.png (256x256 = 4x4 de 64x64)
Linhas no jogo: 0 baixo, 1 esquerda, 2 direita, 3 cima. Colunas: 4 quadros de caminhada.
A linha "direita" é o espelho da "esquerda" (fica sempre consistente).

Uso: python3 tools/import_animals.py
"""
import os
from collections import deque
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "animals")
OUT = os.path.join(ROOT, "assets", "sprites", "animals")
CELL = 64
FEET_Y = 58

# nome: (arquivo, altura alvo do quadro mais alto em px, fundo xadrez pintado?)
ANIMALS = {
    "moombor": ("moombor.webp", 46, False),
    "fofranca": ("fofranca.png", 40, False),
    "catarrapio": ("catarrapio.png", 32, True),
    "piuplum": ("piuplum.webp", 26, False),
}


def remove_fake_checker(im):
    """Apaga o fundo xadrez claro ligado às bordas (flood fill)."""
    w, h = im.size
    px = im.load()

    def is_bg(p):
        r, g, b, _ = p
        return min(r, g, b) >= 200 and max(r, g, b) - min(r, g, b) <= 18

    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        if not is_bg(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                q.append((nx, ny))
    return im


def components(im, min_alpha=128):
    """Lista de componentes: (área, bbox, conjunto de pixels)."""
    w, h = im.size
    a = im.getchannel("A").load()
    lab = [0] * (w * h)
    comps = []
    for y0 in range(h):
        for x0 in range(w):
            if a[x0, y0] < min_alpha or lab[y0 * w + x0]:
                continue
            cid = len(comps) + 1
            pts = []
            q = deque([(x0, y0)])
            lab[y0 * w + x0] = cid
            while q:
                x, y = q.popleft()
                pts.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not lab[ny * w + nx] and a[nx, ny] >= min_alpha:
                        lab[ny * w + nx] = cid
                        q.append((nx, ny))
            xs = [p[0] for p in pts]
            ys = [p[1] for p in pts]
            comps.append({"area": len(pts), "bbox": [min(xs), min(ys), max(xs) + 1, max(ys) + 1], "pts": pts})
    return comps


def find_frames(im):
    comps = components(im)
    big = max(c["area"] for c in comps)
    main = [c for c in comps if c["area"] >= big * 0.25]
    small = [c for c in comps if big * 0.002 <= c["area"] < big * 0.25]
    # pedacinhos soltos (folha, rabo) vão para o quadro mais próximo
    for s in small:
        sx = (s["bbox"][0] + s["bbox"][2]) / 2
        sy = (s["bbox"][1] + s["bbox"][3]) / 2

        def dist(c):
            b = c["bbox"]
            dx = max(b[0] - sx, 0, sx - b[2])
            dy = max(b[1] - sy, 0, sy - b[3])
            return dx * dx + dy * dy
        m = min(main, key=dist)
        if dist(m) < 40 ** 2:
            m["pts"] += s["pts"]
            b = m["bbox"]
            m["bbox"] = [min(b[0], s["bbox"][0]), min(b[1], s["bbox"][1]), max(b[2], s["bbox"][2]), max(b[3], s["bbox"][3])]
    assert len(main) == 16, f"esperava 16 quadros, achei {len(main)}"
    main.sort(key=lambda c: (c["bbox"][1] + c["bbox"][3]) / 2)
    rows = [sorted(main[i * 4:(i + 1) * 4], key=lambda c: c["bbox"][0]) for i in range(4)]
    return rows


def cut(im, comp):
    x0, y0, x1, y1 = comp["bbox"]
    out = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    src = im.load()
    dst = out.load()
    for x, y in comp["pts"]:
        r, g, b, a = src[x, y]
        dst[x - x0, y - y0] = (r, g, b, 255)
    return out


def shrink(img, scale):
    w = max(1, round(img.width * scale))
    h = max(1, round(img.height * scale))
    small = img.resize((w, h), Image.LANCZOS)
    px = small.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 120 else (0, 0, 0, 0)
    return small


def build(name, filename, target_h, checker):
    im = Image.open(os.path.join(SRC, filename)).convert("RGBA")
    if checker:
        im = remove_fake_checker(im)
    rows = find_frames(im)
    frames = [[cut(im, c) for c in row] for row in rows]
    tallest = max(f.height for row in frames for f in row)
    scale = target_h / tallest

    down, up, left = frames[0], frames[1], frames[2]
    right = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in left]
    sheet = Image.new("RGBA", (CELL * 4, CELL * 4), (0, 0, 0, 0))
    for r, row in enumerate([down, left, right, up]):
        for c, f in enumerate(row):
            s = shrink(f, scale)
            ox = c * CELL + (CELL - s.width) // 2
            oy = r * CELL + FEET_Y - s.height
            sheet.alpha_composite(s, (ox, oy))
    sheet.save(os.path.join(OUT, name + ".png"))
    print(f"{name:11s} escala {scale:.3f}  quadro mais alto {tallest}px -> {target_h}px")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, (fn, h, chk) in ANIMALS.items():
        build(name, fn, h, chk)
