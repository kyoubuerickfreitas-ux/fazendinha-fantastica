#!/usr/bin/env python3
"""
Importa os personagens-cogumelo (fundo xadrez "desenhado") e gera assets/sprites/npc_<id>.png
no formato do jogo: 2 quadros de 64x64 (parado e "respirando").

assets/source/npcs_mushroom.webp: Fungo, mago (Mestre Estrelo), Pipoca e Vó Raiz, 2 colunas x 5 linhas cada
assets/source/npc_carpa.webp:     Dona Carpa, 8 colunas x 4 linhas de poses (a pele veio azulada: corrigida)
Usamos a primeira pose (de frente). Uso: python3 tools/import_npcs.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw  # noqa: E402
from import_animals import components, remove_fake_checker  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "npcs_mushroom.webp")
OUT = os.path.join(ROOT, "assets", "sprites")
FRAME = 64
HEIGHT = 54                       # altura do personagem dentro do quadro
# personagem -> (folha, quantos blocos lado a lado, bloco, corrigir pele azulada?)
WHO = {
    "fungo": ("npcs_mushroom.webp", 4, 0, False),
    "estrelo": ("npcs_mushroom.webp", 4, 1, False),
    "pipoca": ("npcs_mushroom.webp", 4, 2, False),
    "raiz": ("npcs_mushroom.webp", 4, 3, False),
    "carpa": ("npc_carpa.webp", 1, 0, True),
}


def segment(im):
    comps = components(im)
    big = max(c["area"] for c in comps)
    main = [c for c in comps if c["area"] >= big * 0.2]
    small = [c for c in comps if 30 <= c["area"] < big * 0.2]
    for s in small:
        sx, sy = (s["bbox"][0] + s["bbox"][2]) / 2, (s["bbox"][1] + s["bbox"][3]) / 2

        def dist(c):
            b = c["bbox"]
            return max(b[0] - sx, 0, sx - b[2]) ** 2 + max(b[1] - sy, 0, sy - b[3]) ** 2
        m = min(main, key=dist)
        if dist(m) < 30 ** 2:
            m["pts"] += s["pts"]
            b = m["bbox"]
            m["bbox"] = [min(b[0], s["bbox"][0]), min(b[1], s["bbox"][1]), max(b[2], s["bbox"][2]), max(b[3], s["bbox"][3])]
    return main


def crop(im, c):
    x0, y0, x1, y1 = c["bbox"]
    out = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    src, dst = im.load(), out.load()
    for x, y in c["pts"]:
        dst[x - x0, y - y0] = src[x, y]
    return out


def shrink(img, h):
    s = h / img.height
    w = max(1, round(img.width * s))
    small = img.resize((w, h), Image.LANCZOS)
    px = small.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 120 else (0, 0, 0, 0)
    return small


def neutral_skin(img):
    """A pele dos cogumelos é preta neutra; tons azul-marinho bem escuros (rosto, mãos, contorno)
    viram preto neutro. Azuis mais claros (roupa, cabelo, enfeites) ficam como estão."""
    import colorsys
    out = img.copy()
    px = out.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if v <= 0.22 and 0.5 <= h <= 0.78:
                r2, g2, b2 = colorsys.hsv_to_rgb(0.08, 0.12, v * 0.8)
                px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return out


def frame(char, squash=0):
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((FRAME / 2 - 14, FRAME - 9, FRAME / 2 + 14, FRAME - 3), fill=(30, 20, 10, 70))   # sombra
    c = char if squash == 0 else char.resize((char.width, char.height - squash), Image.NEAREST)
    img.alpha_composite(c, ((FRAME - c.width) // 2, FRAME - 5 - c.height))
    return img


if __name__ == "__main__":
    sheets = {}
    for name, (src, blocks, block, fix_skin) in WHO.items():
        if src not in sheets:
            im = remove_fake_checker(Image.open(os.path.join(ROOT, "assets", "source", src)).convert("RGBA"))
            sheets[src] = (im, segment(im))
        im, comps = sheets[src]
        bw = im.width / blocks
        x_lo, x_hi = block * bw, (block + 1) * bw
        mine = [c for c in comps if x_lo <= (c["bbox"][0] + c["bbox"][2]) / 2 < x_hi]
        mine.sort(key=lambda c: (round(c["bbox"][1] / 100), c["bbox"][0]))
        pose = crop(im, mine[0])
        if fix_skin:
            pose = neutral_skin(pose)
        pose = shrink(pose, HEIGHT)
        sheet = Image.new("RGBA", (FRAME * 2, FRAME), (0, 0, 0, 0))
        sheet.alpha_composite(frame(pose), (0, 0))
        sheet.alpha_composite(frame(pose, 1), (FRAME, 0))      # "respirando": 1 pixel mais baixo
        sheet.save(os.path.join(OUT, "npc_%s.png" % name))
        print(name, "ok", pose.size)
