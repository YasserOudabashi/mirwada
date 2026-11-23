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
    "ombra": Rampa("ink", "purple_d", "purple"), "fumo": Rampa("slate", "grey", "grey_l"),
    "oro_l": Rampa("amber", "yellow", "white", riflesso="white"), "ciano": Rampa("blue", "cyan", "white"),
    "rosa": Rampa("red", "pink", "white"), "sacco": Rampa("brown_d", "brown", "tan"),
    "legno": Rampa("brown_dd", "brown_d", "brown"), "corda": Rampa("brown", "tan", "cream"),
    "piuma": Rampa("grey_l", "white", "white"), "ruggine": Rampa("brown_dd", "rust", "orange_d"),
    "cera": Rampa("red_d", "red", "pink"), "verde_s": Rampa("teal_d", "green_d", "green_m"),
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


# --- Giro 3 (2026-11-23): venti oggetti in piu' ------------------------------------------------------------------------
def elisir_ombra(t):
    """Fiala alta e stretta di vetro fumé col liquido viola scuro, il fumo nero che esce dal tappo forato."""
    segmento(t, (16, 9), (16, 27), 4.2, 4.6, R["vetro"], "fiala")
    segmento(t, (16, 13), (16, 26.5), 3.0, 3.4, R["ombra"], "liquido", uniti=("fiala",), separa=False)
    segmento(t, (16, 6), (16, 7.5), 2.4, 2.4, R["ferro"], "tappo")
    for k, (x, y, r) in enumerate(((17, 3, 1.6), (20, 2, 1.2), (14, 1.5, 1.0))):
        segmento(t, (x, y), (x, y), r, r, R["ombra"], f"fumo{k}", separa=False)


def ambrosia(t):
    """Bottiglia d'oro a goccia col liquido dorato che brilla, due alette d'oro ai lati del collo, gemma bianca."""
    segmento(t, (16, 21), (16, 21), 7.5, 7.5, R["oro"], "corpo")
    segmento(t, (16, 22), (16, 22), 5.6, 5.6, R["oro_l"], "liquido", uniti=("corpo",), separa=False)
    segmento(t, (16, 9), (16, 14), 2.2, 2.6, R["oro"], "collo")
    segmento(t, (16, 6.5), (16, 6.5), 2.4, 2.4, R["argento"], "tappo")
    for sx in (-1, 1):
        segmento(t, (16 + sx * 3, 12), (16 + sx * 10, 8), 1.6, 0.8, R["piuma"], f"ala{sx}")
        segmento(t, (16 + sx * 3, 14), (16 + sx * 9, 12), 1.2, 0.6, R["piuma"], f"ala{sx}b")
    griglia(t, ["W"], {"W": colore("white")}, 13, 18, "brillio", separa=False)


def tonico_di_forza(t):
    """Bottiglia tozza e larga di coccio col liquido rosso scuro, il tappo di sughero legato e l'etichetta col pugno."""
    segmento(t, (16, 18), (16, 25), 7.0, 7.4, R["cuoio_chiaro"], "coccio")
    segmento(t, (16, 10), (16, 13), 3.0, 3.4, R["cuoio_chiaro"], "collo")
    segmento(t, (16, 7.5), (16, 8.5), 2.6, 2.6, R["sughero"], "tappo")
    _poligono(t, [(11, 18), (21, 18), (21, 26), (11, 26)], R["carta"], "etichetta")
    griglia(t, [".RRR.", "RRRRR", "RRRRR", ".RRR."], {"R": colore("red")}, 14, 20, "pugno", separa=False)


def filtro_di_chiarezza(t):
    """Fiaschetta tonda di vetro limpido col liquido azzurro, dentro galleggia un occhio di luce; collo lungo sottile."""
    segmento(t, (16, 21), (16, 21), 8.0, 8.0, R["vetro"], "fiasca")
    segmento(t, (16, 22), (16, 22), 6.2, 6.2, R["ciano"], "liquido", uniti=("fiasca",), separa=False)
    segmento(t, (16, 5), (16, 13), 1.8, 2.0, R["vetro"], "collo")
    griglia(t, [".www.", "wwKww", ".www."], {"w": colore("white"), "K": colore("navy")}, 14, 20, "occhio", separa=False)


def essenza_rara_di_guarigione(t):
    """Fiala minuscola di cristallo sfaccettato in una gabbietta d'oro, la goccia rosa che brilla dentro: rara."""
    _poligono(t, [(16, 6), (22, 12), (22, 22), (16, 28), (10, 22), (10, 12)], R["vetro"], "cristallo")
    segmento(t, (16, 18), (16, 21), 2.6, 3.0, R["rosa"], "goccia", separa=False)
    for x in (10, 16, 22):
        segmento(t, (x, 6 if x == 16 else 12), (x, 28 if x == 16 else 22), 0.6, 0.6, R["oro"], f"gabbia{x}",
                 separa=False)
    segmento(t, (16, 3.5), (16, 3.5), 1.8, 1.8, R["oro"], "anello")


def pastura_spirituale(t):
    """Sacchetto di tela legato con lo spago, aperto in cima, chicchi chiari che brillano e due stelline sopra."""
    segmento(t, (16, 20), (16, 22), 8.0, 8.5, R["sacco"], "sacco")
    segmento(t, (11, 14), (21, 14), 1.0, 1.0, R["corda"], "spago")
    for k, (x, y) in enumerate(((13, 12), (16, 11), (19, 12), (15, 9))):
        griglia(t, ["c"], {"c": colore("cream")}, x, y, f"chicco{k}", separa=False)
    for x, y in ((8, 5), (24, 7)):
        griglia(t, [".y.", "yWy", ".y."], {"y": colore("yellow"), "W": colore("white")}, x, y, f"stella{x}",
                separa=False)


def lama_del_pentimento(t):
    """Spada lunga con la lama nera solcata da una vena rossa che brilla, guardia a croce di ferro con le spine."""
    segmento(t, (10, 22), (27, 4), 2.0, 1.2, R["ombra"], "lama")
    segmento(t, (11.5, 20.5), (25, 6), 0.5, 0.4, R["rosso"], "vena", separa=False)
    segmento(t, (6, 18), (14, 26), 1.3, 1.3, R["ferro"], "guardia")
    for x, y in ((6, 18), (14, 26)):
        segmento(t, (x, y), (x - 1.5 if x == 6 else x + 1.5, y - 1.5 if x == 6 else y + 1.5), 0.9, 0.3, R["ferro"],
                 f"spina{x}")
    segmento(t, (8, 24), (4.5, 27.5), 1.4, 1.4, R["cuoio"], "impugnatura")
    segmento(t, (3.5, 28.5), (3.5, 28.5), 1.8, 1.8, R["rosso"], "pomolo")


def corazza_espiazione(t):
    """Corazza di ferro scuro a piastre con una catena incrociata sul petto e un lucchetto: si porta come una pena."""
    _poligono(t, [(8, 9), (24, 9), (26, 14), (24, 28), (8, 28), (6, 14)], R["ferro"], "busto")
    for y in (15, 20, 25):
        segmento(t, (8, y), (24, y), 0.5, 0.5, R["pietra"], f"piastra{y}", separa=False)
    for k in range(6):
        segmento(t, (9 + k * 2.6, 11 + k * 2.6), (9 + k * 2.6, 11 + k * 2.6), 1.1, 1.1, R["argento"], f"catena_a{k}",
                 separa=False)
        segmento(t, (23 - k * 2.6, 11 + k * 2.6), (23 - k * 2.6, 11 + k * 2.6), 1.1, 1.1, R["argento"], f"catena_b{k}",
                 separa=False)
    segmento(t, (16, 20), (16, 22), 2.4, 2.4, R["oro"], "lucchetto")
    for x in (7, 25):
        segmento(t, (x, 11), (x, 11), 3.4, 3.4, R["ferro"], f"spalla{x}")


def anello_del_richiamo(t):
    """Anello d'argento grosso visto di tre quarti con incisa una spirale, una pietra verde come un occhio di gatto."""
    ys, xs = np.mgrid[0:L, 0:L]
    rr = np.hypot((xs + 0.5 - 16) / 1.0, (ys + 0.5 - 19) / 0.7)
    anello = (rr <= 10) & (rr >= 6.5)
    c = np.zeros((L, L, 3), np.uint8)
    c[anello] = R["argento"].toni[1]
    c[anello & (ys < 17)] = R["argento"].toni[2]
    c[anello & (ys > 23)] = R["argento"].toni[0]
    t.metti(anello, c, "anello")
    segmento(t, (16, 9), (16, 9), 4.0, 4.0, R["argento"], "castone")
    segmento(t, (16, 9), (16, 9), 2.8, 2.8, R["verde_s"], "pietra", uniti=("castone",), separa=False)
    griglia(t, ["K", "K", "K"], {"K": colore("ink")}, 16, 8, "pupilla", separa=False)


def ascia_da_guerra(t):
    """Ascia da guerra a una mano: manico lungo di legno fasciato, testa larga a mezzaluna di ferro con il filo chiaro."""
    segmento(t, (8, 28), (20, 6), 1.3, 1.3, R["legno"], "manico")
    segmento(t, (9, 26), (11, 22), 1.5, 1.5, R["cuoio"], "fascia")
    ys, xs = np.mgrid[0:L, 0:L]
    testa = (np.hypot(xs + 0.5 - 17, ys + 0.5 - 10) <= 9) & (xs + 0.5 > 19) & (np.abs(ys + 0.5 - 10) <= 8)
    c = np.zeros((L, L, 3), np.uint8)
    c[testa] = R["lama"].toni[1]
    c[testa & (np.hypot(xs + 0.5 - 17, ys + 0.5 - 10) > 7.5)] = R["lama"].toni[2]
    t.metti(testa, c, "testa")
    segmento(t, (18, 8), (21, 12), 1.6, 1.6, R["ferro"], "occhio")


def scudo_rinforzato(t):
    """Scudo a goccia di legno con le fasce di ferro chiodate e l'umbone tondo al centro, bordo di ferro."""
    _poligono(t, [(6, 5), (26, 5), (26, 16), (16, 29), (6, 16)], R["ferro"], "bordo")
    _poligono(t, [(8, 7), (24, 7), (24, 15), (16, 26), (8, 15)], R["legno"], "legno")
    for y in (11, 18):
        segmento(t, (8, y), (24, y), 0.8, 0.8, R["ferro"], f"fascia{y}", separa=False)
        for x in (9, 23):
            griglia(t, ["w"], {"w": colore("grey_l")}, x, y, f"chiodo{x}{y}", separa=False)
    segmento(t, (16, 14), (16, 14), 3.2, 3.2, R["argento"], "umbone")


def anello_di_cristallo(t):
    """Anello sottile d'oro con un grande cristallo azzurro sfaccettato in cima, i riflessi bianchi."""
    ys, xs = np.mgrid[0:L, 0:L]
    rr = np.hypot((xs + 0.5 - 16), (ys + 0.5 - 21) / 0.7)
    anello = (rr <= 8) & (rr >= 6)
    c = np.zeros((L, L, 3), np.uint8)
    c[anello] = R["oro"].toni[1]
    c[anello & (xs < 13)] = R["oro"].toni[2]
    t.metti(anello, c, "anello")
    _poligono(t, [(16, 3), (22, 9), (19, 15), (13, 15), (10, 9)], R["ciano"], "cristallo")
    griglia(t, ["W.", ".W"], {"W": colore("white")}, 13, 7, "riflesso", separa=False)


def cuoio_conciato(t):
    """Pelle conciata arrotolata e legata con due lacci, il bordo irregolare della pelle che si vede di lato."""
    segmento(t, (6, 18), (26, 14), 5.6, 5.6, R["cuoio_chiaro"], "rotolo")
    for x, y in ((6, 18), (26, 14)):
        segmento(t, (x, y), (x, y), 5.0, 5.0, R["cuoio"], f"capo{x}", uniti=("rotolo",))
        segmento(t, (x, y), (x, y), 2.0, 2.0, R["cuoio_chiaro"], f"spirale{x}", uniti=("rotolo",), separa=False)
    for x in (11, 20):
        segmento(t, (x, 11), (x + 1, 22), 0.7, 0.7, R["legno"], f"laccio{x}", separa=False)


def piuma_dei_venti(t):
    """Piuma lunga e chiara col fusto curvo, le barbe che si aprono come in un soffio, tre filetti di vento azzurri."""
    segmento(t, (6, 28), (25, 4), 0.6, 0.4, R["corda"], "fusto")
    for k in range(9):
        x, y = 8 + k * 2.0, 25 - k * 2.6
        segmento(t, (x, y), (x - 4 + k * 0.2, y - 2), 1.2, 0.5, R["piuma"], f"barba_s{k}")
        segmento(t, (x, y), (x + 3, y + 2.5 - k * 0.1), 1.2, 0.5, R["piuma"], f"barba_d{k}")
    for k, y in enumerate((8, 14, 20)):
        griglia(t, ["cc..", "..cc"], {"c": colore("cyan")}, 22 + (k % 2) * 2, y, f"vento{k}", separa=False)


def chiave_del_faro(t):
    """Chiave grande di bronzo con l'anello a forma di faro (torre e lanterna), i denti larghi."""
    segmento(t, (16, 14), (16, 29), 1.4, 1.4, R["oro"], "fusto")
    _poligono(t, [(16, 29), (22, 29), (22, 26), (19, 26), (19, 24), (16, 24)], R["oro"], "denti")
    _poligono(t, [(12, 14), (20, 14), (18, 5), (14, 5)], R["oro"], "torre")
    griglia(t, ["yyy", "yWy"], {"y": colore("yellow"), "W": colore("white")}, 15, 2, "lanterna", separa=False)
    for y in (8, 11):
        segmento(t, (14, y), (18, y), 0.4, 0.4, R["rosso"], f"fascia{y}", separa=False)


def arma_spezzata(t):
    """Una spada rotta in due: l'elsa con un moncone di lama e la punta staccata piu' in la', i bordi seghettati."""
    segmento(t, (6, 26), (15, 15), 1.8, 1.6, R["lama"], "moncone")
    griglia(t, ["l.", ".l", "l."], {"l": colore("grey_l")}, 15, 13, "rottura", separa=False)
    segmento(t, (3, 23), (9, 29), 1.2, 1.2, R["ferro"], "guardia")
    segmento(t, (5, 27), (2.5, 29.5), 1.2, 1.2, R["cuoio"], "impugnatura")
    segmento(t, (19, 11), (27, 3), 1.6, 0.4, R["lama"], "punta")


def pergamena_alba(t):
    """Pergamena aperta srotolata a meta', con un sole che sorge disegnato in oro e i raggi, il sigillo arancio."""
    _poligono(t, [(6, 7), (26, 7), (26, 24), (6, 24)], R["carta"], "foglio")
    segmento(t, (6, 26), (26, 26), 2.6, 2.6, R["carta"], "rotolo")
    ys, xs = np.mgrid[0:L, 0:L]
    sole = (np.hypot(xs + 0.5 - 16, ys + 0.5 - 19) <= 5) & (ys + 0.5 <= 19)
    c = np.zeros((L, L, 3), np.uint8)
    c[sole] = colore("amber")
    t.metti(sole, c, "sole", separa=False)
    for k in range(5):
        a = np.pi * (0.1 + 0.2 * k)
        segmento(t, (16 + np.cos(a) * 7, 19 - np.sin(a) * 7), (16 + np.cos(a) * 9, 19 - np.sin(a) * 9), 0.5, 0.5,
                 R["giallo" if False else "oro"], f"raggio{k}", separa=False)
    segmento(t, (22, 26), (22, 26), 2.4, 2.4, R["ambra"], "sigillo")


def libro_ordine_minore(t):
    """Libro rilegato in cuoio rosso scuro, borchie d'oro agli angoli, sulla copertina lo stemma dell'ordine (un occhio
    in un cerchio), il segnalibro di stoffa che pende."""
    _poligono(t, [(7, 5), (25, 5), (25, 27), (7, 27)], R["cera"], "copertina")
    _poligono(t, [(25, 6), (27, 7), (27, 28), (25, 27)], R["carta"], "pagine")
    for x, y in ((8, 6), (23, 6), (8, 25), (23, 25)):
        griglia(t, ["YY", "YY"], {"Y": colore("yellow")}, x, y, f"borchia{x}{y}", separa=False)
    ys, xs = np.mgrid[0:L, 0:L]
    cer = np.abs(np.hypot(xs + 0.5 - 16, ys + 0.5 - 16) - 5) <= 0.8
    c = np.zeros((L, L, 3), np.uint8)
    c[cer] = colore("amber")
    t.metti(cer, c, "stemma", separa=False)
    griglia(t, [".YYY.", "YYKYY", ".YYY."], {"Y": colore("amber"), "K": colore("ink")}, 14, 15, "occhio", separa=False)
    segmento(t, (12, 27), (11, 31), 0.8, 0.8, R["verde_s"], "segnalibro")


def sigillo_forza_minore(t):
    """Sigillo da incastonare: un disco di pietra rossa con il bordo d'argento e inciso un pugno chiuso."""
    segmento(t, (16, 16), (16, 16), 11.0, 11.0, R["argento"], "bordo")
    segmento(t, (16, 16), (16, 16), 9.0, 9.0, R["cera"], "pietra", uniti=("bordo",), separa=False)
    griglia(t, [".KKKK.", "KKKKKK", "KKKKKK", "KKKKK.", ".KKK..", ".KKK.."], {"K": colore("red_d")}, 13, 12, "pugno",
            separa=False)
    griglia(t, ["W"], {"W": colore("white")}, 10, 10, "riflesso", separa=False)


def sigillo_reale(t):
    """Il sigillo reale (moneta pregiata): grande medaglione d'oro con la corona in rilievo e il nastro blu e bianco."""
    segmento(t, (12, 4), (14, 12), 1.8, 1.8, R["ciano"], "nastro_a")
    segmento(t, (20, 4), (18, 12), 1.8, 1.8, R["bianco"] if "bianco" in R else R["piuma"], "nastro_b")
    segmento(t, (16, 19), (16, 19), 10.0, 10.0, R["oro"], "medaglione")
    segmento(t, (16, 19), (16, 19), 7.5, 7.5, R["ambra"], "campo", uniti=("medaglione",), separa=False)
    griglia(t, ["Y.Y.Y", "YYYYY", "YYYYY", "YYYYY"], {"Y": colore("yellow")}, 14, 16, "corona", separa=False)


OGGETTI = {f.__name__: f for f in (pozione_cura_minore, pozione_cura_maggiore, elisir_del_vigore, spada_ferrea,
                                   corazza_cuoio, amuleto_lunare, lingotto_ferro, cristallo_grezzo, pergamena_vigore,
                                   moneta_comune, elisir_ombra, ambrosia, tonico_di_forza, filtro_di_chiarezza,
                                   essenza_rara_di_guarigione, pastura_spirituale, lama_del_pentimento,
                                   corazza_espiazione, anello_del_richiamo, ascia_da_guerra, scudo_rinforzato,
                                   anello_di_cristallo, cuoio_conciato, piuma_dei_venti, chiave_del_faro, arma_spezzata,
                                   pergamena_alba, libro_ordine_minore, sigillo_forza_minore, sigillo_reale)}


def disegna(nome):
    t = Tela(L, L)
    OGGETTI[nome](t)
    t.contorno()
    return t.immagine()
