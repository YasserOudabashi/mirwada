#!/usr/bin/env python3
"""
Interni (US-8B18c): pavimento e pareti di ogni interno (data/world/interni/<id>.json) in un'immagine sola, alla
grana del terreno del mondo (32 px per casella = un texel per unita'), per le due modalita'. Lo stile e' il campo
"stile" dell'interno (STILI qui sotto); la mappa ASCII resta la fonte di collisioni, nemici, oggetti e NPC.

    python tools/art/build_interni.py      # assets/interni/<tema>/<interno_id>.png

Vista 3/4 come il mondo: la parete con il pavimento davanti (a sud) si vede di fronte, con la cima e il
battiscopa; le altre dall'alto (la cima del muro, larga fino a 2 caselle dal pavimento). Luce da alto-sinistra: il
muro a ovest fa ombra sul pavimento. L'uscita (la casella di spawn) ha la soglia aperta nel muro accanto, con la luce
che entra e lo zerbino, o la scala a pioli se il muro e' a nord; i passaggi '+' una soglia di legno. Palette
Endesga 32 (nel tema cupo i gemelli di forge3d/tema.py), alpha pieno, stesso seed = stessi PNG.
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build_libro import rumore, soglia  # noqa: E402
from forge3d import tema  # noqa: E402
from forge3d.materials import E32  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DATI = os.path.join(ROOT, "data", "world", "interni")
OUT = os.path.join(ROOT, "assets", "interni")
T = 32
SEED = 11
PAVIMENTO = set(".,=+")
CAPO = 4                       # pixel della cima di una parete vista di fronte

# stile: pavimento (tipo, rampa dal piu' scuro), parete di fronte (tipo, rampa, rampa del rivestimento), cima
STILI = {
    "taverna": {"pavimento": ("assi", ["brown_dd", "brown_d", "brown_d", "brown"]),
                "parete": ("intonaco", ["brown", "tan", "cream"], ["brown_dd", "brown_d", "brown"]),
                "cima": ["brown_dd", "brown_d"]},
    "casa": {"pavimento": ("assi", ["brown_d", "brown", "tan", "tan"]),
             "parete": ("intonaco", ["brown", "skin_m", "skin_l"], ["brown_d", "brown", "tan"]),
             "cima": ["brown_dd", "brown_d"]},
    "bottega": {"pavimento": ("cotto", ["brown_d", "rust", "orange_d", "tan"]),
                "parete": ("intonaco", ["brown", "tan", "cream"], ["brown_d", "brown", "tan"]),
                "cima": ["brown_dd", "brown_d"]},
    "fucina": {"pavimento": ("lastre", ["slate_d", "slate", "slate", "grey"]),
               "parete": ("mattoni", ["brown_d", "rust", "orange_d"], ["brown_dd"]),
               "cima": ["navy", "slate_d"]},
    "archivio": {"pavimento": ("lastre", ["slate_d", "slate", "grey", "grey_l"]),
                 "parete": ("scaffali", ["brown_dd", "brown_d", "brown"],      # dorsi: 7 colori, uno per libro
                            ["red_d", "blue_d", "green_m", "purple_d", "brown", "amber", "teal_d"]),
                 "cima": ["navy", "slate_d"]},
    "torre": {"pavimento": ("lastre", ["slate_d", "slate", "grey", "grey"]),
              "parete": ("pietra", ["slate_d", "slate", "grey"], ["navy"]),
              "cima": ["navy", "slate_d"]},
    "capanna": {"pavimento": ("terra", ["brown_dd", "brown_d", "brown", "brown"]),
                "parete": ("tronchi", ["brown_dd", "brown_d", "brown", "tan"], ["ink"]),
                "cima": ["brown_dd", "brown_d"]},
    "sotterraneo": {"pavimento": ("lastre", ["navy", "slate_d", "slate_d", "slate"]),
                    "parete": ("pietra", ["navy", "slate_d", "slate"], ["ink"]),
                    "cima": ["ink", "navy"]},
}


def tavolozza():
    """I colori Endesga 32 per nome, nel tema corrente."""
    return {k: np.array([int(tema.colore(v)[i:i + 2], 16) for i in (1, 3, 5)], np.uint8) for k, v in E32.items()}


def colora(img, maschera, valore, toni, C):
    """Rampa retinata (Bayer 4x4): valore in [0, 1] sui toni dal piu' scuro."""
    n = len(toni)
    v = np.clip(valore, 0, 0.999) * n
    i = v.astype(int)
    i = np.where(v - i > soglia(*valore.shape), np.minimum(i + 1, n - 1), i)
    for k, t in enumerate(toni):
        img[maschera & (i == k)] = C[t]


def sposta(a, dy, dx):
    """a spostata di (dy, dx) pixel, con falso dove entra dal bordo (np.roll riavvolgerebbe: la porta in basso
    disegnava un contorno in cima alla stanza)."""
    out = np.zeros_like(a)
    h, w = a.shape
    out[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = a[max(-dy, 0):h + min(-dy, 0), max(-dx, 0):w + min(-dx, 0)]
    return out


def hash2(a, b, n):
    """Intero deterministico 0..n-1 da due interi (array numpy): stessa pietra, stesso tono."""
    h = (a * 73856093) ^ (b * 19349663) ^ SEED * 83492791
    return (h % n + n) % n


def pavimento(tipo, yy, xx, rng):
    H, W = yy.shape
    if tipo == "assi":                                    # assi orizzontali alte 8, giunti sfalsati per fila
        fila = yy // 8
        o = hash2(fila, 1, 48)
        pezzo = (xx + o) // 48
        v = 0.55 + (hash2(fila, pezzo, 100) / 100.0 - 0.5) * 0.35 + (rumore(H, W, 4, rng) - 0.5) * 0.25
        v = np.where(yy % 8 == 0, v + 0.18, v)
        v = np.where((yy % 8 == 7) | ((xx + o) % 48 == 0), 0.02, v)
        return v
    if tipo in ("lastre", "cotto"):                       # lastre a corsi sfalsati, cotto a quadri allineati
        lato = 16
        o = np.where((yy // lato) % 2 == 1, lato // 2, 0) if tipo == "lastre" else 0
        cx, cy = (xx + o) // lato, yy // lato
        v = 0.55 + (hash2(cx, cy, 100) / 100.0 - 0.5) * 0.4 + (rumore(H, W, 3, rng) - 0.5) * 0.2
        v = np.where(((xx + o) % lato == 0) | (yy % lato == 0), v + 0.15, v)
        return np.where(((xx + o) % lato == lato - 1) | (yy % lato == lato - 1), 0.02, v)
    # terra battuta con paglia
    v = 0.5 + (rumore(H, W, 9, rng) - 0.5) * 0.3 + (rumore(H, W, 2, rng) - 0.5) * 0.15
    return v


def parete(tipo, yy, xx, rng):
    """Valore della parete vista di fronte (ly = riga dentro la casella, sotto la cima) e una maschera 'rivestimento'
    (seconda rampa: boiserie, malta, libri)."""
    H, W = yy.shape
    ly = yy % T
    seconda = np.zeros((H, W), bool)
    if tipo == "intonaco":                                # intonaco sopra, boiserie di assi verticali sotto
        v = 0.62 + (rumore(H, W, 5, rng) - 0.5) * 0.35 + (rumore(H, W, 2, rng) - 0.5) * 0.12
        v = np.where(ly < CAPO + 3, v - 0.3, v)           # l'ombra sotto la cima
        bois = ly >= 19
        seconda = bois.copy()
        vb = np.where(xx % 6 == 0, 0.05, 0.55 + (hash2(xx // 6, 3, 100) / 100.0 - 0.5) * 0.3)
        vb = np.where(ly == 19, 0.95, vb)                 # listello in luce
        vb = np.where(ly >= 29, 0.15, vb)                 # battiscopa
        return np.where(bois, vb, v), seconda
    if tipo == "tronchi":                                 # tronchi orizzontali alti 7, tondi alla luce dall'alto
        k = (ly - CAPO) % 7
        v = 0.15 + 0.8 * np.sin(np.pi * (k + 0.5) / 7.0) ** 0.7 - k / 7.0 * 0.3
        v = v + (rumore(H, W, 3, rng) - 0.5) * 0.15
        seconda = (k == 6)
        return v, seconda
    if tipo in ("pietra", "mattoni"):                     # blocchi a corsi sfalsati con la malta
        bw, bh = (12, 7) if tipo == "pietra" else (8, 4)
        r = (ly - CAPO) // bh
        o = np.where(r % 2 == 1, bw // 2, 0)
        v = 0.5 + (hash2((xx + o) // bw, r + yy // T * 9, 100) / 100.0 - 0.5) * 0.45
        v = v + (rumore(H, W, 3, rng) - 0.5) * 0.15
        v = np.where((ly - CAPO) % bh == 0, v + 0.2, v)
        seconda = ((ly - CAPO) % bh == bh - 1) | ((xx + o) % bw == bw - 1)
        return v, seconda
    # scaffali di libri: montanti ogni 32, ripiani ogni 9, dorsi colorati di 2-3 pixel
    rip = (ly - CAPO) % 9
    v = np.where(rip >= 7, np.where(rip == 7, 0.9, 0.35), 0.1)          # ripiano: bordo in luce, poi legno
    montante = (xx % T == 0) | (xx % T == T - 1)
    v = np.where(montante, 0.5, v)
    dorso = (xx // 3) * 7 + (ly - CAPO) // 9 * 13 + yy // T * 31
    alto = hash2(dorso, 5, 3)
    libro = (rip < 7) & (rip >= alto) & ~montante & (xx % 3 != 2)
    seconda = libro
    return np.where(libro, hash2(dorso, 7, 7), v), seconda              # sui libri: l'indice del colore


def interno(doc, rng, C):
    st = STILI[doc["stile"]]
    mappa = doc["mappa"]
    h, w = len(mappa), len(mappa[0])
    pav = np.array([[ch in PAVIMENTO for ch in r] for r in mappa])
    muro = ~pav
    vicino = np.zeros_like(pav)                           # un pavimento entro 2 caselle: cima del muro
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            vicino |= np.roll(np.roll(np.pad(pav, 2), dy, 0), dx, 1)[2:-2, 2:-2]
    fronte = muro & np.vstack([pav[1:], np.zeros((1, w), bool)])        # il pavimento e' subito a sud
    sx, sy = doc["spawn"]
    # l'uscita: la prima casella accanto allo spawn verso sud, ovest, est, nord che e' un muro o un passaggio
    uscita = None
    for dx, dy in ((0, 1), (-1, 0), (1, 0), (0, -1)):
        x, y = sx + dx, sy + dy
        if 0 <= x < w and 0 <= y < h and mappa[y][x] in "#+":
            uscita = (x, y, dx, dy)
            break

    H, W = h * T, w * T
    yy, xx = np.mgrid[0:H, 0:W]
    cy, cx = yy // T, xx // T
    p_pav = pav[cy, cx]
    p_fronte = fronte[cy, cx] & (yy % T >= CAPO)
    p_cima = muro[cy, cx] & vicino[cy, cx] & ~p_fronte
    if uscita and uscita[3] == 1:                          # porta nel muro a sud: la casella si apre
        ux, uy = uscita[0], uscita[1]
        apri = (cx == ux) & (cy == uy) & (xx % T >= 4) & (xx % T < T - 4)
        p_pav |= apri
        p_cima &= ~apri
    elif uscita and uscita[2] != 0 and mappa[uscita[1]][uscita[0]] == "#":   # porta nel muro di lato
        ux, uy = uscita[0], uscita[1]
        apri = (cx == ux) & (cy == uy) & (yy % T >= 4) & (yy % T < T - 4)
        p_pav |= apri
        p_cima &= ~apri
    img = np.zeros((H, W, 3), np.uint8)
    img[:] = C["ink"]                                     # fuori dalla stanza: il buio

    # --- pavimento: ombra del muro a ovest (luce da sinistra) e un filo d'ombra lungo tutti i muri ---
    tipo_p, rampa_p = st["pavimento"]
    vp = pavimento(tipo_p, yy, xx, rng)
    non_pav = ~p_pav
    ombra = np.zeros((H, W), bool)
    for k in range(1, 6):
        ombra |= sposta(non_pav, 0, k)
    vp = np.where(ombra, vp - 0.22, vp)
    filo = sposta(non_pav, 1, 0) | sposta(non_pav, -1, 0) | sposta(non_pav, 0, -1) | sposta(non_pav, 0, 2)
    vp = np.where(filo, vp - 0.1, vp)
    if uscita:                                            # la luce che entra dall'uscita
        lx = (uscita[0] + 0.5) * T
        ly_ = (uscita[1] + 0.5) * T
        d = np.hypot(xx + 0.5 - lx, yy + 0.5 - ly_)
        vp = np.where(d < 40, vp + (1 - d / 40.0) * 0.35, vp)
    colora(img, p_pav, vp, rampa_p, C)
    if tipo_p == "terra":                                 # fili di paglia
        paglia = p_pav & (rng.rand(H, W) < 0.012) & ~ombra
        for k in range(3):
            img[sposta(paglia, 0, k) & p_pav] = C["amber"] if k == 1 else C["tan"]

    # --- passaggi '+': una soglia di legno di traverso ---
    for y, r in enumerate(mappa):
        for x, ch in enumerate(r):
            if ch == "+":
                orizz = (y > 0 and mappa[y - 1][x] == "#") or (y + 1 < h and mappa[y + 1][x] == "#")
                m = (cx == x) & (cy == y) & ((xx % T >= 13) & (xx % T < 19) if orizz else (yy % T >= 13) & (yy % T < 19))
                colora(img, m, np.full((H, W), 0.6) + (rumore(H, W, 2, rng) - 0.5) * 0.3,
                       ["brown_d", "brown", "tan"], C)

    # --- parete di fronte ---
    tipo_f, rampa_f, rampa_2 = st["parete"]
    vf, seconda = parete(tipo_f, yy, xx, rng)
    colora(img, p_fronte & ~seconda, vf, rampa_f, C)
    if tipo_f == "scaffali":                              # dorsi a colore pieno, uno per libro
        for k, col in enumerate(rampa_2):
            img[p_fronte & seconda & (vf == k)] = C[col]
    else:
        colora(img, p_fronte & seconda, vf, rampa_2, C)

    # --- cima dei muri: un bordo in luce verso la stanza, contorno d'inchiostro ---
    p_cima_tutta = p_cima | (fronte[cy, cx] & (yy % T < CAPO))
    vc = 0.4 + (rumore(H, W, 6, rng) - 0.5) * 0.15
    colora(img, p_cima_tutta, vc, st["cima"], C)
    dentro = p_pav | p_fronte
    tocca = sposta(dentro, 1, 0) | sposta(dentro, -1, 0) | sposta(dentro, 0, 1) | sposta(dentro, 0, -1)
    img[p_cima_tutta & tocca] = C["ink"]
    tocca2 = (sposta(dentro, 2, 0) | sposta(dentro, -2, 0) | sposta(dentro, 0, 2) | sposta(dentro, 0, -2))
    img[p_cima_tutta & tocca2 & ~tocca] = C[st["cima"][-1]]
    img[p_fronte & sposta(p_pav, -1, 0)] = C["ink"]     # piede della parete

    # --- uscita: zerbino davanti alla porta, o scala a pioli verso l'alto ---
    if uscita and uscita[3] == -1:
        x0, y0 = uscita[0] * T, uscita[1] * T
        sub = img[y0:y0 + T, x0:x0 + T]
        sub[CAPO:, 8:24] = C["ink"]                       # il buio della botola
        for gx in (9, 22):
            sub[CAPO:, gx] = C["brown"]
            sub[CAPO:, gx + 1] = C["brown_d"]
        for gy in range(CAPO + 3, T, 5):
            sub[gy, 11:22] = C["tan"]
            sub[gy + 1, 11:22] = C["brown_d"]
    elif uscita:
        x0, y0 = sx * T, sy * T
        mx = (slice(y0 + 12, y0 + 26), slice(x0 + 4, x0 + 28))
        img[mx] = C["red_d"]
        img[y0 + 12, x0 + 4:x0 + 28] = img[y0 + 25, x0 + 4:x0 + 28] = C["brown_dd"]
        img[y0 + 12:y0 + 26, x0 + 4] = img[y0 + 12:y0 + 26, x0 + 27] = C["brown_dd"]
        img[y0 + 15:y0 + 23:3, x0 + 7:x0 + 25] = C["red"]
    return img


def main():
    temi = ("luminoso", "cupo")
    for t in temi:
        tema.imposta(t)
        C = tavolozza()
        consentiti = {tuple(int(c) for c in v) for v in C.values()}
        os.makedirs(os.path.join(OUT, t), exist_ok=True)
        for path in sorted(glob.glob(os.path.join(DATI, "*.json"))):
            doc = json.load(open(path))
            rng = np.random.RandomState(SEED)
            img = interno(doc, rng, C)
            usati = {tuple(int(c) for c in p) for p in img.reshape(-1, 3)}
            fuori = usati - consentiti
            assert not fuori, f"{doc['interno_id']}: colori fuori palette {sorted(fuori)[:5]}"
            dest = os.path.join(OUT, t, doc["interno_id"] + ".png")
            Image.fromarray(img).save(dest)
            print("  " + os.path.relpath(dest, ROOT), img.shape[1], "x", img.shape[0])
    tema.imposta("luminoso")


if __name__ == "__main__":
    main()
