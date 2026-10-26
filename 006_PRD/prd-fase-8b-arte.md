# PRD: Fase 8b — Arte completa (64 px, generata con sprite-forge)

> Scritto il 2026-10-13 dopo l'inventario completo degli asset mancanti
> (sessione Claude Code). Regole d'arte: `CLAUDE.md` v2, sezione "Arte e asset".
> Questo PRD **non** sostituisce `prd-fase-8-vertical-slice.md`: lo affianca.
> Le story qui hanno id `US-8B..` per non collidere con `US-801..814`.

## 0. Stato al 2026-10-26

Dettaglio di ogni story in `progress.txt` (cerca la sigla); le aperte sono anche in `prd.json`.

| Story | Stato | Note |
|---|---|---|
| US-8B01 64 px | fatta | `dimensione_frame` [64, 64] |
| US-8B10, 8B11a-d, 8B13, 8B13b, 8B14-18 rifiniture, 8B18b isole | fatte | mondo generato (seed 6), due modalita' luminosa/cupa |
| US-8B12 loader del mondo unico | fatta | `scripts/world/mondo.gd` (non `sprite_forge_world.gd`): tessere composte in Python, blocchi attorno al giocatore |
| US-8B12b regione dalla posizione | fatta | `regioni.png`, `regions.json` `luoghi_mondo` |
| US-8B12c il gioco parte dal mondo unico | fatta | NPC, gating d'ingresso, viaggio veloce |
| US-8B12d aspetto degli NPC | fatta | `tools/art/build_npc.py`, 16 aspetti, `roster.json` `aspetto.sprite` |
| US-8B12e collisioni, Marche solo volando o dal sottosuolo | fatta | `blocchi.png` 0/128/255, `regions.json` `accesso` |
| US-8B12f sottosuolo nel gioco | fatta | secondo livello, 47 ingressi, dalle fogne alle catacombe delle Marche |
| US-8B12g contenuto dei layout sul mondo | fatta | nemici, boss e oggetti delle fasi 8-11; il boss di Mirwada nelle fogne |
| US-8B30, 8B31, 8B32 personaggi, nemico, pet a 64 px | fatte | `tools/art/build_personaggi.py` |
| US-8B33, 8B34 NPC con nome, generici, antagonista | fatte (idle + walk) | dentro US-8B12d |
| US-8B73 pagine del libro | fatta | cuoio, pergamena, font Alegreya, `book.json` `tema` |
| US-8B18 edifici e oggetti di scena | **aperta, la prossima** | case sugli isolati di Mirwada, villaggi, porte verso gli interni |
| US-8B12c interni separati (testo originale) | aperta | gli interni delle fasi 10-11 esistono: manca l'ingresso dal mondo generato (va con US-8B18) |
| US-8B21a/b varchi come ingressi verso le sotto-aree | aperta, **la prossima** | decisa il 2026-10-26 |
| US-8B91 barca dal porto | aperta | decisa il 2026-10-26 |
| US-8B93 volo da una chiave del mondo | aperta | decisa il 2026-10-26; il meccanismo (strato dei dislivelli) c'e' |
| US-8B95 accesso alla Frontiera | aperta | decisa il 2026-10-26: barca, volo, soglia del faro con chiave |
| US-8B02, 8B03, 8B19, 8B20, 8B22-24, 8B35, 8B40-44, 8B50-65, 8B70-72, 8B74, 8B80-81, 8B90, 8B92, 8B94 | aperte | |

Decisioni nuove: **Marche solo volando o dal sottosuolo** (2026-10-25); **merge della PR #4** nella PR #5
con il mondo generato come scena di gioco (2026-10-25).

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

### Struttura del mondo (US-8B10, 16 risposte, 2026-10-13)

| Tema | Decisione |
|---|---|
| Forma | **Mondo unico collegato**: le regioni confinano, niente caricamenti tra l'una e l'altra |
| Eccezione | **Archivio Sepolto tutto al chiuso**: mappa interna separata, collegata al mondo da un ingresso |
| Dimensione | Regioni **grandi**, 15–20 schermate ciascuna (~100×60 tile a 64 px) |
| Clima | Gradiente: **nord freddo, sud caldo** |
| Mare | Mirwada è un **porto sul mare**; nel mare ci sono **isole da esplorare** in barca |
| Disposizione | La propone Claude, l'utente la corregge su una mappa di prova |
| Confini | **Naturali** (bosco che si dirada, salita, fiume); varchi `AreaGate` solo dove serve |
| Ingressi | **Uno principale** per regione + 1–2 **segreti** |
| Chiuso all'inizio | **Poco, ~15%** per regione (segreti e siti rituali) |
| Movimento | **Nuoto, barca, arrampicata, volo libero**, tutti **da sbloccare** (chiavi del mondo, condizioni di `AreaGate`) |
| Base | **Si sceglie e si sposta** tra 4 luoghi: casa a Mirwada, rifugio nelle Marche, capanna nella Valle, **nave** |
| Vegetazione | **Diversa per regione** |

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
rigenerati a 64. *Domande (S): conferma 1280×720.* **FATTA (2026-10-14):** unità di gioco
invariate (32 per tile), disegno a 1280×720 con `canvas_items` scala 2, Full HD con bordo nero.

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

**US-8B11 spezzata in 4 (2026-10-13):** **8B11a** motivi nuovi + ritocchi di erba,
acqua e neve + tavola dei campioni (FATTA); **8B11b** terreni di Mirwada (8);
**8B11c** Marche + Valle (9); **8B11d** Archivio + Frontiera + isole (10).
Le risposte dell'utente sui 27 terreni sono in `progress.txt`.

**US-8B11 [A] Terreni nuovi.** Dai biomi di US-8B10 escono i terreni che
`terrain.py` non ha ancora (es. selciato, brughiera, cenere, pavimento
d'archivio, nebbia). Uno per riga in `ORDER`, rampe Endesga 32, 16 tile
dual-grid ciascuno, a 64 px. *Domande (M) per ogni terreno nuovo.*

**US-8B12 [C] Loader del mondo unico.** `scripts/world/sprite_forge_world.gd`
(da `engines/godot/`) carica **un solo** `assets/world/world.json` al posto
delle 5 scene-rettangolo 48×36. Collisioni e `AreaGate` restano dati.
**US-8B12b [C] Regione corrente dalla posizione.** Oggi la regione è "la scena
caricata"; nel mondo unico diventa "l'area in cui sta il giocatore" (una
maschera di regioni dentro `world.json`). Zona musica, densità mistica e
gating la leggono da lì. Probabile story da spezzare: si valuta quando la si
spiega.
**US-8B12c [C] Interni separati.** L'Archivio Sepolto (e ogni altro interno
deciso nei giri per regione) è una mappa a sé, collegata al mondo da un
ingresso con ritorno al punto di partenza.

**US-8B13 [D+A] Mappa di prova del mondo intero.** Disposizione delle 5 regioni
e delle isole (proposta di Claude, §5), generata **grezza** dal seed con una
maschera per regione, guardata con l'utente e corretta. Solo dopo il via si
passa alle regioni una per una.

**US-8B14..18 [A] Rifinitura di una regione per story.** Ordine: `mirwada`,
`marche_crepuscolo`, `valle_madre`, `archivio_sepolto` (interno),
`frontiera_porte`. Ognuna: preset di bioma → generazione dal seed → ritocco
**nei dati** → anteprima ingrandita guardata → `world.json` + atlanti committati.
Ogni `location_tag` della regione deve esistere a schermo. Ingresso principale,
1–2 passaggi segreti, ~15% chiuso.
*Domande (XL) per ogni regione: 10–15.*

**Mirwada — decisa (12 risposte, 2026-10-13).** Stile misto: centro antico in
pietra chiara sulla collina, quartiere operaio industriale e porto con
ciminiere in basso. Mura vecchie in rovina, città cresciuta fuori. Metà città,
metà campagna. Grande porto commerciale (moli, navi a vapore e vela, gru,
magazzini, dogana, cantiere). Archivio dell'ordine minore fuori le mura (ex
monastero). Campagna: uliveti e vigneti, fattorie e mulini, cimitero
monumentale, faro e scogliere, piccole caverne con forzieri e mostri, casette
con oggetti casuali. Casa-base vicino al porto. Monumento: il faro. Notte:
lampioni a gas. Fogne: grande livello interno, ingressi da tombini, sbocco sul
mare e cantine segrete. Verde: poco in città, tanto fuori.

**Marche del Crepuscolo — decise (12 risposte, 2026-10-13).** Ciclo giorno/notte
normale con toni crepuscolari. Altopiano a gradoni: rampe e sentieri sempre,
scale dei giganti e pareti scalabili con l'arrampicata. Campo di battaglia di
giganti (ossa e armi enormi). Cripte miste: mausolei in superficie, solo la
principale scende in un interno. Trono del Gigante scolpito nella montagna sul
gradone più alto (nessuna scritta: fog of war). Vegetazione quasi assente.
Solo eremiti; rifugio-base isolato. Tempio dei giganti. Soglia del Crepuscolo
= voragine con scale nel buio. Ingresso principale: passo tra due rupi.
Passaggi in ombra: ombre troppo scure che non seguono la luce.

**Valle della Madre — decisa (12 risposte, 2026-10-13).** Giungla temperata
(liane, felci giganti, nebbia bassa). Radice del Mondo = albero colossale.
Costa a scogliere con grotte di marea (piccole sulla mappa, la grande è un
interno). Villaggio sugli alberi (capanna-base). Radure lunari nascoste di
giorno. Burroni con fiume (alternativa a nuoto) e senza fondo (radici o volo).
Altare di radici in una radura isolata. Ingresso principale: galleria di
alberi. Sorgenti a cascata. Zone delle bestie profonde segnate da ossa e graffi.

**Archivio Sepolto — deciso (12 risposte, 2026-10-13).** In superficie una
pianura bianca vuota con la scalinata scavata e la torre di osservazione che
spunta dalla neve. Dentro, 5 piani a mappe separate: sale di lettura, studi,
officine meccaniche, sala dei sigilli, Biblioteca di Tutto (sfera di libri
con passerelle). Stile misto barocco + meccanico. Luce da cristalli e glifi.
Porte sigillate con glifi. Tra i piani solo montacarichi da riattivare e
pozzi/crolli (si scende senza ritorno: il level design deve garantire che non
si resti bloccati). Libri, costrutti dormienti, forzieri, fantasmi di studiosi.

**Frontiera delle Porte — decisa (12 risposte, 2026-10-13).** Isola nel mare a
sud, nascosta dalla nebbia: la si vede bene solo col cannocchiale. Isola
d'arrivo normale (molo in barca, atterraggio libero in volo), poi l'arcipelago
di 5–6 isolette sospese nella nebbia, collegate da porte. Colori pastello
sbiaditi. Teatro dei burattini; la Porta senza Stanza è una porta di scena sul
palco. Crocevia di strade sospese che finiscono in porte. Zone sbagliate:
oggetti sospesi, riflessi sbagliati, glitch visivi, tempo fermo. Burattini e
manichini innocui. Soglia = bordo di un'isoletta sulla nebbia.

**US-8B18b [A] Isole — decise (6 risposte, 2026-10-13).** 6 isole piccole oltre
alla Frontiera, clima diverso per isola: Relitto (rocciosa, nave naufragata,
forzieri), Vulcanica (cenere, ingredienti di fuoco), Tropicale (laguna,
villaggio di pescatori), Rovine (culto antico, indizi sulla Frontiera), Scoglio
del Faro abbandonato (un eremita), **Isola del Boss** (nascosta, si trova solo
con un indizio; il boss comanda mostri più piccoli che muoiono con lui:
meccanica da decidere nel PRD dei nemici). Barca libera + volo tra isole vicine.

**US-8B18 [A+C] Edifici e oggetti di scena.** Il generatore oggi non fa edifici
né ponti veri: estensione di `forge3d` (case, ponti, templi, torre, scaffali,
altari, rovine). Story a sé, poi si rigenerano le regioni con lo stesso seed.
*Domande (L).*

**US-8B19 [A] Siti unici.** `trono_del_gigante`, `biblioteca_di_tutto`,
`radice_del_mondo`, `porta_senza_stanza`: un pezzo di mappa costruito apposta.
*Domande (L) per ognuno.*

**US-8B20 [A] Base del giocatore.** 4 stanze (`laboratorio`, `stanza_rituale`,
`biblioteca`, `giardino`) e 3 strutture (`palizzata`, `totem_veglia`, `deposito`),
in 4 versioni di luogo: casa a Mirwada, rifugio nelle Marche, capanna nella
Valle, nave. *Domande (L).*

**US-8B21 [A] Varchi di gating visibili.** Un aspetto per ognuno dei 6 tipi in
`gate_types.json` (ombra, radici, porta sigillata, ...). Il giocatore deve capire
*che* c'è un varco, non *come* si apre.
*Deciso il 2026-10-26:* ogni sotto-area è un **ingresso** sulla mappa verso un interno; il varco decide se si
apre, la mappa approvata non cambia; i ponti di radici sono un ponte che compare sul burrone. Spezzata in
**8B21a** (ingressi, aspetto chiuso/aperto, interni) e **8B21b** (contenuto delle zone dentro gli interni, arte).

**US-8B22 [C+D] Forzieri e oggetti casuali.** Richiesta dell'utente per Mirwada
(caverne con forzieri, casette con oggetti casuali). Oggi **non esiste** un
sistema di bottino: servono un oggetto di scena "forziere" e tabelle di bottino
nei dati (quali oggetti, con che probabilità, una volta sola o rigenerati).
Story di codice: spiegarla prima. *Domande (M).*

**US-8B23 [C+A] Fauna d'atmosfera.** Richiesta per la Valle (vale poi per tutto
il mondo): uccelli e farfalle che volano via quando passi, cervi e animali
grandi che pascolano e scappano, lucciole di notte (VFX). Non sono nemici né
pet: niente combattimento, solo un comportamento "fuggi dal giocatore" letto
dai dati. Story di codice + arte: spiegarla prima. *Domande (M).*

**US-8B24 [C+A] Cannocchiale.** Richiesta per la Frontiera: un cannocchiale fisso
in cima al faro di Mirwada (il primo) e più avanti uno da tasca. Usandolo la
camera si sposta lontano e la nebbia si dirada. Il punto panoramico e il
bersaglio stanno nei dati della mappa. *Domande (M).*

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
rottura della postura). **FATTA in parte (2026-10-26)**: `vfx_slash`, `vfx_bolt` (il proiettile in volo, prima
invisibile) con `vfx_bolt_scoppio`, `vfx_streak` in `tools/art/build_vfx.py`, colorati dalla rampa; il feedback del
colpo resta da fare.
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

**US-8B70 [A] 39 icone oggetto. S ciascuna.** **FATTA (2026-10-26)**: un'icona per ognuno dei 353 oggetti, da 44 forme
(`forge3d/icone.py`) e una tinta; 141 icone usate in `assets/icone/oggetti/`, abbinamento in `data/ui/icone.json`
(`tools/art/build_icone.py`), a terra con l'ombra e nello zaino.
**US-8B71 [A] 14 icone di stato. S.** **FATTA (2026-10-26)**: griglie 16x16 in `tools/art/build_stati.py`, bordo dal campo
`negativo`; nel gioco in fila sopra la testa di giocatore e nemici (`scripts/status_icons.gd`).
**US-8B72 [A] 27 icone di primitiva** (colorate dallo shader come i VFX). **FATTA (2026-10-26)**: 28 glifi (le primitive attive sono 28) a 4 toni in
`tools/art/build_primitive.py`, colorati da `shaders/rampa_pathway.gdshader` con la palette di `data/vfx.json`;
nella hotbar davanti al nome dell'abilita'.
**US-8B73 [A] Pagine del libro. M per pagina.** Le 9 pagine di `data/ui/book.json`,
i segnalibri, la voltata, le macchie, la pagina "follia".
**US-8B74 [A] Panorami. L.** Schermata iniziale e libro: 6 strati × 4 fasce orarie.

### Blocco G — Animazioni nuove di Enel

**US-8B80 [D+A]** interagire, raccogliere, bere, rituale (prima la voce in
`animations.json`, poi lo sheet).
**US-8B81 [D+A]** nuoto, arrampicata, volo, in barca (servono a Blocco H).

### Blocco H — Movimento e base mobile (nuovo, da US-8B10)

Sono **sistemi di gioco**, non solo arte: ognuno va spiegato prima, con il
diff stimato, e spezzato se supera i limiti della regola 3. Ogni movimento
è una **chiave del mondo**: si sblocca, e `AreaGate` lo usa come condizione
(un tipo nuovo in `gate_types.json`, o una condizione dei tipi esistenti: si
decide spiegandolo).

**US-8B90 [C+A] Nuoto.** Acqua bassa percorribile, acqua profonda solo con lo
sblocco. *Domande (M).*
**US-8B91 [C+A] Barca.** Salire/scendere al molo, navigare il mare, raggiungere
le isole. *Deciso il 2026-10-26:* barca libera al molo di Mirwada, in barca l'acqua si attraversa, si sbarca
sulle coste. **US-8B95 Accesso alla Frontiera** (2026-10-26): in barca, volando, o da una soglia nel faro che si
apre solo con una chiave trovata nel mondo.
**US-8B92 [C+A] Arrampicata.** Pareti e scale scalabili segnate nei dati della
mappa. *Domande (M).*
**US-8B93 [C+A] Volo libero.** Il più grosso: altezza, ombra a terra, cosa si
scavalca, dove si atterra, costo. Quasi certamente 2–3 story. *Deciso il 2026-10-26:* si sblocca con una chiave
del mondo (oggetto o luogo da trovare), per tutti i Pathway, niente primitive nuove.
**US-8B94 [C] Base sceglibile e spostabile.** I 4 luoghi, come si sceglie, cosa
succede alle stanze quando si sposta, la nave come base mobile. *Domande (L).*

## 4b. Mondo ingrandito: x3 + C + D (decisione 2026-10-14)

Il mondo di prova (320x220 tile, ~210 schermate di terra) e' troppo piccolo per
l'utente. Scelta: **mondo di base x3 (960x660 tile)** piu':
- **terre di mezzo** tra le regioni (zone selvagge di nessun gruppo: nei dati
  restano 5 regioni, le terre di mezzo sono zone dentro le regioni vicine);
- **arcipelago** di isole vere e **Frontiera** come regione vera;
- **sottosuolo collegato** sotto tutte le regioni (fogne, catacombe, grotte,
  miniere) con tanti ingressi.
Stima: ~2.500 schermate sopra + ~1.000 sotto, ~4-5 minuti per attraversarlo.

Story nuove (domande XL prima di ognuna):
- **US-8B13b** mappa di prova x3 con terre di mezzo e arcipelago;
- **US-8B13c** mappa di prova del sottosuolo;
- **US-8B12e [C]** caricamento a pezzi in Godot (blocchi attorno al giocatore)
  e mappe salvate come immagini invece che JSON;
- **US-8B12d [C]** collegamento superficie-sottosuolo nel gioco.

## 5. Disposizione delle regioni (US-8B13) — SCELTA: variante C

Scelta dall'utente il 2026-10-13 guardando lo schizzo di 3 varianti
(A: proposta di Claude, B: Marche e Valle scambiate, C: Frontiera oltre il mare).

```
                 N  (freddo, neve)
   +-------------------------------------------+
   |   MARCHE DEL              ARCHIVIO         |
   |   CREPUSCOLO              SEPOLTO          |
   |   (brughiera, alture,     (ingresso nella  |
   |    vette fredde)           neve, tutto     |
   |                            al chiuso)      |
   |            MIRWADA                         |
   |            (citta' di porto,  VALLE DELLA  |
   |             clima mite)       MADRE        |
   |                               (foresta,    |
   |                                grotte di   |
   |~~~~~~~~~~~~~~~ costa ~~~~~~~~~~ marea) ~~~ |
   |   o isola    o isola   [FRONTIERA]  o isola|
   |                        (isola grande,      |
   |                         nebbia)            |
   +-------------------------------------------+
                 S  (caldo, mare)
```

- **Mirwada** al centro-sud, sul porto: tocca tutte le regioni di terra.
- **Marche del Crepuscolo** a nord-ovest: brughiera fredda, alture, `vetta`.
- **Archivio Sepolto** a nord-est: ingresso nella neve, tutto al chiuso.
- **Valle della Madre** a sud-est, sulla costa (per le `grotta_di_marea`).
- **Frontiera delle Porte** = **isola grande e nebbiosa nel mare a sud**,
  raggiungibile **solo in barca o in volo**. Si vede dal porto fin
  dall'inizio (design-world 2.5: "visibile presto, inaccessibile fino a
  `sequenza_max: 4` circa"): lo sblocco della barca o del volo è il
  gating naturale dell'endgame.
- Le altre isole (piccole) sono quelle di US-8B18b.

Poi un giro di 10–15 domande per ogni regione (US-8B14..18).

## 6. Fuori scope
- Nemici per regione (decisione 3: PRD a parte).
- Audio.
- Generazione del mondo a runtime: mai. Il gioco carica solo dati salvati.

## 7. Definition of done
Come da `CLAUDE.md`, più: **le risposte alle domande sono scritte nella story**.
