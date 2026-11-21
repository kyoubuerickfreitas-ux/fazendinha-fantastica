#!/usr/bin/env python3
"""
Ícones de clima, dia/noite, temperatura e calendário (assets/source/weather_sheet.png, fundo verde).
Saída: assets/sprites/ui/weather/<nome>.png (64x64). ItemDB.ui_icon() usa estes no lugar dos ícones antigos
quando o arquivo existe. As placas de estação e de previsão ficam guardadas na folha para depois.
Uso: python3 tools/import_weather_icons.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from import_hud import key_flood, largest_only  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "weather_sheet.png")
OUT = os.path.join(ROOT, "assets", "sprites", "ui", "weather")
SIZE = 64
# nome do ícone no jogo (UI_ICON de item_db.gd) -> recorte na folha (sem a plaquinha de texto)
BOXES = {
    "sun": (32, 296, 214, 464), "cloud": (242, 300, 442, 450), "rain": (462, 296, 648, 446),
    "heavy_rain": (670, 290, 860, 458), "storm": (878, 284, 1070, 466), "fog": (1090, 300, 1296, 456),
    "snow": (1322, 290, 1512, 466), "heat": (40, 556, 200, 690), "cold": (240, 556, 390, 690),
    "day": (742, 568, 888, 706), "moon": (902, 568, 1032, 712), "calendar": (22, 772, 236, 990),
    "clock": (466, 776, 680, 990),
}
# outros nomes que usam o mesmo desenho
ALIAS = {"wind": "cloud"}
# os que juntam vários pedaços (gotas, flocos, neblina) não passam pelo "maior pedaço só"
MULTI = {"rain", "heavy_rain", "storm", "fog", "snow", "heat", "cold"}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    full = key_flood(Image.open(SRC).convert("RGBA"))
    for name, box in BOXES.items():
        im = full.crop(box)
        px = im.load()
        for y in range(im.height):       # verde preso entre gotas/flocos (não encosta na borda da folha)
            for x in range(im.width):
                r, g, b, a = px[x, y]
                if a and g > 170 and g - max(r, b) > 90:
                    px[x, y] = (0, 0, 0, 0)
        if name not in MULTI:
            im = largest_only(im)
        im = im.crop(im.getbbox())
        s = (SIZE - 2) / max(im.size)
        small = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
        out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        out.alpha_composite(small, ((SIZE - small.width) // 2, (SIZE - small.height) // 2))
        out.save(os.path.join(OUT, name + ".png"))
    # mostrador do relógio sem os ponteiros (o jogo desenha os ponteiros na hora certa): o miolo pega a cor
    # do mostrador na mesma distância do centro, medida na metade de baixo (onde não há ponteiro)
    face = Image.open(os.path.join(OUT, "clock.png")).convert("RGBA")
    fp = face.load()
    cx, cy = 31.5, 31.5
    rings = {}
    for y in range(int(cy) + 3, SIZE):
        for x in range(SIZE):
            r, g, b, a = fp[x, y]
            d = round(((x - cx) ** 2 + (y - cy) ** 2) ** 0.5)
            if a and d <= 16 and (r + g + b) / 3 > 170:
                rings.setdefault(d, []).append((r, g, b))
    def avg(d):
        for k in list(range(d, 18)) + list(range(d, -1, -1)):
            if rings.get(k):
                c = rings[k]
                return tuple(sum(v[i] for v in c) // len(c) for i in range(3)) + (255,)
        return (235, 215, 180, 255)
    for y in range(SIZE):
        for x in range(SIZE):
            d = round(((x - cx) ** 2 + (y - cy) ** 2) ** 0.5)
            r, g, b, a = fp[x, y]
            if d <= 15 or (d <= 17 and (r + g + b) / 3 < 170 and abs(x - cx) > 3):
                fp[x, y] = avg(d)
    face.save(os.path.join(OUT, "clock_face.png"))
    for a, src in ALIAS.items():
        Image.open(os.path.join(OUT, src + ".png")).save(os.path.join(OUT, a + ".png"))
    print("ícones de clima:", len(BOXES) + len(ALIAS))
