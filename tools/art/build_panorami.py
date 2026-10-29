"""Panorami (US-8B74): i 6 strati del parallasse per le 4 fasce del TimeSystem, dietro il libro all'avvio.

    python tools/art/build_panorami.py

Una citta' di mare col faro, le montagne dietro e il mare davanti (forge3d/panorama.py strati()), alla grana del
libro: un texel = un'unita' di gioco = 2 pixel a schermo, 640 x 360. Ogni strato tranne il cielo si ripete in
orizzontale (il gioco lo fa scorrere). Fasce: data/schema/time.json "momenti" -> l'ora di panorama.py TIMES.
Niente che riveli un Pathway o una Sequenza. File: assets/ui/panorama/<momento>/<strato>.png; foglio di
controllo in arte/revisione/panorami.png. Stesso seed = stessi PNG.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from forge3d.panorama import strati  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui", "panorama")
REVISIONE = os.path.join(ROOT, "arte", "revisione", "panorami.png")
SEED = 3
STRATI = ("sky", "clouds", "far", "mid", "near", "fg")
ORA = {"alba": "dawn", "mezzogiorno": "day", "crepuscolo": "dusk", "notte_fonda": "night"}


def main():
    momenti = json.load(open(os.path.join(ROOT, "data", "schema", "time.json")))["momenti"]
    assert set(momenti) == set(ORA), set(momenti) ^ set(ORA)
    composti = []
    for m in momenti:
        lay = strati(640, 360, ORA[m], SEED)
        os.makedirs(os.path.join(OUT, m), exist_ok=True)
        comp = lay["sky"].copy()
        for st in STRATI:
            img = lay[st]
            assert set(np.unique(img[..., 3])) <= {0, 255}, f"{m}/{st}: alpha non 0/255"
            if st not in ("sky", "near"):                     # la citta' si giunta tra due case
                assert ((img[:, 0, 3] > 0) == (img[:, -1, 3] > 0)).mean() > 0.97, f"{m}/{st}: non si ripete"
            if st != "sky":
                comp = np.where(img[..., 3:4] > 0, img, comp)
            Image.fromarray(img).save(os.path.join(OUT, m, st + ".png"))
        composti.append(comp)
    foglio = np.concatenate([np.concatenate(composti[:2], 1), np.concatenate(composti[2:], 1)], 0)
    os.makedirs(os.path.dirname(REVISIONE), exist_ok=True)
    Image.fromarray(foglio).resize((foglio.shape[1] * 2, foglio.shape[0] * 2), Image.NEAREST).save(REVISIONE)
    print(f"{len(momenti)} fasce x {len(STRATI)} strati in assets/ui/panorama/, foglio in "
          f"{os.path.relpath(REVISIONE, ROOT)}")


if __name__ == "__main__":
    main()
