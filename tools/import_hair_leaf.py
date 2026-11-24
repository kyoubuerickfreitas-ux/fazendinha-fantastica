#!/usr/bin/env python3
"""
Cabelos desenhados já no personagem (assets/source/hair_leaf_sheet.png, fundo roxo): cada corte vem em
frente, lado (olhando para a esquerda) e costas. Daqui sai só o cabelo (os verdes acima da regata, com
o contorno grudado neles), na escala do boneco do jogo:
  escala = distância entre as pupilas do jogo / distância entre as pupilas da arte (de frente)
  frente: o meio dos olhos da arte vai no meio dos olhos do boneco
  lado: espelhado (o jogo usa o lado direito; o esquerdo é espelho dele), o olho no olho
  costas: mesma altura da frente; centro do corpo no centro do corpo
Depois o encaixe quadro a quadro é o mesmo dos cogumelos (tools/import_hair.py: build).
Saída: assets/sprites/player/hair_<corte>.png e hair_<corte>_actions.png (com as cores da arte).
Uso: python3 tools/import_hair_leaf.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
from PIL import Image, ImageFilter  # noqa: E402
import import_hair as H  # noqa: E402
from import_animals import components  # noqa: E402

ROOT = H.ROOT
SRC = os.path.join(ROOT, "assets", "source", "hair_leaf_sheet.png")
CELL = H.CELL
DOWN, LEFT, RIGHT, UP = H.DOWN, H.LEFT, H.RIGHT, H.UP

# corte -> {vista: (x0, x1 da coluna na folha, y onde o cabelo acaba)}; y das linhas: 0..430
STYLES = {
    "folhas": {"front": (74, 291, 190), "side": (330, 532, 200), "back": (555, 744, 205)},
}
ROW_Y = (0, 430)
SHEET_EYES = ((146.5, 151.0), (218.0, 150.5))     # pupilas de frente (x, y) na folha
SHEET_SIDE_EYE = (372.0, 150.0)                    # pupila de lado (olhando para a esquerda)
GAME_EYES = ((54.5, 47.5), (73.5, 47.5))           # pupilas de frente no quadro parado do jogo
GAME_SIDE_EYE = (79.0, 43.5)                       # pupila de lado (olhando para a direita)
# ajuste fino de lado (px do quadro): o recorte do cabelo em volta da orelha cai na orelha do boneco
SIDE_ADJ = {"folhas": (0, 4)}


def dil(m, n):
    return np.array(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(n))) > 0


def ero(m, n):
    return np.array(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(n))) > 0


def hair_of(im, x0, x1, cut):
    """Só o cabelo da coluna x0..x1 (coordenadas da folha), sem nada abaixo de y=cut."""
    c = im[ROW_Y[0]:ROW_Y[1], x0:x1]
    bg = im[5, 5]
    op = np.abs(c - bg).sum(-1) > 70
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    green = op & (g >= r - 8) & (g > b + 12)      # inclui o verde-escuro das sombras do cabelo
    green[cut:] = False
    # o pedaço grande e as folhas soltas que encostam nele
    gi = Image.fromarray(np.dstack([green * 255] * 4).astype(np.uint8))
    comps = components(gi, 128)
    big = max(k["area"] for k in comps)
    keep = np.zeros(green.shape, bool)
    for k in comps:
        if k["area"] >= big * 0.01:
            for x, y in k["pts"]:
                keep[y, x] = True
    dark = op & (c.sum(-1) < 200)
    hm = keep | (dark & dil(keep, 5))
    hm = ero(dil(hm, 3), 3) & op
    hm[cut:] = False
    a = np.zeros(c.shape[:2] + (4,), np.uint8)
    a[..., :3] = c
    a[..., 3] = hm * 255
    return a


def body_cx(im, x0, x1):
    c = im[220:300, x0:x1]
    op = np.abs(c - im[5, 5]).sum(-1) > 70
    return np.nonzero(op)[1].mean() + x0


def scaled(a, s):
    img = Image.fromarray(a)
    small = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)
    b = np.array(small)
    b[..., 3] = np.where(b[..., 3] >= 110, 255, 0)
    b[b[..., 3] == 0] = 0
    return Image.fromarray(b)


def main(styles=None, preview=False):
    im = np.array(Image.open(SRC).convert("RGB")).astype(int)
    walk = Image.open(os.path.join(H.SPR, "player.png")).convert("RGBA")
    acts = Image.open(os.path.join(H.SPR, "player_actions.png")).convert("RGBA")
    wa = np.array(walk)
    s = (GAME_EYES[1][0] - GAME_EYES[0][0]) / (SHEET_EYES[1][0] - SHEET_EYES[0][0])
    eye_mid = ((SHEET_EYES[0][0] + SHEET_EYES[1][0]) / 2, (SHEET_EYES[0][1] + SHEET_EYES[1][1]) / 2)
    game_mid = ((GAME_EYES[0][0] + GAME_EYES[1][0]) / 2, (GAME_EYES[0][1] + GAME_EYES[1][1]) / 2)
    print("escala %.3f" % s)
    results = {}
    for style in styles or STYLES:
        spec = STYLES[style]
        place = {}       # direção -> (imagem do cabelo, x e y do canto no quadro parado)
        fx0, fx1, fcut = spec["front"]
        hf = scaled(hair_of(im, fx0, fx1, fcut), s)
        place[DOWN] = (hf, game_mid[0] - (eye_mid[0] - fx0) * s, game_mid[1] - (eye_mid[1] - ROW_Y[0]) * s)
        sx0, sx1, scut = spec["side"]
        hs = scaled(hair_of(im, sx0, sx1, scut)[:, ::-1].copy(), s)        # espelhado: olha para a direita
        ex = (sx1 - SHEET_SIDE_EYE[0]) * s                                 # olho na imagem espelhada
        ey = (SHEET_SIDE_EYE[1] - ROW_Y[0]) * s
        adx, ady = SIDE_ADJ.get(style, (0, 0))
        place[RIGHT] = (hs, GAME_SIDE_EYE[0] - ex + adx, GAME_SIDE_EYE[1] - ey + ady)
        place[LEFT] = (hs.transpose(Image.FLIP_LEFT_RIGHT), CELL - (GAME_SIDE_EYE[0] - ex + adx) - hs.width,
                       GAME_SIDE_EYE[1] - ey + ady)
        bx0, bx1, bcut = spec["back"]
        hb = scaled(hair_of(im, bx0, bx1, bcut), s)
        gcx = np.nonzero(wa[UP * CELL + 70:UP * CELL + 100, 0:CELL, 3] > 0)[1].mean()
        place[UP] = (hb, gcx - (body_cx(im, bx0, bx1) - bx0) * s, game_mid[1] - (eye_mid[1] - ROW_Y[0]) * s)
        refs = {}
        for d, (hat, px, py) in place.items():
            ref = wa[d * CELL:(d + 1) * CELL, 0:CELL]
            top, cx = H.head_ref(Image.fromarray(ref))
            # build() põe o canto em (cx + ox - hcx, center_y + oy - hcy)
            refs[d] = (ref, top, cx, hat, cx - px, top - py, top)
        wrows = {DOWN: DOWN, LEFT: LEFT, RIGHT: RIGHT, UP: UP, H.RUN_ROW: DOWN}
        arows = {r: r % 4 for r in range(acts.height // CELL)}
        hw = H.build(walk, refs, wrows)
        ha = H.build(acts, refs, arows)
        results[style] = (hw, ha)
        if not preview:
            hw.save(os.path.join(H.OUT, "hair_%s.png" % style))
            ha.save(os.path.join(H.OUT, "hair_%s_actions.png" % style))
        print(style, "ok")
    return results


if __name__ == "__main__":
    main()
