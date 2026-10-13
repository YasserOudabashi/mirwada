#!/usr/bin/env python3
"""
Costruttore degli sprite di Enel (il protagonista) per la skill sprite-forge.

    python tools/art/build_enel.py                  # scrive arte/sprite/personaggio_<anim>.json
    python tools/art/build_enel.py --skill <dir>    # in piu' check.py + render.py della skill
                                                      # e copia gli sheet in assets/placeholder/

Enel e' un MANICHINO: le parti (gambe, cappotto, braccia, spada, sciarpa) sono
forme semplici; la luce da alto-sinistra, il contorno da 1px e l'ombra che una
parte getta su quella sotto sono calcolati qui, uguali per tutti i frame. Solo
la testa e' disegnata pixel per pixel (3 viste). Ogni frame dice soltanto dove
stanno le parti: cosi' 174 frame restano coerenti, e cambiare un colore o una
parte qui rigenera tutto.

I JSON prodotti sono generati: non modificarli a mano, cambia questo file.
Numero di frame e durate vengono da data/animations.json (mai copiati qui).
"""

import argparse
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "arte", "sprite")
W = H = 32


# --- palette: Endesga 32 (CLAUDE.md v2), rampe con hue shift, contorno #181425 ---

COLORI = {
    "o": "#181425",                                              # inchiostro
    "A": "#262b44", "B": "#3a4466", "C": "#5a6988",              # cappotto
    "P": "#733e39", "Q": "#c28569", "R": "#e8b796",              # pelle esausta
    "S": "#a22633", "T": "#be4a2f",                              # sciarpa
    "W": "#8b9bb4", "X": "#c0cbdc",                              # bende
    "M": "#8b9bb4", "N": "#c0cbdc",                              # acciaio
    "y": "#2ce8f5", "e": "#ffffff",                              # il freddo che brilla
    "D": "#68386c",                                              # ombra che cola
}
RAMPE = [["A", "B", "C"], ["P", "Q", "R"], ["S", "T"], ["W", "X"], ["M", "N"], ["y", "e"]]

# materiale -> (scuro, medio, chiaro)
MAT = {
    "coat": ("A", "B", "C"), "trou": ("A", "A", "B"), "skin": ("P", "Q", "R"),
    "scarf": ("S", "T", "T"), "band": ("W", "X", "X"), "steel": ("M", "N", "N"),
}
CHMAT = {"A": "coat", "B": "coat", "C": "coat", "P": "skin", "Q": "skin", "R": "skin",
         "S": "scarf", "T": "scarf", "W": "band", "X": "band", "M": "steel", "N": "steel"}

# --- teste: le uniche parti a mano. 'e' occhio/crepa che brilla, 'y' alone ---
TESTA = {
    "down": [
        "...CCBBBB...",
        ".CCCBBBBBBA.",
        "CCBBBBBBBBAA",
        "AAAAAAAAAAAA",
        "CCCBBBBBBBBA",
        "AyeyAPPAyeyA",
        "APyPPPPPPPPA",
        ".PQeQQPPPPP.",
        "..QQyQPPPP..",
    ],
    "up": [
        "...CCBBBB...",
        ".CCCBBBBBBA.",
        "CCBBBBBBBBAA",
        "AAAAAAAAAAAA",
        "CBBBBBBBBBAA",
        "BAAAAAAAAAAA",
        "BAAAAAAyAAAA",
        ".PQQPPyPPPP.",
        "..QPPPePPP..",
    ],
    "right": [
        "..CCBBBB....",
        ".CCBBBBBBB..",
        "CCBBBBBBBBA.",
        "AAAAAAAAAAA.",
        "BCCCBBBBBBBA",
        "BAAPPPPPyey.",
        "BAAPQQPPPyPP",
        ".APQQQPPeP..",
        "..PQQPPyP...",
    ],
}


# --- la tela: pixel, materiale (per l'ombra portata), corpo (per il contorno) ---

class Tela:
    def __init__(self):
        self.px = [["."] * W for _ in range(H)]
        self.mat = [[None] * W for _ in range(H)]
        self.corpo = [[False] * W for _ in range(H)]

    def dentro(self, x, y):
        return 0 <= x < W and 0 <= y < H

    def put(self, x, y, ch, mat=None):
        if self.dentro(x, y):
            self.px[y][x], self.mat[y][x], self.corpo[y][x] = ch, mat, True

    def fx(self, x, y, ch):
        """Effetti (scie, bagliori, ombra): sopra o sotto, mai contornati."""
        x, y = round(x), round(y)
        if self.dentro(x, y):
            self.px[y][x] = ch

    def parte(self, mask, mat, massa=False):
        """Riempie una forma con la ramp del materiale, luce da alto-sinistra:
        bordo in alto/sinistra chiaro, in basso/destra scuro, niente pillow
        shading. Prima getta 1px d'ombra sulla parte sotto (in basso a destra)."""
        mask = {(x, y) for x, y in mask if self.dentro(x, y)}
        if not mask:
            return
        scuro, medio, chiaro = MAT[mat]
        xs = [x for x, _ in mask]
        cx, w = (min(xs) + max(xs)) / 2, max(xs) - min(xs) + 1
        for x, y in mask:
            qx, qy = x + 1, y + 1
            if (qx, qy) not in mask and self.dentro(qx, qy) and self.corpo[qy][qx] \
                    and self.mat[qy][qx]:
                self.px[qy][qx] = MAT[self.mat[qy][qx]][0]
        for x, y in mask:
            tl = (x - 1, y) not in mask or (x, y - 1) not in mask
            br = (x + 1, y) not in mask or (x, y + 1) not in mask
            c = chiaro if tl and not br else scuro if br and not tl else medio
            if massa and c == medio and x > cx + w * 0.18:
                c = scuro
            self.put(x, y, c, mat)

    def griglia(self, rows, ox, oy):
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch != ".":
                    self.put(ox + i, oy + j, ch, CHMAT.get(ch))

    def contorno(self):
        """Contorno 1px, 4-vicini: angoli puliti, mai 2px."""
        add = []
        for y in range(H):
            for x in range(W):
                if self.corpo[y][x]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    X, Y = x + dx, y + dy
                    if self.dentro(X, Y) and self.corpo[Y][X]:
                        add.append((x, y))
                        break
        for x, y in add:
            self.px[y][x] = "o"

    def maschera(self):
        return {(x, y) for y in range(H) for x in range(W) if self.corpo[y][x]}

    def righe(self):
        return ["".join(r) for r in self.px]


# --- forme ---

def _in_poli(px, py, pts):
    ins = False
    for i in range(len(pts)):
        (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % len(pts)]
        if (y1 > py) != (y2 > py) and px < x1 + (py - y1) * (x2 - x1) / (y2 - y1):
            ins = not ins
    return ins


def poli(pts):
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return {(x, y) for y in range(int(min(ys)) - 1, int(max(ys)) + 1)
            for x in range(int(min(xs)) - 1, int(max(xs)) + 1)
            if _in_poli(x + .5, y + .5, pts)}


def linea(a, b):
    x0, y0, x1, y1 = round(a[0]), round(a[1]), round(b[0]), round(b[1])
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err, out = dx + dy, []
    while True:
        out.append((x0, y0))
        if (x0, y0) == (x1, y1):
            return out
        e2 = 2 * err
        if e2 >= dy:
            err, x0 = err + dy, x0 + sx
        if e2 <= dx:
            err, y0 = err + dx, y0 + sy


def spessa(punti, w):
    o, m = (w - 1) // 2, set()
    for a, b in zip(punti, punti[1:]):
        for x, y in linea(a, b):
            m |= {(x - o + i, y - o + j) for i in range(w) for j in range(w)}
    return m


def rett(x, y, w, h):
    return {(x + i, y + j) for i in range(w) for j in range(h)}


def add(p, d):
    return (p[0] + d[0], p[1] + d[1])


# --- parti composte ---

def braccio(t, spalla, gomito, mano, coda=None):
    """Manica del cappotto fino al gomito, avambraccio fasciato, mano 2x2.
    coda: (dx, dy) delle bende strappate che penzolano dal polso."""
    t.parte(spessa([spalla, gomito], 3), "coat")
    t.parte(spessa([gomito, mano], 2), "band")
    if coda:
        p1 = add(mano, coda)
        t.parte({p1, add(p1, coda)}, "band")
    t.parte(rett(round(mano[0]), round(mano[1]), 2, 2), "skin")


def spada(t, mano, d, lung, luce=False):
    """Spadone: lama 2px (lato alto-sinistra chiaro), guardia, impugnatura rossa.
    luce=True: la lama si carica del freddo (bagliore)."""
    n = max(abs(d[0]), abs(d[1]))
    ux, uy = d[0] / n, d[1] / n
    px, py = -uy, ux
    if px + py > 0 or (px + py == 0 and px > 0):
        px, py = -px, -py
    # seconda riga della lama: sopra se la lama e' orizzontale o diagonale,
    # a sinistra se e' verticale (sempre verso la luce, mai a scacchiera)
    sp = (0, -1) if abs(d[0]) >= abs(d[1]) else (-1, 0)
    base = (mano[0] + ux * 2, mano[1] + uy * 2)
    punta = (mano[0] + ux * lung, mano[1] + uy * lung)
    lama = linea(base, punta)
    for x, y in lama:
        t.put(x + sp[0], y + sp[1], "e" if luce else "N", "steel")
        t.put(x, y, "y" if luce else "M", "steel")
    g = (mano[0] + ux, mano[1] + uy)
    for k in (-1, 0, 1):
        t.put(round(g[0] + px * k * 1.5), round(g[1] + py * k * 1.5), "M", "steel")
    t.put(round(mano[0] - ux), round(mano[1] - uy), "S", "scarf")
    t.put(round(mano[0] - ux * 2), round(mano[1] - uy * 2), "N", "steel")
    if not luce:
        tx, ty = lama[-1]
        t.put(tx + sp[0], ty + sp[1], "e", "steel")


def gocce(t, xs, y0, fase, lungo=0):
    """L'ombra che cola dall'orlo del cappotto: gocce che crescono e si staccano."""
    cicli = [0, 1, 2, 1]
    for k, x in enumerate(xs):
        n = cicli[(fase + k * 2) % len(cicli)] + lungo
        for j in range(n):
            t.fx(x, y0 + j, "D")


def scia(t, c, r, a0, a1):
    """Smear dell'attacco: arco di 2px, bianco freddo dentro e alone fuori."""
    passi = max(8, int(abs(a1 - a0) / 6))
    for k in range(passi + 1):
        a = math.radians(a0 + (a1 - a0) * k / passi)
        t.fx(c[0] + (r + 1) * math.cos(a), c[1] + (r + 1) * math.sin(a), "y")
    for k in range(passi + 1):
        a = math.radians(a0 + (a1 - a0) * k / passi)
        t.fx(c[0] + r * math.cos(a), c[1] + r * math.sin(a), "e")


def bagliore(t, x, y, r):
    """Il freddo che si raccoglie: nucleo bianco, croce e anello azzurri."""
    for dx in range(-r, r + 1):
        for dy in range(-r, r + 1):
            d = abs(dx) + abs(dy)
            if d == r or (dx == 0 or dy == 0) and d < r:
                t.fx(x + dx, y + dy, "y")
    t.fx(x, y, "e")
    if r >= 2:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            t.fx(x + dx, y + dy, "e")


def crepa_suolo(t, x, y):
    for dx, dy in ((-1, 0), (-2, 1), (-4, 1), (-5, 0), (1, 0), (2, 1), (3, 1), (5, 0), (0, 1)):
        t.fx(x + dx, y + dy, "y")
    for dx in (-3, 0, 4):
        t.fx(x + dx, y, "e")


def fantasma(t, altra, dx, dy):
    """Scia del dash: la sagoma di un istante prima, in ombra viola."""
    for x, y in altra.maschera():
        t.fx(x + dx, y + dy, "D")


# --- le viste ---

OCCHI = {"norm": {}, "bright": {"y": "e"}, "dim": {"e": "y"}, "off": {"e": "A", "y": "A"}}


def testa(view, occhi):
    m = OCCHI[occhi]
    return ["".join(m.get(c, c) for c in r) for r in TESTA[view]]


def figura(view, P, tela=False):
    """Compone un frame. P: bob/lean (busto), gambe, bracci, spada, orlo,
    sciarpa, occhi, gocce, fx. Le coordinate dei bracci sono 'a riposo':
    bob e lean si sommano qui."""
    t = Tela()
    by, lx = P.get("bob", 0), P.get("lean", 0)
    U = lambda p: (p[0] + lx, p[1] + by)
    laterale = view == "right"

    for (gx, gy) in P.get("fantasmi", []):
        posa = dict(P.get("posa_fantasma", {}), fantasmi=[], fx=[], gocce=None)
        fantasma(t, figura(view, posa, tela=True), gx, gy)

    sp = P.get("spada")
    if sp and sp.get("strato") == "dietro":
        spada(t, U(sp["mano"]), sp["d"], sp["l"], sp.get("luce", False))
    if laterale and P.get("braccio_dietro"):
        braccio(t, *[U(p) for p in P["braccio_dietro"][:3]])

    if P.get("custom"):
        P["custom"](t, U)
    else:
        for anca, piede in P["gambe"]:
            a = (anca[0], anca[1] + by)
            ginocchio = ((a[0] + piede[0]) / 2 + (1 if laterale else 0), (a[1] + piede[1]) / 2)
            t.parte(spessa([a, ginocchio, (piede[0], piede[1] - 2)], 3), "trou")
            t.parte(rett(piede[0] - 1, piede[1] - 1, 4 if laterale else 3, 2), "trou")

        hl, hr, hy = P.get("orlo", (0, 0, 0))
        hb = 26 + by + hy
        if laterale:
            corpo = [U((12, 11)), U((20, 11)), U((22, 13)), (21 + lx // 2, 20 + by),
                     (22 + hr, hb), (10 + hl, hb), (12 + lx // 2, 20 + by), U((11, 13))]
        else:
            corpo = [U((10, 11)), U((22, 11)), U((25, 13)), U((23, 20)), (24 + hr, hb),
                     (17 + (hl + hr) // 2, hb), (16, hb - 3), (15 + (hl + hr) // 2, hb),
                     (8 + hl, hb), U((9, 20)), U((7, 13))]
        t.parte(poli(corpo), "coat", massa=True)
        if view == "down":
            for a, b in (((12, 12), (15, 18)), ((19, 12), (16, 18))):
                for x, y in linea(U(a), U(b)):
                    t.put(x, y, "A", "coat")
        elif view == "up":
            for x, y in linea(U((16, 18)), (16, hb - 4)):
                t.put(x, y, "A", "coat")

    if sp and sp.get("strato") == "mezzo":
        spada(t, U(sp["mano"]), sp["d"], sp["l"], sp.get("luce", False))

    if not P.get("custom"):
        tdx, tdy = P.get("testa", (0, 0))
        hx = (9 if laterale else 10) + lx + tdx
        t.griglia(testa(view, P.get("occhi", "norm")), hx, 2 + by + tdy)
        col = (12, 8) if laterale else (10, 12)
        t.parte(rett(col[0] + lx, 10 + by, col[1], 2), "scarf")
        if P.get("sciarpa"):
            t.parte(spessa([U(p) for p in P["sciarpa"]], 2), "scarf")

    for b in P.get("bracci", []):
        braccio(t, *[U(p) for p in b[:3]], coda=b[3] if len(b) > 3 else None)

    if sp and sp.get("strato", "davanti") == "davanti":
        spada(t, U(sp["mano"]), sp["d"], sp["l"], sp.get("luce", False))

    t.contorno()

    if P.get("gocce") is not None:
        xs = [11, 20] if laterale else [9, 22]
        gocce(t, xs, 26 + by + P.get("orlo", (0, 0, 0))[2], P["gocce"], P.get("gocce_lunghe", 0))
    for f in P.get("fx", []):
        f(t)
    if P.get("flash"):
        t.px = [[("e" if c not in ".o" else c) for c in r] for r in t.px]
    return t if tela else t.righe()


# --- pose a riposo ---

def riposo(view):
    """In piedi, lo spadone appoggiato sulla spalla: la posa che dice 'forte'."""
    if view == "right":
        return dict(
            gambe=[((15, 22), (14, 30)), ((16, 22), (17, 30))],
            braccio_dietro=((14, 12), (13, 17), (13, 20)),
            bracci=[((16, 12), (16, 17), (19, 15), (-1, 1))],
            spada=dict(mano=(19, 15), d=(-1, -1), l=13, strato="mezzo"),
            sciarpa=[(12, 12), (10, 13), (8, 14), (7, 16)],
            gocce=0)
    if view == "down":
        bracci = [((8, 12), (6, 17), (11, 15), (-1, 1)), ((23, 12), (25, 17), (24, 21), (1, 1))]
        sp = dict(mano=(11, 15), d=(-1, -1), l=13, strato="mezzo")
        sciarpa = [(11, 12), (11, 16)]
    else:
        bracci = [((8, 12), (6, 17), (7, 21), (-1, 1)), ((23, 12), (26, 16), (24, 13), (1, 1))]
        sp = dict(mano=(24, 13), d=(1, -1), l=10, strato="dietro")
        sciarpa = [(13, 12), (13, 18), (12, 21)]
    return dict(gambe=[((13, 22), (13, 30)), ((18, 22), (18, 30))], bracci=bracci,
                spada=sp, sciarpa=sciarpa, gocce=0)


def con(base, **kw):
    P = dict(base)
    P.update(kw)
    return P


def mano_spada(view):
    return 0 if view in ("down", "right") else 1


def sposta_braccio(P, i, gomito=None, mano=None, coda=None):
    b = list(P["bracci"])
    sh, el, ma = b[i][:3]
    cd = b[i][3] if len(b[i]) > 3 else None
    b[i] = (sh, gomito or el, mano or ma, coda if coda is not None else cd)
    P["bracci"] = b
    return P


# --- animazioni: una funzione per animazione, (view, i) -> P ---

def a_idle(view, i):
    P = con(riposo(view), bob=[0, 1, 0, 1][i], gocce=i, occhi=["norm", "norm", "bright", "norm"][i])
    sw = [0, 1, 0, -1][i]
    P["sciarpa"] = [(x + (sw if k == len(P["sciarpa"]) - 1 else 0), y) for k, (x, y) in enumerate(P["sciarpa"])]
    return P


def a_walk(view, i):
    """Passo pesante: la spada resta in spalla, oscilla il braccio libero."""
    P = con(riposo(view), bob=[0, 1, 0, 0, 1, 0][i], gocce=i)
    if view == "right":
        near = [(17, 29), (19, 30), (17, 30), (14, 30), (11, 30), (14, 29)][i]
        far = [(14, 30), (11, 30), (14, 29), (17, 29), (19, 30), (17, 30)][i]
        P["gambe"] = [((15, 22), far), ((16, 22), near)]
        sw = [1, 2, 1, -1, -2, -1][i]
        P["braccio_dietro"] = ((14, 12), (13 + sw // 2, 17), (13 + sw, 20))
        P["lean"] = 1
        P["orlo"] = ([-1, -2, -1, -1, -2, -1][i], 0, 0)
        P["sciarpa"] = [(12, 12), (10, 13), (7, 13 + i % 2), (5, 14 + (i + 1) % 2)]
    else:
        ly = [28, 30, 30, 30, 30, 30][i]
        ry = [30, 30, 30, 28, 30, 30][i]
        P["gambe"] = [((13, 22), (13, ly)), ((18, 22), (18, ry))]
        s = [1, 1, 0, -1, -1, 0][i]
        libera = 1 if view == "down" else 0
        b = P["bracci"][libera]
        sposta_braccio(P, libera, mano=(b[2][0], b[2][1] + (s if libera else -s)))
        P["orlo"] = (-s, -s, 0)
        last = P["sciarpa"][-1]
        P["sciarpa"] = P["sciarpa"][:-1] + [(last[0] + s, last[1])]
    return P


def a_dash(view, i):
    P = con(riposo(view), gocce=i, gocce_lunghe=1, occhi="bright", posa_fantasma=riposo(view))
    bob, lean = [2, 2, 1, 1][i], [3, 3, 2, 1][i]
    gh = [[-6], [-4, -9], [-3], []][i]
    if view == "right":
        P.update(bob=bob, lean=lean, fantasmi=[(g, 0) for g in gh],
                 gambe=[((15, 22), (9 + i, 30)), ((16, 22), (21 - i // 2, 30))],
                 orlo=([-3, -3, -2, -1][i], -1, 0),
                 braccio_dietro=((14, 12), (16, 15), (19, 16)),
                 sciarpa=[(12, 12), (8, 12), (4, 12 + i % 2), (1, 13)])
        sposta_braccio(P, 0, gomito=(13, 16), mano=(11, 18), coda=(-1, 0))
        P["spada"] = dict(mano=(11, 18), d=(-2, 1), l=9, strato="mezzo")
    else:
        dy = -1 if view == "down" else 1
        P.update(bob=bob, fantasmi=[(0, g * -dy) for g in gh], orlo=(-2, 2, 0))
        sposta_braccio(P, 0, gomito=(5, 15), mano=(4, 18))
        sposta_braccio(P, 1, gomito=(26, 15), mano=(26, 18))
        k = mano_spada(view)
        P["spada"] = dict(P["spada"], mano=P["bracci"][k][2], d=(-1, -1) if k == 0 else (1, -1))
    return P


def a_attack_light(view, i):
    P = con(riposo(view), gocce=i, bob=[1, 1, 0, 0, 0][i], occhi=["norm", "bright", "bright", "norm", "norm"][i])
    if view == "right":
        el, ma, d, l, lean = [((14, 15), (12, 16), (-1, -1), 10, -1),
                              ((13, 13), (11, 13), (-2, -1), 10, -2),
                              ((19, 13), (22, 14), (1, 0), 9, 2),
                              ((19, 15), (22, 17), (2, 1), 9, 2),
                              ((17, 16), (19, 19), (1, 2), 9, 1)][i]
        sposta_braccio(P, 0, gomito=el, mano=ma, coda=(-1, 1) if i < 2 else (-1, -1))
        P.update(lean=lean, spada=dict(mano=ma, d=d, l=l, strato="davanti" if i >= 2 else "mezzo"))
        if i in (1, 2, 3):
            P["gambe"] = [((15, 22), (11, 30)), ((16, 22), (20, 30))]
        if i == 2:
            P["fx"] = [lambda t: scia(t, (15, 14), 12, -140, 15)]
        if i == 3:
            P["fx"] = [lambda t: (t.fx(31, 20, "e"), t.fx(30, 19, "y"), t.fx(31, 21, "y"))]
        P["sciarpa"] = [(12, 12), (9, 12 + (i > 1)), (6, 13 + (i > 1)), (4, 15)]
        return P
    k = mano_spada(view)
    s = 1 if k == 0 else -1          # verso esterno della mano con la spada
    def X(x):
        return x if k == 0 else 31 - x
    el, ma, d, l = [((6, 13), (7, 9), (-1, -2), 8),
                    ((7, 11), (8, 7), (-1, -1), 9),
                    ((12, 17), (17, 20), (2, 1), 9),
                    ((14, 18), (19, 22), (2, 1), 9),
                    ((7, 17), (9, 20), (-1, 2), 9)][i]
    el, ma = (X(el[0]), el[1]), (X(ma[0]), ma[1])
    d = (d[0] * s, d[1]) if view == "down" else (d[0] * s, -d[1] if i in (2, 3) else d[1])
    sposta_braccio(P, k, gomito=el, mano=ma)
    davanti = view == "down" or i not in (2, 3)
    P["spada"] = dict(mano=ma, d=d, l=l, strato="davanti" if davanti else "dietro")
    if i == 2:
        if view == "down":
            P["fx"] = [lambda t: scia(t, (16, 18), 9, 190 if k == 0 else -10, 40 if k == 0 else 140)]
        else:
            P["fx"] = [lambda t: scia(t, (16, 12), 12, -30 if k == 1 else 210, -150 if k == 1 else 330)]
    return P


def a_attack_heavy(view, i):
    P = con(riposo(view), gocce=i, bob=[2, 1, 0, 0, 1, 2, 1, 0][i],
            occhi=["bright", "norm", "bright", "bright", "bright", "bright", "norm", "norm"][i],
            gocce_lunghe=1 if i == 3 else 0)
    luce = i == 3
    if view == "right":
        mani, d, l, lean, strato = [((14, 20), (-1, 1), 9, -1, "mezzo"),
                                    ((12, 17), (-2, 1), 10, -1, "mezzo"),
                                    ((12, 13), (-1, -1), 10, -1, "mezzo"),
                                    ((13, 11), (-2, -1), 11, -2, "mezzo"),
                                    ((21, 15), (1, 1), 10, 2, "davanti"),
                                    ((22, 18), (0, 1), 11, 3, "davanti"),
                                    ((20, 18), (1, 2), 10, 1, "davanti"),
                                    ((18, 19), (1, 2), 10, 0, "mezzo")][i]
        P.update(lean=lean, spada=dict(mano=mani, d=d, l=l, strato=strato, luce=luce))
        sposta_braccio(P, 0, gomito=((16 + mani[0]) // 2, (12 + mani[1]) // 2 + 1), mano=mani,
                       coda=(-1, 0))
        P["braccio_dietro"] = ((14, 12), ((14 + mani[0]) // 2, (12 + mani[1]) // 2 + 1), (mani[0] - 1, mani[1]))
        if i in (4, 5, 6):
            P["gambe"] = [((15, 22), (10, 30)), ((16, 22), (21, 30))]
        if i == 0:
            P["fx"] = [lambda t: bagliore(t, 18, 7, 2)]
        if i == 4:
            P["fx"] = [lambda t: scia(t, (14, 14), 12, -150, 50)]
        if i == 5:
            P["fx"] = [lambda t: crepa_suolo(t, 24, 29)]
        P["sciarpa"] = [(12, 12), (9, 11 + i % 2), (6, 11), (4, 13)]
        return P
    k = mano_spada(view)
    giu = view == "down"
    X = (lambda x: x) if k == 0 else (lambda x: 31 - x)
    sx = 1 if k == 0 else -1
    # carica sopra la spalla della mano con la spada, colpo verticale davanti
    mani, d, l = [((9, 19), (-1, 1), 8),
                  ((8, 13), (-1, -2), 9),
                  ((8, 9), (-1, -1), 9),
                  ((8, 8), (-1, -1), 10),
                  ((15, 18), (0, 1), 12),
                  ((15, 20), (0, 1), 11),
                  ((15, 19), (0, 1), 10),
                  (None, None, None)][i]
    if mani is None:
        return P
    m = (X(mani[0]) - (1 if k == 1 else 0), mani[1])
    d = (d[0] * sx, d[1])
    sposta_braccio(P, k, gomito=(X(7) - (1 if k == 1 else 0), (12 + mani[1]) // 2 + 1), mano=m)
    altra = (m[0] + 2 * sx if i < 4 else m[0] + sx, m[1] + (1 if i < 4 else 0))
    sposta_braccio(P, 1 - k, gomito=(X(20), (12 + mani[1]) // 2 + 2), mano=altra)
    if i in (4, 5, 6):
        strato = "davanti" if giu else "dietro"
    else:
        strato = "mezzo"
    P["spada"] = dict(mano=m, d=d, l=l, strato=strato, luce=luce)
    fx = []
    if i == 0:
        fx.append(lambda t: bagliore(t, 15, 7, 2))
    if i == 4:
        fx.append(lambda t: [t.fx(16, y, "e") for y in range(3, 30)] + [t.fx(17, y, "y") for y in range(3, 30, 2)]
                  if giu else scia(t, (16, 12), 11, -160, -20))
    if i == 5 and giu:
        fx.append(lambda t: crepa_suolo(t, 16, 30))
    P["fx"] = fx
    return P


def a_parry(view, i):
    perfetta = i < 2
    P = con(riposo(view), occhi="bright" if perfetta else "norm", gocce=i)
    glint = [lambda t: bagliore(t, X, Y, 2), lambda t: bagliore(t, X, Y, 1), None, None]
    if view == "right":
        mani, d, l = [((20, 15), (0, -1), 10), ((20, 15), (0, -1), 10),
                      ((20, 16), (1, -2), 9), ((19, 18), (1, 1), 9)][i]
        X, Y = 21, 5
        sposta_braccio(P, 0, gomito=(18, 16), mano=mani, coda=(-1, 1))
        P["braccio_dietro"] = ((14, 12), (17, 15), (mani[0] - 1, mani[1] + 1))
        P["spada"] = dict(mano=mani, d=d, l=l, strato="davanti")
        P["lean"] = 1 if perfetta else 0
    else:
        k = mano_spada(view)
        giu = view == "down"
        if i < 3:
            a, b = ((8, 15), (22, 15)) if k == 0 else ((23, 15), (9, 15))
            sposta_braccio(P, k, gomito=(7 if k == 0 else 24, 14), mano=a)
            sposta_braccio(P, 1 - k, gomito=(23 if k == 0 else 8, 14), mano=b)
            d = (1, 0) if k == 0 else (-1, 0)
            if i == 2:
                d = (2, 1) if k == 0 else (-2, 1)
            P["spada"] = dict(mano=a, d=d, l=16, strato="davanti" if giu else "dietro")
        X, Y = (25, 14) if k == 0 else (6, 14)
    if glint[i]:
        P["fx"] = [glint[i]]
    return P


def a_hurt(view, i):
    P = con(riposo(view), gocce=i)
    if view == "right":
        P.update(lean=[-1, -2, -1][i], bob=[0, 1, 0][i], occhi=["norm", "off", "dim"][i])
        sposta_braccio(P, 0, gomito=(15, 15), mano=(18, 16) if i == 1 else (17, 20))
        P["spada"] = dict(P["spada"], mano=(18, 16) if i == 1 else (17, 20), d=(2, 1) if i == 1 else (1, 2))
    else:
        P.update(bob=[-1, 1, 0][i], occhi=["norm", "off", "dim"][i])
        if i == 1:
            k = mano_spada(view)
            sposta_braccio(P, 0, mano=(5, 16))
            sposta_braccio(P, 1, mano=(25, 16))
            P["spada"] = dict(P["spada"], mano=P["bracci"][k][2], d=(-1, -2) if k == 0 else (1, -2))
    P["flash"] = i == 0
    return P


def _sdraiato(t, U, occhi):
    """Enel a terra, faccia in giu', verso destra."""
    t.parte(spessa([(8, 28), (3, 29)], 3), "trou")
    t.parte(rett(1, 28, 3, 2), "trou")
    t.parte(poli([(8, 25), (21, 24), (24, 26), (24, 30), (6, 30), (5, 27)]), "coat", massa=True)
    t.parte(spessa([(20, 26), (25, 28), (28, 29)], 2), "band")
    t.parte(rett(28, 28, 2, 2), "skin")
    t.griglia(["..CCBB.", ".CBBBBA", "CBBBBAA", "BBBAAoA" if occhi == "off" else "BBBAAyA", ".AAAAA."], 21, 24)
    t.parte(spessa([(12, 25), (9, 23), (6, 23)], 2), "scarf")


def a_death(view, i):
    view = "right"
    P = con(riposo(view), gocce=i, gocce_lunghe=i // 3)
    sw = dict(mano=(2, 29), d=(1, 0), l=11, strato="dietro")
    if i == 0:
        P.update(lean=-2, bob=1, occhi="dim")
        P["spada"] = dict(P["spada"], d=(2, 1))
    elif i in (1, 2, 3, 4):
        P.update(lean=[0, 0, 1, 1][i - 1] - 1, bob=[2, 4, 6, 7][i - 1],
                 occhi=["dim", "dim", "dim", "off"][i - 1], spada=sw, testa=(0, 1 if i == 4 else 0))
        P["gambe"] = [((15, 22), (12, 30)), ((16, 22), (19, 30))] if i < 3 else \
            [((15, 22), (11, 30)), ((16, 22), (19, 30))]
        sposta_braccio(P, 0, gomito=(17, 18), mano=(18, 22 if i < 3 else 23))
        P["orlo"] = (0, 0, -min(i - 1, 4) if i > 2 else 0)
    elif i == 5:
        P.update(lean=4, bob=8, occhi="off", spada=sw, orlo=(0, 0, -6),
                 gambe=[((15, 22), (11, 30)), ((16, 22), (19, 30))])
        sposta_braccio(P, 0, gomito=(20, 20), mano=(23, 26))
    else:
        occhi = "dim" if i == 6 else "off"
        P = dict(custom=lambda t, U: _sdraiato(t, U, occhi), spada=sw,
                 fx=[lambda t: [t.fx(x, 31, "D") for x in range(3 if i == 7 else 7, 30)],
                     lambda t: [t.fx(x, 30, "D") for x in range(10, 23)] if i == 7 else None])
    return P


def a_cast(view, i):
    P = con(riposo(view), gocce=i, occhi=["norm", "norm", "bright", "bright", "bright", "norm"][i])
    r = [1, 1, 2, 3, 1, 0][i]
    if view == "right":
        ma = [(18, 15), (19, 14), (17, 13), (24, 13), (23, 14), (18, 17)][i]
        P["braccio_dietro"] = None
        P["bracci"] = list(P["bracci"]) + [((15, 12), ((15 + ma[0]) // 2, 14), ma, (-1, 1))]
        P["lean"] = 1 if i == 3 else 0
        if r:
            P["fx"] = [lambda t: bagliore(t, ma[0] + 1 + P["lean"], ma[1] + 1, r)]
    else:
        k = mano_spada(view)
        libera = 1 - k
        ma = [(20, 16), (19, 15), (19, 14), (17, 18), (18, 18), (22, 19)][i]
        ma = ma if libera == 1 else (31 - ma[0] - 1, ma[1])
        sposta_braccio(P, libera, gomito=((P["bracci"][libera][0][0] + ma[0]) // 2, 15), mano=ma)
        if r and view == "down":
            P["fx"] = [lambda t: bagliore(t, ma[0] + 1, ma[1] + 1 + (2 if i == 3 else 0), r)]
        elif r:
            P["fx"] = [lambda t: bagliore(t, ma[0] + 1, ma[1] - 3, r)]
    return P


def _seduto(t, U):
    t.parte(poli([(9, 18), (23, 18), (26, 20), (27, 30), (4, 30), (5, 20)]), "coat", massa=True)
    t.parte(spessa([(8, 27), (15, 28), (23, 27)], 3), "trou")
    t.parte(rett(13, 28, 6, 2), "trou")


def a_meditate(view, i):
    view = "down"
    P = dict(custom=_seduto, bob=0, gocce=None)
    sciarpa_fine = [(11, 22), (10, 23), (11, 23), (12, 22), (11, 22), (10, 22)][i]
    occhi = ["norm", "bright", "bright", "norm", "dim", "norm"][i]

    def sopra(t):
        t2 = t
        t2.griglia(testa("down", occhi), 10, 9)
        t2.parte(rett(10, 17, 12, 2), "scarf")
        t2.parte(spessa([(11, 19), sciarpa_fine], 2), "scarf")
        braccio(t2, (8, 20), (6, 24), (8, 26), (-1, 0))
        braccio(t2, (23, 20), (25, 24), (22, 26), (1, 0))
        spada(t2, (8, 26), (1, 0), 18)
    P["custom"] = lambda t, U: (_seduto(t, U), sopra(t))
    fumo = [(6, 17), (25, 15), (8, 12), (24, 10), (7, 7), (23, 5)]
    P["fx"] = [lambda t: [t.fx(x, y - (i * 2) % 12 + k, "D") for x, y in fumo[(i % 2)::2] for k in (0, 1)]]
    return P


ANIM = {"idle": a_idle, "walk": a_walk, "dash": a_dash, "attack_light": a_attack_light,
        "attack_heavy": a_attack_heavy, "parry": a_parry, "hurt": a_hurt, "death": a_death,
        "cast": a_cast, "meditate": a_meditate}


# --- uscita ---

def durate(spec):
    if spec.get("durate_ms"):
        return [int(d) for d in spec["durate_ms"]]
    return [round(1000 / float(spec.get("fps", 12)))] * int(spec["frames"])


def costruisci(nome, spec):
    ms = durate(spec)
    n = int(spec["frames"])
    doc = {
        "name": f"personaggio_{nome}", "size": [W, H], "pivot": [16, 31], "ppu": 32,
        "_comment": "GENERATO da tools/art/build_enel.py: non modificare a mano. "
                    "Righe nell'ordine di data/animations.json (down, up, left, right); "
                    "left = right specchiato.",
        "colors": COLORI, "ramps": RAMPE, "animations": {},
    }
    if spec.get("direzionale"):
        for view in ("down", "up", "left", "right"):
            if view == "left":
                doc["animations"]["left"] = {"loop": bool(spec.get("loop")), "frames": [
                    {"ms": ms[i], "base": f"right:{i}", "flip": True} for i in range(n)]}
            else:
                doc["animations"][view] = {"loop": bool(spec.get("loop")), "frames": [
                    {"ms": ms[i], "rows": figura(view, ANIM[nome](view, i))} for i in range(n)]}
        # 'left' deve stare prima di 'right' nello sheet ma lo deriva: riordino
        doc["animations"] = {k: doc["animations"][k] for k in ("down", "up", "left", "right")}
    else:
        doc["animations"][nome] = {"loop": bool(spec.get("loop")), "frames": [
            {"ms": ms[i], "rows": figura("down", ANIM[nome]("down", i))} for i in range(n)]}
    return doc


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--skill", help="cartella della skill sprite-forge (con scripts/)")
    ap.add_argument("--out", default=os.path.join(tempfile.gettempdir(), "enel_render"),
                    help="cartella dei render (fuori dal repo)")
    ap.add_argument("solo", nargs="*", help="solo queste animazioni")
    a = ap.parse_args()

    with open(os.path.join(ROOT, "data", "animations.json"), encoding="utf-8") as fh:
        specs = json.load(fh)["personaggio"]
    nomi = a.solo or [k for k in specs if not k.startswith("_")]
    for nome in nomi:
        path = os.path.join(OUT, f"personaggio_{nome}.json")
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(costruisci(nome, specs[nome]), fh, indent=1, ensure_ascii=False)
            fh.write("\n")
        print("scritto", os.path.relpath(path, ROOT))
        if a.skill:
            sc = os.path.join(a.skill, "scripts")
            subprocess.run([sys.executable, os.path.join(sc, "check.py"), path, "--out", a.out], check=True)
            subprocess.run([sys.executable, os.path.join(sc, "render.py"), path, "--out", a.out,
                            "--padding", "0"], check=True, stdout=subprocess.DEVNULL)
            sheet = os.path.join(a.out, f"personaggio_{nome}", f"personaggio_{nome}_sheet.png")
            shutil.copyfile(sheet, os.path.join(ROOT, "assets", "placeholder", f"personaggio_{nome}.png"))


if __name__ == "__main__":
    main()
