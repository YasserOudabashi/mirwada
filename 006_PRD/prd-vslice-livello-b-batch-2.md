# PRD: Livello B (gioco reale) — Batch 2: i 6 Pathway restanti + boss + NPC

> Scritto il 2026-09-10, seguito di `006_PRD/prd-vslice-livello-b-batch-1.md`
> (Mother/Door/Error). Chiude la copertura "gioco reale" per tutti i 10
> Pathway, verifica i boss gia' piazzati mai combattuti con input vero, e
> copre le due forme distinte di dialogo NPC (venditore/non venditore) oltre
> a Sidon. Ogni fatto qui sotto e' stato controllato sui dati reali, non
> ipotizzato.

## 1. I 6 Pathway restanti: dove e con cosa

Controllati `data/potions/formulas.json` e i layout: **Fool e Hermit hanno
gia' tutto** (i 3 ingredienti di Sequenza 9 erano gia' piazzati nei layout
di Frontiera delle Porte/Archivio Sepolto dalla fase 8 originale — sono
letteralmente gli stessi che il batch 1 ha trovato li' per errore pensando
fossero "generici"). Gli altri 4 no: 3 ingredienti a testa aggiunti.

| Pathway | Regione | Ingredienti da aggiungere | Boss gia' in quella regione |
|---|---|---|---|
| Fool | Frontiera delle Porte | nessuno (gia' presenti) | **Fool, Seq 5** (proprio) |
| Hermit | Archivio Sepolto | nessuno (gia' presenti) | **Hermit, Seq 6** (proprio) |
| Death | Marche del Crepuscolo | terra_di_cimitero, dente_di_teschio, muffa_sepolcrale | Twilight Giant, Seq 7 (non suo, vedi §2) |
| Moon | Valle della Madre | radice_di_valeriana, rugiada_notturna, fiore_di_luna | Mother, Seq 7 (non suo, vedi §2) |
| Darkness | Mirwada | velo_di_mezzanotte, occhio_che_non_dorme, cenere_di_stella_morta | Twilight Giant, Seq 8 (non suo, gia' verificato dal Twilight Giant) |
| Paragon | Mirwada | lente_graduata, polvere_reagente, taccuino_di_appunti | (nessuno dedicato: combatte un nemico generico) |

Regioni riusate (piu' Pathway nella stessa regione: gia' fatto nel batch 1
con Sidon+Mirwada): nessun conflitto, sono voci indipendenti in `oggetti`.

## 2. I 2 boss gia' piazzati ma mai combattuti con input reale

Il batch 1 ha scoperto che Valle della Madre e Marche del Crepuscolo hanno
gia' un boss vero (Caratteristica + `drop_probabilita: 1.0`) mai ucciso a
tastiera: **Mother Seq 7** e **Twilight Giant Seq 7**. Invece di scrivere
due script dedicati, si cambia la regola di combattimento (§3): un boss
presente in scena viene sempre preferito a un nemico generico. Risultato,
senza codice o script in piu': lo script **Moon** (Valle della Madre) uccide
il boss Mother; lo script **Death** (Marche del Crepuscolo) uccide il
secondo boss Twilight Giant. Le due verifiche mancanti sono chiuse come
sottoprodotto del punto 1, non come lavoro a parte.

## 3. Cambiamento nel motore di test: combattimento e navigazione

- **Preferenza al boss**: `_passo_6_combattimento` sceglie prima un nemico
  con `override.caratteristica` non vuoto (un boss, qualunque Pathway sia)
  nella scena; solo se non c'e' nessuno sceglie il piu' vicino generico
  (regola gia' introdotta nel batch 1). Nessun id di Pathway nella scelta:
  e' "se c'e' un boss, e' quello", dato dai dati stessi.
- **Attraversamento e riavvicinamento**: riusa senza modifiche la
  `_cammina_verso` del batch 1 (nudge anti-blocco + rilevamento di un
  cambio di regione a meta' corsa) e l'avvicinamento diretto (non un
  teletrasporto sul bersaglio, l'ultimo tratto resta un cammino vero) per
  ogni bersaglio, ingrediente compreso il primo.

## 4. NPC: le due forme di dialogo, non 19 copie

Il batch 1 aveva testato solo Sidon (venditore). Il roster ha 19 NPC ma
`DialogueEngine.scegli()` e i suoi 5 effetti sono lo STESSO motore per
tutti — provarlo NPC per NPC ripeterebbe lo stesso percorso di codice 19
volte senza aggiungere garanzie, l'opposto di Ponytail. Si prova invece
ogni FORMA distinta di scelta che i dati offrono, letta da `scelte_valide()`
(mai un indice fisso: le condizioni possono escludere scelte a runtime):

- **Vesna** (venditore no, guaritrice — condizione `reputazione_min`) e
  **Bruno** (venditore si', ma la scelta di vendita non ha condizioni:
  `apri_vendita` senza gate) — la SECONDA vendita mai provata, con un NPC
  diverso da Sidon e senza scorciatoie sulla valuta gia' verificate nel
  batch precedente.
- **Mirco** — dialogo non-venditore con un `effetti` reale (`avvia_quest`),
  la forma che copre gli altri NPC "normali" del roster (Aldo/Ottavia/Lena/
  Doran/generici condividono lo stesso schema, mai gli stessi `effetti`
  scritti a mano nel motore).
- **Antagonista** — l'UNICO grafo dell'antagonista di fase 7 (US-712),
  condizionato a `tier_min: angel`: un personaggio di Sequenza 9 non
  raggiunge mai quella soglia, quindi l'unica scelta valida e' il congedo.
  Si prova comunque avvio/scelta/chiusura: la condizione che filtra le
  altre due scelte E' il comportamento corretto da verificare, non un
  ostacolo da aggirare.

Assegnazione (un NPC per script, scelto perche' il personaggio transita
comunque per Mirwada prima di uscire, o perche' la regione target coincide):
Paragon parla con Vesna, Darkness con Bruno, Hermit con Mirco (prima di
attraversare verso Archivio Sepolto), Fool con l'Antagonista (gia' a
Frontiera delle Porte).

## 5. Definition of done

- [ ] `python tools/validate_data.py` esce 0
- [ ] `godot --headless --path . --script res://tests/run_tests.gd`: nessuna
      regressione
- [ ] i 6 nuovi `tests/manual/qa_vslice_<pathway>.gd` lanciati con Xvfb:
      tutti i passi OK, screenshot alla mano
- [ ] `progress.txt` aggiornato con l'esito e i boss/NPC effettivamente
      verificati
