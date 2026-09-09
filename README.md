# Mirwada

[![CI](https://github.com/YasserOudabashi/mirwada/actions/workflows/ci.yml/badge.svg)](https://github.com/YasserOudabashi/mirwada/actions/workflows/ci.yml)

Action-RPG 2D esplorativo top-down con sistema di progressione a Pathway e
Sequenze: 10 Pathway attivi (4 gruppi completi), 10 Sequenze ciascuno,
100 in totale. Altri 12 Pathway restano differiti in data/pathways_deferred/.

## Stato

**Fase 1 — Fondamenta: chiusa.** 27 story, 112 test. Caricatore + hot-reload
robusto ai JSON corrotti, statistiche da balance.json, motore delle abilita',
animazione data-driven, movimento, camera, combattimento completo (attacco,
schivata i-frame, parata/postura, nemico con telegrafia e tell sonoro),
salvataggio versionato, HUD i18n, bus audio.

**Fase 2 — Pathway Core: chiusa.** 35 story, 318 test. Motore Pathway/Sequenza,
Acting Method + EventTracker, Follia (layer audio, VFX, Ancore, rituali),
pozioni e concoction, i18n reale dei dati (`data/i18n/`, `GameData.tr_data`),
la **shell del libro** (ogni schermata e' una pagina: scaffale/salvataggi,
frontespizio/creazione personaggio, diagramma dei Pathway con fog of war,
colophon/impostazioni con `user://settings.json`), `data/vfx.json` + renderer
VFX per primitiva con impact frame. Criterio di uscita (US-219): il Twilight
Giant va dalla Sequenza 9 alla 5 con zero codice dedicato.

**Fase 3 — Sistemi di supporto: chiusa.** 35 story, 498 test. Inventario/
equip con tag di sinergia, `stored_ability_id`, alchimia (qualità, fallimenti
mostruosi, scoperta ricette), forgiatura e sigilli (con effetti collaterali),
strutture (`StructureRegistry`, le abilità d'area le rompono), un pet completo
(taming, `bond`, coltivazione, la sua morte è la perdita di un'Ancora), base
building (4 stanze coi bonus letti per chiave, giardino che cresce col tempo
di gioco), talenti (innati alla creazione + acquisiti contando comportamenti),
e `SynergySources` che somma i tag di tutte le fonti per la fase 4. Save da
schema_version 12 a 19. Verdetto (US-335): i sistemi compongono un ciclo
completo con zero codice dedicato a un contenuto.

**Fase 4 — Sinergie: chiusa.** 16 story, 535 test. `SynergyEngine` (autoload)
risolve i tag posseduti in sinergie attive, con priorità/conflitti e
anti-sinergie (`neutralizza` dichiarato nei dati); i 6 tipi di effetto
funzionano tutti (`modifica_stat`, `modifica_follia`, `modifica_qualita_crafting`,
`sblocca_ricetta`, `aggiungi_abilita`, `modifica_primitiva`). Registro
persistente (`sinergie.viste`, save 19 → 20) + sezione Sinergie nella pagina
inventario del libro col fog of war, reattiva dal vivo. 44 sinergie di cui 26
raggiungibili coi 10 Pathway attivi (le altre 18 puntano a gruppi differiti e
si accenderanno riattivandoli). Verdetto (US-413, `tests/test_slice_fase_4.gd`):
una sinergia pet + stanza + talento si attiva senza una riga di codice dedicata.

**Fase 5 — Espansione contenuti: chiusa.** 22 story, 570 test. Cinque Pathway
nuovi completi — **Death, Moon, Mother, Paragon, Hermit**, tutti a 10/10
Sequenze (abilità, recitazione, pozioni, rituali di avanzamento). Sette
primitive implementate (`fear`, `reveal_info`, `teleport`, `soul_detach`,
`resurrect`, `plant_growth`, `mind_read`), ognuna quando il primo Pathway
l'ha richiesta. `darkness_1`/`paragon_1`/`hermit_1` riscritte senza le
primitive differite. `data/schema/location_tags.json` + `ownership.json` (la
matrice di proprietà come check del validator). Save invariato.

**Il punto di controllo dell'architettura è stato superato** (US-508,
`tests/test_slice_fase_5.gd`): Death giocato interamente in codice, dalla
Sequenza 8 alla 2, con zero righe che nominano il Pathway; il `git diff` del
blocco tocca solo i 5 handler di primitiva nuovi + un metodo di movimento del
player. `AbilityEngine.execute` non è stato toccato.

**Fase 6 — Mondo: chiusa.** 22 story, 669 test. Cinque regioni giocabili
(una scena data-driven per tutte), ciclo giorno/notte + fasi lunari
(`TimeSystem`) che fa valere le condizioni `e_notte`/`fase_lunare`/`in_zona_tag`
delle abilità. **Darkness completo 10/10** + `shadow_meld`/`illusion` (fase 5b
interlacciata). `AreaGate` che applica `regions.json.gating[]` (6 modi da
`gate_types.json`), aperto per sempre da un `terrain_modify` permanente. 8 NPC
(`roster.json`) con schedule e memoria; motore dialoghi (`DialogueEngine`,
effetti da vocabolario chiuso) + i 9 grafi; fazioni + reputazione
(`FactionSystem`, comportamenti automatici dichiarati nei dati); motore quest
(`QuestSystem`, lettore di eventi + flag, zero verbi nuovi) + 4 quest di Atto I
+ Journal nel libro; pagina mappa (fog of war, fast travel = potere); densità
mistica (recupero, forzatura, percezione da Seq 5); audio del mondo come
**specifica** (nessun file audio prodotto); antagonista strutturale per Pathway
(`data/lore/antagonisti.json`). Save **`schema_version` 20 → 21** (un solo
bump: tutto il resto sta nel campo `mondo`).

**Fase 5b — Lord of Mysteries: chiusa.** 12 story, 713 test. **Fool, Error,
Door completi 10/10** → con Darkness (fase 6) e i 19 già fatti: **22/22
Pathway attivi completi, 100/100 Sequenze non-stub**. Tre primitive
implementate: `steal` (oggetto/abilità/conoscenza; l'Error *sottrae*, il Door
*fotocopia* con `non_sottrae`), `possess` (status `posseduto`, il corpo del
caster a terra come `soul_detach`), `time_rewind` (ring buffer di snapshot
per-caster, non tocca il save). `fool_2` riscritta senza `probability_shift`
(differita). Materia prima `avatar` nuova (Error: autonomi; Fool: `illusion`).
`chain` resta senza handler: nessuna Sequenza attiva lo richiede. Save
**invariato**. Verdetto (US-5B04, `tests/test_slice_fase_5b.gd`): Error giocato
in codice dalla Sequenza 8 alla 2, zero righe che nominano il Pathway; il
`git diff` del blocco A è solo `ability_engine.gd` +173 -0 (handler nuovi +
ring buffer), il dispatcher intatto. PRD: `006_PRD/prd-fase-5b-lord-of-mysteries.md`.

**Fase 7 — Endgame: chiusa.** 21 story, 776 test. Cambio di Pathway
(`PathwayChange`) solo tra vicini dello stesso gruppo + fusione
(`FusionEngine`, un percorso completo `error_door` con 6 abilità fuse, 7
stub dichiarati per la fase 7b). `TribulationSystem` (lettore di eventi/
flag) blocca l'avanzamento ai 4 salti di fascia finché la prova non è
superata. Sequenze alte come contenuto: 6 abilità di "preghiera" su
primitive già esistenti + 4 siti rituali di Sequenza 0 condivisi per
gruppo. I 3 finali (`data/endings.json`: Apoteosi, Consumazione = il game
over per follia, Rinuncia) valutati da `EndingSystem` (nessun tipo di
condizione nuovo); schermata di finale che estende il colophon; eredità
al personaggio successivo — conoscenza sempre, Ancora a forza dimezzata,
reputazione dimezzata e un oggetto scelto (profilo completo) — riapplicata
a un nuovo personaggio sullo stesso slot. Save **`schema_version` 21 → 22**
(un solo bump: tutto il resto sta nel campo `endgame`).

**Verdetto del checkpoint** (US-720, `tests/test_slice_fase_7.gd`): un
personaggio attraversa l'intero ciclo — cambio Pathway con fusione, una
tribolazione superata, un finale raggiunto, l'eredità riapplicata — con
zero righe di codice che nominino un Pathway, una coppia di fusione, una
tribolazione o un finale specifico. `ability_engine.gd` non è stato
toccato in tutta la fase. PRD: `006_PRD/prd-fase-7-endgame.md`.

## Setup

Richiede Godot 4.x e Python 3 (solo per gli strumenti di dati).
`tools/generate_placeholders.py` richiede anche Pillow (`pip install pillow`).

```bash
python tools/validate_data.py      # valida tutti i dati, esce 0 se ok
godot --headless --path . --script res://tests/run_tests.gd   # suite headless, esce 0 se ok
python tools/generate_pathways.py  # rigenera la spina dorsale dei 10 pathway
```

La suite headless include un test che esegue `tools/validate_data.py`: un
dato rotto committato fa fallire i test, non solo il validator lanciato a
mano. Esce 0 se tutto passa, 1 al primo fallimento.

## Architettura in una riga

Il codice implementa 28 primitive parametriche; i dati JSON le compongono in
abilita'. Prova: tutti e 10 i Pathway attivi (100/100 Sequenze) sono
completi dalla Sequenza 9 alla 0 con zero righe di codice dedicate
(data/abilities/*.json) — e l'intero endgame di fase 7 (cambio Pathway,
tribolazioni, finali) regge sulla stessa architettura.

## Documenti

- `CLAUDE.md` — regole di lavoro, comandi, decisioni prese
- `006_PRD/prd-fase-7-endgame.md` — PRD dell'ultima fase chiusa
- `006_PRD/prd-fase-5b-lord-of-mysteries.md` — PRD della fase 5b (chiusa)
- `006_PRD/prd-fase-6-mondo.md` — PRD della fase 6 (chiusa)
- `006_PRD/prd-fase-2-pathway-core.md` — PRD della fase 2 (chiusa)
- `006_PRD/prd-fase-1-fondamenta.md` — PRD della fase 1 (chiusa)
- `006_PRD/design-master.md` — design doc master: baseline dell'audit, sicurezza, contratti, story per fase, decisioni aperte
- `006_PRD/design-pathways.md` — perche' questi 10 Pathway, cosa si e' perso
- `006_PRD/design-lore.md` — nome del gioco, protagonista, roster NPC
- `006_PRD/design-world.md` — le 5 regioni, biomi, gating, tempo
- `006_PRD/design-npc-quest.md` — NPC, dialoghi, fazioni, quest, tre atti e finali
- `006_PRD/design-ui-libro.md` — la UI a libro: ogni schermata e' una pagina
- `006_PRD/design-vfx.md` — identita' visiva delle abilita' (stile manhwa), 10 palette
- `006_PRD/art-brief-gemini.md` — prompt pronti per generare concept/ritratti/UI con Gemini, con i limiti dichiarati
- `data/audio.json` — sistema audio data-driven (tell sonori, follia, palette)
- `006_PRD/roadmap.md` — fasi 2-8
- `prd.json` — story della fase corrente in formato ralph
- `progress.txt` — memoria tra le sessioni
- `docs/documentazione.py` — rigenera la documentazione docx; `diario.py` — diario del progetto

## Avvio del ciclo ralph

```bash
bash ~/.claude/skills/ralph.sh <N> --fase <F> --test-cmd "godot --headless --script tests/run_tests.gd"
```

Prerequisiti: Docker Desktop attivo, `prd.json` presente in root con le story
della fase da lavorare.

**`--test-cmd` non e' opzionale in questo progetto.** ralph.sh rileva il
comando di test da solo, ma il suo fallback quando non trova `package.json` e'
`uv run pytest tests/ -v`: qui non c'e' ne' npm ne' pytest, quindi ogni
iterazione fallirebbe la verifica dei test su un comando che non puo' passare.
La suite headless include gia' `tools/validate_data.py`.

`<N>` e' il numero di story da lavorare: una story per iterazione, in ordine
di priorita'.
