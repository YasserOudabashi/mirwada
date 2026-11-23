"""Vesna, la guaritrice (aspetto `guaritrice` della categoria personaggio), a griglia, con TUTTE le mosse di Enel.

Donna dei margini, diffidente: fazzoletto verde salvia sulla testa, trecce rosso rame che pendono ai lati, occhi
verdi, lentiggini; veste lunga verde muschio col grembiule color crema, sandali, la borsa delle erbe; il bastone di
legno nodoso sulla schiena (lo impugna a due mani come un'arma da botta).
"""
import sys

import numpy as np

from . import personaggio as P
from ..corpo import Umano
from ..pixel import Rampa, colore, segmento

NEL_GIOCO = True
ASPETTO = "guaritrice"
CORPO = Umano(anca=10.0, busto=11.8, spalle=5.8, fianchi=3.0, braccio=5.0, avambraccio=4.6,
              coscia=5.0, stinco=5.0, piede=2.1, collo=0.6)
R = {"pelle": Rampa("skin_m", "skin_l", "cream"), "veste": Rampa("teal_d", "green_d", "green_m"),
     "grembiule": Rampa("tan", "cream", "white"), "sandali": Rampa("brown_dd", "brown_d", "brown"),
     "cuoio": Rampa("brown_dd", "brown_d", "brown"), "legno": Rampa("brown_dd", "brown_d", "brown"),
     "foglia": Rampa("green_d", "green_m", "green"), "borsa": Rampa("brown_d", "brown", "tan"),
     "luce": Rampa("green_d", "green", "white"), "sangue": Rampa("red_d", "red_d", "red")}
M = {"V": colore("green_m"), "v": colore("green"), "R": colore("rust"), "S": colore("skin_l"), "d": colore("skin_m"),
     "K": colore("ink"), "w": colore("white"), "G": colore("green_d"), "m": colore("red_d"), "f": colore("orange_d")}
TESTA = {
    "down": ["...VVVVVVVV...", "..VvVVVVVVvV..", ".VVRRRRRRRRVV.", ".VRSSSSSSSSRV.", ".RSKKSSSSKKSR.",
             ".RSwGSSSSGwSR.", ".RSfSSddSSfSR.", ".RRSSSSSSSSRR.", "RR.SSSmmSSS.RR", "R...dSSSSd...R",
             "R....dddd....R"],
    "up": ["...VVVVVVVV...", "..VvVVVVVVvV..", ".VVVVVVVVVVVV.", ".VRRRRRRRRRRV.", ".RRRRRRRRRRRR.",
           ".RRRRRRRRRRRR.", ".RRRRRRRRRRRR.", "..RRRRRRRRRR..", "..RR.dddd.RR..", "..R........R..",
           "..R........R.."],
    "left": ["....VVVVVV....", "...VvVVVVVVV..", "..RRRRVVVVVVV.", "..RSSRRRRRVVV.", "..SKKSSRRRRRV.",
             "..SwGSSSRRRRR.", ".SSfSSSdRRRR..", "..SSSSSSdRRR..", "..SmmSSSSdRR..", "...dSSSSd.R...",
             "....dddd..R..."],
}
DOLORE = {
    "down": TESTA["down"][:4] + [".RSKSSSSSSKSR.", ".RSKKSSSSKKSR."] + TESTA["down"][6:8] + ["RR.SSmKKmSS.RR"]
    + TESTA["down"][9:],
    "left": TESTA["left"][:4] + ["..SKSSSRRRRRV.", "..SKKSSSRRRRR."] + TESTA["left"][6:8] + ["..KmKSSSSdRR.."]
    + TESTA["left"][9:],
}
S = dict(P.S, falde=9.0, sciarpa=False, fiale=False, busto="veste", braccio="veste", avambraccio="pelle",
         gamba="veste", piede="sandali", camicia="grembiule", larghezza=(5.6, 5.6),
         arma=dict(manico=3.0, guardia=0, lama=20.0, spessa=(1.1, 1.0), punta=1.2, rampa="legno", elsa="legno",
                   metallo="foglia"))


def _borsa(tela, v, g, posa):
    """La borsa delle erbe al fianco destro, con due foglie che spuntano."""
    c = g["bacino"] + g["destra"] * 3.6 + g["su"] * 0.5 + np.cross(g["su"], g["destra"]) * 0.8

    def f():
        x, y = v.xy(c)
        segmento(tela, (x, y), (x, y + 1.5), 2.0, 2.4, R["borsa"], "borsa")
        segmento(tela, (x - 0.5, y - 2), (x - 1.5, y - 4.5), 0.8, 0.5, R["foglia"], "borsa", uniti=("borsa",))
        segmento(tela, (x + 0.8, y - 2), (x + 1.8, y - 4), 0.8, 0.5, R["foglia"], "borsa", uniti=("borsa",))
    return (v.prof(c) + 0.3, 1.6, f)


EXTRA = (_borsa,)
ANIM = P.ANIM


def disegna(tela, v, g, posa):
    P.disegna(tela, v, g, posa, st=sys.modules[__name__])
