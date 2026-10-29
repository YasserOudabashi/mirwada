#!/usr/bin/env python3
"""
Ritratti (US-8B35): un mezzobusto per aspetto, dallo stesso modello 3D dello sprite (stessi colori, stessa luce in
alto a sinistra), con il dettaglio dei ritratti (detail 3: sopracciglia e bocca con l'espressione dei dati di
build_npc.ASPETTI). Stessa inquadratura e stesso sfondo per tutti: tre quarti, il centro della testa sempre allo
stesso punto, fondo grigio che schiarisce verso la luce.

    python tools/art/build_ritratti.py      # assets/ritratti/<aspetto>.png (64x80) + arte/revisione/ritratti.png

Il nome del file e' l'id dell'aspetto (data/npc/roster.json "aspetto.sprite"; "personaggio" per il giocatore), mai
il nome dell'NPC. Nessun numero casuale: stessi parametri, stessi PNG.
"""

import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_npc as BN  # noqa: E402
import build_personaggi as BP  # noqa: E402
from forge3d.engine import render, rotm  # noqa: E402
from forge3d.materials import E32, hex_to_rgb  # noqa: E402

OUT = os.path.join(BP.ROOT, "assets", "ritratti")
REVISIONE = os.path.join(BP.ROOT, "arte", "revisione", "ritratti.png")
W, H = 64, 80                  # 4:5, mezzobusto
YAW, PITCH, PPU = 205.0, 10.0, 3.6
TESTA_Y = 38                   # dove cade il centro della testa nel ritratto (lo chignon resta dentro)
GRANDE = 300                   # altezza della tela su cui si disegna il corpo intero, poi si ritaglia
FONDO = ("grey_l", "grey")     # dalla luce (sinistra) all'ombra (destra), a retino
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def ritratti():
    """aspetto -> (rig con il dettaglio dei ritratti, posa). Gli NPC dalla loro idle, il giocatore dalla sua."""
    out = {"personaggio": (BP.enel(detail=3, brows=-6, mouth=0), BP.CLIP_ENEL["idle"](4)[0])}
    posa = BN.CLIP["idle"](4)[0]
    for aspetto, rig in BN.ASPETTI.items():
        out[aspetto] = (rig(detail=3), posa)
    return out


def _testa(rig, posa):
    """Centro della testa a schermo (unita' a destra e in alto dai piedi): la prima forma del giunto "head" e' il
    cranio. Serve a mettere tutte le teste nello stesso punto, qualunque sia la posa o l'altezza."""
    fk = rig.fk(posa)
    cranio = next(p for p in rig.parts if p.joint == "head")
    Rj, oj = fk["head"]
    c = rotm(0, 0, YAW) @ (oj + Rj @ np.asarray(cranio.pos, float)) * rig.scale
    phi = np.radians(PITCH)
    return c[0], c[1] * np.sin(phi) + c[2] * np.cos(phi)


def busto(rig, posa):
    piedi = 0.97
    tela = render(rig.instances(posa, yaw=YAW), size=(2 * W, GRANDE), ppu=PPU, pitch=PITCH, foot=(0.5, piedi),
                  shadow=False)
    dx, su = _testa(rig, posa)
    y0 = int(round(piedi * GRANDE - su * PPU)) - TESTA_Y
    x0 = int(round(W + dx * PPU)) - W // 2
    assert y0 >= 0 and not tela[:y0, :, 3].any(), "il ritratto taglia la testa"
    return tela[y0:y0 + H, x0:x0 + W]


def fondo():
    luce, ombra = (np.array(hex_to_rgb(E32[n]), np.uint8) for n in FONDO)
    yy, xx = np.mgrid[0:H, 0:W]
    t = (xx + 0.35 * yy) / (W + 0.35 * H)                      # luce dall'alto a sinistra
    img = np.empty((H, W, 4), np.uint8)
    img[..., 3] = 255
    img[..., :3] = np.where((t > BAYER[yy % 4, xx % 4] * 0.6 + 0.2)[..., None], ombra, luce)
    return img


def componi(figura):
    img = fondo()
    piena = figura[..., 3] == 255
    img[piena, :3] = figura[piena, :3]
    img[0, :, :3] = img[-1, :, :3] = img[:, 0, :3] = img[:, -1, :3] = hex_to_rgb(E32["ink"])   # cornice di 1 px
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    consentiti = {hex_to_rgb(c) for c in E32.values()}
    fatti = []
    for aspetto, (rig, posa) in ritratti().items():
        img = componi(busto(rig, posa))
        assert not ({tuple(int(v) for v in p) for p in img[..., :3].reshape(-1, 3)} - consentiti), aspetto
        Image.fromarray(img).save(os.path.join(OUT, aspetto + ".png"))
        fatti.append(img)
    righe = []
    for bg in ((234, 212, 170), (40, 34, 48)):                   # sulla carta del libro e al buio
        per_riga = 8
        tela = np.zeros((((len(fatti) + per_riga - 1) // per_riga) * (H + 6) + 6, per_riga * (W + 6) + 6, 3),
                        np.uint8)
        tela[:] = bg
        for i, img in enumerate(fatti):
            y, x = 6 + (i // per_riga) * (H + 6), 6 + (i % per_riga) * (W + 6)
            tela[y:y + H, x:x + W] = img[..., :3]
        righe.append(tela)
    im = np.concatenate(righe, 0)
    os.makedirs(os.path.dirname(REVISIONE), exist_ok=True)
    Image.fromarray(im).resize((im.shape[1] * 3, im.shape[0] * 3), Image.NEAREST).save(REVISIONE)
    print(f"{len(fatti)} ritratti in assets/ritratti/, foglio in {os.path.relpath(REVISIONE, BP.ROOT)}")


if __name__ == "__main__":
    main()
