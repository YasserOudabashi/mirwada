# Prossimi passi — istruzioni per la prossima sessione di Claude Code

> Riscritto il 2026-10-26 (la versione del 2026-09-09 descriveva la fase 8 prima del merge).
> Leggilo **dopo** `CLAUDE.md` e **prima** di toccare qualunque file. Il dettaglio di ogni story
> fatta e' in `progress.txt` (cerca la sigla), le story aperte in `prd.json`.

---

## 0. Il quadro in tre righe

Le fasi 1-11 sono chiuse. L'arte (fase 8b) e' in corso: personaggi a 64 px, NPC, terreni e un
**mondo unico generato** (seed 6, 1200 x 1000 caselle) che e' la scena di gioco. Quello che manca
di piu' a schermo sono gli **edifici**: la citta' di Mirwada ha i sedimi degli isolati ma nessuna casa,
e le porte verso gli interni delle fasi 10-11 non sono ancora sul mondo generato.

---

## 1. Stato del repo (2026-10-26)

- Branch di lavoro: `claude/map-creation-resources-g0g7d5`, **PR #5** (draft) verso `main`.
  Contiene l'arte, il mondo generato e il merge della PR #4 (fasi 8-11, 2026-10-25).
- La **PR #4** (`claude/mini-trailer-prompt-adq22o`) e' interamente dentro la PR #5: si puo' chiudere.
- `main` e' ferma alla fase 7: va aggiornata mergiando la PR #5 quando l'utente lo decide.
- CI GitHub Actions **accesa** su push a `main` e sulle pull request (validator + `tools/run_tests.sh`).
- Verifica locale: `python tools/validate_data.py` e `bash tools/run_tests.sh` (982 test, ~1 minuto).

---

## 2. Ordine delle story

1. **US-8B18 Edifici** (arte + codice, da spezzare):
   - **a)** forge3d: case per i quartieri della citta' (magazzini al porto, case strette nel quartiere
     operaio, botteghe nel centro storico, palazzi nel centro antico, baracche nei bassifondi, ville
     nella citta' nuova). Il generatore conosce gia' i sedimi (`build_world.py` `isolati()`: terreno
     `stone` dentro i quartieri): si esportano come oggetti con il loro rettangolo e la collisione.
   - **b)** porte verso gli interni: gli `edifici` dei layout e della campagna (14 interni) vanno su una
     casa vera, con la stessa regola di `mondo.gd popola()` (luogo della zona o posizione relativa). I
     villaggi della campagna vanno ai villaggi suggeriti dal generatore (da esportare in `mondo.json`).
     Entrare: il giocatore esce dal nodo mondo, si carica `interior_scene.tscn`, all'uscita torna alla porta.
   - **c)** gli interni con l'arte vera (oggi tileset segnaposto a 32 px).
2. **US-8B21 Varchi di gating visibili** e barriere delle sotto-aree (cripte, passaggi d'ombra, ponti di
   radici, grotte di marea, ali interne, isole di nebbia) nei punti giusti del mondo.
3. **Decisioni dell'utente** (chiedere, non decidere):
   - chi sa volare e come (US-8B93: altezza, cosa si scavalca, dove si atterra, costo, sblocco);
   - come si arriva alla Frontiera (oggi nessuno ci arriva: e' sospesa nel vuoto);
   - barche e isole (US-8B91).
4. Icone (US-8B70..72), panorami (US-8B74), VFX (US-8B40..44), ritratti (US-8B35).
5. Fase 12 (PRD `prd-fase-12-atto-2-3.md`, `prd-fase-12-mondo-vivo.md`).

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
  (`--solo-blocchi`, `--sottosuolo`, `--solo-dati`) quando bastano.
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
