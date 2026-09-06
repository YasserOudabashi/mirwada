# Mirwada — Design Doc Master

Data: 2026-09-02. Stato di partenza: fase 1 a 6/21 story, audit completo eseguito.

---

## 0. Cosa e' questo documento, e la deroga

La roadmap (`roadmap.md`, righe 3-5) vieta di scrivere il PRD di una fase prima
che la precedente sia chiusa. Questo documento **non e' un PRD di fase**: e' il
design doc master che fissa, adesso, le cose che costano care se decise tardi —
vocabolari chiusi, contratti tra sistemi, decisioni irreversibili (la stessa
categoria di 32×32 e 4 direzioni). I PRD di fase continueranno a nascere con
`/prd` a fase precedente chiusa, **pescando da qui** i loro capitoli.

**Deroga dichiarata**: i capitoli su mondo, NPC, UI e VFX descrivono materia di
fase 2-7. Vengono scritti ora perche' 90 sequenze stub, 8 NPC gia' nominati e
zero UI progettata significano che ogni story futura inventerebbe vocabolari
propri. Meglio un vocabolario deciso oggi che tre incompatibili fra sei mesi.
Approvato dall'utente il 2026-09-02 insieme al piano di questa sessione.

Documenti figli (stesso rango di `design-pathways.md` e `design-lore.md`):

| Documento | Copre |
|---|---|
| `design-world.md` | Regioni, biomi, gating, tempo (momento/fase lunare), densita' mistica |
| `design-npc-quest.md` | NPC, dialoghi, fazioni, quest, struttura narrativa in tre atti, finali |
| `design-ui-libro.md` | La UI a libro: tutte le schermate come pagine, animazione di voltata, impostazioni |
| `design-vfx.md` | Identita' visiva delle abilita' in stile manhwa; 10 palette visive per pathway |

Le tre regole di `CLAUDE.md` valgono per ogni riga di questi documenti:
i dati non sono codice; ponytail; una story una iterazione.

---

## 1. Fotografia dello stato reale (baseline dall'audit)

Cio' che segue e' stato misurato, non stimato. Sessione di audit 2026-09-02:
tre passate parallele su codice, dati e documentazione.

- **Il gioco si avvia su una finestra nera.** Nessun player, mappa, input map,
  HUD, sistema di danno, nemico, audio, save. Le 6 story chiuse (US-001, 002,
  003, 007, 012, 013) sono tutte infrastruttura — ottima, ma invisibile.
- **5 primitive implementate su 31; i dati ne usano gia' 20.** Risultato: delle
  32 abilita' scritte, 15 erano no-op complete a runtime, 9 parziali, 8 intere.
  La prova "twilight_giant con zero codice dedicato" regge come prova di
  *composizione*; il grosso del codice delle primitive resta da scrivere, e il
  punto di controllo della fase 5 va guardato gia' dalla fase 2.
- **90 sequenze su 100 erano gusci vuoti che il validator dichiarava validi.**
  Da questa sessione sono stub *dichiarati* (`"stub": true`, 89 dopo il
  completamento di fool_9) e il validator li conta ed esenta esplicitamente.
- **i18n non esiste ancora** (~250 chiavi `*_i18n` puntano nel vuoto, tre
  convenzioni di naming divergenti), nonostante "i18n dal giorno 1".
- L'architettura dati regge: registro primitive chiuso (28+3), 12 eventi, 82
  tag, dispatch a tabella senza un solo `if` per pathway in `scripts/`.

### Risanato in questa sessione (commit `fix: risanamento dati e motore`)

| Problema | Fix |
|---|---|
| `melee_arc` mai liberato: un Area2D permanente sul caster a ogni attacco | vita di 0.25 s + `queue_free()`; test |
| `heal` ignorava il param `bersaglio` | onorato; bersaglio non risolvibile non cura il caster; test |
| `tag_danno` stringa nei dati, `Array` negli script: crash al primo attacco reale | contratto fissato a stringa + vocabolario chiuso `damage_tags.json` |
| tag `fisico` usato in 8 punti ma fuori da ogni vocabolario | `data/schema/damage_tags.json` (8 voci), validato ovunque |
| filtro `sequenza_min` semanticamente invertito (0 = piu' forte) | rinominato `sequenza_bersaglio_max` prima che diventasse codice |
| `moon_phase` mescolava momenti del giorno e fasi lunari | `data/schema/time.json`: assi separati `momento` / `fase_lunare` |
| sequenze vuote invisibili al validator | flag `stub` esplicito; non-stub esigono acting_actions e `madness_on_force > 0` |
| parametri primitive mai validati ("danno silenzioso a zero") | validati contro il registro; pescato subito `tag_danno: "crescita"` in mother |
| registro: param `tipo` collidenti, `bersaglio` non dichiarato su shield | rinominati `tipo_illusione`/`tipo_modifica`/`tipo_meteo`; `bersaglio` aggiunto |
| sinergia che produce un'abilita' inesistente | errore del validator (stub esente); `sinergia_inganno_probabilita` marcata stub |
| sinergie irraggiungibili coi pathway attivi | warning automatico del validator |
| foundation senza floor (poteva andare a -200) | `minimo: 0` in balance.json |
| `generate_pathways.py` perdeva i campi falsy nel merge; docstring 22/220 stale | merge "il vecchio vince sempre"; docstring corretta; doppia rigenerazione verificata idempotente |

### Aperto, tracciato come story (Appendice A)

Robustezza `typeof` sul caricamento JSON (oggi un JSON strutturalmente sbagliato
crasha invece di produrre un errore gestito), purge di `_cooldowns` e degli
indici su reload, save system (capitolo 3), i18n (story R-12), riscrittura di
`darkness_1`, stats di partenza hardcoded in `stats_component.gd`, test fragili
sui conteggi, CI, nomi dei 22 pathway in sorgente Python dentro
`generate_pathways.py` (contro la nota IP: story R-13).

---

## 2. Visione e principi trasversali

Action-RPG 2D esplorativo. Dieci pathway, dieci verbi, quattro gruppi completi
(tabella in `design-pathways.md`). Mondo **interconnesso e gated**, mai "open
world" (non-goal esplicito): 4-6 regioni disegnate a mano dove l'accesso e il
segreto si pagano in primitive, conoscenza, relazioni e tempo.

Tre principi che ogni capitolo di questi documenti applica:

1. **Ogni sistema nuovo e' un file di dati + uno schema + un check del
   validator.** Mai una classe speciale. Se una proposta non sa dire quale JSON
   crea, non e' pronta.
2. **L'identita' di un pathway viaggia su tre canali paralleli**: timbrica
   (`audio.json.pathway_palette`, esiste), visiva (`data/vfx.json`,
   `design-vfx.md`), spaziale (le regioni, `design-world.md`). Stessa chiave
   (`twilight_giant`, `fool`, ...) su tutti e tre: un pathway si riconosce a
   orecchie chiuse, a occhi chiusi, e dalla terra su cui cammini.
3. **i18n e `SERIAL_NUMBERS_FILED_OFF` sempre**: id neutri, nomi solo da chiavi
   i18n, la rinominazione completa resta un pomeriggio.

---

## 3. Sicurezza e robustezza

E' un gioco single-player: la sicurezza che conta e' integrita' del
salvataggio, robustezza ai dati corrotti, mod-safety. L'audit sulla superficie
classica e' pulito (nessun `Expression`/`eval`/`OS.execute`, nessun path
traversal, `load()` mai su input esterno).

### 3.1 Save system (vincola US-015 — criteri aggiunti in prd.json)

- **Formato**: JSON in chiaro in `user://saves/slot_N.json`. In chiaro di
  proposito: manomettibile per definizione = mod-friendly, e il caricamento
  deve reggere comunque (punto 3).
- **Scrittura atomica**: si scrive su `slot_N.json.tmp`, flush, poi rename sul
  definitivo. Un crash a meta' scrittura non deve mai lasciare l'unico save
  corrotto.
- **Solo `JSON.parse_string`**. MAI `bytes_to_var` con `allow_objects`, mai
  `ResourceLoader` su un file di save: in Godot sono vettori di esecuzione di
  codice arbitrario da file manomesso.
- **Ogni campo e' non fidato**: al load, ogni valore passa da un check
  `typeof()` con default sano; un campo assente o del tipo sbagliato produce un
  errore *gestito* e mai un crash. Slot corrotto = messaggio al giocatore e
  slot ignorato, mai wipe silenzioso.
- **`schema_version` con catena di migrazioni**: da N a N+1 con funzioni
  esplicite; versione piu' nuova del gioco = rifiuto gentile.
- **Cosa si serializza** (si estende per fase): posizione, statistiche, tempo
  di gioco, nome del personaggio (design-lore), pathway/sequenza/tier,
  follia/foundation/acting (fase 2), evocazioni `summon durata -1`
  (design-pathways lo esige gia'), inventario (fase 3), stato del mondo —
  `terrain_modify permanente`, strutture, reputazioni, quest, NPC (fase 6).

### 3.2 Dati di gioco non fidati (story R-11)

I JSON di `data/` finiscono in chiaro nell'export: chiunque li modifichi (o
qualsiasi mod) oggi ottiene un crash, perche' ~11 assegnazioni tipate in
`game_data.gd` e `ability_engine.gd` assumono la struttura giusta. Il fix e'
un loader unico con check `typeof()` che riusa il pattern gia' presente in
`_read_json` (errore registrato, `{}` di ritorno, mai silenzioso).

### 3.3 Validator come cintura di sicurezza

Chiusi in questa sessione: parametri primitive, tag di danno, stub, tempo,
sinergie (cap. 1). Restano da chiudere, ognuno con la story del sistema che lo
introduce: chiavi i18n referenziate esistenti (R-12), `location_tags` contro il
vocabolario (fase 6), palette VFX completa per ogni pathway (con
`data/vfx.json`), cross-check `sequence_id` ↔ `sequences[].abilities`,
`data/pathways_deferred/` letta almeno in modalita' warning, `balance.json`
validato, `EXPECTED_PATHWAYS`/`GROUP_SIZES` letti dai dati invece che
hardcoded.

---

## 4. Contenuto: riempire gli 89 stub e sciogliere le sovrapposizioni

Le linee guida complete per scrivere i 9 pathway restanti sono il modello
`twilight_giant`: trade-off espliciti nelle abilita' alte, recitazione che
*accetta la natura del potere* (il TG di Sequenza 2 lascia decadere una propria
struttura), `madness_on_force` crescente, rituali che mettono in gioco le
Ancore. Prima di scrivere una sola sequenza nuova, pero', vanno fissate le
proprieta': l'audit ha trovato quattro sovrapposizioni reali.

### Matrice di proprieta' (decisione di design, vale da ora)

| Meccanica | Proprietario | Gli altri |
|---|---|---|
| **Mondo spirituale** | **Death** ci *abita*: i suoi passaggi (death_5) sono porte vere, permanenza, esplorazione | Door lo *attraversa* (door_5): scorciatoie istantanee tra punti noti, mai permanenza. Riposizionamento, non dominio |
| **Copia/furto di abilita'** | **Error** *ruba* (error_6: la prende al nemico, uso singolo, il nemico ne resta privo) | Door *registra e riproduce* (door_6/door_2: fotocopia, l'originale resta); Fool *finge* (illusioni di poteri, danno percepito). Tre sapori: sottrazione, replica, finzione |
| **Evocazioni permanenti** | Quattro fonti, quattro materie prime | Death: cadaveri (serve un morto); Paragon: costrutti (serve crafting); Moon: IL pet (unico, con `bond`); Mother: chimere (servono ingredienti vivi). Il validator di fase 5 controlla che `entita_id` dichiari la fonte |
| **Occultamento** | **Darkness** e' invisibilita' *percettiva* (cancella dalla mente: darkness_2) | Door e' invisibilita' *spaziale* (non sei qui: door_4). Contro un cieco funziona solo Door; contro un sigillo di area funziona solo Darkness |
| **Sogni** | **Darkness** (tag root `sonno`): l'incubo come arma | Error entra nei sogni *per rubare* (error_5), non per combattere. Il tag `sogno` di tags.json resta orfano finche' Visionary e' differito: NON usarlo nei pathway attivi |
| **Divinazione** | **Hermit** e' il divinatore sistemico (hermit_9/3) | Fool divina *per ingannare* (mostra il tell), Door divina *lo spazio* (percorsi), Paragon *misura* (strumenti). Ogni abilita' di divinazione fuori da Hermit deve rivelare solo la categoria del suo verbo |

### darkness_1 senza `probability_shift` (raccomandazione)

Il concept ("sfortuna cronica: i nemici falliscono, inciampano, si feriscono da
soli") puntava dritto alla primitiva differita. Riscrittura con primitive
attive: la sfortuna e' `curse` (effetto `sfortuna`, condizione_rimozione) +
stack di `debuff_stat` su evasione/precisione + `dot` basso a tag `follia`.
Il risultato percepito e' identico; la manipolazione *vera* di probabilita'
resta a Wheel of Fortune. Se in fase 5 il feel non basta, riattivare
`probability_shift` = riattivare il gruppo `key_of_light`: discussione
esplicita, come da regola.

### Il surplus delle acting_actions (warning del validator)

Cinque sequenze del TG sommano 1.05-1.15. Oggi nessuna azione e' davvero
saltabile, ma il surplus non e' mai stato *deciso*. Regola da fase 5: somma
esattamente 1.0, tranne dove il design vuole esplicitamente rendere opzionale
un'azione (e allora lo dice in `notes`).

---

## 5. Contratti dati dei sistemi promessi

Questi sistemi restano ai PRD delle loro fasi. Qui vive solo il **contratto**
che i capitoli precedenti gia' presuppongono — il minimo per non scrivere dati
che poi si contraddicono.

- **Ancora** (fase 2): entita' con `id` (`anchor_mirco`, ...), riferita da un
  NPC (`design-npc-quest.md`), dai sacrifici rituali (`ancora_del_giocatore`),
  dai sussurri di follia soglia 55 (audio.json usa i suoi nomi) e da
  `riduzione_max_ancore` in balance.json. Distruttibile; la sua perdita e' un
  evento di follia.
- **Oggetto con abilita'** (fase 3): campo `stored_ability_id` su un oggetto
  d'inventario (la pergamena dell'Hermit e' l'esempio canonico, gia' annotato
  in `data/abilities/hermit.json`). Il motore esegue un'abilita' *non
  posseduta*: capability gia' richiesta da design-pathways.
- **Struttura** (fase 3): entita' costruita con `id`, hp, tag; la sua perdita
  emette `structure_destroyed` (evento gia' nel vocabolario, usato da tg_2);
  `tg_crepuscolo` con `colpisce_oggetti: true` deve poterla danneggiare.
- **Valuta** (fase 3/6): un oggetto d'inventario a tutti gli effetti
  (`item_id: "moneta_..."`), mai un campo speciale del giocatore. Sidon e i
  listini (`design-npc-quest.md`) contano oggetti.
- **Conoscenza** (fase 6): flag booleani namespaced (`testi_ordine_minore`,
  ...) guadagnati da dialoghi, libri, sinergie con `scoperta: "lore"`. Sono la
  moneta del gating dell'Archivio Sepolto e del fog of war del diagramma
  pathway.
- **Fonti di `richiede_tag`** (fase 4): il motore delle sinergie compone i tag
  attivi da cinque sorgenti, ognuna con `tag_attivi() -> {tag: conteggio}` di
  sola lettura — `Inventory` (equip indossato + sigilli incastonati, US-306),
  `PetSystem` (specie + comportamenti sbloccati), `TalentSystem` (`tag_grant`
  dei talenti posseduti), `BaseSystem` (stanze costruite). `SynergySources.tag_sinergia_globali()`
  (US-334) le somma; nessuna di esse conosce le sinergie.

---

## Appendice A — Story per fase

Priorita': P0 blocca altro o e' un bug attivo; P1 necessaria alla fase;
P2 migliorativa. Ogni story ≤4 file / ≤200 righe di diff.

### Fase 1 — risanamento residuo (aggiunte a prd.json come US-022..US-026)

| id | P | Story |
|---|---|---|
| US-022 | P0 | Loader JSON con `typeof()` su ogni struttura attesa (game_data + ability_engine): dati corrotti = errore gestito, mai crash |
| US-023 | P1 | Purge: `_cooldowns` dei caster morti; `load_all()` che svuota gli indici prima di ricaricare (id rinominati non restano in memoria) |
| US-024 | P1 | Stats di partenza da balance.json anche per velocita'/difesa/evasione (oggi hardcoded in stats_component.gd:55-57, contro la regola dichiarata nel file stesso); segnale `spiritualita_changed` |
| US-025 | P1 | Test onesti: asserire `mancanti` in test_game_data (var morta), eseguire davvero il ramo "fuori registro", conteggi letti dai dati invece dei numeri magici 24/32/82, runner che fallisce con 0 test scoperti |
| US-026 | P2 | CI minima (GitHub Actions): validate_data.py + test headless su push |

US-015 (save) resta la story esistente, con i criteri arricchiti dal cap. 3.1.

### Fase 2 — dal PRD di fase 2, quando si genera

P0: riscrittura dati `darkness_1` (cap. 4). P1: shell del libro (controller +
voltata + `data/ui/book.json`; 2 story), pagina frontespizio/creazione
personaggio (nome nel save), pagina diagramma pathway con fog of war (promessa
di roadmap), pagina colophon/impostazioni (le 6 opzioni accessibilita' di
audio.json + video/input), `data/vfx.json` + palette (1 story dati),
VFX delle primitive di fase 2 con impact frames (2-3 story), R-12 i18n
(`tools/generate_i18n_stubs.py` + `data/i18n/it.json` + check validator).
P2: macchie di follia sulle pagine (con toggle).

### Fase 3

P1: pagina inventario del libro. P0: contratto `stored_ability_id`.

### Fase 4

P1: pagina registro sinergie; scrivere `sinergia_colpo_del_caso` e togliere lo
stub alla sinergia firma.

### Fase 5 — contenuto pathway

P0: matrice di proprieta' (cap. 4) applicata PRIMA di riempire gli stub.
P1: 9 pathway × 3 story ciascuno (Seq 9-7, 6-4, 3-0 — una story unica
sforerebbe il limite delle 200 righe: il file abilities del TG da solo e' ~600).
P1: VFX delle primitive man mano che si implementano. P2: R-13 — spostare le
tabelle nomi di `generate_pathways.py` in un file dati (nota IP).

### Fase 6 — mondo (da `design-world.md` e `design-npc-quest.md`)

P0: `location_tags.json` + `regions.json` + schema + validator (anticipabili a
fase 5: servono ai rituali). P1: una story dati + una story scena per regione;
`npc/roster.json` + schema; motore dialoghi (1-2 story) + un file dialogo per
NPC (8 story piccole); motore quest su EventTracker (1-2 story) + quest di
Atto I; `factions.json` + reputazione; pagina mappa del libro (doppia pagina).
P2: zone musica per le 4 regioni nuove in audio.json.

### Fase 7 — endgame

P1: `data/endings.json` (finali come dati, condizioni dal vocabolario
condizioni); eredita' al personaggio successivo (contratto nel save — decisione
aperta n. 8); siti rituali di Sequenza 0 per i 9 pathway (aggiunte versionate a
location_tags).

---

## Appendice B — Decisioni aperte (con raccomandazione)

1. **Nomi delle regioni** — provvisori in `design-world.md`. Raccomandazione:
   la citta' si chiama Mirwada come il gioco (il titolo e' un luogo).
2. **Libro diegetico** — "il libro E' il salvataggio" + macchie di follia sulle
   pagine. Raccomandato si' (design-ui-libro.md, cap. 2).
3. **`damage_tags` a 8 voci** — applicato in questa sessione (fisico, luce,
   ombra, decadimento, spirito, fuoco, veleno, follia). `fuoco` e' presente in
   vista di Red Priest; se resta inutilizzato a fine fase 5, si rimuove.
4. **darkness_1** — riscrittura curse/debuff raccomandata (cap. 4);
   l'alternativa riattiva un gruppo differito intero.
5. **Matrice di proprieta'** — raccomandata come scritta (cap. 4).
6. **Roster NPC** — tenere tutti e 8 (Mirco e Sidon richiesti; gli altri 6
   coprono esattamente i sistemi: 3 Ancore, gating conoscenza, gating zona,
   rivale, pressione investigativa).
7. **Story pathway di fase 5** — 3 story per pathway invece di 1 (limite 200
   righe). La roadmap va aggiornata quando si genera il PRD di fase 5.
8. **Eredita' tra personaggi** (fase 7) — cosa passa al successivo: oggetto,
   conoscenza (fog of war del diagramma gia' scoperto), reputazione, o
   un'Ancora sopravvissuta. Da decidere col PRD di fase 7.
9. **Antagonista / detentore della Sequenza 0** — le opzioni in
   `design-npc-quest.md` cap. 5; da decidere entro il PRD di fase 6.

---

## Appendice C — Vocabolari (stato)

| Vocabolario | File | Voci | Stato |
|---|---|---|---|
| Primitive | `data/schema/primitives.json` | 28 attive + 3 differite | chiuso, parametri validati |
| Eventi tracciabili | `data/schema/tracked_events.json` | 12 | chiuso |
| Tag di sinergia | `data/tags.json` | 82 (39 usati) | chiuso |
| Tag di danno | `data/schema/damage_tags.json` | 8 | chiuso |
| Tempo | `data/schema/time.json` | 4 momenti + 5 fasi lunari | chiuso |
| Categorie di oggetto | `data/schema/item_categories.json` | 7 | chiuso, fase 3 (US-301) |
| Slot di equipaggiamento | `data/schema/equip_slots.json` | 4 slot + 3 tipi | chiuso, fase 3 (US-301) |
| Tipi di stanza + bonus ammessi | `data/schema/room_types.json` | 4 tipi | chiuso, fase 3 (US-326) |
| Comportamenti-talento | `data/schema/tracked_talents.json` | 7 | chiuso, fase 3 (US-330) — distinti dai 12 `tracked_events` |
| Effetti dei sigilli | `data/schema/sigil_effect_types.json` | effetti + effetti_collaterali | chiuso, fase 3 (US-315) |
| Effetti dei Sigillati | `data/schema/sigillato_effect_types.json` | tick + tag | chiuso, fase 3 (US-318) |
| Esiti degli esperimenti | `data/potions/experiment_outcomes.json` | 5 (pesati) | chiuso, fase 3 (US-311) |
| Location tags | `data/schema/location_tags.json` | 24 proposti | PROPOSTO in design-world.md, si crea con la prima story che li valida |
| Condizioni | `ability.schema.json` (enum) | 8 + 3 proposte | le 3 nuove (`follia_min`, `reputazione_min`, `flag`) arrivano col motore dialoghi |
| Modi di gating | `region.schema.json` proposto | primitiva, momento, fase_lunare, npc, conoscenza, sequenza | PROPOSTO in design-world.md |
