# PRD: Fase 5 — Espansione contenuti (5 Pathway + fondamenta)

## 1. Introduzione / Overview

La fase 2 ha scritto **un** Pathway completo, il Twilight Giant, come prova che
un Pathway intero — dal principiante al dio — può esistere solo come dati, con
zero righe di codice dedicate. Le fasi 3 e 4 hanno costruito i sistemi di
supporto e il motore delle sinergie, ognuno con lo stesso verdetto.

La fase 5 mette alla prova quel verdetto sul serio: **scrive cinque Pathway
nuovi** (Death, Moon, Mother, Paragon, Hermit) con la stessa profondità del
Twilight Giant — abilità, recitazione, pozioni, rituali di avanzamento per
ognuna delle 50 Sequenze coinvolte — e **implementa le primitive attive che
ancora non hanno un handler**, ognuna nel momento in cui il primo Pathway la
richiede davvero.

Questo è il **punto di controllo dell'intero progetto** (roadmap `§ Fase 5`).
Se scrivere questi Pathway richiede un `if` speciale in `AbilityEngine` o in
un altro sistema, l'architettura della fase 2 ha sbagliato qualcosa e va
corretta **prima** di proseguire, non dopo. Per questo Death — il primo
Pathway, che stressa `summon` persistente e tre primitive nuove — è seguito da
una story-**checkpoint** dedicata: un verdetto esplicito prima di committare
gli altri quattro.

**Fuori da questa fase:** Darkness (dipende dal ciclo giorno/notte di fase 6),
Fool, Error e Door (usano `illusion`, `possess`, `steal`, `time_rewind`, le
primitive più difficili da rendere leggibili a schermo). Diventano una
**fase 5b** dopo che la fase 6 ha aggiunto il giorno/notte e le regioni. In
fase 5 di Darkness si tocca solo `darkness_1`, la Sequenza che oggi punta a
una primitiva differita e va riscritta.

Scelte confermate con l'utente (2026-09-06):

- **3 story per Pathway** (Sequenze 9-7 / 6-4 / 3-0), come da
  `design-master.md` Appendice A. Una story unica sforerebbe il limite delle
  ~200 righe di diff.
- **Fase 5 = 5 Pathway** (Death, Moon, Mother, Paragon, Hermit) + `darkness_1`
  riscritto. Darkness (resto), Fool, Error, Door → fase 5b.
- **Parità col Twilight Giant**: ogni Sequenza non-stub ha abilità +
  `acting_actions` che sommano 1.0 + `potion` (formula + characteristic +
  ingredienti) + `advancement_ritual` con `location_tags` e sacrificio.
- **Primitive interlacciate**: ogni primitiva senza handler si implementa
  (handler + VFX) nella story del primo Pathway che la usa. Motivazione in
  `§ 7`.

---

## 2. Goals

- **Cinque Pathway completi** in `data/pathways/` e `data/abilities/`: Death,
  Moon, Mother, Paragon, Hermit. 50 Sequenze da `stub: true` a contenuto reale,
  ~90-100 abilità nuove.
- **`darkness_1` riscritto** senza `probability_shift` (primitiva differita),
  con feel percepito equivalente (`curse` + stack di `debuff_stat` + `dot` a
  tag `follia`), come specificato in `design-master.md § 4`.
- **Le primitive attive che servono ai 5 Pathway hanno un handler e un VFX**:
  almeno `fear`, `soul_detach`, `resurrect`, `teleport` (Death),
  `plant_growth` (Mother), `reveal_info` (Paragon), `mind_read` (Hermit). Ogni
  primitiva implementata **e** rimossa dalla lista "non ancora implementata".
- **`summon` con `durata: -1`** (evocazioni persistenti) serializzato nel save
  e ricreato al caricamento — verificato con un test di round-trip, non solo
  annotato.
- **La matrice di proprietà** (`design-master.md § 4`) è un check del
  validator, non solo una tabella: darkness/door non possono rivendicare la
  stessa meccanica, ogni `summon` dichiara la sua materia prima, la
  divinazione fuori da Hermit rivela solo la categoria.
- **`data/schema/location_tags.json`**: vocabolario chiuso dei luoghi dei
  rituali, con validazione. Anticipato da fase 6 perché i rituali di
  avanzamento lo richiedono già.
- **Criterio di uscita**: `tests/test_slice_fase_5.gd` esegue un Pathway
  nuovo intero (Death, Sequenza 8 → 2) — abilità, recitazione, pozione,
  rituale — con **zero righe di codice che nominano "death" o una sua
  Sequenza** (grep, come US-219 / US-335 / US-413). Se il grep trova qualcosa,
  la fase si ferma e si corregge l'architettura.
- Nessuna regressione: i ~535 test di fase 1-4 restano verdi. `schema_version`
  del save invariato (la fase 5 è contenuto, non struttura). Nessuna primitiva
  **nuova** (il registro resta 28 attive + 3 differite); nessun evento nuovo
  (`tracked_events` a 12).

---

## 3. User Stories

Priorità: **P0** blocca il resto della fase; **P1** necessaria alla fase;
**P2** rifinitura.

### Blocco 0 — Fondamenta (P0, prima di ogni contenuto di Pathway)

#### US-501: `location_tags.json` — vocabolario chiuso dei luoghi dei rituali

**Description:** Come sviluppatore, voglio che i `location_tags` dei rituali di
avanzamento siano un vocabolario chiuso e validato, così che una story di dati
non inventi un luogo che il mondo (fase 6) non avrà.

**Acceptance Criteria:**

- [ ] `data/schema/location_tags.json`: array chiuso di tag di luogo. Popolato
      con i tag già usati da `twilight_giant.json` (`rovina`,
      `luogo_in_decadenza`, `campo_di_battaglia`, …) più quelli che
      `design-world.md` propone (~24 voci). Nessun tag orfano.
- [ ] `tools/validate_data.py`: ogni `advancement_ritual.location_tags` di una
      Sequenza non-stub (attiva o differita) deve contenere solo tag del
      vocabolario. Errore se un tag è fuori vocabolario, come per i tag di
      sinergia.
- [ ] Il validator continua a esigere `location_tags` non vuoto su un rituale
      non-stub (regola già presente).
- [ ] `006_PRD/design-world.md`: nota che `location_tags.json` è stato
      anticipato a fase 5; le regioni di fase 6 dovranno realizzare a schermo
      ogni tag usato.
- [ ] `python tools/validate_data.py` esce 0 (le sequenze TG passano invariate).
- [ ] Nessuna regressione. Typecheck passes. Tests pass.

#### US-502: La matrice di proprietà come check del validator

**Description:** Come sviluppatore, voglio che le quattro sovrapposizioni fra
Pathway (`design-master.md § 4`) siano impossibili da violare in un file di
dati, non solo sconsigliate a parole.

**Acceptance Criteria:**

- [ ] `tools/validate_data.py`, sezione abilità: per ogni `summon`,
      `entita_id` deve dichiarare la sua materia prima secondo una convenzione
      di prefisso (`cadavere_…` Death, `costrutto_…` Paragon, `pet_…` Moon,
      `chimera_…` Mother). Errore se `entita_id` non ha un prefisso noto.
- [ ] Ogni abilità di **divinazione** fuori da `hermit` (`reveal_info` /
      `mind_read` con `sequence_id` che non inizia per `hermit_`) deve avere
      `categoria` valorizzata su `reveal_info` (non rivela l'oggetto, solo la
      categoria del verbo). Errore se assente.
- [ ] Il tag `sogno` (root di Visionary, differito) non compare in nessun
      `tag_sinergia` di un Pathway **attivo** — errore se compare
      (`design-master.md § 4`: "NON usarlo nei pathway attivi").
- [ ] Un `_comment` in cima a `primitives.json` (o in un nuovo
      `data/schema/ownership.json` di documentazione) riporta la matrice, così
      il check e la sua motivazione stanno insieme.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-503: `darkness_1` riscritto senza `probability_shift`

**Description:** Come giocatore, voglio che la "sfortuna cronica" del Darkness
di Sequenza 1 si senta come sfortuna anche se il motore non manipola davvero
le probabilità.

**Acceptance Criteria:**

- [ ] `data/abilities/darkness.json`: `darkness_sfortuna_cronica` (già
      esistente come stress test) usa solo primitive attive:
      `curse` (effetto `sfortuna`, `condizione_rimozione`) +
      2-3 `debuff_stat` su `evasione`/`precisione` +
      `dot` basso a `tag_danno: follia`. Nessun `probability_shift`.
- [ ] `data/status_effects.json`: l'effetto `sfortuna` esiste, è `negativo`,
      con una descrizione che spiega il feel ("inciampi, manchi il colpo, ti
      ferisci da solo").
- [ ] La Sequenza `darkness_1` resta `stub: true` (il resto del Darkness è
      fase 5b): solo l'abilità è sistemata, non la Sequenza.
- [ ] Il validator non segnala più `probability_shift` come rischio latente in
      un file attivo (grep di `data/abilities/` per le 3 primitive differite
      → 0 occorrenze).
- [ ] Test headless: `AbilityEngine.execute("darkness_sfortuna_cronica",
      caster)` esegue, applica il `curse` e i `debuff_stat`, 0 warning di
      primitiva.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-504: Regola `acting_actions` somma esatta 1.0

**Description:** Come sviluppatore, voglio che la somma dei `progresso` delle
azioni di recitazione di una Sequenza sia decisa, non un residuo.

**Acceptance Criteria:**

- [ ] `tools/validate_data.py`: la somma dei `progresso` di una Sequenza
      non-stub deve essere **esattamente 1.0** (tolleranza 0.001), **tranne**
      quando la Sequenza dichiara in `notes` che un'azione è deliberatamente
      opzionale (stringa che contiene `acting_surplus_voluto`). Oggi warning,
      diventa **errore** con questa eccezione.
- [ ] Le 5 Sequenze del Twilight Giant che sommano 1.05-1.15
      (`twilight_giant_1..5`) sono normalizzate a 1.0 **oppure** marcate col
      flag in `notes`. Decisione presa nel PRD: normalizzare (nessuna azione
      del TG è pensata come saltabile).
- [ ] `python tools/validate_data.py` esce 0, i warning "acting_actions
      sommano > 1.0" spariscono.
- [ ] Nessuna regressione sui test del Twilight Giant. Typecheck passes. Tests pass.

### Blocco 1 — Death + checkpoint (P0 il checkpoint, P1 il resto)

> Death per primo: introduce `summon` persistente (che serve anche a
> Paragon, Moon, Mother) e tre primitive nuove. È il Pathway su cui
> l'architettura si rompe per prima, se deve rompersi.

#### US-505: Death, Sequenze 9-7 (Corpse Collector → Spirit Medium)

**Description:** Come giocatore, voglio le prime tre Sequenze del Death:
resistenza alla decomposizione, rianimare cadaveri semplici, parlare coi morti.

**Acceptance Criteria:**

- [ ] `data/pathways/death.json`, Sequenze 9/8/7: `stub` → `false`,
      `stat_modifiers`, `abilities` (2 per Sequenza), `acting_actions` (somma
      1.0), `potion` (formula + characteristic + ingredienti), `madness_on_force`
      crescente. Sequenze 9-7 = tier `low`, nessun `advancement_ritual` (è > 4).
- [ ] `data/abilities/death.json`: ~6 abilità nuove composte **solo** da
      primitive del registro. Seq 8 usa `summon` con `entita_id: "cadavere_…"`
      e `durata` finita (alleati temporanei). Seq 7 usa `reveal_info`
      `categoria` (parlare coi morti = divinazione fuori da Hermit → solo la
      categoria).
- [ ] **Primitiva nuova `fear`** (Corpse Collector / spiriti): handler in
      `AbilityEngine`, VFX in `data/vfx.json`, tolta dalla lista "non
      implementata". Parametri dal registro (`raggio`, `durata`,
      `soglia_resistenza`).
- [ ] `data/potions/formulas.json` + `data/characteristics.json`: 3 formule +
      3 caratteristiche nuove (`formula_death_9..7`, `char_death_9..7`); nuovi
      ingredienti aggiunti al vocabolario `ingredients`.
- [ ] i18n: `tools/generate_i18n_stubs.py` rilanciato; i nomi nuovi
      (Pathway/Sequenza/abilità/recitazione/caratteristica) tradotti in
      `it.json` (non lasciati `TODO`).
- [ ] VFX: `pathway_palette` e tratto del Death già esistono (fase 2); solo il
      VFX di `fear` è nuovo.
- [ ] Test headless (`tests/test_death.gd`): ogni abilità delle Seq 9-7
      esegue senza warning di primitiva; `fear` fa fuggire un bersaglio sotto
      soglia; la somma delle acting di ogni Sequenza = 1.0; la catena di
      migrazione del save resta verde.
- [ ] Verifica a schermo documentata in `progress.txt`: l'abilità di rianima
      cadavere di Seq 8 evoca un alleato visibile che sparisce alla scadenza;
      il VFX di `fear` è leggibile (il nemico scappa, un'icona sopra la testa).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-506: Death, Sequenze 6-4 (Spirit Guide → Undying)

**Description:** Come giocatore, voglio il primo potere offensivo del Death
(scagliare spiriti), i passaggi verso il mondo spirituale, e la rigenerazione
estrema.

**Acceptance Criteria:**

- [ ] `death.json` Seq 6/5/4: contenuto pieno come US-505. Seq 4 = tier
      `angel` (o come da `balance.json`), `advancement_ritual` **obbligatorio**
      (Sequenza ≤ 4) con `location_tags` dal vocabolario di US-501, `momento`
      e/o `fase_lunare`, `sacrifices`.
- [ ] Seq 5 (Gatekeeper) usa **`teleport`** (passaggi verso il mondo
      spirituale — *attraversare*, mai *permanenza*: `richiede_visuale` o
      punti noti, `durata` breve). Primitiva nuova: handler + VFX + tolta
      dalla lista. La matrice di proprietà (US-502): Death `teleport` è
      riposizionamento, non dominio spirituale — è coerente perché la
      *permanenza* del mondo spirituale è Seq 2, non Seq 5.
- [ ] Seq 4 (Undying) usa `heal` con `durata` (rigenerazione nel tempo) +
      `buff_stat` su `hp_max` / `difesa`.
- [ ] Formule + caratteristiche + ingredienti + i18n + test + verifica a
      schermo del `teleport` (il giocatore scompare e ricompare al punto
      bersaglio, VFX di apertura/chiusura del varco).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-507: Death, Sequenze 3-0 (Ferryman → Death) + `summon` persistente

**Description:** Come giocatore, voglio le Sequenze alte del Death: separare
anima e corpo, eserciti di non-morti che restano fra un combattimento e
l'altro, uccisione istantanea sotto soglia e resurrezione degli alleati.

**Acceptance Criteria:**

- [ ] `death.json` Seq 3/2/1/0: contenuto pieno, tier alti, rituali con
      trade-off espliciti e sacrifici pesanti (Seq 1: un'**Ancora** del
      giocatore, come `twilight_giant_1`). `madness_on_force` verso 12-14.
- [ ] Seq 3 (Ferryman) usa **`soul_detach`** (uccidere separando anima e
      corpo; l'anima diventa risorsa). Primitiva nuova: handler + VFX + tolta
      dalla lista. Parametri dal registro (`durata`,
      `vulnerabilita_corpo`, `velocita`).
- [ ] Seq 2 (Death Consul) usa **`summon` con `durata: -1`**: le evocazioni
      **persistono** fuori dal combattimento e attraverso il cambio scena.
- [ ] `SummonRegistry` (già esistente, US-fase 2/3) serializza le evocazioni
      persistenti nel save e le ricrea al load. **Test di round-trip
      dedicato**: evoco con `durata: -1`, salvo, azzero, carico → l'evocazione
      è di nuovo in scena con lo stesso `entita_id`. Nessun `if` per Death nel
      `SummonRegistry`.
- [ ] Seq 1 (Pale Emperor) usa **`resurrect`** (riporta in piedi un alleato /
      evocazione caduta) + una condizione `madness_max` sull'uccisione
      istantanea (`condizioni` dell'abilità). Primitiva nuova: handler + VFX +
      tolta dalla lista.
- [ ] Seq 0 (Death): l'abilità di dominio, `aura` a raggio ampio + il segno
      "l'NPC di Sequenza 0" agganciato in fase 7 (qui solo l'abilità).
- [ ] Formule + caratteristiche + ingredienti + i18n + test + verifica a
      schermo di `soul_detach` (il corpo resta a terra vulnerabile, l'anima
      si muove) e dell'evocazione persistente che sopravvive al reload.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-508: CHECKPOINT — verdetto sull'architettura dopo Death

**Description:** Come sviluppatore, voglio un verdetto esplicito che Death è
stato scritto senza toccare il codice, prima di committare gli altri quattro
Pathway.

**Acceptance Criteria:**

- [ ] `tests/test_slice_fase_5.gd`: compone un percorso Death reale — dalla
      Sequenza 8 alla 2 — eseguendo per ogni Sequenza un'abilità, una azione
      di recitazione (via `EventTracker`), la preparazione della pozione e il
      rituale di avanzamento. Tutto senza errori.
- [ ] `test_nessun_codice_nomina_death`: grep di `res://scripts` e
      `res://scripts/pages` per `"death"` e per gli id delle Sequenze
      (`death_0..9`). **Zero occorrenze** fuori dai commenti. Se ne trova una,
      la story fallisce e il PRD si ferma qui.
- [ ] `git diff` fra l'inizio del blocco 1 e ora: i file `.gd` toccati sono
      **solo** handler di primitiva nuovi (`fear`, `teleport`, `soul_detach`,
      `resurrect`) e i loro test — nessuna modifica a `AbilityEngine.execute`,
      `_esegui_primitive` o a un altro sistema per un caso specifico del Death.
      Documentato in `progress.txt` con l'elenco esatto dei file di codice
      toccati e perché.
- [ ] **Verdetto in `progress.txt`**: "l'architettura regge / non regge oltre
      il Twilight Giant", con la motivazione. Se non regge: elenco delle
      correzioni necessarie alla fase 2 e STOP (nessun altro Pathway finché
      non sono fatte).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco 2 — Moon (P1)

#### US-509: Moon, Sequenze 9-7 (Apothecary → Vampire)

**Description:** Come giocatore, voglio l'ingresso all'alchimia del Moon, il
primo pet permanente del gioco e il drenaggio di sangue del Vampiro.

**Acceptance Criteria:**

- [ ] `data/pathways/moon.json` Seq 9/8/7 + `data/abilities/moon.json`:
      contenuto pieno come il blocco Death.
- [ ] Seq 8 (Beast Tamer) è il gancio col **`PetSystem`** di fase 3:
      l'abilità/azione di doma usa il flusso esistente (`PetSystem.doma`),
      `entita_id: "pet_…"` per la matrice di proprietà. Nessun `if` per Moon
      nel `PetSystem`.
- [ ] Seq 7 (Vampire) usa `dot` a `tag_danno: sangue` + `heal` legato al
      danno inflitto (drain) + `buff_stat` condizionato (`e_notte` nelle
      `condizioni`).
- [ ] Nessuna primitiva nuova attesa in questo blocco (verificare: se ne
      serve una, è un segnale — aprire una micro-story, non un `if`).
- [ ] Formule + caratteristiche + ingredienti + i18n + test
      (`tests/test_moon.gd`) + verifica a schermo del drain (hp del bersaglio
      scende, hp del caster sale).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-510: Moon, Sequenze 6-4 (Potions Professor → Shaman King)

**Description:** Come giocatore, voglio le pozioni avanzate del Moon, il sangue
come materiale rituale e il branco dello Shaman King.

**Acceptance Criteria:**

- [ ] Seq 6/5/4 pieni. Seq 5 (Scarlet Scholar): il sangue **potenzia i
      rituali di avanzamento** — un `advancement_ritual` che accetta un
      `sacrifice` di tipo `sangue_del_giocatore` e in cambio abbassa un altro
      requisito. Meccanica di dati, nessun codice.
- [ ] Seq 4 (Shaman King): il pet acquisisce un **branco** — `summon`
      temporaneo legato al pet attivo (`entita_id: "pet_branco_…"`),
      `comportamento` che segue il pet. Nessun `if` per Moon nel `PetSystem` o
      nel `SummonRegistry`.
- [ ] Seq 4 rituale obbligatorio (≤ 4) con `location_tags`, `fase_lunare`
      (Moon usa la luna: il rituale chiede una fase specifica).
- [ ] Formule + caratteristiche + ingredienti + i18n + test + verifica a
      schermo (il branco compare accanto al pet e lo segue).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-511: Moon, Sequenze 3-0 (High Summoner → Moon)

**Description:** Come giocatore, voglio evocare da grande distanza creature mai
incontrate, creare esseri viventi duraturi che coltivano col giocatore, e il
fascino assoluto della Beauty Goddess.

**Acceptance Criteria:**

- [ ] Seq 3/2/1/0 pieni, tier alti, rituali con Ancora in gioco a Seq 1.
- [ ] Seq 3 (High Summoner): `summon` con `richiede_visuale: false` e
      `entita_id` che il giocatore non ha mai incontrato — l'evocazione non
      dipende da un cadavere (Death) o da ingredienti (Mother): è la sua
      materia prima "distanza" dichiarata nella matrice.
- [ ] Seq 2 (Life-Giver): `summon` `durata: -1` di una creatura che **coltiva
      insieme al giocatore** — aggancio al `BaseSystem`/giardino di fase 3 via
      un `comportamento`, non via codice.
- [ ] Seq 1 (Beauty Goddess): "dominio sui viventi senza combattimento" reso
      con `curse` (effetto `affascinato`: il bersaglio non attacca il caster) +
      `debuff_stat`. **Non** `possess` (è di Fool, fase 5b, matrice di
      proprietà). `data/status_effects.json`: effetto `affascinato`.
- [ ] Formule + caratteristiche + ingredienti + i18n + test + verifica a
      schermo (`affascinato`: il nemico smette di attaccarti).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco 3 — Mother (P1)

#### US-512: Mother, Sequenze 9-7 (Planter → Harvest Priest) + `plant_growth`

**Description:** Come giocatore, voglio coltivare e accelerare la crescita
delle piante, curare ferite e diagnosticare veleni, e rigenerare un'area viva
intorno a me.

**Acceptance Criteria:**

- [ ] Seq 9/8/7 pieni. Seq 9 (Planter) è il gancio col ciclo ingredienti /
      giardino di fase 3.
- [ ] **Primitiva nuova `plant_growth`**: handler + VFX + tolta dalla lista.
      Parametri dal registro (`raggio`, `specie`, `velocita`, `persistente`).
      Se `persistente: true` la vegetazione va nel `WorldState` (come
      `terrain_modify` permanente, US-fase 2) — riuso, nessun sistema nuovo.
- [ ] Seq 8 (Doctor): `heal` + `light_purify` (diagnostica/rimuove veleni e
      maledizioni — `light_purify` esiste già).
- [ ] Seq 7 (Harvest Priest): `aura` a `effetto` di rigenerazione su un'area
      (`data/status_effects.json`: `area_viva`).
- [ ] Formule + caratteristiche + ingredienti + i18n + test
      (`tests/test_mother.gd`) + verifica a schermo di `plant_growth` (le
      piante crescono a vista d'occhio nel raggio, quelle persistenti restano
      dopo).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-513: Mother, Sequenze 6-4 (Biologist → Classical Alchemist)

**Description:** Come giocatore, voglio innestare e ibridare creature, usare la
vegetazione come arma e come terreno, e creare omuncoli e materiali organici.

**Acceptance Criteria:**

- [ ] Seq 6/5/4 pieni. Seq 5 (Druid) = terraforming tattico: `plant_growth`
      offensivo + `terrain_modify` (`terreno_vivo`, già usato dallo stress
      test `mother_dominio_druidico`).
- [ ] Seq 6 (Biologist) e Seq 4 (Classical Alchemist): `summon` con
      `entita_id: "chimera_…"` — la materia prima è "ingredienti vivi"
      (matrice di proprietà); l'evocazione richiede un consumo dal
      `PotionSystem`/`Inventory` dichiarato nei dati, non un `if`.
- [ ] Seq 4 rituale obbligatorio con `location_tags` (`bosco_antico`,
      `sorgente`, …).
- [ ] Formule + caratteristiche + ingredienti + i18n + test + verifica a
      schermo (la chimera evocata combatte; il terreno vivo rallenta i nemici).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-514: Mother, Sequenze 3-0 (Pallbearer → Mother)

**Description:** Come giocatore, voglio drenare forza vitale dai nemici e
dall'ambiente restituendola alla terra, creare esseri viventi da zero, e il
dominio sulla natura.

**Acceptance Criteria:**

- [ ] Seq 3/2/1/0 pieni, tier alti, Ancora a Seq 1.
- [ ] Seq 3 (Pallbearer): `dot` + `heal` d'area (drenaggio che restituisce
      alla terra) + `aura`.
- [ ] Seq 2 (Desolate Matriarch): `summon` `durata: -1`, `entita_id:
      "chimera_su_misura_…"` — chimere permanenti che il giocatore configura
      (i parametri della chimera sono nei dati dell'abilità, non generati da
      codice).
- [ ] Seq 1 (Naturewalker): "la natura risponde senza rituali" — un
      `buff_stat` passivo forte + `terrain_modify` a costo ridotto, resi con
      `condizioni` `in_zona_tag` (foresta/natura) invece di un rituale.
- [ ] Formule + caratteristiche + ingredienti + i18n + test + verifica a
      schermo (la chimera permanente sopravvive al reload — riuso del test di
      US-507).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco 4 — Paragon (P1)

#### US-515: Paragon, Sequenze 9-7 (Savant → Appraiser) + `reveal_info`

**Description:** Come giocatore, voglio analizzare oggetti e rivelarne le
proprietà, scavare e disinnescare trappole antiche, e valutare gli Oggetti
Sigillati rivelandone gli effetti collaterali.

**Acceptance Criteria:**

- [ ] Seq 9/8/7 pieni.
- [ ] **Primitiva nuova `reveal_info`**: handler + VFX + tolta dalla lista.
      Parametri dal registro (`raggio`, `categoria`, `durata`). Rispetta la
      matrice: `categoria` obbligatoria (US-502), Paragon *misura* (rivela la
      categoria dell'oggetto/effetto, non l'identità completa fuori dal
      contesto del suo Pathway).
- [ ] Seq 7 (Appraiser) si aggancia al sistema **sigilli** di fase 3: rivela
      l'`effetto_collaterale` di un Oggetto Sigillato (dato già presente,
      `data/sigils/`), tramite `reveal_info` con `categoria: sigillo`. Nessun
      `if` per Paragon nel sistema sigilli.
- [ ] Formule + caratteristiche + ingredienti + i18n + test
      (`tests/test_paragon.gd`) + verifica a schermo (`reveal_info` mostra a
      HUD/libro la categoria svelata; le trappole disinnescate cambiano stato
      nel `WorldState`).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-516: Paragon, Sequenze 6-4 (Artisan → Alchemist)

**Description:** Come giocatore, voglio costruire armi e congegni Beyonder,
usare strumenti ottici per la ricognizione a distanza, e trasmutare i
materiali.

**Acceptance Criteria:**

- [ ] Seq 6/5/4 pieni. Seq 6 (Artisan) è il gancio col sistema **forgia** di
      fase 3: l'abilità di crafting usa `Forge` esistente, `entita_id:
      "costrutto_…"` per i congegni. Nessun `if` per Paragon nel `Forge`.
- [ ] Seq 5 (Astronomer): `reveal_info` a raggio ampio / `categoria: mappa`
      (ricognizione), niente `mind_read` (Paragon non legge le menti, misura).
- [ ] Seq 4 rituale obbligatorio con `location_tags` (`officina`,
      `osservatorio`).
- [ ] Formule + caratteristiche + ingredienti + i18n + test + verifica a
      schermo (il congetto/torretta evocato spara da solo).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-517: Paragon, Sequenze 3-0 (Arcane Scholar → Paragon) + `paragon_1` senza `rule_bind`

**Description:** Come giocatore, voglio incisioni che funzionano su scienza e
misticismo, costrutti autonomi e permanenti, e l'alterazione delle leggi
fisiche locali.

**Acceptance Criteria:**

- [ ] Seq 3/2/1/0 pieni, tier alti, Ancora a Seq 1.
- [ ] Seq 2 (Knowledge Magister): `summon` `durata: -1`, `entita_id:
      "costrutto_autonomo_…"` — costrutti permanenti serializzati (riuso di
      US-507).
- [ ] **Seq 1 (Illuminator) riscritta senza `rule_bind`** (primitiva
      differita): "altera le leggi fisiche locali in un raggio" reso con
      `aura` a `effetto` composito (`debuff_stat` gravità/velocità sui nemici,
      `buff_stat` sugli alleati) + `terrain_modify`. Come `darkness_1`: il
      feel resta, la manipolazione *vera* delle regole resta a un Pathway
      differito. Documentato in `notes`.
- [ ] Il grep di `data/abilities/` per `rule_bind` → 0 occorrenze.
- [ ] Formule + caratteristiche + ingredienti + i18n + test + verifica a
      schermo (dentro l'aura di Illuminator i nemici rallentano, gli alleati
      accelerano).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco 5 — Hermit (P1)

#### US-518: Hermit, Sequenze 9-7 (Mystery Pryer → Warlock)

**Description:** Come giocatore, voglio percepire il misticismo e tracciare
rituali di base, combattere applicando la conoscenza con sigilli incisi
sull'arma, ed evocare creature minori.

**Acceptance Criteria:**

- [ ] Seq 9/8/7 pieni. Seq 9 (Mystery Pryer): `reveal_info` (già implementata
      in US-515) — **Hermit è il divinatore sistemico**, qui `categoria` può
      essere più ampia che negli altri Pathway (la matrice di proprietà lo
      consente: il vincolo `categoria` obbligatoria vale *fuori* da Hermit).
- [ ] Seq 8 (Melee Scholar): `buff_stat` sull'arma applicato in tempo reale +
      `melee_arc` — il gancio col sistema sigilli (incidere al volo) è dati.
- [ ] Seq 7 (Warlock): `summon` temporaneo, `entita_id` con materia prima
      "evocazione rituale" dichiarata.
- [ ] Formule + caratteristiche + ingredienti + i18n + test
      (`tests/test_hermit.gd`) + verifica a schermo.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-519: Hermit, Sequenze 6-4 (Scrolls Professor → Mysticologist)

**Description:** Come giocatore, voglio preparare pergamene monouso, usare
costellazioni legate a posizione e ora, e creare incantesimi propri.

**Acceptance Criteria:**

- [ ] Seq 6/5/4 pieni. Seq 6 (Scrolls Professor) è il gancio con
      `stored_ability_id` di fase 3: l'abilità di Seq 6 **produce un oggetto
      pergamena** con un'abilità Hermit dentro. Il flusso è già supportato
      (`Inventory` esegue l'abilità non posseduta al consumo, US-306). Nessun
      `if` per Hermit.
- [ ] Seq 5 (Constellations Master): `buff_stat` condizionati da `momento` /
      `fase_lunare` (`condizioni` dell'abilità) — le costellazioni sono
      potenziamenti legati all'ora.
- [ ] Seq 4 rituale obbligatorio con `location_tags` (`cerchio_di_pietre`,
      `vetta`).
- [ ] Formule + caratteristiche + ingredienti + i18n + test + verifica a
      schermo (la pergamena prodotta appare nello zaino ed esegue l'abilità al
      consumo).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-520: Hermit, Sequenze 3-0 (Clairvoyant → Hermit) + `mind_read` + `hermit_1` senza `rule_bind`

**Description:** Come giocatore, voglio vedere e sentire le esistenze nascoste,
drenare potere dalla conoscenza accumulata, e leggere/alterare il destino di
una persona.

**Acceptance Criteria:**

- [ ] Seq 3/2/1/0 pieni, tier alti, Ancora a Seq 1.
- [ ] **Primitiva nuova `mind_read`** (Seq 3, Clairvoyant): handler + VFX +
      tolta dalla lista. Parametri dal registro (`raggio`, `profondita`,
      `rivela`). Hermit è l'unico Pathway attivo che la usa (la matrice: la
      lettura della mente è divinazione sistemica, di Hermit).
- [ ] Seq 2 (Sage): `buff_stat` che scala con un contatore di conoscenza
      (`condizioni` / `conoscenza_min` — o un `buff_stat` il cui `valore` è
      letto da uno stato di gioco esistente; **nessun** nuovo sistema).
- [ ] **Seq 1 (Knowledge Emperor) riscritta senza `rule_bind`**: "legge e
      altera il destino tessuto di una persona" reso con `curse` (effetto
      `destino_segnato`: il bersaglio subisce di più / manca i colpi) +
      `debuff_stat` pesanti + `reveal_info` (leggere il destino = rivelare).
      Come `darkness_1` / `paragon_1`.
- [ ] Il grep di `data/abilities/` per `rule_bind` → 0 occorrenze (chiude
      anche il residuo di Paragon).
- [ ] Formule + caratteristiche + ingredienti + i18n + test + verifica a
      schermo di `mind_read` (a schermo compare cosa il bersaglio "sta per
      fare" o un frammento di informazione).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco 6 — Chiusura (P1)

#### US-521: Sinergie e caratteristiche dei 5 Pathway nuovi

**Description:** Come giocatore, voglio che i Pathway nuovi partecipino alle
sinergie e alla creazione personaggio come il Twilight Giant.

**Acceptance Criteria:**

- [ ] Le sinergie di `data/synergies/batch_1..3.json` che usavano tag ora
      portati da un Pathway di fase 5 via la fonte `sequenza` restano corrette
      (il validator già lo verifica; qui si documenta quali sinergie sono
      diventate più facili da attivare).
- [ ] 4-6 sinergie nuove in un `data/synergies/batch_4.json` che sfruttano le
      combinazioni ora possibili fra i 5 Pathway nuovi e i sistemi di fase 3
      (es. Death + evocazione persistente + talento; Mother `plant_growth` +
      giardino; Paragon costrutto + sigillo). Tutte raggiungibili, i18n
      completo, `fonti` ≥ 2.
- [ ] `data/characteristics.json`: le 50 caratteristiche nuove (10 per
      Pathway) esistono e hanno una `name_i18n` tradotta — la creazione
      personaggio (frontespizio del libro) mostra il Pathway scelto con la sua
      caratteristica di Sequenza corrente.
- [ ] Il diagramma dei Pathway nel libro (fase 2) mostra i 5 Pathway nuovi con
      il fog of war corretto (nessun codice nuovo: sono dati).
- [ ] Verifica a schermo: creo un personaggio su ognuno dei 5 Pathway nuovi,
      il frontespizio e il diagramma sono coerenti.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-522: Chiusura fase 5

**Description:** Come sviluppatore, voglio che roadmap e documenti riflettano i
5 Pathway nuovi e il verdetto del punto di controllo.

**Acceptance Criteria:**

- [ ] `006_PRD/roadmap.md` sezione fase 5 → "CHIUSA (N story, M test)", elenco:
      5 Pathway completi, K primitive implementate (con la lista), `summon`
      persistente nel save, `location_tags.json`, matrice di proprietà nel
      validator. Nota che Darkness/Fool/Error/Door sono la fase 5b.
- [ ] `006_PRD/design-pathways.md`: la sezione "Ordine di implementazione" →
      spuntati Death/Moon/Mother/Paragon/Hermit; aggiunta una sezione
      "fase 5b" con i 4 rimasti e le loro primitive dure.
- [ ] `006_PRD/design-master.md` Appendice A fase 5 → CHIUSA; Appendice C:
      `location_tags.json` come vocabolario chiuso nuovo.
- [ ] `CLAUDE.md` + `README.md`: fase 5 chiusa, conteggi, **il verdetto del
      punto di controllo** citato esplicitamente (l'architettura ha retto /
      cosa è stato corretto), criterio di uscita in `test_slice_fase_5.gd`.
- [ ] Il validator ha un check di chiusura: le 50 Sequenze dei 5 Pathway non
      sono più `stub`; ogni primitiva dichiarata implementata ha un handler
      (nessuna resta nella lista "non implementata" se un'abilità attiva la
      usa).
- [ ] Roadmap fase 6: nota che `location_tags.json` è già fatto.
- [ ] `python tools/validate_data.py` esce 0. Tests pass.

---

## 4. Functional Requirements

- **FR-1:** Nessuna primitiva **nuova** e nessun evento nuovo. Il registro
  resta 28 attive + 3 differite; `tracked_events` a 12. Le primitive
  "implementate" in questa fase erano già nel registro, senza handler.
- **FR-2:** Ogni primitiva senza handler si implementa nella story del **primo
  Pathway di questa fase che la usa**, insieme al suo VFX in `data/vfx.json`.
  Se `SynergyEngine`/altri sistemi non ci sono (test isolati), la primitiva si
  comporta come oggi (no-op sicuro).
- **FR-3:** Ogni Sequenza non-stub ha: `stat_modifiers`, `abilities` (2, che
  risolvono), `acting_actions` (somma **1.0**, eventi dai 12 tracciati),
  `potion` (`formula_id` che risolve, `characteristic_sequence` coerente,
  ingredienti nel vocabolario), `madness_on_force > 0` e crescente lungo il
  Pathway. Sequenze ≤ 4: `advancement_ritual` con `location_tags` dal
  vocabolario di US-501.
- **FR-4:** Le abilità sono composte **solo** da primitive del registro
  attivo. Un'abilità che sembra richiederne una nuova → la primitiva esistente
  è sottoparametrizzata: parametrizzala (regola di `CLAUDE.md`). Le 3 Sequenze
  che nel concept puntano a una primitiva differita (`darkness_1`,
  `paragon_1`, `hermit_1`) si riscrivono con primitive attive, feel
  equivalente, come `design-master.md § 4` per `darkness_1`.
- **FR-5:** `summon` con `durata: -1` → l'evocazione persiste ed è
  serializzata dal `SummonRegistry` nel save, ricreata al load. Nessun `if`
  per un Pathway specifico nel `SummonRegistry`.
- **FR-6:** Ogni `summon` dichiara la sua materia prima nel prefisso di
  `entita_id` (`cadavere_`, `costrutto_`, `pet_`, `chimera_`); il validator lo
  esige.
- **FR-7:** La divinazione fuori da Hermit (`reveal_info`/`mind_read` con
  `sequence_id` non `hermit_*`) rivela solo la **categoria**: il validator
  esige `categoria` valorizzata.
- **FR-8:** i18n: dopo ogni story, `generate_i18n_stubs.py` è rilanciato e i
  nomi nuovi (Pathway, Sequenza, abilità, recitazione, caratteristica) sono
  **tradotti** in `it.json`, non lasciati `TODO`. `en.json` resta incompleto
  per scelta (come oggi).
- **FR-9:** Ogni story con un'abilità che usa una primitiva **nuova** ha una
  **verifica a schermo** documentata in `progress.txt` (il feel della
  primitiva si giudica guardando, non leggendo). Le story di sola
  ricombinazione di primitive già implementate no.
- **FR-10:** Il `schema_version` del save **non cambia**: la fase 5 è
  contenuto. Se una story si accorge di aver bisogno di un campo nuovo nel
  save, è un errore di scope — si ferma e si discute.
- **FR-11:** Ordine vincolante: **US-501..504 prima di tutto**; **US-505..508
  (Death + checkpoint) prima degli altri Pathway**; il checkpoint US-508 ha
  potere di veto sul resto della fase.
- **FR-12:** Ogni story chiude in una context window. Se il file abilità di un
  terzo di Pathway supera ~200 righe o si toccano più di ~4 file, si spezza
  ulteriormente e lo si segnala.

---

## 5. Non-Goals (Out of Scope)

- **Darkness (oltre `darkness_1`), Fool, Error, Door.** Sono la **fase 5b**,
  dopo che la fase 6 ha aggiunto il ciclo giorno/notte e le regioni. Le loro
  primitive dure (`illusion`, `possess`, `steal`, `time_rewind`, `shadow_meld`,
  `chain`) restano senza handler in fase 5.
- **Le 3 primitive differite** (`weather_control`, `probability_shift`,
  `rule_bind`). Riattivarle = riattivare il loro gruppo di Pathway:
  discussione esplicita, mai una story di fase 5. `darkness_1`/`paragon_1`/
  `hermit_1` si riscrivono, non aspettano.
- **Le regioni e il mondo di fase 6.** `location_tags.json` è un vocabolario;
  realizzare a schermo ogni luogo è fase 6. In fase 5 i rituali validano i
  tag ma non c'è ancora una zona che li contenga.
- **Il bilanciamento reale.** `stat_modifiers`, `valore`/`delta` delle
  primitive, `madness_on_force`, soglie: plausibili, da riscrivere dopo il
  primo playtest completo.
- **La fase 7** (cambio Pathway, `fusion_rules`, l'NPC di Sequenza 0, finali).
  Le abilità di Sequenza 0 dei 5 Pathway si scrivono; il sistema che le
  intreccia no.
- **Nuovi `page_type` del libro.** Il diagramma dei Pathway e il frontespizio
  esistono; mostrano i 5 Pathway nuovi come dati, senza codice UI nuovo.
- **Doppiaggio, 3D, generazione procedurale** — non-goal di progetto.

---

## 6. Design Considerations

- **Il gold standard è `twilight_giant.json`.** Ogni Sequenza nuova si scrive
  guardando quel file: trade-off espliciti nelle abilità alte
  (`tg_postura_inviolabile`: difesa +70%, velocità −50%), recitazione che
  *accetta la natura del potere* (il TG di Seq 2 lascia decadere una propria
  struttura), `madness_on_force` da ~1 a ~13.6, sacrificio di un'**Ancora** al
  rituale di Seq 1, agganci fra sistemi voluti (`tg_crepuscolo` con
  `colpisce_oggetti: true` danneggia la tua base).
- **La matrice di proprietà** (`design-master.md § 4`) va letta prima di
  scrivere una sola Sequenza. Death *abita* il mondo spirituale, Door lo
  *attraversa*; Error *ruba* le abilità, Door le *registra*, Fool le *finge*;
  quattro fonti di evocazione con quattro materie prime; Darkness è
  invisibilità percettiva, Door spaziale. US-502 la rende un check.
- **VFX**: `pathway_palette` e il tratto di ognuno dei 10 Pathway attivi
  esistono già dalla fase 2 (`data/vfx.json`). In fase 5 si aggiunge solo il
  VFX **per primitiva nuova** (`fear`, `teleport`, `soul_detach`, `resurrect`,
  `plant_growth`, `reveal_info`, `mind_read`), riusando il vocabolario chiuso
  dei tratti e gli `impact_frame` agganciati agli `hitstop_ms`.
- **Audio**: `data/audio.json` ha già la `pathway_palette` timbrica per i 10
  attivi. Una primitiva nuova con un tell (`fear`, `soul_detach`) usa il
  sistema tell esistente (`anticipo_ms > 0`), niente sistema nuovo.
- **Riuso**: `SummonRegistry` (evocazioni + save), `WorldState` (terrain/plant
  persistenti), `PetSystem` (Moon), `Forge` (Paragon), `stored_ability_id` +
  `Inventory` (pergamene Hermit), `KnowledgeStore` (gating conoscenza),
  `status_effects.json` (nuovi effetti: `sfortuna`, `affascinato`, `area_viva`,
  `destino_segnato`), `EventTracker` (recitazione), `tr_data` (nomi).

---

## 7. Technical Considerations

### Perché le primitive vanno interlacciate, non messe in un blocco iniziale

La domanda che conta non è "quanto codice" ma "quale approccio produce il
gioco migliore da giocare". Le tre opzioni:

1. **Blocco iniziale** — implementi tutte le 13 (o 7) primitive prima di
   scrivere un'abilità che le usi.
2. **Interlacciate** — ogni primitiva nasce nella story del primo Pathway che
   la richiede, accanto alla sua prima abilità reale.
3. **Ibrido** — blocco iniziale per le 4 più difficili, interlacciate le altre.

**Le primitive difficili lo sono perché renderle leggibili a schermo è un
problema di design, non di codice.** `illusion`: il giocatore deve capire
quali nemici sono finti. `possess`: di chi è il corpo che controllo, dov'è il
mio. `soul_detach`: il corpo resta a terra vulnerabile, l'anima si muove —
serve che entrambi si vedano. `fear`: il nemico scappa e si capisce *perché*.
Questo feel si può tarare **solo** guardando una vera abilità in un vero
combattimento. Non puoi decidere se un'illusione è leggibile senza
un'abilità Fool che ne genera in una rissa reale.

Quindi:

- **Blocco iniziale**: implementi `soul_detach` senza contenuto Death contro
  cui provarlo. Lo tari alla cieca, poi scrivendo `death_3` scopri che il feel
  è sbagliato e lo rifai. Il gioco ci perde: hai speso il tuo occhio di
  design su un handler astratto.
- **Ibrido**: è la scelta peggiore per le 4 difficili, perché mette davanti
  esattamente le primitive che *più* hanno bisogno di contenuto reale per
  essere tarate.
- **Interlacciate**: la primitiva e la sua prima abilità nascono insieme,
  tarate nello stesso combattimento. I loro feel convergono. Il costo — un
  paio di story di Pathway con un diff di codice più grande — è un costo di
  processo, non di qualità del gioco, ed è contenuto dal taglio in 3 story per
  Pathway (un handler + un terzo di Pathway resta sotto controllo).

Le primitive **semplici** (`teleport`, `reveal_info`, `plant_growth`,
`mind_read`, `resurrect`) sono leggibili quasi per default (ti teletrasporti,
un ping rivela, le viti crescono). Per loro interlacciare vs blocco non cambia
il feel — ma interlacciare vince lo stesso, perché eviti codice speculativo e
le vedi nel contesto giusto.

**Conclusione: interlacciate.** Death (US-505..507) implementa `fear`,
`teleport`, `soul_detach`, `resurrect`; Mother `plant_growth`; Paragon
`reveal_info`; Hermit `mind_read`. Il checkpoint US-508 verifica proprio che
questo modello — "una primitiva nuova per story, nessun'altra riga di codice" —
regga.

### Altre note

- **`AbilityEngine`.** Le primitive nuove sono nuove entry nella tabella
  `tipo -> Callable` e nuovi handler `_p_<tipo>`. `execute` e
  `_esegui_primitive` **non si toccano**. Se una story si trova a modificarli
  per un Pathway, è il segnale che il checkpoint deve cogliere.
- **Save.** Nessun bump di `schema_version`. Le evocazioni persistenti usano
  il `SummonRegistry` che è già nel save (fase 2/3); la story US-507 aggiunge
  solo il **test** di round-trip, non il meccanismo.
- **`SummonRegistry` e le 4 materie prime.** La differenza fra un cadavere di
  Death e un costrutto di Paragon è nei **dati** dell'abilità (costo, requisiti,
  `comportamento`), non nel registro. Il registro serializza `entita_id` +
  stato, uguale per tutti.
- **Formule e caratteristiche.** Ogni Sequenza non-stub tira una
  `formula_<pathway>_<n>` e una `char_<pathway>_<n>`. Vanno create nelle
  stesse story, con ingredienti nuovi aggiunti al vocabolario `ingredients` di
  `formulas.json`. Il validator lega formula ↔ characteristic_sequence ↔
  Sequenza: un mismatch è un errore, non un warning.
- **`generate_pathways.py`** è idempotente e preserva `abilities`,
  `acting_actions`, `potion` già popolati: si può rilanciare dopo ogni story
  senza perdere lavoro. Verificare (doppia rigenerazione = zero diff) come in
  fase 2.
- **Nessuna dipendenza nuova.** Validator resta Python puro, gioco resta
  Godot 4.3.
- **`ralph`.** Docker attivo, `prd.json` in root, `--fase 5`,
  `--test-cmd "godot --headless --script tests/run_tests.gd"`. Una story per
  iterazione. Godot 4.3 headless in locale a ogni story; verifica a schermo
  reale per le story con primitiva nuova.

---

## 8. Success Metrics

- **Punto di controllo (US-508)**: Death completo — Sequenze 8→2 eseguite in
  `test_slice_fase_5.gd` — con **zero righe di codice che nominano "death" o
  una sua Sequenza** (grep). I soli file `.gd` toccati nel blocco 1 sono
  handler di primitiva nuovi e i loro test. Se il grep trova qualcosa o
  `AbilityEngine.execute` è stato modificato per Death, la fase si **ferma** e
  si corregge la fase 2.
- **5 Pathway completi**: 50 Sequenze da `stub` a contenuto reale, ~90-100
  abilità, tutte composte solo da primitive del registro attivo.
- **Ogni primitiva che un'abilità attiva usa ha un handler**: la lista "non
  ancora implementata" si svuota di `fear`, `teleport`, `soul_detach`,
  `resurrect`, `plant_growth`, `reveal_info`, `mind_read`. Il validator lo
  verifica alla chiusura.
- **`summon` persistente**: test di round-trip del save verde.
- **Nessuna primitiva differita in un file attivo**: grep di `data/abilities/`
  per `weather_control|probability_shift|rule_bind` → 0.
- **Nessuna regressione**: i ~535 test di fase 1-4 restano verdi. Save
  `schema_version` invariato. `tracked_events` a 12, registro primitive 28+3.
- **Validator a 0 errori**; i warning "acting > 1.0" spariti (US-504); nessun
  warning nuovo dai 5 Pathway.
- **i18n**: 0 chiavi `TODO` per i nomi dei 5 Pathway nuovi e delle loro
  Sequenze/abilità/caratteristiche in `it.json`.

---

## 9. Open Questions

1. **La profondità "parità col TG" per 50 Sequenze è ~15-20 story?** Il conto:
   4 (blocco 0) + 4 (Death+checkpoint) + 3×4 (Moon/Mother/Paragon/Hermit) + 2
   (chiusura) = **22 story**. Se una story di terzo-di-Pathway sfora
   comunque, si accetta un 4° taglio per quel Pathway (Seq 9-8 / 7-6 / 5-4 /
   3-0)?
2. **Le pozioni e i rituali di Moon usano la `fase_lunare`**: il vocabolario
   di `time.json` ha 5 fasi. Basta, o Moon ne chiede di specifiche che vanno
   aggiunte (discussione, come per gli eventi)?
3. **`fear` e `soul_detach` hanno bisogno di un'IA nemica che "scappi" o che
   "resti a terra"?** Se l'IA di combattimento non è abbastanza sviluppata
   (fase 1 era placeholder), la verifica a schermo di queste primitive è
   parziale. Serve una micro-story sull'IA prima, o si accetta una verifica
   con un manichino scriptato?
4. **`char_<pathway>_<n>` per 50 caratteristiche**: le scriviamo tutte in
   US-521 (una story sola, 50 righe di JSON + 50 traduzioni) o una decina per
   Pathway nelle story del Pathway?
5. **Il branco di Moon (Seq 4) e le chimere di Mother (Seq 2/6) sono
   `summon` legati a un consumo** (il pet attivo, ingredienti): il costo va
   nei `condizioni` dell'abilità (vocabolario chiuso, 8 tipi) o serve un
   nono tipo di condizione? Se serve, è codice — si discute.
6. **Darkness in fase 5b**: `darkness_1` lo sistemiamo ora (US-503), ma le
   altre 9 Sequenze del Darkness dipendono davvero dal giorno/notte, o alcune
   (Seq 9-7, stealth di base) si potrebbero anticipare a fase 5?
