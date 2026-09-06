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

Il PRD della fase 5 (espansione contenuti) si genera con `/prd` — vedi
`006_PRD/roadmap.md`. La fase 5 è il **punto di controllo** dell'architettura.

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
abilita'. Prova: il Twilight Giant e' completo dalla Sequenza 9 alla 0 con
zero righe di codice dedicate (data/abilities/twilight_giant.json).

## Documenti

- `CLAUDE.md` — regole di lavoro, comandi, decisioni prese
- `006_PRD/prd-fase-3-sistemi-di-supporto.md` — PRD della fase corrente
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
