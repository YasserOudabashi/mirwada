# Prossimi passi — istruzioni per la prossima sessione di Claude Code

> Riscritto il 2026-11-10 dopo il controllo generale (la versione del 2026-10-29 metteva l'arte prima del finale).
> Leggilo **dopo** `CLAUDE.md` e **prima** di toccare qualunque file. Il dettaglio di ogni story fatta e' in
> `progress.txt` (le fasi 1-11 in `archive/progress-fasi-1-11.txt`), le story aperte in `prd.json`.

---

## 0. Il quadro in tre righe

Le fasi 1-11 e la fase 8b (arte) sono chiuse e tutto e' su `main`. Il gioco si gioca nel mondo generato con arte
vera, interni, base, mezzi, fauna, notte. **Non si puo' ancora finire** (la prova finale non si supera) e per
giocarlo tutto mancano anche **nemici diversi**, l'**audio** e una **partita intera provata dall'inizio alla fine**.

---

## 1. Stato del repo (2026-11-10)

- `main` contiene tutto (ultima PR unita: #9, US-8B24c).
- CI GitHub Actions accesa su push a `main` e sulle pull request (validator + `tools/run_tests.sh`).
- Verifica locale: `python tools/validate_data.py` e `bash tools/run_tests.sh` (1093 test, ~5 minuti).
- **Niente controlli automatici** della PR o della CI (decisione dell'utente, 2026-10-29).
- 131 story in `prd.json`: 62 fatte, 69 aperte.

---

## 2. Cosa manca per finire il gioco, in ordine

Tutto in `prd.json` (`passes: false`), la priorita' e' il numero tra parentesi.

| # | Blocco | Story | Perche' |
|---|---|---|---|
| 1 | Ritocchi rapidi (41-44) | US-8B80c, 8B21d, 8B73e, 8B75b | piccoli, chiudono la fase 8b |
| 2 | **Atto II e III** (50-63), fase 13 | US-1301..1313 + US-8B60b | **senza, il gioco non si finisce**: la prova finale `trib_1_0` non si supera nel mondo vero; solo 4 quest in tutto il gioco, tutte dell'Atto I |
| 3 | **Nemici e boss** (65-72), fase 15 | US-1501..1507 + US-8B60a | i 72 nemici e i 6 boss sono tutti `nemico_base` ingrandito; le evocazioni non si vedono |
| 4 | **Audio** (75-79), fase 16 | US-1601..1605 | nessun file audio: bip di prova e musiche mute |
| 5 | Mondo vivo (80-96), fase 12 | US-1200..1216 | punti d'interesse, villaggi, dungeon tra le regioni; prima US-1200 riscrive il PRD sul mondo generato |
| 6 | Fusioni (100-106), fase 7b | US-7B01..07 | 7 percorsi di fusione su 8 sono vuoti (stub) |
| 7 | **Rilascio** (108-111), fase 17 | US-1701..1704 | quattro partite intere fino al finale, bilanciamento, primi minuti chiari, eseguibile per Windows |
| 8 | Rifiniture d'arte (115-119) | US-8B26, 8B27, 8B74b, 8B90, 8B92 | cannocchiale da tasca, luci di notte, panorami per regione, nuoto, arrampicata: non bloccano niente |
| 9 | Inglese (125-129) | US-EN01..05 | mancano 1496 voci su 1784 di `data/i18n/en.json` |
| — | Facoltativa | fase 14 | altri Pathway Non-Standard |

Il **gioco e' finito e giocabile al 100% in italiano** alla fine del blocco 7. PRD dei blocchi:
`prd-fase-13-atto-2-3.md` (vi si chiamano ancora US-1201..1213), `prd-fasi-15-17-gioco-completo.md` (nemici, audio,
rilascio), `prd-fase-12-mondo-vivo.md` (da riscrivere con US-1200).

**Decisioni che spettano all'utente** prima di cominciare il blocco:
- blocco 3: quali tipi di nemico in quale regione (proposta: uno per regione e uno per il sottosuolo, poi si allarga);
- blocco 4: suoni generati da Claude con uno script (come gli sprite) oppure presi da librerie libere CC0;
- blocco 8: il cannocchiale da tasca si trova o si compra (US-8B26).

**Controlli che spettano all'utente** (non si fanno in headless): giocare per provare i tempi d'attacco (leggero
450 ms, pesante 850 ms), la durata dei tragitti, la base, il caricamento del mondo su Windows.

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
