# Regioni e mappe

Fonti: `006_PRD/design-world.md`, `data/world/regions.json`,
`data/schema/location_tags.json`, `006_PRD/art-brief-gemini.md` cap. 3.

## 1. Il principio

**Una regione per gruppo di Pathway + la citta' neutra = 5 regioni totali.**
Non e' decorazione: e' il terzo canale di identita' di un Pathway (oltre alle
abilita' e all'audio). Niente open world senza gating, niente generazione
procedurale (non-goal fisso di `CLAUDE.md`): le mappe sono **disegnate a
mano**.

## 2. Le 5 regioni (da `data/world/regions.json`, valori correnti)

| id | Palette visiva | Densita' mistica | Zona musica | location_tags da mostrare |
|---|---|---|---|---|
| `mirwada` (hub, neutra) | neutra | 0.2 (bassa: coltivare qui e' lento) | `citta` | porto, archivio, vicolo, piazza, sotterraneo |
| `marche_crepuscolo` (Twilight Giant, Darkness, Death) | `darkness` | 0.6 | `marche` | altura, luogo_di_battaglia, tempio_abbandonato, rovina, luogo_in_decadenza, vetta, luogo_di_massacro, cripta, trono_del_gigante |
| `valle_madre` (Mother, Moon) | `mother` | 0.45 | `valle` | bosco_antico, radura_lunare, grotta_di_marea, sorgente, altare_di_radici |
| `archivio_sepolto` (Hermit, Paragon) | `hermit` | 0.7 | `archivio` | biblioteca, officina, torre_di_osservazione, sala_dei_sigilli, studio |
| `frontiera_porte` (Fool, Error, Door) | `fool` | 0.9 (massima) | `frontiera` | teatro, crocevia, soglia, nebbia_grigia, palco |

`palette_visiva` rimanda ai colori concreti in `data/vfx.json` (vedi
`04_combattimento_vfx.md`). Densita' mistica alta = piu' segreti, spawn e
percezione a schermo per il giocatore — un'indicazione utile anche per quanto
"vivo/denso" deve sembrare il livello.

## 3. Il gating deve leggersi a schermo

Ogni regione ha varchi che si aprono solo in certe condizioni
(`data/world/regions.json.gating`). Disegnarli in modo che il giocatore li
riconosca **prima** di sapere come si aprono e' parte del lavoro:

| tipo di gate | esempio nel gioco | come renderlo visibile |
|---|---|---|
| `primitiva` | `shadow_meld` apre i passaggi d'ombra nelle Marche | un varco visibilmente "troppo scuro per essere normale" |
| `momento` | cripte aperte solo `notte_fonda` | un ingresso sigillato di giorno, aperto di notte |
| `fase_lunare` | grotte di marea con luna piena | un'apertura che cambia aspetto con la luna |
| `npc` | Bruno sblocca il porto notturno | una barriera fisica/sociale ovvia (cancello, guardia) |
| `conoscenza` | testi dell'Ordine Minore aprono l'Archivio | porte incise/sigillate, non genericamente "chiuse" |
| `sequenza` | la Frontiera respinge chi e' sopra Sequenza ~4 | una soglia che "rifiuta" visivamente, non solo un muro |

## 4. Key art di regione (illustrazione, non pixel art)

Formato **16:9**. Un prompt per regione in `art-brief-gemini.md` cap. 3.2-3.5
(gia' scritti e pronti da incollare), piu' uno separato per il
`trono_del_gigante` (sito unico del rituale di Sequenza 0 del Twilight
Giant). Esempio (Marche del Crepuscolo):

```
[BLOCCO DI STILE — vedi art-brief-gemini.md cap.1]
Wide desolate moorland under an endless burnt-orange sunset that never ends.
Ancient battlefield: broken spears and rusted blades half-sunk in black mud.
Long raking shadows, black silhouettes of ruined arches and a distant
mountain peak against the violet sky. A crumbling abandoned temple on a rise.
Palette: burnt orange horizon, deep violet-blue sky, full black silhouettes,
gold accents. Aspect 16:9.
```

Salva in `assets/concept/regioni/<id>.jpg` (es. `marche_crepuscolo.jpg`,
`trono_del_gigante.jpg`; il nome e' l'`id` della regione, non quello che
assegna Gemini). Le 6 key art attuali sono gia' rinominate cosi'. Materiale di riferimento per atmosfera/palette, non
un asset di gioco.

## 5. Terreni e pareti di gioco (generati, non disegnati)

Aggiornato il 2026-10-14: niente piu' tileset a 4 tile disegnati a mano.

- **Terreni:** `tools/art/forge3d/terrain.py`, tecnica *dual grid* a livelli: 16 tile per
  terreno, un terreno nuovo e' una riga in `TERRAINS` (rampa Endesga 32, motivo, livello).
  Tavola dei campioni: `python tools/art/campioni_terreni.py` -> `arte/terreni/`.
- **Pareti (dislivelli):** `tools/art/forge3d/pareti.py`. Ogni casella ha un'altezza intera;
  dove scende verso sud c'e' una parete alta 1 casella per livello (arenaria, roccia, mura),
  con scalini `S` e rampe `R`. Tavola: `python tools/art/campioni_pareti.py` -> `arte/pareti/`.
- **Mappa del mondo:** `python tools/art/build_world.py` (seed 6) -> `arte/mondo/`
  (`world_prova.json` con terreni, altezze, pareti e passaggi; anteprime e ritagli).
- Niente contorno su pavimento e acqua (si ripetono). Luce da alto-sinistra. Le correzioni si
  fanno nei dati o nel generatore, mai sul PNG.
- `assets/placeholder/tileset.png` resta solo per la stanza di prova: lo sostituisce il mondo
  vero (US-8B12).
- Il tileset a 8 colonne di `tools/generate_sprites.py` (US-813) resta solo per gli interni degli
  edifici (`interior_scene.gd`) e per la vecchia mappa a layout (`world_scene.gd`, fase 10), che
  dal merge con l'arte non e' piu' la scena di gioco.

## 6. Prima di considerarlo fatto

Vedi `05_checklist_finale.md`. In piu', specifico per le regioni: ogni
`location_tag` della tabella al punto 2 deve essere effettivamente
riconoscibile in almeno un punto della mappa (il validator dei dati richiede
gia' che ogni tag sia ospitato da una regione — qui si tratta di renderlo
*visibile*, non solo dichiarato).
