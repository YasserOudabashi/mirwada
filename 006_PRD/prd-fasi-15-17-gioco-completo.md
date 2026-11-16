# PRD: Fasi 15-17 — dal gioco quasi fatto al gioco completo

> Scritto il 2026-11-10 dal controllo generale. Le story sono in `prd.json` (fasi `15`, `16`, `17`), l'ordine in
> `prossimi-passi.md`.

## 1. Perche'

Il controllo del 2026-11-10 ha guardato cosa serve per **finire il gioco e giocarlo tutto**, non solo le story gia'
scritte. Oltre all'Atto II e III (fase 13) e al Mondo vivo (fase 12) mancano tre cose che non erano in nessuna story:

| Cosa | Com'e' oggi | Perche' blocca |
|---|---|---|
| **Nemici** | i 72 nemici del mondo e i 6 boss sono tutti `nemico_base`, ingranditi (`scala`) e con qualche numero cambiato (`override`) | si combatte sempre lo stesso nemico con lo stesso attacco dalla Sequenza 9 alla 0 |
| **Audio** | `data/audio.json` descrive 18 effetti, 26 musiche e 18 ambienti, ma in `assets/` non c'e' **nessun file audio**: `AudioManager` sintetizza bip di prova e le musiche tacciono | il gioco e' muto |
| **Rilascio** | nessuno ha mai giocato una partita intera dal menu al finale; `export_presets.cfg` e' nel `.gitignore` | non si sa se il gioco si finisce davvero, ne' se parte fuori dall'editor |

In piu' due story gia' scritte cambiano posto: **US-8B60b** (antagonisti con la loro figura) va nell'Atto III, perche'
l'antagonista deve comparire alla soglia della Frontiera; **US-8B60a** (evocazioni) va coi nemici, perche' oggi la
primitiva `summon` scrive solo nel registro e chi evoca non vede niente.

## 2. Fase 15 — Nemici e boss (US-1501..US-1507, US-8B60a)

- Un **tipo di nemico e' un dato** (`balance.json nemici_tipi`), come una forma o un'abilita': statistiche, tell,
  comportamento, aspetto. `nemico_base` resta il default, l'override per istanza resta sopra. Niente `if` per tipo.
- Comportamenti nuovi, pochi e riusabili: mischia (c'e' gia'), **distanza**, **carica**, **volo**. Sono codice del
  nemico, non primitive.
- **Boss** come dati: fasi a soglie di vita, gregari, arena che si chiude, barra nell'HUD.
- Arte con forge3d: un aspetto per tipo (uno per regione e uno per il sottosuolo), una figura grande per boss.
- Decisione per l'utente (prima di US-1501): quali tipi per quale regione. **Decisa** col questionario "Bestiario di
  Mirwada" (risposte dell'11 novembre 2026, lette il 16): vedi 2.1.

### 2.1 Bestiario deciso dall'utente

Regole:
- **Circa 35 tipi**: persone, bestie, mostri e congegni.
- **Abilita'**: i comuni ne hanno 1 oltre all'attacco, i rari 2-3. Chi segue un Pathway usa **le stesse abilita' del
  giocatore** (quelle vere dei dati).
- **Durezza secondo il nemico**: i comuni si leggono bene (tell lunghi); un raro con tante abilita' e' teso (tell brevi).
- **Gruppi con ruoli a volte** (certi luoghi e i boss): devono essere davvero forti, ma si devono poter abbattere tutti.
- **Varianti rare** dello stesso nemico, riconoscibili dal colore, **piu' frequenti di notte**. Di notte escono anche
  **nemici diversi**.
- **Ritorno**: i comuni tornano sempre, perche' il mondo non deve svuotarsi; anche i rari tornano, ma la probabilita'
  di oggetti forti scende a ogni ritorno e le **armi uniche si prendono una volta sola**. I boss non tornano.
- **Bottino**: ogni tipo lascia un ingrediente suo.
- **Pagina Bestiario nel libro**: nome, poi i punti deboli quando se ne sono battuti abbastanza, e **che cosa lascia**
  (solo gli oggetti gia' ricevuti), per sapere dove cercare un ingrediente.
- **Boss**: 3 fasi i primi, 4 quelli finali. Uno o due **boss segreti**. **Mini-boss** che girano per il mondo.

I tipi (tutti quelli proposti sono stati tenuti):
- **Mirwada**: tagliaborse dei bassifondi, scaricatore ubriaco, guardia corrotta, devoto fuori controllo,
  contrabbandiere con la balestra.
- **Marche del Crepuscolo**: soldato caduto, alfiere spettrale, corvo della battaglia, ombra strisciante, colosso
  arrugginito.
- **Valle della Madre**: lupo della luna, germoglio spinoso, guardiana delle radici, sciame di spore, cervo dalle corna
  rosse.
- **Archivio Sepolto**: scrivano di carta, automa custode, lettore proibito, glifo vivente, bibliotecario muto.
- **Frontiera delle Porte**: maschera senza volto, viandante delle porte, marionetta del teatro, ladro di tempo, il Doppio.
- **Sottosuolo**: ratto delle fogne, melma, scheletro delle catacombe, pipistrello cieco, custode della cripta.
- **Mare e isole**: granchio corazzato, pirata naufrago, gabbiano ladro, voce dell'acqua, e (aggiunta dell'utente) la
  **barca senza nessuno a bordo** che spara col cannone.
- **Voluto dall'utente**: il **coccodrillo rapper** che spara note musicali e lascia un foglietto con le note di una
  canzoncina da suonare al fortepiano.

Due idee dell'utente cambiate per la Nota IP di `CLAUDE.md` (niente personaggi o musiche di opere protette):
- la canzoncina del foglietto e' **un motivetto nostro**, non la sigla di un cartone animato;
- il boss segreto che "appare a caso davanti a te" si tiene come **idea di gioco** (una figura nera che colpita si
  divide in tante copie e le rifonde in una piu' grande), con nome e aspetto nostri: non il personaggio di un manga.

Boss ("decidili tu e proponimeli"): proposta da confermare prima di US-1505.
1. **Mirwada, fogne** — il Re dei Ratti: un uomo cucito al suo branco (3 fasi; chiama ratti, poi si divide).
2. **Valle** — la Madre delle Radici: albero che cammina, cura se stessa dalle radici che vanno tagliate (3 fasi).
3. **Archivio** — l'Archivista Capo: riscrive le regole della stanza (zittisce, ricopia le tue abilita') (3 fasi).
4. **Marche, catacombe** — il Custode senza Nome: corazzato, si apre solo dopo il suo attacco (3 fasi).
5. **Marche, vetta** — il Gigante sul Trono: l'arena e' la salita; pesta, lancia le spade piantate (4 fasi).
6. **Frontiera** — il Burattinaio: combatte attraverso marionette e il Doppio di Enel (4 fasi).
- Segreti: la **figura nera che si moltiplica** (appare a caso, di notte, davanti al giocatore) e la **barca fantasma
  ammiraglia** su un'isola lontana. Mini-boss in giro: il colosso arrugginito anziano, il lupo alfa, il coccodrillo rapper.

## 3. Fase 16 — Audio (US-1601..US-1605)

- I file vanno in `assets/audio/{sfx,musica,ambiente}/<id>`, con gli id che `audio.json` usa gia'. `AudioManager`
  li usa se ci sono, altrimenti fa il bip di oggi: si puo' riempire un file alla volta.
- **Decisione per l'utente** (prima di US-1601): suoni generati da Claude con uno script rilanciabile con seed (come
  gli sprite: coerente, ma la musica sara' semplice) oppure presi da librerie libere CC0 (piu' ricchi, da citare).

## 4. Fase 17 — Rilascio (US-1701..US-1704)

- **US-1701** e' la prova vera: quattro partite intere, una per gruppo, fino al finale. Ogni blocco trovato diventa
  una story di correzione. Va fatta dopo le fasi 13, 15 e 7b.
- Poi bilanciamento (solo numeri nei dati), i primi dieci minuti, l'eseguibile per Windows.

## 5. Cosa NON serve per dire "finito"

Inglese (US-EN01..05), cannocchiale da tasca, luci di notte, panorami per regione, nuoto, arrampicata: migliorano il
gioco ma non bloccano niente. Stanno in fondo all'elenco.
