# PRD: Copertura "gioco reale" per tutti i 10 Pathway (Livello B)

> Scritto il 2026-09-10 in una sessione Claude Code, su richiesta esplicita:
> "test su tutti i pathway, che si possano completare dal 9 fino allo 0
> giocando il gioco reale". Distingue due livelli di test già presenti nel
> repo (vedi `tests/test_slice_tutti_i_pathway.gd`, aggiunto in questa stessa
> sessione) e documenta perché solo uno dei due è oggi possibile per tutti e
> 10 i Pathway. Nessun codice di gioco toccato da questo documento: è un
> elenco di cosa manca, non un'implementazione.

## 1. I due livelli, e cosa esiste oggi

**Livello A — "giocato in codice".** Il motore (Progression, PotionSystem,
Acting, EventTracker) pilotato direttamente dai dati, senza input reale.
Prima di questa sessione copriva solo 3 Pathway e mai fino in fondo:
Twilight Giant 9→5 (`tests/test_vertical_slice.gd`), Death 8→2
(`tests/test_slice_fase_5.gd`), Error 8→2 (`tests/test_slice_fase_5b.gd`).
`tests/test_slice_tutti_i_pathway.gd` (nuovo, questa sessione) generalizza il
pattern leggendo `GameData.pathway_ids()` invece di elencare i Pathway a
mano: **ora tutti e 10 i Pathway attivi completano 9→0** in un solo file,
automatico, dentro la suite headless (852 test, tutti verdi).

Scrivendolo si sono trovati e corretti due bug reali, mai emersi prima
perché i tre checkpoint esistenti non arrivavano mai così in basso o non
toccavano abilità così costose:

1. **`EventTracker._corrisponde` coi filtri `_min`/`_max`.** Un'acting_action
   come `tg_4_concoction` (Twilight Giant, Sequenza 4) filtra
   `{"qualita_min": 2}`: il campo che l'evento deve portare è `qualita`, non
   `qualita_min`. I tre checkpoint esistenti simulavano la recitazione
   passando i filtri COSÌ COME SONO come dati dell'evento — funzionava solo
   perché non toccavano mai una Sequenza con un filtro a soglia. Con tutti i
   10 Pathway fino a 0 il bug si è manifestato subito (Twilight Giant
   Sequenza 4 restava fermo a progresso 0.4). Non è un bug di gioco: è un
   bug del modo in cui i test simulavano l'evento. Corretto nel nuovo file;
   i tre file esistenti non lo toccano mai per costruzione, quindi restano
   verdi così come sono — ma se in futuro si estendono anche loro fino a 0,
   servirà la stessa correzione.
2. **Il costo in spiritualità cresce scendendo di Sequenza.** Un caster
   configurato una volta sola a Sequenza 9 (`spiritualita_max` basso) non
   può permettersi le abilità costose delle Sequenze basse nemmeno
   impostando `spiritualita` a un numero enorme, perché il setter di
   `StatsComponent` la clampa subito al massimo di quella Sequenza. Il
   sintomo: `darkness_giogo_della_malasorte` (55 di costo) e
   `darkness_dominio_della_notte` (80 di costo) fallivano l'esecuzione
   ovunque nel loop generico. Corretto riconfigurando il caster sulla
   Sequenza dell'abilità che sta per eseguire.

**Livello B — "gioco reale".** Input da tastiera veri, camminata fisica,
combattimento a corpo a corpo, Xvfb con renderer vero (`--headless`
restituisce screenshot nulli). Esiste **un solo script**,
`tests/manual/qa_vslice.gd` (US-814, non nella suite automatica — richiede
un display X11), e copre **un solo passo** di **un solo Pathway**: Twilight
Giant, Sequenza 9→8.

## 2. Perché il Livello B non si estende oggi agli altri 9 Pathway

Verificato sui dati del mondo (`data/world/layouts/*.json`,
`data/npc/roster.json`, `data/potions/formulas.json`), non per sentito dire:

| Pathway | ingredienti delle formule piazzati nel mondo (su 30) |
|---|---|
| twilight_giant | 9 |
| mother | 7 |
| fool, hermit | 6 |
| death, moon, paragon, darkness, error, door | **0** |

- **Un solo nemico "boss" esiste in tutto il gioco**: in `mirwada.json`,
  Sequenza 8, `caratteristica.pathway_id == "twilight_giant"`,
  `drop_probabilita: 1.0`. Le altre 4 regioni (`archivio_sepolto.json`,
  `frontiera_porte.json`, `marche_crepuscolo.json`, `valle_madre.json`) hanno
  solo 7 nemici generici di Sequenza 9 ciascuna, nessuno con una
  Caratteristica da far droppare.
- **Tutti gli 8 NPC con un ruolo di gioco** (incluso l'unico venditore
  `npc_sidon` che il passo 7 di `qa_vslice.gd` usa) vivono in `mirwada`,
  l'hub. Le altre 4 regioni hanno solo `npc_antagonista` (senza vendor).

In sintesi: **fuori da Mirwada e dal Twilight Giant non esiste ancora nel
mondo nulla da raccogliere, nessun nemico che droppi una Caratteristica per
nessun altro Pathway, a nessuna Sequenza**. Un test "gioco reale" per un
Pathway diverso dal Twilight Giant, o oltre la sua Sequenza 8, non è oggi
scrivibile: fallirebbe non per un bug del test, ma perché il mondo non
contiene ciò che il test dovrebbe raccogliere o combattere. Scrivere quel
contenuto è un lavoro di **fase** (mondo/contenuti), non una story di test.

## 3. Cosa servirebbe, Pathway per Pathway

Per ciascuno dei 9 Pathway senza copertura reale (tutti tranne Twilight
Giant), in almeno una delle 5 regioni:

1. **Ingredienti a terra**: per la formula della Sequenza scelta come punto
   d'ingresso del cammino di test (come Mirwada fa per `formula_twilight_
   giant_9`), posizionare a terra gli item degli `ingredients` mancanti
   (oggi 0-24 su 30 a seconda del Pathway, tabella sopra).
2. **Un nemico con `caratteristica.pathway_id`** impostato su quel Pathway e
   `drop_probabilita` > 0, per la Caratteristica che sblocca il `concoct` di
   quella Sequenza (oggi solo Twilight Giant Sequenza 8 ce l'ha, a Mirwada).
3. **Un venditore o una fonte alternativa di valuta/materiali** se il
   cammino di test scelto passa da un acquisto (Sidon è specifico di
   Mirwada/Twilight Giant).
4. Ripetere per ogni Sequenza che il cammino di test deve attraversare
   (`qa_vslice.gd` ne copre una sola, 9→8; un cammino 9→0 completo per un
   solo Pathway ne richiederebbe 9, in una o più regioni).

Non è necessario ripetere tutto questo per **ogni** Sequenza di **ogni**
Pathway per avere UNA prova di "gioco reale" per Pathway: un singolo salto
di Sequenza dimostrativo (come già fa `qa_vslice.gd` per il Twilight Giant)
basta a provare che il cammino "cammina, raccogli, combatti, compra, bevi"
funziona anche per quel Pathway con l'input vero. Un cammino 9→0 completo
per tutti e 10 servirebbe solo se si vuole la stessa garanzia end-to-end che
il Livello A già dà oggi in automatico.

## 4. Raccomandazione

- Il Livello A (`tests/test_slice_tutti_i_pathway.gd`) copre già oggi, in
  automatico e ad ogni CI, "si completa dal 9 allo 0" per tutti e 10 i
  Pathway: è la garanzia ripetibile che l'utente ha chiesto, nel senso in
  cui il progetto stesso la intende nei suoi checkpoint (fase 5/5b/7/8).
- Il Livello B per un secondo Pathway (oltre al Twilight Giant) richiede
  prima di scegliere QUALE Pathway e QUALE regione ospiterà il suo
  contenuto (decisione di design, non di test — vedi tabella "10 Pathway /
  4 gruppi" in `CLAUDE.md`), poi piazzare ingredienti/nemico/venditore per
  almeno una Sequenza in quella regione, poi scrivere uno script
  `tests/manual/qa_vslice_<pathway>.gd` sul modello di quello esistente.
  Stima: una story di contenuto (dati) + una story di script per Pathway,
  quindi **9 coppie di story** se si vuole un Pathway alla volta, o una fase
  dedicata se si preferisce farli insieme.
- Non è stato scritto nessun contenuto di mondo in questa sessione: è una
  decisione di design (quale regione, quale Pathway, con quali NPC) che
  spetta all'utente, coerente con `CLAUDE.md` ("Se ti trovi a scrivere una
  `if` per un caso specifico... quasi certamente è un dato mancante" — qui
  il dato mancante è il contenuto del mondo, non un `if`).
