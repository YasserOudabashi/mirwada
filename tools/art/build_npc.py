#!/usr/bin/env python3
"""
Aspetti degli NPC a 64 px (US-8B12d): stesso motore, stessa luce e stessi tempi del personaggio
(data/animations.json "personaggio"), un disegno per aspetto. L'aspetto di un NPC e' un dato:
data/npc/roster.json "aspetto.sprite" (id neutro, mai il nome dell'NPC).

    python tools/art/build_npc.py        # arte/sprite/ e assets/placeholder/personaggio_<aspetto>_{idle,walk}.png

Gli NPC per ora stanno fermi o camminano: si generano solo idle e walk. Nessun numero casuale: stessi parametri,
stessi PNG.
"""

import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_personaggi as BP  # noqa: E402
from forge3d import anim_humanoid as A  # noqa: E402
from forge3d.humanoid import humanoid  # noqa: E402
from forge3d.sheets import export_spec  # noqa: E402

DEST = os.path.join(BP.ROOT, "assets", "placeholder")
ANIMAZIONI = ("idle", "walk")
CLIP = {k: BP.vivi(A.CLIPS[k]) for k in ANIMAZIONI}


def _npc(name, scale=1.0, **kw):
    base = dict(weapon=None, boots="leather_dark", belt="leather", head=0.95, detail=2, name=name, scale=scale)
    base.update(kw)
    return lambda: humanoid(**base)


ASPETTI = {
    # aspetto: rig. Colori diversi da Enel (cappotto quasi nero, sciarpa rossa) cosi' nessuno sembra il giocatore.
    "amico": _npc("amico", skin="skin_light", hair="hair_brown", hair_style="short", outfit="tunic",
                  top="cloth_green", bottom="cloth_grey"),
    "mercante": _npc("mercante", skin="skin_tan", hair="hair_black", hair_style="short", outfit="robe",
                     top="cloth_orange", bottom="cloth_cream", scarf="cloth_yellow", build=1.12),
    "guaritrice": _npc("guaritrice", skin="skin_light", hair="hair_red", hair_style="long", outfit="robe",
                       top="cloth_cream", bottom="cloth_white", belt="cloth_green"),
    "rivale": _npc("rivale", skin="skin_pale", hair="hair_blond", hair_style="short", outfit="leather",
                   top="cloth_white", bottom="cloth_grey", weapon="sword"),
    "archivista": _npc("archivista", skin="skin_pale", hair="hair_black", hair_style="bun", outfit="robe",
                       top="cloth_purple", bottom="cloth_purple", belt="cloth_yellow"),
    # niente cappuccio: a 64 px copriva tutto il viso (contact sheet)
    "contrabbandiere": _npc("contrabbandiere", skin="skin_tan", hair="hair_black", hair_style="short",
                            outfit="leather", top="cloth_grey", bottom="cloth_black", hat="cap", scarf="cloth_teal"),
    "bambina": _npc("bambina", scale=0.74, skin="skin_light", hair="hair_red", hair_style="ponytail",
                    outfit="peasant", top="cloth_yellow", bottom="cloth_blue", head=1.15),
    "investigatore": _npc("investigatore", skin="skin_light", hair="hair_brown", hair_style="short", outfit="tunic",
                          top="cloth_blue", bottom="cloth_grey", hat="cap", scarf="cloth_cream"),
    "popolano_a": _npc("popolano_a", skin="skin_tan", hair="hair_brown", hair_style="short", outfit="peasant",
                       top="cloth_cream", bottom="cloth_grey"),
    "popolano_b": _npc("popolano_b", skin="skin_dark", hair="hair_black", hair_style="ponytail", outfit="tunic",
                       top="cloth_red", bottom="cloth_cream"),
    "popolano_c": _npc("popolano_c", skin="skin_light", hair="hair_white", hair_style="bald", outfit="tunic",
                       top="cloth_blue", bottom="cloth_cream", build=1.1),
    # fase 11: gli NPC degli interni e dei villaggi
    "fabbro": _npc("fabbro", skin="skin_tan", hair="hair_black", hair_style="short", outfit="leather",
                   top="leather", bottom="cloth_black", boots="leather_dark", build=1.2),
    "erborista": _npc("erborista", skin="skin_light", hair="hair_brown", hair_style="long", outfit="robe",
                      top="cloth_green", bottom="cloth_cream", belt="leather"),
    "alchimista": _npc("alchimista", skin="skin_dark", hair="hair_white", hair_style="bun", outfit="robe",
                       top="cloth_teal", bottom="cloth_teal", belt="cloth_yellow"),
    "mercante_b": _npc("mercante_b", skin="skin_light", hair="hair_blond", hair_style="ponytail", outfit="tunic",
                       top="cloth_yellow", bottom="cloth_grey", scarf="cloth_orange"),
    "soglia": _npc("soglia", skin="skin_grey", hair="hair_white", hair_style="long", outfit="robe",
                   top="cloth_black", bottom="cloth_black", cape="cloth_purple", belt="cloth_purple", eyes="eye_red"),
}


def main():
    os.makedirs(DEST, exist_ok=True)
    tmp = tempfile.mkdtemp()                       # export_spec scrive personaggio_<nome>.png: non sopra Enel
    for aspetto, rig in ASPETTI.items():
        for path in export_spec(rig(), BP.SPEC, "personaggio", tmp, CLIP, ppu=1.22, shadow=False,
                                foot=(0.5, BP.PIEDI), only=ANIMAZIONI):
            nuovo = os.path.join(BP.OUT, os.path.basename(path).replace("personaggio_", f"personaggio_{aspetto}_", 1))
            os.replace(path, nuovo)
            BP.bordo_luce(nuovo)
            shutil.copy(nuovo, os.path.join(DEST, os.path.basename(nuovo)))
            print("  " + os.path.relpath(nuovo, BP.ROOT))
    shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
