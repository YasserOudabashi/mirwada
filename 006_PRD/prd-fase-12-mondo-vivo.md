# PRD: Fase 12 — Mondo Vivo (dungeon, caverne, villaggi e NPC distribuiti)

## 1. Introduzione/Overview

Feedback diretto dell'utente giocando la build attuale: attraversare la
campagna fra due regioni richiede ~2 minuti anche con lo scatto, senza
nulla da fare lungo il tragitto — "come corridoi dritti inutili",
nonostante US-1015 (fase 10) l'abbia già riempita di terreno vero invece
che vuoto. Il problema non è grafico: è che oggi la campagna ha solo 2
villaggi (entrambi vicino a Marche/Archivio, fase 11) su un'area
condivisa enorme. Misurato sui dati reali: la distanza fra i rettangoli
di regioni adiacenti va da ~195 celle (Mirwada↔Marche, il tragitto più
corto) a ~370 celle (Frontiera↔Valle, il più lungo) — decine di secondi
di cammino vuoto anche nel percorso migliore.

**Questa fase risolve il problema riempiendo il mondo di contenuto, non
allargando lo spazio vuoto**: nuovi villaggi, dungeon e caverne sparsi
lungo gli 8 tragitti fra regioni (i 4 raggi Mirwada↔ciascuna regione
esterna + i 4 lati dell'anello fra regioni esterne adiacenti), le 2
regioni che oggi non hanno **nessun** edificio al loro interno (Marche
del Crepuscolo, Frontiera delle Porte) ne guadagnano uno, e gli NPC si
distribuiscono meglio nel mondo invece di restare quasi tutti concentrati
a Mirwada (oggi 19 dei 25 NPC del roster vivono lì).

**Zero motore nuovo**: ogni meccanismo richiesto esiste già e viene solo
riusato. Un dungeon/una caverna nella campagna è tecnicamente identico a
un villaggio di fase 11 — una porta dipinta da
`_disegna_capanne_campagna` (il template generico 5x4, invariato) che
referenzia un interno — solo che l'interno, invece di una singola stanza
con un NPC, è una mappa più grande e ostile con nemici e bottino (esatto
stesso principio di `archivio_torre_osservazione`, già multi-stanza da
fase 10). Nessuna primitiva, evento tracciato o tipo di dato nuovo.

## 2. Goals

- Nessun tragitto fra due regioni adiacenti (raggio o anello) resta senza
  almeno un punto di interesse lungo il percorso.
- Le 2 regioni oggi senza un solo edificio (Marche del Crepuscolo,
  Frontiera delle Porte) ne guadagnano uno.
- Almeno 2 NPC esistenti (oggi solo a Mirwada) guadagnano un secondo
  avamposto altrove nel mondo, oltre ai nuovi NPC dei nuovi insediamenti.
- 12-14 nuovi punti di interesse in tutto (villaggi + dungeon + caverne +
  edifici di regione), zero motore nuovo.
- Ogni story verificata a schermo con Xvfb (cammino reale, non solo dati).

## 3. Cosa esiste già e va solo riusato (non ripetuto per intero — vedi
`006_PRD/prd-design-mondo-regioni.md`/`prd-design-npc-boss.md`)

- `campagna.json.edifici[]` + `world_scene.gd::_disegna_capanne_campagna`
  (template fisso 5x4, dipinge pareti vere per qualunque porta in
  campagna) + `_crea_edifici` (porta → interno, generico da US-1010):
  **il meccanismo per QUALUNQUE nuovo punto di interesse nella campagna**,
  villaggio o dungeon che sia.
- `layout.edifici[]`: stesso meccanismo per un edificio DENTRO una
  regione esistente (Marche, Frontiera).
- Un interno multi-stanza è solo una `mappa` ASCII più grande
  (`archivio_torre_osservazione`, 27×11, già 3 stanze collegate) — non
  serve nulla di nuovo per un dungeon "grande".
- Il 7° effetto di dialogo `crea_su_richiesta` + `vendor.listino`
  (fase 11): per i nuovi NPC crafter/mercante.
- `nemici[]`/`oggetti[]` di un interno o della campagna
  (`scala`/`override` per un mini-boss, stesso principio del boss di
  regione, US-806): per dare ai dungeon/caverne un motivo di
  combattimento, non solo scenografia.

## 4. User Stories

### Blocco 0 — Fondamenta

#### US-1201: Verifica e numerazione

**Descrizione:** Come team, vogliamo confermare che nessun meccanismo
nuovo serva davvero prima di scrivere contenuto, e fissare la
numerazione (questa fase è la Fase 12; `006_PRD/prd-fase-12-atto-2-3.md`
slitta a Fase 13, l'opzionale Pathway Non-Standard a Fase 14 — stessa
procedura già usata per la fase 11).

**Acceptance Criteria:**
- [ ] Verificato che `_disegna_capanne_campagna`/`_crea_edifici`/
      `layout.edifici[]` bastano per ogni story sotto (nessuna nuova
      primitiva/evento/tipo di pagina) — documentato in `progress.txt`.
- [ ] `prd.json` generato da questo PRD con `fase: 12` su ogni story.

### Blocco A — I due tragitti a raggio più lunghi (Mirwada↔Archivio, Mirwada↔Frontiera)

#### US-1202: Un punto di interesse lungo Mirwada→Archivio Sepolto

**Descrizione:** Come giocatore, voglio qualcosa da fare a metà strada
fra Mirwada e l'Archivio Sepolto (~207 celle di campagna vuota oggi).

**Acceptance Criteria:**
- [ ] Nuovo edificio in `campagna.json.edifici[]` a metà circa del
      tragitto, fuori da ogni rettangolo di regione, con un interno
      multi-stanza (dungeon o caverna, non una singola capanna) popolato
      da nemici (`sequenza` coerente con la vicinanza a Demon of
      Knowledge/Hermit) e almeno un oggetto di valore.
- [ ] `python tools/validate_data.py` esce 0. Tests pass. Verifica a
      schermo con Xvfb: si cammina da Mirwada, si trova il punto di
      interesse, si entra, si combatte/raccoglie.

#### US-1203: Un punto di interesse lungo Mirwada→Frontiera delle Porte

**Descrizione:** Come US-1202, sul tragitto verso la Frontiera delle
Porte (~207 celle).

**Acceptance Criteria:**
- [ ] Stesso schema di US-1202, tema coerente con Lord of Mysteries/Fool
      (tag `ombra`/`occulto`).
- [ ] `python tools/validate_data.py` esce 0. Tests pass. Verifica a
      schermo con Xvfb.

### Blocco B — I due tragitti a raggio verso Marche e Valle

#### US-1204: Un punto di interesse lungo Mirwada→Marche del Crepuscolo

**Descrizione:** Come US-1202, sul tragitto verso Marche del Crepuscolo
(~195 celle, il raggio più corto ma comunque vuoto oggi salvo il
villaggio già esistente vicino alla breccia).

**Acceptance Criteria:**
- [ ] Nuovo punto di interesse a metà tragitto (non vicino al villaggio
      già esistente — distanza minima dal villaggio di Marche già in
      dati), tema coerente con Eternal Darkness/Twilight Giant.
- [ ] `python tools/validate_data.py` esce 0. Tests pass. Verifica a
      schermo con Xvfb.

#### US-1205: Un punto di interesse lungo Mirwada→Valle della Madre

**Descrizione:** Come US-1204, verso Valle della Madre (~204 celle).

**Acceptance Criteria:**
- [ ] Stesso schema, tema coerente con Goddess of Origin/Mother.
- [ ] `python tools/validate_data.py` esce 0. Tests pass. Verifica a
      schermo con Xvfb.

### Blocco C — I 4 lati dell'anello (le regioni esterne fra loro)

#### US-1206: Un punto di interesse fra Marche del Crepuscolo e Archivio Sepolto

**Descrizione:** Come giocatore, voglio qualcosa lungo il lato nord
dell'anello (~364 celle, il più lungo insieme a Frontiera↔Valle).

**Acceptance Criteria:**
- [ ] Nuovo punto di interesse lungo quel lato, con un secondo punto se
      la distanza reale supera ~300 celle da qualunque altro punto di
      interesse già piazzato (2 fermate invece di 1 sui lati più lunghi).
- [ ] `python tools/validate_data.py` esce 0. Tests pass. Verifica a
      schermo con Xvfb.

#### US-1207: Un punto di interesse fra Archivio Sepolto e Frontiera delle Porte

**Descrizione:** Come US-1206, lato est dell'anello (~316 celle).

**Acceptance Criteria:**
- [ ] Stesso schema di US-1206.
- [ ] `python tools/validate_data.py` esce 0. Tests pass. Verifica a
      schermo con Xvfb.

#### US-1208: Un punto di interesse fra Frontiera delle Porte e Valle della Madre

**Descrizione:** Come US-1206, lato sud dell'anello (~372 celle, il più
lungo di tutti — 2 fermate qui).

**Acceptance Criteria:**
- [ ] 2 punti di interesse lungo questo lato (non 1), distanziati.
- [ ] `python tools/validate_data.py` esce 0. Tests pass. Verifica a
      schermo con Xvfb.

#### US-1209: Un punto di interesse fra Valle della Madre e Marche del Crepuscolo

**Descrizione:** Come US-1206, lato ovest dell'anello (~312 celle).

**Acceptance Criteria:**
- [ ] Stesso schema di US-1206.
- [ ] `python tools/validate_data.py` esce 0. Tests pass. Verifica a
      schermo con Xvfb.

### Blocco D — I due nuovi villaggi (Valle e Frontiera, come Marche/Archivio in fase 11)

#### US-1210: Villaggio nella campagna vicino a Valle della Madre

**Descrizione:** Come giocatore, voglio un insediamento vicino alla
breccia di Valle della Madre, stesso schema esatto dei 2 villaggi di
fase 11 (Marche/Archivio) — oggi Valle e Frontiera sono le uniche 2
regioni esterne senza un villaggio di campagna vicino.

**Acceptance Criteria:**
- [ ] 2 capanne (crafter + mercante) vicino a una breccia del muro di
      Valle della Madre, 2 nuovi NPC dedicati con dialoghi propri.
- [ ] `python tools/validate_data.py` esce 0. Tests pass. Verifica a
      schermo con Xvfb.

#### US-1211: Villaggio nella campagna vicino a Frontiera delle Porte

**Descrizione:** Come US-1210, vicino alla breccia della Frontiera delle
Porte.

**Acceptance Criteria:**
- [ ] Stesso schema di US-1210, 2 nuovi NPC dedicati.
- [ ] `python tools/validate_data.py` esce 0. Tests pass. Verifica a
      schermo con Xvfb.

### Blocco E — Le 2 regioni vuote si riempiono

#### US-1212: Un dungeon dentro Marche del Crepuscolo

**Descrizione:** Come giocatore, voglio entrare in un edificio dentro
Marche del Crepuscolo (oggi l'unica regione — con Frontiera — a zero
`edifici[]` nel proprio layout), nella zona `trono_del_gigante` o
`rovina` — l'equivalente più vicino a un castello caduto che il gioco
abbia (vedi Open Question già sollevata in
`prd-design-mondo-regioni.md`).

**Acceptance Criteria:**
- [ ] Nuovo `edifici[]` in `data/world/layouts/marche_crepuscolo.json`
      dentro `trono_del_gigante` o `rovina`, interno multi-stanza con
      nemici a tema Twilight Giant e un boss minore (`scala >= 1.3`, più
      debole del boss di regione).
- [ ] Se la zona scelta non ha spazio libero sufficiente, la regione
      cresce di poche celle per farcelo entrare (non un redesign
      completo del layout).
- [ ] `python tools/validate_data.py` esce 0. Tests pass. Verifica a
      schermo con Xvfb.

#### US-1213: Un dungeon dentro Frontiera delle Porte

**Descrizione:** Come US-1212, dentro Frontiera delle Porte, nella zona
`porta_senza_stanza` o `nebbia_grigia`.

**Acceptance Criteria:**
- [ ] Stesso schema di US-1212, tema Lord of Mysteries/Fool.
- [ ] `python tools/validate_data.py` esce 0. Tests pass. Verifica a
      schermo con Xvfb.

### Blocco F — NPC esistenti che si spostano nel mondo

#### US-1214: Doran segue le tue tracce fuori Mirwada

**Descrizione:** Come giocatore, voglio incontrare Doran (investigatore
della Giustizia, oggi solo a Mirwada) anche in un secondo luogo lontano
— coerente con il suo ruolo di "segue le tue tracce", il primo NPC
esistente a guadagnare un secondo avamposto.

**Verificato scrivendo questo PRD**: `NpcSystem.presenti(region_id)`
filtra rigidamente per `n.region_id == region_id` — un NPC con
`region_id: mirwada` non può MAI comparire nella scena di un'altra
regione tramite `schedule`/`location_tag`, qualunque cosa dica lo
schedule (verificato in `npc_system.gd:186`). Un vero "secondo avamposto
all'aperto" richiederebbe un cambio di motore, fuori scope qui (FR-5).
**La soluzione che riusa solo dati**: `interior_scene.gd::_crea_un_npc`
(il motore già scritto in US-1108 per le capanne dei villaggi) non legge
mai `region_id` — un NPC dentro un interno (`npcs: [{x,y,npc_id}]`) è
indipendente dal sistema di presenza a cielo aperto. Doran compare quindi
DENTRO l'interno di uno dei nuovi punti di interesse, non nella campagna
aperta.

**Acceptance Criteria:**
- [ ] `npc_doran` aggiunto a `npcs: [{x,y,npc_id: "npc_doran"}]` di un
      interno nuovo dei Blocchi A-C (non una presenza a cielo aperto).
- [ ] Nessuna regressione sulla sua presenza/fazione a Mirwada (il suo
      `region_id`/`schedule` esistenti restano invariati — un NPC può
      comparire sia nel proprio schedule di regione SIA dentro un
      interno altrove, sono due meccanismi indipendenti).
- [ ] Tests pass. `python tools/validate_data.py` esce 0. Verifica a
      schermo con Xvfb.

#### US-1215: Un secondo mercante esistente apre banco altrove

**Descrizione:** Come US-1214, per Sidon o Bruno (mercanti di Mirwada):
un secondo punto vendita in uno dei nuovi villaggi, non solo NPC del
tutto nuovi ovunque.

**Acceptance Criteria:**
- [ ] Stesso schema di US-1214 (l'NPC compare dentro l'interno di una
      capanna nuova, non a cielo aperto): un NPC vendor già esistente
      (Sidon o Bruno) presente anche in un secondo luogo con un listino
      coerente (sottoinsieme o variante del suo listino a Mirwada).
- [ ] Tests pass. `python tools/validate_data.py` esce 0. Verifica a
      schermo con Xvfb.

### Blocco G — Chiusura

#### US-1216: Checkpoint dinamico + chiusura fase 12

**Descrizione:** Come team, vogliamo la fase chiusa nella documentazione
con lo stesso rigore delle fasi precedenti.

**Acceptance Criteria:**
- [ ] `tests/test_fase_12_checkpoint.gd` (stesso schema di
      `test_fase_11_checkpoint.gd`): zero righe di codice del motore
      nominano uno dei nuovi punti di interesse/NPC — lista vietata
      scoperta dai dati (`GameData.get_campagna().edifici` esteso,
      `GameData.get_npcs()`).
- [ ] `006_PRD/prd-fase-12-atto-2-3.md` rinominato in
      `006_PRD/prd-fase-13-atto-2-3.md` (story id `US-1201..US-1213` di
      quel PRD rinumerate `US-1301..US-1313`), `006_PRD/roadmap.md`
      "Fase 12 — Atto II e Atto III" diventa "Fase 13", "Fase 13 —
      Opzionale" diventa "Fase 14".
- [ ] `progress.txt`, `CLAUDE.md` (§ Fasi), `README.md` aggiornati a
      "Fase 12: CHIUSA".
- [ ] `prd.json`: tutte le story a `passes: true`.
- [ ] Tests pass. `python tools/validate_data.py` esce 0.

## 5. Functional Requirements

- FR-1: Ogni nuovo punto di interesse nella campagna è
  `campagna.json.edifici[]` (porta + interno), MAI una modifica a
  `_disegna_capanne_campagna` o `_crea_edifici` per un caso specifico.
- FR-2: Ogni nuovo edificio dentro Marche/Frontiera è
  `layout.edifici[]`, stesso meccanismo di US-1010/1011/1012.
- FR-3: Un dungeon/una caverna si distingue da un villaggio solo per
  dati (interno più grande, nemici invece di NPC, nessun crafter/vendor)
  — nessuna nuova visual/tipo di struttura nel motore.
- FR-4: Ogni nuovo NPC segue lo schema esistente (`region_id`,
  `schedule` o `schedule: []` se vive in un interno isolato, opzionale
  `crafter`/`vendor`).
- FR-5: Nessuna primitiva, evento tracciato, tag, categoria di oggetto o
  tipo di pagina nuovi in tutta la fase.

## 6. Non-Goals (Out of Scope)

- Nessuna sesta regione: si lavora dentro le 5 esistenti + la campagna
  condivisa.
- Nessun contenuto narrativo/quest legato ai nuovi luoghi (fuori scope,
  eventualmente materiale per la Fase 13 - Atto II/III).
- Nessun ridisegno completo dei layout di Marche/Frontiera: crescono
  solo quanto serve a ospitare 1 nuovo edificio (US-1212/1213), non un
  redesign totale.
- Non tutti i 25 NPC vengono ridistribuiti: solo 2 (Doran, un mercante)
  guadagnano un secondo avamposto in questa fase — gli altri restano
  dove sono.

## 7. Design Considerations

- **Un dungeon/una caverna riusa la stessa porta 5x4 generica dei
  villaggi** (`_disegna_capanne_campagna`, invariata): niente nuova
  grafica per il motore. La differenza fra "dungeon" e "caverna" è
  narrativa (nome, descrizione, nemici/tag), non tecnica — coerente col
  principio "i dati non sono codice".
- I nomi/temi di ogni punto di interesse (proposti nelle story sopra:
  "dungeon", "caverna", coerenti col gruppo di Pathway più vicino) sono
  indicativi — i nomi definitivi si scrivono in esecuzione, come già
  avvenuto per Fenwick/Greta/Orsolya/Dario in fase 11.

## 8. Technical Considerations

- Posizionamento: ogni nuovo punto di interesse deve stare nel
  rettangolo che contiene tutte le regioni (bounding box) e fuori dal
  rettangolo di ognuna — stesso controllo già nel validator per
  `campagna.edifici[]` (fase 11, esteso automaticamente a ogni nuova
  voce, nessuna modifica al validator necessaria).
- Distanza minima fra punti di interesse: da decidere in esecuzione
  (indicativamente 60-80 celle, abbastanza per non vederli l'uno
  dall'altro ma abbastanza vicini da rompere un tragitto di 200-370
  celle in più tappe).

## 9. Success Metrics

- Nessun tragitto fra regioni adiacenti supera ~100 celle senza un punto
  di interesse nelle vicinanze (misurabile: distanza dal punto più
  vicino lungo il percorso diretto).
- 12+ nuovi punti di interesse verificati a schermo con Xvfb.
- Il roster ha almeno 4 regioni esterne con NPC presenti (oggi solo
  Valle/Marche/Archivio ne hanno da fase 11 — Frontiera nessuno).

## 10. Open Questions

- Le "2 fermate" sui lati più lunghi dell'anello (US-1206/1208) — 300
  celle è la soglia giusta, o va ritarata dopo aver visto a schermo
  quanto tempo impiega davvero lo scatto a coprirle?
- US-1212/1213 permettono alla regione di "crescere di poche celle" se
  serve: quanto è "poche" prima che diventi un redesign da spezzare in
  una story a parte?
