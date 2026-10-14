#!/usr/bin/env python3
"""
Rigenera tutta l'arte vera in assets/placeholder/ (CLAUDE.md v2, "Comandi").

    python tools/art/generate_all.py                      # tutte le categorie
    python tools/art/generate_all.py --only personaggio   # una sola
    python tools/art/generate_all.py --skill <cartella sprite-forge>

- personaggio: generato da tools/art/build_enel.py (deterministico, nessun seed:
  ogni frame e' una posa scritta nello script).
- nemico_base, pet: fogli sorgente in arte/sprite/<categoria>_<nome>.png,
  copiati tali e quali. Unica trasformazione: nei frame dello stato che fa da
  tell (nemico_base.anticipo) il contorno esterno diventa rosso, cosi' il tell
  si legge anche in un frame fermo (CLAUDE.md, "Animazione").

Il numero di frame, le direzioni e la dimensione del frame vengono da
data/animations.json: un foglio con la geometria sbagliata fa fallire lo script
invece di finire nel gioco.

US-8B01 (64 px): un foglio disegnato a meta' dimensione (32 px) viene ingrandito
x2 senza sfumare, cosi' il gioco funziona subito a 64. E' un ripiego: i fogli
veri a 64 arrivano con il Blocco C del PRD 8b, che li ridisegna.
"""

import argparse
import glob
import json
import os
import subprocess
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SORGENTI = os.path.join(ROOT, "arte", "sprite")
DEST = os.path.join(ROOT, "assets", "placeholder")
DIM = 64                                  # sovrascritta in main() da data/animations.json
ROSSO_TELL = (0xE4, 0x3B, 0x44, 255)      # Endesga 32
STATI_TELL = {"nemico_base": ["anticipo"]}


def trova_skill():
    if os.environ.get("SPRITE_FORGE"):
        return os.environ["SPRITE_FORGE"]
    trovate = glob.glob(os.path.expanduser("~/.claude/skills/**/sprite-forge"), recursive=True)
    return trovate[0] if trovate else None


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


def ingrandisci_in_assets(cat, spec):
    """Porta a DIM i fogli gia' in assets/ (personaggio: li scrive build_enel.py)."""
    for nome, a in spec.items():
        if nome.startswith("_"):
            continue
        path = os.path.join(DEST, f"{cat}_{nome}.png")
        a_dimensione(Image.open(path).convert("RGBA"), a, path).save(path)


def copia_categoria(cat, spec):
    for nome, a in spec.items():
        if nome.startswith("_"):
            continue
        src = os.path.join(SORGENTI, f"{cat}_{nome}.png")
        im = Image.open(src).convert("RGBA")
        if nome in STATI_TELL.get(cat, []):               # prima di ingrandire: il bordo resta largo come il contorno
            im = contorno_tell(im, im.size[0] // int(a["frames"]))
        im = a_dimensione(im, a, src)
        atteso = (DIM * int(a["frames"]), DIM * (4 if a.get("direzionale") else 1))
        if im.size != atteso:
            sys.exit(f"{src}: {im.size}, atteso {atteso} da data/animations.json")
        im.save(os.path.join(DEST, f"{cat}_{nome}.png"))
        print(f"  {cat}_{nome}.png")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--only", choices=["personaggio", "nemico_base", "pet"])
    ap.add_argument("--skill", help="cartella della skill sprite-forge (default: la trova da sola)")
    a = ap.parse_args()
    with open(os.path.join(ROOT, "data", "animations.json"), encoding="utf-8") as fh:
        specs = json.load(fh)

    global DIM
    DIM = int(specs["convenzioni"]["dimensione_frame"][0])
    for cat in ("personaggio", "nemico_base", "pet"):
        if a.only and a.only != cat:
            continue
        print(cat)
        if cat == "personaggio":
            skill = a.skill or trova_skill()
            if skill:
                subprocess.run([sys.executable, os.path.join(ROOT, "tools", "art", "build_enel.py"),
                                "--skill", skill], check=True)
            else:
                print("  skill sprite-forge non trovata: uso i fogli gia' in assets/ (passa --skill per ridisegnarli)")
            ingrandisci_in_assets(cat, specs[cat])
        else:
            copia_categoria(cat, specs[cat])


if __name__ == "__main__":
    main()
