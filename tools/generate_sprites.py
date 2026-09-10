#!/usr/bin/env python3
"""
Genera pixel art procedurale per personaggio/nemico/pet a partire dalla
geometria di data/animations.json (US-812, fase 8 Blocco E).

    python tools/generate_sprites.py

Grafica PROVVISORIA generata, non arte disegnata a mano (arte/03_sprite_e_
animazioni.md). Deterministico (nessun random non seedato: SEED fisso qui
sotto) — stesso output a ogni run, cosi' il diff resta silenzioso quando
non cambia nulla.

Stile: pixel art 32x32 a strati (ombra, gambe, corpo, braccia, testa,
copricapo, arma/accento), un outline 1px inchiostro per ogni forma (arte/03
chiede 2px: a 32px un bordo 2px mangia troppo dettaglio per un personaggio
alto ~24px — 1px e' la scelta di questo tool, motivata anche in arte/03).
Palette FISSA per personaggio/nemico/pet (non una delle 10 palette di
Pathway di arte/04): "sono i VFX a dire il Pathway, non il cappotto"
(CLAUDE.md/AC di US-812). Le 3 palette qui sotto seguono comunque la
disciplina inchiostro+primario+accento di arte/04, solo con valori propri
invece di uno dei 10 Pathway. Estensione "luci/particellari" (richiesta
esplicita dell'utente oltre all'AC originale, 2026-09-10): un rim-light sul
lato acceso delle forme a colore primario, un bagliore a 2-3px di falloff
per il tell/la finestra di parata perfetta invece di un pixel netto, e
particelle deterministiche sull'ultimo frame di cast.

Richiede Pillow:  pip install pillow
"""

import json
import math
import os
import sys
import zlib

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Serve Pillow: pip install pillow", file=sys.stderr)
    sys.exit(1)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SPEC = os.path.join(ROOT, "data", "animations.json")
OUT = os.path.join(ROOT, "assets", "placeholder")

SEED = 20260910
DIM = 32

# --- Palette fisse (inchiostro + primario + accento, disciplina di arte/04,
# valori propri: NON una delle 10 palette di Pathway) -----------------------
INCHIOSTRO = (12, 11, 14)

PERSONAGGIO = {
    "primario": (58, 74, 92),      # cappotto blu ardesia
    "primario_ombra": (40, 52, 66),
    "accento": (196, 122, 74),     # sciarpa, accento caldo
    "pelle": (198, 168, 138),
    "copricapo": (34, 40, 50),     # berretto piatto, piu' scuro del cappotto
}
NEMICO = {
    "primario": (108, 106, 98),    # tonaca grigio cenere
    "primario_ombra": (78, 76, 70),
    "accento": (120, 168, 74),     # accento verde malato
    "pelle": None,                  # incappucciato: niente pelle in vista
    "copricapo": (58, 56, 52),      # cappuccio
}
PET = {
    "primario": (120, 88, 58),     # pelo del segugio
    "primario_ombra": (92, 66, 42),
    "accento": (196, 122, 74),
    "pelle": None,
    "copricapo": None,
}
PALETTE_PER_CATEGORIA = {"personaggio": PERSONAGGIO, "nemico_base": NEMICO, "pet": PET}

DIR_ORDER = ["down", "up", "left", "right"]


def _lighten(c, amt):
    return tuple(int(v + (255 - v) * amt) for v in c)


def _darken(c, amt):
    return tuple(int(v * (1.0 - amt)) for v in c)


def _rgba(c):
    return c if len(c) == 4 else c + (255,)


def _shape_poly(d, points, fill, outline=INCHIOSTRO):
    d.polygon(points, fill=_rgba(fill), outline=_rgba(outline) if outline is not None else None)


def _shape_rect(d, box, fill, outline=INCHIOSTRO):
    x0, y0, x1, y1 = box
    box = [min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)]
    d.rectangle(box, fill=_rgba(fill), outline=_rgba(outline) if outline is not None else None)


def _shape_ellipse(d, box, fill, outline=INCHIOSTRO):
    x0, y0, x1, y1 = box
    box = [min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)]
    d.ellipse(box, fill=_rgba(fill), outline=_rgba(outline) if outline is not None else None)


def _glow(d, cx, cy, r, color, intensity):
    """Bagliore morbido a 2px di caduta (non un pixel netto): un nucleo
    pieno e chiaro (sempre leggibile, qualunque sia lo sfondo) + 2 anelli
    semitrasparenti intorno. ImageDraw in Pillow SOVRASCRIVE i pixel (non
    li fonde) fra piu' disegni sulla stessa immagine: gli anelli piu'
    grandi e piu' deboli vanno disegnati PRIMA, il nucleo pieno per
    ultimo, altrimenti l'ultimo anello (il piu' debole) sovrascrive il
    nucleo appena disegnato e il bagliore sparisce."""
    if intensity <= 0.0:
        return
    rr0 = max(1, r)
    for i, mul in ((2, 0.22), (1, 0.45)):
        rr = rr0 + i
        a = int(200 * intensity * mul)
        if a <= 0:
            continue
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=color + (a,))
    nucleo = _lighten(color, 0.6)
    d.ellipse([cx - rr0, cy - rr0, cx + rr0, cy + rr0], fill=nucleo + (255,))


def _particelle(img, cx, cy, color, seed):
    """3-4 pixel singoli intorno al centro, offset deterministici dal seed
    (US-812, estensione 'particellari veri'): mai random non seedato."""
    px = img.load()
    offsets = [(-5, -3), (4, -5), (-3, 4), (5, 2)]
    n = 3 + (seed % 2)
    for i in range(n):
        ox, oy = offsets[(seed + i) % len(offsets)]
        x, y = int(cx + ox), int(cy + oy)
        if 0 <= x < img.width and 0 <= y < img.height:
            px[x, y] = color + (255,)


def _rim_light(d, points, color):
    """Una polilinea sottile lungo il bordo illuminato (sinistra/alto) di
    una forma: sostituisce lo shading piatto con un bordo acceso."""
    if len(points) >= 2:
        d.line(points, fill=color + (200,), width=1)


# --- Pose: da (categoria, nome animazione, spec, indice frame) a un
# dizionario di parametri di posa, in [0,1]/booleani. Nessun caso speciale
# per Pathway o personaggio: solo categorie/nomi di animazione (vocabolario
# chiuso di data/animations.json). ------------------------------------------

def _pose_for(cat, name, anim, frame, n_frames):
    t = frame / max(1, n_frames - 1)
    p = {
        "bob": 0.0, "stride": 0.0, "lean": 0.0, "arm": 0.0, "guard": False,
        "weapon": False, "glow": 0.0, "crouch": 0.0, "fallen": 0.0,
        "seated": False, "perfetta": False,
    }
    if name == "idle":
        p["bob"] = 0.15 * math.sin(t * 2 * math.pi)
    elif name == "walk":
        p["stride"] = math.sin(t * 2 * math.pi)
    elif name == "dash":
        p["lean"] = 0.6
        p["stride"] = math.sin(t * 2 * math.pi) * 1.3
    elif name in ("attack_light", "attack_heavy"):
        anticipo = set(anim.get("anticipo", []))
        attivi = set(anim.get("attivi", []))
        if frame in anticipo:
            p["arm"] = -0.6
            p["weapon"] = True
        elif frame in attivi:
            p["arm"] = 1.0
            p["lean"] = 0.3
            p["weapon"] = True
        else:
            p["arm"] = 0.2
            p["weapon"] = True
    elif name == "anticipo":  # nemico: il tell, acceso dal frame 0 (FR-8)
        p["arm"] = min(1.0, (frame + 1) / n_frames)
        p["glow"] = min(1.0, (frame + 1) / n_frames)
    elif name == "attack" and cat in ("nemico_base", "pet"):
        attivi = set(anim.get("attivi", []))
        p["arm"] = 1.0 if frame in attivi else 0.5
        p["weapon"] = frame in attivi
    elif name == "parry":
        fp = set(anim.get("finestra_perfetta", []))
        p["guard"] = True
        p["perfetta"] = frame in fp
        p["glow"] = 1.0 if frame in fp else 0.3
    elif name == "hurt":
        p["crouch"] = 0.5
        p["lean"] = -0.3
    elif name == "stagger":
        p["crouch"] = 0.4
        p["bob"] = 0.1 * math.sin(t * 4 * math.pi)
    elif name == "death":
        p["fallen"] = t
    elif name == "cast":
        p["arm"] = 1.0
        p["glow"] = t
    elif name == "meditate":
        p["seated"] = True
        p["arm"] = 0.05 * math.sin(t * 2 * math.pi)
    return p


def _draw_quadrupede(img, pal, direzione, pose, seed):
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = DIM // 2, DIM // 2 + 4
    bob = pose["bob"] * 3.0
    stride = pose["stride"] * 3.0
    crouch = pose["crouch"] * 3.0
    facing = -1 if direzione == "left" else 1  # right = specchio di left

    _shape_ellipse(d, [cx - 7, cy + 6, cx + 7, cy + 9], (0, 0, 0, 60), outline=None)

    # zampe (2 visibili, di profilo/3-quarti in ogni direzione)
    for side in (-1, 1):
        lx = cx + side * 4 + stride * side * 0.4
        _shape_rect(d, [lx - 1, cy - 1, lx + 1, cy + 7 + crouch], pal["primario_ombra"])

    # corpo
    body_y = cy - 6 + bob + crouch * 0.5
    _shape_ellipse(d, [cx - 9, body_y - 4, cx + 9 * facing + (0 if facing == 1 else 0), body_y + 4],
                    pal["primario"])
    _rim_light(d, [(cx - 8, body_y - 3), (cx - 3, body_y - 5)], _lighten(pal["primario"], 0.5))

    # testa + muso, orientata per direzione
    hx = cx + facing * 8 if direzione in ("left", "right") else cx
    hy = body_y - 2 if direzione != "up" else body_y - 4
    _shape_ellipse(d, [hx - 4, hy - 4, hx + 4, hy + 4], pal["primario"])
    muso_dx = facing * 5 if direzione in ("left", "right") else (0 if direzione == "up" else 0)
    muso_dy = 0 if direzione in ("left", "right") else (-2 if direzione == "up" else 3)
    _shape_ellipse(d, [hx + muso_dx - 2, hy + muso_dy - 2, hx + muso_dx + 2, hy + muso_dy + 2],
                    pal["primario_ombra"])
    # orecchie
    _shape_poly(d, [(hx - 3, hy - 4), (hx - 5, hy - 8), (hx - 1, hy - 5)], pal["primario_ombra"])
    _shape_poly(d, [(hx + 3, hy - 4), (hx + 5, hy - 8), (hx + 1, hy - 5)], pal["primario_ombra"])

    # coda
    tail_dx = -facing * 6 if direzione in ("left", "right") else 0
    tail_dy = -6 if direzione == "down" else (6 if direzione == "up" else -3)
    _shape_poly(d, [(cx, body_y), (cx + tail_dx, body_y + tail_dy),
                     (cx + tail_dx * 0.6, body_y + tail_dy * 0.6 - 2)], pal["primario_ombra"])

    if pose["weapon"] or pose["arm"] > 0.6:
        _glow(d, hx + muso_dx, hy + muso_dy, 2, pal["accento"], min(1.0, pose["arm"]))


def _draw_umanoide(img, cat, pal, direzione, pose, seed):
    d = ImageDraw.Draw(img, "RGBA")
    cx = DIM // 2
    facing = -1 if direzione == "left" else 1  # right = specchio esatto di left
    laterale = direzione in ("left", "right")

    fallen = pose["fallen"]
    bob = pose["bob"] * 2.0
    lean = pose["lean"] * 3.0
    stride = pose["stride"] * 3.0
    crouch = pose["crouch"] * 2.0
    seat = 4.0 if pose["seated"] else 0.0

    piedi_y = DIM - 5 - seat
    testa_y = 8 + bob + crouch + seat * 1.5 - fallen * 10
    corpo_alto = testa_y + 4
    corpo_basso = piedi_y - 6 + fallen * 8

    rot = fallen * 18  # il corpo "si piega" verso terra quando muore

    # ombra
    _shape_ellipse(d, [cx - 8, DIM - 5, cx + 8, DIM - 2], (0, 0, 0, 70), outline=None)

    # gambe (o, seduto, niente gambe in vista sotto il corpo)
    if not pose["seated"]:
        for side in (-1, 1):
            dx = side * 3 + (stride * side if not laterale else stride * 0.5)
            lx = cx + dx + lean * 0.3 + facing * 0 - fallen * facing * 6
            top = corpo_basso - 2
            bot = piedi_y + (2 if (side < 0) != (pose["stride"] > 0) else -1)
            _shape_rect(d, [lx - 2, top, lx + 2, bot], pal["primario_ombra"])

    # corpo (torso): un parallelogramma leggero per il lean/caduta
    ox = lean + facing * (2 if laterale else 0) - fallen * facing * 10
    oy = fallen * 10
    corpo_pts = [
        (cx - 7 + ox * 0.3, corpo_alto + oy - rot * 0.2),
        (cx + 7 + ox, corpo_alto + oy + rot * 0.2),
        (cx + 6 + ox, corpo_basso + oy),
        (cx - 6 + ox * 0.3, corpo_basso + oy),
    ]
    _shape_poly(d, corpo_pts, pal["primario"])
    _rim_light(d, [(cx - 6 + ox * 0.3, corpo_alto + oy + 1), (cx - 5 + ox * 0.3, corpo_basso + oy - 1)],
               _lighten(pal["primario"], 0.55))
    if cat == "personaggio":
        # sciarpa: una fascia dell'accento sul petto
        _shape_rect(d, [cx - 4 + ox, corpo_alto + oy + 2, cx + 4 + ox, corpo_alto + oy + 5],
                    pal["accento"])

    # braccia: angolo secondo pose["arm"] (-1 arretrato .. 1 alzato)
    spalla_x = cx + ox
    spalla_y = corpo_alto + oy + 2
    for side in (-1, 1):
        if laterale and side != facing and not pose["guard"]:
            continue  # braccio lontano nascosto dal corpo in vista laterale
        ang = (pose["arm"] * 70) * (1 if side == facing or not laterale else 0.4)
        rad = math.radians(90 - ang) if side > 0 else math.radians(90 + ang)
        length = 9
        ex = spalla_x + side * 2 + math.cos(rad) * length * 0.5
        ey = spalla_y - math.sin(rad) * length * 0.6 + (2 if pose["guard"] else 0)
        _shape_rect(d, [min(spalla_x + side * 1, ex) - 1, min(spalla_y, ey) - 1,
                         max(spalla_x + side * 1, ex) + 1, max(spalla_y, ey) + 1],
                    pal["primario_ombra"])
        if pose["weapon"] and side == facing:
            wx, wy = ex + facing * 5, ey - 3
            _shape_poly(d, [(ex, ey), (wx, wy), (wx + facing * 2, wy - 2)],
                        (150, 150, 158), outline=INCHIOSTRO)

    # testa: di spalle (direzione "up") si vede la nuca/il retro del
    # copricapo, mai il volto.
    hx, hy = cx + ox * 0.6, testa_y + oy
    di_spalle = direzione == "up"
    colore_testa = pal["copricapo"] if (di_spalle and pal["copricapo"]) else pal["pelle"]
    _shape_ellipse(d, [hx - 4, hy - 4, hx + 4, hy + 4], colore_testa or pal["primario_ombra"])

    # copricapo (berretto piatto / cappuccio)
    if pal["copricapo"] is not None:
        if cat == "personaggio":
            _shape_poly(d, [(hx - 4, hy - 2), (hx + 4, hy - 2), (hx + 5, hy - 4), (hx - 3, hy - 5)],
                        pal["copricapo"])
        else:  # cappuccio: copre quasi tutta la testa, ombra sul volto
            _shape_ellipse(d, [hx - 5, hy - 5, hx + 5, hy + 3], pal["copricapo"])
            _shape_ellipse(d, [hx - 2, hy - 1, hx + 2, hy + 2], _darken(pal["copricapo"], 0.6),
                            outline=None)

    # guardia alta (parry): un accento davanti al petto, MAI davanti al volto
    guardia_x, guardia_y = cx + ox + facing * 4, corpo_alto + oy + 3
    if pose["guard"]:
        colore = pal["accento"] if pose["perfetta"] else _darken(pal["accento"], 0.3)
        _shape_rect(d, [guardia_x - 1, guardia_y - 4, guardia_x + 1, guardia_y + 4], colore)

    # bagliore/tell + particelle (US-812, luci/particellari): piccolo apposta
    # e MAI sopra il volto — sulla guardia per parry, sulla mano per cast/
    # attacco, sopra le braccia alzate per il tell del nemico.
    if pose["glow"] > 0.0:
        if pose["guard"]:
            gx, gy = guardia_x, guardia_y
        elif cat == "nemico_base":
            gx, gy = hx + facing * 4, hy + 4
        else:
            gx, gy = spalla_x + facing * 4, spalla_y + 2
        _glow(d, gx, gy, 1, pal["accento"], pose["glow"])
        if pose["glow"] >= 0.99:
            _particelle(img, gx, gy, pal["accento"], seed)


def build_frame(cat, direzione, pose, seed):
    """'right' e' SEMPRE lo specchio esatto di 'left' (convenzione 4
    direzioni di CLAUDE.md) — garantito per costruzione: disegna 'left' e
    ribalta l'immagine, invece di fidarsi che la matematica delle pose
    (offset di lean/facing/particelle deterministiche) resti simmetrica a
    mano. Coordinate/polilinee scritte a occhio non garantiscono un
    mirror pixel-esatto (scoperto e corretto in US-812 controllando i
    pixel, non solo guardando lo sprite)."""
    if direzione == "right":
        return build_frame(cat, "left", pose, seed).transpose(Image.FLIP_LEFT_RIGHT)
    img = Image.new("RGBA", (DIM, DIM), (0, 0, 0, 0))
    pal = PALETTE_PER_CATEGORIA[cat]
    if pal.get("_quadrupede"):
        _draw_quadrupede(img, pal, direzione, pose, seed)
    else:
        _draw_umanoide(img, cat, pal, direzione, pose, seed)
    return img


PET["_quadrupede"] = True


def main():
    with open(SPEC, encoding="utf-8") as fh:
        spec = json.load(fh)

    size = tuple(spec["convenzioni"]["dimensione_frame"])
    assert size == (DIM, DIM), "dimensione_frame di animations.json non e' 32x32: il generatore e' fisso a 32"
    direzioni = spec["convenzioni"]["direzioni"]
    os.makedirs(OUT, exist_ok=True)

    fogli = 0
    for cat in ("personaggio", "nemico_base", "pet"):
        anims = {k: v for k, v in spec.get(cat, {}).items() if not k.startswith("_")}
        for name, anim in anims.items():
            dirs = direzioni if anim.get("direzionale") else ["down"]
            n_frames = int(anim["frames"])
            sheet = Image.new("RGBA", (size[0] * n_frames, size[1] * len(dirs)), (0, 0, 0, 0))
            for row, direzione in enumerate(dirs):
                for i in range(n_frames):
                    pose = _pose_for(cat, name, anim, i, n_frames)
                    # zlib.crc32, mai hash() built-in: hash() su stringhe non
                    # e' deterministico fra run diversi (PYTHONHASHSEED).
                    seed = SEED + zlib.crc32(f"{cat}:{name}:{i}".encode()) % 997
                    frame = build_frame(cat, direzione, pose, seed)
                    sheet.paste(frame, (i * size[0], row * size[1]), frame)
            path = os.path.join(OUT, f"{cat}_{name}.png")
            sheet.save(path)
            fogli += 1

    print(f"OK: {fogli} fogli sprite generati in assets/placeholder/ "
          f"(attesi 19: 10 personaggio + 6 nemico_base + 3 pet).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
