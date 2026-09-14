# PRD: Design del gioco — Il Libro

## 1. Introduzione/Overview

Quinto e ultimo dei cinque documenti "bibbia di design" (i primi quattro:
oggetti/economia, abilità/pathway, mondo/regioni, NPC/boss — tutti in
`006_PRD/prd-design-*.md`). Descrive **il libro**: ogni schermata del
gioco — menu, creazione personaggio, mappa, albero di progressione,
inventario, dialoghi, impostazioni — è una pagina dello stesso libro,
mai una UI separata. Tratto da `data/ui/book.json` +
`data/schema/page_types.json` + `scripts/book.gd` + `scripts/
book_overlay.gd` + gli 9 script `scripts/pages/page_*.gd`.

**Si apre premendo Tab** (o `I`, tasto alternativo — `Q`/`E` sfogliano
pagina per pagina una volta aperto). Aprirlo **mette in pausa il mondo**
(`get_tree().paused = true`): il libro e i suoi controlli restano vivi
in pausa (`PROCESS_MODE_ALWAYS`), il resto no. Si richiude sempre
sull'ultima pagina consultata (eccetto il dialogo, pagina "transitoria"
che non diventa l'ultima).

## 2. Come funziona (meccanica, non contenuto)

- **Un solo controller** (`Book`, autoload): le pagine sono un dato
  (`data/ui/book.json.pages[]`, ordinate per `ordine`), ognuna con un
  `tipo` dal vocabolario chiuso `page_types.json` (9 voci). Aggiungere
  una schermata = aggiungere una voce ai dati + (se serve davvero un tipo
  nuovo) discuterlo esplicitamente.
- **Una pagina non sbloccata esiste comunque**, bianca (un appunto a
  matita) — mai assente: `sbloccata_da.fase` confronta con
  `balance.json.gioco.fase`. Inventario si sblocca a fase 3, il colophon
  non ha soglia (sempre visibile).
- **Un tipo di pagina, una scena** (`book_overlay.gd::PAGINE`): 7 dei 9
  tipi hanno una scena vera; 2 (`registro_sinergie`, `journal_quest`)
  **non hanno una scena mappata** — se visitati mostrerebbero il
  placeholder letterale `[ registro_sinergie ]` (vedi §5, Open
  Questions: il loro contenuto reale vive altrove, dentro Inventario).
- **La voltata** è un contatore in `_process` (non un Tween — i Tween si
  fermano col mondo in pausa), 350ms normali / 80ms con
  `riduci_animazioni` attivo. Titolo e stato pagina sono sempre testo:
  l'animazione non porta MAI l'unica informazione (FR-8).
- **Le macchie di follia** sul libro sono l'equivalente scritto dei
  sussurri audio: sopra la soglia 15 compaiono macchie ai bordi, sopra
  40 delle note a margine — lo stesso stato di follia del personaggio si
  legge anche sulla pagina fisica.
- **`doppia_pagina`** (solo `mappa`): quella pagina occupa lo spazio di
  due facciate invece di una.
- **`fog_of_war`** (solo `diagramma`): il vocabolario chiuso lo marca
  esplicitamente come pagina con conoscenza parziale.
- **`transitoria`** (solo `dialogo`): non si arriva sfogliando, ci si
  finisce quando `DialogueEngine.avvia()` parte; chiuderla non la rende
  "l'ultima pagina consultata".

## 3. Le pagine, una per una

### Scaffale (`copertina`, tipo `menu_principale`, ordine 0)

Il menu principale: i 4 slot di `SaveSystem` mostrati come **tomi su uno
scaffale**. Un tomo vuoto → nuova partita (porta al Frontespizio). Un
tomo valido → carica la partita. Un tomo **corrotto** → mostrato
"bruciato", non caricabile, mai cancellato in automatico (l'utente
decide cosa farne, il gioco non perde dati da solo).

### Frontespizio (`frontespizio`, tipo `creazione_personaggio`, ordine 1)

Partita nuova: campo nome (precompilato con "Enel" — scelta di design,
non un placeholder dimenticato), un selettore per i 10 Pathway attivi
(`GameData.pathway_ids()`, mai un nome hardcoded — l'indice
dell'`OptionButton` si risolve in un id, mai il contrario), i talenti
innati spuntati alla creazione. Confermare (bottone o voltata pagina)
chiama `nuova_partita`. Partita in corso: sola lettura — nome, Pathway,
Sequenza, tier.

### Mappa (`mappa`, tipo `mappa`, ordine 2, doppia pagina)

Le regioni **scoperte** (da `WorldState`), la posizione attuale, i gate
noti. Una regione mai visitata è **assente**, non grigia — fog of war
identico al diagramma. **"Fast travel è potere"**: non c'è
teletrasporto da menu. Si viaggia da un nodo della mappa solo se il
giocatore ha un mezzo del proprio Pathway — una primitiva `teleport` in
una Sequenza già raggiunta (es. `door_3` "viaggio lungo", `death_5`
"passo tra i mondi") — o un varco permanente aperto dal Twilight Giant.
Altrimenti: "servono le strade" — si cammina.

### Diagramma dei Pathway (`diagramma`, tipo `diagramma_pathway`, ordine 3, fog of war)

Una griglia **10 colonne (i 10 Pathway attivi) × 10 righe (Sequenze 9→0)**,
generata dai dati — mai disegnata a mano. Dentro uno `ScrollContainer`
perché griglia + dettaglio + fusione + avanzamento/dono può superare i
360px di una pagina (problema reale trovato giocando su schermo vero,
non teorico).

**Fog of war sulla conoscenza**: una cella è leggibile solo se il
giocatore la conosce — la propria colonna dalla Sequenza 9 fino a quella
corrente (l'ha vissuta), il resto ignoto salvo un flag esplicito in
`KnowledgeStore`. Eccezione: si può conoscere il **nome** (mai altro) della
Sequenza immediatamente successiva sul proprio Pathway — un presagio, non
un'anticipazione completa.

È anche dove si avanza: per un Pathway `standard` mostra Prepara/Bevi
(pozione); per uno `non_standard` come Eternal Aeon mostra "Il Dono"
(Boon) — un ramo sullo stesso dato, mai un tipo di pagina diverso.

### Inventario (`inventario`, tipo `inventario`, ordine 4, sbloccata a fase 3)

**7 sezioni in una pagina sola**: Zaino, Indosso (equip), Ricettario
(blueprint/ricette scoperte), Talenti, Base (edifici costruiti), Sinergie
(US-410 — il registro delle sinergie attive, col proprio fog of war),
Diario (US-616b — il journal delle quest, in realtà qui dentro). Ogni
riga oggetto mostra il nome colorato per rarità (US-1105: bianco
comune, verde non_comune, blu raro, oro leggendario). Le sinergie
appena attivate si evidenziano al primo render della pagina, poi tornano
normali.

### Dialogo (`dialogo`, tipo `page_dialogo`, ordine 7, transitoria)

Non si sfoglia: si apre quando parte un dialogo (`DialogueEngine.avvia`).
Mostra chi parla, il testo del nodo corrente, un bottone per ogni scelta
**valida** (le altre non compaiono affatto). Due sotto-modalità, sempre
sulla stessa pagina, mai una scena diversa:
- **Negozio** (`in_negozio`): righe compra/vendi, prezzo scalato dalla
  rarità (US-1103), apribile da una scelta di dialogo o da una
  ricompensa di quest.
- **Creazione** (`in_creazione`, fase 11): righe crea-su-richiesta per
  ogni blueprint/ricetta del `crafter` dell'NPC — un bottone Crea
  disabilitato finché mancano i materiali, mai un messaggio di
  fallimento dinamico.

### Colophon (`colophon`, tipo `impostazioni`, ordine 99)

Audio, video, input, lingua — ogni controllo scrive subito in
`SettingsStore` (`user://settings.json`), effetto immediato, mai un
bottone "applica". Se un finale è stato raggiunto (fase 7), una sezione
finale si aggiunge **sopra** tutto il resto invece di diventare un tipo
di pagina nuovo — la stessa regola di "estendi, non moltiplicare i tipi"
di Eternal Aeon sul diagramma.

## 4. Proposte per il futuro

### US-D15: Dare una scena vera a `registro_sinergie` e `journal_quest`

**Descrizione:** Come giocatore, voglio che le pagine "sinergie" e
"journal" dichiarate in `data/ui/book.json` mostrino qualcosa invece del
placeholder `[ registro_sinergie ]`/`[ journal_quest ]` se mai le
raggiungo (oggi il loro contenuto reale vive solo come sezione della
pagina Inventario).

**Acceptance Criteria:**
- [ ] Decisione esplicita presa e documentata: (a) rimuovere le 2 voci
      da `data/ui/book.json.pages[]` e da `page_types.json` (il
      contenuto vive già in Inventario, le voci sono ridondanti), oppure
      (b) scrivere le 2 scene vere e registrarle in
      `book_overlay.gd::PAGINE`.
- [ ] Se (b): Tests pass, verifica a schermo con Xvfb.

### US-D16: Il segnalibro "journal" punta a una pagina orfana

**Descrizione:** Come giocatore, i 3 segnalibri esistenti
(`data/ui/book.json.segnalibri = ["mappa", "diagramma", "journal"]`,
già renderizzati da `book_overlay.gd::_costruisci_segnalibri` in una
riga di scorciatoie funzionante) dovrebbero portarmi tutti a contenuto
vero — oggi cliccare il segnalibro "journal" mostra il placeholder
`[ journal_quest ]` (US-D15) invece del Diario, che vive dentro
Inventario.

**Acceptance Criteria:**
- [ ] Risolto insieme a US-D15: se si sceglie l'opzione (a) (rimuovere
      `journal`/`sinergie` dal vocabolario), il segnalibro "journal" in
      `data/ui/book.json.segnalibri` diventa `"inventario"` invece.
- [ ] Tests pass. Verifica a schermo con Xvfb.

## 5. Non-Goals

- Questo documento non copre il rendering pixel-per-pixel di ogni pagina
  (colori, font, layout esatto): quello vive nel codice/negli asset, non
  in un PRD di design.
- Non propone un ordine di sfogliatura diverso da quello dichiarato in
  `ordine`: cambiarlo è una decisione di UX da discutere a parte, non
  presunta qui.

## 6. Open Questions

- **`registro_sinergie` e `journal_quest` sono pagine "orfane"**: esistono
  nel vocabolario chiuso `page_types.json` e in `data/ui/book.json.pages[]`
  con un `ordine` proprio (5 e 6) e una `sbloccata_da.fase` propria (4 e
  6), ma `book_overlay.gd::PAGINE` non le mappa a nessuna scena — il loro
  contenuto reale è dentro Inventario (sezioni "Sinergie" e "Diario").
  Se non verranno mai raggiunte tramite `vai_a`/sfogliatura, sono morte
  nei dati: vanno tolte, o è previsto che restino come alias futuri?
- I 3 segnalibri configurati (`mappa`, `diagramma`, `journal`) sono
  davvero renderizzati come scorciatoie cliccabili quando il libro è
  aperto (`book_overlay.gd::_costruisci_segnalibri`, un `$Segnalibri`
  vero) — ma uno dei tre (`journal`) punta a una pagina orfana (sopra):
  un segnalibro rotto lasciato così da quando "journal" è stato assorbito
  dentro Inventario, o un promemoria intenzionale di cosa manca ancora?
