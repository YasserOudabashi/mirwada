# PRD Fase 2 — Pathway Core

## Introduzione

La fase 1 ha costruito lo scheletro: movimento, combattimento, caricamento
dati, save, cinque primitive. Il gioco si muove e picchia, ma non ha ancora
**nessuna** meccanica di progressione: non c'è coltivazione, non c'è follia,
non c'è un Pathway.

La fase 2 accende il sistema di progressione a Pathway/Sequenze. È **il salto
più rischioso del progetto**: qui si scopre se l'architettura data-driven
regge davvero. La prova è una sola — `data/abilities/twilight_giant.json`
contiene un Pathway completo dalla Sequenza 9 alla 0, e il motore deve
eseguirlo **senza una riga di codice dedicata**. Se ci riesce, le fasi 3-7
sono in gran parte lavoro di dati. Se serve una `if` per il Twilight Giant,
l'architettura va corretta adesso, non alla fase 5.

Insieme al sistema di progressione, la fase 2 apre la **shell della UI a
libro** (deve assorbire il diagramma dei Pathway promesso dalla roadmap),
crea `data/vfx.json` con le 10 palette visive, e chiude il debito i18n
(R-12): sono tutti sistemi che, se rimandati, farebbero inventare a ogni
story futura un vocabolario proprio.

**Engine:** Godot 4.x (GDScript), invariato dalla fase 1.

### Criterio di uscita della fase

Si può creare un personaggio (scrivendo il nome sul frontespizio del libro),
partire da Sequenza 9 del Twilight Giant, e **arrivare a Sequenza 5 giocando**:
raccogliere le Caratteristiche Beyonder, preparare le pozioni, completare la
recitazione (Acting Method), bere e avanzare — con la follia che cresce a
ogni forzatura e le Ancore che contano. Il tutto leggendo `twilight_giant.json`,
senza codice specifico per quel Pathway.

### Numerazione e dimensione

Story `US-2NN` (il `2` è la fase; ralph filtra sul campo `"fase": 2`). Ogni
story chiude in una context window: ≤4 file toccati, ≤200 righe di diff. Dove
il design-master aveva già previsto uno split (shell del libro, VFX), le story
nascono già spezzate. ~31 story: il PRD è grande perché la fase lo è. Vanno
lavorate in ordine di priorità — i blocchi A→H sono il criterio di uscita, i
blocchi I→J lo completano.

---

## Obiettivi

- Stato di progressione del giocatore (Pathway, Sequenza, tier) persistente
- Il Twilight Giant eseguito end-to-end dal motore, zero codice dedicato
- Portare le primitive implementate da 5 a ~15 su 28
- Le tre capacità del motore emerse dallo stress test (esecuzione di abilità
  non possedute, evocazioni persistenti serializzate, hook `stored_ability_id`)
- Avanzamento per pozione (Concoction) con formule parziali
- Acting Method: recitazione come contatori sui 12 eventi tracciati
- Follia cumulativa con effetti a soglia su tre canali (meccanica, audio, video)
- Ancore: registrazione, riduzione della follia, distruttibilità
- Rituale di avanzamento per le Sequenze alte
- Percezione per Sequenza come canale informativo dell'esplorazione
- Shell della UI a libro con animazione di voltata, più le pagine di fase 2
  (scaffale, frontespizio, diagramma Pathway, colophon)
- `data/vfx.json` con le 10 palette visive e i VFX delle primitive di fase 2
- i18n reale (R-12): stub generati, file `it`, check del validator

---

## User Stories

## Blocco A — Stato di progressione e capacità del motore

### US-201: Stato di progressione del giocatore

**Descrizione:** Come sviluppatore, ho bisogno di un componente che tenga
Pathway, Sequenza e tier del giocatore, così che ogni sistema di fase 2 legga
da un'unica fonte.

**Criteri di accettazione:**
- [ ] Nodo/autoload `ProgressionComponent` (o estensione di `GameState`) con:
      `pathway_id`, `sequence` (9→0), `tier` (derivato dai dati della Sequenza)
- [ ] API di sola lettura: `pathway()`, `sequence()`, `tier()`, `sequence_data()`
- [ ] `stat_modifiers` della Sequenza corrente applicati allo `StatsComponent`
      del giocatore via i modificatori per id di US-007 (id `"sequence:<n>"`),
      rimossi e riapplicati a ogni avanzamento
- [ ] Segnale `sequence_changed(nuova, vecchia)`
- [ ] Nessun nome di Pathway/Sequenza hardcoded: solo `pathway_id` e chiavi i18n
- [ ] `schema_version` del save incrementato; il campo `progressione`
      `{pathway_id, sequence}` serializzato e riletto con `typeof()` + default
- [ ] Catena di migrazione dal salvataggio di fase 1 (aggiunge `progressione`
      con Pathway di default e Sequenza 9)
- [ ] Test headless: applicazione/rimozione degli `stat_modifiers`, round-trip
      del save, migrazione dalla versione di fase 1
- [ ] Il typecheck/lint passa

### US-202: Primitive del Twilight Giant — parte 1 (`shield`, `aura`, `dot`, `decay`)

**Descrizione:** Come sviluppatore, voglio implementare le primitive difensive
e di area che il Twilight Giant usa, secondo i parametri del registro chiuso.

**Criteri di accettazione:**
- [ ] `shield`, `aura`, `dot`, `decay` implementate secondo
      `data/schema/primitives.json` (tutti i parametri dichiarati, `bersaglio`
      incluso)
- [ ] `dot` e `decay` usano la lista di effetti a tempo di `AbilityEngine`
      (`tick_effects`), non `await`
- [ ] `aura` è un effetto persistente attaccato al caster, rimosso quando il
      caster non è più valido
- [ ] `shield` assorbe danno prima degli hp e si esaurisce/scade
- [ ] Nessuna primitiva fuori dal registro; parametri non nel registro →
      errore del motore (comportamento di US-022)
- [ ] Test headless per ognuna
- [ ] Il typecheck/lint passa

### US-203: Primitive del Twilight Giant — parte 2 (`debuff_stat`, `light_purify`, `transform`, `terrain_modify`)

**Descrizione:** Come sviluppatore, voglio implementare le primitive di
alterazione e di terreno del Twilight Giant.

**Criteri di accettazione:**
- [ ] `debuff_stat` (speculare a `buff_stat` di US-013, modificatori per id),
      `light_purify` (rimuove effetti per tag), `transform` (cambio di stato
      con `stat_modifiers` temporanei e trade-off, es. `tg_postura_inviolabile`
      difesa +70% / velocità −50%), `terrain_modify`
- [ ] `terrain_modify` con `permanente: true` scrive nello stato del mondo del
      save (varco aperto per sempre, criterio di `design-world.md` cap. 4);
      con `permanente: false` è temporaneo
- [ ] `transform` è reversibile e si annulla alla scadenza o su richiesta
- [ ] Con queste, il conteggio delle primitive implementate arriva a ~13-15/28
- [ ] Test headless per ognuna, incluso il trade-off di `transform` e la
      persistenza di `terrain_modify`
- [ ] Il typecheck/lint passa

### US-204: `AbilityEngine` esegue un'abilità non posseduta

**Descrizione:** Come sviluppatore, voglio che il motore possa eseguire un
`ability_id` che non appartiene al Pathway del giocatore, con una durata di
prestito e una scadenza — capacità richiesta dallo stress test (Error,
Sequenza 6) e costosa se scoperta a fase 5.

**Criteri di accettazione:**
- [ ] `AbilityEngine.grant_temporary(ability_id, caster, durata)` registra
      un'abilità prestata; `execute()` la accetta anche se non è nel Pathway
      del caster
- [ ] Alla scadenza (gestita da `tick_effects`) l'abilità prestata sparisce;
      `execute()` di un'abilità scaduta → rifiuto gestito, non crash
- [ ] Il prestito è ispezionabile (`granted_abilities(caster)`) per la UI e i test
- [ ] Nessun effetto sul flusso normale di `execute()` per le abilità possedute
- [ ] Test headless: concessione, esecuzione, scadenza, rifiuto dopo scadenza
- [ ] Il typecheck/lint passa

### US-205: Evocazioni persistenti serializzate

**Descrizione:** Come sviluppatore, voglio che `summon` con `durata: -1` crei
entità che sopravvivono al combattimento e al cambio scena, e che il save le
ricostruisca — richiesto da `design-pathways.md` (Death, Paragon) e da
`design-master` cap. 3.1.

**Criteri di accettazione:**
- [ ] Primitiva `summon` implementata; `durata: -1` = entità persistente con
      `entita_id` che dichiara la fonte (cadavere/costrutto/pet/chimera)
- [ ] Le evocazioni persistenti sono in un registro centrale
      (`SummonRegistry` o simile), non figlie della scena di combattimento
- [ ] Il save serializza `evocazioni[]` (lo slot esiste già da US-015):
      `{entita_id, tipo, posizione, hp}`; al load le entità sono ricreate
- [ ] Un'evocazione la cui fonte non è più valida non viene ricreata (errore
      gestito, non crash)
- [ ] Test headless: summon persistente, round-trip del save, ricreazione,
      fonte mancante
- [ ] Il typecheck/lint passa

### US-206: Hook `stored_ability_id` nel motore

**Descrizione:** Come sviluppatore, voglio che il motore sappia eseguire
un'abilità "portata da un oggetto" al consumo, così che il sistema inventario
di fase 3 ci si agganci senza riscrivere `AbilityEngine`.

**Criteri di accettazione:**
- [ ] `AbilityEngine.execute_stored(stored_ability_id, consumer)` esegue
      l'abilità come se il consumer la possedesse, una volta sola, senza
      costo di spiritualità (l'oggetto è già il costo)
- [ ] Riusa `grant_temporary` di US-204 internamente dove ha senso, o è un
      percorso parallelo documentato
- [ ] Nessun sistema inventario in questa story: solo l'API e un test che la
      esercita con un `ability_id` finto
- [ ] Test headless: esecuzione stored, singolo uso, `ability_id` ignoto → errore gestito
- [ ] Il typecheck/lint passa

## Blocco B — Caratteristiche Beyonder e pozioni

### US-207: Caratteristica Beyonder come oggetto

**Descrizione:** Come giocatore, voglio raccogliere le Caratteristiche
Beyonder che i nemici lasciano, così da poterle usare per avanzare.

**Criteri di accettazione:**
- [ ] `data/schema/characteristic.schema.json` + `data/characteristics.json`
      (o generazione dai dati di Pathway): entità con `id`, `pathway_id`,
      `sequence`, `name_i18n`
- [ ] Un nemico Beyonder alla morte può rilasciare una Caratteristica
      (probabilità e Sequenza da `balance.json` / dal nemico); la Caratteristica
      diventa una entità raccoglibile a terra
- [ ] Raccolta → la Caratteristica entra in uno store del giocatore
      (`characteristics_held[]`), serializzato nel save con `typeof()`
- [ ] Nessun nome hardcoded; il validator verifica `pathway_id` e `sequence`
      contro i dati di Pathway
- [ ] Test headless: drop, raccolta, persistenza nel save
- [ ] Verifica a schermo documentata in `progress.txt`

### US-208: Formule delle pozioni e formule parziali

**Descrizione:** Come sviluppatore, voglio il sistema di formule delle pozioni,
comprese le formule parziali (una pozione fatta con 3 ingredienti su 5).

**Criteri di accettazione:**
- [ ] `data/potions/formulas.json` + schema: ogni `formula_id` (già referenziato
      da `twilight_giant.json`, es. `formula_twilight_giant_5`) elenca
      `characteristic_sequence`, `ingredients[]` completi, e la soglia minima
      di ingredienti per una formula **parziale**
- [ ] Una formula parziale (3/5 ingredienti) produce una pozione con effetto
      collaterale/qualità ridotta esplicito nei dati (mai un valore silenzioso)
- [ ] Il validator: ogni `potion.formula_id` delle Sequenze non-stub risolve;
      ogni `ingredient` è un id noto; `characteristic_sequence` coerente con
      la Sequenza della pozione
- [ ] Test headless: formula completa vs parziale, formula inesistente → errore
- [ ] Il typecheck/lint passa

### US-209: Concoction — preparare e bere la pozione

**Descrizione:** Come giocatore, voglio combinare una Caratteristica con gli
ingredienti per creare la pozione della Sequenza successiva e berla per
avanzare.

**Criteri di accettazione:**
- [ ] `PotionSystem.concoct(formula_id, characteristic, ingredienti[])` →
      pozione (completa o parziale), consumando Caratteristica e ingredienti
- [ ] Bere la pozione della Sequenza `N-1` mentre si è a Sequenza `N`:
      se `acting_progress` è a 1.0 (US-212), avanza; altrimenti la pozione è
      "digerita male" — foundation giù, follia su (`madness_on_force` della
      Sequenza), nessun avanzamento
- [ ] L'avanzamento aggiorna `ProgressionComponent`, riapplica gli
      `stat_modifiers`, resetta `acting_progress`, emette `sequence_changed`
- [ ] La pozione parziale ha una penalità (follia extra o effetto collaterale
      dai dati)
- [ ] Test headless: concoct completa → avanzamento con acting pieno; concoct
      con acting incompleto → forzatura; pozione parziale → penalità
- [ ] Verifica a schermo documentata in `progress.txt`

## Blocco C — Acting Method

### US-210: EventTracker generico

**Descrizione:** Come sviluppatore, voglio un unico sistema che conti gli
eventi di gioco filtrati, così che le azioni di recitazione siano contatori
sui 12 eventi tracciati e non 40 rilevatori speciali.

**Criteri di accettazione:**
- [ ] Autoload `EventTracker`: `emit_event(nome, dati)` dove `nome` ∈
      `data/schema/tracked_events.json` (vocabolario chiuso di 12); un evento
      fuori vocabolario → `push_error`, non crash
- [ ] Contatori con filtri: `count(evento, filtri)` applica i filtri ammessi
      per quell'evento (già dichiarati nello schema, es. `tag_danno`,
      `senza_abilita`, `sequenza_bersaglio_max`)
- [ ] I sistemi di combattimento di fase 1 emettono gli eventi rilevanti
      (`enemy_defeated`, `damage_dealt`, `perfect_parry`, `dodge`, …) — un
      adattamento minimo, non una riscrittura
- [ ] I contatori sono serializzati nel save (servono all'Acting persistente)
- [ ] Test headless: emissione, filtri, evento fuori vocabolario, persistenza
- [ ] Il typecheck/lint passa

### US-211: Acting Method — barra `acting_progress`

**Descrizione:** Come giocatore, voglio che recitare il ruolo del mio Pathway
(sconfiggere nemici in duello puro, infliggere danni fisici, ...) riempia la
barra di recitazione della Sequenza corrente.

**Criteri di accettazione:**
- [ ] `ActingComponent` legge le `acting_actions` della Sequenza corrente da
      `ProgressionComponent`, e per ognuna calcola il progresso come
      `min(1.0, EventTracker.count(...) / target) * progresso_dichiarato`
      (ripetibile o una tantum secondo il dato)
- [ ] `acting_progress` totale = somma dei contributi, cap a 1.0
- [ ] Decadimento per azioni incoerenti: usare un'abilità Beyonder mentre si
      recita "duello puro" sottrae `decadimento_azione_incoerente`
      (`balance.json.acting`)
- [ ] Segnale `acting_progress_changed(valore)`; il progresso persiste nel save
- [ ] All'avanzamento di Sequenza, `acting_progress` si azzera e riparte sulle
      `acting_actions` della nuova Sequenza
- [ ] Test headless: accumulo da eventi, cap a 1.0, decadimento, reset su avanzamento
- [ ] Il typecheck/lint passa

### US-212: Blocco dell'avanzamento sotto `acting_progress` 1.0

**Descrizione:** Come designer, voglio che non si possa avanzare di Sequenza
finché la recitazione non è completa, e che forzare abbia un costo pesante.

**Criteri di accettazione:**
- [ ] `PotionSystem.concoct` + bere: con `acting_progress` < 1.0 l'avanzamento
      **non** avviene per via normale
- [ ] Forzare (bere comunque) è possibile e applica: `foundation +=
      malus_avanzamento_forzato`, `follia += madness_on_force` della Sequenza,
      e l'avanzamento avviene con fondamenta degradate
- [ ] `foundation` non scende sotto `minimo` (0); a `foundation` bassa il
      moltiplicatore di follia sale (`moltiplicatore_follia_a_fondamenta_zero`)
- [ ] La UI (HUD) mostra se l'avanzamento è disponibile o forzato
- [ ] Test headless: avanzamento bloccato, forzatura con malus corretti,
      floor di foundation
- [ ] Verifica a schermo documentata in `progress.txt`

## Blocco D — Follia

### US-213: Follia — statistica cumulativa con effetti a soglia

**Descrizione:** Come giocatore, voglio che la follia si accumuli da più
sorgenti e produca effetti meccanici alle soglie di `balance.json`.

**Criteri di accettazione:**
- [ ] `MadnessComponent`: valore 0→100, `add(quantità, sorgente)` con log
      della sorgente; non si azzera mai del tutto (`riduzione_max_ancore` è un
      cap sulla riduzione, non un reset)
- [ ] Sorgenti di fase 2: avanzamento forzato, sacrificio di un'Ancora,
      pozione parziale, permanenza nel mondo spirituale (gancio, anche se il
      luogo arriva dopo)
- [ ] Effetti a soglia da `balance.json.madness`: 15 distorsioni, 40 abilità
      autonome (probabilità `probabilita_attivazione_autonoma_sotto_soglia`),
      70 perdita di input intermittente, 100 stato mostro / game over per follia
- [ ] `decadimento_naturale_al_minuto` (oggi 0) rispettato come dato
- [ ] Segnale `madness_changed(valore, soglia_attraversata)`
- [ ] Serializzato nel save
- [ ] Test headless: accumulo, soglie, cap della riduzione, abilità autonoma
      sotto soglia 40
- [ ] Il typecheck/lint passa

### US-214: Layer audio della follia

**Descrizione:** Come giocatore, voglio sentire la follia prima di vederla:
sussurri che crescono sul bus dedicato.

**Criteri di accettazione:**
- [ ] `AudioManager` legge `audio.json.madness_layer`: 4 soglie
      (`amb_whisper_faint/words/names/chorus`) con `volume_db` e `detune`
      crescenti, sul bus `whisper` (già creato in US-019)
- [ ] Il volume del bus `whisper` è guidato dalla follia, non fisso
- [ ] Soglia 80: `duck_music_db` abbassa la musica come dichiarato nei dati
- [ ] One-shot casuali sopra follia 25: intervallo random in
      `intervallo_secondi`, sfx da `one_shot_casuali.sfx`
- [ ] I sussurri di soglia 55 usano i nomi degli NPC incontrati e delle Ancore
      (gancio: se non ce ne sono, fallback a un set generico)
- [ ] `disattiva_sussurri` silenzia il bus `whisper` **senza** toccare la
      meccanica (la follia continua a salire e a fare danno)
- [ ] Placeholder audio sintetizzati come in US-019 (non file)
- [ ] Verifica a schermo/orecchio documentata in `progress.txt`

### US-215: Effetti visivi della follia

**Descrizione:** Come giocatore, voglio che la follia si veda a schermo, in
modo leggibile e disattivabile per fotosensibilità.

**Criteri di accettazione:**
- [ ] Un overlay HUD (fuori dal libro) legge le soglie da `balance.json.madness`
      e da `design-vfx.md` cap. 5: 15 bordi che "respirano d'inchiostro",
      40 distorsioni che toccano gli sprite (un frame con tratto sbagliato),
      70 il nero di scena si attiva da solo
- [ ] Con `riduci_flash` / `disattiva_sussurri` la versione ridotta è statica
      (vignetta fissa), mai assente (FR-8: la follia resta leggibile)
- [ ] Gli effetti sono guidati dai dati (soglie e parametri), non da numeri
      negli script
- [ ] Nessuna informazione vive **solo** nel canale visivo o **solo** in quello
      audio
- [ ] Verifica a schermo documentata in `progress.txt`

## Blocco E — Ancore

### US-216: Ancore — registrazione, riduzione della follia, distruttibilità

**Descrizione:** Come giocatore, voglio Ancore (legami che mi tengono umano)
che riducono la follia, e la cui perdita è un colpo.

**Criteri di accettazione:**
- [ ] `data/anchors.json` + schema: entità con `id` (`anchor_mirco`, …),
      `name_i18n`, `forza` (contributo alla riduzione)
- [ ] `AnchorSystem`: `register(anchor_id)`, `destroy(anchor_id)`, `active()`;
      la riduzione totale della follia è la somma delle forze, **cappata** a
      `riduzione_max_ancore` (0.60) del valore di follia
- [ ] `destroy` emette `anchor_lost(anchor_id)` che aggiunge follia
      (`MadnessComponent.add` con sorgente `"anchor_lost"`)
- [ ] Le Ancore attive sono serializzate nel save
- [ ] Un'Ancora è referenziabile da: un NPC (`design-npc-quest`), un sacrificio
      rituale (`ancora_del_giocatore` in `twilight_giant.json` Seq 1), i
      sussurri di soglia 55 (US-214). Il validator verifica i riferimenti
      incrociati che esistono già nei dati
- [ ] Test headless: registrazione, riduzione cappata, distruzione → follia,
      persistenza
- [ ] Il typecheck/lint passa

## Blocco F — Rituale di avanzamento

### US-217: Motore del rituale di avanzamento

**Descrizione:** Come giocatore, alle Sequenze alte l'avanzamento non è una
pozione: è un rituale con luogo, momento, sacrifici e sigilli, che si può
interrompere.

**Criteri di accettazione:**
- [ ] `RitualSystem` legge `advancement_ritual` della Sequenza (formato già in
      `twilight_giant.json`: `location_tags`, `momento`, `fase_lunare`,
      `sacrifices[]`, `sigils[]`)
- [ ] Un rituale richiede: essere in un luogo con i `location_tags` giusti
      (gancio: finché non c'è il mondo di fase 6, i tag si simulano/forzano in
      debug), il `momento`/`fase_lunare` giusti (gancio al `time.json`), i
      sacrifici disponibili (una struttura, un'Ancora, …), i sigilli posseduti
- [ ] Fase di build di ~45s (dato); **interruzione** (danno, movimento fuori
      area) → il rituale fallisce, taglio audio secco al silenzio
      (`audio.json.music.rituale.su_interruzione`), penalità di follia
- [ ] Rituale completato → avanzamento come US-209 (richiede comunque
      `acting_progress` 1.0)
- [ ] Il sacrificio di un'Ancora (Seq 1 del TG) passa da `AnchorSystem.destroy`
- [ ] Test headless: prerequisiti mancanti bloccano; interruzione fallisce con
      penalità; completamento avanza
- [ ] Verifica a schermo documentata in `progress.txt`

## Blocco G — Percezione per Sequenza

### US-218: Percezione per Sequenza

**Descrizione:** Come giocatore, salendo di Sequenza voglio *sentire* e
*vedere* cose che prima non c'erano: è il radar dell'esplorazione.

**Criteri di accettazione:**
- [ ] `PerceptionSystem` legge `audio.json.sequence_perception` per la Sequenza
      corrente: attiva i `layers` ambientali e abilita i `reveal`
      (`spiriti_vicini`, `densita_mistica`, `segreti_adiacenti`, …)
- [ ] Ogni `reveal` ha l'equivalente visivo (FR-8, `design-vfx.md` cap. 5):
      `spiriti_vicini` = sagome oltre i muri all'accento della palette del
      loro Pathway; `densita_mistica` = grana d'inchiostro nell'aria
- [ ] La percezione si potenzia scendendo di Sequenza (più layer, più reveal):
      è cumulativa, guidata dal dato
- [ ] Nessun numero di Sequenza hardcoded: si legge la voce corrispondente o
      la più vicina inferiore
- [ ] Test headless: layer/reveal attivi per Sequenza, cumulatività
- [ ] Verifica a schermo documentata in `progress.txt`

## Blocco H — Il gold standard esegue

### US-219: Twilight Giant eseguito end-to-end dal motore

**Descrizione:** Come sviluppatore, voglio la prova che l'architettura regge:
il Twilight Giant, dalla Sequenza 9 alla 5, giocato con dati e zero codice
dedicato.

**Criteri di accettazione:**
- [ ] Un test headless "vertical slice" parte da Sequenza 9 del Twilight Giant
      e arriva a Sequenza 5 in codice, esercitando: raccolta Caratteristica →
      concoct → acting completo via `EventTracker` → bere → avanzamento, per
      ogni salto 9→8→7→6→5
- [ ] Tutte le abilità del Twilight Giant delle Sequenze 9-5 si eseguono senza
      warning "primitiva non implementata" né "fuori registro"
- [ ] `grep` di `scripts/` per `twilight_giant` / nomi di Sequenza: **zero
      occorrenze** (nessun `if` per il Pathway) — assertito da un test o dalla CI
- [ ] Gli `stat_modifiers`, i `madness_on_force`, gli `acting_actions` di ogni
      Sequenza attraversata producono l'effetto dichiarato nei dati
- [ ] `progress.txt` documenta l'esito: **l'architettura regge / va corretta**,
      con il dettaglio di cosa ha richiesto codice se qualcosa l'ha richiesto
- [ ] Il typecheck/lint passa

## Blocco I — UI a libro, VFX, i18n

### US-220: i18n reale (R-12)

**Descrizione:** Come sviluppatore, voglio che le ~250 chiavi `*_i18n` sparse
nei dati puntino a stringhe vere e che il validator becchi quelle rotte.

**Criteri di accettazione:**
- [ ] `tools/generate_i18n_stubs.py`: scandisce `data/` per ogni chiave
      `*_i18n` / `name_i18n` / `descrizione_i18n` e genera/aggiorna
      `data/i18n/it.json` con lo stub mancante (valore = la chiave, marcato da
      rivedere)
- [ ] Le tre convenzioni di naming divergenti sono unificate in una
      (documentata in `CLAUDE.md`)
- [ ] `data/i18n/it.json` (+ `en.json` incompleto) caricato da `GameData`;
      `tr_data(key)` come API
- [ ] Il validator: ogni chiave `*_i18n` referenziata nei dati esiste in
      `it.json` (errore se manca)
- [ ] I `.translation` compilati di fase 1 (HUD) restano; questo sistema è per
      le stringhe **dei dati**, non per la UI di Godot — o si unificano, e
      allora lo si documenta
- [ ] Test headless: chiave presente traduce, chiave mancante segnalata dal validator
- [ ] Il typecheck/lint passa

### US-221: Shell del libro — parte 1: controller e dati

**Descrizione:** Come giocatore, voglio aprire un libro che ferma il mondo e
sfogliarne le pagine; come sviluppatore, voglio che le pagine siano un dato.

**Criteri di accettazione:**
- [ ] `data/ui/book.json` + `data/schema/book.schema.json` come da
      `design-ui-libro.md` cap. 4: `libro` (voltata_ms, sfx, macchie_follia),
      `pages[]` (id, tipo, name_i18n, ordine, sbloccata_da, flag), `segnalibri[]`
- [ ] Vocabolario chiuso degli 8 `tipo` di pagina in
      `data/schema/page_types.json` (o dentro lo schema)
- [ ] `BookController`: apre/chiude (stesso input), ferma il mondo (`get_tree().paused`
      o equivalente che non blocca la UI), si apre sull'ultima pagina consultata
- [ ] Le pagine non sbloccate per la fase corrente **esistono ma sono bianche**
      (un appunto a matita), non assenti
- [ ] Il validator: `tipo` nel vocabolario; `id`/`ordine` unici; segnalibri →
      pagine esistenti; chiavi i18n esistenti (con US-220)
- [ ] Test headless: caricamento di `book.json`, pagine bianche vs sbloccate,
      il mondo è in pausa mentre il libro è aperto
- [ ] Il typecheck/lint passa

### US-222: Shell del libro — parte 2: voltata e navigazione

**Descrizione:** Come giocatore, voglio che cambiare pagina volti la pagina,
con un'animazione, e che i segnalibri portino diretto alle pagine frequenti.

**Criteri di accettazione:**
- [ ] Animazione di voltata 2D placeholder (3-4 frame di curvatura + ombra
      sulla piega); durata = `voltata_ms` dai dati
- [ ] Input: pagina avanti/indietro (Q/E o dorsali), segnalibri diretti,
      chiusura con il tasto d'apertura
- [ ] `sfx_ui_page` (voltata) e `sfx_ui_book_open` (apertura) sul bus `ui`
- [ ] Con `riduci_animazioni` la voltata diventa una dissolvenza di
      `dissolvenza_ridotta_ms`; nessuna informazione vive solo nell'animazione
- [ ] Verifica a schermo documentata in `progress.txt`

### US-223: Pagina scaffale (menu principale) e frontespizio (creazione personaggio)

**Descrizione:** Come giocatore, voglio scegliere il tomo da aprire (slot di
salvataggio) e, per una partita nuova, scrivere il mio nome sul frontespizio.

**Criteri di accettazione:**
- [ ] Pagina `menu_principale`: gli slot di `SaveSystem` come tomi su uno
      scaffale; tomo vuoto = nuova partita; aprire un tomo = caricare
- [ ] Un save corrotto (US-015, stato `CORROTTO`) appare come tomo **bruciato**:
      leggibile come danno, mai crash, mai cancellazione silenziosa
- [ ] Pagina `creazione_personaggio`: campo nome con "Enel" già scritto (default
      di `design-lore`, non placeholder); conferma con la prima voltata; il
      nome finisce nel save (`nome_personaggio`, già serializzato da US-015)
- [ ] In seguito la stessa pagina mostra chi sei (Pathway, Sequenza, titolo)
- [ ] Tutte le stringhe da chiavi i18n
- [ ] Verifica a schermo documentata in `progress.txt`

### US-224: Pagina diagramma dei Pathway con fog of war

**Descrizione:** Come giocatore, voglio vedere l'albero delle Sequenze dei
Pathway, ma solo per quanto ne so — è la promessa della roadmap di fase 2.

**Criteri di accettazione:**
- [ ] Pagina `diagramma_pathway`: le 10 colonne di Sequenze (id e chiavi i18n,
      **nessun nome hardcoded**), 10 righe per le Sequenze 9→0
- [ ] Fog of war sulla conoscenza: si vede solo ciò che è stato letto/scoperto
      (flag di conoscenza `design-master` cap. 5); il resto è offuscato
- [ ] La Sequenza corrente del giocatore è evidenziata; le abilità di quella
      Sequenza sono elencate
- [ ] Il diagramma è generato dai dati di Pathway, non disegnato a mano
- [ ] Verifica a schermo documentata in `progress.txt`

### US-225: Pagina colophon (impostazioni) e `user://settings.json`

**Descrizione:** Come giocatore, voglio una pagina impostazioni per audio,
video, input e lingua, che persista.

**Criteri di accettazione:**
- [ ] Pagina `impostazioni` con: **Audio** (volumi per bus; `sottotitoli_effetti`,
      `indicatore_visivo_tell`, `indicatore_direzione_suono`, `disattiva_sussurri`),
      **Video** (scala finestra ×1/×2/×3, fullscreen, `disattiva_shake`,
      `riduci_hitstop`, `riduci_distorsione`, `riduci_flash`, `riduci_animazioni`,
      macchie di follia on/off), **Input** (rimappatura tasti + supporto
      controller con rimappatura — chiude la domanda aperta di fase 1),
      **Lingua** (it/en)
- [ ] Ogni opzione scrive `user://settings.json` con lo stesso rigore del save:
      scrittura atomica, `typeof()` al load, un file corrotto non è fatale
- [ ] Le opzioni applicate a runtime senza riavvio dove possibile (volumi,
      scala finestra, lingua, toggle di accessibilità)
- [ ] `AudioManager` e i sistemi VFX leggono da qui invece che dai default di
      `audio.json`/`vfx.json`
- [ ] Verifica a schermo documentata in `progress.txt`

### US-226: `data/vfx.json` — palette visive e schema

**Descrizione:** Come sviluppatore, voglio il gemello visivo di
`audio.json.pathway_palette`: 10 palette a 3 colori, una per Pathway.

**Criteri di accettazione:**
- [ ] `data/vfx.json` + `data/schema/vfx.schema.json` come da `design-vfx.md`
      cap. 4: `pathway_palette_visiva` (inchiostro/primario/accento/tratto/
      scia/distorsione), `primitive_vfx`, `impact_frames`, `nero_di_scena`,
      `accessibilita`
- [ ] Vocabolario chiuso dei `tratto` (10 voci, uno per Pathway)
- [ ] `GameData` carica `vfx.json`; `get_vfx_palette(pathway_id)`,
      `get_primitive_vfx(tipo)`
- [ ] Il validator: palette per ogni Pathway attivo (come il check audio);
      `tratto` nel vocabolario; colori `#rrggbb`; ogni primitiva **implementata**
      ha una voce in `primitive_vfx`
- [ ] Nessun campo VFX sulle abilità (`ability.schema.json` non si tocca)
- [ ] Test headless: caricamento, lookup, validator
- [ ] Il typecheck/lint passa

### US-227: VFX delle primitive di fase 2 con impact frame

**Descrizione:** Come giocatore, voglio che le abilità abbiano un aspetto —
inchiostro pesante, un colore di Pathway, l'impact frame sul colpo che conta.

**Criteri di accettazione:**
- [ ] Un renderer di VFX per primitiva: legge `primitive_vfx[tipo]` +
      `pathway_palette_visiva[pathway del caster]`, riproduce lo sprite
      placeholder parametrato (inchiostro/primario/accento)
- [ ] Aggancio al timing esistente: il VFX parte sull'evento `ability_release`
      di `animations.json`
- [ ] Impact frame a inversione bianco/nero, `durata_frames` agganciata a
      `combat_feedback.hitstop_ms` di `audio.json` (si tarano insieme)
- [ ] `nero_di_scena` sui trigger dichiarati (`parry_perfect`, `posture_break`,
      abilità di Sequenza ≤ 4)
- [ ] `riduci_distorsione` e `riduci_flash` rispettati (l'impact frame diventa
      un bordo spesso: stessa informazione, niente lampo)
- [ ] Copre le primitive implementate fino a US-203 (~13-15); le altre man mano
- [ ] Verifica a schermo documentata in `progress.txt`

## Blocco J — Debito di contenuto

### US-228: Riscrittura dati di `darkness_1` senza `probability_shift`

**Descrizione:** Come designer, voglio che `darkness_1` (l'unica abilità
non-stub fuori dal Twilight Giant) non dipenda da una primitiva differita.

**Criteri di accettazione:**
- [ ] `darkness_1` riscritta con primitive **attive**: `curse` (effetto
      `sfortuna`, `condizione_rimozione`) + stack di `debuff_stat` su
      evasione/precisione + `dot` basso a tag `follia` (`design-master` cap. 4)
- [ ] Il risultato percepito ("sfortuna cronica: i nemici falliscono,
      inciampano, si feriscono da soli") è documentato nelle `notes`
- [ ] `probability_shift` resta differita nel registro; il validator continua
      a rifiutare un'abilità che la usi
- [ ] `curse` implementata se non lo è già (registro chiuso, parametri validati)
- [ ] Il validator esce 0; nessuna abilità attiva usa una primitiva differita
- [ ] Test headless: `darkness_1` si esegue componendo le primitive attive

### US-229: Macchie di follia sulle pagine del libro (P2)

**Descrizione:** Come giocatore, voglio che la follia macchi anche il libro:
bordi delle pagine più scuri, note a margine in una grafia non mia.

**Criteri di accettazione:**
- [ ] Sopra le soglie di `balance.json.madness`, il `BookController` scurisce
      i bordi delle pagine e mostra note a margine (i sussurri in forma scritta
      — FR-8, equivalente visivo del canale audio di US-214)
- [ ] Con `disattiva_sussurri` / `riduci_animazioni` (o il toggle dedicato
      "macchie di follia") le macchie si congelano a uno stato neutro; la
      meccanica non cambia
- [ ] `macchie_follia` in `data/ui/book.json` come interruttore dei dati
- [ ] Verifica a schermo documentata in `progress.txt`

---

## Requisiti funzionali

- FR-1: Nessun nome di Pathway o Sequenza hardcoded in script o scene — solo
  `pathway_id` e chiavi i18n (il flag `SERIAL_NUMBERS_FILED_OFF` deve poter
  rinominare tutto sostituendo dati)
- FR-2: Nessuna primitiva fuori dal registro chiuso; nessuna abilità attiva
  usa una primitiva `deferred`
- FR-3: Ogni sistema nuovo è un file di dati + uno schema + un check del
  validator, mai una classe speciale
- FR-4: Ogni campo nuovo del save passa da `typeof()` con default sano e ha
  una migrazione dalla versione precedente
- FR-5: Ogni azione di recitazione è un contatore su un evento di
  `tracked_events.json` con filtri ammessi — mai un rilevatore dedicato
- FR-6: L'avanzamento di Sequenza è impossibile con `acting_progress` < 1.0
  per via normale; forzarlo costa foundation e follia
- FR-7: Ogni informazione veicolata dall'audio (sussurri, tell, percezione)
  ha un equivalente visivo attivabile; e viceversa
- FR-8: L'identità di un Pathway viaggia su tre canali con la stessa chiave:
  timbrica (`audio.json`), visiva (`vfx.json`), e — da fase 6 — spaziale
- FR-9: Il Twilight Giant si esegue dalla Sequenza 9 alla 5 con zero righe di
  codice che lo nominino
- FR-10: Aprire il libro ferma il mondo (pausa vera); il ciclo giorno/notte
  non scorre tra le pagine

## Non-goals di questa fase

- Nessun Pathway implementato oltre il Twilight Giant (Death, Moon, Mother,
  ecc. restano stub — sono fase 5)
- Nessun sistema di inventario, crafting, pet, costruzione, talento (fase 3):
  solo gli **hook** (`stored_ability_id`, evocazioni serializzabili)
- Nessun contenuto di mondo: regioni, NPC, dialoghi, quest (fase 6). I
  `location_tags` dei rituali si simulano in debug
- Nessuna sinergia risolta a runtime (fase 4)
- Nessun cambio di Pathway / fusione (fase 7)
- Nessuna pagina del libro oltre le quattro di fase 2 (mappa, inventario,
  sinergie, journal restano bianche)
- Nessuna arte definitiva, nessuna musica composta: placeholder diagnostici e
  sfx sintetizzati, come in fase 1
- Nessun bilanciamento fine: i numeri di `balance.json` restano "plausibili,
  non bilanciati" — il playtest vero è dopo la fase 2

## Metriche di successo

- Il Twilight Giant va da Sequenza 9 a 5 in un test headless, e `grep -r
  twilight_giant scripts/` non trova nulla
- Cambiare `madness_on_force` o una `acting_action` in un JSON e vederne
  l'effetto dopo F5, senza riavvio
- La suite headless resta sotto i ~60 secondi
- Aprire il libro, sfogliare fino al colophon, cambiare la scala finestra e
  la lingua, chiudere: tutto persiste dopo un riavvio
- Un secondo Pathway (anche solo abbozzato in un file di prova) si esegue
  senza aggiungere codice: la prova che la fase 5 sarà lavoro di dati

## Considerazioni tecniche

- **Save schema_version** sale almeno di 1 (progressione) e possibilmente più
  volte durante la fase (acting, follia, ancore, evocazioni). Ogni incremento
  ha la sua funzione di migrazione. Meglio molti step piccoli che uno grande
- **`get_tree().paused`** per il libro: gli autoload che devono continuare
  (input della UI) vanno in `PROCESS_MODE_ALWAYS`; il resto si ferma
- **EventTracker** va inserito con un adattamento minimo ai sistemi di fase 1:
  `enemy.gd` emette `enemy_defeated`, `hurtbox.gd` emette `damage_dealt` /
  `perfect_parry`, `player.gd` emette `dodge`. Non riscrivere, agganciare
- **Percezione "attraverso i muri"**: in Godot, un secondo `CanvasLayer` con
  le sagome disegnate su `VisibleOnScreenNotifier` o un raycast leggero — non
  serve nulla di sofisticato per il placeholder
- **`transform` e `stat_modifiers` temporanei** riusano i modificatori per id
  di US-007: l'id è `"transform:<ability_id>"`, si rimuove alla scadenza come
  un buff

## Ordine di lavoro consigliato

1. **A** (progressione + primitive + capacità motore) — sblocca tutto il resto
2. **C** (EventTracker + Acting) e **B** (pozioni) in parallelo concettuale
3. **D** (follia) → **E** (ancore) → **F** (rituale): si mordono a vicenda, in
   quest'ordine
4. **G** (percezione) — indipendente, può slittare
5. **H** (US-219) — il verdetto sull'architettura. Se fallisce, **fermarsi** e
   correggere prima di I/J
6. **I** (libro, VFX, i18n) — grande ma parallelizzabile; US-220 (i18n) prima
   delle pagine
7. **J** — US-228 appena `curse`/`debuff_stat`/`dot` esistono (dopo US-202/203);
   US-229 dopo la shell del libro

## Domande aperte

- Le Caratteristiche Beyonder: drop garantito dai Beyonder o probabilistico?
  (propendere per garantito a bassa Sequenza, raro ad alta — ma va provato)
- Il decadimento della follia (`decadimento_naturale_al_minuto` oggi 0): resta
  0 per tutta la fase 2, o si introduce un decadimento lento fuori dai
  combattimenti? Decisione da playtest
- La pagina diagramma Pathway mostra le abilità con i loro effetti, o solo i
  nomi finché non sono state usate/sbloccate? (fog of war più o meno stretto)
- Il libro in pausa: anche durante un rituale di avanzamento? (probabilmente
  no — il rituale è un momento di gioco attivo, interrompibile)
- `settings.json` e il save nello stesso `user://` o `settings.json` globale
  e i save per-profilo? (fase 2 non ha profili multipli: globale va bene)
