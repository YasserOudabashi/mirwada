"""Effetti unici a 4 toni (scelte del 2026-11-18: un disegno per ogni abilita', contorno nero di 1 px).

Come i VFX di oggi i fogli sono a 4 grigi (0 contorno, 85 scuro, 170 primario, 255 accento) e il gioco li colora
con la palette del Pathway (shaders/rampa_pathway.gdshader); il primo frame d'impatto e' tutto acceso (il lampo,
spento con riduci_flash). Ogni effetto ha la sua forma e il suo movimento: qui due prove.

  fendente_pesante      l'attacco pesante: una mezzaluna verticale che cala dall'alto e spacca il terreno
  incantesimo           "Incantesimo tradizionale" (hermit_7): sigillo con 4 rune che gira in volo
  incantesimo_scoppio   il sigillo si apre in un cerchio di rune e si spezza in schegge

Disegnati verso destra (il gioco li gira). Niente caso: i "rumori" hanno un seme fisso.
"""
import math

import numpy as np
from PIL import Image

VUOTO, CONTORNO, SCURO, PRIMARIO, ACCENTO = -1, 0, 1, 2, 3
GRIGI = {CONTORNO: 0, SCURO: 85, PRIMARIO: 170, ACCENTO: 255}


def _xy(w, h):
    y, x = np.mgrid[0:h, 0:w]
    return x + 0.5, y + 0.5


def _dilata(m):
    d = m.copy()
    d[1:] |= m[:-1]
    d[:-1] |= m[1:]
    d[:, 1:] |= m[:, :-1]
    d[:, :-1] |= m[:, 1:]
    return d


def _png(liv):
    """Livelli -> immagine RGBA a 4 grigi, con il contorno nero di 1 px tutto intorno."""
    h, w = liv.shape
    pieno = liv >= SCURO
    fuori = _dilata(pieno) & ~pieno & (liv == VUOTO)
    liv = liv.copy()
    liv[fuori] = CONTORNO
    rgba = np.zeros((h, w, 4), np.uint8)
    for k, g in GRIGI.items():
        sel = liv == k
        rgba[sel] = (g, g, g, 255)
    return Image.fromarray(rgba, "RGBA")


def _metti(liv, mask, livello):
    liv[mask] = np.maximum(liv[mask], livello)


def _rumore(w, h, seme, blocco=2):
    g = np.random.RandomState(seme).rand(h // blocco + 1, w // blocco + 1)
    return np.kron(g, np.ones((blocco, blocco)))[:h, :w]


def _lin(X, Y, x0, y0, x1, y1, r):
    dx, dy = x1 - x0, y1 - y0
    L2 = dx * dx + dy * dy or 1e-6
    t = np.clip(((X - x0) * dx + (Y - y0) * dy) / L2, 0, 1)
    return np.hypot(X - (x0 + t * dx), Y - (y0 + t * dy)) <= r


# --- Fendente pesante ----------------------------------------------------------------------------------------------
def fendente_pesante(n, S=96):
    """Mezzaluna verticale grossa davanti (destra), dall'alto a terra; all'impatto crepe e sassi; poi si sfalda in
    schegge che cadono. Diversa dal fendente leggero (orizzontale, sottile)."""
    X, Y = _xy(S, S)
    cx, cy = S * 0.38, S * 0.62                   # centro dell'arco: il busto di chi colpisce
    ang = np.degrees(np.arctan2(Y - cy, X - cx))  # -90 = in alto, 0 = davanti, 90 = in basso
    rr = np.hypot(X - cx, Y - cy)
    terra = S * 0.86
    out = []
    for i in range(n):
        t = i / max(n - 1, 1)
        liv = np.full((S, S), VUOTO, np.int8)
        a1 = -100 + min((t + 0.18) * 3.0, 1) * 175  # la punta dell'arco scende dall'alto fino a terra
        a0 = max(-100, a1 - 120)
        spess = 13 * (1 - t) ** 0.6 + 2
        r_out = S * 0.40
        dentro = (ang >= a0) & (ang <= a1) & (rr <= r_out) & (rr >= r_out - spess * (0.3 + 0.7 * (ang - a0) /
                                                                                          max(a1 - a0, 1)))
        if i == 0:
            _metti(liv, dentro, ACCENTO)
        else:
            sfalda = _rumore(S, S, 7 + i) > (0.15 + t * 0.9)
            corpo = dentro & (sfalda | (t < 0.35))
            _metti(liv, corpo, PRIMARIO)
            bordo = corpo & (rr >= r_out - 2.5)
            _metti(liv, bordo, ACCENTO)
            _metti(liv, corpo & (rr <= r_out - spess * 0.75), SCURO)
            for k in range(3):                     # righe di velocita' dietro l'arco
                aa = math.radians(a1 - 25 - k * 22)
                r0 = r_out + 3 + k * 2
                x0, y0 = cx + math.cos(aa) * r0, cy + math.sin(aa) * r0
                x1, y1 = cx + math.cos(aa - 0.35) * r0, cy + math.sin(aa - 0.35) * r0
                if t < 0.6:
                    _metti(liv, _lin(X, Y, x0, y0, x1, y1, 0.7), PRIMARIO)
        if t >= 0.25:                              # impatto a terra: crepe a raggiera e sassi che saltano
            k = (t - 0.25) / 0.75
            ix = cx + r_out * 0.95
            for j, dirx in enumerate((-1.0, -0.35, 0.4, 1.0)):
                L = 6 + 14 * min(k * 2, 1)
                x1 = ix + dirx * L
                y1 = terra + abs(dirx) * 2
                if k < 0.85:
                    _metti(liv, _lin(X, Y, ix, terra, x1, y1, 0.8), SCURO if k > 0.5 else PRIMARIO)
            for j in range(5):
                a = math.radians(-160 + j * 35)
                d = 4 + 22 * k
                sx = ix + math.cos(a) * d
                sy = terra - 2 + math.sin(a) * d * 0.9 + 30 * k * k
                if k < 0.9:
                    _metti(liv, np.hypot(X - sx, Y - sy) <= 1.6 - k, PRIMARIO if j % 2 else SCURO)
            if k < 0.7:                            # polvere
                for j in range(3):
                    px = ix + (j - 1) * 10 * (0.5 + k)
                    py = terra - 3 - k * 6
                    _metti(liv, np.hypot((X - px) / 1.4, Y - py) <= 3.5 * (1 - k) + 1, SCURO)
        out.append(_png(liv))
    return out


# --- Incantesimo tradizionale --------------------------------------------------------------------------------------
RUNA = [".##.", "#..#", ".#..", "..#."]


def _rune(liv, X, Y, cx, cy, r, giro, livello, quante=4, scala=1):
    for k in range(quante):
        a = giro + k * 2 * math.pi / quante
        rx, ry = cx + math.cos(a) * r, cy + math.sin(a) * r
        for j, riga in enumerate(RUNA):
            for i, ch in enumerate(riga):
                if ch == "#":
                    px, py = int(rx - 2 * scala + i * scala), int(ry - 2 * scala + j * scala)
                    liv[max(py, 0):py + scala, max(px, 0):px + scala] = np.maximum(
                        liv[max(py, 0):py + scala, max(px, 0):px + scala], livello)


def incantesimo(n, W=40, H=32):
    """In volo: nucleo acceso, anello con 4 rune che gira, scia di 3 scintille dietro (a sinistra)."""
    X, Y = _xy(W, H)
    cx, cy = W * 0.62, H * 0.5
    out = []
    for i in range(n):
        liv = np.full((H, W), VUOTO, np.int8)
        giro = i * math.pi / 2 / n
        anello = np.abs(np.hypot(X - cx, Y - cy) - 8.5) <= 0.8
        _metti(liv, anello, SCURO)
        _rune(liv, X, Y, cx, cy, 8.5, giro, PRIMARIO)
        _metti(liv, np.hypot(X - cx, Y - cy) <= 4.2, PRIMARIO)
        _metti(liv, np.hypot(X - cx + 1, Y - cy + 1) <= 2.2, ACCENTO)
        for k in range(3):
            sx = cx - 13 - k * 6 - (i % 2) * 2
            sy = cy + math.sin(i * 1.7 + k * 2.1) * 3
            _metti(liv, np.hypot(X - sx, Y - sy) <= 1.6 - k * 0.3, ACCENTO if k == 0 else PRIMARIO)
        out.append(_png(liv))
    return out


def incantesimo_scoppio(n, S=64):
    """All'impatto: lampo, poi il cerchio del sigillo si allarga con 8 rune, si incrina e si spezza in schegge."""
    X, Y = _xy(S, S)
    c = S / 2
    rr = np.hypot(X - c, Y - c)
    ang = np.arctan2(Y - c, X - c)
    out = []
    for i in range(n):
        t = i / max(n - 1, 1)
        liv = np.full((S, S), VUOTO, np.int8)
        if i == 0:
            _metti(liv, rr <= 9, ACCENTO)
            out.append(_png(liv))
            continue
        r = 8 + 18 * t ** 0.7
        crepa = (np.cos(ang * 6 + 1.3) > 0.92 - t * 0.6) if t > 0.4 else np.zeros_like(rr, bool)
        anello = (np.abs(rr - r) <= 1.4) & ~crepa
        _metti(liv, anello, PRIMARIO if t < 0.7 else SCURO)
        if t < 0.75:
            _metti(liv, np.abs(rr - r * 0.6) <= 0.7, SCURO)
            _rune(liv, X, Y, c, c, r * 0.8, t * 1.2, ACCENTO if t < 0.4 else PRIMARIO, quante=8)
        if t > 0.45:                                # schegge che volano via
            for k in range(8):
                a = k * math.pi / 4 + 0.4
                d = r + (t - 0.45) * 30
                sx, sy = c + math.cos(a) * d, c + math.sin(a) * d
                _metti(liv, _lin(X, Y, sx, sy, sx + math.cos(a) * 3, sy + math.sin(a) * 3, 0.8),
                       PRIMARIO if t < 0.8 else SCURO)
        if t < 0.3:
            _metti(liv, rr <= 5 * (1 - t), ACCENTO)
        out.append(_png(liv))
    return out


EFFETTI = {
    # nome del foglio -> (funzione, frame, dimensione di una cella)
    "vfx_fendente_pesante": (fendente_pesante, 8),
    "vfx_incantesimo": (incantesimo, 4),
    "vfx_incantesimo_scoppio": (incantesimo_scoppio, 7),
}
