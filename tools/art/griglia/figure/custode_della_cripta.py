"""Il custode della cripta (nemico_base, aspetto custode_della_cripta), a griglia: guardiano alto e lento avvolto
nelle bende ingiallite, una maschera d'oro funeraria con gli occhi vuoti verdi, un collare di pietra con le rune,
le braccia lunghe; brandisce una mazza di pietra pesante a due mani. Scheletro e pose di Enel."""
import sys

import numpy as np

from . import _umano_nemico, personaggio as P
from ..corpo import Umano
from ..pixel import Rampa, colore, segmento

CORPO = Umano(anca=12.5, busto=13.5, spalle=6.8, fianchi=2.8, braccio=6.2, avambraccio=5.8, coscia=6.0, stinco=6.0, piede=2.4, collo=1.0)
R = {"pelle": Rampa("tan", "cream", "white"), "bende": Rampa("brown", "tan", "cream"),
     "pietra": Rampa("slate_d", "slate", "grey"), "oro": Rampa("orange_d", "amber", "yellow", riflesso="white"),
     "legno": Rampa("brown_dd", "brown_d", "brown"),
     "cuoio": Rampa("brown_dd", "brown_d", "brown"), "sangue": Rampa("red_d", "red_d", "red"),
     "luce": Rampa("blue", "cyan", "white")}
M = {"b": colore("tan"), "B": colore("brown"), "Y": colore("amber"), "y": colore("yellow"), "o": colore("orange_d"), "K": colore("ink"), "E": colore("green")}
TESTA = {
    "down": ["...bbBbbbB....", "..bBbbbbBbbb..", ".bbbYYYYYYbbb.", ".bbYyYYYYyYbb.", ".bBYKEYYEKYBb.", ".bbYYYYYYYYbb.", ".bbYYYooYYYbb.", ".bbbYoooooYbb.", "..bbbYYYYbbb..", "...bBbbbBbb..."],
    "up": ["...bbBbbbB....", "..bBbbbbBbbb..", ".bbbbbBbbbbbb.", ".bbBbbbbbBbbb.", ".bbbbBbbbbbBb.", ".bBbbbbbBbbbb.", ".bbbbbBbbbbbb.", "..bbBbbbbBbb..", "...bbbbbbbb..."],
    "left": ["....bbBbbB....", "...bBbbbbBbb..", "..YYYYYbbbbbb.", "..YyYYYbbBbbb.", "..KEYYYbbbbbb.", ".YYYYYYbBbbb..", "..YooYYbbbbb..", "..ooooYbbBb...", "...YYYbbbb....", "....bBbbb....."],
}
S = dict(P.S, falde=0, sciarpa=False, fiale=False, busto="bende", braccio="bende", avambraccio="bende", gamba="bende", piede="bende", camicia=None, larghezza=(5.2, 6.4), spessore=1.0,
         arma=dict(manico=7.0, guardia=0, lama=15.0, spessa=(1.0, 4.2), punta=0, rampa="pietra", elsa="legno", metallo="pietra"))


def _collare(tela, v, g, posa):
    """Il collare di pietra con le rune intorno al collo."""
    def f():
        c = v.xy(g["collo"] - g["su"] * 0.8)
        segmento(tela, (c[0] - 5, c[1]), (c[0] + 5, c[1]), 1.6, 1.6, R["pietra"], "collare")
        for k in (-3, 0, 3):
            segmento(tela, (c[0] + k, c[1]), (c[0] + k, c[1]), 0.5, 0.5, R["oro"], "rune", separa=False)
    return (v.prof(g["bacino"]) + 0.4, 1.4, f)


EXTRA = (_collare,)

ANIM = _umano_nemico.anim_nemico(True)


def disegna(tela, v, g, posa):
    P.disegna(tela, v, g, posa, st=sys.modules[__name__])
