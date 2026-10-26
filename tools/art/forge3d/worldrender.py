"""Render del mondo: terreno a tile (dual grid) + oggetti ordinati per profondita' + overlay di preview."""
import math

import numpy as np
from PIL import Image

from . import tema
from .creatures import bush, ossa, rock, spada, stendardo, tree, trono
from .engine import render
from .terrain import ORDER, TILE, build_atlas, compose_ground

_cache = {}


def object_sprite(o, S=TILE):
    """RGBA + (ancora_x, ancora_y) dei piedi dell'oggetto, con lo stesso motore dei personaggi."""
    t = o["type"]
    key = (t, o.get("kind"), o.get("leaf"), o.get("seed"), o.get("mat"), o.get("berries"), o.get("size"),
           o.get("tipo"), o.get("w"), o.get("h"), S, tema.TEMA)
    if key in _cache:
        return _cache[key]
    k = S / 32.0
    if t == "tree":
        # alberi alti 2-3 tile (revisione 3.3): prima 1,4 tile, alti come il personaggio
        r = tree(o["kind"], seed=o["seed"], leaf=o["leaf"], size=o.get("size", 1.0) * 3.6 * k)
        cw, ch, foot = int(220 * k), int(260 * k), 0.9
    elif t == "bush":
        r = bush(o["seed"], o.get("mat", "leaf"), o.get("berries"), size=1.4 * k)
        cw, ch, foot = int(48 * k), int(48 * k), 0.8
    elif t == "rock":
        r = rock(o["seed"], o.get("mat", "stone"), size=1.5 * k, moss=o.get("moss", False))
        cw, ch, foot = int(48 * k), int(48 * k), 0.8
    elif t == "ossa":
        r = ossa(o["seed"], size=2.6 * k)
        cw, ch, foot = int(64 * k), int(48 * k), 0.75
    elif t == "trono":                                    # Trono del Gigante: alto ~9 tile, sulla vetta delle Marche
        r = trono(o["seed"], size=7.6 * k)
        cw, ch, foot = int(448 * k), int(512 * k), 0.84
    elif t == "spada":
        r = spada(o["seed"], size=2.2 * k)
        cw, ch, foot = int(48 * k), int(56 * k), 0.8
    elif t == "stendardo":
        r = stendardo(o["seed"], size=4.6 * k)
        cw, ch, foot = int(112 * k), int(136 * k), 0.85
    elif t == "scoglio":                                  # roccia nel mare: schiuma alla base, niente ombra a terra
        r = rock(o["seed"], "stone", size=2.6 * o.get("size", 1.0) * k, moss=False)
        cw, ch, foot = int(96 * k), int(72 * k), 0.75
    elif t == "edificio":                                 # US-8B18: copre il suo sedime (o["w"] x o["h"] caselle)
        from .creatures import TIPI_EDIFICIO, edificio
        r = edificio(o["tipo"], o["w"], o["h"], o.get("seed", 1), size=k)
        hw, pend = TIPI_EDIFICIO[o["tipo"]][2] + 4, TIPI_EDIFICIO[o["tipo"]][4]
        tetto = 56 if o["tipo"] == "torre" else (o["h"] * 32 / 0.53 * 0.75) * math.tan(math.radians(pend))
        alto = (o["h"] * 32 + (hw + tetto + 14) * 0.85) * k
        cw, ch = int((o["w"] * 32 + 16) * k), int(alto + 12 * k)
        foot = 1.0 - 6 * k / ch
    elif t == "arredo":                                   # US-8B18d: arredi degli interni (o["w"] x o["h"] caselle)
        from .arredi import ALTEZZA, arredo
        r = arredo(o["kind"], o["w"], o["h"], o.get("seed", 1), size=k)
        cw, ch = int((o["w"] * 32 + 16) * k), int((o["h"] * 32 + ALTEZZA.get(o["kind"], 32) + 12) * k)
        foot = 1.0 - 6 * k / ch
    elif t == "ingresso":                                 # sottosuolo: botola, scale, risalita (stesso punto sopra e sotto)
        from .creatures import ingresso
        r = ingresso(o.get("kind", "scale"), o.get("seed", 1), size=2.0 * k)
        cw, ch, foot = int(64 * k), int(72 * k), 0.78
    elif t == "bridge":
        from .rig import Rig
        r = Rig("bridge"); r.joint("b", "root", (0, 0, 0))
        r.part("b", "box", (S * 0.5, S * 0.5, 0.8), (0, 0, 0.6), mat="wood_light")
        for i in range(-2, 3):
            r.part("b", "box", (S * 0.5, 0.35, 0.9), (0, i * S * 0.18, 0.7), mat="wood")
        cw, ch, foot = S, S, 0.5
    else:
        return None
    # ombra in proporzione all'oggetto (chioma, tronco, sasso), chiara e spostata in basso a destra (luce in alto a
    # sinistra): revisione 3.12
    sr = {"dead": (0.06, 0.03), "palm": (0.12, 0.045), "cipresso": (0.06, 0.03), "felce": (0.13, 0.05),
          "gigante": (0.2, 0.07)}.get(o.get("kind"), (0.15, 0.055)) if t == "tree" else (0.3, 0.12)
    # inner_thr in proporzione alla grandezza del modello: con 1 unita' il bordo ripido di una sfera grande (chioma
    # x3,6) superava la soglia sulla stessa superficie e diventava una fascia scura di 5-8 px (contorno doppio)
    img = render(r.instances({}, 180), size=(cw, ch), ppu=1.0, foot=(0.5, foot), shadow=(t not in ("bridge", "scoglio", "edificio", "arredo") and not (t == "ingresso" and o.get("kind") != "risalita")),
                 shadow_r=sr, shadow_off=(0.25, 0.3), shadow_a=80, inner_thr=max(1.0, r.scale))
    if t == "scoglio":
        img = _sommerso(img, int(ch * foot) - max(2, int(3 * k)), o["seed"])
    _cache[key] = (img, cw // 2, int(ch * foot))
    return _cache[key]


def _sommerso(img, riga, seed):
    """La parte sotto `riga` va sott'acqua; lungo la linea dell'acqua schiuma a pezzetti (bianco e grigio chiaro)."""
    pieno = np.nonzero(img[:riga, :, 3].any(0))[0]
    img = img.copy()
    img[riga:] = 0
    if not len(pieno):
        return img
    rng = np.random.RandomState(seed)
    a, b = int(pieno.min()), int(pieno.max())
    for x in range(max(0, a - 3), min(img.shape[1], b + 4)):
        fuori = x < a or x > b
        for y, p in ((riga - 1, 0.35), (riga, 0.9 if not fuori else 0.55), (riga + 1, 0.3)):
            if 0 <= y < img.shape[0] and rng.rand() < p:
                img[y, x] = (255, 255, 255, 255) if rng.rand() < 0.7 else (192, 203, 220, 255)
    return img


def render_world(w, region=None, S=TILE, with_objects=True, frame=0, atlases=None, tint=None, sopra=None, strati=None,
                 duri=None):
    """region=(x0,y0,x1,y1) in celle. Ritorna un'immagine RGBA.
    sopra: strato RGBA grande come il terreno (es. pareti), disegnato sopra il terreno e sotto gli oggetti."""
    x0, y0, x1, y1 = region or (0, 0, w.W, w.H)
    g = compose_ground(w.ground[y0:y1, x0:x1], atlases=atlases, S=S, frame=frame,
                       strati=None if strati is None else strati[y0:y1, x0:x1],
                       duri=None if duri is None else duri[y0:y1, x0:x1], origine=(x0, y0))
    if sopra is not None:
        a = sopra[..., 3:4].astype(float) / 255.0
        g[..., :3] = (sopra[..., :3] * a + g[..., :3] * (1 - a)).astype(np.uint8)
    if not with_objects:
        return g
    pad = 4 * S
    canvas = np.zeros((g.shape[0] + pad * 2, g.shape[1] + pad * 2, 4), np.uint8)
    canvas[pad:-pad, pad:-pad] = g
    for o in w.objects:
        if not (x0 - 4 <= o["x"] < x1 + 4 and y0 - 4 <= o["y"] < y1 + 6):
            continue
        spr = object_sprite(o, S)
        if spr is None:
            continue
        img, ax, ay = spr
        px = int((o["x"] - x0) * S) - ax + pad
        py = int((o["y"] - y0) * S) - ay + pad
        h, wd = img.shape[:2]
        if py < 0 or px < 0 or py + h > canvas.shape[0] or px + wd > canvas.shape[1]:
            continue
        blk = canvas[py:py + h, px:px + wd]
        a = img[..., 3:4].astype(float) / 255.0
        old_a = blk[..., 3].copy()
        blk[..., :3] = (img[..., :3] * a + blk[..., :3] * (1 - a)).astype(np.uint8)
        blk[..., 3] = np.maximum(old_a, img[..., 3])
    out = canvas[pad:-pad, pad:-pad]
    if tint is not None:
        out = tint(out)
    return out


def save(img, path, scale=1):
    im = Image.fromarray(img)
    if scale != 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    im.save(path)
