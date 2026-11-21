"""Il mercante (aspetto `mercante` della categoria personaggio: solo idle e walk come gli altri NPC), a griglia.

Tarchiato con la pancia, pelle ambrata, turbante arancione con la gemma, baffi neri a manubrio e sorriso, camicia
color crema, panciotto arancione, grembiule di cuoio con la borsa delle monete, pantaloni a sbuffo, babbucce gialle.
Da fermo si sfrega le mani (affari in vista); cammina dondolando sulla pancia.
"""
import numpy as np

from ..corpo import Umano
from ..pixel import Rampa, colore, griglia, segmento

SOLO = ("idle", "walk")                      # gli NPC hanno solo queste (data/animations.json personaggio)
CORPO = Umano(anca=9.5, busto=12.0, spalle=6.6, fianchi=3.2, braccio=4.8, avambraccio=4.4,
              coscia=4.8, stinco=4.6, piede=2.4, collo=0.3)

R = {
    "pelle": Rampa("brown", "skin_m", "skin_l"),
    "turbante": Rampa("purple_d", "purple", "pink"),
    "camicia": Rampa("tan", "cream", "white"),
    "panciotto": Rampa("green_d", "green_m", "green"),
    "grembiule": Rampa("brown_dd", "brown_d", "brown"),
    "pantaloni": Rampa("brown_dd", "red_d", "red"),
    "babbucce": Rampa("orange_d", "amber", "yellow"),
    "borsa": Rampa("brown_d", "brown", "tan"),
}
M = {"T": colore("purple"), "t": colore("pink"), "r": colore("purple_d"), "g": colore("yellow"), "G": colore("amber"),
     "S": colore("skin_m"), "s": colore("skin_l"), "d": colore("brown"), "K": colore("ink"), "w": colore("white"),
     "b": colore("brown_dd"), "m": colore("red_d")}

# teste 14 x 12: turbante con la gemma, baffi a manubrio, sorriso
TESTA = {
    "down": [
        "...rTTTTTr....",
        "..rTtTTTtTr...",
        ".rTtTTgTTtTr..",
        ".rTTTTGTTTTTr.",
        "rrrrrrrrrrrrr.",
        "dSsKSSSSKsSSd.",
        "dSsKSSSSKsSSd.",
        "dSSSSssSSSSSd.",
        "dSbbbSSbbbSSd.",
        ".dbSKmmmmKbd..",
        "..dSSmmmmSSd..",
        "...ddddddd....",
    ],
    "up": [
        "...rTTTTTr....",
        "..rTtTTTtTr...",
        ".rTtTTTTTtTr..",
        ".rTTTTTTTTTTr.",
        "rrrrrrrrrrrrr.",
        "dbbbbbbbbbbbd.",
        "dbbbbbbbbbbbd.",
        "dSbbbbbbbbbSd.",
        ".dSSSSSSSSSd..",
        "..dSSSSSSSd...",
        "...ddddddd....",
    ],
    "left": [
        "....rTTTTTr...",
        "...rTtTTTTTr..",
        "..rTgtTTTTTTr.",
        "..rTGTTTTTTTr.",
        ".rrrrrrrrrrrr.",
        "..sKSSSSSbbbd.",
        "..sKsSSSSbbbd.",
        ".sSSSSSSSbbd..",
        "bbbSSSSSSbd...",
        "..KmmSSSSSd...",
        "...ddSSSSd....",
        "....dddd......",
    ],
}


def disegna(tela, v, g, posa):
    parti = []
    vis = v.lato_visibile()
    for lato in "lr":
        def gamba(lato=lato):
            a, k, c, t = (v.xy(g[f"{n}_{lato}"]) for n in ("anca", "ginocchio", "caviglia", "punta"))
            segmento(tela, a, k, 2.9, 2.6, R["pantaloni"], f"gamba_{lato}")          # pantaloni a sbuffo
            segmento(tela, k, c, 2.5, 1.7, R["pantaloni"], f"gamba_{lato}")
            segmento(tela, c, t, 1.8, 1.2, R["babbucce"], f"gamba_{lato}")
            tx, ty = t
            griglia(tela, ["Y"], {"Y": colore("yellow")}, int(round(tx)), int(round(ty - 1)), f"punta_{lato}",
                    separa=False)                                                    # la punta all'insu'
        parti.append((v.prof(g[f"ginocchio_{lato}"]) + (0.3 if vis == lato else 0), 0, gamba))

        def braccio(lato=lato):
            s, e, m = (v.xy(g[f"{n}_{lato}"]) for n in ("spalla", "gomito", "mano"))
            segmento(tela, s, e, 2.4, 2.2, R["camicia"], f"braccio_{lato}")
            segmento(tela, e, m, 2.0, 1.8, R["camicia"], f"braccio_{lato}")
            segmento(tela, m, m, 1.9, 1.9, R["pelle"], f"braccio_{lato}")
        dp = v.prof(g[f"gomito_{lato}"]) * 0.5 + v.prof(g[f"mano_{lato}"]) * 0.5
        parti.append((dp + (0.6 if vis == lato else 0) + 0.2, 2, braccio))

    def busto():
        a, b = v.xy(g["bacino"] + g["su"] * 0.3), v.xy(g["collo"])
        pancia = v.xy(g["bacino"] + g["su"] * 4.0 + np.array([0, 1.6, 0]))
        segmento(tela, a, b, 6.6, 5.6, R["camicia"], "busto", tappi=False, piatto=0.3)
        if v.dir != "up":                    # la pancia tonda (da dietro non si vede)
            segmento(tela, pancia, pancia, 6.8, 6.8, R["panciotto"], "pancia", uniti=("busto",))
        else:
            segmento(tela, a, b, 5.0, 4.4, R["panciotto"], "panciotto", tappi=False, uniti=("busto",))
        if v.dir != "up":                    # grembiule davanti con la borsa delle monete
            gx, gy = v.xy(g["bacino"] + np.array([0, 2.6 if v.dir == "down" else 1.5, 1.2]))
            segmento(tela, (gx, gy - 6), (gx, gy + 4), 4.2 if v.dir == "down" else 2.4, 4.6 if v.dir == "down"
                     else 2.6, R["grembiule"], "grembiule", tappi=False, uniti=("pancia",))
            bx = gx + (3 if v.dir == "down" else -2 if v.dir == "left" else 2)
            griglia(tela, [".k.", "BBB", "BYB", "BBB"], {"k": colore("brown_dd"), "B": colore("brown"),
                    "Y": colore("yellow")}, int(round(bx - 1)), int(round(gy - 1)), "borsa")
        c = v.xy(g["collo"] - g["su"] * 0.6)      # colletto
        segmento(tela, (c[0] - 3.5, c[1]), (c[0] + 3.5, c[1]), 1.4, 1.4, R["camicia"], "colletto", uniti=("busto",))
    parti.append((v.prof(g["bacino"]) + 0.1, 1, busto))

    def testa():
        x, y = v.xy(g["testa"] + g["su"] * 4.3)
        righe, spec = (TESTA["left"], v.dir == "right") if v.dir in ("left", "right") else (TESTA[v.dir], False)
        w, h = len(righe[0]), len(righe)
        griglia(tela, righe, M, int(round(x - w / 2)), int(round(y - h / 2)), "testa", specchia=spec)
    parti.append((v.prof(g["testa"]) + 1.2, 3, testa))

    for _, _, f in sorted(parti, key=lambda p: (p[0], p[1])):
        f()


# --- Animazioni: idle 6 (si sfrega le mani), walk 8 (dondola) ------------------------------------------------------
BASE = dict(a_terra=True)
MANI = dict(braccio_l=(55, -26, 70), braccio_r=(55, -26, 70))


def _passo(t0, sx, dx, bob, ginocchio, incl):
    return (t0, dict(BASE, gamba_l=(sx, 4, ginocchio[0]), gamba_r=(dx, 4, ginocchio[1]), bob=bob, inclina=incl,
                     braccio_l=(-sx * 0.8 + 10, 18, 30), braccio_r=(-dx * 0.8 + 10, 18, 30)))


ANIM = {
    "idle": {"chiavi": [
        (0.0, dict(BASE, **MANI)),
        (1 / 3, dict(BASE, braccio_l=(58, -30, 66), braccio_r=(52, -22, 74), respiro=0.5)),
        (2 / 3, dict(BASE, braccio_l=(52, -22, 74), braccio_r=(58, -30, 66), respiro=1.0))]},
    "walk": {"chiavi": [_passo(0.0, 22, -18, 0, (4, 12), -5), _passo(0.25, 4, 10, 0.8, (8, 60), 0),
                        _passo(0.5, -18, 22, 0, (12, 4), 5), _passo(0.75, 10, 4, 0.8, (60, 8), 0)]},
}
