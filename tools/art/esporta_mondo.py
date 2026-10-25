#!/usr/bin/env python3
"""
Esporta il mondo di prova (seed 6) per il gioco (US-8B12): Godot carica questi file con scripts/world/mondo.gd.

    python tools/art/esporta_mondo.py                 # tutte e due le modalita' (luminoso + cupo)
    python tools/art/esporta_mondo.py --tema cupo     # una sola
    python tools/art/esporta_mondo.py --solo-blocchi  # solo le collisioni (blocchi.png), pochi minuti
    python tools/art/esporta_mondo.py --sottosuolo    # solo il sottosuolo (secondo livello), luminoso e cupo

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


def blocchi(w):
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


def oggetti(w, cartella):
    os.makedirs(cartella, exist_ok=True)
    sprite, lista = {}, []
    for o in w.objects:
        spr = object_sprite(o, T)
        if spr is None:
            continue
        chiave = "_".join(str(o.get(k)) for k in ("type", "kind", "leaf", "mat", "berries", "seed", "size")
                          if o.get(k) is not None).replace(".", "p")
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
    a = ap.parse_args()
    w, luoghi, villaggi, sotto = B.genera(a.seed)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(blocchi(w)).save(os.path.join(OUT, "blocchi.png"))
    if a.solo_blocchi:
        print("->", os.path.join(OUT, "blocchi.png"))
        return
    if a.sottosuolo:
        esporta_sottosuolo(w, sotto, [a.tema] if a.tema else ["luminoso", "cupo"], a.seed)
        print("->", OUT)
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
            "luoghi": {k: list(v) for k, v in luoghi.items()}, "sprite": sprite, "oggetti": lista}
    vecchio = os.path.join(OUT, "mondo.json")
    if a.tema and os.path.exists(vecchio):                       # un tema solo: tieni i fogli dell'altro
        dati["fogli"] = {**json.load(open(vecchio)).get("fogli", {}), **fogli}
    with open(vecchio, "w") as f:
        json.dump(dati, f, separators=(",", ":"))
    print("->", OUT)


if __name__ == "__main__":
    main()
