#!/usr/bin/env python3
"""
Il libro (design-ui-libro.md): la doppia pagina che fa da cornice a ogni schermata, generata come il resto
dell'arte, senza disegno a mano. Palette Endesga 32 (forge3d/materials.py E32), niente colori fuori palette,
niente anti-aliasing (pixel pieni o trasparenti), luce da alto-sinistra.

    python tools/art/build_libro.py      # assets/ui/libro.png, libro_avvio.png, segnalibro*.png, spunta_*.png, ornamento.png

libro.png e' grande quanto la pagina del gioco in unita' (600 x 340): un texel = un'unita' = 2 pixel a schermo,
la stessa grana del terreno. Stesso seed = stessi PNG.
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from forge3d.materials import E32  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui")
SEED = 7
W, H = 600, 340
C = {k: np.array([int(v[i:i + 2], 16) for i in (1, 3, 5)], np.uint8) for k, v in E32.items()}

# Bayer 4x4: il passaggio fra due toni e' una retinatura, mai una sfumatura
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def soglia(h, w, ox=0, oy=0):
    yy, xx = np.mgrid[0:h, 0:w]
    return BAYER[(yy + oy) % 4, (xx + ox) % 4]


def rumore(h, w, scala, rng):
    """Rumore morbido (valore interpolato) in [0, 1]."""
    gy, gx = h // scala + 2, w // scala + 2
    g = rng.rand(gy, gx)
    yy, xx = np.mgrid[0:h, 0:w] / scala
    y0, x0 = yy.astype(int), xx.astype(int)
    fy, fx = yy - y0, xx - x0
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a = g[y0, x0] * (1 - fx) + g[y0, x0 + 1] * fx
    b = g[y0 + 1, x0] * (1 - fx) + g[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def rampa(img, maschera, valore, toni):
    """Colora i pixel di 'maschera' con la rampa 'toni' (dal piu' scuro): valore in [0, 1], retinato."""
    n = len(toni)
    v = np.clip(valore, 0, 0.999) * n
    i = v.astype(int)
    f = v - i
    i = np.where(f > soglia(*valore.shape), np.minimum(i + 1, n - 1), i)
    for k, t in enumerate(toni):
        img[maschera & (i == k), :3] = C[t]


def libro(rng, W=W, H=H):
    """La doppia pagina con la copertina: W x H unita' (la pagina del gioco; piu' piccola all'avvio, US-8B74)."""
    img = np.zeros((H, W, 4), np.uint8)
    yy, xx = np.mgrid[0:H, 0:W]
    # --- copertina di cuoio, angoli smussati ---
    r = 7
    dentro = np.ones((H, W), bool)
    for cx, cy in ((r, r), (W - 1 - r, r), (r, H - 1 - r), (W - 1 - r, H - 1 - r)):
        angolo = ((xx < r) if cx == r else (xx > W - 1 - r)) & ((yy < r) if cy == r else (yy > H - 1 - r))
        dentro &= ~(angolo & ((xx - cx) ** 2 + (yy - cy) ** 2 > r * r))
    cuoio = rumore(H, W, 9, rng) * 0.4 + rumore(H, W, 3, rng) * 0.2
    luce = (1 - (xx + yy) / (W + H)) * 0.3                        # luce da alto-sinistra
    rampa(img, dentro, cuoio + luce, ["brown_dd", "brown_dd", "brown_d", "brown_d", "brown"])
    img[..., 3] = np.where(dentro, 255, 0)
    # cuciture a 5 px dal bordo: un punto di filo ogni 4 px
    cuc = dentro & (((xx == 5) | (xx == W - 6)) & (yy % 5 < 3) & (yy > 8) & (yy < H - 9)
                    | ((yy == 4) | (yy == H - 6)) & (xx % 5 < 3) & (xx > 8) & (xx < W - 9))
    img[cuc, :3] = C["tan"]
    # --- blocco delle pagine ---
    px0, px1, py0, py1 = 13, W - 13, 9, H - 11
    blocco = (xx >= px0) & (xx < px1) & (yy >= py0) & (yy < py1)
    # spessore dei fogli: righe alternate sul bordo esterno e sotto
    for k in range(4):
        tono = "cream" if k % 2 == 0 else "tan"
        img[(yy == py1 + k) & (xx >= px0 + k) & (xx < px1 - k), :3] = C[tono]
        img[(xx == px0 - 1 - k) & (yy >= py0 + k) & (yy < py1 + k), :3] = C[tono]
        img[(xx == px1 + k) & (yy >= py0 + k) & (yy < py1 + k), :3] = C[tono]
    # carta: crema, macchie larghe e granelli, bordi che ingialliscono, ombra della piega
    # la carta deve restare leggibile: macchie leggere, il colore e' quasi sempre il crema
    carta = rumore(H, W, 45, rng) * 0.22 + rumore(H, W, 7, rng) * 0.08
    mezzo = W // 2
    bordo = np.minimum.reduce([xx - px0, px1 - 1 - xx, yy - py0, py1 - 1 - yy]).astype(float)
    vecchio = np.clip(1 - bordo / 12.0, 0, 1) ** 1.5 * 0.5          # gli ultimi 12 px verso il bordo
    # piega stretta (6 px per lato): il testo che la attraversa resta leggibile
    piega = np.clip(1 - np.abs(xx - mezzo + 0.5) / 6.0, 0, 1) ** 1.5
    v = 0.97 - carta - vecchio - piega * 0.6
    rampa(img, blocco, v, ["brown_d", "brown", "tan", "tan", "cream", "cream"])
    granelli = blocco & (rng.rand(H, W) < 0.004) & (piega < 0.2)
    img[granelli, :3] = C["tan"]
    # la piega: una riga scura, con la carta che sale alla luce subito accanto
    img[blocco & ((xx == mezzo - 1) | (xx == mezzo)), :3] = C["brown_d"]
    img[blocco & (xx == mezzo - 1) & (yy % 2 == 0), :3] = C["brown_dd"]
    # contorno scuro da 1 px della pagina e della copertina
    bordo_pag = blocco & ~(np.roll(blocco, 1, 0) & np.roll(blocco, -1, 0) & np.roll(blocco, 1, 1) & np.roll(blocco, -1, 1))
    img[bordo_pag, :3] = C["brown_d"]
    fuori = ~dentro
    contorno = dentro & (np.roll(fuori, 1, 0) | np.roll(fuori, -1, 0) | np.roll(fuori, 1, 1) | np.roll(fuori, -1, 1)
                         | (yy == 0) | (yy == H - 1) | (xx == 0) | (xx == W - 1))
    img[contorno, :3] = C["ink"]
    # --- angoli d'ottone ---
    for sx, sy in ((0, 0), (1, 0), (0, 1), (1, 1)):
        a = 19
        lx = xx if sx == 0 else W - 1 - xx
        ly = yy if sy == 0 else H - 1 - yy
        tri = dentro & (lx + ly < a)
        # ottone: chiaro verso l'alto-sinistra di ogni angolo, scuro verso la pagina; l'angolo in basso a destra
        # (lontano dalla luce) piu' scuro
        ottone = 0.85 - (lx + ly) / a * 0.55 + (0.12 if (sx, sy) == (0, 0) else -0.12 if (sx, sy) == (1, 1) else 0)
        rampa(img, tri, ottone, ["brown_d", "orange_d", "orange_d", "amber", "yellow"])
        img[tri & (lx + ly == a - 1), :3] = C["brown_dd"]
        riv = tri & ((lx - 5) ** 2 + (ly - 5) ** 2 <= 2)              # ribattino
        img[riv, :3] = C["brown_d"]
        img[tri & (lx == 4) & (ly == 4), :3] = C["amber"]
        img[tri & contorno, :3] = C["ink"]
    return img


def segnalibro(colore, chiaro):
    """Nastro sul bordo destro del libro: 12 x 34, coda a V a destra."""
    w, h = 12, 34
    img = np.zeros((h, w, 4), np.uint8)
    yy, xx = np.mgrid[0:h, 0:w]
    v = (xx < w - 3) | (np.abs(yy - h / 2 + 0.5) > (xx - (w - 4)) * 4)
    img[v, :3] = C[colore]
    img[v & (yy < 3), :3] = C[chiaro]                                # luce dall'alto
    img[v & (yy == 4), :3] = C[chiaro]
    img[v & (xx % 3 == 1) & (yy > 6) & (yy < h - 6) & (xx < w - 4), :3] = C[chiaro] if colore != chiaro else C["red"]
    img[..., 3] = np.where(v, 255, 0)
    bordo = v & ~(np.roll(v, 1, 0) & np.roll(v, -1, 0) & np.roll(v, 1, 1) & np.roll(v, -1, 1))
    img[bordo & (xx > 0), :3] = C["ink"]
    return img


def spunta(acceso):
    """Casella del libro: 12 x 12, carta con bordo d'inchiostro; accesa = una croce di penna rossa."""
    img = np.zeros((12, 12, 4), np.uint8)
    img[1:11, 1:11] = list(C["cream"]) + [255]
    img[1, 1:11] = img[10, 1:11] = img[1:11, 1] = img[1:11, 10] = list(C["brown_dd"]) + [255]
    img[2, 2:10] = list(C["tan"]) + [255]                            # ombra interna in alto
    if acceso:
        for i in range(3, 9):
            img[i, i] = img[i, 11 - i] = list(C["red_d"]) + [255]
            img[i, i + 1] = list(C["red_d"]) + [255]
    return img


def ornamento():
    """Filetto sotto il titolo: 160 x 7, due righe con un rombo al centro."""
    w, h = 160, 7
    img = np.zeros((h, w, 4), np.uint8)
    yy, xx = np.mgrid[0:h, 0:w]
    m = w // 2
    riga = (yy == 3) & (np.abs(xx - m + 0.5) > 6) & (np.abs(xx - m + 0.5) < w / 2 - (np.abs(xx - m) // 30))
    punti = (yy == 3) & ((xx == 2) | (xx == w - 3))
    rombo = (np.abs(xx - m + 0.5) + np.abs(yy - 3) <= 3.5)
    img[riga | punti, :3] = C["brown_d"]
    img[rombo, :3] = C["red_d"]
    img[rombo & (yy == 2) & (xx == m - 1), :3] = C["red"]
    img[..., 3] = np.where(riga | punti | rombo, 255, 0)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = np.random.RandomState(SEED)
    fogli = {
        "libro.png": libro(rng),
        "segnalibro.png": segnalibro("red_d", "red"),
        "segnalibro_su.png": segnalibro("red", "pink"),
        "spunta_no.png": spunta(False),
        "spunta_si.png": spunta(True),
        "ornamento.png": ornamento(),
        # US-8B74: all'avvio il libro e' piu' piccolo e intorno si vede il panorama (data/ui/book.json tema.avvio)
        "libro_avvio.png": libro(np.random.RandomState(SEED + 1), 440, 250),
    }
    tavolozza = {tuple(int(c) for c in v) for v in C.values()}
    for nome, img in fogli.items():
        usati = {tuple(int(c) for c in p[:3]) for p in img.reshape(-1, 4) if p[3] == 255}
        fuori = usati - tavolozza
        assert not fuori, f"{nome}: colori fuori palette {sorted(fuori)[:5]}"
        assert set(np.unique(img[..., 3])) <= {0, 255}, f"{nome}: alpha non 0/255"
        Image.fromarray(img).save(os.path.join(OUT, nome))
        print("  assets/ui/" + nome, img.shape[1], "x", img.shape[0])


if __name__ == "__main__":
    main()
