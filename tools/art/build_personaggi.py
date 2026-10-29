#!/usr/bin/env python3
"""
Personaggi a 64 px (PRD 8b, Blocco C: US-8B30 Enel, US-8B31 nemico_base, US-8B32 pet) con un metodo solo:
il motore 3D di forge3d (stessa luce in alto a sinistra, contorno da 1 px, nessuna ombra cotta: l'ombra a
terra la mette il gioco). Revisione arte 1.1-1.14.

    python tools/art/build_personaggi.py                 # scrive arte/sprite/{categoria}_{nome}.png
    python tools/art/build_personaggi.py --only pet
    python tools/art/generate_all.py                     # poi li porta in assets/ (con il tell del nemico)

Frame, direzioni e dimensione vengono da data/animations.json. Nessun numero casuale: stessi parametri,
stessi PNG.
"""

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from forge3d import anim_humanoid as A  # noqa: E402
from forge3d.creatures import BIRD_CLIPS, QUAD_CLIPS, bird, quadruped  # noqa: E402
from forge3d.humanoid import REST, P, humanoid  # noqa: E402
from forge3d.rig import add_pose, clip_from_keys  # noqa: E402
from forge3d.sheets import export_spec  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SPEC = os.path.join(ROOT, "data", "animations.json")
OUT = os.path.join(ROOT, "arte", "sprite")


# --- Enel -------------------------------------------------------------------------------------------------------
def enel(lama="steel", **volto):
    """Cappotto lungo quasi nero aperto davanti (si vedono le gambe), coppola, occhi freddi che brillano, crepa
    luminosa sul viso, sciarpa rossa che dietro pende sulla schiena, bende sugli avambracci, spadone.
    `volto`: il dettaglio dei ritratti (build_ritratti.py), ad esempio detail=3 e l'espressione. `lama`: il materiale
    della lama (la forma con l'arma di luce, build_forme.py)."""
    kw = dict(skin="skin_enel", hair="hair_black", hair_style="short", outfit="tunic", top="coat_enel",
              bottom="trou_enel", boots="leather_dark", belt="leather_dark", hat="cap", weapon=None,
              eyes="eye_cyan", scarf="cloth_red", head=0.86, detail=2, name="enel")
    kw.update(volto)
    r = humanoid(**kw)
    # spadone con la lama un po' piu' corta del "greatsword" del costruttore (16 -> 13 unita'): col braccio teso
    # il colpo resta nella cella (revisione 1.4: il fendente grande lo fanno i VFX)
    r.group("weapon", [P("cylinder", (0.85, 0.85, 2.2), (0, 0, 1.0), "leather"),
                       P("ellipsoid", (1.2, 1.2, 1.0), (0, 0, -1.4), "gold"),
                       P("box", (3.4, 1.0, 0.65), (0, 0, 3.2), "gold", soft=0.6),
                       P("box", (1.6, 0.5, 6.5), (0, 0, 10.2), lama, soft=0.5),
                       P("cone", (1.6, 0.5, 1.6), (0, 0, 18.3), lama)], pos=(0, 0.2, -0.3), rot=(-90, 0, 0))
    for sx in (-1, 1):                                            # falde del cappotto, dietro e ai lati
        r.part("hips", "ellipsoid", (2.6, 1.6, 6.2), (sx * 3.0, -1.4, -4.6), mat="coat_enel", rot=(6, 0, sx * -4))
    r.part("hips", "ellipsoid", (3.6, 1.2, 6.4), (0, -2.4, -4.4), mat="coat_enel", rot=(8, 0, 0))
    for side in ("l", "r"):                                       # bende
        for z in (-1.8, -3.0):
            r.part(f"fore_{side}", "cylinder", (1.85, 1.85, 0.42), (0, 0, z), mat="cloth_white", soft=0.3)
    r.part("head", "box", (0.32, 0.25, 1.6), (-1.2, 4.75, 5.4 * 0.86 + 1.2), mat="glow_cyan", rot=(0, 18, 0))  # crepa
    r.part("torso", "ellipsoid", (1.2, 0.8, 4.2), (1.6, -3.0, 3.6), mat="cloth_red", rot=(8, 0, 6))    # sciarpa
    return r


# spadone in spalla: lama in diagonale dietro la spalla destra (non esce dalla cella, si legge in tutte le viste)
SPALLA = {"arm_r": (25, 0, -20), "fore_r": (120, 0, 0), "weapon": (-15, 0, -35)}


def in_spalla(pose):
    p = dict(pose)
    for j, v in SPALLA.items():
        p[j] = tuple(a + b for a, b in zip(REST.get(j, (0, 0, 0)), v))
    return p


def clip_spalla(f):
    return lambda n: [in_spalla(p) for p in f(n)]


def da_spalla(f):
    """Attacchi e parata: si parte e si torna con lo spadone in spalla, come nell'idle (niente salto dell'arma)."""
    def g(n):
        pose = f(n)
        return [in_spalla(p) for p in pose[:1]] + pose[1:-1] + [in_spalla(p) for p in pose[-1:]]
    return g


def quasi_uguali(p, q, tol=1.5):
    """Due pose che a 64 px darebbero lo stesso disegno (differenze sotto tol gradi / decimi di unita')."""
    for j in set(p) | set(q):
        a, b = p.get(j, (0, 0, 0)), q.get(j, (0, 0, 0))
        a, b = tuple(a) + (0,) * (6 - len(a)), tuple(b) + (0,) * (6 - len(b))
        if any(abs(x - y) > (tol if k < 3 else 0.1 * tol) for k, (x, y) in enumerate(zip(a, b))):
            return False
    return True


def vivi(clip):
    """Revisione 1.14: un frame uguale al precedente (posa tenuta) diventa un micro-movimento (respiro, tremito
    della carica), cosi' non ci sono frame doppi; la durata la decide durate_ms."""
    def f(n):
        out = []
        for i, p in enumerate(clip(n)):
            if out and quasi_uguali(p, out[-1]):
                p = add_pose(p, {"torso": (2, 0, 1), "head": (1.5, 0, 0), "hips": (0, 0, 0, 0, 0, 0.25)})
            out.append(p)
        return out
    return f


def morte_di_lato(n):
    """Revisione 1.12: cade su un fianco e resta a terra, disteso (la caduta all'indietro, vista di fronte, era
    una testa che affondava). Non direzionale: si vede dal davanti."""
    keys = [(0, A._p(), "out"),
            (1, A._p(hips=(0, -8, 0, 0, 0, -0.8), torso=(-12, 0, 0), head=(-10, 0, 0), arm_l=(30, 0, 0), arm_r=(40, 0, 0)), "in"),
            (3, A._p(hips=(0, -50, 0, 4.0, 0, -3.4), torso=(0, -6, 0), head=(0, -10, 0), arm_l=(20, 30, 0),
                     arm_r=(60, -10, 0), leg_l=(10, 6, 0), leg_r=(-8, 0, 0)), "in"),
            (5, A._p(hips=(0, -84, 0, 8.0, 0, -5.8), torso=(0, -4, 0), head=(0, -8, 0), arm_l=(-10, 20, 0),
                     arm_r=(50, -20, 0), leg_l=(4, 6, 0), leg_r=(-6, 0, 0)), "out"),
            (n - 1, A._p(hips=(0, -90, 0, 8.0, 0, -5.6), torso=(0, -2, 0), head=(0, -6, 0), arm_l=(-10, 22, 0),
                         arm_r=(52, -22, 0), leg_l=(4, 6, 0), leg_r=(-6, 0, 0)), "out")]
    return A.clip_from_keys(keys, n)


CLIP_ENEL = {k: vivi(v) for k, v in dict(A.CLIPS, idle=clip_spalla(A.idle), walk=clip_spalla(A.walk),
                                          dash=clip_spalla(A.dash), attack_light=da_spalla(A.attack_light),
                                          attack_heavy=da_spalla(A.attack_heavy), parry=da_spalla(A.parry),
                                          hurt=clip_spalla(A.hurt), cast=clip_spalla(A.cast),
                                          meditate=clip_spalla(A.meditate), death=morte_di_lato,
                                          interact=clip_spalla(A.interact), pickup=clip_spalla(A.pickup),
                                          drink=clip_spalla(A.drink), ritual=clip_spalla(A.ritual),
                                          fly=clip_spalla(A.fly), sail=clip_spalla(A.sail)).items()}


# --- nemico_base ------------------------------------------------------------------------------------------------
def nemico():
    """Bandito con la mazza: niente berretto (copriva la testa: di profilo non si vedeva il viso), capelli scuri,
    giubba verde che si stacca dalla pelle, da Enel e dal lupo."""
    r = humanoid(skin="skin_tan", hair="hair_black", hair_style="bald", outfit="leather", top="cloth_bandito",
                 bottom="cloth_grey", boots="leather_dark", belt="leather", hat=None, weapon="mace",
                 eyes="eye", head=0.9, build=1.08, detail=2, name="nemico_base")
    hz = 5.4 * 0.9                                                # capelli corti solo su nuca e cima: viso libero
    r.part("head", "ellipsoid", (5.4, 4.6, 3.6), (0, -1.8, hz + 2.6), mat="hair_black")
    r.part("head", "ellipsoid", (5.0, 2.4, 4.2), (0, -3.6, hz + 0.6), mat="hair_black")
    ez = hz - 0.5 * 0.9                                           # profilo (revisione 1.11): occhio sul fianco
    for sx in (-1, 1):                                            # del viso e naso che sporge
        r.part("head", "ellipsoid", (0.77, 0.77, 1.1), (sx * 3.8, 4.4, ez), mat="eye")
    r.part("head", "ellipsoid", (0.9, 1.4, 1.0), (0, 5.6, ez - 1.0), mat="skin_tan")
    return r


# --- pet: lupo cinereo ------------------------------------------------------------------------------------------
def lupo():
    """Grigio cenere caldo (non il blu-grigio di Enel e del selciato), pancia chiara, orecchie a punta, occhi
    ciano sempre visibili."""
    r = quadruped(body_mat="fur_cinereo", belly="fur_white", snout=3.4, ears="point", tail="bushy",
                  eyes="eye_cyan", name="lupo_cinereo")
    for sx in (-1, 1):                                            # orecchie grandi a punta
        r.part("head", "cone", (1.3, 0.8, 2.4), (sx * 1.7, -0.3, 3.6), mat="fur_cinereo", rot=(-8, sx * 14, 0))
    r.part("head", "ellipsoid", (2.0, 1.6, 1.6), (0, 0.9, -1.6), mat="fur_white")          # guance e gola chiare
    r.part("hips", "ellipsoid", (3.0, 2.2, 2.6), (0, 4.6, 1.8), mat="fur_white")           # gorgiera sul petto
    r.part("head", "ellipsoid", (0.7, 0.6, 0.55), (0, 2.8 + 3.4 * 0.95, -0.4), mat="iron")  # naso
    return r


# --- pet: capra lunare -----------------------------------------------------------------------------------------
def capra():
    """Manto argento (ombre fredde, luci crema: il lupo e' scuro, Enel quasi nero), muso lungo e scuro, corna
    scure ad arco all'indietro, orecchie di lato, barbetta, segno ciano sulla fronte (come gli occhi del lupo)."""
    r = quadruped(body_mat="fur_lunare", belly="fur_white", legs_mat="fur_grey", snout=3.0, ears="none",
                  tail="stub", eyes="eye", bulk=0.9, head=0.8, name="capra_lunare")
    r.part("head", "ellipsoid", (1.25, 1.5, 1.15), (0, 5.4, -0.9), mat="fur_black")             # muso scuro
    r.part("head", "ellipsoid", (0.55, 0.6, 1.2), (0, 4.6, -2.4), mat="fur_black")            # barbetta
    for sx in (-1, 1):
        r.part("head", "ellipsoid", (1.5, 0.6, 0.5), (sx * 2.6, -0.2, 1.1), mat="fur_lunare")    # orecchie di lato
        # corna ad arco: tratti in catena dalla fronte, ognuno piu' inclinato all'indietro (rot x positiva =
        # verso la nuca; cilindri e coni hanno mezza altezza come terzo valore)
        punto = np.array([sx * 0.8, 0.6, 1.8])
        for gradi, lungo, raggio, forma in ((12, 2.0, 0.5, "cylinder"), (50, 1.8, 0.42, "cylinder"),
                                            (95, 1.7, 0.36, "cone")):
            asse = np.array([sx * 0.12, -np.sin(np.radians(gradi)), np.cos(np.radians(gradi))])
            r.part("head", forma, (raggio, raggio, lungo / 2), tuple(punto + asse * lungo / 2), mat="corno",
                   rot=(gradi, 0, 0))
            punto = punto + asse * lungo
    r.part("head", "ellipsoid", (0.6, 0.35, 0.6), (0, 1.7, 2.3), mat="glow_cyan")             # segno sulla fronte
    return r


def quad_hurt(n=3):
    """Rinculo: il colpo spinge indietro, muso in alto, coda tesa; poi torna."""
    colpo = {"hips": (-9, 0, 6, 0, -1.3, 0.2), "head": (-16, 0, 6), "tail": (25, 0, 0),
             "leg_fl": (18, 0, 0), "leg_fr": (12, 0, 0)}
    return clip_from_keys([(0, colpo, "out"), (1, add_pose(colpo, {"hips": (4, 0, -2, 0, 0.5, -0.1)})), (n - 1, {})], n)


def quad_morte(n=6, verso=1):
    """Non direzionale: si vede di profilo (girato di 90 gradi), cade sul fianco e resta a terra. Vista di fronte la
    caduta era una macchia, e la caduta di forge3d affondava il corpo sotto il terreno."""
    keys = [(0, {"hips": (0, 0, 90)}),
            (2, {"hips": (0, verso * 25, 90, 0, 0, -1.2), "head": (10, 0, 0)}, "in"),
            (n - 1, {"hips": (0, verso * 85, 90, 0, 0, -2.9), "head": (14, 0, 0), "leg_fl": (20, 0, 0),
                     "leg_bl": (-20, 0, 0), "leg_fr": (30, 0, 0), "leg_br": (-10, 0, 0), "tail": (-30, 0, 0)}, "out")]
    return clip_from_keys(keys, n)


# --- pet: corvo veggente ----------------------------------------------------------------------------------------
def corvo():
    """Piume nere grigio-blu (Enel e' nero-prugna) col bordo di luce, becco e zampe grigio ferro, occhi gialli.
    Vola: il corpo sta sopra l'origine e l'ombra del gioco resta a terra."""
    return bird(body_mat="piume_corvo", beak="iron", eyes="eye_yellow", legs="iron", name="corvo_veggente")


CLIP_PET = {k: vivi(v) for k, v in dict(QUAD_CLIPS, hurt=quad_hurt, death=quad_morte).items()}

# specie di data/pets -> (rig, pixel per unita', clip, bordo di luce). Fogli pet_<id>_<animazione>.png, stessi
# tempi per tutte.
PET = {"lupo_cinereo": (lupo, 1.75, CLIP_PET, False), "capra_lunare": (capra, 1.75, CLIP_PET, False),
       "corvo_veggente": (corvo, 2.3, {k: vivi(v) for k, v in BIRD_CLIPS.items()}, True)}


def bordo_luce(path, colore=(0x8B, 0x9B, 0xB4), cella=64):
    """Revisione 1.1: il contorno che guarda la luce (vuoto sopra o a sinistra) diventa grigio ardesia: Enel resta
    quasi nero ma la sagoma si stacca dal fondo anche di notte."""
    a = np.array(Image.open(path).convert("RGBA"))
    m = a[..., 3] == 255
    su, sx = np.zeros_like(m), np.zeros_like(m)
    su[1:], sx[:, 1:] = m[:-1], m[:, :-1]
    su[::cella], sx[:, ::cella] = False, False                    # il bordo della cella conta come vuoto
    inchiostro = (a[..., 0] < 40) & (a[..., 1] < 40) & (a[..., 2] < 60)
    a[m & inchiostro & (~su | ~sx), :3] = colore
    Image.fromarray(a).save(path)


PIEDI = 54 / 64        # punto dei piedi nella cella, uguale per tutte le categorie (revisione 2.1: il gioco lo usera')

CATEGORIE = {
    # categoria: (rig, clip, pixel per unita', bordo di luce). Enel e nemico alti ~40-47 px su 64, il lupo ~30.
    "personaggio": (enel, CLIP_ENEL, 1.22, True),
    "nemico_base": (nemico, {k: vivi(v) for k, v in dict(A.CLIPS, death=morte_di_lato).items()}, 1.4, False),
    "pet": (None, None, None, False),                           # una voce per specie: vedi PET
}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--only", choices=list(CATEGORIE))
    a = ap.parse_args()
    spec = json.load(open(SPEC, encoding="utf-8"))
    for cat, (costruttore, clip, ppu, luce) in CATEGORIE.items():
        if a.only and a.only != cat:
            continue
        # nessuna ombra cotta: l'ombra a terra la compone il gioco (revisione 1.10, 2.2)
        # piedi a 54 px su 64 (PIEDI): sotto restano 10 px per zampe in avanti e corpi a terra
        voci = PET.items() if cat == "pet" else [("", (costruttore, ppu, clip, luce))]
        for aspetto, (costr, p, clip, luce) in voci:
            mancano = [n for n in spec[cat] if not n.startswith("_") and n not in clip]
            if mancano:
                sys.exit(f"{cat} {aspetto}: animazioni senza clip {mancano}")
            for path in export_spec(costr(), SPEC, cat, OUT, clip, ppu=p, shadow=False, foot=(0.5, PIEDI)):
                if aspetto:                                       # pet_<nome>.png -> pet_<specie>_<nome>.png
                    nuovo = os.path.join(OUT, os.path.basename(path).replace(cat + "_", f"{cat}_{aspetto}_", 1))
                    os.replace(path, nuovo)
                    path = nuovo
                if luce:
                    bordo_luce(path)
                print("  " + os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
