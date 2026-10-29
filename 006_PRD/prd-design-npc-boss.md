# PRD: Design del gioco — NPC e Boss

## 1. Introduzione/Overview

Quarto dei cinque documenti "bibbia di design". Descrive tutti i 25 NPC
del roster, i 5 boss (uno per regione), le 4 fazioni, le 5 Ancore e le 4
quest esistenti — tratti da `data/npc/roster.json` +
`data/dialogues/*.json` + `data/factions.json` + `data/anchors.json` +
`data/quests/*.json` + `data/i18n/it.json`.

## 2. Come funziona (meccanica, non contenuto)

- **Un NPC è dati**: presenza in scena secondo `schedule`
  (momento→location_tag), un `dialogue_id` che risolve un grafo di nodi/
  scelte, una `faction_id` opzionale, `anchor_candidate` (può diventare
  un'Ancora contro la follia), `vendor`/`crafter` opzionali (fase 11).
  Zero `if npc_specifico` nel motore.
- **Un boss non è un tipo**: un `nemici[]` con `sequenza` più bassa,
  `override` più duro, `scala` maggiore — vedi sotto.
- **Le fazioni** hanno reputazione numerica e soglie fisse; comportamenti
  speciali (reazione al potere, sospetto crescente) sono campi dati letti
  genericamente da `FactionSystem`, mai un `if` per fazione.
- **Le Ancore** bufferizzano la follia in arrivo finché attive; perderle
  fa più danno di follia di quanto avrebbero assorbito.

## I 25 NPC

Il roster ha 8 NPC nominati con dialogo/ruolo propri, 10 `npc_generic_*` (popolani intercambiabili, stesso dialogo minimo `dlg_generic`), `npc_antagonista` (l'avversario strutturale), e i 6 NPC crafter/mercante arrivati con la fase 11 (già catalogati per intero in `prd-design-oggetti-economia.md` §5 — qui solo un riferimento breve).


### Mirco (`npc_mirco`)

*Primo volto amichevole, insegna le basi*

- Regione: `mirwada` · Fazione: `quartiere` · Candidato Ancora: sì

- Presenza: alba→piazza; mezzogiorno→piazza; crepuscolo→vicolo; notte_fonda→assente

- Dialogo (`dlg_mirco`, 3 nodi): "Sei nuovo da queste parti. Sta' attento a chi ascolti."



### Sidon (`npc_sidon`)

*Mercante di reagenti e voci*

- Regione: `mirwada` · Fazione: `porto` · Candidato Ancora: no

- Presenza: alba→porto; mezzogiorno→porto; crepuscolo→porto; notte_fonda→assente

- Dialogo (`dlg_sidon`, 3 nodi): "Reagenti freschi, e qualche voce se ti interessa."

- Mercante: 64 oggetti nel listino



### Vesna (`npc_vesna`)

*Guaritrice ai margini, diffida dei Beyonder*

- Regione: `mirwada` · Fazione: `quartiere` · Candidato Ancora: sì

- Presenza: alba→vicolo; mezzogiorno→vicolo; crepuscolo→vicolo; notte_fonda→assente

- Dialogo (`dlg_vesna`, 3 nodi): "Se sei ferito posso aiutarti. Se sei uno di loro, gira al largo."

- Mercante: 26 oggetti nel listino



### Aldo (`npc_aldo`)

*Ex collega, ora rivale in ascesa*

- Regione: `mirwada` · Fazione: `—` · Candidato Ancora: no

- Presenza: alba→assente; mezzogiorno→piazza; crepuscolo→piazza; notte_fonda→assente

- Dialogo (`dlg_aldo`, 3 nodi): "Guarda chi si vede. Ancora a inseguire, eh?"



### Ottavia (`npc_ottavia`)

*Archivista di un ordine minore*

- Regione: `mirwada` · Fazione: `ordine_minore` · Candidato Ancora: no

- Presenza: alba→archivio; mezzogiorno→archivio; crepuscolo→archivio; notte_fonda→assente

- Dialogo (`dlg_ottavia`, 2 nodi): "L'Archivio non e' per curiosi. Cosa cerchi?"



### Bruno (`npc_bruno`)

*Contrabbandiere del porto*

- Regione: `mirwada` · Fazione: `porto` · Candidato Ancora: no

- Presenza: alba→assente; mezzogiorno→assente; crepuscolo→porto; notte_fonda→porto

- Dialogo (`dlg_bruno`, 2 nodi): "Di giorno non ci siamo visti. Adesso, cosa vuoi?"

- Mercante: 29 oggetti nel listino



### Lena (`npc_lena`)

*Bambina del quartiere operaio*

- Regione: `mirwada` · Fazione: `quartiere` · Candidato Ancora: sì

- Presenza: alba→vicolo; mezzogiorno→piazza; crepuscolo→vicolo; notte_fonda→assente

- Dialogo (`dlg_lena`, 3 nodi): "Nessuno vuole mai giocare. Tu giochi?"



### Doran (`npc_doran`)

*Investigatore che segue le tue tracce*

- Regione: `mirwada` · Fazione: `giustizia` · Candidato Ancora: no

- Presenza: alba→vicolo; mezzogiorno→piazza; crepuscolo→vicolo; notte_fonda→porto

- Dialogo (`dlg_doran`, 3 nodi): "Strane coincidenze intorno a te. Ti dispiace se ti faccio qualche domanda?"



### La Soglia (`npc_antagonista`)

*Il detentore precedente della tua Sequenza 0*

- Regione: `frontiera_porte` · Fazione: `—` · Candidato Ancora: no

- Presenza: notte_fonda→soglia

- Dialogo (`dlg_antagonista`, 2 nodi): "Sei arrivato dove mi sono fermato io. La stessa Sequenza, la stessa soglia. Cosa ti fa credere di poterla varcare?"



### Rosalba (`npc_rosalba`)

*Erborista dell'avamposto*

- Regione: `valle_madre` · Fazione: `—` · Candidato Ancora: no

- Presenza: sempre nello stesso interno (nessuno schedule — un crafter/mercante di villaggio)

- Dialogo (`dlg_rosalba`, 1 nodi): "Le radici parlano, se sai ascoltarle. Portami cio' che serve e ti preparo qualcosa di vero."

- Crafter: crea su richiesta `ric_cura_maggiore`, `ric_filtro_di_chiarezza`



### Bram (`npc_bram`)

*Fabbro di Mirwada*

- Regione: `mirwada` · Fazione: `—` · Candidato Ancora: no

- Presenza: sempre nello stesso interno (nessuno schedule — un crafter/mercante di villaggio)

- Dialogo (`dlg_bram`, 1 nodi): "Il ferro non mente. Portamelo giusto e ti forgio quello che serve."

- Crafter: crea su richiesta `bp_spada_ferrea`, `bp_anello_di_cristallo`



### Fenwick (`npc_fenwick`)

*Fabbro del villaggio fuori le mura*

- Regione: `marche_crepuscolo` · Fazione: `—` · Candidato Ancora: no

- Presenza: sempre nello stesso interno (nessuno schedule — un crafter/mercante di villaggio)

- Dialogo (`dlg_fenwick`, 1 nodi): "Lontano dalle mura si forgia meglio: nessuno viene a controllare la fiamma."

- Crafter: crea su richiesta `bp_ascia_da_guerra`, `bp_scudo_rinforzato`



### Greta (`npc_greta`)

*Mercante del villaggio fuori le mura*

- Regione: `marche_crepuscolo` · Fazione: `—` · Candidato Ancora: no

- Presenza: sempre nello stesso interno (nessuno schedule — un crafter/mercante di villaggio)

- Dialogo (`dlg_greta`, 1 nodi): "Chi vive fuori dalle mura impara a portarsi dietro solo cose che valgono davvero."

- Mercante: 4 oggetti nel listino



### Orsolya (`npc_orsolya`)

*Alchimista del villaggio dell'Archivio*

- Regione: `archivio_sepolto` · Fazione: `—` · Candidato Ancora: no

- Presenza: sempre nello stesso interno (nessuno schedule — un crafter/mercante di villaggio)

- Dialogo (`dlg_orsolya`, 1 nodi): "Le pagine dell'Archivio hanno insegnato piu' loro a me che io a chiunque altro."

- Crafter: crea su richiesta `ric_tonico_di_forza`, `ric_essenza_rara_di_guarigione`



### Dario (`npc_dario`)

*Mercante del villaggio dell'Archivio*

- Regione: `archivio_sepolto` · Fazione: `—` · Candidato Ancora: no

- Presenza: sempre nello stesso interno (nessuno schedule — un crafter/mercante di villaggio)

- Dialogo (`dlg_dario`, 1 nodi): "Chi scava vicino a rovine antiche trova cose che non si vendono a chiunque."

- Mercante: 3 oggetti nel listino



### I 10 `npc_generic_*` (popolani)

Abitanti intercambiabili di Mirwada, stesso dialogo minimo (`dlg_generic`, 1 nodo: "Si'? Cosa vuoi?"), nessuna fazione, nessuno stato di anchor. Riempiono le zone della città secondo lo schedule di ognuno (alba/mezzogiorno/crepuscolo/notte_fonda → location_tag), dando la sensazione di una città viva anche senza una storia propria per ognuno.


- `npc_generic_01`: alba→piazza; mezzogiorno→piazza; crepuscolo→piazza; notte_fonda→assente

- `npc_generic_02`: alba→vicolo; mezzogiorno→porto; crepuscolo→piazza; notte_fonda→assente

- `npc_generic_03`: alba→piazza; mezzogiorno→piazza; crepuscolo→vicolo; notte_fonda→assente

- `npc_generic_04`: alba→porto; mezzogiorno→porto; crepuscolo→porto; notte_fonda→vicolo

- `npc_generic_05`: alba→piazza; mezzogiorno→vicolo; crepuscolo→piazza; notte_fonda→assente

- `npc_generic_06`: alba→vicolo; mezzogiorno→piazza; crepuscolo→vicolo; notte_fonda→assente

- `npc_generic_07`: alba→piazza; mezzogiorno→porto; crepuscolo→piazza; notte_fonda→assente

- `npc_generic_08`: alba→archivio; mezzogiorno→archivio; crepuscolo→piazza; notte_fonda→assente

- `npc_generic_09`: alba→vicolo; mezzogiorno→piazza; crepuscolo→porto; notte_fonda→assente

- `npc_generic_10`: alba→piazza; mezzogiorno→piazza; crepuscolo→piazza; notte_fonda→assente


## I 5 Boss

Un boss non è un tipo di nemico nel codice: è un `nemici[]` di layout con
`sequenza` più bassa (più forte, in una progressione Sequenza-inversa),
`override` più duro e `scala: 1.5` — dati, mai un `if boss`. Ogni regione
ne ha esattamente uno, e il tag/pathway del suo `override.caratteristica`
lo lega tematicamente al gruppo della regione:

| Regione | Sequenza | Tag | Pathway associato | Danno attacco | Raggio aggro |
|---|---|---|---|---|---|
| Mirwada | 8 | `bestia` | Twilight Giant (Seq 8) | 15 | 200 |
| Marche del Crepuscolo | 7 | `non_morto` | Twilight Giant (Seq 7) | 15 | 200 |
| Valle della Madre | 7 | `bestia` | Mother (Seq 7) | 15 | 200 |
| Archivio Sepolto | 6 | `spirito` | Hermit (Seq 6) | 15 | 200 |
| Frontiera delle Porte | 5 | `ombra` | Fool (Seq 5) | 15 | 200 |

Il boss di Mirwada (Twilight Giant, Sequenza 8) è il più debole dei 5 —
coerente con Mirwada come hub di partenza; quello della Frontiera delle
Porte (Fool, Sequenza 5) è il più forte, coerente con la Frontiera come
regione a densità mistica più alta (0.9) e con un gating a Sequenza ≤4
per l'ingresso più interno.

## Le 4 fazioni

Vocabolario ristretto (`data/factions.json`), reputazione come numero con
4 soglie (`ostile −30` · `neutrale 0` · `amichevole 20` · `alleato 50`),
mai un `if` per fazione nel codice — un comportamento speciale è un campo
dato letto genericamente da `FactionSystem`.

- **L'Ordine Minore** (`ordine_minore`) — Ottavia.
- **Il Porto** (`porto`) — Sidon, Bruno.
- **Il Quartiere** (`quartiere`) — Mirco, Vesna, Lena. Reazione al potere:
  usare un'abilità davanti a Vesna presente costa 5 reputazione — l'unica
  fazione con questo comportamento.
- **La Giustizia** (`giustizia`) — Doran, fazione da un uomo solo: il suo
  "sospetto" sale di 3 a ogni `ability_used` in Mirwada, e a soglia 30
  scrive il flag `doran_sospetto_alto` — nessun codice dedicato a Doran,
  è il dato a dichiarare il comportamento.

Aldo (rivale in ascesa) non appartiene a nessuna fazione: la sua storia
personale (il duello ai salti di tier, `sfida_ai_tier`) è indipendente
dalla reputazione.

## Le 5 Ancore

Un'Ancora (`data/anchors.json`) bufferizza parte della follia in arrivo
(fino a `forza` punti, mai più del 60% di un colpo); perderla infligge
`penalita` follia invece, senza buffer. Tre sono legate a un NPC/pet, due
sono astratte:

| Ancora | Forza | Penalità se persa | Cos'è |
|---|---|---|---|
| `anchor_mirco` | 10 | 18 | L'amico che ti ha visto prima che tutto cominciasse |
| `anchor_sidon` | 8 | 14 | — |
| `anchor_dimora` | 6 | 10 | Un luogo, non una persona |
| `anchor_promessa` | 12 | 24 | Una promessa fatta — il colpo più duro da perdere |
| `anchor_pet` | 7 | 16 | Il proprio pet (US-321), un'Ancora come le altre |

Separatamente, 3 NPC sono `anchor_candidate` (Mirco, Vesna, Lena):
conoscerli abbastanza permette di promuoverli ad Ancora attiva
(`NpcSystem.promuovi_ancora`), oltre al sacrificio esplicito
`ancora_del_giocatore` che il rituale di Sequenza 1 del Twilight Giant
richiede.

## Le 4 quest di Atto I

Tutte le quest esistenti nel gioco sono di Atto I (Fase 12 pianificata
scrive quelle di Atto II/III):

| Quest | Nome | Chi la dà | Passi |
|---|---|---|---|
| `q_mirco_01` | Le basi | Mirco | 1 — sconfiggi 3 nemici senza abilità (tutorial diegetico) |
| `q_sidon_01` | Merce di scambio | Sidon | 1 |
| `q_vesna_01` | Il beneficio del dubbio | Vesna | 1 |
| `q_lena_01` | Un momento per giocare | Lena | 1 |

## Proposte per il futuro

### US-D12: Una quest per ogni crafter dei villaggi in campagna

**Descrizione:** Come giocatore, voglio conoscere Fenwick/Greta/Orsolya/
Dario oltre al semplice compra/crea — oggi solo i 4 NPC dell'Atto I
originale hanno una quest, i 6 arrivati in fase 11 no.

**Acceptance Criteria:**
- [ ] Almeno 2 nuove quest (`data/quests/*.json`) con `giver` uno dei 6
      NPC di fase 11, riusando solo verbi di completamento esistenti.
- [ ] Tests pass. `python tools/validate_data.py` esce 0.

### US-D13: Un secondo boss riconoscibile per gruppo (non solo per regione)

**Descrizione:** Come giocatore, voglio che il boss della Frontiera delle
Porte (associato a Fool) e uno di un'altra regione dello stesso gruppo
Lord of Mysteries (che oggi non ha altre regioni) si sentano collegati -
oggi ogni gruppo standard ha 2-3 Pathway ma solo Mirwada/Marche
condividono esplicitamente Twilight Giant come tag boss.

**Acceptance Criteria:**
- [ ] Documentare esplicitamente (in questo file o nei dati) perché ogni
      boss usa il tag/pathway che usa, o cambiarlo per coerenza di gruppo.
- [ ] Nessuna modifica di codice richiesta se la risposta è "va bene
      così" — questa story può chiudersi con la sola documentazione.

### US-D14: Doran e Aldo ottengono una fazione propria a una cifra

**Descrizione:** Come giocatore, voglio che Aldo (oggi senza fazione)
abbia un modo dichiarato per il giocatore di influenzarlo, coerente con
Doran (fazione da un uomo solo).

**Acceptance Criteria:**
- [ ] Una nuova fazione a un membro per Aldo in `data/factions.json`, o
      una motivazione esplicita documentata per cui non ne ha una (il
      duello ai salti di tier basta da solo).

## Non-Goals

- I 10 `npc_generic_*` non hanno un dialogo/una storia propri per design:
  riempiono la città, non sono personaggi (CLAUDE.md, "diff minimo").
- Le fazioni dei 12 gruppi di Pathway differiti non esistono e non sono
  proposte qui: fuori scope (CLAUDE.md).
- Il contenuto di Atto II/III ("Doran sa, Lena capisce, Vesna sceglie")
  vive nella Fase 12 pianificata, non qui.

## Open Questions

- Aldo è l'unico NPC nominato senza `faction_id` né `anchor_candidate`: è
  intenzionale (la sua storia passa dal duello, non da fazione/Ancora) o
  una lacuna?
- I 3 anchor_candidate (Mirco, Vesna, Lena) sono tutti della fazione
  Quartiere: è voluto che nessun altro NPC nominato possa diventare
  un'Ancora, o è un'estensione naturale per il futuro?
