#!/usr/bin/env python3
"""Figure dei tipi di nemico (US-1504): un aspetto per tipo di balance.json nemici_tipi, con le animazioni e i tempi di
nemico_base (data/animations.json), a 64 px, stessa luce e stesso metodo di build_personaggi.py.

    python tools/art/build_nemici.py                   # tutti gli aspetti -> arte/sprite/nemico_base_<aspetto>_<anim>.png
    python tools/art/build_nemici.py --solo tagliaborse
    python tools/art/generate_all.py --only nemico_base   # poi in assets/ col contorno rosso del tell

US-1504a: le figure umane (questo file). Le bestie e le forme strane (melma, germoglio, glifo, barca) sono US-1504b/c.
Un aspetto e' un dato del tipo ("aspetto" in balance.json): qui solo come si disegna. Nessun numero casuale: stessi
parametri, stessi PNG. Colori diversi da Enel (cappotto quasi nero e sciarpa rossa): nessun nemico sembra il giocatore,
tranne il Doppio, che deve.
"""
import argparse
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_personaggi as BP  # noqa: E402
from forge3d.humanoid import humanoid  # noqa: E402
from forge3d.sheets import export_spec  # noqa: E402

CAT = "nemico_base"


def _u(name, **kw):
    base = dict(boots="leather_dark", belt="leather", head=0.9, detail=2, name=name, eyes="eye")
    base.update(kw)
    return lambda: humanoid(**base)


ASPETTI = {
    # Mirwada: la strada e il porto
    "tagliaborse": _u("tagliaborse", skin="skin_tan", hair="hair_brown", hair_style="short", outfit="leather",
                      top="cloth_grey", bottom="cloth_black", scarf="cloth_teal", weapon="dagger", build=0.92),
    "scaricatore_ubriaco": _u("scaricatore_ubriaco", skin="skin_light", hair="hair_red", hair_style="bald",
                              outfit="peasant", top="cloth_cream", bottom="cloth_blue", beard="fur_orange",
                              weapon=None, build=1.3),
    "guardia_corrotta": _u("guardia_corrotta", skin="skin_light", hair="hair_brown", hair_style="short",
                           outfit="armor", top="cloth_blue", bottom="cloth_grey", hat="helmet", weapon="spear",
                           shield="round"),
    "devoto_fuori_controllo": _u("devoto_fuori_controllo", skin="skin_pale", hair="hair_white", hair_style="long",
                                 outfit="robe", top="cloth_white", bottom="cloth_white", belt="cloth_red",
                                 eyes="eye_red", weapon="staff"),
    "contrabbandiere_balestra": _u("contrabbandiere_balestra", skin="skin_tan", hair="hair_black",
                                   hair_style="ponytail", outfit="leather", top="cloth_green", bottom="cloth_black",
                                   hat="cap", weapon="torch"),
    "brigante": None,                                   # resta il nemico_base (bandito con la mazza)
    "pirata_naufrago": _u("pirata_naufrago", skin="skin_tan", hair="hair_black", hair_style="long", outfit="rags",
                          top="cloth_red", bottom="cloth_grey", scarf="cloth_red", beard="fur_black", weapon="sword"),
    # Marche: il campo di battaglia
    "soldato_caduto": _u("soldato_caduto", skin="skin_grey", hair="hair_black", hair_style="bald", outfit="armor",
                         top="cloth_red", bottom="cloth_grey", hat="helmet", weapon="sword", shield="kite",
                         eyes="eye_cyan"),
    "alfiere_spettrale": _u("alfiere_spettrale", skin="skin_pale", hair="hair_white", hair_style="short",
                            outfit="robe", top="cloth_grey", bottom="cloth_grey", cape="cloth_purple",
                            eyes="eye_cyan", weapon="spear"),
    "ombra_strisciante": _u("ombra_strisciante", skin="skin_grey", hair="hair_black", hair_style="bald",
                            outfit="robe", top="cloth_black", bottom="cloth_black", cape="cloth_black",
                            eyes="eye_red", weapon="dagger", build=0.9),
    "colosso_arrugginito": _u("colosso_arrugginito", skin="skin_grey", hair="hair_black", hair_style="bald",
                              outfit="armor", top="cloth_orange", bottom="cloth_orange", hat="helmet",
                              weapon="mace", build=1.4, scale=1.12, eyes="eye_yellow"),
    "capitano_senza_riposo": _u("capitano_senza_riposo", skin="skin_grey", hair="hair_white", hair_style="short",
                                outfit="armor", top="cloth_purple", bottom="cloth_black", cape="cloth_red",
                                hat="crown", weapon="greatsword", eyes="eye_cyan", build=1.15),
    # Valle
    "guardiana_delle_radici": _u("guardiana_delle_radici", skin="skin_green", hair="leaf_dead", hair_style="long",
                                 outfit="robe", top="cloth_green", bottom="cloth_green", belt="cloth_yellow",
                                 weapon="staff", eyes="eye_yellow"),
    # Archivio
    "scrivano_di_carta": _u("scrivano_di_carta", skin="skin_pale", hair="hair_black", hair_style="bun",
                            outfit="robe", top="cloth_cream", bottom="cloth_cream", belt="cloth_black",
                            glasses="gold", weapon=None),
    "automa_custode": _u("automa_custode", skin="skin_grey", hair="hair_black", hair_style="bald", outfit="armor",
                         top="cloth_yellow", bottom="cloth_grey", hat="helmet", weapon="axe", eyes="eye_cyan",
                         build=1.15),
    "lettore_proibito": _u("lettore_proibito", skin="skin_pale", hair="hair_purple", hair_style="long",
                           outfit="robe", top="cloth_purple", bottom="cloth_black", hat="wizard", weapon="staff",
                           eyes="eye_cyan"),
    "bibliotecario_muto": _u("bibliotecario_muto", skin="skin_pale", hair="hair_white", hair_style="bald",
                             outfit="robe", top="cloth_blue", bottom="cloth_blue", scarf="cloth_white",
                             weapon=None, beard="fur_white"),
    "custode_del_sapere": _u("custode_del_sapere", skin="skin_pale", hair="hair_white", hair_style="long",
                             outfit="robe", top="cloth_white", bottom="cloth_blue", cape="cloth_blue", hat="crown",
                             weapon="staff", eyes="eye_cyan", build=1.1, scale=1.05),
    # Frontiera
    "maschera_senza_volto": _u("maschera_senza_volto", skin="skin_pale", hair="hair_black", hair_style="short",
                               outfit="tunic", top="cloth_white", bottom="cloth_black", eyes="eye_white",
                               weapon="dagger"),
    "viandante_delle_porte": _u("viandante_delle_porte", skin="skin_tan", hair="hair_blue", hair_style="short",
                                outfit="leather", top="cloth_purple", bottom="cloth_grey", cape="cloth_teal",
                                weapon="sword", eyes="eye_cyan"),
    "marionetta_del_teatro": _u("marionetta_del_teatro", skin="skin_light", hair="hair_red", hair_style="ponytail",
                                outfit="tunic", top="cloth_red", bottom="cloth_yellow", weapon="sword", head=1.05,
                                build=0.85),
    "ladro_di_tempo": _u("ladro_di_tempo", skin="skin_grey", hair="hair_white", hair_style="spiky", outfit="robe",
                         top="cloth_teal", bottom="cloth_black", hat="wizard", weapon="staff", eyes="eye_yellow"),
    "burattinaio": _u("burattinaio", skin="skin_pale", hair="hair_black", hair_style="long", outfit="robe",
                      top="cloth_black", bottom="cloth_purple", cape="cloth_red", hat="wizard", weapon="staff",
                      eyes="eye_red", build=1.1, scale=1.05),
    "il_doppio": lambda: BP.enel(lama="glow_purple", eyes="eye_red"),   # il Doppio di Enel: deve sembrare lui
    # Sottosuolo e mare
    "scheletro_catacombe": _u("scheletro_catacombe", skin="bone", hair="hair_white", hair_style="bald",
                              outfit="rags", top="bone", bottom="bone", boots="bone", belt="leather_dark",
                              weapon="sword", eyes="eye_cyan", build=0.85),
    "custode_della_cripta": _u("custode_della_cripta", skin="skin_grey", hair="hair_black", hair_style="bald",
                               outfit="armor", top="cloth_black", bottom="cloth_black", hat="helmet",
                               weapon="greatsword", shield="round", eyes="eye_red", build=1.25, scale=1.08),
    "voce_dell_acqua": _u("voce_dell_acqua", skin="skin_pale", hair="hair_blue", hair_style="long", outfit="robe",
                          top="cloth_teal", bottom="cloth_blue", eyes="eye_cyan", weapon=None),
}

CLIP = {k: BP.vivi(v) for k, v in dict(BP.A.CLIPS, death=BP.morte_di_lato).items()}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--solo", nargs="*")
    a = ap.parse_args()
    out = BP.OUT
    for aspetto, costr in ASPETTI.items():
        if costr is None or (a.solo and aspetto not in a.solo):
            continue
        # in una cartella temporanea: export_spec scrive nemico_base_<anim>.png, che in arte/sprite e' il foglio base
        with tempfile.TemporaryDirectory() as tmp:
            for path in export_spec(costr(), BP.SPEC, CAT, tmp, CLIP, ppu=1.4, shadow=False, foot=(0.5, BP.PIEDI)):
                nuovo = os.path.join(out, os.path.basename(path).replace(CAT + "_", f"{CAT}_{aspetto}_", 1))
                os.replace(path, nuovo)
        print("  " + aspetto)


if __name__ == "__main__":
    main()
