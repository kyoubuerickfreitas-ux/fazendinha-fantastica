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
import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402
from import_hud import key_flood  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "tractor_iso.png")
OUT = os.path.join(ROOT, "assets", "app_icon")
ICON = (1262, 12, 1520, 286)      # moldura inteira (com as folhinhas)
INNER = (1299, 66, 1489, 258)     # a cena dentro da moldura (sem a borda)
FACE = (1442, 166)                # centro do rosto do porquinho
BG_COLOR = (104, 150, 66, 255)    # verde do fundo do ícone adaptável
BG_SIZE = 220                     # lado do recorte do fundo (o miolo visível fica ~147 px em volta do rosto)

if __name__ == "__main__":
    full = key_flood(Image.open(SRC).convert("RGBA"))
    icon = full.crop(ICON)
    icon = icon.crop(icon.getbbox())
    side = max(icon.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.alpha_composite(icon, ((side - icon.width) // 2, (side - icon.height) // 2))
    sq.resize((512, 512), Image.LANCZOS).save(os.path.join(ROOT, "icon.png"))
    sq.resize((192, 192), Image.LANCZOS).save(os.path.join(OUT, "icon_192.png"))
    # ícone adaptável: a imagem INTEIRA (moldura e folhas) no primeiro plano, dentro da área que o Android
    # nunca corta (66 de 108); o fundo tem a cor da grama de trás, para não aparecer borda.
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    inner = round(432 * 64 / 108)
    fg.alpha_composite(sq.resize((inner, inner), Image.LANCZOS), ((432 - inner) // 2, (432 - inner) // 2))
    fg.save(os.path.join(OUT, "foreground.png"))
    Image.new("RGBA", (432, 432), BG_COLOR).save(os.path.join(OUT, "background.png"))
    print("ícone do app atualizado")
