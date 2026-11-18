"""Enel (il protagonista, id `personaggio`), a griglia: 3 teste, contorno nero, 3 toni.

Coppola marrone, capelli neri corti, pelle chiara e stanca, occhi freddi azzurri che brillano, una crepa di luce
sulla guancia, cappotto lungo blu-ardesia aperto davanti, sciarpa rossa, bende bianche sugli avambracci, stivali,
spadone a due mani portato in spalla.
"""
import numpy as np

from ..corpo import Umano
from ..pixel import Rampa, colore, griglia, segmento

ALTEZZA = 42
CORPO = Umano(anca=14.0, busto=10.5, spalle=5.6, fianchi=2.4, braccio=5.0, avambraccio=4.6,
              coscia=7.0, stinco=7.0, piede=2.0, collo=0.5)

R = {
    "pelle": Rampa("skin_m", "skin_l", "cream"),
    "capelli": Rampa("navy", "slate_d", "slate"),
    "coppola": Rampa("brown_dd", "brown_d", "brown"),
    "cappotto": Rampa("navy", "slate_d", "slate"),
    "camicia": Rampa("brown_dd", "purple_d", "purple"),
    "pantaloni": Rampa("ink", "navy", "slate_d"),
    "stivali": Rampa("brown_dd", "brown_d", "brown"),
    "sciarpa": Rampa("red_d", "red", "pink"),
    "bende": Rampa("grey", "grey_l", "white"),
    "cuoio": Rampa("brown_dd", "brown_d", "brown"),
    "oro": Rampa("orange_d", "amber", "yellow"),
    "lama": Rampa("slate", "grey", "grey_l", riflesso="white"),
}

M = {"C": colore("brown_d"), "c": colore("brown"), "q": colore("brown_dd"),
     "H": colore("slate_d"), "h": colore("slate"), "n": colore("navy"),
     "S": colore("skin_l"), "s": colore("cream"), "d": colore("skin_m"),
     "e": colore("cyan"), "E": colore("blue"), "w": colore("white"), "g": colore("cyan"),
     "m": colore("brown_d"), "K": colore("ink")}

# Teste 14 x 13. Vista da davanti, da dietro e di profilo verso sinistra (a destra si specchia).
TESTA = {
    "down": [
        "...ccCCCCCq...",
        ".cccCCCCCCCCq.",
        "cccCCCCCCCCCCq",
        "qccccccccccccq",
        "nHqqqqqqqqqqHn",
        "HhsKKssssKKdHn",
        "HsswessssweSdn",
        "HgSeESSSSeESdn",
        "HSgSSSSSSSSddn",
        ".HSSSSmmSSSdn.",
        "..dSSSSSSSdd..",
        "...dddddddd...",
    ],
    "up": [
        "...ccCCCCCq...",
        ".cccCCCCCCCCq.",
        "cccCCCCCCCCCCq",
        "qCCCCCCCCCCCqq",
        "nqqqqqqqqqqqqn",
        "HhhHHHHHHHHHHn",
        "HhHHHHHHHHHHnn",
        "HHHHHHHHHHHHnn",
        ".nHHHHHHHHHnn.",
        "..nnHHHHHHnn..",
        "....dSSSSd....",
        "....dddddd....",
    ],
    "left": [
        "....ccCCCCq...",
        "...cccCCCCCCq.",
        "..cccCCCCCCCCq",
        "cccccccccCCCqq",
        "..qqqqqqHhHHHn",
        "..sKKssHhHHHHn",
        "..swesSShHHHHn",
        ".ssEESSgHHHHHn",
        "..SSSSgSdHHHnn",
        "..SmSSSSdHHnn.",
        "...dSSSSdnn...",
        "....ddddd.....",
    ],
}


def _p(v, g):
    return v.xy(g)


def disegna(tela, v, g, posa):
    """Ordina le parti per profondita' e le posa sulla tela."""
    parti = []
    vis = v.lato_visibile()
    dietro = v.prof(g["bacino"] - np.array([0, 1.5, 0]))

    for lato in "lr":
        def gamba(lato=lato):
            a, k, c, t = (v.xy(g[f"{n}_{lato}"]) for n in ("anca", "ginocchio", "caviglia", "punta"))
            segmento(tela, a, k, 2.1, 1.9, R["pantaloni"], f"gamba_{lato}")
            segmento(tela, k, c, 1.9, 1.8, R["pantaloni"], f"gamba_{lato}")
            cs = (c[0], c[1] - 1.2)
            segmento(tela, cs, c, 2.0, 2.0, R["stivali"], f"gamba_{lato}", uniti=(f"gamba_{lato}",))
            segmento(tela, c, t, 1.9, 1.5, R["stivali"], f"gamba_{lato}")
        parti.append((v.prof(g[f"ginocchio_{lato}"]) + (0.3 if vis == lato else 0), 0, gamba))

        def braccio(lato=lato):
            s, e, m = (v.xy(g[f"{n}_{lato}"]) for n in ("spalla", "gomito", "mano"))
            segmento(tela, s, e, 1.9, 1.7, R["cappotto"], f"braccio_{lato}")
            segmento(tela, e, m, 1.6, 1.5, R["bende"], f"braccio_{lato}")
            segmento(tela, m, m, 1.7, 1.7, R["pelle"], f"braccio_{lato}")
        dp = v.prof(g[f"gomito_{lato}"]) * 0.5 + v.prof(g[f"mano_{lato}"]) * 0.5
        parti.append((dp + (0.6 if vis == lato else 0) + 0.2, 2, braccio))

    def falde():
        b = g["bacino"] - g["su"] * 0.5
        dietro_v = -np.array([0, 1.0, 0])
        a = v.xy(b + dietro_v * 0.8)
        z = v.xy(b - np.array([0, 0, 7.5]) + dietro_v * 1.6)
        segmento(tela, a, z, 4.4, 5.2, R["cappotto"], "falde", tappi=False, piatto=0.5)
    parti.append((dietro - 0.5, -1, falde))

    def busto():
        a, b = v.xy(g["bacino"] + g["su"] * 0.5), v.xy(g["collo"])
        segmento(tela, a, b, 4.4, 5.3, R["cappotto"], "busto", tappi=False, piatto=0.35)
        if v.dir == "down":                      # cappotto aperto: camicia scura e cintura
            segmento(tela, (a[0], a[1] - 1), (b[0], b[1] + 1), 1.4, 1.6, R["camicia"], "camicia", tappi=False)
            segmento(tela, (a[0] - 3.5, a[1] - 0.5), (a[0] + 3.5, a[1] - 0.5), 0.8, 0.8, R["cuoio"], "cintura",
                     tappi=False, separa=False)
        elif v.dir in ("left", "right"):
            segmento(tela, (a[0], a[1] - 0.5), (b[0], b[1] + 1), 0.7, 0.7, R["camicia"], "camicia",
                     tappi=False, separa=False)
        # sciarpa intorno al collo
        c = v.xy(g["collo"] - g["su"] * 0.8)
        segmento(tela, (c[0] - 3.8, c[1]), (c[0] + 3.8, c[1]), 1.6, 1.6, R["sciarpa"], "sciarpa")
    parti.append((v.prof(g["bacino"]), 1, busto))

    if v.dir != "down":                          # coda della sciarpa sulla schiena
        def coda():
            c = g["collo"] - g["su"] * 1.0 - np.array([0, 1.8, 0])
            z = c - g["su"] * 5.5 - np.array([0, 1.5 + posa.get("vento", 0.0), 0])
            segmento(tela, v.xy(c), v.xy(z), 1.4, 1.2, R["sciarpa"], "sciarpa_coda", uniti=("sciarpa",))
        parti.append((v.prof(g["bacino"]) + 0.3, 1.5, coda))

    def testa():
        x, y = v.xy(g["testa"] + g["su"] * 4.5)
        if v.dir in ("left", "right"):
            righe, spec = TESTA["left"], v.dir == "right"
        else:
            righe, spec = TESTA[v.dir], False
        gira = 0
        if abs(posa.get("cade", 0)) > 50:
            gira = 3 if posa.get("cade", 0) > 0 else 1
        w, h = len(righe[0]), len(righe)
        if gira:
            w, h = h, w
        griglia(tela, righe, M, int(round(x - w / 2)), int(round(y - h / 2)), "testa", specchia=spec, ruota=gira)
    parti.append((v.prof(g["testa"]) + 1.2, 3, testa))

    schiena = posa.get("arma_su", "mano") == "schiena"
    if schiena:                                  # sulla schiena: elsa sopra la spalla destra, punta al fianco sinistro
        avanti = np.cross(g["su"], g["destra"])
        d = -g["su"] * 1.0 - g["destra"] * 0.75 - avanti * 0.55
        d /= np.linalg.norm(d)
        pomo = g["spalle_c"] + g["destra"] * 8.5 + g["su"] * 6.0 - avanti * 1.6
    else:
        d = g["arma_dir"]
        pomo = g["mano_r"] - d * 2.6

    def arma():
        perp = np.cross(d, np.array([0, 0, 1.0]))
        if np.linalg.norm(perp) < 0.2:
            perp = np.cross(d, np.array([0, 1.0, 0]))
        perp /= np.linalg.norm(perp)
        segmento(tela, v.xy(pomo + d * 0.6), v.xy(pomo + d * 4.8), 0.9, 0.9, R["cuoio"], "arma")
        segmento(tela, v.xy(pomo), v.xy(pomo), 1.2, 1.2, R["oro"], "arma", uniti=("arma",))
        gu = pomo + d * 5.2
        segmento(tela, v.xy(gu - perp * 2.8), v.xy(gu + perp * 2.8), 0.9, 0.9, R["oro"], "arma", uniti=("arma",))
        segmento(tela, v.xy(pomo + d * 5.8), v.xy(pomo + d * 19.6), 1.45, 1.1, R["lama"], "arma", uniti=("arma",))
        segmento(tela, v.xy(pomo + d * 19.6), v.xy(pomo + d * 21.6), 1.1, 0.35, R["lama"], "arma", uniti=("arma",))
    lama_c = pomo + d * 11
    parti.append((v.prof(lama_c) - (1.5 if schiena else 0), 2.5, arma))

    if posa.get("fiala"):                        # la fiala nella mano libera (drink)
        def fiala():
            x, y = v.xy(g["mano_l"])
            griglia(tela, [".K.", "GgG", "GGG", ".G."], {"K": colore("brown_d"), "G": colore("red"),
                                                         "g": colore("pink")}, int(round(x - 1)), int(round(y - 4)),
                    "fiala")
        parti.append((v.prof(g["mano_l"]) + 0.5, 4, fiala))

    for _, _, f in sorted(parti, key=lambda p: (p[0], p[1])):
        f()


# --- Animazioni ---------------------------------------------------------------------------------------------------
# Chiavi a tempo normalizzato (pose.py). I frame e i tempi sono in data/animations.json; qui solo le pose.
# Le fasi dei dati: attack_light 8 frame (anticipo 0-2, colpo 3, recupero 4-7); attack_heavy 12 (anticipo 0-5,
# colpo 6-7, recupero 8-11): t = frame / (frame - 1).
SCH = {"arma_su": "schiena"}
FERMO = dict(SCH, braccio_l=(4, 10, 14), braccio_r=(4, 10, 14))
PRONTO = dict(braccio_r=(42, 22, 60), braccio_l=(52, -12, 52), arma=(22, 40), gamba_l=(14, 4, 8),
              gamba_r=(-10, 4, 8), piega=6)


def _cam(t0, sx, dx, bob=0.0, ginocchio=(6, 6)):
    return (t0, dict(SCH, gamba_l=(sx, 2, ginocchio[0]), gamba_r=(dx, 2, ginocchio[1]),
                     braccio_l=(-sx * 0.9, 12, 18), braccio_r=(-dx * 0.9, 12, 18), bob=bob, piega=4))


ANIM = {
    "idle": {"chiavi": [(0.0, dict(FERMO)), (0.5, dict(FERMO, respiro=1.0, braccio_l=(4, 13, 18),
                                                         braccio_r=(4, 13, 18)))]},
    "walk": {"chiavi": [_cam(0.0, 26, -22, 0, (4, 12)), _cam(0.125, 16, -14, -0.8, (16, 20)),
                        _cam(0.25, 2, 8, 0.4, (6, 45)), _cam(0.375, -12, 20, 0.8, (8, 22)),
                        _cam(0.5, -22, 26, 0, (12, 4)), _cam(0.625, -14, 16, -0.8, (20, 16)),
                        _cam(0.75, 8, 2, 0.4, (45, 6)), _cam(0.875, 20, -12, 0.8, (22, 8))]},
    "dash": {"chiavi": [(0.0, dict(SCH, piega=30, avanti=2, gamba_l=(40, 0, 30), gamba_r=(-35, 0, 20),
                                   braccio_l=(-40, 18, 20), braccio_r=(-40, 18, 20), vento=3)),
                        (0.6, dict(SCH, piega=34, avanti=3, gamba_l=(30, 0, 50), gamba_r=(-40, 0, 30),
                                   braccio_l=(-50, 22, 20), braccio_r=(-50, 22, 20), vento=4)),
                        (1.0, dict(SCH, piega=12, avanti=1, gamba_l=(16, 2, 14), gamba_r=(-12, 2, 10),
                                   braccio_l=(-10, 14, 20), braccio_r=(-10, 14, 20), vento=1))]},
    "attack_light": {"chiavi": [
        (0.0, dict(PRONTO)),
        (1 / 7, dict(PRONTO, gira=24, arma=(30, 95), braccio_r=(34, 40, 70), braccio_l=(48, 6, 64))),
        (2 / 7, dict(PRONTO, gira=34, arma=(38, 125), braccio_r=(28, 52, 80), braccio_l=(44, 14, 70), piega=2)),
        (3 / 7, dict(PRONTO, gira=-26, arma=(6, -35), braccio_r=(78, 4, 8), braccio_l=(74, -22, 14), avanti=2,
                     piega=12, gamba_l=(26, 4, 16))),
        (4 / 7, dict(PRONTO, gira=-40, arma=(-6, -85), braccio_r=(70, -16, 14), braccio_l=(66, -30, 18),
                     avanti=2, piega=14, gamba_l=(26, 4, 16))),
        (6 / 7, dict(PRONTO, gira=-12, arma=(10, 10), avanti=1)),
        (1.0, dict(PRONTO))]},
    "attack_heavy": {"chiavi": [
        (0.0, dict(PRONTO)),
        (2 / 11, dict(PRONTO, arma=(80, 10), braccio_r=(110, 12, 40), braccio_l=(105, -12, 40), piega=0)),
        (5 / 11, dict(PRONTO, arma=(140, 0), braccio_r=(165, 14, 34), braccio_l=(160, -12, 34), piega=-14,
                      bob=1, gamba_l=(10, 4, 4), gamba_r=(-14, 4, 6), tieni=True)),
        (6 / 11, dict(PRONTO, arma=(10, 0), braccio_r=(110, 8, 6), braccio_l=(108, -8, 6), piega=18, avanti=2.5,
                      gamba_l=(30, 4, 30), gamba_r=(-18, 4, 12))),
        (7 / 11, dict(PRONTO, arma=(-40, 0), braccio_r=(70, 6, 2), braccio_l=(68, -8, 2), piega=30, avanti=3,
                      gamba_l=(32, 4, 40), gamba_r=(-20, 4, 14))),
        (9 / 11, dict(PRONTO, arma=(-30, 5), braccio_r=(64, 8, 10), braccio_l=(62, -8, 10), piega=24, avanti=2,
                      gamba_l=(26, 4, 30), gamba_r=(-16, 4, 12))),
        (1.0, dict(PRONTO))]},
    "parry": {"chiavi": [
        (0.0, dict(PRONTO, arma=(70, 25), braccio_r=(70, 20, 70), braccio_l=(68, -14, 70), piega=-4,
                   gamba_l=(18, 6, 14), gamba_r=(-18, 6, 14))),
        (1 / 3, dict(PRONTO, arma=(72, 25), braccio_r=(72, 20, 72), braccio_l=(70, -14, 72), piega=-6,
                     avanti=-1, gamba_l=(18, 6, 16), gamba_r=(-18, 6, 16))),
        (1.0, dict(PRONTO))]},
    "hurt": {"chiavi": [(0.0, dict(FERMO, piega=-16, avanti=-1.5, testa=(-20, 0), braccio_l=(-10, 40, 30),
                                   braccio_r=(-10, 40, 30))),
                        (0.5, dict(FERMO, piega=-22, avanti=-2, braccio_l=(-14, 46, 40), braccio_r=(-14, 46, 40),
                                   gamba_l=(10, 4, 14))),
                        (1.0, dict(FERMO, piega=-6))]},
    "death": {"vista": "left", "chiavi": [
        (0.0, dict(FERMO, piega=-14, braccio_l=(-10, 40, 30), braccio_r=(-10, 40, 30))),
        (2 / 9, dict(FERMO, piega=10, gamba_l=(40, 4, 70), gamba_r=(30, 4, 80), braccio_l=(20, 20, 20),
                     braccio_r=(20, 20, 20))),
        (4 / 9, dict(FERMO, piega=24, gamba_l=(80, 4, 110), gamba_r=(70, 4, 120), braccio_l=(30, 14, 10),
                     braccio_r=(30, 14, 10), testa=(20, 0))),
        (6 / 9, dict(FERMO, piega=10, gamba_l=(50, 4, 60), gamba_r=(40, 4, 60), cade=50, scivola=8,
                     braccio_l=(80, 30, 10), braccio_r=(80, 30, 10))),
        (8 / 9, dict(FERMO, cade=90, scivola=18, braccio_l=(150, 30, 10), braccio_r=(150, 30, 10), gamba_l=(10, 4, 10),
                     gamba_r=(4, 4, 6))),
        (1.0, dict(FERMO, cade=90, scivola=18, braccio_l=(160, 34, 6), braccio_r=(160, 34, 6), gamba_l=(10, 4, 8),
                   gamba_r=(4, 4, 4)))]},
    "cast": {"chiavi": [
        (0.0, dict(FERMO, braccio_l=(40, -10, 80), braccio_r=(40, 10, 80))),
        (0.4, dict(FERMO, braccio_l=(60, -24, 100), braccio_r=(60, 24, 100), piega=-4, bob=0.5)),
        (0.6, dict(FERMO, braccio_l=(95, 0, 0), braccio_r=(20, 30, 40), piega=10, avanti=1.5,
                   gamba_l=(20, 4, 12), gamba_r=(-14, 4, 8))),
        (1.0, dict(FERMO))]},
    "meditate": {"vista": "down", "chiavi": [
        (0.0, dict(SCH, gamba_l=(82, 38, 150), gamba_r=(82, 38, 150), braccio_l=(36, 18, 50),
                   braccio_r=(36, 18, 50))),
        (0.5, dict(SCH, gamba_l=(82, 38, 150), gamba_r=(82, 38, 150), braccio_l=(36, 20, 52),
                   braccio_r=(36, 20, 52), respiro=1.0))]},
    "interact": {"chiavi": [(0.0, dict(FERMO)),
                            (2 / 3, dict(FERMO, braccio_l=(80, 4, 6), piega=6, avanti=0.5, tieni=True)),
                            (1.0, dict(FERMO, braccio_l=(30, 8, 40)))]},
    "pickup": {"chiavi": [(0.0, dict(FERMO)),
                          (0.25, dict(FERMO, piega=26, gamba_l=(20, 6, 30), gamba_r=(12, 6, 30),
                                      braccio_l=(20, 10, 10))),
                          (0.5, dict(FERMO, piega=48, gamba_l=(34, 8, 62), gamba_r=(20, 8, 58),
                                     braccio_l=(8, 6, 0), tieni=True)),
                          (0.75, dict(FERMO, piega=26, gamba_l=(40, 6, 60), gamba_r=(30, 6, 60),
                                      braccio_l=(40, 10, 60))),
                          (1.0, dict(FERMO, braccio_l=(20, 10, 60)))]},
    "drink": {"fiala": True, "chiavi": [
        (0.0, dict(FERMO, braccio_l=(30, 6, 70))),
        (0.4, dict(FERMO, braccio_l=(70, -26, 120))),
        (0.6, dict(FERMO, braccio_l=(100, -30, 120), testa=(-25, 0), piega=-8, tieni=True)),
        (1.0, dict(FERMO, braccio_l=(30, 6, 70)))]},
    "ritual": {"chiavi": [
        (0.0, dict(SCH, braccio_l=(170, 32, 14), braccio_r=(170, 32, 14), testa=(-10, 0))),
        (0.5, dict(SCH, braccio_l=(160, 42, 24), braccio_r=(160, 42, 24), testa=(-14, 0), bob=0.8,
                   respiro=-0.5))]},
    "fly": {"chiavi": [
        (0.0, dict(SCH, a_terra=False, bob=4, gamba_l=(10, 6, 24), gamba_r=(-6, 6, 34), braccio_l=(10, 34, 20),
                   braccio_r=(10, 34, 20), vento=2)),
        (0.5, dict(SCH, a_terra=False, bob=5, gamba_l=(4, 6, 30), gamba_r=(-10, 6, 28), braccio_l=(10, 40, 24),
                   braccio_r=(10, 40, 24), vento=3))]},
    "sail": {"chiavi": [
        (0.0, dict(SCH, gamba_l=(85, 8, 160), gamba_r=(85, 8, 160), braccio_l=(60, 20, 20),
                   braccio_r=(30, 14, 70), piega=10)),
        (0.5, dict(SCH, gamba_l=(85, 8, 160), gamba_r=(85, 8, 160), braccio_l=(10, 24, 20),
                   braccio_r=(30, 14, 70), piega=16))]},
}
