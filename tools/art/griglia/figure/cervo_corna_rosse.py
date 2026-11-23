"""Il cervo dalle corna rosse (nemico_base, aspetto cervo_corna_rosse), a griglia: un cervo della Valle impazzito,
manto bruno scuro con le costole che si vedono, corna enormi ramificate rosso sangue con le punte accese, occhi rossi,
schiuma alla bocca. Carica a testa bassa. Pose del lupo della luna (bestie)."""
import sys

import numpy as np

from . import _bestia
from .lupo_della_luna import ANIM
from ..corpo import Quadrupede
from ..pixel import Rampa, colore, segmento

CORPO = Quadrupede(lungo=15.0, largo=2.6, zampa=(8.0, 7.6), collo=7.5, piedi_pari=True)
R = {"manto": Rampa("brown_dd", "brown_d", "brown"), "manto_scuro": Rampa("ink", "brown_dd", "brown_d"),
     "piede": Rampa("ink", "ink", "brown_dd"), "pancia": Rampa("brown_d", "brown", "tan"),
     "corna": Rampa("red_d", "red", "pink"), "punte": Rampa("red", "pink", "white"),
     "sangue": Rampa("red_d", "red_d", "red")}
M = {"b": colore("brown_d"), "B": colore("brown_dd"), "t": colore("brown"), "E": colore("red"), "K": colore("ink"),
     "w": colore("white")}
TESTA = {
    "down": [".bb.....bb.", "..bbbbbbb..", ".bbEbbbEbb.", "..bbbbbbb..", "...btttb...", "...ttKtt...", "....www...."],
    "up": [".bb.....bb.", "..bbbbbbb..", ".bbbbbbbbb.", "..bbbbbbb..", "...bBBBb..."],
    "left": ["....bb.....", "...bbbbbB..", "..bEbbbbB..", ".bbbbbbb...", "Kttbbbb....", ".wwtb......"],
}
APERTA = TESTA
B = dict(zampa=(2.2, 2.8, 1.1), corpo=(4.4, 4.8), coda="corta", pancia=True, collo=3.0, muso=2)


def _corna(tela, v, g, posa):
    """Corna rosse enormi, a rami: tre punte per lato, accese in cima."""
    def f():
        x, y = v.xy(g["testa"])
        lati = (-1, 1) if v.dir in ("down", "up") else ((1,) if v.dir == "left" else (-1,))
        for s in lati:
            bx = x + (s * 2 if v.dir in ("down", "up") else s * 2)
            a, b = (bx, y - 3), (bx + s * 6, y - 12)
            segmento(tela, a, b, 1.2, 0.8, R["corna"], f"corna{s}")
            for k, (fx, fy) in enumerate(((0.4, -5), (0.7, -4), (1.0, 0))):
                p = (a[0] + (b[0] - a[0]) * fx, a[1] + (b[1] - a[1]) * fx)
                q = (p[0] + s * 3, p[1] + fy) if k < 2 else (p[0] + s * 1, p[1] - 3)
                segmento(tela, p, q, 0.7, 0.4, R["corna"], f"corna{s}", uniti=(f"corna{s}",))
                segmento(tela, q, q, 0.5, 0.5, R["punte"], f"corna{s}", uniti=(f"corna{s}",), separa=False)
    return (v.prof(g["testa"]) + (8.5 if v.dir == "up" else 2.5), 3.2, f)


def _costole(tela, v, g, posa):
    def f():
        if v.dir not in ("left", "right"):
            return
        for k in range(4):
            p = g["spalle"] + (g["anche"] - g["spalle"]) * (0.2 + k * 0.12) - g["su"] * 1.0
            x, y = v.xy(p)
            segmento(tela, (x, y - 2), (x, y + 2), 0.4, 0.4, R["manto_scuro"], "costole", separa=False)
    return (v.prof((g["anche"] + g["spalle"]) / 2) + 0.2, 1.4, f)


EXTRA = (_corna, _costole)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
