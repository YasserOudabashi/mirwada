"""Panorami a strati (parallasse): cielo, sole/luna, nuvole, montagne lontane, colline, foresta/mare/deserto.

Restituisce i singoli strati RGBA (per il parallasse nel gioco) e anche l'immagine composta.
"""
import math

import numpy as np

from .materials import E32, hex_to_rgb
from .terrain import BAYER

TIMES = {
    "dawn": dict(sky=["#5a6988", "#b55088", "#f6757a", "#feae34", "#fee761"], far="#8b6f9a", mid="#6d4f7d", near="#3e3558",
                 fg="#262b44", sun="#fee761", sun_y=0.62, glow="#feae34", stars=0, cloud=("#f6757a", "#ffc08a", "#fee0b0")),
    "day": dict(sky=["#0099db", "#2cb0e8", "#5fc8f0", "#9fe3f8", "#d7f3fb"], far="#8aa2cc", mid="#4f7aa0", near="#2f6e58",
                fg="#265c42", sun="#fff3b0", sun_y=0.22, glow="#fee761", stars=0, cloud=("#c0cbdc", "#ffffff", "#ffffff")),
    "dusk": dict(sky=["#262b44", "#68386c", "#b55088", "#f77622", "#feae34"], far="#7a4a82", mid="#52325f", near="#2f2447",
                 fg="#181425", sun="#fee761", sun_y=0.66, glow="#f77622", stars=0.3, cloud=("#68386c", "#e4693f", "#feae34")),
    "night": dict(sky=["#0b0a18", "#181425", "#262b44", "#3a4466", "#3a4466"], far="#2a3254", mid="#1f2442", near="#161a30",
                  fg="#0f1020", sun="#e8eefc", sun_y=0.2, glow="#5a6988", stars=1.0, cloud=("#262b44", "#3a4466", "#5a6988")),
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
