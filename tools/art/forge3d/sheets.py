"""Rende clip di animazione in spritesheet: frame in colonne, direzioni in righe (down, up, left, right).

Stessa disposizione dei placeholder di Mirwada (`{categoria}_{nome}.png`), quindi i file si
sostituiscono uno a uno senza toccare il codice del gioco.
"""
import json
import os

import numpy as np
from PIL import Image

from .engine import render

YAW = {"down": 180.0, "up": 0.0, "left": 90.0, "right": -90.0}
DIRS = ["down", "up", "left", "right"]


def render_frame(rig, pose, direction="down", size=(32, 32), ppu=1.0, **kw):
    return render(rig.instances(pose, yaw=YAW[direction]), size=size, ppu=ppu, **kw)


def build_sheet(rig, poses, directional=True, size=(32, 32), ppu=1.0, **kw):
    dirs = DIRS if directional else ["down"]
    w, h = size
    sheet = np.zeros((h * len(dirs), w * len(poses), 4), np.uint8)
    for r, d in enumerate(dirs):
        for c, p in enumerate(poses):
            sheet[r * h:(r + 1) * h, c * w:(c + 1) * w] = render_frame(rig, p, d, size, ppu, **kw)
    return Image.fromarray(sheet, "RGBA")


def export_spec(rig, spec_path, category, out_dir, clips, size=None, ppu=1.0, only=None, **kw):
    """Legge data/animations.json (formato Mirwada) e scrive un PNG per ogni animazione della categoria."""
    spec = json.load(open(spec_path, encoding="utf-8"))
    size = tuple(size or spec["convenzioni"]["dimensione_frame"])
    os.makedirs(out_dir, exist_ok=True)
    made = []
    for name, a in spec[category].items():
        if name.startswith("_") or (only and name not in only) or name not in clips:
            continue
        poses = clips[name](a["frames"])
        img = build_sheet(rig, poses, a.get("direzionale", True), size, ppu, **kw)
        path = os.path.join(out_dir, f"{category}_{name}.png")
        img.save(path)
        made.append(path)
    return made
