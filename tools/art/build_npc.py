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
    """Il rig di un aspetto; `volto` aggiunge il dettaglio dei ritratti (build_ritratti.py: detail=3). La barba sta
    anche sullo sprite; occhiali, sopracciglia (brows) e bocca (mouth) si vedono solo con detail 3."""
    base = dict(weapon=None, boots="leather_dark", belt="leather", head=0.95, detail=2, name=name, scale=scale)
    base.update(kw)
    return lambda **volto: humanoid(**dict(base, **volto))


ASPETTI = {
    # aspetto: rig. Colori diversi da Enel (cappotto quasi nero, sciarpa rossa) cosi' nessuno sembra il giocatore.
    "amico": _npc("amico", skin="skin_light", hair="hair_brown", hair_style="short", outfit="tunic",
                  top="cloth_green", bottom="cloth_grey", beard="fur_grey", mouth=1),
    "mercante": _npc("mercante", skin="skin_tan", hair="hair_black", hair_style="short", outfit="robe",
                     top="cloth_orange", bottom="cloth_cream", scarf="cloth_yellow", build=1.12, brows=8, mouth=1),
    "guaritrice": _npc("guaritrice", skin="skin_light", hair="hair_red", hair_style="long", outfit="robe",
                       top="cloth_cream", bottom="cloth_white", belt="cloth_green", brows=14),
    "rivale": _npc("rivale", skin="skin_pale", hair="hair_blond", hair_style="short", outfit="leather",
                   top="cloth_white", bottom="cloth_grey", weapon="sword", brows=-6, mouth=1),
    "archivista": _npc("archivista", skin="skin_pale", hair="hair_black", hair_style="bun", outfit="robe",
                       top="cloth_purple", bottom="cloth_purple", belt="cloth_yellow", glasses="gold", brows=10),
    # niente cappuccio: a 64 px copriva tutto il viso (contact sheet)
    "contrabbandiere": _npc("contrabbandiere", skin="skin_tan", hair="hair_black", hair_style="short",
                            outfit="leather", top="cloth_grey", bottom="cloth_black", hat="cap", scarf="cloth_teal",
                            beard="fur_black", brows=6),
    "bambina": _npc("bambina", scale=0.74, skin="skin_light", hair="hair_red", hair_style="ponytail",
                    outfit="peasant", top="cloth_yellow", bottom="cloth_blue", head=1.15, brows=-14, mouth=1),
    "investigatore": _npc("investigatore", skin="skin_light", hair="hair_brown", hair_style="short", outfit="tunic",
                          top="cloth_blue", bottom="cloth_grey", hat="cap", scarf="cloth_cream", brows=4),
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
                   top="cloth_black", bottom="cloth_black", cape="cloth_purple", belt="cloth_purple", eyes="eye_red",
                   brows=16, mouth=-1),
    # US-8B60b: un aspetto per antagonista (data/lore/antagonisti.json "aspetto"). Id neutri, mai nomi di Pathway:
    # chi e' chi lo dicono i dati. Tutti con gli occhi che brillano e la pelle spenta di chi ha perso il controllo.
    "soglia_01": _npc("soglia_01", scale=1.22, build=1.3, skin="skin_grey", hair="hair_white", hair_style="short",
                      outfit="armor", top="cloth_grey", bottom="cloth_black", cape="cloth_red", hat="helmet",
                      eyes="eye_yellow", weapon="sword", brows=14, mouth=-1),
    # 2026-11-18: capelli bianchi lunghi, saio grigio cenere e sciarpa d'osso (prima il cappuccio nero copriva il volto)
    "soglia_02": _npc("soglia_02", skin="skin_pale", hair="hair_white", hair_style="long", outfit="robe",
                      top="cloth_grey", bottom="cloth_black", belt="bone", scarf="bone", eyes="eye_cyan",
                      brows=8, mouth=-1),
    # 2026-11-18: la veste viola sotto il mantello nero, capelli viola (prima era troppo simile a soglia_02)
    "soglia_03": _npc("soglia_03", skin="skin_grey", hair="hair_purple", hair_style="long", outfit="robe",
                      top="cloth_purple", bottom="cloth_black", cape="cloth_black", belt="bone",
                      eyes="eye_cyan", brows=10),
    "soglia_04": _npc("soglia_04", skin="skin_pale", hair="hair_white", hair_style="long", outfit="robe",
                      top="cloth_white", bottom="cloth_white", belt="cloth_red", hat="crown", eyes="eye_red",
                      brows=12, mouth=-1),
    "soglia_05": _npc("soglia_05", build=1.1, skin="skin_green", hair="leaf_dead", hair_style="spiky", outfit="robe",
                      top="cloth_green", bottom="cloth_green", belt="leaf_dark", scarf="leaf_autumn",
                      eyes="eye_yellow", brows=6, mouth=-1),
    "soglia_06": _npc("soglia_06", skin="skin_pale", hair="hair_white", hair_style="long", outfit="robe",
                      top="cloth_purple", bottom="cloth_purple", belt="cloth_yellow", hat="wizard", glasses="gold",
                      beard="hair_white", eyes="eye_cyan", brows=10),
    "soglia_07": _npc("soglia_07", build=1.08, skin="skin_tan", hair="hair_blond", hair_style="short",
                      outfit="armor", top="cloth_yellow", bottom="cloth_white", cape="cloth_white", hat="crown",
                      eyes="eye_yellow", weapon="sword", brows=4),
    "soglia_08": _npc("soglia_08", skin="skin_grey", hair="hair_blue", hair_style="short", outfit="tunic",
                      top="cloth_teal", bottom="cloth_grey", hat="cap", scarf="cloth_grey", eyes="eye_white",
                      brows=-4, mouth=-1),
    "soglia_09": _npc("soglia_09", skin="skin_pale", hair="hair_purple", hair_style="spiky", outfit="leather",
                      top="cloth_red", bottom="cloth_teal", scarf="cloth_yellow", eyes="eye_red", brows=-12, mouth=1),
    "soglia_10": _npc("soglia_10", skin="skin_pale", hair="hair_red", hair_style="bald", outfit="tunic",
                      top="cloth_red", bottom="cloth_yellow", belt="cloth_purple", cape="cloth_orange", hat="wizard",
                      eyes="eye_white", brows=-10, mouth=1),
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
