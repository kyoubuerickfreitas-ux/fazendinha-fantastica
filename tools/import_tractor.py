#!/usr/bin/env python3
"""
Trator (assets/source/tractor.png, fundo verde, 4 vistas): frente (baixo), costas (cima),
virado para a esquerda (capô à esquerda) e para a direita. Saída: assets/sprites/tractor/<direção>.png,
todas na mesma escala, com as rodas na base da imagem.
Também importa a caçamba (assets/source/trailer.png, mesma organização: em cima à esquerda vista com o
engate para baixo, embaixo à esquerda para cima, à direita engate para a esquerda e para a direita)
em assets/sprites/tractor/trailer_<direção do trator>.png.
Uso: python3 tools/import_tractor.py
"""
import colorsys
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from import_hud import key_flood  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "tractor.png")
OUT = os.path.join(ROOT, "assets", "sprites", "tractor")
VIEWS = {"down": (0, 0, 700, 500), "left": (700, 0, 1536, 512), "up": (0, 500, 700, 1024), "right": (700, 512, 1536, 1024)}
SCALE = 0.13

FRAMES = 4          # quadros das rodas girando (saída: tira horizontal com FRAMES quadros por direção)
# centro aproximado das rodas vistas de lado (na folha original); o centro exato é achado pelo miolo creme
# (x, y, raio aproximado do miolo, número de gomos do aro)
TRACTOR_WHEELS = [(900, 430, 40, 10), (1257, 401, 65, 12), (955, 880, 62, 12), (1325, 900, 42, 10)]
TRAILER_WHEELS = [(1215, 370, 52, 14), (1038, 850, 52, 14)]


def _is_tread(p):
    r, g, b, a = p
    if a < 128:
        return False
    h, s_, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    if v < 0.3:
        return True                         # contornos e frestas entre os gomos
    return 0.03 <= h <= 0.13 and s_ > 0.35 and v < 0.85     # madeira


def _hub(im, hint):
    """Centro e raio do miolo creme da roda, e o raio de fora (descendo até o fundo transparente)."""
    px = im.load()
    hx, hy, hr = hint[:3]
    pts = []
    for y in range(hy - hr - 8, hy + hr + 8):
        for x in range(hx - hr - 8, hx + hr + 8):
            if (x - hx) ** 2 + (y - hy) ** 2 > (hr * 1.1) ** 2:
                continue
            r, g, b, a = px[x, y]
            if a and r > 200 and g > 150 and b < 200 and r - b > 40:
                pts.append((x, y))
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    hub_r = max(hr * 0.9, (len(pts) / math.pi) ** 0.5)
    y = int(cy)
    while y < im.height - 1 and px[int(cx), y][3] > 0:
        y += 1
    return cx, cy, hub_r, y - cy


def _period(im, cx, cy, r0, r1):
    """Ângulo entre os gomos do aro (autocorrelação no anel, na metade de baixo, que não tem para-lama)."""
    px = im.load()
    rr = (r0 + r1) / 2
    angs = [math.radians(20 + k * 0.5) for k in range(280)]
    sig = []
    for a in angs:
        r, g, b, _ = px[int(cx + rr * math.cos(a)), int(cy + rr * math.sin(a))]
        sig.append((r + g + b) / 3)
    m = sum(sig) / len(sig)
    sig = [v - m for v in sig]
    corr = {}
    for lag in range(30, 130):            # 15 a 65 graus
        corr[lag] = sum(sig[k] * sig[k + lag] for k in range(len(sig) - lag)) / (len(sig) - lag)
    top = max(corr.values())
    for lag in range(31, 129):            # o primeiro pico alto é o espaço entre dois gomos
        if corr[lag] >= corr[lag - 1] and corr[lag] >= corr[lag + 1] and corr[lag] > 0.5 * top:
            return lag * 0.5
    return max(corr, key=corr.get) * 0.5


def _spin(src, dst, wheel, frac):
    """Gira o aro (entre o miolo e a borda) por frac de um gomo. Só mexe em pixels de aro."""
    cx, cy, hub_r, out_r, period = wheel
    ang = math.radians(period * frac)
    sp, dp = src.load(), dst.load()
    ca, sa = math.cos(ang), math.sin(ang)
    r0, r1 = hub_r + 3, out_r
    for y in range(int(cy - r1), int(cy + r1) + 1):
        for x in range(int(cx - r1), int(cx + r1) + 1):
            dx, dy = x - cx, y - cy
            d = (dx * dx + dy * dy) ** 0.5
            if not (r0 <= d <= r1) or not _is_tread(sp[x, y]):
                continue
            sx, sy = cx + dx * ca + dy * sa, cy - dx * sa + dy * ca       # de onde vem este pixel
            q = sp[int(round(sx)), int(round(sy))]
            if _is_tread(q):
                dp[x, y] = q


def _roll(src, dst, box, frac, spacing=26):
    """Rodas de frente/costas: a banda de rodagem "corre" para baixo nas laterais de baixo da peça."""
    bb = src.crop(box).getbbox()
    x0, y0, x1, y1 = box[0] + bb[0], box[1] + bb[1], box[0] + bb[2], box[1] + bb[3]
    w = x1 - x0
    sp, dp = src.load(), dst.load()
    shift = int(round(spacing * frac))
    if shift == 0:
        return
    for xa, xb in ((x0, x0 + int(w * 0.24)), (x1 - int(w * 0.24), x1)):
        for x in range(xa, xb):
            y = y0 + int((y1 - y0) * 0.5)
            while y < y1:
                if not _is_tread(sp[x, y]):
                    y += 1
                    continue
                s0 = y
                while y < y1 and _is_tread(sp[x, y]):
                    y += 1
                run = [sp[x, k] for k in range(s0, y)]
                if len(run) >= 8:
                    for k in range(len(run)):
                        dp[x, s0 + k] = run[(k - shift) % len(run)]


def import_sheet(src, views, prefix, scale=SCALE, wheels=()):
    im = key_flood(Image.open(src).convert("RGBA"))
    px = im.load()
    for y in range(im.height):         # verde de fundo preso dentro da cabine
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and g > 190 and r < 90 and b < 90:
                px[x, y] = (0, 0, 0, 0)
    found = []
    for hint in wheels:
        cx, cy, hub_r, out_r = _hub(im, hint)
        found.append((cx, cy, hub_r, out_r, 360.0 / hint[3]))
    frames = []
    for k in range(FRAMES):
        f = im.copy()
        for wh in found:
            _spin(im, f, wh, k / FRAMES)
        for name, box in views.items():
            if name in ("down", "up"):
                _roll(im, f, box, k / FRAMES)
        frames.append(f)
    for name, box in views.items():
        bb = im.crop(box).getbbox()
        strip = None
        for k, f in enumerate(frames):
            p = f.crop(box).crop(bb)
            small = p.resize((round(p.width * scale), round(p.height * scale)), Image.LANCZOS)
            sp = small.load()
            for y in range(small.height):
                for x in range(small.width):
                    r, g, b, a = sp[x, y]
                    sp[x, y] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
            if strip is None:
                strip = Image.new("RGBA", (small.width * FRAMES, small.height), (0, 0, 0, 0))
            strip.paste(small, (k * small.width, 0))
        strip.save(os.path.join(OUT, prefix + name + ".png"))
        print(prefix + name, strip.size, "rodas:", [(round(w[0]), round(w[1]), round(w[4], 1)) for w in found] if name == "left" else "")


# caçamba: nome = direção do TRATOR (o engate aponta para ele)
TRAILER_VIEWS = {"down": (0, 0, 700, 500), "left": (700, 0, 1536, 500), "up": (0, 500, 700, 1024),
                 "right": (700, 500, 1536, 1024)}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    import_sheet(SRC, VIEWS, "", SCALE, TRACTOR_WHEELS)
    import_sheet(os.path.join(ROOT, "assets", "source", "trailer.png"), TRAILER_VIEWS, "trailer_", 0.105, TRAILER_WHEELS)
