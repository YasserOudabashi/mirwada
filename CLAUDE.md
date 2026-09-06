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

Fase corrente: **4 — Sinergie** (da aprire). Scaletta in `006_PRD/roadmap.md`.
PRD dettagliato da generare con `/prd`.

Le fasi 5-8 sono in `006_PRD/roadmap.md`. Il PRD dettagliato di una fase si
genera con `/prd` **solo quando la precedente è chiusa**.

Punto di controllo del progetto: la **fase 5**. Se aggiungere i 9 Pathway
rimanenti richiede codice invece che dati, l'architettura della fase 2 va
corretta prima di proseguire.

Prova che l'architettura regge: `data/abilities/twilight_giant.json` contiene
un Pathway completo dalla Sequenza 9 alla 0 — 20 abilità — con **zero righe di
codice dedicate**. È il modello da imitare per ogni story di dati.

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

## Non-goals

Multiplayer, 3D, generazione procedurale del mondo, monetizzazione,
**doppiaggio**, mondo aperto senza gating, console port.

L'audio NON e' un non-goal: e' un canale informativo del gioco (tell sonori,
sussurri della follia, percezione per Sequenza) e ha il suo sistema
data-driven in `data/audio.json`. Il doppiaggio si', quello resta fuori.

## Repo

https://github.com/YasserOudabashi/mirwada (privata)

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
