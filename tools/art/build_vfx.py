"""VFX degli attacchi base (US-8B40): fendente, proiettile in volo, il suo scoppio, scia dello scatto.

    python tools/art/build_vfx.py

Come i glifi delle primitive, i fogli sono a 4 toni di grigio (0 contorno, 85 scuro, 170 primario, 255 accento)
e li colora shaders/rampa_pathway.gdshader con la palette del Pathway (data/vfx.json): la forma e' una, il colore
cambia. Un effetto d'attacco ha l'impatto nel primo frame (tutto acceso: il gioco lo fa bianco, o no se e' attivo
riduci_flash) e poi 4 frame di dissolvenza. Frame in colonne, una riga; disegnati verso destra (il gioco li gira).
Il numero di frame viene da data/vfx.json (primitive_vfx.<primitiva>.frames, scoppio.frames).
File: assets/vfx/<sprite>.png; foglio di controllo in arte/revisione/vfx_attacchi.png.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_primitive import _dilata, colora, png  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "vfx")
REVISIONE = os.path.join(ROOT, "arte", "revisione", "vfx_attacchi.png")
SEED = 40


def _griglia(w, h):
    y, x = np.mgrid[0:h, 0:w]
    return x + 0.5, y + 0.5


def _rumore(w, h, seed, blocco=2):
    """Rumore a blocchi di 2 px (la dissolvenza si mangia la forma a pezzetti, non a pixel singoli)."""
    rng = np.random.RandomState(seed)
    g = rng.rand(h // blocco + 1, w // blocco + 1)
    return np.kron(g, np.ones((blocco, blocco)))[:h, :w]


def _toni(I, mask, spegni=0):
    """Intensita' -> toni 1..3 (spegni abbassa di tanti toni), contorno 0 attorno alla forma."""
    lv = np.where(I > 0.62, 3, np.where(I > 0.3, 2, 1)) - spegni
    tela = np.full(I.shape, -1, int)
    tela[mask] = np.clip(lv[mask], 1, 3)
    return tela


def _contorno(tela, sagoma=None):
    """Contorno di 1 px attorno alla forma; con `sagoma` solo fuori da essa (i buchi della dissolvenza restano
    trasparenti, senza puntini scuri dentro)."""
    pieno = tela >= 0
    tela = tela.copy()
    anello = _dilata(pieno) & ~pieno
    if sagoma is not None:
        anello &= ~sagoma
    tela[anello] = 0
    return tela


def slash(n, S=96):
    """Mezzaluna davanti al personaggio (centro del foglio = il personaggio), larga 150 gradi."""
    x, y = _griglia(S, S)
    cx = cy = S / 2
    r = np.hypot(x - cx, y - cy)
    th = np.degrees(np.arctan2(y - cy, x - cx))
    nz = _rumore(S, S, SEED)
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        meta = 75.0 * (1 - 0.35 * t)                              # le punte si ritirano
        R = 36.0 + 3.0 * t                                         # e la falce si allarga
        w = 10.0 * np.clip(np.cos(np.radians(th) * 90.0 / meta), 0, 1) ** 0.7 * (1 - 0.35 * t)
        I = np.where(np.abs(th) < meta, 1 - np.abs(r - R) / (w / 2 + 1e-6), 0)
        if k == 0:
            out.append(_contorno(np.where(I > 0, 3, -1)))
            continue
        sagoma = I > 0.12 + 0.45 * t
        tela = _toni(I, sagoma & (nz > 0.75 * t), spegni=int(t * 1.6))
        out.append(_contorno(tela, sagoma) if k < n - 1 else tela)
    return out


def bolt(n, W=48, H=32):
    """Il proiettile in volo (ciclo): sfera accesa con la scia che ondeggia dietro; il centro del foglio e' la
    sfera (la posizione del proiettile)."""
    x, y = _griglia(W, H)
    cx, cy = W / 2, H / 2
    out = []
    for k in range(n):
        fase = k * math.pi
        d = np.hypot(x - cx, y - cy)
        L = 22.0
        u = cx - x                                                 # dietro la sfera
        w = np.clip(1 - u / L, 0, 1) * 6.0
        onda = 1.6 * np.sin(u * 0.4 + fase)
        scia = (u > 0) & (u < L) & (np.abs(y - cy - onda) < w)
        I = np.where(d < 7.5, 1 - d / 13.0, np.where(scia, 0.55 * (1 - u / L) + 0.1, 0))
        mask = (d < 7.5) | scia
        tela = _toni(I, mask)
        tela[(d < 3.5)] = 3
        out.append(_contorno(tela))
    return out


def scoppio(n, S=48):
    """Lo scoppio del proiettile: lampo tondo, poi anello che si allarga e raggi che si spezzano."""
    x, y = _griglia(S, S)
    c = S / 2
    r = np.hypot(x - c, y - c)
    th = np.arctan2(y - c, x - c)
    nz = _rumore(S, S, SEED + 1)
    raggi = [k * math.tau / 6 + 0.3 for k in range(6)]
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        if k == 0:
            out.append(_contorno(np.where(r < 9.5, 3, -1)))
            continue
        else:
            R = 7.0 + 12.0 * t
            anello = np.abs(r - R) < 2.6 * (1 - t) + 0.6
            I = np.where(anello, 0.9 - 0.5 * t, 0.0)
            for a in raggi:
                da = np.abs((th - a + math.pi) % math.tau - math.pi)
                spina = (r > R * 0.4) & (r < R * 1.15) & (da < 0.22 * (1 - t) + 0.04)
                I = np.maximum(I, np.where(spina, 1 - r / (R * 1.3), 0))
            sagoma = I > 0.08
            tela = _toni(I, sagoma & (nz > 0.8 * t), spegni=int(t * 1.6))
        out.append(_contorno(tela, sagoma) if k < n - 1 else tela)
    return out


def streak(n, W=64, H=32):
    """Scia dello scatto: tre linee dietro il personaggio (centro del foglio) che si accorciano e si spengono."""
    x, y = _griglia(W, H)
    linee = [(H / 2 - 7, 22.0), (H / 2, 30.0), (H / 2 + 7, 18.0)]
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        I = np.zeros((H, W))
        for yc, L in linee:
            coda = W / 2 - L * (1 - 0.6 * t)
            u = (x - coda) / (W / 2 - coda)                        # 0 in coda, 1 vicino al personaggio
            spess = 1.6 * (1 - 0.4 * t)
            dentro = (x > coda) & (x < W / 2 - 2) & (np.abs(y - yc) < spess * (0.4 + 0.6 * u))
            I = np.maximum(I, np.where(dentro, 0.25 + 0.75 * u - 0.3 * t, 0))
        mask = I > 0.05
        out.append(_contorno(_toni(I, mask)))
    return out


def main():
    pv = json.load(open(os.path.join(ROOT, "data", "vfx.json")))["primitive_vfx"]
    fogli = {
        pv["melee_arc"]["sprite"]: slash(pv["melee_arc"]["frames"]),
        pv["projectile"]["sprite"]: bolt(pv["projectile"]["frames"]),
        pv["projectile"]["scoppio"]["sprite"]: scoppio(pv["projectile"]["scoppio"]["frames"]),
        pv["dash"]["sprite"]: streak(pv["dash"]["frames"]),
    }
    os.makedirs(OUT, exist_ok=True)
    righe = []
    palette = json.load(open(os.path.join(ROOT, "data", "vfx.json")))["pathway_palette_visiva"]
    for nome, frames in fogli.items():
        Image.fromarray(np.concatenate([png(f) for f in frames], 1)).save(os.path.join(OUT, nome + ".png"))
        for pw in ("twilight_giant", "darkness", "moon"):
            col = [colora(f, palette[pw]) for f in frames]
            if pw == "twilight_giant":
                lampo = col[0].copy()
                lampo[frames[0] >= 2, :3] = 255                    # il primo frame come lo fa il gioco (bianco)
                col = [lampo] + col[1:]
            righe.append(np.concatenate(col, 1))
    w = max(r.shape[1] for r in righe)
    h = sum(r.shape[0] + 4 for r in righe)
    tela = np.zeros((h, w, 4), np.uint8)
    yy = 0
    for r in righe:
        tela[yy:yy + r.shape[0], :r.shape[1]] = r
        yy += r.shape[0] + 4
    fondo = np.zeros((h, w, 3), np.uint8)
    fondo[:] = (38, 43, 68)
    a = tela[..., 3:4] / 255.0
    im = (tela[..., :3] * a + fondo * (1 - a)).astype(np.uint8)
    os.makedirs(os.path.dirname(REVISIONE), exist_ok=True)
    Image.fromarray(im).resize((w * 3, h * 3), Image.NEAREST).save(REVISIONE)
    print(f"{len(fogli)} fogli in assets/vfx/: {', '.join(fogli)}; foglio in {os.path.relpath(REVISIONE, ROOT)}")


if __name__ == "__main__":
    main()
