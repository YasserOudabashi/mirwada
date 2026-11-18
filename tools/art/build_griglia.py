#!/usr/bin/env python3
"""Figure a griglia (scelte artistiche del 2026-11-18): pixel art su scheletro, una figura per file in griglia/figure/.

    python tools/art/build_griglia.py                       # tutte le figure a griglia
    python tools/art/build_griglia.py --only personaggio
    python tools/art/build_griglia.py --effetti             # effetti unici -> assets/vfx/
    python tools/art/generate_all.py --only personaggio     # poi in assets/ (con il tell del nemico)

Scrive arte/sprite/<categoria>[_<aspetto>]_<anim>.png (frame in colonne, direzioni in righe down, up, left, right)
e un foglio di controllo ingrandito in arte/revisione/griglia_<id>.png. Frame, tempi e loop da data/animations.json;
le pose dalle chiavi della figura. Niente caso: stessi file, stessi PNG.
"""
import argparse
import importlib
import json
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from griglia.corpo import DIREZIONI, Vista  # noqa: E402
from griglia.pixel import Tela, foglio  # noqa: E402
from griglia.pose import frame  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "arte", "sprite")
REV = os.path.join(ROOT, "arte", "revisione")
PROVA = os.path.join(ROOT, "arte", "prova")          # versioni da scegliere: non vanno nel gioco

# id -> (modulo in griglia/figure, categoria di animations.json, aspetto: "" per il foglio base della categoria)
FIGURE = {
    "personaggio": ("personaggio", "personaggio", ""),
    "lupo_della_luna": ("lupo_della_luna", "nemico_base", "lupo_della_luna"),
}


def rendi(mod, posa, direzione, lato):
    if "per_vista" in posa:                      # valori diversi per direzione (chi e' sdraiato resta nella cella)
        posa = {**posa, **posa["per_vista"].get(direzione, {})}
    t = Tela(lato, lato)
    v = Vista(direzione, cx=lato / 2, piedi=getattr(mod, "PIEDI", 54) * lato / 64)
    g = mod.CORPO.giunture(posa)
    mod.disegna(t, v, g, posa)
    t.contorno()
    im = t.immagine()
    if posa.get("scia"):                         # copie scure dietro (la schivata "ombra"): sagome piene, sotto
        fondo = Image.new("RGBA", im.size)
        for k in range(int(posa["scia"]), 0, -1):
            p2 = dict(posa, scia=0, avanti=posa.get("avanti", 0) - 7 * k)
            sag = rendi(mod, p2, direzione, lato).split()[3]
            col = ((104, 56, 108, 255), (58, 68, 102, 255), (38, 43, 68, 255))[min(k - 1, 2)]   # viola, poi blu
            fondo.paste(Image.new("RGBA", im.size, col), (0, 0), sag)
        fondo.alpha_composite(im)
        im = fondo
    return im


def costruisci(fid, spec):
    nome_mod, cat, asp = FIGURE[fid]
    mod = importlib.import_module(f"griglia.figure.{nome_mod}")
    lato = getattr(mod, "CELLA", 64)
    pre = f"{cat}_{asp}_" if asp else f"{cat}_"
    fogli = []
    for nome, a in spec[cat].items():
        if not isinstance(a, dict) or "frames" not in a:
            continue
        if nome not in mod.ANIM:
            sys.exit(f"{fid}: manca l'animazione {nome} in griglia/figure/{nome_mod}.py")
        an = mod.ANIM[nome]
        base = {k: v for k, v in an.items() if k not in ("chiavi", "vista")}
        n = int(a["frames"])
        pose = frame(an["chiavi"], n, bool(a.get("loop")), base)
        righe = DIREZIONI if a.get("direzionale") else (an.get("vista", "down"),)
        im = foglio([[rendi(mod, p, d, lato) for p in pose] for d in righe], n)
        os.makedirs(OUT, exist_ok=True)
        im.save(os.path.join(OUT, f"{pre}{nome}.png"))
        fogli.append((nome, im))
        print(f"  {pre}{nome}.png  {n} frame x {len(righe)}")
    for anim, vv in getattr(mod, "VARIANTI", {}).items():   # versioni da scegliere -> arte/prova/
        a = spec[cat][anim]
        n = int(a["frames"])
        for vid, an in vv.items():
            pose = frame(an["chiavi"], n, bool(a.get("loop")), {})
            righe = DIREZIONI if a.get("direzionale") else (an.get("vista", "down"),)
            im = foglio([[rendi(mod, p, d, lato) for p in pose] for d in righe], n)
            os.makedirs(PROVA, exist_ok=True)
            im.save(os.path.join(PROVA, f"{pre}{anim}_{vid}.png"))
            fogli.append((f"{anim} ({vid})", im))
            print(f"  prova: {pre}{anim}_{vid}.png")
    controllo(fid, fogli, lato)


def controllo(fid, fogli, lato, k=3):
    """Tutte le animazioni una sotto l'altra, x3, su fondo chiaro a sinistra e scuro a destra."""
    w = max(im.width for _, im in fogli)
    h = sum(im.height + 10 for _, im in fogli)
    out = Image.new("RGBA", (w * 2 * k + 20, h * k), (0, 0, 0, 255))
    dr = ImageDraw.Draw(out)
    y = 0
    for nome, im in fogli:
        big = im.resize((im.width * k, im.height * k), Image.NEAREST)
        for i, fondo in enumerate(((200, 208, 186, 255), (38, 43, 68, 255))):
            x0 = i * (w * k + 20)
            dr.rectangle([x0, y, x0 + big.width - 1, y + big.height + 10 * k - 1], fill=fondo)
            out.alpha_composite(big, (x0, y + 10 * k))
        dr.text((4, y + 2), nome, fill=(0, 0, 0, 255))
        y += big.height + 10 * k
    os.makedirs(REV, exist_ok=True)
    out.save(os.path.join(REV, f"griglia_{fid}.png"))


def effetti():
    """Gli effetti unici a 4 grigi -> assets/vfx/<nome>.png (frame in colonne, una riga)."""
    from griglia.effetti import EFFETTI
    dest = os.path.join(ROOT, "assets", "vfx")
    for nome, (f, n) in EFFETTI.items():
        fr = f(n)
        im = foglio([fr], n)
        im.save(os.path.join(dest, f"{nome}.png"))
        print(f"  {nome}.png  {n} frame {fr[0].width}x{fr[0].height}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--only", choices=sorted(FIGURE))
    ap.add_argument("--effetti", action="store_true", help="solo gli effetti (griglia/effetti.py)")
    a = ap.parse_args()
    if a.effetti:
        effetti()
        return
    with open(os.path.join(ROOT, "data", "animations.json"), encoding="utf-8") as fh:
        spec = json.load(fh)
    for fid in FIGURE:
        if a.only and fid != a.only:
            continue
        if not os.path.isfile(os.path.join(HERE, "griglia", "figure", f"{FIGURE[fid][0]}.py")):
            continue
        print(fid)
        costruisci(fid, spec)


if __name__ == "__main__":
    main()
