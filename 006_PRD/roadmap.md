# Roadmap — Fasi 2-8

Scaletta, non PRD. Ogni fase riceve il suo PRD dettagliato con `/prd`
**quando la fase precedente e' chiusa**, non prima: scrivere ora il PRD della
fase 6 significa scriverlo sulla base di ipotesi che le fasi 1-5 smentiranno.

---

## Fase 2 — Pathway core (~22 story)

> **PRD generato il 2026-09-03**: `006_PRD/prd-fase-2-pathway-core.md`
> (~31 story, non ~22: la stima non contava il blocco UI-libro / VFX / i18n
> che `design-master.md` Appendice A colloca in fase 2). Questa sezione resta
> come scaletta di riferimento; la verità è il PRD.

Il salto piu' rischioso del progetto. Qui si scopre se l'architettura
data-driven regge.

- Sistema Sequenze: stato del giocatore (pathway attuale, sequenza, tier)
- Caratteristiche Beyonder come oggetti droppabili
- Formule delle pozioni, incluse le **formule parziali** (3 ingredienti su 5)
- Concoction: pozione da Caratteristica + ingredienti
- **EventTracker generico** (1 story): contatori sui 12 eventi di
  `data/schema/tracked_events.json`. E' la versione RIDOTTA dell'Acting Method:
  nessun rilevatore speciale per azione, un solo sistema che conta eventi
  filtrati. Le azioni di recitazione sono gia' scritte come dati.
- **Acting Method**: barra `acting_progress` alimentata dall'EventTracker,
  decadimento per azioni incoerenti
- Blocco dell'avanzamento sotto `acting_progress` 1.0
- **Follia**: statistica cumulativa, sorgenti multiple, effetti a soglia
- **Layer audio della follia** (data/audio.json.madness_layer): 4 soglie di
  sussurri + one-shot casuali senza causa visibile. I sussurri a soglia 55
  usano i nomi degli NPC incontrati e delle Ancore del giocatore.
- **Percezione per Sequenza**: salendo si sentono layer ambientali nuovi e si
  rivelano informazioni (spiriti vicini, densita' mistica, segreti adiacenti).
  E' un canale informativo che si potenzia con la coltivazione.
- Effetti visivi della follia, con opzione di accessibilita'
- **Ancore**: registrazione, effetto di riduzione, distruggibilita'
- **Rituale di avanzamento** da Sequenza 5 in su: luogo, momento, sacrifici,
  sigilli, interruzione
- **Twilight Giant**: il PIU' e' GIA' SCRITTO. `data/abilities/twilight_giant.json`
  contiene tutte e 10 le Sequenze con 20 abilita', modificatori, azioni di
  recitazione, ingredienti e rituali. La fase 2 non deve progettarlo: deve
  farlo ESEGUIRE dal motore. Se il motore lo esegue senza codice dedicato,
  l'architettura e' validata e le fasi successive sono lavoro meccanico.
- 10 primitive aggiuntive (arriviamo a 15 su 28)
- **Tre capacita' del motore emerse dallo stress test** (vedi
  `006_PRD/design-pathways.md`), da prevedere ORA e non in fase 5:
  1. `AbilityEngine` deve eseguire un'abilita' non posseduta, con durata di
     prestito (serve all'Error)
  2. `summon` con `durata: -1` produce entita' persistenti che vanno
     serializzate nel save
  3. gli oggetti devono poter portare un `stored_ability_id` (fase 3, ma il
     motore va predisposto ora)
- Diagramma dei Pathway in UI, con fog of war sulla conoscenza

**Criterio di uscita:** si puo' partire da Sequenza 9 e arrivare a Sequenza 5
giocando, con avanzamenti veri, follia che cresce e Ancore che contano.

---

## Fase 3 — Sistemi di supporto — CHIUSA (35 story, 498 test)

> **PRD**: `006_PRD/prd-fase-3-sistemi-di-supporto.md`. Chiusa il 2026-09-06:
> 35 story `US-301..336` in 8 blocchi (A inventario/equip, B alchimia,
> C forgiatura/sigilli, D strutture, E pet, F base building, G talenti,
> H integrazione). Il save e' passato da schema_version 12 a 19. Verdetto
> sull'architettura (US-335, `tests/test_slice_fase_3.gd`): i sistemi di
> supporto compongono un ciclo completo — coltivazione, alchimia, forgia,
> sigilli, pet, talenti, sinergie — con **zero righe di codice dedicate a un
> contenuto specifico**, come il Twilight Giant in fase 2. Nessuna primitiva
> nuova, i 12 `tracked_events` invariati.
>
> **Vocabolari chiusi nuovi della fase 3**:
> `data/schema/item_categories.json` (7 categorie), `equip_slots.json`
> (4 slot + 3 tipi), `room_types.json` (4 tipi di stanza + chiavi di bonus
> ammesse), `tracked_talents.json` (7 comportamenti-talento — distinti dai 12
> eventi), `sigil_effect_types.json` + `sigillato_effect_types.json` (tipi di
> effetto/collaterale), `experiment_outcomes.json` (5 esiti pesati).
> **Formati nuovi**: `structure.schema.json`, `pet.schema.json`,
> `room.schema.json`, `talent.schema.json`, `forge_blueprint.schema.json`,
> `sigil.schema.json`.

- Inventario e equipaggiamento con tag di sinergia
- **Oggetti con `stored_ability_id`**: pergamene e congegni che contengono
  un'abilita' eseguibile al consumo. Sblocca sinergie tra Pathway diversi
  (un Paragon puo' costruire un oggetto che contiene un'abilita' del Fool).
- Alchimia: qualita', fallimenti mostruosi, scoperta delle ricette
- Forgiatura e incisione di sigilli
- Oggetti Sigillati con effetti collaterali
- Un pet completo: taming, `bond`, coltivazione del pet, morte del pet come
  perdita di Ancora
- Base building: griglia, 4 stanze funzionali (laboratorio, stanza rituale,
  biblioteca, giardino)
- Talenti innati e talenti acquisiti per osservazione del comportamento

---

## Fase 4 — Sinergie — CHIUSA (16 story, 535 test)

> **PRD**: `006_PRD/prd-fase-4-sinergie.md`. Chiusa il 2026-09-06:
> 16 story `US-401..416` in 3 blocchi (A il motore, B il registro nel libro,
> C il contenuto). Il save e' passato da schema_version 19 a 20 (un bump, una
> `_migra_19_a_20`). Verdetto sull'architettura (US-413,
> `tests/test_slice_fase_4.gd`): `sinergia_dottrina_del_guardiano` nasce solo
> combinando pet (`guerra`) + stanza (`conoscenza`) + talento (`non_letale`) —
> nessuna fonte da sola basta — e si attiva col suo effetto misurabile e
> **zero righe di codice che la nominano**. Nessuna primitiva nuova, i 12
> `tracked_events` invariati.
>
> **Cosa contiene**:
> - `SynergyEngine` (autoload): risoluzione tag -> sinergie attive, poll a
>   2 Hz + segnali delle fonti, `stato_registro()` / `contatore()` per il
>   fog of war.
> - I **6 tipi di effetto** funzionano tutti (applicazione + rimozione):
>   `modifica_stat`, `modifica_follia`, `modifica_qualita_crafting`,
>   `sblocca_ricetta`, `aggiungi_abilita`, `modifica_primitiva` (hook in
>   `AbilityEngine._esegui_primitive` su una copia di `prim`).
> - **Priorita' e conflitti**: cumulativi si sommano, esclusivi -> `priorita`
>   desc poi `id` asc. `spiega(id)` per debug/UI.
> - **Anti-sinergie**: `anti: true` + `neutralizza: [id]` dichiarato nei dati.
> - **Registro** persistente (`sinergie.viste` nel save) + sezione Sinergie
>   nella pagina inventario del libro, reattiva dal vivo.
> - **44 sinergie** di cui **26 raggiungibili** coi 10 Pathway attivi; le
>   altre 18 (`batch_3.json` + 2 in `core.json`) richiedono tag di gruppi
>   differiti e si accenderanno riattivando il gruppo (mappa in
>   `design-pathways.md`). `sinergia_colpo_del_caso` scritta
>   (`data/abilities/synergy.json`).
> - `synergy.schema.json` esteso: `priorita`, `effetto` come `oneOf` dei 6
>   tipi, `neutralizza`.

**Criterio di uscita:** una sinergia nata da pet + stanza + talento si attiva
davvero, senza codice dedicato. **Verificato** in `test_slice_fase_4.gd`.

---

## Fase 5 — Espansione contenuti — CHIUSA (22 story, 570 test)

> **PRD**: `006_PRD/prd-fase-5-espansione-contenuti.md`. Chiusa il 2026-09-07:
> 22 story `US-501..522` in 6 blocchi (0 fondamenta, 1 Death + checkpoint,
> 2 Moon, 3 Mother, 4 Paragon, 5 Hermit, 6 chiusura). Save `schema_version`
> INVARIATO (la fase 5 e' contenuto, non struttura).
>
> **Verdetto del punto di controllo (US-508)**: l'architettura REGGE oltre il
> Twilight Giant. `tests/test_slice_fase_5.gd` gioca Death dalla Sequenza 8
> alla 2 in codice (Caratteristica -> concoct -> recitazione via EventTracker
> -> bevi -> avanzamento) con ZERO righe di codice che nominano "death". Il
> `git diff` del blocco Death tocca solo 5 handler `_p_<primitiva>` nel
> pattern del registro chiuso + `player.teleport_verso`;
> `AbilityEngine.execute` e `_esegui_primitive` sono intatti.
>
> **Cosa contiene**:
> - 5 Pathway completi: Death, Moon, Mother, Paragon, Hermit, tutti a 10/10
>   Sequenze. 61 Sequenze non-stub su 100 (10 TG + fool_9 + 50).
> - 7 primitive implementate: `fear`, `reveal_info`, `teleport`, `soul_detach`,
>   `resurrect`, `plant_growth`, `mind_read`, ognuna quando il primo Pathway
>   l'ha richiesta.
> - `darkness_1`, `paragon_1`, `hermit_1` riscritte senza le primitive
>   differite (`probability_shift`, `rule_bind`). Grep di `data/abilities/`
>   per una primitiva differita usata -> 0.
> - `data/schema/location_tags.json` (29 luoghi) + `ownership.json` (la
>   matrice di proprieta' come check del validator).
> - 6 sinergie nuove (`batch_4.json`); 32 raggiungibili su 50.
> - Regola `acting_actions` somma esatta 1.0 (errore, non warning).
>
> **Fase 5b** (non ancora un PRD): Darkness (le altre 9 Sequenze), Fool,
> Error, Door. Le primitive dure senza handler (`illusion`, `possess`,
> `steal`, `time_rewind`, `chain`, `shadow_meld`) hanno bisogno del ciclo
> giorno/notte e delle regioni di fase 6 per essere tarate a schermo.

Ordine di implementazione e stress test in `006_PRD/design-pathways.md`.

---

## Fase 6 — Mondo — CHIUSA (22 story, 669 test)

> **PRD**: `006_PRD/prd-fase-6-mondo.md`. Chiusa il 2026-09-08: 22 story
> (`US-601..622` + `US-613b`, `US-616b`) in 9 blocchi (A regioni, B condizioni
> del tempo, C Darkness, D gating, E NPC, F dialoghi, G fazioni + quest,
> H mappa + densita' + audio, I narrativa + chiusura). Save `schema_version`
> 20 -> 21 con UNA `_migra_20_a_21` (US-602, l'unico bump: tempo, npc,
> reputazione, quest, flag stanno tutti nel campo `mondo` senza bumpare).
>
> **Cosa contiene**:
> - 5 regioni giocabili (una scena `region_scene.gd` data-driven per tutte),
>   ciclo giorno/notte + fasi lunari (`TimeSystem`), le condizioni `e_notte` /
>   `fase_lunare` / `in_zona_tag` delle abilita' ORA valgono (`Conditions`
>   condiviso da `AbilityEngine` e `DialogueEngine`).
> - **Darkness completo 10/10** (fase 5b, gruppo eternal_darkness): +
>   `shadow_meld` e `illusion` implementate. 71/100 Sequenze non-stub.
> - Gating dell'esplorazione: `AreaGate` legge `regions.json.gating[]`
>   (6 modi da `gate_types.json`), `terrain_modify` permanente lo apre per
>   sempre.
> - 8 NPC (`roster.json`) con schedule, memoria, Ancore; motore dialoghi
>   (`DialogueEngine`, effetti da vocabolario chiuso); i 9 grafi; fazioni +
>   reputazione (`FactionSystem`, comportamenti automatici dai dati); motore
>   quest (`QuestSystem`, lettore di eventi + flag, zero verbi nuovi) + le 4
>   quest di Atto I + il Journal nel libro.
> - Pagina mappa (fog of war, fast travel = potere); densita' mistica
>   (recupero, forzatura, percezione da Seq 5); audio del mondo come SPEC
>   (nessun file audio prodotto).
> - Antagonista strutturale (`data/lore/antagonisti.json`, uno per Pathway);
>   Aldo avanza col tempo di gioco; flag `atto_1_concluso` / `aldo_duello_disponibile`.
> - Vocabolari chiusi nuovi: `gate_types.json` (6), effetti dei dialoghi (6),
>   effetti delle quest (5), livelli di reputazione. Schema nuovi:
>   `npc.schema.json`, `dialogue.schema.json`, `quest.schema.json`,
>   `faction.schema.json`, `region.schema.json`.
>
> **Fase 5b (CHIUSA il 2026-09-08, vedi sotto)**: Fool, Error, Door completati.
> Darkness era gia' stato completato qui in fase 6 (blocco C, gruppo
> eternal_darkness).

- **Musica a layer per zona**: stem di base sempre attivo + stem che entrano
  su tensione/combattimento/boss, con crossfade. Riduce i minuti di musica da
  comporre e toglie il taglio brusco all'ingresso in combattimento.
- **Drone del rituale**: build di 45 secondi, e su interruzione taglio SECCO
  al silenzio prima della perdita di controllo.
- Ambienti sonori per zona, ciclo giorno/notte anche in audio

- 4-6 regioni disegnate a mano
- Gating per primitiva: `teleport`, `plant_growth`, `shadow_meld` aprono strade diverse
- Densita' mistica per zona
- Ciclo giorno/notte e fasi lunari con effetti meccanici
- Fazioni e reputazione
- NPC, dialoghi, quest
- Segreti e lore

---

## Fase 5b — Lord of Mysteries — CHIUSA per il gruppo (12 story, 713 test)

> **PRD**: `006_PRD/prd-fase-5b-lord-of-mysteries.md`. Chiusa il 2026-09-08:
> 12 story `US-5B01..5B12` in 4 blocchi (A Error + checkpoint, B Fool, C Door,
> D chiusura). Save `schema_version` **INVARIATO** (contenuto, non struttura).
> Darkness (l'altro membro del gruppo eternal_darkness rimasto) era gia' stato
> completato in fase 6, blocco C.
>
> **Verdetto del checkpoint (US-5B04)**: l'architettura della fase 2 REGGE
> anche sui Pathway "difficili" del Lord of Mysteries. `tests/test_slice_fase_5b.gd`
> gioca Error dalla Sequenza 8 alla 2 in codice con ZERO righe che nominano
> "error". Il `git diff` del blocco A (file `.gd` non di test) e' SOLO
> `scripts/ability_engine.gd` +173 -0: i 3 handler `_p_steal` / `_p_possess` /
> `_p_time_rewind` + il ring buffer di `time_rewind` + hook generici
> (`execute()` +1 riga `_campiona_snapshot`, `_process`/`sweep` piccole
> aggiunte). `execute` / `_esegui_primitive` — il dispatcher — intatti.
>
> **Cosa contiene**:
> - **3 Pathway completi**: Fool, Error, Door, tutti a 10/10 Sequenze. Con
>   Darkness (fase 6) e i 19 gia' fatti: **22/22 Pathway attivi completi,
>   100/100 Sequenze non-stub**.
> - **3 primitive implementate**: `steal` (categoria oggetto/abilita/conoscenza,
>   +param `ability_id`/`non_sottrae`), `possess` (status `posseduto`, record
>   `corpo_a_terra` come `soul_detach`), `time_rewind` (ring buffer di snapshot
>   per-caster in `AbilityEngine`, non tocca il save). `illusion` e
>   `shadow_meld` erano gia' implementate in fase 6; `_p_illusion` esteso
>   (`potenza` per-`tipo_illusione`). `chain` resta senza handler: nessuna
>   Sequenza attiva lo richiede.
> - **`fool_2` (Miracle Invoker) riscritta senza `probability_shift`**: buff/
>   debuff a varianza dichiarata + `curse(sfortuna)` gia' esistente. Grep di
>   `data/abilities/` per una primitiva differita usata come `tipo` -> **0**.
> - **Materia prima `avatar`** in `ownership.json` (9a voce di `summon`): gli
>   avatar dell'Error sono autonomi; il Fool usa `illusion` (sono finti).
> - **`data/synergies/batch_5.json`**: 6 sinergie del gruppo, tutte
>   raggiungibili, + `anti_due_bugiardi` (anti-sinergia, neutralizza
>   `sinergia_ladro_di_poteri`). `sinergia_contratto_solare` di `batch_3` e'
>   diventata raggiungibile (tag `contratto` da `error_patto_truffaldino`).
> - Nessun vocabolario di eventi nuovo (i 12 `tracked_events` invariati).
>
> **Criterio di uscita nel validator**: `tools/validate_data.py` verifica che
> Fool/Error/Door non abbiano Sequenze stub, che `steal`/`possess`/`time_rewind`
> siano `implemented`, che `batch_5.json` esista, e che il gioco sia a 100/100
> Sequenze non-stub.

---

## Fase 7 — Endgame — CHIUSA (21 story, 776 test)

> **PRD**: `006_PRD/prd-fase-7-endgame.md`. Chiusa il 2026-09-09: 21 story
> (`US-701..721`) in 5 blocchi (0 fondamenta, A cambio Pathway + fusione,
> B tribolazioni, C Sequenze alte/preghiere + siti rituali, D finali +
> eredita', E checkpoint + chiusura). Save `schema_version` **21 -> 22**
> con UNA `_migra_21_a_22` (US-701, l'unico bump: cambio Pathway, fusioni,
> tribolazioni superate, eredita', finale stanno tutti nel campo `endgame`).
>
> **Cosa contiene**:
> - Cambio di Pathway (`PathwayChange`) solo tra vicini dello stesso gruppo,
>   sotto una soglia di Sequenza; conserva le abilita' delle Sequenze basse
>   del vecchio Pathway. Fusione (`FusionEngine`) data-driven da
>   `data/fusions/*.json`: 1 percorso completo (`error_door`, 6 abilita' fuse),
>   7 stub dichiarati (fase 7b).
> - Tribolazioni ai salti di fascia (Seq 7->6, 5->4, 3->2, 1->0):
>   `TribulationSystem`, lettore puro di eventi/flag, blocca
>   `Progression.avanza` finche' non superate; le 4 di contenuto con
>   handicap temporaneo e overlay nel libro.
> - Sequenze alte come contenuto: 6 abilita' di "preghiera" (campo
>   puramente semantico) su primitive gia' esistenti; i siti rituali di
>   Sequenza 0 spostati dai tag generici a 4 siti condivisi per gruppo,
>   coerenti con l'antagonista e col cambio Pathway.
> - I 3 finali (Apoteosi, Consumazione = il game over per follia,
>   Rinuncia) come dati (`data/endings.json`), valutati e scelti da
>   `EndingSystem` (nessun tipo di condizione nuovo); schermata di finale
>   che estende il colophon (non un tipo di pagina nuovo); eredita' al
>   personaggio successivo (conoscenza sempre, Ancora a forza dimezzata,
>   reputazione dimezzata e un oggetto per il profilo "completo") scelta
>   dal giocatore e riapplicata a un nuovo personaggio sullo stesso slot.
> - Fog of war sui nomi di Sequenza nel diagramma del libro: si conosce al
>   massimo il nome della Sequenza immediatamente successiva alla propria
>   (richiesta utente in corsa, non pianificata nel PRD originale).
> - Vocabolari chiusi nuovi: `tribulation_effects.json`, `prayer_effects.json`,
>   gli enum `fusion`/`ending`/`eredita_profilo`. Schema nuovi:
>   `fusion.schema.json`, `tribulation.schema.json`, `ending.schema.json`.
> - **Verdetto del checkpoint (US-720)**: l'endgame e' dati. Un personaggio
>   attraversa cambio Pathway + fusione, una tribolazione superata, un
>   finale raggiunto e l'eredita' riapplicata a un nuovo personaggio, senza
>   una riga di codice che nomini un Pathway/una fusione/una tribolazione/
>   un finale specifico. `scripts/ability_engine.gd` non toccato in tutta
>   la fase.

---

## Fase 8 — Vertical slice giocabile (IN CORSO)

> PRD: `006_PRD/prd-fase-8-vertical-slice.md` (19 story: US-801..US-806,
> US-807a..d, US-808, US-809a..c, US-810..US-814 — US-807 spezzata in 4
> per regione, US-809 spezzata in 3 per meccanica).
> Istruzioni operative per eseguirlo: `006_PRD/prossimi-passi.md`.

Le fasi 1-7 hanno costruito **tutti i sistemi** del gioco, provati da 776
test headless. **Ma nessuno puo' giocarlo con la tastiera**: `main.tscn` e'
rimasta la scena di prova della fase 1. Diagnosi fatta il 2026-09-09
giocando davvero il gioco (Xvfb + screenshot) e con tre esplorazioni del
codice — sei blocchi, tutti verificati `file:riga` nel PRD:

1. L'avvio non avvia una partita (`Book.apri()`/`GameState.nuova_partita()`
   non sono mai chiamati; nessuna scelta del Pathway alla creazione).
2. Nessun tasto lancia un'abilita' (`AbilityEngine.execute` esiste, nessun
   input lo raggiunge).
3. Proiettili e archi non fanno danno (nessun `collision_mask`, nessun
   `area_entered`: solo `hitbox.gd` colpisce davvero).
4. La recitazione si ferma a ~1.5%: `enemy_defeated` e' emesso con payload
   `{}`, quindi il filtro `senza_abilita` non matcha mai; e
   `damage_absorbed_for_ally` non ha emettitori (nessun alleato in scena).
5. **Nessuno puo' salire di Sequenza**: `PotionSystem.concoct/bevi` non ha
   UI, e i **299 ingredienti** delle 100 formule non esistono come oggetti.
6. Il mondo e' un pavimento piatto generato dal codice: 0 nemici e 0
   oggetti nelle 5 regioni, NPC = quadrati blu, sprite diagnostici.

**Cosa fa la fase 8**: collega i sistemi gia' scritti in una partita
giocabile, riempie i dati mancanti, e mette una grafica provvisoria
generata. **Zero sistemi nuovi**, zero primitive/eventi/tag nuovi, save
`schema_version` **22 invariato**.

7 blocchi: 0 avvio + controlli (avvio di partita con scelta del Pathway,
abilita' a tastiera + hotbar, proiettili che colpiscono), A recitazione
(payload veri di `enemy_defeated`, `item_crafted`/`ritual_completed`/
`area_cleared`, `tg_9_protettore` riscritta nei dati), B mondo (mappe ASCII
disegnate a mano in `data/world/layouts/`, nemici/boss/oggetti dai dati),
C economia (i 299 ingredienti diventano oggetti con almeno una fonte:
drop, listini, raccolta), D pagine del libro (sezione Avanzamento con
Prepara/Bevi, negozio compra/vendi nel dialogo), E grafica (pixel art
procedurale deterministica, stessa geometria dei fogli attuali), F verifica
giocata end-to-end + chiusura.

---

## Fase 9 — Opzionale

Pathway Non-Standard (Eternal Aeon, Chaos Primogenitor, Scrooge, Dreamless e
gli altri bestowers). Meccanica diversa: avanzamento per **Boon** invece che
per pozione, quindi non e' solo contenuto ma un secondo sistema di
progressione. Le fasi 1-7 sono chiuse: sbloccata, ma opzionale — il PRD
dettagliato si genera con `/prd` solo quando si decide di farla davvero.
