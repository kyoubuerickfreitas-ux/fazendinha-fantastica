#!/usr/bin/env python3
"""
Ícone do app a partir da arte (canto de cima à direita de assets/source/tractor_iso.png, fundo verde).
Substitui o ícone gerado por tools/make_app_icon.py:
  icon.png                        512x512 (moldura completa, fundo transparente)
  assets/app_icon/icon_192.png    192x192
  assets/app_icon/background.png  432x432 (ícone adaptável: a cena de dentro da moldura, preenchendo tudo;
                                  o Android recorta em círculo/quadrado arredondado)
  assets/app_icon/foreground.png  432x432 (transparente: a cena já está no fundo)
Uso: python3 tools/import_app_icon.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from import_hud import key_flood  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "tractor_iso.png")
OUT = os.path.join(ROOT, "assets", "app_icon")
ICON = (1262, 12, 1520, 286)      # moldura inteira (com as folhinhas)
INNER = (1297, 64, 1495, 262)     # a cena dentro da moldura

if __name__ == "__main__":
    full = key_flood(Image.open(SRC).convert("RGBA"))
    icon = full.crop(ICON)
    icon = icon.crop(icon.getbbox())
    side = max(icon.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.alpha_composite(icon, ((side - icon.width) // 2, (side - icon.height) // 2))
    sq.resize((512, 512), Image.LANCZOS).save(os.path.join(ROOT, "icon.png"))
    sq.resize((192, 192), Image.LANCZOS).save(os.path.join(OUT, "icon_192.png"))
    scene = Image.open(SRC).convert("RGBA").crop(INNER)
    scene.resize((432, 432), Image.LANCZOS).save(os.path.join(OUT, "background.png"))
    Image.new("RGBA", (432, 432), (0, 0, 0, 0)).save(os.path.join(OUT, "foreground.png"))
    print("ícone do app atualizado")
