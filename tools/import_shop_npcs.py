#!/usr/bin/env python3
"""
Donos das lojas da cidade (assets/source/npcs_shops.png, fundo verde: 6 personagens, 6 vistas cada,
em 3 linhas com 2 personagens por linha). Para cada um:
  assets/sprites/npc_<id>.png        2 quadros de 64x64 (de frente, parado e "respirando"), como os outros
  assets/sprites/npcs/<id>_views.png as 6 vistas em 64x64 (frente, 3/4, lado, costas...) para quando andarem
Uso: python3 tools/import_shop_npcs.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from import_hud import key_flood  # noqa: E402
from import_animals import components  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "npcs_shops.png")
OUT = os.path.join(ROOT, "assets", "sprites")
FRAME = 64
HEIGHT = 56            # altura do personagem no quadro (como os moradores antigos)
# (linha, metade) -> id
WHO = {(0, 0): "shiitake", (0, 1): "girassol", (1, 0): "cometa", (1, 1): "folha", (2, 0): "bigode", (2, 1): "brioche"}


def fit(p, s):
    small = p.resize((max(1, round(p.width * s)), max(1, round(p.height * s))), Image.LANCZOS)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
    return small


def frame_of(p, s, squash=0):
    small = fit(p, s)
    if squash:
        small = small.resize((small.width, small.height - squash), Image.NEAREST)
    f = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    f.alpha_composite(small, ((FRAME - small.width) // 2, FRAME - 2 - small.height))
    return f


if __name__ == "__main__":
    os.makedirs(os.path.join(OUT, "npcs"), exist_ok=True)
    im = key_flood(Image.open(SRC).convert("RGBA"))
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and g > 190 and r < 90 and b < 90:
                px[x, y] = (0, 0, 0, 0)
    comps = [c for c in components(im) if c["area"] > 2000]
    rows = sorted({c["bbox"][1] // 300 for c in comps})
    for ri, row in enumerate(rows):
        for half in (0, 1):
            figs = [c for c in comps if c["bbox"][1] // 300 == row and (c["bbox"][0] >= im.width // 2) == bool(half)]
            figs.sort(key=lambda c: c["bbox"][0])
            assert len(figs) == 6, (row, half, len(figs))
            pid = WHO[(ri, half)]
            crops = [im.crop(c["bbox"]) for c in figs]
            s = HEIGHT / max(c.height for c in crops)
            sheet = Image.new("RGBA", (FRAME * 2, FRAME), (0, 0, 0, 0))
            sheet.alpha_composite(frame_of(crops[0], s), (0, 0))
            sheet.alpha_composite(frame_of(crops[0], s, squash=1), (FRAME, 0))
            sheet.save(os.path.join(OUT, "npc_%s.png" % pid))
            views = Image.new("RGBA", (FRAME * 6, FRAME), (0, 0, 0, 0))
            for i, c in enumerate(crops):
                views.alpha_composite(frame_of(c, s), (i * FRAME, 0))
            views.save(os.path.join(OUT, "npcs", "%s_views.png" % pid))
            print(pid, "ok")
