#!/usr/bin/env python3
"""
Gera o ícone do app a partir da arte do jogo.

Saídas:
  icon.png                         512x512 (ícone do projeto e do APK)
  assets/app_icon/icon_192.png     192x192 (launcher Android)
  assets/app_icon/foreground.png   432x432 (ícone adaptável: personagens, com margem segura)
  assets/app_icon/background.png   432x432 (ícone adaptável: fundo)

Uso: python3 tools/make_app_icon.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402
from import_animals import find_frames, cut  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "app_icon")
S = 432  # tamanho do ícone adaptável


def hx(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def background():
    img = Image.new("RGBA", (S, S), hx("78945B"))
    d = ImageDraw.Draw(img)
    # céu suave em cima, colina de grama embaixo
    for y in range(S):
        t = y / S
        c = tuple(int(a + (b - a) * t) for a, b in zip(hx("CFE0A8")[:3], hx("9DB874")[:3]))
        d.line((0, y, S, y), fill=c + (255,))
    d.ellipse((-120, 250, S + 120, 640), fill=hx("526A23"))
    d.ellipse((-80, 270, S + 80, 640), fill=hx("6A8C42"))
    rng = random.Random(4)
    for _ in range(90):
        x, y = rng.randrange(0, S), rng.randrange(300, S)
        d.line((x, y, x + rng.randrange(-3, 4), y - rng.randrange(6, 14)), fill=hx("86A85A"), width=3)
    # sol
    d.ellipse((300, 40, 380, 120), fill=hx("F6E7A8"))
    d.ellipse((312, 52, 368, 108), fill=hx("F2D16B"))
    return img


def outline(img, width=6, color=(43, 33, 24, 255)):
    a = img.getchannel("A").point(lambda v: 255 if v > 100 else 0)
    grown = a.filter(ImageFilter.MaxFilter(width * 2 + 1))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(Image.new("RGBA", img.size, color), (0, 0), grown)
    out.alpha_composite(img)
    return out


def foreground():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # Moombor atrás, à direita
    moo_src = Image.open(os.path.join(ROOT, "assets", "source", "animals", "moombor.webp")).convert("RGBA")
    rows = find_frames(moo_src)
    moo = cut(moo_src, rows[0][0])
    moo = moo.resize((round(moo.width * 215 / moo.height), 215), Image.LANCZOS)
    img.alpha_composite(outline(moo, 5), (S - moo.width - 30, 200))
    # personagem grande na frente (close: as pernas saem pela borda)
    hero = Image.open(os.path.join(ROOT, "assets", "source", "base_body", "bald", "careca_1_frente.png")).convert("RGBA")
    hero = hero.crop(hero.getbbox())
    hero = hero.resize((round(hero.width * 400 / hero.height), 400), Image.LANCZOS)
    hero = outline(hero, 5)
    hx0, hy0 = 52, 92
    img.alpha_composite(hero, (hx0, hy0))
    # brotinho saindo do topo da cabeça
    a = hero.getchannel("A")
    cx = hero.width // 2
    top = next(y for y in range(hero.height) if a.getpixel((cx, y)) > 0) + hy0
    cx += hx0
    d = ImageDraw.Draw(img)
    d.line((cx, top + 8, cx + 2, top - 30), fill=hx("2B2118"), width=10)
    d.line((cx, top + 6, cx + 2, top - 28), fill=hx("4C6A30"), width=5)
    d.polygon([(cx, top - 26), (cx - 44, top - 52), (cx - 50, top - 30), (cx - 18, top - 16)], fill=hx("2B2118"))
    d.polygon([(cx - 3, top - 26), (cx - 40, top - 47), (cx - 44, top - 32), (cx - 18, top - 21)], fill=hx("86A85A"))
    d.polygon([(cx + 2, top - 28), (cx + 46, top - 64), (cx + 54, top - 38), (cx + 20, top - 18)], fill=hx("2B2118"))
    d.polygon([(cx + 5, top - 28), (cx + 43, top - 58), (cx + 48, top - 40), (cx + 20, top - 23)], fill=hx("B6C995"))
    return img


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius=radius, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    bg, fg = background(), foreground()
    bg.save(os.path.join(OUT, "background.png"))
    fg.save(os.path.join(OUT, "foreground.png"))
    full = bg.copy()
    full.alpha_composite(fg)
    # moldura de madeira, como a interface
    d = ImageDraw.Draw(full)
    d.rounded_rectangle((6, 6, S - 7, S - 7), radius=86, outline=hx("765137"), width=12)
    d.rounded_rectangle((16, 16, S - 17, S - 17), radius=78, outline=hx("A8784F"), width=4)
    full = rounded(full, 92)
    full.resize((512, 512), Image.LANCZOS).save(os.path.join(ROOT, "icon.png"))
    full.resize((192, 192), Image.LANCZOS).save(os.path.join(OUT, "icon_192.png"))
    print("ícone gerado")
