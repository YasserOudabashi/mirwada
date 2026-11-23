"""Il tagliaborse dei bassifondi (nemico_base, aspetto tagliaborse), a griglia: magro e svelto, cappuccio grigio
scuro calato sulla fronte, fazzoletto nero sul naso, occhi gialli furbi, giubba di cuoio rattoppata, pantaloni scuri,
piedi fasciati, coltello corto curvo. Scheletro e pose di Enel, pezzi suoi."""
import sys

import numpy as np

from . import _umano_nemico, personaggio as P
from ..corpo import Umano
from ..pixel import Rampa, colore, segmento

CORPO = Umano(anca=10.5, busto=11.0, spalle=5.6, fianchi=2.4, braccio=5.6, avambraccio=5.2, coscia=5.6, stinco=5.6, piede=2.2, collo=0.6)
R = {"pelle": Rampa("skin_m", "skin_l", "cream"), "giubba": Rampa("brown_dd", "brown_d", "brown"),
     "cappuccio": Rampa("ink", "slate_d", "slate"), "pantaloni": Rampa("ink", "navy", "slate_d"),
     "fasce": Rampa("grey", "grey_l", "white"), "lama": Rampa("slate", "grey", "grey_l", riflesso="white"),
     "cuoio": Rampa("brown_dd", "brown_d", "brown"), "sangue": Rampa("red_d", "red_d", "red"),
     "luce": Rampa("blue", "cyan", "white")}
M = {"C": colore("slate_d"), "c": colore("slate"), "K": colore("ink"), "S": colore("skin_l"), "d": colore("skin_m"), "E": colore("yellow"), "n": colore("ink")}
TESTA = {
    "down": ["...CCCCCCC....", "..CcCCCCCCCC..", ".CcCCCCCCCCCC.", ".CCSSSSSSSSCC.", ".CSKKSSSSKKSC.", ".CSKESSSSEKSC.", ".CnnnnnnnnnnC.", ".CnnnnnnnnnnC.", "..CnnnnnnnnC..", "...CCCCCCCC..."],
    "up": ["...CCCCCCC....", "..CcCCCCCCCC..", ".CcCCCCCCCCCC.", ".CCCCCCCCCCCC.", ".CCCCCCCCCCCC.", ".CCCCCCCCCCCC.", "..CCCCCCCCCC..", "...CCCCCCCC..."],
    "left": ["....CCCCCCC...", "...CcCCCCCCC..", "..CCCCCCCCCCC.", "..SSSSCCCCCCC.", "..KKSSSCCCCCC.", "..KESSSCCCCCC.", ".nnnnnnCCCCC..", "..nnnnnnCCC...", "...nnnnCC....."],
}
S = dict(P.S, falde=0, sciarpa=False, fiale=False, busto="giubba", braccio="giubba", avambraccio="fasce", gamba="pantaloni", piede="fasce", camicia=None, larghezza=(4.6, 5.6), spessore=0.9,
         arma=dict(manico=2.4, guardia=1.0, lama=7.5, spessa=(1.2, 0.8), punta=1.6, rampa="lama", elsa="cuoio", metallo="lama"))
EXTRA = ()

ANIM = _umano_nemico.anim_nemico()


def disegna(tela, v, g, posa):
    P.disegna(tela, v, g, posa, st=sys.modules[__name__])
