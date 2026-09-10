#!/usr/bin/env python3
"""
Genera spritesheet placeholder REALI da data/animations.json.

    python tools/generate_placeholders.py

Non sono quadrati colorati a caso: il corpo di ogni frame viene da
tools/generate_sprites.py (US-812, pixel art procedurale) — questo script
importa quel corpo e ci disegna SOPRA le informazioni diagnostiche che
servono per tarare il combattimento senza arte definitiva:

  - il numero del frame, per contare a occhio la durata reale
  - il bordo ROSSO sui frame con hitbox attiva
  - il bordo GIALLO sui frame di anticipo (il tell)
  - il bordo CIANO sui frame di invulnerabilita' del dash
  - il bordo VERDE sui frame della finestra di parata perfetta
  - il bordo GRIGIO sui frame di recupero

Un run di generate_sprites.py = arte pulita (senza overlay, quella che
finisce davvero nel gioco). Un run di questo script = arte + diagnostica
(utile SOLO per tarare i tempi guardando lo schermo — sovrascrive gli
stessi file, quindi rilancia generate_sprites.py dopo aver finito di
tarare, prima di committare). Stessa cartella (assets/placeholder/),
stessa iterazione su data/animations.json di sempre.

Richiede Pillow:  pip install pillow
"""

import importlib.util
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

_spec = importlib.util.spec_from_file_location(
    "generate_sprites", os.path.join(ROOT, "tools", "generate_sprites.py"))
generate_sprites = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(generate_sprites)

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


def build_diagnostic_frame(cat, name, direzione, idx, anim, n_frames, seed):
    """Il corpo pulito da generate_sprites.py, con sopra bordo diagnostico
    + numero del frame."""
    pose = generate_sprites._pose_for(cat, name, anim, idx, n_frames)
    img = generate_sprites.build_frame(cat, direzione, pose, seed)
    d = ImageDraw.Draw(img)

    w, h = img.size
    border = frame_border(anim, idx)
    if border:
        d.rectangle([0, 0, w - 1, h - 1], outline=border + (255,), width=2)

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
    for cat in ("personaggio", "nemico_base", "pet"):
        anims = {k: v for k, v in spec.get(cat, {}).items() if not k.startswith("_")}
        for name, anim in anims.items():
            dirs = directions if anim.get("direzionale") else ["down"]
            n_frames = int(anim["frames"])
            sheet = Image.new("RGBA", (size[0] * n_frames, size[1] * len(dirs)), (0, 0, 0, 0))
            for row, direction in enumerate(dirs):
                for i in range(n_frames):
                    seed = generate_sprites.SEED + \
                        generate_sprites.zlib.crc32(f"{cat}:{name}:{i}".encode()) % 997
                    sheet.paste(build_diagnostic_frame(cat, name, direction, i, anim, n_frames, seed),
                                (i * size[0], row * size[1]))
                    total += 1
            path = os.path.join(OUT, f"{cat}_{name}.png")
            sheet.save(path)

    # tileset placeholder: pavimento, muro, ostacolo, acqua (US-813 lo
    # sostituisce con le 8 tile per palette generate da generate_sprites.py).
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

    print(f"OK: {total} frame placeholder (arte + diagnostica) generati in assets/placeholder/")
    print("Legenda bordi: ROSSO hitbox attiva | GIALLO anticipo/tell | "
          "VERDE parata perfetta | CIANO invulnerabile | GRIGIO recupero")
    print("NOTA: sovrascrive gli stessi file di generate_sprites.py con overlay diagnostici — "
          "rilancia generate_sprites.py dopo aver tarato i tempi, prima di committare.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
