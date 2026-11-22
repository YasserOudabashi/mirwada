"""Il Re dei Ratti (boss delle fogne di Mirwada: `balance.json boss`), a griglia, cella 160: un uomo enorme cucito al
suo branco. Corona di ferro arrugginito a punte, capelli grigi sporchi, faccia malata piena di cuciture, occhi rossi,
denti gialli; manto di pelli di ratto a brandelli che striscia a terra, braccia nude cucite, una mannaia arrugginita a
due mani, due ratti vivi sulle spalle e uno che esce dal manto. Scheletro e pose dei nemici umani, pezzi suoi.
"""
import sys

import numpy as np

from . import _umano_nemico, personaggio as P
from ..corpo import Umano
from ..pixel import Rampa, colore, griglia, segmento

PROVA = True                 # cella 160: resta in arte/prova finche' i boss non hanno il loro posto nel gioco
CELLA, PIEDI = 160, 50
CORPO = Umano(anca=23.0, busto=27.0, spalle=15.0, fianchi=6.5, braccio=12.0, avambraccio=11.0,
              coscia=11.5, stinco=11.5, piede=4.8, collo=1.0)
R = {"pelle": Rampa("brown", "skin_m", "skin_l"), "pelli": Rampa("ink", "slate_d", "slate"),
     "stracci": Rampa("ink", "brown_dd", "brown_d"), "cuoio": Rampa("brown_dd", "brown_d", "brown"),
     "ruggine": Rampa("brown_dd", "rust", "orange_d"), "ratto": Rampa("brown_dd", "brown_d", "brown"), "capelli": Rampa("slate", "grey", "grey_l"), "mannaia": Rampa("rust", "grey", "grey_l", riflesso="white"),
     "coda": Rampa("red_d", "pink", "pink"), "sangue": Rampa("red_d", "red_d", "red"),
     "luce": Rampa("red_d", "red", "pink")}
M = {"Y": colore("amber"), "O": colore("rust"), "h": colore("grey"), "H": colore("slate"), "S": colore("skin_l"),
     "d": colore("skin_m"), "x": colore("red_d"), "K": colore("ink"), "E": colore("red"), "w": colore("cream"),
     "m": colore("red_d"), "g": colore("grey")}
_CORONA = ["...Y....Y...Y....Y..", "..YOY..YOY.YOY..YOY.", "..YOOYYOOOYOOOYYOOY.", ".OOOOOOOOOOOOOOOOOO."]
# la testa grande (3 teste anche per lui) e' disegnata a pezzi tondi in _testa: la griglia di Enel resta vuota
TESTA = {"down": ["."], "up": ["."], "left": ["."]}
DOLORE = TESTA


def _testa(tela, v, g, posa):
    """Testa grossa e tonda: capelli grigi sporchi, faccia malata con le cuciture, occhi rossi (che si accendono nel
    tell), bocca larga coi denti gialli, corona di ferro arrugginito a punte."""
    c = g["testa"] + g["su"] * 11.0
    lato = {"left": -1, "right": 1}.get(v.dir, 0)

    def f():
        x, y = v.xy(c)
        dolore = posa.get("faccia") == "dolore"
        if v.dir == "up":
            segmento(tela, (x, y), (x, y), 12.0, 12.0, R["capelli"], "testa")
        else:
            segmento(tela, (x - lato * 3, y - 2), (x - lato * 3, y - 2), 12.0, 12.0, R["capelli"], "testa")
            segmento(tela, (x + lato * 2, y + 1.5), (x + lato * 2, y + 1.5), 10.5, 10.5, R["pelle"], "testa",
                     uniti=("testa",), separa=False)
            occhio = ["KKKK", "KEEE", "KEE."] if not dolore else ["KK..", ".KKK", "..KK"]
            mo = M if not posa.get("lampo") else {**M, "E": colore("white")}
            occhi = (-6, 2) if lato == 0 else ((-8,) if lato < 0 else (5,))
            for ox in occhi:
                griglia(tela, occhio if ox < 0 or lato > 0 else [r[::-1] for r in occhio], mo, int(round(x + ox)),
                        int(round(y)), "occhi", separa=False)
            bx = x - 4 + lato * 3
            griglia(tela, ["wmwmwmw", "mmmmmmm", ".wmwmw."] if not dolore else [".mmmmm.", "mKKKKKm", ".mmmmm."], M,
                    int(round(bx)), int(round(y + 5)), "bocca", separa=False)
            for k in range(4):                     # la cucitura storta sulla guancia
                griglia(tela, ["x", "."], M, int(round(x + 3 - lato * 2 + k)), int(round(y - 3 + k * 2)), "cucitura",
                        separa=False)
                griglia(tela, ["x"], M, int(round(x + 2 - lato * 2 + k)), int(round(y - 2 + k * 2)), "cucitura",
                        separa=False)
        griglia(tela, _CORONA, M, int(round(x - 10)), int(round(y - 16)), "corona")
    return (v.prof(g["testa"]) + 1.2, 3, f)


S = dict(P.S, falde=16.0, sciarpa=False, fiale=False, busto="pelli", braccio="pelle", avambraccio="pelle",
         gamba="stracci", piede="stracci", camicia=None, larghezza=(12.5, 16.0), spessore=2.4, testa_su=9.0,
         arma=dict(manico=8.0, guardia=0, lama=24.0, spessa=(5.0, 5.6), punta=0, rampa="mannaia", elsa="cuoio",
                   metallo="ruggine"))


def _ratto(tela, v, c, verso, nome):
    """Un ratto piccolo appollaiato: corpo, testa col punto rosso, coda rosa che pende."""
    x, y = v.xy(c)
    segmento(tela, (x, y), (x + 5.0 * verso, y - 1.5), 4.4, 3.2, R["ratto"], nome)
    segmento(tela, (x + 7.0 * verso, y - 2.0), (x + 7.0 * verso, y - 2.0), 2.6, 2.6, R["ratto"], nome, uniti=(nome,))
    segmento(tela, (x + 5.0 * verso, y - 4.5), (x + 5.0 * verso, y - 4.5), 1.0, 1.0, R["coda"], nome, uniti=(nome,))
    segmento(tela, (x - 3.0 * verso, y + 0.5), (x - 6.5 * verso, y + 8.0), 0.8, 0.5, R["coda"], nome, uniti=(nome,))
    segmento(tela, (x + 6.6 * verso, y - 2.6), (x + 6.6 * verso, y - 2.6), 0.6, 0.6, R["luce"], nome, separa=False)


def _ratti(tela, v, g, posa):
    def f():
        for s, nome in ((1, "ratto_d"), (-1, "ratto_s")):
            _ratto(tela, v, g[f"spalla_{'r' if s > 0 else 'l'}"] + g["su"] * 3.5, s if v.dir != "left" else -1, nome)
        _ratto(tela, v, g["bacino"] - g["destra"] * 9.0 - g["su"] * 2.0, -1, "ratto_m")
    return (v.prof(g["spalle_c"]) + 1.0, 3.5, f)


def _cuciture(tela, v, g, posa):
    """Cuciture rosse sulle braccia nude: tre punti per braccio."""
    def f():
        for lato in "lr":
            for k in range(3):
                p = g[f"gomito_{lato}"] + (g[f"mano_{lato}"] - g[f"gomito_{lato}"]) * (0.2 + k * 0.3)
                x, y = v.xy(p)
                segmento(tela, (x - 1.2, y), (x + 1.2, y), 0.4, 0.4, R["sangue"], "cuciture", separa=False)
    return (99, 1, f)


EXTRA = (_testa, _ratti, _cuciture)
ANIM = _umano_nemico.anim_nemico(due_mani=True)


def disegna(tela, v, g, posa):
    P.disegna(tela, v, g, posa, st=sys.modules[__name__])
