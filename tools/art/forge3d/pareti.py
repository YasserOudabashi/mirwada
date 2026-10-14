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


def _faccia(mat, X, Yf, Hf, S, seed, Yw=None):
    """Indice di tono (0..n-1) per i pixel della faccia. X: x di mondo, Yf: y dal bordo in alto, Hf: altezza.
    Yw: y di mondo per il disegno (strati, blocchi): cosi' due pareti una sopra l'altra combaciano."""
    Yl, Yf = Yf, (Yf if Yw is None else Yw)
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
    t = t - ((Yl > Hf - S * 0.25) & (t > 1))                             # buio alla base
    t = np.where(Yl < max(2, S // 21), n - 1, t)                         # orlo in luce
    t = np.where(Yl == max(2, S // 21), n - 2, t)
    return np.clip(t, 0, n - 1)


def tile(mat, k, d, sx=None, dx=None, passaggio=None, col=0, S=64, seed=5, base=None, riga=None):
    """Una casella di parete RGBA (S x S): riga k (0 = in alto) di una parete alta d caselle.
    sx/dx: com'e' fatta l'estremita' sinistra/destra:
        None o 'cont' = la parete continua; 'int' = accanto c'e' la cima dell'altopiano (angolo rientrante:
        il bordo lo disegna la cima); 'est' = angolo sporgente: spigolo netto (contorno + fascia, chiara a
        sinistra e scura a destra) che continua il bordo laterale dell'altopiano.
    passaggio: None, 'S' (scalini) o 'R' (rampa). base: contorno in basso (False se sotto c'e' altra parete).
    col, riga: colonna e riga di mondo (la texture combacia tra caselle vicine)."""
    y, x = np.mgrid[0:S, 0:S]
    X, Yf, Hf = col * S + x, k * S + y, d * S
    ramp = MATERIALI[mat]["ramp"]
    t = _faccia(mat, X, Yf, Hf, S, seed, None if riga is None else riga * S + y)
    pal = np.array([_rgb(c) for c in ramp])
    img = pal[t]
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
    lw = _spessore(S)
    if sx == "est":                                            # spigolo sinistro, in luce
        img[:, 1:lw + 1] = pal[-1]; img[:, lw + 1] = pal[-2]; img[:, 0] = _rgb("ink")
    if dx == "est":                                            # spigolo destro, in ombra
        img[:, S - 1 - lw:S - 1] = pal[0]; img[:, S - 2 - lw] = pal[1]; img[:, S - 1] = _rgb("ink")
    if (k == d - 1 if base is None else base) and passaggio is None:
        img[S - 1] = _rgb("ink")                               # piede della parete
    out = np.zeros((S, S, 4), np.uint8)
    out[..., :3] = img; out[..., 3] = 255
    return out


def _spessore(S):
    """Spessore del bordo chiaro (in alto sulle pareti, ai lati della cima): uguale ovunque."""
    return max(2, S // 21)


def tile_ombra(sx=False, dx=False, S=64, angolo=False):
    """Ombra a terra sotto la parete: fascia di inchiostro semitrasparente, spostata a destra (luce a sinistra).
    angolo: a destra la parete prosegue una riga piu' in basso (gradino): l'angolo sporgente fa ombra anche
    nel quarto in alto a destra, dove il terreno della cima smussa l'angolo."""
    y, x = np.mgrid[0:S, 0:S]
    a = np.where(y < S // 6, 110, np.where(y < S // 3, 55, 0))
    if angolo:
        a = np.where((S - 1 - x) + y < S * 0.6, 110, a)              # triangolo verso l'angolo in alto a destra
    if sx:
        a = np.where(x < S // 4, 0, a)
    out = np.zeros((S, S, 4), np.uint8)
    out[..., :3] = OMBRA; out[..., 3] = a.astype(np.uint8)
    return out


def _con_materiale(mat, shape):
    """Vero dove la casella ha un materiale da parete. Senza mat: ovunque."""
    if mat is None:
        return np.ones(shape, bool)
    return np.array([[bool(v) for v in r] for r in mat], bool)


def facce(alt, mat=None):
    """Per ogni casella: (k, d, y del bordo) se e' parete, altrimenti None. alt: array H x W di interi.
    mat: se c'e', una parete nasce solo sotto una casella con materiale (una spiaggia sul mare, che e' piu'
    basso di un livello, non diventa scogliera)."""
    alt = np.asarray(alt)
    H, W = alt.shape
    ok = _con_materiale(mat, alt.shape)
    f = np.full((H, W), None, object)
    for x in range(W):
        for y in range(1, H):
            d = int(alt[y - 1, x] - alt[y, x]) if ok[y - 1, x] else 0
            for k in range(max(0, d)):
                if y + k < H:
                    f[y + k, x] = (k, d, y - 1)
    return f


def _cima(alt, mat, e, y, x, S, seed, f=None):
    """Casella alta che non e' parete: il bordo dell'altopiano. Su ogni lato (sinistra, destra, sopra) che
    confina con una casella piu' bassa - terreno o parete - disegna contorno + linea chiara, come l'orlo in
    cima alle pareti: cosi' il bordo gira l'angolo e lega un gradino al successivo. Le mura hanno in piu'
    il camminamento di pietre chiare su tutta la cima."""
    H, W = alt.shape
    h = alt[y, x]
    m = mat[y][x]
    if h <= 0 or not m:
        return None
    basso = lambda yy, xx: 0 <= yy < H and 0 <= xx < W and alt[yy, xx] < h
    sx, dx, su = basso(y, x - 1), basso(y, x + 1), basso(y - 1, x)
    muro = m == "mura"
    if not (sx or dx or su or muro):
        return None
    pal = np.array([_rgb(c) for c in MATERIALI[m]["ramp"]])
    out = np.zeros((S, S, 4), np.uint8)
    if muro:                                                   # camminamento: lastre quadrate chiare (cima, non faccia)
        yy, xx = np.mgrid[0:S, 0:S]
        q = S // 2
        X, Y = x * S + xx, y * S + yy
        tono = 3 + ((X // q) * 7 + (Y // q) * 3) % 2           # due toni chiari, una lastra per quarto di casella
        out[..., :3] = pal[np.minimum(tono, len(pal) - 1)]
        out[(X % q == 0) | (Y % q == 0), :3] = pal[1]           # fughe
        out[((X % q == 1) | (Y % q == 1)) & (X % q != 0) & (Y % q != 0), :3] = pal[-1]   # spigolo in luce
        out[..., 3] = 255
    lw = _spessore(S)
    if su:
        out[1:lw + 1, :, :3] = pal[-1]; out[lw + 1, :, :3] = pal[-2]; out[0, :, :3] = _rgb("ink")
        out[:lw + 2, :, 3] = 255
    # accanto c'e' la cima di una parete che comincia in questa riga: l'orlo chiaro gira l'angolo senza
    # interrompersi (niente pixel di contorno davanti alla linea chiara)
    gira = lambda xx: f is not None and 0 <= xx < W and f[y, xx] is not None and f[y, xx][0] == 0
    if sx:
        out[:, 1:lw + 1, :3] = pal[-1]; out[:, lw + 1, :3] = pal[-2]; out[:, 0, :3] = _rgb("ink")
        out[:, :lw + 2, 3] = 255
        if gira(x - 1):
            out[:lw, 0, :3] = pal[-1]
    if dx:
        out[:, S - 1 - lw:S - 1, :3] = pal[-1]; out[:, S - 2 - lw, :3] = pal[-2]; out[:, S - 1, :3] = _rgb("ink")
        out[:, S - 2 - lw:, 3] = 255
        if gira(x + 1):
            out[:lw, S - 1, :3] = pal[-1]
    return out


def _estremo(alt, e, y, x, dxx):
    """Tipo dell'estremita' di una parete verso la colonna x + dxx: vedi tile()."""
    W = alt.shape[1]
    xx = x + dxx
    if xx < 0 or xx >= W or e[y, xx]:
        return "cont"
    return "int" if alt[y, xx] > alt[y, x] else "est"


def terreno_sotto(ground, alt, mat=None):
    """Sotto una parete il terreno e' quello della cima (la casella in cima al bordo): la parete lo copre, e
    il passaggio tra due terreni cade al piede della parete invece di smussare gli angoli dell'altopiano."""
    g = np.array(ground, copy=True)
    f = facce(alt, mat)
    for y, x in zip(*np.nonzero(np.vectorize(lambda v: v is not None)(f))):
        g[y, x] = g[f[y, x][2], x]
    return g


def disegna(alt, mat, passaggi=None, S=64, seed=5):
    """Strato RGBA (H*S, W*S) con pareti e ombre, da mettere sopra il terreno.
    mat: H x W di nomi di MATERIALI (conta quello della casella in cima al bordo).
    passaggi: H x W di caratteri ('.', 'S', 'R'), letti sulle caselle di parete."""
    f = facce(alt, mat)
    H, W = f.shape
    out = np.zeros((H * S, W * S, 4), np.uint8)
    e_parete = np.vectorize(lambda v: v is not None)(f)
    alt = np.asarray(alt)
    for y in range(H):
        for x in range(W):
            if f[y, x] is None:
                cima = _cima(alt, mat, e_parete, y, x, S, seed, f)
                if cima is not None:
                    out[y * S:(y + 1) * S, x * S:(x + 1) * S] = cima
                if y > 0 and e_parete[y - 1, x]:               # ombra al piede della parete
                    sx = _estremo(alt, e_parete, y - 1, x, -1) == "est"
                    angolo = x + 1 < W and e_parete[y, x + 1] and not e_parete[y - 1, x + 1]
                    blk = out[y * S:(y + 1) * S, x * S:(x + 1) * S]
                    om = tile_ombra(sx, False, S, angolo)
                    vuoto = blk[..., 3] == 0
                    blk[vuoto] = om[vuoto]
                continue
            k, d, yb = f[y, x]
            sx, dx = _estremo(alt, e_parete, y, x, -1), _estremo(alt, e_parete, y, x, 1)
            p = passaggi[y][x] if passaggi is not None and passaggi[y][x] in "SR" else None
            base = k == d - 1 and not (y + 1 < H and e_parete[y + 1, x])   # sotto c'e' terreno, non altra parete
            out[y * S:(y + 1) * S, x * S:(x + 1) * S] = tile(mat[yb][x], k, d, sx, dx, p, x, S, seed, base, y)
    return out


def maschera(alt, mat=None):
    """Come facce(), ma solo vero/falso e senza cicli: per le mappe grandi (1200 x 1000)."""
    alt = np.asarray(alt)
    ok = _con_materiale(mat, alt.shape) if mat is None or not isinstance(mat, np.ndarray) else (mat != "")
    out = np.zeros(alt.shape, bool)
    salto = np.zeros(alt.shape, int)
    salto[1:] = np.where(ok[:-1], alt[:-1] - alt[1:], 0)  # quanto si scende entrando nella casella da sopra
    for k in range(int(salto.max()) if salto.size else 0):
        m = salto > k
        out[k:] |= m[:alt.shape[0] - k]
    return out
