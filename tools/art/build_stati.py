"""Icone di stato (US-8B71): una per status di data/status_effects.json, 16x16, pixel art disegnata da griglie.

    python tools/art/build_stati.py

Un tondo scuro con il bordo del colore del tipo (negativo: rosso; vantaggio: verde, dal campo "negativo" dei dati)
e il simbolo dentro, 10x10 al centro. Colori solo dalla palette Endesga 32; contorno #181425 di 1 px.
File: assets/icone/stati/<status_id>.png; foglio di controllo in arte/revisione/icone_stati.png.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from forge3d.materials import E32, hex_to_rgb  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "icone", "stati")
REVISIONE = os.path.join(ROOT, "arte", "revisione", "icone_stati.png")
LATO = 16

COLORI = {"k": "ink", "w": "white", "l": "grey_l", "g": "grey", "s": "slate", "S": "slate_d", "r": "red", "R": "red_d",
          "p": "pink", "y": "yellow", "a": "amber", "o": "orange", "G": "green", "m": "green_m", "d": "green_d",
          "c": "cyan", "b": "blue", "B": "blue_d", "v": "purple", "V": "purple_d", "n": "brown", "N": "brown_d",
          "t": "tan", "C": "cream", "u": "rust"}
FONDO, BORDO = "navy", {True: ("red_d", "red"), False: ("green_d", "green_m")}

# 10 righe x 10 colonne; "." lascia il fondo del tondo
SIMBOLI = {
    "sfortuna": [            # ferro di cavallo rovesciato: la fortuna scivola via
        "..ssssss..",
        ".sggllggs.",
        "sgl....lgs",
        "sg......gs",
        "sgk....kgs",
        "sg......gs",
        "sg......gs",
        "sgk....kgs",
        "ssg....gss",
        ".ss....ss.",
    ],
    "taunt": [               # punto esclamativo: guarda me
        "...RrrR...",
        "...rppr...",
        "...rppr...",
        "...rppr...",
        "....rr....",
        "....rr....",
        "....RR....",
        "..........",
        "....pr....",
        "....rR....",
    ],
    "decadimento": [         # goccia di marcio
        "....m.....",
        "...mGm....",
        "...mGm..m.",
        "..mGGGm...",
        "..mGyGGm..",
        ".mGyGGGGm.",
        ".mGGGGGGm.",
        ".mdGGGGdm.",
        "..mddddm..",
        "...mmmm...",
    ],
    "autorita_decadimento": [  # corona che cola
        "a...aa...a",
        "aa.aaaa.aa",
        "aaaaaaaaaa",
        "aayaaaayaa",
        "aaaaaaaaaa",
        "oooooooooo",
        ".m...m..m.",
        ".G...m..G.",
        ".....G....",
        "..........",
    ],
    "comando_non_morti": [   # teschio con gli occhi viola
        "..llllll..",
        ".llwwwwll.",
        "lwwwwwwwwl",
        "lwkkwwkkwl",
        "lwkvwwvkwl",
        "lwwwkkwwwl",
        ".lwwwwwwl.",
        "..lwlwlwl.",
        "..lklklkl.",
        "...lllll..",
    ],
    "paura": [               # fantasma con gli occhi sbarrati
        "...llll...",
        "..lwwwwl..",
        ".lwwwwwwl.",
        ".lwkwwkwl.",
        ".lwkwwkwl.",
        ".lwwwwwwl.",
        ".lwwkkwwl.",
        ".lwwkkwwl.",
        ".lwwwwwwl.",
        ".lw.lw.lw.",
    ],
    "anima_recisa": [        # anima tagliata in due
        "....cc....",
        "...cwc....",
        "..cwwc..r.",
        "..cwwc.r..",
        ".cwwc.r.c.",
        ".cwc.r.cc.",
        ".cc.r.cwc.",
        "...r.cwwc.",
        "..r.cccc..",
        ".r..bbb...",
    ],
    "affascinato": [         # cuore con la scintilla
        ".rr..rr.y.",
        "rpprrpprya",
        "rpwppppr..",
        "rpppppppr.",
        "rpppppppr.",
        ".rpppppr..",
        "..rpppr...",
        "...rpr....",
        "....r.....",
        "..........",
    ],
    "area_viva": [           # germoglio con due foglie
        "..........",
        "...mm.mm..",
        "..mGGmGGm.",
        ".mGGGmGGGm",
        ".mGyGmGyGm",
        "..mGGmGGm.",
        "...mmdmm..",
        ".....d....",
        ".....d....",
        "..nnnnnnn.",
    ],
    "gravita_alterata": [    # masso che sprofonda
        "...vVVv...",
        "..vppvVv..",
        "..vpvvVv..",
        "...vVVv...",
        "..........",
        "....pp....",
        "....pp....",
        "..pppppp..",
        "...pppp...",
        "....pp....",
    ],
    "destino_segnato": [     # mirino: il bersaglio e' segnato
        "....aa....",
        "..aayyaa..",
        ".ay....ya.",
        ".a..oo..a.",
        "ay.oyyo.ya",
        "ay.oyyo.ya",
        ".a..oo..a.",
        ".ay....ya.",
        "..aayyaa..",
        "....aa....",
    ],
    "occultato": [           # occhio sbarrato
        ".........l",
        "...llll.l.",
        ".llggggll.",
        "lgg.kk.lgl",
        "lg.kbbklg.",
        "lg.kbkl.gl",
        "lgg.kl.ggl",
        ".llglggll.",
        "..l.llll..",
        ".l........",
    ],
    "varco_sigillato": [     # lucchetto
        "...gggg...",
        "..g....g..",
        "..g....g..",
        "..g....g..",
        ".aaaaaaaa.",
        ".ayyyyyya.",
        ".ayyooyya.",
        ".ayyooyya.",
        ".aoyyyyoa.",
        ".aaaaaaaa.",
    ],
    "posseduto": [           # fiamma viola con gli occhi
        "....v.....",
        "...vpv....",
        "...vpv.v..",
        "..vppvvpv.",
        ".vppppppv.",
        ".vpkppkpv.",
        ".vpkppkpv.",
        ".vppppppv.",
        "..vVVVVv..",
        "...VVVV...",
    ],
}


def tondo():
    """Maschera del tondo 16x16 e del suo bordo esterno (contorno) e interno (colore del tipo)."""
    yy, xx = np.mgrid[0:LATO, 0:LATO]
    d = np.hypot(xx + 0.5 - LATO / 2, yy + 0.5 - LATO / 2)
    pieno = d <= LATO / 2 - 0.1
    p = np.pad(pieno, 1)
    bordo = pieno & ~(p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:])
    dentro = pieno & ~bordo
    q = np.pad(dentro, 1)
    anello = dentro & ~(q[:-2, 1:-1] & q[2:, 1:-1] & q[1:-1, :-2] & q[1:-1, 2:])
    return pieno, bordo, anello


def icona(sid, negativo):
    pieno, bordo, anello = tondo()
    img = np.zeros((LATO, LATO, 4), np.uint8)
    rgb = lambda n: hex_to_rgb(E32[n]) + (255,)   # noqa: E731
    img[pieno] = rgb(FONDO)
    scuro, chiaro = BORDO[negativo]
    img[anello] = rgb(chiaro)
    img[anello & (np.mgrid[0:LATO, 0:LATO][0] >= LATO // 2)] = rgb(scuro)   # in ombra la meta' bassa
    img[bordo] = rgb("ink")
    griglia = SIMBOLI[sid]
    assert len(griglia) == 10 and all(len(r) == 10 for r in griglia), sid
    for y, riga in enumerate(griglia):
        for x, ch in enumerate(riga):
            if ch != ".":
                img[3 + y, 3 + x] = rgb(COLORI[ch])
    return img


def main():
    stati = json.load(open(os.path.join(ROOT, "data", "status_effects.json")))["statuses"]
    assert set(stati) == set(SIMBOLI), set(stati) ^ set(SIMBOLI)
    os.makedirs(OUT, exist_ok=True)
    consentiti = {hex_to_rgb(c) for c in E32.values()}
    disegni = []
    for sid, s in stati.items():
        img = icona(sid, bool(s.get("negativo", True)))
        piene = img[..., 3] > 0
        assert not ({tuple(int(c) for c in p) for p in img[piene][:, :3]} - consentiti), sid
        Image.fromarray(img).save(os.path.join(OUT, sid + ".png"))
        disegni.append(img)
    fogli = []
    for bg in ((234, 212, 170), (90, 105, 136)):
        tela = np.zeros((LATO + 4, len(disegni) * (LATO + 4), 3), np.uint8)
        tela[:] = bg
        for i, img in enumerate(disegni):
            x = i * (LATO + 4) + 2
            a = img[..., 3:4] / 255.0
            tela[2:2 + LATO, x:x + LATO] = (img[..., :3] * a + tela[2:2 + LATO, x:x + LATO] * (1 - a)).astype(np.uint8)
        fogli.append(tela)
    im = np.concatenate(fogli, 0)
    os.makedirs(os.path.dirname(REVISIONE), exist_ok=True)
    Image.fromarray(im).resize((im.shape[1] * 6, im.shape[0] * 6), Image.NEAREST).save(REVISIONE)
    print(f"{len(disegni)} icone di stato in assets/icone/stati/, foglio in {os.path.relpath(REVISIONE, ROOT)}")


if __name__ == "__main__":
    main()
