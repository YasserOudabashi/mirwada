"""Il contrabbandiere con la balestra (nemico_base, aspetto contrabbandiere_balestra), a griglia: berretto di lana
verde scuro, cicatrice sulla guancia, barba nera corta, sciarpa color sabbia, giaccone di cuoio scuro con la
bandoliera dei dardi, pantaloni grigi, stivali; la balestra di legno con l'arco di ferro. Scheletro e pose di Enel."""
import sys

import numpy as np

from . import _umano_nemico, personaggio as P
from ..corpo import Umano
from ..pixel import Rampa, colore, segmento

CORPO = Umano(anca=10.5, busto=12.2, spalle=6.4, fianchi=2.8, braccio=5.4, avambraccio=5.0, coscia=5.2, stinco=5.4, piede=2.4, collo=0.4)
R = {"pelle": Rampa("brown", "skin_m", "skin_l"), "giaccone": Rampa("ink", "brown_dd", "brown_d"),
     "pantaloni": Rampa("slate_d", "slate", "grey"), "stivali": Rampa("ink", "brown_dd", "brown_d"),
     "sciarpa": Rampa("brown", "tan", "cream"), "legno": Rampa("brown_d", "brown", "tan"),
     "ferro": Rampa("slate", "grey", "grey_l", riflesso="white"),
     "cuoio": Rampa("brown_dd", "brown_d", "brown"), "sangue": Rampa("red_d", "red_d", "red"),
     "luce": Rampa("blue", "cyan", "white")}
M = {"B": colore("green_d"), "b": colore("teal_d"), "S": colore("skin_m"), "d": colore("brown"), "K": colore("ink"), "r": colore("pink"), "E": colore("ink"), "w": colore("white"), "n": colore("ink")}
TESTA = {
    "down": ["...BBBBBBBB...", "..BbBBBBBBBB..", "..BBBBBBBBBB..", "..bbbbbbbbbb..", "..SKKSSSSKKS..", "..SwESSSSEwr..", "..SSSSddSSrS..", "..nnSSSSSSnn..", "...nnnnnnnn...", "....nnnnnn...."],
    "up": ["...BBBBBBBB...", "..BbBBBBBBBB..", "..BBBBBBBBBB..", "..bbbbbbbbbb..", "..nnnnnnnnnn..", "..nnnnnnnnnn..", "...nnnnnnnn...", "....dddddd...."],
    "left": ["....BBBBBBB...", "...BbBBBBBBB..", "...BBBBBBBBB..", "...bbbbbbbbb..", "..KKSSSSnnnn..", "..wESSSrnnnn..", ".SSSSSrSnnn...", "..nnSSSSnn....", "..nnnnnnn.....", "...nnnnn......"],
}
S = dict(P.S, falde=3.0, sciarpa=True, fiale=False, busto="giaccone", braccio="giaccone", avambraccio="giaccone", gamba="pantaloni", piede="stivali", camicia=None, larghezza=(5.6, 6.6),
         arma=dict(manico=2.0, guardia=4.2, lama=9.0, spessa=(1.4, 1.2), punta=0.6, rampa="legno", elsa="legno", metallo="ferro"))
EXTRA = ()

ANIM = _umano_nemico.anim_nemico()


def disegna(tela, v, g, posa):
    P.disegna(tela, v, g, posa, st=sys.modules[__name__])
