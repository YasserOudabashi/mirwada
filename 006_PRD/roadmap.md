# Roadmap — Fasi 2-8

Scaletta, non PRD. Ogni fase riceve il suo PRD dettagliato con `/prd`
**quando la fase precedente e' chiusa**, non prima: scrivere ora il PRD della
fase 6 significa scriverlo sulla base di ipotesi che le fasi 1-5 smentiranno.

---

## Fase 2 — Pathway core (~22 story)

Il salto piu' rischioso del progetto. Qui si scopre se l'architettura
data-driven regge.

- Sistema Sequenze: stato del giocatore (pathway attuale, sequenza, tier)
- Caratteristiche Beyonder come oggetti droppabili
- Formule delle pozioni, incluse le **formule parziali** (3 ingredienti su 5)
- Concoction: pozione da Caratteristica + ingredienti
- **EventTracker generico** (1 story): contatori sui 12 eventi di
  `data/schema/tracked_events.json`. E' la versione RIDOTTA dell'Acting Method:
  nessun rilevatore speciale per azione, un solo sistema che conta eventi
  filtrati. Le azioni di recitazione sono gia' scritte come dati.
- **Acting Method**: barra `acting_progress` alimentata dall'EventTracker,
  decadimento per azioni incoerenti
- Blocco dell'avanzamento sotto `acting_progress` 1.0
- **Follia**: statistica cumulativa, sorgenti multiple, effetti a soglia
- **Layer audio della follia** (data/audio.json.madness_layer): 4 soglie di
  sussurri + one-shot casuali senza causa visibile. I sussurri a soglia 55
  usano i nomi degli NPC incontrati e delle Ancore del giocatore.
- **Percezione per Sequenza**: salendo si sentono layer ambientali nuovi e si
  rivelano informazioni (spiriti vicini, densita' mistica, segreti adiacenti).
  E' un canale informativo che si potenzia con la coltivazione.
- Effetti visivi della follia, con opzione di accessibilita'
- **Ancore**: registrazione, effetto di riduzione, distruggibilita'
- **Rituale di avanzamento** da Sequenza 5 in su: luogo, momento, sacrifici,
  sigilli, interruzione
- **Twilight Giant**: il PIU' e' GIA' SCRITTO. `data/abilities/twilight_giant.json`
  contiene tutte e 10 le Sequenze con 20 abilita', modificatori, azioni di
  recitazione, ingredienti e rituali. La fase 2 non deve progettarlo: deve
  farlo ESEGUIRE dal motore. Se il motore lo esegue senza codice dedicato,
  l'architettura e' validata e le fasi successive sono lavoro meccanico.
- 10 primitive aggiuntive (arriviamo a 15 su 28)
- **Tre capacita' del motore emerse dallo stress test** (vedi
  `006_PRD/design-pathways.md`), da prevedere ORA e non in fase 5:
  1. `AbilityEngine` deve eseguire un'abilita' non posseduta, con durata di
     prestito (serve all'Error)
  2. `summon` con `durata: -1` produce entita' persistenti che vanno
     serializzate nel save
  3. gli oggetti devono poter portare un `stored_ability_id` (fase 3, ma il
     motore va predisposto ora)
- Diagramma dei Pathway in UI, con fog of war sulla conoscenza

**Criterio di uscita:** si puo' partire da Sequenza 9 e arrivare a Sequenza 5
giocando, con avanzamenti veri, follia che cresce e Ancore che contano.

---

## Fase 3 — Sistemi di supporto (~28 story)

- Inventario e equipaggiamento con tag di sinergia
- **Oggetti con `stored_ability_id`**: pergamene e congegni che contengono
  un'abilita' eseguibile al consumo. Sblocca sinergie tra Pathway diversi
  (un Paragon puo' costruire un oggetto che contiene un'abilita' del Fool).
- Alchimia: qualita', fallimenti mostruosi, scoperta delle ricette
- Forgiatura e incisione di sigilli
- Oggetti Sigillati con effetti collaterali
- Un pet completo: taming, `bond`, coltivazione del pet, morte del pet come
  perdita di Ancora
- Base building: griglia, 4 stanze funzionali (laboratorio, stanza rituale,
  biblioteca, giardino)
- Talenti innati e talenti acquisiti per osservazione del comportamento

---

## Fase 4 — Sinergie (~16 story)

- Motore dei tag: raccolta dei tag attivi da tutte le fonti
- Risoluzione delle regole di sinergia, con priorita' e conflitti
- Anti-sinergie
- Registro delle sinergie scoperte
- 30-40 sinergie di contenuto (story di soli dati)

**Criterio di uscita:** una sinergia nata da pet + stanza + talento si attiva
davvero, senza codice dedicato.

---

## Fase 5 — Espansione contenuti (~13 story, quasi tutte di dati)

I restanti 9 Pathway. **Una story per Pathway** se l'architettura ha retto.
Se qui servono `if` speciali, la fase 2 ha sbagliato qualcosa e va corretta
prima di proseguire: e' il punto di controllo dell'intero progetto.

Ordine consigliato in `006_PRD/design-pathways.md`: Death, Moon, Mother,
Paragon, Hermit, Darkness, e per ultimi Fool / Error / Door, che richiedono
le primitive piu' difficili da rendere leggibili a schermo.

Piu' le 13 primitive attive rimanenti (28 attive totali, 3 differite).

---

## Fase 6 — Mondo (~35 story)

- **Musica a layer per zona**: stem di base sempre attivo + stem che entrano
  su tensione/combattimento/boss, con crossfade. Riduce i minuti di musica da
  comporre e toglie il taglio brusco all'ingresso in combattimento.
- **Drone del rituale**: build di 45 secondi, e su interruzione taglio SECCO
  al silenzio prima della perdita di controllo.
- Ambienti sonori per zona, ciclo giorno/notte anche in audio

- 4-6 regioni disegnate a mano
- Gating per primitiva: `teleport`, `plant_growth`, `shadow_meld` aprono strade diverse
- Densita' mistica per zona
- Ciclo giorno/notte e fasi lunari con effetti meccanici
- Fazioni e reputazione
- NPC, dialoghi, quest
- Segreti e lore

---

## Fase 7 — Endgame (~20 story)

- Cambio Pathway con `fusion_rules` data-driven
- Sequenze alte: autorita', seguaci, preghiere
- Unicita' della Sequenza 0: l'NPC che occupa il posto
- Tribolazioni ai salti di fascia
- Finali multipli, incluso il game over per follia con eredita' al personaggio
  successivo

---

## Fase 8 — Opzionale

Pathway Non-Standard (Eternal Aeon, Chaos Primogenitor, Scrooge, Dreamless e
gli altri bestowers). Meccanica diversa: avanzamento per **Boon** invece che
per pozione, quindi non e' solo contenuto ma un secondo sistema di
progressione. Da fare solo a fasi 1-7 chiuse.
