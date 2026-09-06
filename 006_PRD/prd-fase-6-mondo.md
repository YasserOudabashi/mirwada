# PRD: Fase 6 — Mondo (regioni, tempo, Darkness, NPC, dialoghi, quest, fazioni)

## 1. Introduzione / Overview

Fino alla fase 5 Mirwada è un motore senza un posto in cui girare: 21 Pathway
attivi su 22, ogni sistema di supporto e ogni sinergia funzionano, ma non c'è
un mondo. Il giocatore avanza di Sequenza in una scena di test.

La fase 6 costruisce il **mondo diegetico**: cinque regioni disegnate a mano
(una per gruppo di Pathway + la città neutra), il **ciclo giorno/notte e
lunare** che fa valere le condizioni `e_notte`/`fase_lunare` già scritte nei
dati, il **gating** che rende l'esplorazione un privilegio, gli **8 NPC** con
i loro dialoghi, il **motore delle quest** (un lettore di `EventTracker` e
flag, la stessa architettura della recitazione), le **fazioni** e la
reputazione, la **pagina mappa** del libro.

E chiude la **fase 5b per il gruppo eternal_darkness**: le nove Sequenze
rimaste di **Darkness** (`darkness_1` già fatta in US-503) vanno qui, subito
dopo il ciclo giorno/notte — il loro concept ("statistiche raddoppiate al
buio", "oscurità creabile", incubi) lo richiede.

Vincoli ereditati (non-goals di progetto): **niente open world senza gating,
niente generazione procedurale del mondo, niente doppiaggio**. Le regioni sono
4-6, disegnate a mano; l'audio è un canale informativo con un sistema
data-driven, ma **i file audio non li produce questo lavoro** (serve un
musicista o stem CC0).

Come tutte le fasi: NPC, dialoghi, quest, regioni, fazioni sono **dati**. Il
motore implementa primitive di lettura; i JSON compongono il contenuto. I
vocabolari sono chiusi: aggiungere una voce è una story con motivazione, non
un liberi tutti. `design-world.md` e `design-npc-quest.md` fissano la forma
dei dati; questo PRD la realizza.

---

## 2. Goals

- **`data/world/regions.json` + `region.schema.json` + validator**: le 5
  regioni (Mirwada città, Marche del Crepuscolo, Valle della Madre, Archivio
  Sepolto, Frontiera delle Porte) come dati, ognuna con `location_tags`
  (⊆ vocabolario US-501), `densita_mistica`, `music_zone`, `gating[]`,
  `palette_visiva`, `group_affinity`. Una scena placeholder giocabile per
  regione (tilemap diagnostico, come la zona di test di US-006).
- **`TimeSystem` (autoload)**: `momento ∈ {alba, mezzogiorno, crepuscolo,
  notte_fonda}` che avanza col tempo di gioco; `fase_lunare ∈ {nuova,
  crescente, piena, calante, eclissi}` che avanza su un ciclo lungo;
  `eclissi` come **evento raro schedulato**, non una tappa. Il ciclo **non
  scorre durante i dialoghi e le pagine del libro**. `time_in_state` con
  `stato: notte` tracciabile (Darkness ci recita).
- **Le condizioni delle abilità ora valgono**: `AbilityEngine` verifica
  `e_notte`, `fase_lunare`, `in_zona_tag`, `foundation_min`, `tier_min`,
  `madness_min/max`, `acting_progress_min` prima di eseguire. Le costellazioni
  di Hermit (`hermit_5`) e i rituali lunari di Moon smettono di essere
  decorativi.
- **Darkness completo**: le 9 Sequenze rimaste (9-2) da `stub` a contenuto
  reale + `shadow_meld` (già implementata in fase 5b, US-5B08). Con Darkness,
  **100/100 Sequenze non-stub — tutti e 22 i Pathway attivi completi**.
- **Gating applicato**: il motore del mondo legge `regions.json.gating[]` e
  blocca/apre le aree per `primitiva` / `momento` / `fase_lunare` / `npc` /
  `conoscenza` / `sequenza`. `terrain_modify permanente: true` apre gate
  salvati (già nel `WorldState`).
- **`data/npc/roster.json` + `npc.schema.json` + validator**: gli 8 NPC (Mirco,
  Sidon, Vesna, Aldo, Ottavia, Bruno, Lena, Doran) con `region_id`,
  `faction_id`, `schedule` (nel ciclo del tempo), `vendor`, `dialogue_id`,
  `memoria` (contatore per modo di `npc_influenced`), `anchor_candidate`. Più
  i popolani generici `npc_generic_*` (le acting `tg_6_giuramento` /
  `fool_9_inganno` li contano).
- **Motore dialoghi**: `dialogue.schema.json` + un lettore di grafi a nodi.
  Condizioni dallo STESSO vocabolario delle abilità + 3 voci nuove nell'enum
  (`follia_min`, `reputazione_min`, `flag`). Effetti = vocabolario chiuso di
  ~5 (`emit_event` → solo i 12, `flag`, `reputazione`, `apri_vendita`,
  `avvia_quest`). Un file `dlg_*.json` per NPC. Pagina dialogo nel libro.
- **Motore quest**: `quest.schema.json` + un lettore che osserva `EventTracker`
  e i flag. Ogni step si completa con **un evento dei 12 con filtri** o **un
  flag di dialogo** — zero verbi di quest nuovi. `fallibile: true`
  supportato. Le quest di **Atto I** (tier low): tutorial di Mirco, economia
  di Sidon, Ancore di Lena e Vesna. Journal nel libro.
- **`data/factions.json` + reputazione**: 4 fazioni (`ordine_minore`, `porto`,
  `quartiere`, `giustizia`). Reputazione numerica con soglie; `reputazione`
  come effetto, `reputazione_min` come condizione. Doran è una fazione da un
  uomo solo: il suo "sospetto" sale da sé a ogni uso di potere in città.
- **Pagina mappa del libro** (doppia pagina): le regioni scoperte, i gate
  noti, la posizione. Fast travel = potere (Door `door_5`, Death `death_5`,
  varchi permanenti del TG), mai un menu.
- **Densità mistica**: la percezione per Sequenza (`audio.json.
  sequence_perception`, da Seq 5) rivela `densita_mistica`; influenza recupero
  spiritualità, efficacia rituali, frequenza spawn/segreti. La città è
  volutamente bassa: coltivare richiede uscire.
- **Audio del mondo**: `data/audio.json` esteso con le 4 zone musica nuove
  (`marche`, `valle`, `archivio`, `frontiera`), ambienti sonori per `momento`,
  la struttura della musica a layer (base + stem su tensione/combat/boss) e
  del drone del rituale (build 45 s, taglio secco all'interruzione).
- **Antagonista**: **il detentore precedente della Sequenza 0** del Pathway
  del giocatore (design-npc-quest, raccomandazione #1). È strutturale, già
  nei dati (`il_detentore_precedente_della_sequenza_0` nei sacrifici),
  cambia col Pathway scelto. La fase 6 pianta gli indizi; la rivelazione è
  fase 7.
- Nessuna regressione: i ~570 test di fase 1-5 (+ fase 5b) restano verdi.
- **Save**: fase 6 aggiunge campi (tempo corrente, regione corrente, NPC
  conosciuti + memoria, flag, reputazione, quest attive/completate/fallite,
  gate aperti). **Un** bump di `schema_version` con **una** migrazione
  (`_migra_20_a_21`), la catena da v1 resta verde.

---

## 3. User Stories

Priorità: **P0** blocca il resto; **P1** necessaria; **P2** rifinitura.

### Blocco A — Regioni (P0)

#### US-601: `regions.json` + schema + validator

**Description:** Come sviluppatore, voglio le 5 regioni come dati validati,
così che ogni sistema che parla di "zona" (gating, audio, NPC, spawn) legga
un vocabolario chiuso.

**Acceptance Criteria:**

- [ ] `data/schema/region.schema.json` (`additionalProperties: false`): `id`,
      `name_i18n` (`^region\.`), `group_affinity` (gruppo valido o `"neutra"`),
      `densita_mistica` (0..1), `location_tags` (array), `music_zone`,
      `gating[]` (`{ tipo, valore/primitiva, area }`), `palette_visiva`.
- [ ] `data/world/regions.json`: le 5 regioni di `design-world.md § 2`
      (Mirwada `neutra` densità bassa; Marche `eternal_darkness`; Valle
      `goddess_of_origin`; Archivio `demon_of_knowledge`; Frontiera
      `lord_of_mysteries`). Ogni `location_tags` ⊆ vocabolario di US-501.
- [ ] `tools/validate_data.py`: `location_tags` ⊆ vocabolario; `music_zone`
      esiste in `audio.json`; `gating[].tipo` nel vocabolario dei modi (nuovo
      `data/schema/gate_types.json`, 6 voci); `gating[].primitiva` attiva nel
      registro; `palette_visiva` in `data/vfx.json`; `group_affinity` valido.
- [ ] La regione Marche **ospita tutti gli 8 `location_tags` già usati dai
      rituali del TG** (design-world § 2.2): il validator lo verifica come
      check informativo (ogni `location_tag` di un rituale non-stub è in
      almeno una regione).
- [ ] `006_PRD/design-world.md § 2`: nota che `regions.json` è realizzato.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-602: `WorldState` esteso + regione corrente + scena hub

**Description:** Come giocatore, voglio muovermi in una città vera invece che
in una zona di test.

**Acceptance Criteria:**

- [ ] `WorldState` (già esistente) tiene `regione_corrente` e la lista delle
      regioni **scoperte**; segnale `regione_cambiata(id)`.
- [ ] `scenes/regioni/mirwada.tscn`: la città come tilemap placeholder
      giocabile (biomi interni di `design-world § 2.1`: vicoli/tetti, porto,
      quartiere operaio, archivio), con i `location_tags` marcati su zone
      (Area2D con un tag), la camera coi limiti di zona (US-005), il player.
      Arte placeholder come US-006.
- [ ] `scenes/main.tscn`: carica `mirwada.tscn` invece della zona di test.
- [ ] SAVE: `schema_version` 20 → 21. Campo `mondo` `{ regione: "mirwada",
      scoperte: ["mirwada"], gate_aperti: [] }`. `_migra_20_a_21` (default).
      Catena da v1 verde.
- [ ] Verifica a schermo in `progress.txt`: il player si muove in Mirwada, i
      `location_tags` si leggono entrando nelle zone, la camera si clampa ai
      bordi della regione.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-603: Le 4 regioni a tema come scene placeholder + passaggi fra regioni

**Description:** Come giocatore, voglio uscire dalla città verso le Marche, la
Valle, l'Archivio, la Frontiera.

**Acceptance Criteria:**

- [ ] `scenes/regioni/{marche,valle,archivio,frontiera}.tscn`: 4 tilemap
      placeholder giocabili, con i biomi interni di `design-world § 2` marcati
      e i `location_tags` sulle zone. Densità mistica visiva minima (una
      tinta di sfondo dalla `palette_visiva`).
- [ ] Passaggi fra regioni: un'Area2D "confine" che cambia
      `WorldState.regione_corrente` e carica la scena, aggiungendo la regione
      alle scoperte. I confini **rispettano il gating** (US-611) — finché il
      gating non c'è, sono aperti.
- [ ] La Frontiera è visibile presto ma **respinge chi è sopra Sequenza ~4**
      (gating per `sequenza`): dichiarato nel gating della regione, applicato
      in US-611.
- [ ] Verifica a schermo: si passa da Mirwada a ognuna delle 4 regioni e si
      torna; la mappa del libro (US-616) mostra le scoperte.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco B — Ciclo giorno/notte e lunare (P0)

#### US-604: `TimeSystem` — momento e fase lunare

**Description:** Come giocatore, voglio che il tempo scorra: giorno e notte,
fasi della luna.

**Acceptance Criteria:**

- [ ] `TimeSystem` (autoload): `momento()` avanza `alba → mezzogiorno →
      crepuscolo → notte_fonda` su una durata da `balance.json` (nuova
      sezione `tempo`); `fase_lunare()` avanza su un ciclo lungo (N giorni di
      gioco); `e_notte()` = `crepuscolo` o `notte_fonda`. Segnali
      `momento_cambiato`, `fase_lunare_cambiata`.
- [ ] **`eclissi`**: evento raro schedulato (ogni ~M cicli lunari, o forzabile
      da un rituale di Sequenza alta), non una tappa del ciclo. Segnale
      `eclissi_iniziata`/`finita`.
- [ ] Il ciclo **si ferma** quando il libro è aperto o un dialogo è in corso
      (segnale da `Book` / dal motore dialoghi). `design-ui-libro`: il libro
      ferma il mondo.
- [ ] `time_in_state` (evento già nei 12) emette con `{ stato: "notte" }`
      mentre `e_notte()`: `EventTracker` lo conta (Darkness ci recita —
      `darkness_4` "dominio della notte").
- [ ] SAVE: campo `mondo.tempo` `{ momento, fase_lunare, tick }`. Migrazione
      già fatta in US-602 (o bump qui se US-602 non l'ha incluso — **uno**
      solo in tutta la fase 6).
- [ ] Test headless: il momento avanza col `_process`; `e_notte()` è coerente;
      l'eclissi si schedula; il ciclo non avanza col libro aperto.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-605: `AbilityEngine` verifica le condizioni delle abilità

**Description:** Come giocatore, voglio che la costellazione del Custode
funzioni davvero solo a luna piena, e la furia notturna del Vampiro solo di
notte.

**Acceptance Criteria:**

- [ ] `AbilityEngine.execute`, prima di eseguire, verifica ogni voce di
      `ability.condizioni` contro lo stato di gioco:
      `e_notte` → `TimeSystem.e_notte()`;
      `fase_lunare` → `TimeSystem.fase_lunare()`;
      `in_zona_tag` → `WorldState` / la zona corrente del player;
      `foundation_min` → `Foundation.valore()`;
      `tier_min` → `Progression.tier()`;
      `madness_min`/`madness_max` → `Madness.valore()`;
      `acting_progress_min` → `Acting.acting_progress()`.
      Condizione non soddisfatta → `result.reason = "condizione_non_soddisfatta"`,
      `ok: false`, **nessun costo pagato** (come per spiritualità insufficiente).
- [ ] Un caster **senza** contesto (test isolati, nemici) tratta le condizioni
      come soddisfatte (nessuna restrizione), come già per l'ownership.
- [ ] I 3 nuovi tipi di condizione dei dialoghi (`follia_min`,
      `reputazione_min`, `flag`) entrano nell'enum di `ability.schema.json`
      ma restano **non usati** dalle abilità (documentato): sono per i
      dialoghi (US-613).
- [ ] Test headless: `hermit_costellazione_del_custode` esegue a `fase_lunare
      piena` e viene rifiutata altrimenti, senza pagare spiritualità;
      `moon_furia_notturna` esegue solo di notte; le abilità senza `condizioni`
      non cambiano comportamento.
- [ ] **Regressione attesa**: `test_slice_fase_5.gd` / `test_vertical_slice`
      eseguono abilità in un caster isolato — le condizioni passano. I test
      che eseguono `moon_furia_notturna` / le costellazioni con un player in
      scena vanno aggiornati a impostare `TimeSystem`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione (dopo
      l'aggiornamento dei test). Typecheck passes. Tests pass.

### Blocco C — Darkness (P1, subito dopo il day/night)

#### US-606: Darkness, Sequenze 9-7 (Sleepless → Nightmare)

**Description:** Come giocatore, voglio veglia perpetua e forza al buio,
parole che deprimono i nemici, ed entrare negli incubi infliggendo paura che
disorienta i controlli.

**Acceptance Criteria:**

- [ ] `data/pathways/darkness.json` Seq 9/8/7: `stub` → `false`, contenuto
      pieno. Tier `low`. Seq 9 (Sleepless): `buff_stat` condizionati
      `e_notte` (forza/percezione raddoppiate di notte — dato, ora `AbilityEngine`
      le fa valere).
- [ ] Seq 7 (Nightmare): `fear` (già implementata, US-505) +
      `debuff_stat` su `precisione` + condizione `e_notte`.
- [ ] Nessuna primitiva nuova attesa (fear/debuff/curse/dot già ci sono).
- [ ] Formule + caratteristiche + ingredienti + i18n + test (`tests/test_darkness.gd`)
      + verifica a schermo (di notte le abilità Sleepless si accendono, di
      giorno no).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-607: Darkness, Sequenze 6-4 (Soul Assurer → Nightwatcher) + `shadow_meld` in gioco

**Description:** Come giocatore, voglio pacificare anime e curare il danno
spirituale, ospitare spiriti maligni e scagliarli, e il dominio della notte
con statistiche raddoppiate e oscurità creabile.

**Acceptance Criteria:**

- [ ] Seq 6/5/4 pieni. Seq 4 rituale obbligatorio con `location_tags`
      (`cripta`, `luogo_in_decadenza`), `momento: notte_fonda`.
- [ ] Seq 5 (Spirit Warlock): `summon` `entita_id: "spirito_maligno_…"`
      (prefisso `spirito`, già in `ownership.json`) + `projectile` a
      `tag_danno: spirito`.
- [ ] Seq 4 (Nightwatcher): `shadow_meld` (già implementata, US-5B08) +
      `terrain_modify tipo_modifica: "oscurita" permanente: false` (crea
      oscurità che accende le condizioni `e_notte` **localmente** — nuovo
      gancio, documentato: il campo `terrain_modify` con `tipo_modifica:
      "oscurita"` è letto da `TimeSystem.e_notte(posizione)` come override).
- [ ] `data/status_effects.json`: `occultato` (già da US-5B08).
- [ ] Formule + caratteristiche + ingredienti + i18n + test + verifica a
      schermo (l'oscurità creata accende i buff notturni anche di giorno).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-608: Darkness, Sequenze 3-2 (Horror Bishop → Servant of Concealment)

**Description:** Come giocatore, voglio un'aura di terrore che rompe le
formazioni, e cancellare cose e persone dalla percezione altrui anche in
pieno giorno.

**Acceptance Criteria:**

- [ ] Seq 3/2 pieni, tier alti, rituali. (Seq 1 `darkness_1` **già fatta** in
      US-503; Seq 0 `darkness_0` la si scrive qui con le 3-2 o si lascia a un
      completamento — proposta: scriverla qui, 1 abilità di dominio, così
      Darkness è 10/10.)
- [ ] Seq 2 (Servant of Concealment): `darkness_cancellazione` (stress test
      già esistente) usa `illusion` (implementata in fase 5b, US-5B05) —
      questa story ne completa la Sequenza.
- [ ] Seq 3 (Horror Bishop): `fear` a raggio ampio + `aura` con effetto
      `paura` persistente sui nemici.
- [ ] `darkness_1` (Knight of Misfortune) resta come da US-503;
      `darkness_0`: `aura` di dominio. **Darkness diventa 10/10.**
- [ ] **Con Darkness: 100/100 Sequenze non-stub. Tutti e 22 i Pathway attivi
      completi.**
- [ ] Formule + caratteristiche + ingredienti + i18n + test + verifica a
      schermo.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco D — Gating

#### US-611: Il motore del mondo applica `regions.json.gating[]`

**Description:** Come giocatore, voglio che alcune aree si aprano solo di
notte, con una primitiva, o avendo letto certi testi.

**Acceptance Criteria:**

- [ ] Un componente `AreaGate` (Area2D + un dato di gate): legge un blocco
      di `gating` e apre/chiude il passaggio secondo:
      `primitiva` → il player ha usato quella primitiva di recente / la
      possiede (es. `shadow_meld` per i passaggi in ombra);
      `momento` / `fase_lunare` → `TimeSystem`;
      `npc` → un flag di `npc_influenced` col modo giusto (US-612);
      `conoscenza` → un flag `testi_*` (US-613);
      `sequenza` → `Progression.sequence()` (la Frontiera respinge > ~4).
- [ ] `terrain_modify permanente: true` che tocca un `AreaGate` lo apre per
      sempre (già nel `WorldState.gate_aperti`, salvato).
- [ ] Nessun `if` per una regione o un gate specifico: `AreaGate` legge il
      dato. Un tipo di gate nuovo richiederebbe una voce in `gate_types.json`
      (discussione).
- [ ] Test headless: un gate `momento: notte_fonda` è chiuso di giorno e
      aperto di notte; un gate `conoscenza: testi_ordine_minore` si apre
      quando il flag è vero; un `varco_forzato` permanente resta aperto dopo
      il reload.
- [ ] Verifica a schermo in `progress.txt`: attraverso un gate notturno solo
      di notte; l'Archivio Sepolto si apre con il flag di Ottavia.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco E — NPC

#### US-612: `roster.json` + `npc.schema.json` + validator + `NpcSystem`

**Description:** Come giocatore, voglio 8 persone vere in città, ognuna con la
sua vita e la sua memoria di come l'ho trattata.

**Acceptance Criteria:**

- [ ] `data/schema/npc.schema.json` come `design-npc-quest § 6.1`
      (`additionalProperties: false`): `id`, `name_i18n`, `role_i18n`,
      `region_id`, `anchor_candidate`, `faction_id`, `schedule[]`
      (`{ momento, location_tag|null }`), `vendor` (null o `{ listino:
      [item_id] }`), `dialogue_id`, `memoria` (default `{}`).
- [ ] `data/npc/roster.json`: gli 8 (`npc_mirco`, `npc_sidon`, `npc_vesna`,
      `npc_aldo`, `npc_ottavia`, `npc_bruno`, `npc_lena`, `npc_doran`) +
      un numero di `npc_generic_*` sufficiente per `tg_6_giuramento` (aiuta
      8 NPC) e `fool_9_inganno` (inganna 10 NPC).
- [ ] `NpcSystem` (autoload): `conosciuti()` (id degli NPC incontrati),
      `ancore_attive()` (gli `anchor_candidate` che sono diventati Ancore) —
      **serve ai sussurri di follia a soglia 55** (`audio.json` usa "i nomi
      degli NPC che il giocatore ha incontrato e delle sue Ancore":
      `AudioManager.nomi_sussurro` legge da qui, non da una lista hardcodata).
      `memoria(id)` (contatore per modo di `npc_influenced`); `influenza(id,
      modo)` aggiorna la memoria ed emette `npc_influenced` con `{ modo }`.
- [ ] Validator: `region_id` in `regions.json`; `faction_id` in
      `factions.json` (US-615); `schedule[].location_tag` nel vocabolario;
      `schedule[].momento` in `time.json`; `dialogue_id` esiste (US-613);
      `vendor.listino[]` sono `item_id` reali; chiavi i18n presenti.
- [ ] SAVE: campo `mondo.npc` `{ conosciuti: [], memoria: {}, ancore: [] }`.
      (Stesso bump di US-602/604.)
- [ ] Gli NPC compaiono in Mirwada nella `location_tag` giusta per il
      `momento` corrente (Bruno solo di notte, `schedule` con `location_tag:
      null` = "non in scena").
- [ ] Test headless: `NpcSystem.influenza("npc_mirco", "aiutato")` aggiorna
      la memoria ed emette l'evento; `nomi_sussurro` include i conosciuti e le
      Ancore; un NPC col `location_tag: null` a `notte_fonda` non è in scena.
- [ ] Verifica a schermo in `progress.txt`: gli 8 NPC sono in Mirwada, la
      loro posizione cambia col momento.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco F — Dialoghi

#### US-613: Motore dialoghi + `dialogue.schema.json` + pagina del libro

**Description:** Come giocatore, voglio parlare con gli NPC: scelte, condizioni,
conseguenze.

**Acceptance Criteria:**

- [ ] `data/schema/dialogue.schema.json` come `design-npc-quest § 6.2`:
      `id`, `start`, `nodes` (`{ speaker, text_i18n, choices[] }`); ogni
      `choice`: `text_i18n`, `condizioni[]` (vocabolario abilità + `follia_min`
      / `reputazione_min` / `flag`), `effetti[]` (vocabolario chiuso di ~5:
      `emit_event` → solo i 12 eventi, `flag`, `reputazione`, `apri_vendita`,
      `avvia_quest`), `goto`.
- [ ] `DialogueEngine` (autoload): `avvia(dialogue_id)`, valuta le condizioni
      di ogni `choice` (nasconde quelle non soddisfatte), applica gli
      `effetti` di una scelta, segue `goto`. Il **mondo si ferma** durante un
      dialogo (segnale a `TimeSystem`).
- [ ] `FlagStore` (autoload o dentro `WorldState`): flag booleani namespaced
      (`testi_ordine_minore`, `mirco_sa_del_potere`, …). `conosce(flag)`,
      `imposta(flag, bool)`. Serve al gating `conoscenza` (US-611) e al fog of
      war del diagramma dei Pathway (già usa `KnowledgeStore.conosce
      "pathway:*"` — **unificare**: un solo store di flag, o `FlagStore`
      delega a `KnowledgeStore`).
- [ ] Nuova pagina del libro `page_dialogo` (nel vocabolario `book.json` —
      **un nuovo `page_type`**, discusso: i dialoghi sono contenuto diegetico
      del libro come tutto il resto). Mostra `speaker`, testo, le scelte
      valide; input per selezionare.
- [ ] Validator: `start` e ogni `goto` verso nodi esistenti (niente nodi
      orfani o irraggiungibili dallo `start`); `speaker` nel roster; `evento`
      ed `modo` di `emit_event` validi; `effetti` solo dal vocabolario chiuso;
      chiavi i18n presenti.
- [ ] SAVE: campo `mondo.flag` `{ }`.
- [ ] Test headless: un dialogo con una scelta `condizioni: [tier_min mid]`
      nasconde la scelta a tier low; l'effetto `flag` scrive; l'effetto
      `emit_event npc_influenced` aggiorna la memoria; `goto` naviga; un
      dialogo con un `goto` verso un nodo inesistente fa fallire il validator.
- [ ] Verifica a schermo in `progress.txt`: parlo con Mirco, scelgo una
      risposta, il libro mostra il nodo successivo, il mondo era fermo.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-614: Gli 8 file dialogo + i popolani generici

**Description:** Come giocatore, voglio che ognuno degli 8 abbia qualcosa da
dire, coerente con chi è.

**Acceptance Criteria:**

- [ ] `data/dialogues/dlg_{mirco,sidon,vesna,aldo,ottavia,bruno,lena,doran}.json`:
      un grafo per NPC, coerente col ruolo meccanico di `design-npc-quest § 2`
      (Mirco tutorial diegetico; Sidon rumor a pagamento + `apri_vendita`;
      Vesna cura a prezzo di fiducia, reputazione che scende usando poteri
      davanti a lei; Ottavia concede i flag `testi_*`; Bruno apre il porto
      notturno con `npc_influenced modo: aiutato`; Lena solo umanità, nessun
      servizio; Doran pressione, il sospetto sale; Aldo lo specchio).
- [ ] I nodi che concedono un servizio hanno le `condizioni` giuste
      (`reputazione_min`, `flag`, `tier_min`). Il testo del giocatore
      parametrizza il nome scelto via chiave i18n con parametro (mai
      concatenazione — `design-lore`).
- [ ] `dlg_generic.json`: un dialogo minimo per i `npc_generic_*`
      (influenzabili, senza profondità).
- [ ] i18n: tutte le chiavi `dialogue.*` tradotte in `it.json`.
- [ ] Verifica a schermo: parlo con almeno 3 NPC diversi e ne vedo comportamenti
      diversi (Vesna che si raffredda, Ottavia che concede un flag, Bruno che
      apre il porto).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco G — Quest

#### US-615: Fazioni + reputazione

**Description:** Come giocatore, voglio che le mie azioni abbiano un peso
sociale: alcune porte si aprono, altre si chiudono.

**Acceptance Criteria:**

- [ ] `data/factions.json` + `data/schema/faction.schema.json`: 4 fazioni
      (`ordine_minore`, `porto`, `quartiere`, `giustizia`) con `name_i18n`,
      `soglie` (nomi di livello: ostile/neutrale/amichevole/alleato) e i
      `membri` (id NPC).
- [ ] `FactionSystem` (autoload): `reputazione(faction_id)` numerica;
      `modifica(faction_id, delta, sorgente)`; `livello(faction_id)` dalle
      soglie. `reputazione` come effetto di dialogo/quest;
      `reputazione_min` come condizione (già nell'enum, US-605/613).
- [ ] **Doran = sospetto**: `FactionSystem` tratta `giustizia` in modo
      speciale — la sua reputazione è il sospetto e **sale da sola** a ogni
      `ability_used` mentre `WorldState.regione_corrente == "mirwada"`
      (design-npc-quest § 3). A soglie, emette `npc_influenced modo:
      intimidito`? no — emette un evento di **caccia** (proposta: un flag
      `doran_sospetto_alto` che una quest di caccia legge, US-616).
- [ ] Usare un potere davanti a Vesna (in scena, stessa `location_tag`)
      abbassa la reputazione `quartiere`: un handler che ascolta
      `ability_executed` + la posizione di Vesna. Nessun `if` per Vesna nel
      motore abilità: l'handler vive in `FactionSystem`/`NpcSystem`.
- [ ] SAVE: campo `mondo.reputazione` `{ }`.
- [ ] Test headless: `modifica("porto", +10)` cambia il `livello`; il sospetto
      di Doran sale a ogni `ability_used` in città e non fuori; una condizione
      `reputazione_min` in un dialogo si sblocca alla soglia.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-616: Motore quest + `quest.schema.json` + journal + quest di Atto I

**Description:** Come giocatore, voglio quest che nascono dagli NPC e si
completano facendo cose, non premendo "consegna".

**Acceptance Criteria:**

- [ ] `data/schema/quest.schema.json` come `design-npc-quest § 6.3`: `id`,
      `name_i18n`, `giver`, `atto` (1-3), `fallibile`, `exclusive_with[]`,
      `steps[]` (`{ id, desc_i18n, completamento: { tipo: "evento",
      evento, filtri, target } | { tipo: "flag", id }, on_complete[] }`),
      `ricompense[]` (`{ tipo: "item"|"reputazione"|"flag", … }`).
- [ ] `QuestSystem` (autoload): un lettore che, per ogni quest attiva, osserva
      `EventTracker` (per gli step `evento`) e `FlagStore` (per gli step
      `flag`) e avanza. `avvia(quest_id)` (dall'effetto dialogo `avvia_quest`);
      `stato(quest_id)` ∈ `non_iniziata/attiva/completata/fallita`.
      `fallibile: true` + una condizione di fallimento (tempo scaduto, NPC
      morto, `exclusive_with` avviata) → `fallita`, e il journal la mostra
      fallita. **Zero verbi di quest nuovi**: ogni step è un evento dei 12 o
      un flag.
- [ ] Le quest di **Atto I** in `data/quests/`: q_mirco_01 (tutorial: sconfiggi
      3 nemici senza abilità, come `tg_9_duello_puro`), q_sidon_01 (economia:
      `item_crafted` ×N → `apri_vendita`), q_vesna_01 e q_lena_01 (le Ancore:
      scene che, completate, rendono l'NPC un'Ancora attiva — `NpcSystem`).
      3-5 quest, `atto: 1`.
- [ ] Nuova sezione **Journal** nella pagina inventario del libro (come la
      sezione Sinergie di US-410 — `SEZIONI` da 6 a 7, nessun nuovo
      `page_type`): quest attive coi loro step, completate, fallite.
- [ ] Validator: `giver` nel roster; `evento`/`filtri` validi come per le
      acting_actions; `completamento.flag` scritto da almeno un dialogo/quest;
      `ricompense[].item_id` reali; `exclusive_with` verso quest esistenti;
      chiavi i18n presenti.
- [ ] SAVE: campo `mondo.quest` `{ attive: {}, completate: [], fallite: [] }`.
- [ ] Test headless: `QuestSystem.avvia("q_mirco_01")`; emetto 3
      `enemy_defeated` coi filtri giusti → lo step si completa e la ricompensa
      arriva; una quest `fallibile` con l'NPC "morto" (simulato) → `fallita`;
      il journal elenca lo stato giusto.
- [ ] Verifica a schermo: prendo la quest da Mirco, la completo combattendo,
      il journal la mostra completata e la ricompensa è nello zaino.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco H — Mappa, densità mistica, audio

#### US-617: Pagina mappa del libro + fast travel come potere

**Description:** Come giocatore, voglio vedere dove sono stato e come muovermi
tra le regioni note.

**Acceptance Criteria:**

- [ ] Nuovo `page_type` `mappa` in `book.json` (doppia pagina — `book.json` ha
      un flag `doppia_pagina` mai usato, ora si usa): le regioni **scoperte**
      (`WorldState`), i gate noti, la posizione corrente. Le regioni non
      scoperte sono assenti (fog of war, come il diagramma dei Pathway).
- [ ] **Fast travel = potere**: nessun menu di teletrasporto. Da un nodo mappa
      di una regione scoperta si può viaggiare **solo** se il player ha un
      mezzo del suo Pathway (`door_5` viaggio spirituale, `death_5` passaggi)
      o un varco permanente del TG che collega le due. Altrimenti: "servono le
      strade" (nessun viaggio). Coerente con `design-world § 7`.
- [ ] Tutte le stringhe di chrome da `assets/i18n/strings.csv`.
- [ ] Verifica a schermo: apro la mappa, vedo Mirwada + le regioni visitate;
      con un Pathway Door posso viaggiare, con un altro no.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-618: Densità mistica — percezione, recupero, spawn

**Description:** Come giocatore, voglio che uscire dalla città convenga: fuori
si sente di più, si recupera di più, si trova di più.

**Acceptance Criteria:**

- [ ] `WorldState.densita_mistica_corrente()` = quella della regione corrente
      (da `regions.json`), con override locale se una zona la modifica.
- [ ] **Percezione per Sequenza** (`audio.json.sequence_perception`, da Seq 5):
      da Sequenza 5 in su, il giocatore "sente" la `densita_mistica` — un
      indicatore diegetico (un layer audio dei sussurri più fitto, un testo
      nel libro). `AudioManager` lo legge da `WorldState`, non da un valore
      hardcodato.
- [ ] Il **recupero della spiritualità** (`StatsComponent` / il tick di
      rigenerazione) scala con `densita_mistica_corrente()` — un moltiplicatore
      da `balance.json`. L'**efficacia dei rituali** (il malus di forzatura,
      `Foundation`) idem: dove la densità è alta, forzare costa meno.
- [ ] La frequenza degli **spawn Beyonder** e dei **segreti** per zona scala
      con la densità (dato in `regions.json` o `balance.json`; lo spawner vero
      è minimo — placeholder).
- [ ] La città è **bassa** (densità ~0.2): coltivare in città è lento, come da
      design.
- [ ] Test headless: il recupero di spiritualità in una regione a densità 0.6
      è più rapido che a 0.2; la percezione si attiva da Sequenza 5.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-619: Audio del mondo — zone, ambienti, layer

**Description:** Come sviluppatore, voglio che `audio.json` descriva
completamente il paesaggio sonoro del mondo, pronto da consegnare a un
musicista.

**Acceptance Criteria:**

- [ ] `data/audio.json` esteso: le 4 zone musica nuove (`marche`, `valle`,
      `archivio`, `frontiera`) con la loro `pathway_palette`/riverbero;
      `ambienti` per `momento` (giorno/notte per zona); la **struttura della
      musica a layer** (stem `base` sempre attivo + stem `tensione`/`combat`/
      `boss` con crossfade — solo la struttura, non i file); il **drone del
      rituale** (build 45 s, taglio SECCO al silenzio su interruzione, già
      promesso in `design-master`).
- [ ] Il ciclo giorno/notte cambia l'ambiente sonoro attivo (`AudioManager`
      ascolta `TimeSystem.momento_cambiato`).
- [ ] Validator: ogni `music_zone` di `regions.json` esiste; le soglie e la
      struttura a layer sono coerenti; i bus (`whisper`, ecc.) invariati.
- [ ] **LIMITE DICHIARATO** in `progress.txt`: i file audio non li produce
      questo lavoro. `audio.json` è la specifica completa per un musicista o
      per stem CC0 compatibili con la struttura a layer.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco I — Narrativa e chiusura

#### US-620: Gli indizi dell'antagonista + le scene degli atti

**Description:** Come giocatore, voglio che la trama principale si accenni
attraverso il mondo, agganciata alla mia progressione.

**Acceptance Criteria:**

- [ ] L'**antagonista è il detentore precedente della Sequenza 0** del Pathway
      del giocatore (design-npc-quest, raccomandazione #1): un dato in
      `data/lore/antagonisti.json` (uno per Pathway attivo, 22 voci — id,
      `name_i18n`, indizi come chiavi i18n), letto dai dialoghi e dai libri
      trovati. Nessun boss implementato (fase 7): solo gli **indizi**.
- [ ] Le scene degli atti (`design-npc-quest § 5`) sono **flag + quest**, non
      un motore nuovo: l'Atto I finisce quando "il primo rituale non basta
      più" (un flag scritto al primo `advancement_ritual` di Sequenza ≤ 6);
      Doran che nota le coincidenze = il suo sospetto (US-615); Aldo che
      avanza in parallelo = un contatore sul tempo di gioco.
- [ ] `npc_aldo`: la sua Sequenza sale col tempo di gioco (un dato in
      `roster.json`, `avanzamento_temporale`); ai passaggi di tier del
      giocatore, un flag `aldo_duello_disponibile` (il duello è una quest,
      fase 7).
- [ ] i18n: tutte le chiavi degli indizi tradotte.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-621: Sinergie `scoperta: "lore"` e conoscenza dai libri

**Description:** Come giocatore, voglio che leggere i libri giusti e parlare
con Ottavia mi insegni sinergie e mi apra l'Archivio.

**Acceptance Criteria:**

- [ ] Le sinergie con `scoperta: "lore"` (finora scopribili solo da
      `impara_sinergia` di debug) ora si imparano davvero: un effetto di
      dialogo/libro `impara_sinergia` (nuova voce del vocabolario chiuso degli
      effetti dialogo — **discussione**: o si riusa `flag` + un handler che
      mappa flag→sinergia). Ottavia ne insegna almeno una.
- [ ] I flag `testi_*` di gating conoscenza si guadagnano da: dialoghi
      (Ottavia), **libri trovati** nel mondo (un item `categoria: "pergamena"`
      o un nuovo `libro` che al consumo/lettura scrive un flag — riuso di
      `stored_ability_id`? no, `stored_flag`), e sinergie `lore`.
- [ ] L'**Archivio Sepolto** (regione) usa i flag `testi_*` come gating
      `conoscenza` (US-611): le ali interne si aprono avendo letto.
- [ ] `SynergyEngine._viste`: una sinergia `lore` imparata entra in `_viste`
      (già supportato da `impara_sinergia`).
- [ ] Test headless: leggo un libro → il flag è scritto → l'ala dell'Archivio
      si apre; Ottavia insegna una sinergia `lore` → è in `_viste` e, se i
      tag ci sono, si attiva.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-622: Chiusura fase 6

**Description:** Come sviluppatore, voglio che i documenti riflettano il mondo
costruito e tutti e 22 i Pathway completi.

**Acceptance Criteria:**

- [ ] `006_PRD/roadmap.md` fase 6 → "CHIUSA (N story, M test)", elenco:
      5 regioni, ciclo giorno/notte + lunare, condizioni delle abilità
      attive, **Darkness completo → 100/100 Sequenze, 22/22 Pathway**, 8 NPC
      + dialoghi, motore quest, fazioni, mappa, densità mistica, audio del
      mondo (spec, non file).
- [ ] `006_PRD/design-world.md`, `design-npc-quest.md`: intestazione
      "REALIZZATO in fase 6"; le decisioni prese (nomi regioni, antagonista)
      registrate.
- [ ] `006_PRD/design-master.md` Appendice A fase 6 → CHIUSA; Appendice B
      decisioni n. 1 (nomi regioni), n. 6 (roster 8: tenuti), n. 9
      (antagonista: strutturale) → CHIUSE; Appendice C: `regions.json`,
      `npc.schema.json`, `dialogue.schema.json`, `quest.schema.json`,
      `faction.schema.json`, `gate_types.json`.
- [ ] `CLAUDE.md` + `README.md`: fase 6 chiusa, conteggi, "tutti e 22 i
      Pathway attivi completi", save `schema_version` 21.
- [ ] Il validator ha un check di chiusura: **zero Sequenze `stub`** in
      `data/pathways/`; `regions.json`/`roster.json`/`factions.json` esistono
      e sono coerenti; ogni `dialogue_id` del roster ha un file; le quest di
      Atto I esistono.
- [ ] `python tools/validate_data.py` esce 0. Tests pass.

---

## 4. Functional Requirements

- **FR-1:** Regioni, NPC, dialoghi, quest, fazioni, indizi sono **dati** in
  file JSON validati. Il motore è un lettore. Un `if` per una regione, un
  NPC, una quest specifica è un bug: si riformula sui dati.
- **FR-2:** **Vocabolari chiusi nuovi**: `gate_types.json` (6 modi di gate),
  gli effetti dei dialoghi (~5), i livelli di reputazione. Aggiungere una
  voce = una story con motivazione.
- **FR-3:** **Un solo vocabolario di condizioni** in tutto il gioco. Le
  condizioni dei dialoghi sono quelle delle abilità + `follia_min`,
  `reputazione_min`, `flag`. `AbilityEngine` (US-605) e `DialogueEngine`
  (US-613) le valutano con lo stesso codice se possibile (un `Conditions`
  helper condiviso).
- **FR-4:** **Zero verbi di quest nuovi.** Ogni step di quest è un evento dei
  12 `tracked_events` con filtri, oppure un flag scritto da un dialogo/quest.
  Il `QuestSystem` osserva `EventTracker` e `FlagStore`, come `Acting` osserva
  `EventTracker` per la recitazione.
- **FR-5:** Il **ciclo del tempo si ferma** quando il libro è aperto o un
  dialogo è in corso. Le condizioni `e_notte`/`fase_lunare` leggono
  `TimeSystem`; `in_zona_tag` legge `WorldState`.
- **FR-6:** Le **condizioni delle abilità** (US-605): non soddisfatte →
  rifiuto **senza pagare il costo**. Un caster senza contesto (test, nemici)
  → condizioni soddisfatte.
- **FR-7:** **Darkness** completa il gruppo `eternal_darkness` e porta le
  Sequenze non-stub a **100/100**. Va **dopo** US-604/605 (day/night +
  condizioni): il suo concept lo richiede.
- **FR-8:** Il **gating** (US-611) è un componente `AreaGate` che legge
  `regions.json.gating[]`. Nessun `if` per un gate specifico.
  `terrain_modify permanente: true` apre gate salvati.
- **FR-9:** I **sussurri di follia a soglia 55** (`audio.json`) leggono i nomi
  da `NpcSystem.conosciuti()` + `NpcSystem.ancore_attive()`, non da una lista
  hardcodata. `tg_6_giuramento` / `fool_9_inganno` contano i popolani
  generici.
- **FR-10:** **Fast travel = potere.** Nessun menu di teletrasporto. Solo
  `door_5`/`death_5`/varchi permanenti del TG.
- **FR-11:** **SAVE**: fase 6 bumpa `schema_version` **una** volta (20 → 21)
  con **una** `_migra_20_a_21`. I campi nuovi: `mondo.{ regione, scoperte,
  gate_aperti, tempo, npc, flag, reputazione, quest }`. La catena da v1 resta
  verde. Rilettura NON FIDATA di ogni campo (solo id che risolvono).
- **FR-12:** **Nessun nuovo `page_type` non necessario.** Il journal è una
  sezione della pagina inventario (come Sinergie, US-410). `page_dialogo` e
  `page_mappa` sono `page_type` nuovi **giustificati** (il libro è la UI
  diegetica di tutto): discussione esplicita, ma attesi.
- **FR-13:** **i18n**: ogni chiave `region.*`, `npc.*`, `dialogue.*`,
  `quest.*`, `faction.*` tradotta in `it.json` dopo la sua story. `en.json`
  resta incompleto per scelta.
- **FR-14:** **Nessuna dipendenza nuova.** Nessun motore di scripting nei
  dialoghi. Nessuna generazione procedurale.
- **FR-15:** Ogni story chiude in una context window; se supera ~4 file di
  logica o ~200 righe di diff, si spezza (l'US-613 motore dialoghi e l'US-616
  motore quest sono le più a rischio: prevedere di spezzarle in schema /
  engine / pagina).

---

## 5. Non-Goals (Out of Scope)

- **Arte definitiva delle regioni.** Le 5 scene sono tilemap placeholder
  diagnostici (come US-006). Il budget e le strade per l'arte vera sono in
  `prd-fase-1-fondamenta.md`; la decisione non va presa qui.
- **File audio.** `audio.json` è la specifica completa; i suoni li fa un
  musicista o vengono da stem CC0. `design-master`: l'audio è un canale
  informativo, non un non-goal — ma produrlo sì.
- **La fase 7** (cambio Pathway, `fusion_rules`, tribolazioni, `data/endings.json`,
  eredità al personaggio successivo, i duelli con Aldo, il boss antagonista).
  La fase 6 pianta gli **indizi** dell'antagonista; la rivelazione e lo
  scontro sono fase 7.
- **Simulazione sociale.** La memoria degli NPC è un contatore per modo di
  `npc_influenced`, letto dalle condizioni. Nessun sistema di relazioni
  emergenti.
- **IA di combattimento avanzata.** Gli spawn Beyonder per zona sono uno
  spawner minimo. Il comportamento vero dei nemici, dei summon, degli
  illusori (fase 5b) e dei posseduti è un lavoro a sé, agganciabile qui ma
  non un obiettivo di questo PRD.
- **Mondo aperto.** Ogni regione è gated. Le 4-6 regioni sono un limite di
  progetto, non una tappa verso di più.
- **Doppiaggio.** Non-goal di progetto.

---

## 6. Design Considerations

- **Una regione per gruppo di Pathway** (`design-world § 1`): è il terzo
  canale dell'identità di Pathway (dopo primitive e audio). La palette audio
  di ogni Pathway ha già un riverbero — cripta, bosco, teatro, officina — e
  quei riverberi *sono* i luoghi. Un giocatore di Mother sente la Valle come
  casa.
- **Il libro è la UI di tutto** (`design-ui-libro`). La mappa e i dialoghi
  sono pagine del libro; il journal una sezione. Il libro ferma il mondo:
  niente si muove mentre lo leggi o parli.
- **Le quest sono la recitazione applicata alla narrativa.** Stesso
  `EventTracker`, stesso principio: se una quest sembra richiedere un
  rilevatore speciale, è scritta male.
- **Fallire è contenuto.** `fallibile: true` esiste dal giorno 1. Una quest
  persa (tempo, morte di un NPC, scelta opposta) il journal la mostra fallita.
  Non è game over.
- **Gli atti sono i tier.** Atto I = Seq 9-7 (la città), Atto II = Seq 6-4
  (le regioni), Atto III = Seq 3-1 (la Frontiera). Il rituale di Seq 1 chiede
  un'Ancora — la storia arriva dove la meccanica aveva promesso.
- **L'antagonista strutturale** (`il detentore precedente della Sequenza 0`)
  cambia col Pathway: massima rigiocabilità, zero contenuto sprecato. La fase
  6 ne semina gli indizi; chi è e cosa significa sacrificarlo è la
  rivelazione di fase 7.
- **Riuso.** `WorldState` (già c'è: terreni permanenti), `EventTracker`,
  `KnowledgeStore`/`FlagStore` (unificare), `Madness` + i sussurri,
  `AudioManager` + i bus, la pagina inventario del libro (sezioni),
  `SynergyEngine._viste` per le sinergie `lore`, il pattern
  tracker-prima-motore-dopo di `GameState` per il save.

---

## 7. Technical Considerations

- **`TimeSystem`.** Autoload leggero. `momento`/`fase_lunare` sono contatori
  in `_process` con durate da `balance.json`. Si ferma su un segnale da
  `Book` e da `DialogueEngine`. `eclissi` è schedulata (un contatore di
  cicli) o forzata da un rituale.
- **`Conditions` helper.** Un modulo condiviso `scripts/conditions.gd` che
  valuta una lista di `{ tipo, valore }` contro lo stato globale, usato sia
  da `AbilityEngine.execute` sia da `DialogueEngine`. Un solo posto in cui
  vive la semantica di `e_notte`, `reputazione_min`, `flag`, ecc.
- **Autoload nuovi**, nell'ordine (dopo GameData, prima dei sistemi che li
  usano): `TimeSystem`, `NpcSystem`, `FlagStore` (o dentro WorldState),
  `FactionSystem`, `DialogueEngine`, `QuestSystem`. Ognuno con
  `per_salvataggio()` / `da_salvataggio()` e il gancio in `GameState`.
- **SAVE — un bump solo.** Tutti i campi nuovi entrano in `mondo` con
  `_migra_20_a_21`. Se una story a metà fase si accorge di aver bisogno di un
  campo non previsto, lo aggiunge a `mondo` **senza** un secondo bump (il
  campo manca nei save v21 vecchi di poche settimane → default gestito).
- **`AbilityEngine` e le condizioni.** L'unico punto di `execute` che cambia:
  un check `Conditions.tutte_soddisfatte(ability.get("condizioni", []))`
  prima di pagare il costo. `execute_stored` (oggetti) **non** verifica le
  condizioni (l'oggetto è già il permesso). Il checkpoint di fase 5b/5 non è
  intaccato: è un check, non un caso speciale per un Pathway.
- **Il motore dialoghi non è un motore di scripting.** È un walker di grafo +
  un applicatore di effetti da un vocabolario chiuso. Se un dialogo sembra
  richiedere logica, è un flag più una quest.
- **`ralph`.** `--fase 6` (`"fase": 6` in `prd.json`). Docker attivo,
  `--test-cmd "godot --headless --script tests/run_tests.gd"`. Una story per
  iterazione. Godot 4.3 headless in locale a ogni story; verifica a schermo
  reale per le regioni, il ciclo del tempo, i dialoghi, le quest.
- **Ordine vincolante**: Blocco A (regioni) + US-604/605 (tempo + condizioni)
  **prima di** Darkness (C), gating (D), NPC/dialoghi/quest (E/F/G). La mappa
  e la densità (H) dopo che ci sono le regioni. La narrativa (I) alla fine.

---

## 8. Success Metrics

- **Il mondo esiste**: 5 regioni giocabili, ciclo giorno/notte e lunare che
  scorre, gating che apre/chiude aree per 6 modi diversi.
- **Le condizioni delle abilità valgono**: `hermit_costellazione_del_custode`
  funziona solo a luna piena, `moon_furia_notturna` solo di notte, verificato
  a schermo — senza un `if` per una specifica abilità.
- **Tutti e 22 i Pathway attivi completi**: con Darkness, **100/100 Sequenze
  non-stub**. Il validator dà errore su una singola Sequenza `stub`.
- **La narrativa è dati**: 8 NPC con dialoghi, un motore quest che è un
  lettore di `EventTracker` + flag (zero verbi nuovi), 4 fazioni, l'Atto I
  giocabile end-to-end (prendi la quest da Mirco → combatti → journal
  aggiornato → ricompensa).
- **I contratti già vivi sono onorati**: i sussurri di follia a soglia 55
  usano i nomi reali degli NPC conosciuti e delle Ancore;
  `tg_6_giuramento`/`fool_9_inganno` si completano coi popolani generici;
  `fool_6` "eredita i permessi sociali" usa i gate di tipo `npc`.
- **SAVE**: `schema_version` 21 con **una** migrazione, la catena da v1
  verde, rilettura non fidata di ogni campo `mondo`.
- **Nessuna regressione**: i ~570+ test di fase 1-5b restano verdi (dopo
  l'aggiornamento dei test che eseguono abilità condizionate con un player in
  scena, US-605).
- **`audio.json` è pronto per un musicista**: le 4 zone nuove, gli ambienti
  per momento, la struttura a layer e il drone del rituale sono specificati;
  i file sono un lavoro separato dichiarato in `progress.txt`.

---

## 9. Open Questions

1. **`page_dialogo` e `page_mappa` come `page_type` nuovi**: il libro è la UI
   di tutto, quindi sono coerenti — ma `book.json` e il vocabolario dei tipi
   di pagina vanno estesi. Confermare che sono due `page_type` e non, per
   esempio, il dialogo come overlay separato dal libro.
2. **`FlagStore` vs `KnowledgeStore`**: oggi il diagramma dei Pathway usa
   `KnowledgeStore.conosce("pathway:*")`. I flag `testi_*` e
   `mirco_sa_del_potere` sono la stessa cosa? Proposta: un solo store, e
   `KnowledgeStore` diventa `FlagStore` con namespace (`pathway:`, `testi:`,
   `dialogo:`).
3. **Durata di un ciclo giorno/notte** in minuti di gioco reale: quanto lungo?
   Troppo corto = frustrante per le abilità notturne; troppo lungo = si
   aspetta. Da tarare col playtest; default plausibile in `balance.json`.
4. **`impara_sinergia` come effetto di dialogo**: nuova voce del vocabolario
   chiuso degli effetti (ora ~5), o `flag` + un handler flag→sinergia?
   Proposta: nuova voce esplicita, il vocabolario passa a ~6.
5. **Lo spawner Beyonder**: quanto minimo? Solo un contatore che genera un
   nemico placeholder ogni X secondi scalato dalla densità, o niente spawn e
   solo nemici piazzati a mano nelle scene? Proposta: contatore minimo, i
   nemici veri sono contenuto di una fase successiva.
6. **`npc_aldo` che avanza col tempo**: un contatore lineare sul tempo di
   gioco, o legato ai passaggi di tier del giocatore (sempre "una Sequenza
   avanti")? Proposta: sempre una Sequenza avanti al giocatore, con un tetto,
   così il duello è sempre alla portata ma mai banale.
7. **Il numero di quest di Atto I**: 3 (minimo per raccontare la città), 5
   (una per NPC-chiave), o di più? Proposta: 5 — Mirco, Sidon, Vesna, Lena,
   Doran — le altre tre (Aldo, Ottavia, Bruno) sono dialoghi + flag, non
   quest formali, in questa fase.
