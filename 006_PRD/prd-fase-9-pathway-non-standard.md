# PRD: Fase 9 — Pathway Non-Standard (Eternal Aeon + motore Boon)

## 1. Introduzione / Overview

Le fasi 1-8 hanno costruito un solo sistema di progressione: Sequenza 9→0,
Caratteristica + formula + concoct + recitazione + bevi, lo stesso motore
generico (`Progression`/`PotionSystem`/`Acting`) che serve tutti e 10 i
Pathway standard attivi (e i 12 differiti) senza una riga di codice dedicata
a nessuno di loro — provato ripetutamente, l'ultima volta in fase 8 giocando
per davvero tutti e 10 con Xvfb.

Il materiale di riferimento narrativo ha anche un secondo tipo di Pathway,
**"Non-Standard"**: entità come Eternal Aeon, Chaos Primogenitor, Scrooge,
Dreamless (e altri "bestower") che non salgono di Sequenza bevendo una
pozione dopo aver recitato un ruolo — ricevono doni ("Boon") da un'entità
superiore secondo una logica diversa per ciascuna.

Questa fase costruisce **un motore Boon generico** (stesso principio di
`PotionSystem`: il codice non sa nulla di "Eternal Aeon", legge solo dati) e
**un solo Pathway Non-Standard completo, Eternal Aeon** (10/10 Sequenze),
come prova d'architettura — lo stesso ruolo che il Twilight Giant ha avuto
in fase 2 per il motore standard.

**Fuori da questa fase**: gli altri Pathway Non-Standard (Chaos
Primogenitor, Scrooge, Dreamless, ...) restano non scritti finché non si
decide di espanderli, con lo stesso schema. Un secondo tipo di Boon (a
gradini progressivi, o ad accumulo continuo tipo reputazione) **non si
implementa qui**: la scelta fatta con l'utente è "dono una tantum da un
patto/rituale" per ogni Sequenza — lo schema dati lascia il campo aperto a
estenderlo in futuro, ma questa fase non lo fa.

Scelte confermate con l'utente (2026-09-10):

- **Un solo Pathway Non-Standard in questa fase**: Eternal Aeon, completo
  10/10 Sequenze (non una fetta) — scelta esplicita dell'utente sopra
  l'opzione "fetta piccola" che avevo consigliato per rischio minore.
- **Meccanica del Boon**: un dono una tantum concesso quando i requisiti
  della Sequenza sono soddisfatti — non una scala a gradini, non un
  accumulo continuo (quei due restano space per un'eventuale fase futura,
  non costruiti ora).
- **Un Boon si guadagna con una combinazione di tre fonti**, dichiarata nei
  dati per ogni Sequenza (mai tutte e tre obbligatorie insieme, la
  combinazione è per-Sequenza):
  1. **Quest/eventi di trama** dell'entità (riusa `QuestSystem` esistente,
     zero verbi nuovi).
  2. **Comportamenti contati** in gioco (riusa `EventTracker`; se i 12
     eventi tracciati chiusi bastano per esprimere il comportamento di
     Eternal Aeon lo si scopre scrivendo le Sequenze — se NON bastano, è
     una discussione esplicita con l'utente prima di aggiungere un
     tredicesimo evento, mai una decisione presa da sola).
  3. **Costo/sacrificio esplicito** (un oggetto, una Caratteristica, un
     tot di Follia) pagato al momento di ricevere il Boon.
- **Stessa scala Sequenza 9→0** dei Pathway standard: riuso massimo di
  `Progression`, save, pagina diagramma (fog of war, colonna del proprio
  Pathway), invece di una numerazione propria — meno fedele al lessico
  dell'opera originale ma un sistema in meno da costruire.
- **Eternal Aeon si sceglie col ciclo standard di creazione**: stesso
  `OptionButton` di `page_creazione_personaggio.gd` usato per i Pathway
  standard, nessun gating narrativo da costruire in questa fase (vedi § 5).

---

## 2. Goals

- **Un motore Boon generico** (`BoonSystem`, autoload) che legge un campo
  dati `boon` sulla Sequenza corrente (parallelo a `potion` dei Pathway
  standard) — nessun nome di Pathway Non-Standard nel codice, stesso
  principio di `PotionSystem.gd` con "Twilight Giant"/"Darkness".
- **Un campo chiuso `categoria`** (`"standard"` | `"non_standard"`) su ogni
  `data/pathways/*.json` e `data/pathways_deferred/*.json` esistenti (i 22
  già scritti diventano tutti `"standard"`, edit meccanico) + sulla nuova
  `data/pathways_non_standard/eternal_aeon.json`. I sistemi che assumono
  gruppi/vicini/fusione (`PathwayChange`, `FusionEngine`, fase 7) ignorano
  esplicitamente i Pathway `"non_standard"` (non hanno gruppo, non c'è
  fusione per loro in questa fase).
- **Eternal Aeon completo**: 10/10 Sequenze non-stub, nomi propri (mai
  "Sequenza N" generico, stessa regola del fog of war già in vigore),
  abilità composte dalle 28 primitive attive esistenti (nessuna primitiva
  nuova prevista — se emerge il bisogno durante la scrittura, è una
  discussione esplicita, non una scorciatoia), un `boon` per Sequenza con
  requisiti dichiarati.
- **La pagina diagramma del libro** (`page_diagramma_pathway.gd`) mostra
  una sezione "Dono" al posto di "Prepara/Bevi" quando il Pathway corrente
  è `non_standard`: elenco dei requisiti con lo stato di ognuno (soddisfatto
  o no) e un'azione per ricevere il Boon quando tutti lo sono — stessa
  pagina estesa, non un tipo di pagina nuovo (`page_types.json` resta
  chiuso, stesso principio già usato per il colophon in fase 7).
- **Criterio di uscita**: un checkpoint dinamico (stesso schema del
  checkpoint di fase 8, `tests/test_slice_fase_8.gd`: lista vietata
  scoperta dai dati, non scritta a mano) verifica che nessuna riga del
  motore nomini "eternal_aeon"; una story di verifica giocata per davvero
  (Xvfb, stesso schema di `tests/manual/qa_vslice_<pathway>.gd`) porta un
  personaggio Eternal Aeon dalla Sequenza 9 a una Sequenza inferiore
  ricevendo almeno un Boon con tutte e tre le fonti di requisito coinvolte
  (in Sequenze diverse, non necessariamente tutte insieme nella stessa).
- Nessuna regressione sui test esistenti (850+ test). `schema_version` del
  save **invariato se possibile** (vedi Domande Aperte §9 — `BoonSystem`
  potrebbe non aver bisogno di stato proprio, riusando le baseline già
  persistite da `EventTracker`/`QuestSystem`; se durante l'implementazione
  risultasse necessario un campo nuovo, è un bump dichiarato come per ogni
  fase precedente). Nessuna primitiva nuova salvo discussione esplicita.
  Vocabolario dei 12 eventi tracciati invariato salvo discussione esplicita.

---

## 3. User Stories

### US-901: Vocabolario e schema del motore Boon

**Descrizione:** Come sistema, serve un modo chiuso e validato di
dichiarare "questa Sequenza si ottiene con un Boon fatto di questi
requisiti" nei dati, e di distinguere un Pathway standard da uno
Non-Standard.

**Acceptance Criteria:**

- [ ] `data/schema/boon.schema.json` (nuovo): documenta il campo `boon` di
      una Sequenza — `requisiti: []`, ogni voce `{tipo: "quest"|
      "comportamento"|"sacrificio", ...}` con i campi propri di ogni tipo
      (`quest_id` per `quest`; `evento`/`filtri`/`target` per
      `comportamento`, stesso schema di `acting_actions`; `costo:
      {tipo: "oggetto"|"caratteristica"|"follia", id, quantita}` per
      `sacrificio`).
- [ ] Campo `categoria` (`"standard"` | `"non_standard"`) aggiunto a tutti
      i `data/pathways/*.json` (10) e `data/pathways_deferred/*.json` (12)
      esistenti, tutti `"standard"` — edit meccanico via script, non a
      mano (`tools/` nuovo o esteso, coerente con `generate_i18n_stubs.py`
      come pattern di script "riscrive i dati esistenti").
- [ ] `tools/validate_data.py`: valida `boon.requisiti[]` contro il
      vocabolario chiuso dei 3 `tipo`; `quest_id` esiste in
      `data/quests/`; `evento` è uno dei 12 tracciati; `costo.id` esiste
      nella categoria giusta (item/caratteristica); nessuna Sequenza ha
      **sia** `potion` **sia** `boon` (mutuamente esclusivi); ogni Pathway
      `"non_standard"` non compare nei gruppi di `design-pathways.md`/
      fusion.
- [ ] `python tools/validate_data.py` esce 0.
- [ ] Test headless nuovi per ogni check sopra.

### US-902: `BoonSystem` (autoload)

**Descrizione:** Come giocatore con un Pathway Non-Standard, voglio poter
verificare quali requisiti del mio prossimo Boon ho già soddisfatto e
riceverlo quando sono tutti pronti.

**Acceptance Criteria:**

- [ ] `scripts/boon_system.gd` (nuovo autoload): `requisiti_stato() ->
      Array` (un dict per requisito: tipo, descrizione, soddisfatto:bool,
      progresso se rilevante); `puo_ricevere() -> bool`; `ricevi_boon() ->
      Dictionary` (paga il/i sacrificio/i dichiarati, chiama
      `Progression.avanza()`, ritorna `{ok, avanzato, reason}` — stesso
      contratto di forma di `PotionSystem.bevi()`).
- [ ] `comportamento`: conta un evento tracciato con baseline alla Sequenza
      corrente (stesso principio di `Acting._baseline`/`_riparti()` — se
      riusabile direttamente da lì lo si riusa, altrimenti una baseline
      propria minima, mai duplicando la logica di conteggio di
      `EventTracker`).
- [ ] `quest`: legge lo stato da `QuestSystem` (nessun verbo nuovo).
- [ ] `sacrificio`: consuma da `Inventory`/`CharacteristicStore`/`Madness`
      **solo** al momento di `ricevi_boon()` riuscito, mai prima (un
      requisito "in attesa" non deve costare nulla solo a guardarlo).
- [ ] Se `puo_ricevere()` è falso, `ricevi_boon()` non avanza e non
      consuma nulla (`{ok: false, reason: "requisiti_mancanti"}`).
- [ ] Test headless: ogni combinazione di tipo di requisito, singola e
      mista, con un Pathway di prova (non Eternal Aeon — un fixture nei
      test, come fa `test_vertical_slice.gd` col Twilight Giant).

### US-903: Guardie nei sistemi che assumono Pathway standard

**Descrizione:** Come sistema, `PathwayChange`/`FusionEngine` (fase 7) non
devono trattare un Pathway `non_standard` come se avesse un gruppo o un
vicino a cui fondersi.

**Acceptance Criteria:**

- [ ] `PathwayChange`: rifiuta un cambio verso/da un Pathway
      `non_standard` con una `reason` esplicita, non un crash o un
      comportamento silenzioso.
- [ ] `FusionEngine`: nessun percorso di fusione può coinvolgere un
      Pathway `non_standard` (validator + guardia a runtime).
- [ ] Test headless per entrambe le guardie.

### US-904: Eternal Aeon — Sequenze 9-5

**Descrizione:** Come giocatore, voglio le prime 5 Sequenze di Eternal
Aeon giocabili: nomi, abilità, requisiti del Boon.

**Acceptance Criteria:**

- [ ] `data/pathways_non_standard/eternal_aeon.json`: Sequenze 9-5 con
      nome proprio distinto ciascuna (mai "Sequenza N"), `categoria:
      "non_standard"`, `group: null`.
- [ ] `data/abilities/eternal_aeon.json`: almeno un'abilità per Sequenza,
      composta solo da primitive del registro attivo (28) — se una
      Sequenza sembra richiederne una differita o nuova, si riformula sui
      dati o si porta la discussione all'utente prima, come da regola 1
      di `CLAUDE.md`.
- [ ] Ogni Sequenza ha un `boon` con almeno un requisito; almeno una delle
      5 usa tutti e tre i tipi insieme, almeno una ne usa uno solo (prova
      che le combinazioni parziali funzionano).
- [ ] `data/i18n/it.json`/`en.json`: chiavi nella convenzione esistente
      (`pathway.eternal_aeon`, `sequence.eternal_aeon.N`,
      `ability.eternal_aeon.<id>`).
- [ ] `python tools/validate_data.py` esce 0. Test headless invariati +
      eventuali nuovi per Eternal Aeon.

### US-905: Eternal Aeon — Sequenze 4-0

**Descrizione:** Come giocatore, voglio Eternal Aeon completo fino alla
Sequenza 0.

**Acceptance Criteria:**

- [ ] Stesso schema di US-904 per le Sequenze 4-0.
- [ ] Le 10 Sequenze coprono tutte e tre le fonti di requisito almeno una
      volta ciascuna nell'insieme delle 10 (se già soddisfatto da US-904,
      questa story lo conferma invece di ripeterlo).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione.

### US-906: Sezione "Dono" nella pagina diagramma

**Descrizione:** Come giocatore con un Pathway Non-Standard, voglio vedere
nel libro cosa mi manca per ricevere il prossimo Boon, ed esprimere
l'azione di riceverlo.

**Acceptance Criteria:**

- [ ] `page_diagramma_pathway.gd`: quando `Progression.sequence_data()` ha
      un campo `boon` (invece di `potion`), mostra la lista dei requisiti
      con lo stato di ognuno (icona/testo soddisfatto-o-no, dati da
      `BoonSystem.requisiti_stato()`) invece della sezione
      Prepara/Bevi — stessa pagina, un ramo sul DATO (`boon` vs `potion`
      sulla Sequenza), mai un tipo di pagina nuovo.
- [ ] Un bottone "Ricevi il Dono" (chiave i18n nuova in
      `assets/i18n/strings.csv`) chiama `BoonSystem.ricevi_boon()`,
      disabilitato finché `puo_ricevere()` è falso.
- [ ] Verifica a schermo con Xvfb: screenshot della sezione con requisiti
      parzialmente soddisfatti e dopo aver ricevuto il Boon (Sequenza
      scesa), mandati in chat.
- [ ] Test headless per il ramo `boon` vs `potion` della pagina.

### US-907: Checkpoint + verifica giocata + chiusura fase 9

**Descrizione:** Come team, vogliamo la prova che il motore Boon regge
davvero, giocando Eternal Aeon per intero, e la fase chiusa nella
documentazione.

**Acceptance Criteria:**

- [ ] `tests/test_fase_9_checkpoint.gd` (nuovo): grep di `res://scripts` e
      `res://scripts/pages` per `"eternal_aeon"` e per gli id delle sue
      Sequenze/abilità (scoperti dai dati, non scritti a mano — stesso
      schema di `tests/test_slice_fase_8.gd`), 0 occorrenze attese.
- [ ] `tests/manual/qa_vslice_eternal_aeon.gd` (nuovo, script manuale, non
      nella suite headless): crea un personaggio Eternal Aeon, soddisfa i
      requisiti di un Boon con tutte e tre le fonti (quest completata,
      comportamento contato, sacrificio pagato) e lo riceve, verificando
      `Progression.sequence()` sceso. Lanciato per davvero con Xvfb,
      screenshot mandati in chat.
- [ ] `tools/validate_data.py`: blocco "chiusura fase 9" (Eternal Aeon
      10/10 Sequenze non-stub, file di schema presenti).
- [ ] `progress.txt`, `CLAUDE.md` (§ Fasi), `README.md`, `006_PRD/
      roadmap.md` aggiornati a "Fase 9: CHIUSA" nello stesso stile delle
      fasi precedenti.
- [ ] `prd.json`: tutte le story a `passes: true` con note compilate.

---

## 4. Functional Requirements

- FR-1: Ogni Sequenza di un Pathway ha **o** `potion` **o** `boon`, mai
  entrambi — il validator lo impone.
- FR-2: `BoonSystem.requisiti_stato()` deve poter essere chiamato in
  qualunque momento senza effetti collaterali (nessun consumo di risorse
  solo leggendo lo stato).
- FR-3: `BoonSystem.ricevi_boon()` deve essere atomico: se un qualunque
  requisito non è soddisfatto, non consuma nessuno dei sacrifici
  dichiarati e non avanza la Sequenza.
- FR-4: Un Pathway `categoria: "non_standard"` non compare mai come
  vicino/gruppo per `PathwayChange` o `FusionEngine`.
- FR-5: La pagina diagramma sceglie la sezione da mostrare (Prepara/Bevi
  vs Dono) leggendo quale campo (`potion`/`boon`) è presente sulla
  Sequenza corrente, mai leggendo l'id del Pathway.
- FR-6: Nessun nome di Pathway Non-Standard, di Sequenza di Eternal Aeon o
  di sua abilità compare in `res://scripts` o `res://scripts/pages` fuori
  da un commento (checkpoint US-907).

---

## 5. Non-Goals (fuori scope)

- Gli altri Pathway Non-Standard (Chaos Primogenitor, Scrooge, Dreamless,
  altri bestower) — restano non scritti, stessa ricetta quando richiesta.
- Una seconda forma di Boon (a gradini progressivi, o ad accumulo
  continuo) — lo schema dati non la vieta esplicitamente in futuro, ma
  questa fase implementa solo "dono una tantum".
- **Come si ottiene narrativamente l'accesso a un Pathway Non-Standard**
  (nel materiale di riferimento di solito non si sceglie all'inizio, lo si
  riceve in circostanze uniche). **Deciso con l'utente (2026-09-10):**
  Eternal Aeon è selezionabile alla creazione del personaggio esattamente
  come i Pathway standard, stesso `OptionButton`/stesso ciclo di
  `page_creazione_personaggio.gd` — nessuna condizione di sblocco per
  questa fase. Un gating narrativo vero (una quest che "sblocca" la
  scelta) resta un possibile lavoro futuro, fuori da questa fase.
- Cambio di Pathway (fase 7) DA o VERSO un Pathway Non-Standard — bloccato
  (US-903), non implementato in nessuna forma.
- Fusione (fase 7) coinvolgente un Pathway Non-Standard.
- Doppiaggio, audio reale (resta specifica come per ogni fase precedente).

---

## 6. Design Considerations

- La sezione "Dono" riusa i pattern visivi già in `page_diagramma_pathway.gd`
  per la sezione Prepara/Bevi (liste con stato, bottone con `disabled`
  quando non azionabile) — nessun componente UI nuovo.
- I requisiti mostrati devono restare leggibili senza rivelare informazioni
  che il fog of war narrativo nasconderebbe altrove (es. non rivelare il
  nome della Sequenza successiva oltre l'eccezione già prevista).

---

## 7. Technical Considerations

- **Riuso, non duplicazione**: `BoonSystem` deve appoggiarsi a
  `EventTracker`/`QuestSystem`/`Inventory`/`CharacteristicStore`/`Madness`
  esistenti — nessuno di questi sistemi viene riscritto, solo letto/
  chiamato.
- **`Acting`/`EventTracker` restano quelli di oggi**: se il tipo
  `comportamento` di Eternal Aeon può essere espresso coi 12 eventi
  tracciati esistenti (probabile: `ability_used`, `ritual_completed`,
  `item_crafted`, `time_in_state`, ecc. sono già generici), non serve
  toccare `data/schema/tracked_events.json`. Se durante la scrittura di
  US-904/905 emerge che serve davvero un evento nuovo, è una discussione
  esplicita con l'utente (regola 1 di `CLAUDE.md`), non una decisione presa
  scrivendo i dati.
- **`data/pathways_non_standard/`**: nuova cartella, parallela a
  `data/pathways/` e `data/pathways_deferred/` — non dentro nessuna delle
  due, perché non è né un Pathway attivo standard né uno differito dello
  stesso tipo.
- **`GameData.pathway_ids()`**: da confermare se deve restare "solo
  standard" (compatibilità con `page_creazione_personaggio.gd`, fusion,
  ecc. che oggi assumono tutti i pathway_ids() abbiano un gruppo) o se
  serve un accessore parallelo (es. `pathway_ids_non_standard()`) — decisione
  di implementazione in US-901, non bloccante per il PRD.

---

## 8. Success Metrics

- `tests/test_fase_9_checkpoint.gd` verde: zero righe del motore nominano
  Eternal Aeon.
- `tests/manual/qa_vslice_eternal_aeon.gd` lanciato con Xvfb: tutti i passi
  OK, screenshot che mostrano i tre tipi di requisito verificati dal vivo.
- Nessuna regressione sugli 850+ test esistenti.
- `python tools/validate_data.py` esce 0.

---

## 9. Open Questions

- `BoonSystem` avrà bisogno di un campo persistito nel save, o le baseline
  di `EventTracker`/lo stato di `QuestSystem` bastano da soli? Se serve un
  campo nuovo, che bump di `schema_version` comporta — da chiarire durante
  US-902, non bloccante per iniziare.
- I 12 eventi tracciati bastano per esprimere i requisiti `comportamento`
  di tutte le 10 Sequenze di Eternal Aeon, o ne serve uno nuovo per almeno
  una? Da scoprire scrivendo US-904/905 — se serve, si ferma e si discute
  con l'utente prima di aggiungerlo.
- `GameData.pathway_ids()` resta solo-standard o serve un accessore
  parallelo per i non-standard? (vedi § 7).
- Come si presenta a schermo un requisito `comportamento` "in corso" (es.
  "3 di 5") senza rivelare più di quanto la Sequenza dovrebbe far sapere —
  da rifinire in US-906 col resto dell'UI del diagramma.
