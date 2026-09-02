# Design — nomi e lore

Registro dei nomi propri del gioco. **Non è codice e non è ancora dato.**
Finché non esiste il file di i18n (primo testo UI: US-017) e il sistema NPC
(fase 6 — Mondo), questi nomi vivono qui come decisioni di design. Quando i
sistemi arrivano, entrano come stringhe in `data/i18n/*` e in un eventuale
`data/npc/*` — mai hardcoded, come impone `CLAUDE.md` e il flag
`SERIAL_NUMBERS_FILED_OFF`.

---

## Titolo

**Mirwada.** È il titolo del gioco (`project.godot` → `config/name`).
Da non confondere con *Sequenza*/*Sequenze*, che nel resto dei documenti
resta il termine di gameplay: lo scalino di progressione di un Pathway
(9 = più basso, 0 = Vero Dio).

## Protagonista

- Nome di default: **Enel**.
- Il giocatore **può sceglierne un altro** alla creazione del personaggio.
- Il default non è un placeholder: se il giocatore non digita nulla, il gioco,
  i dialoghi e i sussurri della follia usano "Enel".
- Implicazioni tecniche (da agganciare a una story, oggi non esiste):
  - schermata di creazione personaggio → campo nome, fallback "Enel";
  - il nome scelto è parte dello stato salvato (vedi US-015, salvataggi
    versionati);
  - ovunque il nome compaia a schermo passa da una chiave i18n con
    parametro, non da concatenazione di stringhe.

## NPC

Nomi propri degli NPC incontrabili. Ruoli e agganci ai sistemi già esistenti
(Ancore del giocatore; i sussurri della follia usano i nomi degli NPC
incontrati — vedi `data/audio.json` e `progress.txt` soglia follia 55).

| id            | nome    | ruolo                                                                 | aggancio ai sistemi |
|---------------|---------|----------------------------------------------------------------------|---------------------|
| `npc_mirco`   | Mirco   | Primo volto amichevole dell'area di partenza. Insegna le basi.       | Ancora candidata #1 |
| `npc_sidon`   | Sidon   | Mercante di reagenti e voci; sa più di quanto dice.                  | fonte di rumor/lore |
| `npc_vesna`   | Vesna   | Guaritrice ai margini della città; diffida dei Beyonder.             | Ancora candidata #2 |
| `npc_aldo`    | Aldo    | Ex compagno di lavoro del protagonista, ora rivale in ascesa.        | tensione morale / duello |
| `npc_ottavia` | Ottavia | Archivista di un ordine minore; concede accesso a testi proibiti.    | gating di conoscenza (Pathway) |
| `npc_bruno`   | Bruno   | Contrabbandiere del porto; apre strade che la legge chiude.          | gating di zona (fase 6) |
| `npc_lena`    | Lena    | Bambina del quartiere operaio; non ha idea di cosa sei diventato.    | Ancora candidata #3 (la più fragile) |
| `npc_doran`   | Doran   | Investigatore che segue le tue tracce dopo ogni uso di potere.       | pressione/inseguimento |

Mirco e Sidon sono richiesti dall'utente. Gli altri sei sono inventati e
**rinegoziabili**: servono per non lasciare vuoto il roster quando la fase 6
inizia, non sono canonici finché non entrano in un dato con una quest attorno.

## Regole di naming (ribadite qui perché è il posto giusto)

- Nessun nome proprio hardcoded in script o `.tscn`: solo `id` + chiave i18n.
- `id` in inglese/neutro (`npc_mirco`), nome localizzabile.
- Aggiungere un NPC = aggiungere una riga a questa tabella e poi al dato,
  non una classe.

## Cosa NON è deciso qui

- Significato/etimologia di "Mirwada" e "Enel" nella finzione.
- Ambientazione precisa (epoca, città): la roadmap la colloca in fase 6.
- Quali NPC diventano davvero Ancore: dipende dal sistema di Ancore (fase 3+).
