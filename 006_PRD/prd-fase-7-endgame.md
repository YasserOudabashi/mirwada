# PRD: Fase 7 — Endgame (cambio Pathway, tribolazioni, finali)

## 1. Introduzione / Overview

Le fasi 1-6 + 5b hanno costruito il gioco: 22 Pathway attivi completi
(100/100 Sequenze), il motore delle primitive, l'Acting Method, la follia, i
sistemi di supporto, le sinergie, il mondo (regioni, tempo, NPC, dialoghi,
fazioni, quest, mappa). Manca **l'endgame**: cosa succede a un Beyonder che
arriva in cima.

La fase 7 aggiunge quattro cose, tutte già promesse dalla meccanica:

1. **Cambio di Pathway** — il giocatore conserva le Sequenze basse del vecchio
   Pathway e le **fonde** con quelle del nuovo, generando abilità mutate.
   Funziona solo tra Pathway **vicini dello stesso gruppo** (design-pathways.md
   § "Perché questi dieci"): 8 percorsi di fusione possibili.
2. **Tribolazioni ai salti di fascia** — ai confini di tier (Seq 7→6, 5→4,
   3→2, 1→0) il gioco pone una prova: non un boss, una condizione che va
   soddisfatta prima che l'avanzamento sia concesso. Come `QuestSystem`:
   lettore di eventi + flag, zero verbi nuovi.
3. **Sequenze alte come contenuto** — autorità, seguaci, preghiere: la resa
   di gioco delle abilità di dominio (Seq 3-0). Riuso di `aura`/`curse`/
   `summon`; un solo vocabolario chiuso nuovo (`prayer_effects.json`), NON un
   evento nuovo.
4. **Finali** — `data/endings.json`: Apoteosi (Seq 0 raggiunta), Consumazione
   (follia a 100, game over **con eredità** al personaggio successivo),
   Rinuncia (il finale umano). 4 varianti di epilogo, una per gruppo di
   Pathway. Condizioni dal vocabolario chiuso di `scripts/conditions.gd`.

Come tutte le fasi di contenuto: **i dati non sono codice**. Il registro delle
28 primitive resta chiuso (nessuna nuova); i 12 `tracked_events` restano
invariati; ogni vocabolario nuovo è una story di dati con motivazione
esplicita. Il codice aggiunge **motori** (`FusionEngine`, `TribulationSystem`,
`EndingSystem`) che leggono i dati e non sanno nulla di quali Pathway/coppie/
finali esistano.

Save: **un solo bump `schema_version` 21 → 22** (`_migra_21_a_22`), tutto in un
campo nuovo `endgame` con default vuoti — come la fase 6 fece con `mondo`.

### Scelte di scope prese con l'utente (2026-09-08)

- **Fusioni**: motore completo + **1 percorso di fusione scritto per intero**
  (`error` → `door`, gruppo Lord of Mysteries), gli **altri 7 come stub
  dichiarati** (come le Sequenze stub di fase 5, esenti dai controlli di
  completezza ma contati). L'espansione a tutti e 8 è un aggiornamento futuro
  (fase 7b o iterazioni), non fase 7.
- **Eredità (decisione aperta n. 8)**: **tutte e quattro** le voci, ognuna
  attenuata. Vedi FR-14 e US-719 per il contratto esatto.
- **Sequenze alte**: solo dati su primitive esistenti + il vocabolario chiuso
  `prayer_effects.json` (discusso qui). Nessuna primitiva nuova.
- **Antagonista (decisione aperta n. 9)**: **chiusa** — è strutturale, il
  detentore precedente della Sequenza 0, già in `data/lore/antagonisti.json`
  (fase 6, US-620). La fase 7 gli dà il **sito rituale** e il ruolo nel
  finale, non un boss fight.

---

## 2. Goals

- **Cambio di Pathway data-driven**: `data/fusions/*.json` definisce, per ogni
  coppia di Pathway vicini, come le abilità delle Sequenze basse del vecchio
  si trasformano. `FusionEngine.componi(vecchio, nuovo)` restituisce le abilità
  fuse **senza un solo `if` per una coppia specifica**. Grep di `scripts/` per
  un id di Pathway o di coppia di fusione → **0**.
- **1 percorso completo + 7 stub**: `error` → `door` ha ≥ 5 abilità fuse
  scritte (attingono a primitive del registro attivo); gli altri 7 percorsi
  sono `stub: true` nei dati. Il validator li conta e non pretende che siano
  pieni.
- **Tribolazioni come lettore**: `TribulationSystem` blocca l'avanzamento a un
  salto di fascia finché `condizione` (dal vocabolario di `conditions.gd`) +
  `superamento` (un contatore su uno dei 12 eventi, o un flag) non sono
  soddisfatti. Zero eventi nuovi. Le 4 tribolazioni di contenuto esistono e
  sono i18n.
- **`data/endings.json`**: i 3 finali + 4 varianti di epilogo per gruppo, con
  `condizioni` da `conditions.gd` (nessun tipo di condizione nuovo).
  `EndingSystem` valuta e sceglie; la schermata di finale è una pagina del
  libro.
- **Eredità**: al game over per follia (Consumazione), o al finale Rinuncia, il
  save scrive `endgame.eredita`; alla creazione del personaggio successivo
  `Progression`/`GameState` la applicano. Contratto esatto in FR-14.
- **Save 21 → 22, una migrazione**, campo `endgame` con default vuoti.
  Round-trip verificato; i save v≤21 caricano.
- **Criterio di uscita** (`test_slice_fase_7.gd`): un personaggio Error alla
  Sequenza 4 cambia Pathway verso Door, ottiene le abilità fuse `error`→`door`
  dai dati, ne esegue una senza warning di primitiva, e **zero righe di codice
  nominano "error" o "door" o "error_door"**.

---

## 3. User Stories

Priorità: **P0** blocca il resto; **P1** necessaria; **P2** rifinitura.

### Blocco 0 — Fondamenta (save + vocabolari)

#### US-701: Save `schema_version` 21 → 22, campo `endgame`

**Description:** Come sviluppatore, voglio un solo bump del save per tutta la
fase 7, così che cambio Pathway, tribolazioni, finali ed eredità stiano in un
posto solo.

**Acceptance Criteria:**

- [ ] `scripts/save_system.gd`: `VERSIONE_CORRENTE = 22`; `_migra_21_a_22(doc)`
      aggiunge `doc["endgame"] = { "pathway_precedente": "", "fusioni": [],
      "tribolazioni_superate": [], "eredita": {}, "finale": "" }` se assente.
- [ ] La migrazione è idempotente e non tocca gli altri campi.
- [ ] `GameState.snapshot()` / `applica()` includono `endgame`;
      `EndgameState` (nuovo autoload, o campo di `GameState` — scegliere il
      pattern già usato per `mondo`) lo serializza con `per_salvataggio` /
      `da_salvataggio` **non fidati** (solo tipi attesi).
- [ ] Test (`tests/test_save_system.gd` o nuovo): un save v21 carica, `migrato`
      true, `endgame` aggiunto con i default; round-trip di un `endgame`
      popolato.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-702: `data/schema/fusion.schema.json` + `data/fusions/` — forma

**Description:** Come sviluppatore, voglio lo schema dei percorsi di fusione e
un file per percorso, così che il motore legga i dati e non conosca le coppie.

**Acceptance Criteria:**

- [ ] `data/schema/fusion.schema.json` (`additionalProperties:false`): `id`
      (`^<gruppo>_<pathA>_<pathB>$`, con `pathA` < `pathB` alfabetico),
      `gruppo` (uno dei 4 gruppi validi), `pathway_a` / `pathway_b` (id di
      Pathway attivi **dello stesso gruppo**), `abilita_fuse[]` (ognuna:
      `id` con prefisso `fus_<id fusione>_`, `da_sequenza` del vecchio Pathway
      (7..9), `name_i18n` (`^ability\.fusion\.`), `primitive[]` dal registro
      attivo, `tag_sinergia[]`, `note`), `stub` (bool).
- [ ] `data/fusions/`: 8 file, uno per percorso possibile (3 Lord of Mysteries,
      3 Eternal Darkness, 1 Demon of Knowledge, 1 Goddess of Origin). 7 con
      `stub: true` e `abilita_fuse: []`; `door_error` (o `error_door` per
      l'ordine alfabetico) pieno lo scrive US-706.
- [ ] `tools/validate_data.py`: sezione fusioni — id coerente col nome file,
      `pathway_a`/`pathway_b` nello stesso gruppo, `da_sequenza` in 7..9, le
      primitive delle abilità fuse non-stub nel registro attivo (stessi
      controlli delle abilità normali), `abilita_fuse` vuoto sse e solo se
      `stub`. Conta gli stub in un warning (come le Sequenze).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-703: Vocabolari chiusi delle tribolazioni e delle preghiere

**Description:** Come sviluppatore, voglio i due vocabolari chiusi nuovi della
fase 7 dichiarati e validati prima di usarli.

**Acceptance Criteria:**

- [ ] `data/schema/tribulation_effects.json`: vocabolario chiuso (≤ 6 voci) di
      cosa fa una tribolazione mentre è in corso (es. `follia_accelerata`,
      `spiritualita_dimezzata`, `nemici_rinforzati`, `abilita_bloccate`,
      `notte_perenne`). Ogni voce ha un `_comment`. **Non** è un evento
      tracciato.
- [ ] `data/schema/prayer_effects.json`: vocabolario chiuso (≤ 6 voci) degli
      effetti delle "preghiere" delle Sequenze alte (es. `benedizione_seguaci`,
      `voto_di_autorita`, `intercessione`, `anatema`). Ogni voce mappa su una
      **primitiva esistente** con parametri (dichiarato nel `_comment`: es.
      `benedizione_seguaci` = `aura` su `bersagli: "evocati"`).
- [ ] `tools/validate_data.py` carica entrambi e verifica che siano non vuoti e
      senza duplicati. Nessun altro dato li referenzia ancora (lo faranno
      US-712 e US-714).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco A — Cambio Pathway + Fusione

#### US-704: Cambio Pathway solo tra vicini dello stesso gruppo

**Description:** Come giocatore, voglio poter cambiare Pathway verso un vicino
dello stesso gruppo, conservando le abilità delle mie Sequenze basse.

**Acceptance Criteria:**

- [ ] `scripts/pathway_change.gd` (nuovo autoload) o estensione di
      `Progression`: `puo_cambiare(nuovo_pathway) -> bool` — true solo se
      `nuovo_pathway` è nello **stesso gruppo** del Pathway corrente (letto da
      `data/pathways/*.json.group`), diverso dall'attuale, e il giocatore è a
      una Sequenza `<= soglia_cambio` (proposta: Seq 4, tier saint — il cambio
      è tardo). Nessun id di Pathway hardcoded: la relazione "vicini" viene dal
      campo `group`.
- [ ] `cambia(nuovo_pathway) -> Dictionary`: registra `endgame.pathway_
      precedente`, imposta `Progression` sul nuovo Pathway alla **stessa
      Sequenza numerica**, e marca le abilità delle Sequenze 9..7 del vecchio
      Pathway come "conservate" (disponibili al giocatore accanto a quelle del
      nuovo — riuso di `AbilityEngine.grant_permanente` / un set nel
      `PathwayChange`).
- [ ] Rifiuto pulito (Dictionary con `ok:false, reason`) se `puo_cambiare` è
      false. Nessun crash.
- [ ] Test (`tests/test_pathway_change.gd`): Error Seq 4 → Door OK (stesso
      gruppo); Error Seq 4 → Death rifiutato (gruppo diverso); Error Seq 9 →
      Door rifiutato (troppo presto); dopo il cambio, un'abilità di `error_9`
      è ancora eseguibile dal giocatore e una di `door_4` lo è.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-705: `FusionEngine` — compone le abilità fuse dai dati

**Description:** Come sviluppatore, voglio che le abilità fuse nascano da
`data/fusions/` senza che il codice conosca una singola coppia.

**Acceptance Criteria:**

- [ ] `scripts/fusion_engine.gd` (nuovo autoload): `percorso(vecchio, nuovo)
      -> Dictionary` — cerca in `data/fusions/` il file la cui coppia
      `{pathway_a, pathway_b}` combacia (in qualsiasi ordine). `{}` se non
      esiste o è `stub`.
- [ ] `abilita_fuse(vecchio, nuovo) -> Array` — le abilità fuse di quel
      percorso, risolte come le abilità normali (stessa forma:
      `id`/`name_i18n`/`primitive`/`tag_sinergia`). `GameData.get_ability`
      sa risolvere anche un `fus_*` id (le abilità fuse entrano nell'indice
      abilità o in un indice parallelo — scegliere il pattern più semplice).
- [ ] Al `PathwayChange.cambia`, le abilità fuse del percorso (se non-stub)
      vengono concesse al giocatore (`grant_permanente`), registrate in
      `endgame.fusioni`.
- [ ] `AbilityEngine.execute` **non** viene toccato: un'abilità fusa è
      un'abilità come le altre, il dispatcher non la distingue.
- [ ] Test: `FusionEngine.abilita_fuse("error", "door")` → lista non vuota
      (dopo US-706); per un percorso stub → `[]`; l'ordine dei due Pathway non
      conta.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-706: Percorso di fusione completo — `error` → `door`

**Description:** Come giocatore che ha cambiato da Error a Door, voglio abilità
che fondono il furto dell'Error con lo spazio del Door.

**Acceptance Criteria:**

- [ ] `data/fusions/error_door.json`: `stub: false`, ≥ 5 abilità fuse, ognuna
      con `da_sequenza` 9/8/7 (le Sequenze conservate). Concept: rubare *dove*
      un nemico è (steal + teleport), fotocopiare un varco (steal non_sottrae +
      terrain_modify), scambiare la refurtiva con la propria posizione
      (steal + teleport porta_alleati:false). Solo primitive del registro
      attivo.
- [ ] Ogni abilità fusa ha `name_i18n` `^ability\.fusion\.` e almeno un
      `tag_sinergia` valido.
- [ ] i18n: `generate_i18n_stubs.py` rilanciato; i nomi delle abilità fuse
      tradotti in `it.json` (non `TODO`).
- [ ] `data/vfx.json`: se serve, la palette visiva della fusione (proposta:
      interpolazione delle due palette di Pathway — un campo
      `fusion_palette` calcolato o dichiarato). Se un placeholder basta, si
      dichiara.
- [ ] Test (`tests/test_fusion.gd`): ogni abilità fusa `error_door` esegue via
      `AbilityEngine.execute` senza warning di primitiva; le acting non
      c'entrano (le abilità fuse non hanno Sequenze proprie).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-707: Gli altri 7 percorsi come stub + check del validator

**Description:** Come sviluppatore, voglio che i 7 percorsi non scritti siano
stub dichiarati, non file mancanti.

**Acceptance Criteria:**

- [ ] `data/fusions/`: esistono tutti e 8 i file (i 7 con `stub: true`,
      `abilita_fuse: []`, un `note` che spiega il concept in una riga).
- [ ] `tools/validate_data.py`: warning "N percorsi di fusione su 8 sono stub"
      (come le Sequenze); errore se un percorso possibile **manca** del tutto.
- [ ] `FusionEngine.percorso` per uno stub → `{}`; `PathwayChange.cambia` verso
      un vicino con percorso stub funziona lo stesso (conserva le abilità
      basse), solo non concede abilità fuse.
- [ ] Test: `PathwayChange.cambia` Hermit→Paragon (percorso stub) OK, `endgame.
      fusioni` resta `[]`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-708: Pagina del libro per il cambio di Pathway

**Description:** Come giocatore, voglio una pagina del libro che mostra i
Pathway vicini verso cui posso fondere e cosa otterrei.

**Acceptance Criteria:**

- [ ] Nuova pagina (o sezione di `page_diagramma_pathway.gd`): mostra il
      gruppo del Pathway corrente, i vicini fondibili, e per ognuno se il
      percorso è scritto o "ancora da rivelare" (stub → fog of war, come il
      diagramma).
- [ ] Se `PathwayChange.puo_cambiare` è true, un'azione conferma il cambio;
      altrimenti mostra il motivo (troppo presto / gruppo diverso).
- [ ] Nessun nome di Pathway hardcoded nella pagina: solo id e chiavi i18n.
- [ ] Verifica a schermo documentata in `progress.txt`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-709: CHECKPOINT — slice del cambio Pathway + verdetto

**Description:** Come sviluppatore, voglio la conferma che il cambio Pathway +
fusione non ha richiesto un `if` per una coppia, prima di andare avanti.

**Acceptance Criteria:**

- [ ] `tests/test_slice_fase_7.gd`: un personaggio Error a Seq 4 →
      `PathwayChange.cambia("door")` → è su Door Seq 4, ha ancora le abilità di
      `error_9`, ha le abilità fuse `error_door`, ne esegue una senza warning.
- [ ] `test_nessun_codice_nomina_una_fusione`: grep di `res://scripts` e
      `res://scripts/pages` per gli id di Pathway e per `fus_`/`error_door` →
      **zero occorrenze** fuori dai commenti.
- [ ] `git diff` del blocco A (file `.gd`): elenco esatto in `progress.txt`.
      `AbilityEngine.execute` / `_esegui_primitive` non modificati per la
      fusione.
- [ ] **Verdetto in `progress.txt`**: il cambio Pathway è dati / non lo è. Se
      non lo è: correzioni e STOP.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco B — Tribolazioni

#### US-710: `data/schema/tribulation.schema.json` + `data/tribulations/`

**Description:** Come sviluppatore, voglio lo schema delle tribolazioni e un
file per ognuna, prima del motore.

**Acceptance Criteria:**

- [ ] `data/schema/tribulation.schema.json` (`additionalProperties:false`):
      `id`, `name_i18n` (`^tribulation\.`), `salto` (`{"da": N, "a": N-1}` con
      `da` ∈ {7,5,3,1} — i confini di fascia), `condizioni[]` (dal vocabolario
      di `conditions.gd`, nessun tipo nuovo), `mentre_in_corso` (una voce di
      `tribulation_effects.json`), `superamento` (`{"evento": <uno dei 12>,
      "filtri": {}, "target": N}` **oppure** `{"flag": "<nome>"}`),
      `descrizione_i18n`.
- [ ] `data/tribulations/`: 4 file, uno per salto di fascia (7→6, 5→4, 3→2,
      1→0).
- [ ] `tools/validate_data.py`: sezione tribolazioni — `salto.da` valido,
      `condizioni` nel vocabolario, `superamento.evento` nei 12 eventi (o
      `flag` stringa), `mentre_in_corso` in `tribulation_effects.json`, una
      sola tribolazione per salto.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-711: `TribulationSystem` — lettore, blocca l'avanzamento

**Description:** Come giocatore, quando arrivo a un salto di fascia voglio che
il gioco mi ponga la prova prima di lasciarmi avanzare.

**Acceptance Criteria:**

- [ ] `scripts/tribulation_system.gd` (nuovo autoload): `tribolazione_per(da)
      -> Dictionary` (dai dati); `attiva(da)` all'inizio del salto, `stato() ->
      { in_corso, superata, progresso }`, ascolta `EventTracker` per il
      `superamento.evento` e `KnowledgeStore`/flag per `superamento.flag`.
- [ ] `Progression.avanza` (o `RitualSystem`/`PotionSystem` al punto di
      avanzamento): se c'è una tribolazione per quel salto e non è `superata`,
      l'avanzamento è **rifiutato** con un motivo. Nessun verbo nuovo: il
      sistema legge gli eventi che già esistono.
- [ ] `mentre_in_corso` applica il suo effetto (dal vocabolario) mentre la
      tribolazione è attiva; si toglie al superamento.
- [ ] `tribolazioni_superate` nel save (`endgame`).
- [ ] Test (`tests/test_tribulation_system.gd`): al salto 3→2 l'avanzamento è
      bloccato finché il `superamento` non è raggiunto; poi passa;
      `mentre_in_corso` applicato e rimosso; round-trip nel save.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-712: Le 4 tribolazioni di contenuto

**Description:** Come giocatore, voglio che ogni salto di fascia abbia una
prova a tema con la narrativa dei tre atti.

**Acceptance Criteria:**

- [ ] 4 tribolazioni scritte (7→6: "la città non basta più"; 5→4: le fazioni
      prendono posizione; 3→2: Doran sa; 1→0: la soglia — l'antagonista).
      Ognuna con `condizioni` plausibili, `mentre_in_corso` da vocabolario,
      `superamento` su un evento reale o un flag posto da una quest/dialogo.
- [ ] i18n completo (name + descrizione) in `it.json`, 0 `TODO` sulle chiavi
      `tribulation.*`.
- [ ] La tribolazione 1→0 usa il flag `atto_1_concluso`/`aldo_duello_
      disponibile` o un flag nuovo posto da un dialogo con l'antagonista
      (coordinato con `data/lore/antagonisti.json`).
- [ ] Test: ogni tribolazione risolve i suoi riferimenti (evento, flag,
      effetto, condizioni) — un test data-driven che itera i 4 file.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-713: Overlay del libro per la tribolazione in corso

**Description:** Come giocatore, voglio vedere quale prova sto affrontando e a
che punto sono.

**Acceptance Criteria:**

- [ ] Un overlay/pagina mostra: nome della tribolazione, descrizione, l'effetto
      `mentre_in_corso` attivo, il progresso verso il `superamento`.
- [ ] Reattivo dal vivo (ascolta i segnali di `TribulationSystem`).
- [ ] Nessun testo hardcoded: chiavi i18n.
- [ ] Verifica a schermo documentata in `progress.txt`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco C — Sequenze alte (autorità / seguaci / preghiere)

#### US-714: `prayer_effects.json` + le preghiere come contenuto

**Description:** Come giocatore alle Sequenze alte, voglio abilità di
"preghiera" che intercedono per i seguaci e impongono autorità.

**Acceptance Criteria:**

- [ ] `data/schema/prayer_effects.json` (da US-703) referenziato: un campo
      opzionale `preghiera` sulle abilità (`ability.schema.json` esteso,
      retro-compatibile) che nomina una voce del vocabolario. Il campo è
      **puramente semantico + i18n**: l'effetto vero lo fanno le `primitive`
      dell'abilità (aura/curse/summon/buff_stat), come dice il `_comment` del
      vocabolario.
- [ ] ≥ 6 abilità nuove di Sequenza 3-0 distribuite su più Pathway (Death,
      Twilight Giant, Hermit, Sun-not-active → scegliere tra gli attivi) che
      usano `preghiera`: "benedizione dei seguaci" (`aura` su evocati),
      "voto di autorità" (`aura`/`curse` di dominio sui nemici), "anatema"
      (`curse` + `debuff_stat`). Solo primitive esistenti.
- [ ] Queste abilità si aggiungono alle Sequenze già scritte come **seconda o
      terza abilità** dove il conteggio lo permette, oppure sono abilità
      concesse da una sinergia/preghiera — senza rompere il "2 abilità per
      Sequenza" del validator (se il validator lo impone: verificarlo, e nel
      caso ammettere 3 abilità alle Sequenze god/angel con una nota).
- [ ] i18n completo. `tools/validate_data.py`: `preghiera` (se presente) nel
      vocabolario.
- [ ] Test: ogni abilità con `preghiera` esegue senza warning; il campo
      `preghiera` non cambia il comportamento del motore (è i18n).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-715: Siti rituali di Sequenza 0

**Description:** Come giocatore, voglio che il rituale di Sequenza 0 di ogni
Pathway abbia un luogo reale nel mondo.

**Acceptance Criteria:**

- [ ] `data/schema/location_tags.json`: aggiunte versionate — un `location_tag`
      per i siti di Sequenza 0 non ancora coperti (proposta: uno per **gruppo**,
      non per Pathway — `soglia_del_crepuscolo`, `radice_del_mondo`,
      `biblioteca_di_tutto`, `porta_senza_stanza` — 4 tag). Ogni aggiunta con
      motivazione nel `_comment`.
- [ ] I rituali di `advancement_ritual` delle Sequenze 0 dei 22 Pathway
      puntano al tag del proprio gruppo (modifica dati, nessun codice). Il
      validator già pretende che le regioni ospitino i `location_tags` dei
      rituali non-stub: le regioni di fase 6 vanno aggiornate perché ospitino i
      4 nuovi tag (probabilmente tutti in `frontiera_porte` / `marche_
      crepuscolo`).
- [ ] `data/world/regions.json`: le regioni giuste elencano i 4 tag nuovi.
- [ ] Il sito rituale di Sequenza 0 è dove si trova l'antagonista
      (`antagonisti.json`): coerenza dichiarata nella `note`.
- [ ] Test: `test_regions.gd` — ogni `location_tag` di un rituale di Sequenza 0
      è ospitato da una regione.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco D — Finali

#### US-716: `data/endings.json` + schema — i 3 finali + 4 epiloghi

**Description:** Come sviluppatore, voglio i finali come dati con condizioni dal
vocabolario chiuso esistente.

**Acceptance Criteria:**

- [ ] `data/schema/ending.schema.json` (`additionalProperties:false`): `id`
      (`apoteosi` | `consumazione` | `rinuncia`), `name_i18n`
      (`^ending\.`), `condizioni[]` (dal vocabolario di `conditions.gd`,
      nessun tipo nuovo — es. `sequence` raggiunta / `madness_min` 100 /
      `flag` "pozione_distrutta"), `priorita` (int — se più finali sono
      soddisfatti vince il più alto), `eredita_profilo`
      (`completo` | `ancore` | `solo_conoscenza` — quale sottoinsieme
      dell'eredità si applica, vedi FR-14), `epiloghi_per_gruppo`
      (`{ <gruppo>: <text_i18n> }`, 4 voci).
- [ ] `data/endings.json`: le 3 voci. Apoteosi: `sequence` 0 + rituale
      completato. Consumazione: `madness_min` 100. Rinuncia: `flag`
      "pozione_distrutta" + almeno un'Ancora viva.
- [ ] `tools/validate_data.py`: i 3 id esatti presenti; `condizioni` valide;
      `epiloghi_per_gruppo` copre i 4 gruppi; `eredita_profilo` nell'enum.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-717: `EndingSystem` — valuta e sceglie

**Description:** Come giocatore, voglio che il gioco riconosca quando ho
raggiunto un finale e quale.

**Acceptance Criteria:**

- [ ] `scripts/ending_system.gd` (nuovo autoload): `valuta() -> String` — l'id
      del finale con `priorita` più alta le cui `condizioni` sono tutte
      soddisfatte (riuso di `scripts/conditions.gd`), `""` se nessuno.
- [ ] Emesso un segnale `finale_raggiunto(id, gruppo)`; `endgame.finale`
      scritto nel save; il gioco entra in uno stato di epilogo (pausa +
      pagina).
- [ ] La **Consumazione** è agganciata a `Madness` (soglia 100, già la soglia
      "mostro"): il game over per follia È il finale Consumazione, non un
      percorso separato.
- [ ] Test (`tests/test_ending_system.gd`): con follia 100 → `consumazione`;
      con Seq 0 + rituale → `apoteosi` (priorità: se entrambe, vince quella
      dichiarata); con flag pozione_distrutta + Ancora viva → `rinuncia`;
      nessuna condizione → `""`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-718: Schermata di finale nel libro

**Description:** Come giocatore, alla fine voglio una pagina che mi dice come è
andata e cosa passa al prossimo.

**Acceptance Criteria:**

- [ ] Una pagina (estensione del colophon, o nuova): titolo del finale,
      epilogo della variante di gruppo, la lista di cosa viene ereditato
      (da `endgame.eredita`), e — per la Consumazione / Rinuncia — l'azione
      che sceglie l'**oggetto** da ereditare (US-719).
- [ ] Nessun testo hardcoded.
- [ ] Verifica a schermo documentata in `progress.txt`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-719: Eredità al personaggio successivo — il contratto

**Description:** Come giocatore che ha perso (Consumazione) o si è fermato
(Rinuncia), voglio che qualcosa passi al personaggio successivo.

**Acceptance Criteria:**

- [ ] Al `finale_raggiunto`, se `eredita_profilo` != "nessuno", `EndingSystem`
      compila `endgame.eredita` secondo FR-14:
      - `conoscenza`: tutti i flag `pathway:*` / `sequenza:*` di
        `KnowledgeStore` (fog of war del diagramma). **Sempre**, per tutti i
        profili.
      - `ancora`: se il giocatore ha ≥ 1 Ancora viva (`AnchorSystem.active`),
        alla schermata di finale ne sceglie una; passa `{ id, forza:
        forza/2 }`. Profili `completo` e `ancore`.
      - `reputazione`: ogni valore di `FactionSystem` moltiplicato per 0.5
        (verso 0). Profilo `completo`.
      - `oggetto`: il giocatore sceglie **un** `item_id` dall'inventario alla
        schermata di finale. Profilo `completo`.
- [ ] Alla creazione del **nuovo personaggio** (nuova partita con un save che
      ha `endgame.eredita` non vuoto): `KnowledgeStore.da_salvataggio` semina i
      flag di conoscenza; `AnchorSystem` registra l'Ancora ereditata a forza
      dimezzata; `FactionSystem` parte dai valori attenuati; `Inventory`
      aggiunge l'oggetto. Tutto il resto (Sequenza, statistiche, follia)
      riparte da capo.
- [ ] `endgame.eredita` è **non fidato** in lettura: id ignoti scartati, valori
      fuori range clampati.
- [ ] Test (`tests/test_eredita.gd`): un ciclo completo — finale Consumazione
      con 2 Ancore vive, reputazione, un oggetto → `endgame.eredita` compilato
      → nuovo personaggio → conoscenza seminata, 1 Ancora a forza/2,
      reputazione a metà, oggetto in inventario, Sequenza di nuovo a 9.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco E — Chiusura

#### US-720: Verdetto del criterio di uscita della fase 7

**Description:** Come sviluppatore, voglio la prova che l'endgame è dati.

**Acceptance Criteria:**

- [ ] `tests/test_slice_fase_7.gd` (esteso da US-709): copre il ciclo completo
      — cambio Pathway con fusione, una tribolazione superata, un finale
      valutato, l'eredità compilata e riapplicata — **senza una riga di codice
      che nomini un Pathway, una coppia di fusione, una tribolazione o un
      finale specifico**.
- [ ] `git diff` di tutta la fase 7 (file `.gd` non di test): elenco in
      `progress.txt`. I motori nuovi (`FusionEngine`, `TribulationSystem`,
      `EndingSystem`, `PathwayChange`) non contengono `if` per un id di
      contenuto. `AbilityEngine.execute` / `_esegui_primitive` intatti.
- [ ] **Verdetto in `progress.txt`**: l'endgame è dati / non lo è.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-721: Chiusura fase 7

**Description:** Come sviluppatore, voglio che i documenti riflettano la fase 7
chiusa.

**Acceptance Criteria:**

- [ ] `006_PRD/roadmap.md`: "Fase 7 — Endgame — CHIUSA (N story, M test)" con
      l'elenco dei blocchi e la nota sui 7 percorsi di fusione stub (fase 7b).
- [ ] `006_PRD/design-master.md`: Appendice A fase 7 → CHIUSA; Appendice B
      decisioni n. 8 (eredità) e n. 9 (antagonista) → CHIUSE; Appendice C: le
      righe dei vocabolari/schema nuovi (`fusion`, `tribulation`,
      `tribulation_effects`, `prayer_effects`, `ending`, `endgame` nel save).
- [ ] `006_PRD/design-npc-quest.md` § 5: i finali e i tre atti segnati come
      "REALIZZATO in fase 7".
- [ ] `CLAUDE.md` + `README.md`: fase 7 chiusa, conteggi, save 21 → 22,
      "fase corrente: 8 (opzionale) o manutenzione".
- [ ] `tools/validate_data.py`: check di chiusura fase 7 — i file di dati della
      fase esistono (`fusions/`, `tribulations/`, `endings.json` + i 3 schema);
      `error_door` non-stub; i 3 finali presenti.
- [ ] `python tools/validate_data.py` esce 0. Tutti i test headless verdi. Typecheck passes. Tests pass.

---

## 4. Functional Requirements

- **FR-1:** Nessuna primitiva **nuova**, nessun evento **nuovo**. I 12
  `tracked_events` e le 28 primitive del registro restano invariati.
- **FR-2:** Vocabolari chiusi nuovi: `tribulation_effects.json`,
  `prayer_effects.json`, più gli enum degli schema (`fusion` id pattern,
  `ending` id fissi, `eredita_profilo`). Ogni aggiunta a `location_tags.json` è
  versionata con motivazione.
- **FR-3:** Il cambio di Pathway è possibile **solo** tra Pathway con lo stesso
  `group` (letto dai dati), diversi dall'attuale, e solo da una Sequenza
  `<= soglia_cambio` (dato in `balance.json`, proposta 4). Nessun id di Pathway
  hardcoded nella logica.
- **FR-4:** `FusionEngine` cerca il percorso per coppia non ordinata; le abilità
  fuse sono abilità normali (stessa forma), il dispatcher `AbilityEngine.execute`
  non le distingue.
- **FR-5:** 1 percorso completo (`error_door`, ≥ 5 abilità fuse), 7 stub
  dichiarati. Il validator conta gli stub (warning) e pretende che tutti e 8 i
  file esistano.
- **FR-6:** `TribulationSystem` è un **lettore**: `EventTracker` per i contatori,
  `KnowledgeStore`/flag per i booleani. Non emette eventi. Blocca
  l'avanzamento a un salto di fascia (Seq 7→6, 5→4, 3→2, 1→0) finché la
  tribolazione non è `superata`.
- **FR-7:** `mentre_in_corso` di una tribolazione applica una voce di
  `tribulation_effects.json` e la rimuove al superamento.
- **FR-8:** Il campo `preghiera` sulle abilità è **semantico + i18n**: l'effetto
  meccanico lo fanno le `primitive` dell'abilità (aura/curse/summon/buff_stat).
  Il motore non lo legge per cambiare comportamento.
- **FR-9:** `data/endings.json` ha esattamente 3 voci (`apoteosi`,
  `consumazione`, `rinuncia`). `EndingSystem.valuta` usa `scripts/conditions.gd`
  senza aggiungere tipi di condizione.
- **FR-10:** La **Consumazione** È il game over per follia (soglia 100 di
  `Madness`), non un percorso separato.
- **FR-11:** 4 varianti di epilogo, una per **gruppo** di Pathway (non per
  Pathway): il gruppo decide il sapore.
- **FR-12:** Save **`schema_version` 21 → 22**, una `_migra_21_a_22`, campo
  `endgame` = `{ pathway_precedente, fusioni[], tribolazioni_superate[],
  eredita{}, finale }` con default vuoti. I save v≤21 caricano.
- **FR-13:** Ogni sotto-stato di `endgame` si legge **non fidato**: id ignoti
  scartati, numeri fuori range clampati, tipi sbagliati → default.
- **FR-14:** **Eredità** — `endgame.eredita` è compilato al finale secondo
  `eredita_profilo`:
  - `solo_conoscenza` (Apoteosi): solo i flag `pathway:*` / `sequenza:*` del
    diagramma.
  - `ancore` (Rinuncia): conoscenza + 1 Ancora viva scelta, `forza` dimezzata.
  - `completo` (Consumazione): conoscenza + 1 Ancora viva (se c'è) a `forza/2`
    + tutta la reputazione moltiplicata per 0.5 + 1 oggetto scelto
    dall'inventario.
  La conoscenza passa **sempre**. Tutto il resto del profilo (Sequenza,
  statistiche, follia, sinergie, talenti, pet, strutture) riparte da zero al
  nuovo personaggio.
- **FR-15:** Ogni motore nuovo (`PathwayChange`, `FusionEngine`,
  `TribulationSystem`, `EndingSystem`) non contiene un `if` per un id di
  contenuto. Grep di `scripts/` per un id di Pathway / coppia di fusione /
  tribolazione / finale → 0 fuori dai commenti.
- **FR-16:** Ogni story con UI (US-708, US-713, US-718) ha una verifica a
  schermo documentata in `progress.txt`.
- **FR-17:** Ogni story chiude in una context window; se supera ~4 file di
  logica o ~200 righe di diff di codice, si spezza.

---

## 5. Non-Goals (Out of Scope)

- **I 7 percorsi di fusione oltre `error_door`.** Stub dichiarati; li riempie
  una fase 7b o iterazioni successive.
- **Un boss fight per l'antagonista.** L'antagonista resta strutturale (indizi,
  presenza, il sacrificio del rituale di Sequenza 0). Nessuna arena, nessuna
  barra della vita dedicata.
- **Nuove primitive / nuovi eventi tracciati.** Se una preghiera o una
  tribolazione sembra richiederli, si riformula sui dati o si porta la
  discussione all'utente prima.
- **Pathway Non-Standard / avanzamento per Boon** (fase 8).
- **Bilanciamento reale** di fusioni, tribolazioni, finali. Valori plausibili,
  da ritarare dopo il playtest.
- **Doppiaggio degli epiloghi** (non-goal permanente del progetto).
- **Un secondo `save slot` di "lignaggio"** che tiene la storia di tutti i
  personaggi passati. L'eredità è un singolo salto n → n+1.
- **Ricomporre le acting_actions delle abilità fuse.** Le abilità fuse non
  hanno Sequenze proprie: si usano, non si "recitano".

---

## 6. Design Considerations

- **Il gold standard resta `data/abilities/twilight_giant.json` + i Pathway di
  fase 5/5b**: abilità composte da primitive, zero codice dedicato. Le abilità
  fuse di `error_door.json` sono lo stesso formato.
- **La fusione è geografia, non potenza.** `error_door` non deve essere
  "steal + teleport più forti": deve essere un verbo terzo (rubare *da dove*
  sei, non *cosa* — riposizionare la refurtiva, fotocopiare un varco). Il
  concept prima dei numeri.
- **La tribolazione non è un combattimento.** È una condizione + un handicap
  temporaneo + un obiettivo misurato su eventi che il giocatore già genera.
  Come `QuestSystem`, non come `AreaGate`.
- **I finali sono 3, gli epiloghi 4 (per gruppo), le combinazioni Pathway
  22**: la varietà narrativa sta nell'incrocio, non in 22 finali scritti a
  mano.
- **L'eredità dà peso alla morte senza punire la ripetizione.** La conoscenza
  che passa sempre è la meta-progressione (il diagramma resta illuminato); il
  resto è attenuato apposta.
- **Riuso**: `grant_permanente` (US-404) per le abilità conservate e fuse;
  `conditions.gd` per finali e tribolazioni; `EventTracker` per il superamento;
  `KnowledgeStore` / `AnchorSystem` / `FactionSystem` / `Inventory` per
  l'eredità; il pattern `mondo` del save per il campo `endgame`; la pagina
  diagramma per la UI del cambio Pathway.

---

## 7. Technical Considerations

- **Autoload nuovi**: `PathwayChange`, `FusionEngine`, `TribulationSystem`,
  `EndingSystem`. Ordine in `project.godot`: dopo `GameData` e i sistemi che
  leggono (`Progression`, `EventTracker`, `KnowledgeStore`, `AnchorSystem`,
  `FactionSystem`, `Madness`, `Inventory`), prima delle pagine del libro.
  Valutare se `PathwayChange` è meglio come metodi di `Progression` (meno
  autoload) — decidere alla US-704.
- **`GameData.get_ability`** deve risolvere gli id `fus_*`: caricare
  `data/fusions/*.json.abilita_fuse` in un indice (parallelo o unito a quello
  delle abilità). Un `fus_*` non ha `sequence_id`: il validator delle abilità
  normali non deve lamentarsene (ramo separato).
- **`_migra_21_a_22`**: aggiunge un solo campo. `test_save_system.gd` ha già il
  pattern per ogni migrazione precedente.
- **`Madness` soglia 100**: il segnale/stato "mostro" esiste già (US-215).
  `EndingSystem` ci si aggancia invece di duplicare la soglia.
- **Le abilità fuse e il VFX**: `data/vfx.json` ha una palette per Pathway. Una
  fusione può interpolare le due palette a runtime (nessun dato nuovo) o
  dichiarare una `fusion_palette` per `error_door`. Decidere alla US-706 col
  primo VFX a schermo.
- **`ralph`**: `--fase 7` — richiede `"fase": 7` in `prd.json` (int, come le
  fasi 1-6; NON stringa come "5b"). Docker attivo,
  `--test-cmd "godot --headless --script tests/run_tests.gd"`. Una story per
  iterazione; Godot 4.3 headless in locale a ogni story; verifica a schermo
  reale per le story con UI.
- **Nessuna dipendenza nuova.**

---

## 8. Success Metrics

- **Criterio di uscita (`test_slice_fase_7.gd`)**: cambio Pathway + fusione +
  tribolazione + finale + eredità giocati in codice, **zero righe di codice che
  nominano un Pathway, una coppia di fusione, una tribolazione o un finale
  specifico**. I soli file `.gd` toccati sono i 4 motori nuovi + i loro test +
  le pagine del libro.
- **Cambio Pathway data-driven**: `FusionEngine.abilita_fuse("error", "door")`
  restituisce le abilità dai dati; `PathwayChange` rifiuta i cambi fuori
  gruppo; il dispatcher `AbilityEngine.execute` è intatto.
- **1 percorso completo + 7 stub**: `error_door.json` ha ≥ 5 abilità fuse
  eseguibili; gli altri 7 file esistono come stub.
- **Tribolazioni**: le 4 bloccano l'avanzamento al loro salto e si superano
  con eventi/flag reali; `mentre_in_corso` applicato e rimosso.
- **Finali**: i 3 valutati correttamente da `conditions.gd`; la Consumazione è
  il game over per follia; 4 epiloghi per gruppo.
- **Eredità**: un ciclo n → n+1 completo — conoscenza seminata, 1 Ancora a
  forza dimezzata, reputazione a metà, 1 oggetto in inventario, tutto il resto
  da zero.
- **Save 21 → 22**: una migrazione, i save v≤21 caricano, round-trip di un
  `endgame` popolato.
- **Nessuna regressione**: i ~713 test di fase 1-6+5b restano verdi.
  `probability_shift`/`weather_control`/`rule_bind`/`chain` restano non
  implementate (grep → 0).

---

## 9. Open Questions

1. **`soglia_cambio` di Pathway** — Seq 4 (tier saint, il cambio è tardo e
   costa) o Seq 5 (più margine per giocarci le fusioni)? Proposta: 4, in
   `balance.json`, ritarabile.
2. **Abilità fuse: quali Sequenze del vecchio Pathway** — solo 9-7 (le
   "conservate"), o anche 6-4? Proposta: 9-7 (le Sequenze basse sono quelle
   che "restano nelle mani" al cambio; le alte del vecchio Pathway si
   perdono).
3. **`prayer` come campo di abilità vs. abilità concesse da una sinergia** —
   se il validator impone "2 abilità per Sequenza" senza deroghe, le preghiere
   diventano una terza abilità (con nota) o un output di sinergia. Da decidere
   in US-714 dopo aver riletto il check del validator.
4. **VFX della fusione** — palette interpolata a runtime o `fusion_palette`
   dichiarata per `error_door`? Da decidere in US-706 col primo VFX.
5. **La tribolazione 1→0 e l'antagonista** — il `superamento` è un flag posto
   da un dialogo con l'antagonista (serve un grafo dialogo nuovo per
   l'antagonista di ogni Pathway?) o un evento di combattimento generico
   ("sopravvivi a N")? Proposta: un flag `soglia_superata` posto da un dialogo
   generico dell'antagonista (uno solo, parametrico sul Pathway via i18n), per
   non scrivere 22 grafi.
6. **Epiloghi per gruppo: testo lungo o chiave i18n corta** — `text_i18n` che
   punta a un paragrafo in `it.json`. Confermato: chiave i18n, il testo vive
   nel catalogo dati.
