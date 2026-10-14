"""Motore 3D -> pixel art.

Idea (la stessa di Dead Cells): invece di disegnare ogni frame a mano, si costruisce un modello
con forme semplici (ellissoidi, scatole, cilindri, coni), lo si anima con uno scheletro e lo si
"fotografa" con una camera ortografica inclinata. La luce e' discreta (3-5 toni per materiale,
presi dalla palette), i contorni sono di 1 px e i pixel isolati vengono ripuliti.
Vantaggi: 4 direzioni gratis, animazioni coerenti, qualsiasi risoluzione, varianti infinite.

Sistema di coordinate del modello (unita' = pixel a risoluzione base 32):
    x = destra dello schermo, y = verso il fondo (nord), z = su.
    Un personaggio guarda +y quando e' "up", -y quando e' "down" (verso la camera).
"""
import math

import numpy as np

from . import materials as M

INF = 1e18
T0 = 800.0                      # distanza di partenza dei raggi (davanti a tutta la scena)
LIGHT = (-0.55, -0.45, 0.70)    # luce da alto-sinistra, un po' davanti
MAXLV = 8                       # livelli massimi per materiale


def rotm(rx=0.0, ry=0.0, rz=0.0):
    """Matrice di rotazione da angoli in gradi: prima X, poi Y, poi Z."""
    ax, ay, az = (math.radians(a) for a in (rx, ry, rz))
    cx, sx, cy, sy, cz, sz = math.cos(ax), math.sin(ax), math.cos(ay), math.sin(ay), math.cos(az), math.sin(az)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rz @ Ry @ Rx


class Inst:
    """Una forma gia' posizionata nello spazio del modello."""
    __slots__ = ("shape", "c", "R", "size", "mat", "soft", "tex", "rad", "mi")

    def __init__(self, shape, c, R, size, mat, soft=0.0, tex=None):
        self.shape, self.c, self.R, self.size = shape, np.asarray(c, float), R, np.asarray(size, float)
        self.mat, self.soft, self.tex = mat, soft, tex
        s = self.size
        if shape == "ellipsoid":
            self.rad = float(s.max())
        elif shape == "box":
            self.rad = float(np.linalg.norm(s))
        else:  # cylinder / cone: size = (rx, ry, mezza altezza)
            self.rad = float(math.hypot(max(s[0], s[1]), s[2]))
        self.mi = 0


# ------------------------------------------------------------------------------------------------
# intersezioni raggio-forma (raggi paralleli: origini O (N,3), direzione d (3,))
# ------------------------------------------------------------------------------------------------

def _local(O, d, ins):
    return (O - ins.c) @ ins.R, d @ ins.R


def hit_ellipsoid(O, d, ins):
    o, dl = _local(O, d, ins)
    r = ins.size
    o = o / r
    dl = dl / r
    a = float(dl @ dl)
    b = o @ dl
    cc = (o * o).sum(1) - 1.0
    disc = b * b - a * cc
    ok = disc >= 0
    t = np.where(ok, (-b - np.sqrt(np.where(ok, disc, 0.0))) / a, INF)
    p = o + t[:, None] * dl
    nl = p / r
    nl /= np.maximum(np.linalg.norm(nl, axis=1, keepdims=True), 1e-9)
    return t, nl @ ins.R.T, p * r


def hit_box(O, d, ins):
    o, dl = _local(O, d, ins)
    h = ins.size
    inv = 1.0 / np.where(np.abs(dl) < 1e-12, 1e-12, dl)
    t1 = (-h - o) * inv
    t2 = (h - o) * inv
    tn = np.minimum(t1, t2)
    tf = np.maximum(t1, t2)
    tmin = tn.max(1)
    tmax = tf.min(1)
    ok = tmin <= tmax
    t = np.where(ok, tmin, INF)
    ax = tn.argmax(1)
    p = o + tmin[:, None] * dl
    if ins.soft > 0:
        # normali "arrotondate": simula gli spigoli smussati senza cambiare la forma
        q = np.clip(p / h, -1, 1)
        k = 14.0 - 12.0 * min(ins.soft, 1.0)
        nl = np.sign(q) * np.abs(q) ** k
        nl /= np.maximum(np.linalg.norm(nl, axis=1, keepdims=True), 1e-9)
    else:
        nl = np.zeros_like(o)
        nl[np.arange(len(o)), ax] = -np.sign(dl[ax])
    return t, nl @ ins.R.T, p


def hit_cyl(O, d, ins):
    o, dl = _local(O, d, ins)
    rx, ry, h = ins.size
    ox, oy, oz = o[:, 0] / rx, o[:, 1] / ry, o[:, 2]
    dx, dy, dz = dl[0] / rx, dl[1] / ry, dl[2]
    best = np.full(len(o), INF)
    nl = np.zeros_like(o)
    a = dx * dx + dy * dy
    if a > 1e-12:
        b = ox * dx + oy * dy
        cc = ox * ox + oy * oy - 1.0
        disc = b * b - a * cc
        ok = disc >= 0
        ts = (-b - np.sqrt(np.where(ok, disc, 0.0))) / a
        z = oz + ts * dz
        ok &= np.abs(z) <= h
        m = ok & (ts < best)
        best = np.where(m, ts, best)
        px, py = ox + ts * dx, oy + ts * dy
        side = np.stack([px / rx, py / ry, np.zeros_like(px)], 1)
        nl = np.where(m[:, None], side, nl)
    if abs(dz) > 1e-12:
        for sgn in (1.0, -1.0):
            tc = (sgn * h - oz) / dz
            px, py = ox + tc * dx, oy + tc * dy
            ok = (px * px + py * py <= 1.0) & (tc < best)
            best = np.where(ok, tc, best)
            cap = np.stack([px * ins.soft * 0.5 / rx, py * ins.soft * 0.5 / ry, np.full_like(px, sgn)], 1)
            nl = np.where(ok[:, None], cap, nl)
    nl /= np.maximum(np.linalg.norm(nl, axis=1, keepdims=True), 1e-9)
    p = o + np.where(best < INF, best, 0.0)[:, None] * dl
    return best, nl @ ins.R.T, p


def hit_cone(O, d, ins):
    """Cono con base a z=-h (raggio rx,ry) e apice a z=+h."""
    o, dl = _local(O, d, ins)
    rx, ry, h = ins.size
    k = 1.0 / (2.0 * h)
    ox, oy, oz = o[:, 0] / rx, o[:, 1] / ry, o[:, 2]
    dx, dy, dz = dl[0] / rx, dl[1] / ry, dl[2]
    # (ox+t dx)^2 + (oy+t dy)^2 = k^2 (h - oz - t dz)^2
    hz = h - oz
    a = dx * dx + dy * dy - k * k * dz * dz
    b = ox * dx + oy * dy + k * k * hz * dz
    cc = ox * ox + oy * oy - k * k * hz * hz
    best = np.full(len(o), INF)
    nl = np.zeros_like(o)
    if abs(a) > 1e-12:
        disc = b * b - a * cc
        ok0 = disc >= 0
        sq = np.sqrt(np.where(ok0, disc, 0.0))
        for ts in ((-b - sq) / a, (-b + sq) / a):
            z = oz + ts * dz
            ok = ok0 & (np.abs(z) <= h) & (ts < best)
            best = np.where(ok, ts, best)
            px, py = ox + ts * dx, oy + ts * dy
            n = np.stack([px / rx, py / ry, k * k * (h - z)], 1)
            nl = np.where(ok[:, None], n, nl)
    if abs(dz) > 1e-12:
        tc = (-h - oz) / dz
        px, py = ox + tc * dx, oy + tc * dy
        ok = (px * px + py * py <= 1.0) & (tc < best)
        best = np.where(ok, tc, best)
        nl = np.where(ok[:, None], np.array([0.0, 0.0, -1.0]), nl)
    nl /= np.maximum(np.linalg.norm(nl, axis=1, keepdims=True), 1e-9)
    p = o + np.where(best < INF, best, 0.0)[:, None] * dl
    return best, nl @ ins.R.T, p


HIT = {"ellipsoid": hit_ellipsoid, "box": hit_box, "cylinder": hit_cyl, "cone": hit_cone}


# ------------------------------------------------------------------------------------------------
# texture procedurali (in coordinate locali della forma: restano attaccate mentre si anima)
# ------------------------------------------------------------------------------------------------

def _hash3(i, j, k):
    v = np.sin(i * 12.9898 + j * 78.233 + k * 37.719) * 43758.5453
    return v - np.floor(v)


def _tex(tex, pl):
    kind = tex[0]
    if kind == "noise":
        s = tex[1]
        return (_hash3(np.floor(pl[:, 0] * s), np.floor(pl[:, 1] * s), np.floor(pl[:, 2] * s)) - 0.5) * 2 * tex[2]
    if kind == "stripes":
        ax = {"x": 0, "y": 1, "z": 2}[tex[1]]
        return (np.floor(pl[:, ax] / tex[2]) % 2 - 0.5) * 2 * tex[3]
    if kind == "checker":
        s = tex[1]
        c = (np.floor(pl[:, 0] * s) + np.floor(pl[:, 1] * s) + np.floor(pl[:, 2] * s)) % 2
        return (c - 0.5) * 2 * tex[2]
    return 0.0


# ------------------------------------------------------------------------------------------------
# rendering
# ------------------------------------------------------------------------------------------------

def render(insts, size=(32, 32), ppu=1.0, ss=4, pitch=32.0, foot=(0.5, 0.9), light=LIGHT,
           outline="selout", outline_color="#181425", inner_lines=True, inner_thr=1.0,
           cleanup=True, shadow=True, shadow_r=(0.34, 0.14), cover=0.4, levels_bias=0.0, shadow_off=(0.0, 0.0),
           shadow_a=105,
           ambient=0.12, mat_resolver=None):
    """Disegna le forme e ritorna un array RGBA uint8 (H, W, 4).

    size      (larghezza, altezza) in pixel del frame finale
    ppu       pixel per unita' del modello (1.0 a 32 px, 2.0 a 64 px, ...)
    ss        supercampionamento (4 = 16 campioni per pixel)
    pitch     inclinazione della camera in gradi (40 = vista 3/4 dall'alto, 90 = dall'alto, 0 = laterale)
    foot      posizione dei piedi nel frame (frazioni di larghezza e altezza)
    outline   "selout" (colorato sul lato in luce) | "dark" | "none"
    """
    W, H = size
    gw, gh = W * ss, H * ss
    S = ppu * ss
    phi = math.radians(pitch)
    sp, cp = math.sin(phi), math.cos(phi)
    d = np.array([0.0, cp, -sp])
    u = np.array([0.0, sp, cp])
    ex = np.array([1.0, 0.0, 0.0])
    L = np.asarray(light, float)
    L = L / np.linalg.norm(L)
    V = -d
    Hh = L + V
    Hh = Hh / np.linalg.norm(Hh)

    buf_t = np.full((gh, gw), INF)
    buf_n = np.zeros((gh, gw, 3))
    buf_p = np.zeros((gh, gw, 3))
    buf_m = np.full((gh, gw), -1, int)
    buf_i = np.full((gh, gw), -1, int)

    # materiali usati
    mats = []
    midx = {}
    for ins in insts:
        mat = M.get(ins.mat) if mat_resolver is None else mat_resolver(ins.mat)
        if mat.name not in midx:
            midx[mat.name] = len(mats)
            mats.append(mat)
        ins.mi = midx[mat.name]

    fx, fy = foot[0] * gw, foot[1] * gh
    for k, ins in enumerate(insts):
        cs = ins.c[0]
        cy = ins.c[1] * sp + ins.c[2] * cp
        rr = ins.rad + 0.5
        c0 = max(0, int(math.floor(fx + (cs - rr) * S)))
        c1 = min(gw, int(math.ceil(fx + (cs + rr) * S)))
        r0 = max(0, int(math.floor(fy - (cy + rr) * S)))
        r1 = min(gh, int(math.ceil(fy - (cy - rr) * S)))
        if c1 <= c0 or r1 <= r0:
            continue
        jj, ii = np.meshgrid(np.arange(c0, c1), np.arange(r0, r1))
        sx = (jj + 0.5 - fx) / S
        sy = (fy - (ii + 0.5)) / S
        O = (sx[..., None] * ex + sy[..., None] * u - T0 * d).reshape(-1, 3)
        with np.errstate(all="ignore"):
            t, n, pl = HIT[ins.shape](O, d, ins)
        shp = jj.shape
        t = t.reshape(shp)
        sub_t = buf_t[r0:r1, c0:c1]
        better = t < sub_t
        if not better.any():
            continue
        sub_t[better] = t[better]
        buf_n[r0:r1, c0:c1][better] = n.reshape(shp + (3,))[better]
        buf_p[r0:r1, c0:c1][better] = pl.reshape(shp + (3,))[better]
        buf_m[r0:r1, c0:c1][better] = ins.mi
        buf_i[r0:r1, c0:c1][better] = k

    # --- illuminazione a livelli discreti -------------------------------------------------------
    hit = buf_m >= 0
    labels = np.full((gh, gw), -1, int)
    nz = buf_n[..., 2]
    ndl = np.clip(buf_n @ L, 0, 1)
    ndh = np.clip(buf_n @ Hh, 0, 1)
    for mi, mat in enumerate(mats):
        sel = hit & (buf_m == mi)
        if not sel.any():
            continue
        nlev = len(mat.rgb)
        if mat.emissive:
            v = 0.55 + 0.45 * ndl[sel] + mat.bias
        else:
            v = ambient + (1 - ambient) * (0.35 * (nz[sel] * 0.5 + 0.5) + 0.65 * ndl[sel] * mat.contrast)
            v = v + mat.bias + levels_bias
        # texture e per-istanza
        tx = mat.tex
        if tx is not None or any(i.tex for i in insts if i.mi == mi):
            ids = buf_i[sel]
            pl = buf_p[sel]
            add = np.zeros(len(v))
            if tx is not None:
                add += _tex(tx, pl)
            for kk in np.unique(ids):
                it = insts[kk]
                if it.tex is not None:
                    m_ = ids == kk
                    add[m_] += _tex(it.tex, pl[m_])
            v = v + add
        idx = np.floor(np.clip(v, 0, 0.999) * nlev).astype(int)
        if mat.spec > 0:
            sp_ = ndh[sel] ** mat.shin
            idx = np.where(sp_ > (1.0 - 0.55 * mat.spec), nlev - 1, idx)
        labels[sel] = mi * MAXLV + idx

    # --- discesa a risoluzione finale: colore piu' frequente nel blocco ss x ss -------------------
    lab = labels.reshape(H, ss, W, ss).transpose(0, 2, 1, 3).reshape(H, W, ss * ss)
    tt = buf_t.reshape(H, ss, W, ss).transpose(0, 2, 1, 3).reshape(H, W, ss * ss)
    valid = lab >= 0
    cov = valid.sum(2) / float(ss * ss)
    best_c = np.zeros((H, W), int)
    best_l = np.full((H, W), -1, int)
    for lv in np.unique(lab[valid]):
        cnt = (lab == lv).sum(2)
        m = cnt > best_c
        best_c[m] = cnt[m]
        best_l[m] = lv
    fin = np.where(cov >= cover, best_l, -1)
    depth = np.where(valid, tt, 0).sum(2) / np.maximum(valid.sum(2), 1)

    if cleanup:
        fin = _cleanup(fin, mats)

    return _compose(fin, depth, mats, W, H, ppu, foot, outline, outline_color, inner_lines, inner_thr,
                    shadow, shadow_r, shadow_off, shadow_a)


def _neigh4(a, fill=-1):
    p = np.pad(a, 1, constant_values=fill)
    return p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]  # su, giu, sx, dx


def _cleanup(fin, mats):
    """Toglie i pixel isolati (rumore) mantenendo occhi e riflessi."""
    for _ in range(2):
        up, dn, lf, rt = _neigh4(fin)
        same = (up == fin) | (dn == fin) | (lf == fin) | (rt == fin)
        keepm = np.array([m.keep for m in mats] + [False])
        mi = np.where(fin >= 0, fin // MAXLV, len(mats))
        iso = (fin >= 0) & ~same & ~keepm[mi]
        if not iso.any():
            break
        out = fin.copy()
        for y, x in zip(*np.nonzero(iso)):
            cands = [v for v in (up[y, x], dn[y, x], lf[y, x], rt[y, x]) if v >= 0]
            if not cands:
                out[y, x] = -1
            else:
                vals, cnts = np.unique(cands, return_counts=True)
                out[y, x] = vals[cnts.argmax()]
        fin = out
    return fin


def _compose(fin, depth, mats, W, H, ppu, foot, outline, outline_color, inner_lines, inner_thr,
             shadow, shadow_r, shadow_off=(0.0, 0.0), shadow_a=105):
    rgba = np.zeros((H, W, 4), np.uint8)
    opaque = fin >= 0
    mi = np.where(opaque, fin // MAXLV, 0)
    lv = np.where(opaque, fin % MAXLV, 0)
    table = np.zeros((len(mats), MAXLV, 3), np.uint8)
    for i, m in enumerate(mats):
        for j in range(MAXLV):
            table[i, j] = m.rgb[min(j, len(m.rgb) - 1)]
    rgb = table[mi, lv]
    rgba[..., :3] = np.where(opaque[..., None], rgb, 0)
    rgba[..., 3] = np.where(opaque, 255, 0)

    # linee interne: il pixel piu' lontano al bordo di una sovrapposizione diventa scuro
    if inner_lines:
        dark = np.array([m.rgb[0] for m in mats], np.uint8)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nb_o = np.roll(opaque, (dy, dx), (0, 1))
            nb_d = np.roll(depth, (dy, dx), (0, 1))
            # il vicino (spostato) e' piu' vicino alla camera di inner_thr -> questo pixel e' "dietro"
            edge = opaque & nb_o & (depth - nb_d > inner_thr)
            if dy == -1: edge[0, :] = False
            if dy == 1: edge[-1, :] = False
            if dx == -1: edge[:, 0] = False
            if dx == 1: edge[:, -1] = False
            # solo i pixel con livello non gia' al minimo (evita righe doppie)
            sel = edge & (lv > 0)
            rgba[sel, :3] = dark[mi[sel]]

    if outline != "none":
        oc = np.array(M.hex_to_rgb(outline_color), np.uint8)
        occ = np.pad(opaque, 1)
        fp = np.pad(fin, 1, constant_values=-1)
        out_mask = np.zeros((H, W), bool)
        col = np.zeros((H, W, 3), np.uint8)
        # per ogni pixel trasparente: vicino opaco sopra/sotto/sx/dx
        for (dy, dx, lit) in ((-1, 0, False), (1, 0, True), (0, -1, False), (0, 1, True)):
            # vicino alla posizione (y+dy, x+dx); se opaco il pixel corrente e' bordo
            nb = occ[1 + dy:1 + dy + H, 1 + dx:1 + dx + W]
            m = (~opaque) & nb & ~out_mask
            if outline == "selout" and lit:
                # il pixel e' sopra/a sinistra della forma = lato in luce -> colore piu' caldo
                nl = fp[1 + dy:1 + dy + H, 1 + dx:1 + dx + W]
                nmi = np.where(nl >= 0, nl // MAXLV, 0)
                dk = np.array([mt.rgb[0] for mt in mats], np.uint8)[nmi]
                col[m] = dk[m]
            else:
                col[m] = oc
            out_mask |= m
        rgba[out_mask, :3] = col[out_mask]
        rgba[out_mask, 3] = 255

    if shadow:
        W_, H_ = W, H
        rx, ry = shadow_r[0] * W_, shadow_r[1] * W_
        cx, cy = foot[0] * W_ + shadow_off[0] * rx, foot[1] * H_ + shadow_off[1] * ry   # spostata via dalla luce
        yy, xx = np.mgrid[0:H_, 0:W_]
        e = ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0
        free = e & (rgba[..., 3] == 0)
        rgba[free] = (24, 20, 37, shadow_a)
    return rgba
