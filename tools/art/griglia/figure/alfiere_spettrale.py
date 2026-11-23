"""L'alfiere spettrale delle Marche (nemico_base, aspetto alfiere_spettrale), a griglia: anima trasparente in
armatura leggera azzurro-grigia, testa scoperta da morto con le orbite che brillano d'azzurro, capelli lunghi
bianchi mossi; porta lo stendardo strappato dell'esercito caduto (asta lunga, drappo blu con la spada bianca) e
lo usa come una lancia. Scheletro e pose di Enel."""
import sys

import numpy as np

from . import _umano_nemico, personaggio as P
from ..corpo import Umano
from ..pixel import Rampa, colore, segmento

CORPO = Umano(anca=11.5, busto=12.5, spalle=6.4, fianchi=2.8, braccio=5.6, avambraccio=5.2, coscia=5.6, stinco=5.6, piede=2.2, collo=0.8)
R = {"pelle": Rampa("blue_d", "blue", "cyan"), "armatura": Rampa("navy", "slate", "grey_l"),
     "veste": Rampa("navy", "blue_d", "blue"), "asta": Rampa("brown_dd", "brown_d", "brown"),
     "drappo": Rampa("navy", "blue_d", "blue"), "bianco": Rampa("grey", "grey_l", "white"),
     "ferro": Rampa("slate", "grey", "grey_l"),
     "cuoio": Rampa("brown_dd", "brown_d", "brown"), "sangue": Rampa("red_d", "red_d", "red"),
     "luce": Rampa("blue", "cyan", "white")}
M = {"W": colore("white"), "w": colore("grey_l"), "S": colore("blue"), "s": colore("cyan"), "K": colore("navy"), "E": colore("cyan")}
TESTA = {
    "down": ["...WWWWWWWW...", "..WwWWWWWWwW..", ".WWWWWWWWWWWW.", ".WWSSSSSSSSWW.", ".WSKKSSSSKKSW.", ".WSKESSSSEKSW.", "WWSSSSssSSSSWW", "WW.SSKKKKSS.WW", "W...SSSSSS...W", "W....ssss....W"],
    "up": ["...WWWWWWWW...", "..WwWWWWWWwW..", ".WWWWWWWWWWWW.", ".WWWWWWWWWWWW.", ".WWWWWWWWWWWW.", "WWWWWWWWWWWWWW", "WWWWWWWWWWWWWW", "W.WWWWWWWWWW.W", "W..WWWWWWWW..W"],
    "left": ["....WWWWWW....", "...WWWWWWWWW..", "..SSWWWWWWWWW.", "..SKSWWWWWWWW.", "..KESSWWWWWWW.", ".SSSSSSWWWWWW.", "..SKKSSWWWWW..", "...SSSSWWWW...", "....ssWWWW....", "......WWW....."],
}
S = dict(P.S, falde=6.0, sciarpa=False, fiale=False, busto="armatura", braccio="armatura", avambraccio="veste", gamba="veste", piede="armatura", camicia="veste", larghezza=(5.0, 6.2),
         arma=dict(manico=6.0, guardia=0, lama=26.0, spessa=(0.7, 0.7), punta=2.0, rampa="asta", elsa="asta", metallo="ferro"))


def _stendardo(tela, v, g, posa):
    """Il drappo blu strappato appeso sotto la punta dell'asta, con la spada bianca."""
    d = g["arma_dir"]
    tip = g["mano_r"] - d * 2.6 + d * 24.0

    def f():
        x, y = v.xy(tip)
        segmento(tela, (x, y + 1), (x + 0.5, y + 9), 3.4, 3.0, R["drappo"], "drappo", tappi=False, piatto=0.6)
        segmento(tela, (x, y + 3), (x, y + 8), 0.6, 0.6, R["bianco"], "drappo_s", separa=False)
        segmento(tela, (x - 1.5, y + 4), (x + 1.5, y + 4), 0.5, 0.5, R["bianco"], "drappo_s", separa=False)
    return (v.prof(tip) - 0.2, 2.4, f)


EXTRA = (_stendardo,)

ANIM = _umano_nemico.anim_nemico()


def disegna(tela, v, g, posa):
    P.disegna(tela, v, g, posa, st=sys.modules[__name__])
