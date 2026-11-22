"""Disegno comune delle bestie a quattro zampe (fauna e nemici): lo scheletro Quadrupede e l'ordine delle parti.
Ogni specie ha il suo modulo con CORPO, R, M, TESTA (e APERTA), B (misure e coda) ed EXTRA (pezzi suoi: zanne,
corna, chele, aculei...). Come Enel per gli umani: lo scheletro e' comune, il disegno e' della specie.

B: zampa (raggio coscia anteriore, posteriore, stinco), corpo (raggio anche, spalle), collo (raggio o 0), coda
("folta", "corta", "sottile", "fiocco", "nessuna"), pancia (True: pancia chiara sotto), testa_dy (spostamento della
testa sullo schermo), macchie (n di macchie chiare sul dorso).
"""
import numpy as np

from ..pixel import colore, griglia, segmento

SANGUE = {"r": colore("red"), "R": colore("red_d"), "p": colore("pink")}
LAMPO = ["..w..", ".wYw.", "wYWYw", ".wYw.", "..w.."]


def disegna(tela, v, g, posa, st):
    R, B = st.R, st.B
    parti = []
    vis = v.lato_visibile()
    za, zp, zs = B.get("zampa", (2.2, 2.8, 1.2))
    for nome in ("ant", "post"):
        for lato in "lr":
            def zampa(nome=nome, lato=lato):
                p = [v.xy(g[f"{nome}_{lato}_{i}"]) for i in range(4)]
                r = R["manto"] if lato == vis or vis is None else R["manto_scuro"]
                segmento(tela, p[0], p[1], za if nome == "ant" else zp, zs + 0.4, r, f"{nome}_{lato}")
                segmento(tela, p[1], p[2], zs + 0.2, zs, r, f"{nome}_{lato}")
                segmento(tela, p[2], p[3], zs + 0.1, zs, R["piede"], f"{nome}_{lato}")
            parti.append((v.prof(g[f"{nome}_{lato}_1"]) + (0.4 if lato == vis else 0), 0, zampa))

    tipo = B.get("coda", "corta")
    if tipo != "nessuna":
        def coda():
            a, b, c = (v.xy(g[f"coda_{i}"]) for i in range(3))
            rc = R.get("coda", R["manto"])
            if tipo == "folta":
                segmento(tela, a, b, 1.8, 3.0, rc, "coda")
                segmento(tela, b, c, 3.0, 1.0, rc, "coda", uniti=("coda",))
                segmento(tela, ((b[0] + c[0]) / 2, (b[1] + c[1]) / 2), c, 1.6, 0.8, R.get("punta", rc), "coda",
                         uniti=("coda",), separa=False)
            elif tipo == "sottile":
                segmento(tela, a, b, 1.0, 0.8, rc, "coda")
                segmento(tela, b, c, 0.8, 0.5, rc, "coda", uniti=("coda",))
            elif tipo == "fiocco":
                m = (a[0] * 0.5 + b[0] * 0.5, a[1] * 0.5 + b[1] * 0.5)
                segmento(tela, a, m, 1.4, 1.6, rc, "coda")
                segmento(tela, m, m, 1.8, 1.8, R.get("punta", rc), "coda", uniti=("coda",))
            else:                                   # corta
                m = (a[0] * 0.6 + b[0] * 0.4, a[1] * 0.6 + b[1] * 0.4)
                segmento(tela, a, m, 1.4, 1.0, rc, "coda")
        parti.append((v.prof(g["coda_1"]), 0.5, coda))

    def corpo():
        a, s = v.xy(g["anche"]), v.xy(g["spalle"])
        ra, rs = B.get("corpo", (4.0, 4.6))
        segmento(tela, a, s, ra, rs, R["manto"], "corpo", piatto=0.2)
        if B.get("pancia") and v.dir != "up":
            pa, ps = v.xy(g["anche"] - g["su"] * ra * 0.5), v.xy(g["spalle"] - g["su"] * rs * 0.5)
            segmento(tela, pa, ps, ra * 0.45, rs * 0.45, R["pancia"], "pancia", uniti=("corpo",), separa=False)
        if B.get("macchie") and v.dir != "down":
            for k in range(B["macchie"]):
                p = g["anche"] + (g["spalle"] - g["anche"]) * (0.2 + k * 0.6 / B["macchie"]) + g["su"] * ra * 0.6 + \
                    np.array([(k % 2 - 0.5) * 1.6, 0, 0])
                x, y = v.xy(p)
                griglia(tela, ["c"], {"c": R["pancia"].toni[2]}, int(round(x)), int(round(y)), f"macchia{k}",
                        separa=False)
        if B.get("collo"):
            segmento(tela, s, v.xy(g["testa"]), B["collo"], B["collo"] * 0.8, R["manto"], "collo", uniti=("corpo",))
    parti.append((v.prof((g["anche"] + g["spalle"]) / 2), 1, corpo))

    def testa():
        aperta = posa.get("bocca", 0) > 0.5 and hasattr(st, "APERTA")
        fonte = st.APERTA if aperta else st.TESTA
        if v.dir in ("left", "right"):
            righe, spec = fonte.get("left", st.TESTA["left"]), v.dir == "right"
        else:
            righe, spec = fonte.get(v.dir, st.TESTA[v.dir]), False
        gira = (1 if v.dir != "right" else 3) if abs(posa.get("cade", 0)) > 50 and v.dir in ("left", "right") else 0
        x, y = v.xy(g["testa"])
        w, h = len(righe[0]), len(righe)
        if gira:
            w, h = h, w
        dx = {"left": -B.get("muso", 2), "right": B.get("muso", 2)}.get(v.dir, 0)
        mappa = st.M
        if posa.get("lampo_occhi"):
            mappa = {**st.M, "K": colore("yellow"), "E": colore("white")}
        if posa.get("senza_luna"):                  # morto: occhi spenti
            mappa = {**st.M, "E": colore("slate_d")}
        griglia(tela, righe, mappa, int(round(x - w / 2 + dx)), int(round(y - h / 2 + B.get("testa_dy", 0))), "testa",
                specchia=spec, ruota=gira, uniti=("collo", "corpo"))
    parti.append((v.prof(g["testa"]) + (8.0 if v.dir == "up" else 2.0), 3, testa))

    for extra in getattr(st, "EXTRA", ()):
        parti.append(extra(tela, v, g, posa))

    if posa.get("lampo_occhi") and v.dir != "up":   # il tell: bagliore attorno agli occhi
        def bagliore():
            x, y = v.xy(g["testa"])
            dx = {"left": -B.get("muso", 2) - 2, "right": B.get("muso", 2) + 2}.get(v.dir, 0)
            for px in ((-3, 3) if v.dir == "down" else (0,)):
                griglia(tela, LAMPO, {"w": colore("yellow"), "Y": colore("white"), "W": colore("white")},
                        int(round(x + dx + px - 2)), int(round(y - 3 + B.get("testa_dy", 0))), "bagliore", separa=False)
        parti.append((99, 8, bagliore))
    sangue = posa.get("sangue", 0)
    if sangue:
        def gocce():
            c = (g["anche"] + g["spalle"]) / 2 + g["su"] * 2
            for i, (dx, dz) in enumerate(((1.0, 0.6), (1.6, -0.2), (0.6, 1.2), (2.0, 0.4), (1.3, -0.8))):
                p = c + np.array([(i - 2) * 2.2 * sangue, -dx * sangue * 2.0, 2.0 + dz * sangue * 3.0])
                x, y = v.xy(p)
                griglia(tela, ["pr", "rR"] if i % 2 else [".r.", "rRr", ".R."], SANGUE, int(round(x)), int(round(y)),
                        "sangue", separa=False)
        parti.append((99, 7, gocce))
    pozza = posa.get("pozza", 0)
    if pozza:
        def pozza_a_terra():
            x, y = v.xy((g["anche"] + g["spalle"]) / 2 * np.array([1, 1, 0]))
            segmento(tela, (x - pozza * 2.6, y), (x + pozza * 2.6, y), pozza * 1.3, pozza * 1.3, R["sangue"], "pozza",
                     separa=False)
        parti.append((-99, -9, pozza_a_terra))

    for _, _, f in sorted(parti, key=lambda p: (p[0], p[1])):
        f()


# --- pose della fauna: idle 4 (annusa, guarda), fuga 6 (galoppo o balzi) ---------------------------------------------
FERMO = dict(ant_l=(0, 2, 0), ant_r=(0, 2, 0), post_l=(0, 2, 0), post_r=(0, 2, 0), coda=(10, 0))


def anim_fauna(giu=50, coda_su=60, balzo=4.0, raccolto=1.0, testa_alta=-5):
    """idle: muso a terra che annusa, poi alza la testa e guarda; fuga: si raccoglie, si stende in aria, atterra."""
    return {
        "idle": {"chiavi": [
            (0.0, dict(FERMO, testa=(giu, 0), piega=6)),
            (0.25, dict(FERMO, testa=(giu + 6, 4), piega=6)),
            (0.5, dict(FERMO, testa=(testa_alta, 0))),
            (0.75, dict(FERMO, testa=(testa_alta, 14), coda=(20, 0)))]},
        "fuga": {"chiavi": [
            (0.0, dict(FERMO, ant_l=(40 * raccolto, 2, 90), ant_r=(35 * raccolto, 2, 90), post_l=(-10, 2, 40),
                       post_r=(-15, 2, 40), coda=(coda_su, 0), piega=8)),
            (1 / 3, dict(FERMO, ant_l=(70, 2, 20), ant_r=(65, 2, 20), post_l=(-60, 2, 10), post_r=(-65, 2, 10),
                         coda=(coda_su + 5, 0), piega=-8, a_terra=False, bob=balzo)),
            (2 / 3, dict(FERMO, ant_l=(20, 2, 70), ant_r=(10, 2, 70), post_l=(30, 2, 60), post_r=(25, 2, 60),
                         coda=(coda_su, 0), piega=4, a_terra=False, bob=balzo * 0.5))]},
    }
