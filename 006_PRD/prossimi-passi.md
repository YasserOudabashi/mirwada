# Prossimi passi — istruzioni per la prossima sessione di Claude Code

> Riscritto il 2026-10-26 (la versione del 2026-09-09 descriveva la fase 8 prima del merge); aggiornato il 2026-10-29.
> Leggilo **dopo** `CLAUDE.md` e **prima** di toccare qualunque file. Il dettaglio di ogni story
> fatta e' in `progress.txt` (cerca la sigla), le story aperte in `prd.json`.

---

## 0. Il quadro in tre righe

Le fasi 1-11 e la fase 8b (arte) sono chiuse: dal 2026-10-29 tutto e' su `main`. Il gioco si gioca nel mondo
generato con arte vera, interni, base, mezzi, fauna, notte. Quello che manca per **finirlo** e' soprattutto la
storia dell'Atto II e III (la prova finale oggi non si puo' superare): il lavoro che resta e' tutto in `prd.json`.

---

## 1. Stato del repo (2026-10-29)

- `main` contiene tutto (la PR #5 unita il 2026-10-29, con dentro la PR #4 delle fasi 8-11).
- CI GitHub Actions accesa su push a `main` e sulle pull request (validator + `tools/run_tests.sh`).
- Verifica locale: `python tools/validate_data.py` e `bash tools/run_tests.sh` (1076 test, ~5 minuti).
- **Niente controlli automatici** della PR o della CI (decisione dell'utente, 2026-10-29): si controlla solo quando
  lo chiede l'utente.

---

## 2. Ordine delle story

1. Fatte il 2026-10-26 le US-8B21a/b/c: i sei varchi sono ingressi sulla mappa (`regions.json` gating[].varco,
   `mondo.gd crea_varchi`, disegni da `esporta_mondo.py --varchi`), il contenuto delle loro zone sta negli interni,
   gli interni hanno l'arte del loro luogo.
2. Fatte il 2026-10-26 anche **US-8B91 Barca dal porto**, **US-8B93 Volo** (piuma dei venti nell'osservatorio) e
   **US-8B95 Accesso alla Frontiera** (barca, volo, soglia del faro con la chiave delle Rovine): `data/world/mezzi.json`,
   `mondo.gd crea_barca`, `decolla`/`atterra`, `crea_soglie`.
3. Fatta il 2026-10-26 **US-8B70 Icone degli oggetti**: 44 forme in `forge3d/icone.py`, abbinamento nei dati
   (`data/ui/icone.json`, `tools/art/build_icone.py`), a terra con l'ombra e nello zaino. E **US-8B71 Icone di
   stato**: 14 icone da griglie (`tools/art/build_stati.py`), in fila sopra la testa (`scripts/status_icons.gd`).
   E **US-8B72 Icone di primitiva**: 28 glifi a 4 toni (`tools/art/build_primitive.py`) colorati dallo shader
   `shaders/rampa_pathway.gdshader` con la palette del Pathway, nella hotbar.
   E **US-8B40 VFX degli attacchi base**: fendente (anche sull'attacco base), proiettile in volo con lo scoppio,
   scia dello scatto (`tools/art/build_vfx.py`, colorati dalla rampa, lampo spento con riduci_flash).
   Fatta il 2026-10-27 **US-8B74 Panorami**: all'avvio il libro piccolo (`assets/ui/libro_avvio.png`) e intorno il
   panorama a 6 strati che scorre (`tools/art/build_panorami.py`, `book_overlay.gd`), momento dall'ora del computer.
   Fatta il 2026-10-27 **US-8B41 VFX delle primitive, gruppo 1** (buff/debuff, aura, cura, evocazione, scrutare,
   varco, illusione) in `tools/art/build_vfx.py`, e **US-8B42 gruppo 2** (maleficio, frattura, paura, furto, brace,
   ombra, tempo all'indietro, fioritura) e **US-8B43 gruppo 3** (pensiero, scudo, purificazione, possessione,
   trasformazione, anima recisa, resurrezione, decadimento): ogni primitiva implementata ha il suo foglio.
   E **US-8B40b feedback del colpo**: scintilla sul colpito, lampo della parata perfetta, schegge della postura,
   polvere dello scatto (`vfx.json feedback_colpo`); parata e postura restano accese sopra il nero di scena.
   E **US-8B35a/b ritratti**: mezzibusti 64x80 dallo stesso modello degli sprite (`tools/art/build_ritratti.py`),
   con barba, occhiali ed espressione nei dati degli aspetti; nella pagina del dialogo e del negozio.
   E **US-8B73b le due facciate del libro**: niente sulla piega; dialogo a sinistra e scelte a destra, nel negozio
   si compra a sinistra e si vende a destra, con le liste che scorrono.
   E **US-8B73c/d**: tutte le pagine sulle due facciate (scaffale, frontespizio, colophon, inventario con l'indice a
   destra, diagramma con la griglia girata); un test controlla che nessuna facciata chieda piu' spazio di quello che ha.
   E **US-8B50a/b la forma gigante**: Enel una volta e mezza (celle 96, `tools/art/build_forme.py`) quando la
   transform ha una forma con aspetto; torna Enel quando il modificatore finisce.
   E **US-8B50c l'arma di luce**: la seconda forma, Enel con la lama di luce dorata.
   E **US-8B80a/b i gesti di Enel**: interagire, raccogliere (da fermo), bere, rituale, nei dati e nel gioco.
   E **US-8B81a/b Enel in volo e in barca**: sospeso con le gambe che pendono, in ginocchio dentro lo scafo a remare.
   E **US-8B22a forzieri**: tabelle di bottino in `data/world/bottino.json`, `scripts/forziere.gd` (si apre una volta
   sola, il bottino nello zaino), forzieri nella grotta di marea, nel sotterraneo di Mirwada e nella cripta; e
   **US-8B22b**: 9 forzieri nel sottosuolo del mondo (`bottino.json forzieri_mondo`, in un vicolo cieco vicino al punto);
   **US-8B22c**: oggetti a caso nelle casette (`oggetti_casuali` dell'interno), uno preso non ricompare.
   E **US-8B23a/b**: la fauna d'atmosfera (cervo, lepre, uccello, farfalla, lucciole) nel mondo, che scappa quando si
   avvicina Enel (`data/world/fauna.json`, `scripts/world/fauna.gd`). E **US-8B24a**: il cannocchiale sul molo del
   faro, la vista vola alla Frontiera e torna (`data/world/cannocchiali.json`, `scripts/cannocchiale.gd`); **US-8B24b**:
   la lente con la nebbia che si dirada. E **US-8B25**: il buio di notte (`data/world/luce.json`, `scripts/world/luce.gd`).
   E la base del giocatore: **US-8B20a** (gli interni delle 4 basi a piu' stanze, arredi per livello) e **US-8B20b**
   (porte sul mondo, stanze arredate dal livello della sede, la pagina Base dalle stanze, la sede che si sposta).
   E **US-8B18e**: negli interni la camera inquadra la stanza (ferma in basso al centro, l'HUD sopra).
   E **US-8B20c/e**: l'orto all'aperto accanto alla sede, con le piante che crescono, e le strutture (palizzata,
   totem di veglia, deposito) costruite dalla pagina Base.
   E **US-8B20d**: la nave della base ormeggiata al cantiere navale, con la passerella verso il suo interno.
4. Fatte il 2026-10-29 (dal controllo dello stesso giorno): **US-8B22d** gli oggetti fissi si prendono una volta sola,
   **US-8B75** HUD leggibile (contorno alle scritte, barre colorate), **US-8B20f** orto e strutture bloccano il passo.
5. **Prossime, in quest'ordine** (tutte in `prd.json`, `passes: false`):
   1. Miglioramenti rapidi (priorita' 42-49): effetti sul bersaglio (US-8B44), icone nel negozio, in Indosso e
      nella modalita' cupa (US-8B70b), barca piu' veloce (US-8B91b), pontili stretti raggiungibili (US-8B96),
      cannocchiale senza nemici fuori dai muri (US-8B24c), bere dallo zaino e gesti degli NPC (US-8B80c), nemici
      nelle stanze piccole (US-8B21d), sigilli in Indosso (US-8B73e).
   2. Arte rimasta (55-61): cannocchiale da tasca (US-8B26), luci di notte (US-8B27), panorami per regione e cupi
      (US-8B74b), evocazioni (US-8B60a) e antagonisti (US-8B60b) con la loro figura, nuoto (US-8B90), arrampicata
      (US-8B92).
   3. **Atto II e III (65-77, fase 13, US-1301..US-1313)**: e' quello che serve per arrivare alla fine. PRD
      `prd-fase-12-atto-2-3.md` (vi si chiamano US-1201..US-1213: rinumerate come chiede US-1216 del Mondo vivo).
   4. Mondo vivo (80-96, fase 12): prima **US-1200** riscrive il PRD sul mondo generato (quello di oggi misura la
      mappa a layout di prima), poi US-1201..US-1216.
   5. Fusioni (100-106, fase 7b): i 7 percorsi ancora stub (US-7B01..07).
   6. Inglese (110-114): mancano 1496 voci su 1784 di `data/i18n/en.json` (US-EN01..05).
   7. Facoltativa: altri Pathway Non-Standard (ex "fase 13" della roadmap, ora 14).
6. **Controlli che spettano all'utente** (non si fanno in headless): giocare per provare i tempi d'attacco nuovi
   (leggero 450 ms, pesante 850 ms), la durata dei tragitti, la base, il caricamento del mondo su Windows.

---

## 3. Trappole gia' scoperte

- **Un test che va in errore risulta superato**: GDScript non ha eccezioni. Usa sempre
  `bash tools/run_tests.sh`, che fallisce se nell'output compare `SCRIPT ERROR` o un errore di
  formattazione. Mai `"%s" % lista` con un Array: si scrive `"%s" % [lista]`.
- **Zone dei layout** = `[x, y, larghezza, altezza]`, non due angoli.
- **Il giocatore sta dentro il nodo mondo** (`Mondo`, y_sort): chi lo cerca usa il gruppo `player`;
  chi lo sposta usa `mondo.colloca()` (porta anche la telecamera).
- **Le collisioni esistono solo nei blocchi caricati** attorno al giocatore: i nemici lontani vanno
  fermati (`_aggiorna_attivita`), altrimenti attraversano i muri.
- **Livelli**: un'area dell'altro livello (superficie/sottosuolo) va spenta (`monitoring`), non solo
  nascosta, altrimenti si raccoglie un oggetto sotterraneo camminandoci sopra.
- **forge3d**: `box` usa i semi-lati, `cylinder` (raggio x, raggio y, mezza altezza).
- **Esportare il mondo** costa ~1 ora e ~18 MB nel repo: usare le opzioni parziali
  (`--solo-blocchi`, `--sottosuolo`, `--solo-dati`, `--edifici`) quando bastano. `--edifici` (~5 minuti) rifa' gli
  oggetti di scena dal generatore e toglie quelli dentro le case: rilanciato da' gli stessi file byte per byte.
- **Il tetto di una casa sporge verso nord** di 3-4 caselle (muro + colmo): una porta va dove la soglia e le 3
  caselle sotto sono libere, altrimenti il giocatore sulla soglia sparisce sotto il tetto della casa davanti.
- `export_spec` di forge3d scrive `<categoria>_<nome>.png`: esportare in una cartella temporanea
  quando il nome coincide con fogli gia' esistenti (e' successo con gli NPC: sovrascriveva Enel).
- `tools/generate_sprites.py` (fase 8) non riscrive piu' i fogli dei personaggi: quelli li fa
  `tools/art/build_personaggi.py` a 64 px.
- Il libro prende colori, font e immagini da `data/ui/book.json` `tema`: un colore nuovo in una pagina
  deve leggersi sulla pergamena (niente bianco, niente ciano).

---

## 4. Regole dell'utente da ricordare

- "Non mi devi spiegare niente, tu fai e basta": si fa, si verifica, si riassume. Si chiede solo per le
  decisioni di design o di gioco e per cambiare cose gia' approvate (strade, luoghi, villaggi, sottosuolo).
- Mai lasciare imperfezioni: ogni asset si guarda ingrandito, ogni story di gioco si prova a schermo.
- Rispondere in italiano, con parole semplici.
