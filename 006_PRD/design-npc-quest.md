# Mirwada — NPC, dialoghi, fazioni, quest, narrativa

Figlio di `design-master.md`. Materia di fase 6; il roster e i contratti si
fissano ora perche' i dati li citano gia' (sussurri a soglia 55 che usano i
nomi degli NPC, `npc_influenced` nel vocabolario eventi, le Ancore nei
sacrifici rituali). Parte dal roster di `design-lore.md`: Mirco e Sidon
richiesti dall'utente, gli altri sei confermati qui (decisione aperta n. 6 del
master, raccomandazione: tenerli tutti).

---

## 1. Il principio: gli NPC sono dati, i dialoghi non inventano un motore

Un NPC e' una voce di `data/npc/roster.json`. Un dialogo e' un grafo a nodi in
`data/dialogues/`. Le **condizioni** dei dialoghi riusano lo STESSO vocabolario
delle abilita' (`ability.schema.json`): `in_zona_tag`, `e_notte`,
`fase_lunare`, `tier_min`, `foundation_min` — piu' tre voci nuove che entrano
nell'enum con il motore dialoghi: `follia_min`, `reputazione_min`, `flag`.
Un solo vocabolario di condizioni in tutto il gioco: un dialogo che si apre
solo di notte usa la stessa condizione di un'abilita' che funziona solo di
notte.

Gli **effetti** dei dialoghi sono un vocabolario chiuso di ~5 voci:
`emit_event` (solo eventi dei 12: in pratica `npc_influenced` con i suoi 5
modi), `flag`, `reputazione`, `apri_vendita`, `avvia_quest`. Niente scripting
libero nei dialoghi: se un dialogo sembra richiedere un effetto nuovo, quasi
sempre e' un flag piu' una quest.

## 2. Il roster (8, da design-lore.md)

| id | Chi e' | Funzione meccanica | Ancora? |
|---|---|---|---|
| `npc_mirco` | primo volto amichevole, insegna le basi | tutorial diegetico; vende nulla, insegna | candidata #1 |
| `npc_sidon` | mercante di reagenti e voci, sa piu' di quanto dice | economia (listino ingredienti), rumor a pagamento | no |
| `npc_vesna` | guaritrice ai margini, diffida dei Beyonder | cura a prezzo di fiducia: la reputazione con lei scende usando poteri davanti a lei | candidata #2 |
| `npc_aldo` | ex collega, ora rivale in ascesa | specchio del giocatore: avanza di Sequenza col tempo di gioco; duelli ai passaggi di tier | no |
| `npc_ottavia` | archivista di un ordine minore | **gating di conoscenza**: concede i flag `testi_*` che aprono l'Archivio Sepolto | no |
| `npc_bruno` | contrabbandiere del porto | **gating di zona**: porto di notte, passaggi verso le Marche | no |
| `npc_lena` | bambina del quartiere operaio, non sa cosa sei | l'Ancora piu' fragile: nessun servizio, solo umanita'. Le sue scene misurano quanto ne resta | candidata #3 |
| `npc_doran` | investigatore che segue le tue tracce | **pressione**: ogni uso di potere in citta' alza il suo sospetto; a soglie, eventi di caccia | no |

Contratti gia' vivi nei dati che questo roster onora:
- i sussurri di follia a soglia 55 usano "i nomi degli NPC che il giocatore ha
  incontrato e delle sue Ancore" (audio.json) → il sistema NPC espone la lista
  dei *conosciuti* e delle Ancore attive;
- `tg_6_giuramento` chiede di aiutare 8 NPC, `fool_9_inganno` di ingannarne
  10 → servono NPC minori *generici* oltre al roster (popolani con id
  `npc_generic_*`, senza dialogo profondo, influenzabili);
- fool_6 "eredita i permessi sociali" → i permessi sociali sono i gate di tipo
  `npc` e `conoscenza` di design-world: il Faceless li ruba temporaneamente.

## 3. Memoria e reputazione

Ogni NPC del roster ricorda **come** lo hai influenzato: il campo `memoria`
accumula i modi di `npc_influenced` (`persuaso`, `ingannato`, `aiutato`,
`intimidito`, `risparmiato`). Un inganno *scoperto* (evento di quest) sposta la
memoria e la reputazione. Non serve un sistema di simulazione sociale: e' un
contatore per modo, letto dalle condizioni dei dialoghi.

**Fazioni** (`data/factions.json`, fase 6): poche e concrete, 3-4.
Proposta: `ordine_minore` (Ottavia; conoscenza), `porto` (Bruno, Sidon;
commercio e contrabbando), `quartiere` (Mirco, Vesna, Lena; la vita civile),
`giustizia` (Doran; la legge). Reputazione numerica con soglie; `reputazione`
come effetto di dialogo/quest e `reputazione_min` come condizione. Doran e' una
fazione da un uomo solo: la sua "reputazione" e' il sospetto, e sale da solo.

## 4. Le quest sono contatori travestiti

Regola dura: **zero verbi di quest nuovi nel motore**. Ogni step di quest si
completa in uno di due modi:
1. un evento dei 12 con filtri (lo stesso EventTracker dell'Acting Method:
   "purifica la cripta" = `area_cleared` con filtri), oppure
2. un flag di dialogo (`parla con X e convincilo` = flag scritto dall'effetto
   del dialogo).

Se una quest sembra richiedere un rilevatore speciale, e' scritta male: si
riformula sugli eventi. Il motore quest e' un lettore di
`data/quests/*.json` che osserva EventTracker e flag — e' la stessa
architettura della recitazione, applicata alla narrativa. Costo: ~1-2 story.

`fallibile: true` esiste dal giorno 1 nello schema: una quest puo' fallire
(tempo, morte di un NPC, scelta opposta) e il journal la mostra fallita.
Fallire e' contenuto, non game over.

## 5. Struttura narrativa: tre atti sui tier di Sequenza

La progressione narrativa e' agganciata a quella meccanica — gli atti *sono*
le fasce di tier:

- **Atto I — la citta' (Seq 9-7, tier low).** Mirwada, il lavoro, le prime
  pozioni. Doran comincia a notare le coincidenze. Le quest insegnano i
  sistemi (Mirco), aprono l'economia (Sidon), piantano le Ancore (Lena,
  Vesna). Finisce quando il primo rituale non basta piu': per la Sequenza 6
  serve cio' che la citta' non ha.
- **Atto II — le regioni (Seq 6-4, tier mid/saint).** Marche, Valle, Archivio
  si aprono (gating per primitiva e conoscenza). Le fazioni prendono posizione
  su cosa stai diventando. Aldo avanza in parallelo e il confronto diventa
  inevitabile. I rituali cominciano a chiedere luoghi veri e sacrifici veri.
- **Atto III — la soglia (Seq 3-1, tier saint/angel).** La Frontiera delle
  Porte. Le tribolazioni (roadmap fase 7). Il rituale di Sequenza 1 chiede
  **un'Ancora** (gia' scritto nei dati del TG): la storia arriva dove la
  meccanica aveva promesso. Doran sa. Lena capisce. Vesna sceglie.
- **Finale — Sequenza 0.** Il rituale chiede "il detentore precedente della
  Sequenza 0" (gia' nei dati). Chi e', dove si trova e cosa significa
  sacrificarlo e' la rivelazione della trama principale.

### I finali (con `data/endings.json`, fase 7)

1. **Apoteosi** — Sequenza 0 raggiunta. Vinci, e il costo e' esattamente la
   lista delle Ancore spese per arrivarci.
2. **Consumazione** — follia a 100: game over *con eredita'* (roadmap fase 7)
   al personaggio successivo. Cosa si eredita e' la decisione aperta n. 8.
3. **Rinuncia** — il finale umano: fermarsi, distruggere la pozione,
   restare a una Sequenza mortale. Sbloccato dalle Ancore mantenute vive.
   E' il finale che da' senso a Lena.

Varianti di epilogo per gruppo di pathway (4 varianti, non 10: il gruppo
decide il sapore dell'apoteosi).

### L'antagonista (decisione aperta n. 9 del master)

Tre candidati gia' nel cast, in ordine di raccomandazione:
1. **il detentore precedente della Sequenza 0** del pathway del giocatore —
   l'antagonista e' *strutturale*, gia' nei dati, e cambia con il pathway
   scelto: massima rigiocabilita', zero contenuto sprecato;
2. l'ordine di Ottavia, che colleziona Beyonder come colleziona testi;
3. Doran come tragedia — l'uomo giusto dalla parte sbagliata (funziona meglio
   come pressione costante che come boss finale).

## 6. Schema dati (forma, non contenuto)

### `data/npc/roster.json` + `npc.schema.json` — un file, 8+ voci

```json
{
  "schema_version": 1,
  "npcs": [
    {
      "id": "npc_mirco",
      "name_i18n": "npc.mirco.name",
      "role_i18n": "npc.mirco.role",
      "region_id": "mirwada",
      "anchor_candidate": true,
      "faction_id": "quartiere",
      "schedule": [
        { "momento": "alba", "location_tag": "piazza" },
        { "momento": "notte_fonda", "location_tag": null }
      ],
      "vendor": null,
      "dialogue_id": "dlg_mirco",
      "memoria": {}
    }
  ]
}
```

`schedule` usa i `momento` di time.json e i `location_tags` di design-world:
gli NPC vivono nel ciclo del tempo (Bruno esiste solo di notte). `vendor`
non-null porta un `listino` di `item_id` (la valuta e' un oggetto:
design-master cap. 5).

### `data/dialogues/dlg_*.json` + `dialogue.schema.json` — un file per NPC

```json
{
  "schema_version": 1,
  "id": "dlg_mirco",
  "start": "n1",
  "nodes": {
    "n1": {
      "speaker": "npc_mirco",
      "text_i18n": "dialogue.mirco.n1",
      "choices": [
        {
          "text_i18n": "dialogue.mirco.n1.a",
          "condizioni": [ { "tipo": "tier_min", "valore": "mid" } ],
          "effetti": [
            { "tipo": "emit_event", "evento": "npc_influenced", "modo": "persuaso" },
            { "tipo": "flag", "id": "mirco_sa_del_potere", "valore": true }
          ],
          "goto": "n2"
        }
      ]
    }
  }
}
```

Il testo del giocatore parametrizza il nome scelto via chiave i18n con
parametro (design-lore: mai concatenazione).

### `data/quests/*.json` + `quest.schema.json`

```json
{
  "schema_version": 1,
  "id": "q_mirco_01",
  "name_i18n": "quest.q_mirco_01.name",
  "giver": "npc_mirco",
  "atto": 1,
  "fallibile": false,
  "exclusive_with": [],
  "steps": [
    {
      "id": "s1",
      "desc_i18n": "quest.q_mirco_01.s1",
      "completamento": { "tipo": "evento", "evento": "enemy_defeated",
                         "filtri": { "senza_abilita": true }, "target": 3 },
      "on_complete": [ { "tipo": "flag", "id": "q_mirco_01_s1", "valore": true } ]
    }
  ],
  "ricompense": [ { "tipo": "item", "item_id": "ferro_temperato", "quantita": 2 } ]
}
```

Check del validator che nascono con questi file: `region_id`/`location_tag`/
`momento` nei vocabolari; `dialogue_id` esistente; `speaker` nel roster;
`goto` verso nodi esistenti (niente nodi orfani o irraggiungibili dal
`start`); `evento` e filtri validi come per le acting_actions; `giver` nel
roster; chiavi i18n esistenti (quando R-12 e' fatta); effetti solo dal
vocabolario chiuso.
