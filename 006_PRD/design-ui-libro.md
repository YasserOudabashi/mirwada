# Mirwada — La UI a libro

Figlio di `design-master.md`. La shell parte in fase 2 (deve assorbire il
diagramma dei Pathway promesso dalla roadmap); le pagine arrivano ognuna con la
sua fase. Richiesta dell'utente: **ogni schermata e' una pagina di un libro;
cambiare schermata volta la pagina, con l'animazione del libro.**

---

## 1. Perche' un libro (e perche' e' diegetico)

In un gioco dove il potere si prende leggendo formule, recitando ruoli e
completando rituali, il libro non e' una metafora della UI: e' l'oggetto piu'
naturale del mondo di gioco. La proposta forte (decisione aperta n. 2 del
master, raccomandata): **il libro E' il salvataggio.**

- Il menu principale e' uno **scaffale**: ogni tomo e' uno slot di
  salvataggio. Aprire il tomo = caricare. Un tomo nuovo = nuova partita.
- La **creazione del personaggio e' scrivere il frontespizio**: il campo del
  nome, con "Enel" gia' scritto a matita (design-lore: il default non e' un
  placeholder). Si conferma con la prima voltata di pagina.
- La **follia macchia il libro**: sopra le soglie di balance.json i bordi
  delle pagine si scuriscono, compaiono note a margine in una grafia non tua
  (i sussurri, in forma scritta — FR-8: ogni canale audio ha l'equivalente
  visivo). Con `disattiva_sussurri` o `riduci_animazioni` le macchie si
  congelano a uno stato neutro. La meccanica non cambia: e' presentazione.
- Un **tomo corrotto** (save corrotto, design-master 3.1) appare bruciato
  sullo scaffale: leggibile come danno, mai crash, mai cancellazione
  silenziosa.

Aprire il libro **ferma il mondo** (single-player, pausa vera). Il ciclo
giorno/notte non scorre tra le pagine (design-world cap. 5).

## 2. Le pagine

Ogni schermata del gioco e' una pagina (o doppia pagina) dello stesso libro.
Elenco completo, con la fase in cui ogni pagina nasce:

| # | Pagina | Tipo | Fase | Contenuto |
|---|---|---|---|---|
| 0 | **Copertina / scaffale** | `menu_principale` | 2 | slot di salvataggio come tomi; nuova partita; esci |
| 1 | **Frontespizio** | `creazione_personaggio` | 2 | nome (default "Enel"), conferma; in seguito mostra chi sei (pathway, sequenza, titolo) |
| 2 | **Mappa** | `mappa` | 6 | doppia pagina: le regioni come carta disegnata, fog of war geografico, segni del giocatore; i varchi permanenti aperti (terrain_modify) vengono *disegnati* sulla carta |
| 3 | **Diagramma dei Pathway** | `diagramma_pathway` | 2 | la promessa di roadmap fase 2: le 10 colonne di Sequenze con fog of war sulla conoscenza — vedi solo cio' che hai letto/scoperto (flag di conoscenza, design-master cap. 5) |
| 4 | **Inventario** | `inventario` | 3 | oggetti disegnati come illustrazioni di un erbario/bestiario; ingredienti, equipaggiamento, oggetti con `stored_ability_id` |
| 5 | **Registro delle sinergie** | `registro_sinergie` | 4 | la promessa di roadmap fase 4: sinergie scoperte (`visibile` subito, `nascosta` dopo la scoperta, `lore` dopo la lettura) |
| 6 | **Journal** | `journal_quest` | 6 | quest attive/completate/fallite scritte come diario in prima persona; le voci di lore |
| 7 | **Colophon** | `impostazioni` | 2 | le impostazioni: audio (6 opzioni accessibilita' gia' in audio.json), video, input, lingua |

I **segnalibri** (mappa, diagramma, journal) sono nastri sempre visibili sul
bordo: un input diretto per le tre pagine piu' frequenti; le altre si
raggiungono sfogliando. Le pagine non ancora sbloccate **esistono ma sono
bianche** — l'inventario in fase 2 e' una pagina vuota con un appunto a
matita, e questo dice al giocatore che il libro crescera'.

### Il colophon (impostazioni) in dettaglio

Le 6 opzioni di `audio.json.accessibilita` finalmente hanno una casa, piu' le
altre sezioni:

- **Audio**: volumi per bus (master, musica, sfx, ambience, ui, sussurri);
  `sottotitoli_effetti`, `indicatore_visivo_tell`,
  `indicatore_direzione_suono`, `disattiva_sussurri`.
- **Video**: scala finestra (×1/×2/×3, base 640×360), fullscreen,
  `disattiva_shake`, `riduci_hitstop`, `riduci_distorsione` e `riduci_flash`
  (design-vfx), `riduci_animazioni` (che accorcia anche la voltata di pagina),
  macchie di follia on/off.
- **Input**: rimappatura tasti (risolve la domanda aperta del PRD di fase 1
  sul controller: si', supporto controller, con rimappatura, da fase 2).
- **Lingua**: it/en (R-12).

Ogni opzione scrive in `user://settings.json` (stesso rigore del save:
atomico, typeof al load, mai fatale).

## 3. L'animazione di voltata

- **Durata**: `voltata_ms` (default 350) in `data/ui/book.json` — un dato,
  come il timing del combat in animations.json: tarare il feel della UI deve
  costare secondi.
- **Resa**: a 640×360 la voltata onesta e' 2D — la pagina si solleva,
  un'ombra attraversa la piega, 3-4 frame di curvatura disegnati (stile
  placeholder finche' non c'e' l'artista; il budget frame della UI entra in
  animations.json). Niente shader 3D su una pagina di 320×360 pixel: sarebbe
  fuori stile e fuori budget.
- **Suono**: `sfx_ui_page` sul bus `ui` (gia' esistente); apertura del libro
  `sfx_ui_book_open`.
- **Accessibilita'**: con `riduci_animazioni` la voltata diventa una
  dissolvenza di 80 ms. Nessuna informazione vive *solo* nell'animazione.
- **Input**: pagina avanti/indietro (Q/E o dorsali), segnalibri diretti,
  chiusura sempre con lo stesso tasto che ha aperto. Il libro si apre sempre
  sull'ultima pagina consultata.

## 4. Data-driven: `data/ui/book.json`

Il codice implementa **un** controller di libro + un tipo di pagina per ogni
`tipo` del vocabolario chiuso (8 tipi). Aggiungere una schermata futura =
aggiungere una voce a `pages` (e il tipo, solo se davvero nuovo). Le pagine si
sbloccano per fase/flag **dal dato**, senza toccare scene.

```json
{
  "schema_version": 1,
  "libro": {
    "voltata_ms": 350,
    "dissolvenza_ridotta_ms": 80,
    "sfx_apri": "sfx_ui_book_open",
    "sfx_volta": "sfx_ui_page",
    "macchie_follia": true
  },
  "pages": [
    { "id": "copertina",   "tipo": "menu_principale",       "name_i18n": "ui.page.copertina",   "ordine": 0 },
    { "id": "frontespizio","tipo": "creazione_personaggio", "name_i18n": "ui.page.frontespizio","ordine": 1 },
    { "id": "mappa",       "tipo": "mappa",                 "name_i18n": "ui.page.mappa",       "ordine": 2, "doppia_pagina": true, "sbloccata_da": { "fase": 6 } },
    { "id": "diagramma",   "tipo": "diagramma_pathway",     "name_i18n": "ui.page.diagramma",   "ordine": 3, "fog_of_war": true },
    { "id": "inventario",  "tipo": "inventario",            "name_i18n": "ui.page.inventario",  "ordine": 4, "sbloccata_da": { "fase": 3 } },
    { "id": "sinergie",    "tipo": "registro_sinergie",     "name_i18n": "ui.page.sinergie",    "ordine": 5, "sbloccata_da": { "fase": 4 } },
    { "id": "journal",     "tipo": "journal_quest",         "name_i18n": "ui.page.journal",     "ordine": 6, "sbloccata_da": { "fase": 6 } },
    { "id": "colophon",    "tipo": "impostazioni",          "name_i18n": "ui.page.colophon",    "ordine": 99 }
  ],
  "segnalibri": ["mappa", "diagramma", "journal"]
}
```

Check del validator che nascono con questo file: `tipo` nel vocabolario chiuso;
`id` e `ordine` unici; segnalibri che puntano a pagine esistenti; chiavi i18n
esistenti (con R-12).

## 5. HUD: cosa NON e' nel libro

Il libro e' il menu; l'HUD di gioco (US-017: barre hp/spiritualita', poi
follia e acting in fase 2) resta a schermo, minimale, fuori dal libro. Regola
di confine: **cio' che serve durante un combattimento sta nell'HUD; tutto il
resto e' una pagina.** L'indicatore visivo dei tell e i sottotitoli degli
effetti (FR-8) sono HUD, non libro.
