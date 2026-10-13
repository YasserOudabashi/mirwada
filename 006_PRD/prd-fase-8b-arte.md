# PRD: Fase 8b — Arte completa (64 px, generata con sprite-forge)

> Scritto il 2026-10-13 dopo l'inventario completo degli asset mancanti
> (sessione Claude Code). Regole d'arte: `CLAUDE.md` v2, sezione "Arte e asset".
> Questo PRD **non** sostituisce `prd-fase-8-vertical-slice.md`: lo affianca.
> Le story qui hanno id `US-8B..` per non collidere con `US-801..814`.

## 1. Overview

Il gioco ha tutti i sistemi, ma l'arte vera copre solo 3 categorie
(`personaggio`, `nemico_base`, `pet` a 32 px). Mancano mappa, NPC, ritratti,
creature, boss, tutti i 27 VFX, icone, UI del libro e panorami.
Questa fase produce **tutto**, a 64 px, con `sprite-forge`, partendo dalla mappa.

## 2. Decisioni già prese con l'utente (2026-10-13)

| # | Decisione | Conseguenza |
|---|---|---|
| 1 | **64 px per frame** | `dimensione_frame` → `[64,64]`, tile 64, viewport 1280×720 (stessa area visibile di prima), tutto ciò che è a 32 px si rigenera |
| 2 | **VFX colorati nel gioco** | 27 fogli in scala di grigi (uno per primitiva), il colore lo applica uno shader leggendo `data/vfx.json.pathway_palette_visiva` |
| 3 | **Nemici per regione: rimandati** | fuori scope di questa fase, da studiare in un PRD dedicato. Qui resta solo `nemico_base` |

## 3. Regola di lavoro: le domande

Prima di **ogni** story Claude fa domande all'utente e aspetta le risposte.
**Più grande è il posto o la cosa, più domande.** Scala indicativa:

| Taglia | Esempi | Domande minime |
|---|---|---|
| XL | struttura del mondo, una regione intera | 10–15, in più giri |
| L | un boss, una famiglia di creature, Enel | 6–8 |
| M | un NPC, un pet, un set di VFX, una pagina del libro | 3–5 |
| S | un'icona, una variante di colore | 1–2 |

Le risposte si annotano nella story (campo `notes` in `prd.json`) e in
`progress.txt`, così la story si può rigenerare uguale.
Poi vale il flusso normale: spiegazione → via dell'utente → codice/generazione.

## 4. Story

Legenda: **[D]** = solo dati/documenti, **[C]** = codice, **[A]** = generazione d'arte.

### Blocco A — Fondamenta (prima di tutto il resto)

**US-8B01 [C] Passaggio a 64 px.** `data/animations.json.convenzioni.dimensione_frame`
→ `[64,64]`; dimensione tile 64; viewport 1280×720 a scala intera; camera.
Una sola story, come da CLAUDE.md. Test headless verdi con i placeholder
rigenerati a 64. *Domande (S): conferma 1280×720.*

**US-8B02 [C] forge3d dentro il repo.** Oggi la skill vive fuori dal repo
(`~/.claude/skills/...`): sul PC dell'utente la rigenerazione non è
riproducibile. Copia di `forge3d/` in `tools/art/forge3d/` (versione fissata),
`generate_all.py` la usa da lì. È il posto dove andranno i terreni nuovi.

**US-8B03 [C] Shader di palette per i VFX.** Un solo shader: grigio → rampa
`inchiostro / primario / accento` del Pathway che lancia. Legge `vfx.json`,
nessun nome di Pathway nel codice. Rispetta `riduci_flash`.

### Blocco B — La mappa (si parte da qui)

**US-8B10 [D] Struttura del mondo e biomi. XL.** Si decide, con le domande,
come è fatto il mondo e quali biomi ha ogni regione. Esito: aggiornamento di
`006_PRD/design-world.md` (sezione "Biomi a schermo") e un file dati
`data/world/biomes.json`: per ogni regione l'elenco dei biomi, il terreno
dominante, gli oggetti tipici, dove stanno i `location_tags`. Nessuna PNG.
*Domande: vedi §5, primo giro già pronto.*

**US-8B11 [A] Terreni nuovi.** Dai biomi di US-8B10 escono i terreni che
`terrain.py` non ha ancora (es. selciato, brughiera, cenere, pavimento
d'archivio, nebbia). Uno per riga in `ORDER`, rampe Endesga 32, 16 tile
dual-grid ciascuno, a 64 px. *Domande (M) per ogni terreno nuovo.*

**US-8B12 [C] Loader del mondo.** `scripts/world/sprite_forge_world.gd`
(da `engines/godot/`) collegato a `region_scene.gd`: la regione carica
`assets/world/<regione>/world.json` invece del rettangolo 48×36.
Collisioni e `AreaGate` restano dati.

**US-8B13..17 [A] Una regione per story.** Ordine: `mirwada`,
`marche_crepuscolo`, `valle_madre`, `archivio_sepolto`, `frontiera_porte`.
Ognuna: preset di bioma → generazione dal seed → ritocco **nei dati** →
anteprima ingrandita guardata → `world.json` + atlanti committati.
Ogni `location_tag` della regione deve esistere a schermo.
*Domande (XL) per ogni regione: 10–15.*

**US-8B18 [A+C] Edifici e oggetti di scena.** Il generatore oggi non fa edifici
né ponti veri: estensione di `forge3d` (case, ponti, templi, torre, scaffali,
altari, rovine). Story a sé, poi si rigenerano le regioni con lo stesso seed.
*Domande (L).*

**US-8B19 [A] Siti unici.** `trono_del_gigante`, `biblioteca_di_tutto`,
`radice_del_mondo`, `porta_senza_stanza`: un pezzo di mappa costruito apposta.
*Domande (L) per ognuno.*

**US-8B20 [A] Base del giocatore.** 4 stanze (`laboratorio`, `stanza_rituale`,
`biblioteca`, `giardino`) e 3 strutture (`palizzata`, `totem_veglia`, `deposito`).

**US-8B21 [A] Varchi di gating visibili.** Un aspetto per ognuno dei 6 tipi in
`gate_types.json` (ombra, radici, porta sigillata, ...). Il giocatore deve capire
*che* c'è un varco, non *come* si apre.

### Blocco C — Personaggi (rigenerati a 64 px)

**US-8B30 [A] Enel a 64 px. L.** `build_enel.py` riscritto per 64 (a 32 il viso
era al minimo). 10 animazioni, ciclo chiuso, confronto prima/dopo.
**US-8B31 [A] nemico_base a 64 px. M.** Il tell resta leggibile da fermo.
**US-8B32 [A] 3 pet. M ciascuno.** `lupo_cinereo`, `corvo_veggente` (vola:
estensione del generatore), `capra_lunare`, più `hurt` e `death` nei dati.
**US-8B33 [A] 8 NPC con nome. M ciascuno.** idle + walk, 4 direzioni.
**US-8B34 [A] 10 generici + antagonista. M.** Varianti di 2–3 corpi.
**US-8B35 [A] 9 ritratti. M.** Stessa luce, inquadratura e sfondo per tutti.

### Blocco D — VFX (in scala di grigi, colorati dallo shader)

**US-8B40 [A] Attacchi base. M.** `vfx_slash`, `vfx_bolt`, `vfx_streak` +
feedback del colpo (scintilla, scintilla della parata perfetta, polvere,
rottura della postura).
**US-8B41..43 [A] Le altre 24 primitive**, a gruppi di 8. *Domande (M) per gruppo.*
**US-8B44 [A] Varianti `riduci_flash`** di tutti gli effetti con lampo.

### Blocco E — Creature e trasformazioni

**US-8B50 [A] Forme di Enel. L.** `tg_forma_gigante` (set intero, frame più
grandi), `tg_arma_luce` (sovrapposta agli attacchi).
**US-8B51..55 [A] Evocazioni, 5 famiglie. L ciascuna.** Non morti, spiriti,
bestie, chimere, costrutti: uno scheletro per famiglia, varianti per i 22
`entita_id`.
**US-8B56..65 [A] 10 boss** (`data/lore/antagonisti.json`). L ciascuno.
Rispettano il fog of war: nessun dettaglio rivela Sequenze non raggiunte.

### Blocco F — Icone, libro, panorami

**US-8B70 [A] 39 icone oggetto. S ciascuna.**
**US-8B71 [A] 14 icone di stato. S.**
**US-8B72 [A] 27 icone di primitiva** (colorate dallo shader come i VFX).
**US-8B73 [A] Pagine del libro. M per pagina.** Le 9 pagine di `data/ui/book.json`,
i segnalibri, la voltata, le macchie, la pagina "follia".
**US-8B74 [A] Panorami. L.** Schermata iniziale e libro: 6 strati × 4 fasce orarie.

### Blocco G — Animazioni nuove di Enel

**US-8B80 [D+A]** interagire, raccogliere, bere, rituale (prima la voce in
`animations.json`, poi lo sheet). Arrampicata e nuoto solo se una regione li
richiede (lo decide US-8B10).

## 5. Domande del primo giro (US-8B10, struttura del mondo)

1. Mondo unico collegato o 5 mappe separate?
2. Quanto è grande una regione (in schermate)?
3. Come si passa da una regione all'altra?
4. Mirwada è sul mare?
5. Dove sta la base del giocatore?
6. Il mondo ha un "nord freddo" o un clima uniforme?
7. Quanto deve essere fitta la vegetazione nelle regioni aperte?
8. Si vede il cielo o le regioni chiuse (archivio, cripte) sono tutte al chiuso?
9. Si nuota e ci si arrampica?
10. Strade visibili tra i luoghi o terreno libero?
11. Ogni regione ha un solo ingresso o più ingressi?
12. Quanta parte di ogni regione è nascosta dal gating?

Poi un giro di 10–15 domande per ogni regione (US-8B13..17).

## 6. Fuori scope
- Nemici per regione (decisione 3: PRD a parte).
- Audio.
- Generazione del mondo a runtime: mai. Il gioco carica solo dati salvati.

## 7. Definition of done
Come da `CLAUDE.md`, più: **le risposte alle domande sono scritte nella story**.
