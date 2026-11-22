"""Il granchio corazzato (nemico_base, aspetto granchio_corazzato), a griglia: guscio largo color ruggine con le
borchie, occhi neri sui peduncoli, zampe aperte di lato, due chele grandi davanti che si aprono quando morde e
quando prepara l'attacco. Pose del lupo della luna (bestie)."""
import sys

import numpy as np

from . import _bestia
from .lupo_della_luna import ANIM
from ..corpo import Quadrupede
from ..pixel import Rampa, colore, segmento

CORPO = Quadrupede(lungo=6.0, largo=6.5, zampa=(3.4, 3.2), collo=3.5, piedi_pari=True)
R = {"manto": Rampa("red_d", "rust", "orange"), "manto_scuro": Rampa("brown_dd", "red_d", "rust"),
     "piede": Rampa("brown_dd", "red_d", "rust"), "chela": Rampa("red_d", "rust", "orange"),
     "punta": Rampa("brown_dd", "brown_dd", "ink"), "borchie": Rampa("orange_d", "amber", "yellow"),
     "sangue": Rampa("teal_d", "green_m", "green")}
M = {"E": colore("ink"), "r": colore("rust"), "m": colore("red_d")}
TESTA = {
    "down": ["E.....E", "r.....r", ".rrrrr.", "..rmr.."],
    "up": ["E.....E", "r.....r", ".rrrrr."],
    "left": ["E...", "r...", "rrr.", ".mr."],
}
B = dict(zampa=(1.4, 1.4, 0.8), corpo=(6.0, 6.4), coda="nessuna", muso=4, testa_dy=-3)


def _chele(tela, v, g, posa):
    """Le due chele: braccio, pinza grossa, due denti che si aprono con `bocca` (morso e tell)."""
    avanti = (g["spalle"] - g["anche"]) / np.linalg.norm(g["spalle"] - g["anche"])
    destra = np.array([1.0, 0, 0])
    apri = 1.0 + 1.4 * posa.get("bocca", 0) + (0.8 if posa.get("lampo_occhi") else 0)

    def f():
        for s in (-1, 1):
            base = g["spalle"] + destra * s * 4.5 + avanti * 1.0
            pugno = base + avanti * 3.2 + destra * s * 2.2 + g["su"] * 1.0
            segmento(tela, v.xy(base), v.xy(pugno), 1.3, 1.6, R["chela"], f"chela{s}")
            segmento(tela, v.xy(pugno), v.xy(pugno), 2.6, 2.6, R["chela"], f"chela{s}", uniti=(f"chela{s}",))
            for d in (-1, 1):
                tip = pugno + avanti * 3.0 + destra * d * 0.9 * apri + g["su"] * 0.3
                segmento(tela, v.xy(pugno + avanti * 1.0), v.xy(tip), 1.2, 0.4, R["punta"] if d > 0 else R["chela"],
                         f"chela{s}", uniti=(f"chela{s}",))
    return (v.prof(g["spalle"] + avanti * 4) + 0.5, 2.5, f)


def _borchie(tela, v, g, posa):
    def f():
        if v.dir == "down":
            return
        destra = np.array([1.0, 0, 0])
        for k, (a, b) in enumerate(((-2.4, 0.3), (0, 0.5), (2.4, 0.3), (-1.2, 0.8), (1.2, 0.8))):
            p = (g["anche"] + g["spalle"]) / 2 + destra * a + g["su"] * (4.0 + b)
            x, y = v.xy(p)
            segmento(tela, (x, y), (x, y), 0.7, 0.7, R["borchie"], "borchie", separa=False)
    return (v.prof((g["anche"] + g["spalle"]) / 2) + 0.2, 1.5, f)


EXTRA = (_chele, _borchie)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
