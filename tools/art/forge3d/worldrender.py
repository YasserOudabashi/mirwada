"""Render del mondo: terreno a tile (dual grid) + oggetti ordinati per profondita' + overlay di preview."""
import numpy as np
from PIL import Image

from .creatures import bush, rock, tree
from .engine import render
from .terrain import ORDER, TILE, build_atlas, compose_ground

_cache = {}


def object_sprite(o, S=TILE):
    """RGBA + (ancora_x, ancora_y) dei piedi dell'oggetto, con lo stesso motore dei personaggi."""
    t = o["type"]
    key = (t, o.get("kind"), o.get("leaf"), o.get("seed"), o.get("mat"), o.get("berries"), o.get("size"), S)
    if key in _cache:
        return _cache[key]
    k = S / 32.0
    if t == "tree":
        r = tree(o["kind"], seed=o["seed"], leaf=o["leaf"], size=o.get("size", 1.0) * 1.9 * k)
        cw, ch, foot = int(120 * k), int(150 * k), 0.93
    elif t == "bush":
        r = bush(o["seed"], o.get("mat", "leaf"), o.get("berries"), size=1.4 * k)
        cw, ch, foot = int(48 * k), int(48 * k), 0.8
    elif t == "rock":
        r = rock(o["seed"], o.get("mat", "stone"), size=1.5 * k, moss=o.get("moss", False))
        cw, ch, foot = int(48 * k), int(48 * k), 0.8
    elif t == "bridge":
        from .rig import Rig
        r = Rig("bridge"); r.joint("b", "root", (0, 0, 0))
        r.part("b", "box", (S * 0.5, S * 0.5, 0.8), (0, 0, 0.6), mat="wood_light")
        for i in range(-2, 3):
            r.part("b", "box", (S * 0.5, 0.35, 0.9), (0, i * S * 0.18, 0.7), mat="wood")
        cw, ch, foot = S, S, 0.5
    else:
        return None
    img = render(r.instances({}, 180), size=(cw, ch), ppu=1.0, foot=(0.5, foot), shadow=(t != "bridge"))
    _cache[key] = (img, cw // 2, int(ch * foot))
    return _cache[key]


def render_world(w, region=None, S=TILE, with_objects=True, frame=0, atlases=None, tint=None, sopra=None, strati=None,
                 duri=None):
    """region=(x0,y0,x1,y1) in celle. Ritorna un'immagine RGBA.
    sopra: strato RGBA grande come il terreno (es. pareti), disegnato sopra il terreno e sotto gli oggetti."""
    x0, y0, x1, y1 = region or (0, 0, w.W, w.H)
    g = compose_ground(w.ground[y0:y1, x0:x1], atlases=atlases, S=S, frame=frame,
                       strati=None if strati is None else strati[y0:y1, x0:x1],
                       duri=None if duri is None else duri[y0:y1, x0:x1])
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
