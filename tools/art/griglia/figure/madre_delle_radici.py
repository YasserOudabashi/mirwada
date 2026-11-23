"""La Madre delle Radici (boss della Valle), a griglia, cella 160: un albero che cammina. Corpo di corteccia
grigio-bruna con le venature, braccia di rami nodosi che finiscono in dita di legno, gambe di radici che si aprono a
terra, una chioma enorme di foglie verdi con i fiori bianchi al posto dei capelli, il volto e' una maschera di legno
chiaro con gli occhi verdi che brillano. Colpisce coi rami a due mani. Scheletro e pose dei nemici umani.
"""
import sys

import numpy as np

from . import _umano_nemico, personaggio as P
from ..corpo import Umano
from ..pixel import Rampa, colore, griglia, segmento

PROVA = True
CELLA, PIEDI = 160, 50
CORPO = Umano(anca=22.0, busto=26.0, spalle=13.0, fianchi=6.0, braccio=13.0, avambraccio=12.0,
              coscia=11.0, stinco=11.0, piede=4.0, collo=2.0)
R = {"pelle": Rampa("brown_dd", "brown_d", "brown"), "corteccia": Rampa("brown_dd", "brown_d", "brown"),
     "radici": Rampa("ink", "brown_dd", "brown_d"), "foglie": Rampa("teal_d", "green_d", "green_m"),
     "foglie_l": Rampa("green_d", "green_m", "green"), "fiori": Rampa("grey_l", "white", "white"),
     "maschera": Rampa("brown", "tan", "cream"), "cuoio": Rampa("brown_dd", "brown_d", "brown"),
     "sangue": Rampa("teal_d", "green_m", "green"), "luce": Rampa("green_d", "green", "white")}
M = {"K": colore("ink"), "E": colore("green"), "w": colore("white")}
TESTA = {"down": ["."], "up": ["."], "left": ["."]}
DOLORE = TESTA
S = dict(P.S, falde=12.0, sciarpa=False, fiale=False, busto="corteccia", braccio="corteccia", avambraccio="corteccia",
         gamba="radici", piede="radici", camicia=None, larghezza=(12.0, 14.0), spessore=2.2, testa_su=10.0,
         arma=dict(manico=0.5, guardia=0, lama=0, spessa=(1, 1), punta=0, rampa="corteccia", elsa="corteccia",
                   metallo="corteccia"))


def _chioma(tela, v, g, posa):
    """La chioma di foglie con i fiori e, davanti, la maschera di legno con gli occhi verdi."""
    c = g["testa"] + g["su"] * 12.0
    lato = {"left": -1, "right": 1}.get(v.dir, 0)

    def f():
        x, y = v.xy(c)
        for k, (dx, dy, r) in enumerate(((0, -4, 14), (-10, 2, 9), (10, 2, 9), (-6, -12, 8), (7, -12, 8))):
            segmento(tela, (x + dx, y + dy), (x + dx, y + dy), r, r, R["foglie"], f"chioma{k}")
        rng = np.random.RandomState(5)
        for k in range(14):
            px, py = x + rng.randint(-16, 17), y + rng.randint(-20, 8)
            segmento(tela, (px, py), (px, py), 1.4, 1.4, R["foglie_l"] if k % 3 else R["fiori"], f"foglia{k}",
                     separa=False)
        if v.dir != "up":
            mx = x + lato * 4
            segmento(tela, (mx, y + 4), (mx, y + 8), 6.0, 5.0, R["maschera"], "maschera")
            mo = M if not posa.get("lampo") else {**M, "E": colore("white")}
            occhi = (-3, 2) if lato == 0 else ((-3,) if lato < 0 else (2,))
            for ox in occhi:
                griglia(tela, ["KK", "EE"], mo, int(round(mx + ox)), int(round(y + 3)), "occhi", separa=False)
            griglia(tela, ["K.K.K"], M, int(round(mx - 2)), int(round(y + 9)), "bocca", separa=False)
    return (v.prof(g["testa"]) + 1.2, 3, f)


def _radici(tela, v, g, posa):
    """Radici che si aprono a terra dai piedi, a raggiera."""
    def f():
        for lato in "lr":
            x, y = v.xy(g[f"caviglia_{lato}"] * np.array([1, 1, 0]))
            for k, (dx, dy) in enumerate(((-7, 2), (-3, 4), (3, 4), (7, 2))):
                segmento(tela, (x, y), (x + dx, y + dy), 1.6, 0.5, R["radici"], f"radice{lato}{k}")
    return (-50, -5, f)


EXTRA = (_chioma, _radici)
ANIM = _umano_nemico.anim_nemico(due_mani=True)


def disegna(tela, v, g, posa):
    P.disegna(tela, v, g, posa, st=sys.modules[__name__])
