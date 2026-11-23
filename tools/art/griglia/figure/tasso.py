"""Il tasso (fauna, specie `tasso`), a griglia: basso e largo, pelo grigio argento, testa bianca con le due
strisce nere dal naso alle orecchie, zampe corte nere con gli unghioni. Scava; in fuga corre a testa bassa."""
import sys

import numpy as np

from . import _bestia
from ..corpo import Quadrupede
from ..pixel import Rampa, colore, segmento

CORPO = Quadrupede(lungo=8.0, largo=2.8, zampa=(2.4, 2.4), collo=1.8, piedi_pari=True)
R = {"manto": Rampa("slate", "grey", "grey_l"), "manto_scuro": Rampa("slate_d", "slate", "grey"), "piede": Rampa("ink", "ink", "slate_d"),
     "sangue": Rampa("red_d", "red_d", "red")}
M = {"w": colore("white"), "k": colore("ink"), "g": colore("grey"), "E": colore("ink"), "n": colore("ink")}
TESTA = {
    "down": ["g.......g", "gwkkwkkwg", ".wkkwkkw.", ".wkEwEkw.", "..wkwkw..", "...wnw..."],
    "up": ["g.......g", "ggkkgkkgg", ".gkkgkkg.", ".ggggggg.", "..ggggg.."],
    "left": ["...gg...", "..wkkgg.", ".wkEkgg.", "wwkkgg..", "nwwg....", ],
}
B = dict(zampa=(1.8, 2.0, 0.9), corpo=(3.6, 4.0), coda="corta", muso=2)
EXTRA = ()

ANIM = _bestia.anim_fauna(giu=40, coda_su=10, balzo=1.5)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
