"""La lontra (fauna, specie `lontra`), a griglia: lunga e bassa, pelo bruno lucido bagnato, muso chiaro coi
baffi, occhietti neri, coda grossa che si assottiglia, zampe palmate. Si drizza a guardare; scappa scivolando."""
import sys

import numpy as np

from . import _bestia
from ..corpo import Quadrupede
from ..pixel import Rampa, colore, segmento

CORPO = Quadrupede(lungo=9.0, largo=1.8, zampa=(2.2, 2.2), collo=2.4, piedi_pari=True)
R = {"manto": Rampa("brown_dd", "brown_d", "brown"), "manto_scuro": Rampa("ink", "brown_dd", "brown_d"), "piede": Rampa("ink", "brown_dd", "brown_d"), "pancia": Rampa("brown", "tan", "cream"), "coda": Rampa("brown_dd", "brown_d", "brown"),
     "sangue": Rampa("red_d", "red_d", "red")}
M = {"b": colore("brown_d"), "t": colore("tan"), "c": colore("cream"), "E": colore("ink"), "K": colore("ink"), "w": colore("white")}
TESTA = {
    "down": [".b...b.", "bbbbbbb", "bEbbbEb", "bttttb.", "wtKKtw.", ".tttt.."],
    "up": [".b...b.", "bbbbbbb", "bbbbbbb", ".bbbbb."],
    "left": ["..bb..", ".bbbb.", "bEbbb.", "ttbb..", "Ktt...", ],
}
B = dict(zampa=(1.0, 1.2, 0.6), corpo=(2.2, 2.4), coda="folta", pancia=True, collo=1.6, muso=2)
EXTRA = ()

ANIM = _bestia.anim_fauna(giu=30, coda_su=10, balzo=2.0)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
