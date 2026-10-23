#!/usr/bin/env python3
"""
Esporta il mondo di prova (seed 6) per il gioco (US-8B12): Godot carica questi file con scripts/world/mondo.gd.

    python tools/art/esporta_mondo.py                 # tutte e due le modalita' (luminoso + cupo)
    python tools/art/esporta_mondo.py --tema cupo     # una sola

Il terreno con pareti, bordi e varianti si compone qui in Python, a blocchi, esattamente come le anteprime
(build_world.ritaglio); poi si tengono solo le caselle 32x32 diverse (34 mila su 1,2 milioni): fogli-atlante + una
mappa di indici. Il gioco costruisce solo il pezzo attorno al giocatore. Gli oggetti (alberi, rocce, trono...) sono
sprite a parte, ordinati per profondita' nel gioco. L'acqua per ora e' ferma (frame 0).

assets/world/
    mondo.json              dati comuni ai due temi: misure, tile, partenza, luoghi, fogli, oggetti
    blocchi.png             1 px per casella: 255 = non si passa (acqua, vuoto, pareti, salti di lato)
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


def tessere(w):
    """Compone il mondo a blocchi e tiene le tessere diverse. -> (lista di tessere, indici H x W)."""
    atl = {n: B.build_atlas(n, T) for n in B.ORDER}
    viste, lista = {}, []
    indici = np.zeros((B.H, B.W), np.int32)
    for by in range(0, B.H, BLOCCO):
        for bx in range(0, B.W, BLOCCO):
            x1, y1 = min(B.W, bx + BLOCCO), min(B.H, by + BLOCCO)
            img = B.ritaglio(w, (bx, by, x1, y1), w.alt, w.mat_par, w.pas, atl, oggetti=False)
            hh, ww = y1 - by, x1 - bx
            t4 = img.reshape(hh, T, ww, T, 4).swapaxes(1, 2)
            for i in range(hh):
                for j in range(ww):
                    k = hashlib.md5(t4[i, j].tobytes()).digest()
                    if k not in viste:
                        viste[k] = len(lista)
                        lista.append(t4[i, j].copy())
                    indici[by + i, bx + j] = viste[k]
        print(f"  righe {by}-{min(B.H, by + BLOCCO)}: {len(lista)} tessere")
    return lista, indici


def blocchi(w):
    """255 = non si passa: acqua e vuoto, pareti senza scala o rampa, e i salti di lato o verso nord (il bordo alto
    di un gradone: si sale e si scende solo dalle pareti a sud, con scale e rampe)."""
    alt = w.alt
    faccia = maschera_pareti(alt, w.mat_par)
    b = w.water_mask.copy() | (faccia & (w.pas == "."))
    for sy, sx in ((0, 1), (0, -1), (-1, 0)):                 # vicino a est, ovest, nord piu' basso
        vic = B.sposta(alt, sy, sx, -99)
        b |= (vic < alt) & (vic != -99) & ~faccia
    return np.where(b, 255, 0).astype(np.uint8)


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
    a = ap.parse_args()
    w, luoghi, villaggi, sotto = B.genera(a.seed)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(blocchi(w)).save(os.path.join(OUT, "blocchi.png"))
    Image.fromarray(w.biome.astype(np.uint8)).save(os.path.join(OUT, "regioni.png"))
    fogli, sprite, lista = {}, {}, []
    for t in ([a.tema] if a.tema else ["luminoso", "cupo"]):
        tema.imposta(t)
        print(t)
        cart = os.path.join(OUT, t)
        os.makedirs(cart, exist_ok=True)
        tess, ind = tessere(w)
        per_foglio = COL * RIG
        fogli[t] = (len(tess) + per_foglio - 1) // per_foglio
        for f in range(fogli[t]):
            parte = tess[f * per_foglio:(f + 1) * per_foglio]
            righe = (len(parte) + COL - 1) // COL
            img = np.zeros((righe * T, COL * T, 4), np.uint8)
            for i, tl in enumerate(parte):
                img[(i // COL) * T:(i // COL + 1) * T, (i % COL) * T:(i % COL + 1) * T] = tl
            Image.fromarray(img).save(os.path.join(cart, f"tessere_{f}.png"), optimize=True)
        rgb = np.zeros((B.H, B.W, 3), np.uint8)
        rgb[..., 0], rgb[..., 1] = ind & 255, ind >> 8
        Image.fromarray(rgb).save(os.path.join(cart, "indici.png"))
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
