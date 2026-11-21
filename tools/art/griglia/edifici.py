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
    d = Disegno(6, 4, muro=150, sopra=10, seme=23)
    x0, x1 = d.x0, d.x1
    cx = (x0 + x1) // 2
    colmo = d.tetto_y + (d.gronda_y - d.tetto_y) // 3      # il colmo: la falda davanti (in luce) e' piu' grande
    d.tegole(x0 + 6, d.tetto_y, x1 - x0 - 12, colmo - d.tetto_y, R["ardesia"], "falda_n")
    d.t.col[d.tetto_y:colmo, x0 + 6:x1 - 6] = np.where(d.t.a[d.tetto_y:colmo, x0 + 6:x1 - 6, None],
                                                       (d.t.col[d.tetto_y:colmo, x0 + 6:x1 - 6].astype(int)
                                                        * 0.72).astype(np.uint8),
                                                       d.t.col[d.tetto_y:colmo, x0 + 6:x1 - 6])
    d.tegole(x0 + 6, colmo, x1 - x0 - 12, d.gronda_y - colmo, R["ardesia"], "falda_s")
    d.rett(x0 + 6, colmo - 2, x1 - x0 - 12, 3, R["marmo"].toni[1], "colmo", separa=True)
    for i in range(5):                              # lucernario: lastre di vetro col telaio, lungo il colmo
        lx = x0 + 60 + i * 56
        d.rett(lx, colmo + 8, 40, 22, R["marmo"].toni[0], f"luc{i}", separa=True)
        d.rett(lx + 2, colmo + 10, 36, 18, VETRO, f"luc{i}v", separa=False)
        d.rett(lx + 19, colmo + 10, 2, 18, R["marmo"].toni[1], f"luc{i}t", separa=False)
        d.pixel([(lx + 4 + k, colmo + 12 + k // 2) for k in range(8)], colore("grey_l"), f"luc{i}r")
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
        d.rett(bx, fy + 26, 20, 50, R["rosso"].toni[1], f"stend{sx}", separa=True)
        d.rett(bx, fy + 26, 4, 50, R["rosso"].toni[2], f"stend{sx}l", separa=False)
        d.rett(bx + 16, fy + 26, 4, 50, R["rosso"].toni[0], f"stend{sx}o", separa=False)
        d.pixel([(bx + 6 + i, fy + 40 + j) for j, r in enumerate(anfora[::2]) for i, ch in enumerate(r[3:11])
                 if ch == "#"], colore("amber"), f"stend{sx}a")
        d.pixel([(bx + k, fy + 76 + (k % 4 == 0)) for k in range(20)], R["rosso"].toni[0], f"stend{sx}f")
    # sei colonne
    n = 6
    for i in range(n):
        ccx = x0 + 30 + i * (x1 - x0 - 60) // (n - 1)
        d.colonna(ccx, fy + 34, d.terra_y - 20, 9, R["marmo"], f"colonna{i}")
    d.gradini(cx, d.terra_y, x1 - x0 - 40, 4, R["marmo"], "scala", alto=5, sporge=4)
    return d.fine()


EDIFICI = {"casa_antica": casa_antica, "museo": museo}
