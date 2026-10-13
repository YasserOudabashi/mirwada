#!/usr/bin/env python3
"""
Tavola dei campioni dei terreni (US-8B11a, PRD fase 8b): per guardarli prima di usarli.

    python tools/art/campioni_terreni.py            # a 64 px (la risoluzione decisa)
    python tools/art/campioni_terreni.py --size 32

Esce arte/terreni/campioni.png: ogni terreno ripetuto 3x3 (cosi' si vede se la
ripetizione forma un disegno), ingrandito x2, piu' un pezzo di mappa con le
transizioni tra terreni. I terreni "prova:" mostrano i motivi nuovi con colori
provvisori: vivono solo qui, i terreni veri arrivano con US-8B11b/c/d.
"""

import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from forge3d import terrain as T  # noqa: E402

OUT = os.path.join(HERE, "..", "..", "arte", "terreni")

# Solo per mostrare i motivi nuovi: non sono in ORDER, la mappa non li usa.
PROVE = {
    "prova:parquet": dict(ramp=["brown_dd", "brown_d", "brown_d", "brown"], period=4, dither=0.3, detail="herringbone",
                          rim=None, level=99),
    "prova:lamiera": dict(ramp=["slate_d", "slate", "grey", "grey_l"], period=4, dither=0.3, detail="plates", rim=None,
                          level=99),
    "prova:lava": dict(ramp=["ink", "brown_dd", "brown_dd", "slate_d"], period=4, dither=0.4, detail="embers", rim=None,
                       level=99, accent=["orange", "amber"]),
}

# Scene di prova: un pezzo di regione disegnato a lettere, per vedere i terreni insieme e i loro bordi.
SCENE = [
    ("mirwada", "scena di Mirwada: pontile e molo, porto, centro antico, campagna, cimitero",
     ("WWWWWWPPWWWWWWWW",
      "WWWWWWPPWWMMMMWW",
      "WwwwwwPPwwMMMMww",
      "bbsscccccccccccc",
      "bssccclllllllggg",
      "ssggcclllllllgff",
      "gggggrrrrgggmmff",
      "gggggrgggggmhmff"),
     {"W": "deep_water", "w": "water", "P": "pontile_legno", "M": "molo_pietra", "b": "ciottoli_spiaggia",
      "s": "sand", "c": "ciottoli_scuri", "l": "lastre_chiare", "g": "grass", "f": "filari",
      "r": "lastricato_antico", "m": "marmo", "h": "ghiaia"}),
    ("marche", "scena delle Marche: gradoni di arenaria, pietrisco, muschio, campo bruciato, erica, neve",
     ("NNNNNAAAAAAAAANNN",
      "NNNAAAppppppAAAAN",
      "AAAAppppmmppppAAA",
      "ppppppmmmppppbbbp",
      "pppeepppppppbbbbp",
      "peeeeppAAAppbbbpp",
      "AAAAAAAAAAAAAAAAA",
      "ppppppppeeepppppp"),
     {"N": "snow", "A": "arenaria", "p": "pietrisco", "m": "muschio_scuro", "b": "terra_bruciata", "e": "erica_secca"}),
    ("valle", "scena della Valle: giungla (felci, radici e muschio), palude, radura argentata, scogliera sul mare",
     ("fffffrrrrfffffff",
      "fffrrrrrrrrfffpp",
      "ffrrrrgggrrfpppp",
      "fffrrgggggrfpppp",
      "ffffrrgggrrfffpp",
      "AAAffffrrffffAAA",
      "wwAAAAAAAAAAAAww",
      "WWwwwwwwwwwwwwWW"),
     {"f": "felci", "r": "radici_muschio", "g": "erba_argentata", "p": "palude", "A": "arenaria", "w": "water",
      "W": "deep_water"}),
]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--size", type=int, default=64)
    a = ap.parse_args()
    S, k = a.size, 128 // a.size
    T.TERRAINS.update(PROVE)
    nomi = list(T.ORDER) + list(PROVE)
    font = ImageFont.load_default()
    cella, testa, gap = 3 * S * k, 16, 12
    cols = 4
    righe = (len(nomi) + cols - 1) // cols
    # pezzo di mappa con le transizioni: acqua profonda -> acqua -> sabbia -> erba -> sentiero/pietra/neve
    L = {n: i for i, n in enumerate(T.ORDER)}
    mappa = np.array([[L["deep_water"]] * 3 + [L["water"]] * 2 + [L["sand"]] * 2 + [L["grass"]] * 5,
                      [L["deep_water"]] * 2 + [L["water"]] * 2 + [L["sand"]] * 2 + [L["grass"]] * 3 + [L["path"]] * 3,
                      [L["water"]] * 3 + [L["sand"]] * 2 + [L["grass"]] * 2 + [L["forest"]] * 2 + [L["stone"]] * 3,
                      [L["water"]] * 2 + [L["sand"]] * 2 + [L["grass"]] * 3 + [L["dirt"]] * 2 + [L["snow"]] * 3])
    trans = T.compose_ground(mappa, S=S)
    scene = []
    for sid, titolo, righe_scena, cod in SCENE:
        lung = {len(r) for r in righe_scena}
        assert len(lung) == 1, f"{titolo}: righe di lunghezza diversa {[len(r) for r in righe_scena]}"
        scene.append((sid, titolo, T.compose_ground(np.array([[L[cod[ch]] for ch in r] for r in righe_scena]), S=S)))
    larg = cols * cella + (cols - 1) * gap
    larg = max([larg] + [sc.shape[1] for _, _, sc in scene])
    alt_scene = sum(sc.shape[0] + testa + gap for _, _, sc in scene)
    tav = Image.new("RGB", (larg, righe * (cella + testa + gap) + trans.shape[0] + testa + gap + alt_scene),
                    (244, 244, 244))
    dr = ImageDraw.Draw(tav)
    for i, n in enumerate(nomi):
        tex = T.terrain_texture(n, S)
        im = Image.fromarray(np.tile(tex, (3, 3, 1)).astype(np.uint8)).resize((cella, cella), Image.NEAREST)
        x, y = (i % cols) * (cella + gap), (i // cols) * (cella + testa + gap)
        dr.text((x, y + 2), n, fill=(24, 20, 37), font=font)
        tav.paste(im, (x, y + testa))
    y = righe * (cella + testa + gap)
    dr.text((0, y + 2), f"transizioni tra terreni (dual grid), {S} px per tile, 1:1", fill=(24, 20, 37), font=font)
    tav.paste(Image.fromarray(trans[..., :3]), (0, y + testa))
    os.makedirs(OUT, exist_ok=True)
    y += trans.shape[0] + testa + gap
    for sid, titolo, sc in scene:
        dr.text((0, y + 2), titolo, fill=(24, 20, 37), font=font)
        tav.paste(Image.fromarray(sc[..., :3]), (0, y + testa))
        Image.fromarray(sc[..., :3]).save(os.path.join(OUT, f"scena_{sid}.png"))
        y += sc.shape[0] + testa + gap
    path = os.path.join(OUT, "campioni.png")
    tav.save(path)
    print(f"{len(nomi)} terreni, {S} px -> {os.path.abspath(path)}")


if __name__ == "__main__":
    main()
