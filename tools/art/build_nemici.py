#!/usr/bin/env python3
"""Figure dei tipi di nemico (US-1504): un aspetto per tipo di balance.json nemici_tipi, con le animazioni e i tempi di
nemico_base (data/animations.json), a 64 px, stessa luce e stesso metodo di build_personaggi.py.

    python tools/art/build_nemici.py                   # tutti gli aspetti -> arte/sprite/nemico_base_<aspetto>_<anim>.png
    python tools/art/build_nemici.py --solo tagliaborse
    python tools/art/generate_all.py --only nemico_base   # poi in assets/ col contorno rosso del tell

US-1504a: le figure umane; US-1504b: le bestie (quadrupedi e volatili, BESTIE). Le forme strane sono US-1504c.
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
from forge3d.creatures import BIRD_CLIPS, QUAD_CLIPS, bird, bird_hurt, quadruped  # noqa: E402
from forge3d.humanoid import humanoid  # noqa: E402
from forge3d.rig import add_pose, clip_from_keys  # noqa: E402
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


# --- US-1504b: bestie a quattro zampe (stesse clip dei pet, piu' anticipo e barcollo di forge3d) ------------------
def _corna(r, mat, scala=1.0):
    """Palco ramificato (come horns="antlers" di forge3d) in un materiale a scelta: il cervo le ha rosse."""
    for sx in (-1, 1):
        r.part("head", "cylinder", (0.45, 0.45, 3.0 * scala), (sx * 1.4, -0.4, 5.0), mat=mat, rot=(-10, sx * 25, 0))
        r.part("head", "cylinder", (0.38, 0.38, 1.6 * scala), (sx * 2.7, -0.4, 6.4), mat=mat, rot=(-10, sx * 60, 0))
        r.part("head", "cylinder", (0.32, 0.32, 1.2 * scala), (sx * 1.9, 0.6, 7.2), mat=mat, rot=(-40, sx * 10, 0))
    return r


def lupo_luna():
    r = quadruped(body_mat="fur_lunare", belly="fur_white", snout=3.4, ears="point", tail="bushy", eyes="eye_cyan",
                  name="lupo_della_luna")
    r.part("hips", "ellipsoid", (3.0, 2.2, 2.6), (0, 4.6, 1.8), mat="fur_white")
    r.part("head", "ellipsoid", (0.7, 0.6, 0.55), (0, 2.8 + 3.4 * 0.95, -0.4), mat="iron")
    r.part("head", "ellipsoid", (0.55, 0.3, 0.55), (0, 1.7, 2.3), mat="glow_cyan")          # falce di luna in fronte
    return r


def madre_lupi():
    r = quadruped(body_mat="fur_black", belly="fur_grey", snout=3.6, ears="point", tail="bushy", eyes="eye_red",
                  bulk=1.25, size=1.3, name="madre_dei_lupi")
    r.part("hips", "ellipsoid", (3.6, 2.6, 3.0), (0, 4.4, 2.2), mat="fur_grey")              # criniera
    r.part("head", "ellipsoid", (0.75, 0.6, 0.6), (0, 2.8 + 3.6 * 0.95, -0.4), mat="iron")
    return r


def belva_moli():
    r = quadruped(body_mat="fur_grey", belly="fur_white", snout=2.4, ears="round", tail="thin", eyes="eye_yellow",
                  bulk=1.35, head=1.15, size=1.1, name="belva_dei_moli")
    r.part("head", "ellipsoid", (2.2, 1.4, 1.2), (0, 2.6, -1.6), mat="fur_grey")              # mascella larga
    for sx in (-1, 1):
        r.part("head", "cone", (0.3, 0.3, 0.6), (sx * 0.9, 3.6, -1.9), mat="bone", rot=(180, 0, 0))   # zanne
    r.part("hips", "cylinder", (3.0, 3.0, 0.5), (0, 4.0, 2.6), mat="iron", soft=0.3)           # collare di catena
    return r


def cervo():
    r = quadruped(body_mat="fur_brown", belly="fur_white", snout=3.0, ears="long", tail="stub", eyes="eye_red",
                  bulk=0.95, head=0.9, size=1.15, name="cervo_corna_rosse")
    return _corna(r, "cloth_red", 1.1)


def ratto():
    r = quadruped(body_mat="fur_brown", belly="fur_white", snout=2.8, ears="round", tail="thin", eyes="eye_red",
                  bulk=0.85, size=0.9, name="ratto_delle_fogne")
    r.part("tail", "cylinder", (0.4, 0.4, 3.6), (0, 0, -6.0), mat="skin_pale")                # coda lunga e nuda
    r.part("head", "ellipsoid", (0.6, 0.5, 0.5), (0, 2.8 + 2.8 * 0.95, -0.5), mat="skin_pale")
    return r


# --- volatili: anticipo = ali alzate tenute (la carica della picchiata), barcollo = colpito ---------------------
def _bird_anticipo(n=4):
    carica = {"wing_l": (0, 60, 0), "wing_r": (0, -60, 0), "tip_l": (0, 20, 0), "tip_r": (0, -20, 0),
              "body": (15, 0, 0, 0, -0.8, 0.8), "head": (10, 0, 0)}
    return clip_from_keys([(0, {}), (n - 1, carica, "out")], n)


def corvo_battaglia():
    r = bird(body_mat="piume_corvo", beak="bone", eyes="eye_red", legs="iron", size=1.25, name="corvo_della_battaglia")
    r.part("body", "ellipsoid", (1.2, 1.0, 0.9), (0, 1.6, 0.9), mat="cloth_red")             # straccio di stendardo
    return r


def pipistrello():
    r = bird(body_mat="fur_black", beak="fur_black", eyes="eye_white", legs="fur_black", size=1.0,
             name="pipistrello_cieco")
    for sx in (-1, 1):
        r.part("head", "cone", (0.6, 0.4, 1.2), (sx * 0.8, 0.0, 1.6), mat="fur_black", rot=(0, sx * 15, 0))
    return r


def gabbiano():
    return bird(body_mat="fur_white", beak="cloth_yellow", eyes="eye", legs="cloth_orange", size=1.1,
                name="gabbiano_ladro")


def _quad_anticipo(n=4):
    """Tell leggibile da fermo (quello di forge3d e' sottile): si acquatta, testa bassa e zampe davanti piegate,
    groppa alta, coda tesa."""
    acquattato = {"hips": (16, 0, 0, 0, -1.6, -2.0), "head": (-26, 0, 0), "leg_fl": (-28, 0, 0), "leg_fr": (-28, 0, 0),
                  "shin_fl": (40, 0, 0), "shin_fr": (40, 0, 0), "leg_bl": (14, 0, 0), "leg_br": (14, 0, 0),
                  "tail": (40, 0, 0)}
    return clip_from_keys([(0, {}), (2, acquattato, "out"), (n - 1, add_pose(acquattato, {"hips": (2, 0, 0)}))], n)


CLIP_QUAD = {k: BP.vivi(v) for k, v in dict(QUAD_CLIPS, death=BP.quad_morte, anticipo=_quad_anticipo).items()}
CLIP_BIRD = {k: BP.vivi(v) for k, v in dict(BIRD_CLIPS, anticipo=_bird_anticipo,
                                             stagger=lambda n=4: bird_hurt(n)).items()}

# aspetto -> (rig, pixel per unita', clip). I lupi come il pet (1.75), i volatili come il corvo del pet (2.3).
BESTIE = {
    "lupo_della_luna": (lupo_luna, 1.75, CLIP_QUAD),
    "madre_dei_lupi": (madre_lupi, 1.75, CLIP_QUAD),
    "belva_dei_moli": (belva_moli, 1.75, CLIP_QUAD),
    "cervo_corna_rosse": (cervo, 1.6, CLIP_QUAD),
    "ratto_delle_fogne": (ratto, 1.75, CLIP_QUAD),
    "corvo_della_battaglia": (corvo_battaglia, 2.3, CLIP_BIRD),
    "pipistrello_cieco": (pipistrello, 2.3, CLIP_BIRD),
    "gabbiano_ladro": (gabbiano, 2.3, CLIP_BIRD),
}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--solo", nargs="*")
    a = ap.parse_args()
    out = BP.OUT
    voci = [(k, (c, 1.4, CLIP)) for k, c in ASPETTI.items() if c is not None] + list(BESTIE.items())
    for aspetto, (costr, ppu, clip) in voci:
        if a.solo and aspetto not in a.solo:
            continue
        # in una cartella temporanea: export_spec scrive nemico_base_<anim>.png, che in arte/sprite e' il foglio base
        with tempfile.TemporaryDirectory() as tmp:
            for path in export_spec(costr(), BP.SPEC, CAT, tmp, clip, ppu=ppu, shadow=False, foot=(0.5, BP.PIEDI)):
                nuovo = os.path.join(out, os.path.basename(path).replace(CAT + "_", f"{CAT}_{aspetto}_", 1))
                os.replace(path, nuovo)
        print("  " + aspetto)


if __name__ == "__main__":
    main()
