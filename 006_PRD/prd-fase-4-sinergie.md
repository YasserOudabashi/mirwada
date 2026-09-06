# PRD: Fase 4 — Sinergie

## 1. Introduzione / Overview

La fase 3 ha costruito le **fonti**: inventario/equip, pet, talenti e stanze
ognuno espone `tag_attivi()`, e `SynergySources.tag_sinergia_globali()` li
somma in un unico dizionario `{ tag: conteggio }`. Nessuna di quelle fonti
conosce le sinergie: è deliberato.

La fase 4 costruisce il **motore** che legge quella materia prima e ne trae
conseguenze di gioco:

- un **SynergyEngine** che confronta i tag posseduti con le `richiede_tag` /
  `esclude_tag` di ogni sinergia in `data/synergies/`, decide quali sono
  **attive**, risolve **priorità** e **conflitti**, applica gli **effetti**
  (tutti e 6 i tipi dello schema, incluso `modifica_primitiva`), gestisce le
  **anti-sinergie**;
- un **registro** persistente delle sinergie **viste** e una **sezione del
  libro** che le mostra col fog of war (attiva / visibile-non-attiva coi tag
  mancanti / vista-non-attiva offuscata / mai vista = assente);
- il **contenuto**: si scrive `sinergia_colpo_del_caso` (l'abilità della
  sinergia firma), si portano le sinergie di `core.json` da 3 a ~30-40, e si
  verifica il **criterio di uscita**: una sinergia nata da **pet + stanza +
  talento** si attiva davvero, senza una riga di codice dedicata a quella
  sinergia.

Come tutta la fase 2 e 3: le sinergie sono **dati**. Il motore implementa
primitive di risoluzione; i file JSON compongono il contenuto. Nessun `if`
per una sinergia specifica.

---

## 2. Goals

- Un `SynergyEngine` autoload che, dato `SynergySources.tag_sinergia_globali()`,
  produce l'insieme delle sinergie **attive** e applica i loro effetti.
- Rivalutazione **reattiva**: le sinergie si accendono/spengono quando cambi
  equip, domi un pet, sblocchi un talento, costruisci una stanza, avanzi di
  Sequenza — su segnale delle fonti + un poll di sicurezza ogni ~0.5 s.
- Tutti e 6 i tipi di `effetto` dello schema funzionano:
  `modifica_stat`, `modifica_follia`, `modifica_qualita_crafting`,
  `sblocca_ricetta`, `aggiungi_abilita`, `modifica_primitiva`.
- **Priorità e conflitti** risolti da una regola dichiarata, non dall'ordine
  di caricamento dei file.
- **Anti-sinergie**: `anti: true` neutralizza la sinergia gemella e applica il
  suo malus.
- **Registro** persistente (`viste`) + **sezione Sinergie** nel libro col fog
  of war, tutte le stringhe da i18n.
- Il save passa da `schema_version` 19 a 20 (un solo bump, una migrazione).
- Contenuto: `sinergia_colpo_del_caso` scritta; ~30-40 sinergie in
  `data/synergies/`, di cui **≥ 15 raggiungibili** coi 10 Pathway attivi +
  pet/stanze/talenti; le altre puntano a gruppi differiti e restano a
  `warning` documentato (come oggi `sinergia_inganno_probabilita`).
- **Criterio di uscita** verificato da un test: una sinergia pet + stanza +
  talento si attiva e il suo effetto si misura, con zero codice dedicato.

---

## 3. User Stories

### Blocco A — Il motore

#### US-401: Schema esteso e SynergyEngine (risoluzione dei tag)

**Description:** Come sviluppatore, voglio un motore che dato l'insieme dei tag
posseduti dica quali sinergie sono soddisfatte, così che gli effetti abbiano
un input stabile.

**Acceptance Criteria:**

- [ ] `data/schema/synergy.schema.json` esteso (retro-compatibile con i 3
      esempi): campo `priorita` (int, default 0); l'`effetto` diventa un
      `oneOf` per i 6 `tipo` con i loro campi specifici (vedi §4 FR-4..FR-9).
      `esclude_tag` già presente resta.
- [ ] Autoload `SynergyEngine` (`scripts/synergy_engine.gd`):
      `attive() -> Array` (id delle sinergie i cui `richiede_tag` sono
      soddisfatti da `SynergySources.tag_sinergia_globali()` **e** i cui
      `esclude_tag` NON sono presenti); `e_attiva(id) -> bool`;
      `tag_mancanti(id) -> Dictionary` (per la UI: quali tag e quanti ne
      mancano).
- [ ] `SynergySources.tag_sinergia_globali()` esteso con la fonte `sequenza`:
      i `tags` del Pathway attivo (via `Progression`/`GameData.get_pathway`).
      `ingrediente` resta nell'enum `fonti` ma **nessuna fonte lo alimenta in
      fase 4** (documentato: la sinergia a tempo di craft è fase 5+).
- [ ] `GameData.get_synergy(id)`, `synergy_ids()`, `synergies_attive_per_fonte`
      no — solo `get_synergy` e `synergy_ids` (il resto lo fa il motore).
- [ ] Il validator: ogni `richiede_tag`/`esclude_tag` nel vocabolario chiuso
      (già c'è); `priorita` intero; `effetto` valido per il suo `tipo`.
- [ ] Test headless: dato un set di tag finto (mock di SynergySources o
      iniezione), `attive()` include le sinergie soddisfatte ed esclude quelle
      con un `esclude_tag` presente o un `richiede_tag` sotto soglia.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-402: Rivalutazione reattiva + segnali

**Description:** Come giocatore, voglio che equipaggiare un oggetto o domare un
pet accenda subito la sinergia che completa, non al frame dopo un minuto.

**Acceptance Criteria:**

- [ ] `SynergyEngine` in `_ready()` si connette ai segnali di cambiamento
      delle fonti: `Equipment` (equip/rimuovi/incastona), `PetSystem`
      (`pet_impostato`, `pet_liberato`, `pet_morto`, `bond_cambiato`),
      `TalentSystem` (`talento_sbloccato`), `BaseSystem` (`stanza_costruita`,
      `stanza_potenziata`), `Progression` (`sequence_changed`). Un segnale
      mancante su una fonte è un bug di quella fonte: aprire una micro-story,
      non aggiungere un `if` qui.
- [ ] `_process(delta)`: accumulatore; ogni ~0.5 s ricalcola comunque
      `attive()` e fa il **diff** contro l'insieme precedente.
- [ ] Segnali `sinergia_attivata(id)` / `sinergia_disattivata(id)` emessi solo
      sui cambi reali (non a ogni tick).
- [ ] `rivaluta()` pubblico (per i test e per un eventuale chiamante esplicito).
- [ ] Test headless: cambio una fonte finta → `sinergia_attivata` emesso una
      volta; ripeto lo stesso stato → nessun segnale; tolgo un tag → 
      `sinergia_disattivata`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-403: Effetti `modifica_stat` e `modifica_follia`

**Description:** Come giocatore, voglio che una sinergia attiva mi dia davvero
+difesa o mi faccia salire la follia più in fretta.

**Acceptance Criteria:**

- [ ] Su `sinergia_attivata(id)`: se `effetto.tipo == "modifica_stat"`, il
      motore applica un modificatore per id `synergy:<id>` sullo
      `StatsComponent` del giocatore (delta = `valore`, o `valore * base` se
      `moltiplicativo`), come fanno equip/sigilli/talenti (FR-3 di fase 3).
- [ ] `effetto.tipo == "modifica_follia"`: il motore registra un
      `delta_al_minuto` in `Madness` con sorgente `synergy:<id>` (una
      sinergia positiva può anche **ridurre** la follia nel tempo; una
      `anti` la accelera).
- [ ] Su `sinergia_disattivata(id)`: il modificatore/contributo viene rimosso.
- [ ] `riapplica()` rimette gli effetti dei posseduti quando compare il
      giocatore in scena o dopo un load (come `TalentSystem.riapplica`).
- [ ] Test headless: sinergia `modifica_stat` attiva → la stat sale del delta;
      disattivata → torna; `modifica_follia` → `Madness` ha il contributo al
      minuto giusto.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-404: Effetti `modifica_qualita_crafting`, `sblocca_ricetta`, `aggiungi_abilita`

**Description:** Come giocatore, voglio che una sinergia mi renda note certe
ricette, mi migliori la qualità del crafting, o mi presti un'abilità.

**Acceptance Criteria:**

- [ ] `modifica_qualita_crafting` `{ categoria: "pozioni"|"forgia", delta: int }`:
      `PotionSystem._qualita_finale` e `Forge._qualita_finale` sommano
      `SynergyEngine.bonus_qualita(categoria)` (nuovo metodo, come già leggono
      `BaseSystem.bonus`). Nessun `if` sul nome di una sinergia.
- [ ] `sblocca_ricetta` `{ recipe_id }`: su `sinergia_attivata`, il motore
      chiama `KnowledgeStore.impara("ricetta:" + recipe_id)`. La ricetta
      resta nota anche se la sinergia poi si spegne (imparare non si
      dimentica) — documentato.
- [ ] `aggiungi_abilita` `{ ability_id }`: su `sinergia_attivata`, il motore
      concede l'abilità in modo **permanente** finché la sinergia è attiva
      (nuovo `AbilityEngine.grant_permanente(ability_id)` / `revoca_permanente`,
      gemello di `grant_temporary` senza scadenza a tempo). Su
      `sinergia_disattivata` la revoca.
- [ ] Il validator: `recipe_id` risolve; `ability_id` risolve (o la sinergia
      è `stub: true`); `categoria` in `{pozioni, forgia}`.
- [ ] Test headless: `modifica_qualita_crafting` attiva → `prepara` produce una
      qualità più alta; `sblocca_ricetta` → `PotionSystem.ricetta_nota` true;
      `aggiungi_abilita` → `AbilityEngine.can_execute` true mentre attiva,
      false dopo la disattivazione.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-405: Effetto `modifica_primitiva` (hook nel motore delle primitive)

**Description:** Come giocatore, voglio che una sinergia possa allargare il
raggio di tutte le mie abilità d'area, o rendere più veloci i dash.

**Acceptance Criteria:**

- [ ] `effetto.tipo == "modifica_primitiva"`
      `{ primitiva: "<nome>", parametro: "<param>", delta: <number>, moltiplicativo: bool }`.
      `primitiva` è una del registro chiuso `data/schema/primitives.json`;
      `parametro` è uno dei `params` dichiarati per quella primitiva.
- [ ] `AbilityEngine._esegui_primitive`, prima di chiamare l'handler di una
      primitiva `tipo`, applica in cima al dizionario `prim` (su una copia, i
      dati non si toccano) i delta di ogni sinergia **attiva** con
      `modifica_primitiva` su quel `tipo` e quel `parametro`. Additivo per i
      delta flat, moltiplicativo `param *= (1 + delta)`.
- [ ] `SynergyEngine.delta_primitiva(tipo, parametro) -> float` è l'unica API
      che `AbilityEngine` interroga: nessun `if` su una sinergia.
- [ ] Il validator: `primitiva` nel registro (non differita), `parametro` nei
      suoi `params`, `delta` numerico.
- [ ] Test headless: sinergia `modifica_primitiva` su `decay.raggio` attiva →
      `_p_decay` colpisce a un raggio maggiore (verificabile su
      `rec["raggio"]` o su una struttura appena fuori dal raggio base);
      disattivata → raggio base.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-406: Priorità e conflitti

**Description:** Come sviluppatore, voglio che quando due sinergie toccano la
stessa stat il risultato sia deterministico, non un caso.

**Acceptance Criteria:**

- [ ] Regola di risoluzione dichiarata in un `_comment` di `synergy.schema.json`
      e implementata in `SynergyEngine`:
      1. raccogli le sinergie soddisfatte (`richiede_tag` ok, `esclude_tag`
         assenti);
      2. per gli effetti **cumulativi** (`modifica_stat`, `modifica_follia`,
         `modifica_primitiva` con delta) i contributi si **sommano** — nessun
         conflitto, ma `priorita` fissa l'ordine di applicazione (stabile);
      3. per gli effetti **esclusivi** (`sblocca_ricetta`, `aggiungi_abilita`
         sullo stesso id, `modifica_qualita_crafting` sulla stessa categoria)
         vince la sinergia con `priorita` più alta; a parità, l'`id` minore
         (ordine lessicografico, riproducibile fra macchine).
- [ ] `SynergyEngine.spiega(id) -> Dictionary` per il debug/UI: quale regola ha
      deciso, quali sinergie ha sovrascritto.
- [ ] Test headless: due `modifica_stat` sulla stessa stat → la stat sale della
      **somma**; due `modifica_qualita_crafting` sulla stessa categoria → si
      applica solo quella con `priorita` più alta.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-407: Anti-sinergie

**Description:** Come giocatore, voglio che portare due set di poteri che si
mordono (Justiciar + Black Emperor) abbia una conseguenza vera.

**Acceptance Criteria:**

- [ ] Una sinergia con `anti: true` che è **soddisfatta** (i suoi
      `richiede_tag` sono presenti): applica il suo `effetto` (tipicamente un
      malus — `modifica_follia` positivo, `modifica_stat` negativo) e, se
      esiste una sinergia **gemella** (stesso `richiede_tag` set senza `anti`),
      la **neutralizza** (la gemella non applica il suo effetto finché l'anti è
      attiva).
- [ ] L'appartenenza "gemella" è **dichiarata nei dati**: campo opzionale
      `neutralizza: ["<id>", ...]` sulla anti-sinergia. Nessuna inferenza per
      set di tag nel codice.
- [ ] `anti_ordine_disordine` in `core.json`: resta `irraggiungibile`
      (`ordine`/`disordine` sono di gruppi differiti) → warning atteso e
      documentato, ma il **meccanismo** è testato con una anti-sinergia di
      prova raggiungibile.
- [ ] Test headless: anti-sinergia attiva + gemella soddisfatta → la gemella
      NON applica il suo bonus, l'anti applica il malus; tolgo un tag dell'anti
      → la gemella torna attiva.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-408: SAVE — registro delle sinergie viste + migrazione

**Description:** Come giocatore, voglio che le sinergie che ho scoperto restino
scoperte fra una sessione e l'altra.

**Acceptance Criteria:**

- [ ] `SynergyEngine` tiene `_viste: Array` (id). Una sinergia entra in `_viste`
      quando: (a) è `scoperta: "visibile"` (è nel registro dall'inizio); (b) si
      **attiva** per la prima volta (qualsiasi `scoperta`); (c) una fonte lore
      la insegna (`impara_sinergia(id)`, per ora solo debug/drop — la fonte
      lore vera è fase 6).
- [ ] SAVE: `schema_version` 19 → 20. Campo `sinergie` `{ viste: [id] }`. Le
      sinergie **attive** NON si salvano: si riderivano dai tag al load
      (`riapplica()` dopo `da_salvataggio`). `_migra_19_a_20` (default
      `{ viste: [] }`). La catena da v1 resta verde.
- [ ] `GameState` assembla/riapplica il campo `sinergie` (tracker prima,
      motore dopo, come per i talenti).
- [ ] Rilettura NON FIDATA: solo id che risolvono a una sinergia esistente.
- [ ] Test headless: attivo una sinergia `nascosta`, salvo, azzero, carico →
      è in `viste`; le attive si riderivano dai tag correnti; migrazione da
      v19 aggiunge `{ viste: [] }`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco B — Il registro nel libro

#### US-409: Logica di visibilità (fog of war delle sinergie)

**Description:** Come sviluppatore, voglio un'API che per ogni sinergia dica in
che stato il giocatore la vede.

**Acceptance Criteria:**

- [ ] `SynergyEngine.stato_registro() -> Array` di
      `{ id, stato: "attiva"|"visibile"|"vista"|"ignota", tag_mancanti }` dove:
      - `attiva`: `richiede_tag` soddisfatti (e non neutralizzata);
      - `visibile`: `scoperta == "visibile"` ma non attiva → mostra i
        `tag_mancanti`;
      - `vista`: in `_viste` ma non attiva e non `visibile` (l'hai attivata in
        passato) → riga offuscata, nome visibile, effetto no;
      - `ignota`: `scoperta` `nascosta`/`lore` e mai vista → **assente** dal
        registro.
- [ ] `SynergyEngine.contatore() -> Vector2i` = `(scoperte, totali_scopribili)`
      dove `totali_scopribili` esclude le `lore` mai raggiungibili coi gruppi
      attivi (come il conteggio del diagramma dei Pathway).
- [ ] Test headless: 4 sinergie di prova nei 4 stati → `stato_registro` le
      classifica giusto; il contatore sale quando ne attivo una `nascosta`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-410: Sezione Sinergie nella pagina del libro

**Description:** Come giocatore, voglio vedere le sinergie che ho attive, quelle
che potrei completare e quanto ho scoperto.

**Acceptance Criteria:**

- [ ] La sezione **Sinergie** vive nella pagina `inventario` del libro (come
      zaino/indosso/ricettario/talenti/base — **nessun nuovo `page_type`**;
      `SEZIONI` passa da 5 a 6, `data/ui/book.json` non cambia struttura).
- [ ] Per ogni voce di `stato_registro()`:
      - `attiva`: nome (`tr_data`) + riassunto dell'`effetto` + le fonti
        (`fonti` della sinergia);
      - `visibile`: nome + "manca: `<tag> x<n>`" per ogni `tag_mancanti`;
      - `vista`: riga offuscata (`modulate.a` 0.55), solo il nome;
      - `ignota`: assente.
- [ ] In cima: il contatore "`scoperte` / `totali` sinergie".
- [ ] Le anti-sinergie attive sono marcate (icona/colore diverso — un
      `▲` testuale basta) e la loro riga dice quale sinergia neutralizzano.
- [ ] Tutte le stringhe di chrome da `assets/i18n/strings.csv` + `tr()`; i
      nomi da `GameData.tr_data`.
- [ ] Verifica a schermo documentata in `progress.txt`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-411: Il registro reagisce dal vivo

**Description:** Come giocatore, voglio che aprendo il libro dopo aver
equipaggiato qualcosa la sezione Sinergie sia già aggiornata.

**Acceptance Criteria:**

- [ ] La sezione Sinergie si ricostruisce su `sinergia_attivata` /
      `sinergia_disattivata` se il libro è aperto su quella sezione (o
      comunque alla prossima apertura).
- [ ] Una sinergia appena attivata per la prima volta lampeggia/si evidenzia
      una volta (un `▸` per un paio di secondi, o solo un colore per il primo
      render — la cosa più semplice che si nota).
- [ ] Verifica a schermo documentata in `progress.txt`: equipaggio l'oggetto
      che completa una sinergia visibile → apro il libro → è passata da
      "visibile (manca X)" ad "attiva".
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco C — Contenuto (story di soli dati, tranne US-412)

#### US-412: `sinergia_colpo_del_caso` — l'abilità della sinergia firma

**Description:** Come sviluppatore, voglio scrivere l'abilità che
`sinergia_inganno_probabilita` promette, così che lo stub sparisca.

**Acceptance Criteria:**

- [ ] `data/abilities/` (in un file adatto, o un nuovo `data/abilities/synergy.json`):
      `sinergia_colpo_del_caso` — un'abilità composta da primitive del registro
      chiuso, tematica "fortuna/probabilità" (proposta: `debuff_stat` sul
      bersaglio + un `buff_stat` breve su di sé, o una `curse`), con
      `tag_sinergia` e `sequence_id` coerenti (non appartiene a un Pathway: usa
      una convenzione tipo `sequence_id: "synergy"`).
- [ ] `sinergia_inganno_probabilita` in `core.json`: tolto `stub: true`. La
      sinergia resta `irraggiungibile` (il tag `probabilita'` è del gruppo
      differito `key_of_light`) → warning atteso, elencato in `progress.txt`.
- [ ] Il validator non segnala più "abilità inesistente" per quella sinergia.
- [ ] Test headless: `AbilityEngine.execute("sinergia_colpo_del_caso", caster)`
      esegue senza warning di primitiva; l'abilità è nel registro di GameData.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-413: Batch 1 — 8 sinergie raggiungibili, una per meccanismo

**Description:** Come giocatore, voglio le prime sinergie vere, che coprono
ogni tipo di effetto e il criterio di uscita.

**Acceptance Criteria:**

- [ ] 8 sinergie nuove in `data/synergies/` (in `core.json` o file tematici),
      tutte **raggiungibili** con i 10 Pathway attivi + pet/stanze/talenti:
      1. una `modifica_stat` (es. equip "guerra" + talento "guerra" → +forza);
      2. una `modifica_follia` **positiva** (es. stanza `rituale` + Ancora
         forte → follia -X/min);
      3. una `modifica_qualita_crafting` (giardino + ingrediente + pet
         erbivoro → +qualità pozioni — è `sinergia_crescita_pozione`, già
         raggiungibile dopo US-334: portarla a contenuto reale);
      4. una `sblocca_ricetta` (biblioteca lv≥2 + tag "conoscenza" da un
         talento → ricetta avanzata nota);
      5. una `aggiungi_abilita` (2 Pathway dello stesso gruppo → un'abilità di
         "confine");
      6. una `modifica_primitiva` (es. tag "area" da abilità + tag "area" da
         un sigillo → +raggio a `decay`/`aura`);
      7. una **anti-sinergia** raggiungibile con un `neutralizza` verso la #1;
      8. **la sinergia del criterio di uscita**: `richiede_tag` che si
         soddisfano **solo** combinando pet + stanza + talento (nessuna delle
         tre da sola basta), `fonti: ["pet", "stanza", "talento"]`,
         `scoperta: "visibile"`.
- [ ] i18n: `name_i18n` per ognuna, stub tradotti dal campo gemello.
- [ ] Il validator: tutte e 8 con `richiede_tag` **non** irraggiungibili
      (nessun warning nuovo).
- [ ] Test headless (il **criterio di uscita**, `test_slice_fase_4.gd`):
      costruisco la stanza, domo il pet, sblocco il talento — nessuna sinergia
      attiva; con tutti e tre → la sinergia #8 è `attiva` e il suo effetto si
      misura. Zero righe di codice nominano quella sinergia.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-414: Batch 2 — ~10 sinergie raggiungibili di combinazione

**Description:** Come giocatore, voglio abbastanza sinergie da rendere le scelte
di equip/pet/talenti interessanti.

**Acceptance Criteria:**

- [ ] ~10 sinergie nuove, tutte raggiungibili oggi, che pescano da coppie di
      fonti diverse (equip+abilità, sequenza+ingrediente-no → sequenza+equip,
      pet+talento, stanza+sequenza, sigillo+abilità…). Mix di `scoperta`
      `visibile` e `nascosta`.
- [ ] Almeno 2 sfruttano `priorita` per gestire un conflitto reale con una
      sinergia del batch 1 (test: il conflitto si risolve come dichiarato).
- [ ] i18n completo. Validator 0 warning nuovi.
- [ ] Test headless: 3-4 casi a campione (attivazione + effetto) su sinergie di
      questo batch.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-415: Batch 3 — sinergie che puntano ai gruppi differiti

**Description:** Come sviluppatore, voglio scrivere ora le sinergie dei Pathway
che arriveranno in fase 5, così che riattivare un gruppo le accenda da solo.

**Acceptance Criteria:**

- [ ] ~15 sinergie in `data/synergies/` che richiedono tag portati **solo** da
      Pathway di gruppi differiti (`probabilita'`, `ordine`, `disordine`,
      `fortuna` non usato, ecc.). Restano **inattive** e generano il warning
      "irraggiungibile" — **atteso**.
- [ ] Il validator: il warning per queste è OK, ma il **conteggio** delle
      irraggiungibili è stampato come una riga sola ("N sinergie
      irraggiungibili: attese, appartengono a gruppi differiti") invece di N
      warning separati che annegano gli altri.
- [ ] `006_PRD/design-pathways.md`: una riga per gruppo differito che elenca le
      sinergie che si accenderanno riattivandolo.
- [ ] Nessun test nuovo (sono dati inattivi); il validator che le accetta è la
      verifica.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-416: Chiusura fase 4

**Description:** Come sviluppatore, voglio che roadmap e documenti riflettano la
fase 4 chiusa e il motore delle sinergie.

**Acceptance Criteria:**

- [ ] `006_PRD/roadmap.md` sezione fase 4 → "CHIUSA", conteggio reale story e
      test, elenco: `SynergyEngine`, i 6 tipi di effetto, priorità/conflitti,
      anti-sinergie, registro, N sinergie di cui M raggiungibili.
- [ ] `006_PRD/design-master.md` Appendice C: riga per `synergy.schema.json`
      esteso (priorità, 6 effetti); Appendice A fase 4 aggiornata (P1 pagina
      registro: fatta; `sinergia_colpo_del_caso`: scritta).
- [ ] `CLAUDE.md` + `README.md`: fase 4 chiusa, conteggi, il criterio di uscita
      verificato in `test_slice_fase_4.gd`.
- [ ] Il validator ha un check di chiusura: `FASE_4_DATA` (i file nuovi della
      fase) devono esistere; un check che almeno M sinergie sono raggiungibili.
- [ ] `python tools/validate_data.py` esce 0. Tests pass.

---

## 4. Functional Requirements

- **FR-1:** `SynergyEngine` (autoload) è l'**unico** sistema che conosce le
  regole di sinergia. Legge `SynergySources.tag_sinergia_globali()`; nessuna
  fonte conosce le sinergie; nessun `if` per una sinergia specifica in
  qualsiasi file di `scripts/`.
- **FR-2:** Una sinergia è **soddisfatta** se ogni `tag: n` in `richiede_tag`
  ha `tag_globali[tag] >= n` **e** nessun `tag: n` in `esclude_tag` ha
  `tag_globali[tag] >= n`.
- **FR-3:** Una sinergia soddisfatta è **attiva** a meno che una anti-sinergia
  con `neutralizza` che la contiene sia essa stessa attiva.
- **FR-4:** `effetto.tipo == "modifica_stat"` → `{ stat, valore, moltiplicativo }`
  → modificatore per id `synergy:<id>` sullo `StatsComponent` del giocatore.
- **FR-5:** `effetto.tipo == "modifica_follia"` → `{ delta_al_minuto }` →
  contributo in `Madness` con sorgente `synergy:<id>`. Negativo = riduce.
- **FR-6:** `effetto.tipo == "modifica_qualita_crafting"` →
  `{ categoria: "pozioni"|"forgia", delta: int }` → `PotionSystem`/`Forge`
  sommano `SynergyEngine.bonus_qualita(categoria)` in `_qualita_finale`.
  **Esclusivo**: a categoria uguale, vince `priorita` più alta.
- **FR-7:** `effetto.tipo == "sblocca_ricetta"` → `{ recipe_id }` →
  `KnowledgeStore.impara("ricetta:" + recipe_id)` all'attivazione. Non si
  disimpara alla disattivazione.
- **FR-8:** `effetto.tipo == "aggiungi_abilita"` → `{ ability_id }` →
  `AbilityEngine.grant_permanente(ability_id)` mentre attiva,
  `revoca_permanente` alla disattivazione.
- **FR-9:** `effetto.tipo == "modifica_primitiva"` →
  `{ primitiva, parametro, delta, moltiplicativo }` → `AbilityEngine`
  interroga `SynergyEngine.delta_primitiva(primitiva, parametro)` prima di
  eseguire quella primitiva e applica il delta su una **copia** del dizionario
  `prim` (i dati non si toccano). Additivo (delta) o `param *= (1 + delta)`
  (moltiplicativo). Delta di più sinergie si **sommano**.
- **FR-10:** Rivalutazione: su segnale delle fonti + poll ogni ~0.5 s. I
  segnali `sinergia_attivata`/`sinergia_disattivata` si emettono solo sui
  cambi reali (diff contro l'insieme attivo precedente).
- **FR-11:** Priorità/conflitti: effetti **cumulativi** (stat, follia,
  primitiva) si sommano, `priorita` ne fissa l'ordine (stabile); effetti
  **esclusivi** (qualità crafting per categoria, sblocca_ricetta/aggiungi_
  abilita sullo stesso id) → vince `priorita` desc, poi `id` asc.
- **FR-12:** Registro: `_viste` persiste nel save (`sinergie.viste`). Le
  sinergie **attive** non si salvano — si riderivano dai tag al load.
- **FR-13:** SAVE: fase 4 bumpa `schema_version` una sola volta (19 → 20) con
  `_migra_19_a_20`. La catena da v1 resta verde (FR-18 di fase 3).
- **FR-14:** La sezione **Sinergie** è una sezione della pagina `inventario`
  (nessun nuovo `page_type`). Fog of war: `attiva` / `visibile` (coi tag
  mancanti) / `vista` (offuscata) / `ignota` (assente).
- **FR-15:** `SynergySources.tag_sinergia_globali()` esteso con la fonte
  `sequenza` (i `tags` del Pathway attivo). `ingrediente` resta nell'enum
  `fonti` ma non ha una fonte in fase 4.
- **FR-16:** Ogni sinergia ha `fonti` con `minItems: 2` (già nello schema): una
  sinergia interna a un solo sistema non attraversa i sistemi e viola il
  pilastro di design — il validator la rifiuta.
- **FR-17:** Nessuna primitiva nuova (registro 28 attive + 3 differite).
  Nessun evento nuovo (`tracked_events` a 12, `tracked_talents` a 7).
- **FR-18:** Ogni story chiude in una context window; se ne tocca più di ~4
  file o supera ~200 righe di diff, si spezza.

---

## 5. Non-Goals (Out of Scope)

- **Nessuna sinergia a tempo di craft.** `modifica_qualita_crafting` legge lo
  stato globale delle sinergie attive, non i tag degli ingredienti nella
  ricetta corrente. La fonte `ingrediente` resta non alimentata fino a fase 5+.
- **Nessuna fonte lore vera.** `scoperta: "lore"` è accettata dallo schema ma,
  senza dialoghi/libri (fase 6), quelle sinergie si scoprono solo da un
  `impara_sinergia(id)` di debug o da un drop di test.
- **Nessuna UI di "costruzione" delle sinergie.** Il giocatore non compone
  sinergie; le scopre combinando ciò che porta. La sezione libro è di sola
  lettura (fog of war), non un editor.
- **Nessun bilanciamento reale.** I `valore`/`delta`/`priorita`/`delta_al_minuto`
  sono plausibili, da riscrivere dopo il primo playtest.
- **Nessuna sinergia fra più giocatori / co-op.** Multiplayer è un non-goal di
  progetto.
- **Nessuna animazione/VFX dedicata all'attivazione.** L'evidenza è testuale
  nel registro (un marcatore per il primo render). I VFX per sinergia sono
  eventuali di fase 6.
- **Nessuna sinergia che modifica una primitiva DIFFERITA**
  (`weather_control`, `probability_shift`, `rule_bind`): il validator lo
  rifiuta (come per le abilità).
- **Nessun refactor di `SynergySources`** oltre l'aggiunta della fonte
  `sequenza`: la sua forma è di US-334.

---

## 6. Design Considerations

- **UI a libro, fog of war ovunque.** La sezione Sinergie segue il principio
  del diagramma dei Pathway e del ricettario: ciò che non hai ancora scoperto
  è offuscato o assente, non semplicemente mancante. Il registro "cresce sotto
  gli occhi" del giocatore.
- **Riuso.** Modificatori per id sullo `StatsComponent` (US-007), `Madness`
  con sorgenti nominate (US-213), `KnowledgeStore` (US-224), il pattern
  `grant` di `AbilityEngine` (US-206, gemello permanente), il diff-su-insieme
  del `TalentSystem._process` (US-331), la sezione-della-pagina-inventario
  (US-307), `GameData.tr_data` per i nomi (US-220).
- **Il motore delle primitive.** L'hook di `modifica_primitiva` è il punto più
  delicato: va in `_esegui_primitive`, opera su una **copia** del dizionario
  `prim`, e interroga una sola API (`SynergyEngine.delta_primitiva`). Se
  `SynergyEngine` non c'è (test isolati), il delta è 0 e l'abilità si comporta
  come oggi.
- **`neutralizza` esplicito.** L'appartenenza "anti-sinergia ↔ sinergia
  gemella" è un campo nei dati, non un'inferenza per set di tag: due sinergie
  possono condividere i tag senza essere l'una l'anti dell'altra.
- **Ordine stabile.** `id` lessicografico come tie-breaker ovunque
  (`recipes_per_tier` in fase 3 ha già preso questa strada): i test devono
  dare lo stesso risultato su ogni macchina.

---

## 7. Technical Considerations

- **Save.** Fase 3 finisce a `schema_version 19`. Fase 4 aggiunge **un** campo
  (`sinergie.viste`) → **v20**. Un solo bump, una `_migra_19_a_20`, un test di
  migrazione. La catena da v1 deve restare verde.
- **Autoload.** `SynergyEngine` va **dopo** tutte le fonti in `project.godot`
  (Inventory, Equipment, PetSystem, TalentSystem, BaseSystem, Progression,
  SynergySources) perché in `_ready()` si connette ai loro segnali.
- **Costo del poll.** `attive()` su ~40 sinergie è un confronto di dizionari
  piccoli: trascurabile a 2 Hz. Il diff evita di riapplicare i modificatori a
  ogni tick.
- **`grant_permanente`.** Nuovo in `AbilityEngine`: come `grant_temporary` ma
  senza entry in `_granted` con scadenza — una lista `_permanenti` per caster,
  o (più semplice) `_granted[key] = -1` come sentinella "non scade".
  `is_granted` e `can_execute` la riconoscono.
- **`SynergyEngine` senza giocatore in scena.** `attive()` e `stato_registro()`
  non richiedono un player; solo l'**applicazione** di `modifica_stat`
  richiede lo `StatsComponent` — se manca, l'effetto è registrato in
  `_attive` e applicato da `riapplica()` quando il player compare (come
  `TalentSystem`).
- **Validator: contatore delle irraggiungibili.** Con ~15 sinergie di gruppi
  differiti, N warning separati soffocano gli altri: raggrupparli in una riga
  ("N sinergie irraggiungibili: gruppi differiti, atteso — [lista]").
- **`ralph`.** Docker attivo, `prd.json` in root, `--fase 4`,
  `--test-cmd "godot --headless --script tests/run_tests.gd"`. Una story per
  iterazione. Godot 4.3 headless in locale a ogni story (regola del progetto).
- **Nessuna dipendenza nuova** (validator resta Python puro, gioco resta
  Godot 4.3).

---

## 8. Success Metrics

- **Criterio di uscita** (`test_slice_fase_4.gd`): una sinergia che richiede
  tag da **pet + stanza + talento** insieme si attiva quando le tre fonti sono
  in gioco e non prima; il suo effetto si misura; **zero righe di codice**
  nominano quella sinergia (grep, come US-219/US-335).
- Tutti e 6 i `tipo` di `effetto` hanno un test che ne verifica
  l'applicazione **e** la rimozione.
- Il validator a **0 errori**; i warning "irraggiungibile" ridotti a **una
  riga** di conteggio.
- ≥ 15 sinergie raggiungibili coi gruppi attivi; il registro nel libro le
  mostra col fog of war corretto (verifica a schermo).
- `sinergia_inganno_probabilita` non è più `stub`; `sinergia_colpo_del_caso`
  esegue senza warning di primitiva.
- Nessuna regressione: i ~498 test di fase 1-3 restano verdi. `schema_version`
  a 20 con la catena di migrazione verde.
- Nessuna primitiva nuova; `tracked_events` a 12.

---

## 9. Open Questions

1. **`modifica_primitiva` su una primitiva che il giocatore non usa mai** (es.
   una del Pathway di un altro): il delta si applica comunque quando
   quell'abilità viene eseguita (da un pet? da un oggetto?). Confermare che
   l'hook in `_esegui_primitive` copre tutti i chiamanti (`execute`,
   `execute_stored`, `esegui_primitiva`).
2. **Quante sinergie `visibile` vs `nascosta`** nel batch 1-2: troppe
   `visibile` e il registro è una lista della spesa; troppe `nascoste` e il
   giocatore non sa cosa cercare. Proposta: ~⅓ visibili (le "introduttive"),
   ⅔ nascoste. Da tarare col playtest.
3. **La sezione Sinergie rende la pagina `inventario` troppo lunga?** Con 6
   sezioni. `data/ui/book.json` ha un flag `doppia_pagina` mai usato:
   valutarlo in US-410 o rimandarlo.
4. **`aggiungi_abilita` permanente e il save**: l'abilità concessa da una
   sinergia non si salva (si riderivano dalle sinergie attive al load). Ma se
   il giocatore l'ha usata per mettere un `stored_ability_id` in un
   oggetto... quel contratto è già chiuso (US-306), l'oggetto tiene l'id. OK.
5. **Priorità come intero libero o enum** (`bassa/media/alta`)? Intero dà più
   spazio ma invita al bikeshedding dei numeri. Proposta: intero, con `0`
   default e la convenzione "anti-sinergie a `priorita: 100`" documentata.
6. **Il contatore "N/M scoperte"**: `M` conta anche le `lore` (mai
   raggiungibili senza fase 6)? Proposta: no — `M` = sinergie scopribili coi
   sistemi attivi, come il diagramma dei Pathway conta solo i gruppi attivi.
