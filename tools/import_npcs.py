#!/usr/bin/env python3
"""
Importa os personagens-cogumelo de assets/source/npcs_mushroom.webp (fundo xadrez "desenhado")
e gera assets/sprites/npc_<id>.png no formato do jogo: 2 quadros de 64x64 (parado e "respirando").

Folha: 4 personagens (Fungo, mago, Pipoca, Vó Raiz) em 2 colunas x 5 linhas de poses cada.
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
# personagem -> (coluna do bloco 0..3, pose escolhida: índice na ordem de leitura do bloco)
WHO = {"fungo": 0, "estrelo": 1, "pipoca": 2, "raiz": 3}


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


def frame(char, squash=0):
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((FRAME / 2 - 14, FRAME - 9, FRAME / 2 + 14, FRAME - 3), fill=(30, 20, 10, 70))   # sombra
    c = char if squash == 0 else char.resize((char.width, char.height - squash), Image.NEAREST)
    img.alpha_composite(c, ((FRAME - c.width) // 2, FRAME - 5 - c.height))
    return img


if __name__ == "__main__":
    im = remove_fake_checker(Image.open(SRC).convert("RGBA"))
    comps = segment(im)
    for name, block in WHO.items():
        x_lo, x_hi = block * 384, (block + 1) * 384
        mine = [c for c in comps if x_lo <= (c["bbox"][0] + c["bbox"][2]) / 2 < x_hi]
        mine.sort(key=lambda c: (round(c["bbox"][1] / 100), c["bbox"][0]))
        pose = shrink(crop(im, mine[0]), HEIGHT)
        sheet = Image.new("RGBA", (FRAME * 2, FRAME), (0, 0, 0, 0))
        sheet.alpha_composite(frame(pose), (0, 0))
        sheet.alpha_composite(frame(pose, 1), (FRAME, 0))      # "respirando": 1 pixel mais baixo
        sheet.save(os.path.join(OUT, "npc_%s.png" % name))
        print(name, "ok", pose.size)
