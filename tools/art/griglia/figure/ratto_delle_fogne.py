"""Il ratto delle fogne (nemico_base, aspetto ratto_delle_fogne), a griglia: un ratto grosso come un cane, pelo grigio
sporco a ciuffi, orecchie e coda nude rosa, occhi rossi, denti gialli in fuori. Pose del lupo della luna (bestie)."""
import sys

import numpy as np

from . import _bestia
from .lupo_della_luna import ANIM
from ..corpo import Quadrupede
from ..pixel import Rampa, colore, segmento

CORPO = Quadrupede(lungo=11.0, largo=2.8, zampa=(3.6, 3.4), collo=2.6, piedi_pari=True)
R = {"manto": Rampa("slate_d", "slate", "grey"), "manto_scuro": Rampa("ink", "slate_d", "slate"),
     "piede": Rampa("red_d", "pink", "pink"), "coda": Rampa("red_d", "pink", "pink"),
     "pancia": Rampa("slate", "grey", "grey_l"), "ciuffi": Rampa("ink", "slate_d", "slate"),
     "sangue": Rampa("red_d", "red_d", "red")}
M = {"g": colore("slate"), "p": colore("pink"), "E": colore("red"), "n": colore("pink"), "w": colore("yellow"),
     "m": colore("red_d")}
TESTA = {
    "down": [".pp.....pp.", "pggp...pggp", ".pgggggggp.", "..gEgggEg..", "..ggggggg..", "...ggggg...", "...gnnng...",
             "....www....", ".....w....."],
    "up": [".pp.....pp.", "pggp...pggp", ".pgggggggp.", "..ggggggg..", "..ggggggg..", "...ggggg...", "....ggg...."],
    "left": ["...pp......", "..pggp.....", ".gggggg....", "gEggggggg..", "ggggggggg..", "ngggggg....", ".wgggg.....",
             "..ww......."],
}
APERTA = {
    "down": TESTA["down"][:7] + ["...wmmmw...", "....mmm...."],
    "left": TESTA["left"][:5] + ["nggmmgg....", ".wmmmg.....", "..w.w......"],
}
B = dict(zampa=(2.0, 2.6, 0.9), corpo=(3.6, 4.0), coda="sottile", pancia=True, collo=1.8, muso=3)


def _ciuffi(tela, v, g, posa):
    """Ciuffi di pelo arruffato sul dorso."""
    def f():
        for k in range(5):
            base = g["anche"] + (g["spalle"] - g["anche"]) * (0.1 + k * 0.2) + g["su"] * 3.0
            tip = base + g["su"] * 1.6 + np.array([(k % 2 - 0.5) * 1.4, -0.6, 0])
            segmento(tela, v.xy(base), v.xy(tip), 0.9, 0.3, R["ciuffi"], "ciuffi", uniti=("corpo",))
    return (v.prof((g["anche"] + g["spalle"]) / 2) + 0.2, 1.5, f)


EXTRA = (_ciuffi,)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
