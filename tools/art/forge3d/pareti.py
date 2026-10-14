"""Pareti: la faccia verticale dei dislivelli (vista 3/4, luce in alto a sinistra).

Ogni casella ha un'ALTEZZA intera (0 = pianura, 1 = gradone...). Dove una casella e' piu' bassa di
quella sopra di lei sullo schermo, la differenza diventa parete: 1 casella di parete per livello,
disegnata nelle caselle basse subito sotto il bordo (non calpestabili). Sotto la parete, un'ombra.

Materiali (riga in MATERIALI, non una classe): arenaria a strati, roccia fratturata, mura a blocchi.
La texture e' calcolata in coordinate di mondo e si ripete ogni 3 caselle: lungo una parete i pezzi
centrali sono 3 varianti diverse che si incastrano. Passaggi: 'S' = scalini scolpiti, 'R' = rampa.
"""
import functools
import zlib

import numpy as np

from .terrain import _rgb, _voronoi, pnoise

MATERIALI = {
    # ramp dal piu' scuro al piu' chiaro (Endesga 32); motivo della faccia
    "arenaria": dict(ramp=["brown_dd", "brown_d", "rust", "orange_d", "tan"], motivo="strati"),
    "roccia": dict(ramp=["ink", "navy", "slate_d", "slate", "grey"], motivo="fratture"),
    "mura": dict(ramp=["brown_dd", "slate_d", "slate", "grey", "grey_l"], motivo="blocchi"),
}
RAMPA = ["brown_dd", "brown_d", "brown", "orange_d"]        # terra e pietrisco della rampa
OMBRA = (0x18, 0x14, 0x25)                                   # inchiostro: l'ombra a terra e' l'unico alpha intermedio
PERIODO = 3                                                  # la faccia si ripete ogni 3 caselle


@functools.lru_cache(maxsize=None)
def _campi(mat, S, seed):
    """Rumore e celle di Voronoi periodici su 3 caselle, per materiale (stesso seed = stessi pixel)."""
    rs = zlib.crc32(mat.encode()) % 1000 + seed
    P = PERIODO * S
    nz = pnoise(P, 6, rs, 3)
    ids, bordo = _voronoi(np.random.RandomState(rs), 14, P)
    return nz, ids, bordo


def _faccia(mat, X, Yf, Hf, S, seed):
    """Indice di tono (0..n-1) per i pixel della faccia. X: x di mondo, Yf: y dal bordo in alto, Hf: altezza."""
    d = MATERIALI[mat]
    n = len(d["ramp"])
    nz, ids, bordo = _campi(mat, S, seed)
    P = PERIODO * S
    xp, yp = X % P, Yf % P
    if d["motivo"] == "strati":
        h = S / 5
        off = (nz[0, xp] - 0.5) * S / 2.5                                # strati che salgono e scendono piano
        v = Yf + off
        banda = (v // h).astype(int)
        t = 1 + (banda * 2 + (banda // 3)) % 3
        t = np.where((v % h) < 1.5, 0, np.where((v % h) < 2.5, np.minimum(t + 1, n - 1), t))  # fessura + spigolo in luce
        crepa = (nz[(banda * 37) % P, xp] > 0.74) & (np.abs((xp * 7 + banda * 11) % 23 - 11) < 1)
        t = np.where(crepa, 0, t)
    elif d["motivo"] == "fratture":
        t = 1 + ids[yp, xp] % 3                                          # una lastra di roccia per cella
        su = np.roll(bordo, 2, 0)[yp, xp] < 1.5                          # sotto il bordo in alto: faccia in luce
        t = np.where(su, np.minimum(t + 1, n - 1), t)
        t = np.where(bordo[yp, xp] < 1.5, 0, t)
    else:                                                                # mura: blocchi sfalsati
        bh, bw = S // 4, S // 2
        riga = Yf // bh
        col = (X + (riga % 2) * (bw // 2)) // bw
        t = 1 + (riga * 5 + col * 3 + (col * riga) % 2) % 3
        xr, yr = (X + (riga % 2) * (bw // 2)) % bw, Yf % bh
        t = np.where((xr == 1) | (yr == 1), np.minimum(t + 1, n - 1), t)   # spigolo in luce in alto a sinistra
        manca = ((riga * 13 + col * 7) % 17 == 0)                        # qualche blocco caduto: buco in ombra
        t = np.where(manca, np.where(yr < bh // 2, 0, 1), t)
        t = np.where((xr == 0) | (yr == 0), 0, t)                        # fughe
    t = t - ((Yf > Hf - S * 0.25) & (t > 1))                             # buio alla base
    t = np.where(Yf < max(2, S // 21), n - 1, t)                         # orlo in luce
    t = np.where(Yf == max(2, S // 21), n - 2, t)
    return np.clip(t, 0, n - 1)


def tile(mat, k, d, sx=False, dx=False, passaggio=None, col=0, S=64, seed=5):
    """Una casella di parete RGBA (S x S): riga k (0 = in alto) di una parete alta d caselle.
    sx/dx: la parete finisce a sinistra/destra. passaggio: None, 'S' (scalini) o 'R' (rampa).
    col: colonna di mondo (sceglie la variante: col % 3)."""
    y, x = np.mgrid[0:S, 0:S]
    X, Yf, Hf = col * S + x, k * S + y, d * S
    ramp = MATERIALI[mat]["ramp"]
    t = _faccia(mat, X, Yf, Hf, S, seed)
    pal = np.array([_rgb(c) for c in ramp])
    img = pal[t]
    alpha = np.full((S, S), 255, np.uint8)
    nz = _campi(mat, S, seed)[0]
    if passaggio == "S":                                       # scalini: alzate scure, pedate chiare, fianchi
        g = S // 5
        img = pal[np.clip(np.where((Yf % g) < g * 0.35, 1, 3 + ((Yf % g) < g * 0.5)), 0, len(ramp) - 1)]
        img[x < S // 8] = pal[0]; img[x >= S - S // 8] = pal[1]
    elif passaggio == "R":                                     # rampa: sentiero di terra che scende, bordi in ombra
        pr = np.array([_rgb(c) for c in RAMPA])
        v = 3 - np.minimum(3, ((Yf + nz[(y * 2) % S, x] * S / 3) * 4) // Hf).astype(int)  # chiara in alto
        img = pr[np.clip(v, 0, 3)]
        rs = np.random.RandomState(seed * 1000 + col * 7 + k)          # sassi sparsi, deterministici
        for sx_, sy_ in rs.randint(S // 8, S - S // 8, (6, 2)):
            img[sy_, sx_:sx_ + 2] = _rgb("grey"); img[sy_ + 1, sx_:sx_ + 2] = pr[0]
        img[(x < S // 10) | (x >= S - S // 10)] = pr[0]
    lato = (2 + 4 * nz[:S, 0:1]).astype(int)                    # spigolo frastagliato: si vede il terreno sotto
    if sx:
        alpha[x < lato - 2] = 0
        img[(x >= lato - 2) & (x < lato)] = _rgb("ink")
    if dx:
        dentro = x < S - lato
        img[~dentro] = pal[0]                                  # lato in ombra: luce da sinistra
        alpha[x >= S - lato + 2] = 0
    if k == d - 1 and passaggio is None:                       # base frastagliata, sassi caduti
        base = S - 1 - (nz[0:1, :S] * 4).astype(int)
        alpha[y > base] = 0
        img[y == base] = _rgb("ink")
    out = np.zeros((S, S, 4), np.uint8)
    out[..., :3] = img; out[..., 3] = alpha
    return out


def tile_ombra(sx=False, dx=False, S=64):
    """Ombra a terra sotto la parete: fascia di inchiostro semitrasparente, spostata a destra (luce a sinistra)."""
    y, x = np.mgrid[0:S, 0:S]
    a = np.where(y < S // 6, 110, np.where(y < S // 3, 55, 0))
    if sx:
        a = np.where(x < S // 4, 0, a)
    out = np.zeros((S, S, 4), np.uint8)
    out[..., :3] = OMBRA; out[..., 3] = a.astype(np.uint8)
    return out


def facce(alt):
    """Per ogni casella: (k, d, y del bordo) se e' parete, altrimenti None. alt: array H x W di interi."""
    alt = np.asarray(alt)
    H, W = alt.shape
    f = np.full((H, W), None, object)
    for x in range(W):
        for y in range(1, H):
            d = int(alt[y - 1, x] - alt[y, x])
            for k in range(max(0, d)):
                if y + k < H:
                    f[y + k, x] = (k, d, y - 1)
    return f


def disegna(alt, mat, passaggi=None, S=64, seed=5):
    """Strato RGBA (H*S, W*S) con pareti e ombre, da mettere sopra il terreno.
    mat: H x W di nomi di MATERIALI (conta quello della casella in cima al bordo).
    passaggi: H x W di caratteri ('.', 'S', 'R'), letti sulle caselle di parete."""
    f = facce(alt)
    H, W = f.shape
    out = np.zeros((H * S, W * S, 4), np.uint8)
    e_parete = np.vectorize(lambda v: v is not None)(f)
    for y in range(H):
        for x in range(W):
            if f[y, x] is None:
                if y > 0 and e_parete[y - 1, x]:               # ombra sotto la base
                    sx = x == 0 or not e_parete[y - 1, x - 1]
                    out[y * S:(y + 1) * S, x * S:(x + 1) * S] = tile_ombra(sx, False, S)
                continue
            k, d, yb = f[y, x]
            sx = x == 0 or not e_parete[y, x - 1]
            dx = x == W - 1 or not e_parete[y, x + 1]
            p = passaggi[y][x] if passaggi is not None and passaggi[y][x] in "SR" else None
            out[y * S:(y + 1) * S, x * S:(x + 1) * S] = tile(mat[yb][x], k, d, sx, dx, p, x, S, seed)
    return out
