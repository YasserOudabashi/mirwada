# PRD: Fase 11 — Villaggi ed Economia

## 1. Introduzione / Overview

La fase 10 ha reso il mondo continuo (5 regioni + una campagna vera fra di
loro, US-1015). Ma il mondo resta "vuoto" nel senso che conta per un
giocatore: pochi NPC, ammassati vicini l'uno all'altro, che vendono solo
listini fissi di ingredienti grezzi. Non esistono artigiani che
*creano* qualcosa per te, non esiste una nozione di oggetto raro contro
oggetto comune, e i villaggi sono ancora uno solo (l'avamposto di Valle
della Madre, US-1011, e persino la sua capanna "erborista" è vuota dentro).

Questa fase aggiunge lo strato economico e la densità di contenuto che
mancano: più insediamenti (nella campagna E dentro le regioni esistenti),
fabbri e alchimisti che **creano** armi e pozioni quando gli porti gli
ingredienti giusti (non il personaggio che si arrangia da solo), e una
rarità degli oggetti che incide davvero sul gioco (prezzo, drop dai
nemici, e via dicendo) — retrofit su tutti gli oggetti già esistenti.
L'obiettivo dichiarato dall'utente: un mondo con la densità e la varietà
di un gioco 2D esplorativo grande (Pokémon è stato il riferimento usato),
non NPC e contenuto ammassati in un angolo.

**Rinumerazione**: questa diventa la prossima fase da eseguire. La fase
già pianificata "Atto II e Atto III" (`006_PRD/prd-fase-11-atto-2-3.md`,
13 story già scritte) **diventa Fase 12** — si rinomina il file e i
riferimenti, senza riscrivere il contenuto. I Pathway Non-Standard
opzionali (roadmap.md) slittano a Fase 13.

## 2. Goals

- Aggiungere una rarità (`comune` / `non_comune` / `raro` / `leggendario`)
  a **ogni** oggetto del gioco (retrofit sui ~345 esistenti + i nuovi),
  che incide su prezzo e probabilità di drop, non solo su un'etichetta.
- Un meccanismo generico "l'NPC crea per te": porti gli ingredienti,
  l'NPC (fabbro o alchimista) produce l'oggetto — riusando il motore di
  crafting già scritto in fase 3 (`Forge.forgia`/`PotionSystem.prepara`),
  mai un sistema di crafting nuovo.
- Almeno 3 insediamenti nuovi (oltre all'avamposto di Valle, che si
  completa riempiendo la capanna erborista vuota), distribuiti sia nella
  campagna (US-1015) sia dentro le regioni esistenti.
- NPC piazzati con più respiro fra loro (non più tutti in fila nello
  stesso punto della zona).
- Nessuna primitiva, nessun evento tracciato, nessuna categoria di
  oggetto nuova: solo un 7° tipo di effetto di dialogo (discusso qui
  esplicitamente, come impone CLAUDE.md) e due vocabolari chiusi nuovi
  (rarità, e i "ruoli" di crafter se servono).

## 3. Decisioni di design (da confermare, non ancora negoziabili come le regole di CLAUDE.md)

Queste sono le scelte tecniche fatte per scrivere story concrete. Se una
non ti convince, si cambia prima di eseguire — è più facile ora che a
metà story.

### 3.1 Rarità: 4 livelli, incide su prezzo e drop

`data/schema/item_rarity.json` (vocabolario chiuso, come `tags.json` o
`item_categories.json`): `comune`, `non_comune`, `raro`, `leggendario`.
Ogni oggetto (`data/items/*.json`) guadagna un campo `rarita` (default
`comune` per la retrocompatibilità del retrofit). Effetti:
- **Prezzo**: moltiplicatore per tier su `valore` in
  `data/balance.json` (es. `comune: 1.0, non_comune: 2.0, raro: 5.0,
  leggendario: 12.0`) — il prezzo mostrato/di vendita si calcola,
  `valore` nel file resta il prezzo BASE (a rarità comune).
- **Drop**: `enemy.gd`/`region_scene`-ora-`world_scene.gd` scelgono da
  `layout.drop[sequenza]` non più con probabilità uniforme, ma pesata
  per rarità (peso inversamente proporzionale al tier, tabella in
  `balance.json`).
- **UI**: colore/bordo diverso nell'inventario (pagina del libro) — CSS
  procedurale come già per gli altri riquadri, nessun asset nuovo.

### 3.2 Crafting NPC: riusa Forge/PotionSystem, un 7° effetto di dialogo

Oggi `Forge.forgia(blueprint_id)` e `PotionSystem.prepara(recipe_id)`
fanno ESATTAMENTE "controlla ingredienti in Inventory → consumali →
produci l'oggetto (con qualità da bonus di stanza/talento/sinergia)" — è
il motore che il libro del giocatore già chiama (`prepara` legge
`data/potions/recipes.json`, il registro dei consumabili come
`pozione_cura_minore` — un registro DIVERSO da `data/potions/formulas.json`,
che serve solo alla concoction di avanzamento di Sequenza). Non serve un
sistema di crafting nuovo: serve un modo per un NPC di offrirlo.

> **Corretto in corsa (US-1106)**: le due righe sotto erano sbagliate nella
> stesura originale del PRD (scritte prima di leggere `dialogue_engine.gd`
> per davvero). Gli effetti di dialogo in questo motore sono fire-and-forget
> — un side-effect quando si sceglie un'opzione — e MAI generano testo
> dinamico: il testo di ogni nodo è sempre statico, scritto nei dati. Non
> c'è un `Dictionary` di ritorno da mostrare a schermo. La soluzione reale
> ricalca `apri_vendita` (US-811): l'effetto apre una MODALITÀ che una
> pagina ascolta via segnale, con un piccolo menu (un bottone "Crea" per
> blueprint/ricetta noti all'NPC, disabilitato se mancano gli ingredienti) —
> non un blueprint/ricetta per singola scelta di dialogo.

- `data/schema/dialogue.schema.json`: i tipi di effetto di dialogo sono
  chiusi a 6 (`emit_event`, `flag`, `reputazione`, `apri_vendita`,
  `avvia_quest`, `impara_sinergia`, fase 6). Aggiungiamo il **7°**:
  `crea_su_richiesta`, `{ "tipo": "crea_su_richiesta" }` (npc_id opzionale,
  come `apri_vendita` — default l'interlocutore corrente). `DialogueEngine`
  emette un nuovo segnale `apri_creazione(npc_id)`; la pagina del libro
  ascolta e mostra TUTTO ciò che `npc.crafter` sa fare in un colpo solo.
- `Forge.forgia`/`PotionSystem.prepara` guadagnano un parametro opzionale
  `ignora_scoperta: bool` (default `false`, nessuna regressione): un NPC è
  un professionista, conosce il SUO mestiere a prescindere da cosa ha
  scoperto il giocatore — salta `blueprint_noto()`/`ricetta_nota()`.
- Il bottone "Crea" di ogni riga è disabilitato se mancano gli ingredienti
  (stesso helper `_coperto()` già in uso per il negozio/la base) — non
  serve mostrare un testo di fallimento dinamico: la UI comunica
  l'impossibilità come già fa il negozio con "Compra" disabilitato.
- Gli NPC guadagnano un campo opzionale `crafter: { "blueprints": [...],
  "ricette": [...] }` (id che sa fare — `ricette` risolve in
  `data/potions/recipes.json`, MAI `formule`/`formulas.json`), usato solo
  per popolare il menu di creazione — non un sistema a parte.

### 3.3 Insediamenti: riusa `edifici[]`/interno di US-1010..1012

Nessun concetto nuovo: un villaggio è N voci in `layout.edifici[]` + un
file in `data/world/interni/` per ognuna, esattamente come l'avamposto di
Valle o la torre dell'Archivio. Le assegnazioni di questa fase:
- **Riempire la capanna "erborista" già esistente** (Valle della Madre,
  vuota da US-1011) con l'alchimista nuovo — priorità 1, zero mappa da
  disegnare.
- **Un villaggio nuovo nella campagna** vicino a Marche del Crepuscolo
  (fabbro + mercante) — dimostra che la campagna ospita insediamenti
  veri, non solo alberi sparsi (chiudeva un "aperto" lasciato da
  US-1015).
- **Una bottega nuova dentro Mirwada** (un 5° edificio, il muro ha già
  spazio) — un fabbro, per "anche dentro le regioni esistenti" come
  richiesto.
- **Un villaggio nuovo nella campagna** vicino a Archivio Sepolto o
  Frontiera delle Porte (un secondo alchimista + un mercante di oggetti
  rari) — l'ultimo, a chiudere il giro.

Non tutti gli insediamenti futuri di ogni regione: 4 punti nuovi bastano
a rompere la sensazione di vuoto senza esplodere la dimensione della
fase (si può continuare in una fase successiva, vedi Non-Goals).

### 3.4 NPC meno ammassati

`world_scene.gd::_crea_npc_regione` oggi piazza gli NPC di una zona in
una riga al centro della zona, separati da `TILE * 1.5`. Si sostituisce
con una griglia (righe/colonne) che usa più dello spazio della zona
stessa, stesso principio di `_crea_zone`'s fallback quando non c'è un
rettangolo dichiarato — nessun dato nuovo, solo la formula di
posizionamento.

## 4. User Stories

### Blocco A — Fondamenta rarità

#### US-1101: Vocabolario chiuso della rarità
**Descrizione:** Come motore, ho bisogno di un vocabolario chiuso dei
livelli di rarità e di un campo `rarita` su ogni oggetto.
**Acceptance Criteria:**
- [ ] `data/schema/item_rarity.json`: 4 livelli (`comune`, `non_comune`,
      `raro`, `leggendario`), con un peso di drop e un moltiplicatore di
      prezzo ciascuno.
- [ ] Schema di `data/items/*.json` esteso con `rarita` (stringa,
      default `comune` se assente in un file — retrocompatibilità).
- [ ] `tools/validate_data.py`: nuovo blocco, ogni oggetto ha una
      `rarita` nel vocabolario chiuso.
- [ ] Tests pass. `python tools/validate_data.py` esce 0.

#### US-1102: Retrofit della rarità su ogni oggetto esistente
**Descrizione:** Come giocatore, voglio che gli oggetti che già esistono
abbiano una rarità sensata, non tutti "comune" per pigrizia.
**Acceptance Criteria:**
- [ ] Ogni oggetto in `data/items/*.json` (i ~345 esistenti) ha un campo
      `rarita` esplicito. Criterio: `valuta`/`materiale`/ingredienti
      "da mazzo" (usati in tante formule) restano `comune`; gli
      ingredienti che compaiono in UNA sola formula o in ricette di
      Sequenza alta diventano `non_comune`/`raro`; equip/sigilli/
      pergamene uniche (poche in tutto il gioco, es. `libro_ordine_minore`)
      diventano `raro` o `leggendario` — criterio scritto a mano in uno
      script Python che legge le formule/blueprint per contare le
      occorrenze, non a giudizio libero riga per riga.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione.
      Tests pass.

#### US-1103: La rarità incide sul prezzo
**Descrizione:** Come giocatore, voglio che un oggetto raro costi di più
di uno comune della stessa categoria.
**Acceptance Criteria:**
- [ ] `data/balance.json`: moltiplicatori di prezzo per rarità.
- [ ] Il prezzo mostrato/applicato in negozio (`apri_vendita`) usa
      `valore * moltiplicatore(rarita)`, non più `valore` nudo.
- [ ] Test: due oggetti con lo stesso `valore` base ma rarità diversa
      hanno prezzi diversi in negozio.
- [ ] Tests pass. `python tools/validate_data.py` esce 0.

#### US-1104: La rarità incide sul drop dai nemici
**Descrizione:** Come giocatore, voglio che gli oggetti rari droppino
più di rado di quelli comuni dalla stessa tabella.
**Acceptance Criteria:**
- [ ] La scelta da `layout.drop[sequenza]` (oggi presumibilmente
      uniforme — verificare leggendo `enemy.gd` prima di scrivere la
      story) diventa pesata per rarità (pesi da `data/schema/
      item_rarity.json`).
- [ ] Test statistico (tante estrazioni simulate, tolleranza) conferma
      che un oggetto `leggendario` esce molto meno spesso di uno
      `comune` nella stessa tabella.
- [ ] Tests pass. `python tools/validate_data.py` esce 0.

#### US-1105: La rarità si vede nell'inventario
**Descrizione:** Come giocatore, voglio riconoscere a colpo d'occhio se
un oggetto è raro.
**Acceptance Criteria:**
- [ ] La pagina inventario del libro colora/bordo ogni riquadro secondo
      `rarita` (4 colori distinti, nessun asset nuovo — `ColorRect`/
      `StyleBox` procedurali come il resto della UI).
- [ ] Tests pass. Verifica a schermo con Xvfb (screenshot in chat).

### Blocco B — Crafting NPC (fabbro/alchimista)

#### US-1106: Il 7° effetto di dialogo — `crea_su_richiesta` — ✅ FATTO
**Descrizione:** Come motore, voglio un effetto di dialogo generico che
apra un menu "crea per te" per un NPC, riusando Forge/PotionSystem.
**Acceptance Criteria:**
- [x] `data/schema/dialogue.schema.json`: `crea_su_richiesta` aggiunto
      al vocabolario chiuso dei 6 effetti (ora 7). Nessun `valore`
      obbligatorio (`npc_id` opzionale, come `apri_vendita`).
- [x] `Forge.forgia`/`PotionSystem.prepara` guadagnano un parametro
      opzionale `ignora_scoperta: bool = false` (default invariato,
      nessuna regressione sul crafting del giocatore).
- [x] `DialogueEngine` emette `apri_creazione(npc_id)`; `page_dialogo.gd`
      lo ascolta e mostra un bottone "Crea" per ogni blueprint/ricetta di
      `npc.crafter`, disabilitato se mancano gli ingredienti (`_coperto()`,
      lo stesso helper del negozio) — non un testo dinamico per esito.
- [x] Tests pass. `python tools/validate_data.py` esce 0.

#### US-1107: NPC crafter — il campo `crafter`
**Descrizione:** Come team, vogliamo dichiarare su un NPC cosa sa creare.
**Acceptance Criteria:**
- [ ] `data/schema/npc.schema.json`: campo opzionale `crafter: {
      "blueprints": [...], "ricette": [...] }` (array di id, ognuno deve
      esistere nel rispettivo registro — `ricette` risolve in
      `data/potions/recipes.json`, MAI `formule`/`formulas.json` — validato).
- [ ] `tools/validate_data.py`: ogni id in `crafter.blueprints`/
      `crafter.ricette` esiste davvero.
- [ ] Tests pass. `python tools/validate_data.py` esce 0.

#### US-1108: Il primo fabbro — riempie la capanna erborista di Valle
**Descrizione:** Come giocatore, voglio trovare un alchimista vero nella
capanna "erborista" dell'avamposto di Valle della Madre, oggi vuota.
**Acceptance Criteria:**
- [ ] Nuovo NPC nel roster (id, nome, ruolo, `region_id: valle_madre`,
      `schedule` nella capanna erborista, `crafter.ricette` con almeno 1
      formula esistente), grafo di dialogo con una scelta
      `crea_su_richiesta`.
- [ ] `data/world/interni/valle_avamposto_erborista.json`: l'interno
      oggi vuoto guadagna l'NPC (posizionato dentro, non fuori).
- [ ] Test: il dialogo con l'NPC, con gli ingredienti giusti in
      inventario, produce la pozione; senza, fallisce col messaggio
      giusto.
- [ ] Tests pass. `python tools/validate_data.py` esce 0. Verifica a
      schermo con Xvfb (screenshot in chat): si parla con l'NPC, gli si
      commissiona la pozione, appare nell'inventario.

#### US-1109: Un fabbro dentro Mirwada
**Descrizione:** Come giocatore, voglio un fabbro raggiungibile dentro
Mirwada stessa, non solo nei villaggi lontani.
**Acceptance Criteria:**
- [ ] `data/world/layouts/mirwada.json`: un 5° `edifici[]` (una bottega),
      con un nuovo `data/world/interni/mirwada_bottega_del_fabbro.json`.
- [ ] Nuovo NPC fabbro (`crafter.blueprints` con almeno 1 blueprint
      esistente + una nuova arma - vedi US-1110), grafo di dialogo con
      `crea_su_richiesta`.
- [ ] Tests pass. `python tools/validate_data.py` esce 0. Verifica a
      schermo con Xvfb.

#### US-1110: Più ricette da fabbricare (blueprint/ricette nuove)
**Descrizione:** Come giocatore, voglio più di 3 blueprint e più
ricette fra cui scegliere quando parlo con un artigiano.
**Acceptance Criteria:**
- [ ] Almeno 3 `blueprints` nuovi in `data/forge/blueprints.json`
      (armi/equip diversi da quelli esistenti, ingredienti già presenti
      nel gioco) e 3 `ricette` nuove in `data/potions/recipes.json`
      (MAI `formulas.json`, che serve solo alla concoction di
      avanzamento di Sequenza), almeno una con un ingrediente/output di
      rarità `non_comune`+.
- [ ] `python tools/validate_data.py` esce 0. Tests pass.

### Blocco C — Villaggi nuovi (campagna + regioni)

#### US-1111: Villaggio nella campagna vicino a Marche del Crepuscolo
**Descrizione:** Come giocatore, voglio un piccolo insediamento nella
campagna (non dentro nessuna regione), a dimostrazione che la campagna
non è solo alberi sparsi.
**Acceptance Criteria:**
- [ ] Nuovo `data/world/campagna.json` (o una struttura dedicata se
      `campagna.json` non supporta `edifici[]` - da estendere se serve,
      stesso principio di `layout.edifici[]`): 2-3 capanne (fabbro +
      mercante), fuori dal rettangolo di ogni regione, vicino alla
      breccia del muro di Marche (US-1015).
- [ ] 2 nuovi interni in `data/world/interni/`, con l'NPC fabbro di
      questo villaggio dentro una delle capanne.
- [ ] `python tools/validate_data.py` esce 0. Tests pass. Verifica a
      schermo con Xvfb (screenshot in chat): si cammina dalla breccia al
      villaggio, si entra in una capanna.

#### US-1112: Villaggio nella campagna vicino ad Archivio Sepolto/Frontiera
**Descrizione:** Come giocatore, voglio un secondo insediamento in
campagna con un alchimista e un mercante di oggetti rari.
**Acceptance Criteria:**
- [ ] Stesso schema di US-1111: 2-3 capanne in campagna, un alchimista
      (`crafter.ricette`) + un mercante col listino che include almeno
      un oggetto `raro`/`leggendario` (prezzo alto, US-1103).
- [ ] `python tools/validate_data.py` esce 0. Tests pass. Verifica a
      schermo con Xvfb.

### Blocco D — NPC meno ammassati

#### US-1113: Piazzamento NPC a griglia, non in fila
**Descrizione:** Come giocatore, voglio che gli NPC di una stessa zona
non siano tutti appiccicati sullo stesso punto.
**Acceptance Criteria:**
- [ ] `world_scene.gd::_crea_npc_regione`: la formula di piazzamento
      diventa una griglia che usa una porzione più ampia dell'area della
      zona (righe/colonne in base al numero di NPC), non più una riga
      unica al centro.
- [ ] Test: con N>3 NPC nella stessa zona, la distanza minima fra due
      NPC qualsiasi è maggiore di quella di oggi (regressione esplicita
      sul valore precedente).
- [ ] Tests pass. `python tools/validate_data.py` esce 0. Verifica a
      schermo con Xvfb.

### Blocco E — Chiusura

#### US-1114: Chiusura fase 11
**Descrizione:** Come team, vogliamo la fase chiusa nella documentazione,
e "Atto II e Atto III" rinumerata a fase 12.
**Acceptance Criteria:**
- [ ] `006_PRD/prd-fase-11-atto-2-3.md` rinominato in
      `006_PRD/prd-fase-12-atto-2-3.md`, contenuto invariato salvo i
      riferimenti al numero di fase.
- [ ] `006_PRD/roadmap.md`: "Fase 11 — Atto II e Atto III" diventa
      "Fase 12"; "Fase 12 — Opzionale" (Pathway Non-Standard) diventa
      "Fase 13".
- [ ] `tools/validate_data.py`: blocco "chiusura fase 11" (almeno 4
      insediamenti con un `crafter` raggiungibile, rarità su ogni
      oggetto, il 7° effetto di dialogo usato almeno una volta).
- [ ] `progress.txt`, `CLAUDE.md` (§ Fasi), `README.md`,
      `006_PRD/roadmap.md` aggiornati a "Fase 11: CHIUSA".
- [ ] `prd.json`: tutte le story a `passes: true`.
- [ ] Checkpoint dinamico (stesso schema di `test_fase_10_checkpoint.gd`):
      zero righe di codice che nominino un villaggio/NPC/blueprint/
      formula specifici — lista vietata scoperta dai dati.

## 5. Functional Requirements

- FR-1: Ogni oggetto (`data/items/*.json`) ha un campo `rarita` da un
  vocabolario chiuso di 4 valori.
- FR-2: Il prezzo di un oggetto in negozio è `valore * moltiplicatore(rarita)`.
- FR-3: La scelta di un drop da `layout.drop[sequenza]` è pesata per
  rarità, non uniforme.
- FR-4: Un 7° tipo di effetto di dialogo (`crea_su_richiesta`) invoca
  `Forge.forgia`/`PotionSystem.prepara` con `ignora_scoperta: true`.
- FR-5: Un NPC può dichiarare `crafter.blueprints`/`crafter.ricette`.
- FR-6: Almeno 4 insediamenti nuovi/completati (Valle-erborista, Mirwada-
  bottega, 2 villaggi in campagna), ognuno con almeno un NPC crafter
  raggiungibile ed entrabile.
- FR-7: Gli NPC di una zona con più di 3 presenze si dispongono a
  griglia, non in fila.

## 6. Non-Goals (fuori scope)

- Non tutte le regioni/zone ricevono un villaggio in questa fase — solo
  i 4 punti del §3.3. Altri insediamenti sono una fase successiva.
- Nessuna interfaccia grafica nuova per "scegliere cosa commissionare"
  oltre alle scelte del dialogo esistente (stesso `DialogueEngine` di
  sempre, non una schermata dedicata).
- Nessuna rarità che sblocca contenuto esclusivo (missioni/aree) — solo
  prezzo e drop, come deciso in §3.1.
- Nessuna nuova primitiva, nessun nuovo evento tracciato, nessuna nuova
  categoria di oggetto (`item_categories` resta chiuso a 7).
- Il crafting del giocatore nel libro (Alchimia/Forgia esistenti) non
  cambia: gli NPC sono un canale IN PIÙ, non una sostituzione.

## 7. Technical Considerations

- `Forge.forgia`/`PotionSystem.prepara`: verificare all'implementazione
  (US-1106) la firma esatta e il `Dictionary` di ritorno prima di
  aggiungere `ignora_scoperta`, per non rompere i chiamanti esistenti
  (le pagine del libro).
- `data/world/campagna.json` oggi non ha un campo `edifici[]` (solo
  `nemici[]`/`oggetti[]`, coordinate assolute, US-1015) — US-1111/1112
  lo estendono, stesso principio di `layout.edifici[]` ma senza un
  `world_offset` proprio (coordinate assolute, come già `nemici`/
  `oggetti` della campagna).
- Retrofit rarità (US-1102): scrivere uno script Python che legge
  formule/blueprint per contare le occorrenze di ogni ingrediente prima
  di assegnare la rarità — non decidere a giudizio riga per riga su 345
  oggetti.

## 8. Success Metrics

- 4+ insediamenti raggiungibili con un NPC crafter dentro, verificati a
  schermo con Xvfb.
- Ogni oggetto del gioco ha una rarità; un oggetto leggendario costa
  visibilmente di più e droppa visibilmente meno spesso di uno comune
  (verificato con un test statistico, non solo a occhio).
- Zero righe di codice del motore che nominino un villaggio/NPC/
  blueprint/formula specifici (checkpoint dinamico, come ogni fase).

## 9. Open Questions

- Il moltiplicatore di prezzo esatto per tier (§3.1) è una proposta di
  partenza — va tarato in playtest, non è vincolante.
- Se in futuro si vuole che la rarità sblocchi anche statistiche
  migliori (non solo prezzo/drop), è un'estensione successiva — il
  campo `rarita` è già lì per riusarlo.
