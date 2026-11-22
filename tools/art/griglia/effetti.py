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


# --- Stretta ferrea (tg_stretta_ferrea: difesa +25% per 5 s) -----------------------------------------------------------
def stretta_ferrea(n, S=64):
    """Quattro piastre di ferro arrivano dagli angoli, si chiudono a guscio attorno a chi lancia con un clang di
    scintille, il guscio brilla (rivetti), poi resta un riflesso che si spegne. Disegnato sul corpo (centro = busto)."""
    X, Y = _xy(S, S)
    cx, cy = S / 2, S * 0.55
    out = []
    for i in range(n):
        t = i / max(n - 1, 1)
        liv = np.full((S, S), VUOTO, np.int8)
        if i == 0:                                         # lampo
            _metti(liv, np.hypot((X - cx) / 1.3, Y - cy) <= 10, ACCENTO)
            out.append(_png(liv))
            continue
        k = min(t / 0.45, 1.0)                             # 0 -> 1: le piastre arrivano
        for q, (ax, ay) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
            dist = (1 - k) * 12
            px, py = cx + ax * (15 + dist), cy + ay * (12 + dist * 0.8)
            piastra = (np.abs(X - px) <= 4) & (np.abs(Y - py) <= 6)
            if t < 0.85:
                _metti(liv, piastra, PRIMARIO if t < 0.7 else SCURO)
                _metti(liv, piastra & ((X - px) * ax < -4), ACCENTO if t < 0.7 else PRIMARIO)  # bordo in luce
                for rx, ry in ((px - 2 * ax, py - 3), (px - 2 * ax, py + 3)):                 # rivetti
                    _metti(liv, (np.abs(X - rx) <= 0.6) & (np.abs(Y - ry) <= 0.6), SCURO)
        if 0.4 <= t <= 0.65:                               # clang: scintille dove le piastre si toccano
            for ang in range(0, 360, 45):
                a = np.radians(ang)
                r0 = 18 + (t - 0.4) * 24
                x0, y0 = cx + np.cos(a) * r0, cy + np.sin(a) * r0 * 1.2
                _metti(liv, _lin(X, Y, x0, y0, x0 + np.cos(a) * 3, y0 + np.sin(a) * 3, 0.7), ACCENTO)
        if t > 0.6:                                        # riflesso che scorre sul guscio e si spegne
            fase = (t - 0.6) / 0.4
            banda = np.abs((X - cx) + (Y - cy) * 0.6 - (-20 + fase * 40)) <= 1.5
            guscio = np.abs(np.hypot((X - cx) / 17, (Y - cy) / 20) - 0.95) <= 0.08
            _metti(liv, guscio, SCURO if fase < 0.7 else VUOTO)
            _metti(liv, banda & guscio, ACCENTO)
        out.append(_png(liv))
    return out


# --- Giro 2 (2026-11-22): dieci abilita', una per Pathway, ognuna con la sua forma -----------------------------------
def _frame(n, S, disegno, lampo=None):
    """Chiama disegno(liv, X, Y, t) per ogni frame; il frame 0 e' il lampo (una forma accesa) se `lampo` c'e'."""
    X, Y = _xy(S, S)
    out = []
    for i in range(n):
        liv = np.full((S, S), VUOTO, np.int8)
        if i == 0 and lampo is not None:
            _metti(liv, lampo(X, Y), ACCENTO)
        else:
            disegno(liv, X, Y, i / max(n - 1, 1))
        out.append(_png(liv))
    return out


def _ell(X, Y, cx, cy, rx, ry):
    return ((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2 <= 1


def incubo(n, S=64):
    """darkness_incubo (paura e debolezza, sul nemico): un occhio enorme si apre nel buio sopra il bersaglio, la
    pupilla a fessura lo fissa, tentacoli di fumo scendono e lo stringono, poi tutto si richiude."""
    cx, cy = S / 2, S * 0.38

    def d(liv, X, Y, t):
        ap = math.sin(min(t / 0.7, 1) * math.pi) if t < 0.85 else 0.0
        if ap > 0.05:
            occhio = _ell(X, Y, cx, cy, 18, 9 * ap)
            _metti(liv, _ell(X, Y, cx, cy, 20, 10 * ap + 1), SCURO)
            _metti(liv, occhio, PRIMARIO)
            _metti(liv, occhio & _ell(X, Y, cx, cy, 2.2, 8 * ap), CONTORNO + 1)
            _metti(liv, occhio & (np.abs(X - cx) <= 1) & (np.abs(Y - cy) <= 8 * ap), ACCENTO)
        for k in range(4):                                   # tentacoli di fumo che scendono e si chiudono
            x0 = cx - 18 + k * 12
            lun = min(t / 0.6, 1) * 26
            for j in range(int(lun)):
                y = cy + 8 + j
                x = x0 + math.sin(j / 4 + k + t * 6) * 3 * (1 - j / 40) + (cx - x0) * (j / 40) * t
                _metti(liv, np.hypot(X - x, Y - y) <= 2.2 - j / 20, SCURO if j % 5 else PRIMARIO)
    return _frame(n, S, d, lampo=lambda X, Y: _ell(X, Y, cx, cy, 14, 6))


def tocco_gelido(n, S=64):
    """death_tocco_gelido (colpo ravvicinato): tre artigli di brina graffiano in diagonale davanti, dove passano
    crescono cristalli di ghiaccio appuntiti, poi la brina si spezza in schegge."""
    def d(liv, X, Y, t):
        k = min(t / 0.4, 1)
        for j in range(3):
            x0, y0 = 14 + j * 9, 10
            x1, y1 = x0 + 22 * k, y0 + 40 * k
            if t < 0.75:
                _metti(liv, _lin(X, Y, x0, y0, x1, y1, 1.6), PRIMARIO)
                _metti(liv, _lin(X, Y, x0, y0, x1, y1, 0.6), ACCENTO)
        if t >= 0.3:                                         # cristalli lungo i graffi
            g = min((t - 0.3) / 0.3, 1)
            for j in range(6):
                bx, by = 20 + j * 5, 20 + j * 6
                h = 8 * g * (1 - max(t - 0.75, 0) * 4)
                if h > 1:
                    cristallo = (np.abs(X - bx) <= (h - (by - Y)) * 0.35) & (Y <= by) & (Y >= by - h)
                    _metti(liv, cristallo, PRIMARIO)
                    _metti(liv, cristallo & (X < bx), ACCENTO)
        if t > 0.75:                                         # schegge
            for j in range(8):
                a = j * math.pi / 4
                r = 6 + (t - 0.75) * 60
                _metti(liv, np.hypot(X - (40 + math.cos(a) * r), Y - (40 + math.sin(a) * r)) <= 1.2, ACCENTO)
    return _frame(n, S, d, lampo=lambda X, Y: _lin(X, Y, 14, 10, 40, 50, 2.5))


def passo_breve(n, S=64):
    """door_passo_breve (teletrasporto corto): si apre il contorno di una porta di luce dietro, chi lancia la attraversa
    e una seconda porta compare davanti; restano due anelli a terra che svaniscono. Disegnato sul corpo."""
    def porta(liv, X, Y, cx, apri, liv_bordo):
        w, h = 9 * apri, 22 * apri
        if apri < 0.1:
            return
        fuori = (np.abs(X - cx) <= w + 1.5) & (Y >= 50 - h - 1.5) & (Y <= 50)
        dentro = (np.abs(X - cx) <= w) & (Y >= 50 - h) & (Y <= 50)
        _metti(liv, fuori & ~dentro, liv_bordo)
        _metti(liv, dentro & ((X + Y) % 6 < 1), SCURO)

    def d(liv, X, Y, t):
        a = math.sin(min(t / 0.5, 1) * math.pi / 2) * (1 - max(t - 0.6, 0) * 2.5)
        b = math.sin(min(max(t - 0.25, 0) / 0.5, 1) * math.pi / 2) * (1 - max(t - 0.75, 0) * 4)
        porta(liv, X, Y, 16, max(a, 0), PRIMARIO)
        porta(liv, X, Y, 48, max(b, 0), ACCENTO)
        for cx, r in ((16, 10 * t), (48, 10 * max(t - 0.25, 0))):
            _metti(liv, np.abs(np.hypot((X - cx) / 1.0, (Y - 52) * 2.5) - r) <= 1.0, SCURO)
    return _frame(n, S, d, lampo=lambda X, Y: (np.abs(X - 32) <= 2) & (Y >= 24) & (Y <= 52))


def pugnalata_furtiva(n, S=64):
    """error_pugnalata_furtiva (colpo alle spalle): una lama sottilissima sbuca dal nulla e affonda in avanti; l'immagine
    si 'rompe' in rettangoli spostati (l'errore che lascia il Pathway), poi si ricompone e sparisce."""
    rng = np.random.RandomState(7)
    blocchi = [(rng.randint(8, 56), rng.randint(16, 48), rng.randint(3, 9), rng.randint(2, 4)) for _ in range(9)]

    def d(liv, X, Y, t):
        k = min(t / 0.35, 1)
        x1 = 10 + 44 * k
        if t < 0.8:
            _metti(liv, _lin(X, Y, 10, 32, x1, 32, 1.2), PRIMARIO)
            _metti(liv, _lin(X, Y, x1 - 4, 32, x1, 32, 0.6), ACCENTO)
        if 0.3 <= t <= 0.85:
            for j, (bx, by, bw, bh) in enumerate(blocchi):
                sh = int(((j * 7 + int(t * 20)) % 5) - 2) * 2
                _metti(liv, (np.abs(X - bx - sh) <= bw) & (np.abs(Y - by) <= bh), SCURO if j % 2 else PRIMARIO)
                _metti(liv, (np.abs(X - bx - sh) <= bw) & (np.abs(Y - by + bh) <= 0.6), ACCENTO)
    return _frame(n, S, d, lampo=lambda X, Y: _lin(X, Y, 30, 32, 56, 32, 2.5))


def velo_illusorio(n, S=64):
    """fool_velo_illusorio (illusione e protezione): carte da gioco girano attorno a chi lancia sempre piu' vicine, poi
    cadono e diventano un velo a strisce che lo avvolge e si dissolve dal basso. Disegnato sul corpo."""
    cx, cy = S / 2, S * 0.55

    def d(liv, X, Y, t):
        if t < 0.6:
            r = 24 - t * 20
            for j in range(6):
                a = j * math.pi / 3 + t * 7
                px, py = cx + math.cos(a) * r, cy + math.sin(a) * r * 0.55
                carta = (np.abs(X - px) <= 3) & (np.abs(Y - py) <= 4)
                _metti(liv, carta, PRIMARIO)
                _metti(liv, carta & (np.abs(X - px) <= 1) & (np.abs(Y - py) <= 1), ACCENTO)
        if t >= 0.45:
            v = min((t - 0.45) / 0.25, 1)
            giu = max(t - 0.75, 0) / 0.25
            velo = _ell(X, Y, cx, cy, 14, 22) & (Y <= cy + 22 - giu * 44) & (Y >= cy - 22 * v)
            _metti(liv, velo & ((X.astype(int) // 2 + Y.astype(int) // 3) % 3 == 0), PRIMARIO)
            _metti(liv, np.abs(np.hypot((X - cx) / 14, (Y - cy) / 22) - 1) <= 0.06, ACCENTO if v < 1 else SCURO)
    return _frame(n, S, d, lampo=lambda X, Y: _ell(X, Y, cx, cy, 10, 16))


def sigillo_su_arma(n, S=64):
    """hermit_sigillo_su_arma (incanta l'arma): un sigillo a cerchio con 3 rune si forma sulla lama tenuta in alto, si
    avvolge a spirale lungo la lama verso la punta e la lascia accesa di rune che scorrono. Disegnato sul corpo."""
    def d(liv, X, Y, t):
        bx0, by0, bx1, by1 = 34, 52, 50, 12                 # la lama (traccia) dalla mano alla punta
        if t < 0.4:
            g = t / 0.4
            _metti(liv, np.abs(np.hypot(X - 40, Y - 36) - 10 * g) <= 1.0, PRIMARIO)
            _rune(liv, X, Y, 40, 36, 10 * g, t * 4, ACCENTO, quante=3)
        else:
            u = (t - 0.4) / 0.6
            for j in range(10):
                f = j / 10
                if f > u + 0.1:
                    continue
                x = bx0 + (bx1 - bx0) * f + math.sin(f * 12 + t * 10) * 4
                y = by0 + (by1 - by0) * f
                _metti(liv, np.hypot(X - x, Y - y) <= 1.6, ACCENTO if j % 3 == 0 else PRIMARIO)
            _metti(liv, _lin(X, Y, bx0, by0, bx0 + (bx1 - bx0) * u, by0 + (by1 - by0) * u, 0.7), SCURO)
    return _frame(n, S, d, lampo=lambda X, Y: np.hypot(X - 40, Y - 36) <= 7)


def richiamo_compagno(n, S=64):
    """moon_richiamo_compagno (evoca la bestia compagna): una luna piena si accende a terra come cerchio, dal cerchio
    sale la sagoma di un lupo che ulula verso l'alto, poi la luce si spegne e resta la bestia (il gioco la crea)."""
    cx = S / 2
    lupo = ["....##......", "...###......", "..#####.....", ".######.....", "########....", ".#######....",
            "..########..", "..#########.", "..##########", "..##.##..##.", "..##.##..##."]

    def d(liv, X, Y, t):
        r = min(t / 0.3, 1) * 20
        _metti(liv, np.abs(np.hypot(X - cx, (Y - 54) * 3) - r) <= 1.4, PRIMARIO)
        _metti(liv, np.hypot(X - cx, (Y - 54) * 3) <= r * 0.6, SCURO if t < 0.8 else VUOTO)
        if t >= 0.3:
            su = min((t - 0.3) / 0.4, 1)
            h = len(lupo)
            for j, riga in enumerate(lupo):
                for i, ch in enumerate(riga):
                    if ch == "#":
                        y = 52 - (h - j) * 3 * su
                        x = cx - 18 + i * 3
                        if y < 52:
                            _metti(liv, (np.abs(X - x) <= 1.5) & (np.abs(Y - y) <= 1.5), ACCENTO if j < 3 else PRIMARIO)
        if t > 0.7:
            for j in range(3):                                # l'ululato: archi che salgono
                rr = 4 + (t - 0.7) * 40 + j * 5
                _metti(liv, (np.abs(np.hypot(X - cx + 8, Y - 14) - rr) <= 0.7) & (Y < 14), ACCENTO)
    return _frame(n, S, d, lampo=lambda X, Y: np.hypot(X - cx, (Y - 54) * 3) <= 14)


def germoglio_rapido(n, S=64):
    """mother_germoglio_rapido (fa crescere una pianta): la terra si apre, tre viticci salgono a spirale con le foglie,
    in cima si apre un fiore a cinque petali, poi spargono polline che sale. Davanti a chi lancia."""
    def d(liv, X, Y, t):
        _metti(liv, _ell(X, Y, 32, 56, 14 * min(t / 0.2, 1) + 1, 3), SCURO)
        cresci = min(t / 0.6, 1)
        for j, dx in enumerate((-8, 0, 8)):
            h = 40 * cresci * (0.7 if j != 1 else 1)
            for k in range(int(h)):
                x = 32 + dx + math.sin(k / 5 + j * 2) * 3
                y = 54 - k
                _metti(liv, np.hypot(X - x, Y - y) <= 1.4, PRIMARIO)
                if k % 9 == 6:                               # foglie
                    lato = 1 if (k // 9 + j) % 2 else -1
                    _metti(liv, _ell(X, Y, x + lato * 3, y, 2.6, 1.4), ACCENTO)
        if t > 0.55:                                         # il fiore in cima
            ap = min((t - 0.55) / 0.2, 1)
            fx, fy = 32 + math.sin(40 / 5) * 3, 14
            for k in range(5):
                a = k * 2 * math.pi / 5 - math.pi / 2
                _metti(liv, _ell(X, Y, fx + math.cos(a) * 4 * ap, fy + math.sin(a) * 4 * ap, 2.4 * ap + 0.5, 2.4 * ap + 0.5),
                       PRIMARIO)
            _metti(liv, np.hypot(X - fx, Y - fy) <= 1.8, ACCENTO)
        if t > 0.75:
            for k in range(6):
                _metti(liv, np.hypot(X - (20 + k * 5), Y - (10 - (t - 0.75) * 30 + (k % 3) * 4)) <= 0.8, ACCENTO)
    return _frame(n, S, d, lampo=lambda X, Y: _ell(X, Y, 32, 54, 16, 4))


def analisi(n, S=64):
    """paragon_analisi (studia il bersaglio): una lente con la croce di mira scende sul nemico, un ingranaggio gira
    attorno alla lente, una linea di scansione passa dall'alto in basso e lascia i punti deboli segnati. Sul nemico."""
    cx, cy = S / 2, S / 2

    def d(liv, X, Y, t):
        r = 14
        rr = np.hypot(X - cx, Y - cy)
        ang = np.arctan2(Y - cy, X - cx)
        denti = (rr >= r + 1) & (rr <= r + 4) & (np.cos((ang - t * 4) * 10) > 0.3)
        _metti(liv, denti, PRIMARIO)
        _metti(liv, np.abs(rr - r) <= 1.0, ACCENTO)
        _metti(liv, ((np.abs(X - cx) <= 0.5) | (np.abs(Y - cy) <= 0.5)) & (rr <= r - 3), SCURO)
        sy = cy - r + (2 * r) * min(t / 0.7, 1)
        _metti(liv, (np.abs(Y - sy) <= 0.6) & (rr <= r - 1), ACCENTO)
        if t > 0.5:                                          # i punti deboli trovati
            for px, py in ((cx - 5, cy - 4), (cx + 6, cy + 3), (cx - 2, cy + 7)):
                if py < sy:
                    _metti(liv, (np.abs(X - px) + np.abs(Y - py)) <= 2, ACCENTO)
    return _frame(n, S, d, lampo=lambda X, Y: np.hypot(X - cx, Y - cy) <= 10)


def contrattacco(n, S=64):
    """tg_contrattacco (para e risponde): uno scudo di luce si alza davanti, il colpo nemico ci sbatte (scintille a
    raggiera), poi lo scudo si gira in un fendente largo che parte in avanti. Davanti a chi lancia."""
    def d(liv, X, Y, t):
        if t < 0.5:
            alza = min(t / 0.2, 1)
            scudo = _ell(X, Y, 22, 34, 6, 14 * alza + 1) & (X >= 18)
            _metti(liv, scudo, PRIMARIO)
            _metti(liv, scudo & (X <= 20), ACCENTO)
            if 0.2 <= t <= 0.45:
                for j in range(7):
                    a = (j - 3) * 0.4
                    r0 = 6 + (t - 0.2) * 50
                    _metti(liv, _lin(X, Y, 28 + math.cos(a) * r0, 34 + math.sin(a) * r0, 28 + math.cos(a) * (r0 + 4),
                                     34 + math.sin(a) * (r0 + 4), 0.7), ACCENTO)
        else:
            u = (t - 0.5) / 0.5
            rr = np.hypot(X - 14, Y - 34)
            ang = np.arctan2(Y - 34, X - 14)
            arco = (np.abs(rr - (20 + u * 16)) <= 4 * (1 - u) + 1) & (np.abs(ang) <= 1.1)
            _metti(liv, arco, PRIMARIO)
            _metti(liv, arco & (np.abs(rr - (22 + u * 16)) <= 1), ACCENTO)
    return _frame(n, S, d, lampo=lambda X, Y: _ell(X, Y, 22, 34, 6, 14))


EFFETTI = {
    # nome del foglio -> (funzione, frame, dimensione di una cella)
    "vfx_fendente_pesante": (fendente_pesante, 8),
    "vfx_incantesimo": (incantesimo, 4),
    "vfx_incantesimo_scoppio": (incantesimo_scoppio, 7),
    "vfx_stretta_ferrea": (stretta_ferrea, 8),
    "vfx_incubo": (incubo, 8),
    "vfx_tocco_gelido": (tocco_gelido, 7),
    "vfx_passo_breve": (passo_breve, 7),
    "vfx_pugnalata_furtiva": (pugnalata_furtiva, 6),
    "vfx_velo_illusorio": (velo_illusorio, 8),
    "vfx_sigillo_su_arma": (sigillo_su_arma, 8),
    "vfx_richiamo_compagno": (richiamo_compagno, 8),
    "vfx_germoglio_rapido": (germoglio_rapido, 8),
    "vfx_analisi": (analisi, 7),
    "vfx_contrattacco": (contrattacco, 7),
}
