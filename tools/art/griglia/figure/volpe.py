"""La volpe (fauna, specie `volpe`), a griglia: arancio vivo, petto e punta della coda bianchi, zampe e punte delle
orecchie nere, muso lungo e appuntito, coda folta. Da ferma annusa e drizza le orecchie; in fuga corre bassa."""
import sys

from . import _bestia
from ..corpo import Quadrupede
from ..pixel import Rampa, colore

CORPO = Quadrupede(lungo=10.0, largo=2.2, zampa=(4.4, 4.2), collo=3.5, piedi_pari=True)
R = {"manto": Rampa("rust", "orange", "amber"), "manto_scuro": Rampa("red_d", "rust", "orange"),
     "piede": Rampa("ink", "brown_dd", "brown_d"), "pancia": Rampa("grey_l", "white", "white"),
     "coda": Rampa("rust", "orange", "amber"), "punta": Rampa("grey_l", "white", "white"),
     "sangue": Rampa("red_d", "red_d", "red")}
M = {"o": colore("orange"), "k": colore("brown_dd"), "w": colore("white"), "E": colore("ink"), "n": colore("ink")}
TESTA = {
    "down": [".k.......k.", "kok.....kok", "koooooooook", "ooEoooooEoo", "ooowooowooo", ".oowwwwwoo.", "..wwwnwww..",
             "...wwwww...", "....www...."],
    "up": [".k.......k.", "kok.....kok", "koooooooook", "ooooooooooo", "ookoooookoo", ".ooooooooo.", "..ooooooo..",
           "....ooo...."],
    "left": ["....k.k....", "...kokok...", "..ooooooo..", ".ooEoooook.", "oooooooook.", "nwwoooook..", ".wwwwook...",
             "..wwwk....."],
}
B = dict(zampa=(2.0, 2.4, 0.9), corpo=(3.0, 3.2), coda="folta", pancia=True, collo=1.8, muso=3)
ANIM = _bestia.anim_fauna(giu=45, coda_su=20, balzo=3.0)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
