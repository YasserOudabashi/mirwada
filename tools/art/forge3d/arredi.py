"""Arredi degli interni (US-8B18d): un modello per id di data/world/arredi.json, stesso motore e stessa luce degli
edifici. Misure in unita' (32 per casella, size = scala); origine al centro del lato davanti del suo rettangolo di
larg x prof caselle, a terra, il davanti guarda +y (come creatures.edificio). La profondita' del modello e' divisa per
il seno della camera (SENO_CAMERA): una casella di profondita' a schermo = 32 / 0.53 unita' nel modello.
"""
import math
import random

from .creatures import SENO_CAMERA
from .rig import Rig

P = 1.0 / SENO_CAMERA
ALTEZZA = {"scaffale": 56, "camino": 56, "forgia": 56, "letto": 24, "bancone": 40, "alambicco": 44,
           "cornice_porta": 52}                                   # sopra il sedime
MURO = 48                  # contro il muro nord niente sale oltre z 48: la cima della parete (a schermo una casella)


def arredo(kind, larg, prof, seed=1, size=1.0):
    rnd = random.Random(seed)
    r = Rig(f"arredo_{kind}"); r.scale = size
    r.joint("a", "root", (0, 0, 0))
    W, D = larg * 32, prof * 32 * P                      # il rettangolo nel modello
    cy = -D / 2                                          # il centro del rettangolo
    dietro = -D + 9 * P                                  # appoggiato al muro nord (la casella dietro e' parete)

    def box(dim, pos, mat, rot=(0, 0, 0)):
        r.part("a", "box", dim, pos, mat=mat, rot=rot)

    def cyl(dim, pos, mat):
        r.part("a", "cylinder", dim, pos, mat=mat)

    if kind == "botte":
        cyl((10, 10, 12), (0, cy, 12), "wood_light")
        for z in (4, 20):
            cyl((10.6, 10.6, 1.2), (0, cy, z), "iron")
        cyl((9.4, 9.4, 0.6), (0, cy, 24.4), "wood")
    elif kind == "cassa":                                             # da carico, di assi: niente serratura ne' ferro
        box((11, 8, 8), (0, cy, 8), "wood_light")                     # (US-8B22: si aprono solo i forzieri)
        for sx in (-1, 1):
            box((1.4, 8.4, 8.4), (sx * 10.6, cy, 8.4), "wood")        # i montanti agli spigoli
        r.part("a", "box", (11.6, 8.2, 1.2), (0, cy, 16.6), (-14, 0, 0), "leather",   # il coperchio di assi,
               tex=("stripes", "y", 2.6, 0.12))                       # inclinato verso la luce
        box((12.5, 0.8, 1.3), (0, cy + 8.3, 8), "wood", rot=(0, 34, 0))   # la traversa in diagonale sul davanti
    elif kind in ("forziere", "forziere_aperto"):                    # US-8B22: coperchio a botte, ferro, serratura d'oro
        box((13, 8, 7), (0, cy, 7), "wood")
        for sx in (-8, 8):
            box((1.2, 8.6, 7.4), (sx, cy, 7.4), "iron")
        if kind == "forziere":
            cyl_x = (0, 90, 0)                                        # il cilindro col suo asse lungo x: la botte
            # le doghe corrono lungo il coperchio: la venatura del legno ("wood") qui andrebbe di traverso
            r.part("a", "cylinder", (8.4, 8.4, 13), (0, cy, 14), mat="leather", rot=cyl_x, tex=("stripes", "x", 2.8, 0.12))
            for sx in (-8, 8):
                r.part("a", "cylinder", (9.0, 9.0, 1.2), (sx, cy, 14), mat="iron", rot=cyl_x)
            box((2.2, 0.8, 3), (0, cy + 8.8, 13), "gold")             # la serratura sul davanti
        else:
            box((12.4, 7.4, 0.4), (0, cy, 13.8), "shadow_mat")         # il buio dentro, con l'oro che affiora
            for x, y, s in ((-5, -1, 1.0), (1, 2, 1.2), (6, -2, 0.9), (-1, -4, 0.8)):
                r.part("a", "ellipsoid", (3.2 * s, 2.6 * s, 2.6 * s), (x, cy + y, 15), mat="gold")
            r.part("a", "ellipsoid", (1.0, 1.0, 1.0), (1, cy + 1, 18.2), mat="glow_yellow")   # il luccichio
            su = (-58, 0, 0)                                          # il coperchio ribaltato indietro, sui cardini
            box((13, 4.2, 1.4), (0, cy - 9.8, 17.6), "wood", rot=su)
            for sx in (-8, 8):
                box((1.2, 4.6, 1.7), (sx, cy - 9.8, 17.6), "iron", rot=su)
    elif kind in ("tavolo", "scrittoio", "alambicco"):
        hw, hd = W / 2 - 4, min(D / 2 - 6, 24)
        box((hw, hd, 1.6), (0, cy, 17), "wood_light")
        for sx in (-1, 1):
            for sy in (-1, 1):
                box((1.6, 1.6, 8), (sx * (hw - 2.5), cy + sy * (hd - 2.5), 8), "wood")
        if kind == "tavolo":                                          # boccali e un piatto
            for k in range(rnd.randint(2, 3)):
                cyl((2.2, 2.2, 3), (rnd.uniform(-hw + 5, hw - 5), cy + rnd.uniform(-hd / 2, hd / 2), 21.6), "wood")
            cyl((5, 5, 0.6), (rnd.uniform(-hw / 2, hw / 2), cy, 19.2), "stone_light")
        elif kind == "scrittoio":                                     # libro aperto, fogli, candela accesa
            box((7, 5, 0.8), (-hw / 3, cy, 19.4), "cloth_cream", rot=(0, 0, 8))
            box((1, 5, 1.0), (-hw / 3, cy, 19.6), "leather_dark", rot=(0, 0, 8))
            box((4, 6, 0.4), (hw / 3, cy + 3, 19.0), "cloth_white", rot=(0, 0, -12))
            cyl((1.6, 1.6, 3.5), (hw - 6, cy - 6, 22), "cloth_white")
            r.part("a", "ellipsoid", (1.2, 1.2, 2.2), (hw - 6, cy - 6, 27.5), mat="fire")
        else:                                                         # alambicco: storte di vetro, distillatore di rame
            cyl((5, 5, 7), (-hw / 2, cy, 26), "bronze")
            r.part("a", "cone", (5, 5, 4), (-hw / 2, cy, 37), mat="bronze")
            for k, x in enumerate((hw / 4, hw / 2 + 2)):
                r.part("a", "ellipsoid", (4, 4, 4), (x, cy + (k - 0.5) * 6, 23), mat="glow_cyan" if k else "vetro")
                cyl((1.2, 1.2, 3), (x, cy + (k - 0.5) * 6, 29), "vetro")
    elif kind == "tavolo_rotondo":
        cyl((13, 13, 1.4), (0, cy, 17), "wood_light")
        cyl((2.2, 2.2, 8), (0, cy, 8), "wood")
        cyl((6, 6, 0.8), (0, cy, 0.8), "wood")
        cyl((2.2, 2.2, 3), (4, cy + 2, 21.4), "wood")
    elif kind == "sgabello":
        cyl((6.5, 6.5, 1.2), (0, cy, 11), "wood_light")
        for sx, sy in ((-4, -3), (4, -3), (0, 4)):
            box((1.1, 1.1, 5.5), (sx, cy + sy, 5.5), "wood")
    elif kind == "panca":
        box((W / 2 - 3, 7, 1.4), (0, cy, 10), "wood_light")
        for sx in (-1, 1):
            box((1.6, 6, 5), (sx * (W / 2 - 7), cy, 5), "wood")
    elif kind == "bancone":
        box((W / 2 - 2, 14, 14), (0, cy, 14), "wood")
        box((W / 2, 16, 1.6), (0, cy, 29.6), "wood_light")
        for k in range(1, larg * 2):                                  # pannelli del fronte
            box((0.8, 0.6, 11), (-W / 2 + 2 + k * (W - 4) / (larg * 2), cy + 14.4, 14), "wood_light")
        for k in range(rnd.randint(2, 4)):                            # bottiglie
            x = rnd.uniform(-W / 2 + 6, W / 2 - 6)
            cyl((1.8, 1.8, 4), (x, cy - 4, 35), rnd.choice(("vetro", "leaf_dark", "bronze")))
            cyl((0.8, 0.8, 1.5), (x, cy - 4, 40.5), "wood")
    elif kind == "scaffale":                                          # contro il muro: montanti, ripiani, libri e vasi
        for sx in (-1, 1):
            box((1.6, 8, MURO / 2), (sx * (W / 2 - 3), dietro, MURO / 2), "wood")
        ripiani = (2, 13.5, 25, 36.5, MURO - 0.5)                      # passo 11,5: i libri (alti al piu' 9) stanno sotto
        for z in ripiani:
            box((W / 2 - 3, 8, 1.0), (0, dietro, z), "wood_light")
        for z in ripiani[:-1]:
            x = -W / 2 + 6
            while x < W / 2 - 6:
                if rnd.random() < 0.18:                               # un vaso
                    cyl((2.6, 2.6, 3.5), (x + 2, dietro + 2, z + 4.5), rnd.choice(("stone_light", "vetro", "bronze")))
                    x += 6
                else:
                    a = rnd.uniform(3.0, 4.5)
                    box((1.1, 5, a), (x, dietro + 1, z + 1 + a), rnd.choice(
                        ("cloth_red", "cloth_blue", "cloth_green", "cloth_purple", "leather", "cloth_yellow")))
                    x += 2.4
    elif kind == "forgia":                                            # contro il muro: focolare di pietra, cappa, camino
        box((W / 2 - 4, 16, 12), (0, cy - 4, 12), "stone")
        box((W / 2 - 9, 11, 1.0), (0, cy - 4, 24.6), "fire")
        box((W / 2 - 5, 6, 6), (0, dietro - 2, 30), "brick")            # muro della cappa, attaccato al focolare
        box((W / 2 - 2, 9, 6), (0, dietro, MURO - 6), "brick")          # la cappa entra nel muro: niente oltre la cima
        box((W / 2 - 6, 1.2, 2.2), (0, cy + 12, 22), "iron")          # bordo di ferro
    elif kind == "incudine":
        cyl((7, 7, 6), (0, cy, 6), "wood")
        box((3, 2.5, 3), (0, cy, 14), "iron")
        box((9, 3.6, 2.4), (1, cy, 19), "iron")
        r.part("a", "cone", (2.4, 2.4, 4), (-11, cy, 19), mat="iron", rot=(0, -90, 0))
    elif kind == "letto":                                             # una casella di larghezza, due di profondita'
        box((W / 2 - 3, D / 2 - 2, 4), (0, cy, 6), "wood")
        su = (-14, 0, 0)                                              # inclinate verso la luce: piatte escono scure
        box((W / 2 - 4, D / 2 - 4, 3), (0, cy, 12), "cloth_cream", su)
        box((W / 2 - 3.5, D * 0.3, 3.4), (0, cy + D * 0.17, 12.4), rnd.choice(("cloth_red", "cloth_blue", "cloth_green")), su)
        box((W / 2 - 6, 7, 2.4), (0, -D + 12, 17), "cloth_white", su)    # cuscino
        box((W / 2 - 2, 2, 10), (0, -D + 3, 14), "wood")              # testiera
    elif kind == "camino":                                            # contro il muro: pietra, bocca buia, fuoco, mensola
        box((W / 2 - 3, 8, 24), (0, dietro, 24), "stone_light")
        box((W / 2 - 10, 0.4, 10), (0, dietro + 8.2, 11), "shadow_mat")
        r.part("a", "ellipsoid", (6, 2, 4), (0, dietro + 10, 5), mat="fire")      # davanti alla bocca buia
        box((W / 2 - 1, 10, 2), (0, dietro + 2, 40), "wood")
    elif kind == "sacchi":
        for k, (x, y, s) in enumerate(((-4, -3, 1.0), (5, 2, 0.85), (-1, 5, 0.75))):
            r.part("a", "ellipsoid", (7 * s, 6 * s, 9 * s), (x, cy + y, 8 * s), mat="cloth_cream" if k % 2 == 0 else "sand")
    elif kind == "vaso":
        r.part("a", "ellipsoid", (8, 8, 10), (0, cy, 10), mat="brick")
        cyl((4, 4, 2.5), (0, cy, 21), "brick")
    elif kind == "tappeto":                                           # a terra: niente collisione, sotto chi ci passa
        su = (-14, 0, 0)
        box((W / 2 - 3, D / 2 - 4, 0.5), (0, cy, 3), "cloth_red", su)
        box((W / 2 - 7, D / 2 - 9, 0.6), (0, cy, 3.3), "cloth_yellow", su)
        box((W / 2 - 9, D / 2 - 12, 0.7), (0, cy, 3.6), "cloth_red", su)
    elif kind == "sarcofago":                                         # cassa di pietra, coperchio scolpito
        su = (-16, 0, 0)                                              # piani inclinati verso la luce (piatti: scuri)
        box((W / 2 - 4, D / 2 - 8, 8), (0, cy, 8), "stone")
        box((W / 2 - 3, D / 2 - 7, 2), (0, cy, 17.5), "stone_light", su)
        box((W / 2 - 10, D / 2 - 12, 1.4), (0, cy, 20), "stone_light", su)
        r.part("a", "ellipsoid", (4.5, 4, 3), (-W / 2 + 12, cy, 22), mat="bone")       # la testa scolpita
    elif kind == "altare":                                            # blocco di pietra, drappo, due candele
        su = (-16, 0, 0)
        box((W / 2 - 4, D / 2 - 8, 10), (0, cy, 10), "stone_light")
        box((W / 2 - 2, D / 2 - 6, 1.6), (0, cy, 21), "stone_light", su)
        box((5, D / 2 - 5.5, 0.6), (0, cy, 22.8), "cloth_red", su)
        for sx in (-1, 1):
            cyl((1.6, 1.6, 3), (sx * (W / 2 - 8), cy - 4, 25.6), "cloth_white")
            r.part("a", "ellipsoid", (1.2, 1.2, 2.2), (sx * (W / 2 - 8), cy - 4, 31), mat="fire")
    elif kind == "roccia":                                            # massi con un po' di muschio
        r.part("a", "ellipsoid", (11, 8, 9), (-2, cy, 8), mat="stone")
        r.part("a", "ellipsoid", (7, 6, 6), (7, cy + 4, 5), mat="stone")
        r.part("a", "ellipsoid", (6, 4, 2), (-4, cy - 2, 16), mat="leaf_dark")
    elif kind == "sigillo":                                           # cerchio di glifi a terra che brilla
        su = (-16, 0, 0)                                              # inclinato verso la luce: piatto esce scuro
        for raggio, z, mat in ((28, 0.4, "glow_cyan"), (25, 0.8, "stone"), (14, 1.1, "glow_cyan"), (12, 1.4, "stone")):
            r.part("a", "cylinder", (raggio, (raggio - 2) * P * 0.7, 0.3), (0, cy, z + 2), mat=mat, rot=su)
        for k in range(6):
            a = k * math.pi / 3
            box((1.8, 1.8 * P, 0.3), (math.cos(a) * 19, cy + math.sin(a) * 18 * P * 0.7, 3.8), "glow_cyan", su)
    elif kind == "cornice_porta":                                     # una porta di scena senza muro (Frontiera)
        for sx in (-1, 1):
            box((2, 3, 22), (sx * 10, cy, 22), "intonaco_bianco")
        box((12, 3, 2), (0, cy, 45), "intonaco_bianco")
        box((8, 1, 21), (0, cy, 22), "shadow_mat")
        for sx in (-1, 1):
            box((1.0, 1.2, 21), (sx * 7.6, cy + 0.4, 22), "glow_purple")
    else:
        raise ValueError(f"arredo sconosciuto: {kind}")
    return r
