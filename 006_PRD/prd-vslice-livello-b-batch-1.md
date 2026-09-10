# PRD: Livello B (gioco reale) — Batch 1: Mother, Door, Error

> Scritto il 2026-09-10, seguito di `006_PRD/prd-copertura-vertical-slice.md`
> (che documentava il gap senza costruire nulla). Su richiesta esplicita:
> "comincia con 3 pathway qualunque organizzati tu". Scelti Mother, Door,
> Error — motivazione e verifica dei dati sotto. Ogni riferimento a celle di
> mappa e ingredienti qui sotto è stato controllato sui file reali
> (`data/world/layouts/*.json`, `data/potions/formulas.json`), non ipotizzato.

## 1. Perché questi 3 e non altri 6

- **Mother -> Valle della Madre**: fit tematico diretto (il nome della
  regione), e verificato che i 3 ingredienti della sua formula di Sequenza 9
  (`seme_dormiente`, `terriccio_di_prima_luna`, `goccia_di_linfa`) **sono
  già piazzati** in `data/world/layouts/valle_madre.json`. Zero dati da
  scrivere per gli ingredienti: è il Pathway più vicino a una prova reale.
- **Door -> Frontiera delle Porte**: fit tematico diretto (tag della
  regione: `soglia`, `porta_senza_stanza`). I 3 ingredienti di
  `formula_door_9` (`chiave_senza_denti`, `polvere_di_gesso_stellare`,
  `cardine_arrugginito_di_una_porta_perduta`) non sono ancora in nessun
  layout: da piazzare.
- **Error -> Archivio Sepolto**: fit tematico diretto (tag della regione:
  `biblioteca`, `biblioteca_di_tutto`, `sala_dei_sigilli` — Error è il
  "Demon of Knowledge"). I 3 ingredienti di `formula_error_9`
  (`grimaldello_cantante`, `guanto_del_borseggiatore`,
  `refurtiva_dimenticata`) non sono ancora in nessun layout: da piazzare.

Le altre 4 regioni collegate a Mirwada (`marche_crepuscolo`) e i 6 Pathway
restanti (Fool, Hermit, Death, Moon, Paragon, Darkness) restano per un batch
successivo, stessa ricetta.

## 2. Cosa NON serve costruire (rispetto al gap generico documentato prima)

Riletto `tests/manual/qa_vslice.gd` passo 8: la Caratteristica di Sequenza 9
del Twilight Giant è **già** concessa diretta via `CharacteristicStore`,
non farmata da un boss — è una scorciatoia dichiarata nel file stesso
("il boss di Mirwada e' di Sequenza 8, non 9... concessa diretta"). Quindi:

- **Nessun nuovo nemico/boss da piazzare.** I 7 nemici generici già presenti
  in ciascuna regione bastano per il passo di combattimento (dimostra
  ability+attacco reali, non un drop specifico).
- **Nessun nuovo venditore.** Il passo del negozio (Sidon) resta specifico
  di Mirwada; i 3 nuovi script lo OMETTONO — non è necessario per dimostrare
  "cammina, raccogli, lancia un'abilità, combatti, prepara e bevi la
  pozione, avanza di Sequenza" con input reale.
- **Nessuna nuova storia di validator/schema.** Gli ingredienti da piazzare
  sono item già esistenti in `data/items/ingredienti.json` (US-808):
  aggiungerli a `oggetti` nei layout è un dato già nella forma prevista dal
  validator (`x, y, item_id, quantita`, cella calpestabile — verificato con
  `CALPESTABILI_LAYOUT = ".,=+"`).

## 3. Il cammino di ciascuno dei 3 script

Il personaggio nasce sempre a Mirwada (hub fisso, `main.tscn`): la
creazione sceglie il Pathway dall'`OptionButton` già esistente (US-801),
poi si cammina fino al passaggio verso la regione target (coordinate lette
dal layout di Mirwada, non scritte a mano nello script: `regione.call
("passaggi_verso")` come fa già il passo 9 dell'originale), si attraversa,
e nella nuova regione si ripete lo stesso schema di `qa_vslice.gd` (passi
4-5-6-8, senza il passo 7 del negozio): raccolta reale dei 3 ingredienti ->
abilità a tasto vero -> combattimento reale contro un nemico generico ->
diagramma (Prepara/Bevi, Caratteristica di Sequenza 9 concessa diretta come
nell'originale) -> `Progression.sequence()` 9 -> 8.

| Story | Pathway | Regione | Dati da aggiungere | Script nuovo |
|---|---|---|---|---|
| VS-B1-01 | Mother | Valle della Madre | nessuno (già presenti) | `tests/manual/qa_vslice_mother.gd` |
| VS-B1-02 | Door | Frontiera delle Porte | 3 ingredienti in `oggetti` (celle `(34,7)`, `(22,18)`, `(6,7)`, tutte calpestabili e libere, verificate) | `tests/manual/qa_vslice_door.gd` |
| VS-B1-03 | Error | Archivio Sepolto | 3 ingredienti in `oggetti` (celle `(11,12)`, `(26,9)`, `(37,9)`, tutte calpestabili e libere, verificate) | `tests/manual/qa_vslice_error.gd` |

Ogni story: 1 file di dati toccato (0 per Mother) + 1 script nuovo +
verifica con Xvfb reale (schermata alla mano) — dimensionata per una
context window, coerente con "una story, una iterazione".

## 4. Definition of done per ciascuna story

- [ ] (Door, Error) i 3 ingredienti aggiunti a `oggetti` nel layout, celle
      verificate calpestabili e libere
- [ ] `python tools/validate_data.py` esce 0
- [ ] `godot --headless --path . --script res://tests/run_tests.gd`: nessuna
      regressione (i nuovi script sono manuali, in `tests/manual/`, non
      raccolti dalla suite)
- [ ] script `qa_vslice_<pathway>.gd` lanciato per davvero con Xvfb: tutti i
      passi OK, exit 0, screenshot prodotti
- [ ] `progress.txt` aggiornato

## 5. Dopo questo batch

Se il pattern regge (previsto: regge, è lo stesso motore già provato per il
Twilight Giant), lo stesso schema si ripete per i 6 Pathway restanti,
scegliendo la regione più affine per ciascuno (`marche_crepuscolo` è
tematicamente vicina a Death — tag `luogo_di_battaglia`/`altura`, gli
stessi del suo `advancement_ritual` di Sequenza 4).
