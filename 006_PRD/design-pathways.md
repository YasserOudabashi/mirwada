# Design dei 10 Pathway attivi

## Perché questi dieci

Il criterio non è "i più belli" né "i più simili". È **quattro gruppi
completi**.

In questo sistema il cambio di Pathway — la meccanica di endgame in cui il
giocatore conserva i poteri delle Sequenze basse del vecchio Pathway e li
**fonde** con quelli del nuovo, generando abilità mutate che non esistono
altrove — funziona solo tra Pathway vicini dello stesso gruppo. Scegliere
Pathway sparsi avrebbe risparmiato la stessa quantità di dati e avrebbe
ucciso la fase 7.

Con quattro gruppi interi restano possibili **8 percorsi di fusione** distinti,
e la geografia narrativa (chi è alleato di chi, quali chiese controllano cosa)
resta coerente.

| Gruppo | Pathway | Fusioni possibili |
|---|---|---|
| Lord of Mysteries (i Tre Pilastri) | Fool, Error, Door | 3 |
| Eternal Darkness | Darkness, Death, Twilight Giant | 3 |
| Demon of Knowledge | Hermit, Paragon | 1 |
| Goddess of Origin | Mother, Moon | 1 |

## Copertura dei pilastri

Ogni pilastro di design ha almeno un Pathway **nativo**, cioè uno che lo
tratta come attività principale invece che come contorno. Senza questo, un
pilastro diventa un sistema che nessuna build vuole davvero usare.

| Pilastro | Pathway nativo | Supporto |
|---|---|---|
| Combattimento | Twilight Giant | Death, Darkness, Fool |
| Crafting | Paragon | Moon (alchimia), Mother (ingredienti) |
| Pet | Moon | Death (evocazioni), Mother (chimere) |
| Costruzione | Mother, Paragon | Hermit (stanze rituali) |
| Coltivazione | tutti | — |
| Esplorazione | Door | Darkness (stealth), Mother (terreno) |
| Sinergie | tutti | — |

## Varietà di gioco

Il rischio di tagliare da 22 a 10 è l'omogeneità. Questi dieci coprono dieci
verbi diversi:

| Pathway | Verbo | Come si sente al pad |
|---|---|---|
| Twilight Giant | picchiare | mischia diretta, parate, stance, tank |
| Death | comandare | l'esercito combatte, tu posizioni |
| Darkness | negare | stealth, paura, sfortuna; vinci prima dello scontro |
| Fool | dirottare | i nemici combattono tra loro, tu sei altrove |
| Error | derubare | usi il kit del nemico contro di lui |
| Door | eludere | riposizionamento costante, il combattimento è geografia |
| Hermit | preparare | rituali e pergamene: vinci prima di entrare nella stanza |
| Paragon | costruire | torrette, costrutti, congegni; combatti per procura |
| Mother | trasformare | il terreno è l'arma, crescita e drenaggio |
| Moon | crescere | il pet è il vero personaggio, tu lo sostieni |

Dieci verbi distinti su dieci Pathway. Nessuna coppia si sovrappone.

## Cosa si è perso, esplicitamente

I 12 Pathway differiti sono in `data/pathways_deferred/`, completi delle 10
Sequenze. Non sono cancellati: sono fuori scope, riattivabili spostando un
file e aggiornando `ACTIVE` nel generatore.

Le assenze che pesano davvero:

- **Sun** — l'unico guaritore/supporto puro e l'unico che riduce la Sequenza
  nemica. Le build di supporto perdono il loro archetipo naturale. Compensato
  in parte da Moon (cure) e Twilight Giant (protezione).
- **Red Priest / Demoness** — fuoco e assassinio, i due archetipi di
  combattimento più immediati e riconoscibili. È la perdita più evidente per
  un giocatore che arriva dal romanzo.
- **Wheel of Fortune** — l'unico che manipola la probabilità in modo esplicito,
  meccanica firma e senza sostituti. Insieme a lui è stata differita la
  primitiva `probability_shift`.
- **Justiciar / Black Emperor** — l'asse ordine/caos. L'anti-sinergia
  `anti_ordine_disordine` in `data/synergies/core.json` resta scritta ma non
  attivabile: tienila lì come promemoria per un'eventuale riattivazione.

Se un giorno se ne riattiva uno, **riattiva il suo gruppo intero**, mai il
singolo Pathway.

### Sinergie che si accendono riattivando un gruppo (US-415)

`data/synergies/batch_3.json` contiene 16 sinergie già scritte che richiedono
tag portati **solo** da Pathway di gruppi differiti. Restano inattive (il
validator le conta in una riga sola, `N sinergie irraggiungibili…`). Riattivare
il gruppo le accende **senza nuovo codice** — è la prova che l'architettura
regge oltre le 10 Sequenze. Mappa gruppo → sinergie:

| Gruppo differito | Pathway | Sinergie di `batch_3.json` che si attivano |
|---|---|---|
| `father_of_devils` | Abyss, Chained | `sinergia_patto_abissale`, `sinergia_carne_mutevole`, `sinergia_marchio_corrotto` |
| `the_anarchy` | Justiciar, Black Emperor | `sinergia_legge_di_ferro`, `sinergia_giudizio_supremo`, `sinergia_anarchia_pura`, `anti_legge_e_caos` (+ `anti_ordine_disordine` in `core.json`) |
| `calamity_of_destruction` | Demoness, Red Priest | `sinergia_specchio_infranto`, `sinergia_via_del_fuoco`, `sinergia_campo_minato` |
| `god_almighty` | Hanged Man, Sun, Tyrant, Visionary, White Tower | `sinergia_sussurri_appesi`, `sinergia_contratto_solare`, `sinergia_tempesta_vivente`, `sinergia_sogno_lucido`, `sinergia_verita_rivelata` |
| `key_of_light` | Wheel of Fortune | `sinergia_ruota_favorevole` (+ `sinergia_inganno_probabilita` in `core.json`) |

Dopo aver riattivato un gruppo: rilancia `tools/generate_i18n_stubs.py` (le
sinergie hanno già le chiavi i18n, ma i nuovi Pathway/Sequenze no) e verifica
che il conteggio delle irraggiungibili nel validator sia sceso.

## Effetto reale sul carico di lavoro

È utile essere precisi, perché l'intuizione qui inganna.

| | 22 Pathway | 10 Pathway | Risparmio |
|---|---|---|---|
| Sequenze da progettare | 220 | 100 | 55% |
| Abilità stimate | ~450 | ~200 | 55% |
| **Primitive da implementare** | 31 | **28** | **10%** |
| Story di dati (fase 5) | ~25 | ~11 | 56% |
| Story di codice | invariate | invariate | 0% |

Il taglio dimezza il **contenuto**, non il **codice**. Il codice dipende dal
numero di primitive, e dieci Pathway ben scelti ne toccano quasi tutte lo
stesso. È il risultato atteso dell'architettura data-driven: era esattamente
il suo scopo rendere il contenuto economico e il codice costante.

Le tre primitive differite — `weather_control`, `probability_shift`,
`rule_bind` — sono marcate nel registro e il validator **rifiuta** un'abilità
che le usi. Sono le uniche righe di codice che il taglio ha davvero eliminato.

## Il gold standard

`data/abilities/twilight_giant.json` contiene il Twilight Giant **completo**:
20 abilità dalla Sequenza 9 alla 0, con modificatori di statistiche, azioni di
recitazione, ingredienti delle pozioni e rituali di avanzamento per ogni
livello.

Serve a due cose.

**È la prova dell'architettura.** Zero righe di codice sono dedicate al
Twilight Giant. Un Pathway intero, dal principiante al dio, esiste solo come
dati. Se questo non fosse stato possibile, l'impianto sarebbe stato da
ripensare prima di scrivere il gioco, non dopo.

**È il modello da imitare.** Ogni story di dati delle fasi successive va
scritta guardando questo file. In particolare, nota:

- `tg_postura_inviolabile` ha un **trade-off esplicito** (difesa +70%,
  velocità −50%): le abilità di alta Sequenza devono costare qualcosa nel
  momento in cui le usi, non solo in spiritualità.
- `tg_crepuscolo` ha `colpisce_oggetti: true`, quindi degrada **anche le
  strutture costruite dal giocatore**. Il potere di Sequenza 2 danneggia la
  tua base. È voluto ed è il tipo di aggancio tra sistemi che rende il gioco
  interessante.
- L'azione di recitazione di Sequenza 2 è *"lascia decadere una struttura che
  avevi costruito"*. La recitazione non è una barra da riempire: chiede al
  giocatore di **accettare la natura del proprio potere**, e in questo caso di
  distruggere qualcosa che ha fatto.
- Il sacrificio del rituale di Sequenza 1 è **un'Ancora del giocatore**. Per
  avvicinarsi al divino bisogna bruciare ciò che ti tiene umano, e la follia
  sale di conseguenza. Il sistema di Ancore e quello di avanzamento si mordono
  a vicenda per costruzione.
- `madness_on_force` cresce da 1.0 a 13.6 lungo il Pathway: forzare un
  avanzamento a Sequenza bassa è recuperabile, a Sequenza alta ti distrugge.

## Ordine di implementazione consigliato

1. **Twilight Giant** (fase 2) — già scritto, il più leggibile a schermo, e
   stressa poche primitive difficili. Se il motore lo esegue correttamente,
   l'architettura è validata.
2. **Death** (fase 5) — introduce `summon` e le entità persistenti, che
   servono anche a pet e costrutti. Va fatto presto perché sblocca altri
   sistemi.
3. **Moon** e **Mother** — sbloccano rispettivamente pet e ingredienti, cioè
   i pilastri di fase 3.
4. **Paragon** — crafting e costrutti; dipende da `summon` di Death.
5. **Hermit** — rituali; dipende dalle stanze rituali di fase 3.
6. **Darkness** — richiede il ciclo giorno/notte di fase 6.
7. **Fool**, **Error**, **Door** — ultimi. Sono i più belli e i più difficili:
   `illusion`, `possess`, `steal` e `time_rewind` sono le primitive più dure da
   rendere leggibili a schermo. Vanno affrontate quando il resto è stabile,
   non prima.

---

## Stress test del registro delle primitive

Prima di scrivere una riga di codice ho scritto un'abilita' di alta Sequenza
per ognuno dei 9 Pathway non ancora implementati, scegliendo deliberatamente
quelle piu' difficili: il Marionettista del Fool, il furto di abilita' dell'Error,
la cancellazione percettiva del Darkness, il terraforming del Mother.

**Risultato: 12 primitive usate, nessuna fuori dal registro.** Il vincolo delle
28 primitive regge. Era il rischio numero due del progetto e ora e' chiuso.

Ma il test ha trovato **tre capacita' del motore** che il registro non copre e
che avevo dato per scontate. Non sono primitive nuove: sono cose che
`AbilityEngine` e il sistema di inventario devono saper fare.

### 1. Eseguire un'abilita' non posseduta (Error, Sequenza 6)

`steal` con `categoria: "abilita"` presta al giocatore un'abilita' vista sul
nemico. Il motore deve poter eseguire un `ability_id` che non appartiene al
Pathway del giocatore, con una durata di prestito e una scadenza.

*Dove va:* PRD di fase 2, story dedicata su `AbilityEngine`. E' economica se
prevista, costosa se scoperta a fase 5 con il motore gia' scritto.

### 2. Oggetti che portano un'abilita' (Hermit, Sequenza 6)

Le pergamene monouso dell'Hermit **non sono un'abilita'**. Sono un oggetto con
un campo `stored_ability_id` che l'inventario invoca al consumo. Ho provato a
modellarle come primitiva e non funziona: e' un'interazione tra crafting,
inventario e motore delle abilita'.

*Dove va:* PRD di fase 3, sistema inventario. E sblocca gratis un'idea di
design: qualunque Pathway puo' produrre oggetti che contengono abilita' di
altri Pathway, che e' una sorgente di sinergie che non avevo previsto.

### 3. Entita' evocate persistenti (Death e Paragon, Sequenza 2)

`summon` con `durata: -1` crea evocazioni che sopravvivono al combattimento e
al cambio di scena. Il motore deve serializzarle nel save e ricrearle al
caricamento.

*Dove va:* PRD di fase 2 per la logica, e criterio di accettazione in US-015
(salvataggio) per la serializzazione.

### Perche' questo test valeva un'ora

Tutte e tre sarebbero emerse in fase 5, con il motore gia' scritto e 60 story
committate sopra. La numero 1 in particolare avrebbe richiesto di riscrivere
`AbilityEngine`, cioe' il pezzo su cui poggia tutto il resto.

**Fai questo stress test ogni volta che chiudi un sistema nuovo:** scrivi il
caso piu' difficile che il sistema dovra' reggere e verifica che i dati lo
esprimano, prima di scrivere il codice.
