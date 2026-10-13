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

Il numero di frame e le direzioni vengono da data/animations.json: un foglio
con la geometria sbagliata fa fallire lo script invece di finire nel gioco.
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
DIM = 32
ROSSO_TELL = (0xE4, 0x3B, 0x44, 255)      # Endesga 32
STATI_TELL = {"nemico_base": ["anticipo"]}


def trova_skill():
    if os.environ.get("SPRITE_FORGE"):
        return os.environ["SPRITE_FORGE"]
    trovate = glob.glob(os.path.expanduser("~/.claude/skills/**/sprite-forge"), recursive=True)
    return trovate[0] if trovate else None


def contorno_tell(im):
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
                # vuoto = fuori dall'immagine, fuori dalla propria cella da 32 px,
                # o pixel non pieno (trasparente o l'ombra a terra)
                if not (0 <= X < w and 0 <= Y < h) or (X // DIM, Y // DIM) != (x // DIM, y // DIM) \
                        or px[X, Y][3] < 255:
                    da_colorare.append((x, y))
                    break
    for x, y in da_colorare:
        px[x, y] = ROSSO_TELL
    return im


def copia_categoria(cat, spec):
    for nome, a in spec.items():
        if nome.startswith("_"):
            continue
        src = os.path.join(SORGENTI, f"{cat}_{nome}.png")
        im = Image.open(src).convert("RGBA")
        atteso = (DIM * int(a["frames"]), DIM * (4 if a.get("direzionale") else 1))
        if im.size != atteso:
            sys.exit(f"{src}: {im.size}, atteso {atteso} da data/animations.json")
        if nome in STATI_TELL.get(cat, []):
            im = contorno_tell(im)
        im.save(os.path.join(DEST, f"{cat}_{nome}.png"))
        print(f"  {cat}_{nome}.png")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--only", choices=["personaggio", "nemico_base", "pet"])
    ap.add_argument("--skill", help="cartella della skill sprite-forge (default: la trova da sola)")
    a = ap.parse_args()
    with open(os.path.join(ROOT, "data", "animations.json"), encoding="utf-8") as fh:
        specs = json.load(fh)

    for cat in ("personaggio", "nemico_base", "pet"):
        if a.only and a.only != cat:
            continue
        print(cat)
        if cat == "personaggio":
            skill = a.skill or trova_skill()
            if not skill:
                sys.exit("skill sprite-forge non trovata: passa --skill o imposta SPRITE_FORGE")
            subprocess.run([sys.executable, os.path.join(ROOT, "tools", "art", "build_enel.py"),
                            "--skill", skill], check=True)
        else:
            copia_categoria(cat, specs[cat])


if __name__ == "__main__":
    main()
