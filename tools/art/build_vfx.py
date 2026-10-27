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
from PIL import Image, ImageDraw

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


# --- gruppo 1 delle primitive (US-8B41): attorno a chi lancia ------------------------------------------------------
# Il foglio e' centrato 6 unita' sopra i piedi (vfx.gd): a mezza grandezza i piedi stanno 12 pixel sotto il centro.

def _forme(W, H, *ops):
    """Maschera di forme disegnate a 4x e ridotte a maggioranza (niente sfumature); coordinate in pixel del foglio."""
    im = Image.new("L", (W * 4, H * 4), 0)
    d = ImageDraw.Draw(im)
    for op in ops:
        op(d)
    return np.asarray(im, float).reshape(H, 4, W, 4).mean(axis=(1, 3)) >= 128


def _lin(x0, y0, x1, y1, w):
    def f(d):
        d.line([(x0 * 4, y0 * 4), (x1 * 4, y1 * 4)], fill=255, width=max(1, int(w * 4)))
    return f


def _ell(cx, cy, rx, ry):
    return lambda d: d.ellipse([(cx - rx) * 4, (cy - ry) * 4, (cx + rx) * 4, (cy + ry) * 4], fill=255)


def _pol(*pts):
    return lambda d: d.polygon([(x * 4, y * 4) for x, y in pts], fill=255)


def _anello(W, H, cx, cy, r, spess, rapp=0.5):
    """Anello a terra in prospettiva (schiacciato in verticale)."""
    x, y = _griglia(W, H)
    dd = np.hypot((x - cx) / r, (y - cy) / (r * rapp))
    return np.abs(dd - 1) * r < spess / 2


def _metti(tela, mask, livello):
    tela[mask] = livello
    return tela


def _sfuma(mask, t, seed, W, H, soglia=0.85):
    """La dissolvenza a blocchi: con t che va da 0 a 1 se ne mangia sempre di piu'."""
    return mask & (_rumore(W, H, seed) > soglia * t)


def rune_su(n, S=64, giu=False):
    """buff_stat (frecce che salgono) e debuff_stat (frecce che scendono, toni piu' scuri)."""
    piedi = S / 2 + 12
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        tela = np.full((S, S), -1, int)
        anello = _anello(S, S, S / 2, piedi, 18 + 4 * t, 2.2 - 0.8 * t)
        _metti(tela, _sfuma(anello, t, SEED + 10, S, S), 1 if giu else 2)
        for i, (x, fase) in enumerate(((S / 2 - 17, 0), (S / 2 - 7, 14), (S / 2 + 7, 6), (S / 2 + 17, 20), (S / 2, 26))):
            sale = (k * 8 + fase) % 34
            y = (piedi - 6 - sale) if not giu else (piedi - 42 + sale)
            d = 5 if not giu else -5
            ch = _forme(S, S, _lin(x - 5, y + d, x, y, 2.2), _lin(x, y, x + 5, y + d, 2.2))
            alto = 3 if not giu else 2
            _metti(tela, _sfuma(ch, t, SEED + 11 + i, S, S, 0.7), alto if t < 0.6 else alto - 1)
        out.append(_contorno(tela))
    return out


def aura_anello(n, S=96):
    """aura: un anello a terra che si allarga, con scintille che salgono attorno."""
    piedi = S / 2 + 12
    rs = np.random.RandomState(SEED + 20)
    punti = [(rs.uniform(0, math.tau), rs.uniform(0.6, 1.0), rs.uniform(0, 1)) for _ in range(14)]
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        tela = np.full((S, S), -1, int)
        R = 16 + 22 * t
        _metti(tela, _sfuma(_anello(S, S, S / 2, piedi, R, 3.4 - 1.6 * t), t, SEED + 21, S, S, 0.7), 2)
        _metti(tela, _sfuma(_anello(S, S, S / 2, piedi, R * 0.62, 1.6), t, SEED + 22, S, S, 0.7), 3 if t < 0.5 else 1)
        for a, rr, h in punti:
            px = S / 2 + math.cos(a) * R * rr
            py = piedi + math.sin(a) * R * rr * 0.5 - (h * 14 + 18 * t)
            m = _forme(S, S, _lin(px, py, px, py + 3, 1.2))
            _metti(tela, m, 3 if (h + t) < 1.2 else 2)
        out.append(_contorno(tela))
    return out


def ricuci(n, S=64):
    """heal: croci luminose che salgono attorno e un anello morbido ai piedi."""
    piedi = S / 2 + 12
    croci = [(S / 2 - 15, 0.0), (S / 2 + 13, 0.35), (S / 2 - 4, 0.65), (S / 2 + 6, 0.15)]
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        tela = np.full((S, S), -1, int)
        _metti(tela, _sfuma(_anello(S, S, S / 2, piedi, 16, 2.0), t, SEED + 30, S, S), 2)
        for i, (x, fase) in enumerate(croci):
            y = piedi - 8 - ((t + fase) % 1.0) * 34
            s = 3.2 if (t + fase) % 1.0 < 0.6 else 2.2
            m = _forme(S, S, _lin(x - s, y, x + s, y, 1.6), _lin(x, y - s, x, y + s, 1.6))
            _metti(tela, m, 3)
        out.append(_contorno(tela))
    return out


def evoca(n, S=96):
    """summon: lampo di una colonna di luce, poi il cerchio a terra con le rune che si spegne."""
    piedi = S / 2 + 12
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        tela = np.full((S, S), -1, int)
        if k == 0:
            col = _forme(S, S, _pol((S / 2 - 7, piedi), (S / 2 + 7, piedi), (S / 2 + 3, 4), (S / 2 - 3, 4)))
            _metti(tela, col | _anello(S, S, S / 2, piedi, 26, 3.0), 3)
            out.append(_contorno(tela))
            continue
        cerchio = _anello(S, S, S / 2, piedi, 26, 2.6) | _anello(S, S, S / 2, piedi, 19, 1.4)
        rune = np.zeros((S, S), bool)
        for j in range(8):
            a = j * math.tau / 8 + t * 0.6
            rx, ry = S / 2 + math.cos(a) * 22.5, piedi + math.sin(a) * 11.2
            rune |= _forme(S, S, _lin(rx - 1.5, ry - 1.5, rx + 1.5, ry + 1.5, 1.2), _lin(rx - 1.5, ry + 1.5, rx + 1.5, ry - 1.5, 1.2))
        _metti(tela, _sfuma(cerchio, t, SEED + 40, S, S, 0.8), 2 if t < 0.7 else 1)
        _metti(tela, _sfuma(rune, t, SEED + 41, S, S, 0.8), 3 if t < 0.7 else 2)
        if t < 0.5:                                               # la colonna che si assottiglia
            w = 5 * (1 - t * 2)
            _metti(tela, _forme(S, S, _pol((S / 2 - w, piedi), (S / 2 + w, piedi), (S / 2, 6))), 3)
        out.append(_contorno(tela))
    return out


def scruta(n, S=64):
    """reveal_info: onde tratteggiate che si allargano dalla testa (come un sonar) e un occhio che si apre sopra."""
    cx, cy = S / 2, S / 2 - 8
    x, y = _griglia(S, S)
    tratti = (np.degrees(np.arctan2(y - cy, x - cx)) % 30) < 18
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        tela = np.full((S, S), -1, int)
        for j, r in enumerate((8 + 16 * t, 2 + 16 * t)):
            if r > 3:
                onda = _anello(S, S, cx, cy, r, 1.6, rapp=0.8) & tratti
                _metti(tela, _sfuma(onda, t, SEED + 33 + j, S, S, 0.8), 3 if j == 1 and t < 0.7 else 2)
        apertura = 3.5 * math.sin(math.pi * min(1.0, t * 1.4 + 0.15))
        if apertura > 0.6:
            _metti(tela, _forme(S, S, _ell(cx, cy - 18, 6, apertura)), 2)
            _metti(tela, _forme(S, S, _ell(cx, cy - 18, 1.6, min(1.6, apertura))), 3)
        out.append(_contorno(tela))
    return out


def varco(n, S=64):
    """teleport: lampo di una fessura, il varco ovale che si apre con il vortice, poi si richiude a scintille."""
    cx, cy = S / 2, S / 2
    x, y = _griglia(S, S)
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        tela = np.full((S, S), -1, int)
        if k == 0:
            _metti(tela, _forme(S, S, _ell(cx, cy, 3, 26)), 3)
            out.append(_contorno(tela))
            continue
        apre = math.sin(math.pi * min(1.0, t * 1.3))
        rx = 4 + 10 * apre
        ovale = _forme(S, S, _ell(cx, cy, rx, 24))
        dentro = _forme(S, S, _ell(cx, cy, max(0.5, rx - 2.4), 21.5))
        bordo = ovale & ~dentro
        spirale = dentro & ((np.arctan2((y - cy) / 21.5, (x - cx) / max(1.0, rx)) * 3
                             + np.hypot((x - cx) / max(1.0, rx), (y - cy) / 21.5) * 7 + k * 2) % math.tau < 1.6)
        svanisce = max(0.0, (t - 0.5) * 2)                       # aperto pieno, poi si spegne a pezzi
        _metti(tela, _sfuma(dentro, svanisce, SEED + 50, S, S, 0.9), 1)
        _metti(tela, _sfuma(spirale, svanisce, SEED + 51, S, S, 0.9), 2)
        _metti(tela, _sfuma(bordo, svanisce, SEED + 52, S, S, 0.9), 3)
        out.append(_contorno(tela, ~ovale | (tela >= 0)))
    return out


def miraggio(n, S=64):
    """illusion: due doppi come ologrammi (corpo a righe, contorno acceso) che si staccano ai lati e svaniscono."""
    piedi = S / 2 + 12
    righe = (np.mgrid[0:S, 0:S][0] % 2) == 0
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        tela = np.full((S, S), -1, int)
        for lato in (-1, 1):
            cx = S / 2 + lato * (9 + 9 * t)
            sagoma = _forme(S, S, _ell(cx, piedi - 34, 5, 5), _pol((cx - 8, piedi), (cx - 7, piedi - 26), (cx - 3, piedi - 29),
                                                                    (cx + 3, piedi - 29), (cx + 7, piedi - 26), (cx + 8, piedi)))
            p = np.pad(sagoma, 1)
            bordo = sagoma & ~(p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:])
            seme = SEED + 60 + (lato > 0)
            _metti(tela, _sfuma(sagoma & ~bordo & righe, t, seme, S, S, 0.9), 1)
            _metti(tela, _sfuma(bordo, t, seme + 2, S, S, 0.9), 3 if t < 0.5 else 2)
        out.append(tela)
    return out



# --- gruppo 2 delle primitive (US-8B42) -----------------------------------------------------------------------------

def maleficio(n, S=64):
    """curse: il triangolo del maleficio si accende sopra la testa e si stringe, gocce scure che colano giu'."""
    cx, cy = S / 2, 10
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        tela = np.full((S, S), -1, int)
        r = 9 - 3 * t
        tri = _forme(S, S, _pol((cx - r, cy - r * 0.6), (cx + r, cy - r * 0.6), (cx, cy + r * 0.9)))
        dentro = _forme(S, S, _pol((cx - r + 3, cy - r * 0.6 + 1.6), (cx + r - 3, cy - r * 0.6 + 1.6), (cx, cy + r * 0.9 - 3)))
        _metti(tela, _sfuma(tri & ~dentro, t, SEED + 70, S, S, 0.8), 3 if t < 0.5 else 2)
        _metti(tela, _forme(S, S, _ell(cx, cy - 0.5, 1.4, 1.4)), 3 if t < 0.7 else 1)
        for i, x in enumerate((cx - 11, cx + 2, cx + 12)):
            y = 22 + ((t * 26 + i * 9) % 26)
            _metti(tela, _forme(S, S, _ell(x, y, 1.4, 2.2)), 1)
        _metti(tela, _sfuma(_anello(S, S, cx, S / 2 + 12, 13, 1.6), t, SEED + 71, S, S), 1)
        out.append(_contorno(tela))
    return out


def frattura(n, S=96):
    """terrain_modify: lampo delle crepe a terra, poi spuntoni di roccia e sassi che saltano e ricadono."""
    cx, piedi = S / 2, S / 2 + 12
    rs = np.random.RandomState(SEED + 80)
    crepe = []
    for j in range(6):
        a = j * math.tau / 6 + rs.uniform(-0.3, 0.3)
        pts, x, y = [(cx, piedi)], cx, piedi
        for _ in range(4):
            a += rs.uniform(-0.5, 0.5)
            x, y = x + math.cos(a) * 6, y + math.sin(a) * 3
            pts.append((x, y))
        crepe.append(pts)
    sassi = [(rs.uniform(-30, 30), rs.uniform(10, 22), rs.uniform(1.5, 3.0)) for _ in range(7)]
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        tela = np.full((S, S), -1, int)
        linee = _forme(S, S, *[_lin(a[0], a[1], b[0], b[1], 1.6) for c in crepe for a, b in zip(c, c[1:])])
        if k == 0:
            _metti(tela, linee | _anello(S, S, cx, piedi, 18, 3), 3)
            out.append(_contorno(tela))
            continue
        _metti(tela, _sfuma(linee, t, SEED + 81, S, S, 0.8), 1)
        h = 14 * math.sin(math.pi * min(1.0, t * 1.5))
        if h > 1:
            for dx, hh in ((-16, 0.8), (14, 1.0), (-4, 0.6), (24, 0.5)):
                spun = _forme(S, S, _pol((cx + dx - 4, piedi + 3), (cx + dx + 4, piedi + 3), (cx + dx + 0.5, piedi + 3 - h * hh)))
                _metti(tela, spun, 2)
                _metti(tela, _forme(S, S, _lin(cx + dx - 0.5, piedi + 2, cx + dx + 0.5, piedi + 3 - h * hh, 1)), 3)
        for dx, salto, r in sassi:                              # i sassi saltano verso fuori e ricadono
            u = min(1.0, t * 1.25)
            y = piedi - salto * 4 * u * (1 - u) * 1.6
            if u < 0.98:
                _metti(tela, _forme(S, S, _ell(cx + dx * (1 + 0.5 * u), y, r, r * 0.8)), 2)
        out.append(_contorno(tela))
    return out


def terrore(n, S=64):
    """fear: fili di fumo scuro che salgono ondeggiando attorno a chi lancia e un teschio sopra la testa."""
    cx, piedi = S / 2, S / 2 + 12
    x, y = _griglia(S, S)
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        tela = np.full((S, S), -1, int)
        for i, x0 in enumerate((cx - 18, cx - 11, cx - 5, cx + 6, cx + 12, cx + 19)):
            base = piedi + 2
            cima = base - (14 + 18 * math.sin(math.pi * min(1.0, t + 0.25)) * (0.7 + 0.3 * (i % 3) / 2))
            onda = x0 + 2.4 * np.sin((y + k * 5 + i * 9) * 0.28)
            spess = 0.6 + 0.9 * np.clip((y - cima) / max(1.0, base - cima), 0, 1)
            filo = (np.abs(x - onda) < spess) & (y > cima) & (y < base)
            _metti(tela, _sfuma(filo, max(0.0, t - 0.3), SEED + 90 + i, S, S, 0.9), 1)
            _metti(tela, filo & (y < cima + 3) & (t < 0.8), 2)
        a = math.sin(math.pi * min(1.0, t * 1.3 + 0.1))
        if a > 0.3:
            te = _forme(S, S, _ell(cx, 9, 6, 5.5), _pol((cx - 3.5, 12), (cx + 3.5, 12), (cx + 3, 17), (cx - 3, 17)))
            buchi = _forme(S, S, _ell(cx - 2.4, 9, 1.6, 1.8), _ell(cx + 2.4, 9, 1.6, 1.8), _lin(cx, 12, cx, 13, 1))
            _metti(tela, te & ~buchi, 3 if a > 0.7 else 2)
        out.append(_contorno(tela))
    return out


def furto(n, S=64):
    """steal: lampo davanti, poi tre monete che volano verso chi lancia con la scia (disegnato verso destra)."""
    cx, cy = S / 2, S / 2
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        tela = np.full((S, S), -1, int)
        if k == 0:
            st = _forme(S, S, _lin(cx + 22, cy - 6, cx + 22, cy + 6, 1.6), _lin(cx + 16, cy, cx + 28, cy, 1.6),
                        _ell(cx + 22, cy, 2.6, 2.6))
            _metti(tela, st, 3)
            out.append(_contorno(tela))
            continue
        for i, (dy, ritardo) in enumerate(((-7, 0.0), (0, 0.15), (7, 0.3))):
            u = min(1.0, max(0.0, t * 1.3 - ritardo))
            x = cx + 24 - 22 * u
            y = cy + dy - 8 * math.sin(math.pi * u)
            if u < 0.98:
                _metti(tela, _forme(S, S, _lin(x + 2, y, x + 8, y + 2 * math.cos(math.pi * u), 1.2)), 1)
                _metti(tela, _forme(S, S, _ell(x, y, 2.4, 2.4)), 2)
                _metti(tela, _forme(S, S, _ell(x - 0.6, y - 0.6, 0.9, 0.9)), 3)
        out.append(_contorno(tela))
    return out


def brace(n, S=64):
    """dot: fiamme che guizzano attorno alle gambe e braci che salgono."""
    cx, piedi = S / 2, S / 2 + 12
    rs = np.random.RandomState(SEED + 100)
    braci = [(rs.uniform(-18, 18), rs.uniform(0, 1)) for _ in range(9)]
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        tela = np.full((S, S), -1, int)
        for i, dx in enumerate((-15, -6, 5, 15)):
            h = 13 + 4 * math.sin(k * 2.1 + i * 1.7) - 5 * t
            x0 = cx + dx
            fiamma = _forme(S, S, _ell(x0, piedi, 4.2, 3.6), _pol((x0 - 4.2, piedi - 0.5), (x0 + 4.2, piedi - 0.5),
                                                                 (x0 + 1.5 * math.sin(k * 1.3 + i), piedi - h)))
            cuore = _forme(S, S, _ell(x0, piedi + 0.5, 2.0, 1.8), _pol((x0 - 2, piedi), (x0 + 2, piedi),
                                                                      (x0 + math.sin(k * 1.3 + i), piedi - h * 0.5)))
            _metti(tela, fiamma, 2)
            _metti(tela, cuore, 3)
        for dx, fase in braci:
            y = piedi - 8 - ((t + fase) % 1.0) * 34
            _metti(tela, _forme(S, S, _lin(cx + dx, y, cx + dx, y + 1, 1.3)), 3 if (t + fase) % 1.0 < 0.5 else 2)
        out.append(_contorno(tela))
    return out


def ombra(n, S=64):
    """shadow_meld: una pozza scura si allarga ai piedi e lingue d'ombra salgono ad avvolgere, poi si richiude."""
    cx, piedi = S / 2, S / 2 + 12
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        tela = np.full((S, S), -1, int)
        r = 10 + 10 * math.sin(math.pi * t * 0.9 + 0.2)
        _metti(tela, _forme(S, S, _ell(cx, piedi, r, r * 0.45)), 1)
        x, y = _griglia(S, S)
        for i, x0 in enumerate((cx - 9, cx - 3, cx + 4, cx + 10)):
            alto = piedi - (8 + 22 * math.sin(math.pi * t) * (0.6 + 0.4 * (i % 2)))
            onda = x0 + 2.2 * np.sin((y - piedi) * 0.3 + i + k)
            lingua = (np.abs(x - onda) < 1.4 * (y - alto) / max(1.0, piedi - alto) + 0.5) & (y > alto) & (y < piedi)
            _metti(tela, lingua, 1 if i % 2 else 2)
        out.append(_contorno(tela))
    return out


def riavvolgi(n, S=96):
    """time_rewind: lampo di un anello, poi un quadrante con le tacche e una freccia che gira all'indietro."""
    cx, cy = S / 2, S / 2 - 2
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        tela = np.full((S, S), -1, int)
        anello = _anello(S, S, cx, cy, 26, 2.4, rapp=1.0)
        if k == 0:
            _metti(tela, anello, 3)
            out.append(_contorno(tela))
            continue
        tacche = _forme(S, S, *[_lin(cx + math.cos(a) * 22, cy + math.sin(a) * 22, cx + math.cos(a) * 25,
                                     cy + math.sin(a) * 25, 1.4) for a in np.linspace(0, math.tau, 12, endpoint=False)])
        _metti(tela, _sfuma(anello | tacche, t, SEED + 110, S, S, 0.8), 2)
        a0 = -math.pi / 2 - t * math.tau * 0.6                    # la freccia gira in senso antiorario
        R = 32
        arco = _forme(S, S, *[_lin(cx + math.cos(a) * R, cy + math.sin(a) * R, cx + math.cos(a + 0.12) * R,
                                   cy + math.sin(a + 0.12) * R, 3.0) for a in np.linspace(a0, a0 + 1.6, 14)])
        punta = np.array([cx + math.cos(a0) * R, cy + math.sin(a0) * R])
        avanti = np.array([math.sin(a0), -math.cos(a0)])         # tangente nel verso antiorario
        fuori = np.array([math.cos(a0), math.sin(a0)])
        testa = _forme(S, S, _pol(tuple(punta + avanti * 7), tuple(punta + fuori * 5), tuple(punta - fuori * 5)))
        _metti(tela, _sfuma(arco | testa, max(0.0, t - 0.4), SEED + 111, S, S, 0.9), 3)
        out.append(_contorno(tela))
    return out


def fioritura(n, S=64):
    """plant_growth: germogli che crescono attorno ai piedi, mettono le foglie e i fiori, poi si ritirano."""
    cx, piedi = S / 2, S / 2 + 12
    piante = [(-18, 1.0), (-9, 0.75), (9, 0.9), (18, 0.7)]
    out = []
    for k in range(n):
        t = k / max(1, n - 1)
        tela = np.full((S, S), -1, int)
        cresce = math.sin(math.pi * min(1.0, 0.18 + t * 0.95))
        for i, (dx, alt) in enumerate(piante):
            h = 24 * alt * cresce
            x0 = cx + dx
            xt = x0 + math.sin(i * 1.7) * 2
            _metti(tela, _forme(S, S, _lin(x0, piedi + 2, xt, piedi + 2 - h, 1.8)), 2)
            if h > 6:
                for j, f in enumerate((0.45, 0.72)):
                    ym = piedi + 2 - h * f
                    xm = x0 + (xt - x0) * f
                    lato = 1 if (i + j) % 2 else -1
                    _metti(tela, _forme(S, S, _pol((xm, ym), (xm + lato * 7, ym - 4), (xm + lato * 5, ym + 1))), 3)
            if h > 14 and i % 2 == 0:
                yf = piedi + 2 - h
                petali = _forme(S, S, *[_ell(xt + math.cos(a) * 2.6, yf + math.sin(a) * 2.6, 2.0, 2.0)
                                        for a in np.linspace(0, math.tau, 5, endpoint=False)])
                _metti(tela, petali, 3)
                _metti(tela, _forme(S, S, _ell(xt, yf, 1.4, 1.4)), 2)
        out.append(_contorno(tela))
    return out


def main():
    pv = json.load(open(os.path.join(ROOT, "data", "vfx.json")))["primitive_vfx"]
    f = lambda tipo: pv[tipo]["frames"]                          # noqa: E731
    gruppi = {
        "vfx_attacchi": {
            pv["melee_arc"]["sprite"]: slash(f("melee_arc")),
            pv["projectile"]["sprite"]: bolt(f("projectile")),
            pv["projectile"]["scoppio"]["sprite"]: scoppio(pv["projectile"]["scoppio"]["frames"]),
            pv["dash"]["sprite"]: streak(f("dash")),
        },
        "vfx_primitive_1": {
            pv["buff_stat"]["sprite"]: rune_su(f("buff_stat")),
            pv["debuff_stat"]["sprite"]: rune_su(f("debuff_stat"), giu=True),
            pv["aura"]["sprite"]: aura_anello(f("aura")),
            pv["heal"]["sprite"]: ricuci(f("heal")),
            pv["summon"]["sprite"]: evoca(f("summon")),
            pv["reveal_info"]["sprite"]: scruta(f("reveal_info")),
            pv["teleport"]["sprite"]: varco(f("teleport")),
            pv["illusion"]["sprite"]: miraggio(f("illusion")),
        },
        "vfx_primitive_2": {
            pv["curse"]["sprite"]: maleficio(f("curse")),
            pv["terrain_modify"]["sprite"]: frattura(f("terrain_modify")),
            pv["fear"]["sprite"]: terrore(f("fear")),
            pv["steal"]["sprite"]: furto(f("steal")),
            pv["dot"]["sprite"]: brace(f("dot")),
            pv["shadow_meld"]["sprite"]: ombra(f("shadow_meld")),
            pv["time_rewind"]["sprite"]: riavvolgi(f("time_rewind")),
            pv["plant_growth"]["sprite"]: fioritura(f("plant_growth")),
        },
    }
    palette = json.load(open(os.path.join(ROOT, "data", "vfx.json")))["pathway_palette_visiva"]
    os.makedirs(OUT, exist_ok=True)
    for gruppo, fogli in gruppi.items():
        righe = []
        for nome, frames in fogli.items():
            Image.fromarray(np.concatenate([png(fr) for fr in frames], 1)).save(os.path.join(OUT, nome + ".png"))
            for pw in ("twilight_giant", "darkness", "moon"):
                col = [colora(fr, palette[pw]) for fr in frames]
                if pw == "twilight_giant":
                    lampo = col[0].copy()
                    lampo[frames[0] >= 2, :3] = 255                # il primo frame come lo fa il gioco (bianco)
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
        dest = os.path.join(os.path.dirname(REVISIONE), gruppo + ".png")
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        Image.fromarray(im).resize((w * 3, h * 3), Image.NEAREST).save(dest)
        print(f"{len(fogli)} fogli in assets/vfx/: {', '.join(fogli)}; foglio in {os.path.relpath(dest, ROOT)}")


if __name__ == "__main__":
    main()
