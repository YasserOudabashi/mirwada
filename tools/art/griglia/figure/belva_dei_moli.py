"""La belva dei moli (nemico_base, aspetto belva_dei_moli), a griglia: un cane enorme e rognoso che vive sotto le
banchine, pelo giallastro a chiazze scure, collare di catena spezzata col lucchetto, orecchie mozze, muso largo con
la bava, occhi gialli. Pose del lupo della luna (bestie)."""
import sys

import numpy as np

from . import _bestia
from .lupo_della_luna import ANIM
from ..corpo import Quadrupede
from ..pixel import Rampa, colore, segmento

CORPO = Quadrupede(lungo=15.0, largo=3.8, zampa=(6.0, 5.8), collo=4.0, piedi_pari=True)
R = {"manto": Rampa("brown", "tan", "cream"), "manto_scuro": Rampa("brown_d", "brown", "tan"),
     "piede": Rampa("brown_d", "brown", "tan"), "pancia": Rampa("tan", "cream", "white"),
     "chiazze": Rampa("brown_dd", "brown_d", "brown"), "catena": Rampa("slate_d", "slate", "grey"),
     "sangue": Rampa("red_d", "red_d", "red")}
M = {"t": colore("tan"), "b": colore("brown"), "B": colore("brown_d"), "E": colore("yellow"), "K": colore("ink"),
     "w": colore("white"), "m": colore("red_d")}
TESTA = {
    "down": ["bb.......bb", "btbbtttbbtb", ".tttttttttt", "ttEKtttKEtt", "ttttttttttt", ".ttbbbbbtt.", ".tbKKKKKbt.",
             "..tbbbbbt..", "...w...w..."],
    "up": ["bb.......bb", "btbbtttbbtb", ".tttttttttt", "ttttbbbtttt", "ttttttttttt", ".ttttttttt.", "..ttttttt.."],
    "left": ["....bb.....", "...btbtt...", "..tEKtttt..", ".tttttttb..", "Kttttttb...", "bbbbtttb...", ".wmwbtb....",
             "..w.w......"],
}
APERTA = {
    "down": TESTA["down"][:5] + [".ttmmmmmtt.", ".tmwmwmwmt.", "..tmmmmmt..", "...w...w..."],
    "left": TESTA["left"][:5] + ["bmmmmtb....", ".wmwmtb....", "..mmm......"],
}
B = dict(zampa=(2.8, 3.4, 1.3), corpo=(4.8, 6.4), coda="corta", pancia=True, collo=2.6, muso=3)


def _chiazze_catena(tela, v, g, posa):
    def f():
        if v.dir != "down":
            for k, t in enumerate((0.25, 0.55, 0.8)):
                p = g["anche"] + (g["spalle"] - g["anche"]) * t + g["su"] * 2.5 + np.array([(k % 2 - 0.5) * 2, 0, 0])
                x, y = v.xy(p)
                segmento(tela, (x, y), (x + 1.5, y), 1.4, 1.2, R["chiazze"], f"chiazza{k}", separa=False)
        c = v.xy(g["collo"])
        segmento(tela, (c[0] - 3, c[1] + 1), (c[0] + 3, c[1] + 1), 0.9, 0.9, R["catena"], "collare")
        segmento(tela, (c[0] + 1, c[1] + 2), (c[0] + 2, c[1] + 6), 0.5, 0.5, R["catena"], "collare",
                 uniti=("collare",), separa=False)
    return (v.prof(g["collo"]) + 0.5, 2.5, f)


EXTRA = (_chiazze_catena,)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
