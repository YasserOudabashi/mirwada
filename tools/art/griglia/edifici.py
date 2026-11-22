"""Edifici a griglia (stile delle figure: contorno nero 1 px, 3 toni, una luce in alto a sinistra), 64 px per casella
come le figure, cosi' case e personaggi hanno la stessa grana. Vista top-down 3/4: dall'alto il tetto (o la terrazza)
che copre il sedime, davanti la facciata alta `muro` pixel.

Ogni edificio e' una funzione che compone pezzi (blocchi di pietra, marmo, tegole, colonne, archi, finestre, frontone,
gradini, fregio, crepe, muschio): ogni edificio ha il suo disegno, i pezzi sono il vocabolario. Niente caso: il seme e'
fisso per edificio.
"""
import numpy as np

from .pixel import Rampa, Tela, colore

PX = 64                                     # pixel per casella (come le figure)


class Disegno:
    """Una tela con il sedime: x0..x1 in orizzontale, `tetto_y` (alto del tetto visto dall'alto), `gronda_y` (dove il
    tetto incontra la facciata), `terra_y` (il piede della facciata)."""

    def __init__(self, larg, prof, muro, sopra=40, margine=8, seme=1):
        self.w, self.h = larg * PX + 2 * margine, prof * PX + muro + sopra + margine
        self.t = Tela(self.w, self.h)
        self.x0, self.x1 = margine, margine + larg * PX
        self.terra_y = self.h - margine
        self.gronda_y = self.terra_y - muro
        self.tetto_y = self.gronda_y - prof * PX
        self.rng = np.random.RandomState(seme)

    def rett(self, x, y, w, h, col, gruppo, separa=False):
        m = np.zeros((self.h, self.w), bool)
        m[max(y, 0):max(y + h, 0), max(x, 0):max(x + w, 0)] = True
        c = np.zeros((self.h, self.w, 3), np.uint8)
        c[m] = col
        self.t.metti(m, c, gruppo, separa=separa)
        return m

    def pixel(self, punti, col, gruppo):
        m = np.zeros((self.h, self.w), bool)
        for x, y in punti:
            if 0 <= x < self.w and 0 <= y < self.h:
                m[y, x] = True
        c = np.zeros((self.h, self.w, 3), np.uint8)
        c[m] = col
        self.t.metti(m, c, gruppo, separa=False)

    # --- tessiture -------------------------------------------------------------------------------------------------
    def blocchi(self, x, y, w, h, r, gruppo, bw=16, bh=8, malta=None, varia=0.25, rotti=0.0, separa=True):
        """Muro di blocchi sfalsati: malta scura, filo di luce in alto a sinistra di ogni blocco, ombra in basso."""
        malta = r.toni[0] if malta is None else malta
        m = np.zeros((self.h, self.w), bool)
        c = np.zeros((self.h, self.w, 3), np.uint8)
        for j, yy in enumerate(range(y, y + h, bh)):
            off = (bw // 2) * (j % 2)
            for xx in range(x - off, x + w, bw):
                a, b = max(xx, x), min(xx + bw, x + w)
                hh = min(bh, y + h - yy)
                if b <= a or hh <= 0:
                    continue
                if rotti and self.rng.rand() < rotti:
                    continue
                tono = r.toni[2] if self.rng.rand() < varia else r.toni[1]
                m[yy:yy + hh, a:b] = True
                c[yy:yy + hh, a:b] = tono
                c[yy:yy + hh, a] = malta if xx >= x else c[yy:yy + hh, a]
                c[yy, a:b] = malta
                if hh > 2:
                    c[yy + 1, a + 1:b] = r.toni[2]          # luce in alto
                    c[yy + hh - 1, a + 1:b] = r.toni[0]     # ombra in basso
        self.t.metti(m, c, gruppo, separa=separa)
        return m

    def tegole(self, x, y, w, h, r, gruppo, passo=8, separa=True):
        """Tegole a coppi visti dall'alto: file di archetti, luce sul bordo alto, ombra sotto ogni fila."""
        m = np.zeros((self.h, self.w), bool)
        c = np.zeros((self.h, self.w, 3), np.uint8)
        m[y:y + h, x:x + w] = True
        c[y:y + h, x:x + w] = r.toni[1]
        for j, yy in enumerate(range(y, y + h, 6)):
            off = (passo // 2) * (j % 2)
            c[min(yy + 5, y + h - 1), x:x + w] = r.toni[0]
            for xx in range(x - off, x + w, passo):
                for k in range(passo):
                    px = xx + k
                    if x <= px < x + w:
                        cur = abs(k - passo / 2 + 0.5)
                        if cur > passo / 2 - 1.5:
                            c[yy:min(yy + 5, y + h), px] = r.toni[0]
                        elif k < passo / 2 - 1:
                            c[yy + 1:min(yy + 3, y + h), px] = r.toni[2]
        self.t.metti(m, c, gruppo, separa=separa)
        return m

    def lastre(self, x, y, w, h, r, gruppo, lw=24, lh=16, separa=True):
        return self.blocchi(x, y, w, h, r, gruppo, bw=lw, bh=lh, varia=0.15, separa=separa)

    # --- pezzi -----------------------------------------------------------------------------------------------------
    def colonna(self, cx, y_alto, y_basso, raggio, r, gruppo, scanalata=True, rotta=0):
        """Colonna tonda vista di fronte: ombreggiata come un cilindro, capitello e base piu' larghi."""
        m = np.zeros((self.h, self.w), bool)
        c = np.zeros((self.h, self.w, 3), np.uint8)
        top = y_alto + rotta
        for xx in range(cx - raggio, cx + raggio + 1):
            u = (xx - cx) / max(raggio, 1)
            tono = r.toni[2] if u < -0.3 else r.toni[0] if u > 0.45 else r.toni[1]
            m[top:y_basso, xx] = True
            c[top:y_basso, xx] = tono
            if scanalata and (xx - cx) % 3 == 0 and abs(u) < 0.8:
                c[top:y_basso, xx] = r.toni[0] if u > -0.3 else r.toni[1]
        if not rotta:                                # capitello
            m[y_alto - 4:y_alto, cx - raggio - 3:cx + raggio + 4] = True
            c[y_alto - 4:y_alto, cx - raggio - 3:cx + raggio + 4] = r.toni[1]
            c[y_alto - 4, cx - raggio - 3:cx + raggio + 4] = r.toni[2]
            c[y_alto - 1, cx - raggio - 3:cx + raggio + 4] = r.toni[0]
        else:                                        # spezzata: bordo frastagliato
            for xx in range(cx - raggio, cx + raggio + 1):
                d = self.rng.randint(0, 4)
                m[top:top + d, xx] = False
        m[y_basso - 3:y_basso, cx - raggio - 2:cx + raggio + 3] = True        # base
        c[y_basso - 3:y_basso, cx - raggio - 2:cx + raggio + 3] = r.toni[1]
        c[y_basso - 3, cx - raggio - 2:cx + raggio + 3] = r.toni[2]
        self.t.metti(m, c, gruppo, separa=True)

    def arco(self, cx, y_basso, larg, alto, interno, gruppo, chiave=None, cornice=None):
        """Porta o varco ad arco tondo: interno scuro, cornice di conci con la chiave in cima."""
        m = np.zeros((self.h, self.w), bool)
        c = np.zeros((self.h, self.w, 3), np.uint8)
        rr = larg / 2
        ys, xs = np.mgrid[0:self.h, 0:self.w]
        dentro = (np.abs(xs + 0.5 - cx) <= rr) & (ys < y_basso) & (
            (ys >= y_basso - alto + rr) | (np.hypot(xs + 0.5 - cx, ys + 0.5 - (y_basso - alto + rr)) <= rr))
        if cornice is not None:
            fuori = (np.abs(xs + 0.5 - cx) <= rr + 4) & (ys < y_basso) & (
                (ys >= y_basso - alto + rr) | (np.hypot(xs + 0.5 - cx, ys + 0.5 - (y_basso - alto + rr)) <= rr + 4))
            cm = fuori & ~dentro
            m |= cm
            c[cm] = cornice.toni[1]
            c[cm & (xs < cx)] = cornice.toni[2]
            c[cm & (xs > cx + rr)] = cornice.toni[0]
            if chiave is not None:
                k = (np.abs(xs + 0.5 - cx) <= 3) & (ys >= y_basso - alto - 4) & (ys < y_basso - alto + 3)
                m |= k
                c[k] = chiave
        m |= dentro
        c[dentro] = interno
        self.t.metti(m, c, gruppo, separa=True)
        return dentro

    def porta_legno(self, mask, r, gruppo, borchie=None):
        """Battenti di legno dentro una maschera (l'arco): assi verticali, bordo in ombra, borchie."""
        ys, xs = np.nonzero(mask)
        c = np.zeros((self.h, self.w, 3), np.uint8)
        x0, x1 = xs.min(), xs.max()
        for y, x in zip(ys, xs):
            k = (x - x0) % 5
            c[y, x] = r.toni[2] if k == 1 else r.toni[0] if k == 4 else r.toni[1]
        mid = (x0 + x1) // 2
        c[mask & (np.arange(self.w)[None, :] == mid)] = r.toni[0]
        self.t.metti(mask, c, gruppo, separa=False)
        if borchie is not None:
            pts = [(x, y) for x in (x0 + 3, x1 - 3, mid - 2, mid + 2) for y in range(ys.max() - 4, ys.min() + 6, -8)
                   if mask[y, x]]
            self.pixel(pts, borchie, gruppo + "_b")

    def finestra(self, x, y, w, h, vetro, telaio, gruppo, arco=False, davanzale=None):
        m = np.zeros((self.h, self.w), bool)
        c = np.zeros((self.h, self.w, 3), np.uint8)
        m[y:y + h, x:x + w] = True
        c[y:y + h, x:x + w] = vetro
        c[y:y + 2, x:x + w] = telaio.toni[0]                 # ombra dell'architrave sul vetro
        c[y + h // 2, x:x + w] = telaio.toni[1]
        c[y:y + h, x + w // 2] = telaio.toni[1]
        c[y + 3:y + 5, x + 2:x + 4] = colore("grey_l")       # riflesso
        if arco:
            for xx in range(x, x + w):
                d = abs(xx - (x + w / 2 - 0.5)) / (w / 2)
                cut = int(round((1 - np.sqrt(max(1 - d * d, 0))) * w / 2))
                m[y:y + cut, xx] = False
        self.t.metti(m, c, gruppo, separa=True)
        if davanzale is not None:
            self.rett(x - 2, y + h, w + 4, 3, davanzale.toni[2], gruppo + "_d", separa=True)

    def gradini(self, cx, y_basso, larg, n, r, gruppo, alto=5, sporge=6):
        for i in range(n):
            w = larg + 2 * sporge * (n - 1 - i)
            y = y_basso - (n - i) * alto
            m = self.rett(cx - w // 2, y, w, alto, r.toni[1], f"{gruppo}{i}", separa=True)
            self.t.col[y, cx - w // 2:cx + w // 2] = r.toni[2]
            self.t.col[y + alto - 1, cx - w // 2:cx + w // 2] = r.toni[0]

    def fregio(self, x, y, w, r, gruppo, motivo=("..#..", ".#.#.", "#...#", ".#.#.", "..#.."), passo=10):
        """Fascia scolpita: un motivo ripetuto in incavo (ombra) e rilievo (luce)."""
        h = len(motivo) + 4
        self.rett(x, y, w, h, r.toni[1], gruppo, separa=True)
        self.t.col[y, x:x + w] = r.toni[2]
        self.t.col[y + h - 1, x:x + w] = r.toni[0]
        pts_o, pts_l = [], []
        for xx in range(x + 3, x + w - len(motivo[0]) - 1, passo):
            for j, riga in enumerate(motivo):
                for i, ch in enumerate(riga):
                    if ch == "#":
                        pts_o.append((xx + i, y + 2 + j))
                        pts_l.append((xx + i - 1, y + 1 + j))
        self.pixel(pts_l, r.toni[2], gruppo + "_l")
        self.pixel(pts_o, r.toni[0], gruppo + "_o")

    def crepe(self, x, y, w, h, n, col, gruppo):
        pts = []
        for _ in range(n):
            px, py = x + self.rng.randint(0, w), y + self.rng.randint(0, h)
            for _ in range(self.rng.randint(6, 14)):
                pts.append((px, py))
                px += self.rng.choice((-1, 0, 1))
                py += 1
        self.pixel(pts, col, gruppo)

    def muschio(self, x, y, w, h, n, r, gruppo):
        """Ciuffi di muschio/edera: grappoli di 3 toni verdi che pendono."""
        pts = {0: [], 1: [], 2: []}
        for _ in range(n):
            cx, cy = x + self.rng.randint(0, w), y + self.rng.randint(0, h)
            for _ in range(self.rng.randint(8, 22)):
                dx, dy = self.rng.randint(-3, 4), self.rng.randint(-2, 5)
                t = 2 if dy < 0 and dx < 1 else 0 if dy > 2 else 1
                pts[t].append((cx + dx, cy + dy))
        for t in (1, 0, 2):
            self.pixel(pts[t], r.toni[t], gruppo + str(t))

    def fine(self):
        self.t.contorno()
        return self.t.immagine()


# --- rampe -----------------------------------------------------------------------------------------------------------
R = {
    "arenaria": Rampa("brown", "tan", "cream"),
    "arenaria_scura": Rampa("brown_d", "brown", "tan"),
    "marmo": Rampa("grey", "grey_l", "white"),
    "ardesia": Rampa("slate_d", "slate", "grey"),
    "bronzo": Rampa("brown_d", "orange_d", "amber"),
    "legno": Rampa("brown_dd", "brown_d", "brown"),
    "muschio": Rampa("green_d", "green_m", "green"),
    "rosso": Rampa("red_d", "red", "pink"),
    "cotto": Rampa("red_d", "rust", "orange_d"),
    "coppi": Rampa("brown_dd", "red_d", "rust"),
    "pietra": Rampa("slate_d", "slate", "grey"),
    "pietra_chiara": Rampa("grey", "grey_l", "white"),
    "intonaco": Rampa("tan", "cream", "white"),
    "assi": Rampa("brown_dd", "brown_d", "brown"),
    "bianco": Rampa("grey", "grey_l", "white"),
    "blu": Rampa("navy", "blue_d", "blue"),
    "verde": Rampa("teal_d", "green_d", "green_m"),
    "giallo": Rampa("orange_d", "amber", "yellow"),
}
BUIO = colore("brown_dd")
VETRO = colore("navy")


def casa_antica():
    """Centro antico: una casa di arenaria fatta da una civilta' antica. Terrazza piatta col parapetto rotto, un angolo
    crollato, grande arco d'ingresso con la chiave scolpita, due mezze colonne, fregio di glifi, finestre ad arco,
    crepe, muschio ed edera, un rocchio di colonna spezzata sulla terrazza. 4 x 3 caselle."""
    d = Disegno(4, 3, muro=112, seme=11)
    x0, x1 = d.x0, d.x1
    # terrazza vista dall'alto: lastre consumate e spaccate, parapetto basso, angolo nord-est crollato con le macerie,
    # una botola ad arco (la scala che scende), il rocchio di una colonna spezzata, erba fra le lastre
    d.lastre(x0, d.tetto_y + 6, x1 - x0, d.gronda_y - d.tetto_y - 6, R["arenaria_scura"], "terrazza", lw=20, lh=14)
    d.crepe(x0 + 10, d.tetto_y + 12, x1 - x0 - 20, d.gronda_y - d.tetto_y - 40, 9, R["arenaria_scura"].toni[0],
            "crepe_t")
    d.blocchi(x0, d.tetto_y, x1 - x0 - 56, 8, R["arenaria"], "parapetto", bw=12, bh=8, rotti=0.15)
    d.blocchi(x0, d.tetto_y, 8, d.gronda_y - d.tetto_y, R["arenaria"], "parapetto_o", bw=8, bh=12)
    d.blocchi(x1 - 8, d.tetto_y + 60, 8, d.gronda_y - d.tetto_y - 60, R["arenaria"], "parapetto_e", bw=8, bh=12,
              rotti=0.3)
    ys, xs = np.mgrid[0:d.h, 0:d.w]                 # l'angolo crollato: si toglie un triangolo di tetto
    crollo = (xs - (x1 - 64)) * 1.0 > (ys - d.tetto_y) * 1.1 + d.rng.rand(d.h, d.w) * 6
    crollo &= (ys < d.tetto_y + 64) & (xs >= x1 - 64)
    d.t.a[crollo] = False
    d.t.grp[crollo] = -1
    for k in range(7):                              # macerie sull'orlo del crollo
        bx, by = x1 - 60 + k * 8 + d.rng.randint(-2, 3), d.tetto_y + 4 + k * 8 + d.rng.randint(-2, 3)
        d.blocchi(bx, by, 8 + d.rng.randint(0, 4), 6, R["arenaria"], f"maceria{k}", bw=12, bh=6)
    botola = d.arco(x0 + 150, d.tetto_y + 100, 26, 30, BUIO, "botola", cornice=R["arenaria"])
    d.colonna(x0 + 60, d.tetto_y + 66, d.tetto_y + 92, 8, R["arenaria"], "rocchio", rotta=6)
    d.blocchi(x0 + 78, d.tetto_y + 84, 22, 8, R["arenaria"], "rocchio2", bw=11, bh=8)     # un pezzo caduto accanto
    d.muschio(x0 + 10, d.tetto_y + 20, 200, 120, 9, R["muschio"], "muschio_t")
    # facciata
    fy = d.gronda_y
    d.blocchi(x0, fy, x1 - x0, d.terra_y - fy, R["arenaria"], "facciata", bw=16, bh=10, varia=0.3)
    d.fregio(x0, fy + 4, x1 - x0, R["arenaria_scura"], "fregio",
             motivo=(".###.", "#...#", "#.#.#", "#...#", ".###."), passo=12)
    cx = (x0 + x1) // 2
    vano = d.arco(cx, d.terra_y, 52, 76, BUIO, "arco", chiave=R["arenaria"].toni[2], cornice=R["arenaria_scura"])
    d.porta_legno(vano & (np.arange(d.h)[:, None] > d.terra_y - 60), R["legno"], "porta", borchie=colore("amber"))
    for sx in (-1, 1):                                  # mezze colonne ai lati dell'arco
        d.colonna(cx + sx * 46, fy + 22, d.terra_y, 6, R["arenaria"], f"col{sx}")
        d.finestra(cx + sx * 88 - 9, fy + 34, 18, 26, VETRO, R["arenaria_scura"], f"fin{sx}", arco=True,
                   davanzale=R["arenaria"])
    d.gradini(cx, d.terra_y, 60, 2, R["arenaria_scura"], "soglia", alto=3, sporge=4)
    d.crepe(x0 + 6, fy + 14, x1 - x0 - 12, 60, 7, R["arenaria"].toni[0], "crepe")
    d.muschio(x0, fy + 14, 30, 80, 4, R["muschio"], "edera_o")     # edera che scende dall'angolo
    d.muschio(x1 - 26, fy + 40, 26, 60, 3, R["muschio"], "edera_e")
    d.muschio(x0 + 20, d.terra_y - 10, x1 - x0 - 40, 6, 6, R["muschio"], "erba_piede")
    return d.fine()


def museo():
    """Museo: tempio di marmo bianco. Scalinata larga, sei colonne scanalate, frontone triangolare con un rilievo
    (anfora e rami), tetto di ardesia a due falde visto dall'alto, portone di bronzo, due stendardi rossi con l'anfora
    (il simbolo del museo, senza scritte). 6 x 4 caselle."""
    d = Disegno(6, 4, muro=132, sopra=10, seme=23)
    x0, x1 = d.x0, d.x1
    cx = (x0 + x1) // 2
    # tetto a padiglione visto dall'alto: quattro falde (nord in ombra, ovest in luce, est mezza ombra, sud davanti) con
    # le creste chiare; cosi' il sedime si legge come un tetto e non come un muro alto
    ty, gy = d.tetto_y, d.gronda_y
    d.tegole(x0 + 6, ty, x1 - x0 - 12, gy - ty, R["ardesia"], "tetto")
    colmo = ty + (gy - ty) * 2 // 5
    ys, xs = np.mgrid[0:d.h, 0:d.w]
    dn, ds = (ys - ty) / (colmo - ty), (gy - ys) / (gy - colmo)
    dw, de = (xs - x0 - 6) / 110.0, (x1 - 6 - xs) / 110.0
    falda = np.argmin(np.stack([dn, ds, dw, de]), axis=0)          # 0 nord, 1 sud, 2 ovest, 3 est
    tetto = (ys >= ty) & (ys < gy) & (xs >= x0 + 6) & (xs < x1 - 6) & d.t.a
    luce = np.array([0.7, 1.0, 1.15, 0.84])[falda]
    d.t.col[tetto] = np.clip(d.t.col[tetto].astype(float) * luce[tetto, None], 0, 255).astype(np.uint8)
    bordo = np.zeros_like(tetto)                                   # le creste fra due falde
    bordo[1:, :] |= falda[1:, :] != falda[:-1, :]
    bordo[:, 1:] |= falda[:, 1:] != falda[:, :-1]
    bordo &= tetto & (ys > ty + 2) & (ys < gy - 2) & (xs > x0 + 8) & (xs < x1 - 8)
    c = np.zeros((d.h, d.w, 3), np.uint8)
    c[bordo] = R["marmo"].toni[1]
    d.t.metti(bordo, c, "creste", separa=False)
    # lucernari appoggiati sulle falde (mai a cavallo del colmo): ognuno sta dentro una falda sola, prende la luce
    # di quella falda e ha il bordo spesso dal lato dove la falda scende (sud: sotto, nord: sopra, ovest/est: di lato),
    # cosi' si legge che e' inclinato come il tetto. Pochi e sparsi.
    def lucernario(i, lx, ly, w, h, verso):
        f = {"n": 0, "s": 1, "o": 2, "e": 3}[verso]
        assert (falda[ly:ly + h, lx:lx + w] == f).all(), f"lucernario {i} fuori dalla sua falda"
        k = luce[ly + h // 2, lx + w // 2]
        tono = lambda c: tuple(int(min(255, v * k)) for v in c)
        d.rett(lx - 2, ly - 2, w + 4, h + 4, tono(R["marmo"].toni[1]), f"luc{i}", separa=True)
        d.rett(lx, ly, w, h, tono(VETRO), f"luc{i}v", separa=False)
        bx, by, bw, bh = {"s": (lx - 2, ly + h, w + 4, 3), "n": (lx - 2, ly - 4, w + 4, 3),
                          "o": (lx - 4, ly - 2, 3, h + 4), "e": (lx + w + 1, ly - 2, 3, h + 4)}[verso]
        d.rett(bx, by, bw, bh, tono(R["marmo"].toni[0]), f"luc{i}b", separa=False)   # lo spessore verso valle
        if verso in "sn":
            d.rett(lx + w // 2 - 1, ly, 2, h, tono(R["marmo"].toni[1]), f"luc{i}t", separa=False)
        else:
            d.rett(lx, ly + h // 2 - 1, w, 2, tono(R["marmo"].toni[1]), f"luc{i}t", separa=False)
        d.pixel([(lx + 2 + q, ly + 2 + q // 2) for q in range(min(5, w - 4))], tono(colore("grey_l")), f"luc{i}r")
    for i, (lx, ly, w, h, verso) in enumerate(((x0 + 108, colmo + 44, 30, 22, "s"), (x0 + 236, colmo + 70, 22, 16, "s"),
                                               (x0 + 40, colmo + 6, 12, 26, "o"), (x0 + 250, ty + 30, 24, 12, "n"))):
        lucernario(i, lx, ly, w, h, verso)
    for sx in (x0 + 12, x1 - 18):                                  # acroteri sugli spigoli del tetto
        d.pixel([(sx + i, ty + 6 + j) for j in range(6) for i in range(6) if (i - 2.5) ** 2 + (j - 2.5) ** 2 < 8],
                R["marmo"].toni[2], f"acro{sx}")
    d.rett(x0 + 6, d.gronda_y - 5, x1 - x0 - 12, 5, R["marmo"].toni[0], "gronda", separa=True)
    fy = d.gronda_y
    # trabeazione e frontone
    d.blocchi(x0, fy, x1 - x0, 14, R["marmo"], "architrave", bw=32, bh=7, varia=0.1)
    d.fregio(x0 + 4, fy + 14, x1 - x0 - 8, R["marmo"], "fregio",
             motivo=("#.#.#", ".....", "#.#.#"), passo=8)
    ys, xs = np.mgrid[0:d.h, 0:d.w]
    alto_f = 46
    tri = (ys >= fy - alto_f + np.abs(xs - cx) * alto_f / ((x1 - x0) / 2 - 6)) & (ys < fy) & (xs > x0 + 6) & (xs < x1 - 6)
    col = np.zeros((d.h, d.w, 3), np.uint8)
    col[tri] = R["marmo"].toni[1]
    col[tri & (xs < cx)] = R["marmo"].toni[2]
    d.t.metti(tri, col, "frontone", separa=True)
    timp = (ys >= fy - alto_f + 9 + np.abs(xs - cx) * (alto_f - 9) / ((x1 - x0) / 2 - 20)) & (ys < fy - 4)
    col2 = np.zeros((d.h, d.w, 3), np.uint8)
    col2[timp] = R["marmo"].toni[0]
    d.t.metti(timp, col2, "timpano", separa=False)
    anfora = [".....##.....", "....####....", ".....##.....", "...######...", "..########..", ".##########.",
              ".##########.", "..########..", "...######...", "....####...."]
    pts = [(cx - 6 + i, fy - 26 + j) for j, r in enumerate(anfora) for i, ch in enumerate(r) if ch == "#"]
    d.pixel(pts, R["marmo"].toni[2], "rilievo")
    statua = ["..##..", "..##..", ".####.", "######", ".####.", ".#..#.", ".#..#.", "######"]   # acroteri
    for sx, yy in ((cx - 3, fy - alto_f - 8), (x0 + 8, fy - 8), (x1 - 14, fy - 8)):
        d.pixel([(sx + i, yy + j) for j, r in enumerate(statua) for i, ch in enumerate(r) if ch == "#" and i < 3],
                R["marmo"].toni[2], f"statua{sx}l")
        d.pixel([(sx + i, yy + j) for j, r in enumerate(statua) for i, ch in enumerate(r) if ch == "#" and i >= 3],
                R["marmo"].toni[1], f"statua{sx}o")
    for sx in (-1, 1):                                  # rami ai lati dell'anfora
        d.pixel([(cx + sx * (10 + k), fy - 12 - k // 2) for k in range(18)], R["marmo"].toni[2], f"ramo{sx}")
        d.pixel([(cx + sx * (12 + k), fy - 16 - k // 2) for k in range(0, 16, 3)], R["marmo"].toni[2], f"fog{sx}")
    # cella dietro le colonne (in ombra), portone di bronzo
    d.rett(x0 + 20, fy + 24, x1 - x0 - 40, d.terra_y - fy - 40, R["marmo"].toni[0], "cella", separa=True)
    d.blocchi(x0 + 20, fy + 24, x1 - x0 - 40, d.terra_y - fy - 40, Rampa("slate", "grey", "grey_l"), "cella_m",
              bw=24, bh=12, varia=0.05, separa=False)
    d.rett(cx - 22, d.terra_y - 92, 44, 76, R["bronzo"].toni[0], "portale", separa=True)
    vano = d.rett(cx - 18, d.terra_y - 88, 36, 72, R["bronzo"].toni[1], "portone", separa=False)
    d.porta_legno(vano, R["bronzo"], "portone_p", borchie=colore("yellow"))
    for sx in (-1, 1):                                  # stendardi rossi con l'anfora
        bx = cx + sx * 64 - 10
        d.rett(bx, fy + 26, 20, 40, R["rosso"].toni[1], f"stend{sx}", separa=True)
        d.rett(bx, fy + 26, 4, 40, R["rosso"].toni[2], f"stend{sx}l", separa=False)
        d.rett(bx + 16, fy + 26, 4, 40, R["rosso"].toni[0], f"stend{sx}o", separa=False)
        d.pixel([(bx + 6 + i, fy + 36 + j) for j, r in enumerate(anfora[::2]) for i, ch in enumerate(r[3:11])
                 if ch == "#"], colore("amber"), f"stend{sx}a")
        d.pixel([(bx + k, fy + 66 + (k % 4 == 0)) for k in range(20)], R["rosso"].toni[0], f"stend{sx}f")
    # arte sulla parete della cella: due affreschi incorniciati d'oro nelle campate esterne (un paesaggio e una nave),
    # due nicchie con una statua sotto gli stendardi, una fascia a mosaico in basso
    passo = (x1 - x0 - 60) / 5
    for k, scena in ((0, "colline"), (4, "nave")):
        fx = int(x0 + 30 + passo * (k + 0.5)) - 16
        fy2 = fy + 40
        d.rett(fx - 2, fy2 - 2, 36, 46, colore("amber"), f"cornice{k}", separa=True)
        d.rett(fx - 2, fy2 - 2, 36, 2, colore("yellow"), f"cornice{k}l", separa=False)
        d.rett(fx, fy2, 32, 42, colore("cyan"), f"aff{k}", separa=False)
        d.rett(fx, fy2 + 14, 32, 28, colore("blue"), f"aff{k}b", separa=False)
        if scena == "colline":
            d.pixel([(fx + i, fy2 + j) for i in range(32) for j in range(42)
                     if j > 22 + 6 * np.sin(i / 5.0)], colore("green_m"), f"aff{k}c")
            d.pixel([(fx + i, fy2 + j) for i in range(32) for j in range(42) if j > 32 + 3 * np.sin(i / 3.0 + 1)],
                    colore("green_d"), f"aff{k}c2")
            d.pixel([(fx + 22 + i, fy2 + 6 + j) for i in range(5) for j in range(5) if (i - 2) ** 2 + (j - 2) ** 2 < 6],
                    colore("yellow"), f"aff{k}s")
        else:
            d.pixel([(fx + 6 + i, fy2 + 28 + j) for j in range(5) for i in range(20 - j * 2) if i >= j],
                    colore("brown_d"), f"aff{k}n")
            d.pixel([(fx + 15, fy2 + 12 + j) for j in range(16)], colore("brown_dd"), f"aff{k}a")
            d.pixel([(fx + 16 + i, fy2 + 13 + j) for j in range(12) for i in range(8 - abs(j - 6) // 1) if i < 8],
                    colore("white"), f"aff{k}v")
            d.pixel([(fx + i, fy2 + 36 + (i % 5 == 0)) for i in range(32)], colore("white"), f"aff{k}o")
    statua = ["..##...", ".####..", "..##...", ".####..", "######.", "#.###.#", "#.###.#", "..###..", "..###..",
              ".##.##.", ".#...#.", ".#...#.", "#######"]
    for sx in (-1, 1):
        nx = cx + sx * 64
        d.arco(nx, fy + 105, 24, 30, colore("slate_d"), f"nicchia{sx}", cornice=R["marmo"])
        pts = [(nx - 3 + i, fy + 100 - len(statua) + j) for j, r in enumerate(statua) for i, ch in enumerate(r)
               if ch == "#"]
        d.pixel([p for p in pts if p[0] <= nx], R["marmo"].toni[2], f"nst{sx}l")
        d.pixel([p for p in pts if p[0] > nx], R["marmo"].toni[1], f"nst{sx}o")
        d.rett(nx - 6, fy + 100, 12, 5, R["marmo"].toni[1], f"nst{sx}p", separa=True)      # il piedistallo
    # fascia a mosaico (rombi rossi su fondo crema, bordo verde-acqua), interrotta dal portale
    my = d.terra_y - 26
    for x in range(x0 + 20, x1 - 20):
        if abs(x - cx) < 26:
            continue
        d.pixel([(x, my), (x, my + 8)], colore("teal_d"), "mos_b")
        d.pixel([(x, my + j) for j in range(1, 8)], colore("cream"), "mos_f")
        q = (x - x0) % 8
        d.pixel([(x, my + 4 + dy) for dy in range(-min(q, 8 - q) + 1, min(q, 8 - q)) if min(q, 8 - q) > 0],
                colore("red_d"), "mos_r")
    # sei colonne
    n = 6
    for i in range(n):
        ccx = x0 + 30 + i * (x1 - x0 - 60) // (n - 1)
        d.colonna(ccx, fy + 34, d.terra_y - 20, 9, R["marmo"], f"colonna{i}")
    d.gradini(cx, d.terra_y, x1 - x0 - 40, 4, R["marmo"], "scala", alto=5, sporge=4)
    return d.fine()


def casa_antica_pergola():
    """Centro antico, seconda casa: piu' piccola e abitata. Terrazza con la pergola di travi e la vite, anfore di cotto
    nell'angolo, scala esterna che sale lungo la facciata, porta squadrata di lato con l'architrave, finestrelle con
    gli scuri, fascia dipinta color cotto sotto la terrazza. 3 x 3 caselle."""
    d = Disegno(3, 3, muro=96, seme=31)
    x0, x1 = d.x0, d.x1
    ty, gy = d.tetto_y, d.gronda_y
    d.lastre(x0, ty + 6, x1 - x0, gy - ty - 6, R["arenaria"], "terrazza", lw=16, lh=12)
    d.blocchi(x0, ty, x1 - x0, 8, R["arenaria_scura"], "parapetto", bw=12, bh=8)
    d.blocchi(x0, ty, 8, gy - ty, R["arenaria_scura"], "parapetto_o", bw=8, bh=12)
    d.blocchi(x1 - 8, ty, 8, gy - ty - 40, R["arenaria_scura"], "parapetto_e", bw=8, bh=12)
    for k in range(4):                                  # pergola: quattro travi e due longheroni, la vite sopra
        d.rett(x0 + 16, ty + 20 + k * 22, 110, 4, R["legno"].toni[1], f"trave{k}", separa=True)
    for xx in (x0 + 20, x0 + 118):
        d.rett(xx, ty + 16, 5, 90, R["legno"].toni[2], f"long{xx}", separa=True)
    d.muschio(x0 + 18, ty + 14, 104, 84, 34, R["muschio"], "vite")
    d.pixel([(x0 + 30 + k * 17, ty + 40 + (k * 13) % 50) for k in range(6)], colore("purple"), "uva")
    for i, (ax, ay) in enumerate(((x1 - 34, ty + 18), (x1 - 22, ty + 30), (x1 - 36, ty + 42))):
        d.pixel([(ax + u, ay + v) for u in range(-5, 6) for v in range(-5, 6) if u * u + v * v <= 22],
                R["cotto"].toni[1], f"anfora{i}")
        d.pixel([(ax + u, ay + v) for u in range(-4, 1) for v in range(-4, 0) if u * u + v * v <= 10],
                R["cotto"].toni[2], f"anfora{i}l")
        d.pixel([(ax + u, ay + v) for u in range(-1, 2) for v in range(-1, 2)], BUIO, f"anfora{i}b")
    d.rett(x0 + 40, ty + 140, 30, 20, R["legno"].toni[1], "panca", separa=True)
    # facciata: blocchi piu' grandi e scuri, fascia dipinta, porta a sinistra, scala a destra
    fy = gy
    d.blocchi(x0, fy, x1 - x0, d.terra_y - fy, R["arenaria_scura"], "facciata", bw=20, bh=12, varia=0.3)
    d.rett(x0, fy + 4, x1 - x0, 6, R["cotto"].toni[1], "fascia", separa=True)
    d.pixel([(x, fy + 6 + (x // 4) % 2) for x in range(x0, x1, 2)], R["cotto"].toni[2], "fascia_m")
    px = x0 + 26
    d.rett(px - 4, d.terra_y - 62, 40, 6, R["arenaria"].toni[2], "architrave", separa=True)
    vano = d.rett(px, d.terra_y - 56, 32, 56, BUIO, "vano", separa=True)
    d.porta_legno(vano, R["legno"], "porta", borchie=colore("amber"))
    for i, wx in enumerate((x0 + 82, x0 + 126)):
        d.finestra(wx, fy + 30, 14, 16, VETRO, R["arenaria"], f"fin{i}", davanzale=R["arenaria"])
        for sx in (-6, 14):
            d.rett(wx + sx, fy + 30, 6, 16, R["legno"].toni[1], f"scuro{i}{sx}", separa=True)
    for k in range(8):                                  # scala esterna che sale verso la terrazza
        sx, sy = x1 - 52 + k * 5, d.terra_y - 8 - k * 11
        d.rett(sx, sy, 52 - k * 5, 8, R["arenaria"].toni[1], f"scala{k}", separa=True)
        d.rett(sx, sy, 52 - k * 5, 2, R["arenaria"].toni[2], f"scala{k}l", separa=False)
    d.crepe(x0 + 6, fy + 14, x1 - x0 - 60, 60, 4, R["arenaria_scura"].toni[0], "crepe")
    d.muschio(x0, fy + 6, 28, 50, 4, R["muschio"], "edera")
    return d.fine()


def casa_antica_loggia():
    """Centro antico, terza casa: lunga e bassa, col tetto di coppi di cotto sfondato in un punto (si vedono le travi),
    una loggia di tre archi al piano terra (in quello di mezzo la porta), l'occhio tondo sopra, una colonna spezzata e
    una fontana a vasca davanti. 5 x 3 caselle."""
    d = Disegno(5, 3, muro=104, seme=47)
    x0, x1 = d.x0, d.x1
    ty, gy = d.tetto_y, d.gronda_y
    cx = (x0 + x1) // 2
    colmo = ty + (gy - ty) // 3
    d.tegole(x0 + 4, ty, x1 - x0 - 8, colmo - ty, R["coppi"], "falda_n")
    d.t.col[ty:colmo, x0 + 4:x1 - 4] = (d.t.col[ty:colmo, x0 + 4:x1 - 4].astype(int) * 0.74).astype(np.uint8)
    d.tegole(x0 + 4, colmo, x1 - x0 - 8, gy - colmo, R["coppi"], "falda_s")
    d.rett(x0 + 4, colmo - 2, x1 - x0 - 8, 4, R["coppi"].toni[2], "colmo", separa=True)
    ys, xs = np.mgrid[0:d.h, 0:d.w]                     # il buco nel tetto: travi annerite e coppi rotti sull'orlo
    ang = np.arctan2(ys - colmo - 50, xs - x1 + 90)
    buco = np.hypot((xs - (x1 - 90)) / 1.3, ys - (colmo + 50)) < 19 + 2 * np.sin(ang * 3) + 1.5 * np.cos(ang * 7)
    c = np.zeros((d.h, d.w, 3), np.uint8)
    c[buco] = BUIO
    d.t.metti(buco, c, "buco", separa=True)
    for k in range(4):
        d.rett(x1 - 112 + k * 14, colmo + 32, 4, 38, R["legno"].toni[k % 2], f"trave{k}", separa=False)
    d.muschio(x0 + 20, ty + 10, x1 - x0 - 60, 40, 6, R["muschio"], "muschio_t")
    fy = gy
    d.blocchi(x0, fy, x1 - x0, d.terra_y - fy, R["arenaria"], "facciata", bw=14, bh=9, varia=0.3, rotti=0.0)
    d.fregio(x0, fy + 2, x1 - x0, R["arenaria_scura"], "fregio", motivo=("#.#.#.", ".#.#.#"), passo=6)
    for i, ax in enumerate((cx - 92, cx, cx + 92)):     # loggia di tre archi
        vano = d.arco(ax, d.terra_y, 46, 64, BUIO, f"loggia{i}", chiave=R["arenaria"].toni[2],
                      cornice=R["arenaria_scura"])
        if i == 1:
            d.porta_legno(vano & (ys > d.terra_y - 44), R["legno"], "porta", borchie=colore("amber"))
        else:
            d.rett(ax - 14, d.terra_y - 14, 28, 6, R["arenaria"].toni[0], f"panca{i}", separa=True)
    for ax in (cx - 46, cx + 46):                       # pilastri fra gli archi
        d.colonna(ax, fy + 40, d.terra_y, 5, R["arenaria"], f"pil{ax}")
    d.pixel([(cx + u, fy + 22 + v) for u in range(-11, 12) for v in range(-11, 12) if 64 < u * u + v * v <= 121],
            R["arenaria_scura"].toni[1], "occhio_c")
    d.pixel([(cx + u, fy + 22 + v) for u in range(-8, 9) for v in range(-8, 9) if u * u + v * v <= 64], VETRO, "occhio")
    d.pixel([(cx + u, fy + 22) for u in range(-8, 9)] + [(cx, fy + 22 + v) for v in range(-8, 9)],
            R["arenaria_scura"].toni[1], "occhio_t")
    d.colonna(x0 + 18, d.terra_y - 40, d.terra_y, 7, R["arenaria"], "spezzata", rotta=10)
    d.blocchi(x0 + 30, d.terra_y - 7, 22, 7, R["arenaria"], "rocchio", bw=11, bh=7)
    bx = x1 - 34                                        # fontana a vasca con l'acqua
    d.rett(bx - 18, d.terra_y - 16, 36, 16, R["arenaria"].toni[1], "vasca", separa=True)
    d.rett(bx - 18, d.terra_y - 16, 36, 2, R["arenaria"].toni[2], "vasca_l", separa=False)
    d.rett(bx - 15, d.terra_y - 14, 30, 4, colore("blue"), "acqua", separa=False)
    d.rett(bx - 3, d.terra_y - 34, 6, 18, R["arenaria"].toni[1], "getto_p", separa=True)
    d.pixel([(bx + u, d.terra_y - 36 + abs(u) // 2 + v) for u in range(-6, 7) for v in range(2)], colore("cyan"),
            "getto")
    d.crepe(x0 + 6, fy + 12, x1 - x0 - 12, 40, 6, R["arenaria"].toni[0], "crepe")
    d.muschio(x0 + 60, d.terra_y - 8, x1 - x0 - 120, 5, 5, R["muschio"], "erba")
    return d.fine()


def _maschera(d, m, col, gruppo, separa=True):
    c = np.zeros((d.h, d.w, 3), np.uint8)
    c[m] = col
    d.t.metti(m, c, gruppo, separa=separa)
    return m


def _ogiva(d, cx, y_basso, larg, alto, col, gruppo, cornice=None):
    """Arco a sesto acuto (gotico): due archi che si incontrano in punta."""
    ys, xs = np.mgrid[0:d.h, 0:d.w]
    r = larg * 0.85
    imposta = y_basso - alto + larg * 0.9
    sx = np.hypot(xs + 0.5 - (cx - larg / 2 + r), ys + 0.5 - imposta) <= r
    dx = np.hypot(xs + 0.5 - (cx + larg / 2 - r), ys + 0.5 - imposta) <= r
    m = (np.abs(xs + 0.5 - cx) <= larg / 2) & (ys < y_basso) & ((ys >= imposta) | (sx & dx)) & (ys >= y_basso - alto)
    if cornice is not None:
        fuori = np.zeros_like(m)
        for oy, ox in ((-3, 0), (0, -3), (0, 3), (-2, -2), (-2, 2)):
            fuori |= np.roll(np.roll(m, oy, 0), ox, 1)
        _maschera(d, fuori & ~m, cornice, gruppo + "_c")
    return _maschera(d, m, col, gruppo)


def cattedrale():
    """Cattedrale: gotica, di pietra grigia. Due campanili ai lati della facciata con le guglie appuntite e la croce
    di ferro, grande rosone a raggi colorato, portale a sesto acuto profondo con le statue ai lati, contrafforti,
    finestre alte a punta con le vetrate; dall'alto il tetto lungo della navata e il transetto. 7 x 5 caselle."""
    d = Disegno(7, 5, muro=150, sopra=90, seme=61)
    x0, x1 = d.x0, d.x1
    cx = (x0 + x1) // 2
    ty, gy = d.tetto_y, d.gronda_y
    # navata e transetto visti dall'alto: tetto d'ardesia a due falde lungo, la croce del transetto
    d.tegole(cx - 90, ty, 180, gy - ty, R["ardesia"], "navata")
    d.t.col[ty:gy, cx - 90:cx] = (d.t.col[ty:gy, cx - 90:cx].astype(int) * 0.8).astype(np.uint8)
    d.rett(cx - 2, ty, 4, gy - ty, R["pietra"].toni[2], "colmo_n", separa=True)
    tr = ty + (gy - ty) // 3
    d.tegole(x0 + 6, tr, x1 - x0 - 12, 70, R["ardesia"], "transetto")
    d.rett(x0 + 6, tr + 34, x1 - x0 - 12, 3, R["pietra"].toni[2], "colmo_t", separa=True)
    for xx in (cx - 100, cx + 92):                     # i contrafforti lungo la navata
        for k in range(3):
            d.blocchi(xx, ty + 110 + k * 40, 10, 22, R["pietra"], f"contr{xx}{k}", bw=10, bh=11)
    fy = gy
    # facciata
    d.blocchi(cx - 110, fy, 220, d.terra_y - fy, R["pietra"], "facciata", bw=16, bh=10, varia=0.2)
    rx, ry = cx, fy + 42                                # rosone
    ys, xs = np.mgrid[0:d.h, 0:d.w]
    rr = np.hypot(xs + 0.5 - rx, ys + 0.5 - ry)
    ang = np.arctan2(ys + 0.5 - ry, xs + 0.5 - rx)
    _maschera(d, rr <= 30, R["pietra_chiara"].toni[1], "rosone_c")
    vetro = (rr <= 26)
    col = np.zeros((d.h, d.w, 3), np.uint8)
    spicchi = ((ang * 12 / np.pi).astype(int)) % 4
    for k, nome in enumerate(("blue", "red", "amber", "purple")):
        col[vetro & (spicchi == k)] = colore(nome)
    raggi = vetro & ((np.abs(((ang * 12 / np.pi) % 1) - 0.5) > 0.42) | (np.abs(rr - 14) < 1.2) | (rr < 5))
    col[raggi] = R["pietra_chiara"].toni[1]
    d.t.metti(vetro, col, "rosone", separa=False)
    _ogiva(d, cx, d.terra_y, 54, 98, BUIO, "portale", cornice=R["pietra_chiara"].toni[1])
    vano = _ogiva(d, cx, d.terra_y, 40, 80, R["legno"].toni[1], "porta")
    d.porta_legno(vano, R["legno"], "porta_l", borchie=colore("grey_l"))
    statua = ["..##..", "..##..", ".####.", "######", ".####.", ".####.", ".#..#.", "######"]
    for sx in (-1, 1):
        d.pixel([(cx + sx * 36 - 3 + i, d.terra_y - 50 + j) for j, r in enumerate(statua) for i, ch in enumerate(r)
                 if ch == "#"], R["pietra_chiara"].toni[2 if sx < 0 else 1], f"statua{sx}")
        d.rett(cx + sx * 36 - 5, d.terra_y - 42, 10, 4, R["pietra_chiara"].toni[1], f"mensola{sx}", separa=True)
        for k in range(2):                              # vetrate alte a punta
            _ogiva(d, cx + sx * (62 + k * 24), fy + 96, 12, 50, colore("blue_d" if k else "purple_d"), f"vetrata{sx}{k}",
                   cornice=R["pietra_chiara"].toni[0])
    # campanili con le guglie (salgono sopra il tetto)
    for sx in (-1, 1):
        tx = cx + sx * 140
        alto = fy - 70
        d.blocchi(tx - 30, alto, 60, d.terra_y - alto, R["pietra"], f"campanile{sx}", bw=12, bh=10, varia=0.25)
        _ogiva(d, tx, alto + 46, 18, 34, BUIO, f"cella{sx}", cornice=R["pietra_chiara"].toni[1])   # cella campanaria
        d.pixel([(tx - 3 + i, alto + 30 + j) for j in range(6) for i in range(7) if (i - 3) ** 2 + j * j < 14],
                R["giallo"].toni[1], f"campana{sx}")
        _ogiva(d, tx, d.terra_y - 20, 14, 40, colore("blue_d"), f"fin_t{sx}", cornice=R["pietra_chiara"].toni[0])
        gx = (np.abs(xs + 0.5 - tx) <= (ys + 0.5 - (alto - 80)) * 30 / 80) & (ys >= alto - 80) & (ys < alto)
        col = np.zeros((d.h, d.w, 3), np.uint8)
        col[gx] = R["ardesia"].toni[1]
        col[gx & (xs < tx)] = R["ardesia"].toni[2]
        d.t.metti(gx, col, f"guglia{sx}", separa=True)
        d.rett(tx - 1, alto - 96, 3, 16, colore("ink"), f"croce{sx}", separa=False)
        d.rett(tx - 5, alto - 91, 11, 3, colore("ink"), f"croce{sx}o", separa=False)
    d.gradini(cx, d.terra_y, 80, 3, R["pietra_chiara"], "scala", alto=4, sporge=6)
    d.muschio(cx - 110, d.terra_y - 12, 220, 6, 5, R["muschio"], "erba")
    return d.fine()


def faro():
    """Faro: torre altissima a fasce bianche e rosse che si stringe verso l'alto, ballatoio di ferro con la ringhiera,
    lanterna di vetro con la luce gialla, cupola nera col pennacchio; ai piedi lo scoglio e la casetta del guardiano
    col tetto rosso. 3 x 3 caselle, la torre alta piu' di 5."""
    d = Disegno(3, 3, muro=300, sopra=10, seme=71)
    x0, x1 = d.x0, d.x1
    ty, gy = d.tetto_y, d.gronda_y
    tx = x0 + 70
    # scoglio e casetta del guardiano (a destra)
    d.blocchi(x0, d.terra_y - 24, x1 - x0, 24, R["pietra"], "scoglio", bw=20, bh=8, varia=0.4)
    hx = x0 + 110
    d.tegole(hx, d.terra_y - 160, 76, 70, R["coppi"], "tetto_casa")
    d.blocchi(hx, d.terra_y - 90, 76, 66, R["intonaco"], "casa", bw=14, bh=8, varia=0.15)
    vano = d.rett(hx + 30, d.terra_y - 64, 18, 40, R["legno"].toni[1], "porta_casa", separa=True)
    d.porta_legno(vano, R["legno"], "porta_c")
    d.finestra(hx + 8, d.terra_y - 76, 14, 14, VETRO, R["legno"], "fin_casa")
    d.finestra(hx + 56, d.terra_y - 76, 14, 14, VETRO, R["legno"], "fin_casa2")
    # torre a fasce che si stringe
    base, cima = d.terra_y - 20, d.terra_y - 330
    ys, xs = np.mgrid[0:d.h, 0:d.w]
    t = np.clip((base - ys) / (base - cima), 0, 1)
    meta = 26 - t * 10
    torre = (np.abs(xs + 0.5 - tx) <= meta) & (ys >= cima) & (ys < base)
    u = (xs + 0.5 - tx) / np.maximum(meta, 1)
    fascia = (((base - ys) // 38) % 2 == 1)
    col = np.zeros((d.h, d.w, 3), np.uint8)
    rossi, bianchi = R["rosso"], R["bianco"]
    for cond, rampa in ((fascia, rossi), (~fascia, bianchi)):
        col[torre & cond] = rampa.toni[1]
        col[torre & cond & (u < -0.35)] = rampa.toni[2]
        col[torre & cond & (u > 0.5)] = rampa.toni[0]
    d.t.metti(torre, col, "torre", separa=True)
    for k in range(4):                                  # finestrelle lungo la scala a chiocciola
        y = base - 60 - k * 66
        d.finestra(tx - 4 + (k % 2) * 3, y, 8, 12, VETRO, R["pietra"], f"fin_t{k}")
    d.rett(tx - 10, base - 34, 20, 34, R["legno"].toni[1], "porta_t", separa=True)
    # ballatoio, ringhiera, lanterna, cupola
    d.rett(tx - 24, cima - 4, 48, 6, R["pietra"].toni[1], "ballatoio", separa=True)
    for k in range(9):
        d.rett(tx - 22 + k * 5, cima - 16, 2, 12, colore("ink"), f"ringh{k}", separa=False)
    d.rett(tx - 23, cima - 17, 46, 2, colore("ink"), "ringhiera", separa=False)
    lv = d.rett(tx - 14, cima - 40, 28, 36, colore("yellow"), "lanterna", separa=True)
    d.t.col[cima - 30:cima - 14, tx - 6:tx + 6] = colore("white")
    for k in range(3):
        d.rett(tx - 14 + k * 10 + 4, cima - 40, 2, 36, colore("ink"), f"telaio{k}", separa=False)
    cup = (np.hypot((xs + 0.5 - tx) / 1.0, ys + 0.5 - (cima - 40)) <= 17) & (ys < cima - 40)
    _maschera(d, cup, R["ardesia"].toni[0], "cupola")
    d.rett(tx - 1, cima - 66, 3, 10, colore("ink"), "pennacchio", separa=False)
    for k in range(3):                                  # il fascio di luce
        d.pixel([(tx + 16 + i, cima - 24 - k + i // 6) for i in range(30 - k * 6)], colore("yellow"), f"fascio{k}")
    return d.fine()


def bottega():
    """Bottega del mercato (il fornaio): banco aperto sulla strada sotto la tenda a strisce, pagnotte e ciambelle
    sul banco, ceste di pane, insegna appesa a forma di pagnotta (si capisce cosa si vende senza scritte), muro
    intonacato, tetto di coppi, porta di lato. 3 x 2 caselle."""
    d = Disegno(3, 2, muro=104, seme=81)
    x0, x1 = d.x0, d.x1
    ty, gy = d.tetto_y, d.gronda_y
    colmo = ty + (gy - ty) // 3
    d.tegole(x0 + 2, ty, x1 - x0 - 4, colmo - ty, R["coppi"], "falda_n")
    d.t.col[ty:colmo, x0 + 2:x1 - 2] = (d.t.col[ty:colmo, x0 + 2:x1 - 2].astype(int) * 0.75).astype(np.uint8)
    d.tegole(x0 + 2, colmo, x1 - x0 - 4, gy - colmo, R["coppi"], "falda_s")
    d.rett(x0 + 150, ty + 10, 14, 26, R["pietra"].toni[1], "camino", separa=True)
    d.pixel([(x0 + 154 + (k % 3), ty + 2 - k * 2) for k in range(6)], colore("grey_l"), "fumo")
    fy = gy
    d.blocchi(x0, fy, x1 - x0, d.terra_y - fy, R["intonaco"], "muro", bw=22, bh=12, varia=0.2)
    # vano del banco, tenda a strisce, banco con il pane
    d.rett(x0 + 14, fy + 30, 120, d.terra_y - fy - 30, BUIO, "vano", separa=True)
    for k in range(8):                                  # tenda a strisce gialle e bianche, col bordo a onde
        col = R["giallo"] if k % 2 == 0 else R["bianco"]
        d.rett(x0 + 8 + k * 17, fy + 18, 17, 22, col.toni[1], f"tenda{k}", separa=False)
        d.pixel([(x0 + 8 + k * 17 + i, fy + 40 + (1 if i in (5, 6, 7, 8, 9, 10, 11) else 0)) for i in range(17)],
                col.toni[1], f"tenda{k}b")
        d.rett(x0 + 8 + k * 17, fy + 18, 17, 3, col.toni[2], f"tenda{k}l", separa=False)
    d.rett(x0 + 10, d.terra_y - 34, 128, 34, R["legno"].toni[1], "banco", separa=True)
    d.rett(x0 + 10, d.terra_y - 34, 128, 4, R["legno"].toni[2], "banco_l", separa=False)
    for k in range(6):                                  # pagnotte e ciambelle sul banco
        bx = x0 + 22 + k * 20
        if k % 2:
            d.pixel([(bx + i, d.terra_y - 40 + j) for i in range(-6, 7) for j in range(-4, 4)
                     if 9 <= i * i + j * j * 3 <= 40], R["giallo"].toni[0], f"ciambella{k}")
        else:
            d.pixel([(bx + i, d.terra_y - 40 + j) for i in range(-7, 8) for j in range(-4, 4)
                     if i * i / 49 + j * j / 16 <= 1], colore("brown"), f"pagnotta{k}")
            d.pixel([(bx - 3 + i, d.terra_y - 42 + (i % 2)) for i in range(0, 7, 3)], colore("tan"), f"taglio{k}")
    for k in range(2):                                  # ceste di pane a terra
        cx = x0 + 160 + k * 26
        d.rett(cx - 10, d.terra_y - 18, 20, 18, R["legno"].toni[2], f"cesta{k}", separa=True)
        d.pixel([(cx - 8 + i, d.terra_y - 20 - (i % 3)) for i in range(16)], colore("brown"), f"pane{k}")
    # porta di lato e insegna a pagnotta appesa a un braccio di ferro
    vano = d.rett(x1 - 40, d.terra_y - 66, 28, 66, R["legno"].toni[1], "porta", separa=True)
    d.porta_legno(vano, R["legno"], "porta_l", borchie=colore("amber"))
    d.rett(x0 + 140, fy + 10, 34, 3, colore("ink"), "braccio", separa=False)
    d.pixel([(x0 + 172 - 8 + i, fy + 30 + j) for i in range(-14, 15) for j in range(-9, 10)
             if i * i / 196 + j * j / 81 <= 1], colore("brown"), "insegna")
    d.pixel([(x0 + 164 + i, fy + 26 + j) for i in range(-8, 9, 4) for j in range(0, 2)], colore("tan"), "insegna_t")
    d.rett(x0 + 157, fy + 13, 2, 9, colore("ink"), "catena1", separa=False)
    d.rett(x0 + 171, fy + 13, 2, 9, colore("ink"), "catena2", separa=False)
    return d.fine()


def dogana():
    """Dogana del porto: palazzo ufficiale di pietra chiara con il timpano e lo stemma della bilancia (si paga il
    dazio sulle merci), bandiera blu sul tetto, garitta della guardia con la sbarra a strisce sul passaggio, una
    grande bilancia a piatti per pesare le merci, casse e sacchi in attesa. 6 x 3 caselle."""
    d = Disegno(6, 3, muro=120, sopra=50, seme=91)
    x0, x1 = d.x0, d.x1
    cx = (x0 + x1) // 2 - 30
    ty, gy = d.tetto_y, d.gronda_y
    d.tegole(x0 + 4, ty, 250, gy - ty, R["ardesia"], "tetto")
    d.t.col[ty:ty + 60, x0 + 4:x0 + 254] = (d.t.col[ty:ty + 60, x0 + 4:x0 + 254].astype(int) * 0.78).astype(np.uint8)
    d.rett(cx - 1, ty - 40, 3, 60, colore("ink"), "asta", separa=False)          # bandiera
    d.rett(cx + 2, ty - 38, 26, 16, R["blu"].toni[1], "bandiera", separa=True)
    d.pixel([(cx + 10 + i, ty - 33 + j) for i in range(8) for j in range(5) if (i + j) % 3 == 0], colore("yellow"),
            "bandiera_s")
    fy = gy
    d.blocchi(x0, fy, 254, d.terra_y - fy, R["pietra_chiara"], "facciata", bw=24, bh=12, varia=0.15)
    ys, xs = np.mgrid[0:d.h, 0:d.w]
    tri = (ys >= fy - 4 - 30 + np.abs(xs - cx) * 30 / 70) & (ys < fy + 2) & (np.abs(xs - cx) < 70)
    _maschera(d, tri, R["pietra_chiara"].toni[2], "timpano")
    # stemma: scudo blu con la bilancia d'oro
    d.pixel([(cx + i, fy - 16 + j) for i in range(-9, 10) for j in range(0, 18) if abs(i) <= 9 - max(0, j - 9)],
            R["blu"].toni[1], "stemma")
    d.pixel([(cx + i, fy - 12) for i in range(-6, 7)] + [(cx, fy - 14 + j) for j in range(10)] +
            [(cx - 6 + i, fy - 8 + (i in (0, 4))) for i in range(5)] + [(cx + 2 + i, fy - 8 + (i in (0, 4))) for i in range(5)],
            colore("yellow"), "bilancia_s")
    for k in range(4):                                  # finestre alte con le persiane verdi
        wx = x0 + 18 + k * 60 if k < 2 else x0 + 30 + k * 60
        d.finestra(wx, fy + 26, 18, 30, VETRO, R["pietra"], f"fin{k}", davanzale=R["pietra_chiara"])
        d.rett(wx - 7, fy + 26, 6, 30, R["verde"].toni[1], f"pers{k}a", separa=True)
        d.rett(wx + 19, fy + 26, 6, 30, R["verde"].toni[1], f"pers{k}b", separa=True)
    vano = d.arco(cx, d.terra_y, 40, 64, BUIO, "portone", chiave=R["pietra_chiara"].toni[2], cornice=R["pietra"])
    d.porta_legno(vano, R["blu"], "portone_p", borchie=colore("yellow"))
    d.gradini(cx, d.terra_y, 60, 2, R["pietra_chiara"], "soglia", alto=4, sporge=5)
    # garitta con la sbarra a strisce
    gx = x0 + 268
    d.tegole(gx, d.terra_y - 92, 40, 22, R["ardesia"], "garitta_t")
    d.blocchi(gx, d.terra_y - 70, 40, 70, R["assi"], "garitta", bw=8, bh=70, varia=0.3)
    d.finestra(gx + 12, d.terra_y - 58, 16, 14, VETRO, R["legno"], "garitta_f")
    d.rett(gx + 44, d.terra_y - 36, 6, 36, R["pietra"].toni[1], "palo", separa=True)
    for k in range(6):
        d.rett(gx + 50 + k * 10, d.terra_y - 34, 10, 6, (R["rosso"] if k % 2 == 0 else R["bianco"]).toni[1],
               f"sbarra{k}", separa=k == 0)
    # bilancia a piatti e merci in attesa
    bx = x0 + 336
    d.rett(bx - 1, d.terra_y - 120, 3, 114, colore("ink"), "bil_asta", separa=False)
    d.rett(bx - 22, d.terra_y - 120, 45, 3, colore("ink"), "bil_giogo", separa=False)
    for sx in (-1, 1):
        d.rett(bx + sx * 20 - 1, d.terra_y - 118, 2, 18, colore("ink"), f"bil_filo{sx}", separa=False)
        d.rett(bx + sx * 20 - 9, d.terra_y - 100, 18, 3, R["giallo"].toni[0], f"bil_piatto{sx}", separa=True)
    d.rett(bx - 12, d.terra_y - 6, 24, 6, R["pietra"].toni[1], "bil_base", separa=True)
    for sx, merce in ((-1, colore("brown")), (1, colore("amber"))):     # un sacco e un lingotto sui piatti
        d.rett(bx + sx * 20 - 6, d.terra_y - 108, 12, 8, merce, f"bil_merce{sx}", separa=True)
    for k, (cx2, w, h) in enumerate(((x1 - 24, 22, 22), (x1 - 24, 20, 16))):
        y2 = d.terra_y - h - (22 if k == 1 else 0)
        d.blocchi(cx2, y2, w, h, R["assi"], f"cassa{k}", bw=w, bh=h // 2, varia=0.2)
    return d.fine()


def casa_pescatore():
    """Casa del pescatore: di assi di legno grezzo su pali sopra l'acqua bassa, tetto di assi storte, porta blu,
    reti stese ad asciugare con i galleggianti, remi incrociati, una nassa, un barile e una lanterna. 3 x 2."""
    d = Disegno(3, 2, muro=110, seme=101)
    x0, x1 = d.x0, d.x1
    ty, gy = d.tetto_y, d.gronda_y
    colmo = ty + (gy - ty) // 3
    d.blocchi(x0 + 2, ty, x1 - x0 - 4, colmo - ty, R["assi"], "falda_n", bw=12, bh=colmo - ty, varia=0.4)
    d.t.col[ty:colmo, x0 + 2:x1 - 2] = (d.t.col[ty:colmo, x0 + 2:x1 - 2].astype(int) * 0.75).astype(np.uint8)
    d.blocchi(x0 + 2, colmo, x1 - x0 - 4, gy - colmo, R["assi"], "falda_s", bw=12, bh=gy - colmo, varia=0.4)
    d.rett(x0 + 2, colmo - 2, x1 - x0 - 4, 4, R["assi"].toni[2], "colmo", separa=True)
    d.muschio(x0 + 10, ty + 6, 160, 40, 5, R["muschio"], "muschio_t")
    fy = gy
    d.rett(x0 - 6, d.terra_y - 14, x1 - x0 + 12, 14, colore("blue_d"), "acqua", separa=True)       # acqua bassa
    d.pixel([(x0 + i, d.terra_y - 10 + (i // 6) % 2) for i in range(0, x1 - x0, 3)], colore("cyan"), "onde")
    for k in range(5):                                  # pali
        d.rett(x0 + 6 + k * 46, d.terra_y - 30, 8, 30, R["assi"].toni[0], f"palo{k}", separa=True)
    d.blocchi(x0, fy, x1 - x0, d.terra_y - fy - 26, R["assi"], "pareti", bw=10, bh=d.terra_y - fy - 26, varia=0.35)
    vano = d.rett(x0 + 80, d.terra_y - 86, 28, 60, R["blu"].toni[1], "porta", separa=True)
    d.porta_legno(vano, R["blu"], "porta_b", borchie=colore("grey_l"))
    d.finestra(x0 + 30, fy + 24, 20, 18, VETRO, R["assi"], "fin")
    d.rett(x0 + 128, d.terra_y - 120, 4, 30, colore("ink"), "lant_braccio", separa=False)       # lanterna
    d.rett(x0 + 124, d.terra_y - 92, 12, 14, colore("yellow"), "lanterna", separa=True)
    # rete stesa a destra fra due pali, con i galleggianti
    nx, ny = x0 + 150, fy + 12
    d.rett(nx, ny, 3, 80, R["assi"].toni[1], "rete_p1", separa=True)
    d.rett(nx + 36, ny, 3, 80, R["assi"].toni[1], "rete_p2", separa=True)
    d.pixel([(nx + 3 + i, ny + 4 + j) for i in range(33) for j in range(50) if (i + j) % 6 == 0 or (i - j) % 6 == 0],
            colore("tan"), "rete")
    for k in range(4):
        d.pixel([(nx + 6 + k * 8 + i, ny + 4 + j) for i in range(3) for j in range(3)], colore("red"), f"galla{k}")
    # remi incrociati, nassa e barile davanti
    d.pixel([(x0 + 8 + i, d.terra_y - 34 - i) for i in range(28)], R["assi"].toni[2], "remo1")
    d.pixel([(x0 + 8 + i, d.terra_y - 62 + i) for i in range(28)], R["assi"].toni[2], "remo2")
    d.rett(x1 - 30, d.terra_y - 50, 22, 24, R["assi"].toni[1], "barile", separa=True)
    d.rett(x1 - 30, d.terra_y - 46, 22, 2, colore("slate_d"), "cerchio1", separa=False)
    d.rett(x1 - 30, d.terra_y - 32, 22, 2, colore("slate_d"), "cerchio2", separa=False)
    return d.fine()


EDIFICI = {"casa_antica": casa_antica, "casa_antica_pergola": casa_antica_pergola,
           "casa_antica_loggia": casa_antica_loggia, "museo": museo, "cattedrale": cattedrale, "faro": faro,
           "bottega": bottega, "dogana": dogana, "casa_pescatore": casa_pescatore}
