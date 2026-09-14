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

## 1b. Generatore procedurale provvisorio (US-812, fase 8 Blocco E)

`tools/generate_sprites.py` produce GIA' i 19 fogli (personaggio/nemico_base/
pet) descritti sotto — non piu' ellissi numerate, pixel art a strati
(ombra/gambe/corpo/braccia/testa/copricapo/arma), deterministica (stesso
output a ogni run). E' **grafica provvisoria generata**, non arte disegnata a
mano: resta valida finche' un artista non la sostituisce file per file (la
specifica di `data/animations.json` non cambia).

**Cosa rispetta** delle regole di questo documento: 32x32px, le 4 direzioni
(con `right` = specchio ESATTO di `left`, garantito per costruzione — vedi
sotto), l'origine piedi-centro, la griglia righe=direzioni/colonne=frame, i
nomi file (`assets/placeholder/<categoria>_<animazione>.png`), il tell del
nemico visibile dal frame 0 dell'anticipo (FR-8).

**Cosa NON rispetta, deliberatamente**:
- **Outline 1px, non 2px** (cap. 3 chiede 2px pesante, stile Legend of the
  Northern Blade). A 32px un personaggio alto ~24px con un bordo 2px perde
  troppo dettaglio interno (le mani, la sciarpa, il berretto diventano
  macchie): 1px e' la scelta di questo tool. Un artista che ridisegna a mano
  puo' tornare a 2px se il resto del design lo permette.
- **Palette FISSA, non una delle 10 di Pathway** (cap. "arte/04"): "sono i
  VFX a dire il Pathway, non il cappotto" — personaggio/nemico/pet hanno una
  loro palette propria (inchiostro/primario/accento) indipendente da quale
  Pathway il giocatore o il nemico impersonano.
- **"right" = mirror per costruzione, non per geometria a mano**: la prima
  versione del tool calcolava le coordinate di "right" separatamente da
  "left" (stesse formule con un segno diverso) — sembrava simmetrico
  guardando lo sprite, ma un confronto pixel per pixel ha trovato ~150
  pixel diversi su 1024 (US-812, scoperto dal test, non a occhio). Corretto
  disegnando sempre "left" e ribaltando l'immagine per "right": garantisce
  un mirror esatto qualunque sia la posa, senza dover verificare a mano ogni
  nuova animazione.
- **Luci/particellari**: un rim-light sulle forme a colore primario e un
  bagliore morbido (nucleo pieno + 2 anelli di caduta) sul tell/sulla
  finestra di parata perfetta/sul rilascio di `cast`, con particelle
  deterministiche sull'ultimo frame — estensione richiesta esplicitamente
  dall'utente oltre l'AC originale, resta dentro lo stesso script Pillow
  (nessun sistema VFX runtime nuovo).

`tools/generate_placeholders.py` importa il corpo pulito da questo script e
ci disegna sopra SOLO gli overlay diagnostici (bordo colorato + numero del
frame) — non ridisegna il personaggio da zero. Rilancia
`generate_sprites.py` dopo aver tarato i tempi col diagnostico, prima di
committare: altrimenti restano i bordi/numeri nei file veri del gioco.

## 2. Cosa disegnare, animazione per animazione

### Personaggio (protagonista) — 156 frame totali col budget a 4 direzioni

| Animazione | Frame | fps | Note |
|---|---|---|---|
| `idle` | 4 | 6 | loop |
| `walk` | 6 | 12 | loop; passo suona ai frame 1 e 4 (`footstep`) |
| `dash` | 4 | 20 | non loop; **i-frame ai frame 0-2** (invulnerabilita' — critico per il gameplay) |
| `attack_light` | 5 | 16 | anticipo [0,1] · **attivo (hitbox) [2]** · recupero [3,4] |
| `attack_heavy` | 8 | 14 | anticipo [0-3] (tell al frame 0) · **attivi [4,5]** · recupero [6,7] |
| `parry` | 4 | 18 | **finestra di parata perfetta: frame [0,1]**, cioe' ~111ms. E' il numero piu' importante di tutto il combattimento: disegna i primi 2 frame in modo che si "sentano" diversi dagli altri 2 (postura piu' aperta/pronta) |
| `hurt` | 3 | 14 | non loop |
| `death` | 8 | 10 | **non direzionale** (una sola serie, non 4) |
| `cast` | 6 | 12 | il VFX dell'abilita' parte al frame 3 (`ability_release`) |
| `meditate` | 6 | 4 | loop, non direzionale |

### Nemico base — 98 frame totali

| Animazione | Frame | fps | Note |
|---|---|---|---|
| `idle` | 4 | 6 | loop |
| `walk` | 6 | 10 | loop |
| `anticipo` | 4 | 8 | **il tell dell'attacco**: parte al frame 0 (audio + visivo), da' al giocatore 4 frame per reagire. E' uno stato separato dall'attacco, non frame interni — cosi' si puo' tarare la durata del tell senza toccare la velocita' del colpo |
| `attack` | 4 | 16 | **attivo (hitbox) al frame [1]** |
| `stagger` | 4 | 12 | non loop |
| `death` | 6 | 10 | **non direzionale** |

### Pet — 56 frame totali

| Animazione | Frame | fps | Note |
|---|---|---|---|
| `idle` | 4 | 6 | loop |
| `walk` | 6 | 12 | loop |
| `attack` | 4 | 16 | attivo al frame [1]; **niente tell leggibile**, il pet e' un alleato non una minaccia da schivare |

## 3. Se generi un turnaround di riferimento con IA

Blocco di stile pixel (diverso da quello delle illustrazioni,
`art-brief-gemini.md` cap. 6.2):

```
STYLE: 2D pixel art, low resolution, top-down action-RPG, ~32x32 px
character proportions, limited palette (black outline + 3 colours), hard 2px
black outline, no anti-aliasing, no gradients, readable silhouette. Plain
flat magenta background (per il chroma-key dopo).
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

## 5. Budget di lavoro

156 (personaggio) + 98 (nemico base) + 56 (pet) = 310 frame per un set
completo. Un artista fa 30-60 frame di qualita' al giorno: e' il numero che
dice davvero quanto durera' il lavoro — utile per pianificare, non un vincolo
tecnico.

## 6. Prima di considerarlo fatto

Vedi `05_checklist_finale.md`.
