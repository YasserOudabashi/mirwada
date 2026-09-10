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
- [ ] Nessuna regressione sulle 5 regioni esistenti: `world_offset` iniziale
      può essere una disposizione semplice (es. Mirwada al centro, le altre
      4 attorno, stessa topologia hub-and-spoke di oggi — vedi §9 sulla
      topologia).
- [ ] Test headless: nessuna sovrapposizione, ogni regione ha un
      `world_offset`.

#### US-1002: Una scena, non cinque — il motore dipinge più layout nella stessa TileMapLayer

**Descrizione:** Come giocatore, voglio che il mondo sia una sola scena
continua: `region_scene.gd` (o il suo successore) deve poter dipingere PIÙ
layout, ognuno al proprio `world_offset`, nella stessa `TileMapLayer`.

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
      esistere e essere calpestabile).
- [ ] `WorldState.regione_corrente()` si aggiorna quando il giocatore
      attraversa il confine (nuova `Area2D` di attraversamento, sostituisce
      semanticamente il vecchio `passaggio` — stesso nodo, comportamento
      diverso: aggiorna `_regione` e basta, MAI ricarica la scena).
- [ ] `main.gd`: niente più `partita_iniziata` che ricrea la scena regione a
      ogni viaggio — la scena si crea UNA volta all'avvio/al caricamento.
- [ ] Test headless + verifica a schermo con Xvfb: cammina da un capo
      all'altro di due regioni adiacenti senza che lo schermo lampeggi o
      che `Progression`/`Inventory`/qualunque stato si azzeri a metà.

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

**Descrizione:** Come giocatore, voglio che la città hub sia un luogo con
un'identità fisica — non un rettangolo con 5 zone invisibili sovrapposte.

**Acceptance Criteria:**
- [ ] Layout ridisegnato più grande (dimensione libera, non più vincolata a
      48×36 — vedi US-1001/1002), con i 5 `location_tags` di Mirwada
      (`porto`, `archivio`, `vicolo`, `piazza`, `sotterraneo`) come zone
      fisicamente distinte e riconoscibili (non rettangoli a griglia
      automatica).
- [ ] Almeno 3 edifici visitabili (interni, vedi Blocco B) coerenti coi
      biomi di `design-world.md` §2.1 (la casa di Lena, l'archivio di
      Ottavia, una bettola del porto).
- [ ] Nessuna regressione: gli 8 NPC esistenti restano raggiungibili, le
      quest di Atto I restano completabili.

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
- **Connessioni dirette tra le 4 regioni esterne** (oggi e in questa fase:
  hub-and-spoke attraverso Mirwada) — vedi Open Questions §9.

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

- **Topologia**: oggi le 4 regioni esterne si connettono SOLO a Mirwada
  (hub-and-spoke). Il mondo continuo dovrebbe anche collegarle
  direttamente tra loro (più "vera mappa", più esplorazione) o restare
  hub-and-spoke ma percorribile a piedi? Proposta di questo PRD: restare
  hub-and-spoke per questa fase (coerente col design esistente, meno
  contenuto da disegnare), con connessioni dirette come possibile lavoro
  futuro — **da confermare con l'utente prima di iniziare US-1001**.
- **Vocabolario dei tile**: la legenda chiusa (8 caratteri: pavimento,
  muro, ostacoli, acqua, decoro) basta per disegnare interni di edifici
  (porte, finestre, mobilio)? Ipotesi di lavoro: sì per la prima story
  (US-1010), da verificare scrivendo il primo interno vero.
- **`location_tags` per villaggio/struttura**: serve aggiungere voci al
  vocabolario chiuso (`data/schema/location_tags.json`) per "villaggio" e
  "palazzo/struttura"? Probabile sì (stessa procedura già usata in fase 5:
  una story di dati con motivazione) — da decidere quando si sceglie DOVE
  mettere il primo villaggio (US-1011).
