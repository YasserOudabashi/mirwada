# PRD: Fase 3 — Sistemi di supporto

> Prerequisito: **Fase 2 chiusa** (35 story, 318 test). Save allo `schema_version 12`.
> Questo PRD si converte in `prd.json` con `/ralph` prima di implementare.

## 1. Introduzione / Overview

La fase 2 ha acceso la progressione a Pathway/Sequenze e provato che
l'architettura data-driven regge (US-219). La fase 3 costruisce i **sistemi di
supporto** attorno a quel nucleo: quello che il giocatore raccoglie, prepara,
forgia, coltiva e costruisce fra un avanzamento e l'altro.

Sono otto sottosistemi legati fra loro:

1. **Inventario ed equipaggiamento** — la base di tutto il resto
2. **Oggetti con `stored_ability_id`** — pergamene e congegni che eseguono
   un'abilità non posseduta (contratto **P0**, già annotato in
   `data/abilities/hermit.json`, motore già pronto: `AbilityEngine.execute_stored`, US-206)
3. **Alchimia** — qualità delle pozioni, fallimenti mostruosi, scoperta delle ricette
4. **Forgiatura e incisione di sigilli** — equip costruito, sigilli incastonati
5. **Oggetti Sigillati** — equip potente con un effetto collaterale sempre attivo
6. **Pet** — taming, `bond`, coltivazione del pet, la sua morte è la perdita di un'Ancora
7. **Base building** — griglia astratta, 4 stanze funzionali (laboratorio, stanza rituale, biblioteca, giardino)
8. **Talenti** — innati alla creazione, acquisiti per osservazione del comportamento

Il criterio di design non cambia: **il codice implementa primitive e sistemi;
i dati compongono il contenuto.** Nessun `if` per un oggetto o un Pathway
specifico. I vocabolari chiusi si estendono solo con discussione esplicita —
questo PRD è quella discussione per i vocabolari nuovi che dichiara.

## 2. Goals

- Chiudere il contratto **`stored_ability_id`** (P0): un oggetto porta un
  `ability_id`, l'inventario lo consuma, il motore lo esegue una volta senza costo.
- Un **inventario** data-driven, categorizzato, serializzato, i cui tag
  alimentano il motore delle sinergie di fase 4 senza che questo esista ancora.
- Un **equipaggiamento** a slot per tipo, i cui modificatori passano dai
  modificatori per id di US-007 (nessuna stat toccata direttamente).
- Un'**alchimia** con qualità esplicita nei dati, fallimenti mostruosi pesati,
  e tre modi di scoprire una ricetta (nota / sperimentata / rivelata dalla conoscenza).
- **Forgiatura e sigilli** che producono equip con tag; gli oggetti **Sigillati**
  hanno un `effetto_collaterale` sempre dichiarato nei dati, mai silenzioso.
- Un **pet** generico (taming, `bond`, coltivazione) la cui morte passa da
  `AnchorSystem.destroy` — il pet **è** un'Ancora. Il pet unico del Moon si
  aggancia a questo sistema in fase 5.
- Una **base** come griglia astratta di 4 tipi di stanza; ogni stanza dà un
  bonus **dato** al proprio sistema.
- **Talenti** innati + acquisiti: gli acquisiti sono contatori su
  `tracked_events.json` (i 12 esistenti) e su un nuovo vocabolario chiuso
  `tracked_talents.json` (~6-10 comportamenti che i 12 eventi non catturano).
- Ogni story ≤ 4 file / ≤ 200 righe di diff. Ogni story chiude in una context window.
- `python tools/validate_data.py` esce 0 dopo ogni story. Nessuna regressione
  sui 318 test di fase 2.

## 3. User Stories

Blocchi in ordine di dipendenza. **Blocco A** (inventario) sblocca tutto il resto.

---

### Blocco A — Inventario ed equipaggiamento

#### US-301: Vocabolario e schema degli item

**Description:** Come sviluppatore, voglio un formato dati chiuso per gli
oggetti, così che ingredienti, equip, sigilli, pergamene e valuta siano tutti
la stessa entità con una `categoria`.

**Acceptance Criteria:**

- [ ] `data/schema/item_categories.json`: vocabolario **chiuso** delle categorie
      (proposta: `ingrediente`, `equip`, `sigillo`, `pergamena`, `materiale`,
      `valuta`, `consumabile`). Una categoria nuova è codice: va discussa.
- [ ] `data/schema/item.schema.json` + `data/items/*.json`: ogni item con
      `id`, `categoria` (dal vocabolario), `name_i18n`, `descrizione_i18n`,
      `tag` (dal vocabolario di `data/tags.json` — chiuso), `impilabile` (bool),
      `valore` (int, per l'economia — mai una valuta speciale)
- [ ] Campi opzionali per categoria: `equip` → `slot`, `stat_modifiers`,
      `slot_sigilli` (int); `pergamena`/`consumabile` → `stored_ability_id`;
      `sigillo` → `effetto`, `effetto_collaterale`
- [ ] `GameData` carica `data/items/`: `get_item(id)`, `item_categories()`,
      `items_per_categoria(cat)`
- [ ] Almeno 12 item di esempio che coprono tutte le categorie
- [ ] Il validator: `categoria` nel vocabolario; `tag` nel vocabolario dei tag;
      `slot` (se equip) nel vocabolario degli slot (US-303); `stored_ability_id`
      (se presente) risolve a un'abilità esistente
- [ ] `python tools/validate_data.py` esce 0
- [ ] Nessuna regressione. Typecheck passes. Tests pass.

#### US-302: Autoload Inventory

**Description:** Come sviluppatore, voglio un magazzino unico degli oggetti del
giocatore, serializzato, così che ogni sistema di fase 3 legga da qui.

**Acceptance Criteria:**

- [ ] Autoload `Inventory`: `aggiungi(item_id, quantita)`, `rimuovi(item_id, quantita) -> bool`,
      `conta(item_id)`, `possiede(item_id, quantita) -> bool`, `per_categoria(cat) -> Array`,
      `tutto() -> Dictionary`
- [ ] Gli item `impilabile: false` occupano una voce ciascuno (istanze distinte,
      `instance_id`), quelli `impilabile: true` sono un contatore
- [ ] Segnali `item_aggiunto(item_id, quantita)`, `item_rimosso(item_id, quantita)`
- [ ] Nessun cap spaziale né peso (design: lista categorizzata, erbario/bestiario)
- [ ] SAVE: `schema_version` 12 → 13; campo `inventario` serializzato e riletto
      con `typeof()` + default sano (item_id ignoto scartato, mai crash);
      catena di migrazione dalla versione di fase 2
- [ ] Test headless: aggiungi/rimuovi/conta, stack vs istanze, round-trip del
      save, migrazione, `da_salvataggio` non fidato (voci malformate scartate)
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-303: Equipaggiamento a slot

**Description:** Come giocatore, voglio equipaggiare armi, armature e accessori,
e che i loro bonus contino davvero.

**Acceptance Criteria:**

- [ ] `data/schema/equip_slots.json`: vocabolario **chiuso** degli slot
      (proposta: `arma`, `armatura`, `accessorio_1`, `accessorio_2`)
- [ ] Autoload `Equipment` (o estensione di `Inventory`): `equipaggia(instance_id)`,
      `rimuovi_slot(slot)`, `equipaggiato(slot) -> item`, `slot_pieni() -> Dictionary`
- [ ] Equipaggiare consuma la voce dallo zaino; rimuoverla la restituisce
- [ ] Gli `stat_modifiers` dell'equip applicati allo `StatsComponent` del
      giocatore come modificatore **per id** (`equip:<slot>`, US-007); a ogni
      cambio di equip il vecchio si rimuove e il nuovo si applica
- [ ] SAVE: `schema_version` +1; campo `equipaggiamento` {slot → instance_id};
      migrazione
- [ ] Test headless: equip/unequip, stat_modifiers applicati e rimossi,
      round-trip, uno slot per volta
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-304: `stored_ability_id` — consumo dall'inventario (P0)

**Description:** Come giocatore, voglio usare una pergamena e far scattare
l'abilità che contiene, una volta, senza possederla.

**Acceptance Criteria:**

- [ ] `Inventory.usa(instance_id, bersaglio := null)`: se l'item ha
      `stored_ability_id`, chiama `AbilityEngine.execute_stored(stored_ability_id, giocatore)`
      (US-206) e poi **consuma** l'item (1 uso)
- [ ] Nessun costo di spiritualità né cooldown (l'abilità è dell'oggetto);
      nessun controllo di ownership
- [ ] Un item senza `stored_ability_id` passato a `usa()` → esito gestito, non crash
- [ ] `hermit_pergamena` (`data/abilities/hermit.json`) diventa un item reale in
      `data/items/` con `stored_ability_id`, e la sua `note` di stress test è
      risolta (il commento nel file di abilità si aggiorna)
- [ ] Test headless: usa pergamena → abilità eseguita → item consumato; seconda
      `usa()` sulla stessa istanza → rifiuto gestito; item non-pergamena → gestito
- [ ] Verifica a schermo documentata in `progress.txt`
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-305: Valuta come oggetto

**Description:** Come sviluppatore, voglio che il denaro sia un item
`categoria: valuta`, mai un campo speciale del giocatore (design-master cap. 5).

**Acceptance Criteria:**

- [ ] `data/items/valuta.json`: almeno una valuta (`moneta_comune`), `impilabile: true`, `valore: 1`
- [ ] `Inventory` non ha metodi speciali per la valuta: è `conta("moneta_comune")`
- [ ] Helper di lettura `Inventory.ricchezza()` = somma `conta(v) * valore(v)` su
      tutte le categorie `valuta` (comodità per la UI, non uno stato separato)
- [ ] Test headless: la valuta si aggiunge/rimuove/conta come ogni altro item;
      `ricchezza()` corretta con due tagli di valuta
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-306: Tag di inventario ed equip esposti per le sinergie

**Description:** Come sviluppatore, voglio che i tag di ciò che il giocatore
possiede ed equipaggia siano raccoglibili da un'unica API, così che il motore
delle sinergie di fase 4 ci si agganci senza riscrivere l'inventario.

**Acceptance Criteria:**

- [ ] `Inventory.tag_attivi() -> Dictionary` (tag → conteggio): somma i `tag`
      degli item **equipaggiati** e dei sigilli incastonati (US-309). Gli item
      nello zaino non contano (una sinergia è ciò che *porti addosso*)
- [ ] L'API è di sola lettura e non conosce le sinergie: è fase 4 a chiamarla
- [ ] Documentato in `006_PRD/design-master.md` (o in una nota) come una delle
      fonti di `richiede_tag` (le altre: talento, pet, stanza — US-4xx)
- [ ] Test headless: due equip con tag condiviso → conteggio 2; togliere un
      equip aggiorna il conteggio; un item nello zaino non compare
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-307: Pagina inventario del libro (P1)

**Description:** Come giocatore, voglio aprire il libro alla pagina inventario
e vedere cosa ho, cosa indosso, e poter equipaggiare / usare / incastonare.

**Acceptance Criteria:**

- [ ] La pagina `inventario` (tipo già nel vocabolario, `data/ui/book.json`)
      passa da bianca a scritta: `scenes/pages/page_inventario.tscn` +
      script, registrata in `book_overlay.PAGINE`
- [ ] Sezioni (tab o colonne): **Zaino** (item per categoria, illustrazioni
      placeholder), **Indosso** (i 4 slot equip + i sigilli incastonati),
      **Ricettario** (US-315, vuoto per ora), **Talenti** (US-330, vuoto per ora),
      **Base** (US-325, vuoto per ora)
- [ ] Azioni: equipaggia / rimuovi (US-303), usa pergamena (US-304), incastona
      sigillo (US-309)
- [ ] Tutte le stringhe di chrome da `assets/i18n/strings.csv` + `tr()`; i
      `name_i18n`/`descrizione_i18n` degli item da `GameData.tr_data`
- [ ] `tools/generate_i18n_stubs.py` gira: gli `*_i18n` degli item nuovi hanno
      voce in `data/i18n/it.json`
- [ ] Verifica a schermo documentata in `progress.txt`
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

---

### Blocco B — Alchimia

#### US-308: Ricettario, tier e qualità delle pozioni

**Description:** Come sviluppatore, voglio estendere il sistema pozioni di fase
2 con un ricettario a tre tier e una qualità esplicita.

**Acceptance Criteria:**

- [ ] `data/potions/recipes.json` + schema: ogni ricetta con `id`, `tier`
      (`base` | `avanzata` | `leggendaria`), `output` (item_id o effetto),
      `ingredienti` (item_id + quantità), `qualita_base`
- [ ] Vocabolario **chiuso** della qualità: `scarsa`, `instabile`, `pura`,
      `eccelsa`. La `penalita_parziale` di fase 2 (`formulas.json`) si mappa su
      questa scala (una pozione parziale è al più `instabile`)
- [ ] `GameData.get_recipe(id)`, `recipes_per_tier(tier)`
- [ ] Le ricette `base` sono **note dall'inizio** (`nota_da_subito: true`);
      `avanzata` si scoprono sperimentando (US-311); `leggendaria` si sbloccano
      con un flag `KnowledgeStore` (`ricetta:<id>`)
- [ ] Il validator: `tier` e `qualita_base` nei vocabolari; ogni `ingrediente`
      è un item `categoria: ingrediente` esistente; ogni `output` risolve
- [ ] Test headless: caricamento, lookup per tier, mapping parziale → instabile
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-309: Incisione dei sigilli (dipende da C — spostare dopo US-318 se serve)

> **Nota di ordine:** questa story usa i sigilli di US-317. In `prd.json` va
> messa **dopo** US-317. Tenuta qui nel blocco B solo perché la UI di US-307 la cita.

**Description:** Come giocatore, voglio incastonare un sigillo in un pezzo di
equipaggiamento per aggiungergli un effetto.

**Acceptance Criteria:**

- [ ] `Equipment.incastona(slot, sigillo_instance_id) -> bool`: fallisce se lo
      slot equip non ha `slot_sigilli` liberi
- [ ] L'`effetto` del sigillo si applica come modificatore per id
      (`sigillo:<instance_id>`) finché l'equip è indossato; l'`effetto_collaterale`
      (se presente) pure
- [ ] `Equipment.rimuovi_sigillo(slot, sigillo_instance_id)` restituisce il sigillo allo zaino
- [ ] I sigilli incastonati contano in `Inventory.tag_attivi()` (US-306)
- [ ] SAVE: i sigilli incastonati serializzati nell'equipaggiamento; migrazione
- [ ] Test headless: incastona fino al limite di slot, il 4° fallisce; effetto e
      collaterale applicati/rimossi con l'equip; round-trip
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-310: Concoction v2 — qualità, laboratorio, output nell'inventario

**Description:** Come giocatore, voglio preparare una pozione da una ricetta
nota e ottenere un item nell'inventario con una qualità.

**Acceptance Criteria:**

- [ ] `PotionSystem.prepara(recipe_id) -> {ok, item_instance, qualita}`: verifica
      ricetta nota + ingredienti in `Inventory`, consuma gli ingredienti, produce
      un item `categoria: consumabile` con `qualita` calcolata
- [ ] Qualità = `qualita_base` della ricetta + bonus del **laboratorio** (US-326)
      + bonus dei **talenti** di alchimia (US-329) − malus se ingredienti scadenti
- [ ] La concoction di **avanzamento** di fase 2 (`PotionSystem.concoct` +
      `bevi`) resta invariata: questa è la preparazione di pozioni *consumabili*,
      un percorso separato e documentato
- [ ] Test headless: prepara con ricetta nota → item in inventario con qualità;
      ricetta ignota → rifiuto; ingredienti mancanti → rifiuto, niente consumo
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-311: Sperimentazione e scoperta delle ricette

**Description:** Come giocatore, voglio combinare ingredienti a caso e a volte
scoprire una ricetta nuova.

**Acceptance Criteria:**

- [ ] `PotionSystem.sperimenta(ingredienti: Array) -> {esito, ...}`: se la
      combinazione (multiset di item_id) corrisponde a una ricetta `avanzata`
      non ancora nota → **scoperta**: la ricetta entra nel ricettario
      (`KnowledgeStore` flag `ricetta:<id>`), la pozione è prodotta
- [ ] Se non corrisponde a nessuna ricetta → **fallimento**: esito pesato da
      `data/potions/experiment_outcomes.json` (vocabolario chiuso: `fumo` (niente),
      `scarto` (item spazzatura), `ustione` (danno), `contaminazione` (follia),
      `aberrazione` (US-312))
- [ ] Il peso del fallimento mostruoso scende col **laboratorio** e coi
      **talenti**; sale con la **follia** alta (`Foundation.moltiplicatore_follia`)
- [ ] Gli ingredienti si consumano sempre (anche sul fallimento)
- [ ] RNG seedabile per test deterministici
- [ ] Test headless: combinazione = ricetta avanzata → scoperta + flag; combinazione
      ignota con seed → fallimento atteso; laboratorio riduce il peso mostruoso
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-312: Fallimenti mostruosi — l'aberrazione

**Description:** Come giocatore, voglio che un esperimento andato malissimo
evochi qualcosa di ostile.

**Acceptance Criteria:**

- [ ] L'esito `aberrazione` di US-311 evoca un'entità ostile temporanea via
      `SummonRegistry` (durata > 0, `entita_id: "aberrazione_alchemica"`,
      `comportamento: ostile`), aggiunge follia, e degrada le fondamenta
- [ ] I numeri (hp dell'aberrazione, follia, malus fondamenta) sono in
      `balance.json` (nuova sezione `alchimia`)
- [ ] L'aberrazione **non** è persistente: scade e non entra nel save
- [ ] Test headless: forzare `aberrazione` → 1 evocazione ostile temporanea +
      follia salita + fondamenta scese; l'evocazione scade
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-313: Ricette leggendarie via conoscenza

**Description:** Come giocatore, voglio imparare una ricetta rara leggendo un
tomo o comprandola da Sidon.

**Acceptance Criteria:**

- [ ] Una ricetta `leggendaria` è utilizzabile solo se `KnowledgeStore.conosce("ricetta:<id>")`
- [ ] Un item `categoria: pergamena` con campo `insegna_ricetta: <recipe_id>`:
      `Inventory.usa()` su di esso → `KnowledgeStore.impara("ricetta:<id>")` + consuma
- [ ] Il validator: ogni `insegna_ricetta` risolve a una ricetta `leggendaria`
- [ ] Test headless: `prepara(leggendaria)` senza flag → rifiuto; usa la
      pergamena → flag → `prepara` riesce
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-314: Il ricettario nel libro

**Description:** Come giocatore, voglio sfogliare le ricette che conosco, con
quelle ignote annotate come "?".

**Acceptance Criteria:**

- [ ] La sezione **Ricettario** della pagina inventario (US-307) elenca: ricette
      `base` (sempre), `avanzata` scoperte, `leggendaria` apprese
- [ ] Le ricette non note esistono come righe **offuscate** ("ricetta
      sconosciuta", numero di ingredienti visibile) — non assenti (stesso
      principio del fog of war del diagramma)
- [ ] Da una ricetta nota: pulsante "prepara" (US-310) se gli ingredienti ci sono
- [ ] Verifica a schermo documentata in `progress.txt`
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

---

### Blocco C — Forgiatura e sigilli

#### US-315: Schema dei sigilli

**Description:** Come sviluppatore, voglio un formato dati per i sigilli: cosa
fanno e cosa costano.

**Acceptance Criteria:**

- [ ] `data/sigils/*.json` + `data/schema/sigil.schema.json`: ogni sigillo con
      `id`, `name_i18n`, `tag`, `effetto` (uno di: `stat_modifier`
      {stat, valore, moltiplicativo}, `stored_ability_id`, `tag_grant`),
      `effetto_collaterale` (opzionale, stessa forma, sempre negativo)
- [ ] Vocabolario **chiuso** dei tipi di `effetto` e `effetto_collaterale`
- [ ] I sigilli sono item `categoria: sigillo` (US-301): il file `data/sigils/`
      è la definizione dell'effetto, `data/items/` la voce d'inventario che lo referenzia
- [ ] Almeno 8 sigilli, di cui ≥ 2 con `effetto_collaterale`
- [ ] Il validator: `effetto`/`effetto_collaterale` nel vocabolario; stat note;
      `stored_ability_id` risolve; `effetto_collaterale` è sempre uno svantaggio
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-316: Forgiatura dell'equipaggiamento

**Description:** Come giocatore, voglio combinare materiali per forgiare un
pezzo di equipaggiamento.

**Acceptance Criteria:**

- [ ] `data/forge/blueprints.json` + schema: ogni blueprint con `id`,
      `output` (equip item_id), `materiali` (item_id `categoria: materiale` + quantità),
      `qualita_base`, `nota_da_subito` / gating come le ricette
- [ ] Autoload `Forge` (o parte di un `CraftingSystem` condiviso con l'alchimia):
      `forgia(blueprint_id) -> {ok, item_instance, qualita}`
- [ ] La qualità dell'equip forgiato scala coi **materiali**, con la **stanza
      rituale/fucina** (US-326) e coi **talenti** di forgiatura
- [ ] Un equip forgiato ha i `tag` del blueprint (contano nelle sinergie una
      volta equipaggiato)
- [ ] Test headless: forgia con materiali → equip in inventario; materiali
      mancanti → rifiuto senza consumo; qualità sale col bonus della stanza
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-317: Incisione dei sigilli sull'equip

> Motore già descritto in **US-309**. Questa story implementa e testa; US-309
> nel `prd.json` è la stessa story riordinata dopo US-315/316 — **fondere le due
> in una sola voce** al momento della conversione con `/ralph`.

**Description:** vedi US-309.

**Acceptance Criteria:** vedi US-309.

#### US-318: Oggetti Sigillati

**Description:** Come giocatore, voglio maneggiare equip Sigillato: molto
potente, ma con un prezzo sempre pagato.

**Acceptance Criteria:**

- [ ] Un item `equip` con campo `sigillato: true` porta un `effetto_collaterale`
      di livello alto (follia al secondo, drain di spiritualità, un tag negativo
      che attira nemici, ...) **sempre attivo mentre è indossato**, dichiarato nei dati
- [ ] `Equipment` applica l'`effetto_collaterale` del Sigillato come un
      `_pending` persistente (kind dedicato) finché è equipaggiato; lo toglie
      alla rimozione
- [ ] Almeno 3 equip Sigillati di esempio con trade-off netti
- [ ] Il validator: un `equip` `sigillato: true` **deve** avere un
      `effetto_collaterale` non vuoto (un Sigillato senza prezzo è un bug di dati)
- [ ] Test headless: equipaggia un Sigillato → l'effetto collaterale tick
      (es. follia sale); rimuovilo → si ferma
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

---

### Blocco D — Strutture (contratto design-master cap. 5)

#### US-319: StructureRegistry

**Description:** Come sviluppatore, voglio un registro delle strutture
costruite, così che `tg_2` (che le distrugge) e il base building (che le crea)
parlino la stessa lingua.

**Acceptance Criteria:**

- [ ] `data/schema/structure.schema.json` + `data/structures/*.json`: ogni tipo
      di struttura con `id`, `hp_max`, `tag`, `name_i18n`
- [ ] Autoload `StructureRegistry`: `costruisci(struct_id, posizione)`,
      `danneggia(instance_id, quantita)`, `distruggi(instance_id, volontario: bool)`,
      `attive()`. `distruggi` emette `EventTracker.emit_event("structure_destroyed", {volontario})`
      (evento **già** nel vocabolario dei 12)
- [ ] Le strutture attive nel save (`schema_version` +1; migrazione)
- [ ] Test headless: costruisci → attiva; danneggia fino a 0 → distrutta +
      evento; `structure_destroyed{volontario:true}` contato quando `distruggi(..., true)`
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-320: `colpisce_oggetti` — le abilità danneggiano le strutture

**Description:** Come giocatore, voglio che `tg_crepuscolo` (che ha
`colpisce_oggetti: true`) possa davvero rompere una struttura.

**Acceptance Criteria:**

- [ ] Le primitive d'area con `colpisce_oggetti: true` (`decay`, e ogni altra
      che lo dichiara nel registro) cercano anche le strutture in raggio via
      `StructureRegistry` e chiamano `danneggia`
- [ ] Le strutture del giocatore non vengono colpite dalle proprie abilità
      (o sì, se il design lo vuole — decidere e documentare)
- [ ] L'`acting_action` `tg_2_accetta_decadimento` ("lascia decadere una
      struttura tua") si riempie da gioco reale (`structure_destroyed{volontario:true}`)
- [ ] Test headless: `decay` con `colpisce_oggetti` in raggio di una struttura →
      la struttura perde hp; fuori raggio → intatta
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

---

### Blocco E — Pet

#### US-321: Schema e magazzino dei pet

**Description:** Come sviluppatore, voglio un formato dati per i pet e un posto
dove tenere quello del giocatore.

**Acceptance Criteria:**

- [ ] `data/pets/*.json` + `data/schema/pet.schema.json`: ogni specie con `id`,
      `name_i18n`, `hp_max`, `sequenza_iniziale` (il pet ha la sua coltivazione),
      `comportamenti` (sbloccati per soglia di `bond`), `abilita` (ability_id
      che il pet può eseguire), `domabilita` (probabilità base di taming),
      `ancora_id` (il pet **è** un'Ancora: `data/anchors.json` deve avere la voce)
- [ ] Autoload `PetSystem`: `pet_attivo() -> Dictionary` ({} se nessuno),
      `imposta_pet(pet_id)`, `bond()`, `sequenza_pet()`
- [ ] SAVE: `schema_version` +1; campo `pet` {pet_id, bond, hp, sequenza};
      migrazione
- [ ] Il validator: `ancora_id` esiste in `data/anchors.json`; `abilita`
      risolvono; `sequenza_iniziale` in [0,9]
- [ ] Test headless: caricamento, imposta/leggi pet, round-trip del save
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-322: Taming

**Description:** Come giocatore, voglio domare una creatura e renderla il mio pet.

**Acceptance Criteria:**

- [ ] `PetSystem.doma(pet_id) -> bool`: tiro contro `domabilita` (+ bonus da
      talenti/oggetti), su successo `imposta_pet` + `AnchorSystem.register(ancora_id)`
      (il pet entra come Ancora — riduce la follia come le altre)
- [ ] Un solo pet per volta: domare un secondo richiede prima di **liberare** il
      primo (`libera()` → `AnchorSystem.destroy`? no: liberare non è un colpo di
      follia come la morte — decidere: `AnchorSystem` con un flag "rilascio pulito"
      che non aggiunge penalità)
- [ ] RNG seedabile
- [ ] Test headless: doma con seed fortunato → pet impostato + Ancora attiva;
      seed sfortunato → nessun pet; secondo taming bloccato finché non liberi
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-323: `bond` — il legame cresce dalle azioni condivise

**Description:** Come giocatore, voglio che combattere e viaggiare col pet
rafforzi il legame, e che il legame sblocchi cose.

**Acceptance Criteria:**

- [ ] `bond` 0..100. Sale ascoltando `EventTracker`: `enemy_defeated` mentre il
      pet è evocato, `area_cleared`, `time_in_state` "esplorazione"… (contatori,
      come l'Acting Method). I pesi in `balance.json`
- [ ] A soglie di `bond` (dato per specie) si sbloccano `comportamenti` (es.
      "raccoglie ingredienti", "avvisa dei nemici fuori schermo") e l'accesso
      alle `abilita` del pet
- [ ] Segnale `bond_cambiato(valore, soglia_attraversata)`
- [ ] Test headless: eventi condivisi → bond sale; a soglia → comportamento
      sbloccato + segnale; il bond persiste nel save
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-324: Coltivazione del pet

**Description:** Come giocatore, voglio che anche il pet avanzi di Sequenza.

**Acceptance Criteria:**

- [ ] `PetSystem.avanza_pet() -> bool`: il pet sale di Sequenza (9→0) se
      `bond >= soglia_avanzamento` **e** si consuma una risorsa dedicata
      (proposta: una pozione `categoria: consumabile` con `nutre_pet: true`, o
      un ingrediente raro) — la scelta è un dato
- [ ] Avanzare il pet ne migliora `hp_max` e gli `stat`/abilità secondo
      `data/pets/` (curve nel file della specie, non nel codice)
- [ ] Il pet non può superare la Sequenza del giocatore (vincolo di design:
      il pet non supera il padrone)
- [ ] Test headless: bond alto + risorsa → avanza; bond basso → rifiuto; cap
      alla Sequenza del giocatore
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-325: La morte del pet è la perdita di un'Ancora

**Description:** Come giocatore, voglio che perdere il pet sia un colpo vero,
non solo un inconveniente.

**Acceptance Criteria:**

- [ ] `PetSystem.morte()`: `AnchorSystem.destroy(ancora_id)` → segnale
      `anchor_lost` + follia aggiunta (non bufferizzata), come per ogni Ancora
      (US-216); `pet_attivo()` torna {}
- [ ] Lo `SummonRegistry` rimuove l'istanza evocata del pet
- [ ] Il pet morto **non** si ricrea al load; lo slot `pet` del save si svuota
- [ ] I sussurri di soglia 55 (US-214) smettono di usare il nome del pet
- [ ] Test headless: morte → Ancora distrutta + follia su + slot pet vuoto +
      persiste vuoto nel save
- [ ] Verifica a schermo documentata in `progress.txt`
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

---

### Blocco F — Base building

#### US-326: Schema della base e delle 4 stanze

**Description:** Come sviluppatore, voglio una griglia astratta di stanze e i
loro bonus, tutto nei dati.

**Acceptance Criteria:**

- [ ] `data/schema/room_types.json`: vocabolario **chiuso** dei 4 tipi
      (`laboratorio`, `stanza_rituale`, `biblioteca`, `giardino`)
- [ ] `data/base/rooms.json` + schema: per ogni tipo di stanza, i **livelli**
      (1..N) con `costo` (item_id + quantità), `bonus` (oggetto dato — es.
      laboratorio livello 2 → `{rischio_esperimento: -0.15, qualita_pozione: +1}`)
- [ ] `GameData.get_room_type(tipo)`, `room_levels(tipo)`
- [ ] Autoload `BaseSystem`: `costruisci(tipo)`, `potenzia(tipo)`,
      `livello(tipo) -> int` (0 = non costruita), `bonus(tipo) -> Dictionary`
- [ ] SAVE: `schema_version` +1; campo `base` {tipo → livello}; migrazione
- [ ] Il validator: ogni `costo` referenzia item esistenti; `bonus` è un oggetto
      di chiavi note (vocabolario dei bonus per stanza)
- [ ] Test headless: costruisci → livello 1; potenzia → livello 2 + costo
      consumato; `bonus` corretto per livello; round-trip
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-327: Le stanze alimentano i loro sistemi

**Description:** Come giocatore, voglio che costruire il laboratorio renda
davvero l'alchimia meno pericolosa.

**Acceptance Criteria:**

- [ ] `PotionSystem` (US-310/311) legge `BaseSystem.bonus("laboratorio")`:
      `rischio_esperimento` riduce il peso dei fallimenti mostruosi,
      `qualita_pozione` alza la qualità
- [ ] `Forge` (US-316) legge `BaseSystem.bonus("stanza_rituale")`:
      `qualita_forgia`; `RitualSystem` (fase 2) legge un eventuale bonus di build
- [ ] `KnowledgeStore` / TalentSystem: la `biblioteca` sblocca ricette o talenti
      (proposta: livello biblioteca ≥ N rende note certe ricette `avanzata` senza sperimentare)
- [ ] `giardino`: vedi US-328
- [ ] Nessun sistema hardcoda il nome di una stanza in un `if` di caso speciale:
      legge `bonus(tipo)` per chiave
- [ ] Test headless: laboratorio livello 2 → `sperimenta` mostra un peso
      mostruoso più basso; senza laboratorio, peso pieno
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-328: Il giardino — ingredienti che crescono nel tempo

**Description:** Come giocatore, voglio piantare un ingrediente nel giardino e
raccoglierne di più dopo un po'.

**Acceptance Criteria:**

- [ ] `BaseSystem` (giardino): `pianta(item_id)` in uno degli `appezzamenti`
      (numero = livello del giardino); dopo `tempo_crescita` (tick di gioco, in
      `balance.json`) l'appezzamento è `pronto`; `raccogli(appezzamento)` →
      N item nell'inventario (resa scala col livello)
- [ ] Solo item `categoria: ingrediente` con campo `coltivabile: true`
- [ ] La crescita avanza col tempo di gioco (`GameState.tempo_gioco` o un tick
      dedicato), **non** in tempo reale wall-clock; si ferma col mondo in pausa
      (libro aperto)
- [ ] SAVE: gli appezzamenti (item piantato + istante di maturazione) nel save
- [ ] `plant_growth` (primitiva, attiva-non-implementata) **non** si tocca: è
      per le abilità del Mother (fase 5). Il giardino è un sistema data-driven a parte
- [ ] Test headless: pianta → non pronto; avanza il tempo oltre `tempo_crescita`
      → pronto; raccogli → item in inventario; round-trip a metà crescita
- [ ] Verifica a schermo documentata in `progress.txt`
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-329: La base nel libro

**Description:** Come giocatore, voglio gestire le stanze dalla pagina inventario.

**Acceptance Criteria:**

- [ ] La sezione **Base** della pagina inventario (US-307): le 4 stanze col
      livello, il costo del prossimo potenziamento, il bonus attuale; pulsanti
      costruisci / potenzia se il costo è coperto
- [ ] Il giardino mostra gli appezzamenti (vuoto / in crescita con conto alla
      rovescia / pronto) e il pulsante raccogli
- [ ] Tutte le stringhe da `strings.csv` + `tr()`; i `name_i18n` da `tr_data`
- [ ] Verifica a schermo documentata in `progress.txt`
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

---

### Blocco G — Talenti

#### US-330: Schema dei talenti e vocabolario dei comportamenti

**Description:** Come sviluppatore, voglio un formato per i talenti e un
vocabolario **chiuso** dei comportamenti che i 12 eventi non catturano.

**Acceptance Criteria:**

- [ ] `data/schema/tracked_talents.json`: vocabolario **chiuso** di ~6-10
      "comportamenti-talento" (proposta: `giocato_di_notte` (secondi),
      `sequenze_senza_pozione` (conteggio), `nemici_risparmiati` (conteggio),
      `distanza_percorsa` (somma), `ingredienti_coltivati` (conteggio),
      `abilita_prestate_usate` (conteggio), `rituali_interrotti` (conteggio)).
      Ogni voce: `misura` (conteggio/somma/secondi), `filtri` ammessi
- [ ] `data/talents/*.json` + `data/schema/talent.schema.json`: ogni talento con
      `id`, `name_i18n`, `descrizione_i18n`, `tipo` (`innato` | `acquisito`),
      `sblocco` (per gli acquisiti: `{evento, filtri, target}` — l'evento può
      essere uno dei 12 di `tracked_events.json` **o** uno di `tracked_talents.json`),
      `effetto` (modificatore per id, o `tag_grant`, o sblocco di sistema)
- [ ] `GameData` carica entrambi: `get_talent(id)`, `tracked_talents()`, `talents_per_tipo(tipo)`
- [ ] Il validator: `sblocco.evento` in uno dei due vocabolari; filtri ammessi;
      `effetto` ben formato; ≥ 4 innati e ≥ 8 acquisiti
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-331: TalentSystem + emettitori dei nuovi comportamenti

**Description:** Come sviluppatore, voglio contare i comportamenti-talento e
sbloccare i talenti a soglia.

**Acceptance Criteria:**

- [ ] Autoload `TalentTracker` (o estensione di `EventTracker`): conta gli eventi
      di `tracked_talents.json`. Gli emettitori sono agganciati ai sistemi
      esistenti con adattamento **minimo** (1-4 righe a file): `giocato_di_notte`
      dal ciclo del tempo (o da un gancio placeholder finché fase 6), `distanza_percorsa`
      da `player.gd`, `ingredienti_coltivati` dal giardino, ecc.
- [ ] Autoload `TalentSystem`: `posseduti() -> Array`, `possiede(id) -> bool`;
      `_process` (o su segnale) controlla gli `sblocco` degli `acquisiti` non
      ancora posseduti contro i conteggi di `EventTracker` + `TalentTracker`
- [ ] Talento sbloccato → `effetto` applicato (modificatore per id `talent:<id>`
      sullo StatsComponent, o `tag_grant`, o chiamata di sblocco al sistema
      relativo) + segnale `talento_sbloccato(id)`
- [ ] SAVE: `schema_version` +1; campo `talenti` {posseduti, log dei comportamenti};
      migrazione
- [ ] Test headless: comportamento oltre soglia → talento sbloccato + effetto +
      segnale; sotto soglia → niente; persistenza
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-332: Talenti innati alla creazione personaggio

**Description:** Come giocatore, alla creazione del personaggio voglio scegliere
1-2 talenti innati che mi accompagnano tutta la partita.

**Acceptance Criteria:**

- [ ] La pagina `creazione_personaggio` (US-223) si estende: sotto il nome, una
      scelta di **1-2 talenti `innato`** da `data/talents/` (il numero è un dato
      in `balance.json`)
- [ ] `GameState.nuova_partita(nome, slot, talenti_innati: Array)`: i talenti
      innati entrano in `TalentSystem` e sono serializzati come gli altri
- [ ] La pagina identità (partita in corso) mostra i talenti posseduti
- [ ] Tutte le stringhe da i18n
- [ ] Verifica a schermo documentata in `progress.txt`
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-333: La sezione talenti nel libro

**Description:** Come giocatore, voglio vedere i talenti che ho e quanto manca a
quelli che sto per sbloccare.

**Acceptance Criteria:**

- [ ] La sezione **Talenti** della pagina inventario (US-307): posseduti (con
      effetto), + gli `acquisiti` non ancora presi come righe con una **barra di
      progresso** (`count / target` dello `sblocco`)
- [ ] Gli `acquisiti` di cui il giocatore non ha ancora visto nessun progresso
      sono offuscati (non sai cosa non hai ancora iniziato a fare)
- [ ] Verifica a schermo documentata in `progress.txt`
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

---

### Blocco H — Integrazione e chiusura

#### US-334: Il pet e i talenti come fonti di sinergia

**Description:** Come sviluppatore, voglio che pet, talenti e stanze espongano i
loro tag come fa l'inventario (US-306), così che fase 4 li componga.

**Acceptance Criteria:**

- [ ] `PetSystem.tag_attivi()` (i `tag` della specie + dei comportamenti
      sbloccati), `TalentSystem.tag_attivi()` (i `tag_grant` dei talenti
      posseduti), `BaseSystem.tag_attivi()` (i tag delle stanze costruite)
- [ ] Un'API unica `tag_sinergia_globali() -> Dictionary` (in un piccolo
      autoload `SynergySources` o come metodo statico) che somma: inventario
      equipaggiato + sigilli + pet + talenti + stanze. **Non** risolve sinergie:
      è la materia prima di fase 4
- [ ] Le 3 sinergie di esempio in `data/synergies/core.json` (`crescita_pozione`
      da stanza+ingrediente+pet, ecc.) diventano **raggiungibili** con questi tag
      (il warning "irraggiungibile" del validator sparisce per `sinergia_crescita_pozione`)
- [ ] Test headless: un pet + una stanza + un talento coi tag giusti →
      `tag_sinergia_globali()` li somma; `sinergia_crescita_pozione` non è più
      segnalata come irraggiungibile
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-335: Vertical slice della fase 3

**Description:** Come sviluppatore, voglio la prova che i sistemi di supporto
compongono senza codice dedicato: un ciclo di crafting completo, in un test.

**Acceptance Criteria:**

- [ ] Un test headless `test_slice_fase_3.gd` che, in codice:
      1. costruisce il **giardino**, pianta un `coltivabile`, avanza il tempo, raccoglie
      2. costruisce il **laboratorio**, **sperimenta** una combinazione = ricetta
         `avanzata` → scoperta, prepara la pozione (qualità migliorata dal laboratorio)
      3. **forgia** un equip da materiali, lo equipaggia
      4. **incastona** un sigillo con `effetto_collaterale`, verifica effetto + collaterale
      5. **doma** un pet (seed fortunato), il `bond` sale con un `enemy_defeated`
         simulato, si sblocca un comportamento
      6. un **talento acquisito** si sblocca superando la soglia di un comportamento
      7. `SynergySources.tag_sinergia_globali()` contiene i tag di tutte le fonti
- [ ] `grep` di `scripts/` per nomi di item/ricette/pet/stanze specifici: zero
      occorrenze (nessun `if` per un contenuto), assertito da un test o dalla CI
      (come US-219)
- [ ] `progress.txt` documenta l'esito: l'architettura di fase 3 regge / va corretta
- [ ] Nessuna regressione sui 318 test di fase 2. Typecheck passes. Tests pass.

#### US-336: Aggiornamento roadmap e validator di chiusura

**Description:** Come sviluppatore, voglio che roadmap e documenti riflettano la
fase 3 chiusa e i vocabolari nuovi.

**Acceptance Criteria:**

- [ ] `006_PRD/roadmap.md`: sezione fase 3 aggiornata al conteggio reale delle
      story; i vocabolari nuovi elencati (come l'Appendice C di design-master)
- [ ] `006_PRD/design-master.md` Appendice C: righe nuove per
      `item_categories`, `equip_slots`, `room_types`, `tracked_talents`,
      `sigil effetti`, `experiment_outcomes`
- [ ] `CLAUDE.md` + `README.md`: fase 3 chiusa, conteggio story e test
- [ ] Il validator ha un check per ogni file di dati nuovo introdotto nella fase
- [ ] `python tools/validate_data.py` esce 0. Tests pass.

## 4. Functional Requirements

- **FR-1:** Ogni oggetto del gioco è un'entità `data/items/*.json` con una
  `categoria` da un vocabolario chiuso. Nessun oggetto è un caso speciale nel codice.
- **FR-2:** `Inventory` è l'unico magazzino. Nessun sistema tiene una propria
  lista di oggetti. Serializzato nel save con lettura non fidata.
- **FR-3:** I bonus di equip, sigilli, talenti e stanze si applicano **solo**
  come modificatori per id sullo `StatsComponent` (US-007) o come `tag_grant`.
  Mai una scrittura diretta su una stat.
- **FR-4:** `stored_ability_id` su un item + `Inventory.usa()` → `AbilityEngine.execute_stored`
  (già esistente) + consumo. Nessun costo, nessun cooldown, nessun controllo di ownership.
- **FR-5:** La valuta è un item `categoria: valuta`. `Inventory` non ha metodi
  dedicati al denaro oltre a un helper di sola lettura `ricchezza()`.
- **FR-6:** Le ricette hanno tre tier: `base` (note da subito), `avanzata`
  (scoperte sperimentando), `leggendaria` (sbloccate da un flag `KnowledgeStore`).
- **FR-7:** Sperimentare una combinazione ignota consuma sempre gli ingredienti
  e produce un esito da `experiment_outcomes.json` (vocabolario chiuso), pesato
  da laboratorio, talenti e follia.
- **FR-8:** Un item `equip` con `sigillato: true` **deve** dichiarare un
  `effetto_collaterale` non vuoto. Il validator lo impone.
- **FR-9:** `StructureRegistry.distruggi(..., volontario)` emette l'evento
  `structure_destroyed` (dei 12 esistenti) con il filtro `volontario`.
- **FR-10:** Il pet **è** un'Ancora (`ancora_id` obbligatorio, deve esistere in
  `data/anchors.json`). La sua morte passa da `AnchorSystem.destroy` → colpo di follia.
- **FR-11:** Il pet non supera mai la Sequenza del giocatore.
- **FR-12:** Le 4 stanze sono un vocabolario chiuso. Ogni stanza espone
  `bonus(tipo) -> Dictionary`; i sistemi leggono per chiave, mai con un `if` sul nome.
- **FR-13:** Il giardino cresce col **tempo di gioco**, non wall-clock, e si
  ferma col mondo in pausa. `plant_growth` (primitiva) non viene toccata.
- **FR-14:** I talenti acquisiti si sbloccano contando eventi di
  `tracked_events.json` (12, invariato) **o** di `tracked_talents.json` (nuovo,
  ~6-10, chiuso). Nessun nuovo evento in `tracked_events.json`.
- **FR-15:** I talenti innati si scelgono alla creazione personaggio (1-2, il
  numero è un dato) e vivono in `TalentSystem` come gli acquisiti.
- **FR-16:** Inventario/equip, sigilli, pet, talenti e stanze espongono
  `tag_attivi()`; `SynergySources.tag_sinergia_globali()` li somma per fase 4.
  Nessuno di questi sistemi conosce le sinergie.
- **FR-17:** La pagina `inventario` del libro (tipo già nel vocabolario chiuso)
  ospita **tutte** le sezioni di fase 3 (zaino, indosso, ricettario, talenti,
  base). Nessun nuovo `page_type`.
- **FR-18:** Ogni story bumpa al più una volta lo `schema_version` del save e
  aggiunge una funzione di migrazione. La catena di migrazione da v1 resta verde.

## 5. Non-Goals (Out of Scope)

- **Nessuna scena fisica della base.** La base è una griglia astratta + una
  sezione del libro. La base visitabile (e la mappa, e le regioni) è **fase 6**.
- **Nessun pet che segue il giocatore in `main.tscn`** come nodo reale. Il pet
  è un'entità nel save + (quando serve) un'evocazione via `SummonRegistry`. Il
  compagno che cammina accanto a te è fase 6.
- **Il pet unico del Moon** non si scrive qui. Fase 3 costruisce il sistema
  generico; Moon ci si aggancia in fase 5 con la sua specie.
- **Nessuna nuova primitiva.** Il registro resta a 28 attive + 3 differite.
  `plant_growth`, `steal`, `resurrect`, `bond` (che non è una primitiva) restano
  come sono.
- **Nessun nuovo evento in `tracked_events.json`.** I comportamenti-talento
  vivono nel vocabolario separato `tracked_talents.json`.
- **Nessun mercato / NPC / dialoghi.** Sidon, i listini e il motore dialoghi
  sono **fase 6**. Fase 3 rende la valuta un item e prepara il terreno; le
  pergamene che insegnano ricette si trovano "a terra" (drop di test) finché non
  c'è un venditore.
- **Nessun bilanciamento reale.** Tutti i numeri (qualità, pesi dei fallimenti,
  costi delle stanze, soglie di bond) sono plausibili, in `balance.json`, da
  riscrivere dopo il primo playtest.
- **Nessuna economia chiusa** (produzione/consumo bilanciati). Fase 6.

## 6. Design Considerations

- **UI a libro.** Ogni schermata è una sezione della pagina `inventario`. Stile
  erbario/bestiario: oggetti come illustrazioni placeholder raggruppate. Le
  stringhe di chrome vanno in `assets/i18n/strings.csv` + `tr()`; i nomi/le
  descrizioni dei dati in `data/i18n/` + `GameData.tr_data` (convenzione di US-220).
- **Fog of war ovunque.** Ricette non note, talenti non iniziati, comportamenti
  del pet non sbloccati: **offuscati, non assenti** — lo stesso principio del
  diagramma dei Pathway. Il libro cresce sotto gli occhi del giocatore.
- **Riuso.** `AbilityEngine.execute_stored` (US-206), i modificatori per id
  (US-007), `SummonRegistry` (US-205), `AnchorSystem` (US-216), `KnowledgeStore`
  (US-224), `EventTracker` (US-210), la lista `_pending` di `AbilityEngine` per
  gli effetti a tempo (mai `await`). Il pattern "contatore su eventi filtrati"
  dell'Acting Method si ripete per `bond` e per i talenti acquisiti.
- **Un `CraftingSystem` condiviso?** Alchimia e forgiatura hanno la stessa forma
  (ricetta/blueprint + ingredienti + qualità + bonus di stanza). Valutare in
  US-316 se estrarre un motore comune o tenerli separati (ponytail: separati
  finché la duplicazione non fa male).

## 7. Technical Considerations

- **Save.** Fase 2 finisce a `schema_version 12`. Fase 3 aggiunge ~8 campi
  (`inventario`, `equipaggiamento`, `strutture`, `pet`, `base`, `talenti`, +
  ricette scoperte in `conoscenza` già esistente). ~8 bump → v20 circa. Ogni
  bump ha la sua `_migra_N_a_N+1` e il suo test; la catena da v1 deve restare verde.
- **Ordine in `prd.json`.** Blocco A prima di tutto. US-309/317 (sigilli su
  equip) vanno dopo US-315 (schema sigilli): **fondere in una story** alla
  conversione. US-320 dopo US-319. Il resto dei blocchi è largamente parallelo;
  il blocco H per ultimo.
- **`ralph`.** Docker Desktop attivo, `prd.json` in root, `--fase 3`,
  `--test-cmd "godot --headless --script tests/run_tests.gd"` (obbligatorio,
  vedi README). Una story per iterazione.
- **Nessuna dipendenza esterna nuova** per il validator (resta Python puro) né
  per il gioco (Godot 4.3 + i placeholder).
- **Verifica a schermo** per ogni story con UI: finestra reale, script usa e
  getta, screenshot in `user://`, come tutta la fase 2.

## 8. Success Metrics

- Il contratto `stored_ability_id` è chiuso: una pergamena si usa e l'abilità
  scatta (P0 della roadmap).
- La pagina inventario del libro non è più bianca (P1 della roadmap).
- La vertical slice (US-335) passa: crafting, pet, talenti e stanze compongono
  con **zero righe di codice dedicate a un contenuto specifico**.
- Il warning "sinergia irraggiungibile" del validator sparisce per
  `sinergia_crescita_pozione` (fase 4 ha le sue fonti di tag).
- 318 test di fase 2 ancora verdi; ~40-55 test nuovi. Validator a 0.
- Nessuna primitiva aggiunta. `tracked_events.json` invariato a 12 voci.
- Al checkpoint di **fase 5**: aggiungere i 9 Pathway richiede dati, non codice —
  e i sistemi di fase 3 (evocazioni per Death/Paragon/Moon/Mother, oggetti per
  Hermit) sono pronti a riceverli.

## 9. Open Questions

1. **Un `CraftingSystem` unico** per alchimia + forgiatura, o due sistemi
   separati? (Decidere in US-316. Raccomandazione: separati finché la
   duplicazione non supera ~30 righe.)
2. **Liberare un pet** vs. **perderlo**: liberare non dovrebbe essere un colpo
   di follia come la morte. `AnchorSystem` ha bisogno di un `destroy` "pulito"
   (senza penalità) oltre a quello brutale? (Proposta in US-322: sì, un flag.)
3. **La biblioteca sblocca ricette o talenti?** (US-327 propone: entrambi, per
   livello. Confermare quali ricette `avanzata` diventano note "gratis" ad alto
   livello biblioteca — rischia di svuotare la sperimentazione.)
4. **Le abilità del giocatore colpiscono le proprie strutture?** (US-320. Il TG
   di Sequenza 2 *vuole* poter distruggere le sue — quindi sì, almeno con
   `colpisce_oggetti` e un bersagliamento volontario. Decidere se serve una
   conferma.)
5. **Quanti talenti innati** alla creazione: 1 o 2? (Dato in `balance.json`;
   parte a 2, si taglia a 1 se sbilancia.)
6. **`giocato_di_notte`** e gli altri comportamenti-talento legati al tempo:
   il ciclo giorno/notte è fase 6. Fino ad allora l'emettitore è un gancio
   placeholder (0, o pilotabile da debug)? (US-331. Proposta: sì, gancio
   placeholder, come i filtri acting che dipendono dal mondo in US-219.)
7. **La pagina inventario diventa `doppia_pagina`?** Con 5 sezioni potrebbe
   servire più spazio. (Decidere in US-307; `data/ui/book.json` ha già il flag.)
8. **Ordine di scrittura dei blocchi**: A → (B, C, E, F, G in parallelo) → H.
   `ralph` lavora in ordine di `priority`: dare priorità A=1..7, poi C
   (sigilli servono a B e alla UI), poi B, D, E, F, G, H. Rivedere alla conversione.
