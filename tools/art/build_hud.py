"""HUD di gioco (US-8B75d): emblemi delle barre, icona dell'avanzamento e cifre dei tasti, pixel art da griglie.

    python tools/art/build_hud.py

Emblemi 12x12 (cuore = vita, goccia = spiritualita', maschera = recitazione, fiala = avanzamento pronto) e cifre 1-4
6x8 per l'angolo degli slot. Colori solo Endesga 32, contorno #181425 di 1 px, alpha 0 o 255. Le barre e le cornici
degli slot non sono immagini: le disegna scripts/hud_barra.gd e hud_slot.gd coi colori di data/ui/hud.json.
File: assets/ui/hud/<nome>.png; foglio di controllo ingrandito in arte/revisione/hud_icone.png.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from forge3d.materials import E32, hex_to_rgb  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui", "hud")
REVISIONE = os.path.join(ROOT, "arte", "revisione", "hud_icone.png")

COLORI = {"k": "ink", "w": "white", "l": "grey_l", "g": "grey", "s": "slate", "r": "red", "R": "red_d", "p": "pink",
          "y": "yellow", "a": "amber", "o": "orange", "u": "rust", "c": "cyan", "b": "blue", "B": "blue_d",
          "C": "cream", "t": "tan", "v": "purple", "V": "purple_d", "G": "green", "m": "green_m"}

DISEGNI = {
    "cuore": [              # luce in alto a sinistra, ombra in basso a destra
        "............",
        "..kkk..kkk..",
        ".kpprkkrrrk.",
        "kpwprrrrrrRk",
        "kprrrrrrrrRk",
        "krrrrrrrrrRk",
        ".krrrrrrrRk.",
        "..krrrrrRk..",
        "...krrrRk...",
        "....krRk....",
        ".....kk.....",
        "............",
    ],
    "goccia": [
        ".....kk.....",
        "....kcbk....",
        "....kcbk....",
        "...kcbbBk...",
        "..kcwbbbBk..",
        "..kcbbbbBk..",
        ".kcbbbbbbBk.",
        ".kcbbbbbbBk.",
        ".kbbbbbbBBk.",
        "..kbbbbBBk..",
        "...kkBBkk...",
        ".....kk.....",
    ],
    "maschera": [           # la maschera del teatro: recitare il ruolo
        "............",
        ".kkkkkkkkkk.",
        "kyyyyyyyyyak",
        "kywyyyyyyyak",
        "kykkyyyykkak",
        "kykkyyyykkak",
        "kyyyyyyyyyak",
        ".kyyykkyyak.",
        ".kyyyyyyyak.",
        "..kyykkyak..",
        "...kaaaak...",
        "....kkkk....",
    ],
    "fiala": [
        "....kkkk....",
        "....kttk....",
        "....kllk....",
        "....kllk....",
        "...klwllk...",
        "..klcccclk..",
        ".klcwccccck.",
        ".kccccccbBk.",
        ".kcccccbbBk.",
        ".kbcccbbbBk.",
        "..kBBBBBBk..",
        "...kkkkkk...",
    ],
}
CIFRE = {                   # 4x6 dentro un contorno di 1 px: 6x8
    "1": [".w..", "ww..", ".w..", ".w..", ".w..", "www."],
    "2": ["www.", "...w", ".ww.", "w...", "w...", "wwww"],
    "3": ["www.", "...w", ".ww.", "...w", "...w", "www."],
    "4": ["w..w", "w..w", "wwww", "...w", "...w", "...w"],
}


def immagine(righe, contorna=False):
    h, w = len(righe), len(righe[0])
    pad = 1 if contorna else 0
    im = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    pix = im.load()
    for y, riga in enumerate(righe):
        assert len(riga) == w, riga
        for x, ch in enumerate(riga):
            if ch != ".":
                pix[x + pad, y + pad] = hex_to_rgb(E32[COLORI[ch]]) + (255,)
    if contorna:                                      # contorno di 1 px attorno ai pieni (solo in croce: niente angoli)
        ink = hex_to_rgb(E32["ink"]) + (255,)
        piene = {(x, y) for y in range(im.height) for x in range(im.width) if pix[x, y][3] == 255}
        for x, y in piene:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if 0 <= q[0] < im.width and 0 <= q[1] < im.height and q not in piene:
                    pix[q] = ink
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    fatte = []
    for nome, righe in DISEGNI.items():
        im = immagine(righe)
        im.save(os.path.join(OUT, nome + ".png"))
        fatte.append(im)
    for c, righe in CIFRE.items():
        im = immagine(righe, contorna=True)
        im.save(os.path.join(OUT, "cifra_%s.png" % c))
        fatte.append(im)
    # foglio di controllo x8, su fondo chiaro e scuro
    s = 8
    larg = sum(i.width * s + 8 for i in fatte) + 8
    foglio = Image.new("RGBA", (larg, 2 * (12 * s + 16)), (0, 0, 0, 255))
    for riga, fondo in enumerate([(234, 212, 170, 255), (38, 43, 68, 255)]):
        y = riga * (12 * s + 16)
        foglio.paste(Image.new("RGBA", (larg, 12 * s + 16), fondo), (0, y))
        x = 8
        for im in fatte:
            grande = im.resize((im.width * s, im.height * s), Image.NEAREST)
            foglio.alpha_composite(grande, (x, y + 8))
            x += grande.width + 8
    os.makedirs(os.path.dirname(REVISIONE), exist_ok=True)
    foglio.save(REVISIONE)
    print("%d immagini in %s, foglio in %s" % (len(fatte), OUT, REVISIONE))


if __name__ == "__main__":
    main()
