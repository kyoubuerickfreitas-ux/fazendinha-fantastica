#!/usr/bin/env python3
"""
O PixelLab às vezes troca a cor da ferramenta no meio de uma animação (no regar de lado, o regador fica
verde nos quadros do meio e bege nos outros). Repinta os tons do regador bege com os verdes do regador,
só à direita do corpo (o corpo da pose parada, 1º quadro), e só nos quadros em que ele não está verde.
Uso: python3 tools/recolor_can.py entrada.gif saida.gif
"""
import sys

import numpy as np
from PIL import Image, ImageSequence

# tom do regador bege -> verde equivalente
CAN = {(203, 179, 156): (117, 214, 130), (178, 152, 130): (74, 156, 87), (187, 185, 184): (121, 224, 136),
       (254, 254, 254): (178, 242, 186), (222, 218, 218): (150, 232, 160), (151, 146, 144): (59, 127, 68)}
TOL = 8


def body_right(first):
    """Borda direita do corpo (pele/regata/calção, sem o regador nem o contorno) no 1º quadro."""
    a = np.array(first.convert("RGBA"))
    rgb = a[..., :3].astype(int)
    body = (a[..., 3] > 0) & (rgb.sum(-1) > 150)
    for src in CAN:
        body &= np.abs(rgb - np.array(src)).max(-1) > TOL
    body[:90] = False
    xs = np.nonzero(body.any(0))[0]
    return int(np.percentile(xs, 90))


def recolor(frame, x0):
    a = np.array(frame.convert("RGBA"))
    rgb = a[..., :3].astype(int)
    op = a[..., 3] > 0
    green = op & (rgb[..., 1] > rgb[..., 0] + 40) & (rgb[..., 1] > rgb[..., 2] + 30)
    if green.sum() > 400:
        return Image.fromarray(a)          # regador já verde
    zone = np.zeros(op.shape, bool)
    zone[90:, x0:] = True
    for src, dst in CAN.items():
        m = op & zone & (np.abs(rgb - np.array(src)).max(-1) <= TOL)
        a[m, :3] = dst
    return Image.fromarray(a)


if __name__ == "__main__":
    im = Image.open(sys.argv[1])
    frames = [f.convert("RGBA").copy() for f in ImageSequence.Iterator(im)]
    x0 = body_right(frames[0]) - 6
    out = [recolor(f, x0) for f in frames]
    out[0].save(sys.argv[2], save_all=True, append_images=out[1:], duration=im.info.get("duration", 200),
                loop=0, disposal=2)
