"""Aldo, il rivale (aspetto `rivale` della categoria personaggio), a griglia, con TUTTE le mosse di Enel.

Spadaccino elegante e sicuro di se': capelli biondi pettinati all'indietro, occhi verdi, sorriso storto; camicia
bianca con le maniche larghe, farsetto di cuoio stretto, guanti, calzoni grigi, stivali neri alti, una mantellina
color vino sulla spalla sinistra, lo stocco (lama sottile, guardia a coppa d'argento) al fianco. Piu' alto e sottile
di Enel. Lo scheletro e le pose sono quelli di Enel (griglia/figure/personaggio.py); i pezzi e i colori sono suoi.
"""
import sys

import numpy as np

from . import personaggio as P
from ..corpo import Umano
from ..pixel import Rampa, colore, segmento

NEL_GIOCO = True             # i fogli vanno anche in assets/placeholder (l'NPC Aldo usa idle e walk)
CORPO = Umano(anca=11.5, busto=12.0, spalle=6.2, fianchi=2.6, braccio=5.6, avambraccio=5.0,
              coscia=5.8, stinco=5.8, piede=2.3, collo=0.8)

R = {
    "pelle": Rampa("skin_m", "skin_l", "cream"),
    "camicia": Rampa("grey", "grey_l", "white"),
    "farsetto": Rampa("brown_dd", "brown_d", "brown"),
    "guanti": Rampa("brown_dd", "brown_d", "tan"),
    "calzoni": Rampa("slate_d", "slate", "grey"),
    "stivali": Rampa("ink", "navy", "slate_d"),
    "mantella": Rampa("brown_dd", "red_d", "red"),
    "cuoio": Rampa("brown_dd", "brown_d", "brown"),
    "argento": Rampa("grey", "grey_l", "white"),
    "lama": Rampa("slate", "grey", "grey_l", riflesso="white"),
    "luce": Rampa("green_d", "green", "white"),
    "sangue": Rampa("red_d", "red_d", "red"),
}
M = {"A": colore("amber"), "Y": colore("yellow"), "O": colore("orange_d"), "S": colore("skin_l"),
     "s": colore("cream"), "d": colore("skin_m"), "K": colore("ink"), "w": colore("white"), "G": colore("green"),
     "m": colore("red_d")}

# teste 14 x 12: capelli biondi pettinati all'indietro con un ciuffo, occhi verdi, sorriso storto
TESTA = {
    "down": [
        "....AAYYAA....",
        "..AAYYYYYYAA..",
        ".AYYYYYYYYYYA.",
        ".AYAYYYAYYYAYO",
        "OAAsAAAsAAAsAO",
        "ASsKKssssKKsdO",
        "ASswGssssGwddO",
        "ASSSSSSSSSSddO",
        ".ASSSSSSSSSdO.",
        "..dSSKmmmSdd..",
        "...dSSSSSdd...",
        "....ddddd.....",
    ],
    "up": [
        "....AAYYAA....",
        "..AAYYYYYYAA..",
        ".AYYYYYYYYYYA.",
        ".AYAYYYAYYYAYO",
        "AYYAYYYAYYYAYO",
        "AYAYYAYYAYYAAO",
        "AAYYAYYYAYYAAO",
        ".AAYYAYYAYAAO.",
        "..OAAAAAAAAO..",
        "...dSSSSSdd...",
        "....ddddd.....",
    ],
    "left": [
        "....AAYYYA....",
        "...AYYYYYYAA..",
        "..AYYYAYYYYYAO",
        "..sAAYYAYAYYAO",
        "..sKKsAAYAYYAO",
        "..swGsSSAYYAAO",
        ".sSSSSSdAYYAO.",
        "..SSSSSdAAAO..",
        "..SKmmSSdAO...",
        "...dSSSSdd....",
        "....dddd......",
    ],
}
DOLORE = {
    "down": TESTA["down"][:5] + ["ASKKssssssKKdO", "ASssKssssKsddO"] + TESTA["down"][7:9] + ["..dSKmKKmSdd.."]
    + TESTA["down"][10:],
    "left": TESTA["left"][:4] + ["..sKKsAAYAYYAO", "..sKKsSSAYYAAO"] + TESTA["left"][6:8] + ["..KmKSSSdAO..."]
    + TESTA["left"][9:],
}

S = dict(P.S, falde=0, sciarpa=False, fiale=False, busto="farsetto", braccio="camicia", avambraccio="guanti",
         gamba="calzoni", piede="stivali", camicia="camicia", larghezza=(4.8, 6.0), fodero="fianco",
         arma=dict(manico=3.4, guardia=2.0, lama=21.0, spessa=(0.75, 0.55), punta=1.6, rampa="lama", elsa="cuoio",
                   metallo="argento"))


def _mantella(tela, v, g, posa):
    """La mantellina color vino dalla spalla sinistra, dietro la schiena; il vento la apre."""
    avanti = np.cross(g["su"], g["destra"])
    a = g["spalle_c"] - avanti * 1.6 - g["destra"] * 2.0
    z = a - g["su"] * 9.0 - avanti * (1.2 + posa.get("vento", 0.0) * 0.9)

    def f():
        segmento(tela, v.xy(a), v.xy(z), 4.2, 5.4, R["mantella"], "mantella", tappi=False, piatto=0.5)
        b = v.xy(a + g["destra"] * 1.0 + g["su"] * 0.5)      # il fermaglio d'argento sulla spalla
        segmento(tela, b, b, 1.0, 1.0, R["argento"], "fermaglio", separa=False)
    return (v.prof(a - avanti * 0.4) - 0.1, 0.8, f)


EXTRA = (_mantella,)


def disegna(tela, v, g, posa):
    P.disegna(tela, v, g, posa, st=sys.modules[__name__])


def _una_mano(an):
    """Lo stocco si tiene con una mano: le stesse pose di Enel senza la seconda mano sull'elsa."""
    return {**an, "chiavi": [(t, {k: x for k, x in p.items() if k != "due_mani"}) for t, p in an["chiavi"]]}


ANIM = {k: _una_mano(a) for k, a in P.ANIM.items()}
