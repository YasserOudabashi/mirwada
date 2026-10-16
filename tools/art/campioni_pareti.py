#!/usr/bin/env python3
"""
Tavola di prova delle pareti (revisione arte 3.2, parte 1): per guardarle prima di metterle nel mondo.

    python tools/art/campioni_pareti.py            # a 64 px

Esce arte/pareti/scena_<materiale>.png (a dimensione vera) e arte/pareti/campioni.png (tutte, x2,
su sfondo chiaro e scuro). Ogni scena: numeri = altezza della casella, S = scalini, R = rampa.
"""

import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from forge3d import terrain as T  # noqa: E402
from forge3d.pareti import disegna, strati, terreno_sotto  # noqa: E402

OUT = os.path.join(HERE, "..", "..", "arte", "pareti")

# Altezze a lettere (una riga = una riga di caselle). Le caselle di parete sono le prime sotto un bordo:
# 'S'/'R' su una di esse la trasforma in scalini o rampa (l'altezza e' quella della casella sotto).
FORMA = ("2222222222222222",
         "2222222222222222",
         "1111111S11111111",
         "1111111111111111",
         "1111111111111111",
         "00000R000000z000",
         "000000000000z000",
         "0000000000000000")
SCENE = [
    ("arenaria", "Marche: gradoni di arenaria su pietrisco", ["pietrisco", "pietrisco", "erica_secca"]),
    ("roccia", "rupi e sottosuolo: roccia su terra", ["dirt", "pietrisco", "pietrisco"]),
    ("mura", "mura di Mirwada: selciato dentro, erba fuori", ["grass", "lastricato_antico", "lastre_chiare"]),
]


def leggi(forma):
    alt, pas = [], []
    for riga in forma:
        a, p = [], []
        for i, c in enumerate(riga):
            if c.isdigit():
                a.append(int(c)); p.append(".")
            elif c == "z":                                   # muro isolato alto 1 (parete di 1 casella di larghezza)
                a.append(1); p.append(".")
            else:                                            # S/R: casella di parete col passaggio
                a.append(int(riga[i - 1]) if riga[i - 1].isdigit() else 1); p.append(c)
        alt.append(a); pas.append(p)
    alt = np.array(alt)
    # le caselle di passaggio hanno l'altezza della casella sotto il bordo (sono parete)
    for y in range(len(forma)):
        for x, c in enumerate(forma[y]):
            if c in "SR":
                alt[y, x] = alt[y + 1, x] if y + 1 < len(forma) else 0
    return alt, pas


def scena(mat, terreni, S=64):
    alt, pas = leggi(FORMA)
    ground = np.vectorize(lambda h: T.ORDER.index(terreni[min(h, len(terreni) - 1)]))(alt)
    mats = np.full(alt.shape, mat, object)
    if mat == "mura":                                   # le mura sono un muro sul bordo, non tutto l'altopiano
        p = np.pad(alt, 1, mode="edge")
        bordo = (p[2:, 1:-1] < alt) | (p[1:-1, :-2] < alt) | (p[1:-1, 2:] < alt) | (p[:-2, 1:-1] < alt)
        mats[~bordo] = ""
    base = Image.fromarray(T.compose_ground(terreno_sotto(ground, alt, mats), S=S, strati=strati(alt, mats)[0], duri=strati(alt, mats)[1]))
    strato = Image.fromarray(disegna(alt, mats, pas, S=S))
    base.alpha_composite(strato)
    return base


def main():
    os.makedirs(OUT, exist_ok=True)
    imgs = []
    for mat, titolo, terreni in SCENE:
        im = scena(mat, terreni)
        im.convert("RGB").save(os.path.join(OUT, f"scena_{mat}.png"))
        imgs.append(im)
        print(f"  scena_{mat}.png  ({titolo})")
    w, h = imgs[0].size
    tav = Image.new("RGB", (w * 2 * 2 + 20, (h * 2 + 10) * len(imgs)), (128, 128, 128))
    for i, im in enumerate(imgs):
        big = im.resize((w * 2, h * 2), Image.NEAREST)
        for j, sf in enumerate(((236, 232, 220), (34, 30, 44))):
            bg = Image.new("RGBA", big.size, sf + (255,)); bg.alpha_composite(big)
            tav.paste(bg.convert("RGB"), (j * (w * 2 + 20), i * (h * 2 + 10)))
    tav.save(os.path.join(OUT, "campioni.png"))
    print("  campioni.png")


if __name__ == "__main__":
    main()
