"""Lo scoiattolo (fauna, specie `scoiattolo`), a griglia: piccolo e rosso fuoco, pancia bianca, orecchie a
pennello, coda enorme e folta piegata in su sopra la schiena. Rosicchia una ghianda; scappa a balzi."""
import sys

import numpy as np

from . import _bestia
from ..corpo import Quadrupede
from ..pixel import Rampa, colore, segmento

CORPO = Quadrupede(lungo=4.0, largo=1.4, zampa=(2.0, 2.4), collo=1.6, piedi_pari=True)
R = {"manto": Rampa("red_d", "rust", "orange"), "manto_scuro": Rampa("brown_dd", "red_d", "rust"), "piede": Rampa("red_d", "rust", "orange"), "pancia": Rampa("grey_l", "white", "white"), "coda": Rampa("red_d", "rust", "orange"), "punta": Rampa("rust", "orange", "amber"),
     "sangue": Rampa("red_d", "red_d", "red")}
M = {"o": colore("orange"), "r": colore("rust"), "w": colore("white"), "E": colore("ink"), "K": colore("ink")}
TESTA = {
    "down": ["r...r", "rorro", "oEoEo", "owwwo", ".wKw."],
    "up": ["r...r", "rorro", "ooooo", ".ooo."],
    "left": [".r.r.", ".oro.", "Eooo.", "wwo..", "K...."],
}
B = dict(zampa=(0.8, 1.0, 0.5), corpo=(1.8, 2.0), coda="folta", pancia=True, collo=1.0, muso=1, testa_dy=-1)
EXTRA = ()

ANIM = _bestia.anim_fauna(giu=20, coda_su=85, balzo=5.0)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
