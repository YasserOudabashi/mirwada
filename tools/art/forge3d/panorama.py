"""Panorami a strati (parallasse): cielo, sole/luna, nuvole, montagne lontane, colline, foresta/mare/deserto.

Restituisce i singoli strati RGBA (per il parallasse nel gioco) e anche l'immagine composta.
"""
import math

import numpy as np

from .materials import E32, hex_to_rgb
from .terrain import BAYER

TIMES = {
    "dawn": dict(sky=["#5a6988", "#b55088", "#f6757a", "#feae34", "#fee761"], far="#8b6f9a", mid="#6d4f7d", near="#3e3558",
                 fg="#262b44", citta="#4a3a62", sun="#fee761", sun_y=0.62, glow="#feae34", stars=0, cloud=("#f6757a", "#ffc08a", "#fee0b0")),
    "day": dict(sky=["#0099db", "#2cb0e8", "#5fc8f0", "#9fe3f8", "#d7f3fb"], far="#8aa2cc", mid="#4f7aa0", near="#2f6e58",
                fg="#265c42", citta="#5a6988", sun="#fff3b0", sun_y=0.22, glow="#fee761", stars=0, cloud=("#c0cbdc", "#ffffff", "#ffffff")),
    "dusk": dict(sky=["#262b44", "#68386c", "#b55088", "#f77622", "#feae34"], far="#7a4a82", mid="#52325f", near="#2f2447",
                 fg="#181425", citta="#3a2a50", sun="#fee761", sun_y=0.66, glow="#f77622", stars=0.3, cloud=("#68386c", "#e4693f", "#feae34")),
    "night": dict(sky=["#0b0a18", "#181425", "#262b44", "#3a4466", "#3a4466"], far="#2a3254", mid="#1f2442", near="#161a30",
                  fg="#0f1020", citta="#1c2140", sun="#e8eefc", sun_y=0.2, glow="#5a6988", stars=1.0, cloud=("#262b44", "#3a4466", "#5a6988")),
}


def _c(h):
    return np.array(hex_to_rgb(E32.get(h, h)), float)


def _noise1d(n, scale, seed, octaves=4):
    rng = np.random.RandomState(seed)
    out = np.zeros(n); amp = 1.0; tot = 0
    for o in range(octaves):
        k = int(n / scale * 2 ** o) + 3
        g = rng.rand(k)
        xs = np.arange(n) * (k - 3) / n
        i = xs.astype(int); f = xs - i; f = f * f * (3 - 2 * f)
        out += amp * (g[i] * (1 - f) + g[i + 1] * f); tot += amp; amp *= 0.5
    return out / tot


def _noise2d(W, H, scale, seed, octaves=3):
    from .world import fbm
    return fbm(W, H, scale, octaves, seed)


def _dither_bands(t, colors, W, H):
    """Gradiente verticale t (0..1) quantizzato in bande con ordered dithering (look pixel art)."""
    n = len(colors)
    f = t * (n - 1)
    y, x = np.mgrid[0:H, 0:W]
    thr = BAYER[y % 4, x % 4]
    i = np.clip((f + (thr - 0.5) * 0.9).round().astype(int), 0, n - 1)
    return np.array(colors)[i]


def panorama(W=640, H=360, time="day", biome="forest", seed=3, horizon=0.62, mountains=True, clouds=True):
    P = TIMES[time]
    rs = np.random.RandomState(seed)
    layers = {}
    img = np.zeros((H, W, 4), np.uint8)
    # cielo
    y = np.linspace(0, 1, H)[:, None] * np.ones((1, W))
    sky = _dither_bands(np.clip(y / horizon, 0, 1), [_c(c) for c in P["sky"]], W, H)
    layers["sky"] = np.dstack([sky, np.full((H, W), 255)]).astype(np.uint8)
    L = layers["sky"].copy()
    yy, xx = np.mgrid[0:H, 0:W]
    if P["stars"]:
        for _ in range(int(W * H * 0.0012 * P["stars"])):
            sx, sy = rs.randint(W), rs.randint(int(H * horizon * 0.75))
            L[sy, sx, :3] = (255, 255, 255) if rs.rand() < .6 else (150, 170, 230)
    sx = W * (0.72 if time in ("day", "dusk") else 0.3)
    sy = H * (P["sun_y"] if time != "day" else 0.2)
    d = np.hypot(xx - sx, yy - sy)
    glow = np.clip(1 - d / (H * 0.35), 0, 1)
    gl = _c(P["glow"])
    L[..., :3] = np.where((glow > 0.45 + (BAYER[yy % 4, xx % 4] - .5) * .25)[..., None], gl.astype(np.uint8), L[..., :3])
    L[..., :3] = np.where((d < H * 0.07)[..., None], _c(P["sun"]).astype(np.uint8), L[..., :3])
    if time == "night":      # luna: falce
        cres = (np.hypot(xx - (sx + H * 0.03), yy - (sy - H * 0.01)) < H * 0.055) & (d < H * 0.07)
        L[..., :3] = np.where(cres[..., None], _c("#3a4466").astype(np.uint8), L[..., :3])
    layers["sky"] = L
    # nuvole
    if clouds:
        cl = np.zeros((H, W, 4), np.uint8)
        nz = _noise2d(W, H, 40, seed + 1)
        nz2 = _noise2d(W, H, 14, seed + 2)
        m = (nz * 0.8 + nz2 * 0.25) > 0.78
        m &= (yy < H * horizon * 0.8) & (yy > H * 0.06)
        c0, c1, c2 = (_c(c).astype(np.uint8) for c in P["cloud"])
        top = m & ~np.roll(m, 3, axis=0)
        cl[m, :3] = c0; cl[m, 3] = 255
        mid = m & np.roll(m, 3, axis=0) & ~np.roll(m, 7, axis=0)
        cl[mid, :3] = c1
        cl[top, :3] = c2
        layers["clouds"] = cl
    # montagne / colline a strati
    base_y = H * horizon
    def ridge(amp, scale, off, col, seed_, sharp=False):
        n = _noise1d(W, scale, seed_)
        if sharp:
            n = 1 - np.abs(2 * n - 1)
        top_y = base_y - off - n * amp
        lay = np.zeros((H, W, 4), np.uint8)
        mask = yy >= top_y[None, :]
        lay[mask, :3] = col.astype(np.uint8); lay[mask, 3] = 255
        edge = mask & ~np.roll(mask, 1, axis=0)
        lay[edge, :3] = np.clip(col * 1.25 + 20, 0, 255).astype(np.uint8)
        return lay
    if mountains:
        layers["far"] = ridge(H * 0.62, 150, H * 0.06, _c(P["far"]), seed + 3, sharp=True)
        layers["mid"] = ridge(H * 0.34, 90, H * 0.0, _c(P["mid"]), seed + 4, sharp=False)
    layers["near"] = ridge(H * 0.16, 60, -H * 0.03, _c(P["near"]), seed + 5)
    # primo piano per bioma
    fg = np.zeros((H, W, 4), np.uint8)
    fgc = _c(P["fg"])
    gy = int(H * (horizon + 0.12))
    if biome in ("forest", "snow", "taiga"):
        fg[gy:, :, :3] = (fgc if biome != "snow" else _c("#c0cbdc" if time == "day" else "#5a6988")).astype(np.uint8); fg[gy:, :, 3] = 255
        for layer, (cnt, hmin, hmax, shade) in enumerate([(26, 40, 70, 0.8), (16, 70, 120, 1.0)]):
            col = (fgc * shade + (0 if biome != "snow" else 20)).clip(0, 255).astype(np.uint8)
            for _ in range(cnt):
                tx = rs.randint(-10, W + 10); th = rs.randint(hmin, hmax); ty = gy + rs.randint(0, 30) + layer * 20
                tw = th * 0.38
                for k in range(4):
                    seg = th * (0.42 - 0.06 * k)
                    yb = ty - th * 0.2 * k
                    wd = tw * (1 - k * 0.22)
                    for row in range(int(seg)):
                        w_ = int(wd * (row / seg))
                        yy_ = int(yb - seg + row)
                        if 0 <= yy_ < H:
                            x0, x1 = max(0, tx - w_), min(W, tx + w_ + 1)
                            fg[yy_, x0:x1, :3] = col; fg[yy_, x0:x1, 3] = 255
                fg[int(ty):int(ty) + 6, max(0, tx - 1):max(0, tx + 2), :3] = col * 0.7
    elif biome == "sea":
        water = _dither_bands(np.clip((yy - base_y) / (H - base_y), 0, 1), [_c("#124e89"), _c("#0099db"), _c("#2ce8f5")][::-1] if time == "day" else [_c(P["near"]), _c(P["mid"]), _c(P["far"])], W, H)
        mask = yy >= base_y + 4
        fg[mask, :3] = water[mask]; fg[mask, 3] = 255
        refl = np.abs(xx - sx) < (18 + (yy - base_y) * 0.12)
        stripes = ((yy + (np.sin(xx * 0.3 + yy) * 2).astype(int)) % 5 == 0) & refl & mask
        fg[stripes, :3] = _c(P["sun"]).astype(np.uint8)
    elif biome == "desert":
        dune = (H * 0.78 + np.sin(xx / 70.0 + 1) * 24 + np.sin(xx / 23.0) * 6 + _noise1d(W, 50, seed)[None, :] * 20)
        sand = _c("#e4a672") if time == "day" else _c(P["near"]) * 1.4
        mask = yy >= dune
        fg[mask, :3] = sand.clip(0, 255).astype(np.uint8); fg[mask, 3] = 255
        shade = mask & (yy < dune + 10 + np.sin(xx / 30.0) * 6) & (np.sin(xx / 70.0 + 1) < 0)
        fg[shade, :3] = (sand * 0.78).astype(np.uint8)
    layers["fg"] = fg
    comp = layers["sky"].copy()
    for k in ("clouds", "far", "mid", "near", "fg"):
        if k in layers:
            a = layers[k][..., 3:4] > 0
            comp = np.where(a, layers[k], comp)
    return comp, layers


# --- strati per il parallasse che si ripetono in orizzontale (US-8B74) -----------------------------

def _periodico(campo):
    """Un campo largo 2W -> largo W e periodico in x: il bordo destro combacia col sinistro."""
    W = campo.shape[-1] // 2
    t = np.arange(W) / W
    return campo[..., W:] * (1 - t) + campo[..., :W] * t


def _rampa_v(mask, top, col_alto, col_basso, H, W, alto=8):
    """Colore di un rilievo: piu' chiaro (velato dal cielo) per `alto` pixel sotto la cresta, retinato."""
    yy, xx = np.mgrid[0:H, 0:W]
    t = np.clip((yy - top[None, :]) / alto, 0, 1)
    thr = BAYER[yy % 4, xx % 4]
    return np.where(((t + (thr - 0.5) * 0.8) < 0.5)[..., None], col_alto, col_basso)


def _rilievo(W, H, base_y, amp, scala, off, col, cielo, seed, aguzzo=False):
    n = _periodico(_noise1d(2 * W, scala, seed))
    if aguzzo:
        n = 1 - np.abs(2 * n - 1)
    top = base_y - off - n * amp
    yy = np.mgrid[0:H, 0:W][0]
    mask = yy >= top[None, :]
    lay = np.zeros((H, W, 4), np.uint8)
    velo = (col * 0.82 + cielo * 0.18)
    lay[..., :3] = _rampa_v(mask, top, velo, col, H, W).astype(np.uint8)
    lay[..., 3] = np.where(mask, 255, 0)
    cresta = mask & ~np.roll(mask, 1, axis=0)
    lay[cresta, :3] = np.clip(velo * 1.12 + 10, 0, 255).astype(np.uint8)
    return lay


def _citta(W, H, base_y, col, accesi, faro, rs):
    """Sagoma di una citta' di mare: case con i tetti, torri, una cupola e il faro con la lanterna; finestre accese
    secondo l'ora (accesi 0..1). Le case coprono [0, W) di fila: il bordo destro combacia col sinistro."""
    lay = np.zeros((H, W, 4), np.uint8)
    scuro = (col * 0.82).astype(np.uint8)
    chiaro = np.clip(col * 1.18 + 8, 0, 255).astype(np.uint8)
    lume, lume2 = _c("#feae34").astype(np.uint8), _c("#fee761").astype(np.uint8)
    x = 0
    k = 0
    while x < W:
        w = int(rs.randint(9, 22))
        if W - (x + w) < 9:                                       # l'ultima casa finisce esattamente sul bordo
            w = W - x
        h = int(rs.randint(10, 26))
        tipo = rs.rand()
        y0 = int(base_y) - h
        tinta = col.astype(np.uint8) if k % 2 == 0 else scuro
        x1 = min(W, x + w)
        lay[y0:, x:x1, :3] = tinta; lay[y0:, x:x1, 3] = 255
        if tipo < 0.55:                                           # tetto a capanna: largo in basso, stretto in cima
            for r in range(w // 2):
                yr = y0 - 1 - r
                xa, xb = x + r, min(W, x + w - r)
                if xa < xb:
                    lay[yr, xa:xb, :3] = tinta; lay[yr, xa:xb, 3] = 255
                    lay[yr, xa, :3] = chiaro
        elif tipo < 0.7:                                          # torre col tetto a punta
            tx = x + w // 2
            th = int(rs.randint(18, 30))
            lay[y0 - th:y0, tx - 3:tx + 3, :3] = tinta; lay[y0 - th:y0, tx - 3:tx + 3, 3] = 255
            for r in range(4):
                lay[y0 - th - 6 + r * 2:y0 - th - 4 + r * 2, max(0, tx - r):tx + r, :3] = tinta
                lay[y0 - th - 6 + r * 2:y0 - th - 4 + r * 2, max(0, tx - r):tx + r, 3] = 255
            lay[y0 - th:y0, tx - 3, :3] = chiaro
        elif tipo < 0.78:                                         # cupola
            cx, r0 = x + w / 2, w / 2
            yy, xx = np.mgrid[0:H, 0:W]
            dome = ((xx + 0.5 - cx) ** 2 + ((yy + 0.5 - y0) * 1.3) ** 2 <= r0 * r0) & (yy < y0)
            lay[dome, :3] = tinta; lay[dome, 3] = 255
        lay[y0, x:x1, :3] = chiaro                               # filo di luce sul colmo
        for wy in range(y0 + 3, int(base_y) - 1, 4):              # finestre
            for wx in range(x + 2, x1 - 2, 3):
                if rs.rand() < accesi:
                    lay[wy:wy + 2, wx, :3] = lume if rs.rand() < 0.7 else lume2
        x += w
        k += 1
    # il faro: torre stretta e alta con la lanterna, sempre accesa
    fx, fh = faro, 58
    yb = int(base_y)
    lay[yb - fh:yb, fx - 3:fx + 3, :3] = col.astype(np.uint8); lay[yb - fh:yb, fx - 3:fx + 3, 3] = 255
    for fy in range(yb - fh + 6, yb, 10):
        lay[fy:fy + 4, fx - 3:fx + 3, :3] = chiaro
    lay[yb - fh - 5:yb - fh, fx - 2:fx + 2, :3] = lume2; lay[yb - fh - 5:yb - fh, fx - 2:fx + 2, 3] = 255
    lay[yb - fh - 7:yb - fh - 5, fx - 3:fx + 3, :3] = scuro; lay[yb - fh - 7:yb - fh - 5, fx - 3:fx + 3, 3] = 255
    return lay


def strati(W=640, H=360, time="day", seed=3, horizon=0.62, faro=70):
    """I 6 strati del parallasse (sky, clouds, far, mid, near, fg), ognuno periodico in x tranne il cielo (fermo).
    near e' la sagoma della citta' di mare col faro; fg e' il primo piano di alberi."""
    P = TIMES[time]
    rs = np.random.RandomState(seed)
    yy, xx = np.mgrid[0:H, 0:W]
    out = {}
    # cielo con sole o luna dove il libro non copre (a destra, o in alto a sinistra la luna)
    y = np.linspace(0, 1, H)[:, None] * np.ones((1, W))
    sky = _dither_bands(np.clip(y / horizon, 0, 1), [_c(c) for c in P["sky"]], W, H).astype(np.uint8)
    L = np.dstack([sky, np.full((H, W), 255, np.uint8)])
    if P["stars"]:
        for _ in range(int(W * H * 0.0012 * P["stars"])):
            sx, sy = rs.randint(W), rs.randint(int(H * horizon * 0.75))
            L[sy, sx, :3] = (255, 255, 255) if rs.rand() < .6 else (150, 170, 230)
    sx = W * (0.12 if time == "night" else 0.88)
    sy = H * (0.14 if time in ("day", "night") else P["sun_y"])
    d = np.hypot(xx - sx, yy - sy)
    glow = np.clip(1 - d / (H * (0.16 if time == "day" else 0.26)), 0, 1)
    L[..., :3] = np.where((glow > 0.45 + (BAYER[yy % 4, xx % 4] - .5) * .25)[..., None], _c(P["glow"]).astype(np.uint8),
                          L[..., :3])
    L[..., :3] = np.where((d < H * 0.06)[..., None], _c(P["sun"]).astype(np.uint8), L[..., :3])
    if time == "night":
        cres = (np.hypot(xx - (sx + H * 0.025), yy - (sy - H * 0.01)) < H * 0.05) & (d < H * 0.06)
        L[..., :3] = np.where(cres[..., None], _c(P["sky"][1]).astype(np.uint8), L[..., :3])
    out["sky"] = L
    # nuvole periodiche
    from .world import fbm
    # nuvole allungate: rumore piu' largo che alto, che si spegne verso l'alto e verso le montagne
    base = fbm(2 * W // 4, H, 16, 3, seed + 1) * 0.8 + fbm(2 * W // 4, H, 6, 3, seed + 2) * 0.3
    xs = (np.arange(2 * W) + 0.5) / 4 - 0.5                      # stirato 4 volte in orizzontale, senza scalini
    largo = np.stack([np.interp(xs, np.arange(base.shape[1]), r, period=base.shape[1]) for r in base])
    nn = _periodico(largo)
    nn = (nn - nn.min()) / (nn.max() - nn.min() + 1e-9)
    y0c, y1c = H * 0.02, H * horizon * 0.55
    env = np.clip(np.sin(np.pi * (yy - y0c) / (y1c - y0c)), 0, 1) * ((yy > y0c) & (yy < y1c))
    m = nn * (0.55 + 0.45 * env) * (env > 0) > 0.62
    cl = np.zeros((H, W, 4), np.uint8)
    c0, c1, c2 = (_c(c).astype(np.uint8) for c in P["cloud"])
    cl[m, :3] = c0; cl[m, 3] = 255
    cl[m & np.roll(m, 3, axis=0) & ~np.roll(m, 7, axis=0), :3] = c1
    cl[m & ~np.roll(m, 3, axis=0), :3] = c2
    out["clouds"] = cl
    base_y = H * horizon
    cielo = _c(P["sky"][-1])
    out["far"] = _rilievo(W, H, base_y, H * 0.24, 160, H * 0.05, _c(P["far"]), cielo, seed + 3, aguzzo=True)
    out["mid"] = _rilievo(W, H, base_y, H * 0.1, 90, -H * 0.01, _c(P["mid"]), cielo, seed + 4)
    accesi = {"dawn": 0.08, "day": 0.0, "dusk": 0.3, "night": 0.45}[time]
    out["near"] = _citta(W, H, base_y + H * 0.06, _c(P["citta"]), accesi, faro, rs)
    # primo piano: il mare davanti alla citta' (onde periodiche) e una riva bassa con l'erba in fondo
    fg = np.zeros((H, W, 4), np.uint8)
    mare_y = int(base_y + H * 0.06) + 1
    acqua = [_c("#124e89"), _c("#2a7fbf"), _c("#6cbfe0")] if time == "day" else [_c(P["near"]), _c(P["mid"]), _c(P["far"])]
    t = np.clip((yy - mare_y) / (H - mare_y), 0, 1)
    onde = _dither_bands(1 - t, acqua, W, H).astype(np.uint8)
    sotto = yy >= mare_y
    fg[sotto, :3] = onde[sotto]; fg[sotto, 3] = 255
    lampi = sotto & (((yy * 7 + (np.sin(xx * 2 * np.pi / W * 8 + yy) * 3).astype(int)) % 11) == 0) \
        & (((xx + yy * 5) % 23) < 6)
    fg[lampi, :3] = np.clip(acqua[-1] * 1.15 + 20, 0, 255).astype(np.uint8)
    riva_y = int(H * 0.92) + (2 * np.sin(xx[0] * 2 * np.pi / W * 3) + 2 * np.sin(xx[0] * 2 * np.pi / W * 7)).astype(int)
    fgc = _c(P["fg"])
    riva = yy >= riva_y[None, :]
    fg[riva, :3] = fgc.astype(np.uint8); fg[riva, 3] = 255
    luce = np.clip(fgc * 1.3 + 12, 0, 255).astype(np.uint8)
    fg[riva & ~np.roll(riva, 1, axis=0), :3] = luce
    for _ in range(90):                                           # ciuffi d'erba sulla riva
        tx = rs.randint(0, W); th = rs.randint(2, 6)
        for r in range(th):
            yr = riva_y[tx] - 1 - r
            fg[yr, tx, :3] = fgc.astype(np.uint8) if r < th - 1 else luce; fg[yr, tx, 3] = 255
    out["fg"] = fg
    return out
