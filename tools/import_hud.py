#!/usr/bin/env python3
"""
HUD a partir do modelo (assets/source/hud_mockup.png, fundo verde). Recorta cada peça, apaga o conteúdo
"de exemplo" (textos, barras cheias, ícones dos slots, rosto do retrato) e salva em assets/sprites/ui/hud/:

  portrait_frame.png  moldura do retrato (miolo transparente: o jogo desenha o seu personagem por baixo)
  bars.png            painel de vida/energia (os trilhos das barras vazios: o jogo desenha o preenchimento)
  topbar.png          painel do dinheiro/hora/clima (só a moeda fica; o resto o jogo escreve)
  hotbar.png          barra rápida com os 6 espaços vazios
  joy_base.png, joy_knob.png   joystick
  btn_round.png       botão redondo vazio (usar, livro, correr, opções)
  btn_bag.png         botão da mochila;  hand.png  a mão (botão de interagir e mão vazia)
  scripts/ui/hud_layout.gd   onde fica cada coisa dentro das peças (frações do tamanho da imagem)

As imagens saem com ~2x o tamanho em que aparecem na tela de 640x360 (no celular fica 1:1).
Uso: python3 tools/import_hud.py
"""
import json
import os
import sys
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "hud_mockup.png")
OUT = os.path.join(ROOT, "assets", "sprites", "ui", "hud")

# peças no modelo (x0, y0, x1, y1)
BOX = {
    "portrait": (5, 9, 238, 233), "bars": (247, 41, 674, 211), "top": (1042, 35, 1658, 145),
    "joy": (34, 553, 354, 866), "hotbar": (400, 690, 1338, 875), "hand": (1402, 673, 1649, 891),
    "bag": (1459, 461, 1651, 653),
}
# altura final (px da imagem; a tela usa metade)
OUT_H = {"portrait": 104, "bars": 92, "top": 72, "hotbar": 104, "joy": 160, "hand": 112, "bag": 98}


GD_TEMPLATE = """class_name HudLayout
## Gerado por tools/import_hud.py: onde fica cada coisa dentro das peças da HUD
## (frações x0, y0, x1, y1 do tamanho da imagem).

const L := %s


static func rect(piece: String, key: String, size: Vector2) -> Rect2:
	var f: Array = L[piece][key]
	return Rect2(f[0] * size.x, f[1] * size.y, (f[2] - f[0]) * size.x, (f[3] - f[1]) * size.y)


static func slot(i: int, size: Vector2) -> Rect2:
	var f: Array = L["hotbar"]["slots"][i]
	return Rect2(f[0] * size.x, f[1] * size.y, (f[2] - f[0]) * size.x, (f[3] - f[1]) * size.y)
"""


def is_bg(p):
    r, g, b = p[:3]
    return g > 140 and g - max(r, b) > 60


def key_flood(im):
    """Tira só o verde do fundo (ligado à borda); o verde de dentro (barra de energia, folhas) fica."""
    px = im.load()
    w, h = im.size
    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            q.append((x, y))
    while q:
        x, y = q.popleft()
        if not (0 <= x < w and 0 <= y < h) or seen[y * w + x]:
            continue
        seen[y * w + x] = 1
        if not is_bg(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    # borda esverdeada: tira o verde (anti-serrilhado)
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and g > r + 30 and g > b + 30 and g > 150:
                near_clear = any(0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3] == 0
                                 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if near_clear:
                    px[x, y] = (r, max(r, b), b, a)
    return im


def erase_h(im, box):
    """Apaga um retângulo interpolando, linha a linha, entre a cor da esquerda e a da direita."""
    px = im.load()
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        a, b = px[x0 - 1, y], px[x1, y]
        for x in range(x0, x1):
            t = (x - x0 + 1) / (x1 - x0 + 1)
            px[x, y] = tuple(int(a[k] + (b[k] - a[k]) * t) for k in range(4))


def radial_fill(im, box, center):
    """Apaga um retângulo dentro de um disco: cada pixel pega a cor do disco na mesma distância do centro,
    num ponto fora do retângulo (o disco tem sombra em anéis)."""
    px = im.load()
    cx, cy = center
    x0, y0, x1, y1 = box
    src = im.copy().load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            r = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if cy + r >= y1 + 1:
                px[x, y] = src[cx, int(cy + r)]
            elif cx - r <= x0 - 1:
                px[x, y] = src[int(cx - r), cy]
            else:
                px[x, y] = src[x0 - 4, cy]


def largest_only(im):
    """Mantém só o maior pedaço (tira pontinhos soltos)."""
    from import_animals import components
    comps = components(im, 1)
    if len(comps) < 2:
        return im
    keep = max(comps, key=lambda c: c["area"])
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    a, b = im.load(), out.load()
    for x, y in keep["pts"]:
        b[x, y] = a[x, y]
    return out


def fill_rect(im, box, color, radius=0):
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(box, radius=radius, fill=color)


def clear_rect(im, box, radius=0):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    clear = Image.new("RGBA", im.size, (0, 0, 0, 0))
    im.paste(clear, (0, 0), mask)


def scale_out(name, im):
    h = OUT_H[name]
    s = h / im.height
    return im.resize((max(1, round(im.width * s)), h), Image.LANCZOS)


def frac(box, size):
    return [round(box[0] / size[0], 4), round(box[1] / size[1], 4), round(box[2] / size[0], 4), round(box[3] / size[1], 4)]


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    full = key_flood(Image.open(SRC).convert("RGBA"))
    p = {k: full.crop(b) for k, b in BOX.items()}
    layout = {}

    # ---- retrato: miolo transparente
    port = p["portrait"]
    inner = (42, 42, 201, 201)
    clear_rect(port, inner, 12)
    layout["portrait"] = {"inner": frac(inner, port.size)}

    # ---- barras: trilhos vazios (escuros); o jogo desenha o preenchimento dentro de "fill"
    bars = p["bars"]
    trough = (62, 36, 22, 255)
    for (x0, y0, x1, y1) in ((99, 28, 393, 66), (99, 103, 393, 141)):
        fill_rect(bars, (x0, y0, x1, y1), trough, 9)
    layout["bars"] = {"health": frac((101, 30, 391, 64), bars.size), "energy": frac((101, 105, 391, 139), bars.size)}

    # ---- painel de cima: tira texto, sol e nuvem (a moeda fica)
    top = p["top"]
    erase_h(top, (118, 26, 258, 84))
    erase_h(top, (284, 12, 492, 96))      # sol (as pontas passam da borda) e hora
    erase_h(top, (510, 10, 598, 98))      # nuvem
    layout["top"] = {"money": frac((112, 20, 262, 90), top.size), "time_icon": frac((290, 25, 356, 85), top.size),
                     "time": frac((356, 20, 495, 90), top.size), "weather": frac((514, 22, 596, 88), top.size)}

    # ---- barra rápida: limpa o 1º espaço e copia para os 6 (tira o destaque verde do 3º)
    hot = p["hotbar"]
    SX, SY, SW, SH, PITCH = 59, 40, 120, 117, 140
    erase_h(hot, (SX + 8, SY + 6, SX + SW - 8, SY + SH + 8))     # inclui os números em cima da borda
    clean = hot.crop((SX - 12, SY - 12, SX + SW + 12, SY + SH + 12))
    for i in range(1, 6):
        hot.alpha_composite(clean, (SX - 12 + PITCH * i, SY - 12))
    layout["hotbar"] = {"slots": [frac((SX + PITCH * i, SY, SX + PITCH * i + SW, SY + SH), hot.size) for i in range(6)]}

    # ---- joystick: botão (círculo bege) separado da base
    joy = p["joy"]
    jp = joy.load()
    xs, ys = [], []
    for y in range(joy.height):
        for x in range(joy.width):
            r, g, b, a = jp[x, y]
            if a and r > 190 and g > 160 and b > 120 and abs(x - joy.width / 2) < 90 and abs(y - joy.height / 2) < 90:
                xs.append(x)
                ys.append(y)
    kb = (min(xs) - 4, min(ys) - 4, max(xs) + 5, max(ys) + 5)
    knob = Image.new("RGBA", joy.size, (0, 0, 0, 0))
    mask = Image.new("L", joy.size, 0)
    ImageDraw.Draw(mask).ellipse(kb, fill=255)
    knob.paste(joy, (0, 0), mask)
    knob = knob.crop(kb)
    # embaixo do botão: o verde-oliva do fundo do joystick
    cx, cy = (kb[0] + kb[2]) // 2, (kb[1] + kb[3]) // 2
    olive = jp[cx, kb[1] - 10]
    ImageDraw.Draw(joy).ellipse(kb, fill=olive)
    layout["joy"] = {"knob_d": round((kb[2] - kb[0]) / joy.width, 4), "ring_d": round(0.92, 4)}

    # ---- botões: base vazia (sem a mão) e a mão sozinha
    hand_btn = p["hand"]
    hb = (48, 38, 172, 172)
    hand = hand_btn.crop(hb)
    hp = hand.load()
    for y in range(hand.height):
        for x in range(hand.width):
            r, g, b, a = hp[x, y]
            # tira o marrom do disco (fica a mão e o contorno preto)
            if a and abs(r - 150) < 55 and 50 < g < 125 and b < 80 and r - b > 60:
                hp[x, y] = (0, 0, 0, 0)
    radial_fill(hand_btn, hb, (112, 100))
    layout["button"] = {"circle": frac((2, 0, 224, 218), hand_btn.size)}
    layout["bag"] = {"circle": frac((0, 8, 172, 183), p["bag"].size)}

    scale_out("portrait", port).save(os.path.join(OUT, "portrait_frame.png"))
    scale_out("bars", bars).save(os.path.join(OUT, "bars.png"))
    scale_out("top", top).save(os.path.join(OUT, "topbar.png"))
    scale_out("hotbar", hot).save(os.path.join(OUT, "hotbar.png"))
    scale_out("joy", joy).save(os.path.join(OUT, "joy_base.png"))
    knob.resize((round(knob.width * OUT_H["joy"] / joy.height),) * 2, Image.LANCZOS).save(os.path.join(OUT, "joy_knob.png"))
    scale_out("hand", hand_btn).save(os.path.join(OUT, "btn_round.png"))
    scale_out("bag", p["bag"]).save(os.path.join(OUT, "btn_bag.png"))
    hand = largest_only(hand)
    hand = hand.crop(hand.getbbox())
    s = 64 / max(hand.size)
    hand.resize((round(hand.width * s), round(hand.height * s)), Image.LANCZOS).save(os.path.join(OUT, "hand.png"))
    # medidas para o jogo (frações x0, y0, x1, y1 de cada imagem), como script para ir junto no APK
    with open(os.path.join(ROOT, "scripts", "ui", "hud_layout.gd"), "w") as f:
        f.write(GD_TEMPLATE % json.dumps(layout))
    print("HUD importada em", OUT)
