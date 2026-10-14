"""Terreni: texture seamless, tile di transizione "dual grid" e atlanti.

Idea (dual grid + livelli): ogni terreno ha un livello di priorita'. Per ogni terreno t (dal basso
all'alto) si disegna un layer il cui tile, centrato sui VERTICI tra 4 celle, dipende da quali delle 4
celle hanno livello >= t (maschera a 4 bit = 16 tile). Basta quindi 1 atlante di 16 tile per terreno,
senza autotile 47, e qualunque coppia di terreni si fonde in modo pulito.
"""
import math
import zlib

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
    "water": dict(ramp=["blue", "#1fb5d6", "#1fb5d6", "cyan"], period=3, dither=0.5, detail="waves", rim="foam", level=1, anim=4),
    "sand": dict(ramp=["tan", "cream", "cream", "skin_l"], period=4, dither=0.5, detail="dots", rim="dark", rimc="orange_d", level=2),
    "mud": dict(ramp=["brown_dd", "brown_d", "brown_d", "brown"], period=3, dither=0.6, detail="puddles", rim="dark", level=3),
    "grass": dict(ramp=["green_d", "green_m", "green_m", "green"], period=4, dither=0.5, detail="tufts", rim="dark", rimc="green_d", level=4,
                  contrast=0.45),
    "dry_grass": dict(ramp=["brown_d", "#8a7a38", "#b3a050", "#cdbb64"], period=4, dither=0.5, detail="tufts", rim="dark", rimc="brown", level=5, contrast=0.45),
    "forest": dict(ramp=["teal_d", "green_d", "green_d", "green_m"], period=4, dither=0.5, detail="leaves", rim="dark", rimc="teal_d", level=6, contrast=0.45),
    "dirt": dict(ramp=["brown_d", "brown", "brown", "orange_d"], period=4, dither=0.6, detail="pebbles", rim="dark", level=7, contrast=0.45),
    "path": dict(ramp=["brown_d", "brown", "#c9946a", "#dcb68a"], period=5, dither=0.6, detail="pebbles", rim="dark", rimc="brown_d", level=8, contrast=0.45),
    "stone": dict(ramp=["slate_d", "slate", "slate", "grey"], period=3, dither=0.5, detail="cobbles", rim="cliff", level=9),
    "snow": dict(ramp=["grey", "grey_l", "white", "white", "white"], period=4, dither=0.4, detail="dunes", rim="light", rimc="grey", level=10,
                 contrast=0.2),
    # --- Mirwada (US-8B11b). Livelli con la virgola: si inseriscono tra quelli sopra senza rinumerarli ---
    "ciottoli_spiaggia": dict(ramp=["tan", "grey", "grey_l", "cream"], period=4, dither=0.4, detail="cobbles", cells=16,
                              rim="dark", rimc="tan", level=2.5),
    "filari": dict(ramp=["brown_dd", "brown_d", "brown_d", "brown"], period=4, dither=0.5, detail="rows", rim="dark",
                   rimc="brown_dd", level=5.5, contrast=0.3, accent=["green_m", "green"]),
    "lastricato_antico": dict(ramp=["green_d", "grey", "grey_l", "cream"], period=4, dither=0.4, detail="cobbles", cells=5,
                              rim="dark", rimc="green_d", level=8.2),
    "ghiaia": dict(ramp=["slate", "grey", "grey_l", "white"], period=4, dither=0.6, detail="pebbles", rim="dark", rimc="grey",
                   level=8.3, contrast=0.15),
    "marmo": dict(ramp=["grey", "grey_l", "white", "white"], period=4, dither=0.3, detail="slabs", slab=(2, 2), rim="dark",
                  rimc="slate", level=8.4, contrast=0.4),
    "ciottoli_scuri": dict(ramp=["brown_dd", "slate_d", "slate", "grey"], period=4, dither=0.4, detail="cobbles", cells=12,
                           rim="dark", rimc="brown_dd", level=8.6),
    "lastre_chiare": dict(ramp=["grey", "grey_l", "cream", "cream"], period=4, dither=0.4, detail="slabs", slab=(2, 2),
                          rim="dark", rimc="slate", level=8.8, contrast=0.5),
    "molo_pietra": dict(ramp=["navy", "slate_d", "slate", "grey"], period=4, dither=0.4, detail="slabs", rim="cliff",
                        rimc="navy", level=9.2, contrast=0.5),
    "pontile_legno": dict(ramp=["brown_dd", "brown_d", "brown", "tan"], period=4, dither=0.3, detail="planks", rim="dark",
                          rimc="brown_dd", level=9.4),
    # --- Archivio, Frontiera, isole (US-8B11d). Pastelli della Frontiera = colori extra (Endesga non ha il lilla) ---
    "nebbia": dict(ramp=["#b8b0c8", "#cfc8db", "#e0dbe8", "#f0edf4"], period=3, dither=0.6, detail="fog", rim="light",
                   rimc="#f0edf4", level=0.2, contrast=0.6, anim=4),
    "sabbia_bianca": dict(ramp=["cream", "white", "white", "white"], period=4, dither=0.5, detail="dots", rim="dark",
                          rimc="tan", level=2.2, contrast=0.3),
    "erba_lilla": dict(ramp=["#9a7fb0", "#b9a3cc", "#cdb8dc", "#e2d4ec"], period=4, dither=0.5, detail="tufts", rim="dark",
                       rimc="#9a7fb0", level=4.4, contrast=0.4),
    "cenere": dict(ramp=["ink", "slate_d", "slate", "grey"], period=4, dither=0.5, detail="dots", rim="dark", rimc="ink",
                   level=7.6, contrast=0.3),
    "parquet": dict(ramp=["brown_dd", "brown_d", "brown_d", "brown"], period=4, dither=0.3, detail="herringbone", listello=4,
                    rim="dark", rimc="brown_dd", level=8.1),
    "lamiera": dict(ramp=["slate_d", "slate", "grey", "grey_l"], period=4, dither=0.3, detail="plates", rim="dark",
                    rimc="navy", level=8.15, contrast=0.4),
    "terra_rosa": dict(ramp=["#c99a9a", "#ddb3b0", "#e8c6c1", "#f3dcd6"], period=4, dither=0.6, detail="pebbles", rim="dark",
                       rimc="#c99a9a", level=8.25, contrast=0.3),
    "lastre_rovine": dict(ramp=["teal_d", "grey", "grey_l", "cream"], period=4, dither=0.4, detail="slabs", slab=(2, 2),
                          rim="cliff", rimc="teal_d", level=8.9, contrast=0.5),
    "roccia_lavica": dict(ramp=["ink", "brown_dd", "brown_dd", "slate_d"], period=4, dither=0.4, detail="embers", rim="cliff",
                          rimc="ink", level=9.1, accent=["orange", "amber"]),
    "ghiaccio": dict(ramp=["slate", "grey", "grey_l", "grey_l"], period=4, dither=0.4, detail="embers", cells=4, spessore=0.6,
                     rim="light", rimc="white", level=9.6, contrast=0.4, accent=["white", "white"]),
    # --- Sottosuolo (US-8B13c): la roccia delle pareti di gallerie e caverne ---
    "roccia_viva": dict(ramp=["ink", "navy", "slate_d", "slate_d"], period=4, dither=0.4, detail="cobbles", cells=6,
                        rim="cliff", rimc="ink", level=9.8, contrast=0.5),
    # --- Marche e Valle (US-8B11c) ---
    "palude": dict(ramp=["brown_dd", "teal_d", "green_d", "brown_d"], period=3, dither=0.6, detail="puddles", rim="dark",
                   rimc="brown_dd", level=3.2, contrast=0.25, accent=["teal_d", "green_m"]),
    "erba_argentata": dict(ramp=["slate", "grey", "grey_l", "white"], period=4, dither=0.5, detail="tufts", rim="dark",
                           rimc="slate", level=4.2, contrast=0.4),
    "erica_secca": dict(ramp=["brown_dd", "brown_d", "brown_d", "purple"], period=4, dither=0.5, detail="tufts", rim="dark",
                        rimc="brown_dd", level=5.2, contrast=0.4),
    "felci": dict(ramp=["teal_d", "green_d", "green_m", "green"], period=4, dither=0.5, detail="leaves", rim="dark",
                  rimc="teal_d", level=6.2, contrast=0.4),
    "radici_muschio": dict(ramp=["teal_d", "green_d", "green_m", "green_m"], period=4, dither=0.5, detail="embers", cells=3, spessore=0.7,
                           rim="dark", rimc="teal_d", level=6.4, contrast=0.4, accent=["brown_dd", "brown_d"]),
    "muschio_scuro": dict(ramp=["ink", "teal_d", "teal_d", "green_d"], period=4, dither=0.5, detail="dots", rim="dark",
                          rimc="ink", level=6.6, contrast=0.4),
    "pietrisco": dict(ramp=["brown_dd", "brown_d", "brown_d", "skin_m"], period=4, dither=0.6, detail="pebbles", rim="dark",
                      rimc="brown_dd", level=7.2, contrast=0.15),
    "terra_bruciata": dict(ramp=["ink", "brown_dd", "brown_dd", "slate_d"], period=4, dither=0.5, detail="dots", rim="dark",
                           rimc="ink", level=7.4, contrast=0.4),
    # vista dall'alto: lastre di roccia spaccate (le strisce sono della PARETE, forge3d/pareti.py: se la cima avesse
    # le strisce non si capirebbe dove finisce il pianoro e comincia la parete)
    "arenaria": dict(ramp=["brown_dd", "brown_d", "brown", "rust"], period=4, dither=0.4, detail="cobbles", cells=5,
                     rim="dark", rimc="brown_dd", level=9.0, contrast=0.6),
}
ORDER = sorted(TERRAINS, key=lambda k: TERRAINS[k]["level"])


def _voronoi(rng, n, S):
    """Celle di Voronoi periodiche: (id della cella, distanza dal bordo) per ogni pixel."""
    y, x = np.mgrid[0:S, 0:S]
    pts = rng.rand(n, 2) * S
    dist = np.full((S, S), 1e9); dist2 = np.full((S, S), 1e9)
    ids = np.zeros((S, S), int)
    for i, (cx, cy) in enumerate(pts):
        for ox in (-S, 0, S):
            for oy in (-S, 0, S):
                dd = (x - cx - ox) ** 2 + (y - cy - oy) ** 2
                m = dd < dist
                dist2 = np.where(m, dist, np.minimum(dist2, dd))
                ids = np.where(m, i, ids); dist = np.where(m, dd, dist)
    return ids, np.sqrt(dist2) - np.sqrt(dist)


def _accent(d, i=0):
    """Colore d'accento del terreno (piante dei filari, brace delle crepe...)."""
    acc = d.get("accent", ["white"])
    return _rgb(acc[min(i, len(acc) - 1)])


def terrain_texture(name, S=TILE, seed=7, frame=0, nframes=4):
    d = TERRAINS[name]
    rs = zlib.crc32(name.encode()) % 1000 + seed   # hash() cambia a ogni avvio: non riproducibile
    base = pnoise(S, d["period"], rs, 3)
    if d["detail"] == "fog":
        passo = frame * S // nframes
        base = 0.6 * np.roll(base, passo, 1) + 0.4 * np.roll(pnoise(S, d["period"] + 1, rs + 5, 2), -passo, 0)
    base = (base - base.min()) / (np.ptp(base) + 1e-6)
    base = 0.5 + (base - 0.5) * d.get("contrast", 1.0)    # <1: macchie piu' tenui, la ripetizione non si vede
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
            pozza, luce = (_accent(d, 0), _accent(d, 1)) if "accent" in d else (_rgb("blue_d"), _rgb("blue"))
            for dx in range(-2, 3):
                img[py % S, (px + dx) % S] = pozza
            img[(py + 1) % S, (px - 1) % S] = luce; img[(py + 1) % S, px % S] = pozza
    elif detail == "cobbles":
        ids, bordo = _voronoi(rng, d.get("cells", 7), S)
        edge = bordo < 1.8 * S / 32
        shade = (ids % 3)
        img = np.array([_rgb(ramp[1 + int(s) % 3 if 1 + int(s) % 3 < n else n - 1]) for s in shade.ravel()]).reshape(S, S, 3)
        img[edge] = _rgb(ramp[0])
    elif detail == "sparkle":
        for _ in range(S * S // 90):
            put(rng.randint(S), rng.randint(S), 0)
    elif detail == "slabs":
        # lastre di pietra: file sfalsate, ogni lastra un tono, fuga scura, spigolo in luce in alto a sinistra
        lw, lh = S // d.get("slab", (2, 4))[0], S // d.get("slab", (2, 4))[1]   # (2,4) blocchi, (2,2) lastre quadrate
        riga = y // lh
        col = (x + (riga % 2) * (lw // 2)) // lw
        tono = (riga * 7 + col * 5 + (riga * col) % 3 + rng.randint(3)) % (n - 1) + 1   # ogni lastra il suo tono
        img = np.array([_rgb(c) for c in ramp])[np.minimum(tono, n - 1)]
        xr = (x + (riga % 2) * (lw // 2)) % lw
        img[(y % lh == 0) | (xr == 0)] = _rgb(ramp[0])
        img[((y % lh == 1) | (xr == 1)) & ~((y % lh == 0) | (xr == 0))] = _rgb(ramp[-1])
        for _ in range(S // 8):                                     # crepe
            px, py = rng.randint(S), rng.randint(S)
            for k in range(rng.randint(2, 4)):
                put(px + k, py + (k // 2), 0)
    elif detail == "rows":
        # filari: solchi orizzontali, piante in fila sulla cresta (accento)
        passo = max(4, S // 4)
        img[y % passo == 0] = _rgb(ramp[0])
        img[y % passo == 1] = _rgb(ramp[1])
        g = max(1, S // 32)                                        # piantine piu' grandi a 64 px
        for r in range(0, S, passo):
            for px in range(rng.randint(3), S, max(3, S // 6)):
                py = (r + passo // 2) % S
                for oy in range(-g, g + 1):
                    for ox in range(-g, g + 2):
                        if abs(oy) + abs(ox - 0.5) <= g + 0.5:
                            img[(py + oy) % S, (px + ox) % S] = _accent(d, 0)
                img[(py - g) % S, px % S] = _accent(d, 1)
    elif detail == "planks":
        # assi di legno orizzontali con giunte sfalsate e fessure scure (pontili, pavimenti)
        ah = max(4, S // 8)
        asse = y // ah
        img = np.array([_rgb(c) for c in ramp])[1 + (asse * 5 + rng.randint(2)) % (n - 1)]
        img[y % ah == 0] = _rgb(ramp[0])
        for a in range(S // ah):
            gx = (a * 11 * S // 32 + rng.randint(S // 4)) % S
            img[a * ah:(a + 1) * ah, gx] = _rgb(ramp[0])
            for _ in range(2):                                    # venature
                put(rng.randint(S), a * ah + 1 + rng.randint(ah - 1), 1)
    elif detail == "herringbone":
        # parquet a spina di pesce: listelli a 45 gradi alternati per colonna
        lw = max(4, S // d.get("listello", 8))                    # listelli per tile: meno = piu' larghi
        colonna = x // lw
        u = (y + np.where(colonna % 2 == 0, x % lw, lw - 1 - x % lw)) // lw
        img = np.array([_rgb(c) for c in ramp])[1 + (u + colonna) % (n - 1)]
        img[(y + np.where(colonna % 2 == 0, x % lw, lw - 1 - x % lw)) % lw == 0] = _rgb(ramp[0])
        img[x % lw == 0] = _rgb(ramp[0])
    elif detail == "strata":
        # strati di roccia: bande ondulate (periodiche) alternate, con fessure
        k = 2 * math.pi / S
        onda = (S / 16) * np.sin(x * k * 2 + rng.rand() * 6) + (S / 32) * np.sin(x * k * 3)
        h = S / d.get("bande", 6)                                  # bande per tile: meno bande = piu' spesse
        banda = ((y + onda) // h).astype(int)
        img = np.array([_rgb(c) for c in ramp])[1 + banda % (n - 1)]
        img[((y + onda) % h) < 1] = _rgb(ramp[0])
        for _ in range(S // 6):
            put(rng.randint(S), rng.randint(S), n - 1)
    elif detail == "plates":
        # lamiera rivettata a riquadri; un riquadro su due e' una grata (buchi scuri)
        pw = S // 2
        img[(x % pw == 0) | (y % pw == 0)] = _rgb(ramp[0])
        img[((x % pw == 1) | (y % pw == 1)) & (x % pw != 0) & (y % pw != 0)] = _rgb(ramp[-1])
        grata = ((x // pw + y // pw) % 2 == 1) & (x % pw > 2) & (y % pw > 2) & (x % pw < pw - 2) & (y % pw < pw - 2)
        img[grata & ((x % 3 == 0) | (y % 3 == 0))] = _rgb(ramp[1])
        img[grata & (x % 3 != 0) & (y % 3 != 0)] = _rgb("ink")
        for cx in (3, pw - 3):
            for cy in (3, pw - 3):
                for ox in (0, pw):
                    for oy in (0, pw):
                        if not ((ox // pw + oy // pw) % 2):
                            put(cx + ox, cy + oy, n - 1); put(cx + ox + 1, cy + oy + 1, 0)
    elif detail == "embers":
        # roccia lavica: crepe (bordi di Voronoi) incandescenti, piu' calde al centro della crepa
        ids, bordo = _voronoi(rng, d.get("cells", 6), S)
        sp = d.get("spessore", 1.5)                                # radici sottili, crepe di lava larghe
        img[bordo < sp * S / 32] = _accent(d, 0)
        img[bordo < sp * 0.4 * S / 32] = _accent(d, 1)
    elif detail == "dunes":
        # dune di vento: creste ondulate diagonali, chiare al vento e ombra sottile sotto
        k = 2 * math.pi / S
        w = np.sin(k * (2 * x + y) + 0.7 * np.sin(k * 2 * y))
        spezza = pnoise(S, 3, rs + 1, 2) > 0.45                  # creste interrotte, non righe continue
        cresta = (w > 0.97) & spezza
        img[cresta] = _rgb(ramp[1])                                # una linea sottile grigio chiaro
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


def compose_ground(levels, atlases=None, S=TILE, frame=0, seed=3, strati=None, duri=None):
    """levels: array HxW di nomi/indici (indice in ORDER). Ritorna immagine RGBA (H*S, W*S).
    strati: HxW di interi (es. l'altezza). Dove due caselle vicine stanno su strati diversi (un dislivello)
    i terreni NON si sfumano: ogni quarto di casella che tocca un altro strato prende il terreno pieno della
    sua casella, con un bordo netto (lo copre il contorno della parete o della cima).
    duri: HxW booleani, la casella ha un bordo di roccia (materiale da parete). Il bordo netto c'e' solo se la
    piu' alta delle due caselle e' dura: una spiaggia sul mare (piu' basso ma senza parete) resta sfumata."""
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
    out = big[h2:h2 + H * S, h2:h2 + W * S].copy()
    if strati is not None:
        st = np.pad(np.asarray(strati), 1, mode="edge")
        du = np.pad(np.ones((H, W), bool) if duri is None else np.asarray(duri, bool), 1, mode="edge")

        def netto(a, b):
            if st[a] == st[b]:
                return False
            return bool(du[a] if st[a] > st[b] else du[b])

        for i in range(H):
            for j in range(W):
                c = (i + 1, j + 1)
                for qy in (0, 1):
                    for qx in (0, 1):
                        dy, dx = (-1, 1)[qy], (-1, 1)[qx]
                        if not (netto(c, (i + 1 + dy, j + 1)) or netto(c, (i + 1, j + 1 + dx))
                                or netto(c, (i + 1 + dy, j + 1 + dx))):
                            continue
                        at = atlases[ORDER[lv[i, j]]]
                        fr = frame % (at.shape[0] // S)
                        pieno = at[fr * S:(fr + 1) * S, 15 * S:16 * S]    # tile pieno (maschera 15)
                        y0, x0 = i * S + qy * h2, j * S + qx * h2
                        # il tile pieno e' allineato ai vertici: nel ritaglio e' spostato di mezzo tile
                        out[y0:y0 + h2, x0:x0 + h2] = pieno[(qy * h2 + h2) % S:(qy * h2 + h2) % S + h2,
                                                              (qx * h2 + h2) % S:(qx * h2 + h2) % S + h2]
    return out
