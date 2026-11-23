"""Il gatto (fauna, specie `gatto`), a griglia: gatto di strada grigio tigrato a righe scure, orecchie a punta,
occhi verdi a mandorla, baffi bianchi, coda lunga che si alza a punto di domanda. Si lecca; scappa con un balzo."""
import sys

import numpy as np

from . import _bestia
from ..corpo import Quadrupede
from ..pixel import Rampa, colore, segmento

CORPO = Quadrupede(lungo=6.5, largo=1.6, zampa=(3.0, 3.0), collo=2.2, piedi_pari=True)
R = {"manto": Rampa("slate", "grey", "grey_l"), "manto_scuro": Rampa("slate_d", "slate", "grey"), "piede": Rampa("grey", "grey_l", "white"), "coda": Rampa("slate", "grey", "grey_l"), "righe": Rampa("slate_d", "slate_d", "slate"),
     "sangue": Rampa("red_d", "red_d", "red")}
M = {"g": colore("grey"), "G": colore("slate"), "w": colore("white"), "E": colore("green"), "K": colore("ink"), "p": colore("pink")}
TESTA = {
    "down": ["G.....G", "GG...GG", "gGgGgGg", "gEggKEg", "wggpggw", ".ggwgg."],
    "up": ["G.....G", "GG...GG", "gGgGgGg", "gggGggg", ".ggggg."],
    "left": ["..G.G..", "..GgGg.", ".gEggg.", "wgggGg.", "pwgg...", ".w....."],
}
B = dict(zampa=(1.2, 1.4, 0.7), corpo=(2.2, 2.4), coda="sottile", collo=1.4, muso=1, testa_dy=-1)


def _righe(tela, v, g, posa):
    """Le righe scure del tigrato sul dorso."""
    def f():
        for k in range(5):
            t = k / max(5 - 1, 1)
            base = g["anche"] + (g["spalle"] - g["anche"]) * (0.1 + t * 0.8) + g["su"] * 1.6
            tip = base + g["su"] * 0.6 + np.array([(k % 2 - 0.5) * 2.4, 0, 0])
            segmento(tela, v.xy(base), v.xy(tip), 0.6, 0.6, R["righe"], "righe", uniti=("corpo",))
    return (v.prof((g["anche"] + g["spalle"]) / 2) + 0.2, 1.5, f)


EXTRA = (_righe,)

ANIM = _bestia.anim_fauna(giu=30, coda_su=80, balzo=4.0)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
