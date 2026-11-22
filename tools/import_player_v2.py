#!/usr/bin/env python3
"""
Protagonista novo (animações do PixelLab, GIFs de 256x256 em assets/source/player_v2/).
Gera, em quadros de 128x128 (o jogo desenha com escala 0,5: mais nítido na tela do celular):
  assets/sprites/player.png          9 colunas x 4 linhas (baixo, esquerda, direita, cima);
                                     coluna 0 = parado, 1..8 = caminhada
  assets/sprites/player_actions.png  9 colunas x 24 linhas (ferramenta * 4 + direção), como antes
  assets/sprites/player/look_mask.png, look_mask_actions.png   classes para trocar as cores
     (vermelho 60 pele, 120 camisa, 180 calção, 0 manter) — ver assets/shaders/player_look.gdshader
A esquerda é a direita espelhada. O que ainda não tem animação fica vazio (o jogo usa o golpe simples):
de costas só existe a pose parada (andar = pose parada balançando).
Uso: python3 tools/import_player_v2.py
"""
import colorsys
import os

from PIL import Image, ImageOps, ImageSequence

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "player_v2")
SPR = os.path.join(ROOT, "assets", "sprites")
CELL = 128
SCALE = 112 / 256          # o quadro de 256 vira 112 px dentro da célula de 128
FEET = 118                 # onde ficam os pés na célula (era 59 na de 64)
GIF_FEET = 247

DOWN, LEFT, RIGHT, UP = 0, 1, 2, 3
TOOLS = ["axe", "hoe", "pickaxe", "watering_can", "scythe", "fishing_rod"]
# animação -> arquivo
ANIMS = {
    "walk_down": "walk_down.gif", "walk_right": "walk_right.gif",
    "water_down": "water_down.gif", "water_right": "water_right.gif",
    "axe_down": "axe_down.gif", "axe_right": "axe_right.gif",
    "pickaxe_down": "pickaxe_down.gif",
}
BACK = os.path.join(ROOT, "pixellab", "protagonista_4_costas.png")


def frames(name):
    im = Image.open(os.path.join(SRC, ANIMS[name]))
    return [f.convert("RGBA") for f in ImageSequence.Iterator(im)]


def cell(img, dy=0):
    """Quadro de 256 -> célula de 128 (pés no lugar certo, alfa limpo)."""
    small = img.resize((round(256 * SCALE), round(256 * SCALE)), Image.LANCZOS)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 120 else (0, 0, 0, 0)
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    out.alpha_composite(small, ((CELL - small.width) // 2, FEET - round(GIF_FEET * SCALE) + dy))
    return out


def put_row(sheet, row, cells, start=0):
    for i, c in enumerate(cells):
        sheet.alpha_composite(c, ((start + i) * CELL, row * CELL))


def mirror(cells):
    return [ImageOps.mirror(c) for c in cells]


def fit9(cells):
    """As animações de ferramenta têm 9 quadros (as de 8 repetem o último)."""
    cells = list(cells)[:9]
    while len(cells) < 9:
        cells.append(cells[-1])
    return cells


# ------------------------------------------------------------------ máscara de cores
def classify(c):
    r, g, b, a = c
    if a < 128:
        return 0
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    if v < 0.24:
        return 0                                   # contorno e olhos
    if s < 0.08:
        return 0                                   # brilho do olho, metal
    if 0.10 <= h <= 0.24 and s > 0.25 and v < 0.66:
        return 180                                 # calção oliva
    if h < 0.13 or h > 0.95:
        if s < 0.335 and v > 0.66:
            return 120                             # regata clara (o metal das ferramentas é mais cinza)
        if r > 175 and g < 135 and s > 0.45:
            return 0                               # bochecha rosada
        if s > 0.45 and v < 0.62:
            return 0                               # manchas marrons da regata (decididas pela vizinhança)
        if s > 0.3 and v > 0.42:
            return 60                              # pele
    return 0


def mask_of(sheet):
    """Classe por pixel e depois uma "votação" na vizinhança 5x5: manchas e sombras da regata (que têm cor
    de pele) viram regata, e pontinhos soltos somem."""
    import numpy as np
    sp = sheet.load()
    w, h = sheet.size
    k = np.zeros((h, w), np.uint8)
    for y in range(h):
        for x in range(w):
            k[y, x] = classify(sp[x, y])
    out = k.copy()
    pad = np.pad(k, 2)
    counts = {c: np.zeros((h, w), np.int32) for c in (60, 120, 180)}
    for dy in range(5):
        for dx in range(5):
            win = pad[dy:dy + h, dx:dx + w]
            for c in counts:
                counts[c] += win == c
    alpha = np.array(sheet.getchannel("A")) >= 128
    flip = (k == 60) & (counts[120] > counts[60] + 2)
    out[flip] = 120
    # pixels de pele/regata sem classe (sombra mais escura) cercados de uma classe só
    for c in (60, 120, 180):
        fill = (k == 0) & alpha & (counts[c] >= 16)
        out[fill] = c
    # regata: em cada quadro fica só o pedaço grande (o metal das ferramentas tem a mesma cor, mas fica solto)
    from collections import deque
    for cy in range(0, h, CELL):
        for cx in range(0, w, CELL):
            sub = out[cy:cy + CELL, cx:cx + CELL]
            seen = np.zeros(sub.shape, bool)
            comps = []
            for y0, x0 in zip(*np.nonzero(sub == 120)):
                if seen[y0, x0]:
                    continue
                q, pts = deque([(y0, x0)]), []
                seen[y0, x0] = True
                while q:
                    y, x = q.popleft()
                    pts.append((y, x))
                    for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                        if 0 <= ny < CELL and 0 <= nx < CELL and not seen[ny, nx] and sub[ny, nx] == 120:
                            seen[ny, nx] = True
                            q.append((ny, nx))
                comps.append(pts)
            if not comps:
                continue
            big = max(len(c) for c in comps)
            for c in comps:
                if len(c) < big * 0.3 or len(c) < 50:
                    for y, x in c:
                        sub[y, x] = 0
    m = np.zeros((h, w, 3), np.uint8)
    m[..., 0] = out
    return Image.fromarray(m, "RGB")


if __name__ == "__main__":
    walk = Image.new("RGBA", (CELL * 9, CELL * 4), (0, 0, 0, 0))
    idle_down = cell(frames("axe_down")[0])
    idle_right = cell(frames("axe_right")[0])
    put_row(walk, DOWN, [idle_down] + [cell(f) for f in frames("walk_down")])
    right = [idle_right] + [cell(f) for f in frames("walk_right")]
    put_row(walk, RIGHT, right)
    put_row(walk, LEFT, mirror(right))
    back = Image.open(BACK).convert("RGBA")
    back_cells = [cell(back)] + [cell(back, dy=-(1 if i % 4 in (1, 2) else 0)) for i in range(8)]
    put_row(walk, UP, back_cells)
    walk.save(os.path.join(SPR, "player.png"))

    acts = Image.new("RGBA", (CELL * 9, CELL * 4 * len(TOOLS)), (0, 0, 0, 0))
    for tool, prefix in (("axe", "axe"), ("watering_can", "water"), ("pickaxe", "pickaxe")):
        t = TOOLS.index(tool)
        if prefix + "_down" in ANIMS:
            put_row(acts, t * 4 + DOWN, fit9(cell(f) for f in frames(prefix + "_down")))
        if prefix + "_right" in ANIMS:
            r = fit9(cell(f) for f in frames(prefix + "_right"))
            put_row(acts, t * 4 + RIGHT, r)
            put_row(acts, t * 4 + LEFT, mirror(r))
    acts.save(os.path.join(SPR, "player_actions.png"))

    os.makedirs(os.path.join(SPR, "player"), exist_ok=True)
    for sheet, name in ((walk, "look_mask.png"), (acts, "look_mask_actions.png")):
        mask_of(sheet).save(os.path.join(SPR, "player", name))
    # brilho médio de cada classe (para os REF_* do shader)
    sums = {60: [0, 0], 120: [0, 0], 180: [0, 0]}
    sp = walk.load()
    for y in range(walk.height):
        for x in range(walk.width):
            k = classify(sp[x, y])
            if k:
                r, g, b, _ = sp[x, y]
                sums[k][0] += (r + g + b) / 765
                sums[k][1] += 1
    print("REF pele %.3f camisa %.3f calção %.3f" % tuple(sums[k][0] / max(1, sums[k][1]) for k in (60, 120, 180)))
    print("player", walk.size, "actions", acts.size)
