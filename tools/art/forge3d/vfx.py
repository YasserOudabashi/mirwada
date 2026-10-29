"""Effetti (VFX) procedurali: fendenti, impatti, proiettili, esplosioni, aure, fulmini, cerchi magici, fumo.

Ogni effetto e' una funzione che ritorna una lista di frame RGBA (numpy). Il colore viene da una
`palette` (rampa dal piu' scuro al piu' chiaro): per ricolorare un effetto per un altro Pathway basta
cambiare palette, la forma resta identica.
"""
import math

import numpy as np

from .materials import E32, hex_to_rgb

PALETTES = {
    "fire": ["#3e2731", "#a22633", "#e43b44", "#f77622", "#feae34", "#fee761", "#ffffff"],
    "ice": ["#262b44", "#124e89", "#0099db", "#2ce8f5", "#c0cbdc", "#ffffff"],
    "arcane": ["#262b44", "#68386c", "#b55088", "#f6757a", "#feae34", "#ffffff"],
    "shadow": ["#181425", "#262b44", "#3a4466", "#68386c", "#b55088", "#f6757a"],
    "holy": ["#733e39", "#feae34", "#fee761", "#ffffff", "#ffffff"],
    "poison": ["#193c3e", "#265c42", "#3e8948", "#63c74d", "#fee761", "#ffffff"],
    "steel": ["#3a4466", "#5a6988", "#8b9bb4", "#c0cbdc", "#ffffff"],
    "blood": ["#181425", "#3e2731", "#a22633", "#e43b44", "#f6757a", "#ffffff"],
    "lightning": ["#262b44", "#124e89", "#0099db", "#2ce8f5", "#fee761", "#ffffff"],
    "nature": ["#193c3e", "#265c42", "#3e8948", "#63c74d", "#fee761", "#ffffff"],
    "smoke": ["#262b44", "#3a4466", "#5a6988", "#8b9bb4", "#c0cbdc"],
}


def _ramp(p):
    p = PALETTES.get(p, p)
    return np.array([hex_to_rgb(E32.get(c, c)) for c in p], np.uint8)


def finish(I, palette, thr=0.10, outline=True, S=None):
    """Campo d'intensita' 0..1 -> sprite a rampa discreta, con contorno scuro da 1 px."""
    ramp = _ramp(palette)
    n = len(ramp)
    H, W = I.shape
    mask = I > thr
    idx = np.clip(((I - thr) / (1 - thr + 1e-9) * (n - 1)).round().astype(int) + 1, 1, n - 1)
    out = np.zeros((H, W, 4), np.uint8)
    out[mask, :3] = ramp[idx[mask]]
    out[mask, 3] = 255
    if outline:
        p = np.pad(mask, 1)
        ring = ~mask & (p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:])
        out[ring, :3] = ramp[0]; out[ring, 3] = 255
    return out


def _grid(S):
    y, x = np.mgrid[0:S, 0:S]
    return x + 0.5, y + 0.5


def _hash_noise(S, seed, scale=3):
    rng = np.random.RandomState(seed)
    g = rng.rand(scale + 2, scale + 2)
    ys = np.linspace(0, scale, S); xs = np.linspace(0, scale, S)
    y0 = ys.astype(int); x0 = xs.astype(int)
    fy = (ys - y0)[:, None]; fx = (xs - x0)[None, :]
    a = g[np.ix_(y0, x0)]; b = g[np.ix_(y0, x0 + 1)]; c = g[np.ix_(y0 + 1, x0)]; d = g[np.ix_(y0 + 1, x0 + 1)]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


DIR_ANGLE = {"right": 0.0, "down": 90.0, "left": 180.0, "up": -90.0}


def slash(S=64, frames=5, palette="steel", direction="right", sweep=150.0, radius=0.34, width=0.12, seed=1,
          trail=0.7, fade_from=0.6):
    """Fendente a mezzaluna che spazza davanti al personaggio."""
    x, y = _grid(S)
    cx = S * 0.5 + math.cos(math.radians(DIR_ANGLE[direction])) * S * 0.02
    cy = S * 0.55
    ang = np.degrees(np.arctan2(y - cy, x - cx)) - DIR_ANGLE[direction]
    ang = (ang + 180) % 360 - 180                          # -180..180 relativo alla direzione
    r = np.hypot(x - cx, y - cy)
    out = []
    for f in range(frames):
        t = (f + 0.5) / frames
        head = -sweep / 2 + sweep * min(1.0, t / 0.8) ** 0.8
        ln = sweep * trail * (1 - 0.5 * max(0, (t - fade_from) / (1 - fade_from + 1e-9)))
        d = head - ang                                      # >0 = dietro la testa del fendente
        in_arc = (d >= 0) & (d <= ln)
        k = np.clip(1 - d / ln, 0, 1)
        thick = width * S * (k ** 0.6) * (1.0 - 0.3 * max(0, (t - fade_from) / (1 - fade_from + 1e-9)))
        rr = radius * S * (1 + 0.10 * (1 - k))
        dist = np.abs(r - rr)
        I = np.where(in_arc & (dist < thick), (1 - dist / (thick + 1e-6)) * 0.6 + k * 0.55, 0.0)
        out.append(finish(np.clip(I, 0, 1), palette, 0.14))
    return out


def impact(S=48, frames=5, palette="steel", spikes=8, seed=2, size=0.62):
    """Scintilla da colpo: flash bianco, raggi che si allungano e si assottigliano."""
    rng = np.random.RandomState(seed)
    x, y = _grid(S)
    cx = cy = S / 2
    ang0 = rng.rand(spikes) * math.tau
    lens = 0.6 + 0.4 * rng.rand(spikes)
    out = []
    for f in range(frames):
        t = (f + 0.5) / frames
        I = np.zeros((S, S))
        r = np.hypot(x - cx, y - cy); th = np.arctan2(y - cy, x - cx)
        if f == 0:
            I = np.where(r < S * size * 0.5, 1.0, 0.0)
        else:
            reach = size * S * (0.35 + 0.65 * math.sqrt(t))
            w = (1 - t) ** 1.2
            for a, l in zip(ang0, lens):
                dth = np.abs(((th - a) + math.pi) % math.tau - math.pi)
                half = (0.05 + 0.26 * w * (1 - np.clip(r / (reach * l + 1e-6), 0, 1))) if True else 0
                inner = reach * l * 0.25 * t
                I = np.maximum(I, np.where((r > inner) & (r < reach * l) & (dth < half), 1 - r / (reach * l + 1e-6) * 0.7, 0))
            ring = np.abs(r - reach * 0.6) < max(1.0, 2.2 * (1 - t))
            I = np.maximum(I, np.where(ring, 0.5 * (1 - t), 0))
        out.append(finish(I, palette, 0.12))
    return out


def projectile(S=32, frames=4, palette="fire", direction="right", shape="orb", seed=3, trail=1.0):
    x, y = _grid(S)
    a = math.radians(DIR_ANGLE[direction])
    dx, dy = math.cos(a), math.sin(a)
    cx, cy = S / 2, S / 2
    u = (x - cx) * dx + (y - cy) * dy                       # lungo la direzione
    v = -(x - cx) * dy + (y - cy) * dx
    rng = np.random.RandomState(seed)
    out = []
    for f in range(frames):
        pulse = 1 + 0.12 * math.sin(f / frames * math.tau)
        R = S * 0.24 * pulse
        if shape == "orb":
            core = np.clip(1 - np.hypot(u, v) / R, 0, 1)
        else:   # freccia/lancia
            core = np.where((np.abs(v) < 1.2) & (np.abs(u) < S * 0.3), 1.0, 0.0)
            head = np.where((u > S * 0.22 - np.abs(v) * 1.2) & (u < S * 0.34) & (np.abs(v) < 3.2), 0.9, 0.0)
            core = np.maximum(core, head)
        tail = np.zeros((S, S))
        if trail:
            L = S * 0.42 * trail
            wob = 0.8 * np.sin(u * 0.5 + f * 1.7)
            w = np.clip(1 - (-u) / L, 0, 1) * R * 0.9
            tail = np.where((u < 0) & (u > -L) & (np.abs(v + wob) < w), (1 - (-u) / L) * 0.6 * (0.7 + 0.3 * rng.rand(S, S)), 0)
        out.append(finish(np.clip(np.maximum(core, tail), 0, 1), palette, 0.12))
    return out


def explosion(S=64, frames=8, palette="fire", seed=4, size=0.42, smoke=True):
    x, y = _grid(S)
    cx, cy = S / 2, S * 0.56
    nz = _hash_noise(S, seed, 4)
    nz2 = _hash_noise(S, seed + 1, 8)
    r = np.hypot(x - cx, (y - cy) * 1.15)
    out = []
    for f in range(frames):
        t = (f + 0.5) / frames
        R = S * size * (0.25 + 0.95 * math.sqrt(t))
        edge = R * (1 + 0.32 * (nz - 0.5) + 0.12 * (nz2 - 0.5))
        body = np.clip(1 - r / edge, 0, 1)
        heat = body * (1.25 - 1.1 * t)
        I = np.clip(heat, 0, 1)
        if t > 0.55 and smoke:
            sm = np.clip(1 - r / (edge * 1.1), 0, 1) * (1 - t) * 1.6
            I = np.clip(sm, 0, 0.55)
            out.append(finish(I, "smoke", 0.12)); continue
        out.append(finish(I, palette, 0.10))
    return out


def aura(S=48, frames=8, palette="holy", seed=5, particles=14, ring=True):
    """Anello a terra + particelle che salgono (buff, cura, rituale). Ciclo perfetto."""
    rng = np.random.RandomState(seed)
    x, y = _grid(S)
    cx, cy = S / 2, S * 0.78
    ph = rng.rand(particles); px = (rng.rand(particles) - .5) * S * 0.55; sp = 0.7 + rng.rand(particles) * 0.6
    out = []
    for f in range(frames):
        t = f / frames
        I = np.zeros((S, S))
        if ring:
            r = np.hypot((x - cx) / 1.0, (y - cy) / 0.38)
            R = S * (0.30 + 0.04 * math.sin(t * math.tau))
            I = np.maximum(I, np.where(np.abs(r - R) < 1.4, 0.7 + 0.3 * math.sin(t * math.tau + 1), 0))
        for i in range(particles):
            p = (ph[i] + t * sp[i]) % 1.0
            py = cy - p * S * 0.7; pxx = cx + px[i] + 2 * math.sin(p * 6 + i)
            size = 1.3 * (1 - p) + 0.4
            I = np.maximum(I, np.where(np.hypot(x - pxx, y - py) < size, 1 - p * 0.6, 0))
        out.append(finish(I, palette, 0.12))
    return out


def lightning(S=64, frames=4, palette="lightning", direction="right", seed=6, branches=2, length=0.9):
    a = math.radians(DIR_ANGLE[direction])
    out = []
    for f in range(frames):
        rng = np.random.RandomState(seed + f * 13)
        I = np.zeros((S, S))
        def bolt(x0, y0, ang, L, w, depth):
            nonlocal I
            n = max(4, int(L / 5)); px, py = x0, y0
            for i in range(n):
                ang += rng.uniform(-0.55, 0.55)
                step = L / n
                nx, ny = px + math.cos(ang) * step, py + math.sin(ang) * step
                for s in np.linspace(0, 1, 6):
                    qx, qy = px + (nx - px) * s, py + (ny - py) * s
                    xs, ys = _grid(S)
                    I = np.maximum(I, np.where(np.hypot(xs - qx, ys - qy) < w, 1.0, 0.0))
                    I = np.maximum(I, np.where(np.hypot(xs - qx, ys - qy) < w + 1.4, 0.45, 0.0))
                px, py = nx, ny
                if depth < branches and rng.rand() < 0.28:
                    bolt(px, py, ang + rng.choice([-1, 1]) * rng.uniform(0.5, 1.0), L * 0.4, max(0.6, w - 0.5), depth + 1)
        bolt(S * 0.08 if direction == "right" else S / 2, S / 2, a, S * length, 1.2, 0)
        out.append(finish(I * (0.8 if f % 2 else 1.0), palette, 0.2))
    return out


def circle(S=64, frames=8, palette="arcane", seed=7, runes=10, radius=0.4):
    """Cerchio magico a terra (ellisse prospettica) che ruota."""
    x, y = _grid(S)
    cx, cy = S / 2, S / 2
    sq = 0.52
    r = np.hypot(x - cx, (y - cy) / sq)
    th = np.arctan2((y - cy) / sq, x - cx)
    R = S * radius
    out = []
    for f in range(frames):
        t = f / frames * math.tau / runes
        I = np.zeros((S, S))
        I = np.maximum(I, np.where(np.abs(r - R) < 1.2, 0.85, 0))
        I = np.maximum(I, np.where(np.abs(r - R * 0.72) < 0.9, 0.55, 0))
        phase = (th * runes / math.tau + f / frames * 1.0) % 1.0
        I = np.maximum(I, np.where((r > R * 0.76) & (r < R * 0.95) & (phase < 0.22), 0.7, 0))
        # stella interna
        for k in range(5):
            a0 = k * 2 * math.pi * 2 / 5 + t * 2; a1 = (k + 1) * 2 * math.pi * 2 / 5 + t * 2
            for s in np.linspace(0, 1, 40):
                qx = cx + math.cos(a0 + (a1 - a0) * s) * 0 + (math.cos(a0) * (1 - s) + math.cos(a1) * s) * R * 0.7
                qy = cy + (math.sin(a0) * (1 - s) + math.sin(a1) * s) * R * 0.7 * sq
                I = np.maximum(I, np.where(np.hypot(x - qx, y - qy) < 0.9, 0.9, 0))
        out.append(finish(I * (0.85 + 0.15 * math.sin(f / frames * math.tau)), palette, 0.2))
    return out


def smoke_puff(S=48, frames=6, palette="smoke", seed=8):
    x, y = _grid(S)
    nz = _hash_noise(S, seed, 5)
    out = []
    for f in range(frames):
        t = (f + 0.5) / frames
        R = S * (0.14 + 0.22 * math.sqrt(t))
        cy = S * (0.6 - 0.22 * t)
        r = np.hypot(x - S / 2, (y - cy) * 1.1)
        edge = R * (1 + 0.5 * (nz - 0.5))
        I = np.clip(1 - r / edge, 0, 1) * (1 - t * 0.9) * 1.4
        out.append(finish(np.clip(I, 0, 0.9), palette, 0.14))
    return out


KINDS = {"slash": slash, "impact": impact, "projectile": projectile, "explosion": explosion, "aura": aura,
         "lightning": lightning, "circle": circle, "smoke": smoke_puff}


def make(kind, **kw):
    return KINDS[kind](**kw)


def strip(frames):
    return np.concatenate(frames, axis=1)
