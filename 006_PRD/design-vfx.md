# Mirwada — Identita' visiva delle abilita' (stile manhwa)

Figlio di `design-master.md`. Riferimento dichiarato dall'utente: *Legend of
the Northern Blade*. `data/vfx.json` nasce in fase 2 con le prime primitive
visibili; le palette valgono per sempre.

---

## 1. Cosa si prende dal manhwa (e cosa significa a 32×32)

Lo stile di Northern Blade, ridotto ai principi che un action 2D in pixel art
puo' davvero rubare:

1. **Il tratto a pennello d'inchiostro.** I fendenti sono calligrafia: linee
   spesse, cariche, con inizio e fine irregolari. → I nostri slash sono
   sprite a 2-3 frame con contorno nero pesante (2 px) e UN colore di pathway
   dentro. Mai gradienti, mai glow morbido: inchiostro.
2. **Il nero come strumento.** Le tavole usano il nero pieno per aura,
   tensione, peso. → Nei momenti forti (abilita' di Sequenza ≤ 4, parata
   perfetta, rottura di postura) lo sfondo si mangia di nero per qualche
   frame e restano le silhouette + gli accenti.
3. **L'impact frame.** Il colpo che conta e' UN fotogramma a contrasto
   invertito (bianco/nero puri). → 1-2 frame di inversione, agganciati agli
   `hitstop_ms` gia' in `audio.json.combat_feedback`: audio, hitstop, shake e
   impact frame si tarano INSIEME (il principio e' gia' scritto li').
4. **La distorsione dello spazio.** Un fendente pesante piega l'aria: si vede
   la pressione, non solo la lama. → Shader di displacement lungo la
   traiettoria, intensita' parametrata per pathway (`distorsione` 0..1),
   disattivabile (`riduci_distorsione`).
5. **La traiettoria leggibile.** Nel manhwa si puo' sempre ricostruire
   l'angolo di un colpo e della sua deviazione. → Ogni attacco lascia una
   scia che *insegna la geometria*: l'arco del melee mostra l'angolo vero
   della hitbox, il proiettile la sua linea. La leggibilita' del combat e'
   FR-8 applicato alla vista: lo stile serve il gameplay, mai il contrario.
6. **La firma per scuola.** Ogni setta del manhwa ha una visualita' coerente
   (la Northern Heavenly Sect: fredda, precisa, deflessioni). → Ogni pathway
   ha una firma visiva fissa: la palette (cap. 2). Un giocatore riconosce il
   pathway di un nemico dal colore e dal tratto prima di leggere una barra.

## 2. Le dieci palette visive: specchio 1:1 della palette audio

`audio.json.pathway_palette` da' gia' a ogni pathway materiale, riverbero e
registro. `data/vfx.json.pathway_palette_visiva` e' il gemello — stessa
chiave, stessa filosofia ("10 palette invece di 200 sprite"):

| Pathway | Audio (materiale) | Inchiostro + primario + accento (`data/vfx.json`) | Tratto |
|---|---|---|---|
| twilight_giant | metallo_luce | `#0a0a0f` + **oro** `#e8c34a` + bianco caldo `#fff6d8` | `pennellata_carica` — piena, pesante, dritta |
| death | ossa_vento | `#08090b` + **grigio-azzurro ardesia** `#5f7d8c` + bianco gelido `#d7e9f0` | `glifo` — il tratto disegna sigilli |
| darkness | feltro_soffio | `#07070a` + **viola scuro** `#4b3b6b` + lilla chiaro `#b9a6e0` | `pennellata_secca` — spezzata, secca |
| fool | carta_corda | `#0a080c` + **lilla grigio** `#8f7fae` + lilla chiarissimo `#e8e0f2` | `assenza` — niente scia: sparisce |
| error | vetro_scatto | `#0b0a08` + **ruggine** `#c85a3c` + pesca chiaro `#ffd8c0` | `scheggia` — segmenti spigolosi, interrotti |
| door | aria_risucchio | `#0a0810` + **viola** `#7a5cc0` + argento-lilla `#e4d6ff` | `cerchio` — archi e anelli, mai linee dritte |
| hermit | pergamena_cristallo | `#0a0906` + **ambra** `#b98a3e` + pergamena `#f2dcae` | `tratteggio` — doppio segno, come una cosa e la sua finta |
| paragon | ottone_ingranaggio | `#0a0a0c` + **grigio caldo** `#c9c2b0` + bianco `#ffffff` | `meccanico` — linee parallele, angoli netti |
| mother | legno_linfa | `#060a07` + **verde linfa** `#5c9a4e` + verde chiaro `#d8f0c8` | `crescita` — il tratto germoglia dal punto d'origine |
| moon | acqua_pelo | `#070a0c` + **azzurro lunare** `#6fb0c4` + bianco argento `#dff4fa` | `fluido` — curve continue, come acqua |

> **Allineata a `data/vfx.json` il 2026-10-14** (decisione dell'utente: vale il file dati).
> La tabella precedente aveva colori e tratti diversi per death, darkness, fool, error,
> hermit, moon e paragon; resta nella storia di git.

I valori esadecimali precisi si fissano in `data/vfx.json` con la prima story
di fase 2 (e si tarano a schermo, non sulla carta). La regola che non cambia:
**inchiostro scurissimo + UN primario + UN accento**. Tre colori per pathway,
mai di piu' — a 32×32 il quarto colore e' rumore.

## 3. VFX per primitiva, non per abilita'

Stesso principio dell'audio: le ~28 primitive hanno ciascuna UN effetto
parametrizzato dalla palette del pathway di chi la lancia. `tg_fendente_pesante`
e un futuro fendente del Death usano lo stesso sprite di slash — cambiano
inchiostro, primario, tratto, distorsione. 28 effetti invece di 200.

Aggancio al timing gia' esistente: `animations.json` ha l'animazione `cast`
con l'evento `ability_release` al frame 3 (il VFX parte li') e `tell_visivo`
sugli attacchi pesanti dei nemici (il tell visivo del telegraph, FR-8, usa
l'accento della palette del nemico).

## 4. Schema dati (forma)

`data/vfx.json` + `data/schema/vfx.schema.json`:

```json
{
  "schema_version": 1,
  "pathway_palette_visiva": {
    "twilight_giant": {
      "inchiostro": "#0a0a0f",
      "primario": "#e8c34a",
      "accento": "#fff6d8",
      "tratto": "pennellata_carica",
      "scia": "solida",
      "distorsione": 0.3
    }
  },
  "primitive_vfx": {
    "melee_arc": { "sprite": "vfx_slash", "frames": 3, "impact_frame": true, "scia": true },
    "projectile": { "sprite": "vfx_bolt", "frames": 2, "impact_frame": true, "scia": true },
    "buff_stat": { "sprite": "vfx_rune_up", "frames": 4, "impact_frame": false, "scia": false }
  },
  "impact_frames": {
    "stile": "inversione",
    "durata_frames": 2,
    "_comment": "Durata legata a combat_feedback.hitstop_ms di audio.json: si tarano insieme."
  },
  "nero_di_scena": {
    "_comment": "Lo sfondo si mangia di nero nei momenti forti (principio 2).",
    "trigger": ["parry_perfect", "posture_break", "abilita_sequenza_max_4"],
    "durata_ms": 250
  },
  "accessibilita": {
    "riduci_distorsione": false,
    "riduci_flash": false,
    "_comment": "riduci_flash sostituisce l'inversione dell'impact frame con un bordo spesso: stessa informazione, niente lampo. Fotosensibilita'."
  }
}
```

Vocabolario chiuso dei `tratto`: `pennellata_carica`, `pennellata_secca`,
`assenza`, `tratteggio`, `scheggia`, `cerchio`, `glifo`, `meccanico`,
`crescita`, `fluido` (uno per pathway, di proposito: il tratto E' la firma).

Check del validator che nascono con questo file: palette presente per ogni
pathway attivo (identico al check audio gia' esistente); `tratto` nel
vocabolario; ogni primitiva attiva *implementata* con una voce in
`primitive_vfx`; colori in formato `#rrggbb`.

Nota di architettura: **nessun campo VFX sulle abilita'** — tutto vive per
pathway + primitiva, quindi `ability.schema.json` (additionalProperties:
false) NON si tocca. Un'abilita' futura che volesse un VFX unico e' il caso
raro che merita discussione, non un campo di default.

## 5. Follia e percezione (fase 2)

I due canali informativi promessi dalla roadmap hanno la loro resa qui:

- **Follia** (roadmap fase 2, "effetti visivi con opzione di accessibilita'"):
  alle soglie di balance.json — 15: bordi dello schermo che respirano
  d'inchiostro; 40: le distorsioni toccano gli sprite (un NPC per un frame ha
  il tratto di un altro pathway); 70: il nero di scena si attiva da solo;
  100: il finale Consumazione. Con `disattiva_sussurri`/`riduci_flash` la
  versione ridotta e' statica (vignetta fissa), mai assente: la follia deve
  restare leggibile, non aggredire.
- **Percezione per Sequenza** (`sequence_perception` in audio.json): ogni
  `reveal` ha l'equivalente visivo (FR-8) — spiriti_vicini: sagome
  all'accento del proprio pathway oltre i muri; densita_mistica: grana
  d'inchiostro nell'aria; segreti_adiacenti: un segno a margine... nel libro,
  sulla pagina della mappa (aggancio a design-ui-libro).

## 6. Cosa serve all'artista (quando arrivera')

Il PRD di fase 1 rimanda la scelta dell'artista a gioco divertente coi
placeholder. Questo documento e' la meta' della specifica da consegnargli
(l'altra meta' e' animations.json): 10 palette a 3 colori, vocabolario dei
tratti, budget frame per VFX (slash 3, bolt 2, rune 4...), impact frame a
inversione, 32×32, 4 direzioni. I placeholder diagnostici attuali
(generate_placeholders.py) restano lo strumento di lavoro fino ad allora.
