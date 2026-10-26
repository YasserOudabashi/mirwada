"""Icone delle primitive (US-8B72): un glifo 32x32 per primitiva attiva di data/schema/primitives.json.

    python tools/art/build_primitive.py

Il glifo e' disegnato a 4 toni, non a colori: 0 contorno, 1 scuro, 2 primario, 3 accento, scritti nella PNG come
grigi (0, 85, 170, 255). Il colore lo mette il gioco con shaders/rampa_pathway.gdshader dalla palette del Pathway
(data/vfx.json pathway_palette_visiva), come i VFX: la forma e' una, il colore cambia con il Pathway.
Ogni forma si disegna a 4x con PIL e si riduce a maggioranza (niente sfumature); la luce in alto a sinistra e il
contorno di 1 px si aggiungono da soli. File: assets/icone/primitive/<primitiva>.png; foglio di controllo con
alcune palette in arte/revisione/icone_primitive.png.
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "icone", "primitive")
REVISIONE = os.path.join(ROOT, "arte", "revisione", "icone_primitive.png")
LATO, K = 32, 4
GRIGI = {0: 0, 1: 85, 2: 170, 3: 255}


# --- forme (coordinate nel quadrato 32x32) -------------------------------------------------------

def ell(x0, y0, x1, y1):
    return lambda d: d.ellipse([x0 * K, y0 * K, x1 * K - 1, y1 * K - 1], fill=255)


def pol(*pts):
    return lambda d: d.polygon([(x * K, y * K) for x, y in pts], fill=255)


def lin(x0, y0, x1, y1, w):
    def f(d):
        d.line([(x0 * K, y0 * K), (x1 * K, y1 * K)], fill=255, width=int(w * K))
        for x, y in ((x0, y0), (x1, y1)):
            d.ellipse([(x - w / 2) * K, (y - w / 2) * K, (x + w / 2) * K, (y + w / 2) * K], fill=255)
    return f


def arc(cx, cy, r, w, a0, a1):
    """Arco di spessore w (gradi: 0 = destra, in senso orario come PIL)."""
    return lambda d: d.arc([(cx - r) * K, (cy - r) * K, (cx + r) * K, (cy + r) * K], a0, a1, fill=255, width=int(w * K))


def anello(cx, cy, r, w):
    return arc(cx, cy, r, w, 0, 360)


def E(livello, *forme, ombra=True, bordo=True, togli=()):
    """Un elemento: le forme unite, meno quelle in `togli`, con il suo tono (1-3, -1 = buco)."""
    return {"livello": livello, "forme": forme, "togli": togli, "ombra": ombra, "bordo": bordo}


def B(*forme):
    return E(-1, *forme, ombra=False, bordo=False)


def figura(cx, cy, s=1.0):
    """Sagoma di persona: testa e busto."""
    return [ell(cx - 3.5 * s, cy - 10 * s, cx + 3.5 * s, cy - 3 * s),
            pol((cx - 6 * s, cy + 9 * s), (cx - 5 * s, cy - 1 * s), (cx - 2 * s, cy - 3 * s),
                (cx + 2 * s, cy - 3 * s), (cx + 5 * s, cy - 1 * s), (cx + 6 * s, cy + 9 * s))]


def raggi(cx, cy, r0, r1, n, w, fase=0.0):
    out = []
    for k in range(n):
        a = math.radians(fase + 360.0 * k / n)
        out.append(lin(cx + r0 * math.cos(a), cy + r0 * math.sin(a), cx + r1 * math.cos(a), cy + r1 * math.sin(a), w))
    return out


GLIFI = {
    "melee_arc": [E(2, ell(2, 2, 30, 30), togli=[ell(0, -1, 27, 26)]),
                  E(3, arc(13.5, 12.5, 14.6, 1.3, 15, 115), ombra=False, bordo=False)],
    "projectile": [E(1, pol((3, 29), (14, 13), (19, 18)), ombra=False),
                   E(2, ell(13, 4, 28, 19)), E(3, ell(16, 7, 22, 13), ombra=False, bordo=False)],
    "dash": [E(2, pol((3, 6), (11, 6), (19, 16), (11, 26), (3, 26), (11, 16))),
             E(3, pol((13, 6), (21, 6), (29, 16), (21, 26), (13, 26), (21, 16)))],
    "buff_stat": [E(2, pol((16, 2), (28, 15), (20, 15), (20, 29), (12, 29), (12, 15), (4, 15))),
                  E(3, lin(16, 8, 16, 24, 1.4), ombra=False, bordo=False)],
    "debuff_stat": [E(1, pol((16, 30), (28, 17), (20, 17), (20, 3), (12, 3), (12, 17), (4, 17))),
                    E(2, lin(16, 8, 16, 22, 1.4), ombra=False, bordo=False)],
    "heal": [E(2, pol((12, 3), (20, 3), (20, 12), (29, 12), (29, 20), (20, 20), (20, 29), (12, 29), (12, 20),
                      (3, 20), (3, 12), (12, 12))),
             E(3, lin(16, 7, 16, 25, 1.4), lin(7, 16, 25, 16, 1.4), ombra=False, bordo=False)],
    "shield": [E(2, pol((5, 4), (27, 4), (27, 15), (16, 29), (5, 15))),
               E(3, pol((14, 7), (18, 7), (18, 23), (16, 25), (14, 23)), ombra=False)],
    "aura": [E(2, anello(16, 16, 13, 3)), E(3, anello(16, 16, 7, 2), ombra=False),
             E(3, ell(13, 13, 19, 19), ombra=False)],
    "dot": [E(2, ell(7, 12, 25, 29), pol((7, 20), (13, 9), (16, 2), (19, 9), (25, 20)), pol((19, 13), (25, 6), (24, 16))),
            E(3, ell(11, 18, 21, 28), pol((11, 23), (16, 11), (21, 23)), ombra=False)],
    "decay": [E(2, ell(5, 3, 27, 22), togli=[pol((17, 3), (13, 10), (17, 12), (12, 22), (14, 22), (20, 12), (16, 10),
                                                    (20, 3))]),
              E(1, ell(7, 21, 11, 27), ell(15, 22, 18, 30), ell(22, 20, 26, 25))],
    "light_purify": [E(2, *raggi(16, 16, 6, 14, 8, 3, 22.5)), E(3, ell(9, 9, 23, 23))],
    "transform": [E(2, arc(16, 16, 11, 4, 200, 340), pol((24, 3), (30, 12), (20, 13))),
                  E(3, arc(16, 16, 11, 4, 20, 160), pol((8, 29), (2, 20), (12, 19)))],
    "terrain_modify": [E(1, pol((2, 23), (30, 23), (30, 29), (2, 29)), ombra=False),
                       E(2, pol((5, 24), (10, 9), (15, 24)), pol((19, 24), (24, 11), (28, 24))),
                       E(3, pol((11, 24), (17, 3), (22, 24)))],
    "curse": [E(2, pol((3, 5), (29, 5), (16, 29)), togli=[pol((9, 9), (23, 9), (16, 22))]),
              E(3, ell(13, 10, 19, 16), ombra=False)],
    "summon": [E(2, anello(16, 16, 13, 3)), E(3, pol((16, 6), (22, 16), (16, 26), (10, 16))),
               E(3, ell(14, 1, 18, 5), ell(14, 27, 18, 31), ell(1, 14, 5, 18), ell(27, 14, 31, 18), ombra=False)],
    "fear": [E(2, ell(5, 3, 27, 23), pol((9, 17), (23, 17), (22, 28), (10, 28))),
             B(ell(9, 10, 15, 17), ell(17, 10, 23, 17), pol((16, 17), (14, 21), (18, 21)),
               lin(13, 24, 13, 28, 1), lin(16, 24, 16, 28, 1), lin(19, 24, 19, 28, 1))],
    "reveal_info": [E(2, ell(2, 9, 30, 25)), E(3, ell(10, 10, 22, 24), ombra=False),
                    E(1, ell(13, 13, 19, 21), ombra=False, bordo=False),
                    E(3, *raggi(16, 17, 12, 15, 3, 1.6, -125), ombra=False, bordo=False)],
    "teleport": [E(1, ell(9, 3, 23, 29), ombra=False), E(2, anello(16, 16, 9, 3), ombra=False),
                 E(3, ell(13, 9, 19, 23), ombra=False),
                 E(3, ell(3, 7, 6, 10), ell(26, 22, 29, 25), ell(25, 4, 28, 7), ombra=False)],
    "soul_detach": [E(1, *figura(11, 19, 0.95)),
                    E(3, ell(15, 2, 27, 14), pol((15, 8), (27, 8), (28, 22), (25, 19), (22, 23), (19, 19), (15, 22)))],
    "resurrect": [E(2, anello(16, 8, 5.5, 3.5), pol((14, 13), (18, 13), (18, 30), (14, 30)),
                    pol((6, 15), (26, 15), (26, 19), (6, 19))),
                  E(3, lin(16, 18, 16, 28, 1), ombra=False, bordo=False)],
    "plant_growth": [E(1, ell(4, 23, 28, 31), ombra=False), E(2, lin(16, 26, 16, 12, 2.2)),
                     E(3, pol((15, 14), (6, 12), (2, 4), (11, 5))), E(2, pol((17, 12), (24, 6), (30, 8), (25, 16)))],
    "mind_read": [E(2, ell(3, 5, 17, 26), ell(15, 5, 29, 26)),
                  B(lin(16, 6, 16, 25, 1.2), arc(9, 12, 4, 1, 270, 90), arc(23, 18, 4, 1, 90, 270)),
                  E(3, ell(13, 26, 19, 31))],
    "shadow_meld": [E(3, *figura(16, 18, 1.15)),
                    E(1, *figura(16, 18, 1.15), togli=[pol((0, 0), (16, 0), (16, 32), (0, 32))], ombra=False,
                      bordo=False)],
    "illusion": [E(1, *figura(20, 18, 1.0), ombra=False), E(3, *figura(12, 18, 1.0))],
    "steal": [E(2, ell(12, 3, 29, 20)), E(3, anello(20.5, 11.5, 5, 1.6), ombra=False),
              E(3, lin(14, 18, 7, 25, 3.2), pol((2, 30), (3, 19), (13, 29)))],
    "possess": [E(2, pol((5, 2), (27, 2), (27, 6), (5, 6))),
                E(3, lin(8, 6, 11, 17, 1), lin(16, 6, 16, 14, 1), lin(24, 6, 21, 17, 1), ombra=False, bordo=False),
                E(1, *figura(16, 23, 0.8))],
    "time_rewind": [E(2, anello(16, 16, 12, 4)), E(3, lin(16, 16, 16, 9, 2), lin(16, 16, 21, 19, 2), ombra=False),
                    E(3, pol((2, 6), (11, 2), (10, 11)))],
    "chain": [E(2, arc(11, 12, 8, 3.4, 0, 360)), E(3, arc(21, 20, 8, 3.4, 0, 360)),
              E(2, arc(11, 12, 8, 3.4, 300, 30), bordo=False)],
}


def _maschera(forme):
    im = Image.new("L", (LATO * K, LATO * K), 0)
    d = ImageDraw.Draw(im)
    for f in forme:
        f(d)
    a = np.asarray(im, float).reshape(LATO, K, LATO, K).mean(axis=(1, 3))
    return a >= 128


def _vicini(m):
    p = np.pad(m, 1)
    return p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]       # su, giu, sx, dx


def _dilata(m):
    su, giu, sx, dx = _vicini(m)
    return m | su | giu | sx | dx


def glifo(pid):
    tela = np.full((LATO, LATO), -1, int)
    for el in GLIFI[pid]:
        m = _maschera(el["forme"]) & ~_maschera(el["togli"])
        if el["livello"] < 0:
            tela[m] = -1
            continue
        if el["bordo"]:
            tela[_dilata(m) & ~m & (tela >= 0)] = 0
        lv = np.full((LATO, LATO), el["livello"], int)
        if el["ombra"]:
            su, giu, sx, dx = _vicini(m)
            dentro = m & su & giu & sx & dx
            if dentro.sum() >= 0.3 * m.sum():
                lv[m & (~su | ~sx)] = min(3, el["livello"] + 1)          # luce in alto a sinistra
                lv[m & (~giu | ~dx)] = max(1, el["livello"] - 1)
        tela[m] = lv[m]
    pieno = tela >= 0
    tela[_dilata(pieno) & ~pieno] = 0                                    # contorno di 1 px
    return tela


def png(tela):
    img = np.zeros((LATO, LATO, 4), np.uint8)
    for lv, g in GRIGI.items():
        img[tela == lv] = (g, g, g, 255)
    return img


def colora(tela, pal):
    """Anteprima come la fa lo shader: inchiostro, scuro (primario verso l'inchiostro), primario, accento."""
    hx = lambda h: np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float)   # noqa: E731
    ink, pri, acc = hx(pal["inchiostro"]), hx(pal["primario"]), hx(pal["accento"])
    toni = {0: ink, 1: pri + (ink - pri) * 0.45, 2: pri, 3: acc}
    img = np.zeros((LATO, LATO, 4), np.uint8)
    for lv, c in toni.items():
        img[tela == lv, :3] = c.astype(np.uint8)
        img[tela == lv, 3] = 255
    return img


def main():
    prim = json.load(open(os.path.join(ROOT, "data", "schema", "primitives.json")))["primitives"]
    attive = sorted(k for k, v in prim.items() if not v.get("deferred"))
    assert set(attive) == set(GLIFI), set(attive) ^ set(GLIFI)
    palette = json.load(open(os.path.join(ROOT, "data", "vfx.json")))["pathway_palette_visiva"]
    os.makedirs(OUT, exist_ok=True)
    tele = {}
    for pid in attive:
        tele[pid] = glifo(pid)
        Image.fromarray(png(tele[pid])).save(os.path.join(OUT, pid + ".png"))
    # foglio: una riga per palette (prime 4) su carta e su fondo scuro
    righe = []
    for bg in ((234, 212, 170), (38, 43, 68)):
        for pw in list(palette)[:4]:
            riga = np.zeros((LATO + 4, len(attive) * (LATO + 4), 3), np.uint8)
            riga[:] = bg
            for i, pid in enumerate(attive):
                img = colora(tele[pid], palette[pw])
                x = i * (LATO + 4) + 2
                a = img[..., 3:4] / 255.0
                riga[2:2 + LATO, x:x + LATO] = (img[..., :3] * a + riga[2:2 + LATO, x:x + LATO] * (1 - a)).astype(np.uint8)
            righe.append(riga)
    im = np.concatenate(righe, 0)
    os.makedirs(os.path.dirname(REVISIONE), exist_ok=True)
    Image.fromarray(im).resize((im.shape[1] * 2, im.shape[0] * 2), Image.NEAREST).save(REVISIONE)
    print(f"{len(attive)} icone di primitiva in assets/icone/primitive/, foglio in {os.path.relpath(REVISIONE, ROOT)}")


if __name__ == "__main__":
    main()
