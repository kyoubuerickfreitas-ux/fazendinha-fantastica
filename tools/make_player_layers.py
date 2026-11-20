#!/usr/bin/env python3
"""
Camadas da criação de personagem, a partir do corpo base (assets/sprites/player.png e player_actions.png):

  assets/sprites/player/look_mask.png, look_mask_actions.png
      Máscara do mesmo tamanho da folha: vermelho = classe do pixel
      (60 pele, 120 camisa, 180 calção, 0 = manter: contorno, olhos, bochechas e ferramentas).
      O shader scripts/player/player_look.gdshader pinta cada classe com a cor escolhida, mantendo a sombra.
  assets/sprites/player/hair_<estilo>.png, hair_<estilo>_actions.png
      Cabelo em tons de cinza (o jogo tinge com a cor escolhida), um quadro para cada quadro do corpo.
      A cabeça de cada quadro é achada comparando com a cabeça da pose parada (inclusive nas animações
      de ferramenta), então o cabelo acompanha o balanço da caminhada e os golpes.

Uso: python3 tools/make_player_layers.py
"""
import colorsys
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
OUT = os.path.join(SPR, "player")
CELL = 64
STYLES = ["curto", "comprido", "rabo", "coque", "cacheado", "espetado"]
SKIN, SHIRT, PANTS = 1, 2, 3

# tons do cabelo (cinza; o jogo multiplica pela cor)
OUTLINE, SHADOW, BASE, LIGHT = 52, 165, 215, 250


# ================================================================== classes de cor
def classify(px):
    """px: (h, w, 4) uint8 -> classes (h, w)"""
    h, w, _ = px.shape
    out = np.zeros((h, w), np.uint8)
    for y in range(h):
        for x in range(w):
            r, g, b, a = (int(v) for v in px[y, x])
            if a < 128:
                continue
            hh, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if v < 0.22:
                continue                      # contorno e olhos
            if r > 150 and g < 110:
                continue                      # bochechas
            if v > 0.72 and s < 0.35:
                out[y, x] = SHIRT
            elif s > 0.3 and 0.1 < hh < 0.2:
                out[y, x] = PANTS
            elif 0.08 < s < 0.36 and (hh < 0.13 or hh > 0.95) and 0.3 < v < 0.75:
                out[y, x] = SKIN
    return out


def smooth(cls, alpha, below):
    """Pele dentro da roupa (dobras e sombras) vira roupa; roupa só abaixo do pescoço."""
    h, w = cls.shape
    for y in range(h):
        if y < below:
            for x in range(w):
                if cls[y, x] in (SHIRT, PANTS):
                    cls[y, x] = 0          # ex.: brilho dos olhos
    for _ in range(2):
        new = cls.copy()
        for y in range(max(below, 1), h - 1):
            for x in range(1, w - 1):
                if not alpha[y, x] or cls[y, x] != SKIN:
                    continue
                nb = cls[y - 1:y + 2, x - 1:x + 2].ravel()
                for c in (SHIRT, PANTS):
                    if np.count_nonzero(nb == c) >= 4:
                        new[y, x] = c
                        break
        cls = new
    return cls


# ================================================================== cabeça
def head_template(frame):
    """Máscara da cabeça (do topo até o pescoço) na pose parada."""
    a = frame[:, :, 3] > 128
    rows = np.where(a.any(axis=1))[0]
    y0 = rows[0]
    widths = [np.count_nonzero(a[y]) for y in range(CELL)]
    peak = max(widths[y0:y0 + 20])
    yb = y0 + 8
    while yb < CELL - 1 and not (widths[yb] < peak * 0.55 and widths[yb + 1] >= widths[yb]):
        yb += 1
    m = np.zeros_like(a)
    m[y0:yb + 1] = a[y0:yb + 1]
    return m


def find_head(frame, tmpl, ref):
    """Melhor deslocamento (dx, dy) da cabeça modelo neste quadro."""
    a = frame[:, :, 3] > 128
    ty, tx = np.nonzero(tmpl)
    best, best_s = (0, 0), -1e9
    for dy in range(-10, 13):
        for dx in range(-14, 15):
            y, x = ty + dy, tx + dx
            ok = (y >= 0) & (y < CELL) & (x >= 0) & (x < CELL)
            hit = np.count_nonzero(a[y[ok], x[ok]])
            miss = len(ty) - hit
            s = hit - 1.5 * miss - 0.05 * (abs(dx) + abs(dy))
            if s > best_s:
                best_s, best = s, (dx, dy)
    return best


# ================================================================== penteados
def disk(cx, cy, r, bumpy=0.0):
    yy, xx = np.mgrid[0:CELL, 0:CELL]
    ang = np.arctan2(yy - cy, xx - cx)
    rr = r * (1 + bumpy * np.sin(ang * 9))
    return (xx - cx) ** 2 + (yy - cy) ** 2 <= rr ** 2


def ellipse(cx, cy, rx, ry):
    yy, xx = np.mgrid[0:CELL, 0:CELL]
    return ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1


def dilate(m, n=1):
    for _ in range(n):
        p = np.pad(m, 1)
        m = p[1:-1, 1:-1] | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
    return m


def hair_mask(style, head, view):
    """head: máscara da cabeça; view: 'down', 'right' (rosto para a direita) ou 'up'."""
    ys, xs = np.nonzero(head)
    y0, y1 = ys.min(), ys.max()
    x0, x1 = xs.min(), xs.max()
    hh, cx = y1 - y0 + 1, (x0 + x1) / 2
    yy, xx = np.mgrid[0:CELL, 0:CELL]
    v = (yy - y0) / hh
    u = (xx - cx) / ((x1 - x0) / 2)
    if style == "careca":
        return [np.zeros_like(head)]

    # base: "boné" de cabelo cobrindo o alto da cabeça
    if view == "down":
        fringe = 0.36 + 0.05 * np.where((xx // 2) % 2 == 0, 1, -1)       # franja em zigue-zague
        cap = head & ((v < fringe) | ((np.abs(u) > 0.78) & (v < 0.62)))
    elif view == "right":
        cap = head & ((v < 0.36) | ((u < -0.05) & (v < 0.78)) | ((u < 0.35) & (v < 0.5)))
    else:
        cap = head & (v < 0.86)
    # volume: 1 px para fora na parte de cima
    m = cap | (dilate(cap) & ~head & (v < 0.62))

    if style == "comprido":
        if view == "down":
            side = (np.abs(u) > 0.72) & (np.abs(u) < 1.3) & (v > 0.2) & (v < 1.32)
            m |= side & ~(head & (np.abs(u) < 0.86) & (v > 0.4))
        elif view == "right":
            m |= (u < 0.05) & (u > -1.28) & (v > 0.2) & (v < 1.35) & ~(head & (u > -0.1) & (v > 0.5))
        else:
            m |= (np.abs(u) < 1.2) & (v > 0.3) & (v < 1.38)
    elif style == "rabo":
        if view == "right":
            return [m, ellipse(x0 - 1.5, y0 + hh * 0.66, 2.6, 5.5)]
        elif view == "up":
            return [m, ellipse(cx, y0 + hh * 1.0, 2.6, 6.0)]
        else:
            return [m, ellipse(x1 + 1.5, y0 + hh * 0.55, 1.8, 3.4) & ~head]   # pontinha aparecendo
    elif style == "coque":
        if view == "right":
            return [m, disk(x0 + 2.5, y0 - 1.5, 3.4)]
        return [m, disk(cx, y0 - 2.5, 3.6)]
    elif style == "cacheado":
        big = disk(cx - (1.5 if view == "right" else 0), y0 + hh * 0.36, (x1 - x0) * 0.66, bumpy=0.08)
        face = head & (v > 0.38)
        if view == "down":
            face &= np.abs(u) < 0.8
        elif view == "right":
            face &= u > -0.1
        else:
            face &= np.zeros_like(face)
        m |= big & ~face & (v < (1.0 if view != "down" else 0.75))
    elif style == "espetado":
        spikes = np.zeros_like(head)
        for i, k in enumerate(np.linspace(-0.85, 0.85, 6)):
            sx = cx + k * (x1 - x0) / 2
            top = y0 - (4 if i % 2 else 3)
            for y in range(int(top), int(y0 + 3)):
                half = (y - top) * 0.45
                spikes |= (yy == y) & (np.abs(xx - sx) <= half)
        m |= spikes & (v < 0.3)
    return [m]


def shade(m, head, view, style):
    """Máscara -> imagem RGBA em cinza com contorno, sombra e brilho."""
    img = np.zeros((CELL, CELL, 4), np.uint8)
    if not m.any():
        return img
    ys, xs = np.nonzero(m)
    y0, y1 = ys.min(), ys.max()
    p = np.pad(m, 1)
    edge = m & ~(p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:])
    val = np.full((CELL, CELL), BASE, np.int32)
    # sombra embaixo de cada "mecha" (pixel de cima é cabelo, o de baixo não)
    below = np.zeros_like(m)
    below[:-1] = m[:-1] & ~m[1:]
    val[below] = SHADOW
    # brilho: faixa diagonal no alto
    yy, xx = np.mgrid[0:CELL, 0:CELL]
    hx = xs.min() + (xs.max() - xs.min()) * (0.3 if view != "right" else 0.55)
    band = (np.abs((xx - hx) + (yy - y0) * 0.6 - 2) < 1.2) & (yy < y0 + (y1 - y0) * 0.45)
    val[band & m & ~edge] = LIGHT
    # mechas: linhas verticais mais escuras no cabelo comprido e no rabo
    if style in ("comprido", "rabo"):
        strand = ((xx + yy // 5) % 4 == 0) & (yy > y0 + 5)
        val[strand & m & ~edge] = SHADOW + 15
    if style == "cacheado":
        curls = ((xx * 3 + yy * 5) % 7 == 0)
        val[curls & m & ~edge] = SHADOW
    val[edge] = OUTLINE
    img[m, 0] = img[m, 1] = img[m, 2] = val[m]
    img[m, 3] = 255
    return img


# ================================================================== montagem
def build():
    os.makedirs(OUT, exist_ok=True)
    walk = np.array(Image.open(os.path.join(SPR, "player.png")).convert("RGBA"))
    acts = np.array(Image.open(os.path.join(SPR, "player_actions.png")).convert("RGBA"))
    # modelos da cabeça: pose parada de cada direção (0 baixo, 1 esquerda, 2 direita, 3 cima)
    tmpl, refpos = {}, {}
    for d in range(4):
        f = walk[d * CELL:(d + 1) * CELL, 0:CELL]
        tmpl[d] = head_template(f)
    views = {0: "down", 1: "right", 2: "right", 3: "up"}
    hair_base = {}
    for style in STYLES:
        for d in range(4):
            if d == 1:
                continue
            parts = hair_mask(style, tmpl[d], views[d])
            img = shade(parts[0], tmpl[d], views[d], style)
            for extra in parts[1:]:             # coque/rabo por cima, com contorno próprio
                e = shade(extra, tmpl[d], views[d], "comprido")
                sel = e[:, :, 3] > 0
                img[sel] = e[sel]
            hair_base[(style, d)] = img
        hair_base[(style, 1)] = hair_base[(style, 2)][:, ::-1].copy()   # esquerda = espelho
    for name, sheet in (("", walk), ("_actions", acts)):
        H, W = sheet.shape[:2]
        mask = np.zeros((H, W, 4), np.uint8)
        mask[:, :, 3] = 255
        hairs = {s: np.zeros((H, W, 4), np.uint8) for s in STYLES}
        for r in range(H // CELL):
            d = r % 4
            t = tmpl[d] if d != 1 else tmpl[1]
            for c in range(W // CELL):
                f = sheet[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL]
                if f[:, :, 3].max() < 128:
                    continue
                dx, dy = find_head(f, t, None)
                ys, _ = np.nonzero(t)
                neck = ys.max() + dy + 1
                cls = smooth(classify(f), f[:, :, 3] > 128, neck)
                mask[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL, 0] = cls * 60
                for s in STYLES:
                    hb = hair_base[(s, d)]
                    sh = np.zeros_like(hb)
                    sy0, sy1 = max(0, dy), min(CELL, CELL + dy)
                    sx0, sx1 = max(0, dx), min(CELL, CELL + dx)
                    sh[sy0:sy1, sx0:sx1] = hb[sy0 - dy:sy1 - dy, sx0 - dx:sx1 - dx]
                    hairs[s][r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL] = sh
        Image.fromarray(mask).save(os.path.join(OUT, "look_mask%s.png" % name))
        for s in STYLES:
            Image.fromarray(hairs[s]).save(os.path.join(OUT, "hair_%s%s.png" % (s, name)))
    # referência de brilho de cada classe (média), usada pelo shader para manter as sombras
    cls_all = np.array(Image.open(os.path.join(OUT, "look_mask.png")))[:, :, 0] // 60
    lum = walk[:, :, :3].astype(float).mean(axis=2) / 255
    refs = {k: float(lum[cls_all == v].mean()) for k, v in (("skin", SKIN), ("shirt", SHIRT), ("pants", PANTS))}
    print("brilho médio por classe:", {k: round(v, 3) for k, v in refs.items()})


if __name__ == "__main__":
    build()
