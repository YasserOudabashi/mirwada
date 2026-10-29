"""Icone degli oggetti (US-8B70): una forma per tipo di oggetto, con la stessa luce e lo stesso motore dei
personaggi. Le forme sono un vocabolario chiuso (FORME); la tinta (TINTE) colora la parte che cambia (il
liquido di una fiala, il cristallo, la polvere, il metallo...). L'icona id e' "<forma>_<tinta>".

Assi del modello come in engine.py: x a destra, y verso il fondo, z in su; la camera sta davanti (-y) e
guarda in giu' di 32 gradi. Le cose piatte (chiavi, piume, fogli) si costruiscono nel piano x-z e `piano()`
le gira verso la camera, inclinate di `a` gradi in senso orario sullo schermo.
"""
import math
import random

import numpy as np

from . import materials as M
from .engine import render, rotm
from .rig import Rig

LATO = 32                                    # pixel per lato dell'icona

# rampa della parte colorata, dal piu' scuro al piu' chiaro (palette Endesga 32)
TINTE = {
    "rosso": ["brown_dd", "red_d", "red", "pink"],
    "blu": ["navy", "blue_d", "blue", "cyan"],
    "verde": ["teal_d", "green_d", "green_m", "green"],
    "viola": ["navy", "purple_d", "purple", "pink"],
    "oro": ["brown_d", "orange", "amber", "yellow"],
    "nero": ["ink", "navy", "slate_d", "slate"],
    "argento": ["slate_d", "slate", "grey", "grey_l", "white"],
    "ciano": ["blue_d", "blue", "cyan", "white"],
    "bianco": ["slate", "grey", "grey_l", "white"],
    "ambra": ["brown_dd", "brown_d", "orange_d", "amber"],
    "terra": ["brown_dd", "brown_d", "brown", "tan"],
    "ferro": ["ink", "navy", "slate_d", "slate", "grey"],
    "bronzo": ["brown_dd", "brown_d", "orange_d", "amber"],
    "osso": ["slate", "grey", "grey_l", "cream"],
    "legno": ["brown_dd", "brown_d", "brown", "orange_d"],
    "pietra": ["navy", "slate_d", "slate", "grey", "grey_l"],
}
for _t, _r in TINTE.items():
    M.define(f"ic_liq_{_t}", _r, spec=0.7, shin=18)                         # liquidi, gocce, cera
    M.define(f"ic_gem_{_t}", _r, spec=0.9, shin=40)                         # cristalli, gemme, metalli
    M.define(f"ic_opaco_{_t}", _r, tex=("noise", 1.4, 0.14))                # polveri, stoffe, pelo, foglie
    M.define(f"ic_luce_{_t}", _r[1:] + [_r[-1]], emissive=True)             # sfere di luce, portali
for _t, _r in TINTE.items():
    M.define(f"ic_pelle_{_t}", _r, spec=0.15, shin=10, bias=-0.2)                       # cuoio, copertine
    M.define(f"ic_pietra_{_t}", _r, tex=("noise", 1.1, 0.2))                 # pietra, tavolette
M.define("ic_vetro", ["slate", "grey", "grey_l", "white"], spec=0.9, shin=40)
M.define("ic_carta", ["tan", "cream", "cream", "white"])
M.define("ic_carne", ["brown_dd", "red_d", "red", "pink"], spec=0.4, shin=16)
M.define("ic_inchiostro", ["brown_dd", "brown_dd", "brown_d"])
M.define("ic_buco", ["ink", "ink", "navy"])
M.define("ic_punto", ["ink", "ink", "navy"], keep=True)


def piano(r, parti, a=0.0, pos=(0, 0, 0)):
    """Forme costruite nel piano x-z (davanti verso -y), girate di `a` gradi (orario) e inclinate verso la camera."""
    R = rotm(-32, 0, 0) @ rotm(0, a, 0)
    r.group("a", parti, pos=pos, rot=R)


def P(shape, size, pos, mat, rot=(0, 0, 0)):
    return (shape, size, pos, rot, mat, {})


# --- forme ----------------------------------------------------------------------------------------

def fiala(r, t, rnd):
    r.part("a", "ellipsoid", (7, 7, 6.5), (0, 0, 7), mat=f"ic_liq_{t}")
    r.part("a", "ellipsoid", (1.0, 0.6, 2.0), (-3.4, -5.6, 9), mat="white")
    r.part("a", "cylinder", (2.4, 2.4, 3), (0, 0, 15), mat="ic_vetro")
    r.part("a", "cylinder", (3.0, 3.0, 0.8), (0, 0, 17.6), mat="ic_vetro")
    r.part("a", "cylinder", (2.0, 2.0, 1.8), (0, 0, 19.8), mat="wood_light")


def goccia(r, t, rnd):
    r.part("a", "ellipsoid", (6, 6, 6), (0, 0, 7), mat=f"ic_liq_{t}")
    r.part("a", "cone", (4.4, 4.4, 6), (0, 0, 15.5), mat=f"ic_liq_{t}")
    r.part("a", "ellipsoid", (1.0, 0.6, 1.8), (-2.8, -5, 9), mat="white")


def cristallo(r, t, rnd):
    for x, h, ry in ((-5, 5.5, -20), (5, 6.5, 18), (0, 9, 0)):
        R = rotm(0, ry, 45)
        base = np.array([x, 0, 0.0])
        asse = R @ np.array([0, 0, 1.0])
        r.part("a", "box", (2.6, 2.6, h), base + asse * h, rot=R, mat=f"ic_gem_{t}")
        r.part("a", "box", (1.84, 1.84, 1.84), base + asse * (2 * h + 0.2), rot=R @ rotm(45, 35.26, 0),
               mat=f"ic_gem_{t}")


def polvere(r, t, rnd):
    r.part("a", "ellipsoid", (7, 6, 6), (0, 0, 6.5), mat="cloth_cream")
    r.part("a", "cylinder", (3.4, 3.4, 1.4), (0, 0, 12.6), mat="cloth_cream")
    r.part("a", "cylinder", (3.7, 3.7, 0.7), (0, 0, 12.4), mat="cloth_red")
    r.part("a", "ellipsoid", (4.6, 4.2, 1.8), (0, 0, 14.6), mat="cloth_cream")
    r.part("a", "ellipsoid", (3.6, 3.2, 1.4), (0, 0, 15.8), mat=f"ic_opaco_{t}")
    r.part("a", "ellipsoid", (6.4, 4.6, 2.6), (3.6, -6.4, 1.6), mat=f"ic_opaco_{t}")
    r.part("a", "ellipsoid", (2.2, 1.8, 1.0), (-4.6, -7.4, 0.8), mat=f"ic_opaco_{t}")


def fiore(r, t, rnd):
    r.part("a", "cylinder", (0.8, 0.8, 7), (0, 0, 7), mat="grass")
    r.part("a", "ellipsoid", (3.2, 1.0, 1.3), (2.6, 0, 6), rot=(0, -30, 0), mat="leaf")
    petali = [P("ellipsoid", (2.2, 2.2, 1.6), (0, -1.4, 0), "cloth_yellow")]
    for k in range(5):
        ang = math.radians(90 + k * 72)
        petali.append(P("ellipsoid", (3.0, 1.0, 1.7), (3.0 * math.cos(ang), 0, 3.0 * math.sin(ang)),
                        f"ic_opaco_{t}", rot=(0, -math.degrees(ang), 0)))
    piano(r, petali, 0, (0, 0, 16))


def sfera(r, t, rnd):
    r.part("a", "ellipsoid", (7, 7, 7), (0, 0, 11), mat=f"ic_liq_{t}")
    r.part("a", "ellipsoid", (3.6, 3.6, 3.6), (-1.0, -4.4, 12.0), mat=f"ic_luce_{t}")
    r.part("a", "ellipsoid", (1.2, 0.8, 1.2), (-3.4, -6.0, 15.0), mat="white")
    for (x, z) in ((8.0, 18.5), (-8.4, 4.5), (6.6, 3.0)):
        r.part("a", "ellipsoid", (0.9, 0.9, 0.9), (x, -3, z), mat=f"ic_luce_{t}")


def stoffa(r, t, rnd):
    R = rotm(18, 0, 0)
    for k, z in enumerate((2.0, 5.6, 9.2)):
        Rk = R @ rotm(0, 0, 6 - k * 6)
        r.part("a", "box", (8.4 - k * 0.6, 6.2 - k * 0.4, 1.7), R @ np.array([k * 0.6, 0, z]), rot=Rk,
               mat=f"ic_opaco_{t}")
        r.part("a", "box", (8.5 - k * 0.6, 0.5, 0.5), R @ np.array([k * 0.6, -6.3 + k * 0.4, z + 0.7]), rot=Rk,
               mat="gold")
    r.part("a", "ellipsoid", (2.4, 1.6, 5.4), R @ np.array([7.8, -5.0, 5.0]), rot=R @ rotm(0, -10, 0),
           mat=f"ic_opaco_{t}")


def candela(r, t, rnd):
    r.part("a", "cylinder", (6, 6, 0.9), (0, 0, 0.9), mat="bronze")
    r.part("a", "cylinder", (3.2, 3.2, 6.5), (0, 0, 8.3), mat=f"ic_liq_{t}")
    for x, z in ((-2.6, 13), (2.2, 12)):
        r.part("a", "ellipsoid", (1.0, 1.0, 1.8), (x, -1.6, z), mat=f"ic_liq_{t}")
    r.part("a", "box", (0.3, 0.3, 1.2), (0, 0, 15.8), mat="ic_buco")
    r.part("a", "ellipsoid", (1.5, 1.5, 2.8), (0, 0, 19), mat="fire")


def lingotto(r, t, rnd):
    for (x, y, z, rz) in ((-1.5, 2.0, 2.4, 14), (2.5, -3.0, 2.4, 14), (0.5, -0.5, 7.4, -10)):
        r.part("a", "box", (8.0, 3.2, 2.4), (x, y, z), rot=(0, 0, rz), mat=f"ic_gem_{t}")
        r.part("a", "box", (6.8, 2.2, 0.7), (x, y, z + 2.7), rot=(-14, 0, rz), mat=f"ic_gem_{t}")


def erba(r, t, rnd):
    parti = [P("box", (1.8, 0.6, 0.9), (0, -0.4, -7), "cloth_red")]
    for ang, l in ((-26, 15), (0, 18), (24, 14)):
        a = math.radians(ang)
        parti.append(P("box", (0.5, 0.4, l / 2), (math.sin(a) * l / 2, 0, -10 + math.cos(a) * l / 2), "grass",
                       rot=(0, ang, 0)))
        for k in range(4):
            d = l * (0.35 + k * 0.2)
            lato = 1 if k % 2 else -1
            parti.append(P("ellipsoid", (3.0, 0.8, 1.4),
                           (math.sin(a) * d + lato * 2.2 * math.cos(a), 0,
                            -10 + math.cos(a) * d - lato * 2.2 * math.sin(a)),
                           f"ic_opaco_{t}", rot=(0, ang - lato * 45, 0)))
    piano(r, parti, 0, (0, 0, 12))


def radice(r, t, rnd):
    parti = []
    pts = [(0, 9), (-0.6, 5), (0.6, 1), (-0.4, -3), (0.8, -7)]
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        rr = 2.6 - 0.45 * len(parti)
        parti.append(P("ellipsoid", (rr, rr, math.hypot(x1 - x0, z1 - z0) / 2 + 1), ((x0 + x1) / 2, 0, (z0 + z1) / 2),
                       f"ic_opaco_{t}", rot=(0, math.degrees(math.atan2(x1 - x0, z1 - z0)), 0)))
    for (x, z, ang, l) in ((1.5, 3, 50, 4.5), (-1.4, -1, -55, 4), (1.2, -4, 40, 3)):
        a = math.radians(ang)
        parti.append(P("ellipsoid", (0.9, 0.9, l), (x + math.sin(a) * l * 0.8, 0, z - math.cos(a) * l * 0.8),
                       f"ic_opaco_{t}", rot=(0, -ang, 0)))
    for k in range(3):
        parti.append(P("ellipsoid", (1.0, 0.5, 2.6), ((k - 1) * 1.6, 0, 11.5), "leaf", rot=(0, (k - 1) * 28, 0)))
    piano(r, parti, 12, (0, 0, 12))


def fungo(r, t, rnd):
    for (x, y, s) in ((-3.4, 1.5, 0.7), (2.0, -1.0, 1.0)):
        r.part("a", "cylinder", (2.0 * s, 2.0 * s, 5 * s), (x, y, 5 * s), mat="cloth_cream")
        r.part("a", "ellipsoid", (6.5 * s, 6.5 * s, 3.8 * s), (x, y, 11 * s), mat=f"ic_gem_{t}")
        if t == "rosso":
            for (dx, dz) in ((-2.6, 1.6), (1.6, 2.6), (3.6, 0.4)):
                r.part("a", "ellipsoid", (0.9 * s, 0.9 * s, 0.7 * s), (x + dx * s, y - 4.6 * s, (11 + dz) * s),
                       mat="white")


def seme(r, t, rnd):
    mat = f"ic_gem_{t}" if t != "legno" else "wood_light"
    r.part("a", "ellipsoid", (4.6, 4.6, 5.8), (0, 0, 6.2), rot=(0, 14, 0), mat=mat)
    r.part("a", "ellipsoid", (5.2, 5.2, 2.6), (1.2, 0, 11.4), rot=(0, 14, 0), mat="wood")
    r.part("a", "cylinder", (0.6, 0.6, 1.6), (1.8, 0, 14.6), rot=(0, 14, 0), mat="wood")


def piuma(r, t, rnd):
    piano(r, [P("ellipsoid", (3.2, 0.7, 10.5), (0.4, 0, 1.5), f"ic_opaco_{t}"),
              P("box", (0.35, 0.8, 12.5), (0, -0.2, 0), "bone"),
              P("ellipsoid", (1.2, 0.5, 1.6), (-2.0, -0.3, -4), "ic_buco" if t != "nero" else "bone")], 35, (0, 0, 12))


def osso(r, t, rnd):
    parti = [P("cylinder", (1.6, 1.6, 7.5), (0, 0, 0), f"ic_gem_{t}")]
    for z in (-7.5, 7.5):
        for x in (-1.8, 1.8):
            parti.append(P("ellipsoid", (2.2, 2.0, 2.2), (x, 0, z), f"ic_gem_{t}"))
    piano(r, parti, 45, (0, 0, 12))


def zanna(r, t, rnd):
    parti = [P("ellipsoid", (4.0, 3.4, 2.4), (-3.4, 0, -9), "ic_carne")]
    pts = [(-3.4, -8.0, 3.6), (-2.6, -3.5, 3.1), (-0.6, 0.5, 2.5), (2.2, 4.0, 1.8)]
    for (x0, z0, r0), (x1, z1, r1) in zip(pts, pts[1:]):
        ang = math.degrees(math.atan2(x1 - x0, z1 - z0))
        parti.append(P("ellipsoid", (r0, r0, math.hypot(x1 - x0, z1 - z0) / 2 + 1.2),
                       ((x0 + x1) / 2, 0, (z0 + z1) / 2), f"ic_gem_{t}", rot=(0, ang, 0)))
    parti.append(P("cone", (1.8, 1.8, 3.2), (4.6, 0, 6.6), f"ic_gem_{t}", rot=(0, 48, 0)))
    piano(r, parti, -14, (0, 0, 12))


def corno(r, t, rnd):
    parti = []
    for k in range(7):
        a = math.radians(-30 + k * 22)
        rr = 3.4 - k * 0.42
        parti.append(P("ellipsoid", (rr, rr, 2.4), (7 * math.cos(a) - 2, 0, 7 * math.sin(a)), f"ic_gem_{t}",
                       rot=(0, -60 - k * 22 + 90, 0)))
    piano(r, parti, 0, (0, 0, 12))


def occhio(r, t, rnd):
    r.part("a", "ellipsoid", (2.0, 2.0, 2.4), (3, 4, 6), mat="ic_carne")
    r.part("a", "ellipsoid", (7, 7, 7), (0, 0, 10), mat="eye_white")
    piano(r, [P("ellipsoid", (3.4, 1.0, 3.4), (0, 0, 0), f"ic_gem_{t}"),
              P("ellipsoid", (1.6, 0.8, 1.6), (0, -0.7, 0), "ic_buco"),
              P("ellipsoid", (0.7, 0.5, 0.7), (-1.2, -1.2, 1.2), "white")], 0, (0, -6.2, 10.6))


def cuore(r, t, rnd):
    mat = "ic_carne" if t == "rosso" else f"ic_gem_{t}"
    for x in (-3, 3):
        r.part("a", "ellipsoid", (4.4, 4.0, 5.0), (x, 0, 13), mat=mat)
    r.part("a", "cone", (6.2, 4.0, 5.0), (0, 0, 7.0), rot=(180, 0, 0), mat=mat)
    r.part("a", "cylinder", (1.4, 1.4, 2.2), (1.6, 0.8, 18.4), mat=mat)
    r.part("a", "cylinder", (1.0, 1.0, 1.8), (-2.2, 1.0, 18.0), mat=mat)


def pelo(r, t, rnd):
    parti = [P("ellipsoid", (5.0, 1.0, 7.0), (0, 0, 0), f"ic_opaco_{t}"),
             P("ellipsoid", (2.6, 1.2, 2.4), (0, -0.2, 7.4), f"ic_opaco_{t}"),
             P("ellipsoid", (1.0, 0.8, 4.0), (0.8, 0, -9.6), f"ic_opaco_{t}", rot=(0, -12, 0))]
    for sx in (-1, 1):
        for sz, ang in ((3.4, 55), (-3.6, 125)):
            parti.append(P("ellipsoid", (1.6, 0.9, 3.6), (sx * 5.6, 0, sz + (1 if sz > 0 else -1) * 1.6),
                           f"ic_opaco_{t}", rot=(0, sx * ang, 0)))
    piano(r, parti, 18, (0, 0, 12))


def filo(r, t, rnd):
    r.part("a", "cylinder", (6, 6, 1.0), (0, 0, 1.0), mat="wood_light")
    r.part("a", "cylinder", (4.8, 4.8, 5.4), (0, 0, 7.2), mat=f"ic_opaco_{t}")
    r.part("a", "cylinder", (6, 6, 1.0), (0, 0, 13.4), mat="wood_light")
    r.part("a", "box", (0.5, 0.5, 4.5), (5.6, -2.6, 4.5), rot=(0, 30, 0), mat=f"ic_opaco_{t}")


def chiave(r, t, rnd):
    piano(r, [P("cylinder", (4.2, 4.2, 1.2), (0, 0, 7), f"ic_gem_{t}", rot=(90, 0, 0)),
              P("cylinder", (1.9, 1.9, 1.4), (0, -0.2, 7), "ic_buco", rot=(90, 0, 0)),
              P("box", (1.1, 1.0, 7), (0, 0, -3), f"ic_gem_{t}"),
              P("box", (2.0, 0.9, 0.8), (2.0, 0, -8.6), f"ic_gem_{t}"),
              P("box", (1.5, 0.9, 0.8), (1.6, 0, -5.6), f"ic_gem_{t}")], -40, (0, 0, 12))


def chiodo(r, t, rnd):
    piano(r, [P("cylinder", (2.8, 2.8, 0.8), (0, 0, 8.6), f"ic_gem_{t}"),
              P("box", (0.9, 0.9, 8), (0, 0, 0.4), f"ic_gem_{t}"),
              P("cone", (0.9, 0.9, 1.8), (0, 0, -9.2), f"ic_gem_{t}", rot=(180, 0, 0))], 35, (0, 0, 12))


def carta(r, t, rnd):
    parti = [P("box", (7, 0.4, 9.5), (0, 0, 0), "ic_carta")]
    for k in range(5):
        parti.append(P("box", (5.0 - (k == 4) * 2, 0.3, 0.35), (-(k == 4) * 2, -0.4, 6 - k * 3), "ic_inchiostro"))
    parti.append(P("box", (1.6, 0.3, 1.6), (5.4, -0.45, -7.9), "cloth_cream"))
    piano(r, parti, 8, (0, 0, 12))


def pergamena(r, t, rnd):
    parti = [P("box", (5.6, 0.4, 7.0), (0, 0, 0), "ic_carta")]
    for k in range(4):
        parti.append(P("box", (4.0 - (k == 3) * 1.6, 0.3, 0.32), (-(k == 3) * 1.6, -0.45, 4.0 - k * 2.6), "ic_inchiostro"))
    for z in (7.4, -7.4):
        parti.append(P("cylinder", (1.9, 1.9, 6.4), (0, -0.4, z), "ic_carta", rot=(0, 90, 0)))
        for x in (-7.4, 7.4):
            parti.append(P("cylinder", (1.2, 1.2, 1.0), (x, -0.4, z), "wood", rot=(0, 90, 0)))
    parti.append(P("box", (1.0, 0.4, 3.2), (3.0, -2.2, -9.4), f"ic_opaco_{t}", rot=(0, -15, 0)))
    parti.append(P("ellipsoid", (2.0, 1.0, 2.0), (3.0, -2.6, -6.4), f"ic_liq_{t}"))
    piano(r, parti, -12, (0, 0, 12))


def libro(r, t, rnd):
    R = rotm(0, 0, -28)
    parti = [P("box", (6.6, 2.6, 8.8), R @ np.array([0.6, 0.3, 0]), "ic_carta", rot=R),
             P("box", (7.2, 0.5, 9.4), R @ np.array([0, -2.6, 0]), f"ic_pelle_{t}", rot=R),
             P("box", (7.2, 0.5, 9.4), R @ np.array([0, 2.9, 0]), f"ic_pelle_{t}", rot=R),
             P("box", (0.9, 3.2, 9.4), R @ np.array([-7.0, 0.15, 0]), f"ic_pelle_{t}", rot=R),
             P("box", (1.8, 0.4, 1.8), R @ np.array([0.2, -3.1, 1.6]), "gold", rot=R @ rotm(0, 45, 0)),
             P("box", (0.8, 3.6, 1.2), R @ np.array([7.3, 0.15, 0]), "gold", rot=R)]
    piano(r, parti, -6, (0, 0, 12))


def specchio(r, t, rnd):
    piano(r, [P("cylinder", (5.6, 5.6, 1.0), (0, 0, 3), "gold", rot=(90, 0, 0)),
              P("cylinder", (4.4, 4.4, 0.6), (0, -0.7, 3), f"ic_gem_{t}", rot=(90, 0, 0)),
              P("box", (0.8, 0.4, 2.4), (-1.6, -1.3, 4.6), "white", rot=(0, -40, 0)),
              P("box", (1.1, 1.0, 4.6), (0, 0, -6.6), "gold"),
              P("ellipsoid", (1.6, 1.4, 1.4), (0, 0, -11.4), "gold")], -25, (0, 0, 12))


def moneta(r, t, rnd):
    scuro = {"oro": "bronze", "argento": "iron", "bronzo": "leather_dark"}.get(t, "iron")
    for (x, y, z, a, s) in ((6.0, 4.0, 15.0, 24, 0.62), (-1.4, -2.0, 9.0, -8, 1.0)):
        piano(r, [P("cylinder", (6.2 * s, 6.2 * s, 1.0), (0, 0.6, 0), scuro, rot=(90, 0, 0)),
                  P("ellipsoid", (5.4 * s, 1.2, 5.4 * s), (0, 0, 0), f"ic_gem_{t}"),
                  P("box", (0.9 * s, 0.7, 2.8 * s), (0, -1.2, 0), scuro),
                  P("box", (2.8 * s, 0.7, 0.9 * s), (0, -1.2, 0), scuro)], a, (x, y, z))


def sigillo(r, t, rnd):
    piano(r, [P("box", (1.6, 0.4, 5), (-2.2, 0.6, -5.6), f"ic_opaco_{t}", rot=(0, 18, 0)),
              P("box", (1.6, 0.4, 5), (2.2, 0.6, -5.6), f"ic_opaco_{t}", rot=(0, -18, 0)),
              P("ellipsoid", (6.4, 1.8, 6.0), (0, 0, 1), f"ic_liq_{t}"),
              P("ellipsoid", (4.2, 1.4, 4.0), (0, -0.9, 1), f"ic_liq_{t}"),
              P("box", (0.6, 0.5, 2.6), (0, -2.2, 1), f"ic_liq_{t}"),
              P("box", (2.6, 0.5, 0.6), (0, -2.2, 1), f"ic_liq_{t}")], 0, (0, 0, 12))


def ingranaggio(r, t, rnd):
    def ruota(raggio, denti, pos, fase):
        parti = [P("cylinder", (raggio, raggio, 1.4), (0, 0, 0), f"ic_gem_{t}", rot=(90, 0, 0)),
                 P("cylinder", (raggio * 0.32, raggio * 0.32, 1.6), (0, -0.2, 0), "ic_buco", rot=(90, 0, 0))]
        for k in range(denti):
            a = 360.0 * k / denti + fase
            ar = math.radians(a)
            parti.append(P("box", (1.2, 1.3, 1.3), ((raggio + 0.8) * math.cos(ar), 0, (raggio + 0.8) * math.sin(ar)),
                           f"ic_gem_{t}", rot=(0, -a, 0)))
        piano(r, parti, 0, pos)
    ruota(3.6, 6, (6, 3, 18), 15)
    ruota(6.2, 9, (-1, 0, 10), 0)


def clessidra(r, t, rnd):
    for z in (1.2, 20.4):
        r.part("a", "cylinder", (6.4, 6.4, 1.2), (0, 0, z), mat="wood")
    for x in (-5.4, 5.4):
        r.part("a", "cylinder", (0.9, 0.9, 8.4), (x, -1.4, 10.8), mat="wood_light")
    r.part("a", "cone", (4.8, 4.8, 4.6), (0, 0, 7.0), mat=f"ic_opaco_{t}")
    r.part("a", "cone", (4.8, 4.8, 4.6), (0, 0, 14.6), rot=(180, 0, 0), mat="ice")
    r.part("a", "cone", (2.4, 2.4, 2.0), (0, 0, 12.2), rot=(180, 0, 0), mat=f"ic_opaco_{t}")
    r.part("a", "cylinder", (0.5, 0.5, 1.6), (0, -0.4, 10.6), mat=f"ic_opaco_{t}")


def calice(r, t, rnd):
    r.part("a", "cylinder", (4.6, 4.6, 0.9), (0, 0, 0.9), mat=f"ic_gem_{t}")
    r.part("a", "cylinder", (1.1, 1.1, 3.6), (0, 0, 5.0), mat=f"ic_gem_{t}")
    r.part("a", "ellipsoid", (1.9, 1.9, 1.3), (0, 0, 6.2), mat=f"ic_gem_{t}")
    r.part("a", "cone", (6.0, 6.0, 4.6), (0, 0, 13.4), rot=(180, 0, 0), mat=f"ic_gem_{t}")
    r.part("a", "cylinder", (6.1, 6.1, 0.8), (0, 0, 17.6), mat=f"ic_gem_{t}")
    r.part("a", "ellipsoid", (2.6, 0.5, 1.0), (0, -5.4, 11.6), mat="gem_red")


def campana(r, t, rnd):
    r.part("a", "box", (2.6, 1.0, 1.6), (0, 0, 20), mat="iron")
    r.part("a", "ellipsoid", (5.0, 5.0, 6.5), (0, 0, 13), mat=f"ic_gem_{t}")
    r.part("a", "cone", (7.2, 7.2, 4), (0, 0, 7.6), mat=f"ic_gem_{t}")
    r.part("a", "cylinder", (7.4, 7.4, 1.0), (0, 0, 4.4), mat=f"ic_gem_{t}")
    r.part("a", "ellipsoid", (1.8, 1.8, 1.8), (0.8, -2, 2.6), mat="iron")


def maschera(r, t, rnd):
    piano(r, [P("ellipsoid", (6.2, 2.6, 8.2), (0, 0, 0), f"ic_gem_{t}"),
              P("ellipsoid", (1.9, 0.8, 1.1), (-2.6, -2.2, 1.6), "ic_buco", rot=(0, -12, 0)),
              P("ellipsoid", (1.9, 0.8, 1.1), (2.6, -2.2, 1.6), "ic_buco", rot=(0, 12, 0)),
              P("box", (1.8, 0.5, 0.35), (0, -2.4, -4.4), "ic_buco"),
              P("ellipsoid", (0.9, 1.0, 2.2), (0, -2.4, -1.0), f"ic_gem_{t}")], 12, (0, 0, 12))


def corona(r, t, rnd):
    R = rotm(-14, 0, 0)
    def at(v):
        return R @ np.array(v, float)
    r.part("a", "cylinder", (8.4, 8.4, 3.2), at((0, 0, 5)), rot=R, mat=f"ic_gem_{t}")
    r.part("a", "cylinder", (7.3, 7.3, 3.1), at((0, 0, 5.5)), rot=R, mat="ic_pelle_rosso")
    for k in range(5):
        a = -90 + (k - 2) * 34
        ar = math.radians(a)
        Rp = R @ rotm(0, 0, a + 90) @ rotm(0, 45, 0)
        r.part("a", "box", (3.0, 0.8, 3.0), at((8.0 * math.cos(ar), 8.0 * math.sin(ar), 8.6)), rot=Rp,
               mat=f"ic_gem_{t}")
        r.part("a", "ellipsoid", (1.2, 1.2, 1.2), at((8.0 * math.cos(ar), 8.0 * math.sin(ar), 13.6)), rot=R,
               mat=f"ic_gem_{t}")
    for k in (-1, 0, 1):
        a = math.radians(-90 + k * 34)
        r.part("a", "ellipsoid", (1.6, 0.9, 1.6), at((8.4 * math.cos(a), 8.4 * math.sin(a), 5)), rot=R,
               mat="gem_red" if k == 0 else "gem_blue")


def porta(r, t, rnd):
    luce = t not in ("legno", "terra")
    parti = [P("box", (1.8, 2.0, 7.6), (x, 0, -2), "stone_light") for x in (-6.2, 6.2)]
    parti += [P("box", (8.0, 2.0, 1.6), (0, 0, 6.6), "stone_light"),
              P("box", (4.5, 1.0, 7.8), (0, 1.2, -1.8), "ic_buco" if luce else "wood")]
    if luce:                                       # un varco che brilla: vortice ombreggiato e un cuore di luce
        parti += [P("ellipsoid", (4.2, 1.0, 7.2), (0, 0.2, -2.2), f"ic_liq_{t}"),
                  P("ellipsoid", (1.8, 0.6, 4.6), (-0.6, -0.6, -1.6), f"ic_luce_{t}")]
    else:
        parti.append(P("ellipsoid", (0.7, 0.6, 0.7), (2.6, 0.0, -2), "gold"))
    piano(r, parti, 0, (0, 0, 11))


def tavoletta(r, t, rnd):
    R = rotm(0, 0, -22)
    parti = [P("box", (6.4, 2.4, 7.4), R @ np.array([0, 0, -1.4]), f"ic_pietra_{t}", rot=R),
             P("cylinder", (6.4, 2.4, 2.4), R @ np.array([0, 0, 5.4]), f"ic_pietra_{t}", rot=R @ rotm(90, 0, 0))]
    for k in range(4):
        parti.append(P("box", (4.4 - (k % 2) * 1.2, 0.4, 0.4), R @ np.array([-(k % 2) * 1.2, -2.35, 4.4 - k * 2.6]),
                       "ic_buco", rot=R))
    parti.append(P("box", (0.5, 0.5, 2.6), R @ np.array([3.4, -2.4, -5.4]), "ic_buco", rot=R @ rotm(0, 30, 0)))
    piano(r, parti, 4, (0, 0, 11))


def dado(r, t, rnd):
    s = 7.0
    R = rotm(22, 0, 30)
    c = np.array([0, 0, 9.0])
    r.part("a", "box", (s, s, s), c, rot=R, mat="bone")
    q = s * 0.5
    facce = {(0, 0, 1): [(-q, -q), (0, 0), (q, q)], (0, -1, 0): [(-q, q), (q, -q)],
             (1, 0, 0): [(-q, -q), (-q, q), (q, -q), (q, q)], (-1, 0, 0): [(0, 0)]}
    for n, pips in facce.items():
        n = np.array(n, float)
        u = np.array([1.0, 0, 0]) if abs(n[0]) < 0.5 else np.array([0, 1.0, 0])
        v = np.cross(n, u)
        for a, b in pips:
            dim = np.abs(u) * 1.5 + np.abs(v) * 1.5 + np.abs(n) * 0.5
            r.part("a", "ellipsoid", tuple(dim), c + R @ (n * s + u * a + v * b), rot=R, mat="ic_punto")


def spada(r, t, rnd):
    piano(r, [P("box", (1.4, 0.5, 8.6), (0, 0, 3.4), f"ic_gem_{t}"),
              P("box", (0.35, 0.6, 8.0), (-0.5, -0.2, 3.4), "white"),
              P("cone", (1.4, 0.5, 1.8), (0, 0, 13.8), f"ic_gem_{t}"),
              P("box", (4.2, 1.1, 0.9), (0, 0, -5.6), "gold"),
              P("cylinder", (0.9, 0.9, 2.6), (0, 0, -9.0), "leather"),
              P("ellipsoid", (1.4, 1.4, 1.4), (0, 0, -12.2), "gold")], 45, (0, 0, 12))


def ascia(r, t, rnd):
    piano(r, [P("cylinder", (1.0, 1.0, 10.5), (0, 0, 0), "wood"),
              P("box", (3.4, 0.8, 2.6), (2.6, 0, 7.0), f"ic_gem_{t}"),
              P("ellipsoid", (2.4, 0.9, 4.6), (5.6, 0, 7.0), f"ic_gem_{t}"),
              P("box", (1.4, 0.9, 1.6), (-1.6, 0, 7.0), f"ic_gem_{t}")], 30, (0, 0, 12))


def corazza(r, t, rnd):
    mat = f"ic_gem_{t}" if t in ("ferro", "argento", "oro", "bronzo") else f"ic_opaco_{t}"
    r.part("a", "ellipsoid", (6.6, 4.4, 7.6), (0, 0, 10), mat=mat)
    for x in (-6.4, 6.4):
        r.part("a", "ellipsoid", (3.0, 3.2, 2.6), (x, 0, 15.4), mat=mat)
    r.part("a", "ellipsoid", (2.8, 2.0, 1.4), (0, -1.6, 17.2), mat="ic_buco")
    r.part("a", "cylinder", (6.3, 4.2, 1.0), (0, 0, 5.2), mat="leather_dark")
    r.part("a", "box", (1.0, 0.6, 0.9), (0, -4.3, 5.2), mat="gold")


def scudo(r, t, rnd):
    piano(r, [P("cylinder", (8.4, 8.4, 0.8), (0, 0.5, 0), "iron", rot=(90, 0, 0)),
              P("cylinder", (7.4, 7.4, 1.0), (0, 0, 0), f"ic_opaco_{t}", rot=(90, 0, 0)),
              P("box", (7.4, 1.05, 1.0), (0, -0.1, 0), "iron"),
              P("box", (1.0, 1.05, 7.4), (0, -0.1, 0), "iron"),
              P("ellipsoid", (2.4, 1.6, 2.4), (0, -0.8, 0), "iron")], 0, (0, 0, 11))


def anello(r, t, rnd):
    parti = []
    for k in range(14):
        a = 2 * math.pi * k / 14
        parti.append(P("ellipsoid", (1.5, 1.5, 1.5), (5.2 * math.cos(a), 0, 5.2 * math.sin(a)), "gold"))
    parti += [P("box", (2.2, 2.0, 1.2), (0, 0, 6.2), "gold"), P("ellipsoid", (2.4, 2.2, 2.0), (0, -0.4, 8.2), f"ic_gem_{t}")]
    piano(r, parti, 0, (0, 0, 9))


def amuleto(r, t, rnd):
    parti = []
    for k in range(9):
        a = math.radians(20 + k * 17.5)
        parti.append(P("ellipsoid", (0.7, 0.7, 0.7), (7 * math.cos(a), 0, 7 * math.sin(a) - 1), "gold"))
    parti += [P("cylinder", (4.4, 4.4, 1.0), (0, 0, -4.6), "gold", rot=(90, 0, 0)),
              P("ellipsoid", (2.8, 1.4, 2.8), (0, -0.8, -4.6), f"ic_gem_{t}")]
    piano(r, parti, 0, (0, 0, 12))


FORME = {f.__name__: f for f in (
    fiala, goccia, cristallo, polvere, fiore, sfera, stoffa, candela, lingotto, erba, radice, fungo, seme, piuma,
    osso, zanna, corno, occhio, cuore, pelo, filo, chiave, chiodo, carta, pergamena, libro, specchio, moneta,
    sigillo, ingranaggio, clessidra, calice, campana, maschera, corona, porta, tavoletta, dado, spada, ascia,
    corazza, scudo, anello, amuleto)}


def icona(forma, tinta, seed=1):
    """RGBA LATO x LATO dell'icona: modello disegnato su una tela piu' grande, poi centrato."""
    r = Rig(f"icona_{forma}"); r.joint("a", "root", (0, 0, 0))
    FORME[forma](r, tinta, random.Random(seed))
    big = render(r.instances({}, 0), size=(48, 48), ppu=1.0, foot=(0.5, 0.82), shadow=False)
    ys, xs = np.nonzero(big[..., 3])
    h, w = ys.max() - ys.min() + 1, xs.max() - xs.min() + 1
    assert h <= LATO and w <= LATO, f"{forma}_{tinta}: {w}x{h} non entra in {LATO}"
    out = np.zeros((LATO, LATO, 4), np.uint8)
    oy, ox = (LATO - h) // 2, (LATO - w) // 2
    out[oy:oy + h, ox:ox + w] = big[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return out
