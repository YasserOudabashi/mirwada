"""Lo scheletro delle catacombe (nemico_base, aspetto scheletro_catacombe), a griglia: ossa bianche sottili, costole
che si vedono, teschio con le orbite nere e un punto rosso negli occhi, una cintura di cuoio marcio, la spada corta
arrugginita. Scheletro e pose di Enel (i nemici umani: _umano_nemico.py), pezzi suoi."""
import sys

import numpy as np

from . import _umano_nemico, personaggio as P
from ..corpo import Umano
from ..pixel import Rampa, colore, segmento

CORPO = Umano(anca=11.0, busto=11.5, spalle=5.8, fianchi=2.4, braccio=5.6, avambraccio=5.0,
              coscia=5.6, stinco=5.6, piede=2.0, collo=1.4)
R = {"ossa": Rampa("grey", "grey_l", "white"), "cavo": Rampa("ink", "slate_d", "slate"),
     "pelle": Rampa("grey", "grey_l", "white"), "cuoio": Rampa("brown_dd", "brown_dd", "brown_d"),
     "ruggine": Rampa("brown_dd", "rust", "orange_d"), "sangue": Rampa("slate", "grey", "grey_l"),
     "luce": Rampa("red_d", "red", "pink")}
M = {"w": colore("white"), "g": colore("grey_l"), "K": colore("ink"), "E": colore("red")}
TESTA = {
    "down": ["...wwwwwww....", "..wwwwwwwwww..", ".wwwwwwwwwwgw.", ".wwwwwwwwwwwg.", ".wKKKwwwKKKwg.",
             ".wKKEwwwKEKwg.", ".wKKKwwwKKKgg.", "..wwwwKwwwwg..", "..gwwKKKwwgg..", "...wKwKwKwg...",
             "...gwgwgwg....", "....ggggg....."],
    "up": ["...wwwwwww....", "..wwwwwwwwww..", ".wwwwwwwwwwgw.", ".wwwwwwwwwwwg.", ".wwwwwwwwwwwg.",
           ".wwwwwwwwwwgg.", ".gwwwwwwwwwgg.", "..gwwwwwwwgg..", "...ggggggg....", "....ggggg....."],
    "left": ["....wwwwww....", "...wwwwwwwww..", "..wwwwwwwwwwg.", ".wwwwwwwwwwwg.", ".KKKwwwwwwwwg.",
             ".KEKwwwwwwwgg.", ".KKwwwwwwwwgg.", "Kwwwwwwwwwgg..", ".wKwKwwwwgg...", ".gwgwgwggg....",
             "..ggggg......."],
}
S = dict(P.S, falde=0, sciarpa=False, fiale=False, busto="cavo", braccio="ossa", avambraccio="ossa", gamba="ossa",
         piede="ossa", camicia=None, larghezza=(3.2, 4.6), spessore=0.55,
         arma=dict(manico=3.0, guardia=2.0, lama=13.0, spessa=(1.3, 1.0), punta=1.2, rampa="ruggine", elsa="cuoio",
                   metallo="ruggine"))


def _costole(tela, v, g, posa):
    """Quattro costole bianche sul petto scuro e la colonna in mezzo (da dietro solo la colonna)."""
    def f():
        for k in range(4):
            c = g["bacino"] + g["su"] * (5.0 + k * 1.7)
            larga = 3.6 - abs(k - 1.5) * 0.4
            if v.dir in ("down", "up"):
                segmento(tela, v.xy(c - g["destra"] * larga), v.xy(c + g["destra"] * larga), 0.6, 0.6, R["ossa"],
                         "costole", separa=False)
            else:
                segmento(tela, v.xy(c - np.cross(g["su"], g["destra"]) * 1.6), v.xy(c), 0.6, 0.6, R["ossa"], "costole",
                         separa=False)
        segmento(tela, v.xy(g["bacino"]), v.xy(g["collo"]), 0.7, 0.7, R["ossa"], "colonna", separa=False)
    return (v.prof(g["bacino"]) + 0.05, 1.1, f)


EXTRA = (_costole,)
ANIM = _umano_nemico.anim_nemico()


def disegna(tela, v, g, posa):
    P.disegna(tela, v, g, posa, st=sys.modules[__name__])
