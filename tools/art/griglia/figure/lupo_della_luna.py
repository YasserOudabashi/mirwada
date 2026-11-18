"""Il lupo della luna (nemico_base, aspetto lupo_della_luna), a griglia: lupo grigio-argento con le ombre azzurre,
criniera chiara sul petto, la falce di luna bianca sulla fronte, occhi ambra. Il tell (anticipo) e' estremo: si
abbassa sulle zampe anteriori, testa bassa, coda dritta in su, bocca aperta.
"""
import numpy as np

from ..corpo import Quadrupede
from ..pixel import Rampa, colore, griglia, segmento

CORPO = Quadrupede(lungo=17.0, anca=12.0, spalla=13.0, largo=4.0, zampa=(6.6, 6.4), collo=4.6)

R = {
    "pelo": Rampa("slate", "grey", "grey_l"),
    "pelo_scuro": Rampa("slate_d", "slate", "grey"),
    "criniera": Rampa("grey", "grey_l", "white"),
    "zampa": Rampa("slate_d", "slate", "grey"),
}
M = {"g": colore("grey"), "l": colore("grey_l"), "s": colore("slate"), "S": colore("slate_d"), "w": colore("white"),
     "K": colore("ink"), "y": colore("amber"), "Y": colore("yellow"), "m": colore("red_d"), "t": colore("white"),
     "p": colore("purple_d")}

TESTA = {
    "down": [
        "..l..........s..",
        ".lll........sss.",
        ".lpl........sps.",
        ".lppl......spps.",
        "llggllwwwggggggs",
        "lgggggwwgggggggs",
        "lggYYKggggYYKggs",
        "lggYKKggggYKKgss",
        "lgggggllllgggggs",
        ".lgggllllllgggs.",
        "..lglllllllllg..",
        "...lllKKKKllls..",
        "....llKKKKlls...",
        ".....llllllS....",
        "......SSSS......",
    ],
    "up": [
        ".s.........s.",
        ".ss.......ss.",
        ".sgs.....sgs.",
        "sgggggggggggs",
        "sglllllgggggs",
        "sglllggggggss",
        ".sgggggggggs.",
        "..ssgggggss..",
        "....sssss....",
    ],
    "left": [
        "......ls......",
        ".....lls......",
        "....lpgs......",
        "...lggwgggs...",
        "..lgwgggggggs.",
        ".lgYKggggggss.",
        "llllgggggggs..",
        "Klllllgggggs..",
        ".slllllgggs...",
        "..ssllggs.....",
    ],
}
# bocca aperta (morso, anticipo): sostituisce le righe del muso
APERTA = {
    "down": TESTA["down"][:11] + [
        "...ltmmmmmtls...",
        "....lmmmmmls....",
        ".....tllllt.....",
        "......SSSS......",
    ],
    "left": TESTA["left"][:7] + [
        "Klllgggggggs..",
        ".tmmmlgggss...",
        "..mmmllggs....",
        "..sllls.......",
    ],
}


def disegna(tela, v, g, posa):
    parti = []
    vis = v.lato_visibile()
    for nome in ("ant", "post"):
        for lato in "lr":
            def zampa(nome=nome, lato=lato):
                p = [v.xy(g[f"{nome}_{lato}_{i}"]) for i in range(4)]
                r0 = 2.6 if nome == "ant" else 3.2
                segmento(tela, p[0], p[1], r0, 1.8, R["pelo"] if lato == vis or vis is None else R["pelo_scuro"],
                         f"{nome}_{lato}")
                segmento(tela, p[1], p[2], 1.6, 1.3, R["zampa"], f"{nome}_{lato}")
                segmento(tela, p[2], p[3], 1.5, 1.4, R["zampa"], f"{nome}_{lato}")
            d = v.prof(g[f"{nome}_{lato}_1"]) + (0.4 if lato == vis else 0)
            parti.append((d, 0, zampa))

    def coda():
        a, b, c = (v.xy(g[f"coda_{i}"]) for i in range(3))
        segmento(tela, a, b, 1.8, 2.2, R["pelo"], "coda")
        m = (b[0] * 0.4 + c[0] * 0.6, b[1] * 0.4 + c[1] * 0.6)
        segmento(tela, b, m, 2.2, 1.6, R["pelo"], "coda", uniti=("coda",))
        segmento(tela, m, c, 1.6, 0.7, R["criniera"], "coda", uniti=("coda",))
    parti.append((v.prof(g["coda_1"]), 0.5, coda))

    def corpo():
        a, s = v.xy(g["anche"]), v.xy(g["spalle"])
        segmento(tela, a, s, 5.8, 6.8, R["pelo"], "corpo", piatto=0.2)
        c = v.xy(g["collo"])
        segmento(tela, s, c, 4.6, 4.2, R["pelo"] if v.dir == "up" else R["criniera"], "criniera")          # criniera chiara sul petto e collo
    parti.append((v.prof((g["anche"] + g["spalle"]) / 2), 1, corpo))

    def testa():
        aperta = posa.get("bocca", 0) > 0.5
        if v.dir in ("left", "right"):
            righe = (APERTA if aperta else TESTA)["left"]
            spec = v.dir == "right"
        else:
            righe = (APERTA if aperta and v.dir == "down" else TESTA)[v.dir]
            spec = False
        gira = 0
        if abs(posa.get("cade", 0)) > 50:
            gira = 1 if v.dir != "right" else 3
        x, y = v.xy(g["testa"])
        w, h = len(righe[0]), len(righe)
        if gira:
            w, h = h, w
        dx = {"left": -2, "right": 2}.get(v.dir, 0)
        griglia(tela, righe, M, int(round(x - w / 2 + dx)), int(round(y - h / 2)), "testa", specchia=spec,
                ruota=gira, uniti=("criniera",))
    parti.append((v.prof(g["testa"]) + (8.0 if v.dir == "up" else 2.0), 3, testa))

    for _, _, f in sorted(parti, key=lambda p: (p[0], p[1])):
        f()


# --- Animazioni (nemico_base: idle 6, walk 8, anticipo 4, attack 6 con il colpo al frame 2, stagger 4, death 10) ---
FERMO = dict(ant_l=(0, 2, 0), ant_r=(0, 2, 0), post_l=(0, 2, 0), post_r=(0, 2, 0), coda=(10, 0))


def _trotto(t, a, b, bob=0.0):
    """Trotto: anteriore sinistra con posteriore destra (a), e le altre due (b)."""
    return (t, dict(FERMO, ant_l=(a, 2, 10 if a < 0 else 30), post_r=(a, 2, 10), ant_r=(b, 2, 10 if b < 0 else 30),
                    post_l=(b, 2, 10), bob=bob, coda=(25, 4 if a > 0 else -4)))


ANIM = {
    "idle": {"chiavi": [(0.0, dict(FERMO)), (0.5, dict(FERMO, bob=-0.6, testa=(10, 0), coda=(16, 6)))]},
    "walk": {"chiavi": [_trotto(0.0, 26, -22), _trotto(0.25, 0, 4, 0.8), _trotto(0.5, -22, 26),
                        _trotto(0.75, 4, 0, 0.8)]},
    "anticipo": {"chiavi": [
        (0.0, dict(FERMO, piega=10, testa=(20, 0), coda=(40, 0))),
        (0.5, dict(FERMO, piega=22, testa=(34, 0), coda=(70, 0), bocca=1, ant_l=(30, 6, 60), ant_r=(30, 6, 60),
                   post_l=(-12, 4, 20), post_r=(-12, 4, 20), avanti=-1.5, tieni=True)),
        (1.0, dict(FERMO, piega=24, testa=(36, 0), coda=(75, 0), bocca=1, ant_l=(32, 6, 64), ant_r=(32, 6, 64),
                   post_l=(-14, 4, 24), post_r=(-14, 4, 24), avanti=-2))]},
    "attack": {"chiavi": [
        (0.0, dict(FERMO, piega=20, testa=(30, 0), bocca=1, coda=(60, 0), ant_l=(30, 6, 60), ant_r=(30, 6, 60),
                   avanti=-2)),
        (0.2, dict(FERMO, piega=-12, testa=(-5, 0), bocca=1, coda=(10, 0), ant_l=(60, 4, 70), ant_r=(55, 4, 70),
                   post_l=(-40, 4, 10), post_r=(-40, 4, 10), avanti=4, a_terra=False, bob=3)),
        (0.4, dict(FERMO, piega=6, testa=(10, 0), bocca=0, coda=(15, 0), ant_l=(40, 4, 20), ant_r=(36, 4, 20),
                   post_l=(-30, 4, 10), post_r=(-30, 4, 10), avanti=6)),
        (0.6, dict(FERMO, piega=10, testa=(16, 0), coda=(20, 0), ant_l=(20, 4, 10), ant_r=(18, 4, 10), avanti=5)),
        (1.0, dict(FERMO))]},
    "stagger": {"chiavi": [
        (0.0, dict(FERMO, piega=-14, testa=(-25, 0), avanti=-2, coda=(-10, 0), ant_l=(30, 6, 40),
                   ant_r=(30, 6, 40), bocca=1)),
        (0.5, dict(FERMO, piega=-8, testa=(-15, 10), avanti=-2.5, coda=(-20, 0))),
        (1.0, dict(FERMO, coda=(0, 0)))]},
    "death": {"vista": "left", "chiavi": [
        (0.0, dict(FERMO, piega=-10, testa=(-25, 0), bocca=1)),
        (2 / 9, dict(FERMO, piega=12, testa=(30, 0), ant_l=(30, 4, 70), ant_r=(30, 4, 70), bocca=1)),
        (4 / 9, dict(FERMO, piega=20, testa=(40, 0), ant_l=(60, 4, 120), ant_r=(60, 4, 120), post_l=(20, 4, 40),
                     post_r=(20, 4, 40), cade=30)),
        (7 / 9, dict(FERMO, testa=(10, 0), ant_l=(20, 10, 20), ant_r=(30, 10, 20), post_l=(-10, 10, 20),
                     post_r=(0, 10, 20), cade=85, coda=(-30, 0))),
        (1.0, dict(FERMO, testa=(10, 0), ant_l=(24, 10, 24), ant_r=(34, 10, 24), post_l=(-12, 10, 22),
                   post_r=(0, 10, 22), cade=90, coda=(-34, 0)))]},
}
