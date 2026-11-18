"""Scheletro: dove stanno le giunture in una posa, e come si vedono da una delle 4 direzioni (top-down 3/4).

E' l'unica cosa comune fra i personaggi. Le misure (altezza dell'anca, lunghezza delle braccia...) sono del
personaggio; qui c'e' solo la geometria. Spazio del modello: x verso la mano destra, y in avanti (dove guarda), z in
alto, in pixel; i piedi a terra in z = 0.

Posa (tutti gli angoli in gradi, tutto facoltativo):
  bob, avanti, lato      spostamento del bacino (su, in avanti, verso destra)
  respiro                il busto si accorcia di tanti pixel (il respiro da fermo)
  piega, gira, inclina   busto: in avanti, girato a destra, inclinato verso destra
  testa                  (in avanti, girata) - sposta la testa, la griglia non ruota
  braccio_l, braccio_r   (avanti, fuori, gomito)  avanti: 90 = teso davanti; fuori: allargato; gomito: piegato
  gamba_l, gamba_r       (avanti, fuori, ginocchio)
  arma                   (alzata, direzione): direzione dell'arma dalla mano destra; alzata 90 = in su,
                         direzione 0 = davanti, 90 = a destra, 180 = dietro
  cade                   tutto il corpo ruota intorno ai piedi: positivo = all'indietro
  perno                  altezza del punto intorno a cui ruota `cade` (la capriola gira sul bacino)
  scivola                dopo la caduta sposta tutto in avanti (y), per restare nella cella
  a_terra                True (default): il piede piu' basso tocca terra
"""
import math

import numpy as np

DIREZIONI = ("down", "up", "left", "right")
AVANTI = {"down": (0, 1), "up": (0, -1), "left": (-1, 0), "right": (1, 0)}
SCORCIO = 0.45          # quanto la profondita' scende sullo schermo (vista dall'alto e da sud)


def _rx(v, a):          # intorno all'asse x del modello: verso +y (avanti) per a positivo, partendo da -z
    c, s = math.cos(a), math.sin(a)
    x, y, z = v
    return np.array([x, y * c - z * s, y * s + z * c])


def _ry(v, a):          # intorno all'asse y: z verso +x
    c, s = math.cos(a), math.sin(a)
    x, y, z = v
    return np.array([x * c + z * s, y, -x * s + z * c])


def _rz(v, a):          # intorno all'asse verticale: y verso +x (gira a destra)
    c, s = math.cos(a), math.sin(a)
    x, y, z = v
    return np.array([x * c + y * s, -x * s + y * c, z])


def arto(avanti, fuori, lato):
    """Direzione di un arto che pende (0, 0, -1), aperto di `fuori` verso il suo lato e portato in avanti."""
    d = np.array([lato * math.sin(math.radians(fuori)), 0.0, -math.cos(math.radians(fuori))])
    return _rx(d, math.radians(avanti))


class Umano:
    """Misure in pixel: anca (altezza), busto, spalle, fianchi, braccio, avambraccio, coscia, stinco, piede, collo."""

    def __init__(self, anca=14.0, busto=11.0, spalle=6.0, fianchi=2.6, braccio=5.5, avambraccio=5.0,
                 coscia=7.2, stinco=6.8, piede=2.2, collo=1.0):
        self.m = dict(anca=anca, busto=busto, spalle=spalle, fianchi=fianchi, braccio=braccio,
                      avambraccio=avambraccio, coscia=coscia, stinco=stinco, piede=piede, collo=collo)

    def giunture(self, posa):
        m, p = self.m, posa
        g = {}
        bac = np.array([p.get("lato", 0.0), p.get("avanti", 0.0), m["anca"] + p.get("bob", 0.0)])
        g["bacino"] = bac
        piega, gira, incl = (math.radians(p.get(k, 0.0)) for k in ("piega", "gira", "inclina"))
        # _rx porta -z in avanti e quindi +z indietro: il busto si piega in avanti con -piega (era il segno sbagliato
        # che faceva chinare tutti all'indietro, giudizio dell'utente del 2026-11-18). Le braccia seguono il busto.
        su = _rz(_ry(_rx(np.array([0, 0, 1.0]), -piega), incl), gira)
        destra = _rz(np.array([1.0, 0, 0]), gira)
        busto = m["busto"] - p.get("respiro", 0.0)
        g["collo"] = bac + su * busto
        g["spalle_c"] = bac + su * (busto - 1.0)
        tp, ty = p.get("testa", (0, 0))
        g["testa"] = g["collo"] + su * m["collo"] + np.array([0, math.sin(math.radians(tp)) * 1.5, 0])
        g["testa_gira"] = ty
        for lato, s in (("r", 1), ("l", -1)):
            sp = g["spalle_c"] + destra * s * m["spalle"]
            av, fu, gom = p.get(f"braccio_{lato}", (0, 8, 10))
            d1 = _rz(_ry(_rx(arto(av, fu, s), -piega * 0.6), incl), gira)
            d2 = _rz(_ry(_rx(arto(av + gom, fu * 0.6, s), -piega * 0.6), incl), gira)
            g[f"spalla_{lato}"] = sp
            g[f"gomito_{lato}"] = sp + d1 * m["braccio"]
            g[f"mano_{lato}"] = g[f"gomito_{lato}"] + d2 * m["avambraccio"]
            an = bac + np.array([s * m["fianchi"], 0, 0])
            av, fu, gin = p.get(f"gamba_{lato}", (0, 0, 0))
            d1 = arto(av, fu, s)
            d2 = arto(av - gin, fu, s)
            g[f"anca_{lato}"] = an
            g[f"ginocchio_{lato}"] = an + d1 * m["coscia"]
            g[f"caviglia_{lato}"] = g[f"ginocchio_{lato}"] + d2 * m["stinco"]
            g[f"punta_{lato}"] = g[f"caviglia_{lato}"] + np.array([0, m["piede"], -0.3])
        el, dr = p.get("arma", (60, 160))
        el, dr = math.radians(el), math.radians(dr)
        g["arma_dir"] = np.array([math.sin(dr) * math.cos(el), math.cos(dr) * math.cos(el), math.sin(el)])
        g["su"], g["destra"] = su, destra
        if p.get("a_terra", True):
            basso = min(g[f"caviglia_{s}"][2] for s in "lr") - 0.6
            for k, v in g.items():
                if isinstance(v, np.ndarray) and k not in ("arma_dir", "su", "destra"):
                    g[k] = v - np.array([0, 0, basso])
        cade = math.radians(p.get("cade", 0.0))
        if cade:
            perno = np.array([0, 0, p.get("perno", 0.0)])
            for k, v in list(g.items()):
                if isinstance(v, np.ndarray):
                    g[k] = _rx(v - perno, cade) + perno if k not in ("arma_dir", "su", "destra") else _rx(v, cade)
        if p.get("scivola"):                     # dopo la caduta: il corpo resta nella cella
            for k, v in list(g.items()):
                if isinstance(v, np.ndarray) and k not in ("arma_dir", "su", "destra"):
                    g[k] = v + np.array([0, p["scivola"], 0])
        return g


class Vista:
    """Proiezione del modello sullo schermo per una direzione. `piedi`: riga dei piedi; `cx`: colonna del centro."""

    def __init__(self, direzione, cx=32.0, piedi=54.0):
        self.dir = direzione
        fx, fy = AVANTI[direzione]
        self.f = np.array([fx, fy, 0.0])
        self.r = np.array([-fy, fx, 0.0])          # la mano destra di chi guarda verso f
        self.cx, self.piedi = cx, piedi

    def mondo(self, v):
        return v[0] * self.r + v[1] * self.f + np.array([0, 0, v[2]])

    def xy(self, v):
        w = self.mondo(v)
        return (self.cx + w[0], self.piedi - w[2] + SCORCIO * w[1])

    def prof(self, v):
        """Piu' grande = piu' vicino a chi guarda (disegnato dopo)."""
        return self.mondo(v)[1]

    def lato_visibile(self):
        """Il lato del corpo verso chi guarda nelle viste di profilo: 'l' guardando a sinistra, 'r' a destra."""
        return {"left": "l", "right": "r"}.get(self.dir)


class Quadrupede:
    """Quattro zampe. Misure: lungo (spalle-anche), anca e spalla (altezze), larghezza, zampa (due pezzi),
    collo. Posa: bob, avanti, piega (in avanti = il davanti scende), testa (giu', girata), ant_l/ant_r/post_l/post_r
    (avanti, fuori, piega), coda (alzata, di lato), cade (sul fianco, gradi), a_terra."""

    def __init__(self, lungo=18.0, anca=13.0, spalla=14.0, largo=3.2, zampa=(6.8, 6.6), collo=4.0):
        self.m = dict(lungo=lungo, anca=anca, spalla=spalla, largo=largo, zampa=zampa, collo=collo)

    def giunture(self, posa):
        m, p = self.m, posa
        g = {}
        av, bob = p.get("avanti", 0.0), p.get("bob", 0.0)
        piega = math.radians(p.get("piega", 0.0))
        c = np.array([0, av, (m["anca"] + m["spalla"]) / 2 + bob])
        spina = np.array([0, math.cos(piega), -math.sin(piega)])
        g["anche"] = c - spina * m["lungo"] / 2 + np.array([0, 0, (m["anca"] - m["spalla"]) / 2])
        g["spalle"] = c + spina * m["lungo"] / 2 - np.array([0, 0, (m["anca"] - m["spalla"]) / 2])
        su = np.array([0, math.sin(piega), math.cos(piega)])
        g["su"] = su
        for nome, base, segno in (("ant", g["spalle"], 1), ("post", g["anche"], -1)):
            for lato, s in (("r", 1), ("l", -1)):
                a, fu, k = p.get(f"{nome}_{lato}", (0, 0, 0))
                attacco = base + np.array([s * m["largo"], 0, 0]) - su * (1.5 if nome == "ant" else 2.5)
                d1 = arto(a + (0 if nome == "ant" else 12), fu, s)
                d2 = arto(a + segno * k + (0 if nome == "ant" else -18), fu, s)
                g[f"{nome}_{lato}_0"] = attacco
                g[f"{nome}_{lato}_1"] = attacco + d1 * m["zampa"][0]
                g[f"{nome}_{lato}_2"] = g[f"{nome}_{lato}_1"] + d2 * m["zampa"][1]
                g[f"{nome}_{lato}_3"] = g[f"{nome}_{lato}_2"] + np.array([0, 1.6, -0.2])
        tp, ty = p.get("testa", (0, 0))
        tp, ty = math.radians(tp), math.radians(ty)
        g["collo"] = g["spalle"] + su * 2.5 + spina * 1.0
        dir_testa = np.array([math.sin(ty) * math.cos(tp), math.cos(ty) * math.cos(tp), 0.75 - math.sin(tp)])
        g["testa"] = g["collo"] + dir_testa / np.linalg.norm(dir_testa) * m["collo"]
        ca, cl = (math.radians(x) for x in p.get("coda", (20, 0)))
        g["coda_0"] = g["anche"] + su * 1.5 - spina * 1.2
        dcoda = np.array([math.sin(cl), -math.cos(ca), math.sin(ca)])
        g["coda_1"] = g["coda_0"] + dcoda * 5.5
        g["coda_2"] = g["coda_1"] + (dcoda + np.array([0, 0, -0.5])) * 4.5
        punti = [k for k, v in g.items() if isinstance(v, np.ndarray) and k != "su"]
        if p.get("a_terra", True):
            basso = min(g[f"{n}_{s}_2"][2] for n in ("ant", "post") for s in "lr") - 0.8
            for k in punti:
                g[k] = g[k] - np.array([0, 0, basso])
        cade = math.radians(p.get("cade", 0.0))
        if cade:
            for k in punti:
                g[k] = _ry(g[k], cade) + np.array([0, 0, math.sin(abs(cade)) * 2.0])
            g["su"] = _ry(g["su"], cade)
        return g
