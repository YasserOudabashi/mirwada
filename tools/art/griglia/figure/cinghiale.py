"""Il cinghiale (fauna, specie `cinghiale`), a griglia: tozzo e gobbo, setole scure ritte sul dorso, testa grossa a
cuneo col grugno chiaro, zanne bianche, zampe corte, codino sottile. Da fermo grufola; in fuga carica a testa bassa."""
import sys

import numpy as np

from . import _bestia
from ..corpo import Quadrupede
from ..pixel import Rampa, colore, segmento

CORPO = Quadrupede(lungo=11.0, largo=3.2, zampa=(3.8, 3.6), collo=2.0, piedi_pari=True)
R = {"manto": Rampa("brown_dd", "brown_d", "brown"), "manto_scuro": Rampa("ink", "brown_dd", "brown_d"),
     "piede": Rampa("ink", "ink", "brown_dd"), "setole": Rampa("ink", "brown_dd", "brown_d"),
     "sangue": Rampa("red_d", "red_d", "red")}
M = {"b": colore("brown_d"), "B": colore("brown_dd"), "p": colore("tan"), "E": colore("ink"), "K": colore("ink"),
     "w": colore("white")}
TESTA = {
    "down": [".b........b.", "bBb......bBb", "bBBbbbbbbBBb", "BBEBBBBBBEBB", "BBBBBBBBBBBB", "wBBbppppbBBw",
             ".w.bpKKpb.w.", "...bppppb...", "....bbbb...."],
    "up": [".b........b.", "bBb......bBb", "bBBBBBBBBBBb", "BBBBbBBbBBBB", "BBBBBBBBBBBB", ".BBBBBBBBBB.",
           "..BBBBBBBB..", "....BBBB...."],
    "left": [".....bb.....", "....bBBb....", "...bBBBBBb..", "..bBEBBBBBb.", ".bbBBBBBBBb.", "pbbBBBBBBb..",
             "pwbBBBBBb...", ".wwbbBBb....", "..w.bbb....."],
}
B = dict(zampa=(2.4, 2.8, 1.1), corpo=(4.6, 5.8), coda="sottile", muso=3, testa_dy=1)


def _setole(tela, v, g, posa):
    """Cresta di setole ritte lungo il dorso, piu' alte sulle spalle."""
    def f():
        for k in range(7):
            t = k / 6
            base = g["anche"] + (g["spalle"] - g["anche"]) * t + g["su"] * (4.0 + 1.6 * t)
            tip = base + g["su"] * (1.8 + 1.6 * t) + np.array([0, -0.8, 0])
            segmento(tela, v.xy(base), v.xy(tip), 1.2, 0.3, R["setole"], "setole", uniti=("corpo",))
    return (v.prof((g["anche"] + g["spalle"]) / 2) + 0.2, 1.5, f)


EXTRA = (_setole,)
ANIM = _bestia.anim_fauna(giu=40, coda_su=50, balzo=2.0, testa_alta=10)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
