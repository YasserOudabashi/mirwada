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

Salva in `assets/concept/regioni/<id>.png` (es. `marche_crepuscolo.png`,
`trono_del_gigante.png`). Materiale di riferimento per atmosfera/palette, non
un asset di gioco.

## 5. Tileset di gioco (pixel art reale)

`tools/generate_placeholders.py` genera un tileset placeholder di 4 tile per
`assets/placeholder/tileset.png`: **pavimento, muro, ostacolo, acqua**, ognuno
32x32. Quando disegni il tileset vero di una regione:

1. Stessa griglia: 4 tile 32x32, edge-tileable (i bordi combaciano tra loro).
2. Palette della regione (max inchiostro + primario + accento, cap. 4).
3. Outline scuro 2px, niente anti-aliasing, coerente con lo stile pixel degli
   sprite (vedi `03_sprite_e_animazioni.md`).

Prompt di riferimento (`art-brief-gemini.md` cap. 6.5):

```
[BLOCCO STILE PIXEL — vedi 03_sprite_e_animazioni.md]
A small tileset strip: four 32x32 top-down terrain tiles side by side for
[regione] — (1) walkable ground, (2) solid wall, (3) a low obstacle,
(4) water. Each tile self-contained and edge-tileable. Palette [inchiostro +
primario + accento della regione]. Aspect 4:1.
```

Riferimento generato da IA → `assets/concept/sprite_ref/tileset_<regione>.png`.
Tileset reale, dopo post-produzione (ritaglio esatto, verifica in gioco) →
sostituisce `assets/placeholder/tileset.png`.

## 6. Prima di considerarlo fatto

Vedi `05_checklist_finale.md`. In piu', specifico per le regioni: ogni
`location_tag` della tabella al punto 2 deve essere effettivamente
riconoscibile in almeno un punto della mappa (il validator dei dati richiede
gia' che ogni tag sia ospitato da una regione — qui si tratta di renderlo
*visibile*, non solo dichiarato).
