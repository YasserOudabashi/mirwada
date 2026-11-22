"""La lepre (fauna, specie `lepre`), a griglia: piccola, orecchie lunghe con la punta scura, manto fulvo, pancia e
muso crema, coda a fiocco bianca. Da ferma annusa e si drizza; in fuga balza lunga."""
import sys

from . import _bestia
from ..corpo import Quadrupede
from ..pixel import Rampa, colore

CORPO = Quadrupede(lungo=6.0, largo=1.6, zampa=(3.2, 3.2), collo=2.5, piedi_pari=True)
R = {"manto": Rampa("brown", "tan", "cream"), "manto_scuro": Rampa("brown_d", "brown", "tan"),
     "piede": Rampa("brown", "tan", "cream"), "pancia": Rampa("tan", "cream", "white"),
     "punta": Rampa("grey_l", "white", "white"), "sangue": Rampa("red_d", "red_d", "red")}
M = {"t": colore("tan"), "b": colore("brown"), "c": colore("cream"), "E": colore("ink"), "n": colore("pink")}
TESTA = {
    "down": ["..t...t..", ".tbt.tbt.", ".tbt.tbt.", ".tbt.tbt.", ".ttttttt.", "ttEtttEtt", "ttttttttt", ".tttnttt.",
             "..ccccc..", "...ccc..."],
    "up": ["..t...t..", ".tbt.tbt.", ".tbt.tbt.", ".tbt.tbt.", ".ttttttt.", "tbtttttbt", "ttbbbbbtt", ".ttbbbtt.",
           "..ttttt.."],
    "left": ["....tt...", "....tbt..", "....tbt..", "...ttbt..", "..tttttt.", ".tEttttb.", "tttttttb.", "nctttttb.",
             ".ccctb..."],
}
B = dict(zampa=(1.6, 2.2, 0.8), corpo=(2.6, 2.2), coda="fiocco", pancia=True, collo=1.2, muso=1, testa_dy=-2)
ANIM = _bestia.anim_fauna(giu=55, coda_su=40, balzo=5.0)


def disegna(tela, v, g, posa):
    _bestia.disegna(tela, v, g, posa, sys.modules[__name__])
