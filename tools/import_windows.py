#!/usr/bin/env python3
"""
Visual das janelas a partir do modelo assets/source/ui_windows.png (fundo verde), usando a janela de Opções:

  assets/sprites/ui/win/frame.png      moldura esticável (pergaminho + madeira + folhas), sem cabeçalho nem conteúdo
  assets/sprites/ui/win/title.png      plaquinha creme do título
  assets/sprites/ui/win/close.png      botão X de madeira
  assets/sprites/ui/win/button.png     botão de madeira vazio;  button_red.png  o vermelho (ações perigosas)
  assets/sprites/ui/win/knob.png       bolinha do controle deslizante

As margens de 9 fatias (em px da imagem salva) ficam em MARGINS, copiadas em scripts/ui/ui_style.gd.
Uso: python3 tools/import_windows.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from import_hud import key_flood, erase_h  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "ui_windows.png")
OUT = os.path.join(ROOT, "assets", "sprites", "ui", "win")
OPT = (1095, 55, 1525, 700)        # janela de Opções no modelo
SCALE = 0.4                        # a tela do jogo é 640x360: tudo sai menor


def cut_outside(im):
    """Tira tudo o que está fora do contorno escuro da peça (enchendo a partir da borda da imagem)."""
    from collections import deque
    px = im.load()
    w, h = im.size
    seen = set()
    q = deque([(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)])
    while q:
        x, y = q.popleft()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        r, g, b, a = px[x, y]
        if a and (r + g + b) / 3 < 70:
            continue                     # contorno: para aqui
        px[x, y] = (0, 0, 0, 0)
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return im


def shrink(im, s=SCALE):
    return im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    full = key_flood(Image.open(SRC).convert("RGBA"))
    win = full.crop(OPT)

    # peças antes de limpar a janela
    title = win.crop((100, 25, 266, 96))
    erase_h(title, (14, 10, 152, 62))                         # tira "Opções"
    # o lado esquerdo da placa fica atrás da engrenagem: usa o direito espelhado
    half = title.crop((title.width // 2, 0, title.width, title.height))
    title = Image.new("RGBA", (half.width * 2, half.height), (0, 0, 0, 0))
    title.paste(half.transpose(Image.FLIP_LEFT_RIGHT), (0, 0))
    title.paste(half, (half.width, 0))
    close = win.crop((343, 24, 408, 98))
    plank = win.crop((52, 538, 382, 600))                     # "Sair para o menu"
    erase_h(plank, (14, 10, 316, 52))
    red = win.crop((52, 472, 382, 536))                       # "Novo jogo"
    erase_h(red, (14, 9, 316, 54))
    knob = win.crop((262, 133, 292, 166))

    # moldura: viga de cima sem o ícone, a plaquinha e o X (copia o trecho liso da viga)
    beam = win.crop((276, 20, 334, 100))
    for x in range(16, 410, beam.width):
        piece = beam.crop((0, 0, min(beam.width, 410 - x), beam.height))
        win.paste(piece, (x, 20))
    # a coroa de folhas do ícone (acima da viga) sai junto
    for y in range(0, 22):
        for x in range(10, 130):
            win.putpixel((x, y), (0, 0, 0, 0))
    # miolo: faixa de pergaminho limpo (entre os controles e os botões) repetida para baixo
    strip = win.crop((26, 236, 404, 262))
    for y in range(100, 601, strip.height):
        piece = strip.crop((0, 0, strip.width, min(strip.height, 601 - y)))
        win.paste(piece, (26, y))

    shrink(win).save(os.path.join(OUT, "frame.png"))
    for im in (close, plank, red, knob):
        cut_outside(im)
    # a placa do título: contorno claro demais para o "cut_outside"; recorta com cantos arredondados
    from PIL import ImageDraw
    m = Image.new("L", title.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((1, 3, title.width - 2, title.height - 4), radius=14, fill=255)
    clear = Image.new("RGBA", title.size, (0, 0, 0, 0))
    clear.paste(title, (0, 0), m)
    title = clear
    shrink(title).save(os.path.join(OUT, "title.png"))
    shrink(close).save(os.path.join(OUT, "close.png"))
    shrink(plank).save(os.path.join(OUT, "button.png"))
    shrink(red).save(os.path.join(OUT, "button_red.png"))
    shrink(knob, 0.5).save(os.path.join(OUT, "knob.png"))
    for n in ("frame", "title", "close", "button", "button_red", "knob"):
        print(n, Image.open(os.path.join(OUT, n + ".png")).size)
