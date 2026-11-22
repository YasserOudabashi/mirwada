"""L'orso bruno (fauna, specie `orso`), a griglia: grosso e pesante, gobba sulle spalle, orecchie tonde, muso chiaro
col naso nero, zampe larghe. Da fermo annusa l'aria alzando il muso; in fuga corre goffo e dondolante."""
import sys

from . import _bestia
from ..corpo import Quadrupede
from ..pixel import Rampa, colore

CORPO = Quadrupede(lungo=12.0, largo=3.8, zampa=(5.0, 4.8), collo=2.5, piedi_pari=True)
R = {"manto": Rampa("brown_dd", "brown_d", "brown"), "manto_scuro": Rampa("ink", "brown_dd", "brown_d"),
     "piede": Rampa("ink", "brown_dd", "brown_d"), "sangue": Rampa("red_d", "red_d", "red")}
M = {"b": colore("brown_d"), "B": colore("brown_dd"), "t": colore("tan"), "E": colore("ink"), "K": colore("ink")}
TESTA = {
    "down": [".bb......bb.", "bBBb....bBBb", "bBbbbbbbbbBb", ".bbbbbbbbbb.", "bbEbbbbbbEbb", "bbbbttttbbbb",
             "bbbttKKttbbb", ".bbttttttbb.", "..bbttttbb..", "....bbbb...."],
    "up": [".bb......bb.", "bBBb....bBBb", "bBbbbbbbbbBb", ".bbbbbbbbbb.", "bbbbbbbbbbbb", "bbbbbbbbbbbb",
           ".bbbbbbbbbb.", "..bbbbbbbb..", "....bbbb...."],
    "left": [".....bb.....", "....bBBb....", "...bbbbbbb..", "..bEbbbbbbB.", ".tbbbbbbbbB.", "ttttbbbbbBB.",
             "Kttttbbbbb..", ".ttttbbbb...", "..bbbbbb...."],
}
B = dict(zampa=(3.0, 3.4, 1.5), corpo=(5.4, 6.6), coda="corta", muso=3, testa_dy=1)
ANIM = _bestia.anim_fauna(giu=30, coda_su=30, balzo=1.5, raccolto=0.7, testa_alta=-20)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
