"""L'Archivista Capo (boss dell'Archivio Sepolto), a griglia, cella 160: altissimo e magro, la veste lunga blu
notte coi bordi d'oro che striscia a terra, il cappuccio profondo e dentro una maschera di carta bianca scritta
d'inchiostro con gli occhi gialli che brillano; tre libri aperti gli girano intorno alle spalle; impugna una penna
d'oca gigante col pennino d'argento come una lancia. Scheletro e pose dei nemici umani, pezzi suoi.
"""
import sys

import numpy as np

from . import _umano_nemico, personaggio as P
from ..corpo import Umano
from ..pixel import Rampa, colore, griglia, segmento

PROVA = True
CELLA, PIEDI = 160, 50
CORPO = Umano(anca=24.0, busto=26.0, spalle=11.0, fianchi=5.0, braccio=13.0, avambraccio=12.0,
              coscia=12.0, stinco=12.0, piede=4.0, collo=2.0)
R = {"pelle": Rampa("grey", "grey_l", "white"), "veste": Rampa("ink", "navy", "blue_d"),
     "oro": Rampa("orange_d", "amber", "yellow"), "carta": Rampa("grey_l", "white", "white"),
     "libro": Rampa("brown_dd", "red_d", "red"), "pagine": Rampa("tan", "cream", "white"),
     "penna": Rampa("grey", "grey_l", "white"), "argento": Rampa("slate", "grey_l", "white", riflesso="white"),
     "cuoio": Rampa("brown_dd", "brown_d", "brown"), "sangue": Rampa("slate", "grey", "grey_l"),
     "luce": Rampa("orange_d", "yellow", "white")}
M = {"K": colore("ink"), "E": colore("yellow"), "k": colore("slate_d")}
TESTA = {"down": ["."], "up": ["."], "left": ["."]}
DOLORE = TESTA
S = dict(P.S, falde=24.0, sciarpa=False, fiale=False, busto="veste", braccio="veste", avambraccio="pelle",
         gamba="veste", piede="veste", camicia="oro", larghezza=(10.0, 13.0), spessore=1.9, testa_su=10.0,
         arma=dict(manico=6.0, guardia=0, lama=34.0, spessa=(1.0, 0.8), punta=4.0, rampa="argento", elsa="penna",
                   metallo="oro"))


def _cappuccio(tela, v, g, posa):
    """Il cappuccio profondo e la maschera di carta scritta con gli occhi gialli."""
    c = g["testa"] + g["su"] * 11.0
    lato = {"left": -1, "right": 1}.get(v.dir, 0)

    def f():
        x, y = v.xy(c)
        segmento(tela, (x - lato * 2, y - 2), (x - lato * 3, y + 6), 13.0, 12.0, R["veste"], "cappuccio")
        if v.dir != "up":
            mx = x + lato * 3
            segmento(tela, (mx, y + 2), (mx, y + 6), 7.0, 6.0, R["carta"], "maschera", separa=False)
            mo = M if not posa.get("lampo") else {**M, "E": colore("white")}
            occhi = (-4, 2) if lato == 0 else ((-4,) if lato < 0 else (2,))
            for ox in occhi:
                griglia(tela, ["KKK", "KEK"], mo, int(round(mx + ox)), int(round(y + 1)), "occhi", separa=False)
            for k in range(3):                       # le righe d'inchiostro sulla maschera
                griglia(tela, ["k.k.k"], M, int(round(mx - 3 + k)), int(round(y + 6 + k * 2)), "scritte", separa=False)
        segmento(tela, (x - 9, y + 11), (x + 9, y + 11), 1.0, 1.0, R["oro"], "bordo", separa=False)
    return (v.prof(g["testa"]) + 1.2, 3, f)


def _libri(tela, v, g, posa):
    """Tre libri aperti che gli girano intorno all'altezza delle spalle."""
    avanti = np.cross(g["su"], g["destra"])

    def f():
        for k in range(3):
            a = k * 2 * np.pi / 3 + 0.5
            p = g["spalle_c"] + g["su"] * 4.0 + g["destra"] * np.cos(a) * 26 + avanti * np.sin(a) * 12
            x, y = v.xy(p)
            segmento(tela, (x - 4, y), (x + 4, y), 2.0, 2.0, R["libro"], f"libro{k}", tappi=False)
            segmento(tela, (x - 3.5, y - 1), (x - 0.5, y - 1), 1.2, 1.2, R["pagine"], f"pagine{k}", separa=False)
            segmento(tela, (x + 0.5, y - 1), (x + 3.5, y - 1), 1.2, 1.2, R["pagine"], f"pagine{k}", separa=False)
    return (99, 2, f)


def _piuma(tela, v, g, posa):
    """La piuma bianca in fondo alla penna (dietro la mano)."""
    d = g["arma_dir"]
    pomo = g["mano_r"] - d * 2.6

    def f():
        segmento(tela, v.xy(pomo), v.xy(pomo - d * 9), 2.6, 0.6, R["penna"], "piuma")
    return (v.prof(pomo) - 0.2, 2.4, f)


EXTRA = (_cappuccio, _libri, _piuma)
ANIM = _umano_nemico.anim_nemico()


def disegna(tela, v, g, posa):
    P.disegna(tela, v, g, posa, st=sys.modules[__name__])
