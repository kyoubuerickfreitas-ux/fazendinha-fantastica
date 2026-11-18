#!/usr/bin/env python3
"""
Converte a folha do personagem (assets/source/character/) para o formato do jogo.

Origem: walk.png 576x384 (6 quadros x 4 linhas de 96x96) e idle.png 96x384 (1 x 4).
Linhas na origem: 0 baixo, 1 direita, 2 cima, 3 esquerda.

Saída: assets/sprites/player.png 448x256 = 7 colunas x 4 linhas de 64x64.
Linhas: 0 baixo, 1 esquerda, 2 direita, 3 cima. Coluna 0 = parado, 1..6 = caminhada.
O personagem é reduzido para 60% (mesma escala do Forest Map Kit), com os pés em y=58.

Uso: python3 tools/import_character.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "character")
OUT = os.path.join(ROOT, "assets", "sprites", "player.png")

SRC_CELL = 96
CELL = 64
SCALE = 0.6
FEET_Y = 58
SRC_FEET_Y = 79  # pés do personagem dentro do quadro de 96 px
ROW_MAP = {0: 0, 1: 3, 2: 1, 3: 2}  # linha no jogo -> linha na origem


def shrink(cell):
    size = round(SRC_CELL * SCALE)
    im = cell.resize((size, size), Image.LANCZOS)
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
    return im


def place(sheet, cell_img, col, row):
    """Posição fixa (sem recentralizar por quadro) para a animação não tremer."""
    ox = col * CELL + (CELL - cell_img.width) // 2
    oy = row * CELL + FEET_Y - round(SRC_FEET_Y * SCALE)
    sheet.alpha_composite(cell_img, (ox, oy))


def main():
    walk = Image.open(os.path.join(SRC, "walk.png")).convert("RGBA")
    idle = Image.open(os.path.join(SRC, "idle.png")).convert("RGBA")
    sheet = Image.new("RGBA", (CELL * 7, CELL * 4), (0, 0, 0, 0))
    for row, src_row in ROW_MAP.items():
        y = src_row * SRC_CELL
        place(sheet, shrink(idle.crop((0, y, SRC_CELL, y + SRC_CELL))), 0, row)
        for f in range(6):
            x = f * SRC_CELL
            place(sheet, shrink(walk.crop((x, y, x + SRC_CELL, y + SRC_CELL))), f + 1, row)
    sheet.save(OUT)
    print("ok:", OUT, sheet.size)


if __name__ == "__main__":
    main()
