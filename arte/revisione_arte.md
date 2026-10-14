# Revisione generale dell'arte — 2026-10-14

> Controllo fatto da Claude Code su tutto ciò che esiste oggi: i 19 fogli sprite in
> `assets/placeholder/`, i ritagli e le anteprime del mondo in `arte/mondo/`, le scene dei
> terreni in `arte/terreni/`, le concept art, gli script in `tools/art/` e il codice che
> mostra gli sprite. **Solo revisione: nessun file di gioco toccato.**
> Ogni punto dice cosa non va, come l'ho misurato, perché conta e **come correggerlo**.
> Le correzioni con codice vanno spiegate e approvate prima (regola di `CLAUDE.md`).

Immagini di prova (generate per questa revisione, non sono asset del gioco):
- `arte/revisione/leggibilita_personaggi_sul_mondo.png` — Enel, nemico e pet messi sopra i
  ritagli della mappa alla scala vera del gioco (porto di giorno, porto di notte, bosco).
- `arte/revisione/nemico_attacco_frame_attivo.png` — l'attacco del nemico frame per frame.

Legenda: 🔴 alta (rovina la leggibilità o va decisa prima del Blocco C/D) ·
🟠 media (da fare nella story indicata) · 🟢 bassa (pulizia, quando capita).

---

## 0. Cosa va già bene

- **Palette:** 0 colori fuori Endesga 32 nei 19 fogli sprite; i colori extra dei terreni
  stanno nelle rampe di `terrain.py`, come chiede `CLAUDE.md`.
- **Alpha pulita su Enel:** solo 0 o 255. Numero di frame e dimensione di tutti i 19 fogli
  identici a `data/animations.json`.
- **Godot:** filtro Nearest, snap ai pixel, `canvas_items` 1280×720 a scala intera: giusti.
- **Determinismo:** mondo e terreni danno lo stesso md5 a ogni lancio; `forge3d` è nel repo
  e differisce dalla skill solo in `terrain.py` (modifiche documentate in `ORIGINE.md`).
  `selftest.py` della skill esce 0.
- **Idee forti che funzionano:** la sciarpa rossa e gli occhi ciano di Enel si riconoscono
  subito; il contorno rosso del tell del nemico si legge anche da fermo; la disposizione
  del mondo è approvata.

---

## 1. Personaggi (sprite)

### 🔴 1.1 Enel sparisce sul selciato di Mirwada (e di notte quasi del tutto)
- **Cosa:** il cappotto di Enel (`#262b44 / #3a4466 / #5a6988`) usa la stessa rampa
  blu-ardesia dei ciottoli di Mirwada. Messo sopra il ritaglio del porto si vedono solo
  sciarpa e occhi; con la luce di notte resta visibile quasi solo lo sguardo
  (vedi `leggibilita_personaggi_sul_mondo.png`). Mirwada è la regione di partenza.
- **Prova in grigi** (`check.py`): cappello, cappotto e braccia stanno nella stessa fascia
  scura; si staccano solo occhi e bende. La sagoma si legge come una macchia.
- **Come correggere** (US-8B30 + rifinitura di Mirwada US-8B14):
  1. Cappotto con un gradino chiaro in più e un **bordo di luce** (selout chiaro, 1 px)
     sul lato in alto a sinistra: resta scuro ma si stacca dal fondo.
  2. Ciottoli di Mirwada **meno contrastati nei dettagli** e di una tinta diversa dal
     cappotto (es. grigio caldo), restando luminosi (decisione 3.1): si cambia la rampa in
     `terrain.py`, non il PNG.
  3. **Ombra a terra composta dal gioco** sotto ogni personaggio (vedi 2.2).
  4. Criterio di accettazione: rifare l'immagine di prova giorno/notte; Enel si deve
     leggere su ogni terreno della sua regione.

### 🔴 1.2 L'attacco del nemico non ha la posa del colpo
- **Cosa:** `nemico_base.attack` ha `attivi: [1]`, ma il frame 1 mostra la mazza **alzata**
  (carica). Il frame 2 è identico all'1 (0 pixel diversi) e il frame 3 è di nuovo l'idle
  (36–50 pixel diversi). Non esiste un frame con la mazza che scende o colpisce.
  Il giocatore viene colpito mentre la mazza è ancora in aria: contrario a FR-8
  (leggibilità del combattimento). Vedi `nemico_attacco_frame_attivo.png`.
- **Come correggere** (US-8B31, conviene anticiparla): 4 pose diverse —
  0 carica breve, **1 colpo** (mazza davanti al corpo, verso il bersaglio), 2 impatto
  tenuto (160 ms), 3 recupero. I tempi in `durate_ms` restano quelli.
  Non c'è un ripiego senza ridisegnare: la posa del colpo nel foglio non esiste.

### 🔴 1.3 Tutti i 19 fogli sono disegni a 32 px ingranditi ×2
- Già noto (US-8B01): nessun beneficio dei 64 px finché non arriva il Blocco C.
  **Consiglio:** scrivere i punti 1.1 e 1.4–1.13 dentro i brief di US-8B30/31/32, così il
  ridisegno li risolve in un colpo solo invece di rifare tutto due volte.

### 🟠 1.4 Gli sprite toccano il bordo della cella (arma e testa tagliate)
- **Cosa:** Enel e il nemico sono alti 32 su 32 px. La spada o il cappello di Enel toccano
  il bordo in 12 frame su 16 dell'idle (e in 24 su 24 del cast); il berretto del nemico
  tocca il bordo in alto in tutti i frame di idle e walk. Il manuale della skill vuole il personaggio al 70–85% della cella.
- **Come correggere:** a 64 px corpo alto **44–50 px**, 6–8 px liberi sopra e ai lati per
  l'arma. Il fendente grande non va nello sprite: va nei VFX (punto 1.6).

### 🟠 1.5 Su e giù si confondono
- **Cosa:** nella vista da dietro (`up`) Enel mostra due punti ciano sulla nuca (la crepa
  luminosa) e la sciarpa che pende come davanti: sembra girato verso di noi. Le sagome
  `down` e `up` sono uguali, cambia solo il lato della spada.
- **Come correggere** (US-8B30): da dietro la crepa diventa **una sola linea verticale**
  (non due punti a forma di occhi), la sciarpa pende sulla schiena, si vede il colletto.

### 🟠 1.6 Effetti colorati "cotti" dentro gli sprite di Enel
- **Cosa:** archi degli attacchi, crepa nel suolo dell'attacco pesante e bagliore della
  parata sono **ciano fisso** dentro il foglio; la scia del dash è viola fissa.
  Ma il Pathway si può cambiare (US-704) e il colore va letto da `data/vfx.json`
  (`twilight_giant` = oro `#e8c34a`; nessun Pathway ha il ciano come primario).
  In più l'arco è un tratteggio sottile di puntini (22–25 pixel isolati per frame), non la
  "pennellata carica" del manhwa.
- **Come correggere:** in US-8B30 lo sprite tiene **solo la posa** (al massimo una scia
  della lama in grigio neutro); archi, crepe e bagliori diventano VFX in scala di grigi
  colorati dallo shader (US-8B03 + US-8B40). Gli occhi ciano sono design del personaggio:
  restano.

### 🟠 1.7 Il lampo bianco del colpo subito ignora `riduci_flash`
- **Cosa:** il frame 0 di `personaggio_hurt` è una sagoma tutta bianca disegnata nel
  foglio. L'opzione `riduci_flash` non la può spegnere (`CLAUDE.md`: ogni flash bianco
  deve avere una variante attenuata).
- **Come correggere:** nel foglio un frame normale di "colpito"; il lampo lo fa il gioco
  con `modulate` (o uno shader) su `AnimationMachine`, leggendo `riduci_flash`.
  Piccola modifica di codice: va spiegata prima.

### 🟠 1.8 La camminata di Enel va a scatti e le gambe non si vedono
- **Cosa:** i frame 2–3 e 5–0 sono quasi uguali (50–66 pixel diversi contro i 260–310 degli
  altri passaggi, su tutte e 4 le direzioni): in pratica 4 pose, e la posa "gambe unite"
  resta a schermo 240 ms contro i 150 ms dei contatti. È il contrario della regola
  (contatti tenuti di più). Il cappotto lungo copre quasi tutte le gambe.
- **Come correggere** (US-8B30): 6 pose diverse (contatto, giù, passaggio, su, ×2),
  cappotto aperto davanti per far vedere le gambe, bob di 1–2 px a 64.

### 🟠 1.9 La spada sparisce nella morte di Enel
- **Cosa:** al frame 1 la spada cade a terra, dal frame 2 non c'è più (i pixel d'acciaio
  passano da ~31 a ~11, restano solo le bende).
- **Come correggere:** la spada resta a terra accanto al corpo fino all'ultimo frame.

### 🟠 1.10 Stile diverso tra Enel e nemico/pet
- **Cosa:** Enel viene dal costruttore, nemico e pet dallo zip di Claude in Chrome:
  proporzioni diverse (nemico esile con testa enorme), ombra cotta nel nemico e nel pet ma
  non in Enel, **linee d'inchiostro dentro la sagoma** del nemico (~80 px di `#181425` per
  frame: la regola dice di separare le parti con le ombre, non col nero).
  Nemico e pet non hanno un generatore: non sono "rilanciabili con seed".
- **Come correggere:** Blocco C rigenera tutti e tre con lo stesso metodo (stessa luce,
  stesse proporzioni, stessa regola del contorno), senza ombre cotte.

### 🟠 1.11 Nemico di profilo: non si capisce dove guarda
- **Cosa:** nelle viste `left`/`right` la testa è tutta berretto (si vede la nuca).
- **Come correggere** (US-8B31): profilo con viso visibile (naso, mento), berretto più piccolo.

### 🟠 1.12 Morte del nemico: affonda invece di cadere
- Già noto. L'ultimo frame è quasi vuoto (181 pixel). **Correggere:** caduta, ultimo frame
  col corpo a terra; la dissolvenza la fa già `enemy.gd` (`modulate:a`).

### 🟠 1.13 Il pet non si vede e non sembra un lupo
- **Cosa:** alto 12–15 px su 32 (occupa il 9–14% della cella), stesso grigio-blu di Enel: sul selciato
  e nel bosco quasi sparisce. Nelle viste su/giù è una macchia senza muso né orecchie.
  Un pixel ciano (l'occhio) compare solo in alcuni frame: lampeggia. Mancano `hurt` e `death`.
- **Come correggere** (US-8B32): a 64 px alto 28–36 px, colore distinto da Enel, orecchie e
  muso leggibili in tutte le viste, occhio fisso in ogni frame.

### 🟢 1.14 Frame duplicati
- `nemico_base.attack` 1 = 2, `nemico_base.stagger` 0 = 1, `pet.attack` 1 = 2 (in tutte le
  direzioni). **Correggere:** pose diverse, oppure un frame solo con durata più lunga in
  `durate_ms` (stessa resa, meno frame da disegnare).

### 🟢 1.15 Avvisi minori di `check.py`
- Rampe bende/acciaio "dritte" (senza hue shift): già noto.
- Dash a 50 ms per frame (20 fps, sopra i ~15 consigliati): scelta di gameplay, resta;
  ma i 4 frame devono essere pose molto diverse.

---

## 2. Aggancio tra sprite e gioco

### 🟠 2.1 I piedi non stanno sul punto fisico del personaggio
- **Cosa:** in `player.tscn` ed `enemy.tscn` lo sprite è centrato a `(0, -8)` ed è alto 32
  unità, quindi **i piedi sono disegnati a +8**; il cerchio di collisione (raggio 5) sta a
  `(0, -4)` e copre da -9 a +1. `animations.json` dice `origine: piedi_centro`, ma il codice
  non lo usa. Con muri e ordinamento per profondità (mondo vero, US-8B12) i piedi
  entreranno nei muri e gli alberi si disegneranno davanti/dietro nel momento sbagliato.
- **Come correggere:** sprite a `(0, -16)` (piedi sull'origine del nodo) e collisione ai
  piedi; da provare a schermo. Codice: va spiegato prima.

### 🟢 2.2 Ombra a terra: una regola sola
- **Cosa:** Enel senza ombra, nemico e pet con ombra grigia cotta (alpha 105), alberi con
  ombre cotte molto grandi.
- **Come correggere:** un'ellisse semitrasparente disegnata dal gioco sotto ogni entità
  (dimensione nei dati), e niente ombre negli sprite del Blocco C.

### 🟢 2.3 Tell del nemico doppio
- **Cosa:** contorno rosso nel foglio **e** `modulate (1, 0.5, 0.4)` in `enemy.gd:106`: la
  tinta scurisce proprio il contorno rosso e sporca tutta la figura.
- **Come correggere:** tenere uno solo dei due (il contorno si legge meglio).

---

## 3. Mondo e terreni

### ✅ 3.1 Direzione artistica — DECISO (2026-10-14): mondo luminoso come ora
- **Cosa era:** le concept art (`assets/concept/regioni/`) sono cupe e desaturate; i
  terreni generati sono luminosi e saturi.
- **Decisione dell'utente:** si tiene il mondo **luminoso** dei terreni attuali. Le concept
  art restano un riferimento per atmosfera e forme, **non per i colori**.
- **Conseguenza:** la leggibilità non si ottiene spegnendo i colori del mondo, ma
  rinforzando i personaggi (punto 1.1: valori, bordo di luce, ombra a terra) e abbassando
  il contrasto dei **dettagli** delle texture (punto 3.5). La regola di `CLAUDE.md` "sfondi
  meno contrastati dei personaggi" vale ancora: si misura con la prova giorno/notte.

### ✅ 3.2 Nessuna altezza: rupi, gradoni, scogliere e mura sono piatti — FATTO (2026-10-14)
> Parte 1: `forge3d/pareti.py` + tavola `arte/pareti/`. Parte 2: altezze in `build_world.py` e in
> `world_prova.json` (`altezza`, `parete`, `passaggi`), prima/dopo in `arte/mondo/pareti_prima_dopo_*.png`.
> Raccordi (2026-10-14, dopo due segnalazioni dell'utente): bordo continuo che gira gli angoli, spigoli
> netti, terreno della cima sotto la parete, mare a -1 per le scogliere, cima delle mura a lastre.
> Poi (stesso giorno): niente sfumature attraverso i dislivelli di roccia, case liberate lungo le mura,
> niente rombi o scatolette isolate, rampe chiare, arenaria vista dall'alto a lastre.
> In Godot le pareti come muri (e i bordi netti tra strati) arrivano con US-8B12.

- **Cosa:** tutto è una texture vista dall'alto. Al "passo tra due rupi" le rupi sono
  strisce di arenaria per terra; i gradoni delle Marche non si vedono; le scogliere sono
  bande. In una vista 3/4 un dislivello si capisce dalla **parete verticale** (faccia
  rivolta a sud) e dall'ombra che proietta. Senza, non si leggono il passo, i gradoni, le
  pareti scalabili (US-8B92) né le scogliere.
- **Come correggere:** una story del generatore: in `forge3d` il terreno "parete" con faccia
  frontale alta 1–2 tile, bordo superiore e ombra portata; i livelli d'altezza come
  mappa nei dati di `world.json`. Da fare prima della rifinitura delle Marche (US-8B15).

### 🟠 3.3 Scala degli oggetti: gli alberi sono alti come Enel
- **Cosa:** gli alberi sono alti 1–1,5 tile, gli alberi secchi meno di Enel: il bosco
  sembra un prato di cespugli.
- **Come correggere:** alberi alti 2–4 tile, chioma che copre il personaggio quando passa
  dietro (ordinamento per profondità), collisione solo sul tronco.

### 🟠 3.4 Vegetazione non legata alla regione
- **Cosa:** alla galleria di alberi (Valle, "giungla temperata con liane e felci giganti")
  ci sono palme gialle, betulle, abeti e latifoglie mescolati.
- **Come correggere:** un elenco chiuso di oggetti per regione nei dati dei biomi.
  Esempio: Valle = felci giganti, liane, alberi enormi; Mirwada = ulivi, viti, cipressi;
  Marche = rocce e ossa; palme solo sull'isola tropicale.

### 🟠 3.5 Texture che si ripetono a vista
- **Cosa:** si vede la griglia dei tile nei ciottoli del porto, nella `roccia_viva` del
  sottosuolo (disegno a rombi come una stoffa), nella palude (macchie uguali ogni tile),
  nelle `radici_muschio` (triangoli) e nel mare (tappeto regolare di lineette).
  Mare e sottosuolo sono le superfici più grandi del mondo: devono essere le più calme.
- **Come correggere:** 2–4 varianti per tile scelte dal seed nel dual grid; dettagli meno
  contrastati; mare con poche onde sparse e animate.

### 🟠 3.6 Pavimenti e moli con bordi "naturali"
- **Cosa:** lastre, piazze, moli e pontili usano la stessa transizione ondulata dell'erba:
  la piazza di lastre chiare del porto sembra una macchia di neve, i pontili hanno le punte
  arrotondate e il bordo dentellato verso la spiaggia, un tile di legno da solo diventa un
  "pallino".
- **Come correggere:** per i terreni costruiti un bordo **dritto** (con cordolo), scelto
  con un campo nella riga di `terrain.py`; moli e pontili come oggetti, non come terreno.
- **FATTO (2026-10-14):** `bordo="dritto"` per i terreni costruiti; moli, scali e diga rialzati con la
  parete (materiali `molo` e `legno`) invece che come oggetti: hanno faccia e bordi come le altre pareti.

### 🟠 3.7 Pavimenti a scacchiera
- **Cosa:** `lastre_rovine` e altre lastre alternano giallo e azzurro in modo regolare:
  le rovine del boss sembrano il pavimento di un bagno.
- **Come correggere:** tono di ogni lastra dal rumore (non alternato), fughe irregolari,
  crepe, erba nelle fughe, lastre mancanti.

### 🟠 3.8 Strade che finiscono nel nulla
- **Cosa:** il lastricato si ferma al bordo della giungla (proprio all'ingresso principale
  della Valle, con un albero sulla fine), al confine delle Marche e a metà della piazza
  delle rovine.
- **Come correggere:** le strade proseguono dentro la regione fino al luogo; alberi e rocce
  esclusi dalla strada e da 1 tile ai lati.

### 🟠 3.9 Coste a gradini e luoghi perfettamente rotondi
- **Cosa:** la Frontiera è un'ellisse a scalini regolari (sembra una piramide vista
  dall'alto), la fascia d'acqua bassa è larga sempre uguale, rovine, cimitero, archivio e
  isolette nella nebbia sono cerchi perfetti.
- **Come correggere:** contorni deformati dal rumore (come già fatto per le regioni),
  fascia d'acqua bassa variabile, qualche scoglio.
- **FATTO (2026-10-14):** a fine generazione la forma della terra si sfuma e si ritaglia con un rumore
  (golfi e promontori di 1–3 caselle), la spiaggia segue la costa nuova con larghezza 1–2, l'acqua bassa
  è larga 2–6 caselle con il bordo arrotondato; i cerchi (rovine, cimitero, archivio, isolette) hanno il
  raggio che ondeggia. Fermi: scogliere, moli, città, strade, luoghi, villaggi, laghi. Gli scogli non
  sono stati aggiunti (servirebbe un oggetto nuovo nel mare).

### 🟠 3.10 Acqua del sottosuolo turchese e a pezzetti
- **Cosa:** fogne e grotte usano l'acqua bassa tropicale (turchese brillante); nelle fogne
  l'acqua è a pezzetti staccati invece che in canali continui.
- **Come correggere:** terreni `acqua_fogna` (verde-bruna torbida) e `acqua_grotta` (scura
  con riflessi); canali continui lungo le gallerie con i camminamenti ai lati.
- **FATTO (2026-10-14):** terreni `acqua_fogna` (verde-petrolio torbido, riflessi grigi) e `acqua_grotta`
  (blu profondo, riflessi grigi). Fogne: un canale continuo al centro di una galleria nord-sud su tre, una
  quota più basso (cordolo di pietra ai lati, gradino dove comincia), grate di metallo (`lamiera`) agli
  incroci; il canale non tocca mai la roccia e non passa sotto ingressi e boss.

### 🟢 3.11 Puntini colorati nell'erba
- Pixel singoli ciano, rosa e bianchi sparsi: a dimensione vera sporcano.
  **Correggere:** fiori a gruppetti di 2–3 pixel, colori della regione, meno frequenti.

### 🟢 3.12 Ombre degli oggetti
- Ellisse uguale per tutti, 4 volte più larga del tronco per gli alberi secchi, scura.
  **Correggere:** ombra in proporzione all'oggetto, più chiara, spostata verso il basso a
  destra (luce in alto a sinistra).

### 🟢 3.13 Strade della città tutte a griglia
- Anche il centro antico e i bassifondi sono una scacchiera perfetta.
  **Da proporre all'utente** (non cambia la disposizione approvata): griglia solo per
  porto e città nuova, vicoli storti nel centro antico e nei bassifondi (con US-8B14/18).

### 🟢 3.14 Grandi aree tutte uguali
- Marche (pietrisco bruno su ~670 schermate) e interno della Frontiera (lilla su ~690).
  **Correggere** nella rifinitura delle regioni: un punto d'interesse o un cambio di
  terreno ogni 2–3 schermate.

---

## 4. Dati e documenti

### ✅ 4.1 Palette dei VFX — DECISO (2026-10-14): vale `data/vfx.json`
La tabella di `006_PRD/design-vfx.md` cap. 2 è stata riscritta con i valori di
`data/vfx.json`; la vecchia proposta in `art-brief-gemini.md` è segnata come superata.
Le differenze che c'erano (per memoria):

| Pathway | `design-vfx.md` | `data/vfx.json` |
|---|---|---|
| death | verde osso pallido, `pennellata_secca` | `#5f7d8c` ardesia, `glifo` |
| darkness | nero-viola, niente accento, `assenza` | `#4b3b6b` + accento `#b9a6e0`, `pennellata_secca` |
| fool | rosso teatro + crema, `tratteggio` | `#8f7fae` lilla, `assenza` |
| error | ciano tagliente + bianco | `#c85a3c` ruggine |
| hermit | ambra + azzurro cristallo, `glifo` | `#b98a3e` + `#f2dcae`, `tratteggio` |
| moon | argento lunare + rosso sangue | `#6fb0c4` azzurro + `#dff4fa` (niente rosso) |
| paragon | rame + ottone chiaro | `#c9c2b0` grigio caldo + `#ffffff` |

Nel Blocco D (US-8B40) i fogli VFX in grigio seguono il `tratto` di `data/vfx.json`, lo
shader ne legge i colori.

### ✅ 4.2 La guida `arte/` è superata — FATTO (2026-10-14: 64 px, terreni e pareti generati)
- `arte/01–05` parlano ancora di 32×32, contorno 2 px nei VFX, prompt per Gemini e
  placeholder diagnostici; `CLAUDE.md` v2 dice 64 px e sprite-forge.
  **Correggere:** aggiornare i 5 file (solo documentazione).

### 🟢 4.3 Riproducibilità
- `build_enel.py` usa ancora `render.py`/`check.py` della skill esterna (già noto); nemico e
  pet non hanno generatore (punto 1.10). Si chiude con il Blocco C.

### ✅ 4.4 Godot importa anche le anteprime e le concept art — FATTO (`.gdignore`, 2026-10-14)
- `arte/` (anteprime, mappe di rumore 1200×1000) e `assets/concept/` vengono importati:
  import più lento e, all'esportazione, finirebbero dentro il gioco (le concept art non
  sono distribuibili: nota IP). Nessuno script le carica.
  **Correggere:** un file vuoto `.gdignore` in `arte/` e in `assets/concept/`.

### 🟢 4.5 La cartella `assets/placeholder/` contiene l'arte vera
- Nome fuorviante. **Correggere** quando capita: `assets/sprites/` (il percorso è in
  `animation_machine.gd`, `generate_all.py`, `generate_placeholders.py`).

---

## 5. Cosa manca ancora (già nel PRD 8b)

0 su 27 fogli VFX (oggi `vfx.gd` colora un solo sprite segnaposto), edifici e ponti
(US-8B18), NPC e ritratti (US-8B33–35), creature e boss, icone (39 + 14 + 27), pagine del
libro, panorami, `tileset.png` di prova ancora a 32 px. Da decidere: **font pixel per
l'HUD** (dopo US-8B01 le scritte sono lisce).

---

## 6. Ordine consigliato

1. ~~**Decisioni (nessun codice):** direzione del colore del mondo (3.1) e palette/tratti
   dei VFX (4.1).~~ **Fatto il 2026-10-14:** mondo luminoso, vale `data/vfx.json`.
2. **Generatore (`forge3d`):** pareti e altezze (3.2), bordi dritti per i terreni
   costruiti (3.6), varianti dei tile (3.5), scala degli alberi (3.3). Poi si rigenera il
   mondo con lo stesso seed e si confronta il prima e il dopo.
3. **Blocco C** con i punti 1.1 e 1.4–1.13 scritti nei brief: Enel (US-8B30), nemico
   (US-8B31, prima possibile per 1.2), pet (US-8B32).
4. **Piccolo codice** (ognuno spiegato prima): piedi sull'origine (2.1), ombra composta
   (2.2), lampo del colpo dal gioco (1.7), tell singolo (2.3).
5. **Pulizia:** guida `arte/` (4.2), `.gdignore` (4.4).

## Come è stata fatta questa revisione

- Analisi automatica dei 19 fogli: palette, alpha, frame duplicati, cicli (differenza tra
  ultimo e primo frame), pivot dei piedi, sprite che toccano il bordo, inchiostro dentro la
  sagoma; `check.py` della skill sui JSON di Enel (prova in grigi e silhouette).
- Ogni foglio guardato ingrandito su sfondo chiaro e scuro; ritagli della mappa, scene dei
  terreni, città e mappa intera guardati a dimensione vera.
- Prova composita: personaggi sopra la mappa alla scala del gioco, di giorno e di notte.
- Lettura del codice che mostra gli sprite (`animation_machine.gd`, `player.tscn`,
  `enemy.tscn`, `enemy.gd`, `vfx.gd`) e confronto tra `data/vfx.json` e `design-vfx.md`.
- Gli script di analisi sono rimasti fuori dal repo (erano usa e getta). Se servono come
  controllo fisso, `tools/art/controlla_sprite.py` è una story di codice da spiegare prima.
