#!/usr/bin/env python3
"""
Cercas da cidade a partir da cerca de madeira da bancada (assets/sprites/craft/fence.png):
  fence_h.png: a mesma cerca (um trecho na horizontal, 1 quadrado)
  fence_v.png: um trecho na vertical (o poste embaixo e a travessa, girada, subindo até o poste de cima)
Saída em assets/sprites/city/. Uso: python3 tools/make_city_fence.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "sprites", "craft", "fence.png")
OUT = os.path.join(ROOT, "assets", "sprites", "city")

if __name__ == "__main__":
    f = Image.open(SRC).convert("RGBA")
    f.save(os.path.join(OUT, "fence_h.png"))
    post = f.crop((2, 4, 12, 30))                       # poste da esquerda (10 x 26)
    rail = f.crop((12, 9, 23, 27)).rotate(90, expand=True)   # as duas travessas, giradas: 18 x 11
    v = Image.new("RGBA", (20, 58), (0, 0, 0, 0))
    for y in range(0, 33, rail.height):                  # travessas de cima a baixo do quadrado
        v.alpha_composite(rail, (1, y + 4))
    v.alpha_composite(post, (5, 58 - post.height))
    v.save(os.path.join(OUT, "fence_v.png"))
    print("fence_h", f.size, "fence_v", v.size)
