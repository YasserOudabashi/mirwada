# PRD: Fase 10 — Mondo Continuo (mappa vera, niente più salti tra quadrati)

## 1. Introduzione / Overview

Oggi il mondo di Mirwada sono **5 scene separate** (`region_scene.gd`, una
istanza per regione, griglia fissa 48×36 tile = 1536×1152px), collegate da
`passaggi`: un'`Area2D` che, quando il giocatore la tocca, **ricarica
l'intera scena** sulla regione di destinazione (`region_scene.gd::viaggia_a`,
`main.gd::partita_iniziata`). Il giocatore sparisce da una mappa e riappare
in un'altra — un salto, non un cammino. Ogni regione è inoltre un rettangolo
quasi vuoto: un bordo di muri, poche zone rettangolari genériche per i
`location_tags`, nessun edificio, nessun villaggio.

Il materiale di design (`006_PRD/design-world.md`, REALIZZATO in fase 6) ha
già un'identità ricca per ognuna delle 5 regioni — biomi interni, luoghi
unici, filosofia del gating ("il viaggio costa, le scorciatoie sono
poteri, niente teletrasporto da menu", §7) — ma la fase 6/8 hanno costruito
solo l'ossatura tecnica minima (il rettangolo diagnostico) e i 5 layout
disegnati a mano restano piatti e piccoli.

Questa fase fa due cose:

1. **Un solo mondo continuo**: le 5 regioni diventano zone di un'**unica
   mappa**, senza mai un caricamento di scena tra loro. Il gating (chi può
   andare dove) resta — anzi il motore che già esiste (`AreaGate`,
   `regions.json.gating[]`, 6 modi) è esattamente ciò che serve — ma diventa
   una barriera fisica sul posto, mai un "no, non carico quella scena".
2. **Contenuto vero**: ogni regione cresce, ospita villaggi e strutture
   grandi (palazzi, torri, cripte a più stanze) che si possono davvero
   visitare — entrare in un edificio resta un caricamento di scena (piccolo,
   locale: la stessa tecnica di oggi, usata per gli interni invece che per
   le regioni).

## 2. Goals

- **Zero caricamenti di scena tra le 5 regioni**: si cammina da Mirwada alle
  Marche del Crepuscolo con lo stesso identico input (`move_*`) con cui si
  cammina dentro Mirwada oggi.
- **Coordinate di mondo**: ogni regione occupa un blocco di celle in
  un'unica griglia condivisa (un `TileMapLayer`), non più la propria griglia
  isolata 48×36.
- **Il confine tra due regioni è geografia, non un muro invalicabile**: oggi
  ogni layout ha un bordo esterno tutto `#` (obbligatorio dal validator) —
  dove due regioni si toccano quel bordo va aperto e le due mappe devono
  incastrarsi (stesso terreno, stessa quota).
- **Gating invariato nella sostanza, cambiato nella forma**: `AreaGate` e i
  6 modi di `gate_types.json` restano identici (sono già una barriera *in
  scena*, non un blocco di caricamento) — l'unica cosa che cambia è
  `_ingresso_aperto()` (oggi decide se caricare la scena, domani decide se
  la barriera fisica al confine è aperta o chiusa).
- **Almeno un villaggio e una struttura grande** (palazzo/torre/cripta a più
  stanze) costruiti per davvero, con interni visitabili, come prova che
  l'insediamento è un tipo di contenuto riusabile — non un caso singolo.
- **Nessuna primitiva nuova, nessun evento tracciato nuovo, nessun bump di
  `schema_version`** se possibile (vedi §9): il salto è nella rappresentazione
  del mondo, non nel motore di gioco.

## 3. User Stories

### Blocco 0 — il motore del mondo continuo

#### US-1001: Coordinate di mondo per le 5 regioni

**Descrizione:** Come motore, serve che le 5 regioni condividano un'unica
griglia di celle invece di 5 griglie isolate, così una sola `TileMapLayer`
può dipingerle tutte insieme.

**Acceptance Criteria:**
- [ ] `data/world/regions.json`: nuovo campo `world_offset: [x, y]` per
      regione (in celle, dentro l'unica griglia condivisa) — dato, non
      calcolato a runtime; il validator verifica che i rettangoli
      `[world_offset, world_offset + dimensioni_layout]` di due regioni non
      si sovrappongano mai.
- [ ] `data/schema/layout.schema.json`/`region.schema.json` aggiornati con
      la nuova forma.
- [ ] Nessuna regressione sulle 5 regioni esistenti: `world_offset`
      dispone Mirwada al centro e le altre 4 ai quattro angoli, in un
      anello — collegamenti diretti tra le 4 regioni esterne, non
      hub-and-spoke puro (decisione presa con l'utente, §9).
- [ ] Test headless: nessuna sovrapposizione, ogni regione ha un
      `world_offset`.

#### US-1002: Il motore del mondo continuo — world_scene.gd dipinge più layout nella stessa TileMapLayer

> **Split in corsa (2026-09-11)**: scrivendo questa story è emerso che
> collegarla davvero a `main.tscn` richiede anche ritirare `region_scene.gd`
> + le 5 `scenes/regioni/*.tscn` e riscrivere `tests/test_layouts.gd`
> (~800 righe, 20 test sulla vecchia architettura a scena singola) oltre a
> `test_area_gate.gd`/`test_page_mappa.gd`/`test_main_boot.gd` — da solo
> oltre la soglia di CLAUDE.md ("se superi ~200 righe di diff, segnalalo e
> proponi di spezzarla"). US-1002 ora prova il motore **in isolamento**
> (mai collegato a `main.tscn`, il gioco vero continua a girare su
> `region_scene.gd`, zero regressione); **US-1002B** (nuova) fa il
> collegamento vero, ritira il codice morto e migra i test.

**Descrizione:** Come motore, serve un nodo che dipinga OGNI regione di
`GameData.get_regions()` nella stessa `TileMapLayer` al proprio
`world_offset`, con un corridoio di raccordo vero e un modo di sapere in
quale regione si trova il giocatore senza mai ricaricare una scena.

**Acceptance Criteria:**
- [ ] Il motore (nome di lavoro `world_scene.gd`, sostituisce
      `region_scene.gd` come scena caricata da `main.gd`) itera
      `GameData.get_regions()` e dipinge ogni layout dai suoi dati esistenti
      (`_dipingi()`, `_crea_nemici()`, `_crea_oggetti()`, `_crea_npc()`,
      `_crea_zone()`, `_crea_gate()` — tutte le funzioni già scritte in
      `region_scene.gd` restano, cambia solo il ciclo esterno: una volta
      per regione invece di una volta per scena).
- [ ] Il confine tra due regioni adiacenti (per `world_offset`) è aperto: il
      bordo `#` obbligatorio del validator vale solo sui lati SENZA una
      regione vicina (nuovo campo dichiarato, es.
      `layout.confini_aperti: ["est", "nord", ...]`, o dedotto dai
      `world_offset` — decisione di implementazione, non di design).
- [ ] Un "corridoio"/terreno di raccordo disegnato a mano riempie lo spazio
      tra il bordo aperto di una regione e quello della vicina (nuovo
      contenuto minimo per questa story: non serve bello, deve solo
      esistere e essere calpestabile) — con la topologia ad anello (§9),
      questa story ne copre almeno una coppia (es. Mirwada-Marche) come
      prova del meccanismo; coprire tutti e 8 i collegamenti (4 raggi + 4
      lati dell'anello) è lavoro del Blocco A (US-1005..1009, un corridoio
      a testa quando la regione corrispondente viene disegnata).
- [ ] `WorldState.regione_corrente()` si aggiorna quando il giocatore
      attraversa il confine (nuova `Area2D` di attraversamento, sostituisce
      semanticamente il vecchio `passaggio` — stesso nodo, comportamento
      diverso: aggiorna `_regione` e basta, MAI ricarica la scena).
- [ ] `world_scene.gd::viaggia_a(target)` riposiziona il giocatore alla
      cella di spawn della regione target senza caricare nulla — sostituisce
      la vecchia semantica di `region_scene.gd::viaggia_a` (ricaricava la
      scena). Il collegamento vero a `main.gd`/`main.tscn` (niente più
      `partita_iniziata` che ricrea una scena) è US-1002B.
- [ ] Test headless dedicati (`tests/test_world_scene.gd`) che provano il
      meccanismo in isolamento: dipintura per-regione al proprio offset,
      spawn per regione, il confine aggiorna `WorldState`, il corridoio è
      calpestabile, `viaggia_a` riposiziona senza liberare il nodo, i
      nemici/oggetti di ogni regione compaiono alla posizione globale giusta.

#### US-1002B: Collega world_scene.gd al gioco vero

**Descrizione:** Come giocatore, voglio che il gioco VERO usi il mondo
continuo (non solo i test): `main.tscn` carica `world_scene.gd` invece
della singola regione Mirwada, `main.gd` non ricrea più la scena a ogni
nuova partita, la pagina mappa (fast travel) trova il nuovo nodo, e
`region_scene.gd` + le 5 `scenes/regioni/*.tscn` (ormai morti) vengono
ritirati insieme ai test che testavano solo la vecchia architettura a
scena singola.

**Acceptance Criteria:**
- [ ] `scenes/main.tscn`: il nodo regione è sostituito da un'istanza di
      `scenes/world_scene.tscn`; la posizione iniziale del Player viene da
      `world_scene.punto_spawn("mirwada")`, non un `Vector2` scritto a mano.
- [ ] `main.gd::_su_partita_iniziata`: non ricrea più la scena — su una
      nuova partita chiama `world_scene.viaggia_a("mirwada")`.
- [ ] `page_mappa.gd::_viaggia`: il lookup del nodo mondo passa dal
      confronto sul path dello script (`region_scene.gd`, non esiste più)
      allo stesso contratto pubblico `has_method("viaggia_a")` già usato
      da `main.gd`.
- [ ] Ritirati: `scripts/region_scene.gd`, `scenes/regioni/*.tscn` (5 file).
      Nessun riferimento residuo in `res://scripts` (grep di verifica).
- [ ] `tests/test_layouts.gd` riscritto per usare `scenes/world_scene.tscn`
      (coordinate + `world_offset`, nodi `Passaggio_X` rimossi/riformulati
      sul confine+corridoio); `test_area_gate.gd`/`test_page_mappa.gd`/
      `test_main_boot.gd` aggiornati allo stesso modo.
- [ ] Verifica a schermo con Xvfb: la partita vera cammina da Mirwada a
      Marche attraverso il corridoio SENZA `change_scene_to_*` e senza che
      `Progression`/`Inventory` si azzerino a metà. Screenshot in chat.

#### US-1003: Prestazioni — non tutto il mondo è vivo insieme

**Descrizione:** Come motore, con 5 regioni piene di nemici/NPC in scena
contemporaneamente serve non far girare la fisica/IA di ciò che è lontano
dal giocatore.

**Acceptance Criteria:**
- [ ] Nemici e NPC fuori da un raggio dal giocatore (valore in
      `data/balance.json`, non hardcoded) hanno `process_mode = DISABLED`
      (o equivalente) finché il giocatore non si riavvicina — riusa
      `Node2D`/`VisibleOnScreenNotifier2D` di Godot, non un sistema nuovo.
- [ ] Nessuna differenza di comportamento osservabile per il giocatore
      quando è vicino (i nemici già vicini restano esattamente come oggi).
- [ ] Un test manuale/profiling minimo documentato in `progress.txt`
      (frame time con le 5 regioni piene vs una sola, prima/dopo).

#### US-1004: Il save resta invariato

**Descrizione:** Come sistema, la posizione del giocatore nel mondo
continuo e la regione corrente devono salvarsi/ripristinarsi esattamente
come oggi, senza un nuovo campo.

**Acceptance Criteria:**
- [ ] `posizione` (già `Node2D.global_position` nel save, US-6xx) diventa
      naturalmente una posizione assoluta nel mondo continuo — **nessuna
      modifica al formato**, cambia solo cosa significano i numeri.
- [ ] `WorldState._regione` (già salvata) resta la fonte di verità per
      "in che regione sono" (gating, musica, densità mistica) —
      aggiornata dal trigger di attraversamento di US-1002.
- [ ] **Nessun bump di `schema_version`**: se durante l'implementazione
      emerge che serve un campo nuovo, è una decisione da dichiarare
      esplicitamente (come ogni bump precedente), non una sorpresa a
      fine story.
- [ ] Test headless: salva a metà di una regione "nuova" (lontana dallo
      spawn originale), ricarica, il personaggio riappare nello stesso
      punto del mondo continuo.

### Blocco A — le 5 regioni crescono

#### US-1005: Mirwada più grande, con quartieri veri

> **Split in corsa (2026-09-11)**: l'AC originale ("Almeno 3 edifici
> visitabili, vedi Blocco B") dipende da un motore — US-1010, "Vocabolario
> di un insediamento" — che nel PRD arrivava DOPO US-1006..1009, cioè dopo
> questa story. Implementare "edifici visitabili" senza quel motore avrebbe
> voluto dire scrivere codice specifico per Mirwada (contro la Regola 1 di
> CLAUDE.md: "i dati non sono codice", mai un caso speciale per un luogo).
> Riordinato invece di tirare dritto: **US-1010 portata avanti** subito dopo
> questa story; **nuova US-1005B** ("I 3 edifici visitabili di Mirwada")
> chiude la promessa usando quel motore. US-1006..1009/1011..1014 slittano
> di conseguenza (vedi `prd.json` per l'ordine di priorità aggiornato).
> US-1005 (questa story) chiude solo il layout ridisegnato + la verifica di
> non-regressione.

**Descrizione:** Come giocatore, voglio che la città hub sia un luogo con
un'identità fisica — non un rettangolo con 5 zone invisibili sovrapposte.

**Acceptance Criteria:**
- [x] Layout ridisegnato più grande (dimensione libera, non più vincolata a
      48×36 — vedi US-1001/1002), con i 5 `location_tags` di Mirwada
      (`porto`, `archivio`, `vicolo`, `piazza`, `sotterraneo`) come zone
      fisicamente distinte e riconoscibili (non rettangoli a griglia
      automatica).
- [ ] ~~Almeno 3 edifici visitabili (interni, vedi Blocco B) coerenti coi
      biomi di `design-world.md` §2.1 (la casa di Lena, l'archivio di
      Ottavia, una bettola del porto).~~ → spostato in **US-1005B**.
- [x] Nessuna regressione: gli 8 NPC esistenti restano raggiungibili, le
      quest di Atto I restano completabili.

#### US-1005B: I 3 edifici visitabili di Mirwada

**Descrizione:** Come giocatore, voglio poter entrare davvero nei 3 edifici
promessi dall'AC originale di US-1005 (la casa di Lena, l'archivio di
Ottavia, una bettola del porto) — usando il motore generico di US-1010
(`edifici: [{x, y, interno_id}]` + `data/world/interni/<interno_id>.json`),
non codice dedicato a Mirwada.

**Acceptance Criteria:**
- [ ] `data/world/layouts/mirwada.json`: nuovo campo `edifici` con almeno 3
      marcatori (Lena nel quartiere `vicolo`, Ottavia nell'edificio
      `archivio` già disegnato in US-1005, una bettola nel `porto`), ognuno
      con un `interno_id` che referenzia un file
      `data/world/interni/<interno_id>.json` vero (non uno stub vuoto).
- [ ] Entrare nella porta di ognuno dei 3 edifici carica il rispettivo
      interno; uscire torna alla mappa esterna di Mirwada, alla cella della
      porta — usando esclusivamente il motore di US-1010, zero righe di
      codice che nominino "mirwada", "lena", "ottavia" o un id di interno
      specifico.
- [ ] L'edificio dell'archivio (già disegnato in US-1005 come struttura
      murata cosmetica) diventa il primo edificio REALMENTE visitabile:
      l'interno ospita Ottavia (o un suo riferimento coerente col gating di
      conoscenza di `design-world.md`).
- [ ] Verifica a schermo con Xvfb: si entra ed esce da tutti e 3 gli
      edifici nella partita vera. Screenshot mandati in chat.

#### US-1006..US-1009: le altre 4 regioni crescono (una story a testa)

**Descrizione:** Stesso trattamento di US-1005 per Marche del Crepuscolo,
Valle della Madre, Archivio Sepolto, Frontiera delle Porte — ognuna secondo
i propri biomi interni già scritti in `design-world.md` §2.2-2.5.

**Acceptance Criteria (per ognuna):**
- [ ] Layout ridisegnato, dimensione libera, ogni `location_tag` della
      regione è una zona fisicamente distinta e riconoscibile nel terreno
      (non un rettangolo a griglia automatica).
- [ ] I siti già esistenti nei dati (es. `trono_del_gigante` per il TG,
      Sequenza 0) restano ospitati e raggiungibili — nessuna regressione
      sui rituali/le abilità che li referenziano.
- [ ] Il gating d'ingresso della regione (se dichiarato, es. la Frontiera
      "sequenza_max ~4") si applica come barriera fisica al confine
      (US-1002), non più come rifiuto di caricamento.

### Blocco B — insediamenti: villaggi e strutture grandi

#### US-1010: Vocabolario di un "insediamento" (edificio con interno)

**Descrizione:** Come sistema, serve un modo dati-driven di dichiarare "qui
c'è un edificio, ha una porta, dentro c'è una scena interna" — riusando la
tecnica già in campo per i passaggi tra regioni (un'`Area2D` che carica
un'altra scena), applicata a un ambito piccolo e locale.

**Acceptance Criteria:**
- [ ] Nuovo campo layout (es. `edifici: [{x, y, interno_id}]`) — un
      marcatore sulla mappa esterna con una porta, che referenzia un file
      `data/world/interni/<interno_id>.json` (stesso schema di un layout,
      ma tipicamente piccolo: una stanza o poche stanze).
- [ ] Entrare nella porta carica la scena interna (piccola, locale — stesso
      pattern tecnico di `_su_passaggio`, mai un sistema nuovo); uscire
      torna nella mappa esterna, alla cella della porta.
- [ ] Il validator verifica che ogni `interno_id` referenziato esista, e
      che ogni file interno abbia uno `spawn` valido.
- [ ] Nessun nuovo tipo di pagina, nessuna nuova primitiva: un interno è un
      layout come un altro, letto dallo stesso `region_scene`/`world_scene`.

#### US-1011: Il primo villaggio vero

**Descrizione:** Come giocatore, voglio un villaggio reale da esplorare —
non un singolo edificio, un insediamento con più case, una piazza, NPC che
ci vivono.

**Acceptance Criteria:**
- [ ] Un villaggio (3-6 edifici) in una delle regioni (candidato naturale:
      un avamposto nella Valle della Madre o un borgo minerario nelle
      Marche — coerente coi biomi già scritti).
- [ ] Almeno 2 interni visitabili con contenuto reale (un NPC con dialogo,
      o oggetti raccoglibili, o un piccolo incontro) — non stanze vuote.
- [ ] Verifica a schermo con Xvfb: si entra ed esce da almeno 2 edifici
      diversi nello stesso villaggio.

#### US-1012: La prima struttura grande (palazzo/torre/cripta a più stanze)

**Descrizione:** Come giocatore, voglio almeno un edificio "importante" con
un interno a più stanze collegate — non solo una singola stanza come le
case del villaggio.

**Acceptance Criteria:**
- [ ] Una struttura (candidati coerenti coi dati esistenti: una torre
      d'osservazione dell'Archivio Sepolto, o il tempio abbandonato delle
      Marche) con un interno di almeno 3 stanze collegate da porte/corridoi
      **nello stesso file/scena interna** (non un'altra catena di
      caricamenti — l'interno stesso può essere un piccolo layout
      multi-stanza in una sola scena, riusando `zone`/muri interni).
- [ ] Contenuto reale in almeno una stanza (un nemico, un oggetto
      significativo, o un gating di conoscenza coerente con
      `design-world.md` §2.4).

### Blocco C — verifica e chiusura

#### US-1013: Checkpoint dinamico + verifica giocata

**Descrizione:** Come team, vogliamo la prova che il mondo continuo regge
davvero: si cammina da una regione all'altra senza stacchi, si entra ed
esce da edifici, senza una riga di codice che nomini un luogo specifico.

**Acceptance Criteria:**
- [ ] `tests/test_fase_10_checkpoint.gd`: grep di `res://scripts` per gli id
      delle 5 regioni + i nomi degli insediamenti/interni nuovi, scoperti
      dai dati (stesso schema del checkpoint di fase 8/9) — 0 occorrenze.
- [ ] `tests/manual/qa_mondo_continuo.gd` (Xvfb): cammina da Mirwada a una
      regione adiacente attraversando il confine SENZA che compaia una
      schermata di caricamento (nessuna chiamata a
      `get_tree().change_scene_to_*` durante l'attraversamento — solo
      all'avvio), entra in un edificio del villaggio, ne esce, entra nella
      struttura grande, ne esce. Screenshot mandati in chat.

#### US-1014: Chiusura fase 10

**Descrizione:** Come team, vogliamo la fase chiusa nella documentazione.

**Acceptance Criteria:**
- [ ] `tools/validate_data.py`: blocco "chiusura fase 10".
- [ ] `progress.txt`, `CLAUDE.md` (§ Fasi), `README.md`,
      `006_PRD/roadmap.md` aggiornati a "Fase 10: CHIUSA".
- [ ] `prd.json`: tutte le story a `passes: true`.

## 4. Functional Requirements

- FR-1: Attraversare il confine tra due regioni non deve MAI chiamare
  `change_scene_to_*` o ricreare nodi di gioco (Inventory/Progression/ecc
  restano gli stessi autoload, mai toccati da un attraversamento).
- FR-2: Un edificio (villaggio o struttura grande) resta un caricamento di
  scena locale — piccolo, veloce, esattamente come un passaggio oggi.
- FR-3: `AreaGate`/`gate_types.json` (6 modi) restano l'unico meccanismo di
  gating, sia per barriere interne a una regione sia per il confine
  d'ingresso di una regione — nessun secondo sistema di gating.
- FR-4: Nessun nome di regione/villaggio/struttura hardcoded in
  `res://scripts` — solo id e chiavi i18n (Regola 1 di CLAUDE.md).
- FR-5: Le prestazioni non devono degradare in modo percepibile
  camminando nel mondo continuo rispetto a stare fermi in una regione
  isolata di oggi (US-1003).

## 5. Non-Goals (fuori scope)

- **Non diventa un mondo aperto senza gating**: resta un non-goal esplicito
  del progetto. Il gating (chi può andare dove, quando) è identico nella
  sostanza a oggi — cambia solo che è una barriera fisica invece di un
  rifiuto di caricamento.
- **Generazione procedurale del mondo**: resta un non-goal. Ogni metro di
  mappa nuova in questa fase è disegnato a mano (come oggi).
- **Arte finale**: i tile restano procedurali/placeholder (stesso stato di
  oggi) — questa fase è geografia e contenuto, non arte.
- **Tutte le regioni "finite" di contenuto**: questa fase le fa crescere e
  costruisce UN villaggio e UNA struttura grande come prova. Riempire ogni
  regione di insediamenti è lavoro per l'Atto II/III (fase 11) o oltre.

## 6. Design Considerations

- Il confine tra due regioni deve leggersi a schermo (un cambio di bioma
  visibile, non solo geometria) — coerente con l'identità di ogni regione
  già scritta in `design-world.md`.
- Gli edifici (porte) riusano lo sprite `passaggio.png`/lo stile visivo già
  generato in fase 8, finché non serve altro.

## 7. Technical Considerations

- **Riuso massimo di `region_scene.gd`**: quasi tutte le sue funzioni
  (`_dipingi`, `_crea_zone`, `_crea_nemici`, `_crea_oggetti`, `_crea_npc`,
  `_crea_gate`) restano identiche nella logica — il cambiamento è
  strutturale (un ciclo esterno per-regione, coordinate con offset) non
  una riscrittura.
- **`AreaGate`/`_ingresso_aperto()`**: la logica di "questa regione respinge
  chi non soddisfa X" cambia da "non caricare la scena" a "la barriera
  fisica al confine resta chiusa" — stesso dato (`gating[]` con
  `area: "ingresso"`), diversa esecuzione.
- **Dimensione della `TileMapLayer`**: una singola `TileMapLayer` con tutte
  e 5 le regioni piene (stima: 5-8× le celle di oggi) è ben dentro i
  limiti pratici di Godot 4 per una `TileMapLayer` — nessuna preoccupazione
  di readibilità del motore, il vero costo è nodi (nemici/NPC/oggetti)
  vivi contemporaneamente, coperto da US-1003.

## 8. Success Metrics

- `tests/manual/qa_mondo_continuo.gd` verde: attraversamento tra regioni
  senza caricamento, ingresso/uscita da edifici.
- Nessuna regressione sugli 884+ test esistenti.
- `python tools/validate_data.py` esce 0.
- Frame time stabile camminando nel mondo pieno (US-1003).

## 9. Open Questions

- **Topologia — DECISA con l'utente (2026-09-11)**: le 4 regioni esterne
  NON restano collegate solo a Mirwada. Disposizione scelta: un anello
  attorno alla città — Mirwada al centro, le 4 regioni esterne ai quattro
  angoli (Marche del Crepuscolo NO, Archivio Sepolto NE, Frontiera delle
  Porte SE, Valle della Madre SO) — così ogni coppia di regioni esterne
  adiacenti nell'anello (Marche-Archivio, Archivio-Frontiera,
  Frontiera-Valle, Valle-Marche) ha un corridoio diretto, oltre ai 4 raggi
  verso il centro. `world_offset` (US-1001) è già piazzato secondo questa
  disposizione; i corridoi di raccordo veri (8 in tutto: 4 raggi + 4 lati
  dell'anello) restano da disegnare in US-1002.
- **Vocabolario dei tile**: la legenda chiusa (8 caratteri: pavimento,
  muro, ostacoli, acqua, decoro) basta per disegnare interni di edifici
  (porte, finestre, mobilio)? Ipotesi di lavoro: sì per la prima story
  (US-1010), da verificare scrivendo il primo interno vero.
- **`location_tags` per villaggio/struttura**: serve aggiungere voci al
  vocabolario chiuso (`data/schema/location_tags.json`) per "villaggio" e
  "palazzo/struttura"? Probabile sì (stessa procedura già usata in fase 5:
  una story di dati con motivazione) — da decidere quando si sceglie DOVE
  mettere il primo villaggio (US-1011).
