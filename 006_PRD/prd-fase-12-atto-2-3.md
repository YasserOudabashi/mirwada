# PRD: Fase 12 — Atto II e Atto III (le regioni che si aprono, la soglia)

> **Rinumerata in corsa (2026-09-12, US-1114)**: questa fase era la
> "Fase 11" pianificata quando questo PRD è stato scritto. L'utente ha poi
> chiesto una nuova fase di villaggi/economia/rarità (crafting NPC, oggetti
> rari, insediamenti nella campagna) che è diventata la vera Fase 11
> (`006_PRD/prd-fase-11-villaggi-ed-economia.md`, US-1101..1114): questa
> fase è slittata a Fase 12, e le sue story (originariamente US-1101..1113)
> sono state rinumerate US-1201..1213 per non collidere. Nessun contenuto
> è cambiato, solo i numeri.

## 1. Introduzione / Overview

`006_PRD/design-npc-quest.md` §5 disegna tre atti agganciati alle fasce di
tier del giocatore, non a capitoli scritti a mano:

- **Atto I — la città (Seq 9-7).** REALIZZATO in fase 6: 4 quest
  (`q_mirco_01`, `q_sidon_01`, `q_vesna_01`, `q_lena_01`), i dialoghi degli
  8 NPC nominati, le fazioni. Finisce quando "il primo rituale non basta
  più" — meccanicamente già vero: `npc_system.gd::_su_rituale` scrive il
  flag `atto_1_concluso` al primo `advancement_ritual` di Sequenza ≤ 6.
- **Atto II — le regioni (Seq 6-4).** "Le regioni si aprono, le fazioni
  prendono posizione, Aldo avanza in parallelo, i rituali chiedono luoghi
  veri e sacrifici veri." Oggi le regioni SONO aperte (gating di fase 6),
  Aldo avanza DAVVERO in parallelo (`npc_system.gd::_su_momento`,
  `avanzamento_temporale` nel roster) e offre un duello ai salti di tier
  (`sfida_ai_tier`) — tutto meccanico, **zero quest scritte intorno**.
- **Atto III — la soglia (Seq 3-1).** Tribolazioni (`TribulationSystem`,
  fase 7), Frontiera delle Porte, il rituale di Sequenza 1 che chiede
  un'Ancora (`advancement_ritual.sacrifices: ["ancora_del_giocatore"]`,
  già nei dati del Twilight Giant). "Doran sa. Lena capisce. Vesna
  sceglie" — tre frasi di design mai diventate contenuto.
- **Finale — Sequenza 0.** REALIZZATO in fase 7: 3 finali
  (`data/endings.json`), 12 epiloghi di gruppo già scritti per intero (3
  finali × 4 gruppi), eredità al personaggio successivo.

**Quello che manca non è un motore: è contenuto.** Verificato leggendo i
dati prima di scrivere questo PRD:

- Le 4 tribolazioni (`data/tribulations/trib_7_6.json` … `trib_1_0.json`)
  hanno già una condizione di superamento **soddisfacibile in gioco**, ma
  minima: `trib_7_6` = 2 `area_cleared` (nessun NPC coinvolto),
  `trib_5_4` = 3 `npc_influenced` generici (nessuna scena dedicata),
  `trib_3_2` = un flag scritto da **un'unica scelta di dialogo** già
  presente in `dlg_doran.json` (`tribolazione_doran_affrontato`, dietro
  `tier_min: saint`), `trib_1_0` = il flag `tribolazione_soglia_varcata`,
  che oggi **non lo scrive nessun dialogo o quest** (grep confermato: 0
  occorrenze fuori dal file della prova stessa).
- Solo 4 quest esistono in tutto il gioco, tutte di Atto I. Zero quest di
  Atto II o Atto III.
- `dlg_lena.json`/`dlg_vesna.json` non hanno nodi condizionati al tier del
  giocatore: "Lena capisce" e "Vesna sceglie" (design cap. 5) non sono mai
  stati scritti.
- Gli epiloghi di finale sono scritti e buoni (verificato: 15 chiavi
  `ending.*` in `it.json`, tutte con prosa reale, non stub `TODO`). Non
  c'è lavoro da fare lì.

Questa fase scrive quel contenuto, riusando **esclusivamente** motori già
esistenti: `QuestSystem` (lettore di eventi/flag, zero verbi nuovi),
`DialogueEngine` (stesso vocabolario chiuso di condizioni/effetti),
`FactionSystem` (reputazione già cablata), `TribulationSystem` (le 4 prove
esistono già, restano invariate — questa fase le VESTE di contenuto, non le
tocca come dati di struttura).

### Dipendenza dichiarata dalla Fase 10

Per scelta esplicita dell'utente, la Fase 10 (Mondo Continuo: mappa unica,
villaggi, strutture grandi) precede questa fase. I siti dei rituali di
Sequenza 0 (`data/lore/antagonisti.json`, uno per Pathway, già esistenti
come indizi) e il luogo del duello con Aldo diventano luoghi fisici veri
nel mondo continuo, non zone generiche. Se questa fase parte prima che la
Fase 10 sia chiusa, quei riferimenti restano su `location_tag` esistenti
(funzionano lo stesso, solo meno "vero") — nessuna story qui è bloccata
dall'altra, ma l'ordine consigliato resta mappa-prima.

## 2. Goals

- Ogni salto di tribolazione (7→6, 5→4, 3→2, 1→0) è superabile attraverso
  **almeno una scena narrativa riconoscibile**, non solo un contatore
  anonimo — mantenendo la condizione di superamento dati esistente
  invariata (nessuna modifica a `data/tribulations/`).
- Atto II ha **almeno 2 quest** nuove: una che fa "prendere posizione" a
  una fazione (reputazione che si muove per una scelta narrativa, non per
  farming), una legata al duello con Aldo.
- Atto III scrive le tre reazioni di design ("Doran sa, Lena capisce,
  Vesna sceglie") come contenuto giocabile, agganciato al tier del
  giocatore (condizioni `tier_min` esistenti nel vocabolario dialoghi).
- `trib_1_0` (l'unica prova oggi orfana di contenuto) ha una fonte reale
  per il suo flag `tribolazione_soglia_varcata`.
- Il rituale di Sequenza 1 che chiede un'Ancora (`ancora_del_giocatore`
  come `sacrifices`) è verificato/esteso a **tutti e 10** i Pathway attivi,
  non solo il Twilight Giant — con motivazione esplicita se qualcuno resta
  fuori.
- Nessuna primitiva nuova, nessun evento tracciato nuovo, nessun tipo di
  condizione/effetto di dialogo nuovo, nessun verbo di quest nuovo. Save
  `schema_version` **invariato** se possibile (le tribolazioni e i finali
  hanno già il loro spazio nel campo `endgame`/`mondo` da fase 6/7).

## 3. User Stories

### Blocco 0 — fondamenta e audit

**US-1201 — Audit del rituale di Sequenza 1 sui 10 Pathway attivi**
- Grep di `advancement_ritual.sacrifices` sulla Sequenza 1 di ognuno dei
  10 Pathway attivi (`data/pathways/*.json`, esclusi i deferred).
- Per ogni Pathway senza `"ancora_del_giocatore"` tra i sacrifici: aggiunta
  minima (una riga nell'array `sacrifices`), coerente con lo stile già
  presente nel resto di quella Sequenza (nessun altro campo toccato).
- Tabella dei 10 Pathway con esito (già presente / aggiunto) in
  `progress.txt`.
- `python tools/validate_data.py` esce 0.

**US-1202 — Contenuto per `trib_1_0`: chi scrive `tribolazione_soglia_varcata`**
- Oggi nessun dialogo/quest scrive questo flag: la prova finale (Seq 1→0)
  è tecnicamente insuperabile in una partita normale.
- Un nuovo nodo in `dlg_antagonista.json` (già esiste, già ha 2 occorrenze
  di flag imparentati — verificarne il contenuto prima di estenderlo),
  raggiungibile solo a `tier_min: angel`, che scrive il flag su una scelta
  esplicita del giocatore (stesso pattern di `dlg_doran.json` per
  `tribolazione_doran_affrontato`).
- Verificato che `AreaGate`/la posizione di `npc_antagonista` (oggi
  `region_id: frontiera_porte`, `location_tag: soglia`, `momento:
  notte_fonda`) sono raggiungibili nel gioco reale (non solo nei test).

### Blocco A — Atto II: le regioni che si aprono (US-1203..1106)

**US-1203 — Quest "posizione di fazione"**
- Una quest nuova (`q_<npc>_02` su uno degli NPC di fazione già esistenti,
  candidato: Ottavia/`ordine_minore` o Bruno/`porto`) i cui step usano
  `evento`+`filtri` esistenti (niente di nuovo) e il cui `on_complete`
  applica un effetto `reputazione` significativo verso una fazione,
  esplicitamente narrativo (il giocatore sceglie un lato in un dialogo,
  non lo fa "capitare" farmando).
- Il giver è raggiungibile in Atto II (tier mid), non prima: condizione
  `tier_min` sul primo nodo di dialogo che offre la quest.

**US-1204 — Il duello con Aldo diventa contenuto, non solo un flag**
- `npc_system.gd` già offre il duello ai salti di tier per gli NPC
  `sfida_ai_tier` (solo Aldo oggi). Verificare ESATTAMENTE quale flag/
  segnale espone oggi (letto dal codice, non dal roadmap) e usarlo come
  trigger di un piccolo dialogo `dlg_aldo` nuovo (nodo condizionato)
  che inquadra lo scontro: vittoria/sconfitta come branch dichiarati nel
  dialogo (`effetti`/`flag`), non una nuova regola di combattimento.
- Nessuna nuova meccanica di duello: riusa il combattimento esistente
  (il "duello" è narrativo — un nemico istanziato con la Sequenza di Aldo,
  stesso pattern di ogni altro nemico dai dati).

**US-1205 — Rituali che chiedono luoghi veri (Atto II)**
- Verifica che gli `advancement_ritual.location_tags` delle Sequenze 6-4
  dei 10 Pathway puntino a `location_tags` che esistono per davvero nelle
  regioni aperte in Atto II (non solo Mirwada) — audit, non necessariamente
  nuovi dati. Dove manca una zona coerente, la aggiunge (riuso del
  meccanismo di zone della Fase 10/6, non un tipo nuovo).

**US-1206 — Checkpoint di blocco: una partita attraversa l'Atto II per
davvero**
- `tests/manual/qa_atto_2.gd` (Xvfb): un personaggio a Sequenza 6 fa la
  quest di fazione, affronta il duello con Aldo, supera `trib_5_4`, arriva
  a Sequenza 4. Screenshot in chat.

### Blocco B — Atto III: la soglia (US-1207..1111)

**US-1207 — "Doran sa"**
- Nuovo nodo in `dlg_doran.json`, condizionato `tier_min: saint` (coerente
  con la condizione già presente sull'unica scelta di Atto III che ha),
  che espande la reazione oggi ridotta a una riga ("Interessante
  reazione…") in una scena vera: Doran mostra di aver capito, con
  conseguenze dichiarate (flag e/o `reputazione` sulla fazione
  `giustizia`), senza toccare `trib_3_2` (il flag di superamento resta
  quello esistente).

**US-1208 — "Lena capisce"**
- Nuovo ramo in `dlg_lena.json` condizionato a un tier alto (`saint` o
  `angel`, da decidere in story guardando il resto dei suoi nodi): la
  scena che il design cap. 5 promette — l'Ancora più fragile del roster
  reagisce al cambiamento del giocatore. Se Lena è tra le Ancore attive
  del giocatore, effetto meccanico dichiarato (es. sulla sua forza come
  Ancora, riusando l'effetto di riduzione già esistente in negativo o
  positivo — non un tipo di effetto nuovo).

**US-1209 — "Vesna sceglie"**
- Nuovo ramo in `dlg_vesna.json`: la sua diffidenza verso i Beyonder
  (`reazione_al_potere` già in `factions.json`) arriva a un bivio
  esplicito a tier alto — resta o si allontana, scritto come `flag` +
  `reputazione`, letto più avanti da un `open question` su un possibile
  effetto sul finale Rinuncia (§9).

**US-1210 — Il rituale di Sequenza 1 nel mondo reale**
- Verifica giocata (non solo dati): l'Ancora sacrificata al rituale di
  Sequenza 1 è raggiungibile e osservabile a schermo (il `location_tag`
  del rituale esiste nella Frontiera delle Porte/regione corretta,
  raggiungibile senza gating rotto).

**US-1211 — Checkpoint di blocco: una partita attraversa l'Atto III per
davvero**
- `tests/manual/qa_atto_3.gd` (Xvfb): Sequenza 4 → 0, tutte e 4 le
  tribolazioni superate con le loro scene (non solo i contatori nudi),
  il rituale di Sequenza 1 con l'Ancora, arrivo a Sequenza 0. Screenshot
  in chat.

### Blocco C — chiusura (US-1212..1113)

**US-1212 — Checkpoint dinamico dell'intera fase**
- `tests/test_fase_11_checkpoint.gd`: grep-based come i checkpoint delle
  fasi precedenti — verifica che le nuove quest/nodi di dialogo esistano,
  che referenzino solo id validi (giver nel roster, `evento` nei 12
  tracciati, `flag` coerenti), che nessun nome di Pathway sia hardcoded
  nel codice `.gd` toccato da questa fase (stesso pattern delle fasi 5/7/8).

**US-1213 — Chiusura fase 12**
- `progress.txt`/`CLAUDE.md`/`006_PRD/roadmap.md` aggiornati a "Fase 12:
  CHIUSA". `prd.json` tutto `passes: true`.

## 4. Functional Requirements

- FR-1: nessuna nuova voce in `data/schema/tracked_events.json` (12
  chiusi, invariati).
- FR-2: nessun nuovo tipo di condizione o effetto in `dialogue.schema.json`
  (il vocabolario chiuso di ~5 effetti e le condizioni condivise con le
  abilità bastano).
- FR-3: nessun nuovo verbo nel motore quest (`QuestSystem` resta un
  lettore di eventi/flag).
- FR-4: le 4 tribolazioni (`data/tribulations/*.json`) restano **dati
  invariati**: questa fase aggiunge le scene che le circondano, non
  modifica le condizioni di superamento già esistenti.
- FR-5: nessun nome di Pathway/regione/NPC specifico hardcoded in
  `res://scripts` (checkpoint dinamico, come ogni fase precedente).
- FR-6: ogni nuova chiave `*_i18n` ha voce in `it.json` (R-12 del
  validator, invariata).

## 5. Non-Goals

- Nuovi NPC oltre al roster esistente (8 nominati + generici +
  antagonista). Se in fase di scrittura una scena richiede davvero una
  voce nuova, è una decisione da prendere esplicitamente con l'utente, non
  presa qui.
- Boss fight per l'antagonista (non-goal esplicito ereditato dalla fase 7:
  resta solo indizi + il sito del rituale di Sequenza 0).
- Riscrivere o ribilanciare le condizioni di superamento delle 4
  tribolazioni: sono strutturali (fase 7), questa fase le veste.
- Contenuto per i 4 epiloghi di finale: già scritto e buono (fase 7),
  fuori scope.
- Doppiaggio (non-goal di progetto, invariato).

## 6. Design Considerations

- Ogni scena nuova riusa lo stile già presente nei dialoghi esistenti:
  frasi brevi, un bivio per nodo, mai più di 3-4 scelte.
- Le condizioni `tier_min` sui nuovi nodi devono essere coerenti con
  quelle già presenti sullo stesso NPC (es. `dlg_doran.json` usa già
  `saint` per la sua scelta più alta: US-1207 aggancia lì, non altrove).

## 7. Technical Considerations

- Tutta la fase tocca solo `data/dialogues/`, `data/quests/`,
  `data/i18n/`, e — solo se l'audit US-1201 lo richiede — `data/pathways/`
  (un campo `sacrifices` per Sequenza 1). Nessun file `.gd` nuovo fuori
  dai due script di verifica Xvfb e dal checkpoint.
- I duelli (US-1204) riusano l'istanziazione nemico esistente dai dati
  (stesso meccanismo di ogni boss/nemico piazzato nei layout, fase 8):
  nessun sistema di "duello 1v1" speciale.

## 8. Success Metrics

- `tests/test_fase_11_checkpoint.gd` verde.
- Nessuna regressione sui test esistenti (897+ alla chiusura della fase
  precedente).
- `validate_data.py` esce 0.
- `qa_atto_2.gd` e `qa_atto_3.gd` verdi con screenshot inviati in chat.

## 9. Open Questions

- **US-1209 (Vesna)**: se "si allontana" deve avere un effetto meccanico
  sul finale Rinuncia (che richiede "almeno un'Ancora viva", FR-9 di fase
  7) — da decidere quando si scrive quel nodo, guardando quante Ancore ha
  in media un giocatore a quel punto. Proposta di default: nessun effetto
  automatico sul finale, solo narrativo (Vesna non è mai stata una delle
  3 candidate Ancora "di sistema" più forti — Mirco, Lena — quindi il
  rischio di rompere Rinuncia è basso, ma va verificato in story).
- **US-1203 (quale fazione)**: proposta Ottavia/`ordine_minore` (meno
  sviluppata delle altre nel roster attuale) o Bruno/`porto` — da
  confermare quando si scrive la story, guardando quale NPC ha meno
  contenuto oggi.
- Se la Fase 10 non è ancora chiusa quando questa fase parte, US-1205/
  US-1210 restano su `location_tags` esistenti invece che sui nuovi siti
  fisici — nessun blocco, solo meno "vero" fino a quando la mappa
  continua non arriva.
