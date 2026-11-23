"""La pecora (fauna, specie `pecora`), a griglia: tonda di lana bianca soffice a riccioli, muso e zampe neri,
orecchie che pendono di lato. Bruca e bela; in fuga saltella goffa."""
import sys

import numpy as np

from . import _bestia
from ..corpo import Quadrupede
from ..pixel import Rampa, colore, segmento

CORPO = Quadrupede(lungo=9.0, largo=3.0, zampa=(4.0, 3.8), collo=3.0, piedi_pari=True)
R = {"manto": Rampa("grey_l", "white", "white"), "manto_scuro": Rampa("grey", "grey_l", "white"), "piede": Rampa("ink", "ink", "slate_d"), "lana": Rampa("grey", "grey_l", "white"),
     "sangue": Rampa("red_d", "red_d", "red")}
M = {"k": colore("ink"), "K": colore("slate_d"), "w": colore("white"), "E": colore("white")}
TESTA = {
    "down": [".wwwwwww.", "kkwwwwwkk", "k.kkkkk.k", "..kEkEk..", "..kkkkk..", "...kKk...", "....k...."],
    "up": [".wwwwwww.", "kkwwwwwkk", "k.wwwww.k", "..wwwww..", "...www..."],
    "left": ["...wwww..", "..wwwwwk.", "kkkkwwwkk", "kEkkkww..", "kkkkkw...", "Kkkk....."],
}
B = dict(zampa=(1.4, 1.6, 0.8), corpo=(5.0, 5.0), coda="corta", collo=2.0, muso=2)


def _riccioli(tela, v, g, posa):
    """I riccioli di lana: bozzi tondi su tutto il corpo."""
    def f():
        for k in range(8):
            t = (k % 4) / 3
            p = g["anche"] + (g["spalle"] - g["anche"]) * t + g["su"] * (3.0 + (k // 4) * 1.5) + \
                np.array([((k // 4) - 0.5) * 3.0, 0, 0])
            x, y = v.xy(p)
            segmento(tela, (x, y), (x, y), 1.6, 1.6, R["lana"], f"riccio{k}", uniti=("corpo",), separa=False)
    return (v.prof((g["anche"] + g["spalle"]) / 2) + 0.2, 1.5, f)


EXTRA = (_riccioli,)

ANIM = _bestia.anim_fauna(giu=55, coda_su=20, balzo=3.0)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
