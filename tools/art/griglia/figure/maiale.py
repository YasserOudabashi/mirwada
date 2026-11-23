"""Il maiale (fauna, specie `maiale`), a griglia: rosa e tondo, grugno grosso con due narici, orecchie a
punta che cadono sugli occhi, coda a ricciolo, zampe corte con gli zoccoli. Grufola; in fuga trotterella."""
import sys

import numpy as np

from . import _bestia
from ..corpo import Quadrupede
from ..pixel import Rampa, colore, segmento

CORPO = Quadrupede(lungo=10.0, largo=3.4, zampa=(3.0, 2.8), collo=2.0, piedi_pari=True)
R = {"manto": Rampa("red_d", "pink", "skin_l"), "manto_scuro": Rampa("red_d", "red_d", "pink"), "piede": Rampa("brown_dd", "brown_d", "brown"), "coda": Rampa("red_d", "pink", "skin_l"),
     "sangue": Rampa("red_d", "red_d", "red")}
M = {"p": colore("pink"), "P": colore("red_d"), "s": colore("skin_l"), "E": colore("ink"), "K": colore("ink")}
TESTA = {
    "down": ["PP.....PP", "pPP...PPp", "ppppppppp", "ppEpppEpp", "pppssspp.", ".psKsKsp.", "..sssss.."],
    "up": ["PP.....PP", "pPP...PPp", "ppppppppp", "ppppppppp", ".ppppppp.", "..ppppp.."],
    "left": ["...PP....", "..pPPp...", ".ppPpppp.", "pEppppp..", "sspppp...", "Ksspp....", ".ss......"],
}
B = dict(zampa=(2.0, 2.4, 1.0), corpo=(4.6, 4.8), coda="sottile", muso=2)
EXTRA = ()

ANIM = _bestia.anim_fauna(giu=40, coda_su=50, balzo=1.8)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
