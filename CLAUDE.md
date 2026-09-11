# Mirwada — CLAUDE.md di progetto

Action-RPG 2D esplorativo con sistema di progressione a Pathway/Sequenze.
**10 Pathway attivi (4 gruppi completi), 100 Sequenze.**
Leggi questo file a inizio di ogni sessione, poi `progress.txt` e `prd.json`.

---

## Le tre regole che non si negoziano

### 1. I dati non sono codice

Il codice implementa **primitive**. I dati compongono **abilità**.

- Il registro delle primitive in `data/schema/primitives.json` è **chiuso**:
  28 attive + 3 differite. Usare una primitiva differita fa fallire il
  validator: è codice che nessun Pathway attivo richiede. Se un'abilità sembra richiederne una nuova, quasi sempre significa
  che una primitiva esistente è sottoparametrizzata. Parametrizza quella.
  Aggiungere una primitiva richiede una discussione esplicita con l'utente.
- Il vocabolario degli eventi in `data/schema/tracked_events.json` è **chiuso**:
  12 voci. Le azioni di recitazione sono contatori su questi eventi, mai azioni
  descritte a parole. Un evento nuovo è **codice**: va discusso.
- Il vocabolario dei tag in `data/tags.json` è **chiuso**. Serve a impedire
  che `fiamma` e `fuoco` coesistano rompendo silenziosamente le sinergie.
- Nessun nome di Pathway o Sequenza hardcoded in script o UI. Solo id e chiavi
  i18n. Motivo: il flag `SERIAL_NUMBERS_FILED_OFF` deve poter rinominare tutto
  sostituendo file di dati, mai toccando codice.

**Se ti trovi a scrivere una `if` per un caso specifico di un Pathway, fermati.**
Quasi certamente è un dato mancante, non un caso speciale.

### 2. Ponytail

Diff minimo che funziona. Riusa i pattern già presenti nel codebase. Nessuna
astrazione non richiesta. Se una story si chiude aggiungendo una riga a un
JSON invece che una classe, si aggiunge la riga al JSON.

### 3. Una story, una iterazione

Ogni story deve chiudersi in una context window. Se ne tocchi più di ~4 file o
superi ~200 righe di diff, la story era troppo grande: segnalalo e proponi di
spezzarla invece di tirare dritto.

---

## Comandi

```bash
# Validazione dei dati — DEVE uscire 0 prima di ogni commit
python tools/validate_data.py

# Rigenera i 324 frame placeholder da data/animations.json
python tools/generate_placeholders.py

# Rigenera la spina dorsale dei pathway (idempotente, preserva il lavoro fatto)
python tools/generate_pathways.py

# Test headless — esce 0 se tutto passa
godot --headless --path . --script res://tests/run_tests.gd
```

## Struttura

```
006_PRD/          PRD per fase + roadmap
data/
  schema/         schemi JSON, registro chiuso delle primitive,
                  vocabolario chiuso dei 12 eventi tracciabili
  pathways/       10 file, 100 sequenze — la spina dorsale
  pathways_deferred/  12 pathway fuori scope, completi. NON cancellati.
  abilities/      abilità composte dalle primitive
  synergies/      regole di sinergia data-driven
  tags.json       vocabolario chiuso dei tag
tools/            generatore e validator
scenes/ scripts/ assets/ tests/    (creati in fase 1)
prd.json          story della fase corrente per ralph
progress.txt      memoria tra le iterazioni
```

## Definition of done di ogni story

- [ ] typecheck/lint passa
- [ ] test headless passano (esistenti + nuovi)
- [ ] `python tools/validate_data.py` esce 0
- [ ] nessuna regressione sulle story precedenti
- [ ] story con UI/gameplay: verifica a schermo documentata in `progress.txt`
- [ ] `progress.txt` aggiornato con cosa fatto, come verificato, cosa resta aperto
- [ ] `prd.json`: story a `"passes": true` con `notes` compilate
- [ ] commit dei soli file toccati, messaggio `US-NNN: <cosa>`

## Fasi

Fase 1 — Fondamenta: **CHIUSA** (27 story, 112 test, CI). PRD storico in
`006_PRD/prd-fase-1-fondamenta.md`.

Fase 2 — Pathway Core: **CHIUSA** (35 story, 318 test). PRD in
`006_PRD/prd-fase-2-pathway-core.md`. Criterio di uscita verificato in US-219:
il Twilight Giant va dalla Sequenza 9 alla 5 con zero codice dedicato
(verdetto in `progress.txt`). Include: motore Pathway/Sequenza, Acting Method
+ EventTracker, Follia (audio + VFX + Ancore), pozioni e rituali, i18n reale
(`data/i18n/`, `tr_data`), shell del libro (ogni schermata e' una pagina:
scaffale, frontespizio, diagramma con fog of war, colophon/impostazioni),
`data/vfx.json` + renderer VFX per primitiva.

Fase 3 — Sistemi di supporto: **CHIUSA** (35 story US-301..336, 498 test).
PRD in `006_PRD/prd-fase-3-sistemi-di-supporto.md`. 8 blocchi: inventario/
equip, alchimia, forgiatura/sigilli, strutture, pet, base building, talenti,
integrazione. Save da schema_version 12 a 19. Verdetto sull'architettura
verificato in US-335 (`tests/test_slice_fase_3.gd`): coltivazione, alchimia,
forgia, sigilli, pet, talenti e sinergie compongono un ciclo completo con
**zero righe di codice dedicate a un contenuto specifico**. Vocabolari chiusi
nuovi: `item_categories`, `equip_slots`, `room_types`, `tracked_talents`
(distinto dai 12 `tracked_events`, invariati), effetti dei sigilli,
`experiment_outcomes`. Nessuna primitiva nuova. Fonti di tag per la fase 4:
`SynergySources.tag_sinergia_globali()` (inventario + pet + talenti + stanze).

Fase 4 — Sinergie: **CHIUSA** (16 story US-401..416, 535 test). PRD in
`006_PRD/prd-fase-4-sinergie.md`. 3 blocchi: A il motore (`SynergyEngine`
autoload, i 6 tipi di effetto, priorità/conflitti, anti-sinergie con
`neutralizza`, save 19 → 20), B il registro nel libro (sezione della pagina
inventario col fog of war, reattiva dal vivo), C il contenuto (44 sinergie
di cui 26 raggiungibili; `batch_3.json` punta ai gruppi differiti;
`sinergia_colpo_del_caso` scritta). Criterio di uscita verificato in
`tests/test_slice_fase_4.gd`: `sinergia_dottrina_del_guardiano` si attiva solo
combinando pet + stanza + talento, con zero codice dedicato. Nessuna primitiva
nuova. `synergy.schema.json` esteso (`priorita`, `effetto` oneOf, `neutralizza`).

Fase 5 — Espansione contenuti: **CHIUSA** (22 story US-501..522, 570 test).
PRD in `006_PRD/prd-fase-5-espansione-contenuti.md`. 6 blocchi: 0 fondamenta
(`location_tags.json`, matrice di proprietà nel validator, `darkness_1` senza
`probability_shift`, acting = 1.0), 1 Death + **checkpoint**, 2 Moon, 3 Mother,
4 Paragon, 5 Hermit, 6 chiusura. **5 Pathway nuovi completi** (Death, Moon,
Mother, Paragon, Hermit, 10/10 Sequenze). **7 primitive implementate** (fear,
reveal_info, teleport, soul_detach, resurrect, plant_growth, mind_read).
`paragon_1`/`hermit_1` riscritte senza `rule_bind`. Save invariato.

**Il punto di controllo è stato superato (US-508)**: `test_slice_fase_5.gd`
gioca Death Seq 8→2 in codice con zero righe che nominano "death"; il `git diff`
del blocco tocca solo 5 handler `_p_<primitiva>` + `player.teleport_verso`,
`AbilityEngine.execute` intatto. L'architettura della fase 2 regge oltre il
Twilight Giant.

Fase 6 — Mondo: **CHIUSA** (22 story US-601..622 + US-613b/US-616b, 669 test).
PRD in `006_PRD/prd-fase-6-mondo.md`. 9 blocchi (A regioni, B condizioni del
tempo, C Darkness, D gating, E NPC, F dialoghi, G fazioni + quest, H mappa +
densità + audio, I narrativa + chiusura). Save `schema_version` **20 → 21**
(US-602, l'unico bump: tempo/npc/reputazione/quest/flag stanno tutti nel campo
`mondo` senza bumpare). 5 regioni giocabili data-driven; `TimeSystem`
(giorno/notte + fasi lunari) che fa valere `e_notte`/`fase_lunare`/`in_zona_tag`
delle abilità (`Conditions` condiviso da AbilityEngine e DialogueEngine);
**Darkness completo 10/10** + `shadow_meld`/`illusion` (fase 5b interlacciata);
`AreaGate` che applica `regions.json.gating[]` (6 modi); 8 NPC + `DialogueEngine`
+ i 9 grafi; `FactionSystem` (comportamenti automatici dai dati);
`QuestSystem` (lettore di eventi + flag, zero verbi nuovi) + 4 quest di Atto I +
Journal; pagina mappa (fog of war, fast travel = potere); densità mistica;
audio del mondo come **spec** (nessun file audio prodotto);
`data/lore/antagonisti.json` (antagonista strutturale per Pathway). Vocabolari
chiusi nuovi: `gate_types.json` (6), effetti dialoghi (6), effetti quest (5),
livelli di reputazione. Schema nuovi: `npc`/`dialogue`/`quest`/`faction`/`region`.

Fase 5b — Lord of Mysteries: **CHIUSA** (12 story US-5B01..5B12, 713 test).
PRD in `006_PRD/prd-fase-5b-lord-of-mysteries.md`. 4 blocchi (A Error +
checkpoint, B Fool, C Door, D chiusura). Save `schema_version` **invariato**.
**Fool, Error, Door completi 10/10** → con Darkness (chiuso in fase 6) e i 19
già fatti: **22/22 Pathway attivi completi, 100/100 Sequenze non-stub**.
3 primitive implementate: `steal` (categoria oggetto/abilita/conoscenza,
+param `ability_id`/`non_sottrae`), `possess` (status `posseduto`, record
`corpo_a_terra` come `soul_detach`), `time_rewind` (ring buffer di snapshot
per-caster in `AbilityEngine`, non tocca il save). `illusion`/`shadow_meld`
erano già di fase 6; `_p_illusion` esteso (`potenza` per-`tipo_illusione`).
`chain` resta senza handler (nessuna Sequenza attiva lo richiede).
`fool_2` riscritta senza `probability_shift` (grep di `data/abilities/` per
una primitiva differita come `tipo` → **0**). Materia prima `avatar` nuova in
`ownership.json` (Error: avatar autonomi; Fool: `illusion`). `batch_5.json`:
6 sinergie del gruppo + `anti_due_bugiardi`. Criterio di uscita verificato in
`tests/test_slice_fase_5b.gd` (Error 8→2, zero codice che nomina "error";
diff `.gd` del blocco A = solo `ability_engine.gd` +173 -0, dispatcher
intatto) e nel validator (check di chiusura fase 5b).

Fase 7 — Endgame: **CHIUSA** (21 story US-701..721, 776 test). PRD in
`006_PRD/prd-fase-7-endgame.md`. 5 blocchi (0 fondamenta, A cambio Pathway +
fusione, B tribolazioni, C Sequenze alte/preghiere + siti rituali, D finali +
eredità, E checkpoint + chiusura). Save `schema_version` **21 → 22**
(US-701, l'unico bump: cambio Pathway, fusioni, tribolazioni superate,
eredità, finale stanno tutti nel campo `endgame`). Include: `PathwayChange`
(cambio solo tra vicini dello stesso gruppo) + `FusionEngine` (1 percorso
completo `error_door`, 7 stub dichiarati per la fase 7b); `TribulationSystem`
(lettore di eventi/flag, blocca `Progression.avanza` ai 4 salti di fascia);
6 abilità di "preghiera" sulle Sequenze alte (campo puramente semantico) +
4 siti rituali di Sequenza 0 condivisi per gruppo; `data/endings.json` (3
finali) + `EndingSystem` (nessun tipo di condizione nuovo, la Consumazione
È il game over per follia); schermata di finale che estende il colophon
(nessun tipo di pagina nuovo); eredità al personaggio successivo (tutte e
quattro le voci, scelte dal giocatore, riapplicate a un nuovo personaggio
sullo stesso slot); fog of war sui nomi di Sequenza nel diagramma (richiesta
utente in corsa: si conosce al più il nome della Sequenza successiva).

**Verdetto del checkpoint (US-720)**: `test_slice_fase_7.gd` fa attraversare
a un personaggio l'intero ciclo — cambio Pathway con fusione, una
tribolazione superata, un finale raggiunto, l'eredità riapplicata a un
nuovo personaggio — con zero righe di codice che nominino un Pathway, una
coppia di fusione, una tribolazione o un finale specifico.
`scripts/ability_engine.gd` non è stato toccato in tutta la fase.

Fase 8 — Vertical slice giocabile: **CHIUSA** (19 story US-801..US-806,
US-807a..d, US-808, US-809a..c, US-810..US-814, 850 test). PRD in
`006_PRD/prd-fase-8-vertical-slice.md`; istruzioni operative in
`006_PRD/prossimi-passi.md`. Le fasi 1-7 avevano costruito tutti i sistemi
ma nessuno poteva giocare il gioco con la tastiera: `main.tscn` era rimasta
la scena di prova della fase 1. La fase 8 ha collegato i sistemi già
scritti, riempito i dati mancanti e messo una grafica provvisoria generata
(**zero sistemi nuovi**, save `schema_version` **invariato**). 7 blocchi:
0 avvio + controlli (`GameState.nuova_partita` con scelta del Pathway,
abilità a tastiera + hotbar, proiettili/mischia che colpiscono davvero),
A recitazione (payload veri di `enemy_defeated`/`item_crafted`/
`ritual_completed`/`area_cleared`), B mondo (5 layout ASCII disegnati a
mano in `data/world/layouts/`, nemici/boss/oggetti dai dati), C economia
(i 307 ingredienti delle formule diventano oggetti via
`tools/generate_formula_ingredients.py`, US-808, con fonti nel mondo:
drop/listini/raccolta, US-809a..c), D pagine del libro (Prepara/Bevi nel
diagramma, negozio compra/vendi nel dialogo), E grafica (`tools/
generate_sprites.py`: pixel art procedurale deterministica per personaggio/
nemico/pet/NPC/oggetti/tileset, 23 fogli — 19 animazioni + npc_popolano/
oggetti/passaggio/gate —, `tools/build_tileset.gd` per il TileSet a righe-
per-palette), F verifica giocata end-to-end + chiusura.

**Verdetto** (US-814, `tests/manual/qa_vslice.gd` + `tests/
test_slice_fase_8.gd`): una partita giocata per davvero con Xvfb — scaffale
→ creazione con Pathway scelto da `pathway_ids()` → cammina e raccoglie
oggetti col tasto vero → lancia un'abilità col tasto vero → uccide un boss
a colpi di mischia (segnale `morto` + evento tracciato `enemy_defeated`
con payload reale) → compra da un NPC → prepara e beve una pozione (
`Progression.sequence()` 9 → 8) → attraversa un passaggio verso una
regione con un layout diverso — con zero righe di codice che nominino un
Pathway, una regione, un NPC o una formula specifici (checkpoint dinamico:
la lista vietata è letta da `GameData.pathway_ids()` +
`data/world/regions.json` + `data/npc/roster.json` +
`data/potions/formulas.json`, non scritta a mano).

Fase 9 — Pathway Non-Standard: **CHIUSA** (7 story US-901..US-907, 884
test). PRD in `006_PRD/prd-fase-9-pathway-non-standard.md`. Le fasi 1-8
avevano un solo sistema di progressione (Sequenza 9→0, Caratteristica +
formula + concoct + recitazione + bevi). Il materiale di riferimento ha
anche Pathway "Non-Standard" (bestower come Eternal Aeon) che avanzano
ricevendo **Boon** da un'entità, non bevendo pozioni. 4 blocchi: 0
fondamenta (`categoria: "standard"|"non_standard"` su ogni Pathway,
`data/schema/boon.schema.json`, `BoonSystem` autoload — legge solo il
campo `boon` della Sequenza corrente, stesso principio di `PotionSystem`
—, guardie in `PathwayChange`/`FusionEngine` contro un Pathway
non_standard), A contenuto (**Eternal Aeon completo 10/10 Sequenze**,
10 abilità dalle primitive attive esistenti, nessuna nuova), B libro
(sezione "Il Dono" nella pagina diagramma al posto di Prepara/Bevi,
stessa pagina — un ramo sul dato `boon` vs `potion`, mai un tipo di
pagina nuovo), C checkpoint + chiusura. Save `schema_version` **22 → 23**
(US-902, l'unico bump: il campo `boon` — solo la baseline dei requisiti
`comportamento` — accanto ad `acting`).

Un Boon è un dono **una tantum** per Sequenza: i requisiti (quest
completata / comportamento contato / sacrificio pagato, combinabili
per Sequenza, mai tutti e tre per forza) sono dati, mai codice.
`GameData.pathway_ids()` resta scoped ai soli Pathway standard (ogni
sistema che itera "ogni Pathway attivo" — VFX, diagramma, siti rituali,
i18n, gli slice — lo assume): i non_standard vivono in un registro
GameData separato (`pathway_ids_non_standard()`), usato solo dove serve
davvero (il selettore di creazione personaggio, così Eternal Aeon si
sceglie col ciclo standard, deciso con l'utente).

**Verdetto** (US-907, `tests/manual/qa_vslice_eternal_aeon.gd` +
`tests/test_fase_9_checkpoint.gd`): un personaggio Eternal Aeon creato
dal selettore vero di `page_creazione_personaggio.gd`, un Boon con
tutte e tre le fonti insieme soddisfatto e ricevuto dalla pagina
diagramma vera, `Progression.sequence()` sceso da 5 a 4 — con zero
righe di codice che nominino "eternal_aeon" o una sua Sequenza/abilità
(checkpoint dinamico, lista vietata letta da
`GameData.get_pathway("eternal_aeon")`, non scritta a mano).

Prova che l'architettura regge: `data/abilities/twilight_giant.json` (fase 2),
i 5 Pathway di fase 5, i 3 del Lord of Mysteries (fase 5b), l'intero
endgame di fase 7 e Eternal Aeon (fase 9, un secondo sistema di
progressione intero, non solo contenuto) sono motori/contenuto completi
con **zero righe di codice dedicate**. È il modello da imitare per ogni
story di dati.

Fase 10 — Mondo Continuo: **CHIUSA** (16 story US-1001..US-1014 +
US-1002B/US-1005B, 925 test). PRD in
`006_PRD/prd-fase-10-mondo-continuo.md`. Le 5 regioni, prima 5 scene
isolate con un salto ad ogni passaggio, sono diventate un'unica griglia
condivisa dipinta in una sola TileMapLayer persistente (`world_scene.gd`,
sostituisce `region_scene.gd` — ritirato insieme alle 5 `scenes/regioni/
*.tscn`, US-1002B): `world_offset` per regione (US-1001) dispone Mirwada
al centro di un anello con le 4 regioni esterne ai quattro angoli, 8
corridoi disegnati a mano collegano ogni coppia adiacente (US-1002/1006/
1007/1008/1009), il gating d'ingresso diventa per la prima volta una
barriera fisica vera invece di un rifiuto di caricamento (US-1009,
Frontiera delle Porte — il meccanismo generico esisteva gia', bastava
provarlo). Prestazioni: nemici/NPC fuori da un raggio dal giocatore si
disattivano (US-1003, `process_mode`). Il save resta invariato,
`schema_version` **23** (US-1004, la posizione nel mondo e' gia'
assoluta). Le 5 regioni sono cresciute con location_tags fisicamente
distinti, non piu' rettangoli a griglia automatica (US-1005/1006/1007/
1008/1009), e un nuovo motore data-driven per gli edifici visitabili
(US-1010: `edifici: [{x,y,interno_id}]` su un layout, un interno e' un
layout come un altro, nessuna nuova voce in `location_tags.json` — un
edificio non e' legato a un location_tag, decisione dichiarata
esplicitamente ogni volta) ha dato vita ai primi 3 edifici di Mirwada
(US-1005B), al primo villaggio vero (US-1011: l'avamposto della sorgente
in Valle della Madre, 4 capanne) e alla prima struttura grande (US-1012:
la torre d'osservazione dell'Archivio Sepolto, un interno a 3 stanze
collegate nella stessa mappa, nessuna catena di caricamenti). **Verdetto
del checkpoint (US-1013)**: `test_fase_10_checkpoint.gd` prova che zero
righe di codice del motore nominano una regione (oltre a `"mirwada"`,
l'hub per design fin dalla fase 6) o uno dei 9 interni esistenti — lista
scoperta dai dati, non scritta a mano; `tests/manual/qa_mondo_continuo.gd`
gioca la partita vera con Xvfb: cammina attraverso un confine di regione
con Input reale senza alcuna `change_scene_to_*` (solo all'avvio), entra
ed esce dal villaggio e dalla struttura grande. Nessuna primitiva/evento
nuovo.

Fase 11 — Atto II e Atto III (le regioni che si aprono, la soglia):
**PIANIFICATA**, eseguita dopo la fase 10. PRD in
`006_PRD/prd-fase-11-atto-2-3.md`. I motori di Atto II/III esistono già
dalla fase 7 (tribolazioni, rituale di Sequenza 1 con Ancora, duello di
Aldo ai salti di tier) ma sono quasi senza contenuto narrativo intorno:
questa fase scrive le quest/scene mancanti (fazioni che prendono
posizione, "Doran sa, Lena capisce, Vesna sceglie") riusando solo motori
esistenti (`QuestSystem`, `DialogueEngine`, `FactionSystem`).

Fase 12 (opzionale, non pianificata): altri Pathway Non-Standard (Chaos
Primogenitor, Scrooge, Dreamless, altri bestower), stesso schema di
Eternal Aeon — il PRD si genera con `/prd` solo quando si decide di
farla davvero. Roadmap in `006_PRD/roadmap.md`.

## Decisioni prese

- **Engine**: Godot 4.x, GDScript. Alternativa scartata: Unity 2D (più
  boilerplate per un sistema così data-driven; le Resource di Godot mappano
  meglio sul formato JSON).
- **10 Pathway invece di 22**: scelti come 4 gruppi completi, non come
  selezione dei più belli. Il cambio di Pathway (fase 7) funziona solo tra
  vicini dello stesso gruppo: gruppi a metà avrebbero rotto quel sistema.
  Motivazione completa e cosa si è perso: `006_PRD/design-pathways.md`.
  Riattivare un Pathway significa riattivare **il suo gruppo intero**.
- **Pathway della fase 2**: Twilight Giant. Il Fool è più interessante ma
  richiede `illusion` e `possess` leggibili a schermo, che sono molto più
  difficili da far funzionare bene come primo Pathway.
- **Risoluzione**: 32×32 px, base 640×360. Fissata ora perché cambiarla dopo
  significa rifare ogni asset.
- **4 direzioni, non 8**: le diagonali riusano gli sprite orizzontali. Dimezza
  i frame da disegnare, invisibile in un top-down. Stessa logica dei 32×32:
  irreversibile, quindi decisa subito.
- **Il timing del combat vive in `data/animations.json`**, non negli script.
  Frame di anticipo, attivi, recupero, iframe del dash e finestra di parata
  perfetta sono dati. Tarare il feel deve costare secondi, non ricompilazioni.
- **i18n dal giorno 1**: nessun testo hardcoded, nemmeno nei placeholder.

## i18n — due sistemi, una convenzione per le stringhe dei dati

Il gioco ha **due** cataloghi di stringhe, per scopi diversi:

1. **UI chrome** (HUD, etichette del motore): `assets/i18n/strings.csv` →
   `.translation` compilati, risolti con `tr("HUD_...")` di Godot. Chiavi in
   `SCREAMING_SNAKE`. Resta com'e'.
2. **Stringhe dei dati** (nomi di Pathway/Sequenza/abilita', descrizioni delle
   azioni di recitazione, Ancore, Caratteristiche, forme, sinergie):
   `data/i18n/it.json` + `data/i18n/en.json`, risolti con
   `GameData.tr_data(key)`. Le chiavi sono i valori dei campi `*_i18n` sparsi
   nei file di `data/`.

**Convenzione unica delle chiavi dei dati** (`US-220`), una sola forma:

```
<categoria>[.<pathway_id>].<local>
```

- `categoria`: `pathway` | `sequence` | `ability` | `acting` |
  `characteristic` | `form` | `anchor` | `synergy`
- `<pathway_id>` è presente per le entità che appartengono a un Pathway
  (`sequence`, `ability`, `acting`, `characteristic`, `form`); **assente** per
  le entità globali (`anchor`, `synergy`) e per `pathway` stesso
- `local`: l'`id` dell'entità verbatim; il **numero** per `sequence` e
  `characteristic`; per `pathway` è l'id del Pathway. Per `anchor`/`synergy`
  si toglie il prefisso di tipo ridondante (`anchor_mirco` → `anchor.mirco`).

Esempi: `pathway.twilight_giant`, `sequence.twilight_giant.9`,
`ability.twilight_giant.tg_fendente_pesante`,
`acting.twilight_giant.tg_9_duello_puro`, `anchor.mirco`,
`synergy.inganno_probabilita`.

`tools/generate_i18n_stubs.py` scandisce `data/` (esclusi `schema/`, `i18n/`,
`pathways_deferred/`), **riscrive** le chiavi non canoniche nei file di dati,
e rigenera i due cataloghi: le traduzioni autoriali si preservano, le chiavi
nuove partono da un eventuale testo in chiaro già nei dati (campo gemello
`name`/`descrizione`) o da uno stub `TODO <chiave>`. Il validator (`R-12`)
dà **errore** se una chiave `*_i18n` dei dati attivi non ha voce in `it.json`.
Riattivi un gruppo differito → rilancia il tool e traduci i nuovi stub.

## Fog of war sulla conoscenza — nomi di Sequenza

Ogni Sequenza di ogni Pathway ha gia' un nome canonico proprio e distinto
(campo `name` di ogni voce in `data/pathways/*.json`: 100 nomi diversi,
nessuna fascia condivide un nome generico — es. Twilight Giant 9=Warrior,
8=Pugilist, ... 0=Twilight Giant). Verificato riga per riga su tutti i 10
Pathway attivi (2026-09-09): i dati sono gia' corretti, non serve toccarli.

Il giocatore non deve MAI conoscere in anticipo il nome di una Sequenza non
ancora raggiunta. Unica eccezione: puo' conoscere il nome della Sequenza
**immediatamente successiva** alla propria sul **proprio** Pathway (un
presagio/indiscrezione) — mai il nome, ne' altro, di Sequenze piu' lontane,
ne' quello di Sequenze di altri Pathway (a meno di un flag esplicito in
KnowledgeStore, gia' previsto dal fog of war esistente). La pagina diagramma
del libro (`scripts/pages/page_diagramma_pathway.gd`, fase 2 US-224) applica
il fog of war sulle celle della griglia (colonna propria fino alla Sequenza
corrente = nota, il resto ignoto salvo flag) ma oggi non renderizza nomi di
Sequenza da nessuna parte nella griglia; l'eccezione della Sequenza
successiva (solo nome, mai abilita' o altri dettagli) e' da implementare.

## Non-goals

Multiplayer, 3D, generazione procedurale del mondo, monetizzazione,
**doppiaggio**, mondo aperto senza gating, console port.

L'audio NON e' un non-goal: e' un canale informativo del gioco (tell sonori,
sussurri della follia, percezione per Sequenza) e ha il suo sistema
data-driven in `data/audio.json`. Il doppiaggio si', quello resta fuori.

## Repo

https://github.com/YasserOudabashi/mirwada (pubblica)

Repo dedicata a questo progetto, aggiunta alla tabella "Repository che uso"
in ~/.claude/CLAUDE.md come prescrive quel file per ogni repo nuova.
`Mirwada` è il nome del gioco; `Sequenza`/`Sequenze` nel resto dei documenti
resta il termine di gameplay (lo scalino di progressione), non il titolo.
Percorso locale: `D:\005-Friend\Ivan\MEgaProJect`.

## Nota IP

Il sistema di riferimento è opera protetta di terzi. Progetto personale, non
distribuibile né monetizzabile con i nomi attuali. Il flag
`SERIAL_NUMBERS_FILED_OFF` (default `false`) esiste perché la rinominazione
completa resti un'operazione da un pomeriggio: per questo i nomi vivono solo
nei dati.
