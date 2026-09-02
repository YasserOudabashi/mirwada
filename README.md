# Mirwada

Action-RPG 2D esplorativo top-down con sistema di progressione a Pathway e
Sequenze: 10 Pathway attivi (4 gruppi completi), 10 Sequenze ciascuno,
100 in totale. Altri 12 Pathway restano differiti in data/pathways_deferred/.

## Stato

Fase 1 — Fondamenta, 6 story su 26 chiuse (21 originali + 5 di risanamento
dall'audit del 2026-09-02). Spina dorsale dei dati completa; caricatore,
hot-reload, statistiche e motore delle abilita' funzionanti e coperti da 43
test headless. Movimento, camera e combattimento non ancora iniziati:
richiedono verifica a schermo.

## Setup

Richiede Godot 4.x e Python 3 (solo per gli strumenti di dati).

```bash
python tools/validate_data.py      # valida tutti i dati, esce 0 se ok
godot --headless --path . --script res://tests/run_tests.gd   # test, esce 0 se ok
python tools/generate_pathways.py  # rigenera la spina dorsale dei 10 pathway
```

## Architettura in una riga

Il codice implementa 28 primitive parametriche; i dati JSON le compongono in
abilita'. Prova: il Twilight Giant e' completo dalla Sequenza 9 alla 0 con
zero righe di codice dedicate (data/abilities/twilight_giant.json).

## Documenti

- `CLAUDE.md` — regole di lavoro, comandi, decisioni prese
- `006_PRD/prd-fase-1-fondamenta.md` — PRD della fase corrente
- `006_PRD/design-master.md` — design doc master: baseline dell'audit, sicurezza, contratti, story per fase, decisioni aperte
- `006_PRD/design-pathways.md` — perche' questi 10 Pathway, cosa si e' perso
- `006_PRD/design-lore.md` — nome del gioco, protagonista, roster NPC
- `006_PRD/design-world.md` — le 5 regioni, biomi, gating, tempo
- `006_PRD/design-npc-quest.md` — NPC, dialoghi, fazioni, quest, tre atti e finali
- `006_PRD/design-ui-libro.md` — la UI a libro: ogni schermata e' una pagina
- `006_PRD/design-vfx.md` — identita' visiva delle abilita' (stile manhwa), 10 palette
- `data/audio.json` — sistema audio data-driven (tell sonori, follia, palette)
- `006_PRD/roadmap.md` — fasi 2-8
- `prd.json` — story della fase corrente in formato ralph
- `progress.txt` — memoria tra le sessioni
- `docs/documentazione.py` — rigenera la documentazione docx; `diario.py` — diario del progetto

## Avvio del ciclo ralph

```bash
bash ~/.claude/skills/ralph.sh 21 --fase 1 --test-cmd "python tools/validate_data.py"
```

Prerequisiti: Docker Desktop attivo, `prd.json` presente in root.

**`--test-cmd` non e' opzionale in questo progetto.** ralph.sh rileva il
comando di test da solo, ma il suo fallback quando non trova `package.json` e'
`uv run pytest tests/ -v`: qui non c'e' ne' npm ne' pytest, quindi ogni
iterazione fallirebbe la verifica dei test su un comando che non puo' passare.

Finche' US-016 (infrastruttura dei test headless) non e' chiusa, l'unico
controllo reale sui dati e' il validator. Da US-016 in poi passare a:

```bash
bash ~/.claude/skills/ralph.sh 21 --fase 1 --test-cmd "godot --headless --script tests/run_tests.gd"
```

`21` e' il numero di story della fase 1: una story per iterazione. Un numero
piu' basso lavora solo le prime N story in ordine di priorita'.
