"""La guardia corrotta di Mirwada (nemico_base, aspetto guardia_corrotta), a griglia: elmo a cresta di ferro, baffi
neri a punta, occhi piccoli e avidi, tabarda rossa col sole di Mirwada stinto, cotta di maglia grigia sotto, guanti
di cuoio, stivali alti; un'alabarda (asta lunga con la scure e la punta). Scheletro e pose di Enel."""
import sys

import numpy as np

from . import _umano_nemico, personaggio as P
from ..corpo import Umano
from ..pixel import Rampa, colore, segmento

CORPO = Umano(anca=11.0, busto=12.6, spalle=6.8, fianchi=3.0, braccio=5.4, avambraccio=5.0, coscia=5.4, stinco=5.4, piede=2.4, collo=0.4)
R = {"pelle": Rampa("skin_m", "skin_l", "cream"), "tabarda": Rampa("red_d", "red", "pink"),
     "maglia": Rampa("slate_d", "slate", "grey"), "stivali": Rampa("brown_dd", "brown_d", "brown"),
     "asta": Rampa("brown_dd", "brown_d", "brown"), "ferro": Rampa("slate", "grey", "grey_l", riflesso="white"),
     "oro": Rampa("orange_d", "amber", "yellow"),
     "cuoio": Rampa("brown_dd", "brown_d", "brown"), "sangue": Rampa("red_d", "red_d", "red"),
     "luce": Rampa("blue", "cyan", "white")}
M = {"I": colore("grey"), "i": colore("grey_l"), "k": colore("slate"), "K": colore("ink"), "S": colore("skin_l"), "d": colore("skin_m"), "E": colore("brown_d"), "b": colore("ink")}
TESTA = {
    "down": ["......ii......", "....iIIIIi....", "..kIIIIIIIIk..", ".kIIIIIIIIIIk.", "kkkkkkkkkkkkkk", "..SKKSSSSKKS..", "..SSESSSSESd..", "..SSSSddSSSd..", ".bbbbSSSSbbbb.", "...dSSKKSSd...", "....dddddd...."],
    "up": ["......ii......", "....iIIIIi....", "..kIIIIIIIIk..", ".kIIIIIIIIIIk.", "kkkkkkkkkkkkkk", "..IIIIIIIIIIk.", "..kIIIIIIIIkk.", "...dSSSSSSdd..", "....dddddd...."],
    "left": [".......ii.....", ".....iIIIIi...", "...kIIIIIIIIk.", "..kIIIIIIIIIIk", "kkkkkkkkkkkkk.", "..KKSSSSIIIk..", "..SESSSSIIIk..", ".SSSSSSdIIk...", "bbbbSSSSdk....", "..KSSSSSd.....", "...dddddd....."],
}
S = dict(P.S, falde=5.0, sciarpa=False, fiale=False, busto="tabarda", braccio="maglia", avambraccio="stivali", gamba="maglia", piede="stivali", camicia="maglia", larghezza=(5.8, 6.8),
         arma=dict(manico=10.0, guardia=0, lama=24.0, spessa=(0.8, 0.8), punta=3.0, rampa="asta", elsa="asta", metallo="ferro"))


def _scure(tela, v, g, posa):
    """La scure e la punta di ferro in cima all'asta dell'alabarda."""
    d = g["arma_dir"]
    pomo = g["mano_r"] - d * 2.6
    tip = pomo + d * 24.0
    perp = np.cross(d, np.array([0, 0, 1.0]))
    if np.linalg.norm(perp) < 0.2:
        perp = np.cross(d, np.array([0, 1.0, 0]))
    perp /= np.linalg.norm(perp)

    def f():
        a, b = v.xy(tip - d * 4.5 + perp * 0.5), v.xy(tip - d * 1.0 + perp * 3.6)
        segmento(tela, a, b, 1.8, 2.6, R["ferro"], "scure", uniti=("arma",))
        segmento(tela, v.xy(tip), v.xy(tip + d * 3.0), 1.0, 0.3, R["ferro"], "scure", uniti=("arma", "scure"))
    return (v.prof(tip) + 0.2, 2.6, f)


EXTRA = (_scure,)

ANIM = _umano_nemico.anim_nemico()


def disegna(tela, v, g, posa):
    P.disegna(tela, v, g, posa, st=sys.modules[__name__])
