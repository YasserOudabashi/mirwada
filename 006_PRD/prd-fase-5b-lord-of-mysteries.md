# PRD: Fase 5b — Lord of Mysteries (Fool, Error, Door)

## 1. Introduzione / Overview

La fase 5 ha scritto cinque Pathway nuovi (Death, Moon, Mother, Paragon,
Hermit) e superato il **punto di controllo**: `test_slice_fase_5.gd` gioca
Death dalla Sequenza 8 alla 2 con zero righe di codice dedicate. Restano
scoperti quattro Pathway attivi. Tre di questi — **Fool, Error, Door** —
formano il gruppo **Lord of Mysteries** (design-pathways.md): scriverli tutti
e tre chiude un gruppo intero e mantiene possibili i tre percorsi di fusione
di quel gruppo per la fase 7. Il quarto, **Darkness**, completa il gruppo
*eternal_darkness* (già TG + Death) ma le sue nove Sequenze rimaste dipendono
dal ciclo giorno/notte: va nel PRD di fase 6, subito dopo il blocco che
introduce quel ciclo.

Perché questi tre sono stati lasciati per ultimi: usano le **primitive più
difficili da rendere leggibili a schermo**. `illusion` — il giocatore deve
capire quali nemici sono finti. `possess` — di chi è il corpo che controllo,
dov'è il mio. `steal` — cosa ho preso e per quanto. `time_rewind` — cosa è
tornato indietro. Non è un problema di codice: è un problema di design che si
risolve **solo** con contenuto vero in un vero combattimento. La fase 5b
esiste per dargli quel contenuto.

Come tutta la fase 5: i Pathway sono **dati**. Il motore implementa le
primitive del registro chiuso; i JSON compongono il contenuto. L'unica
Sequenza che nel concept punta a una primitiva **differita** — `fool_2`
(Miracle Invoker → `probability_shift`) — si riscrive con primitive attive,
feel equivalente, come `darkness_1`/`paragon_1`/`hermit_1` in fase 5.

Save `schema_version` **invariato**: contenuto, non struttura.

---

## 2. Goals

- **Tre Pathway completi** in `data/pathways/` e `data/abilities/`: Fool,
  Error, Door, tutti a 10/10 Sequenze (abilità, `acting_actions` a somma 1.0,
  `potion` con formula + caratteristica + ingredienti, `advancement_ritual`
  con `location_tags` per le Sequenze ≤ 4). ~60 abilità nuove.
- **Le primitive attive che servono a questi tre hanno un handler e un VFX**:
  `illusion`, `possess`, `steal`, `time_rewind` di sicuro; `chain` e
  `shadow_meld` se una loro Sequenza li richiede. Ognuna implementata **nel
  momento in cui il primo Pathway la usa**, come in fase 5.
- **`fool_2` riscritto** senza `probability_shift`: "converte spiritualità in
  eventi improbabili" reso con `buff_stat`/`debuff_stat` a forte varianza
  dichiarata + `curse` (effetto `sfortuna`, già in `status_effects.json`).
  Grep di `data/abilities/` per `probability_shift` come primitiva → 0.
- **La matrice di proprietà regge** (già check del validator, `ownership.json`):
  Error *ruba* (`steal`, uso singolo, il nemico ne resta privo), Door
  *registra e riproduce* (fotocopia, l'originale resta), Fool *finge*
  (illusioni di poteri); ogni `summon` dichiara la sua materia prima nel
  prefisso di `entita_id`; ogni divinazione fuori da Hermit (`fool_9`,
  `door_7`) rivela solo la `categoria`.
- **Criterio di uscita**: `tests/test_slice_fase_5b.gd` gioca un Pathway
  nuovo intero (proposto: **Error**, Sequenza 8 → 2) in codice — abilità,
  recitazione via `EventTracker`, pozione, rituale — con **zero righe di
  codice che nominano "error" o una sua Sequenza** (grep, come US-508). Il
  `git diff` del blocco tocca solo handler di primitiva nuovi + i loro test.
- **Il gruppo Lord of Mysteries è chiuso**: 3 Pathway completi, i tre percorsi
  di fusione (Fool↔Error, Error↔Door, Fool↔Door) restano possibili per la
  fase 7. Con Darkness (fase 6) saranno **91/100 Sequenze non-stub**; con
  Darkness completo, **100/100**.
- Nessuna regressione: i ~570 test di fase 1-5 restano verdi. Nessuna
  primitiva **nuova** (registro 28 attive + 3 differite); nessun evento nuovo
  (`tracked_events` a 12).

---

## 3. User Stories

Priorità: **P0** blocca il resto; **P1** necessaria; **P2** rifinitura.

### Blocco A — Error (il Pathway del criterio di uscita)

> Error per primo: `steal` è la primitiva-firma del gruppo e la capacità
> "eseguire un'abilità non posseduta" è già stata prevista in fase 2
> (`grant_temporary`, US-204). Se il modello regge su Error, regge sugli
> altri due.

#### US-5B01: Error, Sequenze 9-7 (Marauder → Cryptologist) + `steal`

**Description:** Come giocatore, voglio scassinare e rubare da un nemico,
truffare gli NPC, e decifrare formule e sigilli rubando conoscenza invece di
oggetti.

**Acceptance Criteria:**

- [ ] `data/pathways/error.json` Seq 9/8/7: `stub` → `false`, contenuto pieno
      (stat_modifiers, 2 abilità/Seq, `acting_actions` somma 1.0, `potion`,
      `madness_on_force` crescente da ~1.0). Tier `low`, nessun
      `advancement_ritual`.
- [ ] **Primitiva nuova `steal`** `{ categoria, durata_prestito, probabilita }`:
      handler in `AbilityEngine`, VFX in `data/vfx.json`, tolta dalla lista
      "non implementata". `categoria: "oggetto"` → registra un furto d'item
      (il consumo/aggiunta reale è aggancio inventario, come `stored_ability_id`);
      `categoria: "abilita"` → presta al caster l'`ability_id` visto sul
      nemico via `grant_temporary` (US-204, già esistente) con scadenza
      `durata_prestito`; `categoria: "conoscenza"` → `KnowledgeStore.impara`.
      **Il nemico ne resta privo** è marcato nel record (`sottratto: true`) —
      l'applicazione al bersaglio è combat, fase 6.
- [ ] Seq 8 (Swindler) usa il flusso `npc_influenced` (evento già nel
      vocabolario) via `acting_actions`; nessun `if` per Error.
- [ ] Seq 7 (Cryptologist): `steal` `categoria: "conoscenza"` + `reveal_info`
      con `categoria` valorizzata (divinazione fuori da Hermit).
- [ ] `data/potions/formulas.json` + `data/characteristics.json`: 3 formule +
      3 caratteristiche (`formula_error_9..7`, `char_error_9..7`), ingredienti
      nuovi nel vocabolario.
- [ ] i18n: `generate_i18n_stubs.py` rilanciato; nomi nuovi tradotti in
      `it.json` (non `TODO`).
- [ ] Test headless (`tests/test_error.gd`): ogni abilità Seq 9-7 esegue senza
      warning di primitiva; `steal categoria: "abilita"` rende `is_granted`
      true per la durata e false dopo; le acting sommano 1.0.
- [ ] Verifica a schermo in `progress.txt`: `steal` è leggibile — a schermo si
      vede *cosa* è stato preso (un'icona dell'abilità/oggetto rubato) e per
      quanto (un timer). Se non è leggibile con un manichino scriptato, lo si
      dichiara e si rimanda l'affinamento a un aggancio combat di fase 6.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-5B02: Error, Sequenze 6-4 (Prometheus → Parasite) + `possess`

**Description:** Come giocatore, voglio rubare temporaneamente un'abilità
Beyonder appena vista, entrare nei sogni per rubare ricordi, e attaccarmi a un
ospite usandone sensi e movimento restando nascosto.

**Acceptance Criteria:**

- [ ] Seq 6/5/4 pieni. Seq 4 = tier `saint`, `advancement_ritual`
      obbligatorio con `location_tags` dal vocabolario (US-501:
      `nebbia_grigia`, `crocevia`, `soglia`), `momento`/`fase_lunare`,
      `sacrifices`.
- [ ] Seq 6 (Prometheus): `steal` `categoria: "abilita"` con
      `durata_prestito` breve e `probabilita` < 1.0 (non sempre riesce) — la
      firma dell'Error, distinta dallo `Scribe` del Door (fotocopia, sempre).
- [ ] **Primitiva nuova `possess`** `{ durata, soglia_resistenza, controllo }`:
      handler + VFX + tolta dalla lista. Applica lo status `posseduto` al
      bersaglio (nuovo in `status_effects.json`, `negativo`) e registra
      `controllo` (parziale/totale). Il *corpo del caster* resta a terra
      vulnerabile durante `possess` (registrato, come `soul_detach` di Death);
      la resa combat è fase 6. Seq 4 (Parasite) usa `possess`
      `controllo: "sensi"` (nessun controllo motorio del bersaglio, solo
      percezione condivisa).
- [ ] Seq 5 (Dream Stealer): `steal` `categoria: "conoscenza"` +
      `debuff_stat` (il bersaglio derubato dei ricordi combatte peggio) +
      condizione `e_notte` (i sogni sono di notte — dato, l'engine la legge
      in fase 6).
- [ ] Formule + caratteristiche + ingredienti + i18n + test + verifica a
      schermo di `possess` (di chi è il corpo che controllo? il caster a terra
      è visibile e vulnerabile?).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-5B03: Error, Sequenze 3-0 (Mentor of Deceit → Error) + `time_rewind`

**Description:** Come giocatore, voglio creare avatar autonomi che agiscono
come me, impiantare un errore nel destino di un bersaglio, e riavvolgere brevi
tratti di tempo.

**Acceptance Criteria:**

- [ ] Seq 3/2/1/0 pieni, tier alti, rituali con trade-off espliciti; Seq 1
      sacrifica un'**Ancora** del giocatore (come `twilight_giant_1`).
      `madness_on_force` verso ~12-14.
- [ ] Seq 3 (Mentor of Deceit): `summon` con `entita_id: "avatar_error_…"`
      (prefisso di materia prima nuovo in `ownership.json` — **discussione
      esplicita**: gli avatar dell'Error non sono cadaveri/costrutti/pet/
      chimere; proposta `avatar` come nona materia prima). Se la discussione
      non si chiude, Seq 3 usa `illusion` (avatar illusori) invece di `summon`.
- [ ] Seq 2 (Trojan Horse of Destiny): "impianta un errore nel destino" reso
      con `curse` (effetto `destino_segnato`, già in `status_effects.json` da
      `hermit_1`) + `debuff_stat` pesanti + `dot` a tag `follia`.
- [ ] **Primitiva nuova `time_rewind`** `{ secondi, ripristina, costo_follia }`
      (Seq 1, Worm of Time): handler + VFX + tolta dalla lista. Ripristina lo
      stato del **caster** salvato `secondi` fa (hp, spiritualità, posizione
      se `ripristina` lo include) e addebita `costo_follia` a `Madness`. Il
      "raggio limitato" (altre entità) è combat, fase 6: qui il caster.
      Meccanismo: `AbilityEngine` tiene un ring buffer di snapshot del caster
      ogni ~0.5 s (piccolo, per-caster), `time_rewind` ne rilegge uno.
- [ ] Seq 0 (Error): l'abilità di dominio ("sfrutta i buchi nelle regole") —
      `aura` a raggio ampio con un effetto composito, come i Seq 0 di fase 5.
- [ ] Formule + caratteristiche + ingredienti + i18n + test (`time_rewind`
      riporta gli hp del caster al valore di N secondi fa; costa follia) +
      verifica a schermo (cosa è tornato indietro? un lampo che segna il punto
      di ripristino).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-5B04: CHECKPOINT — Error slice + verdetto

**Description:** Come sviluppatore, voglio la conferma che Error è stato
scritto senza toccare il codice, prima di committare Fool e Door.

**Acceptance Criteria:**

- [ ] `tests/test_slice_fase_5b.gd`: compone un percorso Error dalla Sequenza
      8 alla 2 — per ogni salto Caratteristica → concoct → recitazione via
      `EventTracker` (dai dati) → bevi → avanzamento. Come `test_slice_fase_5`
      ma su un Pathway del gruppo Lord of Mysteries.
- [ ] `test_nessun_codice_nomina_error`: grep di `res://scripts` e
      `res://scripts/pages` per `"error_"` e i nomi di Sequenza. **Zero
      occorrenze** fuori dai commenti.
- [ ] `git diff` del blocco A (`.gd`): solo i nuovi handler `_p_steal`,
      `_p_possess`, `_p_time_rewind` (+ il ring buffer di snapshot per
      `time_rewind`) e i loro test. `AbilityEngine.execute` /
      `_esegui_primitive` non modificati per un caso specifico dell'Error.
      Elenco esatto in `progress.txt`.
- [ ] **Verdetto in `progress.txt`**: l'architettura regge / non regge sui
      Pathway "difficili". Se non regge: correzioni necessarie e STOP.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco B — Fool

#### US-5B05: Fool, Sequenze 9-7 (Seer → Magician) + `illusion`

**Description:** Come giocatore, voglio divinare col pendolo e leggere le
intenzioni nemiche, usare destrezza acrobatica e illusioni brevi, e creare
illusioni solide che infliggono danno percepito.

**Acceptance Criteria:**

- [ ] Seq 9/8/7 pieni. `fool_9` è **già non-stub** dall'audit
      (`fool_divinazione_pendolo`, `fool_lettura_espressioni` — `reveal_info`
      con `categoria`, già conformi alla matrice): la story ne completa
      `stat_modifiers`/`potion`/`madness_on_force` e aggiunge le acting a
      somma 1.0.
- [ ] **Primitiva nuova `illusion`** `{ raggio, durata, potenza, tipo_illusione }`:
      handler + VFX + tolta dalla lista. `fool_velo_illusorio` (stress test,
      già esistente) e `darkness_cancellazione` (Darkness, fase 6) la usano —
      questa è la prima story che la implementa. `tipo_illusione: "copia_nemico"`
      → registra N bersagli-esca (i "finti" combat, fase 6);
      `tipo_illusione: "danno_percepito"` → `dot` a tag `follia` che si
      annulla se il bersaglio "capisce" (condizione di rimozione registrata).
- [ ] **La leggibilità di `illusion` è il rischio numero uno**: la verifica a
      schermo deve mostrare che il giocatore distingue un'esca da un nemico
      vero (un tell visivo sull'esca: bordo tremolante, colore della palette
      Fool). Se non è leggibile, la story si ferma e lo si segnala.
- [ ] Seq 7 (Magician): `illusion tipo_illusione: "oggetto_evocato"` +
      `melee_arc`/`projectile` per il colpo.
- [ ] Formule + caratteristiche + ingredienti + i18n + test (`illusion`
      registra le esche; il danno percepito è un `dot` follia rimuovibile) +
      verifica a schermo.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-5B06: Fool, Sequenze 6-4 (Faceless → Bizarro Sorcerer) + `fool_2` deferred rewrite prep

**Description:** Come giocatore, voglio assumere aspetto e voce di un NPC
ereditandone i permessi sociali, controllare un nemico come marionetta, e
sostituirmi a un oggetto a distanza.

**Acceptance Criteria:**

- [ ] Seq 6/5/4 pieni. Seq 4 rituale obbligatorio con `location_tags`
      (`teatro`, `palco`).
- [ ] Seq 6 (Faceless): "eredita i permessi sociali" → l'abilità concede
      temporaneamente i flag di gate di tipo `npc` (design-world § 4). In
      fase 5b senza regioni: `illusion tipo_illusione: "aspetto"` + un
      `emit_event npc_influenced modo: "ingannato"` via acting; il gate vero
      lo aggancia fase 6.
- [ ] Seq 5 (Marionettist): **`possess`** `controllo: "totale"` (già
      implementata in US-5B02) — il nemico controllato attacca gli altri
      (combat, fase 6); qui `possess` + `debuff_stat` sugli altri nemici che
      "vedono un alleato voltarsi".
- [ ] Seq 4 (Bizarro Sorcerer): `teleport` (già implementata, US-506) con
      `porta_alleati: false` + `illusion` (un'esca lasciata al posto di
      partenza).
- [ ] Formule + caratteristiche + ingredienti + i18n + test + verifica a
      schermo (`possess controllo: "totale"`: si capisce chi controllo?).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-5B07: Fool, Sequenze 3-0 (Scholar of Yore → Fool) — `fool_2` senza `probability_shift`

**Description:** Come giocatore, voglio richiamare dal passato una versione
precedente di me o di un oggetto, spendere spiritualità per eventi improbabili,
e creare un'area di segretezza in cui la realtà locale è manomettibile.

**Acceptance Criteria:**

- [ ] Seq 3/2/1/0 pieni, tier alti, Ancora a Seq 1.
- [ ] Seq 3 (Scholar of Yore): "richiama una versione precedente" →
      `time_rewind` (già implementata, US-5B03) sul caster + un `summon`
      `entita_id` con prefisso `avatar` (o `illusion` se `avatar` non è stato
      approvato in US-5B03).
- [ ] **Seq 2 (Miracle Invoker) SENZA `probability_shift`** (primitiva
      differita): "converte spiritualità in eventi improbabili" reso con
      `buff_stat`/`debuff_stat` a varianza alta dichiarata nel `note` +
      `curse` (effetto `sfortuna`, già esistente) sul bersaglio. Come
      `darkness_1`. La manipolazione *vera* della probabilità resta a Wheel
      of Fortune (gruppo `key_of_light`, differito).
- [ ] Grep di `data/abilities/` per `probability_shift` come primitiva → 0.
- [ ] Seq 1 (Attendant of Mysteries): `terrain_modify`
      `tipo_modifica: "area_di_segretezza"` + `illusion` a raggio ampio.
- [ ] Seq 0 (Fool): l'abilità di dominio ("falsifica la realtà su scala di
      mondo") — `aura` con effetto composito.
- [ ] Formule + caratteristiche + ingredienti + i18n + test + verifica a
      schermo.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco C — Door

> Door ha bisogno di **poche primitive nuove**: `teleport` e `reveal_info`
> sono già implementate (fase 5). Serve `shadow_meld` (Secrets Sorcerer) e la
> "replica" dello Scribe, che per la matrice di proprietà è **fotocopia**
> (l'originale resta), distinta dallo `steal` dell'Error.

#### US-5B08: Door, Sequenze 9-7 (Apprentice → Astrologer) + `shadow_meld`

**Description:** Come giocatore, voglio teletrasporti brevi a vista e aprire
serrature mistiche, incantesimi di fuga e scambio di posizione, e divinazione
stellare che rivela percorsi nascosti.

**Acceptance Criteria:**

- [ ] Seq 9/8/7 pieni. Seq 9 (Apprentice) usa `teleport` (già implementata).
- [ ] **Primitiva nuova `shadow_meld`** `{ durata, velocita, richiede_ombra }`:
      handler + VFX + tolta dalla lista. Applica lo status `occultato`
      (nuovo, `non negativo`; sfugge al rilevamento) al caster per `durata`;
      `richiede_ombra` è registrato (il gate vero — "solo in ombra" — è
      fase 6). Anche Darkness (fase 6, Nightwatcher) lo userà.
- [ ] Seq 8 (Trickmaster): `teleport porta_alleati: false` +
      `debuff_stat`/`buff_stat` per lo "scambio di posizione" (registrato;
      lo swap vero col bersaglio è combat).
- [ ] Seq 7 (Astrologer): `reveal_info` (già implementata) con
      `categoria: "percorso"` — divinazione dello **spazio** (matrice: Door
      divina i percorsi, non le menti).
- [ ] Formule + caratteristiche + ingredienti + i18n + test + verifica a
      schermo di `shadow_meld` (il giocatore si vede "sbiadire"; il tell che
      è occultato).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-5B09: Door, Sequenze 6-4 (Scribe → Secrets Sorcerer)

**Description:** Come giocatore, voglio registrare un'abilità osservata e
riprodurla una volta, viaggiare nel mondo spirituale come scorciatoia, e
occultamento totale che sfugge anche al rilevamento mistico.

**Acceptance Criteria:**

- [ ] Seq 6/5/4 pieni. Seq 4 rituale obbligatorio con `location_tags`
      (`soglia`, `crocevia`).
- [ ] Seq 6 (Scribe): "registra e riproduce" → riusa `AbilityEngine.
      grant_temporary` (US-204) **ma marcato `fotocopia: true`** nel record:
      l'originale sul nemico non è sottratto (distinzione dalla matrice di
      proprietà vs `steal` dell'Error). Nessun `if` per Door: è un parametro
      del `steal`/una variante — proposta: `steal { categoria: "abilita",
      probabilita: 1.0, non_sottrae: true }`, così il vocabolario resta uno.
- [ ] Seq 5 (Traveler): `teleport` `distanza` grande + `porta_alleati: true` —
      il fast travel *del Door* (design-world § 7: scorciatoie istantanee,
      mai permanenza). Nessun `if`: è `teleport` coi parametri giusti.
- [ ] Seq 4 (Secrets Sorcerer): `shadow_meld` (già implementata, US-5B08) con
      `durata` lunga + `illusion` (un'esca).
- [ ] Formule + caratteristiche + ingredienti + i18n + test (la "fotocopia"
      concede l'abilità senza marcare il nemico come derubato) + verifica a
      schermo.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-5B10: Door, Sequenze 3-0 (Wanderer → Door)

**Description:** Come giocatore, voglio teletrasporto a lunga distanza
portando alleati e pet, aprire porte stabili tra piani replicando abilità
note, e chiavi che aprono qualunque cosa.

**Acceptance Criteria:**

- [ ] Seq 3/2/1/0 pieni, tier alti, Ancora a Seq 1.
- [ ] Seq 2 (Planeswalker): `teleport porta_alleati: true` a lunghissima
      distanza + un `steal { non_sottrae: true }` senza registrazione
      preventiva ("replica abilità che conosce"). Nessuna primitiva nuova.
- [ ] Seq 1 (Key of Stars): "chiavi che aprono qualunque cosa, anche luoghi
      senza porta" → `terrain_modify tipo_modifica: "varco_forzato"
      permanente: true` (entra nel `WorldState`, come i varchi del TG) +
      `teleport`.
- [ ] Seq 0 (Door): l'abilità di dominio ("passaggio senza limiti") — `aura`
      + `teleport` a costo ridotto in un raggio.
- [ ] Formule + caratteristiche + ingredienti + i18n + test + verifica a
      schermo (il `varco_forzato` permanente sopravvive al reload — riuso del
      test di `terrain_modify` permanente).
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

### Blocco D — Chiusura

#### US-5B11: Sinergie e caratteristiche del gruppo Lord of Mysteries

**Description:** Come giocatore, voglio che Fool, Error e Door partecipino
alle sinergie e alla creazione personaggio come gli altri Pathway.

**Acceptance Criteria:**

- [ ] `data/synergies/batch_3.json`: `sinergia_inganno_probabilita` (il tag
      `probabilita'` è di `key_of_light`, differito) resta irraggiungibile —
      **atteso**; ma `sinergia_colpo_del_caso` (l'abilità che concede) ora è
      eseguibile e le sinergie di `batch_3` che usano `inganno`/`furto`/
      `spazio`/`viaggio`/`destino` (tag ora portati da Fool/Error/Door via la
      fonte `sequenza`) vanno rivalutate: quali sono diventate raggiungibili?
      Documentato in `progress.txt`.
- [ ] 4-6 sinergie nuove in `data/synergies/batch_5.json` che sfruttano le
      combinazioni del gruppo (Error `steal` + talento; Fool `illusion` +
      pet; Door `teleport` + sigillo d'area…). Tutte raggiungibili, i18n
      completo, `fonti` ≥ 2. Almeno una è una **anti-sinergia** con
      `neutralizza` (Fool + Error si mordono: entrambi mentono).
- [ ] `data/characteristics.json`: le 30 caratteristiche nuove (10 per
      Pathway) esistono e sono **tradotte** (0 `TODO`).
- [ ] Il diagramma dei Pathway nel libro e il frontespizio mostrano Fool,
      Error, Door con contenuto pieno — nessun codice nuovo. Verifica a
      schermo: creo un personaggio su ognuno dei tre.
- [ ] `python tools/validate_data.py` esce 0. Nessuna regressione. Typecheck passes. Tests pass.

#### US-5B12: Chiusura fase 5b

**Description:** Come sviluppatore, voglio che i documenti riflettano il
gruppo Lord of Mysteries chiuso.

**Acceptance Criteria:**

- [ ] `006_PRD/roadmap.md`: la nota "fase 5b" → "CHIUSA per il gruppo Lord of
      Mysteries (12 story); resta Darkness dentro fase 6". Conteggio reale
      story e test.
- [ ] `006_PRD/design-pathways.md`: sezione "Fase 5b" con Fool/Error/Door
      spuntati; Darkness segnato come "nel PRD di fase 6, dopo il day/night".
- [ ] `006_PRD/design-master.md` Appendice C: righe per le primitive
      implementate (`illusion`, `possess`, `steal`, `time_rewind`,
      `shadow_meld`, `chain` se usata); Appendice A aggiornata.
- [ ] `CLAUDE.md` + `README.md`: gruppo Lord of Mysteries chiuso, conteggi,
      criterio di uscita in `test_slice_fase_5b.gd`. Il grep di
      `data/abilities/` per una primitiva differita usata → 0 (tutte le
      Sequenze che ne dipendevano sono state riscritte).
- [ ] Il validator ha un check di chiusura: `fool`/`error`/`door` senza
      Sequenze `stub`.
- [ ] `python tools/validate_data.py` esce 0. Tests pass.

---

## 4. Functional Requirements

- **FR-1:** Nessuna primitiva **nuova** e nessun evento nuovo. Le primitive
  "implementate" (`illusion`, `possess`, `steal`, `time_rewind`,
  `shadow_meld`, ev. `chain`) erano già nel registro senza handler.
- **FR-2:** Ogni primitiva senza handler si implementa nella story del **primo
  Pathway di questa fase che la usa**, col suo VFX. Ordine atteso: `steal`
  (US-5B01), `possess` (US-5B02), `time_rewind` (US-5B03), `illusion`
  (US-5B05), `shadow_meld` (US-5B08). `chain` solo se una Sequenza lo
  richiede davvero (altrimenti resta senza handler, documentato).
- **FR-3:** Ogni Sequenza non-stub: `stat_modifiers`, `abilities` (2, che
  risolvono), `acting_actions` (somma **1.0**, eventi dai 12), `potion`
  (`formula_id` che risolve, `characteristic_sequence` coerente, ingredienti
  nel vocabolario), `madness_on_force > 0` crescente. Sequenze ≤ 4:
  `advancement_ritual` con `location_tags` dal vocabolario di US-501.
- **FR-4:** Le abilità sono composte **solo** da primitive del registro
  attivo. `fool_2` (Miracle Invoker → `probability_shift`) si riscrive con
  primitive attive, feel equivalente.
- **FR-5:** **Matrice di proprietà** (già check del validator): Error `steal`
  **sottrae** (`sottratto: true`), Door replica **non sottrae**
  (`non_sottrae: true` / `fotocopia: true`), Fool **finge** (`illusion` di
  poteri). Un solo vocabolario di primitiva (`steal` con un flag), non due
  primitive.
- **FR-6:** `time_rewind` legge da un ring buffer di snapshot del **caster**
  tenuto da `AbilityEngine` (piccolo, per-caster, ~0.5 s di granularità). Non
  tocca il save né il `WorldState`. Il "raggio limitato" su altre entità è
  fase 6.
- **FR-7:** `possess` e `soul_detach` (Death) condividono il pattern "il corpo
  del caster resta a terra vulnerabile" — registrato nel record, la resa
  combat è fase 6. Nessun sistema nuovo.
- **FR-8:** Se una Sequenza sembra richiedere una materia prima di `summon`
  nuova (gli avatar dell'Error/Scholar of Yore), **discussione esplicita**
  prima di aggiungere `avatar` a `ownership.json`. Fallback: `illusion`.
- **FR-9:** i18n: dopo ogni story, `generate_i18n_stubs.py` rilanciato e i
  nomi nuovi **tradotti** in `it.json`.
- **FR-10:** Ogni story con un'abilità che usa una primitiva **nuova** ha una
  **verifica a schermo** documentata in `progress.txt`. Per `illusion`,
  `possess` e `steal` la verifica riguarda esplicitamente la **leggibilità**
  (il giocatore capisce cosa è successo?), non solo che l'abilità esegua.
- **FR-11:** Il `schema_version` del save **non cambia**.
- **FR-12:** Ordine vincolante: **Blocco A (Error) + US-5B04 (checkpoint)
  prima di Fool e Door**; il checkpoint ha potere di veto.
- **FR-13:** Ogni story chiude in una context window; se supera ~4 file di
  logica o ~200 righe di diff di codice, si spezza.

---

## 5. Non-Goals (Out of Scope)

- **Darkness.** Le nove Sequenze rimaste (9-2, `darkness_1` già fatta in
  US-503) vanno nel PRD di fase 6, subito dopo il blocco day/night: il loro
  concept ("statistiche raddoppiate al buio", "oscurità creabile", incubi)
  dipende dal ciclo giorno/notte. `shadow_meld` viene implementata qui
  (US-5B08) e Darkness la trova pronta.
- **Le 3 primitive differite** (`weather_control`, `probability_shift`,
  `rule_bind`). `fool_2` si riscrive, non aspetta.
- **La resa combat delle primitive.** `illusion` che spawna esche vere,
  `possess` che fa attaccare il nemico controllato, `steal` che sottrae
  l'abilità al bersaglio, gli avatar autonomi dell'Error: tutto questo è
  **integrazione combat/IA**, fase 6. In fase 5b la primitiva registra il
  fatto e applica lo status; la verifica a schermo giudica la leggibilità del
  VFX e degli status, non il comportamento nemico.
- **I gate di zona e i permessi sociali.** Il Faceless "eredita i permessi",
  il Traveler "viaggia tra zone": i gate veri sono fase 6. In fase 5b le
  abilità emettono l'evento/registrano il fatto.
- **Il bilanciamento reale.** Valori plausibili, da riscrivere dopo il
  playtest.
- **La fase 7** (cambio Pathway, fusioni del gruppo, finali). Le Sequenze 0
  si scrivono; il sistema che le intreccia no.

---

## 6. Design Considerations

- **Il gold standard resta `twilight_giant.json`** + i 5 Pathway di fase 5:
  trade-off espliciti nelle abilità alte, recitazione che *accetta la natura
  del potere*, `madness_on_force` da ~1 a ~14, Ancora al rituale di Seq 1.
- **La leggibilità è il tema di questa fase.** `design-vfx.md` va riletto per
  `illusion` (le esche hanno un tell di palette Fool), `possess` (l'aura sul
  bersaglio + il corpo del caster a terra evidenziato), `steal` (l'icona di
  ciò che è stato preso + il timer di prestito). Se un VFX placeholder non
  basta a rendere leggibile la meccanica, è un segnale che quella meccanica
  ha bisogno di UI dedicata (fase 6), e va scritto.
- **La matrice di proprietà fa il lavoro pesante.** Error vs Door sulla copia
  di abilità è la sovrapposizione più delicata: un solo `steal` con
  `non_sottrae`/`sottratto` risolve, senza due primitive. Il validator lo
  verifica già (`ownership.json`).
- **Riuso.** `grant_temporary` (US-204) per `steal categoria: "abilita"` e per
  la fotocopia del Door; `status_effects.json` per `posseduto`/`occultato`
  (nuovi) e `sfortuna`/`destino_segnato` (già esistenti); `KnowledgeStore`
  per `steal categoria: "conoscenza"`; `WorldState` per il `varco_forzato`
  del Key of Stars; il diff-su-insieme e la pagina del libro invariati.

---

## 7. Technical Considerations

- **`AbilityEngine`.** Le primitive nuove sono nuove entry in `_handlers` +
  nuovi `_p_<tipo>`. `execute`/`_esegui_primitive` non si toccano. `steal`
  con `categoria: "abilita"` chiama `grant_temporary` — è già pubblico.
- **`time_rewind` e il ring buffer.** `AbilityEngine` tiene, per ogni caster
  che ha eseguito un'abilità di recente, ~10 snapshot (hp, spiritualità,
  posizione, ms) a passo ~0.5 s. `_process` lo aggiorna; lo si purga insieme
  ai cooldown dei caster morti (già c'è `sweep_cooldowns`). Costo: trascurabile.
- **`possess` / `soul_detach`.** Stesso record `{ corpo_a_terra: true,
  vulnerabilita_corpo, durata }`. Il combat di fase 6 lo legge; qui è dato.
- **Save.** Nessun bump. `time_rewind` non serializza nulla.
- **`generate_pathways.py`** idempotente: si rilancia dopo ogni story senza
  perdere il lavoro (doppia rigenerazione = zero diff).
- **`ralph`.** `--fase 5b` — richiede il campo `"fase": "5b"` in `prd.json`
  (stringa, non int: `ralph.sh` filtra sul campo, non sull'id). Docker
  attivo, `--test-cmd "godot --headless --script tests/run_tests.gd"`. Una
  story per iterazione. Godot 4.3 headless in locale a ogni story; verifica a
  schermo reale per le story con primitiva nuova.
- **Nessuna dipendenza nuova.**

---

## 8. Success Metrics

- **Criterio di uscita (`test_slice_fase_5b.gd`)**: Error dalla Sequenza 8
  alla 2 giocato in codice, **zero righe di codice che nominano "error"** o
  una sua Sequenza. I soli file `.gd` toccati nel blocco A sono handler di
  primitiva nuovi + il ring buffer di `time_rewind` + i loro test.
- **3 Pathway completi**: Fool, Error, Door a 10/10 Sequenze, ~60 abilità,
  tutte da primitive del registro attivo.
- **Ogni primitiva che un'abilità usa ha un handler**: la lista "non
  implementata" si svuota di `illusion`, `possess`, `steal`, `time_rewind`,
  `shadow_meld` (+ `chain` se usata).
- **Nessuna primitiva differita in un file attivo**: grep di
  `data/abilities/` per `weather_control|probability_shift|rule_bind` → 0.
- **Leggibilità verificata a schermo** per `illusion`, `possess`, `steal`:
  la verifica in `progress.txt` dice esplicitamente se il giocatore capisce
  cosa è successo, e cosa serve alla fase 6 se non basta.
- **Gruppo Lord of Mysteries chiuso**: 3 percorsi di fusione possibili per la
  fase 7. Con Darkness (fase 6): 100/100 Sequenze non-stub.
- **Nessuna regressione**: i ~570 test di fase 1-5 restano verdi.
  `schema_version` invariato.

---

## 9. Open Questions

1. **`avatar` come nona materia prima di `summon`** (Error Seq 3, Fool Seq 3):
   gli avatar non sono cadaveri/costrutti/pet/chimere/evocazioni. Aggiungere
   `avatar` a `ownership.json` (una story di dati con motivazione) o
   modellarli con `illusion`? Proposta: `illusion` per il Fool (sono finti),
   `avatar` per l'Error (sono autonomi) — se si aggiunge, è la nona voce e
   basta.
2. **`steal categoria: "oggetto"`** senza sistema di combattimento: registra
   solo il fatto, o aggancia già `Inventory.rimuovi`/`aggiungi` con un
   bersaglio-manichino nei test? Proposta: solo record in 5b, aggancio in
   fase 6.
3. **`illusion` e il numero di esche**: `potenza` = numero di copie? O
   `potenza` = quanto sono convincenti (durata prima che il nemico "capisca")
   e le copie sono fisse? Da decidere in US-5B05 col primo VFX a schermo.
4. **Darkness in fase 6 vs 5c**: le 9 Sequenze di Darkness sono un blocco del
   PRD di fase 6 (dopo day/night) o un mini-PRD "fase 5c" a sé? Proposta:
   blocco di fase 6, 3 story, subito dopo il ciclo giorno/notte.
5. **`test_slice_fase_5b.gd` su Error o su Fool?** Error ha meno primitive
   "di leggibilità" da tarare nel percorso 8→2 (steal, possess) e più
   agganci ai sistemi (KnowledgeStore, grant_temporary): è il test più
   informativo sull'architettura. Fool sarebbe il test più informativo sulla
   *leggibilità*. Proposta: slice su Error (architettura), verifica a schermo
   dedicata sul Fool (leggibilità).
