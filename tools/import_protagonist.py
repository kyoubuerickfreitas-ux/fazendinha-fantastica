#!/usr/bin/env python3
"""
Monta a folha do jogador (assets/sprites/player.png) a partir do protagonista do PixelLab.

Origem (assets/source/protagonist/, quadros 256x256 já com o fundo limpo):
  Idle/rotations/{south,east,north}.png   pose parada
  Walk/{south,east,north}/0..7.png        caminhada, 8 quadros
A esquerda (west) é o espelho da direita.

Saída: 9 colunas x 4 linhas de 64x64.
Linhas: 0 baixo, 1 esquerda, 2 direita, 3 cima. Coluna 0 = parado, 1..8 = caminhada.
O personagem fica com TARGET_H px de altura e os pés em y=58 em todos os quadros
(a mesma escala e o mesmo encaixe para todos, então a animação não treme).

Uso: python3 tools/import_protagonist.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "protagonist")
OUT = os.path.join(ROOT, "assets", "sprites", "player.png")
CELL = 64
FEET_Y = 58
TARGET_H = 48
WALK_FRAMES = 8


def load(path):
    return Image.open(os.path.join(SRC, path)).convert("RGBA")


def frames_for(direction):
    idle = load(f"Idle/rotations/{direction}.png")
    walk = [load(f"Walk/{direction}/{i}.png") for i in range(WALK_FRAMES)]
    return [idle] + walk


def main():
    rows = {"south": frames_for("south"), "east": frames_for("east"), "north": frames_for("north")}
    rows["west"] = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in rows["east"]]

    ref = rows["south"][0].getbbox()        # pose parada de frente define escala e linha dos pés
    scale = TARGET_H / (ref[3] - ref[1])
    feet = ref[3]
    canvas = round(256 * scale)
    ox_base = (CELL - canvas) // 2
    oy_base = FEET_Y - round(feet * scale)
    assert 0 <= ox_base and 0 <= oy_base and canvas <= CELL, "personagem não cabe no quadro de 64x64"

    sheet = Image.new("RGBA", (CELL * (1 + WALK_FRAMES), CELL * 4), (0, 0, 0, 0))
    for r, d in enumerate(["south", "west", "east", "north"]):
        for c, f in enumerate(rows[d]):
            small = f.resize((canvas, canvas), Image.LANCZOS)
            px = small.load()
            for y in range(canvas):
                for x in range(canvas):
                    rr, gg, bb, a = px[x, y]
                    px[x, y] = (rr, gg, bb, 255) if a >= 110 else (0, 0, 0, 0)
            sheet.alpha_composite(small, (c * CELL + ox_base, r * CELL + oy_base))
    sheet.save(OUT)
    print("ok:", OUT, sheet.size, f"escala {scale:.3f}")


if __name__ == "__main__":
    main()
