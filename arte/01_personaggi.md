# Personaggi — protagonista, NPC, popolani

Fonti: `006_PRD/design-npc-quest.md` (roster e funzione), `006_PRD/design-lore.md`
(chi ha vincoli dell'utente), `006_PRD/art-brief-gemini.md` cap. 4 (prompt
pronti + blocco di stile completo).

## 1. Chi va disegnato

**9 ritratti**: il protagonista (`Enel`, nome di default, rinominabile) + gli
8 NPC del roster. Ognuno ha una funzione meccanica precisa, non solo
narrativa — utile per capire cosa il ritratto deve comunicare:

| id | Funzione nel gioco | Cosa deve trasmettere il volto |
|---|---|---|
| **Enel** (protagonista) | — | guardato, esausto, un freddo che cresce sotto |
| `npc_mirco` *(vincolato dall'utente, provvisorio)* | tutorial diegetico, insegna le basi | apertura, calore, il primo volto amico |
| `npc_sidon` *(vincolato dall'utente, provvisorio)* | mercante di reagenti e voci | piacevole in superficie, calcolatore sotto |
| `npc_vesna` | cura a prezzo di fiducia | diffidenza, misura chi hai davanti |
| `npc_aldo` | rivale che avanza in parallelo | amichevole e competitivo insieme |
| `npc_ottavia` | gating di conoscenza (Archivio Sepolto) | fredda, valuta se meriti di leggere |
| `npc_bruno` | gating di zona (porto notturno) | indifferente, transazionale |
| `npc_lena` | l'Ancora piu' fragile, nessun servizio | luminosa, ignara di cosa sei diventando |
| `npc_doran` | pressione: il sospetto sale con l'uso di potere | paziente, gia' sulle tue tracce |

**Mirco e Sidon sono provvisori**: l'utente decide lui il loro aspetto finale.
Le descrizioni fisiche sotto servono solo a non lasciare buchi nel set — vanno
rigenerate quando l'utente fissa i volti veri. Non trattarle come canoniche.

Servono anche **popolani generici** (`npc_generic_*`, senza dialogo): 3-4
varianti anonime bastano, usate dalle recitazioni "aiuta 8 NPC" / "inganna 10".

## 2. Descrizioni fisiche di partenza (sostituibili)

Vedi `006_PRD/design-world.md` cap. 4.3 per la tabella completa (eta',
corporatura, capelli, guardaroba, espressione, colore di accento per
ciascuno). Trattale come default, non come canone — soprattutto Mirco e
Sidon.

## 3. Se generi con IA (Gemini/Imagen)

Blocco di stile da incollare in testa a **ogni** prompt (`art-brief-gemini.md`
cap. 1):

```
STYLE: Ink-and-brush illustration in the manner of modern Korean action
manhwa (e.g. Legend of the Northern Blade): heavy solid black fills, thick
loaded brush lines with irregular, tapering ends, bold negative space, high
contrast, sparse rendering. Limited muted palette, three colours plus black.
Gritty early-20th-century gaslamp-fantasy setting.

DO NOT: photorealism, 3D render, plastic skin, anime chibi, flat vector,
glossy gradients, modern clothing, on-image text, watermark, UI elements.
```

Formato ritratto: **4:5 mezzobusto**, tre quarti, sguardo verso l'osservatore.

Per una serie coerente (Gemini non tiene un personaggio identico tra
un'immagine e l'altra):
1. incolla lo stesso blocco di stile ogni volta;
2. ripeti **tutta** la descrizione fisica per esteso (eta', corporatura,
   capelli, viso, guardaroba) — mai "lo stesso di prima";
3. genera tutti i 9 ritratti nella stessa sessione, uno dopo l'altro;
4. fissa scena identica per tutti: sfondo grigio-carta neutro, luce da
   sinistra, mezzobusto, sguardo in camera.

Prompt base da riempire (`art-brief-gemini.md` cap. 4.2):

```
[BLOCCO DI STILE]
Character portrait, bust, three-quarter view, subject looking toward the
viewer. Neutral warm-grey paper background, single soft light from the left.
Early-20th-century working-class clothing, worn, practical. No weapons, no
magic effects, no text.

SUBJECT: [età] year old [gender], [corporatura]. [capelli]. [tratto del viso
più forte]. Wearing [guardaroba]. Expression: [espressione]. Palette: black,
warm grey, [accento]. Aspect 4:5.
```

## 4. Dove salvare

```
assets/concept/ritratti/enel.png, mirco.png, sidon.png, vesna.png, aldo.png,
                        ottavia.png, bruno.png, lena.png, doran.png
```

Materiale di **riferimento**: non entra in `assets/` ne' viene caricato dal
gioco finche' non diventa un ritratto di dialogo vero (fase 6, non ancora
implementata).

## 5. Prima di considerarlo fatto

Vedi `05_checklist_finale.md`. In breve per i ritratti: palette max 3 colori
+ nero, niente testo/watermark, guardaroba coerente inizio '900, l'intera
serie con luce/inquadratura identiche.
