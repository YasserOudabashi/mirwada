# Prossimi passi — istruzioni per la prossima sessione di Claude Code

> Scritto il 2026-09-09. Leggilo **dopo** `CLAUDE.md` e **prima** di toccare
> qualunque file. Dice cosa fare, in che ordine, con quali strumenti, e le
> trappole già scoperte. Il "cosa" dettagliato è in
> `006_PRD/prd-fase-8-vertical-slice.md` (14 story, US-801..US-814).

---

## 0. Il quadro in tre righe

Le fasi 1-7 sono chiuse (776 test). **Nessuno può però giocare il gioco con
la tastiera**: `main.tscn` è una scena di prova della fase 1 (un nemico,
nessuna partita avviata, nessun tasto per le abilità, 299 ingredienti che
non esistono come oggetti). La fase 8 collega i sistemi già scritti in una
partita giocabile, riempie i dati mancanti e mette una grafica provvisoria
generata. **Zero sistemi nuovi, zero primitive/eventi/tag nuovi, save
invariato.**

---

## 1. Stato del repo (verificato il 2026-09-09)

- Branch di lavoro: `claude/mini-trailer-prompt-adq22o` (l'utente lo
  rinomina da GitHub, probabilmente in `fase-7-8`; il rename da GitHub
  conserva la PR). Contiene la **chiusura della fase 7** (US-714..721) +
  questo PRD.
- **PR #3** aperta (draft) su quel branch → `main`:
  https://github.com/YasserOudabashi/mirwada/pull/3. `mergeable_state:
  clean` all'ultima verifica.
- `main` è fermo a `9ee3ded` (US-713): la fase 7 **non è ancora in main**.
- Branch `claude/map-creation-resources-g0g7d5`: stantio (basato su un
  main pre-fase-7); il suo unico contenuto, la cartella `arte/`, è **già
  identico in main**. Si può cancellare; non ripartire da lì.
- CI GitHub Actions **disattivata** (minuti esauriti fino al 1° ottobre
  2026, vedi `.github/workflows/ci.yml`): i test si lanciano in locale a
  ogni story, senza eccezioni.
- Repo **pubblico**: vedi "Nota IP" in `CLAUDE.md` — non è un problema
  tecnico, ma va tenuto presente per ogni cosa che si scrive nei dati.

---

## 2. Ordine delle operazioni

### Passo 0 — prima di iniziare la fase 8 (decisione dell'utente)

Mergiare la **PR #3** in `main`, così la fase 8 parte dalla fase 7 chiusa.
Poi aprire (o farsi indicare) il branch per la fase 8. Se l'utente preferisce
continuare sullo stesso branch rinominato (`fase-7-8`), va bene: le story
US-8NN si accodano lì e la PR #3 continua a raccoglierle.

**Non** spezzare la storia del branch (niente rebase/force-push su un branch
con PR aperta).

### Passo 1 — `/prd`: NON serve

Il PRD della fase 8 è **già scritto** nel formato che `/prd` produrrebbe
(le 9 sezioni: overview, goals, user stories con acceptance criteria,
FR, non-goals, design, technical, metrics, open questions) ed è **più
preciso** di quanto `/prd` possa generare: ogni riferimento `file:riga` è
stato verificato sul codice. Rilanciare `/prd` lo rigenererebbe da zero
perdendo quel lavoro.

Usa `/prd` **solo** se l'utente vuole cambiare lo scope (es. togliere la
grafica, aggiungere la persistenza): in quel caso dagli in input questo
PRD e chiedigli di **modificarlo**, non di riscriverlo.

### Passo 2 — `/ralph`: SÌ, per generare `prd.json`

`prd.json` contiene oggi le 21 story della fase 7, tutte `passes: true`
(storico: il PRD `.md` è il documento, `prd.json` è la coda di lavoro della
fase corrente, e viene sovrascritto a ogni fase — così è stato fatto per
le fasi 2→7).

Lancia:

```
/ralph 006_PRD/prd-fase-8-vertical-slice.md
```

e poi **controlla e correggi** il `prd.json` prodotto, perché la skill ha
dei default diversi dalle convenzioni di questo repo:

| Campo | Deve essere | Perché |
|---|---|---|
| `project` | `"Mirwada"` | come le fasi precedenti |
| `branchName` | il branch di lavoro reale (es. `fase-7-8`), **non** `ralph/...` | ralph.sh e le regole di push del repo usano quello |
| `description` | una riga dalla sezione 1 del PRD | |
| `userStories[*].id` | `US-801` … `US-814`, **identici** al PRD | i commit si chiamano `US-8NN: <cosa>` |
| `userStories[*].fase` | `8` (numero) | il campo esiste in tutte le story precedenti; `ralph.sh --fase 8` |
| `userStories[*].priority` | 1..14 nell'ordine del PRD | le dipendenze vanno solo all'indietro |
| `userStories[*].acceptanceCriteria` | gli AC del PRD, **compresa** la riga finale "python tools/validate_data.py esce 0. Nessuna regressione. Typecheck passes. Tests pass." | è il gate di ogni iterazione |
| `passes` / `notes` | `false` / `""` | |

Verifica veloce dopo il fix:

```bash
python3 -c "import json; d=json.load(open('prd.json')); print(d['branchName'], len(d['userStories']), [s['id'] for s in d['userStories']], all(s['fase']==8 for s in d['userStories']))"
```

Commit: `docs: prd.json della fase 8 (14 story) generato da /ralph`.

### Passo 3 — eseguire le story

Due modi, equivalenti nel risultato:

**A. Ciclo ralph in locale** (sul PC dell'utente, Docker Desktop attivo —
non nel container remoto, dove `~/.claude/skills/ralph.sh` non c'è):

```bash
bash ~/.claude/skills/ralph.sh 14 --fase 8 --test-cmd "godot --headless --script tests/run_tests.gd"
```

`--test-cmd` è **obbligatorio** in questo progetto (README § "Avvio del
ciclo ralph": senza, ralph ripiega su `pytest`, che qui non esiste).

**B. Una story per sessione Claude Code** (web o CLI). Prompt suggerito:

```
Leggi CLAUDE.md, progress.txt, prd.json e 006_PRD/prossimi-passi.md.
Fai la prossima story di prd.json con passes:false a priorità più bassa
(è US-8NN), seguendo la sua sezione in 006_PRD/prd-fase-8-vertical-slice.md.
Prima di scrivere codice spiegami in breve cosa farai e aspetta il mio ok.
Alla fine: validator 0, suite verde, verifica Xvfb se la story tocca UI o
gameplay, progress.txt, prd.json (passes:true + notes), commit
"US-8NN: <cosa>", push.
```

La riga "spiegami e aspetta il mio ok" è la **preferenza dichiarata
dell'utente** (vale in modalità B; in modalità A ralph è autonomo per
definizione).

### Passo 4 — la sequenza consigliata dentro ogni story

1. Leggi `CLAUDE.md` (regole), `progress.txt` (ultime 100 righe bastano),
   `prd.json` (la story), la sezione della story nel PRD, e la tabella
   "Cose che si riusano" (PRD § 7): **contiene i file e le righe** da cui
   partire.
2. Apri i file citati e verifica che le righe siano ancora quelle (il PRD
   è stato scritto su `d7d450e`; se qualcuno ha toccato quei file, i numeri
   possono essere scivolati — cerca la funzione per nome).
3. Scrivi **prima il test** (o estendi quello indicato), poi il codice
   minimo che lo fa passare. Niente astrazioni non richieste (Ponytail).
4. `python tools/validate_data.py` → 0. Se una story tocca dati, aggiungi
   al validator il check che la story chiede (i blocchi sono in fondo al
   file, prima di `report()`; segui lo stile dei blocchi "chiusura fase N").
5. `godot --headless --path . --import` (se hai toccato PNG/tscn/tres),
   poi la suite. Tutta verde, **compresi** i test nuovi.
6. Story con UI/gameplay → verifica a schermo con Xvfb (§ 5) e scrivi in
   `progress.txt` **cosa hai osservato**, non "ok".
7. `progress.txt`: blocco `=== US-8NN: <titolo> ===` con cosa fatto, come
   verificato, cosa resta aperto. `prd.json`: `passes: true`, `notes`
   compilate con le decisioni prese (non un riassunto del titolo).
8. Commit dei **soli file toccati**: `git add <file...>` esplicito,
   messaggio `US-8NN: <cosa>` (+ il footer di attribuzione richiesto dalla
   sessione), push con `git push -u origin <branch>`.
9. Se la story supera ~4 file o ~200 righe di diff **dopo** averla letta
   bene: fermati, dillo, proponi lo split (regola 3). Le story del PRD sono
   già state dimensionate per evitarlo, ma US-807 (4 mappe) e US-812
   (19 fogli) sono le più grosse: se una non chiude, spezzala per regione
   / per foglio, aggiornando `prd.json`.

---

## 3. Setup di un ambiente nuovo (container remoto o PC pulito)

Cosa serve e come lo verifichi:

```bash
godot --version            # atteso: 4.3.stable.official
python3 --version          # 3.10+
python3 -c "import PIL; print(PIL.__version__)"   # Pillow, per i generatori
which xvfb-run             # per la verifica a schermo (opzionale ma richiesto dalle story UI)
```

Se Godot manca (stesse righe della CI, `.github/workflows/ci.yml`):

```bash
mkdir -p ~/godot && cd ~/godot
curl -fsSL -o godot.zip "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip"
unzip -q godot.zip && mv Godot_v4.3-stable_linux.x86_64 godot && chmod +x godot
sudo ln -sf ~/godot/godot /usr/local/bin/godot
cd - && timeout 120 godot --headless --path . --import || true   # l'import in 4.3 non sempre esce 0: il gate è la suite
```

Se mancano Pillow / Xvfb: `pip install pillow` e `apt-get install -y xvfb`
(nel container remoto `apt-get` funziona; su Windows Xvfb non serve: si
lancia Godot normalmente e si guarda).

---

## 4. Comandi di verifica (copia-incolla)

```bash
python tools/validate_data.py                                   # DEVE uscire 0
godot --headless --path . --import || true                      # dopo PNG/tscn/tres
godot --headless --path . --script res://tests/run_tests.gd     # DEVE uscire 0 (776 + i nuovi)
python tools/generate_i18n_stubs.py                             # dopo aver aggiunto chiavi *_i18n
python tools/generate_placeholders.py                           # rigenera i frame (fase 8: sopra generate_sprites.py)
```

Un solo test: la suite non ha filtro per nome; il modo più rapido è un
`--script` che carica solo quel file, oppure lanciare tutto (≈ 1-2 min).

---

## 5. Verifica a schermo con Xvfb (ricetta che funziona in questo repo)

Uno script `SceneTree` (non un test della suite), lanciato con:

```bash
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s res://tests/manual/<nome>.gd
```

Scheletro che **funziona** (già usato per la schermata di finale e per la
diagnosi di `main.tscn`):

```gdscript
extends SceneTree

func _initialize() -> void:
    await process_frame
    await process_frame                      # senza, get_tree() è null negli autoload
    TranslationServer.set_locale("it")       # SettingsStore._ready non gira qui
    var main: Node = load("res://scenes/main.tscn").instantiate()
    get_root().add_child(main)               # gli overlay vanno aggiunti PRIMA di scatenare ciò che devono mostrare
    await process_frame
    await process_frame
    # ... azioni: Input.action_press("move_right"); await process_frame ×N; Input.action_release(...)
    # ... asserzioni: assert(get_root().get_node("Inventory").call("conta", id) == 1)
    get_root().get_texture().get_image().save_png("/tmp/qa/01_passo.png")
    quit()
```

Poi guarda davvero il PNG (`Read` del file nel tool) e scrivi in
`progress.txt` cosa si vede. Uno screenshot grigio = hai scattato prima
che gli overlay ricevessero il segnale: sposta `add_child` prima.

---

## 6. Trappole già scoperte (costano ore, leggile)

1. **`GameState._partita_attiva` non ha reset pubblico.** Un test che chiama
   `nuova_partita()`/`carica_slot()` lo lascia `true` e fa fallire
   `test_page_scaffale` (si aspetta 4 bottoni, ne trova 5: compare
   "Riprendi"). Convenzione (da `tests/test_creazione_talenti.gd`):
   `gs.set("_partita_attiva", false)` in `prepara()` **e** in `_fine()`.
2. **Libro lasciato aperto = albero in pausa** per tutte le suite
   successive in ordine alfabetico (`test_equipment` è la prima vittima).
   Ogni test che apre il libro (`Book.apri`, `apri_a`, o un finale che lo
   apre) lo chiude in `_fine()`; `_fine()` va chiamata in **ogni** test,
   anche quelli che falliscono a metà (il runner non ha teardown).
3. **`assert_almost_eq(got, want, what: String, epsilon = 0.0001)`**: il
   messaggio è il terzo argomento, non l'epsilon.
4. **Import prima della suite** dopo aver toccato asset o scene; e
   `.import` è gitignorato: non committarli.
5. **Le scene regione vengono istanziate headless** da `test_regions.gd`,
   `test_area_gate.gd` (conta i figli per script) e `test_page_mappa.gd`:
   tutto ciò che `region_scene.gd` crea in `_ready()` deve funzionare
   senza player e senza cambiare tipo dei nodi contati.
6. **Nomi dei file di fusione**: coppia in ordine alfabetico
   (`door_error.json`, non `error_door`). Prima di scrivere un check sul
   nome di un file, `ls`.
7. **`generate_i18n_stubs.py` riscrive le chiavi non canoniche nei file di
   dati**: lancialo consapevolmente e guarda il diff.
8. **Il validator è fatto a mano** (`tools/validate_data.py`), non usa
   `jsonschema`: gli schema in `data/schema/*.schema.json` sono
   documentazione. Un check nuovo si scrive come `err()`/`warn()` nello
   stile dei blocchi esistenti.
9. **Segnali e nomi reali** (verificati): `GameState.partita_iniziata(nome)`,
   `Progression.sequence_changed(nuova, vecchia)` (non
   `sequenza_cambiata`), `AbilityEngine.ability_executed(id, caster,
   result)`, `Inventory.tutto()` (non `tutti()`), `enemy.morto(chi)`.
10. **`EventTracker._corrisponde`**: un filtro booleano `true` pretende
    `dati[k] == true`; un payload `{}` non matcha mai. I nuovi payload
    emettono i booleani espliciti (`false` compreso).

---

## 7. Le regole che non si negoziano (recap; il testo vero è in `CLAUDE.md`)

- **I dati non sono codice**: primitive (28), eventi (12), tag (82) sono
  chiusi. Se una story sembra chiederne uno nuovo, è un dato mancante o
  una primitiva sottoparametrizzata: fermati e chiedi all'utente.
- **Nessun nome di contenuto nel codice** (Pathway, NPC, regione, oggetto,
  formula, palette): solo id dai dati e chiavi i18n. US-814 lo controlla
  col grep.
- **Ponytail**: diff minimo, riusa i pattern citati nel PRD § 7, niente
  astrazioni "per dopo".
- **Una story, una iterazione**: se non chiude in una context window, era
  troppo grossa — dillo e spezzala.
- **i18n dal giorno 1**: chiavi in `strings.csv` (UI) o `data/i18n/*.json`
  (dati), mai testo in chiaro, nemmeno provvisorio.

---

## 8. Cosa consegnare all'utente

- A ogni story con UI/gameplay: **lo screenshot** (via `SendUserFile`) e
  due righe su cosa si vede. L'utente vuole vedere il gioco, non leggere
  che "i test passano".
- A fine fase (US-814): gli screenshot del giro completo, lo **schema dei
  comandi** (movimento WASD/frecce; attacco/schivata/parata come in
  `project.godot`; 1-4 abilità; Tab/I libro; F/Invio interagisci; Q/E
  pagine) e l'elenco onesto di cosa resta fuori (PRD § 5).
- Se emerge una decisione di design (PRD § 9 "Open Questions" o una nuova):
  **chiedi**, con opzioni chiare, prima di implementare. Non decidere da
  solo cosa "deve esserci" nel gioco: è la regola con cui questo PRD è
  stato scritto.

---

## 9. Dopo la fase 8

Aggiornare `CLAUDE.md` § Fasi ("Fase 8 — Vertical slice: CHIUSA"),
`roadmap.md` (Fase 9 opzionale = Pathway Non-Standard), `README.md`. Il
primo vero playtest umano produrrà la lista di bilanciamento e la
decisione su persistenza/spawner (PRD § 5): quello è materiale per un
nuovo PRD, da generare **allora** con `/prd`.
