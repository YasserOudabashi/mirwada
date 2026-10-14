#!/usr/bin/env python3
"""
Mappa di prova del mondo intero (US-8B13b superficie + US-8B13c sottosuolo, PRD fase 8b).

    python tools/art/build_world.py                 # seed 6 (scelto dall'utente)
    python tools/art/build_world.py --senza-ritagli # solo le mappe intere (piu' veloce)
    python tools/art/build_world.py --confronto 4 5 6 7   # piu' seed affiancati, per scegliere

Mondo x3 + terra di mezzo + arcipelago + sottosuolo (decisione 2026-10-14, PRD par. 4b):
- continente: Marche a nord-ovest, Archivio a nord-est, Mirwada al centro-sud sul porto,
  Valle a sud-est, e al centro LA terra di mezzo (steppa, colline e rovine, foreste,
  paludi) con le rovine del boss;
- mare a sud: la Frontiera (la zona piu' grande) e un arcipelago di 16 isole;
- sottosuolo: una sola rete sotto il continente (fogne, catacombe, grotte, miniere,
  citta' sotterranea), stessa griglia della superficie, ingressi nello stesso punto.

E' un abbozzo: niente edifici (US-8B18), tile da 32 (i 64 px sono US-8B01). Esce in arte/mondo/:
  world_prova.json            dati (superficie + sottosuolo + luoghi), NON committato
  mondo_prova.png             superficie intera, 1 px per tile
  sottosuolo_prova.png        sottosuolo intero, 1 px per tile
  mondo_prova_<luogo>.png     ritagli a tile vere
Stesso seed = stessi file. Luoghi, villaggi e ingressi sono SUGGERIMENTI da correggere.
"""

import argparse
import heapq
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from forge3d.terrain import ORDER, build_atlas  # noqa: E402
from forge3d.world import LEVEL, World, fbm  # noqa: E402
from forge3d.worldrender import render_world, save  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "arte", "mondo")
W, H = 1200, 1000
COSTA = 0.46                       # frazione di H dove finisce il continente
HC = H * COSTA                     # altezza del continente
K = 3.4                            # scala del paesaggio rispetto alla prima mappa di prova (320x220)
KC = 2.0                           # scala di cimitero e monastero
SCHERMATA = 20 * 11                # tile in una schermata a 64 px

# Continente: centro di ogni zona in frazioni (x di W, y di HC). Ordine = indice nella mappa.
# Disposizione: tools/art/layout_mondo.json (la scrive anche l'artifact "tavolo tattico").
LAYOUT_PATH = os.path.join(HERE, "layout_mondo.json")
with open(LAYOUT_PATH, encoding="utf-8") as _f:
    LAYOUT = json.load(_f)
# Continente: centro di ogni zona in frazioni (x di W, y di HC). Ordine = indice nella mappa.
TERRA = {n: (v["x"], v["y"]) for n, v in LAYOUT["terra"].items()}
PESO = {n: v.get("peso", 1.0) for n, v in LAYOUT["terra"].items()}     # >1 zona piu' piccola, <1 piu' grande
MEZZO = {n: (v["x"], v["y"]) for n, v in LAYOUT["mezzo"].items()}
# Isole: (id, cx, cy in frazioni di W e H, raggio in tile, profilo).
ISOLE = [(i["id"], i["x"], i["y"], i["r"], i["profilo"]) for i in LAYOUT["isole"]]
RC = LAYOUT["citta"]["raggio"]      # raggio della citta' di Mirwada in tile (~55 schermate con 55)
REGIONI = ["mare"] + list(TERRA) + [i[0] for i in ISOLE]
SENZA_ALBERI = ["path", "sand", "stone", "lastre_chiare", "ciottoli_scuri", "molo_pietra", "pontile_legno",
                "lastricato_antico", "marmo", "ghiaia", "ciottoli_spiaggia", "arenaria", "pietrisco", "terra_bruciata",
                "sabbia_bianca", "cenere", "roccia_lavica", "lastre_rovine", "nebbia", "ghiaccio", "terra_rosa", "snow"]
L = LEVEL
# alberi per profilo: (densita', [(tipo, foglia)])
ALBERI = {"campagna": (0.035, [("oak", "leaf_light"), ("oak", "leaf"), ("birch", "leaf_light")]),
          "giungla": (0.32, [("oak", "leaf_dark"), ("palm", "leaf_light"), ("oak", "leaf"), ("birch", "leaf_light")]),
          "foresta": (0.28, [("oak", "leaf_dark"), ("pine", "leaf_dark"), ("oak", "leaf")]),
          "rado": (0.02, [("dead", "leaf"), ("pine", "leaf_dark")]),
          "neve": (0.006, [("pine", "snow")]),
          "tropicale": (0.20, [("palm", "leaf_light")]),
          "boss": (0.30, [("dead", "leaf"), ("oak", "leaf_dark")]),
          "frontiera": (0.03, [("dead", "leaf")])}                 # alberi pastello: con gli oggetti (US-8B18)
YY, XX = np.mgrid[0:H, 0:W]


def nb4(y, x):
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        if 0 <= y + dy < H and 0 <= x + dx < W:
            yield y + dy, x + dx


def sposta(a, dy, dx, fill=False):
    """Come np.roll ma senza fare il giro del mondo: entra 'fill' dal bordo."""
    out = np.full_like(a, fill)
    ys, yd = (slice(0, H - dy), slice(dy, H)) if dy >= 0 else (slice(-dy, H), slice(0, H + dy))
    xs, xd = (slice(0, W - dx), slice(dx, W)) if dx >= 0 else (slice(-dx, W), slice(0, W + dx))
    out[yd, xd] = a[ys, xs]
    return out


def ispessisci(b, k):
    for _ in range(k):
        b = b | sposta(b, 1, 0) | sposta(b, -1, 0) | sposta(b, 0, 1) | sposta(b, 0, -1)
    return b


def distanza(sorgente, massimo):
    """Distanza (a passi di 4 vicini) da 'sorgente', fino a 'massimo'; oltre vale 999."""
    dist = np.where(sorgente, 0, 999)
    fronte = sorgente.copy()
    for k in range(1, massimo + 1):
        fronte = ispessisci(fronte, 1) & (dist == 999)
        if not fronte.any():
            break
        dist[fronte] = k
    return dist


def componenti(mask):
    """Etichette delle parti connesse di 'mask' (4 vicini). Ritorna (etichette, n)."""
    lab = np.zeros(mask.shape, np.int32)
    n = 0
    for y0, x0 in zip(*np.nonzero(mask)):
        if lab[y0, x0]:
            continue
        n += 1
        lab[y0, x0] = n
        pila = [(y0, x0)]
        while pila:
            y, x = pila.pop()
            for ny, nx in nb4(y, x):
                if mask[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = n
                    pila.append((ny, nx))
    return lab, n


def pulisci_enclavi(reg, minimo):
    """Pezzi staccati di una zona (Voronoi deformato) -> alla zona che li circonda."""
    for r in np.unique(reg[reg > 0]):
        lab, n = componenti(reg == r)
        if n < 2:
            continue
        grandi = np.bincount(lab.ravel())[1:]
        for i in range(n):
            if grandi[i] >= minimo or grandi[i] == grandi.max():
                continue
            pezzo = lab == i + 1
            vicini = reg[ispessisci(pezzo, 1) & ~pezzo]
            vicini = vicini[(vicini > 0) & (vicini != r)]
            if len(vicini):
                reg[pezzo] = np.bincount(vicini).argmax()
    return reg


def disco(cx, cy, r):
    return (XX - cx) ** 2 + (YY - cy) ** 2 <= r * r


def centro_di(nome):
    return int(TERRA[nome][0] * W), int(TERRA[nome][1] * HC)


def astar(costo, a, b):
    """a, b = (x, y). costo = array HxW."""
    pq, came, g = [(0, a)], {a: None}, {a: 0}
    while pq:
        _, cur = heapq.heappop(pq)
        if cur == b:
            break
        for ny, nx in nb4(cur[1], cur[0]):
            ng = g[cur] + costo[ny, nx]
            if ng < g.get((nx, ny), math.inf):
                g[(nx, ny)] = ng
                came[(nx, ny)] = cur
                heapq.heappush(pq, (ng + abs(nx - b[0]) + abs(ny - b[1]), (nx, ny)))
    p, c = [], b
    while c is not None:
        p.append(c)
        c = came.get(c)
    return p[::-1]


def galleria(mask, a, b, larg, rnd):
    """Scava una galleria un po' storta da a a b (x, y) in 'mask'."""
    (x, y), (x1, y1) = a, b
    while abs(x - x1) + abs(y - y1) > 0:
        if rnd.random() < 0.5 and x != x1:
            x += 1 if x1 > x else -1
        elif y != y1:
            y += 1 if y1 > y else -1
        else:
            x += 1 if x1 > x else -1
        mask[max(0, y - larg // 2):y + larg - larg // 2, max(0, x - larg // 2):x + larg - larg // 2] = True


def genera(seed):
    rnd = random.Random(seed)
    rng = np.random.RandomState(seed)
    yy, xx = YY, XX
    e = 0.65 * fbm(W, H, 28 * K, 5, seed) + 0.35 * fbm(W, H, 9 * K, 3, seed + 1)      # altezza (paesaggio)
    m = fbm(W, H, 24 * K, 4, seed + 2)                                               # umidita'
    d = fbm(W, H, 6 * 1.5, 2, seed + 9)                                              # macchie (piccole)
    n1, n2 = fbm(W, H, 30 * K, 3, seed + 3), fbm(W, H, 12 * K, 2, seed + 4)

    # --- continente, zone (Voronoi deformato), golfo, isole ---
    costa = HC + (n1 - 0.5) * 34 * K + (n2 - 0.5) * 10 * K
    terra = yy < costa
    px = centro_di("mirwada")[0]
    golfo = ((xx - px) / (RC * 1.15)) ** 2 + ((yy - HC - 4) / (RC * 0.8)) ** 2 < 1 + (n2 - 0.5) * 0.3
    terra &= ~golfo
    wx, wy = xx + (n2 - 0.5) * 60 * K, yy + (n1 - 0.5) * 60 * K
    dist = np.stack([np.hypot(wx - cx * W, wy - cy * HC) * PESO.get(n, 1.0) for n, (cx, cy) in TERRA.items()])
    reg = np.where(terra, dist.argmin(0) + 1, 0)
    LAGUNE = []
    for rid, cx, cy, r, prof in ISOLE:
        dx, dy = xx - cx * W, (yy - cy * H) * 1.25
        if prof == "mostro":
            dx = dx / 1.8                                                  # isola lunga: la schiena della bestia
        rr = np.hypot(dx, dy)
        isola = (rr < r * (0.8 + 0.4 * n2)) & ~terra
        if prof == "atollo":
            LAGUNE.append((rr < r * 0.62) & ~terra)                        # laguna bassa dentro l'anello
            isola &= rr > r * 0.62
        reg[isola] = REGIONI.index(rid)
    reg = pulisci_enclavi(reg, int(300 * K * K))
    R = {n: reg == i for i, n in enumerate(REGIONI)}
    land = reg > 0
    nord = yy < HC * 0.10 + (n1 - 0.5) * 18 * K                                     # nord freddo
    dmare = distanza(~land, 60)
    dacqua = distanza(land, 6)
    mw, mc, ar, vl, tm = (R[n] for n in ("mirwada", "marche_crepuscolo", "archivio_sepolto", "valle_madre",
                                          "terra_di_mezzo"))

    g = np.full((H, W), L["grass"])
    g[~land] = np.where(dacqua[~land] > 4, L["deep_water"], L["water"])
    for laguna in LAGUNE:
        g[laguna & ~land] = L["water"]

    # Mirwada: campagna a filari e boschetti
    g[mw & (d > 0.66)] = L["filari"]
    g[mw & (d < 0.14)] = L["forest"]
    # Marche: gradoni che salgono allontanandosi da Mirwada
    cmw = centro_di("mirwada")
    lontano = np.hypot(xx - cmw[0], yy - cmw[1])
    alt = 0.35 * e + 0.65 * np.clip((lontano - 40 * K) / (130 * K), 0, 1)
    grad = np.floor(alt * 6).astype(int)
    bordo_grad = (grad != sposta(grad, 1, 0, -1)) | (grad != sposta(grad, 0, 1, -1))
    g[mc] = L["pietrisco"]
    g[mc & (m > 0.62)] = L["muschio_scuro"]
    g[mc & (d < 0.22)] = L["erica_secca"]
    ys_mc, xs_mc = np.nonzero(mc)
    campo = (int(xs_mc.mean()), int(ys_mc.mean()))
    g[mc & (np.hypot(xx - campo[0], yy - campo[1]) < (12 + (n2 - 0.5) * 10) * K)] = L["terra_bruciata"]
    g[mc & ((d > 0.72) | bordo_grad)] = L["arenaria"]
    # Archivio: pianura bianca
    g[ar] = L["snow"]
    # Valle: felci, radici nel cuore, palude
    g[vl] = np.where(m[vl] > 0.42, L["felci"], L["grass"])
    cvl = centro_di("valle_madre")
    g[vl & (np.hypot(xx - cvl[0], yy - cvl[1]) < 38 * K) & (m > 0.5)] = L["radici_muschio"]
    g[vl & (m > 0.72)] = L["palude"]
    # Terra di mezzo: 4 paesaggi (Voronoi interno) e le rovine del boss al centro
    dsub = np.stack([np.hypot(wx - cx * W, wy - cy * HC) for cx, cy in MEZZO.values()])
    sub = dsub.argmin(0)
    PAES = {n: tm & (sub == i) for i, n in enumerate(MEZZO)}
    g[PAES["steppa"]] = np.where(d[PAES["steppa"]] > 0.55, L["pietrisco"], L["dry_grass"])
    g[PAES["colline"]] = np.where(d[PAES["colline"]] > 0.74, L["lastre_rovine"], L["grass"])
    g[PAES["colline"] & (d < 0.2)] = L["dry_grass"]
    g[PAES["foreste"]] = np.where(m[PAES["foreste"]] > 0.35, L["felci"], L["forest"])
    g[PAES["paludi"]] = np.where(m[PAES["paludi"]] > 0.5, L["palude"], L["erica_secca"])
    g[PAES["paludi"] & (d > 0.75)] = L["mud"]
    rovine_boss = centro_di("terra_di_mezzo")
    g[disco(*rovine_boss, 10 * K / 2) & tm] = L["lastre_rovine"]
    g[nord & land & ~vl] = L["snow"]
    # coste: sabbia, scogliere di arenaria nella Valle e nelle Marche
    riva = land & (dmare <= 2)
    riva |= mw & (dmare <= 3)
    g[riva] = L["sand"]
    g[riva & (vl | mc)] = L["arenaria"]

    # isole
    for rid, cx, cy, r, prof in ISOLE:
        z = R[rid]
        base = {"frontiera": "erba_lilla", "relitto": "pietrisco", "vulcanica": "cenere", "tropicale": "grass",
                "rovine": "dry_grass", "faro": "arenaria", "boss": "forest", "pirati": "grass", "ghiacciata": "snow",
                "mostro": "muschio_scuro", "atollo": "sabbia_bianca", "boschiva": "forest",
                "rocciosa": "pietrisco"}[prof]
        g[z & (dmare > 1)] = L[base]
        if prof in ("relitto", "rocciosa"):
            g[z & (dmare > 1) & (d > 0.6)] = L["arenaria"]
        if prof == "vulcanica":
            g[z & (dmare > 4 * K / 2) & (d > 0.4)] = L["roccia_lavica"]
        if prof in ("tropicale", "atollo", "pirati"):
            g[z & (dmare <= 2)] = L["sabbia_bianca"]
        if prof == "rovine":
            g[z & (dmare > 1) & (d > 0.6)] = L["lastre_rovine"]
        if prof == "ghiacciata":
            g[z & (dmare > 6)] = L["ghiaccio"]
        if prof == "mostro":
            g[z & (dmare > 3) & (d > 0.65)] = L["roccia_viva"]
        if prof == "boss":
            g[z & (dmare > 2) & (m > 0.6)] = L["palude"]
        if prof == "frontiera":                       # isola d'arrivo, poi la nebbia con le isolette sospese
            g[z & (dmare > 2) & (d > 0.72)] = L["terra_rosa"]
            interno_f = z & (dmare > 22)
            g[interno_f] = L["nebbia"]
            ys_f, xs_f = np.nonzero(interno_f)
            cxf, cyf = int(xs_f.mean()), int(ys_f.mean())
            for k_i in range(6):                     # 5-6 isolette nella nebbia
                ang = k_i * 2 * math.pi / 6 + rnd.random() * 0.5
                ix, iy = int(cxf + math.cos(ang) * 70), int(cyf + math.sin(ang) * 50)
                g[interno_f & (np.hypot(xx - ix, yy - iy) < 14 + 8 * n2)] = L["erba_lilla"]
            g[interno_f & disco(cxf, cyf, 18)] = L["erba_lilla"]

    # --- confini e ingressi principali (verso Mirwada) ---
    def confine(z):
        b = np.zeros_like(land)
        for sy, sx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            b |= z & land & ~sposta(z, sy, sx) & sposta(land, sy, sx)
        return b

    def ingresso(z, verso):
        ys, xs = np.nonzero(confine(z) & ~riva)
        cx, cy = centro_di(verso)
        i = int(np.argmin((xs - cx) ** 2 + (ys - cy) ** 2))
        return int(xs[i]), int(ys[i])

    passo = ingresso(mc, "terra_di_mezzo")
    galleria_alberi = ingresso(vl, "mirwada")
    scalinata = ingresso(ar, "terra_di_mezzo")
    rupi = ispessisci(confine(mc), 1) & land & ~disco(*passo, 5)
    g[rupi] = L["arenaria"]
    muro_verde = ispessisci(confine(vl), 3) & vl & ~disco(*galleria_alberi, 3) & ~riva
    g[muro_verde] = L["felci"]
    g[disco(*scalinata, 3) & ar] = L["ghiaccio"]

    # --- Mirwada, grande citta' portuale a quartieri (risposte dell'utente 2026-10-14) ---
    py = int(np.nonzero(mw[:, px])[0].max()) - 1                       # riva nord del golfo (non la Frontiera!)
    porto, centro = (px, py), (px, py - int(RC * 0.6))
    rq = fbm(W, H, 18, 2, seed + 50) - 0.5                                         # confini irregolari
    dxc, dyc = xx - centro[0] + rq * RC * 0.5, yy - centro[1] + rq * RC * 0.4
    dc = np.hypot(dxc, dyc)
    base_citta = mw & (dmare > 1)
    vecchia = base_citta & (dc < RC * 0.85)                                       # dentro le mura
    fuori = base_citta & (dc >= RC * 0.9) & (dc < RC * 1.3)
    Q = {"porto_commerciale": vecchia & (yy > py - RC * 0.32) & (np.abs(xx - px) < RC * 0.75),
         "quartiere_operaio": vecchia & (dxc < -RC * 0.25),
         "centro_antico": vecchia & (dyc < -RC * 0.35),
         "bassifondi": fuori & (dxc < -RC * 0.3),
         "citta_nuova": fuori & (dxc >= -RC * 0.3) & (yy < py - RC * 0.15)}
    Q["quartiere_operaio"] &= ~Q["porto_commerciale"]
    Q["centro_antico"] &= ~Q["quartiere_operaio"]
    Q["centro_storico"] = vecchia & ~Q["porto_commerciale"] & ~Q["quartiere_operaio"] & ~Q["centro_antico"]
    citta = np.zeros((H, W), bool)
    for z in Q.values():
        citta |= z

    def isolati(z, passo_x, passo_y, larg, alt, strada, edificio=L["stone"]):
        """Strade e sedime degli edifici (stone = edifici, US-8B18)."""
        blocco = ((xx % passo_x) < larg) & ((yy % passo_y) < alt)
        g[z] = np.where(blocco[z], edificio, strada)

    isolati(Q["porto_commerciale"], 12, 9, 9, 6, L["ciottoli_scuri"])            # magazzini grandi
    isolati(Q["quartiere_operaio"], 5, 4, 4, 3, L["ciottoli_scuri"])             # case strette e fabbriche
    isolati(Q["centro_storico"], 8, 7, 6, 5, L["lastre_chiare"])                 # negozi, famiglie
    isolati(Q["centro_antico"], 10, 9, 8, 7, L["lastre_chiare"])                 # palazzi
    # bassifondi: terra e fango, baracche sparse e case crollate
    z = Q["bassifondi"]
    g[z] = np.where(d[z] < 0.25, L["mud"], L["dirt"])
    g[z & ((xx % 5) < 3) & ((yy % 4) < 2) & (d > 0.3)] = L["stone"]
    g[z & ((xx % 5) < 3) & ((yy % 4) < 2) & (d > 0.75)] = L["lastre_rovine"]
    # citta' nuova: giardini, ville e viali larghi
    z = Q["citta_nuova"]
    g[z] = L["grass"]
    g[z & ((xx % 14) < 5) & ((yy % 12) < 4)] = L["stone"]
    g[z & (((xx % 14) >= 11) | ((yy % 12) >= 9))] = L["lastre_chiare"]
    # piazze in marmo: centro storico (museo, mercanti) e centro antico (cattedrale)
    piazza_storico = (centro[0] + int(RC * 0.2), centro[1] + int(RC * 0.05))
    cattedrale = (centro[0], centro[1] - int(RC * 0.6))
    g[disco(*piazza_storico, RC * 0.1) & citta] = L["marmo"]
    g[disco(*cattedrale, RC * 0.08) & citta] = L["marmo"]
    # mura in rovina tra la citta' vecchia e quella nuova
    mura = base_citta & (dc >= RC * 0.85) & (dc < RC * 0.9)
    ang = np.degrees(np.arctan2(dyc, dxc)) % 360
    g[mura & ((ang % 40) < 26)] = L["stone"]
    # lungomare: passeggiata lungo il golfo, con la piazza del mercato
    lungomare = mw & (dmare >= 2) & (dmare <= 4) & (np.abs(xx - px) < RC * 1.0) & (yy > py - RC * 0.5)
    g[lungomare] = L["lastre_chiare"]
    citta |= lungomare
    sx_l = np.nonzero(lungomare & (xx > px + RC * 0.1) & (xx < px + RC * 0.35))
    piazza_mercato = (int(sx_l[1].mean()), int(sx_l[0].mean())) if len(sx_l[0]) else porto
    g[disco(*piazza_mercato, 5) & mw] = L["marmo"]
    g[riva & mw & ~citta & ((np.hypot(xx - porto[0], yy - porto[1]) < RC * 1.4) | (d > 0.62))] = L["ciottoli_spiaggia"]
    # moli di pietra e pontili di legno lungo il porto commerciale
    for i, dx in enumerate(range(-int(RC * 0.65), int(RC * 0.3), 10)):
        ter, larg, lung = ("molo_pietra", 4, 14) if i % 2 == 0 else ("pontile_legno", 2, 9)
        x0 = porto[0] + dx
        y0 = int(np.nonzero(mw[:, x0])[0].max())
        g[y0:y0 + lung + 1, x0:x0 + larg] = L[ter]
        land[y0:y0 + lung + 1, x0:x0 + larg] = True
    # cantiere navale sulla riva est del golfo: piazzale e scali di legno verso l'acqua
    xs_c = px + int(RC * 0.55)
    yc = int(np.nonzero(mw[:, xs_c])[0].max())
    cantiere = (xs_c, yc)
    g[disco(xs_c, yc - 4, 8) & mw] = L["pietrisco"]
    for k_s in range(4):
        x0 = xs_c - 9 + k_s * 6
        y0 = int(np.nonzero(mw[:, x0])[0].max())
        g[y0:y0 + 8, x0:x0 + 3] = L["pontile_legno"]
        land[y0:y0 + 8, x0:x0 + 3] = True
    # diga foranea: un lungo braccio di pietra dalla punta ovest del golfo, con il faro in fondo
    punta = mw & riva & (xx < px - RC * 0.5) & (xx > px - RC * 2.0)              # punta ovest del golfo
    ys_p, xs_p = np.nonzero(punta)
    i_p = int(np.argmax(ys_p))
    x_a, y_a = int(xs_p[i_p]), int(ys_p[i_p])
    x_b, y_b = px + int(RC * 0.1), y_a + int(RC * 0.25)                          # testata, davanti al porto
    n_p = max(abs(x_b - x_a), abs(y_b - y_a))
    for t in range(n_p + 1):
        xd = int(round(x_a + (x_b - x_a) * t / n_p))
        yd = int(round(y_a + (y_b - y_a) * t / n_p - math.sin(math.pi * t / n_p) * RC * 0.15))
        g[yd - 1:yd + 2, xd - 1:xd + 2] = L["molo_pietra"]
        land[yd - 1:yd + 2, xd - 1:xd + 2] = True
    faro_diga = (x_b, y_b)
    diga_meta = ((x_a + x_b) // 2, (y_a + y_b) // 2 - int(RC * 0.15))

    # --- fiumi: dal nord verso il mare ---
    acqua = ~land
    for sx in (0.12, 0.30, 0.56, 0.82):
        y, x, visti = int(HC * 0.15), int(sx * W), set()
        for _ in range(H * 3):
            if acqua[y, x] and (y, x) not in visti and len(visti) > 5:
                break
            visti.add((y, x))
            if not acqua[y, x]:
                g[y, x] = L["water"]
            cand = [(e[ny, nx] - (ny - y) * 0.004 + rnd.random() * 0.002, ny, nx)   # segue il terreno
                    for ny, nx in nb4(y, x) if (ny, nx) not in visti]
            if not cand:
                break
            _, y, x = min(cand)
        acqua |= g == L["water"]

    # --- strade principali dal porto ---
    archivio_ordine = (centro[0] + int(RC * 0.1), centro[1] - int(RC * 1.6))
    cimitero = (centro[0] + int(RC * 1.5), centro[1] - int(RC * 0.1))
    costo = np.where(np.isin(g, [L["stone"], L["arenaria"]]), 25.0, 1.0) + np.where(g == L["forest"], 4.0, 0.0)
    costo[acqua] = 40.0
    strade, ponti = [], []
    for meta in (rovine_boss, passo, galleria_alberi, scalinata, archivio_ordine, cimitero):
        p = astar(costo, porto, meta)
        strade.append(p)
        for x, y in p:
            if g[y, x] in (L["water"], L["deep_water"]):
                ponti.append({"type": "bridge", "x": x + .5, "y": y + .5, "variant": 0})
            elif not citta[y, x]:
                g[y, x] = L["lastricato_antico"]
    for luogo, r_marmo in ((cimitero, 2 * KC), (archivio_ordine, KC)):
        g[disco(*luogo, 5 * KC) & land] = L["ghiaia"]
        g[disco(*luogo, r_marmo + 1) & land] = L["marmo"]

    # --- luoghi (suggerimenti) ---
    interno = (xx >= 20) & (xx < W - 20) & (yy >= 20) & (yy < H - 20)

    def migliore(z, valore):
        v = np.where(z & interno, valore, -np.inf)
        y, x = np.unravel_index(int(np.argmax(v)), v.shape)
        return int(x), int(y)

    luoghi = {
        "porto": porto, "centro_antico": centro, "archivio_ordine": archivio_ordine, "cimitero": cimitero,
        "faro": faro_diga, "diga_foranea": diga_meta,
        "casa_base_porto": (porto[0] + 10, porto[1] - 4),
        "cantiere_navale": cantiere, "piazza_mercato": piazza_mercato, "museo": piazza_storico,
        "cattedrale": cattedrale, "dogana": (porto[0] - int(RC * 0.2), porto[1] - 3),
        "passo_tra_rupi": passo, "trono_del_gigante": migliore(mc, alt),
        "soglia_del_crepuscolo": migliore(mc & (alt > 0.45) & (alt < 0.65), d),
        "campo_di_battaglia": campo,
        "galleria_di_alberi": galleria_alberi,
        "radice_del_mondo": migliore(vl, -np.hypot(xx - cvl[0], yy - cvl[1]) + e * 10),
        "grotte_di_marea": migliore(vl & riva, xx),
        "scalinata_archivio": scalinata, "torre_osservazione": (scalinata[0] + 8, scalinata[1] - 6),
        "rovine_del_boss": rovine_boss,
        "approdo_frontiera": migliore(R["frontiera_porte"] & (dmare == 2), -yy),
    }
    for q_nome in ("quartiere_operaio", "bassifondi", "citta_nuova", "centro_antico"):
        ys_q, xs_q = np.nonzero(Q[q_nome])
        if len(xs_q):
            luoghi[q_nome] = (int(xs_q.mean()), int(ys_q.mean()))
    for rid, cx, cy, r, prof in ISOLE[1:]:
        ys_i, xs_i = np.nonzero(R[rid])
        if len(xs_i):
            luoghi[rid] = (int(xs_i.mean()), int(ys_i.mean()))

    # --- villaggi, case, capanne, accampamenti (suggerimenti) ---
    def scegli(z, n, dist_min, evita=()):
        ys, xs = np.nonzero(z & interno)
        ordine = rng.permutation(len(xs))
        presi = []
        for i in ordine:
            q = (int(xs[i]), int(ys[i]))
            if all((q[0] - o[0]) ** 2 + (q[1] - o[1]) ** 2 >= dist_min ** 2 for o in presi + list(evita)):
                presi.append(q)
                if len(presi) == n:
                    break
        return presi

    def vicino_a(punto, da, a):
        dd = np.hypot(xx - punto[0], yy - punto[1])
        return (dd >= da) & (dd <= a)

    fiume = acqua & land
    riva_fiume = ispessisci(fiume, 1) & ~fiume
    lontano_citta = ~disco(*centro, RC * 1.4)
    campagna = mw & lontano_citta & ~riva & np.isin(g, [L["grass"], L["dry_grass"], L["filari"]])
    villaggi = {"villaggio_sugli_alberi": migliore(vl & vicino_a(galleria_alberi, 30 * K, 45 * K) & (g == L["felci"]), m),
                "capanna_base_valle": migliore(vl & vicino_a(galleria_alberi, 8 * K, 14 * K) & ~riva, d),
                "rifugio_base_marche": migliore(mc & vicino_a(passo, 10 * K, 16 * K) & ~rupi, d),
                "mulino": migliore(mw & riva_fiume & lontano_citta, -abs(yy - centro[1])),
                "villaggio_pescatori": migliore(R["isola_tropicale"] & (dmare == 2), xx),
                "villaggio_pirati": migliore(R["isola_pirati"] & (dmare == 2), -yy)}
    for paes, z in PAES.items():
        villaggi[f"villaggio_libero_{paes}"] = migliore(z & ~disco(*rovine_boss, 30 * K / 2) & (d < 0.5), -np.hypot(
            xx - MEZZO[paes][0] * W, yy - MEZZO[paes][1] * HC))
    for i, q in enumerate(scegli(tm & ~disco(*rovine_boss, 25 * K), 4, 25 * K, list(villaggi.values())), 1):
        villaggi[f"accampamento_banditi_{i}"] = q
    for i, q in enumerate(scegli(mc & (g == L["pietrisco"]), 3, 30 * K), 1):
        villaggi[f"eremita_{i}"] = q
    for i, q in enumerate(scegli(campagna & (g == L["filari"]), 3 * 2, 22 * K / 2), 1):
        villaggi[f"fattoria_{i}"] = q
    for i, q in enumerate(scegli(campagna, 6 * 2, 16 * K / 2, list(villaggi.values())), 1):
        villaggi[f"casetta_{i}"] = q
    for i, q in enumerate(scegli(campagna & (d > 0.6), 3 * 2, 25 * K / 2, list(villaggi.values())), 1):
        luoghi[f"caverna_{i}"] = q
    for nome, (x, y) in villaggi.items():
        r = 4 if nome.startswith(("villaggio", "accampamento")) else 1
        g[disco(x, y, r) & land & ~acqua] = L["path"] if r > 1 else L["dirt"]

    w = World(W, H, seed, g, reg, e, REGIONI, water_mask=acqua)
    w.citta = citta                                   # per misurare la citta' e disegnarne l'anteprima
    w.roads = [[list(map(int, q)) for q in p] for p in strade]
    w.objects = ponti

    # --- alberi e rocce (calcolati su tutta la mappa insieme) ---
    profilo = np.full((H, W), "", object)
    profilo[mw & ~citta] = "campagna"
    profilo[vl] = "giungla"
    profilo[ar] = "neve"
    profilo[PAES["foreste"]] = "foresta"
    profilo[PAES["colline"] | PAES["steppa"] | PAES["paludi"]] = "rado"
    for rid, *_, prof in ISOLE:
        profilo[R[rid]] = {"pirati": "tropicale", "atollo": "tropicale", "boschiva": "foresta"}.get(prof, prof)
    ciuffi = fbm(W, H, 5, 2, seed + 77)
    occupato = acqua | np.isin(g, [L[n] for n in SENZA_ALBERI])
    dens = np.zeros((H, W))
    for prof, (dd_, _) in ALBERI.items():
        dens[profilo == prof] = dd_
    dens[muro_verde] = 0.6
    p_albero = dens * (0.4 + 1.6 * ciuffi)
    scelti = (rng.rand(H, W) < p_albero) & ~occupato
    for y, x in zip(*np.nonzero(scelti)):
        kind, leaf = ALBERI[profilo[y, x]][1][rng.randint(len(ALBERI[profilo[y, x]][1]))]
        w.objects.append({"type": "tree", "kind": kind, "leaf": leaf, "x": x + rng.uniform(.2, .8),
                          "y": y + rng.uniform(.3, .9), "seed": int(rng.randint(6)),
                          "size": [0.9, 1.0, 1.1][rng.randint(3)]})
    rocce = (g == L["arenaria"]) & mc & (rng.rand(H, W) < 0.05)
    for y, x in zip(*np.nonzero(rocce)):
        w.objects.append({"type": "rock", "x": x + .5, "y": y + .7, "seed": int(rng.randint(6)),
                          "mat": "stone_light", "moss": False})
    w.objects.sort(key=lambda o: o["y"])
    sotto = genera_sottosuolo(seed, R, land, acqua, centro, rovine_boss, porto, rnd, rng, g)
    applica_spostati(luoghi, villaggi, sotto)
    return w, luoghi, villaggi, sotto


def applica_spostati(luoghi, villaggi, sotto):
    """Le decisioni dell'utente (tavolo tattico) vincono sui suggerimenti: [x, y] sposta o aggiunge, null cancella."""
    for chiave, dove in (("luoghi", luoghi), ("villaggi", villaggi), ("ingressi", sotto["ingressi"]),
                         ("boss", sotto["boss"])):
        for nome, pos in LAYOUT["spostati"].get(chiave, {}).items():
            if pos is None:
                dove.pop(nome, None)
            else:
                dove[nome] = (int(pos[0]), int(pos[1]))


def genera_sottosuolo(seed, R, land, acqua, centro, rovine_boss, porto, rnd, rng, g_sopra):
    """Una sola rete sotto il continente. Stessa griglia della superficie: un ingresso ha le
    stesse coordinate sopra e sotto. -1 = roccia (diventa 'roccia_viva')."""
    yy, xx = YY, XX
    mw, mc, ar, vl, tm = R["mirwada"], R["marche_crepuscolo"], R["archivio_sepolto"], R["valle_madre"], \
        R["terra_di_mezzo"]
    s = np.full((H, W), -1)
    zona = np.full((H, W), "", object)
    # fogne sotto la citta': griglia di corridoi con il canale al centro
    fogne_area = disco(*centro, 75) & mw
    corr = fogne_area & (((xx % 10) < 3) | ((yy % 9) < 3))
    s[corr] = L["ciottoli_scuri"]
    canale = fogne_area & (((xx - centro[0]) % 30 == 1) | ((yy - centro[1]) % 27 == 1))
    s[canale & corr] = L["water"]
    zona[corr] = "fogne"
    sbocco = np.zeros((H, W), bool)
    galleria(sbocco, (centro[0], centro[1] + 20), (porto[0] - 30, porto[1] + 1), 3, rnd)   # sbocco sul mare
    s[sbocco & (s < 0)] = L["ciottoli_scuri"]
    zona[sbocco & (zona == "")] = "fogne"
    # catacombe sotto le Marche: stanze collegate a catena
    ys_m, xs_m = np.nonzero(mc)
    stanze = []
    for _ in range(240):
        i = rng.randint(len(xs_m))
        stanze.append((int(xs_m[i]), int(ys_m[i]), int(rng.randint(4, 10))))
    cat = np.zeros((H, W), bool)
    for i, (x, y, r) in enumerate(stanze):
        cat[y - r:y + r, x - r:x + r] = True
        if i:
            px_, py_, _ = min(stanze[:i], key=lambda q: (q[0] - x) ** 2 + (q[1] - y) ** 2)
            galleria(cat, (x, y), (px_, py_), 2, rnd)
    cat &= mc
    s[cat] = L["lastre_rovine"]
    zona[cat] = "catacombe"
    # grotte sotto la Valle: caverne naturali con laghi sotterranei
    cav = fbm(W, H, 14, 3, seed + 31)
    grotte = vl & (cav > 0.52)
    s[grotte] = np.where(cav[grotte] > 0.72, L["water"], np.where(cav[grotte] > 0.64, L["muschio_scuro"],
                                                                     L["pietrisco"]))
    zona[grotte] = "grotte"
    # miniere sotto la terra di mezzo: gallerie dritte con diramazioni
    ys_t, xs_t = np.nonzero(tm)
    min_mask = np.zeros((H, W), bool)
    for _ in range(170):
        i = rng.randint(len(xs_t))
        x, y = int(xs_t[i]), int(ys_t[i])
        for _ in range(3):
            lung = int(rng.randint(25, 70))
            if rng.rand() < 0.5:
                x1, y1 = x + int(rng.choice([-1, 1])) * lung, y
            else:
                x1, y1 = x, y + int(rng.choice([-1, 1])) * lung
            x1, y1 = int(np.clip(x1, 1, W - 2)), int(np.clip(y1, 1, H - 2))
            min_mask[min(y, y1):max(y, y1) + 3, min(x, x1):max(x, x1) + 3] = True
            x, y = x1, y1
    min_mask &= tm
    s[min_mask] = L["dirt"]
    zona[min_mask] = "miniere"
    # citta' sotterranea sotto le rovine del boss
    cs = (((xx - rovine_boss[0]) / 45) ** 2 + ((yy - rovine_boss[1]) / 30) ** 2) < 1
    s[cs] = L["ciottoli_scuri"]
    s[cs & ((xx % 7 < 4) & (yy % 6 < 3))] = L["stone"]
    s[disco(*rovine_boss, 8)] = L["marmo"]
    zona[cs] = "citta_sotterranea"
    # una sola rete: ogni parte staccata si collega con una galleria alla parte piu' grande
    lab, n = componenti(s >= 0)
    grandezza = np.bincount(lab.ravel())
    grandezza[0] = 0
    principale = int(grandezza.argmax())
    pts_princ = np.column_stack(np.nonzero(lab == principale))[::40]
    for c in range(1, n + 1):
        if c == principale or grandezza[c] < 12:
            if c != principale:
                s[lab == c] = -1
                zona[lab == c] = ""
            continue
        ys_c, xs_c = np.nonzero(lab == c)
        a = (int(xs_c[0]), int(ys_c[0]))
        j = int(np.argmin((pts_princ[:, 1] - a[0]) ** 2 + (pts_princ[:, 0] - a[1]) ** 2))
        b = (int(pts_princ[j, 1]), int(pts_princ[j, 0]))
        tunnel = np.zeros((H, W), bool)
        galleria(tunnel, a, b, 2, rnd)
        s[tunnel & (s < 0)] = L["pietrisco"]
    # ingressi (stesso punto sopra e sotto) e boss di zona
    sopra_ok = land & ~acqua & ~np.isin(g_sopra, [L["deep_water"], L["water"], L["stone"]])
    interno = (xx >= 20) & (xx < W - 20) & (yy >= 20) & (yy < H - 20)
    ingressi, boss = {}, {}
    for z_nome, n_ing in (("fogne", 12), ("catacombe", 12), ("grotte", 10), ("miniere", 10), ("citta_sotterranea", 3)):
        cand = (zona == z_nome) & (s >= 0) & (s != L["water"]) & sopra_ok & interno
        ys_c, xs_c = np.nonzero(cand)
        ordine = rng.permutation(len(xs_c))
        presi = []
        for i in ordine:
            q = (int(xs_c[i]), int(ys_c[i]))
            if all((q[0] - o[0]) ** 2 + (q[1] - o[1]) ** 2 >= 18 ** 2 for o in presi):
                presi.append(q)
                if len(presi) == n_ing:
                    break
        for k_i, q in enumerate(presi, 1):
            ingressi[f"{z_nome}_{k_i}"] = q
        if z_nome != "citta_sotterranea" and presi:
            zz = (zona == z_nome) & (s >= 0) & (s != L["water"]) & interno          # non sul bordo
            ys_b, xs_b = np.nonzero(zz)
            dmin = np.min([np.hypot(xs_b - q[0], ys_b - q[1]) for q in presi], axis=0)
            i = int(np.argmax(dmin))
            boss[f"boss_{z_nome}"] = (int(xs_b[i]), int(ys_b[i]))
    ground = np.where(s >= 0, s, L["roccia_viva"])
    return {"ground": ground, "zona": zona, "ingressi": ingressi, "boss": boss, "pavimento": s >= 0}


def colori_terreni():
    """Colore medio del tile pieno di ogni terreno (indice 15 dell'atlante)."""
    out = []
    for n in ORDER:
        at = build_atlas(n, 32)
        t = at[:32, 15 * 32:16 * 32, :3].reshape(-1, 3)
        out.append(t.mean(0).astype(np.uint8))
    return np.array(out)


def _scritta(dr, font, x, y, s, c=(255, 255, 255)):
    for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        dr.text((x + ox, y + oy), s, fill=(24, 20, 37), font=font)
    dr.text((x, y), s, fill=c, font=font)


def anteprima(w, luoghi, villaggi, k=1, etichette=True, segni=True):
    col = colori_terreni()
    img = col[w.ground].copy()
    reg = w.biome
    bordo = np.zeros(reg.shape, bool)
    bordo[:, 1:] |= reg[:, 1:] != reg[:, :-1]
    bordo[1:, :] |= reg[1:, :] != reg[:-1, :]
    img[bordo & (reg > 0)] = (24, 20, 37)
    for o in w.objects:
        if o["type"] == "tree":
            img[int(o["y"]), int(o["x"])] = (25, 60, 62)
    im = Image.fromarray(img).resize((W * k, H * k), Image.NEAREST)
    dr = ImageDraw.Draw(im)
    font = ImageFont.load_default()
    if not segni:                                     # sfondo pulito per il tavolo tattico
        return im
    for i, rid in enumerate(REGIONI[1:len(TERRA) + 2], start=1):
        ys, xs = np.nonzero(reg == i)
        if len(xs):
            _scritta(dr, font, xs.mean() * k - 30, ys.mean() * k - 20, rid.upper(), (254, 231, 97))
    for nome, (x, y) in luoghi.items():
        dr.rectangle([x * k - 3, y * k - 3, x * k + 3, y * k + 3], fill=(228, 59, 68), outline=(24, 20, 37))
        if etichette:
            _scritta(dr, font, x * k + 6, y * k - 6, nome)
    for nome, (x, y) in villaggi.items():
        r = 5 if nome.startswith(("villaggio", "accampamento")) else 3
        dr.ellipse([x * k - r, y * k - r, x * k + r, y * k + r], fill=(254, 231, 97), outline=(24, 20, 37))
        if etichette and nome.startswith(("villaggio", "accampamento", "rifugio", "capanna")):
            _scritta(dr, font, x * k + 7, y * k - 6, nome, (254, 231, 97))
    _scritta(dr, font, 8, 6, f"N (freddo)   seed {w.seed}   {W}x{H} tile   1 px = 1 tile")
    _scritta(dr, font, 8, H * k - 30, "quadrato rosso = luogo speciale", (228, 59, 68))
    _scritta(dr, font, 8, H * k - 16, "cerchio giallo = villaggio, casa, capanna, accampamento", (254, 231, 97))
    return im


def anteprima_sotto(w, sotto, k=1, segni=True):
    col = colori_terreni()
    img = col[sotto["ground"]].copy()
    img[~sotto["pavimento"]] = (14, 12, 22)
    costa = w.biome > 0
    bordo = (costa != sposta(costa, 1, 0)) | (costa != sposta(costa, 0, 1))
    img[bordo] = (70, 70, 90)                       # la costa di sopra, per orientarsi
    im = Image.fromarray(img).resize((W * k, H * k), Image.NEAREST)
    if not segni:
        return im
    dr = ImageDraw.Draw(im)
    font = ImageFont.load_default()
    for nome, (x, y) in sotto["ingressi"].items():
        dr.rectangle([x * k - 3, y * k - 3, x * k + 3, y * k + 3], fill=(44, 232, 245), outline=(24, 20, 37))
    for nome, (x, y) in sotto["boss"].items():
        dr.rectangle([x * k - 4, y * k - 4, x * k + 4, y * k + 4], fill=(228, 59, 68), outline=(24, 20, 37))
        _scritta(dr, font, x * k + 7, y * k - 6, nome)
    for z_nome in ("fogne", "catacombe", "grotte", "miniere", "citta_sotterranea"):
        ys, xs = np.nonzero(sotto["zona"] == z_nome)
        if len(xs):
            _scritta(dr, font, xs.mean() * k - 30, ys.mean() * k - 24, z_nome.upper(), (254, 231, 97))
    _scritta(dr, font, 8, 6, f"SOTTOSUOLO   seed {w.seed}   linea grigia = costa di sopra")
    _scritta(dr, font, 8, H * k - 30, f"azzurro = ingresso ({len(sotto['ingressi'])})", (44, 232, 245))
    _scritta(dr, font, 8, H * k - 16, "rosso = boss di zona", (228, 59, 68))
    return im


CITTA_LUOGHI = ("porto", "museo", "piazza_mercato", "cattedrale", "dogana", "cantiere_navale", "faro",
                "diga_foranea", "casa_base_porto", "quartiere_operaio", "bassifondi", "citta_nuova", "centro_antico")


def anteprima_citta(w, luoghi, k=4):
    """La citta' di Mirwada ingrandita, con i nomi dei quartieri e dei luoghi."""
    ys, xs = np.nonzero(w.citta)
    fy = luoghi.get("faro", (0, 0))[1]
    x0, x1 = max(0, xs.min() - 25), min(W, xs.max() + 25)
    y0, y1 = max(0, ys.min() - 15), min(H, max(ys.max(), fy) + 15)
    col = colori_terreni()
    img = col[w.ground[y0:y1, x0:x1]].copy()
    im = Image.fromarray(img).resize(((x1 - x0) * k, (y1 - y0) * k), Image.NEAREST)
    dr = ImageDraw.Draw(im)
    font = ImageFont.load_default()
    for nome in CITTA_LUOGHI:
        if nome in luoghi:
            x, y = luoghi[nome]
            X, Y = (x - x0) * k, (y - y0) * k
            dr.rectangle([X - 4, Y - 4, X + 4, Y + 4], fill=(228, 59, 68), outline=(24, 20, 37))
            _scritta(dr, font, X + 8, Y - 6, nome)
    _scritta(dr, font, 8, 6, f"MIRWADA   {int(w.citta.sum()) / SCHERMATA:.0f} schermate di citta'   1 tile = {k} px")
    return im


TAVOLO = os.path.join(ROOT, "arte", "tavolo")


def esporta_tavolo(w, luoghi, villaggi, sotto):
    """File per l'artifact 'tavolo tattico': due sfondi puliti e i punti suggeriti dal generatore."""
    os.makedirs(TAVOLO, exist_ok=True)
    anteprima(w, luoghi, villaggi, segni=False).save(os.path.join(TAVOLO, "superficie.png"))
    anteprima_sotto(w, sotto, segni=False).save(os.path.join(TAVOLO, "sottosuolo.png"))
    righe, tot, sotto_tot = misure(w, sotto)
    punti = {"W": W, "H": H, "HC": HC, "seed": w.seed, "schermata": SCHERMATA,
             "luoghi": luoghi, "villaggi": villaggi, "ingressi": sotto["ingressi"], "boss": sotto["boss"],
             "misure": {n: round(v, 1) for n, v in righe}, "superficie": round(tot), "sottosuolo": round(sotto_tot),
             "citta": round(int(w.citta.sum()) / SCHERMATA),
             "layout": {k: LAYOUT[k] for k in ("terra", "mezzo", "isole", "citta", "spostati", "note")}}
    with open(os.path.join(TAVOLO, "punti.json"), "w", encoding="utf-8") as f:
        json.dump(punti, f, ensure_ascii=False, separators=(",", ":"))


def misure(w, sotto):
    """Schermate (20x11 tile a 64 px) per zona: per capire quanto e' grande il mondo."""
    righe = []
    for i, n in enumerate(REGIONI[1:], start=1):
        righe.append((n, int((w.biome == i).sum()) / SCHERMATA))
    tot = sum(v for _, v in righe)
    sotto_tot = int(sotto["pavimento"].sum()) / SCHERMATA
    return righe, tot, sotto_tot


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", type=int, default=6)
    ap.add_argument("--senza-ritagli", action="store_true", help="solo le mappe intere (piu' veloce)")
    ap.add_argument("--confronto", type=int, nargs="+", metavar="SEED",
                    help="solo un confronto affiancato tra piu' seed -> arte/mondo/confronto_seed.png")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    if a.confronto:
        imgs = [anteprima(*genera(sd)[:3], etichette=False).resize((W // 2, H // 2), Image.NEAREST)
                for sd in a.confronto]
        cols = 2
        nr = (len(imgs) + cols - 1) // cols
        tav = Image.new("RGB", (imgs[0].width * cols + 10 * (cols - 1), imgs[0].height * nr + 10 * (nr - 1)),
                        (244, 244, 244))
        for i, im in enumerate(imgs):
            tav.paste(im, ((i % cols) * (im.width + 10), (i // cols) * (im.height + 10)))
        tav.save(os.path.join(OUT, "confronto_seed.png"))
        print(f"confronto seed {a.confronto} -> {OUT}/confronto_seed.png")
        return
    w, luoghi, villaggi, sotto = genera(a.seed)
    j = w.to_json()
    j["ground"] = [[int(v) for v in r] for r in j["ground"]]
    j["biome_map"] = [[int(v) for v in r] for r in j["biome_map"]]
    j.pop("biomes")
    j.update({"regions": REGIONI, "region_map": j.pop("biome_map"), "luoghi": luoghi, "villaggi": villaggi,
              "tile": 32, "layout": {"terra": TERRA, "mezzo": MEZZO, "isole": ISOLE, "costa": COSTA},
              "sottosuolo": {"ground": [[int(v) for v in r] for r in sotto["ground"]],
                             "ingressi": sotto["ingressi"], "boss": sotto["boss"]}})
    with open(os.path.join(OUT, "world_prova.json"), "w") as f:
        json.dump(j, f, separators=(",", ":"))
    anteprima(w, luoghi, villaggi).save(os.path.join(OUT, "mondo_prova.png"))
    anteprima_sotto(w, sotto).save(os.path.join(OUT, "sottosuolo_prova.png"))
    anteprima_citta(w, luoghi).save(os.path.join(OUT, "mirwada_citta.png"))
    esporta_tavolo(w, luoghi, villaggi, sotto)
    if not a.senza_ritagli:
        atl = {n: build_atlas(n, 32) for n in ORDER}
        for nome in ("porto", "passo_tra_rupi", "rovine_del_boss", "galleria_di_alberi", "approdo_frontiera",
                     "atollo", "isola_mostro"):
            x, y = luoghi[nome]
            box = (max(0, x - 20), max(0, y - 12), min(W, x + 20), min(H, y + 12))
            save(render_world(w, box, atlases=atl), os.path.join(OUT, f"mondo_prova_{nome}.png"))
        ws = World(W, H, a.seed, sotto["ground"], w.biome, w.elev, REGIONI, water_mask=None)
        for nome, (x, y) in (("citta_sotterranea", luoghi["rovine_del_boss"]), ("fogne", luoghi["centro_antico"]),
                             ("grotte", sotto["boss"].get("boss_grotte", luoghi["radice_del_mondo"]))):
            box = (max(0, x - 20), max(0, y - 12), min(W, x + 20), min(H, y + 12))
            save(render_world(ws, box, atlases=atl, with_objects=False),
                 os.path.join(OUT, f"sottosuolo_prova_{nome}.png"))
    righe, tot, sotto_tot = misure(w, sotto)
    for n, v in righe:
        print(f"  {n:24s} {v:7.1f} schermate")
    print(f"  citta' di Mirwada: {int(w.citta.sum()) / SCHERMATA:.0f} schermate")
    print(f"seed {a.seed}: superficie {tot:.0f} schermate, sottosuolo {sotto_tot:.0f}; {len(w.objects)} oggetti, "
          f"{len(luoghi)} luoghi, {len(villaggi)} villaggi, {len(sotto['ingressi'])} ingressi -> {OUT}")


if __name__ == "__main__":
    main()
