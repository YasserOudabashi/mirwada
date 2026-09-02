# PRD Fase 1 — Fondamenta

## Introduzione

Questa fase costruisce lo scheletro tecnico su cui poggeranno tutte le fasi
successive: movimento, combattimento base, caricamento dei dati, salvataggio.

Non contiene **nessuna** meccanica di Pathway, coltivazione, crafting o
sinergia. È deliberato: quei sistemi sono inutili se il personaggio non si
muove bene e se i dati non si caricano. La fase 1 è finita quando si può
girare in una stanza, picchiare un manichino, salvare, ricaricare, e cambiare
un numero in un JSON vedendolo applicato senza riavviare.

**Engine assunto: Godot 4.x (GDScript).** Se si sceglie Unity, questo è
l'unico documento del pacchetto che va riscritto.

## Obiettivi

- Movimento e camera che si sentono bene (questo va sistemato ora, non dopo)
- Loop di combattimento leggibile: attaccare, schivare, parare, subire
- Caricamento dei dati da `data/` con hot-reload in debug
- Salvataggio versionato con migrazione
- Cinque primitive di abilità funzionanti come prova dell'architettura
- Test headless eseguibili da CLI

## User Stories

### US-001: Setup progetto Godot e struttura cartelle

**Descrizione:** Come sviluppatore, ho bisogno di un progetto Godot configurato
per pixel art a 32×32 così che la resa visiva sia corretta fin dall'inizio.

**Criteri di accettazione:**
- [ ] Progetto Godot 4.x che si apre senza errori
- [ ] Risoluzione base 640×360, modalità stretch `viewport`, filtro texture `nearest`
- [ ] Cartelle: `scenes/`, `scripts/`, `data/`, `assets/`, `tests/`
- [ ] `.gitignore` per Godot (`.godot/`, `*.import`, export)
- [ ] Il progetto avvia una scena vuota senza errori in console

### US-002: Caricatore dei dati JSON

**Descrizione:** Come sviluppatore, ho bisogno di un singleton che carichi
tutti i file in `data/` in memoria all'avvio, così che ogni sistema legga da
un'unica fonte.

**Criteri di accettazione:**
- [ ] Autoload `GameData` che carica `data/pathways/`, `data/abilities/`, `data/synergies/`, `data/tags.json`, `data/schema/primitives.json`
- [ ] API: `GameData.get_pathway(id)`, `get_sequence(id)`, `get_ability(id)`
- [ ] Errore esplicito in console se un file è malformato (mai fallimento silenzioso)
- [ ] Test headless: caricamento di tutti i 10 pathway, verifica di 100 sequenze
- [ ] Il typecheck/lint passa

### US-003: Hot-reload dei dati in debug

**Descrizione:** Come sviluppatore, voglio ricaricare i JSON con un tasto
senza riavviare, così da iterare sul bilanciamento in secondi invece che minuti.

**Criteri di accettazione:**
- [ ] Tasto F5 (solo build di debug) richiama `GameData.reload()`
- [ ] Il ricaricamento non invalida i riferimenti già ottenuti dai sistemi attivi
- [ ] Messaggio in console con numero di file ricaricati ed errori
- [ ] Il typecheck/lint passa
- [ ] Verifica manuale documentata in `progress.txt`

### US-004: Movimento del giocatore a 8 direzioni

**Descrizione:** Come giocatore, voglio muovermi fluidamente in 8 direzioni,
così che il controllo risulti immediato.

**Criteri di accettazione:**
- [ ] `CharacterBody2D` con accelerazione e attrito (non velocità istantanea)
- [ ] Input mappato su WASD e frecce
- [ ] Velocità diagonale normalizzata
- [ ] Sprite placeholder 32×32 con direzione visibile
- [ ] Il typecheck/lint passa
- [ ] Verifica a schermo documentata in `progress.txt`

### US-005: Camera con smoothing e limiti

**Descrizione:** Come giocatore, voglio una camera che segua senza scatti e non
mostri fuori mappa.

**Criteri di accettazione:**
- [ ] `Camera2D` con `position_smoothing` attivo
- [ ] Limiti configurabili per zona
- [ ] Nessun tremolio su pixel a movimento diagonale
- [ ] Il typecheck/lint passa
- [ ] Verifica a schermo documentata in `progress.txt`

### US-006: Tilemap e collisioni dell'area di test

**Descrizione:** Come sviluppatore, ho bisogno di un'area di test giocabile per
provare tutti i sistemi successivi.

**Criteri di accettazione:**
- [ ] `TileMapLayer` con tileset placeholder 32×32
- [ ] Livelli di collisione: pavimento, muro, ostacolo
- [ ] Area di test ~40×30 tile con muri, un corridoio e una stanza
- [ ] Il giocatore non attraversa i muri
- [ ] Il typecheck/lint passa
- [ ] Verifica a schermo documentata in `progress.txt`

### US-007: Componente statistiche

**Descrizione:** Come sviluppatore, ho bisogno di un componente riusabile di
statistiche che vada bene sia per il giocatore che per i nemici.

**Criteri di accettazione:**
- [ ] Nodo `StatsComponent` con: hp, hp_max, spiritualita, spiritualita_max, velocita, difesa, evasione
- [ ] Segnali `hp_changed`, `died`
- [ ] Modificatori applicabili e rimovibili per id (necessari per buff/debuff a durata)
- [ ] Test headless su applicazione e rimozione dei modificatori
- [ ] Il typecheck/lint passa

### US-008: Attacco in mischia con arco

**Descrizione:** Come giocatore, voglio colpire con un attacco che ha una forma
visibile, così da capire cosa raggiungo.

**Criteri di accettazione:**
- [ ] Attacco su input, con arco di collisione nella direzione guardata
- [ ] Frame di anticipo, frame attivi, frame di recupero distinti e configurabili
- [ ] Non si può attaccare durante il recupero
- [ ] Feedback visivo dell'arco e feedback di colpo (hitstop breve)
- [ ] Il typecheck/lint passa
- [ ] Verifica a schermo documentata in `progress.txt`

### US-009: Schivata con frame di invulnerabilità

**Descrizione:** Come giocatore, voglio schivare gli attacchi con un dash che
mi rende brevemente invulnerabile.

**Criteri di accettazione:**
- [ ] Dash nella direzione di input, distanza e durata configurabili
- [ ] Finestra di i-frame configurabile all'interno del dash
- [ ] Cooldown che impedisce lo spam
- [ ] Indicatore visivo dello stato invulnerabile
- [ ] Test headless: nessun danno ricevuto durante gli i-frame
- [ ] Il typecheck/lint passa

### US-010: Parata e rottura di postura

**Descrizione:** Come giocatore, voglio parare gli attacchi e vedere premiato
il tempismo.

**Criteri di accettazione:**
- [ ] Parata tenuta che riduce il danno; parata perfetta (finestra iniziale) che lo annulla
- [ ] Barra di postura sui nemici, ridotta dai colpi e dalle parate perfette
- [ ] A postura zero il nemico entra in stato vulnerabile per N secondi
- [ ] Il typecheck/lint passa
- [ ] Verifica a schermo documentata in `progress.txt`

### US-011: Nemico base con telegrafia

**Descrizione:** Come giocatore, voglio nemici i cui attacchi siano leggibili
prima dell'impatto.

**Criteri di accettazione:**
- [ ] Macchina a stati: idle, inseguimento, anticipo, attacco, recupero, morto
- [ ] Fase di anticipo con tell visivo (flash o indicatore) di durata configurabile
- [ ] Il nemico usa `StatsComponent` e la barra di postura di US-010
- [ ] Alla morte rilascia un segnale, non distrugge sé stesso direttamente
- [ ] Il typecheck/lint passa
- [ ] Verifica a schermo documentata in `progress.txt`

### US-012: Motore delle abilità e primitiva `projectile`

**Descrizione:** Come sviluppatore, ho bisogno del motore che legge un'abilità
dal JSON e la esegue, dimostrato sulla prima primitiva.

**Criteri di accettazione:**
- [ ] `AbilityEngine.execute(ability_id, caster)` legge l'abilità da `GameData`
- [ ] Itera sull'array `primitive` ed esegue ognuna in ordine
- [ ] Verifica costo di spiritualità e cooldown prima dell'esecuzione
- [ ] Primitiva `projectile` implementata con tutti i parametri dello schema
- [ ] Una primitiva sconosciuta produce un errore esplicito, non un crash
- [ ] Test headless: esecuzione di un'abilità di prova, verifica del costo scalato
- [ ] Il typecheck/lint passa

### US-013: Primitive `melee_arc`, `buff_stat`, `heal`, `dash`

**Descrizione:** Come sviluppatore, voglio quattro primitive in più per provare
che la composizione dal JSON funziona davvero.

**Criteri di accettazione:**
- [ ] Le quattro primitive implementate secondo i parametri di `data/schema/primitives.json`
- [ ] `buff_stat` usa i modificatori per id di US-007 e si rimuove alla scadenza
- [ ] L'abilità `fool_velo_illusorio` (2 primitive) si esegue correttamente componendole
- [ ] Test headless per ogni primitiva
- [ ] Il typecheck/lint passa

### US-014: Validator dei dati integrato nei test

**Descrizione:** Come sviluppatore, voglio che i dati rotti facciano fallire i
test, così che nessuna iterazione di ralph committi un JSON invalido.

**Criteri di accettazione:**
- [ ] `python tools/validate_data.py` eseguito dalla suite di test
- [ ] La suite fallisce se il validator esce con codice diverso da 0
- [ ] Documentato in `README.md` come eseguirlo da solo
- [ ] Il typecheck/lint passa

### US-015: Salvataggio e caricamento versionati

**Descrizione:** Come giocatore, voglio che i progressi persistano tra le
sessioni senza rompersi quando il gioco viene aggiornato.

**Criteri di accettazione:**
- [ ] Save JSON in `user://` con campo `schema_version`
- [ ] Serializza: posizione, statistiche, tempo di gioco
- [ ] Al caricamento, versione inferiore a quella corrente passa da una funzione di migrazione
- [ ] Un save corrotto produce un errore gestito, mai un crash
- [ ] Test headless: salva, modifica la versione, carica, verifica la migrazione
- [ ] Il typecheck/lint passa

### US-016: Infrastruttura dei test headless

**Descrizione:** Come sviluppatore, voglio eseguire tutti i test da riga di
comando senza aprire l'editor, così che ralph possa verificarsi da solo.

**Criteri di accettazione:**
- [ ] Comando documentato che esegue l'intera suite senza finestra
- [ ] Codice di uscita 0 al successo, diverso da 0 al fallimento
- [ ] Almeno un test per: GameData, StatsComponent, AbilityEngine, save/load
- [ ] Comando annotato in `CLAUDE.md` di progetto e in `README.md`
- [ ] Il typecheck/lint passa

### US-017: HUD minimo

**Descrizione:** Come giocatore, voglio vedere salute e spiritualità.

**Criteri di accettazione:**
- [ ] Barra hp e barra spiritualità agganciate ai segnali di `StatsComponent`
- [ ] Tutte le stringhe passano da chiavi i18n, nessun testo hardcoded
- [ ] File di traduzione `it` e `en` presenti, anche se `en` è incompleto
- [ ] Il typecheck/lint passa
- [ ] Verifica a schermo documentata in `progress.txt`

### US-018: Scena di debug con manichino

**Descrizione:** Come sviluppatore, voglio una scena dove provare rapidamente
ogni sistema.

**Criteri di accettazione:**
- [ ] Scena con giocatore, due nemici di US-011, un manichino con hp infiniti
- [ ] Pannello di debug: hp, spiritualità, cooldown, primitiva eseguita per ultima
- [ ] Tasti rapidi per eseguire ognuna delle 5 primitive
- [ ] La scena non è inclusa nell'export di release
- [ ] Il typecheck/lint passa
- [ ] Verifica a schermo documentata in `progress.txt`

## Requisiti funzionali

- FR-1: Tutti i dati di gioco sono caricati da `data/`, mai hardcoded in script
- FR-2: Le stringhe visibili passano da chiavi i18n
- FR-3: Ogni sistema logico è testabile senza avviare una scena di gioco
- FR-4: Nessuna primitiva fuori dal registro di `data/schema/primitives.json`
- FR-5: Il validator dei dati è parte della suite di test
- FR-6: I save sono versionati e migrabili
- FR-7: Audio, hitstop e shake sono guidati da `data/audio.json`, mai hardcoded
- FR-8: Ogni informazione veicolata dall'audio ha un equivalente visivo attivabile

## Non-goals di questa fase

- Nessuna meccanica di Pathway, Sequenza, Acting Method o follia
- Nessun crafting, pet, costruzione, talento, sinergia
- Nessuna arte definitiva, nessuna musica composta (ma il **sistema** audio e i placeholder sonori sì: vedi US-019/US-020)
- Nessun contenuto di mondo oltre l'area di test
- Nessun menu, titolo o schermata di opzioni

## Metriche di successo

- 60 FPS stabili con 10 nemici attivi
- Cambiare un numero in un JSON e vederne l'effetto in meno di 5 secondi
- La suite di test gira in meno di 30 secondi
- Un nuovo sistema può leggere i dati senza toccare `GameData`

## Asset grafici — chi li produce

Come per l'audio, va detto chiaro: **non disegno pixel art.** Le animazioni le
programmo (macchina a stati, frame di hitbox, eventi sincronizzati), i disegni no.

Quello che ho fatto invece è togliere l'arte dal percorso critico:
`tools/generate_placeholders.py` genera **324 frame reali** da
`data/animations.json`, con i bordi diagnostici colorati — rosso dove la hitbox
è attiva, giallo sull'anticipo, ciano sui frame di invulnerabilità, verde sulla
finestra di parata perfetta.

Non è un ripiego. È **migliore dell'arte definitiva** per tarare il
combattimento: guardando lo schermo vedi esattamente quanti frame dura ogni
fase, cosa che uno sprite finito nasconde. Le fasi 1-4 si chiudono così, senza
un artista.

### Quando serve l'arte vera, le strade sono quattro

1. **Pack CC0/gratuiti** (Kenney, itch.io, LPC). Gratis e immediati, ma il
   gioco somiglierà ad altri giochi e i pack raramente hanno le animazioni
   specifiche che servono qui (parata, meditazione, trasformazione).
2. **Pack a pagamento** su itch.io, 20-60 dollari. Miglior rapporto
   qualità/prezzo se ne trovi uno con le animazioni giuste.
3. **Un pixel artist su commissione.** L'unica strada per un'identità visiva
   vera e per le dieci palette dei Pathway. Il budget si calcola dal
   `budget_frame` in `data/animations.json`: un personaggio completo sono 156
   frame, un artista ne fa 30-60 buoni al giorno.
4. **Impararla tu** con Aseprite. Per una pixel art 32×32 leggibile servono
   settimane, non anni — ed è l'unico modo in cui il gioco avrà davvero il tuo
   aspetto.

La decisione **non va presa adesso**. Va presa quando il gioco è divertente
coi placeholder, perché a quel punto sai se vale la pena investirci. Prenderla
prima significa spendere soldi o mesi su un gioco che potrebbe non funzionare.

### La decisione che invece va presa adesso

**4 direzioni, non 8.** È già in `data/animations.json` sotto `convenzioni`.
Le diagonali riusano gli sprite orizzontali: dimezza i frame da disegnare e in
un top-down 2D nessuno se ne accorge. Cambiarla dopo significa ridisegnare
tutto, quindi è fissata ora insieme ai 32×32.

## Asset audio — chi li produce

Questo va detto senza girarci intorno: **non posso produrre audio.** Non compongo
musica e non genero file sonori. Il sistema lo progetto e lo faccio scrivere,
i suoni no.

Per la fase 1 non è un problema: gli SFX di combattimento vanno generati con
**bfxr / sfxr / Chiptone** (gratuiti, in browser, un suono in trenta secondi).
Per un gioco in pixel art non sono placeholder da sostituire: sono lo stile
giusto. Un pomeriggio produce tutti i suoni di US-019 e US-020.

Per le fasi successive le strade sono tre:

1. **Librerie CC0** (Freesound con filtro CC0, Kenney, OpenGameArt) per ambienti
   e suoni concreti. Gratis, usabili, ma il gioco suonerà come altri giochi.
2. **Musica CC0/CC-BY** per gli stem. Funziona, ma la struttura a layer di
   `data/audio.json` richiede stem composti apposta per incastrarsi: trovare
   stem compatibili in libreria è difficile.
3. **Un musicista.** È l'unica strada per l'identità sonora dei dieci Pathway
   e per gli stem a layer. Non serve subito — serve in fase 6.

La cosa da fare adesso, e che costa zero: quando arrivi a comporre o commissionare
la musica, `data/audio.json` contiene già la specifica esatta (stem, stati,
crossfade, palette per Pathway). Un musicista può lavorare su quella senza che
tu debba spiegargli il gioco.

## Domande aperte

- Il combattimento è a bersaglio libero o con lock-on? (propendere per libero,
  ma va provato con il manichino prima di deciderlo)
- La parata è tenuta o a pressione singola?
- Serve il supporto controller già in fase 1, o basta la mappatura astratta?
