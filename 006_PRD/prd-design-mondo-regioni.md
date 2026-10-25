# PRD: Design del gioco — Mondo e Regioni

## 1. Introduzione/Overview

Terzo dei cinque documenti "bibbia di design" (i primi due:
`prd-design-oggetti-economia.md`, `prd-design-abilita-pathway.md`).
Descrive il mondo così com'è dopo la fase 10 (Mondo Continuo) e la fase
11 (Villaggi ed Economia): 5 regioni + la campagna che le collega, tutte
sulla stessa griglia condivisa, senza un solo caricamento di scena fra
loro.

**Su "castelli/grotte/caverne" per nome**: il gioco non ha una zona
letteralmente chiamata "castello" o "caverna" — ha equivalenti funzionali
coerenti con l'ambientazione (nomi propri, non generici): un **trono**
in rovina su cui si sedeva chi deteneva la Sequenza 0 del Twilight Giant
(`trono_del_gigante`), un **tempio abbandonato** e una **rovina** fra le
Marche del Crepuscolo fanno il lavoro narrativo di un castello caduto; la
**grotta di marea** a Valle della Madre è una vera caverna costiera. Ogni
regione è descritta con i suoi nomi reali sotto, non con etichette
generiche da fantasy-medievale.

## 2. Come funziona il mondo (meccanica, non contenuto)

- **Una sola `TileMapLayer`** ospita tutte le 5 regioni, ognuna al proprio
  `world_offset` nella griglia condivisa: entrare in un'altra regione è
  solo attraversare un confine, mai un caricamento di scena.
- **Le zone** (`location_tags`) sono rettangoli dentro il layout di una
  regione: ogni Pathway/gruppo ha zone a tema, e la Sequenza 0 di ogni
  gruppo ha un sito rituale dedicato (`soglia_del_crepuscolo`,
  `radice_del_mondo`, `biblioteca_di_tutto` — Lord of Mysteries condivide
  `frontiera_porte` come sede, senza una zona di Sequenza 0 propria
  separata).
- **Il gating** (6 tipi chiusi: primitiva/momento/fase_lunare/npc/
  conoscenza/sequenza) trasforma l'ingresso a un'area in una barriera
  fisica vera (dalla fase 10), non un rifiuto di caricamento: serve
  un'abilità, un momento del giorno preciso, una fase lunare, la
  conoscenza di un testo, o una Sequenza sufficientemente bassa per
  entrare.
- **Gli edifici** (`edifici: [{x,y,interno_id}]`) sono porte sulla mappa
  esterna che caricano un interno — una stanza o poche stanze collegate,
  sempre uno scambio di scena LOCALE (il mondo esterno si nasconde, non
  si libera mai).
- **Un boss è dati**, mai un tipo: un nemico con `sequenza` più bassa
  (più forte, in questo sistema Sequenza-inversa), `override` più duro e
  `scala` 1.5× — ogni regione ne ha esattamente 1.

## Le 5 regioni

### Mirwada (`mirwada`)

- Affinità di gruppo: **neutra (hub, nessun gruppo)**

- Posizione nel mondo (world_offset): [220, 180] · Dimensione: 64x44 celle

- Densità mistica: 0.2 · Palette visiva: `neutra` · Musica: `citta`

- Nessuna barriera d'ingresso: si entra liberamente.



**Le 5 zone:**


- **porto** — 15x11 celle: il porto di Mirwada, dove arrivano contrabbandieri e mercanti di voci

- **archivio** — 15x10 celle: l'archivio cittadino, sapere ordinato e custodito

- **vicolo** — 13x17 celle: i vicoli stretti fra le case, dove si incontra chi non vuole essere visto

- **piazza** — 13x11 celle: la piazza centrale, cuore sociale della città

- **sotterraneo** — 11x8 celle: un sotterraneo sotto Mirwada, accessibile da un edificio



**Edifici visitabili (5):**


- `mirwada_sotterraneo` — interno 10x8 celle, porta a (31,31)

- `mirwada_casa_di_lena` — interno 8x6 celle, porta a (6,19) · contiene: trottola_di_legno_intagliata

- `mirwada_archivio_ottavia` — interno 10x7 celle, porta a (13,12) · contiene: libro_ordine_minore

- `mirwada_bettola_del_porto` — interno 9x7 celle, porta a (56,28) · contiene: boccale_dei_contrabbandieri

- `mirwada_bottega_del_fabbro` — interno 7x5 celle, porta a (53,6) · abitato da Bram (Fabbro di Mirwada)



**Boss della regione**: nemico di Sequenza 8, scala 1.5× (override: {'danno_attacco': 15, 'raggio_aggro': 200, 'tag': 'bestia', 'caratteristica': {'pathway_id': 'twilight_giant', 'sequence': 8, 'probabilita': 1.0}, 'drop_probabilita': 1.0}). Un boss non è un tipo di dato — è un nemico normale con `sequenza` più bassa, `override` più duro e `scala` visiva maggiore (US-806).


### Marche del Crepuscolo (`marche_crepuscolo`)

- Affinità di gruppo: **Eternal Darkness**

- Posizione nel mondo (world_offset): [0, 0] · Dimensione: 76x48 celle

- Densità mistica: 0.6 · Palette visiva: `darkness` · Musica: `marche`

- **Barriere d'ingresso** (2): richiede la primitiva `shadow_meld` per entrare in `passaggi_ombra`; accessibile solo a `notte_fonda` in `cripte`



**Le 10 zone:**


- **altura** — 13x20 celle: un'altura esposta, punto alto delle Marche del Crepuscolo

- **luogo_di_battaglia** — 13x20 celle: un campo dove si è combattuto, ancora segnato

- **tempio_abbandonato** — 13x20 celle: un tempio caduto in disuso

- **rovina** — 13x20 celle: rovine di una struttura più antica

- **luogo_in_decadenza** — 13x20 celle: un luogo che si sta letteralmente sfaldando

- **vetta** — 13x20 celle: la cima più alta delle Marche

- **luogo_di_massacro** — 13x20 celle: il sito di un massacro passato

- **cripta** — 13x20 celle: una cripta sotterranea

- **trono_del_gigante** — 13x20 celle: il trono di chi ha detenuto la Sequenza 0 del Twilight Giant

- **soglia_del_crepuscolo** — 13x20 celle: il sito rituale del gruppo Eternal Darkness (Sequenza 0)



**Boss della regione**: nemico di Sequenza 7, scala 1.5× (override: {'danno_attacco': 15, 'raggio_aggro': 200, 'tag': 'non_morto', 'caratteristica': {'pathway_id': 'twilight_giant', 'sequence': 7, 'probabilita': 1.0}, 'drop_probabilita': 1.0}). Un boss non è un tipo di dato — è un nemico normale con `sequenza` più bassa, `override` più duro e `scala` visiva maggiore (US-806).


### Valle della Madre (`valle_madre`)

- Affinità di gruppo: **Goddess of Origin**

- Posizione nel mondo (world_offset): [0, 360] · Dimensione: 68x50 celle

- Densità mistica: 0.45 · Palette visiva: `mother` · Musica: `valle`

- **Barriere d'ingresso** (2): richiede la primitiva `plant_growth` per entrare in `ponti_di_radici`; accessibile solo a fase lunare `piena` in `grotte_di_marea`



**Le 6 zone:**


- **bosco_antico** — 19x21 celle: un bosco che precede la memoria scritta

- **radura_lunare** — 19x21 celle: una radura aperta al cielo, dove la luna si vede intera

- **grotta_di_marea** — 19x21 celle: una grotta costiera che la marea riempie e svuota

- **sorgente** — 19x21 celle: la sorgente d'acqua della Valle, cuore dell'avamposto

- **altare_di_radici** — 19x21 celle: un altare cresciuto dalle radici stesse

- **radice_del_mondo** — 19x21 celle: il sito rituale del gruppo Goddess of Origin (Sequenza 0)



**Edifici visitabili (4):**


- `valle_avamposto_vedetta` — interno 8x6 celle, porta a (5,42) · contiene: corno_da_richiamo_intagliato

- `valle_avamposto_deposito` — interno 8x6 celle, porta a (13,42) · contiene: cesto_di_vimini_intrecciato

- `valle_avamposto_focolare` — interno 8x6 celle, porta a (5,48) · contiene: campanaccio_di_capra_smarrita

- `valle_avamposto_erborista` — interno 8x6 celle, porta a (13,48) · abitato da Rosalba (Erborista dell'avamposto) · contiene: quaderno_di_appunti_sulle_maree



**Boss della regione**: nemico di Sequenza 7, scala 1.5× (override: {'danno_attacco': 15, 'raggio_aggro': 200, 'tag': 'bestia', 'caratteristica': {'pathway_id': 'mother', 'sequence': 7, 'probabilita': 1.0}, 'drop_probabilita': 1.0}). Un boss non è un tipo di dato — è un nemico normale con `sequenza` più bassa, `override` più duro e `scala` visiva maggiore (US-806).


### Archivio Sepolto (`archivio_sepolto`)

- Affinità di gruppo: **Demon of Knowledge**

- Posizione nel mondo (world_offset): [440, 0] · Dimensione: 72x44 celle

- Densità mistica: 0.7 · Palette visiva: `hermit` · Musica: `archivio`

- **Barriere d'ingresso** (1): richiede di conoscere `testi_ordine_minore` per entrare in `ali_interne`



**Le 6 zone:**


- **biblioteca** — 32x20 celle: la biblioteca principale dell'Archivio Sepolto, scaffali su scaffali

- **officina** — 32x17 celle: un'officina fra i detriti, dove si ripara e si smonta

- **torre_di_osservazione** — 27x17 celle: la torre a più piani da cui si sorveglia il territorio

- **sala_dei_sigilli** — 15x12 celle: una sala dedicata ai sigilli, disposti in cerchio

- **studio** — 11x9 celle: uno studio appartato, poche persone alla volta

- **biblioteca_di_tutto** — 28x7 celle: il santuario murato, sito rituale del gruppo Demon of Knowledge (Sequenza 0)



**Edifici visitabili (1):**


- `archivio_torre_osservazione` — interno 27x11 celle, porta a (63,15) · contiene: mappa_delle_costellazioni_perdute



**Boss della regione**: nemico di Sequenza 6, scala 1.5× (override: {'danno_attacco': 15, 'raggio_aggro': 200, 'tag': 'spirito', 'caratteristica': {'pathway_id': 'hermit', 'sequence': 6, 'probabilita': 1.0}, 'drop_probabilita': 1.0}). Un boss non è un tipo di dato — è un nemico normale con `sequenza` più bassa, `override` più duro e `scala` visiva maggiore (US-806).


### Frontiera delle Porte (`frontiera_porte`)

- Affinità di gruppo: **Lord of Mysteries**

- Posizione nel mondo (world_offset): [440, 360] · Dimensione: 72x48 celle

- Densità mistica: 0.9 · Palette visiva: `fool` · Musica: `frontiera`

- **Barriere d'ingresso** (2): richiede Sequenza ≤4 per entrare in `ingresso`; richiede la primitiva `teleport` per entrare in `isole_nebbia`



**Le 6 zone:**


- **teatro** — 22x21 celle: un teatro alla Frontiera delle Porte, palco per chi recita un ruolo

- **crocevia** — 22x21 celle: un incrocio di strade che non portano tutte da qualche parte

- **soglia** — 22x21 celle: l'ingresso della Frontiera, gating a Sequenza 4

- **nebbia_grigia** — 22x21 celle: una nebbia che confonde direzione e distanza

- **palco** — 22x21 celle: il palco del teatro

- **porta_senza_stanza** — 22x21 celle: una porta che non apre su nulla — o su tutto



**Boss della regione**: nemico di Sequenza 5, scala 1.5× (override: {'danno_attacco': 15, 'raggio_aggro': 200, 'tag': 'ombra', 'caratteristica': {'pathway_id': 'fool', 'sequence': 5, 'probabilita': 1.0}, 'drop_probabilita': 1.0}). Un boss non è un tipo di dato — è un nemico normale con `sequenza` più bassa, `override` più duro e `scala` visiva maggiore (US-806).

## La campagna: il mondo condiviso fuori dalle regioni

Le 5 regioni sopra non sono scene isolate: condividono un'unica
`TileMapLayer` (`world_scene.gd`, fase 10). Lo spazio FUORI dal
rettangolo di ogni regione non è vuoto — è **campagna vera**: terreno
attraversabile, alberi sparsi (densità 6% per cella, deterministica),
36 nemici deboli (Sequenza 9) e 34 oggetti comuni sparsi, popolati da
`data/world/campagna.json`. Il muro perimetrale di ogni regione ha
brecce regolari (ogni 11 celle, larghe 3) su tutti e 4 i lati: si esce
verso la campagna in molti punti, non da un solo varco.

Nella campagna vivono i primi 2 **villaggi** che non appartengono a
nessuna regione — piccoli insediamenti fuori le mura, ognuno con un
fabbro/alchimista che crea oggetti su richiesta e un mercante:

- **Villaggio di Marche** (vicino alla breccia sud-est del muro di
  Marche del Crepuscolo): `marche_villaggio_fabbro` (Fenwick, fabbro)
  e `marche_villaggio_mercante` (Greta, mercante) — 2 capanne 7x5
  celle, pareti dipinte da un template generico, non parte di nessuna
  mappa ASCII disegnata a mano.
- **Villaggio dell'Archivio** (vicino alla breccia sud del muro
  dell'Archivio Sepolto): `archivio_villaggio_alchimista` (Orsolya,
  alchimista) e `archivio_villaggio_mercante` (Dario, mercante — vende
  Ambrosia, l'unico oggetto leggendario del gioco).

## Proposte per il futuro

Nessuna richiede un motore nuovo: `_crea_edifici`/`AreaGate`/il template di
capanna generico bastano per tutto quello che segue.

### US-D08: Una grotta vera dentro Valle della Madre

**Descrizione:** Come giocatore, voglio poter entrare fisicamente nella
`grotta_di_marea` (oggi solo una zona esterna, nessun interno), la prima
vera caverna-dungeon del gioco.

**Acceptance Criteria:**
- [ ] Un nuovo edificio/passaggio in `data/world/layouts/valle_madre.json`
      dentro la zona `grotta_di_marea`, con un interno multi-stanza (come
      `archivio_torre_osservazione`, non una singola capanna).
- [ ] Tests pass. `python tools/validate_data.py` esce 0. Verifica a
      schermo con Xvfb.

### US-D09: Un vero castello/rovina esplorabile a Marche del Crepuscolo

**Descrizione:** Come giocatore, voglio entrare nel `trono_del_gigante`
o nella `rovina` (oggi solo zone esterne, Marche è l'unica regione senza
un singolo `edifici[]`), l'equivalente più vicino a un castello del
gioco.

**Acceptance Criteria:**
- [ ] Un nuovo edificio in `data/world/layouts/marche_crepuscolo.json`
      dentro `trono_del_gigante` o `rovina`, con un interno a più stanze.
- [ ] Tests pass. `python tools/validate_data.py` esce 0. Verifica a
      schermo con Xvfb.

### US-D10: Un terzo villaggio in campagna

**Descrizione:** Come giocatore, voglio un insediamento vicino alla
Valle della Madre o alla Frontiera delle Porte (oggi i 2 villaggi di
campagna sono entrambi vicino a Marche/Archivio), per coprire meglio la
mappa.

**Acceptance Criteria:**
- [ ] 2 nuove capanne in `data/world/campagna.json.edifici[]` vicino a
      una breccia di Valle della Madre o Frontiera delle Porte, con un
      NPC crafter/mercante nuovo dentro una di esse.
- [ ] Tests pass. `python tools/validate_data.py` esce 0. Verifica a
      schermo con Xvfb.

### US-D11: Un secondo boss per regione

**Descrizione:** Come giocatore, voglio più di un nemico "riconoscibile"
per regione (oggi ce n'è esattamente 1 a Sequenza fissa), per dare peso a
esplorare zone diverse della stessa regione.

**Acceptance Criteria:**
- [ ] Almeno 1 nemico nuovo con `scala >= 1.5` in ognuna delle 5 regioni,
      posizionato in una zona diversa da quella del boss esistente.
- [ ] Tests pass. `python tools/validate_data.py` esce 0.

## Non-Goals

- Nessuna sesta regione: le 5 esistenti (Mirwada + 4 esterne) sono il
  design completo del mondo (CLAUDE.md, mondo continuo fase 10).
- Il contenuto narrativo di Atto II/III (fazioni che prendono posizione,
  quest legate alle regioni) è fuori scope qui: vive nella Fase 12
  pianificata (`006_PRD/prd-fase-12-atto-2-3.md`), non in questo
  documento di catalogo.
- L'audio del mondo (tell sonori per zona) resta una **spec**
  (`data/audio.json`), nessun file audio prodotto: non ripetuto qui.

## Open Questions

- Marche del Crepuscolo e Frontiera delle Porte hanno **zero** edifici
  visitabili nel proprio layout (solo Mirwada/Valle/Archivio ne hanno) —
  è una lacuna di contenuto o una scelta deliberata (quelle due regioni
  sono pensate come "aperte", senza interni)?
- `grotta_di_marea` è una zona esterna, non un vero interno-caverna: il
  nome promette più di quanto la regione offre oggi — vale la pena
  scriverci sopra (US-D08) o va bene come sfondo?
