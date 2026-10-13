"""Terreni: texture seamless, tile di transizione "dual grid" e atlanti.

Idea (dual grid + livelli): ogni terreno ha un livello di priorita'. Per ogni terreno t (dal basso
all'alto) si disegna un layer il cui tile, centrato sui VERTICI tra 4 celle, dipende da quali delle 4
celle hanno livello >= t (maschera a 4 bit = 16 tile). Basta quindi 1 atlante di 16 tile per terreno,
senza autotile 47, e qualunque coppia di terreni si fonde in modo pulito.
"""
import math

import numpy as np

from .materials import E32, hex_to_rgb

TILE = 32


def _rgb(c):
    return np.array(hex_to_rgb(E32.get(c, c)), np.uint8)


def pnoise(S, period, seed, octaves=3):
    """Rumore di valore PERIODICO (si ripete ogni S pixel): i tile adiacenti combaciano."""
    rng = np.random.RandomState(seed)
    out = np.zeros((S, S)); amp, tot = 1.0, 0.0
    for o in range(octaves):
        P = max(1, int(period * (2 ** o)))
        g = rng.rand(P, P)
        xs = np.arange(S) * P / S
        x0 = np.floor(xs).astype(int); fx = xs - x0
        fx = fx * fx * (3 - 2 * fx)
        x1 = (x0 + 1) % P
        gy0 = g[x0][:, None] if False else None
        # interpolazione bilineare con wrap
        a = g[np.ix_(x0, x0)]; b = g[np.ix_(x0, x1)]; c = g[np.ix_(x1, x0)]; d = g[np.ix_(x1, x1)]
        fy, fxx = fx[:, None], fx[None, :]
        v = (a * (1 - fxx) + b * fxx) * (1 - fy) + (c * (1 - fxx) + d * fxx) * fy
        out += v * amp; tot += amp; amp *= 0.5
    return out / tot


BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def _quant(field, ramp, dither=0.0, S=TILE):
    n = len(ramp)
    f = np.clip(field, 0, 0.9999) * n
    if dither:
        t = np.tile(BAYER, (S // 4 + 1, S // 4 + 1))[:S, :S]
        f = f + (t - 0.5) * dither
    idx = np.clip(f.astype(int), 0, n - 1)
    return np.array([_rgb(c) for c in ramp])[idx], idx


# nome: (ramp scuro->chiaro, periodo rumore, contrasto, dither, dettaglio, livello)
TERRAINS = {
    "deep_water": dict(ramp=["navy", "blue_d", "blue_d", "blue"], period=3, dither=0.5, detail="waves", rim=None, level=0, anim=4),
    "water": dict(ramp=["blue_d", "blue", "blue", "cyan"], period=3, dither=0.5, detail="waves", rim="foam", level=1, anim=4),
    "sand": dict(ramp=["tan", "cream", "cream", "skin_l"], period=4, dither=0.5, detail="dots", rim="dark", rimc="orange_d", level=2),
    "mud": dict(ramp=["brown_dd", "brown_d", "brown_d", "brown"], period=3, dither=0.6, detail="puddles", rim="dark", level=3),
    "grass": dict(ramp=["green_d", "green_m", "green_m", "green"], period=4, dither=0.5, detail="tufts", rim="dark", rimc="green_d", level=4),
    "dry_grass": dict(ramp=["brown_d", "#8a7a38", "#b3a050", "#cdbb64"], period=4, dither=0.5, detail="tufts", rim="dark", rimc="brown", level=5),
    "forest": dict(ramp=["teal_d", "green_d", "green_d", "green_m"], period=4, dither=0.5, detail="leaves", rim="dark", rimc="teal_d", level=6),
    "dirt": dict(ramp=["brown_d", "brown", "brown", "orange_d"], period=4, dither=0.6, detail="pebbles", rim="dark", level=7),
    "path": dict(ramp=["brown_d", "brown", "#c9946a", "#dcb68a"], period=5, dither=0.6, detail="pebbles", rim="dark", rimc="brown_d", level=8),
    "stone": dict(ramp=["slate_d", "slate", "slate", "grey"], period=3, dither=0.5, detail="cobbles", rim="cliff", level=9),
    "snow": dict(ramp=["grey", "grey_l", "white", "white"], period=4, dither=0.4, detail="sparkle", rim="light", rimc="grey", level=10),
}
ORDER = sorted(TERRAINS, key=lambda k: TERRAINS[k]["level"])


def terrain_texture(name, S=TILE, seed=7, frame=0, nframes=4):
    d = TERRAINS[name]
    rs = hash(name) % 1000 + seed
    base = pnoise(S, d["period"], rs, 3)
    base = (base - base.min()) / (np.ptp(base) + 1e-6)
    ramp = d["ramp"]
    detail = d["detail"]
    y, x = np.mgrid[0:S, 0:S]
    rng = np.random.RandomState(rs)
    if detail == "waves":
        ph = frame / nframes * 2 * math.pi
        k = 2 * math.pi / S
        w = np.sin((y * 2 * k * 2 + 3.0 * np.sin(x * k + ph)) + ph) + 0.6 * np.sin((x * k * 2 + y * k) - ph * 1.0)
        base = np.clip(0.38 + 0.18 * base + 0.14 * w, 0, 1)
        img, idx = _quant(base, ramp, d["dither"], S)
        crest = (w > 1.25)
        img[crest] = _rgb("white") if name == "water" else _rgb("cyan")
        return img
    img, idx = _quant(base, ramp, d["dither"], S)
    n = len(ramp)
    def put(px, py, c):
        img[py % S, px % S] = _rgb(ramp[c])
    if detail == "tufts":
        for _ in range(S * S // 22):
            px, py = rng.randint(S), rng.randint(S)
            put(px, py, 0); put(px, py - 1, n - 1) if rng.rand() < .7 else None
        for _ in range(S * S // 160):
            px, py = rng.randint(S), rng.randint(S)
            img[py, px] = _rgb(["white", "yellow", "pink", "cyan"][rng.randint(4)]) if name == "grass" else img[py, px]
    elif detail == "leaves":
        for _ in range(S * S // 30):
            px, py = rng.randint(S), rng.randint(S)
            put(px, py, n - 1); put(px + 1, py, n - 2)
        for _ in range(S * S // 80):
            px, py = rng.randint(S), rng.randint(S)
            img[py, px] = _rgb(["orange_d", "amber", "rust"][rng.randint(3)])
    elif detail == "dots":
        for _ in range(S * S // 18):
            put(rng.randint(S), rng.randint(S), rng.choice([0, n - 1]))
    elif detail == "pebbles":
        for _ in range(S * S // 70):
            px, py = rng.randint(S), rng.randint(S)
            put(px, py, n - 1); put(px + 1, py, n - 2); put(px, py + 1, 0)
    elif detail == "puddles":
        for _ in range(3):
            px, py = rng.randint(S), rng.randint(S)
            for dx in range(-2, 3):
                img[py % S, (px + dx) % S] = _rgb("blue_d")
            img[(py + 1) % S, (px - 1) % S] = _rgb("blue"); img[(py + 1) % S, px % S] = _rgb("blue_d")
    elif detail == "cobbles":
        pts = rng.rand(7, 2) * S
        dist = np.full((S, S), 1e9); dist2 = np.full((S, S), 1e9)
        ids = np.zeros((S, S), int)
        for i, (cx, cy) in enumerate(pts):
            for ox in (-S, 0, S):
                for oy in (-S, 0, S):
                    dd = (x - cx - ox) ** 2 + (y - cy - oy) ** 2
                    m = dd < dist
                    dist2 = np.where(m, dist, np.minimum(dist2, dd))
                    ids = np.where(m, i, ids); dist = np.where(m, dd, dist)
        edge = (np.sqrt(dist2) - np.sqrt(dist)) < 1.8
        shade = (ids % 3)
        img = np.array([_rgb(ramp[1 + int(s) % 3 if 1 + int(s) % 3 < n else n - 1]) for s in shade.ravel()]).reshape(S, S, 3)
        img[edge] = _rgb(ramp[0])
    elif detail == "sparkle":
        for _ in range(S * S // 90):
            put(rng.randint(S), rng.randint(S), 0)
    return img


def layer_masks(S=TILE, seed=3, noise_amp=0.10):
    """16 maschere booleane (bit: 1=TL, 2=TR, 4=BL, 8=BR) con bordo irregolare ma periodico."""
    nz = pnoise(S, 4, seed, 3) - 0.5
    yy, xx = np.mgrid[0:S, 0:S]
    u = (xx + 0.5) / S; v = (yy + 0.5) / S
    masks = []
    for m in range(16):
        tl, tr, bl, br = (m & 1) > 0, (m & 2) > 0, (m & 4) > 0, (m & 8) > 0
        w = (tl * (1 - u) * (1 - v) + tr * u * (1 - v) + bl * (1 - u) * v + br * u * v)
        if m in (0, 15):
            masks.append(np.full((S, S), m == 15)); continue
        # il rumore e' spento sui bordi del tile dove il campo e' 0 o 1 (nessun taglio nei tile adiacenti)
        masks.append((w + nz * noise_amp * 2 * np.minimum(w, 1 - w) * 2) > 0.5)
    return masks


def _rim(mask, img, kind, rimc, ramp):
    S = mask.shape[0]
    p = np.pad(mask, 1, mode="edge")
    inner = mask & ~(p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:])
    out = img.copy()
    if kind == "dark" or kind == "cliff":
        out[inner] = _rgb(rimc) if rimc else _rgb(ramp[0])
    elif kind == "light":
        out[inner] = _rgb(rimc) if rimc else _rgb(ramp[-1])
    elif kind == "foam":
        out[inner] = _rgb("white")
    if kind == "cliff":
        # fronte roccioso: sotto il bordo inferiore aggiungi una fascia scura (profondita')
        below = np.zeros_like(mask)
        for k in (1, 2, 3):
            sh = np.zeros_like(mask); sh[k:, :] = mask[:-k, :] if k else mask
            below |= sh & ~mask
        out_rgba = None
    return out, inner


def build_atlas(name, S=TILE, seed=3):
    """Atlante RGBA 16 tile in una riga (indice = maschera). Per i terreni animati: righe = frame."""
    d = TERRAINS[name]
    masks = layer_masks(S, seed)
    nfr = d.get("anim", 1)
    atlas = np.zeros((S * nfr, S * 16, 4), np.uint8)
    for f in range(nfr):
        tex = terrain_texture(name, S, frame=f, nframes=nfr)
        for m, mask in enumerate(masks):
            img, inner = _rim(mask, tex, d["rim"], d.get("rimc"), d["ramp"]) if d["rim"] else (tex, None)
            tile = np.zeros((S, S, 4), np.uint8)
            tile[..., :3] = img; tile[..., 3] = np.where(mask, 255, 0)
            atlas[f * S:(f + 1) * S, m * S:(m + 1) * S] = tile
    return atlas


def compose_ground(levels, atlases=None, S=TILE, frame=0, seed=3):
    """levels: array HxW di nomi/indici (indice in ORDER). Ritorna immagine RGBA (H*S, W*S)."""
    lv = np.asarray(levels)
    H, W = lv.shape
    if atlases is None:
        atlases = {n: build_atlas(n, S, seed) for n in ORDER}
    pad = np.pad(lv, 1, mode="edge")
    canvas = np.zeros((H * S, W * S, 4), np.uint8)
    h2 = S // 2
    big = np.zeros(((H + 1) * S, (W + 1) * S, 4), np.uint8)       # canvas con mezzo tile di margine
    for ti, name in enumerate(ORDER):
        at = atlases[name]
        nfr = at.shape[0] // S
        fr = frame % nfr
        ge = pad >= ti
        # vertice (i,j) tra le celle pad[i..i+1, j..j+1]
        m = (ge[:-1, :-1] * 1 + ge[:-1, 1:] * 2 + ge[1:, :-1] * 4 + ge[1:, 1:] * 8)
        if ti == 0:
            m = np.full_like(m, 15)
        ys, xs = np.nonzero(m)
        for i, j in zip(ys, xs):
            mk = m[i, j]
            tile = at[fr * S:(fr + 1) * S, mk * S:(mk + 1) * S]
            blk = big[i * S:(i + 1) * S, j * S:(j + 1) * S]
            a = tile[..., 3:4] > 0
            blk[...] = np.where(a, tile, blk)
    return big[h2:h2 + H * S, h2:h2 + W * S].copy()
