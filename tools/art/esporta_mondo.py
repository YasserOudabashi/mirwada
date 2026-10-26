#!/usr/bin/env python3
"""
Esporta il mondo di prova (seed 6) per il gioco (US-8B12): Godot carica questi file con scripts/world/mondo.gd.

    python tools/art/esporta_mondo.py                 # tutte e due le modalita' (luminoso + cupo)
    python tools/art/esporta_mondo.py --tema cupo     # una sola
    python tools/art/esporta_mondo.py --solo-blocchi  # solo le collisioni (blocchi.png), pochi minuti
    python tools/art/esporta_mondo.py --sottosuolo    # solo il sottosuolo (secondo livello), luminoso e cupo
    python tools/art/esporta_mondo.py --solo-dati     # solo i riquadri delle regioni in mondo.json, pochi secondi
    python tools/art/esporta_mondo.py --edifici       # solo gli edifici della citta' (sprite, dati, collisioni)

Il terreno con pareti, bordi e varianti si compone qui in Python, a blocchi, esattamente come le anteprime
(build_world.ritaglio); poi si tengono solo le caselle 32x32 diverse (34 mila su 1,2 milioni): fogli-atlante + una
mappa di indici. Il gioco costruisce solo il pezzo attorno al giocatore. Gli oggetti (alberi, rocce, trono...) sono
sprite a parte, ordinati per profondita' nel gioco. L'acqua per ora e' ferma (frame 0).

assets/world/
    mondo.json              dati comuni ai due temi: misure, tile, partenza, luoghi, fogli, oggetti
    blocchi.png             1 px per casella: 255 = acqua o vuoto, 128 = dislivello (a piedi no, in volo si'), 0 = libera
    regioni.png             1 px per casella: indice della regione (mondo.json "regioni")
    <tema>/tessere_<k>.png  fogli-atlante, 64 x 128 tessere da 32 px
    <tema>/indici.png       1 px per casella: indice della tessera (R = byte basso, G = byte alto)
    <tema>/oggetti/<chiave>.png
Stesso seed = stessi file.
"""
import argparse
import hashlib
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_world as B  # noqa: E402
from forge3d import tema  # noqa: E402
from forge3d.creatures import SENO_CAMERA, TIPI_EDIFICIO  # noqa: E402
from forge3d.pareti import maschera as maschera_pareti  # noqa: E402
from forge3d.worldrender import object_sprite  # noqa: E402

OUT = os.path.join(B.ROOT, "assets", "world")
T = 32
BLOCCO = 100                  # caselle per lato di un blocco composto
COL, RIG = 64, 128            # tessere per foglio: 2048 x 4096 px (sotto il limite delle texture di Godot)


def tessere(w, alt=None, mat=None, pas=None, pieno=None):
    """Compone il mondo a blocchi e tiene le tessere diverse. -> (lista di tessere, indici H x W).
    pieno (sottosuolo): maschera della roccia; un blocco tutto roccia anche nei 12 dintorni (non si vede da nessuna
    galleria) prende la tessera di roccia di un blocco gia' composto invece di essere ricomposto."""
    alt = w.alt if alt is None else alt
    mat = w.mat_par if mat is None else mat
    pas = w.pas if pas is None else pas
    atl = {n: B.build_atlas(n, T) for n in B.ORDER}
    viste, lista = {}, []
    indici = np.zeros((B.H, B.W), np.int32)
    roccia = -1
    for by in range(0, B.H, BLOCCO):
        for bx in range(0, B.W, BLOCCO):
            x1, y1 = min(B.W, bx + BLOCCO), min(B.H, by + BLOCCO)
            if pieno is not None and roccia >= 0 and pieno[max(0, by - 12):y1 + 12, max(0, bx - 12):x1 + 12].all():
                indici[by:y1, bx:x1] = roccia
                continue
            img = B.ritaglio(w, (bx, by, x1, y1), alt, mat, pas, atl, oggetti=False)
            hh, ww = y1 - by, x1 - bx
            t4 = img.reshape(hh, T, ww, T, 4).swapaxes(1, 2)
            for i in range(hh):
                for j in range(ww):
                    k = hashlib.md5(t4[i, j].tobytes()).digest()
                    if k not in viste:
                        viste[k] = len(lista)
                        lista.append(t4[i, j].copy())
                    indici[by + i, bx + j] = viste[k]
            if pieno is not None and roccia < 0 and pieno[by:y1, bx:x1].all():
                roccia = int(indici[by + (y1 - by) // 2, bx + (x1 - bx) // 2])
        print(f"  righe {by}-{min(B.H, by + BLOCCO)}: {len(lista)} tessere")
    return lista, indici


ACQUA, DISLIVELLO = 255, 128

# US-8B18: il tipo di edificio di ogni quartiere della citta' (build_world.py, isolati())
TIPO_DI_QUARTIERE = {"porto_commerciale": "magazzino", "quartiere_operaio": "casa", "centro_storico": "bottega",
                     "centro_antico": "palazzo", "bassifondi": "baracca", "citta_nuova": "villa"}


def rettangoli(m):
    """Copre una maschera con rettangoli pieni (il primo libero in alto a sinistra, largo quanto puo', poi alto
    quanto puo'). -> [(x0, y0, larghezza, altezza)]"""
    m = m.copy()
    out = []
    for y, x in zip(*np.nonzero(m)):
        if not m[y, x]:
            continue
        x1 = x
        while x1 + 1 < m.shape[1] and m[y, x1 + 1]:
            x1 += 1
        y1 = y
        while y1 + 1 < m.shape[0] and m[y1 + 1, x:x1 + 1].all():
            y1 += 1
        m[y:y1 + 1, x:x1 + 1] = False
        out.append((int(x), int(y), int(x1 - x + 1), int(y1 - y + 1)))
    return out


PROFONDITA_MAX = 4      # un sedime piu' profondo diventa piu' file di case (il tetto di una casa 2 x 11 era una
                        # colonna alta tutto lo schermo)
LARGHEZZA_MAX = {"casa": 4, "bottega": 4, "baracca": 3, "villa": 5}   # case a schiera: una fila lunga diventa case
                        # singole (altezza, comignolo e porta propri); magazzini e palazzi restano lunghi


def sporgenza(tipo, prof=PROFONDITA_MAX):
    """Quanto un edificio copre a schermo oltre il lato dietro del suo sedime, in unita': il muro piu' alto (+4)
    visto a 32 gradi, piu' il colmo del tetto se sale oltre (stesse misure di forge3d.creatures.edificio)."""
    _, _, hw, _, pend = TIPI_EDIFICIO[tipo]
    cos = (1 - SENO_CAMERA ** 2) ** 0.5
    d = prof * 32
    colmo = 0.75 * d + 0.75 * d / SENO_CAMERA * np.tan(np.radians(pend)) * cos
    return (hw + 4) * cos + max(0.0, colmo - d)


def vicolo(tipo):
    """Caselle libere davanti a una casa perche' la sua soglia resti visibile sotto il tetto di quella davanti."""
    return int(sporgenza(tipo) / 32 + 0.5) + 1


def dividi(y0, lh, massimo, spazio=0):
    """Divide [y0, y0 + lh) in pezzi lunghi 2..massimo separati da 'spazio' caselle: -> [(inizio, lunghezza)].
    Un pezzo solo se non ce ne stanno due da 2 con lo spazio in mezzo. (Serve per le file, con il vicolo, e per le
    case di una fila, senza spazio.)"""
    n = max(1, min(-(-(lh + spazio) // (massimo + spazio)), (lh + spazio) // (2 + spazio)))
    case = lh - (n - 1) * spazio
    out, y = [], y0
    for k in range(n):
        p = case * (k + 1) // n - case * k // n
        out.append((y, p))
        y += p + spazio
    return out


def variante(x, y, n=6):
    """Variante 1..n di un edificio dalla sua posizione. Un hash, non una somma: con (7x + 13y) % 4 le case di una
    griglia a passo 4 avevano tutte la stessa variante lungo la colonna."""
    return int(hashlib.md5(f"{x},{y}".encode()).hexdigest(), 16) % n + 1


def edifici(w):
    """Gli edifici di Mirwada sui sedimi degli isolati (terreno stone dentro i quartieri, a livello 0, fuori dalle
    strade): un rettangolo almeno 2 x 2 = edifici del tipo del quartiere. Un sedime profondo diventa file di case
    con un vicolo in mezzo (vicolo(): il tetto di una fila non copre la soglia di quella dietro), una fila lunga
    diventa case singole (LARGHEZZA_MAX). Variante (seed) dalla posizione."""
    strada = np.zeros(w.alt.shape, bool)
    for s in list(w.roads) + list(w.sentieri):
        for x, y in s:
            strada[y, x] = True
    out = []
    for q, tipo in TIPO_DI_QUARTIERE.items():
        zona = getattr(w, "quartieri", {}).get(q)
        if zona is None:
            continue
        sedime = (w.ground == B.L["stone"]) & zona & (w.alt == 0) & ~w.water_mask & ~strada
        for x_, y_, lw_, lh_ in rettangoli(sedime):
            if lw_ < 2 or lh_ < 2:
                continue
            for y0, lh in dividi(y_, lh_, PROFONDITA_MAX, vicolo(tipo)):
                for x0, lw in dividi(x_, lw_, LARGHEZZA_MAX.get(tipo, lw_)):
                    out.append({"type": "edificio", "tipo": tipo, "x": x0, "y": y0, "w": lw, "h": lh,
                                "seed": variante(x0, y0)})
    return out


# Case dei villaggi suggeriti dal generatore (build_world.genera: villaggi) e torri sui luoghi: prefisso del nome
# del villaggio -> tipi di edificio, in ordine; misure in caselle per tipo.
CASE_DI_VILLAGGIO = {"villaggio_libero": ["casale", "casa", "capanna", "fienile", "casa"],
                     "villaggio_sugli_alberi": ["capanna", "capanna", "capanna", "capanna"],
                     "villaggio_pescatori": ["capanna", "capanna", "capanna"],
                     "villaggio_pirati": ["capanna", "casale", "capanna"],
                     "capanna_base": ["capanna"], "rifugio_base": ["casale"], "fattoria": ["casale", "fienile"],
                     "casetta": ["casa"], "eremita": ["capanna"], "accampamento_banditi": ["capanna", "capanna"],
                     "mulino": ["fienile"]}
TORRI_SUI_LUOGHI = {"torre_osservazione": "torre", "faro": "torre"}
MISURE = {"casa": (4, 3), "capanna": (3, 2), "casale": (5, 4), "fienile": (5, 3), "torre": (3, 2)}


def interni_per_villaggio():
    """Quanti edifici dei layout (data/world/layouts/*.json, campagna.json: edifici[].villaggio) vanno in ogni
    villaggio: il villaggio ha almeno tante case (mondo.gd crea_porte ci mette le porte)."""
    n = {}
    cart = os.path.join(B.ROOT, "data", "world")
    for nome in sorted(os.listdir(os.path.join(cart, "layouts"))) + ["../campagna.json"]:
        if nome.endswith(".json"):
            for e in json.load(open(os.path.join(cart, "layouts", nome))).get("edifici", []):
                if "villaggio" in e:
                    n[e["villaggio"]] = n.get(e["villaggio"], 0) + 1
    return n


def edifici_fuori_citta(w, luoghi, villaggi, gia):
    """Case vicino a ogni villaggio suggerito e torri sui luoghi: la prima area libera (anelli attorno al punto)
    larga quanto la casa piu' una casella di margine, con la soglia e le 3 caselle sotto libere (il tetto di una
    casa davanti non copre la porta), fuori da acqua, dislivelli, strade, luoghi e altre case. Un villaggio
    nell'angolo (0, 0) e' un posto non trovato dal generatore (il mulino): si salta."""
    libero = (blocchi(w, senza_edifici=True) == 0)
    strada = np.zeros(w.alt.shape, bool)
    for s_ in list(w.roads) + list(w.sentieri):
        for x, y in s_:
            strada[y, x] = True
    libero &= ~strada
    for x, y in luoghi.values():
        libero[max(0, y - 2):y + 3, max(0, x - 2):x + 3] = False
    occ = np.zeros(w.alt.shape, bool)
    for e in gia:
        occ[e["y"] - 1:e["y"] + e["h"] + 2, e["x"] - 1:e["x"] + e["w"] + 1] = True

    def posa(cx, cy, tipo, seed):
        lw, lh = MISURE[tipo]
        for r in range(0, 40):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if max(abs(dx), abs(dy)) != r:
                        continue
                    x0, y0 = cx + dx - lw // 2, cy + dy - lh
                    if x0 < 1 or y0 < 1 or x0 + lw + 1 >= B.W or y0 + lh + 4 >= B.H:
                        continue
                    area = (slice(y0 - 1, y0 + lh + 4), slice(x0 - 1, x0 + lw + 1))   # + margine, soglia e 3 sotto
                    if libero[area].all() and not occ[area].any():
                        occ[area] = True
                        return {"type": "edificio", "tipo": tipo, "x": int(x0), "y": int(y0), "w": lw, "h": lh,
                                "seed": seed}
        return None

    out = []
    servono = interni_per_villaggio()
    for nome, (x, y) in sorted(villaggi.items()):
        if (x, y) == (0, 0):
            continue
        tipi = list(next((v for k, v in CASE_DI_VILLAGGIO.items() if nome.startswith(k)), None) or [])
        tipi += tipi[:1] * (servono.get(nome, 0) - len(tipi))       # una casa per ogni interno del villaggio
        for i, tipo in enumerate(tipi):
            e = posa(x + (i % 3 - 1) * 7, y + (i // 3) * 8, tipo, (x * 3 + y + i) % 4 + 1)
            if e:
                out.append(e)
    for luogo, tipo in TORRI_SUI_LUOGHI.items():
        if luogo in luoghi:
            e = posa(luoghi[luogo][0], luoghi[luogo][1] + 3, tipo, 1)
            if e:
                out.append(e)
    return out


def tutti_gli_edifici(w, luoghi, villaggi):
    citta = edifici(w)
    return citta + edifici_fuori_citta(w, luoghi, villaggi, citta)


def chiave_edificio(e):
    return f"edificio_{e['tipo']}_{e['w']}x{e['h']}_{e['seed']}"


def esporta_edifici(w, luoghi, villaggi, temi):
    """Sprite degli edifici per tema (<tema>/oggetti/edificio_*.png), voce "edifici" e oggetti in mondo.json, e i
    sedimi come ostacolo in blocchi.png. Le tessere del terreno non cambiano. Gli oggetti di scena (alberi, rocce)
    che starebbero dentro una casa si tolgono."""
    lista = getattr(w, "edifici", None) or tutti_gli_edifici(w, luoghi, villaggi)
    w.edifici = lista
    sprite = {}
    for t in temi:
        tema.imposta(t)
        cart = os.path.join(OUT, t, "oggetti")
        os.makedirs(cart, exist_ok=True)
        for e in lista:
            k = chiave_edificio(e)
            img, ax, ay = object_sprite(e, T)
            Image.fromarray(img).save(os.path.join(cart, k + ".png"))
            sprite[k] = {"ax": int(ax), "ay": int(ay)}
        img, ax, ay = object_sprite({"type": "ingresso", "kind": "porta", "seed": 3}, T)   # porte nella roccia
        Image.fromarray(img).save(os.path.join(cart, "ingresso_porta.png"))
        sprite["ingresso_porta"] = {"ax": int(ax), "ay": int(ay)}
        print(f"  {t}: {len(sprite)} sprite di edifici")
    path = os.path.join(OUT, "mondo.json")
    dati = json.load(open(path))
    dentro = np.zeros(w.alt.shape, bool)
    for e in lista:
        dentro[e["y"]:e["y"] + e["h"] + 1, e["x"]:e["x"] + e["w"]] = True
    # gli oggetti si rifanno dal generatore (stessi di oggetti()), non da mondo.json: rilanciando, un albero tolto
    # da una casa che poi si sposta torna al suo posto
    dati["oggetti"] = [[chiave_oggetto(o), round(float(o["x"]), 3), round(float(o["y"]), 3)] for o in w.objects
                       if chiave_oggetto(o) in dati["sprite"]
                       and not dentro[min(int(o["y"]), B.H - 1), min(int(o["x"]), B.W - 1)]]
    dati["oggetti"] += [[chiave_edificio(e), e["x"] + e["w"] / 2, e["y"] + e["h"]] for e in lista]
    dati["sprite"] = {k: v for k, v in dati["sprite"].items() if not k.startswith("edificio_") and k != "ingresso_porta"}
    dati["sprite"].update(sprite)
    dati["edifici"] = [[e["x"], e["y"], e["w"], e["h"], e["tipo"]] for e in lista]
    dati["villaggi"] = {k: [int(v[0]), int(v[1])] for k, v in villaggi.items() if tuple(v) != (0, 0)}
    with open(path, "w") as f:
        json.dump(dati, f, separators=(",", ":"))
    Image.fromarray(blocchi(w)).save(os.path.join(OUT, "blocchi.png"))
    return lista


def esporta_varchi(temi):
    """US-8B21a: i varchi delle sotto-aree (forge3d.creatures.varco), chiusi e aperti, tra gli oggetti di ogni tema
    (<tema>/oggetti/varco_<aspetto>_<chiuso|aperto>.png) con le ancore in mondo.json "sprite". Dove stanno lo
    decidono i dati (regions.json gating[].varco) e mondo.gd crea_varchi()."""
    from forge3d.creatures import ASPETTI_VARCO
    sprite = {}
    for t in temi:
        tema.imposta(t)
        cart = os.path.join(OUT, t, "oggetti")
        for a in ASPETTI_VARCO:
            for stato, aperto in (("chiuso", False), ("aperto", True)):
                img, ax, ay = object_sprite({"type": "varco", "kind": a, "aperto": aperto, "seed": 1}, T)
                k = f"varco_{a}_{stato}"
                Image.fromarray(img).save(os.path.join(cart, k + ".png"))
                sprite[k] = {"ax": int(ax), "ay": int(ay)}
        print(f"  {t}: {len(sprite)} sprite di varchi")
    path = os.path.join(OUT, "mondo.json")
    dati = json.load(open(path))
    dati["sprite"] = {k: v for k, v in dati["sprite"].items() if not k.startswith("varco_")}
    dati["sprite"].update(sprite)
    with open(path, "w") as f:
        json.dump(dati, f, separators=(",", ":"))


def blocchi(w, senza_edifici=False):
    """Per casella: 255 = acqua o vuoto (non si passa mai), 128 = dislivello (non si passa a piedi, volando si'),
    0 = libera. Dislivello: le pareti senza scala o rampa e i bordi alti dei gradoni verso est, ovest e nord (si
    sale e si scende solo dalle pareti a sud, con scale e rampe). Strade e sentieri attraversano i dislivelli solo
    dentro una stessa regione: al confine (il Passo tra le Rupi, sotto le Marche) il salto resta.
    2026-10-25: il vicino "a nord" era quello a sud (sposta(alt, -1, 0) e' la casella sotto): bloccava la fila in
    cima a ogni scala e lasciava aperti i bordi nord."""
    alt = w.alt
    faccia = maschera_pareti(alt, w.mat_par)
    salto = faccia & (w.pas == ".")
    for sy, sx in ((0, 1), (0, -1), (1, 0)):                  # vicino a ovest, est, nord piu' basso
        vic = B.sposta(alt, sy, sx, -99)
        salto |= (vic < alt) & (vic != -99) & ~faccia
    strada = np.zeros(alt.shape, bool)
    for s in list(w.roads) + list(w.sentieri):
        for x, y in s:
            strada[y, x] = True
    stessa = np.ones(alt.shape, bool)                          # tutti e 4 i vicini nella regione della casella
    for sy, sx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        stessa &= B.sposta(w.biome, sy, sx, -1) == w.biome
    salto &= ~(strada & stessa)
    if not senza_edifici:                                      # US-8B18: il sedime di un edificio non si passa
        for e in getattr(w, "edifici", None) or edifici(w):
            salto[e["y"]:e["y"] + e["h"], e["x"]:e["x"] + e["w"]] = True
    out = np.where(salto, DISLIVELLO, 0).astype(np.uint8)
    out[w.water_mask] = ACQUA
    return out


def blocchi_sotto(sotto):
    """Sottosuolo: 255 = roccia o acqua (canali delle fogne, laghi delle grotte), 128 = faccia di roccia senza scala,
    0 = libera. Niente salti di lato: il cordolo dei canali e' camminamento, non un gradone."""
    g = sotto["ground"]
    acque = np.isin(g, [B.L[k] for k in ("water", "deep_water", "acqua_fogna", "acqua_grotta") if k in B.L])
    out = np.zeros(g.shape, np.uint8)
    out[maschera_pareti(sotto["alt"]) & (sotto["pas"] == ".")] = DISLIVELLO
    out[~sotto["pavimento"] | acque] = ACQUA
    return out


INGRESSO_DI_ZONA = {"fogne": "botola"}          # le altre zone: "scale"; sotto, sempre "risalita"


def salva_fogli(tess, cart):
    per_foglio = COL * RIG
    n = (len(tess) + per_foglio - 1) // per_foglio
    for f in range(n):
        parte = tess[f * per_foglio:(f + 1) * per_foglio]
        righe = (len(parte) + COL - 1) // COL
        img = np.zeros((righe * T, COL * T, 4), np.uint8)
        for i, tl in enumerate(parte):
            img[(i // COL) * T:(i // COL + 1) * T, (i % COL) * T:(i % COL + 1) * T] = tl
        Image.fromarray(img).save(os.path.join(cart, f"tessere_{f}.png"), optimize=True)
    return n


def salva_indici(ind, cart):
    rgb = np.zeros((B.H, B.W, 3), np.uint8)
    rgb[..., 0], rgb[..., 1] = ind & 255, ind >> 8
    Image.fromarray(rgb).save(os.path.join(cart, "indici.png"))


def esporta_sottosuolo(w, sotto, temi, seed):
    """Il sottosuolo come secondo livello (stessa griglia: un ingresso ha le stesse coordinate sopra e sotto):
    assets/world/sotto/blocchi.png, <tema>/sotto/{tessere_<k>,indici}.png, gli sprite degli ingressi e la voce
    "sottosuolo" di mondo.json (fogli per tema, ingressi con la loro zona, boss di zona)."""
    os.makedirs(os.path.join(OUT, "sotto"), exist_ok=True)
    Image.fromarray(blocchi_sotto(sotto)).save(os.path.join(OUT, "sotto", "blocchi.png"))
    ws = B.World(B.W, B.H, seed, sotto["ground"], w.biome, w.elev, B.REGIONI, water_mask=None)
    mat = np.full((B.H, B.W), "roccia", object)
    fogli, sprite = {}, {}
    for t in temi:
        tema.imposta(t)
        print("sottosuolo", t)
        cart = os.path.join(OUT, t, "sotto")
        os.makedirs(cart, exist_ok=True)
        tess, ind = tessere(ws, sotto["alt"], mat, sotto["pas"], pieno=~sotto["pavimento"])
        fogli[t] = salva_fogli(tess, cart)
        salva_indici(ind, cart)
        cart_ogg = os.path.join(OUT, t, "oggetti")
        os.makedirs(cart_ogg, exist_ok=True)
        for kind in ("botola", "scale", "risalita"):
            img, ax, ay = object_sprite({"type": "ingresso", "kind": kind, "seed": 3}, T)
            Image.fromarray(img).save(os.path.join(cart_ogg, f"ingresso_{kind}.png"))
            sprite[f"ingresso_{kind}"] = {"ax": int(ax), "ay": int(ay)}
        print(f"  {len(tess)} tessere in {fogli[t]} fogli")
    path = os.path.join(OUT, "mondo.json")
    dati = json.load(open(path))
    vecchi = (dati.get("sottosuolo") or {}).get("fogli", {})
    ingressi = {k: [int(x), int(y), k.rsplit("_", 1)[0]] for k, (x, y) in sotto["ingressi"].items()}
    dati["sottosuolo"] = {"fogli": {**vecchi, **fogli}, "ingressi": ingressi,
                          "boss": {k: [int(x), int(y)] for k, (x, y) in sotto["boss"].items()},
                          "sprite_ingresso": {z: INGRESSO_DI_ZONA.get(z, "scale") for z in
                                              sorted({v[2] for v in ingressi.values()})}}
    dati["sprite"].update(sprite)
    with open(path, "w") as f:
        json.dump(dati, f, separators=(",", ":"))


def riquadri(regioni_png):
    """Riquadro [x0, y0, x1, y1] (x1, y1 esclusi) di ogni regione su regioni.png: il gioco ci riporta il contenuto
    dei layout della fase 10 (nemici e oggetti nella stessa posizione relativa)."""
    reg = np.array(Image.open(regioni_png))
    out = {}
    for i, nome in enumerate(B.REGIONI):
        ys, xs = np.nonzero(reg == i)
        if len(xs):
            out[nome] = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
    return out


def aggiorna_dati():
    """Solo i dati ricavati da regioni.png (riquadri): niente generazione, pochi secondi."""
    path = os.path.join(OUT, "mondo.json")
    dati = json.load(open(path))
    dati["riquadri"] = riquadri(os.path.join(OUT, "regioni.png"))
    with open(path, "w") as f:
        json.dump(dati, f, separators=(",", ":"))


def chiave_oggetto(o):
    return "_".join(str(o.get(k)) for k in ("type", "kind", "leaf", "mat", "berries", "seed", "size")
                    if o.get(k) is not None).replace(".", "p")


def oggetti(w, cartella):
    os.makedirs(cartella, exist_ok=True)
    sprite, lista = {}, []
    for o in w.objects:
        spr = object_sprite(o, T)
        if spr is None:
            continue
        chiave = chiave_oggetto(o)
        if chiave not in sprite:
            img, ax, ay = spr
            Image.fromarray(img).save(os.path.join(cartella, chiave + ".png"))
            sprite[chiave] = {"ax": int(ax), "ay": int(ay)}
        lista.append([chiave, round(float(o["x"]), 3), round(float(o["y"]), 3)])
    return sprite, lista


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--tema", choices=["luminoso", "cupo"])
    ap.add_argument("--seed", type=int, default=6)
    ap.add_argument("--solo-blocchi", action="store_true", help="riscrive solo blocchi.png (le collisioni)")
    ap.add_argument("--sottosuolo", action="store_true", help="solo il sottosuolo (secondo livello)")
    ap.add_argument("--solo-dati", action="store_true", help="solo i dati ricavati da regioni.png (riquadri)")
    ap.add_argument("--edifici", action="store_true", help="solo gli edifici della citta' (sprite, dati, collisioni)")
    ap.add_argument("--varchi", action="store_true", help="solo i disegni dei varchi delle sotto-aree (pochi secondi)")
    a = ap.parse_args()
    if a.varchi:
        esporta_varchi([a.tema] if a.tema else ["luminoso", "cupo"])
        print("->", os.path.join(OUT, "mondo.json"))
        return
    if a.solo_dati:
        aggiorna_dati()
        print("->", os.path.join(OUT, "mondo.json"))
        return
    w, luoghi, villaggi, sotto = B.genera(a.seed)
    w.edifici = tutti_gli_edifici(w, luoghi, villaggi)          # US-8B18: servono anche alle collisioni
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(blocchi(w)).save(os.path.join(OUT, "blocchi.png"))
    if a.solo_blocchi:
        print("->", os.path.join(OUT, "blocchi.png"))
        return
    if a.sottosuolo:
        esporta_sottosuolo(w, sotto, [a.tema] if a.tema else ["luminoso", "cupo"], a.seed)
        print("->", OUT)
        return
    if a.edifici:
        lista = esporta_edifici(w, luoghi, villaggi, [a.tema] if a.tema else ["luminoso", "cupo"])
        print(f"-> {len(lista)} edifici in", OUT)
        return
    Image.fromarray(w.biome.astype(np.uint8)).save(os.path.join(OUT, "regioni.png"))
    fogli, sprite, lista = {}, {}, []
    for t in ([a.tema] if a.tema else ["luminoso", "cupo"]):
        tema.imposta(t)
        print(t)
        cart = os.path.join(OUT, t)
        os.makedirs(cart, exist_ok=True)
        tess, ind = tessere(w)
        fogli[t] = salva_fogli(tess, cart)
        salva_indici(ind, cart)
        sprite, lista = oggetti(w, os.path.join(cart, "oggetti"))
        print(f"  {len(tess)} tessere in {fogli[t]} fogli, {len(sprite)} sprite, {len(lista)} oggetti")
    dati = {"seed": a.seed, "larghezza": B.W, "altezza": B.H, "tile": T, "colonne_foglio": COL, "righe_foglio": RIG,
            "fogli": fogli, "partenza": luoghi["casa_base_porto"], "regioni": B.REGIONI,
            "riquadri": riquadri(os.path.join(OUT, "regioni.png")),
            "luoghi": {k: list(v) for k, v in luoghi.items()}, "sprite": sprite, "oggetti": lista}
    vecchio = os.path.join(OUT, "mondo.json")
    if os.path.exists(vecchio):
        prima = json.load(open(vecchio))
        if a.tema:                                               # un tema solo: tieni i fogli dell'altro
            dati["fogli"] = {**prima.get("fogli", {}), **fogli}
        if "sottosuolo" in prima:                                # il sottosuolo si esporta a parte (--sottosuolo)
            dati["sottosuolo"] = prima["sottosuolo"]
            dati["sprite"].update({k: v for k, v in prima.get("sprite", {}).items() if k.startswith("ingresso_")})
    with open(vecchio, "w") as f:
        json.dump(dati, f, separators=(",", ":"))
    esporta_edifici(w, luoghi, villaggi, [a.tema] if a.tema else ["luminoso", "cupo"])
    esporta_varchi([a.tema] if a.tema else ["luminoso", "cupo"])
    print("->", OUT)


if __name__ == "__main__":
    main()
