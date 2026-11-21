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
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = [
    ("protagonist", "player_farmer.png"),   # fazendeiro de chapéu (skin guardada)
    ("base_body", "player.png"),            # jogador atual: corpo base
]

# Animações de ferramenta do jogador (assets/source/base_body/<Pasta>/<direção>/0..8.png)
# Saída: assets/sprites/player_actions.png, 9 colunas x (5 ferramentas x 4 direções) de 64x64.
# Linha = ferramenta * 4 + direção (0 baixo, 1 esquerda, 2 direita, 3 cima); direção ausente fica vazia.
ACTION_TOOLS = ["Axe", "Hoe", "Pickaxe", "Water", "Scythe", "Fish"]
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


def _shift(f, dy):
    out = Image.new("RGBA", f.size, (0, 0, 0, 0))
    out.alpha_composite(f, (0, dy))
    return out


def _remove_prop(frames):
    """Tira o objeto desenhado no chão (montinho de terra / pedra) e as pedrinhas que voam dele,
    deixando o personagem e a picareta. O objeto é o que fica separado do corpo no 1º quadro do golpe."""
    import numpy as np
    from import_animals import components
    ref = frames[1]
    comps = sorted(components(ref, 128), key=lambda c: -c["area"])
    body_area = comps[0]["area"]
    h = ref.height
    mask = np.zeros((h, ref.width), bool)
    for c in comps[1:]:
        if c["area"] > 30 and c["bbox"][1] > h * 0.55:
            for x, y in c["pts"]:
                mask[y, x] = True
    for _ in range(3):
        m = np.pad(mask, 1)
        mask = m[1:-1, 1:-1] | m[:-2, 1:-1] | m[2:, 1:-1] | m[1:-1, :-2] | m[1:-1, 2:]
    ra = np.array(ref).astype(int)
    out = [frames[0]]
    for f in frames[1:]:
        a = np.array(f).astype(int)
        same = np.abs(a[:, :, :3] - ra[:, :, :3]).sum(2) < 90
        clear = mask & (same | (ra[:, :, 3] > 0) & (a[:, :, 3] > 0) & (np.abs(a[:, :, :3] - ra[:, :, :3]).sum(2) < 140))
        a[clear] = 0
        img = Image.fromarray(a.astype("uint8")).copy()
        # pedrinhas soltas na metade de baixo (o corpo e a picareta estão ligados entre si)
        px = img.load()
        for c in components(img, 1):
            if c["area"] < body_area * 0.03 and c["bbox"][1] > h * 0.5:
                for x, y in c["pts"]:
                    px[x, y] = (0, 0, 0, 0)
        out.append(img)
    return out


def _remove_mound_south(frames, box=(126, 212, 204, 256)):
    """De frente o montinho de terra fica embaixo do pé direito (encostado): apaga o que é montinho na área
    e põe ali o pé da pose parada (quadro 0)."""
    import numpy as np
    ref = np.array(frames[1]).astype(int)
    idle = np.array(frames[0]).astype(int)
    x0, y0, x1, y1 = box
    out = [frames[0]]
    for f in frames[1:]:
        a = np.array(f).astype(int)
        sub, rsub = a[y0:y1, x0:x1], ref[y0:y1, x0:x1]
        same = (np.abs(sub[:, :, :3] - rsub[:, :, :3]).sum(2) < 120) & (rsub[:, :, 3] > 0)
        # pedrinhas e terra soltas do golpe: tons do montinho (marrom-acinzentado e preto do contorno)
        r, g, b = sub[:, :, 0], sub[:, :, 1], sub[:, :, 2]
        dirt = (sub[:, :, 3] > 0) & (np.abs(r - g) < 45) & (np.abs(g - b) < 30) & (r < 200) & ~((r > 140) & (g > 140) & (b > 140))
        clear = same | dirt
        sub[clear] = 0
        isub = idle[y0:y1, x0:x1]
        put = (sub[:, :, 3] == 0) & (isub[:, :, 3] > 0)
        sub[put] = isub[put]
        out.append(Image.fromarray(a.astype("uint8")).copy())
    return out


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
        if tool == "Pickaxe":
            frames = {d: _remove_prop(fs) for d, fs in frames.items()}
            if "south" in frames:
                frames["south"] = _remove_mound_south(frames["south"])
        # os pés de cada direção na mesma linha que os da frente (a primeira pose como referência)
        if "south" in frames:
            ref = frames["south"][0].getbbox()[3]
            for d in frames:
                dy = ref - frames[d][0].getbbox()[3]
                if dy:
                    frames[d] = [_shift(f, dy) for f in frames[d]]
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
