# Mirwada — Guida per chi disegna

Questa cartella raccoglie in un posto solo tutto cio' che serve a chi deve
**disegnare o generare l'arte** del gioco: personaggi, regioni/mappe, sprite,
combattimento/VFX. Non introduce decisioni nuove — le decisioni sono gia'
prese, sparse tra `006_PRD/` e i file dati in `data/`. Qui c'e' solo l'ordine
in cui leggerle e i passi pratici da seguire.

Se un numero (dimensione, frame, colore) qui dentro e in un file sorgente
sotto non coincidono mai, **vince il file sorgente**: questa guida e' un
indice comodo, non l'autorita'.

## Le 3 cose da sapere prima di aprire un editor di immagini

1. **I dati non sono codice** (`CLAUDE.md`, regola 1). Quello che disegni
   finisce quasi sempre in due posti soli:
   - `assets/concept/` — materiale di **riferimento** (illustrazioni,
     turnaround, mood), mai usato a runtime dal gioco;
   - `assets/` (es. `assets/placeholder/`) — asset **reali**, spritesheet
     ritagliati alla griglia esatta che il codice carica.
   Nessun nome di Pathway o Sequenza va scritto a mano nel codice o nella UI:
   solo nei dati e nei file immagine (i nomi file seguono le convenzioni gia'
   in uso, es. `personaggio_idle.png`).
2. **Niente e' definitivo finche' non e' a schermo.** Fase 1-6 del gioco
   usano placeholder diagnostici generati da `tools/generate_placeholders.py`.
   L'arte "vera" e' benvenuta ma non blocca nulla: sostituisce i placeholder
   file per file, quando c'e'.
3. **Nota IP** (`CLAUDE.md`): il sistema di riferimento narrativo e' opera di
   terzi. Progetto personale, non distribuibile ne' monetizzabile con i nomi
   attuali. L'arte generata (Gemini/Imagen) e' "alla maniera di", materiale
   di riferimento — mai da ridistribuire come se fosse originale.

## Percorso consigliato

1. **`01_personaggi.md`** — protagonista, 8 NPC, popolani generici.
2. **`02_regioni_e_mappe.md`** — le 5 regioni del mondo, i tileset, il gating.
3. **`03_sprite_e_animazioni.md`** — sprite di gioco 32x32, animazioni, timing.
4. **`04_combattimento_vfx.md`** — leggibilita' del combattimento, effetti per
   pathway.
5. **`05_checklist_finale.md`** — checklist unica prima di considerare
   un'immagine "fatta" e sapere dove salvarla.

Ogni file dice: cosa disegnare, con quali vincoli, con quale prompt (se generi
con IA), dove salvare il risultato, come verificarlo.

## Documenti sorgente (l'autorita' vera)

| File | Cosa contiene |
|---|---|
| `006_PRD/art-brief-gemini.md` | Prompt pronti per Gemini/Imagen per ogni categoria (regioni, ritratti, UI, sprite, tileset) + checklist di accettazione |
| `006_PRD/design-world.md` | Le 5 regioni, i biomi, il gating, tempo/luna |
| `006_PRD/design-vfx.md` | Identita' visiva delle abilita', le 10 palette per Pathway, principi manhwa |
| `006_PRD/design-npc-quest.md` | Il roster dei 9 personaggi (protagonista + 8 NPC), funzione di ognuno |
| `006_PRD/design-lore.md`, `design-master.md`, `design-ui-libro.md` | Narrativa, principi generali, UI a libro |
| `data/animations.json` | Fonte di verita' esatta: frame, fps, indici di anticipo/attivi/recupero per ogni animazione |
| `data/vfx.json` | Palette visiva corrente per Pathway + effetto per primitiva (colori "plausibili", li rivede l'arte vera) |
| `data/world/regions.json` | Le 5 regioni con id, gating, palette, location_tags |
| `data/schema/location_tags.json` | Vocabolario chiuso dei luoghi da rendere a schermo |

## Strumenti

```bash
# Rigenera i placeholder diagnostici da data/animations.json — utile per
# capire la griglia esatta (righe/colonne, dimensioni) prima di disegnare
python tools/generate_placeholders.py
```

Richiede Pillow (`pip install pillow`).
