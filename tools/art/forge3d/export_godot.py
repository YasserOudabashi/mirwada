"""Esporta per Godot 4: spritesheet dei personaggi (formato Mirwada) e mondo (tile + oggetti + json)."""
import json
import os
import shutil

import numpy as np
from PIL import Image

from .terrain import ORDER, TILE, TERRAINS, build_atlas, n_varianti
from .worldrender import object_sprite

HERE = os.path.dirname(os.path.abspath(__file__))
GD_LOADER = os.path.join(HERE, "..", "..", "engines", "godot", "sprite_forge_world.gd")


def export_world(w, out_dir, S=TILE, copy_loader=True):
    os.makedirs(os.path.join(out_dir, "objects"), exist_ok=True)
    frames, varianti = {}, {}
    for name in ORDER:                                    # righe dell'atlante: variante * frame + frame
        at = build_atlas(name, S)
        Image.fromarray(at).save(os.path.join(out_dir, f"terrain_{name}.png"))
        frames[name] = TERRAINS[name].get("anim", 1)
        varianti[name] = {"n": n_varianti(TERRAINS[name]), "macro": TERRAINS[name]["macro"]}
    sprites, objs = {}, []
    for o in w.objects:
        spr = object_sprite(o, S)
        if spr is None:
            continue
        key = "_".join(str(o.get(k)) for k in ("type", "kind", "leaf", "mat", "berries", "seed", "size") if o.get(k) is not None)
        key = key.replace(".", "p")
        if key not in sprites:
            img, ax, ay = spr
            Image.fromarray(img).save(os.path.join(out_dir, "objects", key + ".png"))
            sprites[key] = {"ax": ax, "ay": ay, "w": img.shape[1], "h": img.shape[0]}
        objs.append({"sprite": key, "x": round(o["x"], 3), "y": round(o["y"], 3), "type": o["type"]})
    j = w.to_json()
    j.update({"tile": S, "terrain_frames": frames, "terrain_variants": varianti, "sprites": sprites, "objects": objs})
    j["ground"] = [[int(v) for v in row] for row in j["ground"]]
    j["roads"] = [[list(map(int, p)) for p in r] for r in j["roads"]]
    with open(os.path.join(out_dir, "world.json"), "w") as f:
        json.dump(j, f, separators=(",", ":"))
    if copy_loader:
        shutil.copy(GD_LOADER, os.path.join(out_dir, "..", "sprite_forge_world.gd") if False else os.path.join(out_dir, "sprite_forge_world.gd"))
    return {"terrains": len(ORDER), "objects": len(objs), "sprites": len(sprites)}
