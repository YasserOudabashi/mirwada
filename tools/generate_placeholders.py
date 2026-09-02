#!/usr/bin/env python3
"""
Genera spritesheet placeholder REALI da data/animations.json.

    python tools/generate_placeholders.py

Non sono quadrati colorati a caso: rispettano la specifica delle animazioni
(numero di frame, direzioni) e disegnano a schermo le informazioni che servono
per tarare il combattimento senza arte definitiva:

  - il numero del frame, per contare a occhio la durata reale
  - il bordo ROSSO sui frame con hitbox attiva
  - il bordo GIALLO sui frame di anticipo (il tell)
  - il bordo CIANO sui frame di invulnerabilita' del dash
  - il bordo VERDE sui frame della finestra di parata perfetta
  - una tacca che indica la direzione

Questo permette di chiudere le fasi 1-4 senza un pixel artist, e di tarare
i frame di attacco guardando lo schermo invece di leggere il codice.
Quando l'arte vera arriva, i file si sostituiscono uno a uno: la specifica in
data/animations.json non cambia.

Richiede Pillow:  pip install pillow
"""

import json
import os
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Serve Pillow: pip install pillow", file=sys.stderr)
    sys.exit(1)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SPEC = os.path.join(ROOT, "data", "animations.json")
OUT = os.path.join(ROOT, "assets", "placeholder")

# Colori base per categoria: distinguibili a colpo d'occhio anche in movimento.
BODY = {
    "personaggio": (90, 140, 200),
    "nemico_base": (190, 80, 80),
    "pet": (110, 180, 110),
}
DIR_OFFSET = {"down": (0, 1), "up": (0, -1), "left": (-1, 0), "right": (1, 0)}

# Bordi diagnostici. L'ordine conta: il primo che matcha vince.
BORDERS = [
    ("attivi", (255, 40, 40)),            # hitbox attiva
    ("anticipo", (255, 210, 40)),         # tell / wind-up
    ("finestra_perfetta", (60, 230, 90)),  # parata perfetta
    ("recupero", (150, 150, 150)),        # recovery
]

DIGITS = {
    "0": ["111", "101", "101", "101", "111"],
    "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"],
    "3": ["111", "001", "111", "001", "111"],
    "4": ["101", "101", "111", "001", "001"],
    "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"],
    "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"],
    "9": ["111", "101", "111", "001", "111"],
}


def draw_digit(px, ch, ox, oy, color):
    """Cifra 3x5 disegnata a mano: un font TTF a 32px sarebbe illeggibile."""
    for y, row in enumerate(DIGITS.get(ch, DIGITS["0"])):
        for x, bit in enumerate(row):
            if bit == "1":
                px[ox + x, oy + y] = color


def frame_border(anim, idx):
    for key, color in BORDERS:
        rng = anim.get(key)
        if rng and idx in rng:
            return color
    if anim.get("iframe_da") is not None and anim["iframe_da"] <= idx <= anim.get("iframe_a", -1):
        return (60, 220, 230)  # invulnerabile
    return None


def build_frame(size, body, direction, idx, anim):
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # corpo: leggera oscillazione verticale per rendere visibile il ciclo
    bob = (idx % 2) - 0.5
    cx, cy = w // 2, h // 2 + 2
    d.ellipse([cx - 8, cy - 10 + bob, cx + 8, cy + 10 + bob], fill=body + (255,))

    # tacca di direzione
    if direction in DIR_OFFSET:
        dx, dy = DIR_OFFSET[direction]
        tip = (cx + dx * 11, cy + dy * 11 + bob)
        d.ellipse([tip[0] - 3, tip[1] - 3, tip[0] + 3, tip[1] + 3], fill=(20, 20, 25, 255))

    # bordo diagnostico
    border = frame_border(anim, idx)
    if border:
        d.rectangle([0, 0, w - 1, h - 1], outline=border + (255,), width=2)

    # numero del frame in alto a sinistra: pastiglia scura + cifra chiara,
    # cosi' resta leggibile sia su sfondo chiaro che scuro
    d.rectangle([1, 1, 5, 7], fill=(15, 15, 20, 230))
    px = img.load()
    draw_digit(px, str(idx)[-1], 2, 2, (255, 255, 255, 255))
    return img


def main():
    with open(SPEC, encoding="utf-8") as fh:
        spec = json.load(fh)

    size = tuple(spec["convenzioni"]["dimensione_frame"])
    directions = spec["convenzioni"]["direzioni"]
    os.makedirs(OUT, exist_ok=True)

    total = 0
    for cat, body in BODY.items():
        anims = {k: v for k, v in spec.get(cat, {}).items() if not k.startswith("_")}
        for name, anim in anims.items():
            dirs = directions if anim.get("direzionale") else ["down"]
            frames = anim["frames"]
            sheet = Image.new("RGBA", (size[0] * frames, size[1] * len(dirs)), (0, 0, 0, 0))
            for row, direction in enumerate(dirs):
                for i in range(frames):
                    sheet.paste(build_frame(size, body, direction, i, anim),
                                (i * size[0], row * size[1]))
                    total += 1
            path = os.path.join(OUT, f"{cat}_{name}.png")
            sheet.save(path)

    # tileset placeholder: pavimento, muro, ostacolo, acqua
    tiles = [("pavimento", (60, 55, 50)), ("muro", (30, 28, 26)),
             ("ostacolo", (80, 70, 55)), ("acqua", (40, 70, 100))]
    ts = Image.new("RGBA", (size[0] * len(tiles), size[1]), (0, 0, 0, 0))
    for i, (_, col) in enumerate(tiles):
        t = Image.new("RGBA", size, col + (255,))
        dt = ImageDraw.Draw(t)
        dt.rectangle([0, 0, size[0] - 1, size[1] - 1],
                     outline=tuple(min(255, c + 30) for c in col) + (255,))
        ts.paste(t, (i * size[0], 0))
    ts.save(os.path.join(OUT, "tileset.png"))

    print(f"OK: {total} frame placeholder generati in assets/placeholder/")
    print("Legenda bordi: ROSSO hitbox attiva | GIALLO anticipo/tell | "
          "VERDE parata perfetta | CIANO invulnerabile | GRIGIO recupero")
    return 0


if __name__ == "__main__":
    sys.exit(main())
