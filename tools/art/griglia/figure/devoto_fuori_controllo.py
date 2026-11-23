"""Il devoto fuori controllo (nemico_base, aspetto devoto_fuori_controllo), a griglia: monaco fanatico con la
tonsura, occhi spiritati bianchi, bocca aperta che urla, saio bianco sporco e strappato, cordone rosso alla vita,
piedi nudi; agita un turibolo di ottone fumante come una mazza (la catena e la sfera). Scheletro e pose di Enel."""
import sys

import numpy as np

from . import _umano_nemico, personaggio as P
from ..corpo import Umano
from ..pixel import Rampa, colore, segmento

CORPO = Umano(anca=10.5, busto=12.0, spalle=6.0, fianchi=3.0, braccio=5.4, avambraccio=5.0, coscia=5.2, stinco=5.2, piede=2.2, collo=0.6)
R = {"pelle": Rampa("skin_m", "skin_l", "cream"), "saio": Rampa("grey", "grey_l", "white"),
     "cordone": Rampa("red_d", "red", "pink"), "catena": Rampa("slate", "grey", "grey_l"),
     "ottone": Rampa("orange_d", "amber", "yellow", riflesso="white"), "fumo": Rampa("grey", "grey_l", "white"),
     "cuoio": Rampa("brown_dd", "brown_d", "brown"), "sangue": Rampa("red_d", "red_d", "red"),
     "luce": Rampa("blue", "cyan", "white")}
M = {"H": colore("brown_d"), "S": colore("skin_l"), "d": colore("skin_m"), "K": colore("ink"), "w": colore("white"), "m": colore("red_d"), "E": colore("white")}
TESTA = {
    "down": ["....SSSSSS....", "...SSSSSSSS...", "..HSSSSSSSSH..", "..HHSSSSSSHH..", "..SKKSSSSKKS..", "..SKwSSSSwKS..", "..SSSSddSSSd..", "..SSSKmmKSSd..", "...SSmmmmSd...", "....dddddd...."],
    "up": ["....SSSSSS....", "...SSSSSSSS...", "..HSSSSSSSSH..", "..HHHHHHHHHH..", "..HHHHHHHHHH..", "..HHHHHHHHHH..", "...HHHHHHHH...", "....dddddd...."],
    "left": ["....SSSSSS....", "...SSSSSSSS...", "..SSSSSSSSHH..", "..SSSSSSHHHH..", "..KKSSSSHHHH..", "..wKSSSSHHHH..", ".SSSSSSdHHH...", "..KmmSSSdH....", "..mmmSSSd.....", "...dddddd....."],
}
S = dict(P.S, falde=10.0, sciarpa=False, fiale=False, busto="saio", braccio="saio", avambraccio="pelle", gamba="saio", piede="pelle", camicia="cordone", larghezza=(5.6, 6.0),
         arma=dict(manico=1.0, guardia=0, lama=9.0, spessa=(0.4, 0.4), punta=0, rampa="catena", elsa="catena", metallo="catena"))


def _turibolo(tela, v, g, posa):
    """La sfera di ottone traforata in fondo alla catena, con il fumo che esce."""
    d = g["arma_dir"]
    tip = g["mano_r"] - d * 2.6 + d * 10.5

    def f():
        x, y = v.xy(tip)
        segmento(tela, (x, y), (x, y), 2.8, 2.8, R["ottone"], "turibolo")
        for k in range(3):
            segmento(tela, (x - 1 + k, y - 3 - k * 2), (x - 1 + k, y - 3 - k * 2), 1.0, 1.0, R["fumo"], "fumo",
                     separa=False)
    return (v.prof(tip) + 0.2, 2.6, f)


EXTRA = (_turibolo,)

ANIM = _umano_nemico.anim_nemico()


def disegna(tela, v, g, posa):
    P.disegna(tela, v, g, posa, st=sys.modules[__name__])
