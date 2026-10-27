#!/usr/bin/env python3
"""
Forme di Enel (US-8B50): i fogli delle forme della primitiva transform, come aspetti del personaggio. Stessi tempi
e stesse animazioni di "personaggio" (data/animations.json), celle piu' grandi quando la forma e' piu' grande: il gioco
legge la cella dal foglio e mostra i pixel alla stessa grana degli altri sprite.

    python tools/art/build_forme.py      # arte/sprite/ e assets/placeholder/personaggio_<aspetto>_<animazione>.png

L'aspetto di una forma e' un dato: data/forms.json "aspetto" (id neutro, mai il nome della forma o del Pathway).
Nessun numero casuale: stessi parametri, stessi PNG.
"""

import json
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_personaggi as BP  # noqa: E402
from forge3d.sheets import export_spec  # noqa: E402

DEST = os.path.join(BP.ROOT, "assets", "placeholder")
FORMS = os.path.join(BP.ROOT, "data", "forms.json")

# aspetto: (rig, pixel per unita', lato della cella). Il gigante e' Enel una volta e mezza: piu' largo di spalle e con
# la testa piu' piccola rispetto al corpo, cosi' si legge come un gigante e non come Enel ingrandito.
FORME = {
    "gigante": (lambda: BP.enel(build=1.18, head=0.74), 1.22 * 1.5, 96),
}


def main():
    forme = json.load(open(FORMS, encoding="utf-8"))["forms"]
    usati = {f["aspetto"] for f in forme.values() if f.get("aspetto")}
    assert usati <= set(FORME), f"forme senza disegno: {usati - set(FORME)}"
    spec = json.load(open(BP.SPEC, encoding="utf-8"))
    mancano = [n for n in spec["personaggio"] if not n.startswith("_") and n not in BP.CLIP_ENEL]
    assert not mancano, mancano
    os.makedirs(DEST, exist_ok=True)
    tmp = tempfile.mkdtemp()                       # export_spec scrive personaggio_<nome>.png: non sopra Enel
    for aspetto in sorted(usati):
        rig, ppu, cella = FORME[aspetto]
        for path in export_spec(rig(), BP.SPEC, "personaggio", tmp, BP.CLIP_ENEL, size=(cella, cella), ppu=ppu,
                                shadow=False, foot=(0.5, BP.PIEDI)):
            nuovo = os.path.join(BP.OUT, os.path.basename(path).replace("personaggio_", f"personaggio_{aspetto}_", 1))
            os.replace(path, nuovo)
            BP.bordo_luce(nuovo, cella=cella)
            shutil.copy(nuovo, os.path.join(DEST, os.path.basename(nuovo)))
            print("  " + os.path.relpath(nuovo, BP.ROOT))
    shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
