# Confronto tra concept art e mondo generato (2026-10-19)

Per ogni regione: a sinistra la concept (`assets/concept/regioni/<id>.jpg`), a destra un pezzo di 40×24 tile
della mappa vera (seed 6, quella approvata), centrato sul luogo che la concept rappresenta. Tavole in
`arte/revisione/concept/confronto_<id>.png`.

Regola di partenza (CLAUDE.md, decisione 3.1): le concept valgono per **atmosfera e forme**, non per i colori; il
mondo resta luminoso. Il confronto quindi guarda soprattutto le forme e gli oggetti.

## In una riga

Le concept raccontano le regioni con **oggetti, edifici e un luogo simbolo**; il generatore oggi fa quasi solo
**terreno** (più alberi, rocce, ossa e scogli). La distanza più grande non è il colore: sono gli oggetti che mancano.

## Regione per regione

### Archivio Sepolto — distanza massima
- **Concept:** una sala **sotterranea**: scaffali altissimi (alcuni crollati), pavimento coperto di libri e
  pergamene, volta in muratura, soffitto crollato con un raggio di luce, **porta di pietra incisa e sigillata**
  (è il gating "conoscenza" di `regions.json`), ingranaggi e tubi di bronzo, un **automa** accasciato con il
  nucleo ciano, candele.
- **Adesso:** in superficie è **neve** con la scalinata di ghiaccio e la torre di osservazione; sotto non c'è
  niente (il sottosuolo ha fogne, catacombe, grotte, miniere, città sotterranea, ma non l'archivio).
- **Manca:** una zona sotterranea "archivio" (sale e corridoi in muratura) e i suoi oggetti.
- **Prova fatta:** `archivio_prova_tavola.png` (concept, adesso, prova in stile luminoso, prova con l'atmosfera
  della concept) e `archivio_prova_schermata.png` (una schermata di gioco ingrandita). Oggetti nuovi fatti con il
  motore 3D di forge3d: scaffale, scaffale caduto, libri e pergamene, ingranaggio con tubo, porta sigillata con le
  rune, automa, leggio con candele, macerie. Muri `mura` alti 2 tile, cima scura (il soffitto), pavimento
  `lastre_rovine`.
- **Cosa non mi convince ancora della prova:** il pavimento è troppo chiaro e pulito per un archivio sepolto
  (nella versione luminosa); nella versione con l'atmosfera le rune della porta si spengono; l'ingranaggio grande
  sta in mezzo alla stanza invece che dentro il muro.

### Mirwada — forme giuste a metà
- **Concept:** porto vittoriano: case a schiera in mattoni con tetti d'ardesia e comignoli che fumano, strade di
  ciottoli **in salita** e storte, lampioni a gas con la luce calda, panni stesi tra le case, navi e gru al porto,
  nebbia.
- **Adesso:** il selciato e gli isolati ci sono (blocchi di `ciottoli_scuri` e strade), ma senza case: la città è
  piatta e gli isolati sono ancora quasi a griglia.
- **Manca:** edifici (US-8B18: case a schiera, tetti, comignoli), lampioni (la luce la fa il gioco), panni stesi,
  navi e gru, fumo (VFX), dislivello (scalinate, strade in salita).

### Marche del Crepuscolo — quasi vuota
- **Concept:** campo di battaglia al tramonto: spade e lance piantate nel terreno, scheletri, stendardi
  strappati, un'abbazia gotica in rovina su una cresta, una montagna lontana.
- **Adesso:** al `campo_di_battaglia` c'è un terreno prugna uniforme con due chiazze; le ossa ci sono ma rare
  (0,4%), niente armi né stendardi; le rovine grandi stanno nella terra di mezzo, non qui.
- **Manca:** oggetti spade/lance/stendardi/scheletri (fitti al campo di battaglia), abbazia in rovina (archi),
  una cresta (altezza) da cui si vede.

### Valle Madre — bosco sbagliato e difetti negli alberi
- **Concept:** bosco antico di alberi enormi e contorti coperti di muschio, nebbia bassa, una radura con un
  **altare di radici** circondato di fiori rossi, un raggio di luce.
- **Adesso:** alla `radice_del_mondo` un bosco fitto di querce, pini e felci generici, verde saturo; nessuna
  radura, nessun altare.
- **Difetti trovati e corretti** (2026-10-20, `alberi_valle_prima_dopo.png`):
  1. **contorno doppio** (fascia scura di 5-8 px sul bordo delle chiome, in tutti gli alberi): la soglia delle
     linee interne era 1 unita' anche per i modelli ingranditi x3,6, e il bordo ripido di una sfera grande la
     superava sulla stessa superficie. Ora `worldrender.object_sprite` usa `inner_thr = scala del modello`;
  2. **righe verticali**: erano le liane del `gigante`, dritte, chiare e lunghe fino a terra. Ora 4 fili scuri
     che escono dalla chioma e pendono fino a meta' tronco;
  3. felci **giallo acceso**: nella giungla ora `leaf` invece di `leaf_light` (stessa scelta casuale, mappa uguale).
- **Manca:** un albero "antico" contorto e muschioso (tipo nuovo in `creatures.tree`), radura con altare di
  radici e fiori rossi, nebbia bassa (strato del gioco), raggio di luce.

### Frontiera delle Porte — idea diversa
- **Concept:** isole **sospese** in un vuoto di nebbia grigia, **porte isolate** (stipiti senza muro), strade
  d'asfalto spezzate che finiscono nel vuoto, un **teatro** su un'isola con palco, sedie e un faretto rosso.
- **Adesso:** all'`approdo_frontiera` un'isola normale nel mare (acqua, spiaggia, erba lilla, alberi secchi).
- **Manca:** il vuoto (bordo dell'isola = precipizio nella nebbia, non spiaggia), porte isolate, strade
  spezzate, teatro. **Da decidere:** l'asfalto con le strisce è fuori epoca: è voluto (il "Fool", l'errore)?

### Trono del Gigante — il luogo non si vede
- **Concept:** un trono enorme scavato in una rupe, spade e stendardi ai piedi, cielo al tramonto.
- **Adesso:** il luogo sta a (21, 20), nell'angolo in alto a sinistra della mappa, in mezzo alla neve; non c'è
  niente che lo segni. **Da verificare** se quella posizione è voluta.
- **Manca:** il trono (un oggetto grande o una parete scolpita), spade e stendardi, una salita.

## Decisioni dell'utente (2026-10-20)

- **Due modalità:** facile = luminosa (l'arte di adesso, tenuta da parte), difficile = cupa e identica alle concept,
  anche rifacendo tutto.
- **Frontiera:** vuoto di nebbia; l'asfalto con le strisce è voluto.
- **Trono del Gigante:** sulla vetta più alta delle Marche.

## Cosa proponevo, in ordine (prima delle decisioni)

1. ~~Difetti degli alberi~~ (contorno doppio, righe, felci gialle): **fatto** 2026-10-20.
2. **Decisione sull'atmosfera:** sprite luminosi come ora, ma una **luce d'ambiente per regione** messa dal gioco
   (dato in `regions.json`, come la prova 4 dell'Archivio). Non cambia nessun PNG e avvicina molto le concept.
3. **Un luogo simbolo per regione**, uno alla volta, con oggetti nuovi in forge3d: sala dell'Archivio (porta
   sigillata, scaffali, automa), abbazia in rovina e campo di spade nelle Marche, altare di radici nella Valle,
   teatro e porte nella Frontiera, trono del Gigante.
4. **Zona sotterranea "archivio"** nel generatore (sale e corridoi in muratura sotto l'Archivio Sepolto).
5. **Edifici di Mirwada** (US-8B18) e oggetti di città (lampioni, panni, navi, gru).
6. **Frontiera sospesa:** bordo nel vuoto invece del mare (cambia la forma approvata: va deciso insieme).

La prova dell'Archivio è stata fatta con due script fuori dal repo (oggetti e composizione della sala, seed fisso);
se la direzione va bene diventano una story vera in `tools/art/`, spiegata prima di scriverla.
