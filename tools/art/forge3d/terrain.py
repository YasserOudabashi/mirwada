"""Terreni: texture seamless, tile di transizione "dual grid" e atlanti.

Idea (dual grid + livelli): ogni terreno ha un livello di priorita'. Per ogni terreno t (dal basso
all'alto) si disegna un layer il cui tile, centrato sui VERTICI tra 4 celle, dipende da quali delle 4
celle hanno livello >= t (maschera a 4 bit = 16 tile). Basta quindi 1 atlante di 16 tile per terreno,
senza autotile 47, e qualunque coppia di terreni si fonde in modo pulito.
"""
import math
import zlib

import numpy as np

from . import tema
from .materials import E32, hex_to_rgb

TILE = 32


def _rgb(c):
    return np.array(hex_to_rgb(tema.colore(E32.get(c, c))), np.uint8)


def rampa(d):
    """La rampa del terreno nel tema corrente: nel cupo vince la sua "ramp_cupo", se c'e' (umore della regione)."""
    return d.get("ramp_cupo", d["ramp"]) if tema.TEMA == "cupo" else d["ramp"]


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


# dettagli che si possono disegnare su una texture grande (macro): niente righe o griglie legate al tile
MACRO_OK = ("waves", "tufts", "leaves", "dots", "pebbles", "puddles", "cobbles", "sparkle", "embers", "dunes", "fog",
            "roots")

# nome: (ramp scuro->chiaro, periodo rumore, contrasto, dither, dettaglio, livello)
TERRAINS = {
    "deep_water": dict(onde=420, ramp=["navy", "blue_d", "blue_d", "blue"], period=3, dither=0.5, detail="waves", rim=None, level=0, anim=4),
    "water": dict(onde=220, ramp=["blue", "#1fb5d6", "#1fb5d6", "cyan"], period=3, dither=0.5, detail="waves", rim="foam", level=1, anim=4,
                  cresta="white"),
    # acque del sottosuolo (revisione arte 3.10): torbida nelle fogne, scura con riflessi nelle grotte
    "acqua_fogna": dict(onde=320, ramp=["brown_dd", "teal_d", "teal_d", "slate_d"], period=3, dither=0.5, detail="waves", rim=None,
                        level=0.5, anim=4, cresta="grey"),
    "acqua_grotta": dict(onde=360, ramp=["navy", "blue_d", "blue_d", "blue"], period=3, dither=0.5, detail="waves", rim=None,
                         level=0.6, anim=4, cresta="grey"),
    "sand": dict(ramp=["tan", "cream", "cream", "skin_l"], period=4, dither=0.5, detail="dots", rim="dark", rimc="orange_d", level=2),
    "mud": dict(ramp=["brown_dd", "brown_d", "brown_d", "brown"], period=3, dither=0.6, detail="puddles", rim="dark", level=3),
    "grass": dict(fiori=["white", "yellow", "pink"], ramp=["green_d", "green_m", "green_m", "green"], period=4, dither=0.5, detail="tufts", rim="dark", rimc="green_d", level=4,
                  contrast=0.45),
    "dry_grass": dict(ramp=["brown_d", "#8a7a38", "#b3a050", "#cdbb64"], period=4, dither=0.5, detail="tufts", rim="dark", rimc="brown", level=5, contrast=0.45),
    "forest": dict(ramp=["teal_d", "green_d", "green_d", "green_m"], period=4, dither=0.5, detail="leaves", rim="dark", rimc="teal_d", level=6, contrast=0.45),
    "dirt": dict(ramp=["brown_d", "brown", "brown", "orange_d"], period=4, dither=0.6, detail="pebbles", rim="dark", level=7, contrast=0.45),
    "path": dict(ramp=["brown_d", "brown", "#c9946a", "#dcb68a"], period=5, dither=0.6, detail="pebbles", rim="dark", rimc="brown_d", level=8, contrast=0.45),
    "stone": dict(bordo="dritto", ramp=["slate_d", "slate", "slate", "grey"], period=3, dither=0.5, detail="cobbles", rim="cliff", level=9),
    "snow": dict(macro=8, ramp=["grey", "grey_l", "white", "white", "white"], period=2, dither=0.4, detail="dunes", rim="light",
                 rimc="grey", level=10, contrast=0.32),
    # --- Mirwada (US-8B11b). Livelli con la virgola: si inseriscono tra quelli sopra senza rinumerarli ---
    "ciottoli_spiaggia": dict(ramp=["tan", "grey", "grey_l", "cream"], period=4, dither=0.4, detail="cobbles", cells=16,
                              rim="dark", rimc="tan", level=2.5),
    "filari": dict(ramp=["brown_dd", "brown_d", "brown_d", "brown"], period=4, dither=0.5, detail="rows", rim="dark",
                   rimc="brown_dd", level=5.5, contrast=0.3, accent=["green_m", "green"]),
    "lastricato_antico": dict(ramp=["green_d", "grey", "grey_l", "cream"], period=4, dither=0.4, detail="cobbles", cells=5,
                              rim="dark", rimc="green_d", level=8.2),
    "ghiaia": dict(ramp=["slate", "grey", "grey_l", "white"], period=4, dither=0.6, detail="pebbles", rim="dark", rimc="grey",
                   level=8.3, contrast=0.15),
    "marmo": dict(bordo="dritto", ramp=["grey", "grey_l", "white", "white"], period=4, dither=0.3, detail="slabs", slab=(2, 2), rim="dark",
                  rimc="slate", level=8.4, contrast=0.4, varianti=8, fuga="grey"),
    # selciato di Mirwada: grigio caldo e poco contrastato (revisione 1.1: il blu-ardesia era il colore del cappotto
    # di Enel, che ci spariva sopra). Grigi caldi = colori extra della rampa
    "ciottoli_scuri": dict(bordo="dritto", ramp=["#5e4b4a", "#8a7b72", "#978a80", "#a4988e"], period=4, dither=0.4,
                           detail="cobbles", cells=12, rim="dark", rimc="#5e4b4a", level=8.6),
    "lastre_chiare": dict(bordo="dritto", ramp=["grey", "grey_l", "cream", "cream"], period=4, dither=0.4, detail="slabs", slab=(2, 2),
                          rim="dark", rimc="slate", level=8.8, contrast=0.5, varianti=8, fuga="grey"),
    "molo_pietra": dict(bordo="dritto", ramp=["navy", "slate_d", "slate", "grey"], period=4, dither=0.4, detail="slabs", rim="cliff",
                        rimc="navy", level=9.2, contrast=0.5),
    "pontile_legno": dict(bordo="dritto", ramp=["brown_dd", "brown_d", "brown", "tan"], period=4, dither=0.3, detail="planks", rim="dark",
                          rimc="brown_dd", level=9.4),
    # --- Archivio, Frontiera, isole (US-8B11d). Pastelli della Frontiera = colori extra (Endesga non ha il lilla) ---
    # vuoto di nebbia attorno alla Frontiera (decisione 2026-10-20): grigio freddo, piu' scuro della terra lilla e due
    # livelli sotto; non si calpesta (water_mask). Il livello piu' basso: tutto il resto gli si disegna sopra
    "vuoto": dict(macro=8, ramp=["slate", "#76839c", "grey", "#a9b3c6"], period=3, dither=0.6, detail="fog", rim=None,
                  level=-1, contrast=0.35, anim=4),
    "nebbia": dict(macro=8, ramp=["#b8b0c8", "#cfc8db", "#e0dbe8", "#f0edf4"], period=3, dither=0.6, detail="fog", rim="light",
                   rimc="#f0edf4", level=0.2, contrast=0.6, anim=4),
    # sabbia corallina: crema e avorio caldi, bianco solo nei riflessi (prima 3 bianchi su 4: sembrava neve)
    "sabbia_bianca": dict(ramp=["tan", "cream", "#f3e7cf", "white"], period=4, dither=0.5, detail="dots", rim="dark",
                          rimc="tan", level=2.2, contrast=0.45),
    "erba_lilla": dict(macro=8, ramp=["#9a7fb0", "#b9a3cc", "#cdb8dc", "#e2d4ec"], period=4, dither=0.5, detail="tufts", rim="dark",
                       rimc="#9a7fb0", level=4.4, contrast=0.4),
    "cenere": dict(ramp=["ink", "slate_d", "slate", "grey"], period=4, dither=0.5, detail="dots", rim="dark", rimc="ink",
                   level=7.6, contrast=0.3),
    "parquet": dict(bordo="dritto", ramp=["brown_dd", "brown_d", "brown_d", "brown"], period=4, dither=0.3, detail="herringbone", listello=4,
                    rim="dark", rimc="brown_dd", level=8.1),
    "lamiera": dict(bordo="dritto", ramp=["slate_d", "slate", "grey", "grey_l"], period=4, dither=0.3, detail="plates", rim="dark",
                    rimc="navy", level=8.15, contrast=0.4),
    "terra_rosa": dict(ramp=["#c99a9a", "#ddb3b0", "#e8c6c1", "#f3dcd6"], period=4, dither=0.6, detail="pebbles", rim="dark",
                       rimc="#c99a9a", level=8.25, contrast=0.3),
    "lastre_rovine": dict(ramp=["teal_d", "grey", "grey_l", "cream"], period=4, dither=0.4, detail="slabs", slab=(2, 2),
                          rim="cliff", rimc="teal_d", level=8.9, contrast=0.5, varianti=8, erba=0.35, fuga="slate",
                          accent=["green_d", "green_m"], mancanti=0.08, buca=["brown_dd", "brown_d"]),
    "roccia_lavica": dict(ramp=["ink", "brown_dd", "brown_dd", "slate_d"], period=4, dither=0.4, detail="embers", rim="cliff",
                          rimc="ink", level=9.1, accent=["orange", "amber"]),
    "ghiaccio": dict(ramp=["slate", "grey", "grey_l", "grey_l"], period=4, dither=0.4, detail="embers", cells=4, spessore=0.6,
                     rim="light", rimc="white", level=9.6, contrast=0.4, accent=["white", "white"]),
    # --- Sottosuolo (US-8B13c): la roccia delle pareti di gallerie e caverne ---
    "roccia_viva": dict(macro=8, fuga_px=1.1, ramp=["ink", "navy", "slate_d", "slate_d"], period=4, dither=0.4,
                        detail="cobbles", cells=3,
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
    "radici_muschio": dict(macro=8, ramp=["teal_d", "green_d", "green_m", "green_m"], period=4, dither=0.5, detail="roots",
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
for _d in TERRAINS.values():                              # texture grande 4x4 tile dove il dettaglio lo consente:
    _d.setdefault("macro", 4 if _d["detail"] in MACRO_OK and "varianti" not in _d else 1)   # niente griglia a vista
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


def _lastre(d, S, rs, base):
    """Lastre con le fughe sul bordo della casella (le varianti si accostano senza tagliare una lastra). Ogni
    variante divide la casella a modo suo (1 lastra, 2 orizzontali, 2 verticali, 4): il pavimento non fa griglia.
    Tono di ogni lastra a caso (quasi sempre quello centrale), ombreggiato dal rumore; fuga di un tono medio,
    spigolo in luce in alto a sinistra, spigoli scheggiati, crepe. Campi della riga: fuga (colore), erba (frazione
    di fughe con l'erba, colori in accent), mancanti (lastre sparite: buca di terra coi colori in buca)."""
    ramp = rampa(d); n = len(ramp)
    rng = np.random.RandomState(rs)
    nx_, ny_ = [(1, 1), (2, 1), (1, 2), (2, 2)][rng.choice(4, p=[0.35, 0.2, 0.2, 0.25])]
    lw, lh = S // nx_, S // ny_
    y, x = np.mgrid[0:S, 0:S]
    riga, col, yr, xr = y // lh, x // lw, y % lh, x % lw
    pesi = np.array([2, 6, 2][:n - 1], float)
    toni = rng.choice(np.arange(1, n), size=(ny_, nx_), p=pesi / pesi.sum())
    tono = toni[riga, col] + np.where(base > 0.72, 1, 0) - np.where(base < 0.28, 1, 0)
    img = np.array([_rgb(c) for c in ramp])[np.clip(tono, 1, n - 1)]
    fuga = (yr == 0) | (xr == 0)
    img[((yr == 1) | (xr == 1)) & (tono < n - 1)] = _rgb(ramp[-1])
    s1 = max(1, S // 32)
    scheggia = _rgb(d.get("fuga", ramp[0]))
    for r in range(ny_):
        for c in range(nx_):
            y0, x0 = r * lh, c * lw
            if rng.rand() < d.get("mancanti", 0) * nx_ * ny_ / 2:   # lastra mancante: buca di terra con sassolini
                buca = d.get("buca", ["brown_dd", "brown_d"])
                img[y0 + 1:y0 + lh, x0 + 1:x0 + lw] = _rgb(buca[-1])
                for _ in range(lw * lh // 10):
                    img[y0 + 1 + rng.randint(lh - 1), x0 + 1 + rng.randint(lw - 1)] = _rgb(buca[0])
                continue
            for _ in range(rng.randint(0, 3)):            # spigolo scheggiato
                cy, cx = y0 + 1 + (lh - 2) * rng.randint(2), x0 + 1 + (lw - 2) * rng.randint(2)
                img[max(y0, cy - s1):cy + s1, max(x0, cx - s1):cx + s1] = scheggia
            if rng.rand() < 0.4:                          # crepa: una linea spezzata dentro la lastra
                py, px = y0 + 2 + rng.randint(lh - 4), x0 + 2 + rng.randint(max(1, lw // 2))
                for _ in range(rng.randint(3, 3 + lw // 3)):
                    img[py, px] = _rgb(ramp[0])
                    py = int(np.clip(py + rng.randint(-1, 2), y0 + 2, y0 + lh - 2))
                    px = int(np.clip(px + 1, x0 + 2, x0 + lw - 2))
    img[fuga] = scheggia
    if d.get("erba"):                                     # erba nelle fughe, a ciuffi (rumore), anche oltre la fuga
        ciuffi = pnoise(S, 4, rs + 3, 2) > 1 - d["erba"]
        verde = ciuffi & (fuga | ((yr == 1) & (rng.rand(S, S) < 0.5)) | ((xr == 1) & (rng.rand(S, S) < 0.5)))
        acc = d.get("accent", ["green_d", "green_m"])
        img[verde] = _rgb(acc[0])
        img[verde & (rng.rand(S, S) < 0.4)] = _rgb(acc[-1])
    return img


_macro_cache = {}


def n_varianti(d):
    """Righe di varianti nell'atlante: `varianti` (scelte a caso) oppure macro x macro (pezzi di una texture grande)."""
    return d.get("varianti", d.get("macro", 1) ** 2)


def terrain_texture(name, S=TILE, seed=7, frame=0, nframes=4, variante=0):
    """Texture di un tile. Con `macro` = M nella riga del terreno la texture e' grande M x M tile, continua e
    periodica: la variante v e' il suo pezzo (riga v // M, colonna v % M), scelto dalla posizione nel mondo."""
    d = TERRAINS[name]
    M = d.get("macro", 1)
    if M == 1:
        return _texture(name, S, S, seed, frame, nframes, variante)
    key = (name, S, seed, frame, nframes, tema.TEMA)
    if key not in _macro_cache:
        _macro_cache[key] = _texture(name, S, S * M, seed, frame, nframes, 0)
    r, c = divmod(variante, M)
    return _macro_cache[key][r * S:(r + 1) * S, c * S:(c + 1) * S].copy()


def _texture(name, S, Z, seed, frame, nframes, variante):
    """S = lato del tile (misura dei dettagli), Z = lato della texture (S, o S x macro)."""
    d = TERRAINS[name]
    assert Z == S or d["detail"] in MACRO_OK, f"{name}: macro non supportato per {d['detail']}"
    q = (Z // S) ** 2                                     # quanti tile nella texture: i conteggi scalano con l'area
    rs = zlib.crc32(name.encode()) % 1000 + seed   # hash() cambia a ogni avvio: non riproducibile
    base = pnoise(Z, d["period"] * Z // S, rs, 3)
    if d["detail"] == "fog":
        passo = frame * S // nframes
        base = 0.6 * np.roll(base, passo, 1) + 0.4 * np.roll(pnoise(Z, (d["period"] + 1) * Z // S, rs + 5, 2), -passo, 0)
    base = (base - base.min()) / (np.ptp(base) + 1e-6)
    base = 0.5 + (base - 0.5) * d.get("contrast", 1.0)    # <1: macchie piu' tenui, la ripetizione non si vede
    ramp = rampa(d)
    detail = d["detail"]
    y, x = np.mgrid[0:Z, 0:Z]
    rng = np.random.RandomState(rs)
    if detail == "waves":
        # acqua calma: macchie tenui e poche creste sparse che compaiono e scorrono (2 frame su 4), non un tappeto
        img, idx = _quant(np.clip(0.36 + 0.26 * base, 0, 1), ramp, d["dither"], Z)
        s1 = max(1, S // 32)
        for _ in range(Z * Z // d.get("onde", 260)):
            px, py, fase, lung = rng.randint(Z), rng.randint(Z), rng.randint(nframes), rng.randint(2, 5) * s1
            t = (frame - fase) % nframes
            if t >= 2:
                continue
            for i_ in range(lung):
                img[(py - i_ // 2) % Z, (px + i_ + t * s1) % Z] = _rgb(d.get("cresta", "cyan") if t == 0 else ramp[-1])
        return img
    img, idx = _quant(base, ramp, d["dither"], Z)
    n = len(ramp)
    def put(px, py, c):
        img[py % Z, px % Z] = _rgb(ramp[c])
    if detail == "tufts":
        for _ in range(Z * Z // 22):
            px, py = rng.randint(Z), rng.randint(Z)
            put(px, py, 0); put(px, py - 1, n - 1) if rng.rand() < .7 else None
        fiori = d.get("fiori", [])                         # fiorellini di 3 pixel, rari (prima puntini singoli)
        for _ in range(Z * Z // 700 if fiori else 0):
            px, py, c = rng.randint(Z), rng.randint(Z), _rgb(fiori[rng.randint(len(fiori))])
            img[py % Z, px % Z] = img[py % Z, (px + 1) % Z] = img[(py - 1) % Z, px % Z] = c
            img[(py + 1) % Z, px % Z] = _rgb(ramp[0])
    elif detail == "leaves":
        for _ in range(Z * Z // 30):
            px, py = rng.randint(Z), rng.randint(Z)
            put(px, py, n - 1); put(px + 1, py, n - 2)
        for _ in range(Z * Z // 80):
            px, py = rng.randint(Z), rng.randint(Z)
            img[py, px] = _rgb(["orange_d", "amber", "rust"][rng.randint(3)])
    elif detail == "dots":
        for _ in range(Z * Z // 18):
            put(rng.randint(Z), rng.randint(Z), rng.choice([0, n - 1]))
    elif detail == "pebbles":
        for _ in range(Z * Z // 70):
            px, py = rng.randint(Z), rng.randint(Z)
            put(px, py, n - 1); put(px + 1, py, n - 2); put(px, py + 1, 0)
    elif detail == "puddles":
        for _ in range(3 * q):
            px, py = rng.randint(Z), rng.randint(Z)
            pozza, luce = (_accent(d, 0), _accent(d, 1)) if "accent" in d else (_rgb("blue_d"), _rgb("blue"))
            for dx in range(-2, 3 + rng.randint(3)):              # pozze di lunghezza diversa
                img[py % Z, (px + dx) % Z] = pozza
            img[(py + 1) % Z, (px - 1) % Z] = luce; img[(py + 1) % Z, px % Z] = pozza
    elif detail == "cobbles":
        ids, bordo = _voronoi(rng, d.get("cells", 7) * q, Z)
        edge = bordo < d.get("fuga_px", 1.8) * S / 32             # spessore della fuga tra i ciottoli
        shade = (ids % 3)
        img = np.array([_rgb(ramp[1 + int(s) % 3 if 1 + int(s) % 3 < n else n - 1]) for s in shade.ravel()]).reshape(Z, Z, 3)
        img[edge] = _rgb(ramp[0])
    elif detail == "sparkle":
        for _ in range(Z * Z // 90):
            put(rng.randint(Z), rng.randint(Z), 0)
    elif detail == "slabs":
        # lastre di pietra: file sfalsate, ogni lastra un tono, fuga scura, spigolo in luce in alto a sinistra
        nx_, ny_ = d.get("slab", (2, 4))
        lw, lh = S // nx_, S // ny_                                  # (2,4) blocchi, (2,2) lastre quadrate
        if d.get("varianti", 1) > 1:
            img = _lastre(d, S, rs + 7919 * variante, base)
        else:
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
        ids, bordo = _voronoi(rng, d.get("cells", 6) * q, Z)
        sp = d.get("spessore", 1.5)                                # radici sottili, crepe di lava larghe
        img[bordo < sp * S / 32] = _accent(d, 0)
        img[bordo < sp * 0.4 * S / 32] = _accent(d, 1)
    elif detail == "roots":
        # radici: linee sottili che serpeggiano (direzione che cambia piano), scure con la luce sopra; sparse
        for _ in range(Z * Z // 450):
            px, py, ang = float(rng.randint(Z)), float(rng.randint(Z)), rng.rand() * 2 * math.pi
            for _ in range(rng.randint(S // 3, S)):
                ang += rng.uniform(-0.35, 0.35)
                px, py = px + math.cos(ang), py + math.sin(ang) * 0.6
                img[int(py) % Z, int(px) % Z] = _accent(d, 0)
                img[(int(py) - 1) % Z, int(px) % Z] = _accent(d, 1) if rng.rand() < 0.6 else img[(int(py) - 1) % Z, int(px) % Z]
    elif detail == "dunes":
        # neve: increspature di vento corte e sparse (archetti grigio chiaro con il bianco sopra), non righe continue
        s1 = max(1, S // 32)
        for _ in range(Z * Z // 380):
            px, py, lung = rng.randint(Z), rng.randint(Z), rng.randint(4, 9) * s1
            for i_ in range(lung):
                yy_ = py - int(round(1.5 * s1 * math.sin(math.pi * i_ / lung)))   # arco
                img[yy_ % Z, (px + i_) % Z] = _rgb(ramp[1])
                img[(yy_ - 1) % Z, (px + i_) % Z] = _rgb(ramp[-1])
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


def masks_dritte(S=TILE):
    """16 maschere a quarti pieni: il bordo cade dritto sul lato della casella (cose costruite: lastre, moli...)."""
    yy, xx = np.mgrid[0:S, 0:S]
    alto, sin = yy < S // 2, xx < S // 2
    return [((m & 1) > 0) & alto & sin | ((m & 2) > 0) & alto & ~sin | ((m & 4) > 0) & ~alto & sin
            | ((m & 8) > 0) & ~alto & ~sin for m in range(16)]


def build_atlas(name, S=TILE, seed=3):
    """Atlante RGBA 16 tile in una riga (indice = maschera). Per i terreni animati: righe = frame.
    bordo="dritto" nella riga del terreno: bordi squadrati invece che sfumati (cose costruite dall'uomo)."""
    d = TERRAINS[name]
    masks = masks_dritte(S) if d.get("bordo") == "dritto" else layer_masks(S, seed)
    nfr, nva = d.get("anim", 1), n_varianti(d)
    atlas = np.zeros((S * nfr * nva, S * 16, 4), np.uint8)
    for v in range(nva):                                  # riga = variante * frame totali + frame
        for f in range(nfr):
            tex = terrain_texture(name, S, frame=f, nframes=nfr, variante=v)
            r0 = (v * nfr + f) * S
            for m, mask in enumerate(masks):
                img, inner = _rim(mask, tex, d["rim"], d.get("rimc"), rampa(d)) if d["rim"] else (tex, None)
                tile = np.zeros((S, S, 4), np.uint8)
                tile[..., :3] = img; tile[..., 3] = np.where(mask, 255, 0)
                atlas[r0:r0 + S, m * S:(m + 1) * S] = tile
    return atlas


def scelta(d, i, j):
    """Variante del tile al vertice (i, j) del mondo: pezzo della texture grande (macro) o hash (varianti)."""
    M = d.get("macro", 1)
    if M > 1:
        return (i % M) * M + (j % M)
    return variante(i, j, d.get("varianti", 1))


def variante(i, j, n):
    """Variante del tile al vertice (i, j) del mondo (righe, colonne): un hash fisso, uguale in ogni ritaglio.
    Il caricatore di Godot deve usare la stessa formula."""
    if n <= 1:
        return 0
    h = (i * 374761393 + j * 668265263) & 0xFFFFFFFF      # hash a 32 bit: mescola tutti i bit (niente motivi)
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return (h ^ (h >> 16)) % n


def compose_ground(levels, atlases=None, S=TILE, frame=0, seed=3, strati=None, duri=None, origine=(0, 0)):
    """levels: array HxW di nomi/indici (indice in ORDER). Ritorna immagine RGBA (H*S, W*S).
    strati: HxW di interi (es. l'altezza). Dove due caselle vicine stanno su strati diversi (un dislivello)
    i terreni NON si sfumano: ogni quarto di casella che tocca un altro strato prende il terreno pieno della
    sua casella, con un bordo netto (lo copre il contorno della parete o della cima).
    duri: HxW booleani, la casella ha un bordo di roccia (materiale da parete). Il bordo netto c'e' solo se la
    piu' alta delle due caselle e' dura: una spiaggia sul mare (piu' basso ma senza parete) resta sfumata.
    origine: (x0, y0) del ritaglio nel mondo, per scegliere le varianti dei tile come nella mappa intera."""
    lv = np.asarray(levels)
    H, W = lv.shape
    if atlases is None:
        atlases = {n: build_atlas(n, S, seed) for n in ORDER}
    pad = np.pad(lv, 1, mode="edge")
    canvas = np.zeros((H * S, W * S, 4), np.uint8)
    h2 = S // 2
    big = np.zeros(((H + 1) * S, (W + 1) * S, 4), np.uint8)       # canvas con mezzo tile di margine
    oy, ox = origine[1] - 1, origine[0] - 1                       # il vertice (i, j) del pad e' (y0-1+i, x0-1+j)
    for ti, name in enumerate(ORDER):
        at = atlases[name]
        nva = n_varianti(TERRAINS[name])
        nfr = at.shape[0] // S // nva
        fr = frame % nfr
        ge = pad >= ti
        # vertice (i,j) tra le celle pad[i..i+1, j..j+1]
        m = (ge[:-1, :-1] * 1 + ge[:-1, 1:] * 2 + ge[1:, :-1] * 4 + ge[1:, 1:] * 8)
        # un terreno si disegna solo dove almeno una delle 4 caselle e' davvero di quel terreno: altrimenti un
        # terreno intermedio (solo "di livello piu' basso") sbordava dagli angoli di un terreno a bordo dritto
        eq = pad == ti
        m = np.where(eq[:-1, :-1] | eq[:-1, 1:] | eq[1:, :-1] | eq[1:, 1:], m, 0)
        if ti == 0:
            m = np.full_like(m, 15)
        ys, xs = np.nonzero(m)
        for i, j in zip(ys, xs):
            mk = m[i, j]
            r0 = (scelta(TERRAINS[name], oy + i, ox + j) * nfr + fr) * S
            tile = at[r0:r0 + S, mk * S:(mk + 1) * S]
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
                        dq = TERRAINS[ORDER[lv[i, j]]]
                        nfr = at.shape[0] // S // n_varianti(dq)
                        r0 = (scelta(dq, oy + i + qy, ox + j + qx) * nfr + frame % nfr) * S
                        pieno = at[r0:r0 + S, 15 * S:16 * S]    # tile pieno (maschera 15) del vertice del quarto
                        y0, x0 = i * S + qy * h2, j * S + qx * h2
                        # il tile pieno e' allineato ai vertici: nel ritaglio e' spostato di mezzo tile
                        out[y0:y0 + h2, x0:x0 + h2] = pieno[(qy * h2 + h2) % S:(qy * h2 + h2) % S + h2,
                                                              (qx * h2 + h2) % S:(qx * h2 + h2) % S + h2]
    return out
