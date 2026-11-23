"""Lo scaricatore ubriaco del porto (nemico_base, aspetto scaricatore_ubriaco), a griglia: grosso e pesante,
pelato, naso rosso, barba ispida, occhi lucidi, canottiera bianca macchiata sulla pancia, braccia nude con le
cinghie, pantaloni di tela blu con le bretelle, una bottiglia verde rotta come arma. Scheletro e pose di Enel."""
import sys

import numpy as np

from . import _umano_nemico, personaggio as P
from ..corpo import Umano
from ..pixel import Rampa, colore, segmento

CORPO = Umano(anca=9.5, busto=12.5, spalle=7.6, fianchi=3.6, braccio=5.8, avambraccio=5.2, coscia=5.0, stinco=4.8, piede=2.6, collo=0.2)
R = {"pelle": Rampa("brown", "skin_m", "skin_l"), "canotta": Rampa("grey", "grey_l", "white"),
     "tela": Rampa("navy", "blue_d", "blue"), "stivali": Rampa("brown_dd", "brown_d", "brown"),
     "vetro": Rampa("teal_d", "green_m", "green", riflesso="white"), "bretelle": Rampa("red_d", "red_d", "red"),
     "cuoio": Rampa("brown_dd", "brown_d", "brown"), "sangue": Rampa("red_d", "red_d", "red"),
     "luce": Rampa("blue", "cyan", "white")}
M = {"S": colore("skin_m"), "s": colore("skin_l"), "d": colore("brown"), "K": colore("ink"), "r": colore("red"), "b": colore("brown_d"), "w": colore("white"), "E": colore("grey")}
TESTA = {
    "down": ["....dSSSSd....", "...dSsSSSSSd..", "..dSsSSSSSSSd.", "..SSSSSSSSSSS.", "..SKKSSSSKKSS.", "..SwESSSSEwSd.", "..SSSSrrSSSSd.", "..bSSSrrSSSbd.", "..bbbSSSSbbbd.", "...bbbKKbbbb..", "....bbbbbbb..."],
    "up": ["....dSSSSd....", "...dSsSSSSSd..", "..dSsSSSSSSSd.", "..SSSSSSSSSSS.", "..SSSSSSSSSSS.", "..SSSSSSSSSSd.", "..dSSSSSSSSdd.", "...dSSSSSSdd..", "....bbbbbbb..."],
    "left": ["....dSSSSd....", "...SsSSSSSSd..", "..SsSSSSSSSSd.", "..SSSSSSSSSSd.", "..KKSSSSSSSSd.", "..wESSSSSSSdd.", ".rrSSSSSSSSd..", ".rrbSSSSSSd...", "..bbbbSSSd....", "..KbbbbbS.....", "...bbbbb......"],
}
S = dict(P.S, falde=0, sciarpa=False, fiale=False, busto="canotta", braccio="pelle", avambraccio="pelle", gamba="tela", piede="stivali", camicia="bretelle", larghezza=(7.0, 7.6), spessore=1.2,
         arma=dict(manico=3.4, guardia=0, lama=7.0, spessa=(2.0, 1.4), punta=1.4, rampa="vetro", elsa="vetro", metallo="vetro"))
EXTRA = ()

ANIM = _umano_nemico.anim_nemico()


def disegna(tela, v, g, posa):
    P.disegna(tela, v, g, posa, st=sys.modules[__name__])
