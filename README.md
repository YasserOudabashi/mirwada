# Sequenza

Action-RPG 2D esplorativo top-down con sistema di progressione a Pathway e
Sequenze: 10 Pathway attivi (4 gruppi completi), 10 Sequenze ciascuno,
100 in totale. Altri 12 Pathway restano differiti in data/pathways_deferred/.

## Stato

Fase 1 — Fondamenta. La spina dorsale dei dati e' completa; il codice di gioco
non e' ancora iniziato.

## Setup

Richiede Godot 4.x e Python 3 (solo per gli strumenti di dati).

```bash
python tools/validate_data.py      # valida tutti i dati, esce 0 se ok
python tools/generate_pathways.py  # rigenera la spina dorsale dei 22 pathway
```

## Architettura in una riga

Il codice implementa 28 primitive parametriche; i dati JSON le compongono in
abilita'. Prova: il Twilight Giant e' completo dalla Sequenza 9 alla 0 con
zero righe di codice dedicate (data/abilities/twilight_giant.json).

## Documenti

- `CLAUDE.md` — regole di lavoro, comandi, decisioni prese
- `006_PRD/prd-fase-1-fondamenta.md` — PRD della fase corrente
- `006_PRD/design-pathways.md` — perche' questi 10 Pathway, cosa si e' perso
- `data/audio.json` — sistema audio data-driven (tell sonori, follia, palette)
- `006_PRD/roadmap.md` — fasi 2-8
- `prd.json` — story della fase corrente in formato ralph
- `progress.txt` — memoria tra le sessioni

## Avvio del ciclo ralph

```bash
bash ~/.claude/skills/ralph.sh 5 --fase 1
```

Prerequisiti: Docker Desktop attivo, `prd.json` presente in root.
