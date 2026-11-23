"""Il lettore proibito dell'Archivio (nemico_base, aspetto lettore_proibito), a griglia: studioso curvo con la
veste viola lunga e il cappuccio abbassato, capelli grigi radi, occhiali tondi che brillano di viola, barba bianca a
punta; nella sinistra un libro aperto che brilla (le pagine si sfogliano da sole), nella destra un pugnale da carte.
Scheletro e pose di Enel."""
import sys

import numpy as np

from . import _umano_nemico, personaggio as P
from ..corpo import Umano
from ..pixel import Rampa, colore, segmento

CORPO = Umano(anca=10.5, busto=11.5, spalle=5.8, fianchi=2.8, braccio=5.2, avambraccio=4.8, coscia=5.2, stinco=5.2, piede=2.2, collo=0.4)
R = {"pelle": Rampa("skin_m", "skin_l", "cream"), "veste": Rampa("purple_d", "purple", "pink"),
     "fodera": Rampa("ink", "purple_d", "purple"), "libro": Rampa("brown_dd", "red_d", "red"),
     "pagine": Rampa("tan", "cream", "white"), "luce_v": Rampa("purple", "pink", "white"),
     "lama": Rampa("slate", "grey", "grey_l", riflesso="white"),
     "cuoio": Rampa("brown_dd", "brown_d", "brown"), "sangue": Rampa("red_d", "red_d", "red"),
     "luce": Rampa("blue", "cyan", "white")}
M = {"G": colore("grey"), "g": colore("grey_l"), "S": colore("skin_l"), "d": colore("skin_m"), "K": colore("ink"), "E": colore("pink"), "W": colore("white"), "w": colore("grey_l")}
TESTA = {
    "down": ["....gGGGGg....", "...gGSSSSGg...", "..gSSSSSSSSg..", "..SSSSSSSSSS..", "..SKKKSSKKKS..", "..SKEKSSKEKS..", "..SKKKddKKKd..", "..SSSWWWWSSd..", "...dWWwwWWd...", "....WWWWWW....", ".....WWWW.....", "......WW......"],
    "up": ["....gGGGGg....", "...gGGGGGGg...", "..gGGGGGGGGg..", "..GGGGGGGGGG..", "..GGGGGGGGGG..", "..dGGGGGGGGd..", "...dSSSSSSd...", "....dddddd...."],
    "left": ["....gGGGGg....", "...gSSSGGGg...", "..SSSSSSGGGG..", "..KKKSSSGGGG..", "..KEKSSSGGGG..", ".SKKKSSdGGG...", "..SSSSSdGG....", "..WWWWSd......", "..WWwWd.......", "..WWWW........", "...WW........."],
}
S = dict(P.S, falde=9.0, sciarpa=False, fiale=False, busto="veste", braccio="veste", avambraccio="veste", gamba="veste", piede="fodera", camicia="fodera", larghezza=(5.0, 5.6),
         arma=dict(manico=2.0, guardia=1.2, lama=6.0, spessa=(0.9, 0.6), punta=1.0, rampa="lama", elsa="libro", metallo="lama"))


def _libro(tela, v, g, posa):
    """Il libro aperto nella mano sinistra, che brilla di viola."""
    c = g["mano_l"] + np.cross(g["su"], g["destra"]) * 1.2 + g["su"] * 1.0

    def f():
        x, y = v.xy(c)
        segmento(tela, (x - 3.2, y), (x + 3.2, y), 1.8, 1.8, R["libro"], "libro", tappi=False)
        segmento(tela, (x - 2.8, y - 0.8), (x - 0.4, y - 0.8), 1.0, 1.0, R["pagine"], "libro_p", separa=False)
        segmento(tela, (x + 0.4, y - 0.8), (x + 2.8, y - 0.8), 1.0, 1.0, R["pagine"], "libro_p", separa=False)
        segmento(tela, (x, y - 4), (x, y - 4), 1.2, 1.2, R["luce_v"], "libro_luce", separa=False)
    return (v.prof(c) + 0.6, 4.0, f)


EXTRA = (_libro,)

ANIM = _umano_nemico.anim_nemico()


def disegna(tela, v, g, posa):
    P.disegna(tela, v, g, posa, st=sys.modules[__name__])
