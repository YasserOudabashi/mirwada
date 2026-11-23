"""Il cane (fauna, specie `cane`), a griglia: cane da pastore di taglia media, pelo bianco e marrone, orecchie
morbide che cadono, lingua fuori, coda folta che scodinzola, collare rosso. Annusa; corre via abbaiando."""
import sys

import numpy as np

from . import _bestia
from ..corpo import Quadrupede
from ..pixel import Rampa, colore, segmento

CORPO = Quadrupede(lungo=10.0, largo=2.6, zampa=(4.4, 4.2), collo=3.2, piedi_pari=True)
R = {"manto": Rampa("brown_d", "brown", "tan"), "manto_scuro": Rampa("brown_dd", "brown_d", "brown"), "piede": Rampa("grey", "grey_l", "white"), "pancia": Rampa("grey", "grey_l", "white"), "coda": Rampa("brown_d", "brown", "tan"), "punta": Rampa("grey", "grey_l", "white"), "collare": Rampa("red_d", "red", "pink"),
     "sangue": Rampa("red_d", "red_d", "red")}
M = {"b": colore("brown"), "B": colore("brown_d"), "w": colore("white"), "E": colore("ink"), "K": colore("ink"), "l": colore("pink")}
TESTA = {
    "down": ["BB.....BB", "BbbbwbbbB", "BbEbwbEbB", ".bbwwwbb.", "..wwKww..", "..wwwww..", "...wlw..."],
    "up": ["BB.....BB", "BbbbbbbbB", ".bbbbbbb.", ".bbbbbbb.", "..bbbbb.."],
    "left": ["...BB....", "..BbbB...", ".bEbbbB..", "wwwbbB...", "Kwwwb....", ".wlw....."],
}
B = dict(zampa=(1.8, 2.2, 0.9), corpo=(3.2, 3.6), coda="folta", pancia=True, collo=2.0, muso=2)
EXTRA = ()

ANIM = _bestia.anim_fauna(giu=50, coda_su=60, balzo=3.0)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
