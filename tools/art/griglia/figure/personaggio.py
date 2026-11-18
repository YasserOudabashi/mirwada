"""Enel (il protagonista, id `personaggio`), a griglia: 3 teste, contorno nero, 3 toni.

Coppola marrone, capelli neri corti, pelle chiara e stanca, occhi freddi azzurri che brillano, una crepa di luce
sulla guancia, cappotto lungo blu-ardesia aperto davanti, sciarpa rossa, bende bianche sugli avambracci, stivali,
spadone a due mani portato in spalla.
"""
import numpy as np

from ..corpo import Umano
from ..pixel import Rampa, colore, griglia, segmento

ALTEZZA = 42
# gambe corte e busto largo (giudizio dell'utente, 2026-11-18): la figura si legge dal busto, non dalle gambe
CORPO = Umano(anca=10.5, busto=12.5, spalle=6.8, fianchi=2.9, braccio=5.4, avambraccio=4.8,
              coscia=5.2, stinco=5.3, piede=2.2, collo=0.5)

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
    "luce": Rampa("blue", "cyan", "white"),
    "sangue": Rampa("red_d", "red_d", "red"),
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

# faccia del dolore (hurt): occhi strizzati, sopracciglia su in mezzo, bocca aperta
DOLORE = {
    "down": TESTA["down"][:5] + ["HhssKssssKsdHn", "HssKKssssKKSdn", "HgSSSSSSSSSSdn", "HSgSSSSSSSSddn",
                                 ".HSSSmKKmSSdn."] + TESTA["down"][10:],
    "left": TESTA["left"][:5] + ["..ssKssHhHHHHn", "..sKKsSShHHHHn", ".ssSSSSgHHHHHn", "..SSSSgSdHHHnn",
                                 "..KmSSSSdHHnn."] + TESTA["left"][10:],
}
SANGUE = {"r": colore("red"), "R": colore("red_d"), "p": colore("pink")}


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
            segmento(tela, a, k, 2.5, 2.2, R["pantaloni"], f"gamba_{lato}")
            segmento(tela, k, c, 2.2, 2.0, R["pantaloni"], f"gamba_{lato}")
            cs = (c[0], c[1] - 1.2)
            segmento(tela, cs, c, 2.0, 2.0, R["stivali"], f"gamba_{lato}", uniti=(f"gamba_{lato}",))
            segmento(tela, c, t, 1.9, 1.5, R["stivali"], f"gamba_{lato}")
        parti.append((v.prof(g[f"ginocchio_{lato}"]) + (0.3 if vis == lato else 0), 0, gamba))

        def braccio(lato=lato):
            s, e, m = (v.xy(g[f"{n}_{lato}"]) for n in ("spalla", "gomito", "mano"))
            segmento(tela, s, e, 2.3, 2.0, R["cappotto"], f"braccio_{lato}")
            segmento(tela, e, m, 1.8, 1.6, R["bende"], f"braccio_{lato}")
            segmento(tela, m, m, 1.9, 1.9, R["pelle"], f"braccio_{lato}")
        dp = v.prof(g[f"gomito_{lato}"]) * 0.5 + v.prof(g[f"mano_{lato}"]) * 0.5
        parti.append((dp + (0.6 if vis == lato else 0) + 0.2, 2, braccio))

    def falde():
        b = g["bacino"] - g["su"] * 0.5
        dietro_v = -np.array([0, 1.0, 0])
        a = v.xy(b + dietro_v * 0.8)
        z = v.xy(b - np.array([0, 0, 6.0]) + dietro_v * (1.6 + posa.get("vento", 0.0) * 0.8))
        segmento(tela, a, z, 5.4, 6.4, R["cappotto"], "falde", tappi=False, piatto=0.5)
    parti.append((dietro - 0.5, -1, falde))

    def busto():
        a, b = v.xy(g["bacino"] + g["su"] * 0.5), v.xy(g["collo"])
        segmento(tela, a, b, 5.6, 6.6, R["cappotto"], "busto", tappi=False, piatto=0.35)
        if v.dir == "down":                      # cappotto aperto: camicia scura, cintura con due fiale
            segmento(tela, (a[0], a[1] - 1), (b[0], b[1] + 1), 1.8, 2.0, R["camicia"], "camicia", tappi=False)
            segmento(tela, (a[0] - 4.6, a[1] - 0.5), (a[0] + 4.6, a[1] - 0.5), 0.9, 0.9, R["cuoio"], "cintura",
                     tappi=False, separa=False)
            for dx, liq in (((-3.4, "red"), (-1.6, "cyan")) if abs(posa.get("cade", 0)) < 30 else ()):
                griglia(tela, [".K.", "lLl", "LLL"], {"K": colore("brown_d"), "L": colore(liq), "l": colore("white")},
                        int(round(a[0] + dx * (1 if v.dir == "down" else -1) - 1)), int(round(a[1] - 1)), "fiale")
        elif v.dir in ("left", "right"):
            segmento(tela, (a[0], a[1] - 0.5), (b[0], b[1] + 1), 0.7, 0.7, R["camicia"], "camicia",
                     tappi=False, separa=False)
        # sciarpa intorno al collo
        c = v.xy(g["collo"] - g["su"] * 0.8)
        segmento(tela, (c[0] - 4.8, c[1]), (c[0] + 4.8, c[1]), 1.9, 1.9, R["sciarpa"], "sciarpa")
        if v.dir == "down":                      # un capo della sciarpa che pende sul petto, da una parte sola
            segmento(tela, (c[0] + 2.6, c[1] + 1), (c[0] + 3.4 + posa.get("vento", 0.0), c[1] + 6.5), 1.3, 1.1,
                     R["sciarpa"], "sciarpa", uniti=("sciarpa",))
    parti.append((v.prof(g["bacino"]), 1, busto))

    if v.dir != "down":                          # coda della sciarpa sulla schiena
        def coda():
            c = g["collo"] - g["su"] * 1.0 - np.array([0, 1.8, 0])
            z = c - g["su"] * 5.5 - np.array([0, 1.5 + posa.get("vento", 0.0), 0])
            segmento(tela, v.xy(c), v.xy(z), 1.4, 1.2, R["sciarpa"], "sciarpa_coda", uniti=("sciarpa",))
        parti.append((v.prof(g["bacino"]) + 0.3, 1.5, coda))

    def testa():
        x, y = v.xy(g["testa"] + g["su"] * 4.5)
        facce = DOLORE if posa.get("faccia") == "dolore" else TESTA
        if v.dir in ("left", "right"):
            righe, spec = facce["left"], v.dir == "right"
        else:
            righe, spec = facce.get(v.dir, TESTA[v.dir]), False
        # la testa gira a quarti con il corpo, ma solo di profilo: da davanti chi e' sdraiato all'indietro si vede in
        # faccia (dritto), da dietro a testa in giu'
        q = int(-round(posa.get("cade", 0) / 90.0)) % 4
        gira = q if v.dir in ("left", "right") else (0 if v.dir == "down" else (2 * q) % 4)
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

    fiala = posa.get("fiala")                   # drink: chiusa -> stappata -> inclinata alla bocca
    if fiala:
        def disegna_fiala():
            x, y = v.xy(g["mano_l"])
            righe = [".K.", "GgG", "GGG", ".G."] if fiala == "chiusa" else ["...", "GgG", "GGG", ".G."]
            mappa = {"K": colore("brown_d"), "G": colore("red"), "g": colore("pink")}
            if fiala == "bevi":
                griglia(tela, righe, mappa, int(round(x - 2)), int(round(y - 3)), "fiala",
                        ruota=1 if v.dir != "right" else 3)
            else:
                griglia(tela, righe, mappa, int(round(x - 1)), int(round(y - 5)), "fiala")
            if fiala == "stappa":                # il tappo che salta
                griglia(tela, ["K"], mappa, int(round(x + 2)), int(round(y - 8)), "tappo", separa=False)
        parti.append((v.prof(g["mano_l"]) + 0.5, 4, disegna_fiala))

    ogg = posa.get("oggetto")                    # pickup: il sacchetto a terra davanti, poi in mano
    if ogg:
        def oggetto():
            punto = g["mano_l"] if ogg == "mano" else np.array([-2.0, 4.5, 0.0])
            x, y = v.xy(punto)
            griglia(tela, [".kk.", "kCCk", "CccC", "CCCC"], {"k": colore("brown_dd"), "C": colore("tan"),
                                                           "c": colore("cream")}, int(round(x - 2)),
                    int(round(y - (2 if ogg == "mano" else 3))), "oggetto")
        parti.append(((v.prof(g["mano_l"]) + 0.4) if ogg == "mano" else v.prof(np.array([-2.0, 4.5, 0.0])) - 0.2,
                      4 if ogg == "mano" else -2, oggetto))

    luce = posa.get("luce", 0)                   # cast: qualcosa che si forma nella mano e parte
    if luce:
        def lampo():
            x, y = v.xy(g["mano_l"] + np.array([0, 1.2, 0.5]))
            segmento(tela, (x, y), (x, y), 1.2 + luce, 1.2 + luce, R["luce"], "luce", separa=False)
            segmento(tela, (x - 0.3, y - 0.3), (x - 0.3, y - 0.3), 0.4 + luce * 0.45, 0.4 + luce * 0.45, None,
                     "luce", separa=False, colore_fisso=colore("white"))
        parti.append((v.prof(g["mano_l"]) + 1.0, 5, lampo))

    if posa.get("scintilla"):                    # parry: il colpo che arriva sulla lama
        def scintilla():
            x, y = v.xy(pomo + d * 12)
            griglia(tela, ["..Y..", ".YWY.", "YWWWY", ".YWY.", "..Y.."], {"Y": colore("yellow"), "W": colore("white")},
                    int(round(x - 2)), int(round(y - 2)), "scintilla", separa=False)
        parti.append((99, 6, scintilla))

    sangue = posa.get("sangue", 0)               # gocce che schizzano dal petto (hurt, death)
    if sangue:
        def gocce():
            c = g["spalle_c"] - g["su"] * 2.5
            for i, (dx, dz) in enumerate(((1.0, 0.6), (1.6, -0.2), (0.6, 1.2), (2.0, 0.4), (1.3, -0.8))):
                p = c + np.array([0, -1.0, 0]) * sangue * dx * 3.5 + np.array([(i - 2) * 2.4 * sangue, 0,
                                                                               2.0 + dz * sangue * 3.0])
                x, y = v.xy(p)
                griglia(tela, ["pr", "rR"] if i % 2 else [".r.", "rRr", ".R."], SANGUE, int(round(x)), int(round(y)),
                        "sangue", separa=False)
        parti.append((99, 7, gocce))

    pozza = posa.get("pozza", 0)                 # death: la pozza che si allarga sotto il corpo
    if pozza:
        def pozza_a_terra():
            c = (g["bacino"] + g["collo"]) / 2 * np.array([1, 1, 0])
            x, y = v.xy(c)
            segmento(tela, (x - pozza * 2.6, y), (x + pozza * 2.6, y), pozza * 1.3, pozza * 1.3, R["sangue"],
                     "pozza", separa=False)
        parti.append((-99, -9, pozza_a_terra))

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
    "walk": {"chiavi": [_cam(0.0, 28, -24, 0, (4, 14)), _cam(0.125, 18, -16, -0.8, (18, 30)),
                        _cam(0.25, 6, 14, 0.6, (6, 75)), _cam(0.375, -12, 24, 0.9, (8, 40)),
                        _cam(0.5, -24, 28, 0, (14, 4)), _cam(0.625, -16, 18, -0.8, (30, 18)),
                        _cam(0.75, 14, 6, 0.6, (75, 6)), _cam(0.875, 24, -12, 0.9, (40, 8))]},
    "dash": {"chiavi": [
        (0.0, dict(SCH, piega=18, gamba_l=(30, 4, 50), gamba_r=(-10, 4, 50), braccio_l=(-20, 20, 30),
                   braccio_r=(-20, 20, 30))),
        (2 / 7, dict(SCH, piega=40, avanti=2, gamba_l=(40, 2, 20), gamba_r=(-50, 2, 10), braccio_l=(-60, 22, 10),
                     braccio_r=(-60, 22, 10), vento=3)),
        (4 / 7, dict(SCH, piega=44, avanti=4, gamba_l=(35, 2, 50), gamba_r=(-45, 2, 30), braccio_l=(-70, 24, 10),
                     braccio_r=(-70, 24, 10), vento=4)),
        (6 / 7, dict(SCH, piega=24, avanti=3, gamba_l=(30, 4, 40), gamba_r=(-10, 4, 30), braccio_l=(-20, 18, 20),
                     braccio_r=(-20, 18, 20), vento=2)),
        (1.0, dict(SCH, piega=10, avanti=2, gamba_l=(14, 4, 14), gamba_r=(-8, 4, 10), braccio_l=(-6, 14, 18),
                   braccio_r=(-6, 14, 18), vento=1))]},
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
    # carica raccolta IN AVANTI (mai all'indietro): piedi larghi, peso sulla gamba davanti, spadone alto dietro la
    # spalla destra. Il frame 5 e' quello che il gioco tiene fermo mentre si carica (tenendo premuto il tasto).
    "attack_heavy": {"chiavi": [
        (0.0, dict(PRONTO)),
        (2 / 11, dict(PRONTO, arma=(45, 160), braccio_r=(95, 30, 90), braccio_l=(95, 4, 85), gira=12, piega=18,
                      avanti=1.0, gamba_l=(28, 6, 34), gamba_r=(-8, 6, 14))),
        (5 / 11, dict(PRONTO, arma=(65, 175), braccio_r=(125, 26, 95), braccio_l=(122, 4, 95), gira=14, piega=24,
                      avanti=2.0, gamba_l=(32, 8, 46), gamba_r=(-8, 8, 18), tieni=True)),
        (6 / 11, dict(PRONTO, arma=(10, 0), braccio_r=(105, 8, 6), braccio_l=(102, -8, 6), gira=-4, piega=22,
                      avanti=2.5, gamba_l=(32, 6, 34), gamba_r=(-20, 6, 14))),
        (7 / 11, dict(PRONTO, arma=(-40, 0), braccio_r=(70, 6, 2), braccio_l=(68, -8, 2), piega=30, avanti=3,
                      gamba_l=(34, 6, 42), gamba_r=(-22, 6, 14))),
        (9 / 11, dict(PRONTO, arma=(-30, 5), braccio_r=(64, 8, 10), braccio_l=(62, -8, 10), piega=24, avanti=2,
                      gamba_l=(26, 6, 30), gamba_r=(-16, 6, 12))),
        (1.0, dict(PRONTO))]},
    # parry: lama dritta davanti al corpo, braccia avanti, incontro al colpo; la scintilla e' dove il colpo arriva
    "parry": {"chiavi": [
        (0.0, dict(PRONTO, arma=(72, 15), braccio_r=(78, 18, 40), braccio_l=(76, -14, 44), piega=10, avanti=1.5,
                   gamba_l=(22, 6, 18), gamba_r=(-18, 6, 14))),
        (1 / 3, dict(PRONTO, arma=(76, 12), braccio_r=(84, 18, 34), braccio_l=(82, -14, 38), piega=12, avanti=2,
                     gamba_l=(24, 6, 22), gamba_r=(-20, 6, 16), scintilla=True)),
        (2 / 3, dict(PRONTO, arma=(66, 18), braccio_r=(72, 18, 46), braccio_l=(70, -14, 50), piega=6, avanti=0.5,
                     gamba_l=(20, 6, 18), gamba_r=(-16, 6, 14))),
        (1.0, dict(PRONTO))]},
    "hurt": {"chiavi": [
        (0.0, dict(FERMO, piega=20, avanti=-1.5, braccio_l=(40, -10, 80), braccio_r=(30, 30, 30), faccia="dolore",
                   sangue=0.6, gamba_l=(10, 4, 20), gamba_r=(-10, 4, 20))),
        (0.5, dict(FERMO, piega=26, avanti=-2, braccio_l=(45, -14, 90), braccio_r=(26, 34, 34), faccia="dolore",
                   sangue=1.2, gamba_l=(12, 4, 30), gamba_r=(-12, 4, 26))),
        (1.0, dict(FERMO, piega=8, faccia="dolore"))]},
    "death": {"chiavi": [
        (0.0, dict(FERMO, piega=12, braccio_l=(30, 20, 60), braccio_r=(30, 20, 60), faccia="dolore", sangue=0.8)),
        (2 / 9, dict(FERMO, piega=20, gamba_l=(40, 4, 70), gamba_r=(30, 4, 80), braccio_l=(20, 20, 20),
                     braccio_r=(20, 20, 20), faccia="dolore", sangue=1.4)),
        (4 / 9, dict(FERMO, piega=24, gamba_l=(80, 4, 110), gamba_r=(70, 4, 120), braccio_l=(30, 14, 10),
                     braccio_r=(30, 14, 10), testa=(20, 0), faccia="dolore", pozza=1.0)),
        (6 / 9, dict(FERMO, piega=10, gamba_l=(50, 4, 60), gamba_r=(40, 4, 60), cade=50, scivola=8,
                     braccio_l=(80, 30, 10), braccio_r=(80, 30, 10), faccia="dolore", pozza=2.0,
                     per_vista={"down": {"scivola": 2}, "up": {"scivola": 16}})),
        (8 / 9, dict(FERMO, cade=90, scivola=18, per_vista={"down": {"scivola": 5}, "up": {"scivola": 30}}, braccio_l=(110, 55, 10), braccio_r=(110, 55, 10),
                     gamba_l=(10, 4, 10), gamba_r=(4, 4, 6), faccia="dolore", pozza=3.2)),
        (1.0, dict(FERMO, cade=90, scivola=18, per_vista={"down": {"scivola": 5}, "up": {"scivola": 30}}, braccio_l=(115, 60, 6), braccio_r=(115, 60, 6), gamba_l=(10, 4, 8),
                   gamba_r=(4, 4, 4), faccia="dolore", pozza=3.8))]},
    "cast": {"chiavi": [
        (0.0, dict(FERMO, braccio_l=(40, -14, 100), luce=0.3)),
        (0.4, dict(FERMO, braccio_l=(30, -20, 120), luce=1.4, piega=4)),
        (0.6, dict(FERMO, braccio_l=(92, 0, 0), luce=2.4, piega=10, avanti=1.5, gamba_l=(20, 4, 12),
                   gamba_r=(-14, 4, 8))),
        (0.8, dict(FERMO, braccio_l=(90, 0, 0), luce=0.6, piega=8, avanti=1.5, gamba_l=(20, 4, 12),
                   gamba_r=(-14, 4, 8))),
        (1.0, dict(FERMO))]},
    "meditate": {"vista": "down", "chiavi": [
        (0.0, dict(SCH, gamba_l=(82, 38, 150), gamba_r=(82, 38, 150), braccio_l=(36, 18, 50),
                   braccio_r=(36, 18, 50))),
        (0.5, dict(SCH, gamba_l=(82, 38, 150), gamba_r=(82, 38, 150), braccio_l=(36, 20, 52),
                   braccio_r=(36, 20, 52), respiro=1.0))]},
    "interact": {"chiavi": [(0.0, dict(FERMO)),
                            (2 / 3, dict(FERMO, braccio_l=(80, 4, 6), piega=6, avanti=0.5, tieni=True)),
                            (1.0, dict(FERMO, braccio_l=(30, 8, 40)))]},
    "pickup": {"chiavi": [
        (0.0, dict(FERMO, oggetto="terra")),
        (0.25, dict(FERMO, piega=30, gamba_l=(55, 6, 90), gamba_r=(35, 6, 90), braccio_l=(40, 6, 20),
                    oggetto="terra")),
        (0.5, dict(FERMO, piega=42, gamba_l=(75, 6, 130), gamba_r=(50, 6, 130), braccio_l=(25, 4, 0),
                   oggetto="mano", tieni=True)),
        (0.75, dict(FERMO, piega=22, gamba_l=(40, 6, 70), gamba_r=(25, 6, 70), braccio_l=(40, 8, 60),
                    oggetto="mano")),
        (1.0, dict(FERMO, braccio_l=(20, 10, 80), oggetto="mano"))]},
    "drink": {"chiavi": [
        (0.0, dict(FERMO, braccio_l=(40, -10, 80), fiala="chiusa")),
        (0.2, dict(FERMO, braccio_l=(45, -14, 90), braccio_r=(45, 14, 100), fiala="stappa")),
        (0.45, dict(FERMO, braccio_l=(70, -34, 135), fiala="aperta", testa=(-10, 0))),
        (0.65, dict(FERMO, braccio_l=(95, -38, 140), fiala="bevi", testa=(-30, 0), tieni=True)),
        (1.0, dict(FERMO, braccio_l=(40, -10, 80), fiala="aperta"))]},
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


# --- Versioni da scegliere (l'utente sceglie, poi una diventa "dash" in ANIM) ----------------------------------------
# Stessi frame e tempi di data/animations.json personaggio.dash (4 frame, i-frame 0-2). `scia`: copie scure dietro.
# Capriola (ricerca: abbassarsi, tuffo con le braccia avanti, palla raccolta che rotola sulle spalle, piedi a terra,
# rialzarsi; 7-8 fotogrammi): la rotazione e' sul bacino (`perno`), il corpo raccolto e' una palla.
_TUCK = dict(SCH, gamba_l=(110, 6, 150), gamba_r=(110, 6, 150), braccio_l=(80, 10, 110), braccio_r=(80, 10, 110),
             piega=50, perno=6.0, a_terra=False, bob=-2.5)
VARIANTI = {
    "dash": {
        "scivolata": {"nome": "Scivolata bassa (su un ginocchio)", "chiavi": [
            (0.0, dict(SCH, piega=20, gamba_l=(40, 4, 60), gamba_r=(-10, 4, 70), braccio_l=(-20, 24, 30),
                       braccio_r=(-20, 24, 30))),
            (2 / 7, dict(SCH, piega=34, gamba_l=(60, 4, 70), gamba_r=(-30, 4, 140), braccio_l=(-40, 34, 30),
                         braccio_r=(30, 40, 40), avanti=3, vento=3)),
            (5 / 7, dict(SCH, piega=36, gamba_l=(70, 4, 80), gamba_r=(-40, 4, 150), braccio_l=(-50, 36, 30),
                         braccio_r=(40, 44, 40), avanti=6, vento=4)),
            (1.0, dict(SCH, piega=12, gamba_l=(20, 4, 30), gamba_r=(-10, 4, 40), braccio_l=(-10, 16, 20),
                       braccio_r=(-10, 16, 20), avanti=3, vento=1))]},
        "capriola": {"nome": "Capriola in avanti", "chiavi": [
            (0.0, dict(SCH, piega=30, gamba_l=(50, 6, 90), gamba_r=(40, 6, 90), braccio_l=(40, 14, 40),
                       braccio_r=(40, 14, 40))),
            (1 / 7, dict(SCH, piega=60, gamba_l=(30, 6, 40), gamba_r=(-20, 6, 30), braccio_l=(120, 10, 10),
                         braccio_r=(120, 10, 10), avanti=2, vento=2)),
            (2 / 7, dict(_TUCK, cade=-70, avanti=3)),
            (3 / 7, dict(_TUCK, cade=-150, avanti=4)),
            (4 / 7, dict(_TUCK, cade=-230, avanti=5)),
            (5 / 7, dict(_TUCK, cade=-310, avanti=6)),
            (6 / 7, dict(SCH, piega=34, gamba_l=(60, 6, 110), gamba_r=(50, 6, 110), braccio_l=(50, 20, 40),
                         braccio_r=(50, 20, 40), avanti=6)),
            (1.0, dict(SCH, piega=10, gamba_l=(20, 6, 30), gamba_r=(10, 6, 30), braccio_l=(10, 16, 20),
                       braccio_r=(10, 16, 20), avanti=6))]},
        "affondo": {"nome": "Passo d'affondo", "chiavi": [
            (0.0, dict(SCH, piega=20, gamba_l=(30, 2, 40), gamba_r=(-20, 2, 30), braccio_l=(-30, 14, 20),
                       braccio_r=(-30, 14, 20))),
            (2 / 7, dict(SCH, piega=36, gamba_l=(55, 2, 10), gamba_r=(-50, 2, 10), braccio_l=(-60, 14, 10),
                         braccio_r=(-60, 14, 10), avanti=4, vento=4)),
            (4 / 7, dict(SCH, piega=34, gamba_l=(50, 2, 40), gamba_r=(-55, 2, 5), braccio_l=(-70, 18, 10),
                         braccio_r=(-70, 18, 10), avanti=6, vento=4)),
            (6 / 7, dict(SCH, piega=20, gamba_l=(30, 2, 30), gamba_r=(-20, 2, 30), braccio_l=(-30, 16, 20),
                         braccio_r=(-30, 16, 20), avanti=5, vento=2)),
            (1.0, dict(SCH, piega=10, gamba_l=(14, 4, 14), gamba_r=(-10, 4, 10), braccio_l=(-10, 14, 20),
                       braccio_r=(-10, 14, 20), avanti=3, vento=1))]},
        "ombra": {"nome": "Passo d'ombra (con le copie dietro)", "chiavi": [
            (0.0, dict(SCH, piega=20, gamba_l=(30, 2, 40), gamba_r=(-20, 2, 30), braccio_l=(-40, 24, 10),
                       braccio_r=(-40, 24, 10), avanti=1, vento=2, scia=1)),
            (2 / 7, dict(SCH, piega=34, gamba_l=(30, 2, 30), gamba_r=(-30, 2, 20), braccio_l=(-60, 24, 10),
                         braccio_r=(-60, 24, 10), avanti=4, vento=4, scia=3)),
            (5 / 7, dict(SCH, piega=36, gamba_l=(20, 2, 50), gamba_r=(-36, 2, 30), braccio_l=(-60, 26, 10),
                         braccio_r=(-60, 26, 10), avanti=6, vento=4, scia=3)),
            (1.0, dict(SCH, piega=10, gamba_l=(16, 4, 14), gamba_r=(-12, 4, 10), braccio_l=(-10, 14, 20),
                       braccio_r=(-10, 14, 20), avanti=4, vento=1, scia=1))]},
    },
}
