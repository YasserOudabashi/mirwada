# Mirwada — Brief per la generazione di immagini con Gemini

Figlio di `design-vfx.md`, `design-world.md`, `design-lore.md`,
`design-npc-quest.md`, `design-ui-libro.md` e `data/animations.json`. Questo
documento **non aggiunge decisioni di design**: raccoglie quelle gia' prese e
le traduce in prompt pronti da incollare in Gemini (Imagen), con parametri,
aspettative realistiche e post-produzione.

---

## 0. Cosa e' questa arte, e cosa non e'

Il PRD di fase 2 (`prd-fase-2-pathway-core.md`, Non-goals) e `design-vfx.md`
cap. 6 sono espliciti: **nessuna arte definitiva in fase 2**, i placeholder
diagnostici di `tools/generate_placeholders.py` restano lo strumento di
lavoro. Quindi:

| Categoria | Cosa serve davvero | Gemini la produce usabile? |
|---|---|---|
| Key art delle 5 regioni | riferimento di atmosfera, palette, silhouette per l'artista e per il mood dei livelli | **Si**. Illustrazione, non pixel art. Entra in `assets/concept/`, mai nel gioco |
| Ritratti degli 8 NPC + protagonista | riferimento di volto, guardaroba, espressione; serve anche ai dialoghi (fase 6) | **Si**, con la riserva della coerenza di serie (cap. 4.1). Riferimento, non asset |
| Arte della UI a libro | texture di pagina, scaffale, bordi, illustrazioni erbario/bestiario | **In parte**. Le texture e le illustrazioni si, gli elementi che servono a pixel esatti vanno rifatti |
| Sprite e tileset di gioco | spritesheet 32x32, 4 direzioni, sfondo trasparente, frame allineati a `animations.json` | **No** come asset drop-in (cap. 6). Si come turnaround di riferimento da ridisegnare |

Regola d'oro: quello che esce da Gemini vive in `assets/concept/<categoria>/`,
**non** in `assets/` ne' in `assets/placeholder/`. E' materiale di
riferimento. La nota IP di `CLAUDE.md` vale: concept "alla maniera di", non
redistribuibile con i nomi attuali.

## 0.1 Come si usano i prompt

- **Lingua del prompt: inglese.** Imagen rende meglio.
- **Un soggetto per immagine.** Niente "le 5 regioni in un collage".
- **Incolla sempre il Blocco di stile (cap. 1) in testa al prompt specifico.**
- **Aspect ratio**: key art 16:9; ritratti 4:5 (mezzobusto) o 1:1; texture di
  pagina 1:1 o 2:3; turnaround sprite 16:9 (personaggio ripetuto).
- **Itera**: genera 4, scegli la silhouette giusta, poi chiedi varianti
  ("same character, same palette, now facing left"). Gemini non ha un seed
  stabile: la coerenza si ottiene ripetendo la descrizione fisica per esteso
  ogni volta.
- **Palette**: i valori esadecimali qui sotto sono **proposti**. Vanno
  riconciliati con `data/vfx.json` quando nasce (US-226). Se US-226 e' gia'
  chiusa, prendi i valori da li' e ignora la tabella del cap. 2.

---

## 1. Blocco di stile comune (incollare in testa a OGNI prompt di illustrazione)

```
STYLE: Ink-and-brush illustration in the manner of modern Korean action
manhwa (e.g. Legend of the Northern Blade): heavy solid black fills, thick
loaded brush lines with irregular, tapering ends, bold negative space, high
contrast, sparse rendering — shape and silhouette carry the image, not
texture. Limited muted palette, three colours plus black. Gritty early-20th-
century gaslamp-fantasy setting (gas lamps, soot, brick, wool coats, fog).
Painterly and graphic, hand-drawn feel. Cinematic composition.

DO NOT: photorealism, 3D render, plastic skin, anime chibi / cute style,
flat vector, glossy digital gradients, colour banding, lens flare, bloom,
modern clothing, bright saturated cartoon colours, on-image text, watermark,
signature, logo, UI elements, decorative border/frame.
```

Per gli sprite (cap. 6) il blocco di stile e' diverso ed e' scritto li'.

---

## 2. Palette per Pathway (proposta — da fissare in `data/vfx.json`, US-226)

`design-vfx.md` cap. 2 fissa la regola: **inchiostro scurissimo + UN primario
+ UN accento**, mai un quarto colore. Ecco una proposta di valori concreti,
coerente con le descrizioni gia' scritte (materiale audio, tratto):

| Pathway | Inchiostro | Primario | Accento | Tratto (firma) |
|---|---|---|---|---|
| twilight_giant | `#0A0A0F` | oro `#E8C34A` | bianco caldo `#FFF6D8` | pennellata piena, pesante, dritta |
| death | `#0C0F0C` | verde osso `#B8C9A8` | grigio freddo `#8A93A0` | pennellata secca, spezzata come ossa |
| darkness | `#08080C` | nero-viola `#241B33` | (nessuno) `#3A2F4D` | assenza di scia: la forma sparisce |
| fool | seppia-nero `#2B211A` | rosso teatro `#B4302A` | crema `#EFE2C4` | doppio segno, una cosa e la sua finta |
| error | `#0A0B0D` | ciano tagliente `#37C9D6` | bianco `#FFFFFF` | schegge, segmenti spigolosi interrotti |
| door | blu notte `#0D1326` | viola profondo `#5B3A8C` | argento `#C9D2DA` | archi e anelli, mai linee dritte |
| hermit | `#0D0B08` | ambra `#E0A44B` | azzurro cristallo `#8FD4E8` | il tratto disegna glifi e sigilli |
| paragon | `#0C0A08` | rame `#B87333` | ottone chiaro `#D9B87A` | linee parallele, angoli netti, meccanico |
| mother | terra scura `#1A130D` | verde linfa `#6FA84B` | fiore chiaro `#F2E7D8` | il tratto germoglia dal punto d'origine |
| moon | blu abisso `#0A1020` | argento lunare `#C0C7CF` | rosso sangue `#8E1F2B` | curve continue e fluide, come acqua |

---

## 3. Key art delle 5 regioni

Da `design-world.md`. Ogni regione e' anche il terzo canale dell'identita' di
un gruppo di Pathway (`design-master` principio 2): la palette della regione
e' quella del gruppo. Formato: **16:9, illustrazione, niente pixel art**.

### 3.1 Mirwada — la citta' (hub, neutra)

**Setting**: citta' portuale d'inizio Novecento, densita' mistica bassa: qui
il potere *si nota*. Porto, quartiere operaio, mercato, l'archivio di un
ordine minore. Vicoli e tetti con verticalita' leggera. Nebbia, lampioni a
gas, ciottolato bagnato, mattone annerito, fumo di camini.
**Palette**: neutra — ardesia desaturata, mattone bruno-rosso, ambra dei
lampioni, grigio nebbia. Nessun colore di Pathway domina.
**Da mostrare**: `porto`, `vicolo`, `piazza`; un tetto da cui si vede il
porto sotto la nebbia.

```
[STYLE BLOCK]
Wide establishing shot of a foggy early-20th-century harbour city at dusk.
Narrow cobblestone alleys between soot-stained brick tenements, gas street
lamps glowing amber through mist, wet stone reflecting the light, chimney
smoke, laundry lines overhead, a distant harbour with masts and cranes below.
Low rooftops, gentle verticality. No people or one tiny distant silhouette.
Mood: ordinary, working-class, watchful — a place where using magic would be
noticed. Palette: desaturated slate grey, brick red-brown, amber lamplight,
fog grey. Aspect 16:9.
```
Varianti: "the port at night, smugglers' boats, no lamps"; "the working-class
quarter, washing lines, a child's chalk drawing on the wall"; "the sealed
door of a small archive, stone, iron bands".

### 3.2 Marche del Crepuscolo — eternal_darkness (Twilight Giant, Darkness, Death)

**Setting**: brughiera in un tramonto che non finisce. Campi di battaglia
antichi con armi spezzate conficcate nel fango, cripte, rovine, alture, una
vetta lontana, un tempio abbandonato. Orizzonte basso, ombre lunghissime,
silhouette nere contro il cielo.
**Palette**: eternal_darkness — orizzonte arancio bruciato `#C25A2E`, cielo
viola-blu profondo, silhouette in nero pieno, accenti oro (Twilight Giant).
**Da mostrare**: `luogo_di_battaglia`, `altura`, `rovina`, `cripta`,
`tempio_abbandonato`, `vetta`; in una key art separata il `trono_del_gigante`
(sito unico del rituale di Sequenza 0).

```
[STYLE BLOCK]
Wide desolate moorland under an endless burnt-orange sunset that never ends.
Ancient battlefield: broken spears and rusted blades half-sunk in black mud,
scattered bones, tattered banners. Long raking shadows, a low horizon, black
silhouettes of ruined arches and a distant mountain peak against the violet
sky. A crumbling abandoned temple on a rise. Heavy solid blacks, gold rim
light on the ruins. No living figures. Mood: aftermath, weight, the tail end
of something enormous. Palette: burnt orange horizon, deep violet-blue sky,
full black silhouettes, gold accents. Aspect 16:9.
```
Variante chiave: "a colossal weathered stone throne on a windswept summit,
seen from below, twilight behind it, gold light catching the edge — the seat
of a giant, empty".

### 3.3 Valle della Madre — goddess_of_origin (Mother, Moon)

**Setting**: foresta antica e fitta (visuale corta, il suono conta piu' della
vista), radure lunari dove di notte con la luna giusta fioriscono cose rare,
grotte di marea che si aprono con la luna piena o nuova, sorgenti di
guarigione, un altare di radici.
**Palette**: verde linfa `#6FA84B`, argento lunare `#C0C7CF`, rosso sangue dei
fiori rari `#8E1F2B`, ombra di bosco profonda.
**Da mostrare**: `bosco_antico`, `radura_lunare`, `grotta_di_marea`,
`sorgente`, `altare_di_radici`.

```
[STYLE BLOCK]
Deep ancient forest at night, enormous moss-covered trunks crowding close,
canopy almost sealed, shafts of silver moonlight. A small clearing opens: the
grass is pale and a few blood-red flowers bloom in a ring around a low altar
made of woven living roots. Mist near the ground. Short sightlines, the woods
press in. Mood: fertile, old, patient, slightly threatening. Palette: sap
green, deep forest shadow, lunar silver, one note of blood red. Aspect 16:9.
```
Varianti: "a tide cave mouth revealed at low water under a full moon, wet
rock, phosphorescent pools"; "a healing spring, clear water over pale stone,
ferns".

### 3.4 Archivio Sepolto — demon_of_knowledge (Hermit, Paragon)

**Setting**: una citta' di studiosi collassata e sepolta. Sale di biblioteca
sprofondate con scaffali inclinati e libri a terra, officine meccaniche ferme
con ingranaggi enormi e costrutti dormienti, torri d'osservazione con volte
crepate aperte sul cielo, una sala dei sigilli con porte incise. Polvere
sospesa, luce di lampada ad ambra, un bagliore azzurro cristallo dai
meccanismi.
**Palette**: ambra `#E0A44B`, rame `#B87333`, azzurro cristallo `#8FD4E8`,
marroni profondi, polvere.
**Da mostrare**: `biblioteca`, `officina`, `torre_di_osservazione`,
`sala_dei_sigilli`, `studio`.

```
[STYLE BLOCK]
The collapsed underground library of a lost city of scholars. Vast tilted
bookshelves, a sea of fallen books and scrolls, a caved-in ceiling letting a
single shaft of light down through dust. To one side a stopped mechanical
workshop: giant bronze cogs, a dormant humanoid construct slumped against the
wall, faint crystal-blue light in its chest. Sealed stone doors carved with
sigils. Amber lamplight, copper machinery, drifting dust. Mood: knowledge
hoarded and abandoned, a puzzle waiting. Palette: amber, copper, crystal
blue, deep brown. Aspect 16:9.
```
Varianti: "an observation tower, cracked dome open to a sky full of
constellations, a broken brass orrery"; "the hall of seals, rows of engraved
doors, one glowing".

### 3.5 Frontiera delle Porte — lord_of_mysteries (Fool, Error, Door)

**Setting**: la regione di endgame. Nebbia grigia in cui galleggiano isole di
terreno collegate solo da soglie e porte isolate. Un teatro abbandonato dove
gli oggetti recitano se stessi, un palco che e' un luogo rituale, un crocevia
di strade che non portano dove dovrebbero. Zone dove le regole locali sono
sbagliate (gravita', riflessi, tempo). Spazio non euclideo: prospettive che
non chiudono.
**Palette**: nebbia grigia `#9A9CA0` che spegne tutto, rosso teatro `#B4302A`,
viola profondo `#5B3A8C`, argento-ciano freddo. Basso contrasto tranne il
rosso.
**Da mostrare**: `nebbia_grigia`, `teatro`, `palco`, `crocevia`, `soglia`.

```
[STYLE BLOCK]
A grey featureless fog with no horizon. Islands of dark earth float at
different heights, connected only by isolated freestanding doorframes and a
few stone thresholds standing in mid-air. In the middle distance an abandoned
theatre: rows of empty seats facing a lit stage where a single chair sits
under a red spotlight with no one in it. Roads that bend wrongly and stop.
Non-euclidean perspective, lines that don't resolve. Everything desaturated
except the theatre red. Mood: unreal, staged, the edge of the world. Palette:
grey fog, theatre red, deep violet, cold silver. Aspect 16:9.
```
Varianti: "a single doorframe standing alone in grey fog, light of a
different colour spilling from the other side"; "a crossroads where each road
leads into fog at a wrong angle".

---

## 4. Ritratti — protagonista + 8 NPC

Da `design-lore.md` e `design-npc-quest.md`. Formato: **4:5 mezzobusto** o
**1:1**. Servono come riferimento per l'artista e, in fase 6, per i ritratti
di dialogo.

Le descrizioni fisiche qui sotto sono **proposte**. `design-lore.md` dichiara
Mirco e Sidon richiesti dall'utente e gli altri sei rinegoziabili: trattare
ogni riga come un default sostituibile, non come canone.

**Mirco e Sidon: provvisori, da rifare.** L'utente decide lui l'aspetto di
questi due. Le righe in tabella servono solo a non lasciare buchi nel set di
riferimento: vanno rigenerate quando l'utente fissa i loro volti. Non
considerarle canoniche in nessun caso.

### 4.1 Coerenza di serie

Gemini non tiene un personaggio identico tra un'immagine e l'altra. Per una
serie coerente:
1. incolla lo stesso Blocco di stile;
2. ripeti **tutta** la descrizione fisica ogni volta (eta', corporatura,
   capelli, viso, guardaroba), non "lo stesso di prima";
3. genera tutti i ritratti nella stessa sessione, di seguito;
4. fissa 2-3 costanti di scena identiche per tutti (sfondo neutro grigio
   carta, luce da sinistra, mezzobusto, sguardo verso l'osservatore) cosi'
   che il set sembri una tavola di personaggi unica.

### 4.2 Prompt base del ritratto (riempi `[…]`)

```
[STYLE BLOCK]
Character portrait, bust, three-quarter view, subject looking toward the
viewer. Neutral warm-grey paper background, single soft light from the left.
Ink-and-brush manhwa style: strong black shapes, few lines, restrained
colour. Early-20th-century working-class / lower-middle-class clothing, worn,
practical. No weapons drawn, no magic effects, no text.

SUBJECT: [età] year old [gender], [corporatura]. [capelli]. [tratto del
viso più forte]. Wearing [guardaroba]. Expression: [espressione] — [una riga
sul carattere]. Palette: black, warm grey, [un colore di accento].
Aspect 4:5.
```

### 4.3 Il cast

| id | Descrizione da incollare in SUBJECT | Accento |
|---|---|---|
| **Enel** (protagonista, nome di default, rinominabile) | 30-ish, average build, a factory/dock worker. Short dark hair, tired eyes, three-day stubble. Wearing a patched wool coat over work clothes, a flat cap in hand. Expression: guarded, exhausted, a flicker of something colder underneath — an ordinary man on the first step of becoming something else | freddo, grigio-oro molto tenue |
| **npc_mirco** *(richiesto dall'utente — confermare)* | 40s, broad and solid, a foreman's warmth. Greying beard, deep smile lines, one hand always half-raised as if to explain. Heavy canvas apron over a flannel shirt. Expression: open, encouraging, the first friendly face — teaches by showing | ambra calda |
| **npc_sidon** *(richiesto dall'utente — confermare)* | 50s, lean, stooped, quick-eyed. Thin grey hair combed back, a merchant's ringed fingers, a small scale hanging from his belt. Long dark coat with many pockets, a scarf. Expression: pleasant on the surface, calculating underneath — knows more than he says | verde bottiglia |
| **npc_vesna** | 60s, weathered, upright. White hair in a tight knot, strong hands, an apron stained with herbs and iodine. Shawl over a plain dress. Expression: wary, unsmiling, measuring you — a healer who does not trust what you are becoming | verde salvia spento |
| **npc_aldo** | 30-ish like Enel, once a coworker. Same class of clothes but newer, a little too clean, a new coat. Slicked hair, a strained confident smile. Expression: friendly and competitive at once — climbing the same ladder, faster, and wants you to see it | rosso mattone |
| **npc_ottavia** | 40s, precise, buttoned-up. Dark hair pinned severely, small round spectacles, ink on her fingers. A high-collared archivist's coat, a ring of keys. Expression: cool, assessing, a gatekeeper deciding whether you may read | ambra fredda / carta |
| **npc_bruno** | 40s, heavyset, dockhand's shoulders, a broken nose. Stubble, a knitted cap, a pea coat, a coil of rope over one shoulder. Expression: unbothered, transactional, glances past you at who might be watching | blu porto |
| **npc_lena** | a child, 8-9, small, from the working-class quarter. Messy hair, a hand-me-down coat too big for her, scuffed boots, chalk dust on her fingers. Expression: bright, open, completely unaware of what you are — the most fragile thing you have left | crema chiara |
| **npc_doran** | 40s, tall, still. Sharp features, close-cropped greying hair, a long grey investigator's coat, a notebook in one hand. Expression: patient, unhurried, certain — he is already following your tracks and both of you know it | grigio acciaio |

Nota narrativa (`design-npc-quest.md`): serviranno anche **popolani generici**
(`npc_generic_*`, senza dialogo profondo) per le recitazioni "aiuta 8 NPC" /
"inganna 10". Un singolo prompt con 3-4 varianti di popolano anonimo basta
come riferimento.

---

## 5. Arte della UI a libro

Da `design-ui-libro.md`. Il libro **e'** il salvataggio, ed e' diegetico:
serve arte di un libro vero, non di un menu. Base 640x360 → una pagina e'
circa **320x360** px. Le texture vanno in `assets/concept/ui/` come
riferimento; le versioni finali usabili come texture (tileabili, dimensioni
esatte, canale alpha) si ritagliano a mano da li'.

### 5.1 Lo scaffale dei tomi (pagina `menu_principale`)

```
[STYLE BLOCK]
A dark wooden bookshelf seen straight on, filling the frame. Several thick
leather-bound tomes standing and stacked, each slightly different — different
wear, different clasps, different coloured ribbons — so each reads as a
separate saved life. One slot is empty (a new book waiting). One tome is
visibly burnt: charred spine, warped cover, still shelved, not destroyed.
Warm low light, deep shadow between the books. No text, no titles on the
spines. Mood: a quiet archive of lives. Aspect 3:2.
```

### 5.2 Texture di pagina — pulita e macchiata di follia

Due immagini, stessa inquadratura:

```
[STYLE BLOCK — but flat, no character]
Top-down flat scan of a single blank page of an old handmade book. Thick
cream rag paper, deckle edge, faint horizontal laid lines, a few foxing
spots, the ghost of a previous page's ink. Even soft light, no perspective.
Nothing printed on it. Aspect 2:3.
```
Variante follia (`design-ui-libro.md` cap. 1): "the same page but the edges
are darkened as if scorched from the margin inward, and cramped handwritten
notes in a nervous unfamiliar hand crawl up the outer margin — illegible,
menacing, in brown-black ink".

### 5.3 Bordi, segnalibri, cornici di pagina

```
[STYLE BLOCK — flat, graphic]
A set of hand-inked page decorations on transparent/white: a plain thick
rule frame with slightly broken brush edges; three cloth bookmark ribbons
hanging from a top edge, frayed ends, muted red / muted blue / muted gold;
a small corner flourish. Sparse, asymmetric, hand-drawn, not ornate
Victorian filigree. Black ink only. Aspect 1:1.
```

### 5.4 Illustrazioni erbario / bestiario (pagina `inventario`, fase 3)

Riferimento di stile per come sono disegnati gli oggetti nel libro:

```
[STYLE BLOCK]
A single naturalist's plate as it would appear handwritten in an old field
journal: one alchemical ingredient (a twisted pale root / a phosphorescent
mushroom / a shard of a Beyonder characteristic) drawn in brown ink with
light wash, a few callout lines pointing to details, blank space where
handwritten labels would go (leave the labels empty). Aged paper. Aspect 1:1.
```

### 5.5 Il frontespizio (pagina `creazione_personaggio`)

```
[STYLE BLOCK]
The title page of a handmade book. Centre: a wide blank ruled line where a
name would be written, with the name "Enel" lightly pencilled in, as a
suggestion not a stamp. Above it, room for a hand-inked title (leave blank).
Cream paper, one pressed flower or a thumbprint in the corner. Nothing else.
Aspect 2:3.
```

### 5.6 I frame della voltata di pagina

`design-ui-libro.md` cap. 3: 2D, 3-4 frame di curvatura + un'ombra che
attraversa la piega. Chiedi a Gemini una **strip di 4 pose**, sapendo che va
comunque ridisegnata:

```
[STYLE BLOCK — flat, graphic]
A 4-step sequence, left to right, of a single book page turning: (1) flat,
(2) lifting at the outer edge with a soft shadow starting to cross it,
(3) curled halfway, vertical, a hard shadow down the fold, (4) almost fallen
to the other side. Same page, same lighting, side view, plain background.
Black ink and one grey. Aspect 16:9.
```

---

## 6. Sprite e tileset — con i limiti dichiarati

### 6.1 Perche' Gemini non li produce come asset

`data/animations.json` fissa: frame **32x32**, **4 direzioni**
(down/up/left/right, le diagonali riusano l'orizzontale), origine
`piedi_centro`, e ogni animazione ha un numero di frame preciso con indici
che il codice usa (`attack_light`: anticipo [0,1], attivi [2], recupero
[3,4]; `dash`: iframe [0..2]). Un generatore di immagini non produce:

- una griglia a passo esatto di 32 px con i frame allineati;
- lo stesso personaggio coerente su 4 direzioni e decine di frame;
- sfondo trasparente pulito;
- frame agganciati agli indici di anticipo/attivi/recupero.

Quindi l'output di Gemini qui e' **turnaround di riferimento**, da cui un
pixel artist (o tu) ridisegna gli sprite veri. Non si risparmia lavoro di
sprite; si fissa il look.

### 6.2 Blocco di stile per pixel art (sostituisce il cap. 1)

```
STYLE: 2D pixel art, low resolution, top-down action-RPG, ~32x32 px
character proportions, limited palette (black outline + 3 colours), hard
2px black outline, no anti-aliasing, no gradients, readable silhouette.
Manhwa-influenced: heavy blacks, one accent colour. Plain flat background
(single solid colour, not transparent — describe it as "plain magenta
background" for easy keying).
DO NOT: high resolution, painterly, smooth shading, 3D, isometric, text.
```

### 6.3 Turnaround del personaggio (Enel)

```
[PIXEL STYLE BLOCK]
Character reference sheet of the same 30-ish worker in a patched wool coat
and flat cap, shown in four separate poses on one row: facing down (toward
camera), facing up (back), facing left, facing right. Identical character in
all four, neutral standing idle. Plain flat magenta background. Pixel art,
~32x32 proportions, 2px black outline, palette black + slate blue + grey +
one warm accent. Aspect 16:9.
```
Poi, separatamente: "same character, facing down, mid dash, leaning
forward", "same character, facing right, light attack swing" — sapendo che i
5-8 frame veri vanno disegnati a mano dagli indici di `animations.json`.

### 6.4 Nemico base

```
[PIXEL STYLE BLOCK]
Enemy reference: a gaunt hooded cultist figure, four poses on one row —
facing down, up, left, right. Identical in all four. Plain flat magenta
background. Pixel art, ~32x32 proportions, 2px black outline, palette black +
ash grey + one sickly accent. Aspect 16:9.
```

### 6.5 Tileset per regione (32x32, 4 tile)

`tools/generate_placeholders.py` fa un tileset placeholder di 4 tile:
`pavimento`, `muro`, `ostacolo`, `acqua`. Un prompt per regione, con la
palette del cap. 3:

```
[PIXEL STYLE BLOCK]
A small tileset strip: four 32x32 top-down terrain tiles side by side for
[regione] — (1) walkable ground, (2) solid wall, (3) a low obstacle,
(4) water. Each tile self-contained and edge-tileable. Pixel art, 2px dark
outline per tile, palette [inchiostro + primario + accento della regione].
Plain background. Aspect 4:1.
```

### 6.6 Post-produzione obbligatoria

1. Ridimensiona/ricampiona alla griglia esatta di 32 px (nearest neighbour).
2. Rimuovi lo sfondo (chroma key sul magenta), pulisci i bordi.
3. Ritaglia i frame nella griglia che `animation_machine.gd` si aspetta
   (`assets/placeholder/<categoria>_<nome>.png`, righe = direzioni, colonne =
   frame).
4. Verifica in gioco con F5 (hot-reload) prima di considerare fatto un asset.

---

## 7. Checklist di accettazione di un'immagine

- [ ] Palette: inchiostro scuro + max 2 colori (illustrazione) / outline + 3
      (pixel). Un quarto colore = rifiuta.
- [ ] Stile: neri pieni, tratto a pennello, spazio negativo. Se sembra un
      render 3D o un disegno "anime carino" = rifiuta.
- [ ] Niente testo, watermark, cornici decorative sull'immagine.
- [ ] Guardaroba e ambiente d'inizio Novecento, non moderni, non fantasy
      generico con armature di piastre.
- [ ] Key art: nessun elemento di UI, nessun HUD.
- [ ] Ritratti di serie: sfondo, luce e inquadratura identici a tutto il set.
- [ ] Sprite: e' un riferimento, non un asset — nessuno lo droppa in
      `assets/` senza la post-produzione del cap. 6.6.

## 8. Dove finiscono i file

```
assets/concept/
  regioni/       mirwada.png, marche.png, valle.png, archivio.png, frontiera.png, trono_del_gigante.png
  ritratti/      enel.png, mirco.png, sidon.png, vesna.png, aldo.png, ottavia.png, bruno.png, lena.png, doran.png
  ui/            scaffale.png, pagina_pulita.png, pagina_follia.png, bordi.png, erbario.png, frontespizio.png, voltata.png
  sprite_ref/    enel_turnaround.png, nemico_turnaround.png, tileset_<regione>.png
```

`assets/concept/` va versionato (piccolo, utile). **Non** va in `assets/` ne'
in `assets/placeholder/`: quelli sono, rispettivamente, gli asset di gioco e
l'output del generatore di placeholder. Nota IP di `CLAUDE.md`: e' materiale
di riferimento "alla maniera di", non redistribuibile con i nomi attuali.
