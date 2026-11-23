"""Il cavallo (fauna, specie `cavallo`), a griglia: alto e snello, manto baio (bruno rossiccio), criniera e coda
nere, zoccoli scuri, una stella bianca in fronte. Da fermo bruca e scuote la testa; in fuga galoppa."""
import sys

import numpy as np

from . import _bestia
from ..corpo import Quadrupede
from ..pixel import Rampa, colore, segmento

CORPO = Quadrupede(lungo=15.0, largo=2.8, zampa=(8.4, 8.0), collo=7.0, piedi_pari=True)
R = {"manto": Rampa("brown_d", "rust", "orange_d"), "manto_scuro": Rampa("brown_dd", "brown_d", "rust"), "piede": Rampa("ink", "ink", "brown_dd"), "coda": Rampa("ink", "brown_dd", "brown_d"), "criniera": Rampa("ink", "brown_dd", "brown_d"),
     "sangue": Rampa("red_d", "red_d", "red")}
M = {"r": colore("rust"), "R": colore("brown_d"), "w": colore("white"), "E": colore("ink"), "n": colore("brown_dd")}
TESTA = {
    "down": [".R.....R.", ".rR...Rr.", "..rrrrr..", ".rEwwwEr.", "..rrwrr..", "..rrrrr..", "..rrrrr..", "...nnn...", "...nnn..."],
    "up": [".R.....R.", ".rR...Rr.", "..rrrrr..", ".rrRRRrr.", "..rrRrr..", "..rrrrr..", "...rrr..."],
    "left": ["....RR....", "...rRrr...", "..rrwrrR..", ".rrErrrR..", "rrrrrrR...", "nrrrrR....", "nnrR......"],
}
B = dict(zampa=(2.4, 3.0, 1.0), corpo=(4.8, 5.2), coda="folta", collo=3.0, muso=3, testa_dy=-2)


def _criniera(tela, v, g, posa):
    """La criniera nera lungo il collo."""
    def f():
        for k in range(6):
            t = k / max(6 - 1, 1)
            base = g["spalle"] + (g["testa"] - g["spalle"]) * (0.0 + t * 0.8) + g["su"] * 3.0
            tip = base + g["su"] * 2.0 + np.array([(k % 2 - 0.5) * 0.8, 0.4, 0])
            segmento(tela, v.xy(base), v.xy(tip), 1.3, 0.5, R["criniera"], "criniera", uniti=("corpo",))
    return (v.prof((g["anche"] + g["spalle"]) / 2) + 0.2, 1.5, f)


EXTRA = (_criniera,)

ANIM = _bestia.anim_fauna(giu=60, coda_su=40, balzo=4.0)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
