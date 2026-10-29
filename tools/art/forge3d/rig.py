"""Scheletro, pose e animazione.

Un Rig e' un albero di giunti (joint) con delle forme (part) attaccate. Una *pose* e' un dizionario
    {"nome_giunto": (rx, ry, rz)}                      rotazione in gradi attorno al perno
    {"nome_giunto": (rx, ry, rz, tx, ty, tz)}          + spostamento nel sistema del genitore
Il giunto "root" sta ai piedi del personaggio; spostarlo con (0,0,0, dx,dy,dz) muove tutto il corpo.

Convenzioni (personaggio che guarda +y, z in alto):
    rx > 0  gli arti che pendono vanno AVANTI, la testa guarda in SU, il busto si piega INDIETRO
    ry > 0  gli arti che pendono vanno verso -x (dentro per il lato destro)
    rz > 0  rotazione antioraria vista dall'alto (il personaggio gira verso la sua sinistra)
"""
import math

import numpy as np

from .engine import Inst, rotm


class Joint:
    def __init__(self, name, parent, pivot, rest=(0, 0, 0)):
        self.name, self.parent, self.pivot = name, parent, np.asarray(pivot, float)
        self.rest = rest        # rotazione fissa di riposo (le pose si sommano a questa)


class Part:
    def __init__(self, joint, shape, size, pos, rot, mat, soft, tex, name):
        self.joint, self.shape, self.size = joint, shape, np.asarray(size, float)
        self.pos = np.asarray(pos, float)
        self.rot = rot            # tuple di gradi oppure matrice 3x3
        self.mat, self.soft, self.tex, self.name = mat, soft, tex, name


class Rig:
    def __init__(self, name="rig"):
        self.name = name
        self.joints = {"root": Joint("root", None, (0, 0, 0))}
        self.order = ["root"]
        self.parts = []
        self.scale = 1.0

    def joint(self, name, parent, pivot, rest=(0, 0, 0)):
        self.joints[name] = Joint(name, parent, pivot, rest)
        self.order.append(name)
        return name

    def part(self, joint, shape, size, pos=(0, 0, 0), rot=(0, 0, 0), mat="skin_light", soft=0.0, tex=None,
             name=None):
        """Aggiunge una forma. shape: ellipsoid (raggi), box (semi-lati), cylinder/cone (rx, ry, mezza altezza)."""
        p = Part(joint, shape, size, pos, rot, mat, soft, tex, name)
        self.parts.append(p)
        return p

    def group(self, joint, parts, pos=(0, 0, 0), rot=(0, 0, 0)):
        """Aggiunge piu' forme definite in un sistema locale, poi ruotato/spostato in blocco."""
        R0 = rot if isinstance(rot, np.ndarray) else rotm(*rot)
        for (shape, size, p, r, mat, kw) in parts:
            Rp = r if isinstance(r, np.ndarray) else rotm(*r)
            self.part(joint, shape, size, R0 @ np.asarray(p, float) + np.asarray(pos, float), R0 @ Rp, mat, **kw)

    # ----------------------------------------------------------------------------------------
    def fk(self, pose):
        out = {}
        for name in self.order:
            j = self.joints[name]
            p = pose.get(name, ())
            rot = tuple(p[:3]) if len(p) >= 3 else (0, 0, 0)
            tr = np.asarray(p[3:6], float) if len(p) >= 6 else np.zeros(3)
            Rj = rotm(*j.rest) @ rotm(*rot)
            if j.parent is None:
                Rp, op = np.eye(3), np.zeros(3)
            else:
                Rp, op = out[j.parent]
            out[name] = (Rp @ Rj, op + Rp @ (j.pivot + tr))
        return out

    def instances(self, pose, yaw=0.0, scale=1.0):
        """Forme posizionate nello spazio del modello, ruotate di `yaw` gradi attorno a z."""
        fk = self.fk(pose)
        Ry = rotm(0, 0, yaw)
        s = self.scale * scale
        res = []
        for p in self.parts:
            Rj, oj = fk[p.joint]
            c = oj + Rj @ p.pos
            Rp = p.rot if isinstance(p.rot, np.ndarray) else rotm(*p.rot)
            R = Rj @ Rp
            res.append(Inst(p.shape, (Ry @ c) * s, Ry @ R, p.size * s, p.mat, p.soft, p.tex))
        return res


# --- pose e animazione ---------------------------------------------------------------------------

def _pad(v, n):
    v = tuple(v)
    return v + (0.0,) * (n - len(v))


def lerp_pose(a, b, t):
    out = {}
    for k in set(a) | set(b):
        va, vb = a.get(k, ()), b.get(k, ())
        n = max(len(va), len(vb), 3)
        n = 6 if n > 3 else 3
        pa, pb = _pad(va, n), _pad(vb, n)
        out[k] = tuple(x + (y - x) * t for x, y in zip(pa, pb))
    return out


def add_pose(*poses):
    """Somma le pose (utile per comporre ciclo + inclinazione)."""
    out = {}
    for p in poses:
        for k, v in p.items():
            if k in out:
                n = 6 if max(len(out[k]), len(v)) > 3 else 3
                out[k] = tuple(x + y for x, y in zip(_pad(out[k], n), _pad(v, n)))
            else:
                out[k] = tuple(v)
    return out


def scale_pose(p, k):
    return {j: tuple(x * k for x in v) for j, v in p.items()}


def ease(t, kind="inout"):
    t = max(0.0, min(1.0, t))
    if kind == "linear":
        return t
    if kind == "in":
        return t * t
    if kind == "out":
        return 1 - (1 - t) * (1 - t)
    if kind == "hold":
        return 0.0
    if kind == "snap":      # scatto rapido a meta' (colpi)
        return 0.0 if t < 0.5 else 1.0
    if kind == "back":      # supera e torna (follow-through)
        c1 = 1.70158
        c3 = c1 + 1
        return 1 + c3 * (t - 1) ** 3 + c1 * (t - 1) ** 2
    return t * t * (3 - 2 * t)


def sample(keys, i, loop_len=None):
    """keys: [(frame, pose[, easing]), ...] ordinati. Ritorna la posa del frame `i` (anche frazionario).
    Con loop_len il ciclo si richiude: l'ultima chiave torna alla prima a `loop_len`."""
    ks = [(k[0], k[1], (k[2] if len(k) > 2 else "inout")) for k in keys]
    if loop_len is not None:
        ks = ks + [(ks[0][0] + loop_len, ks[0][1], ks[-1][2])]
        if i < ks[0][0]:
            i += loop_len
    if i <= ks[0][0]:
        return dict(ks[0][1])
    for (f0, p0, _), (f1, p1, e) in zip(ks, ks[1:]):
        if f0 <= i <= f1:
            return lerp_pose(p0, p1, ease((i - f0) / (f1 - f0), e))
    return dict(ks[-1][1])


def clip_from_keys(keys, n, loop=False):
    """Genera n pose (una per frame) dai fotogrammi chiave."""
    return [sample(keys, i, loop_len=n if loop else None) for i in range(n)]
