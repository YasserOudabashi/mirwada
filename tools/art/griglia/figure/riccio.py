"""Il riccio (fauna, specie `riccio`), a griglia: piccolissimo, una palla di aculei bruni con la punta chiara,
musetto appuntito chiaro col naso nero, zampette corte. Annusa per terra; se spaventato scappa veloce."""
import sys

import numpy as np

from . import _bestia
from ..corpo import Quadrupede
from ..pixel import Rampa, colore, segmento

CORPO = Quadrupede(lungo=4.0, largo=1.6, zampa=(1.6, 1.6), collo=1.4, piedi_pari=True)
R = {"manto": Rampa("brown_dd", "brown_d", "brown"), "manto_scuro": Rampa("ink", "brown_dd", "brown_d"), "piede": Rampa("brown", "tan", "cream"), "aculei": Rampa("brown_dd", "brown_d", "tan"),
     "sangue": Rampa("red_d", "red_d", "red")}
M = {"t": colore("tan"), "c": colore("cream"), "E": colore("ink"), "K": colore("ink")}
TESTA = {
    "down": ["..ttt..", ".tEtEt.", ".ttttt.", "..tKt.."],
    "up": ["..ttt..", ".ttttt.", "..ttt.."],
    "left": ["..tt.", ".Ett.", "Ktt.."],
}
B = dict(zampa=(0.8, 0.8, 0.5), corpo=(2.6, 2.6), coda="nessuna", muso=2, testa_dy=1)


def _aculei(tela, v, g, posa):
    """Gli aculei: tante punte chiare che escono dal dorso."""
    def f():
        for k in range(9):
            t = k / max(9 - 1, 1)
            base = g["anche"] + (g["spalle"] - g["anche"]) * (0.0 + t * 1.0) + g["su"] * 1.6
            tip = base + g["su"] * 2.2 + np.array([(k % 2 - 0.5) * 3.0, -0.6, 0])
            segmento(tela, v.xy(base), v.xy(tip), 0.7, 0.2, R["aculei"], "aculei", uniti=("corpo",))
    return (v.prof((g["anche"] + g["spalle"]) / 2) + 0.2, 1.5, f)


EXTRA = (_aculei,)

ANIM = _bestia.anim_fauna(giu=50, coda_su=0, balzo=1.0)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
