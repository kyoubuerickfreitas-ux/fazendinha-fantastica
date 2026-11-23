#!/usr/bin/env python3
"""
Protagonista novo (animações do PixelLab, GIFs de 256x256 em assets/source/player_v2/).
Gera, em quadros de 128x128 (o jogo desenha com escala 0,5: mais nítido na tela do celular):
  assets/sprites/player.png          9 colunas x 4 linhas (baixo, esquerda, direita, cima);
                                     coluna 0 = parado, 1..8 = caminhada
  assets/sprites/player_actions.png  9 colunas x 24 linhas (ferramenta * 4 + direção), como antes
  assets/sprites/player/look_mask.png, look_mask_actions.png   classes para trocar as cores
     (vermelho 60 pele, 120 camisa, 180 calção, 0 manter) — ver assets/shaders/player_look.gdshader
A esquerda é a direita espelhada. O que ainda não tem animação fica vazio (o jogo usa o golpe simples):
de costas só existe a pose parada (andar = pose parada balançando).
Uso: python3 tools/import_player_v2.py
"""
import colorsys
import os

from PIL import Image, ImageOps, ImageSequence

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "player_v2")
SPR = os.path.join(ROOT, "assets", "sprites")
CELL = 128
SCALE = 112 / 256          # o quadro de 256 vira 112 px dentro da célula de 128
FEET = 126                 # onde ficam os pés na célula (sobra espaço em cima para o cabelo)
GIF_FEET = 247

DOWN, LEFT, RIGHT, UP = 0, 1, 2, 3
TOOLS = ["axe", "hoe", "pickaxe", "watering_can", "scythe", "fishing_rod"]
# animação -> arquivo
ANIMS = {
    "walk_down": "walk_down.gif", "walk_right": "walk_right.gif",
    "water_down": "water_down.gif", "water_right": "water_right.gif",
    "axe_down": "axe_down.gif", "axe_right": "axe_right.gif",
    "pickaxe_down": "pickaxe_down.gif",
    "fishing_down": "fishing_down.gif", "fishing_right": "fishing_right.gif",
    "hoe_right": "hoe_right.gif", "hoe_down": "hoe_down.gif", "run_down": "run_down.gif",
}
BACK = os.path.join(ROOT, "pixellab", "protagonista_4_costas.png")


def frames(name):
    im = Image.open(os.path.join(SRC, ANIMS[name]))
    out = [f.convert("RGBA") for f in ImageSequence.Iterator(im)]
    if name.startswith("axe"):
        out = [fill_blade(f) for f in out]
    # andar/correr: a classificação por cor+posição já acerta; golpes: paleta própria de cada animação
    cmap = None if name.startswith(("walk", "run")) else color_classes(out[0])
    for f in out:
        f.info["cmap"] = cmap
        f.info["tol"] = 14 if name.startswith(("walk", "run")) else 26    # golpes variam mais a paleta
    if name.endswith("_down") and not name.startswith(("walk", "run")):
        out = [out[0]] + [repaint_shirt(out[0], f) for f in out[1:]]
    return out


def repaint_shirt(idle, img):
    """Nos golpes de frente o PixelLab pintou a regata com a cor da pele: onde a pose parada tem regata e
    este quadro tem pele (e o corpo está no mesmo lugar), volta a pintar de regata, com a sombra da pele."""
    import numpy as np
    li = np.array(label_frame(idle))[..., 0]
    lf = np.array(label_frame(img))[..., 0]
    shirt_idle = li == SHIRT
    if (lf == SHIRT).sum() > shirt_idle.sum() * 0.5:
        return img                                   # a regata já aparece: nada a fazer
    a = np.array(img)
    sel = shirt_idle & (lf == SKIN)
    # não pinta os braços: só o que tem regata em volta na pose parada (miolo do molde)
    core = shirt_idle.copy()
    for dy, dx in ((2, 0), (-2, 0), (0, 2), (0, -2)):
        core &= np.roll(np.roll(shirt_idle, dy, 0), dx, 1)
    sel &= core
    lum = a[..., :3].astype(float).mean(-1)
    base = np.array([225, 192, 158], float)
    f = np.clip(lum / 175.0, 0.7, 1.12)
    a[sel, :3] = np.clip(base[None, :] * f[sel][:, None], 0, 255).astype(np.uint8)
    out = Image.fromarray(a, "RGBA")
    out.info["cmap"] = img.info.get("cmap")
    out.info["tol"] = img.info.get("tol", 14)
    return out


def color_classes(first):
    """Cada animação do PixelLab tem a sua paleta. O 1º quadro é a pose parada (onde a classificação por
    cor+posição acerta): cada cor exata dele vira pele/regata/calção pela maioria; a cor do bege que
    aparece na cabeça e na regata fica TAN (decidida pela posição em cada quadro)."""
    import numpy as np
    from collections import defaultdict
    lab = np.array(label_frame(first))[..., 0]
    a = np.array(first)
    votes = defaultdict(lambda: defaultdict(int))
    for y, x in zip(*np.nonzero(a[..., 3] >= 120)):
        votes[tuple(int(v) for v in a[y, x, :3])][int(lab[y, x])] += 1
    cmap = {}
    for col, v in votes.items():
        tot = sum(v.values())
        cls, n = max(v.items(), key=lambda kv: kv[1])
        if v.get(SKIN, 0) > tot * 0.2 and v.get(SHIRT, 0) > tot * 0.2:
            cmap[col] = TAN
        elif n >= tot * 0.6:
            cmap[col] = cls
    return cmap


def fill_blade(img, r=5):
    """A lâmina do machado veio só com o contorno (o miolo transparente, às vezes aberto de um lado).
    Fecha o contorno engrossando o desenho (r px), acha os buracos fechados e pinta de metal os que têm
    borda de contorno escuro ou metal cinza (os vãos entre braço e corpo têm borda de pele e ficam)."""
    import numpy as np
    from collections import deque
    a = np.array(img)
    solid = a[..., 3] >= 120
    h, w = solid.shape
    thick = solid.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                thick |= np.roll(np.roll(solid, dy, 0), dx, 1)
    outside = np.zeros_like(solid)
    q = deque([(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)])
    while q:
        y, x = q.popleft()
        if not (0 <= y < h and 0 <= x < w) or outside[y, x] or thick[y, x]:
            continue
        outside[y, x] = True
        q.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    # o que não é "fora": buracos + desenho engrossado; o desenho engrossado volta encolhendo r px
    near_out = outside.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                near_out |= np.roll(np.roll(outside, dy, 0), dx, 1)
    cand = (~solid) & (~near_out)
    seen = np.zeros_like(cand)
    for y0, x0 in zip(*np.nonzero(cand)):
        if seen[y0, x0]:
            continue
        comp, border = [], []
        q = deque([(y0, x0)])
        seen[y0, x0] = True
        while q:
            y, x = q.popleft()
            comp.append((y, x))
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if not (0 <= ny < h and 0 <= nx < w):
                    continue
                if solid[ny, nx]:
                    border.append(a[ny, nx, :3])
                elif cand[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        if len(comp) > 1500 or len(border) < 8:
            continue
        grey = sum(1 for c in border if int(c.max()) < 80
                   or colorsys.rgb_to_hsv(*(int(v) / 255 for v in c))[1] < 0.22)
        metal = sum(1 for c in border if int(c.min()) > 120
                    and colorsys.rgb_to_hsv(*(int(v) / 255 for v in c))[1] < 0.18)
        if grey < len(border) * 0.75 or metal < len(border) * 0.12 or len(comp) > 700:
            continue                          # vão entre as pernas etc.: borda só de contorno
        for y, x in comp:
            a[y, x] = (196, 199, 206, 255)
    # o miolo fica um pouco aberto na borda (o r encolhido): fecha com metal mais escuro
    filled = (a[..., 3] >= 120) & ~solid
    ring = np.zeros_like(solid)
    for dy in (-2, -1, 0, 1, 2):
        for dx in (-2, -1, 0, 1, 2):
            ring |= np.roll(np.roll(filled, dy, 0), dx, 1)
    ring &= (~solid) & (~filled) & (~outside)
    a[ring] = (150, 152, 160, 255)
    return Image.fromarray(a, "RGBA")


def cell(img, dy=0, k=1.0, feet=GIF_FEET):
    """Quadro de 256 -> célula de 128 (pés no lugar certo, alfa limpo). k aumenta animações desenhadas
    menores no quadro (a corrida), com os pés (feet, na arte) no lugar."""
    sc = SCALE * k
    if LABELS:
        img = label_frame(img)
        small = img.resize((round(256 * sc), round(256 * sc)), Image.NEAREST)
    else:
        small = img.resize((round(256 * sc), round(256 * sc)), Image.LANCZOS)
        px = small.load()
        for y in range(small.height):
            for x in range(small.width):
                r, g, b, a = px[x, y]
                px[x, y] = (r, g, b, 255) if a >= 120 else (0, 0, 0, 0)
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    out.alpha_composite(small, ((CELL - small.width) // 2, FEET - round(feet * sc) + dy))
    return out


def put_row(sheet, row, cells, start=0):
    for i, c in enumerate(cells):
        sheet.alpha_composite(c, ((start + i) * CELL, row * CELL))


def mirror(cells):
    return [ImageOps.mirror(c) for c in cells]


def fit9(cells):
    """As animações de ferramenta têm 9 quadros (as de 8 repetem o último)."""
    cells = list(cells)[:9]
    while len(cells) < 9:
        cells.append(cells[-1])
    return cells


# ------------------------------------------------------------------ máscara de cores
# A arte usa poucas cores chapadas. Cada cor é ligada à parte do corpo; a cabeça tem um bege ("tan")
# quase igual à sombra da regata, então o tan se decide pela posição: o pedaço de cima é a cabeça.
LABELS = False
SKIN_C = [(230, 170, 131), (231, 176, 137), (225, 159, 122), (203, 144, 111), (198, 125, 95)]
TAN_C = [(210, 169, 133), (207, 164, 128), (214, 178, 145)]
SHIRT_C = [(225, 192, 158), (239, 225, 211)]
PANTS_C = [(154, 139, 105), (140, 133, 92), (141, 123, 85), (125, 118, 78), (87, 100, 60), (87, 81, 55),
           (126, 100, 73)]
STAIN_C = [(180, 124, 95), (164, 102, 78)]
SKIN, SHIRT, PANTS = 60, 120, 180
TAN, STAIN = 1, 2


def label_frame(img):
    """Quadro de 256 -> imagem de rótulos (vermelho = classe, alfa 255 onde tem classe)."""
    import numpy as np
    from collections import deque
    a = np.array(img).astype(int)
    rgb, alpha = a[..., :3], a[..., 3] >= 120
    h, w = alpha.shape
    lab = np.zeros((h, w), np.int32)
    cmap = img.info.get("cmap")
    if cmap:
        # cor exata do 1º quadro, ou a mais próxima dele (as paletas variam um pouco de quadro a quadro)
        keys = np.array(list(cmap.keys()), float)
        vals = np.array(list(cmap.values()))
        cols, inv = np.unique(rgb[alpha].reshape(-1, 3), axis=0, return_inverse=True)
        d = np.sqrt(((cols[:, None, :] - keys[None, :, :]) ** 2).sum(-1))
        j = d.argmin(1)
        tol = img.info.get("tol", 14)
        cls_of = np.where(d[np.arange(len(cols)), j] < tol, vals[j], 0)
        lab[alpha] = cls_of[inv.ravel()]
    else:
        best = np.full((h, w), 1e9)
        for cls, cols in ((SKIN, SKIN_C), (TAN, TAN_C), (SHIRT, SHIRT_C), (PANTS, PANTS_C), (STAIN, STAIN_C)):
            for c in cols:
                d = np.sqrt(((rgb - np.array(c)) ** 2).sum(-1))
                better = alpha & (d < 24) & (d < best)
                lab[better] = cls
                best[better] = d[better]
    def comps_of(cls):
        seen = np.zeros((h, w), bool)
        out = []
        for y0, x0 in zip(*np.nonzero(lab == cls)):
            if seen[y0, x0]:
                continue
            q, pts = deque([(y0, x0)]), []
            seen[y0, x0] = True
            while q:
                y, x = q.popleft()
                pts.append((y, x))
                for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                    if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx] and lab[ny, nx] == cls:
                        seen[ny, nx] = True
                        q.append((ny, nx))
            out.append(pts)
        return out

    # calção: só os pedaços grandes (sombras dos pés e contornos com a mesma cor ficam de fora)
    pc = comps_of(PANTS)
    big_p = max((len(c) for c in pc), default=0)
    pants_pts = []
    main_p = max(pc, key=len) if pc else []
    main_bottom = max((p[0] for p in main_p), default=h)
    for pts in pc:
        below = min(p[0] for p in pts) > main_bottom - 2      # sola do pé com a cor do calção
        if len(pts) < big_p * 0.2 or (pts is not main_p and below):
            for y, x in pts:
                lab[y, x] = STAIN          # decidido pela vizinhança abaixo (pé = pele)
        else:
            pants_pts += pts
    pants_mid = (sum(p[0] for p in pants_pts) / len(pants_pts)) if pants_pts else h
    # tan: o pedaço mais alto (a cabeça) e o que fica abaixo do calção (pés) é pele; o resto é regata
    shirt_y = np.nonzero(lab == SHIRT)[0]
    top_shirt = shirt_y.min() if len(shirt_y) else h
    comps = comps_of(TAN)
    head = max(comps, key=len) if comps else []
    for pts in comps:
        cy = sum(p[0] for p in pts) / len(pts)
        is_skin = pts is head or cy < top_shirt - 4 or cy > pants_mid
        for y, x in pts:
            lab[y, x] = SKIN if is_skin else SHIRT
    # manchas: da regata se estão no meio da regata, senão sombra da pele
    pad = np.pad(lab, 4)
    shirt_n = np.zeros((h, w), np.int32)
    skin_n = np.zeros((h, w), np.int32)
    for dy in range(9):
        for dx in range(9):
            win = pad[dy:dy + h, dx:dx + w]
            shirt_n += win == SHIRT
            skin_n += win == SKIN
    st = lab == STAIN
    to_shirt = st & (shirt_n > skin_n)
    lab[to_shirt] = SHIRT
    lab[st & ~to_shirt] = SKIN
    # roupa: só o pedaço principal e o que encosta nele (lâminas de metal têm cor de calção/regata)
    for cls in (PANTS, SHIRT):
        cc = comps_of(cls)
        if not cc:
            continue
        # o pedaço principal fica na faixa certa do corpo (calção embaixo, regata no meio) e perto do eixo
        # do corpo; lâminas de metal de cor parecida ficam fora
        sy, sx = np.nonzero(lab == SKIN)
        top, bot = (sy.min(), sy.max()) if len(sy) else (0, h)
        mid_x = float(np.median(sx)) if len(sx) else w / 2
        band = (0.55, 0.9) if cls == PANTS else (0.3, 0.72)

        def ok(pts):
            cy = sum(p[0] for p in pts) / len(pts)
            cx = sum(p[1] for p in pts) / len(pts)
            t = (cy - top) / max(1, bot - top)
            return band[0] <= t <= band[1] and abs(cx - mid_x) < 45

        good = [c for c in cc if ok(c)]
        main = max(good or cc, key=len)
        near = np.zeros((h, w), bool)
        for y, x in main:
            near[max(0, y - 3):y + 4, max(0, x - 3):x + 4] = True
        for pts in cc:
            if pts is main or (ok(pts) and len(pts) > 20) or any(near[y, x] for y, x in pts):
                continue
            for y, x in pts:
                lab[y, x] = 0
    out = np.zeros((h, w, 4), np.uint8)
    out[..., 0] = np.where(lab >= SKIN, lab, 0)
    out[..., 3] = np.where(lab >= SKIN, 255, 0)
    return Image.fromarray(out, "RGBA")


def build():
    walk = Image.new("RGBA", (CELL * 9, CELL * 5), (0, 0, 0, 0))     # linha 4: correndo de frente
    idle_down = cell(frames("axe_down")[0])
    idle_right = cell(frames("axe_right")[0])
    put_row(walk, DOWN, [idle_down] + [cell(f) for f in frames("walk_down")])
    right = [idle_right] + [cell(f) for f in frames("walk_right")]
    put_row(walk, RIGHT, right)
    put_row(walk, LEFT, mirror(right))
    back = Image.open(BACK).convert("RGBA")
    back_cells = [cell(back)] + [cell(back, dy=-(1 if i % 4 in (1, 2) else 0)) for i in range(8)]
    put_row(walk, UP, back_cells)
    put_row(walk, 4, [idle_down] + [cell(f, k=1.05, feet=222) for f in frames("run_down")])
    acts = Image.new("RGBA", (CELL * 9, CELL * 4 * len(TOOLS)), (0, 0, 0, 0))
    for tool, prefix in (("axe", "axe"), ("watering_can", "water"), ("pickaxe", "pickaxe"),
                         ("fishing_rod", "fishing"), ("hoe", "hoe")):
        t = TOOLS.index(tool)
        if prefix + "_down" in ANIMS:
            put_row(acts, t * 4 + DOWN, fit9(cell(f) for f in frames(prefix + "_down")))
        if prefix + "_right" in ANIMS:
            r = fit9(cell(f) for f in frames(prefix + "_right"))
            put_row(acts, t * 4 + RIGHT, r)
            put_row(acts, t * 4 + LEFT, mirror(r))
    return walk, acts


if __name__ == "__main__":
    walk, acts = build()
    walk.save(os.path.join(SPR, "player.png"))
    acts.save(os.path.join(SPR, "player_actions.png"))
    LABELS = True
    mwalk, macts = build()
    os.makedirs(os.path.join(SPR, "player"), exist_ok=True)
    for m, name in ((mwalk, "look_mask.png"), (macts, "look_mask_actions.png")):
        m.convert("RGB").save(os.path.join(SPR, "player", name))
    # brilho médio de cada classe (para os REF_* do shader)
    import numpy as np
    wa = np.array(walk).astype(float)
    ma = np.array(mwalk)[..., 0]
    lum = wa[..., :3].mean(-1) / 255
    print("REF pele %.3f camisa %.3f calção %.3f" % tuple(lum[ma == k].mean() for k in (SKIN, SHIRT, PANTS)))
    print("player", walk.size, "actions", acts.size)
