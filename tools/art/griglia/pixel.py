"""Tela e disegno dei pezzi: rampe a 3 toni, segmenti ombreggiati, griglie, contorno nero di 1 px.

Regole (CLAUDE.md, scelte del 2026-11-18): contorno #181425 di 1 px fuori dalla figura e dove una parte davanti
copre una parte diversa dietro (gli arti si staccano dal corpo); 3 toni per materiale (ombra, base, luce) piu' il
riflesso solo sul metallo; una luce sola in alto a sinistra; alpha solo 0 o 255.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from forge3d.materials import E32, hex_to_rgb  # noqa: E402

INK = hex_to_rgb(E32["ink"])
LUCE = np.array([-0.55, -0.62, 0.56])          # verso la luce: sinistra, in alto sullo schermo, verso chi guarda
LUCE = LUCE / np.linalg.norm(LUCE)


def colore(nome):
    return np.array(hex_to_rgb(E32[nome]), dtype=np.uint8)


class Rampa:
    """3 toni (ombra, base, luce) e, solo per il metallo, un riflesso."""

    def __init__(self, ombra, base, luce, riflesso=None):
        self.toni = [colore(ombra), colore(base), colore(luce)]
        self.riflesso = colore(riflesso) if riflesso else None

    def tono(self, d):
        """d = luce che arriva (-1..1)."""
        if self.riflesso is not None and d > 0.86:
            return self.riflesso
        return self.toni[2] if d > 0.42 else self.toni[1] if d > -0.05 else self.toni[0]


class Tela:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.col = np.zeros((h, w, 3), np.uint8)
        self.a = np.zeros((h, w), bool)
        self.grp = np.full((h, w), -1, np.int32)
        self._gruppi = {}

    def gid(self, nome):
        return self._gruppi.setdefault(nome, len(self._gruppi))

    def metti(self, mask, col, gruppo, separa=True, uniti=()):
        """Posa una parte: `mask` (h,w) bool, `col` (h,w,3). Con `separa` traccia 1 px di contorno appena fuori dalla
        parte, sopra le parti gia' posate di un altro gruppo (non sopra quelle di `uniti`)."""
        g = self.gid(gruppo)
        if separa:
            fuori = _dilata(mask) & ~mask & self.a & (self.grp != g)
            for u in uniti:
                fuori &= self.grp != self.gid(u)
            self.col[fuori] = INK
            self.grp[fuori] = -2
        self.col[mask] = col[mask]
        self.a |= mask
        self.grp[mask] = g

    def contorno(self):
        fuori = _dilata(self.a) & ~self.a
        self.col[fuori] = INK
        self.a |= fuori

    def immagine(self):
        rgba = np.zeros((self.h, self.w, 4), np.uint8)
        rgba[..., :3] = self.col
        rgba[..., 3] = np.where(self.a, 255, 0)
        return Image.fromarray(rgba, "RGBA")


def _dilata(m):
    d = m.copy()
    d[1:] |= m[:-1]
    d[:-1] |= m[1:]
    d[:, 1:] |= m[:, :-1]
    d[:, :-1] |= m[:, 1:]
    return d


def segmento(tela, a, b, ra, rb, rampa, gruppo, tappi=True, separa=True, uniti=(), piatto=0.0, colore_fisso=None):
    """Un pezzo tondo da a a b (punti dello schermo in pixel, continui) con raggio da ra a rb, ombreggiato come un
    cilindro dalla luce. `tappi` False: estremi piatti (busto, falde). `piatto` 0..1 schiaccia l'ombreggiatura (stoffa
    larga). Restituisce la maschera."""
    h, w = tela.h, tela.w
    ys, xs = np.mgrid[0:h, 0:w]
    px, py = xs + 0.5, ys + 0.5
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    if L2 < 1e-6:
        t = np.zeros_like(px)
    else:
        t = ((px - ax) * dx + (py - ay) * dy) / L2
    tt = np.clip(t, 0, 1)
    cx, cy = ax + tt * dx, ay + tt * dy
    r = ra + (rb - ra) * tt
    ox, oy = px - cx, py - cy
    dist = np.sqrt(ox * ox + oy * oy)
    mask = dist <= r
    if not tappi:
        mask &= (t >= 0) & (t <= 1)
    # normale: nel piano dello schermo dalla distanza dall'asse, verso chi guarda il resto
    nx, ny = ox / np.maximum(r, 1e-3), oy / np.maximum(r, 1e-3)
    nx, ny = nx * (1 - piatto), ny * (1 - piatto)
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
    d = nx * LUCE[0] + ny * LUCE[1] + nz * LUCE[2]
    col = np.zeros((h, w, 3), np.uint8)
    if colore_fisso is not None:
        col[:] = colore_fisso
    else:
        for i, soglia in enumerate((-9, -0.05, 0.42)):
            sel = d > soglia
            col[sel] = rampa.toni[i]
        if rampa.riflesso is not None:
            col[d > 0.86] = rampa.riflesso
    tela.metti(mask, col, gruppo, separa=separa, uniti=uniti)
    return mask


def griglia(tela, righe, mappa, x0, y0, gruppo, specchia=False, ruota=0, separa=True, uniti=()):
    """Una griglia di lettere (lettera -> colore RGB; '.' vuoto) con l'angolo in alto a sinistra in (x0, y0)."""
    larg = max(len(r) for r in righe)
    g = np.array([list(r.ljust(larg, ".")) for r in righe])
    if specchia:
        g = g[:, ::-1]
    if ruota:
        g = np.rot90(g, ruota)
    mask = np.zeros((tela.h, tela.w), bool)
    col = np.zeros((tela.h, tela.w, 3), np.uint8)
    for (j, i), ch in np.ndenumerate(g):
        if ch == ".":
            continue
        x, y = x0 + i, y0 + j
        if 0 <= x < tela.w and 0 <= y < tela.h:
            mask[y, x] = True
            col[y, x] = mappa[ch]
    tela.metti(mask, col, gruppo, separa=separa, uniti=uniti)
    return mask


def foglio(frame, colonne):
    """Righe di frame (liste di Image) -> un foglio: frame in colonne, direzioni in righe."""
    cw, ch = frame[0][0].size
    out = Image.new("RGBA", (cw * colonne, ch * len(frame)))
    for r, riga in enumerate(frame):
        for c, im in enumerate(riga):
            out.paste(im, (c * cw, r * ch))
    return out
