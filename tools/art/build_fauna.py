#!/usr/bin/env python3
"""
Fauna d'atmosfera (US-8B23): animali che non combattono e scappano quando arriva il giocatore. Una specie = un
aspetto della categoria "fauna" di data/animations.json (idle, fuga), stessi tempi per tutte; le celle sono di 32 px per
i piccoli e 64 per il cervo (il gioco legge la cella dal foglio e tiene la scala dei dati: i pixel hanno la stessa grana).

    python tools/art/build_fauna.py      # arte/sprite/ e assets/placeholder/fauna_<specie>_<animazione>.png

Cervo, lepre, uccello e farfalla dal motore 3D di forge3d (stessa luce, contorno da 1 px, niente ombra cotta: l'ombra
a terra la mette il gioco). Le lucciole sono punti di luce disegnati pixel per pixel. Nessun numero casuale: stessi
parametri, stessi PNG.
"""

import json
import os
import shutil
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_personaggi as BP  # noqa: E402
from forge3d.creatures import VOLO, bird, bird_walk, quad_walk  # noqa: E402
from forge3d.materials import E32  # noqa: E402
from forge3d.rig import Rig, clip_from_keys  # noqa: E402
from forge3d.sheets import export_spec  # noqa: E402

DEST = os.path.join(BP.ROOT, "assets", "placeholder")


# --- cervo: pascola a testa bassa, scappa al galoppo --------------------------------------------------------------
# Rotazioni (rx, ry, rz): rx positivo alza in avanti cio' che e' attaccato al giunto (muso, collo); negativo lo abbassa.
def cervo():
    """Zampe lunghe e sottili, corpo snello, collo, muso lungo, specchio bianco sul posteriore, palchi ramificati."""
    r = Rig("cervo")
    r.joint("hips", "root", (0, 0, 8.8))
    r.joint("neck", "hips", (0, 4.2, 1.0))
    r.joint("head", "neck", (0, 2.6, 5.0))                     # collo lungo, in avanti e in su
    r.joint("tail", "hips", (0, -5.0, 1.2))
    for nm, (x, y) in {"fl": (-1.4, 3.6), "fr": (1.4, 3.6), "bl": (-1.4, -3.4), "br": (1.4, -3.4)}.items():
        r.joint("leg_" + nm, "hips", (x, y, -0.8))
        r.joint("shin_" + nm, "leg_" + nm, (0, 0, -3.5))
        r.part("leg_" + nm, "ellipsoid", (0.8, 1.0, 2.3), (0, 0, -1.5), mat="fur_brown")
        r.part("shin_" + nm, "cylinder", (0.38, 0.42, 2.1), (0, 0, -2.2), mat="leather")
        r.part("shin_" + nm, "ellipsoid", (0.5, 0.6, 0.35), (0, 0.2, -4.3), mat="fur_black")
    r.part("hips", "ellipsoid", (2.3, 5.4, 2.4), (0, 0, 0.3), mat="fur_brown")
    r.part("hips", "ellipsoid", (1.7, 4.2, 1.0), (0, 0.2, -1.5), mat="fur_white")             # ventre
    r.part("hips", "ellipsoid", (1.6, 0.8, 1.6), (0, -5.0, 0.6), mat="fur_white")             # lo specchio
    r.part("neck", "ellipsoid", (1.0, 1.3, 3.2), (0, 1.3, 2.5), mat="fur_brown", rot=(-27, 0, 0))
    r.part("neck", "ellipsoid", (0.7, 0.8, 2.2), (0, 1.9, 2.0), mat="fur_white", rot=(-27, 0, 0))   # gola
    r.part("head", "ellipsoid", (1.15, 1.4, 1.15), (0, 0, 0), mat="fur_brown")
    r.part("head", "ellipsoid", (0.75, 1.5, 0.75), (0, 1.6, -0.4), mat="fur_brown")            # muso
    r.part("head", "ellipsoid", (0.45, 0.4, 0.4), (0, 3.0, -0.4), mat="fur_black")            # naso
    for sx in (-1, 1):
        r.part("head", "ellipsoid", (0.35, 0.35, 0.4), (sx * 0.95, 0.6, 0.35), mat="eye")
        r.part("head", "ellipsoid", (1.0, 0.3, 0.5), (sx * 1.6, -0.5, 0.9), mat="fur_brown", rot=(0, sx * -25, 0))
        # palco: un ramo che sale e piega all'indietro (rx positivo porta la cima indietro), due punte in avanti
        r.part("head", "cylinder", (0.28, 0.28, 1.6), (sx * 1.1, -1.2, 2.4), mat="cloth_cream", rot=(30, sx * 24, 0))
        r.part("head", "cylinder", (0.24, 0.24, 1.2), (sx * 1.8, -2.5, 3.9), mat="cloth_cream", rot=(55, sx * 14, 0))
        r.part("head", "cylinder", (0.2, 0.2, 0.75), (sx * 1.5, -0.9, 3.4), mat="cloth_cream", rot=(-25, sx * 18, 0))
        r.part("head", "cylinder", (0.18, 0.18, 0.7), (sx * 2.0, -2.8, 5.0), mat="cloth_cream", rot=(-5, sx * 20, 0))
    r.part("tail", "ellipsoid", (0.45, 0.5, 0.8), (0, -0.2, -0.4), mat="fur_white")
    return r


def cervo_idle(n=4):
    """Bruca: collo giu' fino all'erba, la testa che strappa, la coda che batte."""
    # il collo scende quasi dritto e il muso resta parallelo all'erba: di fronte la testa non esce dalla cella
    return [{"neck": (-135 - 5 * (i % 2), 0, 0), "head": (30 - 10 * (i % 2), 0, 0), "tail": (25 * (i % 2), 0, 0),
             "hips": (0, 0, 0, 0, 0, -0.3), "leg_fl": (-8, 0, 0), "leg_fr": (-8, 0, 0)} for i in range(n)]


def galoppo(n=6, stride=40):
    out = quad_walk(n, stride)
    for i, p in enumerate(out):
        s = np.sin(2 * np.pi * i / n)
        p["hips"] = (5 * s, 0, 0, 0, 0, 1.0 * abs(s))               # il corpo si alza nel salto
        p["neck"] = (-25 - 8 * s, 0, 0)                            # collo teso in avanti
        p["head"] = (10, 0, 0)
        p["tail"] = (60, 0, 0)                                     # la coda bianca alzata: il segnale di fuga
    return out


# --- lepre: seduta con le orecchie dritte, scappa a balzi ---------------------------------------------------------
def lepre():
    """Corpo a uovo, zampe dietro grandi, orecchie lunghe con la punta nera, codino bianco."""
    r = Rig("lepre")
    r.joint("hips", "root", (0, 0, 3.0))
    r.joint("head", "hips", (0, 2.8, 2.0))
    r.joint("tail", "hips", (0, -2.9, 0.6))
    r.part("hips", "ellipsoid", (1.7, 3.0, 1.9), (0, -0.4, 0.2), mat="fur_brown")
    r.part("hips", "ellipsoid", (1.4, 1.5, 1.6), (0, 1.6, 0.6), mat="fur_brown")             # petto
    r.part("hips", "ellipsoid", (1.2, 2.2, 0.9), (0, 0.2, -1.0), mat="fur_white")            # ventre
    r.part("head", "ellipsoid", (1.05, 1.35, 1.05), (0, 0.2, 0.1), mat="fur_brown")
    r.part("head", "ellipsoid", (0.6, 0.6, 0.5), (0, 1.4, -0.3), mat="fur_white")            # muso
    for sx, lato in ((-1, "l"), (1, "r")):
        r.part("head", "ellipsoid", (0.3, 0.3, 0.35), (sx * 0.8, 0.7, 0.35), mat="eye")
        e = r.joint("ear_" + lato, "head", (sx * 0.4, -0.3, 0.8))
        r.part(e, "ellipsoid", (0.38, 0.22, 1.9), (sx * 0.15, 0, 1.7), mat="fur_brown", rot=(0, sx * 8, 0))
        r.part(e, "ellipsoid", (0.3, 0.2, 0.45), (sx * 0.4, 0, 3.4), mat="fur_black", rot=(0, sx * 8, 0))
        f = r.joint("leg_f" + lato, "hips", (sx * 0.7, 2.0, -0.8))
        r.part(f, "ellipsoid", (0.38, 0.45, 1.2), (0, 0.1, -1.0), mat="fur_brown")
        b = r.joint("leg_b" + lato, "hips", (sx * 1.1, -1.4, -0.2))
        r.part(b, "ellipsoid", (0.8, 1.4, 1.1), (0, 0.2, -0.5), mat="fur_brown")             # coscia
        r.part(b, "ellipsoid", (0.45, 1.3, 0.35), (0, 0.9, -2.2), mat="fur_brown")           # piede lungo
    r.part("tail", "ellipsoid", (0.6, 0.55, 0.6), (0, -0.2, 0.2), mat="fur_white")
    return r


def lepre_idle(n=4):
    """Seduta: il davanti alto, le zampe dietro raccolte; un orecchio si gira e torna."""
    seduta = {"hips": (24, 0, 0, 0, 0, -0.2), "head": (-18, 0, 0), "leg_bl": (-24, 0, 0), "leg_br": (-24, 0, 0),
              "leg_fl": (-24, 0, 0), "leg_fr": (-24, 0, 0)}
    return [dict(seduta, ear_l=(0, 0, 0), ear_r=(-20 * (i % 2), 0, 25 * (i % 2)), head=(-18 + 4 * (i % 2), 0, 0))
            for i in range(n)]


def lepre_fuga(n=6):
    """Balzo: raccolta, spinta con le zampe dietro distese, volo, atterraggio sulle zampe davanti."""
    orecchie = {"ear_l": (-22, 0, 0), "ear_r": (-22, 0, 0)}                 # appena all'indietro: restano lunghe
    raccolta = dict(orecchie, hips=(-6, 0, 0, 0, 0, -0.4), leg_bl=(30, 0, 0), leg_br=(30, 0, 0),
                    leg_fl=(-20, 0, 0), leg_fr=(-20, 0, 0))
    spinta = dict(orecchie, hips=(12, 0, 0, 0, 0.4, 0.6), leg_bl=(-60, 0, 0), leg_br=(-60, 0, 0),
                  leg_fl=(-50, 0, 0), leg_fr=(-50, 0, 0))
    volo = dict(orecchie, hips=(0, 0, 0, 0, 0.6, 1.4), leg_bl=(-70, 0, 0), leg_br=(-70, 0, 0),
                leg_fl=(55, 0, 0), leg_fr=(55, 0, 0))
    atterra = dict(orecchie, hips=(-12, 0, 0, 0, 0.3, 0.2), leg_fl=(30, 0, 0), leg_fr=(30, 0, 0),
                   leg_bl=(-30, 0, 0), leg_br=(-30, 0, 0))
    return clip_from_keys([(0, raccolta), (1, spinta, "out"), (3, volo), (4, atterra, "in"), (n - 1, raccolta)], n)


# --- uccello: a terra becchetta, vola via ------------------------------------------------------------------------
def uccello():
    """Un passero: dorso bruno, petto chiaro, ali piu' scure, becco giallo. Stessi giunti di forge3d bird()."""
    r = bird(body_mat="fur_brown", beak="gold", eyes="eye", legs="iron", size=0.75, name="passero")
    r.part("body", "ellipsoid", (1.4, 2.0, 1.25), (0, 1.2, -0.75), mat="cloth_cream")         # petto
    r.part("head", "ellipsoid", (1.0, 0.8, 0.5), (0, 0.8, -0.5), mat="cloth_cream")          # gola
    for lato, sx in (("l", -1), ("r", 1)):
        r.part("wing_" + lato, "ellipsoid", (1.7, 1.05, 0.3), (sx * 1.7, -0.45, 0.14), mat="leather_dark")
    return r


A_TERRA = -VOLO + 3.0          # il corpo scende finche' le zampette toccano terra


def uccello_idle(n=4):
    """A terra, petto in fuori (rx positivo alza il davanti), ali chiuse sul dorso, coda giu'; ogni due frame si
    piega a beccare."""
    # ali girate all'indietro lungo il fianco, punte risvoltate (girate verso il basso finivano sotto terra)
    chiuse = {"wing_l": (0, -15, 85), "wing_r": (0, 15, -85), "tip_l": (0, 0, 150), "tip_r": (0, 0, -150),
              "leg_l": (20, 0, 0), "leg_r": (20, 0, 0)}
    return [dict(chiuse, body=(32 - 50 * (i % 2), 0, 0, 0, 0, A_TERRA), head=(-10 - 30 * (i % 2), 0, 0),
                 tail=(-35 + 30 * (i % 2), 0, 0), leg_l=(20 + 50 * (i % 2), 0, 0), leg_r=(20 + 50 * (i % 2), 0, 0))
            for i in range(n)]


def uccello_fuga(n=6):
    return bird_walk(n)


# --- farfalla: ali che si aprono piano, poi battito veloce -------------------------------------------------------
def farfalla():
    """Corpo sottile, due paia d'ali (le anteriori piu' grandi), antenne. Sta a mezz'aria sopra l'origine."""
    r = Rig("farfalla")
    r.joint("body", "root", (0, 0, 6.0))
    r.part("body", "cylinder", (0.35, 0.35, 1.3), (0, 0, 0), mat="fur_black", rot=(90, 0, 0))
    for sx, lato in ((-1, "l"), (1, "r")):
        a = r.joint("ala_" + lato, "body", (sx * 0.3, 0, 0.1))
        r.part(a, "ellipsoid", (1.9, 1.5, 0.12), (sx * 1.8, 0.6, 0), mat="cloth_orange")
        r.part(a, "ellipsoid", (1.0, 0.8, 0.14), (sx * 2.4, 1.0, 0.05), mat="fur_black")     # punta scura
        r.part(a, "ellipsoid", (1.4, 1.1, 0.12), (sx * 1.3, -0.9, 0), mat="cloth_yellow")
        r.part("body", "cylinder", (0.1, 0.1, 0.8), (sx * 0.35, 1.8, 0.6), mat="fur_black", rot=(-50, sx * 20, 0))
    return r


def _battito(a):
    return {"ala_l": (0, a, 0), "ala_r": (0, -a, 0)}


CABRATA = -55                   # inclinata verso la camera: nella vista di fronte le ali aperte si vedono intere, dal dritto


def farfalla_idle(n=4):
    return [dict(_battito((10, 45, 75, 45)[i % 4]), body=(CABRATA, 0, 0, 0, 0, 0.3 * (i % 2))) for i in range(n)]


def farfalla_fuga(n=6):
    return [dict(_battito(80 * np.cos(2 * np.pi * i / n) - 10), body=(CABRATA, 0, 0, 0, 0, 0.6 * np.sin(2 * np.pi * i / n)))
            for i in range(n)]


# --- lucciola: punti di luce che pulsano (non un modello 3D) -----------------------------------------------------
GIALLO, VERDE, VERDE_SCURO = (E32["yellow"], E32["green"], E32["green_m"])
PUNTI = [(9, 10, 0), (21, 6, 1), (15, 17, 2)]          # (x, y, fase): tre lucciole sfasate in una cella di 32
LUCE = [0, 1, 2, 1, 0, 0]                              # 0 spenta (un puntino verde scuro), 1 accesa, 2 piena


def _hex(c):
    return tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def lucciole(frames, righe=4, cella=32):
    img = np.zeros((cella * righe, cella * frames, 4), np.uint8)
    for f in range(frames):
        for x, y, fase in PUNTI:
            livello = LUCE[(f * 2 + fase * 2) % len(LUCE)]
            dx, dy = (f + fase) % 2, -((f + fase) // 2 % 2)          # una deriva di un pixel
            for r in range(righe):
                cx, cy = f * cella + x + dx, r * cella + y + dy
                img[cy, cx] = _hex(VERDE_SCURO if livello == 0 else GIALLO)
                if livello >= 1:
                    for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        img[cy + oy, cx + ox] = _hex(VERDE if livello == 2 else VERDE_SCURO)
    return Image.fromarray(img, "RGBA")


# specie: (rig, pixel per unita', cella, clip idle, clip fuga)
SPECIE = {
    "cervo": (cervo, 2.0, 64, cervo_idle, galoppo),
    "lepre": (lepre, 1.9, 32, lepre_idle, lepre_fuga),
    "uccello": (uccello, 2.0, 32, uccello_idle, uccello_fuga),
    "farfalla": (farfalla, 1.6, 32, farfalla_idle, farfalla_fuga),
}


def main():
    spec = json.load(open(BP.SPEC, encoding="utf-8"))["fauna"]
    nomi = [n for n in spec if not n.startswith("_")]
    assert nomi == ["idle", "fuga"], nomi
    os.makedirs(DEST, exist_ok=True)
    tmp = tempfile.mkdtemp()                       # export_spec scrive fauna_<nome>.png: una specie alla volta
    for specie, (rig, ppu, cella, idle, fuga) in SPECIE.items():
        clip = {"idle": BP.vivi(idle), "fuga": BP.vivi(fuga)}
        for path in export_spec(rig(), BP.SPEC, "fauna", tmp, clip, size=(cella, cella), ppu=ppu, shadow=False,
                                foot=(0.5, BP.PIEDI)):
            nuovo = os.path.join(BP.OUT, os.path.basename(path).replace("fauna_", f"fauna_{specie}_", 1))
            os.replace(path, nuovo)
            shutil.copy(nuovo, os.path.join(DEST, os.path.basename(nuovo)))
            print("  " + os.path.relpath(nuovo, BP.ROOT))
    shutil.rmtree(tmp)
    for nome in nomi:
        path = os.path.join(BP.OUT, f"fauna_lucciola_{nome}.png")
        lucciole(spec[nome]["frames"]).save(path)
        shutil.copy(path, os.path.join(DEST, os.path.basename(path)))
        print("  " + os.path.relpath(path, BP.ROOT))


if __name__ == "__main__":
    main()
