"""La mucca (fauna, specie `mucca`), a griglia: grossa e tranquilla, bianca a grandi macchie nere, muso rosa,
corna corte chiare, campanaccio al collo, coda col fiocco. Rumina; se spaventata trotta via pesante."""
import sys

import numpy as np

from . import _bestia
from ..corpo import Quadrupede
from ..pixel import Rampa, colore, segmento

CORPO = Quadrupede(lungo=15.0, largo=4.0, zampa=(6.0, 5.6), collo=4.0, piedi_pari=True)
R = {"manto": Rampa("grey", "grey_l", "white"), "manto_scuro": Rampa("slate", "grey", "grey_l"), "piede": Rampa("ink", "slate_d", "slate"), "macchie": Rampa("ink", "ink", "slate_d"), "punta": Rampa("ink", "ink", "slate_d"), "campana": Rampa("orange_d", "amber", "yellow"),
     "sangue": Rampa("red_d", "red_d", "red")}
M = {"w": colore("white"), "g": colore("grey_l"), "k": colore("ink"), "p": colore("pink"), "c": colore("cream"), "E": colore("ink")}
TESTA = {
    "down": ["c.........c", "cc.wwkww.cc", ".wwkkwwwww.", ".wEkkwwwEw.", "..wwwwwww..", "..ppppppp..", "..pkpppkp..", "...ppppp..."],
    "up": ["c.........c", "cc.wwkww.cc", ".wwkkwwwww.", ".wwkkwwwww.", "..wwwwwww..", "...wwwww..."],
    "left": ["...c.....", "..cwwkk..", ".wwwkkkw.", ".wEwwkkw.", "wwwwwwww.", "pppwwww..", "pkppww...", ".ppp....."],
}
B = dict(zampa=(2.8, 3.4, 1.2), corpo=(5.4, 5.8), coda="fiocco", collo=3.0, muso=2)


def _macchie(tela, v, g, posa):
    """Macchie nere sul fianco e il campanaccio d'ottone al collo."""
    def f():
        for k, (t, a, r) in enumerate(((0.2, 1.5, 2.2), (0.55, -1.0, 2.6), (0.8, 2.0, 1.6))):
            p = g["anche"] + (g["spalle"] - g["anche"]) * t + g["su"] * a + np.array([0, 0, 0])
            x, y = v.xy(p)
            segmento(tela, (x, y), (x + 1.2, y + 0.5), r, r * 0.8, R["macchie"], f"macchia{k}", separa=False)
        c = v.xy(g["collo"] - g["su"] * 3.0)
        segmento(tela, c, (c[0], c[1] + 1.5), 1.4, 1.8, R["campana"], "campana")
    return (v.prof((g["anche"] + g["spalle"]) / 2) + 0.2, 1.5, f)


EXTRA = (_macchie,)

ANIM = _bestia.anim_fauna(giu=55, coda_su=30, balzo=1.5, raccolto=0.7)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
