#!/usr/bin/env python3
"""
Rigenera tutta l'arte vera in assets/placeholder/ (CLAUDE.md v2, "Comandi").

    python tools/art/generate_all.py                      # tutte le categorie
    python tools/art/generate_all.py --only personaggio   # una sola
    python tools/art/build_personaggi.py                  # prima: ridisegna i fogli sorgente

- personaggio, nemico_base, pet: fogli sorgente in arte/sprite/<categoria>_<nome>.png (pet: pet_<specie>_<nome>.png,
  una specie per voce di data/pets), generati da
  tools/art/build_personaggi.py (a 64 px, motore 3D di forge3d, stessa luce per tutti) e copiati tali e
  quali. Unica trasformazione: nei frame dello stato che fa da tell (nemico_base.anticipo) il contorno
  esterno diventa rosso, cosi' il tell si legge anche in un frame fermo (CLAUDE.md, "Animazione").

Il numero di frame, le direzioni e la dimensione del frame vengono da
data/animations.json: un foglio con la geometria sbagliata fa fallire lo script
invece di finire nel gioco.

Un foglio disegnato a meta' dimensione (32 px) verrebbe ingrandito x2 senza sfumare (ripiego di
US-8B01): dal Blocco C del PRD 8b tutti i fogli sono gia' a 64.
"""

import argparse
import json
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SORGENTI = os.path.join(ROOT, "arte", "sprite")
DEST = os.path.join(ROOT, "assets", "placeholder")
DIM = 64                                  # sovrascritta in main() da data/animations.json
ROSSO_TELL = (0xE4, 0x3B, 0x44, 255)      # Endesga 32
STATI_TELL = {"nemico_base": ["anticipo"]}


def contorno_tell(im, cella):
    """Contorno esterno (pixel scuri pieni che toccano il vuoto) -> rosso."""
    px = im.load()
    w, h = im.size
    da_colorare = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 255 or r + g + b > 150:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                X, Y = x + dx, y + dy
                # vuoto = fuori dall'immagine, fuori dalla propria cella (frame),
                # o pixel non pieno (trasparente o l'ombra a terra)
                if not (0 <= X < w and 0 <= Y < h) or (X // cella, Y // cella) != (x // cella, y // cella) \
                        or px[X, Y][3] < 255:
                    da_colorare.append((x, y))
                    break
    for x, y in da_colorare:
        px[x, y] = ROSSO_TELL
    return im


def a_dimensione(im, a, nome):
    """Foglio a meta' dimensione (32 px) -> x2 senza sfumare. Ripiego fino al Blocco C."""
    atteso = (DIM * int(a["frames"]), DIM * (4 if a.get("direzionale") else 1))
    if im.size == (atteso[0] // 2, atteso[1] // 2):
        print(f"    {os.path.basename(nome)}: disegnato a {DIM // 2} px, ingrandito x2 (da ridisegnare a {DIM})")
        return im.resize(atteso, Image.NEAREST)
    return im


def copia_categoria(cat, spec, aspetto=""):
    pre = f"{cat}_{aspetto}_" if aspetto else f"{cat}_"
    for nome, a in spec.items():
        if nome.startswith("_"):
            continue
        src = os.path.join(SORGENTI, f"{pre}{nome}.png")
        im = Image.open(src).convert("RGBA")
        if nome in STATI_TELL.get(cat, []):               # prima di ingrandire: il bordo resta largo come il contorno
            im = contorno_tell(im, im.size[0] // int(a["frames"]))
        im = a_dimensione(im, a, src)
        atteso = (DIM * int(a["frames"]), DIM * (4 if a.get("direzionale") else 1))
        if im.size != atteso:
            sys.exit(f"{src}: {im.size}, atteso {atteso} da data/animations.json")
        im.save(os.path.join(DEST, f"{pre}{nome}.png"))
        print(f"  {pre}{nome}.png")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--only", choices=["personaggio", "nemico_base", "pet"])
    a = ap.parse_args()
    with open(os.path.join(ROOT, "data", "animations.json"), encoding="utf-8") as fh:
        specs = json.load(fh)

    global DIM
    DIM = int(specs["convenzioni"]["dimensione_frame"][0])
    for cat in ("personaggio", "nemico_base", "pet"):
        if a.only and a.only != cat:
            continue
        print(cat)
        if cat != "pet":
            copia_categoria(cat, specs[cat])
            continue
        # pet: un foglio per specie di data/pets (pet_<id>_<nome>.png), stessi tempi per tutte
        with open(os.path.join(ROOT, "data", "pets", "core.json"), encoding="utf-8") as fh:
            specie = [p["id"] for p in json.load(fh)["pets"]]
        for sp in specie:
            if not os.path.exists(os.path.join(SORGENTI, f"pet_{sp}_idle.png")):
                print(f"  {sp}: nessun foglio in arte/sprite/ (resta il segnaposto pet_<nome>.png)")
                continue
            copia_categoria(cat, specs[cat], sp)


if __name__ == "__main__":
    main()
