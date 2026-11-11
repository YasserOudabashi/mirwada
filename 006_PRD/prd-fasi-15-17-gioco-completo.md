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
- Decisione per l'utente (prima di US-1501): quali tipi per quale regione. Proposta di partenza: uno a testa
  (citta', Valle, Archivio, Marche, Frontiera, sottosuolo) e poi si allarga.

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
