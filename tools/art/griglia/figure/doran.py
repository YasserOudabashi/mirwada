"""Doran, l'investigatore (aspetto `investigatore` della categoria personaggio), a griglia, con TUTTE le mosse di Enel.

Uomo maturo e asciutto che segue le tue tracce: cappello a tesa grigio con la fascia nera, capelli castani, barba
grigia corta e baffi, occhi azzurri stretti; impermeabile lungo color sabbia con la cintura, gilet scuro, pantaloni
grigi, scarpe nere; il bastone animato (una lama sottile nascosta nel bastone col pomolo d'argento) al fianco.
"""
import sys

from . import personaggio as P
from ..corpo import Umano
from ..pixel import Rampa, colore

NEL_GIOCO = True
ASPETTO = "investigatore"
CORPO = Umano(anca=11.0, busto=12.6, spalle=6.6, fianchi=2.8, braccio=5.6, avambraccio=5.0,
              coscia=5.4, stinco=5.6, piede=2.4, collo=0.6)
R = {"pelle": Rampa("skin_m", "skin_l", "cream"), "trench": Rampa("brown", "tan", "cream"),
     "gilet": Rampa("ink", "navy", "slate_d"), "pantaloni": Rampa("slate_d", "slate", "grey"),
     "scarpe": Rampa("ink", "ink", "navy"), "cuoio": Rampa("brown_dd", "brown_d", "brown"),
     "bastone": Rampa("brown_dd", "brown_d", "brown"), "argento": Rampa("grey", "grey_l", "white"),
     "lama": Rampa("slate", "grey", "grey_l", riflesso="white"), "luce": Rampa("blue", "cyan", "white"),
     "sangue": Rampa("red_d", "red_d", "red")}
M = {"G": colore("slate"), "g": colore("ink"), "K": colore("ink"), "H": colore("brown_d"), "S": colore("skin_l"),
     "d": colore("skin_m"), "w": colore("white"), "E": colore("blue"), "s": colore("grey"), "m": colore("red_d")}
TESTA = {
    "down": ["..GGGGGGGGGG..", ".GGGGGGGGGGGG.", ".gggggggggggg.", "GGGGGGGGGGGGGG", "..HSSSSSSSSH..",
             "..SKKSSSSKKS..", "..SwESSSSEwS..", "..SSSSddSSSS..", "..SsssSSsssS..", "...SsKKKKsS...",
             "....ssssss...."],
    "up": ["..GGGGGGGGGG..", ".GGGGGGGGGGGG.", ".gggggggggggg.", "GGGGGGGGGGGGGG", "..HHHHHHHHHH..",
           "..HHHHHHHHHH..", "..HHHHHHHHHH..", "...HHHHHHHH...", "....SSSSSS....", "....dddddd...."],
    "left": ["...GGGGGGGG...", "..GGGGGGGGGG..", "..gggggggggg..", "GGGGGGGGGGGGG.", "..SSSSSHHHHH..",
             "..KKSSSSHHHH..", "..wESSSSHHHH..", ".SSSSSSdHHH...", "..ssSSSSdH....", "..KsssssS.....",
             "...ssssss....."],
}
DOLORE = {
    "down": TESTA["down"][:5] + ["..SKSSSSSSKS..", "..SKKSSSSKKS.."] + TESTA["down"][7:9] + ["...SsKmmKsS..."]
    + TESTA["down"][10:],
    "left": TESTA["left"][:5] + ["..KSSSSSHHHH..", "..KKSSSSHHHH.."] + TESTA["left"][7:9] + ["..KmmsssS....."]
    + TESTA["left"][10:],
}
S = dict(P.S, falde=8.0, sciarpa=False, fiale=False, busto="trench", braccio="trench", avambraccio="trench",
         gamba="pantaloni", piede="scarpe", camicia="gilet", larghezza=(5.4, 6.4), fodero="fianco",
         arma=dict(manico=4.0, guardia=0, lama=19.0, spessa=(0.75, 0.6), punta=1.0, rampa="lama", elsa="bastone",
                   metallo="argento"))
ANIM = {k: {**a, "chiavi": [(t, {q: x for q, x in p.items() if q != "due_mani"}) for t, p in a["chiavi"]]}
        for k, a in P.ANIM.items()}


def disegna(tela, v, g, posa):
    P.disegna(tela, v, g, posa, st=sys.modules[__name__])
