"""Il cervo (fauna, specie `cervo`: idle e fuga), a griglia. Zampe lunghe e sottili, collo lungo, corna ramificate color
osso, manto bruno con macchie chiare sul dorso, pancia e gola crema, coda corta col fiocco bianco che si alza quando
scappa. Da fermo bruca e alza la testa per guardarsi intorno; in fuga salta (zampe tutte tese, poi raccolte).
"""
import numpy as np

from ..corpo import Quadrupede
from ..pixel import Rampa, colore, griglia, segmento

CORPO = Quadrupede(lungo=15.0, anca=15.0, spalla=16.0, largo=2.6, zampa=(8.0, 7.6), collo=7.5)

R = {
    "manto": Rampa("brown_d", "brown", "tan"),
    "manto_scuro": Rampa("brown_dd", "brown_d", "brown"),
    "crema": Rampa("tan", "cream", "white"),
    "zoccolo": Rampa("brown_dd", "brown_dd", "brown_d"),
    "corna": Rampa("tan", "cream", "white"),
}
M = {"b": colore("brown"), "B": colore("brown_d"), "t": colore("tan"), "c": colore("cream"), "K": colore("ink"),
     "w": colore("white"), "n": colore("brown_dd"), "o": colore("cream")}

# teste: corna ramificate sopra, orecchie larghe, muso chiaro col naso nero
TESTA = {
    "down": [
        "o.o.......o.o",
        ".oo.o...o.oo.",
        "..ooo...ooo..",
        "...oo...oo...",
        "Bb..bbbbb..bB",
        ".Bbbbtttbbbb.",
        "..bKbtttbKb..",
        "..bbbcccbbb..",
        "...bbcccbb...",
        "....ccKcc....",
        ".....ccc.....",
    ],
    "up": [
        "o.o.......o.o",
        ".oo.o...o.oo.",
        "..ooo...ooo..",
        "...oo...oo...",
        "Bb..bbbbb..bB",
        ".BbbbbbbbbbB.",
        "..bbbbbbbbb..",
        "...bbbbbbb...",
        "....BBBBB....",
    ],
    "left": [
        "....o.o.....",
        ".....oo.o...",
        "......ooo...",
        ".......oo...",
        ".....bbbbBB.",
        "....btbbbbB.",
        "..bbKbbbbb..",
        ".bcbbbbbb...",
        "Kccbbbb.....",
        ".ccc........",
    ],
}


def disegna(tela, v, g, posa):
    parti = []
    vis = v.lato_visibile()
    for nome in ("ant", "post"):
        for lato in "lr":
            def zampa(nome=nome, lato=lato):
                p = [v.xy(g[f"{nome}_{lato}_{i}"]) for i in range(4)]
                rampa = R["manto"] if lato == vis or vis is None else R["manto_scuro"]
                segmento(tela, p[0], p[1], 2.2 if nome == "ant" else 2.8, 1.4, rampa, f"{nome}_{lato}")
                segmento(tela, p[1], p[2], 1.2, 1.0, rampa, f"{nome}_{lato}")
                segmento(tela, p[2], p[2], 1.3, 1.3, R["zoccolo"], f"{nome}_{lato}")
            parti.append((v.prof(g[f"{nome}_{lato}_1"]) + (0.4 if lato == vis else 0), 0, zampa))

    def coda():
        a, b = v.xy(g["coda_0"]), v.xy(g["coda_1"])
        m = (a[0] * 0.5 + b[0] * 0.5, a[1] * 0.5 + b[1] * 0.5)
        segmento(tela, a, m, 1.6, 1.8, R["manto"], "coda")
        segmento(tela, m, m, 1.9, 1.9, R["crema"], "coda", uniti=("coda",))          # il fiocco bianco
    parti.append((v.prof(g["coda_1"]), 0.5, coda))

    def corpo():
        a, s = v.xy(g["anche"]), v.xy(g["spalle"])
        segmento(tela, a, s, 4.6, 5.0, R["manto"], "corpo", piatto=0.2)
        if v.dir != "up":                                   # pancia chiara sotto
            pa, ps = v.xy(g["anche"] - g["su"] * 2.4), v.xy(g["spalle"] - g["su"] * 2.4)
            segmento(tela, pa, ps, 2.2, 2.4, R["crema"], "pancia", uniti=("corpo",), separa=False)
        if v.dir != "down":                                 # macchie chiare sul dorso
            for k in range(5):
                p = g["anche"] + (g["spalle"] - g["anche"]) * (0.2 + k * 0.15) + g["su"] * 2.6 + \
                    np.array([(k % 2 - 0.5) * 1.6, 0, 0])
                x, y = v.xy(p)
                griglia(tela, ["c"], {"c": colore("cream")}, int(round(x)), int(round(y)), f"macchia{k}", separa=False)
        c = v.xy(g["collo"])                                # collo lungo, gola crema
        segmento(tela, s, c, 3.4, 2.6, R["manto"], "collo", uniti=("corpo",))
        if v.dir != "up":
            segmento(tela, (s[0], s[1] + 1), (c[0], c[1] + 1), 1.4, 1.0, R["crema"], "gola", uniti=("collo", "corpo"),
                     separa=False)
    parti.append((v.prof((g["anche"] + g["spalle"]) / 2), 1, corpo))

    def testa():
        righe, spec = (TESTA["left"], v.dir == "right") if v.dir in ("left", "right") else (TESTA[v.dir], False)
        x, y = v.xy(g["testa"])
        w, h = len(righe[0]), len(righe)
        dx = {"left": -2, "right": 2}.get(v.dir, 0)
        griglia(tela, righe, M, int(round(x - w / 2 + dx)), int(round(y - h + 3)), "testa", specchia=spec,
                uniti=("collo",))
    parti.append((v.prof(g["testa"]) + (8.0 if v.dir == "up" else 2.0), 3, testa))

    for _, _, f in sorted(parti, key=lambda p: (p[0], p[1])):
        f()


FERMO = dict(ant_l=(0, 2, 0), ant_r=(0, 2, 0), post_l=(0, 2, 0), post_r=(0, 2, 0), coda=(10, 0))

ANIM = {
    # bruca (testa giu'), poi alza la testa e guarda (orecchie dritte): 4 frame in ciclo
    "idle": {"chiavi": [
        (0.0, dict(FERMO, testa=(70, 0), piega=6)),
        (0.25, dict(FERMO, testa=(75, 4), piega=6)),
        (0.5, dict(FERMO, testa=(-5, 0), coda=(20, 0))),
        (0.75, dict(FERMO, testa=(-5, 12), coda=(25, 0)))]},
    # salto: si raccoglie, si stende tutto in aria, atterra davanti; la coda bianca alta
    "fuga": {"chiavi": [
        (0.0, dict(FERMO, ant_l=(40, 2, 90), ant_r=(35, 2, 90), post_l=(-10, 2, 40), post_r=(-15, 2, 40),
                   coda=(70, 0), piega=8)),
        (1 / 3, dict(FERMO, ant_l=(70, 2, 20), ant_r=(65, 2, 20), post_l=(-60, 2, 10), post_r=(-65, 2, 10),
                     coda=(75, 0), piega=-8, a_terra=False, bob=4)),
        (2 / 3, dict(FERMO, ant_l=(20, 2, 70), ant_r=(10, 2, 70), post_l=(30, 2, 60), post_r=(25, 2, 60),
                     coda=(70, 0), piega=4, a_terra=False, bob=2))]},
}
