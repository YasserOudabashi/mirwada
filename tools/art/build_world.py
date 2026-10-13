#!/usr/bin/env python3
"""
Mappa di prova del mondo intero (US-8B13, PRD fase 8b).

    python tools/art/build_world.py                 # seed 4
    python tools/art/build_world.py --seed 5        # stessa disposizione, coste e colline diverse
    python tools/art/build_world.py --confronto 4 5 6 7   # piu' seed affiancati, per scegliere

Disposizione = variante C scelta dall'utente (006_PRD/prd-fase-8b-arte.md, par. 5):
Marche a nord-ovest, Archivio a nord-est, Mirwada al centro-sud sul porto, Valle a
sud-est sulla costa, Frontiera isola nel mare a sud, 6 isole piccole.

E' un abbozzo GREZZO: solo i terreni che forge3d ha gia' (i nuovi sono US-8B11),
niente edifici (US-8B18), tile da 32 (i 64 px sono US-8B01). Esce in arte/mondo/:
  world_prova.json        dati (formato World di forge3d + regioni + luoghi)
  mondo_prova.png         mappa intera, 3 px per tile, con confini e luoghi
  mondo_prova_<luogo>.png ritagli a tile vere, per vedere i terreni
Stesso seed = stessi file. I luoghi sono SUGGERIMENTI da correggere guardandoli.
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
W, H = 320, 220                      # ~100x60 tile per regione, piu' il mare a sud
COSTA = 0.66                         # frazione di H dove finisce la terraferma

# Regioni di terra: punto centrale (frazioni del mondo). Ordine = indice nella mappa.
TERRA = {"mirwada": (0.43, 0.50), "marche_crepuscolo": (0.20, 0.24),
         "archivio_sepolto": (0.72, 0.17), "valle_madre": (0.82, 0.50)}
PESO = {"archivio_sepolto": 1.45}   # >1 = regione piu' piccola (richiesta: Archivio in superficie ridotto)
# Isole: (id, cx, cy, raggio in tile, profilo)
ISOLE = [("frontiera_porte", 0.55, 0.87, 20, "frontiera"),
         ("isola_relitto", 0.12, 0.80, 8, "relitto"),
         ("isola_vulcanica", 0.30, 0.92, 9, "vulcanica"),
         ("isola_tropicale", 0.80, 0.80, 10, "tropicale"),
         ("isola_rovine", 0.93, 0.93, 7, "rovine"),
         ("scoglio_faro", 0.24, 0.76, 4, "faro"),
         ("isola_boss", 0.05, 0.95, 7, "boss")]
REGIONI = ["mare"] + list(TERRA) + [i[0] for i in ISOLE]
L = LEVEL
# alberi per profilo: (densita', [(tipo, foglia)])
ALBERI = {"campagna": (0.035, [("oak", "leaf_light"), ("oak", "leaf"), ("birch", "leaf_light")]),
          "giungla": (0.32, [("oak", "leaf_dark"), ("palm", "leaf_light"), ("oak", "leaf"), ("birch", "leaf_light")]),
          "neve": (0.006, [("pine", "snow")]),
          "tropicale": (0.20, [("palm", "leaf_light")]),
          "boss": (0.30, [("dead", "leaf"), ("oak", "leaf_dark")]),
          "frontiera": (0.03, [("dead", "leaf"), ("birch", "leaf_light")])}


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


def pulisci_enclavi(reg, minimo=300):
    """Pezzi staccati di una regione (Voronoi deformato) -> alla regione che li circonda."""
    vista = np.zeros(reg.shape, bool)
    for y0 in range(H):
        for x0 in range(W):
            if vista[y0, x0] or reg[y0, x0] == 0:
                continue
            r, pila, pezzo, vicini = reg[y0, x0], [(y0, x0)], [], {}
            vista[y0, x0] = True
            while pila:
                y, x = pila.pop()
                pezzo.append((y, x))
                for ny, nx in nb4(y, x):
                    if reg[ny, nx] == r and not vista[ny, nx]:
                        vista[ny, nx] = True
                        pila.append((ny, nx))
                    elif reg[ny, nx] not in (r, 0):
                        vicini[reg[ny, nx]] = vicini.get(reg[ny, nx], 0) + 1
            if len(pezzo) < minimo and vicini:
                nuovo = max(vicini, key=vicini.get)
                for y, x in pezzo:
                    reg[y, x] = nuovo
    return reg


def disco(cx, cy, r):
    yy, xx = np.mgrid[0:H, 0:W]
    return (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r


def astar(costo, a, b):
    """a, b = (x, y). costo = array HxW (np.inf = invalicabile)."""
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


def genera(seed):
    rnd = random.Random(seed)
    yy, xx = np.mgrid[0:H, 0:W]
    e = 0.65 * fbm(W, H, 28, 5, seed) + 0.35 * fbm(W, H, 9, 3, seed + 1)      # altezza
    m = fbm(W, H, 24, 4, seed + 2)                                            # umidita'
    d = fbm(W, H, 6, 2, seed + 9)                                             # macchie
    n1, n2 = fbm(W, H, 30, 3, seed + 3), fbm(W, H, 12, 2, seed + 4)

    # --- terra, regioni (Voronoi deformato dal rumore) e isole ---
    costa = H * COSTA + (n1 - 0.5) * 34 + (n2 - 0.5) * 10
    terra = yy < costa
    golfo = ((xx - TERRA["mirwada"][0] * W) / 26) ** 2 + ((yy - costa) / 15) ** 2 < 1
    terra &= ~golfo
    wx, wy = xx + (n2 - 0.5) * 60, yy + (n1 - 0.5) * 60
    dist = np.stack([np.hypot(wx - cx * W, wy - cy * H) * PESO.get(n, 1.0) for n, (cx, cy) in TERRA.items()])
    reg = pulisci_enclavi(np.where(terra, dist.argmin(0) + 1, 0))
    for i, (rid, cx, cy, r, _) in enumerate(ISOLE):
        isola = (np.hypot(xx - cx * W, (yy - cy * H) * 1.25) < r * (0.75 + 0.5 * n2)) & ~terra
        reg[isola] = REGIONI.index(rid)
    R = {n: reg == i for i, n in enumerate(REGIONI)}
    land = reg > 0
    nord = yy < H * 0.13 + (n1 - 0.5) * 18                                    # nord freddo

    # distanza dal mare (in tile, fino a 6) per spiagge e acque profonde
    dmare = np.where(land, 99, 0)
    for k in range(1, 7):
        lim = np.zeros_like(land)
        for sy, sx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            lim |= sposta(dmare == k - 1, sy, sx)
        dmare = np.where((dmare == 99) & lim, k, dmare)
    dacqua = np.where(~land, 99, 0)
    for k in range(1, 6):
        lim = np.zeros_like(land)
        for sy, sx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            lim |= sposta(dacqua == k - 1, sy, sx)
        dacqua = np.where((dacqua == 99) & lim, k, dacqua)

    g = np.full((H, W), L["grass"])
    g[~land] = np.where(dacqua[~land] > 4, L["deep_water"], L["water"])

    # Mirwada: campagna (uliveti = erba secca, boschetti), citta' sul porto
    mw = R["mirwada"]
    g[mw & (d > 0.66)] = L["dry_grass"]
    g[mw & (d < 0.14)] = L["forest"]
    # Marche: altopiano a gradoni, quasi niente verde
    mc = R["marche_crepuscolo"]
    lontano = np.hypot(xx - TERRA["mirwada"][0] * W, yy - TERRA["mirwada"][1] * H)
    alt = 0.35 * e + 0.65 * np.clip((lontano - 40) / 130, 0, 1)            # sale verso nord-ovest
    grad = np.floor(alt * 6).astype(int)
    bordo_grad = np.zeros_like(land)
    for sy, sx in ((1, 0), (0, 1)):
        bordo_grad |= grad != sposta(grad, sy, sx, -1)
    g[mc] = np.where(grad[mc] % 2 == 0, L["dirt"], L["dry_grass"])
    g[mc & ((d > 0.72) | bordo_grad)] = L["stone"]
    # Archivio: pianura bianca vuota
    g[R["archivio_sepolto"]] = L["snow"]
    # Valle: giungla fitta, radure d'erba, fango nelle zone umide
    vl = R["valle_madre"]
    g[vl] = np.where(m[vl] > 0.42, L["forest"], L["grass"])
    g[vl & (m > 0.72)] = L["mud"]
    g[nord & land & ~vl] = L["snow"]
    # coste: sabbia, ma scogliere nella Valle e nelle Marche
    riva = land & (dmare <= 2)
    riva |= R["mirwada"] & (dmare <= 3)                                   # spiagge di Mirwada piu' larghe
    g[riva] = L["sand"]
    g[riva & (vl | mc)] = L["stone"]
    # isole
    for rid, cx, cy, r, prof in ISOLE:
        z = R[rid]
        base = {"frontiera": L["grass"], "relitto": L["stone"], "vulcanica": L["dirt"], "tropicale": L["grass"],
                "rovine": L["dry_grass"], "faro": L["stone"], "boss": L["forest"]}[prof]
        g[z & (dmare > 1)] = base
        if prof == "vulcanica":
            g[z & (dmare > 3) & (d > 0.5)] = L["stone"]
        if prof in ("rovine", "frontiera"):
            g[z & (dmare > 2) & (d > 0.7)] = L["stone"]
        if prof == "boss":
            g[z & (dmare > 2) & (m > 0.6)] = L["mud"]

    # --- confini naturali e ingressi principali ---
    def confine(z):
        b = np.zeros_like(land)
        for sy, sx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            b |= z & land & ~sposta(z, sy, sx) & sposta(land, sy, sx)
        return b

    def ingresso(z, verso):
        """Punto del confine di z piu' vicino al centro di 'verso'."""
        ys, xs = np.nonzero(confine(z) & ~riva)
        cx, cy = TERRA[verso][0] * W, TERRA[verso][1] * H
        i = int(np.argmin((xs - cx) ** 2 + (ys - cy) ** 2))
        return int(xs[i]), int(ys[i])

    def ispessisci(b, k):
        for _ in range(k):
            b = b | sposta(b, 1, 0) | sposta(b, -1, 0) | sposta(b, 0, 1) | sposta(b, 0, -1)
        return b

    passo = ingresso(mc, "mirwada")
    galleria = ingresso(vl, "mirwada")
    scalinata = ingresso(R["archivio_sepolto"], "mirwada")
    rupi = ispessisci(confine(mc), 1) & land & ~disco(*passo, 3)
    g[rupi] = L["stone"]
    muro_verde = ispessisci(confine(vl), 2) & vl & ~disco(*galleria, 2) & ~riva
    g[muro_verde] = L["forest"]

    # --- Mirwada citta': porto sulla costa, isolati e strade, mura in rovina ---
    px = int(TERRA["mirwada"][0] * W)
    py = int(max(y for y in range(H) if land[y, px])) - 1
    porto, centro = (px, py), (px, py - 18)
    citta = disco(*centro, 22) & mw & (dmare > 1)
    isolati = ((xx % 6) < 4) & ((yy % 5) < 3)
    g[citta] = np.where(isolati[citta], L["stone"], L["path"])
    mura = disco(*centro, 23) & ~disco(*centro, 21) & mw & (dmare > 1)
    ang = np.degrees(np.arctan2(yy - centro[1], xx - centro[0])) % 360
    g[mura & ((ang % 40) < 26)] = L["stone"]            # tratti di mura, interrotti (in rovina)
    g[disco(*porto, 4) & land] = L["path"]               # banchine

    # --- fiumi: dal nord verso il mare, uno nella Valle e uno tra citta' e Marche ---
    acqua = ~land
    for sx in (int(0.82 * W), int(0.30 * W)):
        y, x, visti = int(H * 0.22), sx, set()
        for _ in range(H * 3):
            if acqua[y, x] and (y, x) not in visti and len(visti) > 5:
                break
            visti.add((y, x))
            if not acqua[y, x]:
                g[y, x] = L["water"]
            cand = [(e[ny, nx] - (ny - y) * 0.03 + rnd.random() * 0.01, ny, nx)
                    for ny, nx in nb4(y, x) if (ny, nx) not in visti]
            if not cand:
                break
            _, y, x = min(cand)
        acqua |= g == L["water"]

    # --- strade principali dal porto agli ingressi e ai luoghi fuori le mura ---
    archivio_ordine = (centro[0] + 6, centro[1] - 34)
    cimitero = (centro[0] + 30, centro[1] - 4)
    costo = np.where(g == L["stone"], 25.0, 1.0) + np.where(g == L["forest"], 4.0, 0.0)
    costo[acqua] = 40.0
    strade, ponti = [], []
    for meta in (passo, galleria, scalinata, archivio_ordine, cimitero):
        p = astar(costo, porto, meta)
        strade.append(p)
        for x, y in p:
            if g[y, x] in (L["water"], L["deep_water"]):
                ponti.append({"type": "bridge", "x": x + .5, "y": y + .5, "variant": 0})
            elif not citta[y, x]:
                g[y, x] = L["path"]

    # --- luoghi (suggerimenti da correggere) ---
    interno = (xx >= 14) & (xx < W - 14) & (yy >= 14) & (yy < H - 14)

    def migliore(z, valore):
        v = np.where(z & interno, valore, -np.inf)
        y, x = np.unravel_index(int(np.argmax(v)), v.shape)
        return int(x), int(y)

    costa_mw = mw & riva
    lontano_dal_confine = -np.hypot(xx - TERRA["valle_madre"][0] * W, yy - TERRA["valle_madre"][1] * H)
    luoghi = {
        "porto": porto, "centro_antico": centro, "archivio_ordine": archivio_ordine, "cimitero": cimitero,
        "faro": migliore(costa_mw & (xx < px - 20), yy),             # la punta piu' a sud a ovest della citta' 
        "casa_base_porto": (porto[0] + 5, porto[1] - 2),
        "passo_tra_rupi": passo, "trono_del_gigante": migliore(mc, alt),
        "soglia_del_crepuscolo": migliore(mc & (alt > 0.45) & (alt < 0.65), d),
        "galleria_di_alberi": galleria, "radice_del_mondo": migliore(vl, lontano_dal_confine + e * 10),
        "grotte_di_marea": migliore(vl & riva, xx),
        "scalinata_archivio": scalinata, "torre_osservazione": (scalinata[0] + 5, scalinata[1] - 4),
        "approdo_frontiera": migliore(R["frontiera_porte"] & (dmare == 2), -yy),
    }
    for rid, cx, cy, r, prof in ISOLE[1:]:
        luoghi[rid] = (int(cx * W), int(cy * H))

    # --- villaggi, case e capanne: dove vive qualcuno (suggerimenti) ---
    def scegli(z, n, distanza, evita=()):
        ys, xs = np.nonzero(z & interno)
        ordine = list(range(len(xs)))
        rnd.shuffle(ordine)
        presi = []
        for i in ordine:
            q = (int(xs[i]), int(ys[i]))
            if all((q[0] - o[0]) ** 2 + (q[1] - o[1]) ** 2 >= distanza ** 2 for o in presi + list(evita)):
                presi.append(q)
                if len(presi) == n:
                    break
        return presi

    def vicino_a(punto, da, a):
        dd = np.hypot(xx - punto[0], yy - punto[1])
        return (dd >= da) & (dd <= a)

    fiume = acqua & land
    riva_fiume = ispessisci(fiume, 1) & ~fiume
    lontano_citta = ~disco(*centro, 30)
    campagna = mw & lontano_citta & ~riva & np.isin(g, [L["grass"], L["dry_grass"]])
    villaggi = {"villaggio_sugli_alberi": migliore(vl & vicino_a(galleria, 30, 45) & (g == L["forest"]), m),
                "capanna_base_valle": migliore(vl & vicino_a(galleria, 8, 14) & ~riva, d),
                "rifugio_base_marche": migliore(mc & vicino_a(passo, 10, 16) & ~rupi, d),
                "mulino": migliore(mw & riva_fiume & lontano_citta, -abs(yy - centro[1])),
                "villaggio_pescatori": migliore(R["isola_tropicale"] & (dmare == 2), xx)}
    for i, q in enumerate(scegli(mc & (g == L["dirt"]), 3, 30), 1):
        villaggi[f"eremita_{i}"] = q
    for i, q in enumerate(scegli(campagna & (g == L["dry_grass"]), 3, 22), 1):
        villaggi[f"fattoria_{i}"] = q
    for i, q in enumerate(scegli(campagna, 6, 16, list(villaggi.values())), 1):
        villaggi[f"casetta_{i}"] = q
    for i, q in enumerate(scegli(campagna & (d > 0.6), 3, 25, list(villaggi.values())), 1):
        luoghi[f"caverna_{i}"] = q
    for nome, (x, y) in villaggi.items():
        r = 3 if nome.startswith("villaggio") else 1
        g[disco(x, y, r) & land & ~acqua] = L["path"] if r == 3 else L["dirt"]

    w = World(W, H, seed, g, reg, e, REGIONI, water_mask=acqua)
    w.roads = [[list(map(int, q)) for q in p] for p in strade]
    w.objects = ponti

    # --- alberi e rocce ---
    profilo = np.full((H, W), "", object)
    profilo[mw & ~citta] = "campagna"
    profilo[vl] = "giungla"
    profilo[R["archivio_sepolto"]] = "neve"
    for rid, *_, prof in ISOLE:
        if prof in ALBERI:
            profilo[R[rid]] = prof
    ciuffi = fbm(W, H, 5, 2, seed + 77)
    occupato = acqua | (g == L["path"]) | (g == L["sand"]) | (g == L["stone"])
    for y in range(H):
        for x in range(W):
            if occupato[y, x]:
                if g[y, x] == L["stone"] and mc[y, x] and rnd.random() < 0.05:
                    w.objects.append({"type": "rock", "x": x + .5, "y": y + .7, "seed": rnd.randrange(6),
                                      "mat": "stone_light", "moss": False})
                continue
            prof = profilo[y, x] or None
            if prof is None:
                continue
            dens, tipi = ALBERI[prof]
            if muro_verde[y, x]:
                dens = 0.6
            if rnd.random() < dens * (0.4 + 1.6 * ciuffi[y, x]):
                kind, leaf = rnd.choice(tipi)
                w.objects.append({"type": "tree", "kind": kind, "leaf": leaf, "x": x + rnd.uniform(.2, .8),
                                  "y": y + rnd.uniform(.3, .9), "seed": rnd.randrange(6),
                                  "size": rnd.choice([0.9, 1.0, 1.1])})
    w.objects.sort(key=lambda o: o["y"])
    return w, luoghi, villaggi


def colori_terreni():
    """Colore medio del tile pieno di ogni terreno (indice 15 dell'atlante)."""
    out = []
    for n in ORDER:
        at = build_atlas(n, 32)
        t = at[:32, 15 * 32:16 * 32, :3].reshape(-1, 3)
        out.append(t.mean(0).astype(np.uint8))
    return np.array(out)


def anteprima(w, luoghi, villaggi, k=3, etichette=True):
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

    def scritta(x, y, s, c=(255, 255, 255)):
        for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            dr.text((x + ox, y + oy), s, fill=(24, 20, 37), font=font)
        dr.text((x, y), s, fill=c, font=font)

    for i, rid in enumerate(REGIONI[1:5], start=1):
        ys, xs = np.nonzero(reg == i)
        scritta(xs.mean() * k - 30, ys.mean() * k - 20, rid.upper(), (254, 231, 97))
    for nome, (x, y) in luoghi.items():
        dr.rectangle([x * k - 3, y * k - 3, x * k + 3, y * k + 3], fill=(228, 59, 68), outline=(24, 20, 37))
        if etichette:
            scritta(x * k + 6, y * k - 6, nome)
    for nome, (x, y) in villaggi.items():
        r = 6 if nome.startswith("villaggio") else 4
        dr.ellipse([x * k - r, y * k - r, x * k + r, y * k + r], fill=(254, 231, 97), outline=(24, 20, 37))
        if etichette:
            scritta(x * k + 7, y * k - 6, nome, (254, 231, 97))
    scritta(8, 6, f"N (freddo)   seed {w.seed}   {W}x{H} tile")
    scritta(8, H * k - 30, "quadrato rosso = luogo speciale", (228, 59, 68))
    scritta(8, H * k - 16, "cerchio giallo = villaggio, casa, capanna", (254, 231, 97))
    return im


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", type=int, default=4)
    ap.add_argument("--senza-ritagli", action="store_true", help="solo la mappa intera (piu' veloce)")
    ap.add_argument("--confronto", type=int, nargs="+", metavar="SEED",
                    help="solo un confronto affiancato tra piu' seed -> arte/mondo/confronto_seed.png")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    if a.confronto:
        imgs = [anteprima(*genera(sd), etichette=False) for sd in a.confronto]
        cols = 2
        righe = (len(imgs) + cols - 1) // cols
        tav = Image.new("RGB", (imgs[0].width * cols + 10 * (cols - 1), imgs[0].height * righe + 10 * (righe - 1)),
                        (244, 244, 244))
        for i, im in enumerate(imgs):
            tav.paste(im, ((i % cols) * (im.width + 10), (i // cols) * (im.height + 10)))
        tav.save(os.path.join(OUT, "confronto_seed.png"))
        print(f"confronto seed {a.confronto} -> {OUT}/confronto_seed.png")
        return
    w, luoghi, villaggi = genera(a.seed)
    j = w.to_json()
    j["ground"] = [[int(v) for v in r] for r in j["ground"]]
    j["biome_map"] = [[int(v) for v in r] for r in j["biome_map"]]
    j.pop("biomes")
    j.update({"regions": REGIONI, "region_map": j.pop("biome_map"), "luoghi": luoghi, "villaggi": villaggi, "tile": 32,
              "layout": {"terra": TERRA, "isole": ISOLE, "costa": COSTA}})
    with open(os.path.join(OUT, "world_prova.json"), "w") as f:
        json.dump(j, f, separators=(",", ":"))
    anteprima(w, luoghi, villaggi).save(os.path.join(OUT, "mondo_prova.png"))
    if not a.senza_ritagli:
        atl = {n: build_atlas(n, 32) for n in ORDER}
        for nome in ("porto", "passo_tra_rupi", "galleria_di_alberi", "scalinata_archivio", "approdo_frontiera"):
            x, y = luoghi[nome]
            box = (max(0, x - 20), max(0, y - 12), min(W, x + 20), min(H, y + 12))
            save(render_world(w, box, atlases=atl), os.path.join(OUT, f"mondo_prova_{nome}.png"))
    print(f"seed {a.seed}: {len(w.objects)} oggetti, {len(luoghi)} luoghi, {len(villaggi)} villaggi -> {OUT}")


if __name__ == "__main__":
    main()
