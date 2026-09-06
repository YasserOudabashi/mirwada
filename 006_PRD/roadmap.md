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

## Fase 5 — Espansione contenuti (~13 story, quasi tutte di dati)

I restanti 9 Pathway. **Una story per Pathway** se l'architettura ha retto.
Se qui servono `if` speciali, la fase 2 ha sbagliato qualcosa e va corretta
prima di proseguire: e' il punto di controllo dell'intero progetto.

Ordine consigliato in `006_PRD/design-pathways.md`: Death, Moon, Mother,
Paragon, Hermit, Darkness, e per ultimi Fool / Error / Door, che richiedono
le primitive piu' difficili da rendere leggibili a schermo.

Piu' le 13 primitive attive rimanenti (28 attive totali, 3 differite).

---

## Fase 6 — Mondo (~35 story)

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

## Fase 7 — Endgame (~20 story)

- Cambio Pathway con `fusion_rules` data-driven
- Sequenze alte: autorita', seguaci, preghiere
- Unicita' della Sequenza 0: l'NPC che occupa il posto
- Tribolazioni ai salti di fascia
- Finali multipli, incluso il game over per follia con eredita' al personaggio
  successivo

---

## Fase 8 — Opzionale

Pathway Non-Standard (Eternal Aeon, Chaos Primogenitor, Scrooge, Dreamless e
gli altri bestowers). Meccanica diversa: avanzamento per **Boon** invece che
per pozione, quindi non e' solo contenuto ma un secondo sistema di
progressione. Da fare solo a fasi 1-7 chiuse.
