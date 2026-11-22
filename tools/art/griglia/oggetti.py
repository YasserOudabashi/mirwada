"""Icone degli oggetti a griglia (scelte del 2026-11-18): ogni oggetto il suo disegno 32x32, contorno nero di 1 px,
3 toni, luce in alto a sinistra. Le famiglie si riconoscono (la cura minore e la maggiore sono la stessa fiala, la
maggiore piu' grande e decorata d'oro). Prima prova: dieci oggetti veri dei dati; vanno in arte/prova/ finche' non
sono approvati (poi in assets/icone/oggetti/ con data/ui/icone.json).
"""
import numpy as np

from .pixel import Rampa, Tela, colore, griglia, segmento

L = 32
R = {
    "vetro": Rampa("grey", "grey_l", "white"), "rosso": Rampa("red_d", "red", "pink"),
    "sughero": Rampa("brown_dd", "brown_d", "tan"), "oro": Rampa("orange_d", "amber", "yellow", riflesso="white"),
    "ambra": Rampa("orange_d", "amber", "yellow"), "verde": Rampa("teal_d", "green_m", "green"),
    "lama": Rampa("slate", "grey", "grey_l", riflesso="white"), "cuoio": Rampa("brown_dd", "brown_d", "brown"),
    "cuoio_chiaro": Rampa("brown_d", "brown", "tan"), "argento": Rampa("grey", "grey_l", "white", riflesso="white"),
    "blu": Rampa("navy", "blue", "cyan"), "ferro": Rampa("slate_d", "slate", "grey"),
    "viola": Rampa("purple_d", "purple", "pink"), "pietra": Rampa("slate_d", "slate", "grey"),
    "carta": Rampa("tan", "cream", "white"),
}


def _poligono(t, punti, rampa, gruppo, luce_sx=True, separa=True):
    """Poligono pieno: base, lato sinistro/alto in luce, lato destro/basso in ombra (una luce sola)."""
    ys, xs = np.mgrid[0:t.h, 0:t.w]
    px, py = xs + 0.5, ys + 0.5
    dentro = np.zeros((t.h, t.w), bool)
    n = len(punti)
    for i in range(n):
        (x1, y1), (x2, y2) = punti[i], punti[(i + 1) % n]
        attraversa = ((y1 > py) != (y2 > py)) & (px < (x2 - x1) * (py - y1) / ((y2 - y1) or 1e-9) + x1)
        dentro ^= attraversa
    cx, cy = np.mean([p[0] for p in punti]), np.mean([p[1] for p in punti])
    c = np.zeros((t.h, t.w, 3), np.uint8)
    c[dentro] = rampa.toni[1]
    d = (px - cx) + (py - cy) * 0.7
    c[dentro & (d < -2.5)] = rampa.toni[2]
    c[dentro & (d > 3.5)] = rampa.toni[0]
    t.metti(dentro, c, gruppo, separa=separa)
    return dentro


def _fiala(t, grande):
    r = 8.5 if grande else 6.2
    cy = 21 if grande else 22
    segmento(t, (16, cy - r - 4), (16, cy - r + 1), 2.6, 2.6, R["vetro"], "collo")
    segmento(t, (16, cy), (16, cy), r, r, R["vetro"], "fiala")
    segmento(t, (16, cy + 1.5), (16, cy + 1.5), r - 1.6, r - 1.6, R["rosso"], "liquido", uniti=("fiala",),
             separa=False)
    griglia(t, ["ww", "w."], {"w": colore("white")}, int(16 - r * 0.55), int(cy - r * 0.55), "riflesso", separa=False)
    if grande:                                       # decorata: tappo d'oro con la gemma, collare e fascia d'oro
        segmento(t, (16, cy - r - 6.5), (16, cy - r - 6.5), 3.0, 3.0, R["oro"], "tappo")
        griglia(t, ["r"], {"r": colore("red")}, 15, int(cy - r - 7), "gemma", separa=False)
        segmento(t, (12.5, cy - r + 0.5), (19.5, cy - r + 0.5), 1.0, 1.0, R["oro"], "collare", uniti=("collo",))
        segmento(t, (16 - r + 1, cy + 2), (16 + r - 1, cy + 2), 0.9, 0.9, R["oro"], "fascia", uniti=("fiala",),
                 separa=False)
        for dx in (-4, 0, 4):
            griglia(t, ["Y"], {"Y": colore("yellow")}, 16 + dx, int(cy + 5), f"filigrana{dx}", separa=False)
    else:
        segmento(t, (16, cy - r - 5), (16, cy - r - 4), 2.2, 2.2, R["sughero"], "tappo")


def pozione_cura_minore(t):
    _fiala(t, False)


def pozione_cura_maggiore(t):
    _fiala(t, True)


def elisir_del_vigore(t):
    """Fiala alta e sottile col liquido ambra a bolle verdi, una foglia legata al collo con lo spago."""
    segmento(t, (16, 7), (16, 27), 4.6, 5.2, R["vetro"], "fiala")
    segmento(t, (16, 12), (16, 26.5), 3.4, 4.0, R["ambra"], "liquido", uniti=("fiala",), separa=False)
    for x, y in ((15, 22), (17, 18), (15, 15)):
        griglia(t, [".g.", "gWg", ".g."], {"g": colore("green"), "W": colore("white")}, x - 1, y - 1, f"bolla{y}",
                separa=False)
    segmento(t, (16, 4), (16, 5.5), 2.6, 2.6, R["sughero"], "tappo")
    segmento(t, (19, 7), (25, 4), 1.4, 2.4, R["verde"], "foglia")
    segmento(t, (13, 8), (19, 8), 0.6, 0.6, R["sughero"], "spago", separa=False)


def spada_ferrea(t):
    """Spada a una mano di ferro in diagonale: lama col filo chiaro, guardia dritta, impugnatura di cuoio, pomolo."""
    segmento(t, (11, 21), (27, 5), 2.0, 1.4, R["lama"], "lama")
    segmento(t, (27, 5), (28.5, 3.5), 1.4, 0.4, R["lama"], "lama", uniti=("lama",))
    segmento(t, (6, 17), (14, 25), 1.4, 1.4, R["ferro"], "guardia")
    segmento(t, (9, 23), (5, 27), 1.5, 1.5, R["cuoio"], "impugnatura")
    segmento(t, (4, 28), (4, 28), 2.0, 2.0, R["ferro"], "pomolo")


def corazza_cuoio(t):
    """Corazza di cuoio: busto con gli spallacci tondi, cinghie e fibbie di ferro, cuciture."""
    _poligono(t, [(8, 9), (24, 9), (26, 14), (24, 28), (8, 28), (6, 14)], R["cuoio_chiaro"], "busto")
    _poligono(t, [(12, 9), (20, 9), (18, 13), (14, 13)], R["cuoio"], "scollo")
    for x in (7, 25):
        segmento(t, (x, 11), (x, 11), 3.6, 3.6, R["cuoio"], f"spalla{x}")
    for y in (17, 23):
        segmento(t, (8, y), (24, y), 0.9, 0.9, R["cuoio"], f"cinghia{y}", separa=False)
        griglia(t, ["II", "II"], {"I": colore("grey")}, 15, y - 1, f"fibbia{y}", separa=False)
    for y in range(12, 28, 3):
        griglia(t, ["c"], {"c": colore("tan")}, 16, y, f"cucitura{y}", separa=False)


def amuleto_lunare(t):
    """Catenella d'argento e una falce di luna d'argento con una gemma blu al centro."""
    for k in range(11):                              # la catenella a V che regge la luna dalla punta
        f = k / 10
        x = 5 + f * 22
        y = 3 + (1 - abs(f - 0.5) * 2) * 10
        segmento(t, (x, y), (x, y), 0.9, 0.9, R["argento"], f"anello{k}", separa=False)
    segmento(t, (16, 13), (16, 15), 1.0, 1.0, R["argento"], "gancio")
    ys, xs = np.mgrid[0:L, 0:L]
    luna = (np.hypot(xs + 0.5 - 16, ys + 0.5 - 22) <= 8) & (np.hypot(xs + 0.5 - 19.5, ys + 0.5 - 20) > 6.5)
    c = np.zeros((L, L, 3), np.uint8)
    c[luna] = R["argento"].toni[1]
    c[luna & (xs < 13)] = R["argento"].toni[2]
    c[luna & (ys > 26)] = R["argento"].toni[0]
    t.metti(luna, c, "luna")
    segmento(t, (17.5, 21), (17.5, 21), 2.2, 2.2, R["blu"], "gemma")


def lingotto_ferro(t):
    """Lingotto di ferro a tronco di piramide visto di tre quarti, col marchio della fonderia battuto sopra."""
    _poligono(t, [(5, 24), (27, 24), (24, 28), (8, 28)], R["ferro"], "fianco", separa=True)
    _poligono(t, [(9, 13), (23, 13), (27, 24), (5, 24)], R["ferro"], "fronte")
    _poligono(t, [(11, 9), (21, 9), (23, 13), (9, 13)], R["argento"], "sopra")
    griglia(t, [".k.", "kkk", ".k."], {"k": colore("slate_d")}, 15, 17, "marchio", separa=False)


def cristallo_grezzo(t):
    """Tre schegge di cristallo viola che escono da un sasso grigio, una piu' alta in mezzo."""
    _poligono(t, [(6, 28), (26, 28), (24, 23), (8, 23)], R["pietra"], "sasso")
    for k, (x, h, w) in enumerate(((11, 14, 3.0), (16, 21, 3.6), (21, 12, 3.0))):
        _poligono(t, [(x - w, 24), (x - w, 24 - h + 4), (x, 24 - h), (x + w, 24 - h + 4), (x + w, 24)], R["viola"],
                  f"scheggia{k}")
    griglia(t, ["W", "W"], {"W": colore("white")}, 14, 7, "brillio", separa=False)


def pergamena_vigore(t):
    """Pergamena arrotolata in diagonale, i due rotoli alle estremita', il nastro rosso col sigillo di ceralacca."""
    segmento(t, (6, 24), (25, 7), 4.4, 4.4, R["carta"], "rotolo")
    for x, y in ((6, 24), (25, 7)):
        segmento(t, (x, y), (x, y), 4.8, 4.8, R["carta"], f"capo{x}", uniti=("rotolo",))
        griglia(t, ["b"], {"b": colore("tan")}, x, y, f"spirale{x}", separa=False)
    segmento(t, (12, 13), (19, 20), 1.0, 1.0, R["rosso"], "nastro", separa=False)
    segmento(t, (16, 16.5), (16, 16.5), 2.8, 2.8, R["rosso"], "ceralacca")
    griglia(t, ["Y"], {"Y": colore("pink")}, 15, 15, "impronta", separa=False)


def moneta_comune(t):
    """Una pila di tre monete di rame-oro e una moneta in piedi davanti con la corona incisa."""
    for k in range(3):
        segmento(t, (8, 25 - k * 3), (20, 25 - k * 3), 2.0, 2.0, R["ambra"], f"pila{k}")
    segmento(t, (21, 18), (21, 18), 7.0, 7.0, R["oro"], "moneta")
    segmento(t, (21, 18), (21, 18), 5.0, 5.0, R["ambra"], "moneta_c", uniti=("moneta",), separa=False)
    griglia(t, ["y.y.y", "yyyyy", "yyyyy"], {"y": colore("yellow")}, 19, 16, "corona", separa=False)


OGGETTI = {f.__name__: f for f in (pozione_cura_minore, pozione_cura_maggiore, elisir_del_vigore, spada_ferrea,
                                   corazza_cuoio, amuleto_lunare, lingotto_ferro, cristallo_grezzo, pergamena_vigore,
                                   moneta_comune)}


def disegna(nome):
    t = Tela(L, L)
    OGGETTI[nome](t)
    t.contorno()
    return t.immagine()
