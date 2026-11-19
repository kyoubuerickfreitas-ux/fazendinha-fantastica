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

O corpo base (assets/source/base_body/) vira player.png e o fazendeiro player_farmer.png,
usando a MESMA escala do protagonista, para roupas e chapéus encaixarem depois.
Se não houver Idle/rotations, a pose parada é o 1º quadro da caminhada.

Uso: python3 tools/import_protagonist.py            (protagonista e corpo base)
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = [
    ("protagonist", "player_farmer.png"),   # fazendeiro de chapéu (skin guardada)
    ("base_body", "player.png"),            # jogador atual: corpo base
]

# Animações de ferramenta do jogador (assets/source/base_body/<Pasta>/<direção>/0..8.png)
# Saída: assets/sprites/player_actions.png, 9 colunas x (5 ferramentas x 4 direções) de 64x64.
# Linha = ferramenta * 4 + direção (0 baixo, 1 esquerda, 2 direita, 3 cima); direção ausente fica vazia.
ACTION_TOOLS = ["Axe", "Hoe", "Pickaxe", "Water", "Scythe"]
ACTION_FRAMES = 9
CELL = 64
FEET_Y = 58
TARGET_H = 48
WALK_FRAMES = 8


def load(src, path):
    return Image.open(os.path.join(ROOT, "assets", "source", src, path)).convert("RGBA")


def frames_for(src, direction):
    walk = [load(src, f"Walk/{direction}/{i}.png") for i in range(WALK_FRAMES)]
    idle_path = os.path.join(ROOT, "assets", "source", src, f"Idle/rotations/{direction}.png")
    idle = load(src, f"Idle/rotations/{direction}.png") if os.path.exists(idle_path) else walk[0]
    return [idle] + walk


# escala e linha dos pés vêm do protagonista (pose parada de frente), para todas as folhas
_ref = load("protagonist", "Idle/rotations/south.png").getbbox()
SCALE = TARGET_H / (_ref[3] - _ref[1])
FEET_SRC = _ref[3]


def build(src, out_name):
    rows = {d: frames_for(src, d) for d in ("south", "east", "north")}
    rows["west"] = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in rows["east"]]
    scale = SCALE
    feet = FEET_SRC
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
    out = os.path.join(ROOT, "assets", "sprites", out_name)
    sheet.save(out)
    print("ok:", out, sheet.size, f"escala {scale:.3f}")


def shrink(f, scale):
    canvas = round(256 * scale)
    small = f.resize((canvas, canvas), Image.LANCZOS)
    px = small.load()
    for y in range(canvas):
        for x in range(canvas):
            rr, gg, bb, a = px[x, y]
            px[x, y] = (rr, gg, bb, 255) if a >= 110 else (0, 0, 0, 0)
    return small


def build_actions():
    base = os.path.join(ROOT, "assets", "source", "base_body")
    canvas = round(256 * SCALE)
    ox = (CELL - canvas) // 2
    oy = FEET_Y - round(FEET_SRC * SCALE)
    sheet = Image.new("RGBA", (CELL * ACTION_FRAMES, CELL * 4 * len(ACTION_TOOLS)), (0, 0, 0, 0))
    found = []
    for t, tool in enumerate(ACTION_TOOLS):
        frames = {}
        for d in ("south", "east", "north"):
            folder = os.path.join(base, tool, d)
            if os.path.isdir(folder):
                frames[d] = [Image.open(os.path.join(folder, f"{i}.png")).convert("RGBA") for i in range(ACTION_FRAMES)]
        if "east" in frames:
            frames["west"] = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in frames["east"]]
        for r, d in enumerate(("south", "west", "east", "north")):
            for c, f in enumerate(frames.get(d, [])):
                sheet.alpha_composite(shrink(f, SCALE), (c * CELL + ox, (t * 4 + r) * CELL + oy))
            if d in frames:
                found.append(f"{tool}/{d}")
    out = os.path.join(ROOT, "assets", "sprites", "player_actions.png")
    sheet.save(out)
    print("ok:", out, sheet.size, "->", ", ".join(found))


if __name__ == "__main__":
    build_actions()
    for src, out_name in SOURCES:
        if os.path.isdir(os.path.join(ROOT, "assets", "source", src, "Walk")):
            build(src, out_name)
