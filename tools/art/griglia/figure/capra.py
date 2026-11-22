"""La capra di montagna (fauna, specie `capra`), a griglia: bianca e lanosa, corna grigie a falce piegate indietro,
barbetta, zoccoli scuri, coda corta. Da ferma bruca e si guarda intorno; in fuga salta alto da roccia a roccia."""
import sys

from . import _bestia
from ..corpo import Quadrupede
from ..pixel import Rampa, colore

CORPO = Quadrupede(lungo=10.0, largo=2.4, zampa=(5.2, 5.0), collo=4.5, piedi_pari=True)
R = {"manto": Rampa("grey", "grey_l", "white"), "manto_scuro": Rampa("slate", "grey", "grey_l"),
     "piede": Rampa("ink", "slate_d", "slate"), "sangue": Rampa("red_d", "red_d", "red")}
M = {"h": colore("slate"), "w": colore("white"), "g": colore("grey_l"), "E": colore("ink"), "n": colore("slate_d")}
TESTA = {
    "down": [".hh.....hh.", "h..h...h..h", "...hh.hh...", "..gwwwwwg..", ".gwEwwwEwg.", "..wwwwwww..", "..gwwwwwg..",
             "...wwnww...", "....ggg....", "....ggg....", ".....g....."],
    "up": [".hh.....hh.", "h..h...h..h", "...hh.hh...", "..gwwwwwg..", ".gwwwwwwwg.", "..wwwwwww..", "..gwwwwwg..",
           "...ggggg..."],
    "left": ["....hhh....", "...h...h...", "......hh...", ".....wwh...", "...wwwwww..", "..wEwwwwg..", ".wwwwwwwg..",
             "nwwwwwgg...", ".wgwgg.....", "..g........"],
}
B = dict(zampa=(2.2, 2.6, 1.0), corpo=(3.6, 3.8), coda="corta", collo=2.2, muso=2, testa_dy=-1)
ANIM = _bestia.anim_fauna(giu=60, coda_su=70, balzo=6.0)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
