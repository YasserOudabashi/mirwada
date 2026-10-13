# Sprite e animazioni

Fonte di verita' **assoluta**: `data/animations.json`. Se un numero qui sotto
e quel file non coincidono, ha ragione il file — questa e' solo una copia di
lettura comoda del giorno in cui e' stata scritta.

## 1. Regole fisse (decise una volta per tutte, irreversibili)

- **32x32 px** per frame.
- **4 direzioni**, non 8: `down`, `up`, `left`, `right`. Le diagonali riusano
  lo sprite orizzontale — dimezza i frame da disegnare, invisibile in un
  top-down 2D.
- Origine dello sprite: `piedi_centro`.
- 12 fps di default (ogni animazione puo' avere i suoi fps, vedi sotto).
- Sfondo **trasparente** nell'asset finale (durante la generazione IA si usa
  uno sfondo magenta piatto, da chroma-key-are dopo, vedi cap. 4).

### Regole di disegno (fonte: `art-brief-gemini.md` cap. 6.7)

- **Contorno 1px** color inchiostro (mai `#000000`, mai 2px); sul lato
  illuminato diventa il tono scuro del materiale (*selout*). Il contorno
  pesante 2px resta solo nei VFX (`04_combattimento_vfx.md`).
- **Luce da alto-sinistra**, la stessa in ogni sprite e in ogni frame.
- **Max 16 colori**, in ramp di 3 toni per materiale con hue shift di 10-20
  gradi (ombre verso blu/viola, luci verso giallo); l'inchiostro e' il tono
  piu' scuro di tutte le ramp.
- **Chibi**: testa 1/3-1/2 dell'altezza, figura al 70-85% della cella.
- **Niente anti-aliasing sul bordo esterno**, niente pixel isolati.
- `left` ottenuto specchiando `right` specchia anche la luce: decidilo.
- In idle/walk i piedi non si muovono: si sposta il busto di 1px.

## 2. Cosa disegnare, animazione per animazione

### Personaggio (protagonista) — 156 frame totali col budget a 4 direzioni

| Animazione | Frame | fps / ms per frame | Note |
|---|---|---|---|
| `idle` | 4 | 400/300/400/300 ms | loop |
| `walk` | 6 | 120/150/120/120/150/120 ms | loop; passo suona ai frame 1 e 4 (`footstep`) |
| `dash` | 4 | 20 | non loop; **i-frame ai frame 0-2** (invulnerabilita' — critico per il gameplay) |
| `attack_light` | 5 | 60/120/40/150/80 ms | anticipo [0,1] · **attivo (hitbox) [2]** · recupero [3,4] |
| `attack_heavy` | 8 | 70/70/70/180/50/160/100/150 ms | anticipo [0-3] (tell al frame 0) · **attivi [4,5]** · recupero [6,7] |
| `parry` | 4 | 18 | **finestra di parata perfetta: frame [0,1]**, cioe' ~111ms. E' il numero piu' importante di tutto il combattimento: disegna i primi 2 frame in modo che si "sentano" diversi dagli altri 2 (postura piu' aperta/pronta) |
| `hurt` | 3 | 14 | non loop |
| `death` | 8 | 10 | **non direzionale** (una sola serie, non 4) |
| `cast` | 6 | 12 | il VFX dell'abilita' parte al frame 3 (`ability_release`) |
| `meditate` | 6 | 4 | loop, non direzionale |

### Nemico base — 98 frame totali

| Animazione | Frame | fps / ms per frame | Note |
|---|---|---|---|
| `idle` | 4 | 400/300/400/300 ms | loop |
| `walk` | 6 | 10 | loop |
| `anticipo` | 4 | 8 | **il tell dell'attacco**: parte al frame 0 (audio + visivo), da' al giocatore 4 frame per reagire. E' uno stato separato dall'attacco, non frame interni — cosi' si puo' tarare la durata del tell senza toccare la velocita' del colpo |
| `attack` | 4 | 60/50/160/120 ms | **attivo (hitbox) al frame [1]** |
| `stagger` | 4 | 12 | non loop |
| `death` | 6 | 10 | **non direzionale** |

### Pet — 56 frame totali

| Animazione | Frame | fps / ms per frame | Note |
|---|---|---|---|
| `idle` | 4 | 400/300/400/300 ms | loop |
| `walk` | 6 | 120/150/120/120/150/120 ms | loop |
| `attack` | 4 | 60/50/160/120 ms | attivo al frame [1]; **niente tell leggibile**, il pet e' un alleato non una minaccia da schivare |

## 3. Se generi un turnaround di riferimento con IA

Blocco di stile pixel (diverso da quello delle illustrazioni,
`art-brief-gemini.md` cap. 6.2):

```
STYLE: 2D pixel art, low resolution, top-down action-RPG, ~32x32 px
chibi proportions (head about 1/3 of the height), limited palette (at most
16 colours, grouped in short 3-tone ramps: shadows shift toward blue-violet,
highlights toward warm yellow), crisp 1px near-black outline (not pure
black), single light source from the top left, no anti-aliasing on the outer
edge, no gradients, readable silhouette. Plain flat magenta background (per
il chroma-key dopo).
DO NOT: high resolution, painterly, smooth shading, 3D, isometric, text.
```

Questo **non produce asset finali**: Gemini/Imagen non tengono una griglia a
32px esatta ne' un personaggio identico su 4 direzioni e decine di frame. Il
risultato e' un turnaround da cui un pixel artist (o tu, a mano) ridisegna
gli sprite veri — fissa il look, non risparmia il lavoro di sprite.

Salva i turnaround di riferimento in `assets/concept/sprite_ref/` (es.
`enel_turnaround.png`, `nemico_turnaround.png`).

## 4. Disegnare/ritagliare l'asset vero

1. Griglia esatta 32x32, nearest-neighbour se ricampioni da un'immagine piu'
   grande.
2. Sfondo trasparente pulito (rimuovi il magenta, pulisci i bordi).
3. Ritaglia i frame nella griglia che il codice si aspetta: **righe =
   direzioni** (down/up/left/right, nell'ordine), **colonne = frame**, nello
   stesso ordine della tabella al cap. 2.
4. Nome file: `assets/placeholder/<categoria>_<animazione>.png`, stessa
   convenzione gia' in uso (`personaggio_idle.png`, `nemico_base_attack.png`,
   `pet_walk.png` — guarda `assets/placeholder/` per l'elenco completo dei
   nomi attesi).
5. Prima di considerarlo fatto: **verifica in gioco** (hot-reload F5) che gli
   indici di anticipo/attivi/recupero/i-frame cadano dove il codice se li
   aspetta — un frame sbagliato sposta silenziosamente il timing del combat.

Per capire la griglia esatta prima di disegnare, puoi rigenerare i
placeholder diagnostici:

```bash
python tools/generate_placeholders.py
```

## 4b. Disegnare con la skill `sprite-forge` (consigliato)

`sprite-forge` scrive lo sprite come **dati** (griglie di caratteri +
palette), lo controlla e lo trasforma in PNG: ogni pixel e' una scelta
esplicita e correggibile, e le regole del cap. 1 le verifica `check.py`.

1. **Un JSON per file di gioco**, es. `arte/sprite/personaggio_idle.json`,
   con `"name": "personaggio_idle"`, `"size": [32, 32]`,
   `"pivot": [16, 31]` (`piedi_centro`) e le ramp dichiarate in `"ramps"`.
2. **Un'animazione per direzione**, chiamate `down`, `up`, `left`, `right`
   **in quest'ordine**: lo sheet ha una riga per animazione, quindi le righe
   escono gia' nell'ordine che il codice si aspetta. Le animazioni non
   direzionali (`death`, `meditate`) hanno una sola animazione, una sola riga.
3. **Numero di frame** = quello di `data/animations.json`; `ms` di ogni
   frame = il suo valore in `durate_ms`, o `1000 / fps` se l'animazione non
   le ha, cosi' l'anteprima gira al tempo vero del gioco.
4. Controllo e render, **senza padding** (la griglia del gioco non ne ha):
   ```bash
   python scripts/check.py arte/sprite/personaggio_idle.json --out out
   python scripts/render.py arte/sprite/personaggio_idle.json --out out --padding 0
   ```
   (`scripts/` e' la cartella della skill.) Guarda `_preview.png` e
   `_checks.png`, correggi errori e avvisi, rilancia.
5. Copia `out/personaggio_idle/personaggio_idle_sheet.png` su
   `assets/placeholder/personaggio_idle.png` e verifica la dimensione:
   colonne x 32 per righe x 32 (idle: 128x128, death: 256x32).
   `tools/generate_placeholders.py` salta i file che hanno un JSON in
   `arte/sprite/`: rilanciarlo non cancella l'arte vera.

**Enel (protagonista): non si disegna a mano.** I 10 file `personaggio_*`
li genera `tools/art/build_enel.py` (un manichino a parti: teste a mano,
corpo come forme, luce da alto-sinistra, contorno 1px e ombre calcolati).
Per cambiare qualcosa (colori, cappotto, una posa) si modifica il
costruttore e si rigenera tutto:

```bash
python tools/art/generate_all.py                      # tutte le categorie
python tools/art/generate_all.py --only personaggio   # solo Enel
python tools/art/build_enel.py --skill <...> attack_heavy   # una sola animazione
```

Frame e durate li legge da `data/animations.json`. I frame che il codice usa
si vedono: scia viola del dash solo nei frame di invulnerabilita' (0-2),
occhi accesi e bagliore sulla lama nella finestra di parata (0-1), smear
solo sul frame con la hitbox, bagliore del cast che esplode al frame 3.

**Nemico base e pet** vengono da un set disegnato con Claude in Chrome: i
fogli originali stanno in `arte/sprite/<categoria>_<animazione>.png` e sono
copiati tali e quali in `assets/placeholder/`. Per sostituirli si cambia il
PNG in `arte/sprite/` e lo si ricopia. `tools/generate_placeholders.py` salta
ogni foglio che ha in `arte/sprite/` un sorgente `.json` (sprite-forge) o un
foglio `.png`: rilanciarlo non cancella mai l'arte vera.

**Tempi.** Le animazioni coperte dalla tabella della skill hanno
`durate_ms` in `data/animations.json` (una durata per frame): idle
400/300/400/300, walk con i contatti a 150 ms, attacchi con anticipo lento,
colpo da 40-50 ms e impatto tenuto. Copia quelle durate nei `ms` dello
sprite. Dash e parata restano a `fps`: i loro tempi sono finestre di
gameplay (i-frame, parata perfetta), non resa.

## 5. Budget di lavoro

156 (personaggio) + 98 (nemico base) + 56 (pet) = 310 frame per un set
completo. Un artista fa 30-60 frame di qualita' al giorno: e' il numero che
dice davvero quanto durera' il lavoro — utile per pianificare, non un vincolo
tecnico.

## 6. Prima di considerarlo fatto

Vedi `05_checklist_finale.md`.
