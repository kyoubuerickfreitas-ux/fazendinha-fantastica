#!/usr/bin/env python3
"""
Ícones dos botões redondos da HUD (folhas de fundo verde em assets/source/, peças da esquerda para a direita):
  ui_buttons.png   mochila e álbum (Livro de Pesca)
  ui_buttons_2.png mão (interagir) e pé (correr)
  ui_windows.png   botão quadrado da engrenagem (Opções) e a engrenagem sozinha
Saída: assets/sprites/ui/<nome>.png em 64x64 (o botão desenha em 32x32 na tela de 640x360, que no celular
fica 1:1 com os pixels). Uso: python3 tools/import_ui_buttons.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from import_animals import components  # noqa: E402
from import_props_sheet import key_green, crop  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEETS = {"ui_buttons.png": ["backpack", "book"], "ui_buttons_2.png": ["hand", "foot"]}
OUT = os.path.join(ROOT, "assets", "sprites", "ui")
SIZE = 64

def import_sheet(src, names):
    im = key_green(Image.open(src).convert("RGBA"))
    comps = sorted([c for c in components(im) if c["area"] > 5000], key=lambda c: c["bbox"][0])
    assert len(comps) == len(names), len(comps)
    for name, c in zip(names, comps):
        p = crop(im, c)
        s = (SIZE - 2) / max(p.size)
        small = p.resize((max(1, round(p.width * s)), max(1, round(p.height * s))), Image.LANCZOS)
        out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        out.alpha_composite(small, ((SIZE - small.width) // 2, (SIZE - small.height) // 2))
        out.save(os.path.join(OUT, name + ".png"))
        print("ok:", name)


def import_gear():
    """Engrenagem: pixels cinza do botão quadrado de engrenagem + o contorno escuro em volta."""
    import colorsys
    import numpy as np
    src = Image.open(os.path.join(ROOT, "assets", "source", "ui_windows.png")).convert("RGBA").crop((670, 648, 795, 762))
    a = np.array(src).astype(int)
    h, w = a.shape[:2]
    gray = np.zeros((h, w), bool)
    dark = np.zeros((h, w), bool)
    for y in range(h):
        for x in range(w):
            r, g, b, _ = a[y, x]
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            gray[y, x] = ss < 0.32 and 0.45 < vv < 0.98
            dark[y, x] = vv < 0.25
    keep = gray.copy()
    for _ in range(4):                     # contorno escuro colado no cinza
        p = np.pad(keep, 1)
        near = p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
        keep |= near & dark
    out = np.zeros_like(a)
    out[keep] = a[keep]
    img = Image.fromarray(out.astype("uint8"))
    img = img.crop(img.getbbox())
    s = (SIZE - 2) / max(img.size)
    small = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
    o = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    o.alpha_composite(small, ((SIZE - small.width) // 2, (SIZE - small.height) // 2))
    o.save(os.path.join(OUT, "gear.png"))
    # o botão quadrado inteiro (madeira + engrenagem), usado no botão de Opções
    from import_hud import key_flood
    sq = key_flood(Image.open(os.path.join(ROOT, "assets", "source", "ui_windows.png")).convert("RGBA").crop((670, 645, 793, 761)))
    sq = sq.crop(sq.getbbox())
    s2 = (SIZE - 2) / max(sq.size)
    small = sq.resize((round(sq.width * s2), round(sq.height * s2)), Image.LANCZOS)
    o = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    o.alpha_composite(small, ((SIZE - small.width) // 2, (SIZE - small.height) // 2))
    o.save(os.path.join(OUT, "gear_button.png"))
    print("ok: gear")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for sheet, names in SHEETS.items():
        import_sheet(os.path.join(ROOT, "assets", "source", sheet), names)
    import_gear()
