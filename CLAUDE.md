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

Fase corrente: **2 — Pathway Core**. PRD dettagliato:
`006_PRD/prd-fase-2-pathway-core.md` (~31 story `US-2NN`). Da convertire in
`prd.json` con `/ralph`. È il salto più rischioso: il criterio di uscita è
il Twilight Giant eseguito dalla Sequenza 9 alla 5 con zero codice dedicato.

Le fasi 3-8 sono in `006_PRD/roadmap.md`. Il PRD dettagliato di una fase si
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
