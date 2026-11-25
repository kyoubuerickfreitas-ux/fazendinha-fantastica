#!/usr/bin/env python3
"""
Encaixe de cabelos no protagonista, quadro a quadro (usado por tools/import_hair_leaf.py).
Para cada quadro das folhas do corpo (player.png e player_actions.png) acha onde está a cabeça
(comparando com a cabeça do quadro parado da mesma direção) e cola o cabelo ali. Onde um braço ou
ferramenta passa na frente da cabeça (acima do queixo), o cabelo dá lugar a ele.
"""
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
OUT = os.path.join(SPR, "player")
CELL = 128
DOWN, LEFT, RIGHT, UP = 0, 1, 2, 3
RUN_ROW = 4
HEAD_H = 44            # do topo da cabeça até o queixo (px da célula)


def head_ref(cellimg):
    """Topo e centro da cabeça no quadro parado (o mais alto opaco; centro pelos 20 px de cima)."""
    a = np.array(cellimg)
    ys, xs = np.nonzero(a[..., 3] > 0)
    top = ys.min()
    sel = ys < top + 20
    return int(top), float(xs[sel].mean())


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
