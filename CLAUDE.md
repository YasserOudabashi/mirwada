# Mirwada — CLAUDE.md di progetto

Action-RPG 2D esplorativo con sistema di progressione a Pathway/Sequenze.
**10 Pathway attivi (4 gruppi completi), 100 Sequenze.**
Leggi questo file a inizio di ogni sessione, poi `progress.txt` e `prd.json`.

> **Versione 2.** Rispetto alla v1 cambiano le regole sull'arte: tutti gli asset grafici li
> genera Claude (o Claude Code) con la skill `sprite-forge`, senza artista e senza disegno a mano.
> Le regole sui dati, il metodo di lavoro e i sistemi di gioco restano quelli di prima.
> Le decisioni cambiate sono elencate in "Cosa è cambiato rispetto alla v1" in fondo.

---

## Le tre regole che non si negoziano

### 1. I dati non sono codice

Il codice implementa **primitive**. I dati compongono **abilità**.

- Il registro delle primitive in `data/schema/primitives.json` è **chiuso**:
  28 attive + 3 differite. Usare una primitiva differita fa fallire il
  validator. Se un'abilità sembra richiederne una nuova, quasi sempre significa
  che una primitiva esistente è sottoparametrizzata: parametrizza quella.
  Aggiungere una primitiva richiede una discussione esplicita con l'utente.
- Il vocabolario degli eventi in `data/schema/tracked_events.json` è **chiuso**:
  12 voci. Un evento nuovo è **codice**: va discusso.
- Il vocabolario dei tag in `data/tags.json` è **chiuso**.
- Nessun nome di Pathway o Sequenza hardcoded in script, UI o **nomi di file**.
  Solo id e chiavi i18n. Il flag `SERIAL_NUMBERS_FILED_OFF` deve poter rinominare
  tutto sostituendo file di dati, mai toccando codice.

**Se ti trovi a scrivere una `if` per un caso specifico di un Pathway, fermati.**
Quasi certamente è un dato mancante, non un caso speciale.

### 2. Ponytail

Diff minimo che funziona. Riusa i pattern già presenti. Nessuna astrazione non
richiesta. Se una story si chiude aggiungendo una riga a un JSON invece che una
classe, si aggiunge la riga al JSON.

### 3. Una story, una iterazione

Ogni story deve chiudersi in una context window. Se ne tocchi più di ~4 file o
superi ~200 righe di diff, la story era troppo grande: segnalalo e proponi di
spezzarla. **Eccezione per l'arte:** i PNG e i JSON generati da `sprite-forge`
non contano nel conteggio dei file né delle righe, ma il comando che li produce
va scritto nella story.

---

## Come lavora Claude con l'utente (Asso)

- **Niente spiegazioni prima del codice** (decisione dell'utente, 2026-10-23: "non mi devi spiegare niente, tu fai
  e basta"). Si fa, si verifica, e alla fine si riassume cosa è stato fatto. Si chiede solo per le decisioni che
  spettano all'utente (cambiare cose già approvate, scelte di design o di gioco).
- Quando l'utente chiede del codice, lo spieghi bene, con parole semplici e un esempio.
- Quando c'è un errore, dici **come correggerlo**, non solo che c'è.
- Rispondi in italiano.

---

## Arte e asset: tutto generato da Claude

### Chi fa cosa
- **Tutti gli sprite, i tile, gli effetti, i panorami e le mappe li genera Claude** con la skill
  `sprite-forge` (cartella `scripts/forge3d/`, comando `scripts/forge.py`). Nessuno disegna a mano.
- I file generati sostituiscono i placeholder **uno a uno**. La specifica in
  `data/animations.json` non cambia quando arriva l'arte vera.
- Un asset non è finito finché Claude non l'ha **guardato**: dopo ogni generazione apri
  l'immagine ingrandita (`forge.py contact FILE --scale 4`) e correggi ciò che non si legge.
  Mai consegnare un asset visto solo come numeri.

### Come si genera (flusso di ogni story d'arte)
1. **Brief** in 4 righe: cosa, vista, dimensione, palette, animazioni richieste.
2. Niente attesa del via (decisione dell'utente, 2026-10-23): si genera, si guarda e si riassume alla fine.
   Si chiede solo per le scelte di design che spettano all'utente.
3. **Genera** con `forge.py` oppure con un piccolo script che importa `forge3d`.
   Lo script va in `tools/art/` e si può rilanciare: stessi parametri e stesso `seed` = stessi PNG.
4. **Guarda** il risultato ingrandito, su sfondo chiaro e scuro. Controlla silhouette,
   viso, arma, direzioni, e che il primo e l'ultimo frame di un ciclo combacino.
5. **Esporta** in `assets/` con il naming sotto.
6. `python tools/validate_data.py` esce 0, i test headless passano.
7. Annota in `progress.txt` il comando usato, il seed e cosa non ti convince ancora.

### Formato dei file
- Sheet per animazione: `assets/<cartella>/{categoria}_{nome}.png`, frame in **colonne**,
  direzioni in **righe** nell'ordine `down, up, left, right`. Le animazioni non direzionali
  hanno una sola riga. È lo stesso formato dei placeholder, quindi `animation_machine.gd` non cambia.
- Il numero di frame, gli fps, e le fasi (`anticipo`, `attivi`, `recupero`, `iframe_*`,
  `finestra_perfetta`) restano **solo** in `data/animations.json`. Se cambi i frame di un
  attacco, cambi il JSON e rigeneri lo sheet: il generatore legge il JSON.
- Nomi dei file e id: solo id dei dati (`personaggio`, `nemico_base`, `pet`, `fire`, ...).
  Mai nomi di Pathway o Sequenza nei nomi dei file.
- Tutte le animazioni di una stessa categoria hanno **la stessa dimensione di frame**.
  Mai mescolare 32 e 64 nella stessa categoria.

### Risoluzione
- **Deciso: 64×64 per frame** (US-8B01, 2026-10-14). `dimensione_frame` in `data/animations.json`
  è `[64, 64]`. Le **unità di gioco restano 32 per tile** (mondo visibile 640×360 unità): lo sprite
  si mette a mezza grandezza (`animation_machine.gd`) e a schermo mostra tutti i suoi 64 pixel.
- Godot disegna a **1280×720 pixel veri** (`canvas_items`, scala 2): 1 unità = 2 pixel.
  Su Full HD resta 1280×720 nitido con il bordo nero; su 1440p e 4K riempie (×2, ×3).
- Tutti i fogli dei personaggi sono a 64 (Blocco C, `tools/art/build_personaggi.py`, 2026-10-16): figura
  alta 35–46 px, piedi a 54 px, nessun pixel sul bordo della cella.
- Scalatura sempre a **multipli interi**. Mai filtri sfumati.

### Colore e stile
- Palette master del progetto: **Endesga 32** (stessa di `forge3d/materials.py`). Non inventare
  colori fuori palette senza motivo. I colori extra (come i grigi-verde di terreni e panorami)
  vanno nelle rampe di `terrain.py`/`vfx.py`, non sparsi nei file.
- Ogni materiale è una **rampa di 3–5 tonalità**, con hue shift di circa 15–20° per step:
  luci verso il caldo, ombre verso il freddo. Niente nero puro tranne il contorno `#181425`.
- **Una sola luce**, in alto a sinistra e un po' davanti, uguale in tutti gli sprite e frame.
- Contorno scuro di 1 px, mai 2. Niente anti-aliasing sul bordo esterno: i pixel sono solo
  trasparenti (alpha 0) o pieni (alpha 255). L'ombra a terra è l'unica eccezione e va
  composta nel gioco, non cotta nello sprite, se serve cambiare terreno.
- Gli sfondi sono meno saturi e meno contrastati dei personaggi.
- Il giocatore deve leggere a colpo d'occhio: **silhouette** riconoscibile in nero pieno,
  arti separati dal corpo nelle pose chiave, faccia visibile.

### Animazione (valori di partenza, da regolare a occhio)
Fonti: guide di pratica, non misure ufficiali. In caso di dubbio decide la prova a schermo.
I valori veri sono in `data/animations.json` (`durate_ms`, una durata per frame); questa
tabella li ricopia. Dash e parata restano a `fps`: sono finestre di gameplay.

| Animazione | Frame | Durata per frame | Regola |
|---|---|---|---|
| idle | 4 | 400/300/400/300 ms | respiro, mai fermo del tutto |
| walk | 6 | 120/150/120/120/150/120 ms | contact (frame 1 e 4) tenuti più dei passing, bob di 1 px |
| attack leggero | 5 | 60/120/40/150/80 ms | anticipo 2 frame, colpo 1, recupero 2 |
| attack pesante | 8 | 70/70/70/180/50/160/100/150 ms | anticipo di 4 frame **leggibile**: è il tell del combattimento |
| dash | 4 | ~50 ms (20 fps) | iframe 0–2 |
| morte | 6–8 | ~100 ms | l'ultimo frame resta a terra |

- I **frame d'impatto** si tengono di più, il passaggio veloce è nel mezzo (ease in/out).
- Il **tell del nemico** (`nemico_base.anticipo`) deve essere visibile anche in un frame
  fermo: pose estreme, mai sottili.
- Il ciclo si chiude: il frame dopo l'ultimo è il primo.
- Oltre ~15 fps effettivi la pixel art perde carattere.

### Effetti (VFX)
- Generati con `forge3d/vfx.py` (`slash`, `impact`, `projectile`, `explosion`, `aura`,
  `lightning`, `circle`, `smoke`). La **forma** è una, il **colore** cambia con la palette.
- Le palette VFX hanno id neutri (`fire`, `ice`, `arcane`, `shadow`, `holy`, `poison`, `steel`,
  `blood`, `lightning`, `nature`). Il legame Pathway → palette sta in `data/vfx.json`,
  mai nel codice.
- Un effetto d'attacco ha l'impatto in 1 frame bianco più 3–4 frame di dissolvenza.
- Rispetta `riduci_flash`: gli effetti con flash bianco devono avere una variante attenuata.

### Icone degli oggetti
- Una forma per tipo di oggetto in `forge3d/icone.py` (`FORME`, vocabolario chiuso: fiala, cristallo, chiave, ...),
  la **tinta** colora la parte che cambia (liquido, cristallo, metallo). Icona = `<forma>_<tinta>`, 32x32.
- L'abbinamento oggetto -> icona e' un **dato** (`data/ui/icone.json` `oggetti`): `build_icone.py` lo propone per gli
  oggetti nuovi (parole dell'id e tag) e tiene quelli esistenti, quindi si ritocca nel JSON. Il validator vuole
  un'icona per ogni oggetto e il disegno di ogni icona usata.
- Nel gioco: `GameData.icona_oggetto(id)`; a terra a mezza grandezza (come gli sprite a 64) con l'ombra a terra
  (`vfx.json ombra_terra.raggi.oggetto`), nello zaino a 16 unita' (1:1).
- Icone degli status (`build_stati.py`): pixel art da griglie 10x10 in un tondo 16x16, bordo rosso se `negativo`,
  verde se e' un vantaggio. Nel gioco `GameData.icona_stato(id)` e `scripts/status_icons.gd`: fila sopra la testa
  di giocatore e nemici (segnale `StatsComponent.status_cambiati`), lampeggia negli ultimi 2 secondi.
- Glifi delle primitive (`build_primitive.py`): forme 2D disegnate a 4x e ridotte a maggioranza, a 4 toni di grigio
  (contorno, scuro, primario, accento). Il colore lo mette `shaders/rampa_pathway.gdshader` dalla palette del
  Pathway in `data/vfx.json`, come i VFX. Nella hotbar l'abilita' mostra il glifo della sua prima primitiva.

### Mondo, mappe e biomi
- **La generazione procedurale del mondo è consentita come strumento di produzione**:
  `forge3d/world.py` produce biomi, fiumi, laghi, villaggi, strade, oggetti e spawn dal `seed`.
- Il risultato **si salva come dati** (`assets/world/`, vedi sotto) e si committa. Il gioco
  carica i dati, non rigenera il mondo a runtime. Il seed e i parametri vanno in `progress.txt`.
- Le regioni di Mirwada (`data/regions.json`) hanno la precedenza: una regione si genera con un
  preset di bioma e **poi si ritocca nei dati**. Mai ritoccare il PNG a mano.
- Terreni: tecnica "dual grid" a livelli, 16 tile per terreno. L'ordine di priorità dei terreni
  è in `forge3d/terrain.py` (`ORDER`). Un terreno nuovo è una riga lì, non una classe.
- Nel gioco il mondo si carica con `scripts/world/mondo.gd` (US-8B12): tessere gia' composte in
  Python e deduplicate (`<tema>/tessere_<k>.png` + `indici.png`), costruite solo nei blocchi attorno al
  giocatore. Le PNG si leggono dal disco, senza import dell'editor. File in `assets/world/`:
  `mondo.json` (misure, partenza, luoghi, riquadri delle regioni, oggetti, sottosuolo, edifici, villaggi), `blocchi.png`
  (0 libera, 128 dislivello: a piedi no, in volo si', 255 acqua o vuoto), `regioni.png`, `<tema>/oggetti/`,
  `sotto/` e `<tema>/sotto/` (il sottosuolo, secondo livello sulla stessa griglia, 47 ingressi).
- La regione e la zona vengono dalla posizione; `regions.json` dice come ci si arriva (`accesso`:
  a_piedi, volo, sottosuolo, barca) e abbina i luoghi della mappa ai location_tags (`luoghi_mondo`).
- Barca (`data/world/mezzi.json`, US-8B91): ormeggiata al porto; in barca l'acqua si attraversa e la terra no, si
  sbarca su una costa libera di una regione che lo ammette (le Marche no).
- Volo (US-8B93): con la piuma dei venti nello zaino (mezzi.json volo.chiave, non vendibile, nell'osservatorio
  dell'Archivio) il tasto V decolla e atterra; in volo non ferma niente, si atterra su terra libera.
- Soglie (US-8B95, mezzi.json con "arrivo"): la soglia del faro porta alla Frontiera, aperta con la chiave del faro
  (sull'isola delle Rovine). Alla Frontiera si arriva anche in barca e volando.
- Il contenuto dei layout delle fasi 8-11 (nemici, boss, oggetti) si riporta sul mondo generato con
  `mondo.gd popola()`: al luogo della zona o nella stessa posizione relativa della regione, mai a mano.
- Spawn, insediamenti e NPC usciti dal generatore sono **suggerimenti**: i personaggi veri
  restano nei dati (`data/npcs`, `data/factions`) e non vengono scritti dal generatore.
- Panorami (`forge3d/panorama.py`): strati separati per il parallasse (`sky`, `clouds`,
  `far`, `mid`, `near`, `fg`), con le quattro fasce del `TimeSystem` (alba, giorno,
  tramonto, notte).

### Impostazioni Godot per la pixel art
- Default Texture Filter = **Nearest**.
- Rendering → 2D → **Snap 2D Transforms to Pixel** attivo.
- Stretch mode **canvas_items**, base 1280×720, `stretch/scale = 2`, scala intera
  (mai `viewport`: disegnerebbe a 640×360 e i 64 px perderebbero metà dei dettagli).
- Se uno sprite è sfocato: reimporta e controlla il filtro prima di toccare il PNG.

### Limiti noti del generatore (da migliorare, non da aggirare a mano)
- A 32 px il viso è ridotto al minimo; a 48–64 px si legge bene.
- Nella preparazione degli attacchi l'arma può restare dietro la testa.
- Il ponte è un rettangolo di legno.
- I panorami sono ancora piatti.
- Mancano: animazioni di arrampicata/nuoto/volo, mostri volanti grandi (c'è solo `bird()` per i volatili
  piccoli), castelli e ponti dettagliati. Vanno aggiunti a `forge3d`, con una story dedicata.
- Le case (`creatures.edificio`, US-8B18a) coprono a schermo il loro sedime e sporgono verso nord di 3-4
  caselle (muro + colmo): dove il generatore ha stradine di 1 casella si vedono i tetti, non le facciate.
- Una correzione al generatore (ad esempio il viso) è una story a sé e **rigenera tutto**
  con lo stesso seed, poi si confronta il prima e il dopo.

### Checklist automatica di ogni asset
- [ ] Tutti i colori sono in palette (nessun colore fuori dalle rampe)
- [ ] Alpha solo 0 o 255, tranne l'ombra a terra
- [ ] Nessun pixel isolato e nessun contorno doppio
- [ ] Silhouette leggibile e luce coerente in tutti i frame
- [ ] Tutti i frame hanno la stessa dimensione e lo stesso pivot (**piedi al centro in basso**)
- [ ] Numero di frame uguale a quello di `data/animations.json`
- [ ] Il ciclo si chiude (ultimo → primo)
- [ ] Anteprima ingrandita su sfondo chiaro e scuro guardata
- [ ] `python scripts/selftest.py` (di sprite-forge) esce 0

---

## Comandi

```bash
# Validazione dei dati: DEVE uscire 0 prima di ogni commit
python tools/validate_data.py

# Placeholder (restano come ripiego per le animazioni non ancora generate)
python tools/generate_placeholders.py

# Arte vera, da data/animations.json
python tools/art/build_personaggi.py        # Enel, nemico_base, pet a 64 px (fogli sorgente in arte/sprite/)
python tools/art/generate_all.py            # tutte le categorie
python tools/art/generate_all.py --only personaggio

# Singoli asset con la skill
python scripts/forge.py character --spec data/animations.json --category personaggio --out assets/placeholder
python scripts/forge.py vfx --kind slash --palette fire --out assets/vfx
python scripts/forge.py world --out assets/world --w 128 --h 96 --seed 4 --godot --preview
python tools/art/build_world.py                # mondo di prova (seed 6), modalita' facile/luminosa -> arte/mondo/
python tools/art/build_world.py --tema cupo    # stessi dati, modalita' difficile/cupa -> arte/mondo/cupo/ (forge3d/tema.py)
python tools/art/esporta_mondo.py              # mondo per il gioco -> assets/world/ (tutte e due le modalita', ~1 ora)
python tools/art/esporta_mondo.py --solo-blocchi   # solo le collisioni (blocchi.png)
python tools/art/esporta_mondo.py --sottosuolo     # solo il sottosuolo (~5 minuti)
python tools/art/esporta_mondo.py --solo-dati      # solo i riquadri delle regioni in mondo.json
python tools/art/esporta_mondo.py --edifici        # solo gli edifici: sprite, mondo.json, blocchi.png (~5 minuti)
python tools/art/esporta_mondo.py --varchi         # solo i disegni dei varchi delle sotto-aree (pochi secondi)
python tools/art/esporta_mondo.py --barca          # solo il disegno della barca (pochi secondi)
python tools/art/build_interni.py              # interni: pavimenti, pareti e arredi -> assets/interni/<tema>/
python tools/art/build_npc.py                  # aspetti degli NPC (personaggio_<aspetto>_{idle,walk}.png)
python tools/art/build_libro.py                # carta, segnalibri, caselle e filetto del libro (assets/ui/)
python tools/art/build_icone.py                # icone degli oggetti: abbina i nuovi in data/ui/icone.json, disegna assets/icone/oggetti/
python tools/art/build_stati.py                # icone degli status (griglie 16x16) -> assets/icone/stati/<status_id>.png
python tools/art/build_primitive.py            # glifi delle primitive a 4 toni -> assets/icone/primitive/ (colori dallo shader)
python scripts/forge.py contact FILE.png --scale 4

# Rigenera la spina dorsale dei pathway (idempotente)
python tools/generate_pathways.py

# Test headless: esce 0 se tutto passa (Godot 4.3)
godot --headless --path . --import          # solo dopo aver cambiato le PNG
bash tools/run_tests.sh                     # suite + fallisce sugli errori di script nascosti (usare questo)
godot --headless --path . --script res://tests/run_tests.gd   # solo la suite
```

## Struttura

```
006_PRD/          PRD per fase + roadmap
data/
  schema/         schemi JSON, registro chiuso delle primitive,
                  vocabolario chiuso dei 12 eventi tracciabili
  pathways/       10 file, 100 sequenze: la spina dorsale
  pathways_deferred/  12 pathway fuori scope, completi. NON cancellati.
  abilities/      abilità composte dalle primitive
  synergies/      regole di sinergia data-driven
  animations.json timing e fasi di ogni animazione (unica fonte)
  vfx.json        effetti per primitiva e legame Pathway → palette
  tags.json       vocabolario chiuso dei tag
tools/            generatore, validator
tools/art/        script di generazione asset (rilanciabili, con seed)
scripts/world/    loader del mondo unico (mondo.gd: blocchi, livelli, ingressi, NPC, popolamento)
scenes/ scripts/ assets/ tests/
assets/placeholder/   sheet {categoria}_{nome}.png (ora generati da sprite-forge)
assets/world/         mondo.json, blocchi/regioni.png, <tema>/tessere+indici+oggetti, sotto/
assets/interni/       <tema>/<interno_id>.png (pavimenti e pareti), <tema>/arredi/, arredi.json (build_interni.py)
assets/ui/            libro (carta, segnalibri, caselle, filetto) e font Alegreya (OFL)
assets/icone/oggetti/ <forma>_<tinta>.png, 32x32, solo le icone usate (build_icone.py, data/ui/icone.json)
assets/icone/stati/   <status_id>.png, 16x16 (build_stati.py)
assets/icone/primitive/ <primitiva>.png, 32x32 a 4 grigi (build_primitive.py, shaders/rampa_pathway.gdshader)
assets/vfx/           sheet degli effetti
prd.json          story della fase corrente per ralph
progress.txt      memoria tra le iterazioni
```

## Definition of done di ogni story

- [ ] typecheck/lint passa
- [ ] test headless passano (esistenti + nuovi)
- [ ] `python tools/validate_data.py` esce 0
- [ ] nessuna regressione sulle story precedenti
- [ ] story con UI/gameplay: verifica a schermo documentata in `progress.txt`
- [ ] **story d'arte: comando di generazione + seed in `progress.txt`, asset guardato ingrandito, checklist automatica spuntata**
- [ ] `progress.txt` aggiornato con cosa fatto, come verificato, cosa resta aperto
- [ ] `prd.json`: story a `"passes": true` con `notes` compilate
- [ ] commit dei soli file toccati, messaggio `US-NNN: <cosa>`

## Fasi

Le fasi 1-12 si sono sviluppate su due rami paralleli, uniti il 2026-10-25 (merge della PR #4 nella
PR #5). Il dettaglio di ogni fase e' in `progress.txt` e nei PRD di `006_PRD/`.

- Fasi 1-7 e 5b: **CHIUSE**. Sistemi, Pathway, sinergie, mondo, endgame.
- Fase 8 — Vertical slice giocabile: **CHIUSA** (19 story). Avvio di partita con scelta del Pathway,
  abilita' a tastiera + hotbar, proiettili, recitazione con payload veri, 307 ingredienti come oggetti,
  fonti nel mondo, Prepara/Bevi, negozio. PRD `prd-fase-8-vertical-slice.md`.
- Fase 9 — Pathway Non-Standard (Boon): **CHIUSA** (7 story). PRD `prd-fase-9-pathway-non-standard.md`.
- Fase 10 — Mondo continuo a layout ASCII (`world_scene.gd`, `data/world/layouts/`, edifici e
  interni): **CHIUSA** sul suo ramo. Dal merge la scena di gioco e' il **mondo generato** (sotto): i
  layout restano come dati e come fonte del contenuto da portare sul mondo generato.
- Fase 11 — Villaggi ed economia (rarita', fabbri, interni, villaggi in campagna): **CHIUSA** sul suo
  ramo; i villaggi e gli edifici vanno portati sul mondo generato come per la fase 10.
- Fase 8b — Arte con sprite-forge: **IN CORSO**. Fatti: personaggi a 64 px, aspetti degli NPC, terreni,
  pareti, mondo generato (seed 6) con modalita' luminosa/cupa, mondo unico nel gioco (US-8B12..g:
  caricatore, regione dalla posizione, NPC, collisioni, sottosuolo, contenuto dei layout), libro (US-8B73),
  edifici di citta', villaggi e torri con le porte verso i 14 interni (US-8B18a/b), interni disegnati e
  arredati (US-8B18c/d), varchi delle sotto-aree come ingressi con il loro contenuto e la loro arte (US-8B21a/b/c),
  icone degli oggetti a terra e nello zaino (US-8B70), icone degli status sopra la testa (US-8B71),
  glifi delle primitive nella hotbar (US-8B72).
  PRD `prd-fase-8b-arte.md`, story aperte in `prd.json`.
- Fase 12 — Atto II/III e Mondo vivo: **PIANIFICATA**. PRD `prd-fase-12-atto-2-3.md`,
  `prd-fase-12-mondo-vivo.md`.

**Lavoro corrente** (vedi `006_PRD/prossimi-passi.md` e `prd.json`): panorami (US-8B74), VFX (US-8B40). Varchi,
barca, volo, Frontiera e le icone (oggetti, status, primitive) sono fatti (2026-10-26).

## Decisioni prese

- **Engine**: Godot 4.x, GDScript. (Unity scartato: più boilerplate per un sistema così data-driven.)
- **10 Pathway invece di 22**: 4 gruppi completi. Riattivare un Pathway significa riattivare **il suo gruppo intero**. Motivazioni in `006_PRD/design-pathways.md`.
- **4 direzioni, non 8**: le diagonali riusano gli sprite orizzontali.
- **Il timing del combat vive in `data/animations.json`**, non negli script né nelle immagini.
- **Arte generata da Claude con `sprite-forge`** (nuova, v2). Vedi sezione dedicata.
- **i18n dal giorno 1**: nessun testo hardcoded.
- **Pathway della fase 2**: Twilight Giant.
- **Colore del mondo: due modalità** (2026-10-20, sostituisce "luminoso" del 2026-10-14). **Facile = luminosa**
  (l'arte attuale, che non si butta: resta com'è e si tiene come riferimento). **Difficile = cupa, identica alle
  concept** (`assets/concept/regioni/`) per atmosfera, colori, forme e oggetti, anche se serve rifare tutto. La vista
  resta top-down 3/4: "identica" vuol dire stessi colori, luci, forme e luoghi, non la stessa inquadratura.
  Le due modalità sono due insiemi di asset generati dallo stesso generatore (rampe diverse), mai PNG ritoccati.
  La difficile cambia **anche il gioco** (numeri in un file dati, mai nel codice) e si sceglie **a inizio partita**:
  resta fissa e va nel salvataggio.
- **Frontiera delle Porte** (2026-10-20): isole sospese in un **vuoto di nebbia**, non un'isola nel mare (cambia la
  forma approvata). Le strade d'asfalto con le strisce **sono volute**: sono la stranezza della Frontiera.
- **Trono del Gigante** (2026-10-20): va sulla **vetta** più alta delle Marche, con salita, spade e stendardi ai piedi.
- **Palette dei VFX: vale `data/vfx.json`** (2026-10-14). `design-vfx.md` è allineato al file dati.
- **Merge dei due rami** (2026-10-25): la PR #4 (fasi 8-11) e' unita nella PR #5; il mondo generato resta la
  scena di gioco, i layout della fase 10 sono la fonte del contenuto da riportarci.
- **Marche del Crepuscolo** (2026-10-25): ci si arriva **solo volando o dal sottosuolo** (le catacombe sbucano
  nelle Marche). A piedi restano chiuse; `regions.json` `accesso`, verificato da un test di raggiungibilita'.
- **Libro** (2026-10-25): copertina di cuoio, pergamena, font Alegreya/Alegreya SC, inchiostro scuro; tutto in
  `data/ui/book.json` `tema`, immagini da `tools/art/build_libro.py`.
- **Varchi delle sotto-aree** (2026-10-26): ogni area del gating di `regions.json` e' un **ingresso** sulla mappa
  verso un interno (cripta, tempio, radura, grotta grande, sala dei sigilli, isola di nebbia); `AreaGate` decide se
  si apre. La mappa approvata non cambia. I ponti di radici sono un ponte che compare sul burrone.
- **Volo** (2026-10-26): si sblocca con una **chiave del mondo** (oggetto o luogo da trovare), per tutti i Pathway.
  Niente primitive nuove.
- **Barca** (2026-10-26): barca libera al **molo di Mirwada**; in barca l'acqua si attraversa, si sbarca sulle coste.
- **Frontiera, come si arriva** (2026-10-26): **in barca, volando, o da una soglia nel faro** che si apre solo con
  una chiave trovata nel mondo. Resta il gating di sequenza (respinge chi e' oltre la Sequenza 4).

## i18n — due sistemi, una convenzione per le stringhe dei dati

1. **UI chrome** (HUD, etichette del motore): `assets/i18n/strings.csv` → `.translation`, con
   `tr("HUD_...")`. Chiavi in `SCREAMING_SNAKE`.
2. **Stringhe dei dati**: `data/i18n/it.json` + `data/i18n/en.json`, con `GameData.tr_data(key)`.

Convenzione unica delle chiavi dei dati: `<categoria>[.<pathway_id>].<local>`, con categoria
`pathway | sequence | ability | acting | characteristic | form | anchor | synergy`.
Esempi: `pathway.twilight_giant`, `sequence.twilight_giant.9`, `anchor.mirco`.
`tools/generate_i18n_stubs.py` riscrive le chiavi non canoniche e rigenera i cataloghi.
Il validator (`R-12`) dà **errore** se una chiave `*_i18n` non ha voce in `it.json`.
Gli asset non hanno testo: se un'immagine ha bisogno di una scritta, è un dato i18n.

## Fog of war sulla conoscenza: nomi di Sequenza

Il giocatore non deve MAI conoscere in anticipo il nome di una Sequenza non ancora raggiunta.
Unica eccezione: il nome della Sequenza **immediatamente successiva** sul **proprio** Pathway
(solo il nome). Vale anche per l'arte: nessuna icona, effetto o panorama deve rivelare una
Sequenza non ancora raggiunta.

## Non-goals

Multiplayer, 3D **a runtime** (il 3D esiste solo nella produzione degli sprite), monetizzazione,
**doppiaggio**, mondo aperto senza gating, console port.
L'audio NON è un non-goal: ha il suo sistema data-driven in `data/audio.json`.

## Repo

https://github.com/YasserOudabashi/mirwada (pubblica).
Percorso locale: `D:\005-Friend\Ivan\MEgaProJect`.

## Nota IP

Il sistema di riferimento è opera protetta di terzi. Progetto personale, non distribuibile né
monetizzabile con i nomi attuali. Il flag `SERIAL_NUMBERS_FILED_OFF` (default `false`) rende la
rinominazione completa un'operazione da un pomeriggio: i nomi vivono solo nei dati. Vale anche per
gli sprite: nessun personaggio o simbolo di opere protette negli asset.

---

## Cosa è cambiato rispetto alla v1

| Tema | v1 | v2 |
|---|---|---|
| Chi crea gli asset | artista a mano, placeholder nel frattempo | Claude con `sprite-forge`, rilanciabile con seed |
| Risoluzione | 32×32 fissa e irreversibile | 32×32 di default; 64×64 possibile come decisione unica di progetto |
| Palette | 3 colori + nero | Endesga 32, rampe di 3–5 tonalità con hue shift |
| Mappe | disegnate a mano | generate dal seed, **salvate come dati** e ritoccate nei dati |
| Generazione procedurale | non-goal | consentita come strumento di produzione, mai a runtime |
| Regola "una story" | max ~4 file / 200 righe | uguale, tranne PNG/JSON generati |
| Verifica visiva | non prevista | obbligatoria: ogni asset si guarda ingrandito |
| Nomi dei file | liberi | solo id dei dati, mai nomi di Pathway |

Se qualcosa qui sopra non ti torna, dimmelo: i punti più discutibili sono la decisione 32/64 px
e il permesso di generare il mondo in modo procedurale.
