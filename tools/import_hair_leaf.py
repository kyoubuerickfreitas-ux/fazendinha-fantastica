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
# "eyes": pupilas de frente (x, y) na folha; "side_eye": pupila de lado (olhando para a esquerda)
STYLES = {
    "folhas": {"front": (74, 291, 198), "side": (330, 532, 200), "back": (555, 744, 205),
               "eyes": ((146.5, 151.0), (218.0, 150.5)), "side_eye": (372.0, 150.0)},
    "folhas_rabo": {"front": (825, 1050, 198), "side": (1082, 1305, 200), "back": (1313, 1513, 206),
                    "eyes": ((902.0, 151.5), (970.0, 150.5)), "side_eye": (1115.0, 150.0)},
    # comprido com flores (2ª linha da folha): abaixo do queixo passa por trás do corpo (LONG)
    "folhas_flores": {"front": (52, 307, 712), "side": (334, 547, 728), "back": (580, 788, 740),
                      "eyes": ((146.7, 596.1), (216.2, 594.8)), "side_eye": (375.5, 595.7), "row": (440, 880),
                      "body_rows": (780, 860)},
}
LONG = {"folhas_flores"}
# folha extra colada de lado (centro no quadro parado olhando para a direita): tapa o vão acima da orelha
LEAF_PATCH = {"folhas_rabo": (63, 40)}
LEAF_BOX = (1196, 84, 1252, 124)          # a folha de baixo da presilha do rabinho, na folha
ROW_Y = (0, 430)
GAME_EYES = ((54.5, 47.5), (73.5, 47.5))           # pupilas de frente no quadro parado do jogo
GAME_SIDE_EYE = (79.0, 43.5)                       # pupila de lado (olhando para a direita)
# ajuste fino de lado (px do quadro): o recorte do cabelo em volta da orelha cai na orelha do boneco
SIDE_ADJ = {"folhas": (2, 4), "folhas_rabo": (2, 2), "folhas_flores": (-2, 2)}   # x: franja encostada na testa


def dil(m, n):
    return np.array(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(n))) > 0


def ero(m, n):
    return np.array(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(n))) > 0


def hair_of(im, x0, x1, cut, row=ROW_Y):
    """Só o cabelo da coluna x0..x1 e da linha row (coordenadas da folha), sem nada abaixo de y=cut."""
    c = im[row[0]:row[1], x0:x1]
    cut = cut - row[0]
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
        if k["area"] >= max(12, big * 0.002):      # pontinhas soltas (nuca, atrás da orelha) também
            for x, y in k["pts"]:
                keep[y, x] = True
    dark = op & (c.sum(-1) < 200)
    hm = keep | (dark & dil(keep, 5))
    hm = ero(dil(hm, 3), 3) & op
    hm[cut:] = False
    # flores e enfeites (rosa, branco, amarelo) cercados de cabelo também entram; bochecha, branco dos
    # olhos e orelha ficam de fora (em volta deles é pele, não cabelo)
    fl = op & ~hm & ((r - g > 85) | ((c.min(-1) > 175) & (c.max(-1) - c.min(-1) < 75) & (g > 200)) | ((g - b > 90) & (r > 200)))
    fl[cut:] = False
    skin = op & (r > 190) & (g > 135) & (g < 200) & (b > 80) & (b < 170) & (r - g > 35) & (r - g < 92)   # pétala rosa: mais vermelha
    fi = Image.fromarray(np.dstack([fl * 255] * 4).astype(np.uint8))
    for k in components(fi, 128):
        if k["area"] < 6 or k["area"] > 3000:
            continue
        comp = np.zeros(hm.shape, bool)
        for x, y in k["pts"]:
            comp[y, x] = True
        ring = dil(comp, 13) & ~dil(comp, 7)      # depois do contorno da flor
        if (skin & comp).sum() > comp.sum() * 0.3:
            continue                              # é pele (orelha)
        if ring.sum() and (skin & ring).sum() / ring.sum() > 0.12:
            continue                              # perto do rosto: olho, bochecha
        if ring.sum() and (hm & ring).sum() / ring.sum() > 0.2:
            hm |= op & dil(comp, 9)               # a flor inteira, com o miolo e o contorno
    # o miolo das flores (amarelo, com contorno) e o contorno delas
    hm |= dark & dil(hm & ~dil(keep, 3), 3)
    hm[cut:] = False
    # buraquinhos cercados de cabelo (miolo claro das folhas, brilho): também são cabelo
    holes = ~hm
    hi = Image.fromarray(np.dstack([holes * 255] * 4).astype(np.uint8))
    for k in components(hi, 128):
        bb = k["bbox"]
        touches = bb[0] == 0 or bb[1] == 0 or bb[2] >= hm.shape[1] or bb[3] >= hm.shape[0]
        if k["area"] < 80 and not touches:
            for x, y in k["pts"]:
                if op[y, x]:
                    hm[y, x] = True
    a = np.zeros(c.shape[:2] + (4,), np.uint8)
    a[..., :3] = c
    a[..., 3] = hm * 255
    return a


def leaf_piece(im, s):
    """Uma folha solta (miolo verde-claro + contorno), espelhada como o lado do jogo, na escala s."""
    x0, y0, x1, y1 = LEAF_BOX
    c = im[y0:y1, x0:x1]
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    light = (g > 125) & (g > b + 40) & (r > 90)
    li = Image.fromarray(np.dstack([light * 255] * 4).astype(np.uint8))
    comps = components(li, 128)
    big = max(comps, key=lambda k: k["area"])
    m = np.zeros(light.shape, bool)
    for x, y in big["pts"]:
        m[y, x] = True
    m = ero(dil(m, 3), 3)
    m = dil(m, 5) & ((c.sum(-1) < 200) | m)       # com o contorno preto
    a = np.zeros(c.shape[:2] + (4,), np.uint8)
    a[..., :3] = c
    a[..., 3] = m * 255
    a = a[:, ::-1].copy()
    return scaled(a, s)


def body_cx(im, x0, x1, rows=(220, 300)):
    c = im[rows[0]:rows[1], x0:x1]
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
    game_mid = ((GAME_EYES[0][0] + GAME_EYES[1][0]) / 2, (GAME_EYES[0][1] + GAME_EYES[1][1]) / 2)
    results = {}
    for style in styles or STYLES:
        spec = STYLES[style]
        se = spec["eyes"]
        s = (GAME_EYES[1][0] - GAME_EYES[0][0]) / (se[1][0] - se[0][0])
        eye_mid = ((se[0][0] + se[1][0]) / 2, (se[0][1] + se[1][1]) / 2)
        SHEET_SIDE_EYE = spec["side_eye"]
        row = spec.get("row", ROW_Y)
        body_rows = spec.get("body_rows", (220, 300))
        print("%s: escala %.3f" % (style, s))
        place = {}       # direção -> (imagem do cabelo, x e y do canto no quadro parado)
        fx0, fx1, fcut = spec["front"]
        hf = scaled(hair_of(im, fx0, fx1, fcut, row), s)
        place[DOWN] = (hf, game_mid[0] - (eye_mid[0] - fx0) * s, game_mid[1] - (eye_mid[1] - row[0]) * s)
        sx0, sx1, scut = spec["side"]
        hs = scaled(hair_of(im, sx0, sx1, scut, row)[:, ::-1].copy(), s)        # espelhado: olha para a direita
        ex = (sx1 - SHEET_SIDE_EYE[0]) * s                                 # olho na imagem espelhada
        ey = (SHEET_SIDE_EYE[1] - row[0]) * s
        adx, ady = SIDE_ADJ.get(style, (0, 0))
        if style in LEAF_PATCH:
            lf = leaf_piece(im, s)
            lx, ly = LEAF_PATCH[style]
            hs = hs.copy()
            hs.alpha_composite(lf, (int(round(lx - (GAME_SIDE_EYE[0] - ex + adx) - lf.width / 2)),
                                    int(round(ly - (GAME_SIDE_EYE[1] - ey + ady) - lf.height / 2))))
        place[RIGHT] = (hs, GAME_SIDE_EYE[0] - ex + adx, GAME_SIDE_EYE[1] - ey + ady)
        place[LEFT] = (hs.transpose(Image.FLIP_LEFT_RIGHT), CELL - (GAME_SIDE_EYE[0] - ex + adx) - hs.width,
                       GAME_SIDE_EYE[1] - ey + ady)
        bx0, bx1, bcut = spec["back"]
        hb = scaled(hair_of(im, bx0, bx1, bcut, row), s)
        gcx = np.nonzero(wa[UP * CELL + 70:UP * CELL + 100, 0:CELL, 3] > 0)[1].mean()
        place[UP] = (hb, gcx - (body_cx(im, bx0, bx1, body_rows) - bx0) * s, game_mid[1] - (eye_mid[1] - row[0]) * s)
        refs = {}
        for d, (hat, px, py) in place.items():
            ref = wa[d * CELL:(d + 1) * CELL, 0:CELL]
            top, cx = H.head_ref(Image.fromarray(ref))
            # build() põe o canto em (cx + ox - hcx, center_y + oy - hcy)
            refs[d] = (ref, top, cx, hat, cx - px, top - py, top)
        wrows = {DOWN: DOWN, LEFT: LEFT, RIGHT: RIGHT, UP: UP, H.RUN_ROW: DOWN}
        arows = {r: r % 4 for r in range(acts.height // CELL)}
        behind = (DOWN, LEFT, RIGHT) if style in LONG else ()
        hw = H.build(walk, refs, wrows, behind=behind)
        ha = H.build(acts, refs, arows, behind=behind)
        results[style] = (hw, ha)
        if not preview:
            hw.save(os.path.join(H.OUT, "hair_%s.png" % style))
            ha.save(os.path.join(H.OUT, "hair_%s_actions.png" % style))
        print(style, "ok")
    return results


if __name__ == "__main__":
    main()
