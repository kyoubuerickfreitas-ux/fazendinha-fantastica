#!/usr/bin/env python3
"""
"Cabelos" de cogumelo do protagonista a partir de assets/source/mushroom_hair_sheet.png
(7 chapéus x 8 vistas, fundo verde, cada um sobre uma cabeça-molde lisa).
Vistas usadas: coluna 0 = frente, 2 e 6 = os dois lados, 4 = costas.

A cabeça-molde (o miolo claro ligado ao pescoço, e o contorno dela que não encosta no chapéu) é
apagada; ela serve de medida: o tamanho dela vira o tamanho da cabeça do boneco, e o centro dela
fica no centro da cabeça. A aba da frente fica na altura dos olhos.

Para cada quadro das folhas do corpo (player.png e player_actions.png) acha onde está a cabeça
(comparando com a cabeça do quadro parado da mesma direção) e cola o chapéu ali. Saída, do mesmo
tamanho das folhas do corpo: assets/sprites/player/hair_<corte>.png e hair_<corte>_actions.png
(com as cores da arte; não são tingidos). Onde um braço ou ferramenta passa na frente da cabeça
(acima do queixo), o chapéu dá lugar a ele.
Uso: python3 tools/import_hair.py   (depois de tools/import_player_v2.py)
"""
import os
import sys
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
from PIL import Image, ImageFilter  # noqa: E402
from import_hud import key_flood  # noqa: E402
from import_animals import components  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "mushroom_hair_sheet.png")
SPR = os.path.join(ROOT, "assets", "sprites")
OUT = os.path.join(SPR, "player")
CELL = 128
DOWN, LEFT, RIGHT, UP = 0, 1, 2, 3
RUN_ROW = 4

STYLES = ["classico", "folhoso", "enrolado", "pontudo", "florido", "rachado", "fumado"]
ROWS_Y = [0, 150, 285, 420, 560, 700, 845, 1024]
COLS_X = [155, 328, 500, 670, 838, 1005, 1175, 1343, 1515]
DIR_COL = {DOWN: 0, LEFT: 2, UP: 4, RIGHT: 6}
HEAD_W = 37.0          # largura da cabeça do boneco (px da célula) que a cabeça-molde deve ter
HEAD_H = 44            # do topo da cabeça até o queixo (px da célula)
RIM_GAP = -5           # aba da frente: px abaixo do topo dos olhos (negativo = acima)


def load_sheet():
    im = key_flood(Image.open(SRC).convert("RGBA"))
    a = np.array(im)
    rgb = a[..., :3].astype(int)
    # só o verde vivo do fundo (preso entre as partes); o verde do chapéu folhoso fica
    green = (rgb[..., 1] > 140) & (rgb[..., 1] > rgb[..., 0] + 60) & (rgb[..., 1] > rgb[..., 2] + 60)
    a[green] = 0
    return Image.fromarray(a)


def piece(im, row, col):
    y0, y1 = max(0, ROWS_Y[row] - 30), min(im.height, ROWS_Y[row + 1] + 30)
    p = im.crop((COLS_X[col], y0, COLS_X[col + 1], y1))
    keep = Image.new("RGBA", p.size, (0, 0, 0, 0))
    kp, pp = keep.load(), p.load()
    for c in components(p, 20):
        bb = c["bbox"]
        cy = (bb[1] + bb[3]) / 2 + y0
        if ROWS_Y[row] <= cy < ROWS_Y[row + 1] and c["area"] > 30:
            for x, y in c["pts"]:
                kp[x, y] = pp[x, y]
    return keep.crop(keep.getbbox())


def split_head(p):
    """Separa a cabeça-molde: enche a partir do pescoço (base da imagem) pelo que não é contorno escuro.
    Devolve (chapéu sem a cabeça, máscara da cabeça)."""
    a = np.array(p)
    h, w = a.shape[:2]
    lum = a[..., :3].astype(int).sum(-1)
    op = a[..., 3] > 0
    light = op & (lum > 330)
    head = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in range(h - 1, h - 4, -1):
            if light[y, x]:
                q.append((y, x))
    while q:
        y, x = q.popleft()
        if head[y, x] or not light[y, x]:
            continue
        head[y, x] = True
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and not head[ny, nx] and light[ny, nx]:
                q.append((ny, nx))
    # contorno da cabeça: escuro encostado nela, a menos que também encoste no chapéu
    near_head = np.array(Image.fromarray(head.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(7))) > 0
    cap = op & ~head & ~near_head
    near_cap = np.array(Image.fromarray(cap.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(5))) > 0
    drop = head | (near_head & op & ~light & ~near_cap)
    out = a.copy()
    out[drop] = 0
    # riscos do contorno da cabeça que sobram abaixo da aba: em cada coluna, só fica até 3 px
    # abaixo da parte colorida mais baixa do chapéu
    colored = (out[..., 3] > 0) & (lum > 100)
    for x in range(w):
        ys = np.nonzero(colored[:, x])[0]
        out[(ys.max() + 4 if len(ys) else 0):, x] = 0
    # sobras soltas (pedacinhos de contorno)
    img = Image.fromarray(out).copy()
    comps = components(img, 20)
    if comps:
        big = max(c["area"] for c in comps)
        ox = img.load()
        for c in comps:
            if c["area"] < big * 0.02:
                for x, y in c["pts"]:
                    ox[x, y] = (0, 0, 0, 0)
    return img, head


def head_ref(cellimg):
    """Topo e centro da cabeça no quadro parado (o mais alto opaco; centro pelos 20 px de cima)."""
    a = np.array(cellimg)
    ys, xs = np.nonzero(a[..., 3] > 0)
    top = ys.min()
    sel = ys < top + 20
    return int(top), float(xs[sel].mean())


def eyes_top(cellimg, top):
    """Topo dos olhos (pupilas pretas grandes) no quadro de frente."""
    a = np.array(cellimg).astype(int)
    dark = (a[..., 3] > 0) & (a[..., :3].sum(-1) < 90)
    rows = [y for y in range(top + 4, top + HEAD_H) if dark[y].sum() >= 6]
    return rows[0]


def find_offset(ref, refbox, target):
    """Desloca a cabeça do quadro de referência até casar com o quadro alvo (menor diferença)."""
    x0, y0, x1, y1 = refbox
    r = ref[y0:y1, x0:x1].astype(float)
    m = r[..., 3] > 0
    best, bo = 1e9, (0, 0)
    for dy in range(-10, 40):
        for dx in range(-16, 17):
            ty0, tx0 = y0 + dy, x0 + dx
            if ty0 < 0 or tx0 < 0 or ty0 + (y1 - y0) > CELL or tx0 + (x1 - x0) > CELL:
                continue
            t = target[ty0:ty0 + (y1 - y0), tx0:tx0 + (x1 - x0)].astype(float)
            d = np.abs(r[..., :3] - t[..., :3]).mean(-1) / 255
            d = np.where(t[..., 3] > 0, d, 1.0)
            s = d[m].mean() + 0.002 * abs(dx)
            if s < best:
                best, bo = s, (dx, dy)
    return bo


def prepare(im, row, col, scale):
    """Chapéu reduzido + onde fica o centro da cabeça-molde nele. O alfa 128 marca o "vão" debaixo do
    chapéu (onde era a cabeça-molde): ele só é pintado onde a cabeça do boneco não cobre (sem frestas)."""
    cap, head = split_head(piece(im, row, col))
    ca = np.array(cap)
    lum = ca[..., :3].astype(int).sum(-1)
    colored = (ca[..., 3] > 0) & (lum > 100)
    under = np.zeros(head.shape, bool)
    # onde era a cabeça-molde (com o contorno dela, que também foi apagado)
    head_d = np.array(Image.fromarray(head.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(7))) > 0
    for x in range(head.shape[1]):
        cy_ = np.nonzero(colored[:, x])[0]
        if len(cy_):
            under[:cy_.max() + 1, x] = head_d[:cy_.max() + 1, x]
    under &= ca[..., 3] == 0
    shade = (ca[colored][:, :3].mean(0) * 0.45).astype(np.uint8)
    ca[under, :3] = shade
    ca[under, 3] = 128
    cap = Image.fromarray(ca)
    ys, xs = np.nonzero(head)
    widths = head.sum(1)
    wide = widths > widths.max() * 0.6          # sem o pescoço (só a parte larga)
    hy = np.nonzero(wide)[0]
    cy = (hy.min() + hy.max()) / 2
    cx = xs[(ys >= hy.min()) & (ys <= hy.max())].mean()
    small = cap.resize((max(1, round(cap.width * scale)), max(1, round(cap.height * scale))), Image.LANCZOS)
    small_u = Image.fromarray(((np.array(cap)[..., 3] == 128) * 255).astype(np.uint8)).resize(small.size, Image.NEAREST)
    a = np.array(small)
    u = (np.array(small_u) > 0)
    solid = (a[..., 3] >= 160) & ~u
    a[..., 3] = np.where(solid, 255, np.where(u | (a[..., 3] >= 110), 128, 0))
    a[a[..., 3] == 0] = 0
    return Image.fromarray(a), cx * scale, cy * scale


def head_width(im, row, col):
    _, head = split_head(piece(im, row, col))
    return head.sum(1).max()


def build(sheet, refs, rows_dir, extra_dy=None, behind=()):
    out = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    arr = np.array(sheet)
    for row, d in rows_dir.items():
        ref, top, cx, hat, hcx, hcy, center_y = refs[d]
        refbox = (int(cx) - 24, top - 2, int(cx) + 24, top + HEAD_H)
        refhead = ref[refbox[1]:refbox[3], refbox[0]:refbox[2], 3] > 0
        h = np.array(hat)
        for col in range(sheet.width // CELL):
            tgt = arr[row * CELL:(row + 1) * CELL, col * CELL:(col + 1) * CELL]
            if not (tgt[..., 3] > 0).any():
                continue
            ox, oy = find_offset(ref, refbox, tgt)
            hx = int(round(cx + ox - hcx))
            hy = int(round(center_y + oy - hcy)) + (extra_dy or {}).get(row, 0)
            # o que está na frente da cabeça (braço, ferramenta) acima do queixo tapa o chapéu
            occ = (tgt[..., 3] > 0).copy()
            head = np.zeros((CELL, CELL), bool)
            ys, xs = np.nonzero(refhead)
            ys, xs = ys + refbox[1] + oy, xs + refbox[0] + ox
            ok = (ys >= 0) & (ys < CELL) & (xs >= 0) & (xs < CELL)
            head[ys[ok], xs[ok]] = True
            head = np.array(Image.fromarray(head.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(3))) > 0
            occ &= ~head
            occ[max(0, top + oy + HEAD_H):, :] = False
            layer = np.zeros((CELL, CELL, 4), np.uint8)
            sy0, sx0 = max(0, -hy), max(0, -hx)
            ey, ex = min(h.shape[0], CELL - hy), min(h.shape[1], CELL - hx)
            if ey > sy0 and ex > sx0:
                layer[hy + sy0:hy + ey, hx + sx0:hx + ex] = h[sy0:ey, sx0:ex]
            # vão debaixo do chapéu: só onde o corpo não cobre; contorno onde ele encosta no vazio
            body = tgt[..., 3] > 0
            gap = layer[..., 3] == 128
            layer[gap & body] = 0
            layer[gap & ~body, 3] = 255
            fill = layer[..., 3] > 0
            filled = fill | body
            empty_n = ~np.array(Image.fromarray(filled.astype(np.uint8) * 255).filter(ImageFilter.MinFilter(3))).astype(bool)
            edge = gap & ~body & empty_n
            layer[edge, :3] = (40, 28, 26)
            layer[occ] = 0
            if d in behind:
                # cabelo comprido: abaixo do queixo fica por trás do corpo (ombro, braço, regata)
                low = np.zeros((CELL, CELL), bool)
                low[max(0, top + oy + HEAD_H - 6):, :] = True
                layer[low & (tgt[..., 3] > 0)] = 0
            out.alpha_composite(Image.fromarray(layer), (col * CELL, row * CELL))
    return out


def main(styles=None, preview=False):
    im = load_sheet()
    walk = Image.open(os.path.join(SPR, "player.png")).convert("RGBA")
    acts = Image.open(os.path.join(SPR, "player_actions.png")).convert("RGBA")
    wa = np.array(walk)
    scale = HEAD_W / head_width(im, 0, 0)
    # altura do centro da cabeça: escolhida para a aba da frente do chapéu clássico ficar nos olhos
    front = Image.fromarray(wa[0:CELL, 0:CELL])
    ftop, _ = head_ref(front)
    eye = eyes_top(front, ftop)
    hat, hcx, hcy = prepare(im, 0, 0, scale)
    ha = np.array(hat)[..., 3] > 0
    rim = np.nonzero(ha[:, max(0, int(hcx) - 4):int(hcx) + 4].any(1))[0].max()   # base da aba no meio
    center_dy = (eye + RIM_GAP) - (rim - hcy) - ftop       # centro da cabeça abaixo do topo
    print("escala %.3f  olhos %d  centro da cabeça = topo + %.1f" % (scale, eye, center_dy))
    results = {}
    for style in styles or STYLES:
        row = STYLES.index(style)
        refs = {}
        for d, col in DIR_COL.items():
            ref = wa[d * CELL:(d + 1) * CELL, 0:CELL]
            top, cx = head_ref(Image.fromarray(ref))
            hat, hcx, hcy = prepare(im, row, col, scale)
            refs[d] = (ref, top, cx, hat, hcx, hcy, top + center_dy)
        wrows = {DOWN: DOWN, LEFT: LEFT, RIGHT: RIGHT, UP: UP, RUN_ROW: DOWN}
        arows = {r: r % 4 for r in range(acts.height // CELL)}
        hw = build(walk, refs, wrows)
        hac = build(acts, refs, arows)
        results[style] = (hw, hac)
        if not preview:
            hw.save(os.path.join(OUT, "hair_%s.png" % style))
            hac.save(os.path.join(OUT, "hair_%s_actions.png" % style))
        print(style, "ok")
    return results


if __name__ == "__main__":
    main()
