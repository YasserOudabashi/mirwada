"""Il pirata naufrago (nemico_base, aspetto pirata_naufrago), a griglia: tricorno blu notte col bordo d'oro, fazzoletto
rosso, benda sull'occhio, barba nera, maglia a righe bianche e blu, calzoni strappati, piedi scalzi, sciabola larga.
Scheletro e pose di Enel (i nemici umani: _umano_nemico.py), pezzi suoi."""
import sys

from . import _umano_nemico, personaggio as P
from ..corpo import Umano
from ..pixel import Rampa, colore, segmento

CORPO = Umano(anca=10.0, busto=12.8, spalle=7.2, fianchi=3.2, braccio=5.4, avambraccio=5.0,
              coscia=5.0, stinco=5.0, piede=2.4, collo=0.4)
R = {"pelle": Rampa("brown", "skin_m", "skin_l"), "maglia": Rampa("grey", "grey_l", "white"),
     "calzoni": Rampa("brown_dd", "brown_d", "brown"), "cuoio": Rampa("red_d", "red_d", "red"),
     "lama": Rampa("slate", "grey", "grey_l", riflesso="white"), "oro": Rampa("orange_d", "amber", "yellow"),
     "righe": Rampa("navy", "blue_d", "blue_d"), "sangue": Rampa("red_d", "red_d", "red"),
     "luce": Rampa("blue", "cyan", "white")}
M = {"K": colore("navy"), "k": colore("slate_d"), "Y": colore("yellow"), "r": colore("red"), "S": colore("skin_m"),
     "d": colore("brown"), "b": colore("brown_dd"), "m": colore("red_d"), "w": colore("white"), "E": colore("ink")}
TESTA = {
    "down": ["..KKKKKKKKKK..", ".KkKKKKKKKKkK.", "KYKKKKKKKKKKYK", ".KKKKKKKKKKKK.", "..rrrrrrrrrr..",
             ".dSSKKSSSSSSd.", ".dSKKKSSSwESd.", ".dSSKSSSSSSSd.", ".dSbbbSSbbbSd.", "..dbbmmmmbbd..",
             "..dbbbbbbbbd..", "...dbbbbbbd...", "....dbbbbd...."],
    "up": ["..KKKKKKKKKK..", ".KkKKKKKKKKkK.", "KYKKKKKKKKKKYK", ".KKKKKKKKKKKK.", "..rrrrrrrrrr..",
           ".dbbbbbbbbbbd.", ".dbbbbbbbbbbd.", ".drrbbbbbbbbd.", "..dbbbbbbbbd..", "...dbbbbbbd...",
           "....dddddd...."],
    "left": ["....KKKKKKK...", "...KkKKKKKKKK.", "..YKKKKKKKKKKY", "...KKKKKKKKK..", "...rrrrrrrrr..",
             "..SSKSSSbbbbd.", "..KKKSSSbbbbd.", ".SSSSSSSbbbd..", "bbbbSSSSSbd...", "Kmmbbbbbbd....",
             ".bbbbbbbd.....", "..bbbbbd......"],
}
S = dict(P.S, falde=0, sciarpa=False, fiale=False, busto="maglia", braccio="maglia", avambraccio="pelle",
         gamba="calzoni", piede="pelle", camicia=None, larghezza=(6.0, 7.0),
         arma=dict(manico=3.2, guardia=2.6, lama=12.5, spessa=(1.8, 1.4), punta=1.8, rampa="lama", elsa="calzoni",
                   metallo="oro"))


def _righe(tela, v, g, posa):
    """Le righe blu della maglia, attorno al busto e alle braccia."""
    def f():
        for k in range(4):
            c = g["bacino"] + g["su"] * (2.5 + k * 2.6)
            segmento(tela, v.xy(c - g["destra"] * 5.8), v.xy(c + g["destra"] * 5.8), 0.6, 0.6, R["righe"], "righe",
                     separa=False)
    return (v.prof(g["bacino"]) + 0.05, 1.1, f)


EXTRA = (_righe,)
ANIM = _umano_nemico.anim_nemico()


def disegna(tela, v, g, posa):
    P.disegna(tela, v, g, posa, st=sys.modules[__name__])
