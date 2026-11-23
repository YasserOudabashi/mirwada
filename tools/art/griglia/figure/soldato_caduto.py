"""Il soldato caduto delle Marche (nemico_base, aspetto soldato_caduto), a griglia: un'anima in armatura, elmo chiuso
col cimiero rosso, dalla fessura due occhi azzurri che brillano, il mento di luce spettrale; tabarda blu strappata,
scudo tondo di legno col bordo di ferro, spada a una mano scheggiata. Scheletro e pose di Enel, pezzi suoi."""
import sys

import numpy as np

from . import _umano_nemico, personaggio as P
from ..corpo import Umano
from ..pixel import Rampa, colore, segmento

CORPO = Umano(anca=11.0, busto=12.5, spalle=7.0, fianchi=3.0, braccio=5.4, avambraccio=5.0,
              coscia=5.4, stinco=5.4, piede=2.4, collo=0.4)
R = {"pelle": Rampa("slate", "grey", "grey_l"), "armatura": Rampa("slate_d", "slate", "grey"),
     "tabarda": Rampa("navy", "blue_d", "blue"), "cuoio": Rampa("brown_dd", "brown_d", "brown"),
     "lama": Rampa("slate", "grey", "grey_l", riflesso="white"), "ferro": Rampa("slate_d", "grey", "grey_l"),
     "scudo": Rampa("brown_dd", "brown_d", "brown"), "sangue": Rampa("blue_d", "blue", "cyan"),
     "luce": Rampa("blue", "cyan", "white")}
M = {"G": colore("grey"), "g": colore("grey_l"), "K": colore("ink"), "E": colore("cyan"), "c": colore("blue"),
     "r": colore("red")}
TESTA = {
    "down": ["......rr......", ".....rrrr.....", "...gGGrrGGg...", "..gGGGGGGGGg..", ".gGGGGGGGGGGg.",
             ".GGKKKKKKKKGG.", ".GGKEKKKKEKGG.", ".GGKKKGKKKKGG.", ".GGGGcGcGGGGG.", "..GGcccccccG..",
             "...GcccccG....", "....GGGGG....."],
    "up": ["......rr......", ".....rrrr.....", "...gGGrrGGg...", "..gGGGGrGGGg..", ".gGGGGGrGGGGg.",
           ".GGGGGGrGGGGG.", ".GGGGGGGGGGGG.", ".GGGGGGGGGGGG.", ".gGGGGGGGGGGg.", "..GGGGGGGGGG..",
           "...GGGGGGG...."],
    "left": ["........rr....", ".......rrrr...", ".....gGGrrGg..", "....gGGGGGGGg.", "...gGGGGGGGGG.",
             "..KKKKKKGGGGG.", "..KEKKKKGGGGG.", "..KKKKGGGGGGG.", "...GcGGGGGGG..", "..cccccGGGG...",
             "...ccccGGG....", "....GGGG......"],
}
S = dict(P.S, falde=4.0, sciarpa=False, fiale=False, busto="tabarda", braccio="armatura", avambraccio="armatura",
         gamba="armatura", piede="armatura", camicia="armatura", larghezza=(5.8, 7.0),
         arma=dict(manico=3.4, guardia=2.8, lama=15.0, spessa=(1.5, 1.1), punta=1.4, rampa="lama", elsa="cuoio",
                   metallo="ferro"))


def _scudo(tela, v, g, posa):
    """Lo scudo tondo sull'avambraccio sinistro: legno, bordo e umbone di ferro."""
    c = (g["gomito_l"] + g["mano_l"]) / 2 + np.cross(g["su"], g["destra"]) * 0.8

    def f():
        x, y = v.xy(c)
        segmento(tela, (x, y), (x, y), 4.6, 4.6, R["ferro"], "scudo")
        segmento(tela, (x, y), (x, y), 3.7, 3.7, R["scudo"], "scudo", uniti=("scudo",), separa=False)
        segmento(tela, (x - 0.4, y - 0.4), (x - 0.4, y - 0.4), 1.2, 1.2, R["ferro"], "scudo", uniti=("scudo",),
                 separa=False)
    return (v.prof(c) + 0.5, 2.2, f)


EXTRA = (_scudo,)
ANIM = _umano_nemico.anim_nemico()


def disegna(tela, v, g, posa):
    P.disegna(tela, v, g, posa, st=sys.modules[__name__])
