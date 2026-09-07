# Combattimento e VFX

Fonti: `006_PRD/design-vfx.md` (principi), `data/vfx.json` (valori correnti —
i colori sono segnati come "plausibili", l'arte vera li puo' rivedere ma la
struttura resta), `data/animations.json` (timing).

## 1. I principi (stile: Legend of the Northern Blade)

1. **Il tratto a pennello.** I colpi sono calligrafia: linee spesse, cariche,
   con inizio/fine irregolari — sprite a 2-3 frame, outline nero 2px pesante,
   UN colore di Pathway dentro. Mai gradienti, mai glow morbido.
2. **Il nero come strumento.** Nei momenti forti lo sfondo si mangia di nero
   per qualche frame e restano silhouette + accenti (vedi "nero di scena"
   sotto).
3. **L'impact frame.** Il colpo che conta e' 1-2 frame a contrasto invertito
   (bianco/nero puri), sincronizzati con l'hitstop del colpo.
4. **La distorsione dello spazio.** Un colpo pesante piega l'aria: si vede la
   pressione, non solo la lama.
5. **La traiettoria sempre leggibile.** Ogni attacco lascia una scia che
   *insegna la geometria* del colpo: l'arco del melee mostra l'angolo vero
   della hitbox, il proiettile la sua linea. Lo stile serve sempre la
   leggibilita' del gameplay, mai il contrario.
6. **Una firma per Pathway.** Un giocatore deve riconoscere il Pathway di un
   nemico dal colore e dal tratto prima ancora di leggere una barra vita.

## 2. Le 10 palette (valori correnti, `data/vfx.json`)

Regola che non cambia mai: **inchiostro scurissimo + UN primario + UN
accento**. Un quarto colore a 32x32 e' rumore, va rifiutato.

| Pathway | Inchiostro | Primario | Accento | Tratto (firma) |
|---|---|---|---|---|
| twilight_giant | `#0a0a0f` | `#e8c34a` | `#fff6d8` | `pennellata_carica` — piena, pesante, dritta |
| darkness | `#07070a` | `#4b3b6b` | `#b9a6e0` | `pennellata_secca` — spezzata |
| death | `#08090b` | `#5f7d8c` | `#d7e9f0` | `glifo` |
| door | `#0a0810` | `#7a5cc0` | `#e4d6ff` | `cerchio` — archi e anelli, mai linee dritte |
| error | `#0b0a08` | `#c85a3c` | `#ffd8c0` | `scheggia` — segmenti spigolosi, interrotti |
| hermit | `#0a0906` | `#b98a3e` | `#f2dcae` | `tratteggio` |
| moon | `#070a0c` | `#6fb0c4` | `#dff4fa` | `fluido` — curve continue |
| mother | `#060a07` | `#5c9a4e` | `#d8f0c8` | `crescita` — germoglia dal punto d'origine |
| paragon | `#0a0a0c` | `#c9c2b0` | `#ffffff` | `meccanico` — linee parallele, angoli netti |
| fool | `#0a080c` | `#8f7fae` | `#e8e0f2` | `assenza` — niente scia, la forma sparisce |

Il vocabolario dei `tratto` e' chiuso a queste 10 voci (uno per Pathway, di
proposito). Se un'idea richiede un undicesimo tratto, e' una discussione da
fare con l'utente, non una scelta libera.

## 3. VFX per primitiva, non per abilita'

Stesso principio dell'audio: ogni **primitiva** (non ogni abilita') ha un
effetto base, ricolorato dalla palette del Pathway di chi lo lancia.
`tg_fendente_pesante` e un futuro fendente del Death usano lo stesso sprite
di slash — cambia solo palette e tratto. ~24 effetti invece di 100+.

Esempi gia' fissati in `data/vfx.json` (sprite, frame, se ha impact frame,
se lascia una scia):

| Primitiva | Sprite | Frame | Impact frame | Scia |
|---|---|---|---|---|
| `melee_arc` | `vfx_slash` | 3 | si | si |
| `projectile` | `vfx_bolt` | 2 | si | si |
| `dash` | `vfx_streak` | 3 | no | si |
| `buff_stat` | `vfx_rune_up` | 4 | no | no |
| `heal` | `vfx_mend` | 4 | no | no |
| `teleport` | `vfx_rift` | 3 | si | no |
| `shadow_meld` | `vfx_umbra` | 4 | no | si |

(elenco completo con tutte le ~24 primitive attive in `data/vfx.json` —
questa tabella e' solo un campione dei pattern piu' comuni)

## 4. Leggibilita' del combattimento (FR-8) — non negoziabile

Questi tre punti sono i piu' importanti di tutto il documento, perche' sono
gia' meccanica di gioco, non solo estetica:

- **Il tell dei nemici parte al frame 0 dell'anticipo**, non dell'attacco:
  il giocatore ha ~4 frame per leggerlo e reagire. Deve essere visivamente
  ovvio (posa che cambia, colore che si accende) fin dal primo frame.
- **hitbox_on/hitbox_off** sono frame precisi (`data/animations.json`), non a
  occhio: l'arma/effetto deve visivamente "esistere" solo in quella finestra,
  altrimenti il giocatore impara un tempismo sbagliato guardando lo sprite.
- **La parata perfetta e' i primi 2 frame su 4 dell'animazione `parry`, a
  18fps (~111ms)**. E' la finestra piu' stretta del gioco: disegnala in modo
  che quei 2 frame si distinguano visivamente dagli altri 2.

## 5. Impact frame e "nero di scena"

- **Impact frame**: 1-2 frame a colori invertiti (bianco/nero puri),
  sincronizzati con l'hitstop del colpo (`audio.json.combat_feedback`).
- **Nero di scena**: lo sfondo diventa nero per 250ms in tre momenti —
  `parry_perfect`, `posture_break`, abilita' di Sequenza ≤4. Restano visibili
  solo silhouette + accenti di colore.

## 6. Accessibilita' (disegna sempre entrambe le varianti)

- `riduci_distorsione`: disattiva lo shader di piegatura dello spazio.
- `riduci_flash`: sostituisce l'inversione dell'impact frame con un bordo
  spesso — stessa informazione, niente lampo (fotosensibilita').

## 7. Dove salvare

Oggi il renderer VFX (`scripts/vfx.gd`) usa ancora uno sprite placeholder
generico colorato dalla palette — **non esiste ancora una cartella asset
definita per i file `vfx_*`**. Quando disegni gli sprite veri, segui la
convenzione gia' in uso altrove (`assets/placeholder/<nome>.png`) e verifica
lo stato di `scripts/vfx.gd` prima di aspettarti che vengano caricati
automaticamente: potrebbe servire un piccolo aggancio di codice, da discutere
come story a parte (non e' un'operazione "solo dati").

## 8. Prima di considerarlo fatto

Vedi `05_checklist_finale.md`. In piu': ogni effetto deve restare leggibile
anche con `riduci_flash`/`riduci_distorsione` attivi.
