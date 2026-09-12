# PRD: Fase 8 — Vertical slice giocabile (mondo, avanzamento, grafica)

> Scritto il 2026-09-09 in una sessione Claude Code, dopo aver **giocato il
> gioco per davvero** (Xvfb + screenshot) e tre esplorazioni indipendenti del
> codice. Ogni riferimento `file:riga` qui sotto è stato verificato su quel
> commit (`d7d450e`, fine fase 7). Le istruzioni operative per eseguire
> questo PRD (ordine, `/ralph`, comandi, trappole note) sono in
> `006_PRD/prossimi-passi.md`.

## 1. Introduzione / Overview

Le fasi 1-7 hanno costruito **tutti i sistemi** del gioco: 10 Pathway
completi (100/100 Sequenze), il motore delle 28 primitive, l'Acting Method,
la follia, inventario/alchimia/forgia/base/pet/talenti, 44 sinergie, il mondo
(5 regioni, tempo, 19 NPC, dialoghi, fazioni, quest, mappa), l'endgame
(cambio Pathway, tribolazioni, 3 finali, eredità). 776 test headless verdi.

**Ma nessuno può giocarlo con la tastiera.** L'utente ha premuto Play e si
è trovato in una griglia vuota con un solo nemico. Verificato: `main.tscn`
(la scena che Godot avvia, `project.godot:13`) è rimasta la scena di prova
della fase 1 e **nulla collega i sistemi a una partita reale**. Nel
dettaglio, sei blocchi che nessun playtest a tastiera supera:

1. **L'avvio non avvia una partita.** Nessuno chiama `Book.apri()` o
   `GameState.nuova_partita()`: all'avvio `GameState.partita_attiva ==
   false`, `Progression._pathway_id == ""` (fallback su
   `balance.json.progressione.pathway_default`), inventario vuoto,
   `BaseSystem` con 0 stanze e 0 appezzamenti. `main.tscn` istanzia la
   regione `mirwada`, il player, **un** `Enemy` a coordinate fisse
   (`scenes/main.tscn:21-22`) e gli overlay. La creazione del personaggio
   (`page_creazione_personaggio.gd`) non offre la scelta del Pathway.
2. **Nessun tasto lancia un'abilità.** `player.gd` gestisce solo `attacco`,
   `schivata`, `parata` e il movimento (`project.godot` input map).
   `AbilityEngine.execute(ability_id, caster)` (`ability_engine.gd:110`) è
   chiamato solo da sistemi interni (fusioni, oggetti, sinergie) e dai test;
   `debug_scene.gd` (tasti 1-5) lancia primitive grezze via
   `esegui_primitiva`, non abilità vere, e si autodistrugge fuori dai build
   di debug. Le due abilità di Sequenza 9 del Twilight Giant
   (`tg_fendente_pesante`, `tg_stretta_ferrea`) sono possedute dal primo
   secondo (`owned_abilities`, `:378`) e nessuno può usarle. L'HUD
   (`hud.gd`) mostra HP/Spiritualità/Recitazione, nessuna abilità.
3. **Le abilità a proiettile/arco non fanno danno.** `projectile.gd` e
   `melee_arc.gd` non hanno `collision_mask` né `area_entered`/`body_entered`:
   sono solo cinematica. L'unico oggetto che colpisce davvero è
   `hitbox.gd:52-61` (chiama `Hurtbox.subisci(danno, stagger, da,
   {"tag_danno": tag})`).
4. **La recitazione non può avanzare.** `enemy.gd:188` emette
   `enemy_defeated` con payload `{}`: il filtro `senza_abilita: true`
   dell'azione `tg_9_duello_puro` non matcha mai (`event_tracker.gd:
   _corrisponde`: un filtro booleano pretende `== true`).
   `damage_absorbed_for_ally` (`tg_9_protettore`, 35% della Sequenza 9) non
   ha nessun emettitore: non esistono alleati in scena. `item_crafted`,
   `area_cleared`, `ritual_completed` non sono mai emessi dal codice di
   gioco; `ability_used` dipende dal punto 2. Risultato: la barra
   "Recitazione" del Twilight Giant a Sequenza 9 si ferma intorno all'1.5%.
5. **Nessuno può salire di Sequenza.** `PotionSystem.concoct/bevi`
   (`potion_system.gd:22,97`) non ha nessuna pagina o tasto che li chiami;
   e i **299 ingredienti** delle 100 formule (`data/potions/formulas.json`,
   campo `ingredients`: es. `ferro_temperato`, `sangue_di_toro`,
   `radice_di_quercia` per il TG 9) **non esistono come oggetti**:
   `data/items/ingredienti.json` ne ha 8, tutti diversi. Nessun drop,
   nessun listino, nessuna raccolta li fornisce (verificato: gli unici
   `Inventory.aggiungi` in gioco sono giardino — che consuma un ingrediente
   già posseduto —, forgia, pozioni, ricompensa quest `item` mai usata dai
   dati, eredità). Il negozio di Sidon esiste nei dati
   (`roster.json` `vendor.listino`) ma **nessuno ascolta**
   `DialogueEngine.apri_vendita` (`dialogue_engine.gd:20,145`).
6. **Il mondo è vuoto e senza grafica.** `region_scene.gd::_dipingi()`
   riempie un rettangolo 48×36 di pavimento con un bordo di muri, uguale
   per le 5 regioni; 0 nemici da dati, 0 oggetti a terra; gli NPC sono
   quadrati blu senza nome (`_crea_npc`, `:189`); gli sprite sono i
   placeholder diagnostici (ellisse + cifra del frame) di
   `tools/generate_placeholders.py`.

La fase 8 chiude questi sei blocchi **senza aggiungere sistemi**: collega
quelli che ci sono, riempie i dati mancanti, e mette una grafica
procedurale provvisoria che rispetta `arte/`. Tutto il resto del progetto
(motori, vocabolari chiusi, save v22) resta com'è.

### Scelte di scope prese con l'utente (2026-09-09)

- **"Voglio poter fare tutto il gioco come se fosse finito"**: la slice
  copre il ciclo completo — avvio, creazione con scelta del Pathway,
  esplorazione, combattimento con più nemici e boss, raccolta, NPC con
  dialoghi e **negozio (compra/vendi, in questo giro)**, abilità a
  tastiera, recitazione che avanza, pozione e **salita di Sequenza**,
  passaggio alle altre 4 regioni.
- **Tutti i 299 ingredienti diventano oggetti con almeno una fonte nel
  mondo** ("deve esserci tutto"), non solo quelli del primo Pathway.
- **`tg_9_protettore` si riscrive nei dati** (nessun alleato in scena in
  questa fase): diventa un'azione su `perfect_parry`.
- **Mappe disegnate a mano in ASCII** (`data/world/layouts/<region>.json`),
  una per regione: sono dati, si leggono e si correggono con un editor di
  testo, il validator le controlla.
- **Grafica provvisoria generata** (pixel art procedurale deterministica,
  32×32, palette e regole di `arte/03`/`arte/04`), stessa geometria dei
  fogli attuali: quando arriverà l'arte vera basterà sostituire i PNG.
- **Un boss non è un tipo**: è un nemico con `override` di dati (più
  danno, più aggro, Sequenza più bassa, Caratteristica più rara) e una
  `scala` visiva. Zero `if boss` nel codice.
- **Respawn**: nemici e oggetti a terra si ricreano a ogni ingresso nella
  regione (la scena si ricostruisce). Scelta esplicita per la slice; la
  persistenza è fuori scope (§ 5).
- **Numerazione**: questa è la **Fase 8**. "Pathway Non-Standard"
  (avanzamento per Boon) slitta a **Fase 9**: gia' fatto in
  `roadmap.md`, `CLAUDE.md` e `README.md` nel commit che introduce questo PRD.

Le tre regole di `CLAUDE.md` restano in vigore e sono state verificate
contro ogni story: **nessuna primitiva, nessun evento tracciato, nessun
tag nuovo**; nessun nome di Pathway/NPC/oggetto hardcoded fuori dai dati;
diff minimo che riusa i pattern esistenti. Save `schema_version` **22,
invariato**: layouts, oggetti, listini, sprite sono dati o asset, non
stato.

---

## 2. Goals

- **Avvio reale**: Play → libro sullo scaffale → nuovo personaggio con
  **nome + Pathway scelto tra i 10** → partita che parte dalla regione hub.
  `GameState.partita_attiva == true`, `Progression.pathway_id()` = quello
  scelto.
- **Abilità a tastiera**: tasti 1-4 → `AbilityEngine.execute` sull'abilità
  N-esima di `owned_abilities(player)`; hotbar nell'HUD con nome i18n e
  cooldown. Proiettili e archi **colpiscono** le Hurtbox come l'hitbox.
- **Recitazione viva**: `enemy_defeated` con payload reale (`senza_abilita`,
  `senza_subire_danno`, `sequenza_bersaglio`, `tag_nemico`); `item_crafted`,
  `ritual_completed`, `area_cleared` emessi dai punti giusti;
  `tg_9_protettore` riscritta. La Sequenza 9 del TG è completabile al 100%.
- **Mondo dai layout**: 5 mappe ASCII disegnate a mano (48×36) con zone per
  ogni `location_tag`, passaggi, spawn, **nemici** (con override e boss),
  **oggetti a terra**; validate dal validator; `region_scene.gd` le legge.
  Nessuna regione con 0 nemici.
- **Economia degli ingredienti**: i 299 ingredienti sono item con nome
  IT/EN; ogni ingrediente di una formula di un Pathway attivo ha **≥1
  fonte** fra drop dei nemici (per regione/Sequenza), listini dei
  venditori, raccolta a terra. Check del validator.
- **Salire di Sequenza dal libro**: pagina diagramma → sezione Avanzamento
  → *Prepara* (concoction, anche parziale con penalità dichiarata) →
  *Bevi* (pieno o forzato con la follia scritta accanto) → Sequenza 8.
- **Negozio**: dialogo con un venditore → compra (a `valore`) / vendi (a
  `valore/2`) → inventario e `moneta_comune` aggiornati.
- **Grafica leggibile**: sprite a strati per personaggio/nemico/pet
  (19 fogli, geometria invariata), NPC con sprite e **nome**, icone degli
  oggetti, tileset a righe (una palette per regione: neutra + le 4 di
  `vfx.json`), passaggi e gate visibili.
- **Criterio di uscita**: un test manuale Xvfb (`tests/manual/qa_vslice.gd`)
  gioca la slice end-to-end (creazione → raccolta → abilità → boss →
  negozio → Prepara/Bevi → Sequenza 8) con asserzioni e screenshot; grep
  di `scripts/` per un id di Pathway/NPC/oggetto/regione → **0** (come nei
  checkpoint delle fasi 2, 5, 5b, 7).

---

## 3. User Stories

Ogni story chiude in una context window (regola 3 di `CLAUDE.md`); le
dipendenze vanno **solo all'indietro**. Ogni story finisce con:
`python tools/validate_data.py` esce 0, nessuna regressione sui 776 test,
`progress.txt` + `prd.json` aggiornati, commit `US-8NN: <cosa>` dei soli
file toccati. Le story con UI/gameplay hanno la verifica a schermo (Xvfb)
documentata in `progress.txt`.

### Blocco 0 — Avvio e controlli

#### US-801: Avvio di partita vero + scelta del Pathway

**Description:** Come giocatore, voglio che premendo Play il gioco mi
faccia creare (o caricare) un personaggio, scegliendo il Pathway, e poi mi
metta nel mondo — come un gioco finito.

**Acceptance Criteria:**

- [ ] `scripts/main.gd` (nuovo, attaccato al nodo `Main` di
      `scenes/main.tscn`): in `_ready()` chiama `Book.apri()`
      (`book.gd:67`; il libro apre sulla prima pagina per `ordine`, cioè
      `copertina` = scaffale/menu principale, `data/ui/book.json`). Si
      connette a `GameState.partita_iniziata(nome)` (`game_state.gd:15`) e
      ricostruisce la regione corrente con lo **stesso meccanismo** di
      `region_scene._viaggia_verso` (`:301`: istanzia
      `scenes/regioni/<id>.tscn`, libera la vecchia, ricolloca il player),
      così nemici e oggetti (US-806) ripartono puliti a ogni nuova partita.
      Verificare che `partita_iniziata` sia emesso anche da `carica_slot`
      (se no, emetterlo lì: stesso contratto).
- [ ] `scripts/pages/page_creazione_personaggio.gd`: un `OptionButton` con
      i Pathway attivi (`GameData.pathway_ids()`, `:685`; nome via
      `tr_data(get_pathway(id).name_i18n)`), preselezionato su
      `balance.json.progressione.pathway_default`. Il bottone di conferma
      passa l'id scelto.
- [ ] `GameState.nuova_partita(nome, slot, talenti_innati, pathway_id := "")`:
      4° parametro opzionale, passato a `Progression.configura(pathway_id, 9)`
      (oggi `configura("", 9)`, `game_state.gd:187`). Con `""` il
      comportamento resta identico (fallback al default): i test esistenti
      non cambiano. Il save non cambia (Progression salva già il pathway).
- [ ] `scenes/main.tscn`: aggiunto lo script `main.gd`. Il nodo `Enemy`
      hardcoded **resta** finché US-806 non lo sostituisce coi nemici dei
      layout (ogni commit deve restare giocabile).
- [ ] Test `tests/test_main_boot.gd`: istanziando `main.tscn` headless il
      libro risulta aperto sulla `copertina`; `nuova_partita("X", 1, [],
      "<un id da pathway_ids()>")` configura Progression su quel Pathway e
      Sequenza 9; con `""` usa il default. I test che chiamano
      `nuova_partita` azzerano `GameState._partita_attiva` prima e dopo
      (convenzione di `tests/test_creazione_talenti.gd`) e chiudono il
      libro (`Book.chiudi()`), altrimenti le suite alfabeticamente
      successive falliscono (trappola nota, vedi `prossimi-passi.md`).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-802: Abilità a tastiera + hotbar nell'HUD

**Description:** Come giocatore, voglio lanciare le abilità del mio
Pathway coi tasti 1-4 e vedere nell'HUD quali sono e quando tornano
disponibili.

**Acceptance Criteria:**

- [ ] `project.godot`: 4 azioni nuove `abilita_1`..`abilita_4` (tasti 1-4),
      stesso stile delle voci `attacco`/`schivata`/`parata`.
- [ ] `scripts/player.gd`: in `_physics_process`, per N in 1..4, se
      `Input.is_action_just_pressed("abilita_N")`: `owned =
      AbilityEngine.owned_abilities(self)` (`:378`); se esiste `owned[N-1]`
      → `AbilityEngine.execute(owned[N-1], self)` (`:110`, che già gestisce
      possesso, cooldown, condizioni, costo, `ability_used`). Se `ok`,
      riproduce l'animazione `cast` (già in `data/animations.json`). Nessuna
      logica di bersaglio nuova. Non lancia col libro aperto (albero in
      pausa) né durante dash/stagger (stessi guard di `attacco`).
- [ ] `scripts/hud.gd` + `scenes/hud.tscn`: riga `Hotbar` (`HBoxContainer`
      di 4 `Label`) sotto la barra Recitazione. Testo per slot:
      `"N  <tr_data(ability.name_i18n)>  <cooldown residuo, 1 decimale>"`
      oppure `tr("HUD_HOTBAR_VUOTO")` (chiave nuova in
      `assets/i18n/strings.csv` IT/EN). Aggiornata su
      `AbilityEngine.ability_executed` e `Progression.sequence_changed`
      (`progression.gd:19`), e ogni 0.1 s per il cooldown
      (`AbilityEngine.cooldown_left(caster, id)`, `:276`) — stesso pattern
      della barra Acting. Mai un nome hardcoded.
- [ ] Test: `tests/test_player_abilita.gd` — con un player finto in gruppo
      `player` e Progression configurata, simulare l'azione `abilita_1`
      (`Input.action_press` + un frame) → `ability_executed` emesso con
      `owned[0]`; `abilita_3` senza terza abilità → nessun errore, nessun
      evento. `tests/test_i18n_hud.gd` esteso: la hotbar non contiene testo
      fuori da `tr`/`tr_data`.
- [ ] Verifica Xvfb: screenshot con la hotbar popolata e un cooldown in
      corso, in `progress.txt`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-803: Proiettili e archi che colpiscono

**Description:** Come giocatore, voglio che un'abilità a proiettile o ad
arco faccia danno quando tocca un nemico, come già fa l'attacco base.

**Acceptance Criteria:**

- [ ] `scripts/projectile.gd`: `collision_mask` = quello delle Hurtbox
      (leggere il valore usato da `hitbox.gd`, non un numero nuovo),
      `monitoring = true`, `area_entered` → se `a.has_method("subisci")` e
      `a` non è la hurtbox del caster → `a.call("subisci", danno, stagger,
      caster, {"tag_danno": tag})` (identico a `hitbox.gd:61`);
      `registra_colpo(bersaglio)` (`:50`) già decide pierce/colpi residui.
- [ ] `scripts/melee_arc.gd`: stesso collegamento; filtra con
      `dentro_arco(punto_globale)` (`:48`) prima di colpire; un bersaglio
      colpito una sola volta per arco.
- [ ] Il caster arriva a `setup()` come argomento **opzionale in coda**
      (`projectile.setup(spec, posizione, direzione, caster = null)`,
      `melee_arc.setup(spec, direzione, caster = null)`): i chiamanti
      esistenti e i test (`setup(spec, pos, dir)`) restano validi.
      `AbilityEngine` passa il caster dove istanzia i due nodi.
- [ ] Danno/stagger/tag letti dallo `spec` della primitiva (già presenti nei
      dati delle abilità), nessun valore nel codice.
- [ ] Test `tests/test_projectile_hit.gd`: proiettile lanciato su una
      Hurtbox finta → `subisci` chiamato una volta con il tag della
      primitiva; con `pierce` N attraversa N bersagli; arco fuori angolo
      non colpisce; la hurtbox del caster non viene colpita.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco A — Recitazione che avanza davvero

#### US-804: Eventi di recitazione emessi con payload vero + `tg_9_protettore`

**Description:** Come giocatore, voglio che le azioni di recitazione della
mia Sequenza avanzino quando faccio davvero quelle cose in gioco.

**Acceptance Criteria:**

- [ ] `scripts/enemy.gd::_su_morte` (`:176-189`): `enemy_defeated` con
      payload dai filtri di `data/schema/tracked_events.json`:
      `senza_abilita` (true se il player non ha emesso
      `AbilityEngine.ability_executed` da quando il nemico è entrato in
      INSEGUIMENTO), `senza_subire_danno` (true se nessun
      `Hurtbox.colpito` del player con `danno > 0` nello stesso intervallo —
      la parata perfetta emette con 0, `hurtbox.gd:84`),
      `sequenza_bersaglio` (dalla propria `StatsComponent`; il filtro
      `sequenza_bersaglio_max` legge il campo senza suffisso,
      `event_tracker.gd::_corrisponde`), `tag_nemico` da `_cfg.tag` (arriva
      dall'`override` del layout, US-806; assente → `""`). I booleani sono
      emessi **espliciti** (`false` incluso): i test che emettono `{}`
      restano validi. `tipo_arma` rimandato (nessuna Sequenza 9 lo usa;
      nota in `progress.txt`).
- [ ] `scripts/potion_system.gd` (in `concoct`, dopo il successo) e
      `scripts/forge.gd::forgia`: `EventTracker.emit_event("item_crafted",
      {"categoria": <categoria dell'item prodotto>, "qualita": <se
      esiste>})`. Sblocca `q_sidon_01` (che apre la vendita di Sidon: il
      negozio "si guadagna").
- [ ] `scripts/ritual_system.gd` (alla conclusione del rituale):
      `emit_event("ritual_completed", {})`.
- [ ] `area_cleared`: emesso da `region_scene.gd` alla morte dell'ultimo
      nemico spawnato dal layout (`senza_uccidere: false`, `senza_abilita`
      come sopra). Dipende da US-806: **il codice va in US-806**, qui solo
      il contratto documentato.
- [ ] `data/pathways/twilight_giant.json`: `tg_9_protettore` →
      `{"evento": "perfect_parry", "filtri": {}, "target": 12,
      "progresso": 0.35, "ripetibile": true, "descrizione": "Para
      perfettamente 12 colpi"}`; `data/i18n/it.json`/`en.json` aggiornati
      sulla chiave esistente `acting.twilight_giant.tg_9_protettore`.
      Grep: `damage_absorbed_for_ally` compare **solo** lì nei Pathway attivi
      (verificato); resta nel vocabolario chiuso (i differiti lo usano).
- [ ] Test `tests/test_enemy_payload.gd`: nemico ucciso senza abilità →
      payload `senza_abilita: true`; dopo un `ability_executed` del player →
      `false`; `sequenza_bersaglio` = Sequenza dello StatsComponent.
      `tests/test_acting.gd` esteso: `tg_9_duello_puro` avanza con 3 kill
      senza abilità e non con 3 kill dopo un'abilità.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco B — Il mondo dai layout

#### US-805: Formato dei layout + loader + validator + Mirwada disegnata

**Description:** Come designer, voglio disegnare la mappa di una regione
in un file di testo (muri, acqua, sentieri, zone, passaggi, spawn) e
vederla nel gioco senza toccare codice.

**Acceptance Criteria:**

- [ ] `data/schema/layout.schema.json` (documentazione, come gli altri
      schema) + primo file `data/world/layouts/mirwada.json`:
      ```json
      {
        "schema_version": 1,
        "region_id": "mirwada",
        "mappa": ["################...", "...36 righe di 48 caratteri..."],
        "spawn": [4, 4],
        "zone": { "porto": [36, 26, 10, 8], "piazza": [20, 14, 8, 8] },
        "passaggi": { "marche_crepuscolo": [46, 8], "valle_madre": [46, 20] },
        "nemici": [],
        "oggetti": [],
        "drop": {}
      }
      ```
      Legenda **fissa** (documentata nello schema): `.` pavimento,
      `,` pavimento variante, `=` sentiero, `#` muro, `o` ostacolo
      (roccia), `t` ostacolo 2 (albero/pilastro), `~` acqua (solida: blocca,
      non si nuota), `+` decoro calpestabile. Coordinate in celle
      (x, y, w, h). `nemici`/`oggetti`/`drop` arrivano in US-806/US-809:
      qui esistono vuoti.
- [ ] `scripts/game_data.gd`: `_load_layouts()` (copia del pattern di
      `_load_quests`, `:768`) + `get_layout(region_id) -> Dictionary`
      (`{}` se assente). Hot-reload come gli altri dati.
- [ ] `scripts/region_scene.gd`: `SPAWN` da `const` a valore letto dal
      layout con fallback `(4, 4)`; `_dipingi()` legge `mappa` (fallback al
      riempimento piatto attuale se il layout manca — le altre 4 regioni
      restano com'erano fino a US-807); mappa carattere → tile
      (pavimento/muro già esistono in `tileset.tres`; gli altri 6 tipi
      arrivano con US-813: fino ad allora `o`/`t`/`~` usano il tile muro e
      `,`/`=`/`+` il pavimento — **il comportamento fisico è già giusto**,
      la grafica arriva dopo); `_crea_zone()` usa `zone[tag]` se presente,
      nomi dei nodi `Zona_<tag>` invariati (li cerca `_crea_npc`);
      `_crea_passaggi()` usa `passaggi[id]` se presente, altrimenti il
      bordo come oggi.
- [ ] `tools/validate_data.py`, blocco "layouts": esattamente 36 righe ×
      48 caratteri; solo caratteri della legenda; bordo esterno tutto `#`;
      `spawn` e ogni coordinata di `zone`/`passaggi` dentro i limiti e su
      cella calpestabile; `zone` ⊆ `location_tags` della regione **e** ogni
      `location_tag` della regione ha una zona (le zone senza layout
      restano in griglia come oggi → warning, non errore, finché US-807
      non chiude); `passaggi` verso regioni esistenti.
- [ ] Mirwada disegnata a mano come **città portuale**: banchina e acqua
      (`~`) a sud-est nella zona `porto`, piazza centrale, vicoli, un
      quartiere per ogni `location_tag` di `regions.json`, i passaggi sul
      bordo est verso le 4 regioni. Leggibile a schermo.
- [ ] Attenzione ai test che istanziano le 5 scene regione headless
      (`tests/test_regions.gd`, `test_area_gate.gd` conta i figli per
      script, `test_page_mappa.gd`): il conteggio dei nodi zona/passaggio
      non deve cambiare tipo; se cambia numero, aggiornare il test con la
      motivazione.
- [ ] Test `tests/test_layouts.gd`: regione con layout → la cella `#` è
      solida (`get_cell_source_id`/`tile_data` del layer), `~` solida,
      `.` no; spawn dal dato; zona `porto` nel rettangolo dichiarato;
      passaggio nella cella dichiarata. Regione senza layout → identica a
      prima (nessuna regressione).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-806: Nemici, boss e oggetti a terra dai layout (Mirwada popolata)

**Description:** Come giocatore, voglio trovare nel mondo più nemici, un
boss riconoscibile e oggetti da raccogliere, tutti dichiarati nei dati
della regione.

**Acceptance Criteria:**

- [ ] Layout, campo `nemici`: `[{"x", "y", "sequenza": 9..0, "scala":
      1.0, "override": {...}}]`. `override` è un sottoinsieme delle chiavi di
      `balance.json.nemico_base` (es. `danno_attacco`, `raggio_aggro`,
      `caratteristica: {pathway_id, sequence, probabilita}`, `tag`,
      `oggetti_a_morte` da US-809). **Un boss** = `sequenza` più bassa +
      `override` più duro + `scala` 1.5; nessun flag `boss`.
- [ ] `scripts/enemy.gd`: `var override: Dictionary = {}`; in `_ready()`
      dopo `_cfg = get_balance("nemico_base")` (`:38`) → `_cfg.merge(override,
      true)`. Tutto ciò che enemy.gd già legge con `_cfg.get(...)` diventa
      sovrascrivibile per dato senza altre righe. `tag` finisce nel payload
      di `enemy_defeated` (US-804).
- [ ] `scripts/region_scene.gd::_crea_nemici()`: per ogni voce istanzia
      `scenes/enemy.tscn`, imposta `override` e `scale` **prima** di
      `add_child`, posiziona in cella×`TILE`, poi
      `StatsComponent.configure_from_balance(sequenza)`
      (`stats_component.gd:65`: la curva HP per Sequenza è già dati).
      Conta i vivi tramite `morto(chi)` (`enemy.gd:11`) ed emette
      `area_cleared` (contratto di US-804) alla morte dell'ultimo.
- [ ] Layout, campo `oggetti`: `[{"x", "y", "item_id", "quantita": 1}]`.
      `scripts/item_pickup.gd` (nuovo, ~15 righe): `extends
      "res://scripts/characteristic_pickup.gd"`, aggiunge `item_id` e
      `quantita`, ridefinisce `raccogli()` → `Inventory.aggiungi(item_id,
      quantita)`; stesso `setup(id, posizione)`, stessa Area2D, stesso
      `raccogli()` pubblico per i test. `region_scene::_crea_oggetti()` li
      istanzia.
- [ ] `tools/validate_data.py`: `x,y` su cella calpestabile; `sequenza`
      0..9; chiavi di `override` ⊆ chiavi di `nemico_base`;
      `override.caratteristica.pathway_id` attivo; `item_id` esistente in
      `data/items/`; `scala` in [0.5, 3].
- [ ] `mirwada.json` popolata: ≥ 6 nemici di Sequenza 9 sparsi fuori dalla
      piazza (mai a < 8 celle dallo spawn), **1 boss** di Sequenza 8 al porto
      (`danno_attacco` +50%, `raggio_aggro` 200, Caratteristica TG 8
      garantita, `scala` 1.5, `tag` `bestia`), ≥ 8 oggetti a terra (gli
      ingredienti del TG 9→7 e `moneta_comune`, vedi US-809 per le fonti).
- [ ] `scenes/main.tscn`: rimosso il nodo `Enemy` hardcoded.
- [ ] Nemici spawnati **senza player** in scena (test headless) devono
      restare inerti (`enemy.gd:56` tollera `null`): verificarlo in
      `test_layouts.gd`.
- [ ] Test `tests/test_layouts.gd` esteso: N nemici istanziati con la
      Sequenza giusta (`hp_max` dalla curva), il boss ha `scale` 1.5 e
      `_cfg.danno_attacco` sovrascritto; M pickup; `item_pickup.raccogli()`
      → `Inventory.conta` +quantita; uccidendo tutti i nemici →
      `area_cleared` emesso una volta.
- [ ] Verifica Xvfb: screenshot di Mirwada con nemici, boss e oggetti
      visibili, in `progress.txt`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-807: Le altre quattro regioni disegnate e popolate — SPEZZATA

**Nota (2026-09-09):** questa story copriva 4 regioni in un colpo solo — a
giudicare dal precedente della fase (US-805, una sola regione, già vicina
al budget di una context window per la regola 3 di `CLAUDE.md`), 4 regioni
insieme avrebbero quasi certamente sforato. Su richiesta esplicita
dell'utente, spezzata **prima di iniziare** in 4 story indipendenti, una
per regione: **US-807a** (Marche del Crepuscolo), **US-807b** (Valle
Madre), **US-807c** (Archivio Sepolto), **US-807d** (Frontiera delle
Porte, che chiude anche il Blocco B). Il testo originale (qui sotto, non
più la fonte di verità) resta come riferimento del disegno complessivo;
le 4 story seguenti lo suddividono senza perdere nessun criterio.

*Description originale:* Come giocatore, voglio che ogni regione abbia una
mappa propria, nemici della sua fascia e oggetti del suo gruppo.

*Acceptance Criteria originali (superseded dalle 4 story sotto):*

- `data/world/layouts/marche_crepuscolo.json`, `valle_madre.json`,
  `archivio_sepolto.json`, `frontiera_porte.json` disegnati a mano,
  ciascuno con **identità** coerente con `design-world.md` §2 e
  `arte/02_regioni_e_mappe.md`: Marche = brughiera e cripte (ostacoli `t`,
  zona `cripte` chiusa da muri con un varco per il gate `momento`); Valle =
  fiume e ponti di radici (`~` attraversato da `=` nella zona
  `ponti_di_radici` — il gate `primitiva` esistente resta sul varco);
  Archivio = sale e corridoi (`#` interni, `ali_interne` raggiungibile solo
  dal gate `conoscenza`); Frontiera = isole nella nebbia (`~` ovunque,
  isole `.` collegate da `=`, gate `sequenza` all'ingresso). **I gate
  esistenti non cambiano**: il layout mette il varco dove
  `regions.json.gating[].area` già lo dichiara.
- Nemici: Sequenza per regione dal `group_affinity` e dalla fascia (Marche
  9-8, Valle 9-8, Archivio 8-7, Frontiera 7-6), 6-10 per regione, **1
  boss** per regione (Sequenza -1 rispetto ai normali, `override` più duro,
  Caratteristica del gruppo garantita, `scala` 1.5), `tag` dai vocabolari.
- Oggetti a terra: 6-10 per regione + `moneta_comune` (gli ingredienti veri
  restano rimandati a US-809, come già corretto in US-806).
- Validator: tutte e 5 le regioni hanno layout; il warning di US-805
  ("zona senza layout") diventa **errore**.
- Test, verifica Xvfb, `validate_data.py` 0 come sempre.

#### US-807a: Marche del Crepuscolo — layout + popolazione (Blocco B)

**Description:** Come giocatore, voglio che le Marche del Crepuscolo
abbiano una mappa propria da brughiera e cripte, con nemici del Twilight
Giant (gruppo `eternal_darkness`) e un boss riconoscibile.

**Acceptance Criteria:**

- [ ] `data/world/layouts/marche_crepuscolo.json`: identità brughiera e
      cripte. Usa l'ostacolo `t` (oltre a `o`) per varietà visiva. Una zona
      `cripta` chiusa da muri `#` con un solo varco calpestabile allineato
      al gate esistente `{"tipo":"momento","valore":"notte_fonda","area":"cripte"}`
      (`data/world/regions.json`, non tocco il gate, solo la geometria).
      10 `location_tags` da coprire con una zona ciascuno (`altura`,
      `luogo_di_battaglia`, `tempio_abbandonato`, `rovina`,
      `luogo_in_decadenza`, `vetta`, `luogo_di_massacro`, `cripta`,
      `trono_del_gigante`, `soglia_del_crepuscolo`): con 10 zone su una
      griglia 48×36 alcune saranno rettangoli semplici senza decorazione
      elaborata (a differenza delle 5 di Mirwada), per restare dentro lo
      scope della story — l'identità brughiera/cripte si concentra su 2-3
      zone chiave (`cripta`, `trono_del_gigante`), le altre sono spazio
      aperto con l'ostacolo giusto. Spawn e passaggio verso `mirwada`
      (unico, essendo una regione a raggio, non hub) su cella calpestabile.
- [ ] Nemici: 6-10 di Sequenza 9 e 8 (mix), sparsi fuori dallo spawn (stessa
      regola di distanza minima di US-806); **1 boss** Sequenza 7,
      `override` (danno_attacco/raggio_aggro più duri, `tag: "non_morto"`
      dal vocabolario di `data/tags.json`, `caratteristica: {pathway_id:
      "twilight_giant", sequence: 7, probabilita: 1.0}`), `scala` 1.5,
      dentro la zona `cripta`.
- [ ] Oggetti: 6-10 `moneta_comune` (ingredienti veri rimandati a US-809,
      come già corretto in US-806 — l'AC originale li chiedeva ma non
      esistono ancora come item).
- [ ] `tools/validate_data.py`: nessun cambio di logica (il warning
      "regione senza layout" continua a valere per le 3 regioni ancora
      senza — diventa errore solo nell'ultima, US-807d).
- [ ] `tests/test_layouts.gd` esteso con test dedicati per
      `marche_crepuscolo` (stesso stile esplicito di quelli di `mirwada`:
      bordo solido, spawn dal layout, nemici con la Sequenza giusta, boss
      riconoscibile dalla `scala`, oggetti raccolti finiscono in Inventory,
      area_cleared alla morte dell'ultimo, nemici inerti senza player).
- [ ] Verifica Xvfb: screenshot delle Marche in `progress.txt`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Tests pass.

#### US-807b: Valle Madre — layout + popolazione (Blocco B)

**Description:** Come giocatore, voglio che la Valle Madre abbia una mappa
propria da fiume e ponti di radici, con nemici del gruppo
`goddess_of_origin` e un boss riconoscibile.

**Acceptance Criteria:**

- [ ] `data/world/layouts/valle_madre.json`: identità fiume. Un corpo
      d'acqua `~` attraversato da un ponte `=` nella zona
      `ponti_di_radici`, allineato al gate esistente
      `{"tipo":"primitiva","primitiva":"plant_growth","area":"ponti_di_radici"}`
      (non tocco il gate). 6 `location_tags` da coprire (`bosco_antico`,
      `radura_lunare`, `grotta_di_marea`, `sorgente`, `altare_di_radici`,
      `radice_del_mondo`) — con solo 6 zone (contro le 10 di Marche) c'è
      margine per curare meglio 2-3 aree chiave (`sorgente`,
      `radice_del_mondo`). Spawn e passaggio verso `mirwada` su cella
      calpestabile.
- [ ] Nemici: 6-10 di Sequenza 9 e 8; **1 boss** Sequenza 7, `override`
      (`tag: "bestia"`, `caratteristica: {pathway_id: "mother", sequence:
      7, probabilita: 1.0}`), `scala` 1.5, dentro una zona d'acqua/natura.
- [ ] Oggetti: 6-10 `moneta_comune` (stessa nota di US-807a su US-809).
- [ ] `tests/test_layouts.gd` esteso con test dedicati per `valle_madre`
      (stesso stile di US-807a).
- [ ] Verifica Xvfb: screenshot della Valle in `progress.txt`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Tests pass.

#### US-807c: Archivio Sepolto — layout + popolazione (Blocco B)

**Description:** Come giocatore, voglio che l'Archivio Sepolto abbia una
mappa propria da sale e corridoi, con nemici del gruppo
`demon_of_knowledge` e un boss riconoscibile.

**Acceptance Criteria:**

- [ ] `data/world/layouts/archivio_sepolto.json`: identità sale e corridoi
      interni (molti muri `#` a formare stanze, non una brughiera aperta).
      Una zona `ali_interne` raggiungibile da un solo varco allineato al
      gate esistente `{"tipo":"conoscenza","valore":"testi_ordine_minore",
      "area":"ali_interne"}` (non tocco il gate). 6 `location_tags`
      (`biblioteca`, `officina`, `torre_di_osservazione`, `sala_dei_sigilli`,
      `studio`, `biblioteca_di_tutto`). Spawn e passaggio verso `mirwada`
      su cella calpestabile.
- [ ] Nemici: 6-10 di Sequenza 8 e 7; **1 boss** Sequenza 6, `override`
      (`tag: "spirito"`, `caratteristica: {pathway_id: "hermit", sequence:
      6, probabilita: 1.0}`), `scala` 1.5, dentro `ali_interne` o
      `sala_dei_sigilli`.
- [ ] Oggetti: 6-10 `moneta_comune` (stessa nota di US-807a su US-809).
- [ ] `tests/test_layouts.gd` esteso con test dedicati per
      `archivio_sepolto` (stesso stile di US-807a).
- [ ] Verifica Xvfb: screenshot dell'Archivio in `progress.txt`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Tests pass.

#### US-807d: Frontiera delle Porte — layout + popolazione + chiusura Blocco B

**Description:** Come giocatore, voglio che la Frontiera delle Porte abbia
una mappa propria da isole nella nebbia, con nemici del gruppo
`lord_of_mysteries` e un boss riconoscibile; con questa regione tutte e 5
hanno un layout, quindi il validator chiude il cerchio.

**Acceptance Criteria:**

- [ ] `data/world/layouts/frontiera_porte.json`: identità isole nella
      nebbia. `~` predominante, isole `.` collegate da sentieri `=`. Un
      varco all'ingresso allineato al gate esistente
      `{"tipo":"sequenza","valore":4,"area":"ingresso"}` (non tocco il
      gate — resta il tetto di Sequenza 4 già nei dati). 6 `location_tags`
      (`teatro`, `crocevia`, `soglia`, `nebbia_grigia`, `palco`,
      `porta_senza_stanza`). Spawn e passaggio verso `mirwada` su cella
      calpestabile (su un'isola, non in acqua).
- [ ] Nemici: 6-10 di Sequenza 7 e 6; **1 boss** Sequenza 5, `override`
      (`tag: "ombra"`, `caratteristica: {pathway_id: "door", sequence: 5,
      probabilita: 1.0}`), `scala` 1.5, su un'isola isolata.
- [ ] Oggetti: 6-10 `moneta_comune` (stessa nota di US-807a su US-809).
- [ ] `tools/validate_data.py`: con questa la 5ª e ultima regione ha un
      layout — il check "regione senza layout" (oggi `warn()`) non troverà
      più nessuna regione a cui applicarsi, ma converto comunque
      esplicitamente la logica a `err()` per il caso, cosi' se in futuro
      un layout viene rimosso per errore il validator lo blocca invece di
      limitarsi ad avvisare.
- [ ] `tests/test_layouts.gd` esteso con test dedicati per
      `frontiera_porte` (stesso stile di US-807a) + un test di chiusura
      "tutte e 5 le regioni hanno un layout" (`GameData.get_layout(id)`
      non vuoto per ogni id di `get_regions()`).
- [ ] Verifica Xvfb: screenshot della Frontiera in `progress.txt`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Tests pass.

### Blocco C — Economia degli ingredienti

#### US-808: I 299 ingredienti delle formule diventano oggetti (generatore + i18n)

**Description:** Come giocatore, voglio che ogni ingrediente citato da una
formula esista come oggetto con un nome, così posso possederlo, vederlo
nell'inventario e usarlo.

**Acceptance Criteria:**

- [ ] `tools/generate_formula_ingredients.py` (nuovo, **idempotente** come
      `generate_pathways.py`): legge `data/potions/formulas.json`
      (`formulas[*].ingredients`), e per ogni id non ancora presente in
      `data/items/ingredienti.json` crea `{id, categoria: "ingrediente",
      name_i18n: "item.<id>", descrizione_i18n: "item.<id>.desc", tag: [...],
      impilabile: true, valore: f(sequenza minima che lo usa)}`. Le voci
      scritte a mano (le 8 esistenti e future) si **preservano** (merge per
      id). `valore`: tabella nel tool 9→3, 8→5, 7→8, 6→12, 5→18, 4→27,
      3→40, 2→60, 1→90, 0→120 (in `_comment` del file generato).
- [ ] `tag`: solo voci di `data/tags.json` (chiuso, 82). Il tool ha una
      tabella **chiusa** parola→tag (es. `sangue`→`vita`, `ferro`/`acciaio`
      →`forza`, `radice`/`erba`→`crescita`, `specchio`/`nebbia`→`inganno`,
      `osso`/`cadavere`→`morte`, `luna`→`luna`, ...; le parole senza
      corrispondenza non aggiungono tag). Ogni item ha almeno `pozione`.
      Un tag non in `tags.json` fa fallire il tool, non il validator dopo.
- [ ] i18n: nome IT dall'id (`ferro_temperato` → "Ferro temperato";
      `acqua_di_un_pozzo_che_non_trovi_piu` → "Acqua di un pozzo che non
      trovi più": tabella di accenti nel tool); nome EN da un dizionario
      parola-per-parola nel tool (~200 voci: ferro→iron, sangue→blood,
      radice→root, temperato→tempered, ...) con ordine invertito
      aggettivo/nome dove serve, e stub `TODO` **solo** per le parole
      ignote (elencate a fine run). Descrizione: una riga generica per
      categoria ("Ingrediente alchemico. Compare nella formula di Sequenza
      N di <Pathway>"). Poi `tools/generate_i18n_stubs.py` per allineare i
      cataloghi. R-12 del validator verde.
- [ ] Validator: **ogni** ingrediente di ogni formula dei 10 Pathway attivi
      è un item di categoria `ingrediente` (errore se manca). Le formule
      dei Pathway differiti sono escluse.
- [ ] `README.md` § Setup: il nuovo comando.
- [ ] Test: `tests/test_data_loading.gd` (o simile esistente) —
      `GameData.get_item("ferro_temperato")` non è vuoto; conteggio
      `items_per_categoria("ingrediente")` ≥ 299 + 8.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-809: Fonti nel mondo — drop per regione, listini, raccolta a terra — SPEZZATA

**Nota (2026-09-09):** come US-807, questa story copriva 3 meccaniche
abbastanza indipendenti (drop dei nemici, listini, raccolta a terra +
chiusura del validator) lungo ~12 file. Su richiesta esplicita
dell'utente, spezzata **prima di iniziare** in **US-809a** (drop dei
nemici), **US-809b** (listini dei venditori), **US-809c** (raccolta a
terra + il blocco validator "fonti", che ha senso solo a tutte e 3 le
meccaniche esistenti). Il testo originale sotto resta come riferimento
del disegno complessivo, non più la fonte di verità.

*Description originale:* Come giocatore, voglio poter ottenere ogni
ingrediente di cui ho bisogno giocando: uccidendo nemici della regione
giusta, comprando da un venditore, o raccogliendolo a terra.

*Acceptance Criteria originali (superseded dalle 3 story sotto):*

- **Drop dei nemici** (dati): nel layout, `drop: {"9": [ids], "8":
  [ids], ...}` = ingredienti delle formule dei Pathway del
  `group_affinity` della regione, per Sequenza; per l'hub `mirwada` tutti
  i Pathway ma solo Sequenze 9-8. Il tool di US-808 guadagna un'opzione
  `--drops` che scrive queste tabelle nei layout. `region_scene::
  _crea_nemici` mette nell'`override` di ogni nemico `oggetti_a_morte =
  drop[str(sequenza)]`: nessuna tabella nel codice.
- `scripts/enemy.gd::_lascia_oggetto()` accanto a `_lascia_caratteristica`:
  con probabilità `_cfg.drop_probabilita` (nuovo campo in
  `balance.json.nemico_base`) lascia a terra un item a caso da
  `_cfg.oggetti_a_morte`. Il boss ha `drop_probabilita: 1.0`.
- **Listini** (dati, `roster.json` `vendor.listino`): Sidon = ingredienti
  Seq 9-8 di tutti i Pathway attivi; Vesna = tag `guarigione`/`crescita`;
  Bruno = Seq 9-7 del gruppo `eternal_darkness`. Generati dal tool
  (`--listini`); le voci esistenti restano.
- **Raccolta a terra** (dati, a mano nei layout): in `mirwada.json` gli
  ingredienti del Twilight Giant Seq 9→7 + `moneta_comune`; nelle altre
  regioni gli ingredienti del gruppo.
- Validator, blocco "fonti": per ogni ingrediente di una formula attiva,
  ≥1 fonte fra drop/listino/oggetti. Errore altrimenti.
- Test `tests/test_enemy_drop.gd` come sopra. `validate_data.py` 0.

#### US-809a: Drop dei nemici (Blocco C)

**Description:** Come giocatore, voglio che uccidere un nemico possa
lasciare a terra un ingrediente della sua regione, così posso raccogliere
materiali giocando invece di dover solo comprare o cercare a terra.

**Acceptance Criteria:**

- [ ] `data/balance.json.nemico_base`: nuovo campo `drop_probabilita`
      (proposta 0.6, `_comment` esplicito che ne spiega l'uso e come un
      boss lo sovrascrive per-istanza via `override`).
- [ ] `scripts/enemy.gd::_lascia_oggetto()` accanto a `_lascia_caratteristica`
      (`:278`, stesso pattern: legge `_cfg`, tira un `randf()`, instanzia
      un pickup, lo aggiunge al genitore): con probabilità
      `_cfg.drop_probabilita` lascia a terra **un** item scelto a caso da
      `_cfg.oggetti_a_morte` (array di id) come `item_pickup.gd` (US-806).
      Chiamata da `_su_morte()` accanto a `_lascia_caratteristica()`. Se
      `oggetti_a_morte` è vuoto o assente, no-op (nessuna regressione sul
      nemico da banco di prova, che oggi non ha questo campo).
- [ ] `scripts/region_scene.gd::_crea_nemici()` (`:250`): legge
      `layout.drop` (dict `{"<sequenza>": [ids]}`) una volta; per ogni
      nemico, se `drop` ha una voce per la sua `sequenza`, la inietta come
      `oggetti_a_morte` nell'`override` (su una **copia** — `.duplicate(true)`
      — per non mutare il dict condiviso del layout, stessa disciplina
      della correzione fatta in US-806 per `_cfg`). Nessuna tabella nel
      codice: l'unica fonte è `layout.drop`.
- [ ] `tools/generate_formula_ingredients.py`: nuova opzione `--drops`
      (idempotente, non tocca `nemici`/`oggetti` degli stessi layout):
      per le 4 regioni con `group_affinity` reale, scrive `drop` con una
      chiave per ogni Sequenza 0-9 che ha almeno una formula fra i
      Pathway attivi di quel gruppo, valore = lista degli ingredienti di
      quelle formule; per `mirwada` (`group_affinity: "neutra"`), `drop`
      con solo le chiavi `"9"`/`"8"`, ingredienti di **tutti** i 10
      Pathway attivi a quelle Sequenze.
- [ ] I boss dei 5 layout guadagnano `"drop_probabilita": 1.0` nel loro
      `override` (una riga a mano per file, i boss esistono già da
      US-806/US-807a..d).
- [ ] Test `tests/test_enemy_drop.gd` (nuovo): un nemico con
      `override.oggetti_a_morte` non vuoto e `drop_probabilita: 1.0` →
      alla morte c'è un `item_pickup` figlio della regione con uno degli
      id dichiarati; con `drop_probabilita: 0.0` → nessun pickup nuovo.
- [ ] Verifica Xvfb: uno screenshot che mostra un drop raccolto dopo aver
      ucciso un nemico, in `progress.txt`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Tests pass.

#### US-809b: Listini dei venditori (Blocco C)

**Description:** Come giocatore, voglio poter comprare gli ingredienti
che mi servono da un venditore invece di dover sempre ucciderli o
cercarli a terra.

**Acceptance Criteria:**

- [ ] `tools/generate_formula_ingredients.py`: nuova opzione `--listini`
      (idempotente: solo append, mai rimuove/duplica un id già presente)
      che estende `vendor.listino` in `data/npc/roster.json` per i 3 NPC
      che hanno già un `vendor` reale (`npc_sidon`, `npc_vesna`,
      `npc_bruno`, verificati esistenti): Sidon = ingredienti di Sequenza
      9-8 di tutti i 10 Pathway attivi; Vesna = ingredienti con tag
      `guarigione` o `crescita` (dal `tag` generato in US-808); Bruno =
      ingredienti di Sequenza 9-7 del gruppo `eternal_darkness`. Le 8
      voci scritte a mano già presenti (`erba_lunare` ecc.) restano.
- [ ] Verifica: nessuna regressione sui test/dialoghi che leggono
      `roster.json` (`tests/test_dialoghi_roster.gd` e simili).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Tests pass.

#### US-809c: Raccolta a terra + chiusura (fonti nel mondo)

**Description:** Come giocatore, voglio trovare ingredienti veri a terra
nelle regioni (non solo monete), e sapere che ogni ingrediente di cui ho
bisogno è ottenibile in almeno un modo.

**Acceptance Criteria:**

- [ ] I 5 layout (`data/world/layouts/*.json`): il campo `oggetti`
      sostituisce (in tutto o in parte) le voci `moneta_comune` di
      US-806/US-807a..d con ingredienti veri. `mirwada.json`: gli
      ingredienti del Twilight Giant Sequenza 9→7 (9 id, così il primo
      ciclo di coltivazione si chiude senza dover passare da un negozio)
      + `moneta_comune` residua. Le altre 4 regioni: ingredienti del
      Pathway già scelto in US-807a..d per quella regione (coerenza col
      boss/Caratteristica già assegnati).
- [ ] `tools/validate_data.py`: nuovo blocco "fonti" — per ogni
      ingrediente di ogni formula dei 10 Pathway attivi, verifica che
      esista **almeno una fonte** fra: un layout con l'id in `drop`
      (qualunque Sequenza, US-809a), un venditore con l'id nel `listino`
      (US-809b), un layout con l'id in `oggetti` (questa story). Errore
      con l'elenco degli id senza nessuna fonte, altrimenti.
- [ ] Verifica Xvfb: screenshot di un ingrediente vero raccolto a terra
      (non più una moneta), in `progress.txt`.
- [ ] `python tools/validate_data.py` esce 0 (il blocco "fonti" non trova
      mancanti: la copertura del drop di US-809a su tutte le Sequenze di
      ogni gruppo dovrebbe già coprire i 299 ingredienti da sola). Nessuna
      regressione. Tests pass.

### Blocco D — Pagine del libro

#### US-810: Sezione Avanzamento nel diagramma (Prepara / Bevi)

**Description:** Come giocatore, voglio vedere nel libro cosa mi manca per
la pozione della mia Sequenza, prepararla e berla — con la penalità
scritta se la forzo.

**Acceptance Criteria:**

- [ ] `scripts/pages/page_diagramma_pathway.gd`: `_sezione_avanzamento()`
      sotto la fusione, **stesso stile** di `_sezione_fusione` (`:102-150`).
      Legge `Progression.sequence_data().potion` (già usato a `:79`):
      `formula_id`, `characteristic_sequence`, `ingredients`. Righe:
      Caratteristica richiesta (`GameData.characteristic_for(pw, seq)`,
      `:675`, + `CharacteristicStore.possiede`), ogni ingrediente con
      "nome ×posseduti/1" (`Inventory.conta`), recitazione
      (`Acting.acting_progress()` in %).
- [ ] Bottone **Prepara**: attivo se la Caratteristica è posseduta e gli
      ingredienti posseduti ≥ `soglia_parziale` della formula; se < 3,
      etichetta "Prepara (parziale: <penalita_parziale letta dai dati>)".
      Chiama `PotionSystem.concoct(formula_id, char_id, ingredienti_posseduti)`
      (`:22`) e poi `Inventory.rimuovi` di ognuno usato. Esito mostrato
      nella sezione (successo / motivo del rifiuto, dal `Dictionary` di
      ritorno, via chiavi i18n).
- [ ] Bottone **Bevi**: visibile se `PotionSystem.pozione_pronta()` non è
      vuoto; etichetta "Bevi" se `avanzamento_disponibile()` (`:66`),
      altrimenti "Bevi (forzato: +N follia)" con N = `sequence_data.
      madness_on_force × Foundation.moltiplicatore_follia` (stesso calcolo
      di `bevi`, `:113-114`) se `avanzamento_forzabile()` (`:74`), altrimenti
      disabilitato con il motivo. Chiama `bevi(forza)` (`:97`). La pagina si
      ridisegna su `Progression.sequence_changed`.
- [ ] Chiavi UI nuove in `assets/i18n/strings.csv` (`LIBRO_AVANZAMENTO_*`),
      IT/EN. Nessun nome di Pathway/ingrediente nel codice.
- [ ] Metodi pubblici per i test, come `fondi()`: `prepara_pozione()`,
      `bevi_pozione(forza)`. Controllare prima `tests/test_page_diagramma*.gd`:
      se contano i figli della pagina, aggiornare il conteggio con la
      motivazione.
- [ ] Test `tests/test_page_avanzamento.gd`: inventario coi 3 ingredienti +
      Caratteristica → Prepara → `pozione_pronta()` non vuoto, ingredienti
      scalati → Bevi (recitazione al 100% simulata via `EventTracker`) →
      `Progression.sequence() == 8`; con 2 ingredienti → pozione parziale e
      follia extra al bere; senza Caratteristica → Prepara disabilitato.
- [ ] Verifica Xvfb: screenshot della sezione prima e dopo Prepara, in
      `progress.txt`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-811: Negozio (compra / vendi) nella pagina dialogo

**Description:** Come giocatore, voglio comprare ingredienti da un
venditore e vendergli quello che non mi serve, dentro il dialogo.

**Acceptance Criteria:**

- [ ] `scripts/pages/page_dialogo.gd`: in `_ready()` si connette anche a
      `DialogueEngine.apri_vendita(npc_id)` (`dialogue_engine.gd:20`) e a
      `QuestSystem.apri_vendita` (stesso nome, verificare la firma).
      `aggiorna()` guadagna la modalità **negozio**: intestazione col nome
      del venditore, riga "Monete: N" (`Inventory.ricchezza()`, `:182`);
      sezione *Compra*: per ogni `item_id` di `get_npc(npc_id).vendor.listino`
      riga `nome` + `valore` (da `GameData.get_item`, `:528`) + bottone
      attivo se `Inventory.conta(valuta) >= valore` → `Inventory.rimuovi(
      valuta, valore)` + `Inventory.aggiungi(item_id, 1)` + ridisegno;
      sezione *Vendi*: per ogni voce di `Inventory.tutto()` (`:166`) di
      categoria ≠ `valuta`, riga `nome ×conta` + bottone "Vendi (valore/2,
      arrotondato per difetto, minimo 1)" → `rimuovi(item_id, 1)` +
      `aggiungi(valuta, prezzo)`; bottone *Chiudi* → torna al dialogo
      (`DialogueEngine` in corso) o chiude la pagina.
- [ ] `valuta` = `GameData.items_per_categoria("valuta")[0].id` (`:536`):
      **nessun id nel codice**. Se la lista è vuota, la sezione mostra un
      avviso i18n e nessun bottone.
- [ ] Chiavi UI nuove in `strings.csv` (`LIBRO_NEGOZIO_*`), IT/EN.
- [ ] Metodi pubblici per i test: `compra(item_id)`, `vendi(item_id)`,
      `in_negozio() -> bool`.
- [ ] Test `tests/test_page_negozio.gd`: `apri_vendita("npc_sidon")` →
      `in_negozio()`; con 10 monete comprare un item da 3 → conta +1,
      monete 7; comprare senza monete → rifiuto, niente cambia; vendere →
      conta -1, monete +valore/2; Chiudi → `in_negozio() == false`.
      Le esistenti `test_page_dialogo*.gd` non cambiano.
- [ ] Verifica Xvfb: screenshot del negozio di Sidon, in `progress.txt`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco E — Grafica provvisoria che rispetta `arte/`

#### US-812: `generate_sprites.py` — personaggio, nemico, pet (19 fogli)

**Description:** Come giocatore, voglio vedere un personaggio, un nemico e
un pet leggibili invece di ellissi numerate — finché non arriva l'arte
vera.

**Acceptance Criteria:**

- [ ] `tools/generate_sprites.py` (nuovo, Pillow, **deterministico**: seed
      fisso): pixel art procedurale 32×32 a **strati** (ombra, gambe, corpo,
      braccia, testa, copricapo, arma/accento), outline 1 px inchiostro
      (`arte/03` chiede 2 px: a 32 px è troppo, motivazione in `_comment`
      del tool e in `arte/03`), palette inchiostro + primario + accento da
      `arte/04_combattimento_vfx.md`; direzione destra = specchio della
      sinistra (decisione "4 direzioni" di `CLAUDE.md`).
- [ ] Produce gli **stessi 19 fogli** con la **stessa geometria** letta da
      `data/animations.json` (colonne = frame, righe = direzioni, 32 px):
      `animation_machine.gd:60-98` e `tests/test_animation_machine.gd` non
      cambiano.
- [ ] **Personaggio** (brief `arte/01` §6.3): operaio anni '20, berretto
      piatto, cappotto blu ardesia rattoppato, sciarpa accento caldo.
      `idle` respiro; `walk` 6 passi; `dash` inclinato + scia;
      `attack_light`/`attack_heavy` con lama (anticipo arretrato, attivo
      esteso, recupero); `parry` guardia alta con accento acceso sui frame
      della finestra perfetta; `hurt` flash; `death` caduta; `cast` mani
      alzate con bagliore sull'ultimo frame; `meditate` seduto.
      Palette **fissa**: sono i VFX a dire il Pathway, non il cappotto.
- [ ] **Nemico base**: cultista incappucciato grigio cenere, accento verde
      malato; `anticipo` = braccia alzate + accento che si accende dal
      primo frame (è il tell, FR-8 di fase 1); `stagger`, `death`.
- [ ] **Pet**: piccolo segugio, stesse categorie di animazione che
      `animations.json` gli assegna.
- [ ] `tools/generate_placeholders.py`: **non cambia cartella** (il runtime
      legge `assets/placeholder/`, `animation_machine.gd:79`): importa il
      corpo del frame da `generate_sprites.py` e ci disegna sopra gli
      overlay diagnostici di sempre (bordi colorati per fase, cifra del
      frame). Un run di `generate_sprites.py` = arte pulita; un run di
      `generate_placeholders.py` = arte + diagnostica. Stessi file, stessa
      iterazione su `animations.json` (`:121-137`).
- [ ] `.import` sono gitignorati (`.gitignore:3`): i PNG si sovrascrivono
      in place; `godot --headless --import` prima della suite.
- [ ] `README.md` § Setup: i due comandi e cosa produce ciascuno.
      `arte/03_sprite_e_animazioni.md`: nota "generatore procedurale
      provvisorio" con cosa rispetta e cosa no.
- [ ] Test: `tests/test_animation_machine.gd` verde senza modifiche;
      `tests/test_sprites_generati.gd`: ogni PNG esiste, ha la dimensione
      attesa da `animations.json`, il frame `anticipo` del nemico differisce
      dal frame `idle` (il tell è visibile), il frame di destra è lo
      specchio di quello di sinistra.
- [ ] Verifica Xvfb **obbligatoria**: screenshot di idle/walk/attack/parry
      del personaggio e anticipo/attacco del nemico, in `progress.txt`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-813: Sprite di NPC, oggetti, passaggi, gate + tileset per palette

**Description:** Come giocatore, voglio riconoscere a colpo d'occhio NPC
(col nome), oggetti a terra, passaggi e barriere, e vedere ogni regione
col suo colore.

**Acceptance Criteria:**

- [ ] `generate_sprites.py` produce anche: `npc_popolano.png` (6 varianti
      su 6 righe: abiti diversi, palette neutra; la riga la sceglie il dato
      `aspetto.variante` nel roster, default 0, documentato in
      `data/schema/npc.schema.json` — 19 voci del roster aggiornate a mano
      con una variante sensata); `oggetti.png` (una icona per categoria di
      `item_categories.json`, ordine = quello del vocabolario, scritto nel
      suo `_comment`; per `ingrediente` 3 varianti scelte dal tag dominante:
      erba/minerale/fiala); `passaggio.png` (arco/cartello); `gate.png`
      (barriera).
- [ ] **Un solo `tileset.png` a righe**: colonne = gli 8 tipi di tile della
      legenda di US-805 (pavimento, muro, ostacolo, acqua, pavimento
      variante, sentiero, ostacolo 2, decoro), righe = palette: riga 0
      `neutra`, poi le chiavi di `vfx.json.pathway_palette_visiva`
      **nel loro ordine** (dato, non nome). Texture a rumore deterministico,
      edge-tileable, palette inchiostro + primario + accento.
- [ ] `tools/build_tileset.gd`: loop su righe e colonne; colonne solide
      `[1, 2, 3, 6]` (muro, ostacolo, acqua, ostacolo 2); un solo
      `tileset.tres` rigenerato e committato.
- [ ] `scripts/region_scene.gd`: riga del tileset = 0 se `palette_visiva ==
      "neutra"`, altrimenti `1 + indice` in `vfx.json` (letto da
      `GameData`); i caratteri della legenda mappano ora sulle 8 colonne
      (US-805 usava muro/pavimento). NPC = `Sprite2D` da `npc_popolano.png`
      (riga da `aspetto.variante`) + `Label` col nome (`tr_data`) sopra la
      testa; passaggi e gate con il loro sprite; `item_pickup` con l'icona
      della categoria (e della variante per gli ingredienti).
- [ ] Nessun nome di regione/NPC/palette nel codice: solo indici e dati.
- [ ] `arte/02_regioni_e_mappe.md`: nota sulle 8 tile e sulla riga per
      palette.
- [ ] Test: `tests/test_layouts.gd` esteso — la cella `~` usa la colonna 3,
      la regione con palette non neutra usa la riga giusta; un NPC ha un
      `Sprite2D` e una `Label` col testo di `tr_data`.
- [ ] Verifica Xvfb: uno screenshot per regione con NPC e oggetti, in
      `progress.txt`.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco F — Verifica giocata + chiusura

#### US-814: La slice giocata end-to-end + documentazione + chiusura

**Description:** Come team, vogliamo la prova che la slice si gioca dal
primo all'ultimo passo, e la documentazione allineata.

**Acceptance Criteria:**

- [ ] `tests/manual/qa_vslice.gd` (script `SceneTree`, lanciato con
      `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s
      res://tests/manual/qa_vslice.gd`, **non** parte della suite headless):
      avvia `main.tscn` → libro sullo scaffale → crea "Tester" con un
      Pathway scelto da `pathway_ids()` (non hardcoded) → chiude il libro →
      cammina fino a un oggetto (`Input.action_press` sui `move_*`) →
      `Inventory.conta` +1 → preme `abilita_1` → `ability_executed` → va dal
      boss, lo uccide con `attacco` → `enemy_defeated` con payload, un
      pickup a terra → parla con Sidon (`interagisci`), sceglie la riga
      che apre la vendita, compra → conta e monete cambiano → apre il
      diagramma, Prepara, Bevi (recitazione simulata al 100% via
      `EventTracker`) → `Progression.sequence() == 8` → passaggio a una
      regione → layout diverso caricato. Ogni passo con `assert` e uno
      screenshot in `/tmp/qa_vslice/NN_<passo>.png`. Esce 0/1.
- [ ] Criterio di uscita (come i checkpoint delle fasi 2/5/5b/7):
      `tests/test_slice_fase_8.gd` fa grep di `scripts/` per gli id di
      `pathway_ids()`, degli NPC, delle regioni, delle formule e degli
      ingredienti del TG 9 → **0** occorrenze (esclusi commenti di test
      già ammessi dai checkpoint precedenti).
- [ ] `tools/validate_data.py`: blocco "chiusura fase 8" (5 layout
      presenti, ≥1 boss per regione, ogni ingrediente attivo ha una fonte,
      i 19 + 4 fogli sprite esistono con la dimensione attesa).
- [ ] Documentazione: `progress.txt` (blocco fase 8 con verdetto e le 12
      verifiche a schermo), `CLAUDE.md` (§ Fasi: "Fase 8 — Vertical slice:
      CHIUSA", comandi nuovi, sezione "Come si gioca" con lo schema
      comandi), `README.md` (paragrafo Fase 8 + comandi), `roadmap.md`
      (Fase 8 chiusa, Fase 9 opzionale), `arte/README.md` (stato:
      provvisoria generata).
- [ ] Schema comandi (anche nella pagina `colophon` del libro, chiave
      i18n): WASD/frecce movimento; attacco/schivata/parata come da
      `project.godot`; 1-4 abilità; Tab/I libro; F/Invio interagisci;
      Q/E volta pagina.
- [ ] Screenshot finali inviati all'utente in chat (`SendUserFile`).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

---

## 4. Functional Requirements

- **FR-1:** Nessuna primitiva nuova, nessun evento tracciato nuovo, nessun
  tag nuovo. I 28/12/82 restano invariati. Verificato story per story: i
  payload di US-804 usano solo i filtri già dichiarati in
  `tracked_events.json`; i tag degli ingredienti (US-808) solo `tags.json`.
- **FR-2:** Nessun nome di Pathway, NPC, regione, oggetto, formula o
  palette nel codice: solo id letti dai dati e chiavi i18n. Grep → 0
  (US-814).
- **FR-3:** Save `schema_version` 22 **invariato**. Layout, drop, listini,
  sprite non sono stato.
- **FR-4:** Ogni commit lascia il gioco **giocabile** da Play: il nodo
  `Enemy` hardcoded sparisce solo quando i layout lo sostituiscono
  (US-806); le 4 regioni senza layout restano com'erano fino a US-807; i
  tile nuovi arrivano con la grafica (US-813) ma la fisica è giusta da
  US-805.
- **FR-5:** Il layout è la **sola** fonte di nemici/oggetti/zone/passaggi
  di una regione; `region_scene.gd` non contiene coordinate.
- **FR-6:** Un boss è dati (`sequenza`, `override`, `scala`); il codice non
  ha nessun ramo per "boss".
- **FR-7:** Un'abilità si lancia **solo** via `AbilityEngine.execute`; il
  player non aggiunge controlli di possesso/costo/cooldown/condizioni
  (li fa `execute`).
- **FR-8:** Proiettili e archi colpiscono con la **stessa chiamata**
  dell'hitbox (`Hurtbox.subisci(danno, stagger, da, {tag_danno})`); un
  bersaglio è colpito una volta per arco; pierce dai dati.
- **FR-9:** I payload di `enemy_defeated` sono espliciti (`false`
  incluso), così i filtri booleani dell'EventTracker funzionano senza
  cambiare `_corrisponde`.
- **FR-10:** Ogni ingrediente di una formula di un Pathway **attivo** è un
  item **e** ha ≥1 fonte (drop/listino/terra). Errore del validator
  altrimenti.
- **FR-11:** Prezzi: compra a `valore`, vendi a `valore/2` (minimo 1);
  valuta = primo item di categoria `valuta` nei dati.
- **FR-12:** Pozione parziale: `soglia_parziale` e `penalita_parziale`
  della formula si applicano come già fa `PotionSystem`; la UI li mostra,
  non li reinterpreta.
- **FR-13:** La grafica generata rispetta la geometria dei fogli di
  `animations.json` e i vincoli di `CLAUDE.md` (32×32, 4 direzioni, destra
  = specchio). Un run del generatore è deterministico (stesso PNG, byte per
  byte).
- **FR-14:** Legenda dei layout chiusa (8 caratteri); il validator la fa
  rispettare; ogni zona di gate ha un solo varco.
- **FR-15:** Respawn a ogni ingresso in regione (scelta dichiarata); nessuna
  persistenza di nemici/oggetti nel save.

---

## 5. Non-Goals (Out of Scope)

- **Alleati/pet in scena** durante il combattimento
  (`damage_absorbed_for_ally` resta senza emettitore; i Pathway differiti
  lo usano, il vocabolario non cambia).
- **`time_in_state`** oltre `notte`; **`structure_destroyed`** (nessuna
  struttura fisica nel mondo in questa fase); **siti rituali fisici** per
  `RitualSystem.imposta_luogo` (le Sequenze ≤ 4 con rituale: dopo il primo
  playtest).
- **Persistenza** di oggetti raccolti / nemici uccisi tra un ingresso e
  l'altro; **spawner a tempo** (`WorldState.spawn_rate_corrente` resta il
  gancio che è).
- **VFX delle primitive** (restano i punti tinti di `vfx.json`), **audio**
  (spec in `data/audio.json`, nessun file), **ritratti**.
- **Arte definitiva**: i PNG generati sono un segnaposto leggibile, non
  l'arte del gioco (`arte/` resta il brief per chi disegna).
- **Bilanciamento**: i numeri (drop 0.6, prezzi, HP del boss, 6-10 nemici)
  sono plausibili e si tarano giocando, non in questa fase.
- **Base building / forgia / pet nella slice guidata**: raggiungibili (le
  pagine esistono), non pre-sbloccati né coperti da `qa_vslice.gd`.
- **Fase 9** (Pathway Non-Standard, Boon).

---

## 6. Design Considerations

- **Legenda dei layout** (US-805): 8 caratteri, tutti a un tasto. Un
  layout si legge a colpo d'occhio in un editor con font monospazio; la
  regola "bordo tutto `#`" evita di uscire dalla mappa; `~` è solido
  perché non c'è nuoto e un "quasi ostacolo" confonde.
- **Identità delle regioni** (US-807) da `design-world.md` §2 e
  `arte/02`: la mappa è la prima cosa che dice "dove sono", prima della
  palette.
- **Hotbar** (US-802): 4 slot bastano (2 abilità a Sequenza 9, ≤ 4 fino
  alla 7); oltre, la pagina diagramma resta il riferimento. Testo, non
  icone: nessuna icona di abilità esiste e disegnarne 208 non è di questa
  fase.
- **Boss leggibile** (US-806): `scala` 1.5 + posizione (porto, cripta,
  sala, isola) + `raggio_aggro` alto = si vede da lontano e viene incontro.
- **Avanzamento nel diagramma** (US-810): sta dove sta la fusione, perché
  è la stessa domanda ("come salgo"). Il forzato mostra il numero di
  follia prima del click: nessuna sorpresa.
- **Negozio nel dialogo** (US-811): nessuna pagina nuova nel vocabolario
  `page_types.json`; il negozio è uno stato del dialogo, si esce e si
  rientra parlando.
- **Sprite a strati** (US-812): le regole di `arte/03` (silhouette,
  outline, accento sul tell) si applicano anche a un generatore; il
  personaggio non cambia colore col Pathway (`arte/01` §6.3).
- **Tileset a righe** (US-813): una palette per regione con **una** riga
  ciascuna; aggiungere una regione = aggiungere una riga generata, zero
  codice.

---

## 7. Technical Considerations

**Cose che si riusano (verificate su `d7d450e`):**

| Cosa | Dove |
|---|---|
| Apertura libro / scaffale / creazione | `book.gd:67` `apri`, `page_menu_principale.gd`, `page_creazione_personaggio.gd:92-99` |
| Segnale di partita avviata | `game_state.gd:15` `partita_iniziata(nome)` |
| Lancio abilità + possedute + cooldown | `ability_engine.gd:110` `execute`, `:378` `owned_abilities`, `:276` `cooldown_left`, `:14` `ability_executed` |
| Cambio Sequenza | `progression.gd:19` `sequence_changed(nuova, vecchia)` |
| Danno alle hurtbox | `hitbox.gd:61` → `hurtbox.gd:45` `subisci(danno, stagger, da, extra)` |
| Cinematica proiettile/arco | `projectile.gd:20` `setup`, `:50` `registra_colpo`; `melee_arc.gd:23` `setup`, `:48` `dentro_arco` |
| Pickup a terra | `characteristic_pickup.gd` (`setup(id, pos)`, `raccogli()`) |
| Stat per Sequenza | `stats_component.gd:65` `configure_from_balance(seq)` |
| Config del nemico | `enemy.gd:38` `_cfg = get_balance("nemico_base")`, `:11` `morto(chi)`, `:188` `enemy_defeated`, `:214` `_lascia_caratteristica` |
| Filtri degli eventi | `event_tracker.gd::_corrisponde` (`_max`/`_min`/bool) |
| Caratteristica per (pathway, seq) | `game_data.gd:675` `characteristic_for` |
| Loader di una directory di dati | `game_data.gd:768` `_load_quests` |
| Item / categorie / NPC / regioni / palette | `game_data.gd:528` `get_item`, `:536` `items_per_categoria`, `:616` `get_npc`, `:598` `get_regions`, `:585` `get_vfx_palette`, `:685` `pathway_ids` |
| Cambio regione a runtime | `region_scene.gd:287` `viaggia_a`, `:301` `_viaggia_verso` |
| Sezione con bottoni nel diagramma | `page_diagramma_pathway.gd:102` `_sezione_fusione` |
| Concoction / bere | `potion_system.gd:22` `concoct`, `:60` `pozione_pronta`, `:66` `avanzamento_disponibile`, `:74` `avanzamento_forzabile`, `:97` `bevi` |
| Inventario | `inventory.gd:29` `aggiungi`, `:51` `rimuovi`, `:133` `conta`, `:166` `tutto`, `:155` `per_categoria`, `:182` `ricchezza` |
| Vendita dal dialogo | `dialogue_engine.gd:20` `apri_vendita(npc_id)` |
| i18n dei dati | `tools/generate_i18n_stubs.py` (+ validator R-12) |
| Geometria dei fogli sprite | `animation_machine.gd:60-98` (32 px, colonne = frame, righe = direzioni) |

**Vincoli e trappole note (dettagli in `prossimi-passi.md`):**

- Test che chiamano `nuova_partita`/`carica_slot` devono azzerare
  `GameState._partita_attiva` prima e dopo, e chiudere il libro se lo
  aprono: altrimenti `test_page_scaffale` e `test_equipment` (successive
  in ordine alfabetico) falliscono.
- `assert_almost_eq(got, want, what, epsilon)`: il messaggio è il 3°
  argomento.
- `godot --headless --path . --import` prima della suite dopo aver
  toccato PNG/tscn/tres (in 4.3 non sempre esce 0: ignorare l'exit, il
  gate è la suite).
- Le scene regione vengono istanziate headless da 3 suite: i nemici dei
  layout devono restare inerti senza player.
- Xvfb per la verifica a schermo: `xvfb-run -a -s "-screen 0 1280x720x24"
  godot --path . -s <script.gd>`, con `await process_frame` ×2 prima di
  toccare gli autoload, `TranslationServer.set_locale("it")` esplicito,
  overlay aggiunti **prima** di scatenare quello che devono mostrare.
- Godot 4.3 stable (`.github/workflows/ci.yml` ha il download); Pillow
  per i generatori.
- Nessun bump del save. Nessuna modifica a `AbilityEngine.execute`, ai
  dispatcher, alle primitive, a `data/pathways_deferred/`.

---

## 8. Success Metrics

- **Criterio di uscita** (US-814): `tests/manual/qa_vslice.gd` esce 0 con
  tutti gli `assert` e i 12 screenshot; `tests/test_slice_fase_8.gd` grep
  → 0 id di contenuto in `scripts/`.
- **Avvio**: da Play alla regione con un Pathway scelto in ≤ 5 click; nessun
  file toccato fuori da `main.gd`, creazione, `GameState`, `main.tscn`.
- **Abilità**: `abilita_1` lancia `owned[0]` con cooldown visibile; un
  proiettile su un nemico riduce i suoi HP.
- **Recitazione**: TG Sequenza 9 al 100% in una sessione di gioco reale
  (3 kill senza abilità + 2000 danni fisici + 12 parate perfette), e la
  pozione preparata dal libro porta a Sequenza 8.
- **Mondo**: 5 layout validati; ≥ 6 nemici e 1 boss per regione; ogni
  `location_tag` ha una zona; ogni gate ha un varco.
- **Ingredienti**: 299 item generati, 0 `TODO` in `it.json` per gli
  ingredienti, ≤ 5% di `TODO` in `en.json` (parole ignote elencate);
  validator "fonti" verde.
- **Negozio**: compra/vendi cambiano inventario e monete; il negozio di
  Sidon si sblocca giocando (`q_sidon_01` via `item_crafted`).
- **Grafica**: 19 + 4 fogli generati, deterministici, geometria invariata;
  `test_animation_machine.gd` intatto; tell del nemico distinguibile a
  schermo.
- **Nessuna regressione**: i 776 test restano verdi; validator 0 con
  i blocchi nuovi (layouts, fonti, chiusura fase 8).

---

## 9. Open Questions

1. **Drop garantito vs. probabilistico** — `drop_probabilita` 0.6 può
   rendere il primo ciclo lento; alternativa: garantito per la Sequenza 9
   nell'hub. Proposta: 0.6 ovunque, la raccolta a terra nell'hub copre
   il TG 9→7 (US-809). Da tarare dopo il primo playtest.
2. **Prezzi** — `valore` per Sequenza minima d'uso è una scala plausibile;
   il negozio di Sidon a Sequenza 9 deve permettere ≥ 1 acquisto con le
   monete a terra di Mirwada. Verificare in US-811.
3. **Pathway all'avvio: tutti e 10 o solo i "facili"?** — Proposta: tutti,
   ordinati come `pathway_ids()`; la difficoltà è contenuto, non un gate.
4. **Riga del tileset per le regioni future** — `1 + indice in vfx.json`
   lega l'ordine del PNG a quello del JSON: documentare nel `_comment` di
   `vfx.json` che l'ordine è significativo, o generare la mappa
   palette→riga in un piccolo JSON accanto al tileset (US-813 decide).
5. **`tipo_arma` nel payload di `enemy_defeated`** — richiede sapere con
   che arma è arrivato l'ultimo colpo; nessuna Sequenza 9 lo usa. Da fare
   quando un Pathway attivo lo chiede (nota in US-804).
6. **`qa_vslice.gd` in CI?** — no finché le Actions restano disattivate
   (`ci.yml`); resta un comando locale documentato. Da rivalutare a
   ottobre 2026 col reset dei minuti.
