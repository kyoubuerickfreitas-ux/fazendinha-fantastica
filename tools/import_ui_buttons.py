#!/usr/bin/env python3
"""
Ícones dos botões redondos da HUD (folhas de fundo verde em assets/source/, peças da esquerda para a direita):
  ui_buttons.png   mochila e álbum (Livro de Pesca)
  ui_buttons_2.png mão (interagir) e pé (correr)
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


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for sheet, names in SHEETS.items():
        import_sheet(os.path.join(ROOT, "assets", "source", sheet), names)
