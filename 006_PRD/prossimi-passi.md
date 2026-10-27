# Prossimi passi — istruzioni per la prossima sessione di Claude Code

> Riscritto il 2026-10-26 (la versione del 2026-09-09 descriveva la fase 8 prima del merge).
> Leggilo **dopo** `CLAUDE.md` e **prima** di toccare qualunque file. Il dettaglio di ogni story
> fatta e' in `progress.txt` (cerca la sigla), le story aperte in `prd.json`.

---

## 0. Il quadro in tre righe

Le fasi 1-11 sono chiuse. L'arte (fase 8b) e' in corso: personaggi a 64 px, NPC, terreni e un
**mondo unico generato** (seed 6, 1200 x 1000 caselle) che e' la scena di gioco, con le case di
Mirwada, dei villaggi e le torri, e le porte verso i 14 interni delle fasi 10-11 (US-8B18a/b, 2026-10-26).
Gli interni sono disegnati e arredati (US-8B18c/d); varchi, barca, volo, soglia del faro e icone degli oggetti
e degli status, i glifi delle primitive e i VFX degli attacchi base sono fatti (2026-10-26), il panorama
dell'avvio il 2026-10-27. Quello che manca di piu' a schermo: i **VFX delle altre 24 primitive**.

---

## 1. Stato del repo (2026-10-26)

- Branch di lavoro: `claude/map-creation-resources-g0g7d5`, **PR #5** (draft) verso `main`.
  Contiene l'arte, il mondo generato e il merge della PR #4 (fasi 8-11, 2026-10-25).
- La **PR #4** (`claude/mini-trailer-prompt-adq22o`) e' interamente dentro la PR #5: si puo' chiudere.
- `main` e' ferma alla fase 7: va aggiornata mergiando la PR #5 quando l'utente lo decide.
- CI GitHub Actions **accesa** su push a `main` e sulle pull request (validator + `tools/run_tests.sh`).
- Verifica locale: `python tools/validate_data.py` e `bash tools/run_tests.sh` (1021 test, ~1 minuto).

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
4. **Prossime**: VFX delle altre primitive (US-8B41..43, stesso schema di build_vfx.py),
   feedback del colpo (scintilla, parata perfetta, polvere, rottura della postura), ritratti (US-8B35).
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
