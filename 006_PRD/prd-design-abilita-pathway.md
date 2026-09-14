# PRD: Design del gioco — Abilità e Pathway

## 1. Introduzione/Overview

Secondo dei cinque documenti "bibbia di design" (il primo:
`006_PRD/prd-design-oggetti-economia.md`). Descrive **quello che esiste
già**: i 10 Pathway attivi, le loro 100 Sequenze, le 218 abilità che le
compongono, tratti direttamente da `data/pathways/*.json` +
`data/abilities/*.json` + `data/pathways_non_standard/eternal_aeon.json` +
`data/i18n/it.json`. Nessun nome, numero o parametro è inventato.

Un Pathway è un percorso di potere: 10 Sequenze (9 = debole, 0 = apice),
ognuna con un nome proprio, un concept, modificatori di statistiche, 1-2
abilità, un set di "azioni di recitazione" che fanno avanzare
`Progression` da sola (senza bere nulla), e — per i Pathway standard —
una pozione con ingredienti fissi per completare l'avanzamento. La
Sequenza 0 aggiunge un rituale di avanzamento (luogo, fase lunare,
sacrificio).

## 2. Come funziona il sistema (meccanica, non contenuto)

- **Le abilità sono composte da primitive**: mai codice dedicato a
  un'abilità specifica. `AbilityEngine.execute` dispatcha su `tipo` e
  chiama l'handler `_p_<primitiva>` giusto — lo stesso dispatcher intatto
  da 7 fasi di contenuto (fase 2 → fase 9).
- **La recitazione** (`acting_actions`) conta eventi tracciati (12 voci
  chiuse in `data/schema/tracked_events.json`) verso una soglia; superarla
  dà progresso frazionario verso l'avanzamento di Sequenza, a fianco della
  pozione — chi recita bene beve una pozione "già mezza pronta".
- **La pozione** (`potion`) chiede 3 ingredienti fissi per Sequenza: berla
  con tutti e 3 presenti avanza pulito; con ingredienti mancanti, la
  Sequenza avanza comunque ma con una penalità dichiarata nei dati (più
  follia, qualità ridotta) — mai un fallimento silenzioso.
- **Il rituale di Sequenza 0** chiede un luogo (`location_tags`), a volte
  una fase lunare precisa, e un sacrificio — l'ultimo passo per diventare
  l'apice del proprio Pathway.
- **Eternal Aeon** (sezione 4) sostituisce pozione+rituale con un **Boon**:
  un dono una tantum per Sequenza, concesso quando 1-3 requisiti (quest
  completata / comportamento contato / sacrificio pagato) sono
  soddisfatti insieme.

## 3. Il registro delle primitive

**Chiuso**: 27 primitive con `implemented: true` (usabili da qualunque
abilità) + 4 dichiarate ma senza handler ancora scritto
(`chain`/`probability_shift`/`weather_control`/`rule_bind` — nessuna
Sequenza attiva le richiede oggi). Aggiungerne una nuova è una decisione
di codice, va discussa esplicitamente: se un'abilità sembra richiederne
una nuova, quasi sempre una primitiva esistente è sottoparametrizzata.

| Primitiva | Parametri | Stato |
|---|---|---|
| `projectile` | danno, velocita, gittata, pierce, tag_danno | attiva |
| `melee_arc` | danno, angolo, raggio, stagger, tag_danno | attiva |
| `aura` | raggio, durata, effetto, tick_rate, bersagli | attiva |
| `dot` | danno_tick, tick_rate, durata, tag_danno | attiva |
| `heal` | quantita, istantaneo, durata, bersaglio | attiva |
| `buff_stat` | stat, valore, durata, moltiplicativo | attiva |
| `debuff_stat` | stat, valore, durata, moltiplicativo | attiva |
| `dash` | distanza, durata, invulnerabile, attraversa_nemici | attiva |
| `summon` | entita_id, quantita, durata, comportamento | attiva |
| `illusion` | raggio, durata, potenza, tipo_illusione | attiva |
| `mind_read` | raggio, profondita, rivela, categoria | attiva |
| `teleport` | distanza, richiede_visuale, porta_alleati | attiva |
| `shield` | assorbimento, durata, riflette, tag_bloccati, bersaglio | attiva |
| `transform` | forma_id, durata, costo_al_secondo | attiva |
| `terrain_modify` | tipo_modifica, raggio, durata, permanente | attiva |
| `possess` | durata, soglia_resistenza, controllo, vulnerabilita_corpo | attiva |
| `curse` | effetto, durata, condizione_rimozione | attiva |
| `reveal_info` | raggio, categoria, durata | attiva |
| `time_rewind` | secondi, ripristina, costo_follia | attiva |
| `soul_detach` | durata, vulnerabilita_corpo, velocita | attiva |
| `plant_growth` | raggio, specie, velocita, persistente | attiva |
| `light_purify` | raggio, potenza, riduce_sequenza | attiva |
| `shadow_meld` | durata, velocita, richiede_ombra | attiva |
| `steal` | categoria, durata_prestito, probabilita, ability_id, non_sottrae | attiva |
| `resurrect` | bersaglio, hp_ripristinati, costo_follia, cooldown | attiva |
| `decay` | danno, raggio, colpisce_oggetti, durata | attiva |
| `fear` | raggio, durata, soglia_resistenza | attiva |
| `chain` | danno, rimbalzi, decadimento, tag_danno | **differita, nessun handler** |
| `probability_shift` | evento, delta, durata, accumula | **differita, nessun handler** |
| `weather_control` | tipo_meteo, intensita, raggio, durata | **differita, nessun handler** |
| `rule_bind` | regola, penalita, durata, raggio | **differita, nessun handler** |

## 4. I 10 Pathway attivi, Sequenza per Sequenza

## Gruppo Eternal Darkness

### Darkness (`darkness`)

*Dominare la notte, le anime e il sonno; infliggere sfortuna*

- god_title: Darkness · tag: notte, anima, sonno, occultamento



**Sequenza 9 — Sleepless** (tier `low`)

> Veglia perpetua: visione notturna, immunita' al sonno, forza al buio.

- Modificatori: hp_max +40, spiritualita_max +0.1

  - **Forza del Buio** (`darkness_forza_del_buio`) — costo 20 spiritualità, cooldown 12.0s. `buff_stat`(stat=forza, valore=1.0, durata=12.0, moltiplicativo=True); `buff_stat`(stat=evasione, valore=0.8, durata=12.0, moltiplicativo=True)

    *Sleepless: al buio le statistiche del Darkness raddoppiano. La condizione e_notte ora vale (US-605): di giorno l'abilita' e' rifiutata senza pagare il costo.*

    tag sinergia: notte, forza, ombra

  - **Veglia Perpetua** (`darkness_veglia_perpetua`) — costo 15 spiritualità, cooldown 20.0s. `buff_stat`(stat=difesa, valore=0.12, durata=25.0, moltiplicativo=False); `light_purify`(raggio=0, potenza=1, riduce_sequenza=False)

    *Immunita' al sonno: light_purify toglie lo status imposto. Nessuna condizione: la veglia e' sempre.*

    tag sinergia: notte, sonno, negazione

- Recitazione (3 azioni):

  - Invoca la Forza del Buio 10 volte → +0.4 (evento `ability_used`, target 10)

  - Resta sveglio nella notte per 600 secondi → +0.35 (evento `time_in_state`, target 600)

  - Rinnova la Veglia Perpetua 12 volte → +0.25 (evento `ability_used`, target 12)

- Pozione: ingredienti velo_di_mezzanotte, occhio_che_non_dorme, cenere_di_stella_morta



**Sequenza 8 — Midnight Poet** (tier `low`)

> Parole che deprimono desideri e umore nemico, riducendo aggressivita'.

- Modificatori: hp_max +50, forza +0.05

  - **Verso Cupo** (`darkness_verso_cupo`) — costo 25 spiritualità, cooldown 15.0s. `debuff_stat`(stat=forza, valore=-0.3, durata=15.0, moltiplicativo=True); `debuff_stat`(stat=velocita, valore=-0.2, durata=15.0, moltiplicativo=True)

    *Midnight Poet: parole che deprimono desiderio e umore, riducendo l'aggressivita' del bersaglio.*

    tag sinergia: notte, emozione, singolo

  - **Poesia Amara** (`darkness_poesia_amara`) — costo 22 spiritualità, cooldown 14.0s. `debuff_stat`(stat=evasione, valore=-0.25, durata=12.0, moltiplicativo=True); `dot`(danno_tick=3, tick_rate=2.0, durata=12.0, tag_danno=follia)

    *La malinconia che logora: debuff di evasione + dot a tag follia.*

    tag sinergia: notte, emozione, follia

- Recitazione (3 azioni):

  - Recita il Verso Cupo a 12 bersagli → +0.4 (evento `ability_used`, target 12)

  - Recita la Poesia Amara 12 volte → +0.35 (evento `ability_used`, target 12)

  - Infliggi 1500 danni da follia → +0.25 (evento `damage_dealt`, target 1500)

- Pozione: ingredienti inchiostro_di_seppia_abissale, corda_di_impiccato, lacrima_di_vedova



**Sequenza 7 — Nightmare** (tier `low`)

> Entra negli incubi e infligge paura che disorienta i controlli nemici.

- Modificatori: hp_max +60, spiritualita_max +0.1

  - **Incubo** (`darkness_incubo`) — costo 30 spiritualità, cooldown 18.0s. `fear`(raggio=0, durata=8.0, soglia_resistenza=0.3); `debuff_stat`(stat=precisione, valore=-0.4, durata=8.0, moltiplicativo=True)

    *Nightmare: entra nell'incubo del bersaglio e vi infligge paura che disorienta la mira. Solo di notte (US-605).*

    tag sinergia: sonno, follia, mente

  - **Terrore Notturno** (`darkness_terrore_notturno`) — costo 35 spiritualità, cooldown 25.0s. `fear`(raggio=110, durata=6.0, soglia_resistenza=0.2); `dot`(danno_tick=4, tick_rate=2.0, durata=8.0, tag_danno=follia)

    *Paura d'area che rompe le formazioni + logorio a tag follia.*

    tag sinergia: sonno, follia, area

- Recitazione (3 azioni):

  - Entra in 15 incubi → +0.4 (evento `ability_used`, target 15)

  - Scatena il Terrore Notturno 12 volte → +0.35 (evento `ability_used`, target 12)

  - Infliggi 1800 danni da follia → +0.25 (evento `damage_dealt`, target 1800)

- Pozione: ingredienti polvere_di_incubo, piuma_di_civetta_nera, radice_di_mandragora_urlante



**Sequenza 6 — Soul Assurer** (tier `mid`)

> Pacifica anime inquiete e cura il danno spirituale degli alleati.

- Modificatori: hp_max +90, spiritualita_max +0.15

  - **Quiete dell'Anima** (`darkness_quiete_dell_anima`) — costo 28 spiritualità, cooldown 16.0s. `heal`(quantita=40, istantaneo=False, durata=8.0, bersaglio=self); `light_purify`(raggio=6, potenza=2, riduce_sequenza=False)

    *Soul Assurer: pacifica anime inquiete (light_purify) e cura il danno spirituale (heal nel tempo).*

    tag sinergia: anima, guarigione, spirito

  - **Requiem** (`darkness_requiem`) — costo 24 spiritualità, cooldown 14.0s. `buff_stat`(stat=difesa, valore=0.15, durata=20.0, moltiplicativo=False); `heal`(quantita=25, istantaneo=True, durata=0.0, bersaglio=self)

    *Un canto che rassicura: buff di difesa + cura istantanea.*

    tag sinergia: anima, difesa, guarigione

- Recitazione (3 azioni):

  - Pacifica 14 anime inquiete → +0.4 (evento `ability_used`, target 14)

  - Intona 14 requiem → +0.35 (evento `ability_used`, target 14)

  - Assorbi 600 danni per gli alleati → +0.25 (evento `damage_absorbed_for_ally`, target 600)

- Pozione: ingredienti balsamo_di_silenzio, corona_di_papavero_nero, acqua_di_fonte_cieca



**Sequenza 5 — Spirit Warlock** (tier `mid`)

> Ospita spiriti maligni nel corpo e li scaglia come proiettili viventi.

- Modificatori: hp_max +120, forza +0.1

  - **Ospite Maligno** (`darkness_ospite_maligno`) — costo 40 spiritualità, cooldown 30.0s. `summon`(entita_id=spirito_maligno, quantita=1, durata=40.0, comportamento=aggressivo); `buff_stat`(stat=forza, valore=0.2, durata=40.0, moltiplicativo=True)

    *Spirit Warlock: ospita uno spirito maligno nel corpo (materia prima 'spirito', ownership.json). Il consumo/scambio combat e' fase 6.*

    tag sinergia: spirito, evocazione, ombra

  - **Scaglia Spirito** (`darkness_scaglia_spirito`) — costo 32 spiritualità, cooldown 8.0s. `projectile`(danno=45, velocita=260, gittata=180, pierce=1, tag_danno=spirito)

    *Scaglia lo spirito ospitato come proiettile vivente.*

    tag sinergia: spirito, singolo, ombra

- Recitazione (3 azioni):

  - Ospita 10 spiriti maligni → +0.4 (evento `ability_used`, target 10)

  - Scaglia 20 spiriti → +0.35 (evento `ability_used`, target 20)

  - Infliggi 2500 danni da spirito → +0.25 (evento `damage_dealt`, target 2500)

- Pozione: ingredienti reliquia_profanata, zolfo_delle_fosse, filo_di_lutto



**Sequenza 4 — Nightwatcher** (tier `saint`)

> Dominio della notte: statistiche raddoppiate al buio, oscurita' creabile.

- Modificatori: hp_max +170, spiritualita_max +0.2, evasione +0.05

  - **Manto d'Ombra** (`darkness_manto_d_ombra`) — costo 30 spiritualità, cooldown 22.0s. `shadow_meld`(durata=8.0, velocita=1.4, richiede_ombra=True)

    *Nightwatcher: il caster si fonde con l'ombra (status 'occultato'). richiede_ombra e' registrato; il gate 'solo in ombra' e' fase 6.*

    tag sinergia: occultamento, ombra, silenzioso

  - **Notte Artificiale** (`darkness_notte_artificiale`) — costo 45 spiritualità, cooldown 35.0s. `terrain_modify`(tipo_modifica=oscurita, raggio=140, durata=12.0, permanente=False); `debuff_stat`(stat=precisione, valore=-0.35, durata=12.0, moltiplicativo=True)

    *Crea oscurita' locale: TimeSystem.e_notte(posizione) la legge come notte anche di giorno (gancio US-607). I nemici, al buio, vedono peggio (debuff precisione).*

    tag sinergia: ombra, notte, area

- Recitazione (3 azioni):

  - Fonditi con l'ombra 15 volte → +0.4 (evento `ability_used`, target 15)

  - Crea la Notte Artificiale 10 volte → +0.35 (evento `ability_used`, target 10)

  - Veglia nella notte per 900 secondi → +0.25 (evento `time_in_state`, target 900)

- Pozione: ingredienti ala_di_falena_crepuscolare, ombra_imbottigliata, chiodo_di_bara

- Rituale di avanzamento: luogo `['cripta', 'luogo_in_decadenza']`, fase lunare `None`, sacrifici ['il_proprio_nome_sussurrato_a_un_morto']



**Sequenza 3 — Horror Bishop** (tier `saint`)

> Aura di terrore che rompe le formazioni nemiche e controlla il buio.

- Modificatori: hp_max +240, spiritualita_max +0.25, forza +0.1

  - **Aura di Terrore** (`darkness_aura_di_terrore`) — costo 50 spiritualità, cooldown 28.0s. `fear`(raggio=180, durata=8.0, soglia_resistenza=0.15); `aura`(raggio=180, durata=15.0, effetto=paura, tick_rate=2.0, bersagli=nemici)

    *Horror Bishop: un'aura di terrore che rompe le formazioni nemiche - fear istantaneo + aura di 'paura' persistente.*

    tag sinergia: sonno, follia, area

  - **Predica Nera** (`darkness_predica_nera`) — costo 44 spiritualità, cooldown 22.0s. `debuff_stat`(stat=forza, valore=-0.4, durata=12.0, moltiplicativo=True); `curse`(effetto=sfortuna, durata=12.0, condizione_rimozione=purificazione); `dot`(danno_tick=4, tick_rate=2.0, durata=12.0, tag_danno=follia)

    *Sermone che spezza il coraggio: debuff forza + maledizione di sfortuna + logorio.*

    tag sinergia: maledizione, follia, area

- Recitazione (3 azioni):

  - Scatena l'Aura di Terrore 14 volte → +0.4 (evento `ability_used`, target 14)

  - Pronuncia 14 Prediche Nere → +0.35 (evento `ability_used`, target 14)

  - Infliggi 3500 danni da follia → +0.25 (evento `damage_dealt`, target 3500)

- Pozione: ingredienti mitra_di_vescovo_apostata, incenso_di_cenere, campana_incrinata

- Rituale di avanzamento: luogo `['tempio_abbandonato', 'luogo_in_decadenza']`, fase lunare `None`, sacrifici ['la_voce_di_un_coro']



**Sequenza 2 — Servant of Concealment** (tier `angel`)

> Cancella cose e persone dalla percezione altrui, anche in pieno giorno.

- Modificatori: hp_max +340, spiritualita_max +0.3, evasione +0.1

  - **Cancellazione** (`darkness_cancellazione`) — costo 45 spiritualità, cooldown 60.0s. `illusion`(raggio=8, durata=20.0, potenza=5, tipo_illusione=cancellazione_percettiva); `debuff_stat`(stat=percezione, valore=-0.9, durata=20.0, moltiplicativo=True)

    *STRESS TEST. Cancella cose e persone dalla percezione altrui. Risolto parametrizzando illusion con tipo_illusione, senza primitiva nuova.*

    tag sinergia: notte, occultamento, illusione, area

  - **Svanire** (`darkness_svanire`) — costo 42 spiritualità, cooldown 26.0s. `illusion`(raggio=10, durata=20.0, potenza=4, tipo_illusione=cancellazione_percettiva); `shadow_meld`(durata=12.0, velocita=1.2, richiede_ombra=False)

    *Servant of Concealment: cancella se stesso dalla percezione altrui (illusion) e si fonde con l'ombra (shadow_meld) - anche in pieno giorno.*

    tag sinergia: occultamento, illusione, ombra

- Recitazione (3 azioni):

  - Cancella 12 presenze dalla percezione → +0.4 (evento `ability_used`, target 12)

  - Svanisci 12 volte → +0.35 (evento `ability_used`, target 12)

  - Resta occultato nella notte per 1200 secondi → +0.25 (evento `time_in_state`, target 1200)

- Pozione: ingredienti specchio_annerito, polvere_di_confine, filo_dell_oblio

- Rituale di avanzamento: luogo `['cripta', 'sotterraneo']`, fase lunare `nuova`, sacrifici ['il_ricordo_del_proprio_volto']



**Sequenza 1 — Knight of Misfortune** (tier `angel`)

> Infligge sfortuna cronica: i nemici falliscono, inciampano, si feriscono da soli.

- Modificatori: hp_max +520, spiritualita_max +0.35, forza +0.2

  - **Sfortuna cronica** (`darkness_sfortuna_cronica`) — costo 40 spiritualità, cooldown 30.0s. `curse`(effetto=sfortuna, durata=20.0, condizione_rimozione=purificazione); `debuff_stat`(stat=evasione, valore=-0.35, durata=20.0, moltiplicativo=True); `debuff_stat`(stat=precisione, valore=-0.4, durata=20.0, moltiplicativo=True); `dot`(danno_tick=3, tick_rate=2.0, durata=20.0, tag_danno=follia)

    *US-228: 'Knight of Misfortune' SENZA probability_shift (differita). La sfortuna e' curse('sfortuna', rimossa da purificazione) + stack di debuff_stat su evasione e precisione + dot basso a tag follia: il bersaglio schiva meno, manca i colpi e si logora nel tempo. evasione e precisione sono stat forward-looking (nessun sistema di combattimento le legge ancora: arrivano con l'integrazione combat delle abilita'). Il concept originale puntava a probability_shift; la manipolazione VERA della probabilita' resta a Wheel of Fortune (gruppo key_of_light, differito). Se in fase 5 il feel non basta -> discussione esplicita per riattivare probability_shift col suo gruppo.*

    tag sinergia: maledizione, notte, follia, singolo

  - **Giogo della Malasorte** (`darkness_giogo_della_malasorte`) — costo 55 spiritualità, cooldown 40.0s. `curse`(effetto=sfortuna, durata=25.0, condizione_rimozione=purificazione); `debuff_stat`(stat=evasione, valore=-0.4, durata=25.0, moltiplicativo=True); `debuff_stat`(stat=precisione, valore=-0.4, durata=25.0, moltiplicativo=True); `dot`(danno_tick=5, tick_rate=2.0, durata=25.0, tag_danno=follia)

    *Knight of Misfortune, versione d'area: la sfortuna cronica di darkness_sfortuna_cronica (US-503, senza probability_shift) estesa a piu' bersagli.*

    tag sinergia: maledizione, follia, area

- Recitazione (3 azioni):

  - Maledici 15 bersagli con la sfortuna cronica → +0.4 (evento `ability_used`, target 15)

  - Cala il Giogo della Malasorte 10 volte → +0.35 (evento `ability_used`, target 10)

  - Infliggi 4500 danni da follia → +0.25 (evento `damage_dealt`, target 4500)

- Pozione: ingredienti chiodo_arrugginito_di_forca, tredicesimo_grano_di_rosario, sale_versato

- Rituale di avanzamento: luogo `['tempio_abbandonato', 'rovina']`, fase lunare `None`, sacrifici ['ancora_del_giocatore']



**Sequenza 0 — Darkness** (tier `god`)

> La notte come dominio.

- Modificatori: hp_max +900, spiritualita_max +0.5, forza +0.3, difesa +0.2

  - **Dominio della Notte** (`darkness_dominio_della_notte`) — costo 80 spiritualità, cooldown 90.0s. `aura`(raggio=300, durata=-1, effetto=paura, tick_rate=3.0, bersagli=nemici); `terrain_modify`(tipo_modifica=oscurita, raggio=300, durata=60.0, permanente=False); `buff_stat`(stat=forza, valore=0.5, durata=-1, moltiplicativo=True)

    *Darkness (Sequenza 0): la notte come dominio. Aura di terrore permanente + oscurita' che rende notte tutto intorno + il caster raddoppia quasi la forza. Abilita' di dominio come i Seq 0 di fase 5.*

    tag sinergia: notte, ombra, dominio

  - **Anatema del Vuoto** (`darkness_anatema_del_vuoto`) — costo 40 spiritualità, cooldown 45.0s. `curse`(effetto=sfortuna, durata=20.0, condizione_rimozione=purificazione); `debuff_stat`(stat=difesa, valore=-0.3, durata=20.0, moltiplicativo=True)

    *US-714. Darkness pronuncia l'anatema del vuoto: non e' un rituale, e' la notte stessa che si rivolta contro il bersaglio. curse(sfortuna) + debuff, come le altre maledizioni del Pathway (nessuna primitiva nuova).*

    tag sinergia: notte, dominio, maledizione

- Recitazione (2 azioni):

  - Imponi il Dominio della Notte 20 volte → +0.5 (evento `ability_used`, target 20)

  - Regna sulla notte per 3000 secondi → +0.5 (evento `time_in_state`, target 3000)

- Pozione: ingredienti frammento_di_notte_primordiale, occhio_del_gufo_del_giudizio, ultimo_respiro_del_giorno

- Rituale di avanzamento: luogo `['soglia_del_crepuscolo']`, fase lunare `eclissi`, sacrifici ['il_detentore_precedente_della_sequenza_0']





### Death (`death`)

*Evocare i morti e attraversare il mondo spirituale*

- god_title: Death · tag: morte, spirito, decadimento, non_morto



**Sequenza 9 — Corpse Collector** (tier `low`)

> Resiste a freddo e decomposizione; vede dove sono morti di recente.

- Modificatori: hp_max +25, difesa +0.05

  - **Tocco gelido** (`death_tocco_gelido`) — costo 4 spiritualità, cooldown 3.0s. `melee_arc`(danno=12, angolo=70, raggio=1.8, stagger=15, tag_danno=decadimento)

    *Il primo attacco del Death: una carezza che fa marcire. Danno basso, insegna il tag decadimento.*

    tag sinergia: morte, decadimento, singolo

  - **Pelle di tomba** (`death_pelle_di_tomba`) — costo 4 spiritualità, cooldown 12.0s. `buff_stat`(stat=difesa, valore=0.2, durata=8.0, moltiplicativo=True)

    *Il corpo del Corpse Collector non teme freddo ne' decomposizione.*

    tag sinergia: morte, difesa, decadimento

- Recitazione (3 azioni):

  - Sconfiggi 8 nemici: ogni caduto e' un cadavere raccolto → +0.4 (evento `enemy_defeated`, target 8)

  - Infliggi 1500 danni da decadimento → +0.35 (evento `damage_dealt`, target 1500)

  - Subisci 800 danni senza morire: il corpo non teme la decomposizione → +0.25 (evento `damage_taken`, target 800)

- Pozione: ingredienti terra_di_cimitero, dente_di_teschio, muffa_sepolcrale



**Sequenza 8 — Gravedigger** (tier `low`)

> Rianima cadaveri semplici come alleati temporanei.

- Modificatori: hp_max +40, difesa +0.08

  - **Rianima servo** (`death_rianima_servo`) — costo 8 spiritualità, cooldown 18.0s. `summon`(entita_id=cadavere_servo, quantita=2, durata=25.0, comportamento=aggressivo)

    *Rianima cadaveri semplici come alleati temporanei. Materia prima: un morto (matrice di proprieta').*

    tag sinergia: morte, non_morto, evocazione

  - **Stretta della terra** (`death_stretta_della_terra`) — costo 6 spiritualità, cooldown 8.0s. `debuff_stat`(stat=velocita, valore=-0.35, durata=6.0, moltiplicativo=True); `dot`(danno_tick=4, tick_rate=1.5, durata=6.0, tag_danno=decadimento)

    *La terra della fossa afferra: il bersaglio rallenta e marcisce.*

    tag sinergia: morte, decadimento, singolo

- Recitazione (3 azioni):

  - Rianima 15 servi cadavere → +0.4 (evento `ability_used`, target 15)

  - Sconfiggi 12 nemici (la fossa comune si riempie) → +0.35 (evento `enemy_defeated`, target 12)

  - Infliggi 3000 danni da decadimento → +0.25 (evento `damage_dealt`, target 3000)

- Pozione: ingredienti mano_di_gloria, chiodo_di_bara, cera_di_veglia



**Sequenza 7 — Spirit Medium** (tier `low`)

> Parla con i morti per ottenere informazioni non altrimenti accessibili.

- Modificatori: hp_max +55, spiritualita_max +0.1

  - **Seduta spiritica** (`death_seduta_spiritica`) — costo 10 spiritualità, cooldown 25.0s. `reveal_info`(raggio=12, categoria=voce_dei_morti, durata=15.0)

    *Parla coi morti per informazioni non altrimenti accessibili. Divinazione fuori da Hermit: la categoria limita cosa si sente (matrice di proprieta').*

    tag sinergia: morte, spirito, divinazione

  - **Lamento funebre** (`death_lamento_funebre`) — costo 9 spiritualità, cooldown 20.0s. `fear`(raggio=5, durata=6.0, soglia_resistenza=3); `dot`(danno_tick=3, tick_rate=2.0, durata=6.0, tag_danno=spirito)

    *Un coro di spiriti in lutto: chi ha volonta' debole fugge, gli altri si logorano.*

    tag sinergia: morte, spirito, area

- Recitazione (3 azioni):

  - Tieni 12 sedute spiritiche → +0.4 (evento `ability_used`, target 12)

  - Intona 15 lamenti funebri → +0.35 (evento `ability_used`, target 15)

  - Infliggi 2000 danni da spirito → +0.25 (evento `damage_dealt`, target 2000)

- Pozione: ingredienti ectoplasma, moneta_del_traghettatore, soffio_di_spettro



**Sequenza 6 — Spirit Guide** (tier `mid`)

> Comanda spiriti e li scaglia; il primo vero potere offensivo del Pathway.

- Modificatori: hp_max +80, spiritualita_max +0.15

  - **Scaglia spirito** (`death_scaglia_spirito`) — costo 8 spiritualità, cooldown 4.0s. `projectile`(danno=22, velocita=9, gittata=10, pierce=1, tag_danno=spirito)

    *Il primo vero potere offensivo del Death: uno spirito scagliato come un dardo.*

    tag sinergia: morte, spirito, singolo

  - **Falange spettrale** (`death_falange_spettrale`) — costo 14 spiritualità, cooldown 22.0s. `summon`(entita_id=spirito_soldato, quantita=3, durata=30.0, comportamento=aggressivo); `buff_stat`(stat=difesa, valore=0.15, durata=30.0, moltiplicativo=True)

    *Tre spiriti-soldato in formazione: comandi, loro combattono.*

    tag sinergia: morte, spirito, evocazione, area

- Recitazione (3 azioni):

  - Scaglia 25 spiriti → +0.4 (evento `ability_used`, target 25)

  - Sconfiggi 18 nemici col tuo esercito spettrale → +0.35 (evento `enemy_defeated`, target 18)

  - Infliggi 4000 danni da spirito → +0.25 (evento `damage_dealt`, target 4000)

- Pozione: ingredienti essenza_spettrale, ferro_delle_lapidi, incenso_dei_riti



**Sequenza 5 — Gatekeeper** (tier `mid`)

> Apre passaggi verso il mondo spirituale, usabili per esplorare e fuggire.

- Modificatori: hp_max +110, velocita +0.1

  - **Passo tra i mondi** (`death_passo_tra_i_mondi`) — costo 12 spiritualità, cooldown 10.0s. `teleport`(distanza=200, richiede_visuale=False, porta_alleati=False)

    *Un passo nel mondo spirituale e uno fuori, altrove. Riposizionamento; la porta permanente per l'esplorazione e' fase 6.*

    tag sinergia: morte, spazio, viaggio

  - **Porta di fuga** (`death_porta_di_fuga`) — costo 16 spiritualità, cooldown 25.0s. `teleport`(distanza=160, richiede_visuale=True, porta_alleati=True); `buff_stat`(stat=evasione, valore=0.3, durata=4.0, moltiplicativo=False)

    *Una porta che porta via anche gli alleati vicini: si fugge insieme.*

    tag sinergia: morte, spazio, difesa

- Recitazione (3 azioni):

  - Apri 20 passaggi → +0.4 (evento `ability_used`, target 20)

  - Ripulisci 10 aree spostandoti tra i varchi → +0.35 (evento `area_cleared`, target 10)

  - Subisci 2500 danni senza morire, sfuggendo di continuo → +0.25 (evento `damage_taken`, target 2500)

- Pozione: ingredienti chiave_d_ossa, nebbia_del_limbo, pietra_di_soglia



**Sequenza 4 — Undying** (tier `saint`)

> Rigenerazione estrema: non muore facilmente, torna in piedi.

- Modificatori: hp_max +180, difesa +0.2

  - **Carne ostinata** (`death_carne_ostinata`) — costo 14 spiritualità, cooldown 18.0s. `heal`(quantita=8, istantaneo=False, durata=10.0, bersaglio=self); `buff_stat`(stat=difesa, valore=0.3, durata=10.0, moltiplicativo=True)

    *Le ferite si chiudono da sole: l'Undying non muore facilmente.*

    tag sinergia: morte, guarigione, difesa

  - **Rialzati** (`death_rialzati`) — costo 20 spiritualità, cooldown 40.0s. `heal`(quantita=50, istantaneo=True, bersaglio=self); `buff_stat`(stat=hp_max, valore=0.15, durata=12.0, moltiplicativo=True)

    *Torni in piedi quando dovresti essere a terra.*

    tag sinergia: morte, guarigione, singolo

- Recitazione (3 azioni):

  - Rigenera 18 volte → +0.4 (evento `ability_used`, target 18)

  - Subisci 6000 danni senza morire → +0.35 (evento `damage_taken`, target 6000)

  - Rialzati 10 volte dopo essere caduto → +0.25 (evento `ability_used`, target 10)

- Pozione: ingredienti cuore_che_non_si_ferma, radice_di_immortelle, sale_della_veglia_eterna

- Rituale di avanzamento: luogo `['cripta', 'luogo_di_massacro']`, fase lunare `None`, sacrifici ['dieci_anni_della_propria_eta']



**Sequenza 3 — Ferryman** (tier `saint`)

> Uccide separando anima e corpo; traghetta anime come risorsa.

- Modificatori: hp_max +240, spiritualita_max +0.3

  - **Recisione** (`death_recisione`) — costo 22 spiritualità, cooldown 14.0s. `soul_detach`(durata=8.0, vulnerabilita_corpo=0.6, velocita=1.4); `dot`(danno_tick=10, tick_rate=1.0, durata=8.0, tag_danno=spirito)

    *Il Ferryman recide: anima e corpo si staccano, il corpo abbandonato quasi non combatte.*

    tag sinergia: morte, anima, spirito, singolo

  - **Traghetto** (`death_traghetto`) — costo 16 spiritualità, cooldown 12.0s. `heal`(quantita=30, istantaneo=True, bersaglio=self); `buff_stat`(stat=spiritualita_max, valore=0.2, durata=15.0, moltiplicativo=True)

    *Traghettare un'anima e' una risorsa: ogni passaggio restituisce forza.*

    tag sinergia: morte, anima, guarigione

- Recitazione (3 azioni):

  - Recidi 15 anime → +0.4 (evento `ability_used`, target 15)

  - Sconfiggi 20 nemici → +0.35 (evento `enemy_defeated`, target 20)

  - Infliggi 8000 danni da spirito → +0.25 (evento `damage_dealt`, target 8000)

- Pozione: ingredienti obolo_di_bronzo, acqua_dello_stige, filo_delle_parche

- Rituale di avanzamento: luogo `['tempio_abbandonato', 'cripta']`, fase lunare `None`, sacrifici ['il_nome_di_un_morto_che_amavi']



**Sequenza 2 — Death Consul** (tier `angel`)

> Eserciti di non-morti persistenti anche fuori dal combattimento.

- Modificatori: hp_max +350, difesa +0.35

  - **Legione** (`death_legione`) — costo 50 spiritualità, cooldown 90.0s. `summon`(entita_id=non_morto_legionario, quantita=8, durata=-1, comportamento=aggressivo); `aura`(raggio=10, durata=-1, effetto=comando_non_morti, tick_rate=2.0, bersagli=evocati)

    *STRESS TEST. durata -1: evocazioni persistenti fuori dal combattimento. Il motore deve gestire entita' che sopravvivono al cambio di scena.*

    tag sinergia: morte, non_morto, evocazione, area

  - **Editto di morte** (`death_editto_di_morte`) — costo 30 spiritualità, cooldown 40.0s. `debuff_stat`(stat=difesa, valore=-0.4, durata=12.0, moltiplicativo=True); `aura`(raggio=8, durata=-1, effetto=decadimento, tick_rate=2.0, bersagli=nemici)

    *Un editto che non si revoca: chi entra nel raggio decade finche' il Console vive.*

    tag sinergia: morte, decadimento, dominio, area

- Recitazione (3 azioni):

  - Schiera la legione 10 volte → +0.4 (evento `ability_used`, target 10)

  - Sconfiggi 25 nemici col tuo esercito persistente → +0.35 (evento `enemy_defeated`, target 25)

  - Infliggi 10000 danni da decadimento → +0.25 (evento `damage_dealt`, target 10000)

- Pozione: ingredienti corona_di_ossa, stendardo_lacero, polvere_di_ossario

- Rituale di avanzamento: luogo `['luogo_di_massacro', 'cripta']`, fase lunare `eclissi`, sacrifici ['un_alleato_evocato_a_cui_ti_eri_affezionato']



**Sequenza 1 — Pale Emperor** (tier `angel`)

> Uccisione istantanea sotto soglia e resurrezione degli alleati.

- Modificatori: hp_max +500, difesa +0.4, spiritualita_max +0.4

  - **Sentenza** (`death_sentenza`) — costo 35 spiritualità, cooldown 25.0s. `dot`(danno_tick=35, tick_rate=0.5, durata=6.0, tag_danno=spirito); `debuff_stat`(stat=difesa, valore=-0.6, durata=6.0, moltiplicativo=True)

    *Sotto una certa soglia di vita la sentenza e' immediata: qui e' resa come un dot brutale (l'uccisione istantanea vera arriva col combat, fase 6).*

    tag sinergia: morte, spirito, singolo

  - **Resurrezione imperiale** (`death_imperatore_resurrezione`) — costo 28 spiritualità, cooldown 30.0s. `resurrect`(bersaglio=evocazione, hp_ripristinati=80, costo_follia=5.0, cooldown=30.0)

    *Il Pale Emperor rialza gli alleati caduti. Il prezzo e' follia.*

    tag sinergia: morte, non_morto, guarigione

  - **Benedizione dei Caduti** (`death_benedizione_dei_caduti`) — costo 30 spiritualità, cooldown 35.0s. `aura`(raggio=10, durata=-1, effetto=comando_non_morti, tick_rate=2.0, bersagli=evocati)

    *US-714. Il Pale Emperor intercede per la sua legione: aura(comando_non_morti) su bersagli 'evocati', stesso effetto gia' usato da death_legione (US-714 lo riusa).*

    tag sinergia: morte, non_morto, evocazione

- Recitazione (3 azioni):

  - Pronuncia 15 sentenze → +0.4 (evento `ability_used`, target 15)

  - Sconfiggi 15 nemici sotto la soglia della sentenza → +0.35 (evento `enemy_defeated`, target 15)

  - Rialza 8 alleati caduti → +0.25 (evento `ability_used`, target 8)

- Pozione: ingredienti scettro_pallido, cenere_di_re, ultimo_battito

- Rituale di avanzamento: luogo `['cripta', 'tempio_abbandonato']`, fase lunare `None`, sacrifici ['ancora_del_giocatore']



**Sequenza 0 — Death** (tier `god`)

> Dominio sulla fine: la morte come autorita' sul mondo.

- Modificatori: hp_max +800, difesa +0.6, spiritualita_max +0.6

  - **Autorita finale** (`death_autorita_finale`) — costo 50 spiritualità, cooldown 60.0s. `aura`(raggio=15, durata=-1, effetto=autorita_decadimento, tick_rate=2.0, bersagli=nemici)

    *L'autorita' della fine su tutto cio' che le sta intorno.*

    tag sinergia: morte, dominio, decadimento, area

  - **Ultima parola** (`death_ultima_parola`) — costo 45 spiritualità, cooldown 45.0s. `fear`(raggio=12, durata=10.0, soglia_resistenza=9); `dot`(danno_tick=20, tick_rate=1.0, durata=10.0, tag_danno=spirito)

    *Tutti temono Death. Anche i forti.*

    tag sinergia: morte, spirito, area

- Recitazione (3 azioni):

  - Imponi l'autorita' finale 5 volte → +0.4 (evento `ability_used`, target 5)

  - Sconfiggi 30 nemici → +0.35 (evento `enemy_defeated`, target 30)

  - Pronuncia l'ultima parola 10 volte → +0.25 (evento `ability_used`, target 10)

- Pozione: ingredienti il_confine_del_mondo, respiro_finale, chiave_dell_oltretomba

- Rituale di avanzamento: luogo `['soglia_del_crepuscolo']`, fase lunare `eclissi`, sacrifici ['il_detentore_precedente_della_sequenza_0']





### Twilight Giant (`twilight_giant`)

*Combattere in prima linea con armi di luce e difesa assoluta*

- god_title: Twilight Giant · tag: arma, difesa, luce, decadimento



**Sequenza 9 — Warrior** (tier `low`)

> Maestria delle armi, forza e resistenza. Il combattente puro.

- Modificatori: hp_max +20, forza +0.1

  - **Fendente pesante** (`tg_fendente_pesante`) — costo 6 spiritualità, cooldown 3.0s. `melee_arc`(danno=18, angolo=90, raggio=2.2, stagger=25, tag_danno=fisico)

    *Colpo lento ad alto stagger. Insegna il ritmo anticipo/recupero fin dal primo minuto.*

    tag sinergia: arma, forza, singolo

  - **Stretta ferrea** (`tg_stretta_ferrea`) — costo 4 spiritualità, cooldown 8.0s. `buff_stat`(stat=difesa, valore=0.25, durata=5.0, moltiplicativo=True)

    tag sinergia: difesa, arma, forza

- Recitazione (3 azioni):

  - Sconfiggi 3 nemici senza usare abilita' Beyonder → +0.35 (evento `enemy_defeated`, target 3)

  - Infliggi 2000 danni fisici → +0.3 (evento `damage_dealt`, target 2000)

  - Para perfettamente 12 colpi → +0.35 (evento `perfect_parry`, target 12)

- Pozione: ingredienti ferro_temperato, sangue_di_toro, radice_di_quercia



**Sequenza 8 — Pugilist** (tier `low`)

> Combattimento a mani nude con contrattacco su parata perfetta.

- Modificatori: hp_max +35, forza +0.15, difesa +0.05

  - **Contrattacco** (`tg_contrattacco`) — costo 5 spiritualità, cooldown 6.0s. `melee_arc`(danno=26, angolo=60, raggio=1.6, stagger=45, tag_danno=fisico); `buff_stat`(stat=evasione, valore=0.2, durata=2.0, moltiplicativo=False)

    *Progettata per essere usata subito dopo una parata perfetta (US-010). Aggancio diretto al combat.*

    tag sinergia: arma, forza, difesa, singolo

  - **Carica di spalla** (`tg_carica_spalla`) — costo 7 spiritualità, cooldown 7.0s. `dash`(distanza=4.0, durata=0.25, invulnerabile=False, attraversa_nemici=False); `melee_arc`(danno=14, angolo=45, raggio=1.4, stagger=60, tag_danno=fisico)

    tag sinergia: forza, arma, agilita'

- Recitazione (3 azioni):

  - Sconfiggi 5 nemici a mani nude → +0.4 (evento `enemy_defeated`, target 5)

  - 10 parate perfette in un solo combattimento → +0.35 (evento `perfect_parry`, target 10)

  - Subisci 1500 danni senza morire → +0.25 (evento `damage_taken`, target 1500)

- Pozione: ingredienti osso_di_pugile, sale_di_roccia, estratto_di_muscolo



**Sequenza 7 — Weapon Master** (tier `low`)

> Padroneggia ogni arma; tecniche avanzate e combo estese.

- Modificatori: hp_max +50, forza +0.2, danno_arma +0.1

  - **Maestria nell'arma** (`tg_maestria_arma`) — costo 0 spiritualità, cooldown 0.0s. `buff_stat`(stat=danno_arma, valore=0.15, durata=-1, moltiplicativo=True)

    *Passiva permanente (durata -1). Il motore deve gestire i buff senza scadenza.*

    tag sinergia: arma, forza

  - **Turbine** (`tg_turbine`) — costo 14 spiritualità, cooldown 10.0s. `melee_arc`(danno=16, angolo=360, raggio=2.6, stagger=30, tag_danno=fisico); `buff_stat`(stat=difesa, valore=0.15, durata=1.5, moltiplicativo=True)

    tag sinergia: arma, area, forza

  - **Lancio preciso** (`tg_lancio_preciso`) — costo 8 spiritualità, cooldown 4.0s. `projectile`(danno=22, velocita=14, gittata=9, pierce=1, tag_danno=fisico)

    tag sinergia: arma, singolo

- Recitazione (3 azioni):

  - Sconfiggi 15 nemici alternando tipi di arma → +0.4 (evento `enemy_defeated`, target 15)

  - Infliggi 8000 danni fisici → +0.35 (evento `damage_dealt`, target 8000)

  - Completa 3 aree senza perdere alleati → +0.25 (evento `area_cleared`, target 3)

- Pozione: ingredienti acciaio_stellare, polvere_di_arena, tendine_di_lupo



**Sequenza 6 — Dawn Paladin** (tier `mid`)

> Crescita fisica e armatura di luce evocabile.

- Modificatori: hp_max +80, forza +0.3, difesa +0.15

  - **Armatura dell'alba** (`tg_armatura_alba`) — costo 18 spiritualità, cooldown 25.0s. `shield`(assorbimento=80, durata=12.0, riflette=0.0, tag_bloccati=['fisico', 'ombra']); `buff_stat`(stat=difesa, valore=0.2, durata=12.0, moltiplicativo=True)

    tag sinergia: luce, difesa, arma

  - **Crescita** (`tg_crescita`) — costo 20 spiritualità, cooldown 40.0s. `transform`(forma_id=tg_forma_gigante, durata=15.0, costo_al_secondo=1.5); `buff_stat`(stat=forza, valore=0.35, durata=15.0, moltiplicativo=True)

    tag sinergia: forza, luce, crescita

- Recitazione (3 azioni):

  - Resta trasformato per 10 minuti cumulativi → +0.4 (evento `time_in_state`, target 600)

  - Aiuta 8 NPC in pericolo → +0.35 (evento `npc_influenced`, target 8)

  - Infliggi 5000 danni di luce → +0.25 (evento `damage_dealt`, target 5000)

- Pozione: ingredienti frammento_di_alba, oro_bianco, linfa_di_gigante



**Sequenza 5 — Guardian** (tier `mid`)

> Assorbe il danno diretto agli alleati; stance difensiva quasi inviolabile.

- Modificatori: hp_max +130, forza +0.35, difesa +0.3

  - **Scudo del compagno** (`tg_scudo_del_compagno`) — costo 12 spiritualità, cooldown 15.0s. `shield`(assorbimento=120, durata=10.0, riflette=0.15, tag_bloccati=['fisico', 'luce', 'ombra'], bersaglio=alleato)

    *Prende il danno diretto agli alleati e al pet. Sinergia esplicita col sistema pet.*

    tag sinergia: difesa, luce, non_letale

  - **Postura inviolabile** (`tg_postura_inviolabile`) — costo 16 spiritualità, cooldown 30.0s. `buff_stat`(stat=difesa, valore=0.7, durata=6.0, moltiplicativo=True); `debuff_stat`(stat=velocita, valore=-0.5, durata=6.0, moltiplicativo=True); `aura`(raggio=3.0, durata=6.0, effetto=taunt, tick_rate=1.0, bersagli=nemici)

    *Trade-off esplicito: quasi invulnerabile ma quasi immobile. Il giocatore sceglie quando ancorarsi.*

    tag sinergia: difesa, arma, area

- Recitazione (3 azioni):

  - Assorbi 5000 danni diretti agli alleati o al pet → +0.5 (evento `damage_absorbed_for_ally`, target 5000)

  - Completa 8 aree senza perdere nessun alleato → +0.3 (evento `area_cleared`, target 8)

  - Subisci 12000 danni senza morire → +0.2 (evento `damage_taken`, target 12000)

- Pozione: ingredienti scudo_fuso, cuore_di_montagna, resina_di_ferro



**Sequenza 4 — Demon Hunter** (tier `saint`)

> Concoction di potenziamento e caccia agli spiriti maligni.

- Modificatori: hp_max +200, forza +0.45, difesa +0.35, velocita +0.1

  - **Distillato del potenziamento** (`tg_concoction_potenziamento`) — costo 10 spiritualità, cooldown 45.0s. `buff_stat`(stat=forza, valore=0.3, durata=20.0, moltiplicativo=True); `buff_stat`(stat=velocita, valore=0.2, durata=20.0, moltiplicativo=True); `heal`(quantita=40, istantaneo=True, durata=0, bersaglio=self)

    *Primo aggancio duro tra Pathway e crafting: la concoction usa ingredienti dall'inventario.*

    tag sinergia: pozione, forza, guarigione, crafting

  - **Caccia spirituale** (`tg_caccia_spirituale`) — costo 14 spiritualità, cooldown 8.0s. `melee_arc`(danno=45, angolo=90, raggio=2.4, stagger=40, tag_danno=luce); `light_purify`(raggio=2.4, potenza=2, riduce_sequenza=False)

    *Danno enormemente maggiore contro bersagli con tag 'spirito' o 'non_morto'.*

    tag sinergia: luce, purificazione, arma, spirito

- Recitazione (3 azioni):

  - Purifica 30 creature spirituali o non-morte → +0.4 (evento `enemy_defeated`, target 30)

  - Prepara 10 concoction di qualita' alta → +0.35 (evento `item_crafted`, target 10)

  - Sconfiggi 5 Beyonder di Sequenza 6 o superiore → +0.25 (evento `enemy_defeated`, target 5)

- Pozione: ingredienti cenere_di_spirito, argento_benedetto, fiele_di_demone

- Rituale di avanzamento: luogo `['altura', 'luogo_di_battaglia']`, fase lunare `None`, sacrifici ['arma_spezzata_di_un_nemico_ucciso']



**Sequenza 3 — Silver Knight** (tier `saint`)

> Arma di luce solida che purifica cio' che colpisce.

- Modificatori: hp_max +300, forza +0.6, difesa +0.45

  - **Lama argentea** (`tg_lama_argentea`) — costo 22 spiritualità, cooldown 20.0s. `transform`(forma_id=tg_arma_luce, durata=25.0, costo_al_secondo=1.0); `buff_stat`(stat=danno_arma, valore=0.5, durata=25.0, moltiplicativo=True)

    tag sinergia: luce, arma, purificazione

  - **Giudizio luminoso** (`tg_giudizio_luminoso`) — costo 30 spiritualità, cooldown 35.0s. `light_purify`(raggio=6.0, potenza=4, riduce_sequenza=False); `dot`(danno_tick=12, tick_rate=1.0, durata=6.0, tag_danno=luce)

    tag sinergia: luce, purificazione, area

- Recitazione (3 azioni):

  - Risparmia 10 nemici che si arrendono → +0.4 (evento `npc_influenced`, target 10)

  - Mantieni l'arma di luce attiva per 30 minuti cumulativi → +0.35 (evento `time_in_state`, target 1800)

  - Infliggi 20000 danni di luce a creature spirituali → +0.25 (evento `damage_dealt`, target 20000)

- Pozione: ingredienti lama_di_luce_solidificata, platino_rituale, lacrima_di_paladino

- Rituale di avanzamento: luogo `['tempio_abbandonato', 'altura']`, fase lunare `None`, sacrifici ['armatura_indossata_per_100_battaglie']



**Sequenza 2 — Glory** (tier `angel`)

> Luce del crepuscolo: infligge decadimento a materia e spirito.

- Modificatori: hp_max +450, forza +0.8, difesa +0.55

  - **Crepuscolo** (`tg_crepuscolo`) — costo 40 spiritualità, cooldown 60.0s. `decay`(danno=70, raggio=7.0, colpisce_oggetti=True, durata=10.0); `debuff_stat`(stat=difesa, valore=-0.4, durata=10.0, moltiplicativo=True)

    *L'abilita' firma del Pathway. colpisce_oggetti True: degrada le strutture, comprese quelle costruite dal giocatore. Deve poter danneggiare la propria base.*

    tag sinergia: decadimento, luce, area

  - **Aura del declino** (`tg_aura_declino`) — costo 25 spiritualità, cooldown 45.0s. `aura`(raggio=5.0, durata=15.0, effetto=decadimento, tick_rate=1.0, bersagli=nemici)

    tag sinergia: decadimento, area, luce

- Recitazione (3 azioni):

  - Lascia decadere volontariamente una struttura che avevi costruito → +0.5 (evento `structure_destroyed`, target 1)

  - Usa il Crepuscolo 25 volte → +0.25 (evento `ability_used`, target 25)

  - Infliggi 40000 danni da decadimento → +0.25 (evento `damage_dealt`, target 40000)

- Pozione: ingredienti polvere_di_crepuscolo, ossidiana_decaduta, ultimo_respiro

- Rituale di avanzamento: luogo `['rovina', 'luogo_in_decadenza']`, fase lunare `None`, sacrifici ['struttura_costruita_dal_giocatore']



**Sequenza 1 — Hand of God** (tier `angel`)

> Forza divina applicata: rompe strutture e barriere.

- Modificatori: hp_max +700, forza +1.1, difesa +0.7

  - **Mano divina** (`tg_mano_divina`) — costo 55 spiritualità, cooldown 90.0s. `melee_arc`(danno=220, angolo=120, raggio=6.0, stagger=999, tag_danno=luce); `terrain_modify`(tipo_modifica=frantuma, raggio=6.0, durata=0, permanente=True)

    *permanente True: altera davvero la mappa. Aggancio a esplorazione e gating.*

    tag sinergia: forza, luce, area, arma

  - **Spezza-barriera** (`tg_spezza_barriera`) — costo 45 spiritualità, cooldown 60.0s. `terrain_modify`(tipo_modifica=apre_varco, raggio=3.0, durata=0, permanente=True); `light_purify`(raggio=3.0, potenza=6, riduce_sequenza=True)

    *riduce_sequenza True: abbassa temporaneamente la Sequenza effettiva del bersaglio. Solo da Sequenza 1.*

    tag sinergia: luce, purificazione, forza

- Recitazione (3 azioni):

  - Sconfiggi 3 Beyonder di Sequenza 2 o superiore → +0.5 (evento `enemy_defeated`, target 3)

  - Apri 10 varchi in barriere considerate inviolabili → +0.25 (evento `ability_used`, target 10)

  - Completa il rituale di Sequenza 1 senza interruzioni → +0.25 (evento `ritual_completed`, target 1)

- Pozione: ingredienti scheggia_divina, metallo_impossibile, voce_del_gigante

- Rituale di avanzamento: luogo `['vetta', 'luogo_di_massacro']`, fase lunare `eclissi`, sacrifici ['ancora_del_giocatore']



**Sequenza 0 — Twilight Giant** (tier `god`)

> Il crepuscolo come autorita'.

- Modificatori: hp_max +1200, forza +1.6, difesa +1.0

  - **Autorità del crepuscolo** (`tg_autorita_crepuscolo`) — costo 0 spiritualità, cooldown 0.0s. `aura`(raggio=999, durata=-1, effetto=autorita_decadimento, tick_rate=5.0, bersagli=mondo)

    *Autorita' divina passiva e globale. Endgame: tutto cio' che il giocatore non protegge attivamente decade.*

    tag sinergia: decadimento, luce, dominio, area

  - **Giuramento del Crepuscolo** (`tg_giuramento_del_crepuscolo`) — costo 45 spiritualità, cooldown 50.0s. `aura`(raggio=12, durata=-1, effetto=autorita_decadimento, tick_rate=2.0, bersagli=nemici)

    *US-714. Il Twilight Giant impone la propria autorita' su chi entra nel raggio: non e' un colpo, e' un editto. aura(autorita_decadimento) su nemici, stesso effetto gia' usato da death_autorita_finale (US-714 lo riusa, non lo duplica).*

    tag sinergia: dominio, luce, area

- Recitazione (1 azioni):

  - Rivendica la Sequenza 0 sconfiggendo chi la occupa → +1.0 (evento `enemy_defeated`, target 1)

- Pozione: ingredienti caratteristica_del_gigante, nucleo_del_crepuscolo, tempo_solidificato

- Rituale di avanzamento: luogo `['soglia_del_crepuscolo']`, fase lunare `eclissi`, sacrifici ['il_detentore_precedente_della_sequenza_0']





## Gruppo Lord of Mysteries

### Door (`door`)

*Attraversare lo spazio e replicare i poteri osservati*

- god_title: Door · tag: spazio, viaggio, stella, occultamento



**Sequenza 9 — Apprentice** (tier `low`)

> Teletrasporti brevi a vista; apre serrature mistiche e passaggi bloccati.

- Modificatori: velocita +0.1, evasione +0.08

  - **Passo breve** (`door_passo_breve`) — costo 8 spiritualità, cooldown 3.0s. `teleport`(distanza=120, richiede_visuale=True, porta_alleati=False)

    *Il primo passo dell'Apprentice: un salto breve verso un punto a vista. teleport gia' implementata (US-506).*

    tag sinergia: spazio, viaggio, singolo

  - **Grimaldello mistico** (`door_grimaldello_mistico`) — costo 10 spiritualità, cooldown 6.0s. `terrain_modify`(tipo_modifica=serratura_aperta, raggio=2, durata=0, permanente=False); `reveal_info`(raggio=6, categoria=passaggi_bloccati, durata=8.0)

    *Apre serrature mistiche e mostra dove sono i passaggi bloccati. terrain_modify non permanente (la serratura resta aperta per la scena); reveal_info porta la categoria (matrice: Door divina lo SPAZIO).*

    tag sinergia: spazio, occultamento, analisi

- Recitazione (3 azioni):

  - Fai 25 passi brevi nello spazio → +0.4 (evento `ability_used`, target 25)

  - Apri 15 serrature mistiche → +0.35 (evento `ability_used`, target 15)

  - Ripulisci 8 aree passando dove gli altri non passano → +0.25 (evento `area_cleared`, target 8)

- Pozione: ingredienti chiave_senza_denti, polvere_di_gesso_stellare, cardine_arrugginito_di_una_porta_perduta



**Sequenza 8 — Trickmaster** (tier `low`)

> Incantesimi di fuga e scambio di posizione con un bersaglio.

- Modificatori: velocita +0.12, evasione +0.12

  - **Via di fuga** (`door_via_di_fuga`) — costo 12 spiritualità, cooldown 10.0s. `teleport`(distanza=160, richiede_visuale=False, porta_alleati=False); `buff_stat`(stat=evasione, valore=0.3, durata=4.0, moltiplicativo=False)

    *Un incantesimo di fuga: via da qui, e per un attimo difficile da colpire.*

    tag sinergia: spazio, viaggio, difesa

  - **Scambio di posto** (`door_scambio_di_posto`) — costo 16 spiritualità, cooldown 14.0s. `teleport`(distanza=200, richiede_visuale=True, porta_alleati=False); `debuff_stat`(stat=difesa, valore=-0.2, durata=5.0, moltiplicativo=True); `buff_stat`(stat=precisione, valore=0.15, durata=5.0, moltiplicativo=False)

    *Scambia posizione con un bersaglio: il Trickmaster finisce dov'era lui, in vantaggio. Lo swap VERO delle posizioni col bersaglio e' combat (fase 6); qui teleport + i modificatori che rendono il fatto.*

    tag sinergia: spazio, inganno, singolo

- Recitazione (3 azioni):

  - Fuggi 20 volte da uno scontro impossibile → +0.4 (evento `ability_used`, target 20)

  - Scambia posizione con un bersaglio 15 volte → +0.35 (evento `ability_used`, target 15)

  - Incassa 1500 danni restando sempre in movimento → +0.25 (evento `damage_taken`, target 1500)

- Pozione: ingredienti specchio_da_borsetta_a_due_facce, gessetto_che_disegna_porte, filo_teso_tra_due_stanze



**Sequenza 7 — Astrologer** (tier `low`)

> Divinazione stellare che rivela percorsi nascosti sulla mappa.

- Modificatori: spiritualita_max +0.1, precisione +0.08

  - **Lettura stellare** (`door_lettura_stellare`) — costo 12 spiritualità, cooldown 18.0s. `reveal_info`(raggio=20, categoria=percorso, durata=12.0)

    *L'Astrologer legge nelle stelle i percorsi nascosti. Matrice di proprieta': Door divina lo SPAZIO (i percorsi), non le menti (Hermit) ne' per ingannare (Fool).*

    tag sinergia: divinazione, stella, spazio

  - **Occhio nell'ombra** (`door_occhio_nell_ombra`) — costo 14 spiritualità, cooldown 16.0s. `shadow_meld`(durata=6.0, velocita=0.15, richiede_ombra=False); `reveal_info`(raggio=12, categoria=percorso, durata=8.0)

    *Osserva i percorsi restando occultato. shadow_meld (gia' implementata in fase 6, Nightwatcher del Darkness) applica lo status 'occultato'; anche il Secrets Sorcerer (Seq 4, US-5B09) la usera'.*

    tag sinergia: occultamento, divinazione, stella

- Recitazione (3 azioni):

  - Leggi 15 volte i percorsi nelle stelle → +0.4 (evento `ability_used`, target 15)

  - Osserva 12 volte dall'ombra senza essere visto → +0.35 (evento `ability_used`, target 12)

  - Mappa 8 aree seguendo i percorsi nascosti → +0.25 (evento `area_cleared`, target 8)

- Pozione: ingredienti carta_stellare_con_una_stella_in_piu, sabbia_di_meridiana_notturna, lente_puntata_sempre_a_nord



**Sequenza 6 — Scribe** (tier `mid`)

> Registra un'abilita' osservata e la riproduce una volta.

- Modificatori: spiritualita_max +0.15, precisione +0.1

  - **Registra abilita'** (`door_registra_abilita`) — costo 22 spiritualità, cooldown 28.0s. `steal`(categoria=abilita, ability_id=tg_stretta_ferrea, probabilita=1.0, durata_prestito=20.0, non_sottrae=True)

    *MATRICE DI PROPRIETA': lo Scribe FOTOCOPIA (non_sottrae:true, probabilita 1.0) - registra un'abilita' osservata e se la tiene, ma l'originale sul nemico NON e' sottratto. Distinto dallo steal dell'Error (sottrae, probabilita < 1). Un solo vocabolario 'steal' con un flag, nessuna primitiva nuova, nessun if per Door.*

    tag sinergia: spazio, conoscenza, singolo

  - **Riproduci la copia** (`door_riproduci_copia`) — costo 12 spiritualità, cooldown 5.0s. `projectile`(danno=22, velocita=9, gittata=10, pierce=1, tag_danno=fisico)

    *Scarica una riproduzione del potere registrato: la fotocopia funziona una volta.*

    tag sinergia: spazio, inganno, singolo

- Recitazione (3 azioni):

  - Registra 12 abilita' osservate → +0.4 (evento `ability_used`, target 12)

  - Riproduci 15 copie di poteri altrui → +0.35 (evento `ability_used`, target 15)

  - Sconfiggi 15 nemici con le loro stesse abilita' fotocopiate → +0.25 (evento `enemy_defeated`, target 15)

- Pozione: ingredienti inchiostro_che_copia_da_solo, carta_carbone_dell_anima, timbro_di_ogni_potere



**Sequenza 5 — Traveler** (tier `mid`)

> Viaggio nel mondo spirituale come scorciatoia tra zone lontane.

- Modificatori: velocita +0.15, spiritualita_max +0.12

  - **Scorciatoia** (`door_scorciatoia`) — costo 18 spiritualità, cooldown 14.0s. `teleport`(distanza=500, richiede_visuale=False, porta_alleati=True)

    *Il fast travel DEL DOOR (design-world cap. 7): scorciatoia istantanea tra zone lontane, mai permanenza. Nessun if: e' teleport con distanza grande e porta_alleati:true.*

    tag sinergia: spazio, viaggio, singolo

  - **Porta di gruppo** (`door_porta_di_gruppo`) — costo 24 spiritualità, cooldown 22.0s. `teleport`(distanza=400, richiede_visuale=False, porta_alleati=True); `buff_stat`(stat=velocita, valore=0.2, durata=6.0, moltiplicativo=True)

    *Porta un gruppo intero attraverso una porta di viaggio, e per un momento sono tutti piu' rapidi.*

    tag sinergia: spazio, viaggio, area

- Recitazione (3 azioni):

  - Prendi 20 scorciatoie tra zone lontane → +0.4 (evento `ability_used`, target 20)

  - Porta 12 gruppi attraverso una porta di viaggio → +0.35 (evento `ability_used`, target 12)

  - Ripulisci 8 aree arrivando da dove non se lo aspettano → +0.25 (evento `area_cleared`, target 8)

- Pozione: ingredienti biglietto_di_sola_andata_e_ritorno, sabbia_di_due_deserti_lontani, mappa_che_si_ripiega_su_se_stessa



**Sequenza 4 — Secrets Sorcerer** (tier `saint`)

> Occultamento totale: sfugge al rilevamento anche mistico.

- Modificatori: hp_max +130, evasione +0.15, spiritualita_max +0.15

  - **Occultamento totale** (`door_occultamento_totale`) — costo 24 spiritualità, cooldown 20.0s. `shadow_meld`(durata=15.0, velocita=0.2, richiede_ombra=False); `illusion`(raggio=3, durata=8.0, potenza=1, tipo_illusione=copia_statica)

    *Il Secrets Sorcerer sparisce anche dal rilevamento mistico: shadow_meld lungo (status 'occultato') + un'esca al suo posto.*

    tag sinergia: occultamento, illusione, spazio

  - **Segreto svanito** (`door_segreto_svanito`) — costo 18 spiritualità, cooldown 12.0s. `shadow_meld`(durata=8.0, velocita=0.15, richiede_ombra=False); `teleport`(distanza=200, richiede_visuale=False, porta_alleati=False)

    *Svanisce e riappare altrove, senza che nessuno sappia che c'era. shadow_meld + teleport, entrambe gia' implementate.*

    tag sinergia: occultamento, spazio, viaggio

- Recitazione (3 azioni):

  - Occultati completamente 12 volte → +0.4 (evento `ability_used`, target 12)

  - Passa 500 secondi occultato, fuori da ogni rilevamento → +0.35 (evento `time_in_state`, target 500)

  - Abbatti 12 nemici che non ti hanno mai visto → +0.25 (evento `enemy_defeated`, target 12)

- Pozione: ingredienti segreto_sigillato_in_cera_nera, ombra_ritagliata_con_le_forbici, chiave_che_chiude_e_non_apre

- Rituale di avanzamento: luogo `['soglia', 'crocevia']`, fase lunare `None`, sacrifici ['un_segreto_che_ti_definiva']



**Sequenza 3 — Wanderer** (tier `saint`)

> Teletrasporto a lunga distanza portando con se' alleati e pet.

- Modificatori: hp_max +150, velocita +0.15, spiritualita_max +0.2

  - **Viaggio lungo** (`door_viaggio_lungo`) — costo 35 spiritualità, cooldown 40.0s. `teleport`(distanza=999, richiede_visuale=False, porta_alleati=True); `reveal_info`(raggio=15, categoria=percorsi, durata=8.0)

    *STRESS TEST. Teletrasporto a lunga distanza con alleati e pet. Nessuna primitiva nuova.*

    tag sinergia: spazio, viaggio, occultamento

  - **Passo del pellegrino** (`door_passo_del_pellegrino`) — costo 26 spiritualità, cooldown 24.0s. `teleport`(distanza=600, richiede_visuale=False, porta_alleati=True); `buff_stat`(stat=difesa, valore=0.15, durata=6.0, moltiplicativo=False)

    *Il Wanderer porta un gruppo su una strada lunga, e all'arrivo sono ancora saldi.*

    tag sinergia: spazio, viaggio, difesa

- Recitazione (3 azioni):

  - Compi 12 viaggi lunghi con alleati e pet → +0.4 (evento `ability_used`, target 12)

  - Guida 12 pellegrinaggi attraverso lo spazio → +0.35 (evento `ability_used`, target 12)

  - Attraversa 10 aree ostili senza mai fermarti → +0.25 (evento `area_cleared`, target 10)

- Pozione: ingredienti suola_consumata_da_mille_strade, acqua_di_un_pozzo_che_non_trovi_piu, bussola_che_punta_a_dove_vuoi_tu

- Rituale di avanzamento: luogo `['nebbia_grigia', 'crocevia']`, fase lunare `None`, sacrifici ['il_posto_che_chiamavi_casa']



**Sequenza 2 — Planeswalker** (tier `angel`)

> Apre porte stabili tra piani; replica abilita' che conosce senza registrarle.

- Modificatori: hp_max +260, spiritualita_max +0.3, velocita +0.15

  - **Camminatore di piani** (`door_camminatore_di_piani`) — costo 34 spiritualità, cooldown 30.0s. `teleport`(distanza=1500, richiede_visuale=False, porta_alleati=True)

    *Il Planeswalker apre una porta stabile tra piani: distanza enorme, con alleati e pet. Sempre teleport, mai una primitiva nuova.*

    tag sinergia: spazio, viaggio, singolo

  - **Replica nota** (`door_replica_nota`) — costo 24 spiritualità, cooldown 26.0s. `steal`(categoria=abilita, ability_id=tg_turbine, probabilita=1.0, durata_prestito=25.0, non_sottrae=True)

    *Il Planeswalker replica un'abilita' che GIA' conosce, senza il passaggio di registrazione dello Scribe: steal { non_sottrae:true } senza bisogno di 'osservare' prima. Nessuna primitiva nuova.*

    tag sinergia: spazio, conoscenza, singolo

- Recitazione (3 azioni):

  - Cammina tra 12 piani lontani → +0.4 (evento `ability_used`, target 12)

  - Replica 12 abilita' che gia' conosci, senza registrarle → +0.35 (evento `ability_used`, target 12)

  - Sconfiggi 20 nemici essendo ovunque e da nessuna parte → +0.25 (evento `enemy_defeated`, target 20)

- Pozione: ingredienti frammento_di_una_porta_tra_i_mondi, eco_di_un_potere_visto_una_volta_sola, polvere_di_un_piano_gia_chiuso

- Rituale di avanzamento: luogo `['crocevia', 'nebbia_grigia']`, fase lunare `nuova`, sacrifici ['la_possibilita_di_restare_fermo']



**Sequenza 1 — Key of Stars** (tier `angel`)

> Chiavi che aprono qualunque cosa, compresi luoghi che non hanno una porta.

- Modificatori: hp_max +400, spiritualita_max +0.35, velocita +0.15

  - **Chiave di ogni luogo** (`door_chiave_di_ogni_luogo`) — costo 36 spiritualità, cooldown 40.0s. `terrain_modify`(tipo_modifica=varco_forzato, raggio=3, durata=0, permanente=True); `teleport`(distanza=300, richiede_visuale=False, porta_alleati=True)

    *La Key of Stars apre qualunque cosa, anche un luogo senza porta: terrain_modify tipo_modifica 'varco_forzato' permanente:true entra nel WorldState (e sopravvive al reload, come i varchi del Twilight Giant) + teleport per passarci.*

    tag sinergia: spazio, viaggio, stella

  - **Una porta dove non c'e'** (`door_porta_dove_non_ce`) — costo 28 spiritualità, cooldown 30.0s. `terrain_modify`(tipo_modifica=varco_forzato, raggio=3, durata=0, permanente=True)

    *Solo il varco, senza attraversarlo subito: resta aperto nel mondo (WorldState).*

    tag sinergia: spazio, stella, singolo

  - **Anatema del Varco** (`door_anatema_del_varco`) — costo 27 spiritualità, cooldown 26.0s. `curse`(effetto=varco_sigillato, durata=15.0, condizione_rimozione=); `debuff_stat`(stat=velocita, valore=-0.3, durata=15.0, moltiplicativo=True)

    *US-714. La Key of Stars sigilla lo spazio intorno al bersaglio invece di aprirlo: curse(varco_sigillato, nuovo status) + debuff velocita'. Stessa primitiva delle altre maledizioni del gioco, nessuna nuova.*

    tag sinergia: spazio, maledizione

- Recitazione (3 azioni):

  - Apri 12 luoghi con la chiave di ogni serratura → +0.4 (evento `ability_used`, target 12)

  - Forza 12 varchi dove non c'era una porta → +0.35 (evento `ability_used`, target 12)

  - Entra in 10 aree che credevano di essere chiuse → +0.25 (evento `area_cleared`, target 10)

- Pozione: ingredienti chiave_fatta_di_luce_di_stella, serratura_dell_orizzonte, cardine_del_cielo

- Rituale di avanzamento: luogo `['nebbia_grigia', 'soglia']`, fase lunare `eclissi`, sacrifici ['ancora_del_giocatore']



**Sequenza 0 — Door** (tier `god`)

> Passaggio senza limiti.

- Modificatori: hp_max +700, spiritualita_max +0.6, velocita +0.2

  - **Passaggio senza limiti** (`door_passaggio_senza_limiti`) — costo 55 spiritualità, cooldown 60.0s. `aura`(raggio=15, durata=-1, effetto=gravita_alterata, tick_rate=2.0, bersagli=nemici); `teleport`(distanza=400, richiede_visuale=False, porta_alleati=True)

    *L'abilita' di dominio del Door: nel raggio ogni passaggio e' suo da concedere o negare - i nemici si muovono a fatica (gravita_alterata) mentre lui e gli alleati saltano dove vogliono. Aura persistente + teleport, come i Seq 0 di fase 5.*

    tag sinergia: dominio, spazio, area

  - **Ogni soglia** (`door_ogni_soglia`) — costo 45 spiritualità, cooldown 45.0s. `terrain_modify`(tipo_modifica=varco_forzato, raggio=5, durata=0, permanente=True); `buff_stat`(stat=velocita, valore=0.3, durata=10.0, moltiplicativo=True)

    *Apre un varco largo che resta nel mondo, e per un momento il Door e' piu' veloce di ogni porta.*

    tag sinergia: spazio, dominio, viaggio

- Recitazione (3 azioni):

  - Imponi il passaggio senza limiti 5 volte → +0.4 (evento `ability_used`, target 5)

  - Attraversa 10 soglie che non esistevano → +0.35 (evento `ability_used`, target 10)

  - Sconfiggi 30 nemici: nessun muro ti ha fermato → +0.25 (evento `enemy_defeated`, target 30)

- Pozione: ingredienti prima_porta_mai_aperta, distanza_ridotta_a_zero, soglia_tra_tutto_e_tutto

- Rituale di avanzamento: luogo `['porta_senza_stanza']`, fase lunare `eclissi`, sacrifici ['il_detentore_precedente_della_sequenza_0']





### Error (`error`)

*Rubare le abilita' altrui e sfruttare i buchi nelle regole*

- god_title: Error · tag: furto, inganno, tempo, parassita



**Sequenza 9 — Marauder** (tier `low`)

> Scasso, furto da inventario nemico, colpo alle spalle con bonus se non visto.

- Modificatori: velocita +0.08, evasione +0.05

  - **Scasso** (`error_scasso`) — costo 5 spiritualità, cooldown 8.0s. `steal`(categoria=oggetto, durata_prestito=0, probabilita=0.8)

    *Il primo furto del Marauder: forza una serratura o alleggerisce un nemico. L'aggancio all'inventario del bersaglio e' combat (fase 6); qui la primitiva registra il colpo.*

    tag sinergia: furto, singolo, cavillo

  - **Pugnalata furtiva** (`error_pugnalata_furtiva`) — costo 6 spiritualità, cooldown 4.0s. `melee_arc`(danno=16, angolo=55, raggio=1.5, stagger=22, tag_danno=fisico)

    *Un colpo alle spalle: danno secco se il bersaglio non ti ha visto. Il bonus da invisibilita' e' combat (fase 6).*

    tag sinergia: furto, singolo, agilita'

- Recitazione (3 azioni):

  - Scassina 15 volte: ogni serratura forzata e' bottino → +0.4 (evento `ability_used`, target 15)

  - Abbatti 10 nemici senza incassare un colpo: il Marauder non si fa vedere → +0.35 (evento `enemy_defeated`, target 10)

  - Infliggi 1200 danni fisici alle spalle dei nemici → +0.25 (evento `damage_dealt`, target 1200)

- Pozione: ingredienti grimaldello_cantante, guanto_del_borseggiatore, refurtiva_dimenticata



**Sequenza 8 — Swindler** (tier `low`)

> Eloquenza e truffa: estrae denaro e informazioni dagli NPC senza combattere.

- Modificatori: spiritualita_max +0.08, precisione +0.05

  - **Parlantina** (`error_parlantina`) — costo 8 spiritualità, cooldown 10.0s. `debuff_stat`(stat=precisione, valore=-0.2, durata=8.0, moltiplicativo=True)

    *Un fiume di parole che distrae: il bersaglio perde il filo e mira peggio. La truffa vera sugli NPC e' il flusso npc_influenced, contato dalla recitazione.*

    tag sinergia: inganno, mente, singolo

  - **Patto truffaldino** (`error_patto_truffaldino`) — costo 10 spiritualità, cooldown 24.0s. `buff_stat`(stat=spiritualita_max, valore=0.15, durata=20.0, moltiplicativo=True)

    *Ogni accordo dello Swindler ha una clausola nascosta a suo favore: ne ricava risorse.*

    tag sinergia: inganno, contratto, furto

- Recitazione (3 azioni):

  - Inganna 12 NPC: la truffa e' il mestiere dello Swindler → +0.45 (evento `npc_influenced`, target 12)

  - Persuadi 8 NPC con la sola parlantina → +0.3 (evento `npc_influenced`, target 8)

  - Usa la parlantina 15 volte per confondere i bersagli → +0.25 (evento `ability_used`, target 15)

- Pozione: ingredienti lingua_d_argento_falsa, contratto_con_la_clausola_nascosta, dado_truccato



**Sequenza 7 — Cryptologist** (tier `low`)

> Decifra formule, sigilli e testi cifrati; ruba conoscenza invece di oggetti.

- Modificatori: spiritualita_max +0.1, precisione +0.08

  - **Decifrazione** (`error_decifrazione`) — costo 12 spiritualità, cooldown 18.0s. `steal`(categoria=conoscenza, durata_prestito=0, probabilita=0.9); `reveal_info`(raggio=10, categoria=formule_cifrate, durata=12.0)

    *Il Cryptologist ruba conoscenza al posto di oggetti: decifra una formula o un sigillo e se lo tiene. reveal_info porta la categoria (divinazione fuori da Hermit, matrice di proprieta').*

    tag sinergia: furto, conoscenza, analisi

  - **Lettura rubata** (`error_lettura_rubata`) — costo 10 spiritualità, cooldown 12.0s. `reveal_info`(raggio=8, categoria=sigilli_nascosti, durata=10.0); `debuff_stat`(stat=difesa, valore=-0.15, durata=6.0, moltiplicativo=True)

    *Legge i sigilli difensivi del bersaglio e ne trova il difetto: la difesa cede dove il testo lo dice.*

    tag sinergia: conoscenza, divinazione, singolo

- Recitazione (3 azioni):

  - Decifra 12 formule o sigilli: la conoscenza si prende, non si chiede → +0.4 (evento `ability_used`, target 12)

  - Ruba 12 letture dai testi altrui → +0.35 (evento `ability_used`, target 12)

  - Passa 300 secondi a studiare i cifrari rubati → +0.25 (evento `time_in_state`, target 300)

- Pozione: ingredienti stele_di_rosetta_infranta, inchiostro_simpatico_rubato, chiave_di_cifrario



**Sequenza 6 — Prometheus** (tier `mid`)

> Ruba temporaneamente un'abilita' Beyonder appena vista e la usa una volta.

- Modificatori: spiritualita_max +0.12, precisione +0.08

  - **Furto di Prometeo** (`error_furto_prometeo`) — costo 25 spiritualità, cooldown 30.0s. `steal`(categoria=abilita, ability_id=tg_fendente_pesante, durata_prestito=12.0, probabilita=0.7)

    *Ruba un'abilita' Beyonder appena vista e la rende eseguibile via grant_temporary (US-204). Il prestito e' breve e non sempre riesce (probabilita 0.7): la firma dell'Error, distinta dallo Scribe del Door (fotocopia, sempre). ability_id nei dati = quale potere questo Beyonder e' capace di copiare; il bersaglio da cui rubare lo sceglie il combat (fase 6).*

    tag sinergia: furto, inganno, singolo

  - **Scintilla rubata** (`error_scintilla_rubata`) — costo 12 spiritualità, cooldown 5.0s. `projectile`(danno=24, velocita=10, gittata=11, pierce=1, tag_danno=spirito)

    *Un frammento del potere rubato scagliato indietro: il Prometheus non tiene mai a lungo cio' che prende.*

    tag sinergia: furto, spirito, singolo

- Recitazione (3 azioni):

  - Ruba 12 abilita' Beyonder appena viste → +0.45 (evento `ability_used`, target 12)

  - Infliggi 3000 danni da spirito con poteri non tuoi → +0.3 (evento `damage_dealt`, target 3000)

  - Sconfiggi 15 nemici con le loro stesse armi → +0.25 (evento `enemy_defeated`, target 15)

- Pozione: ingredienti favilla_del_titano_incatenato, fegato_sempre_rigenerato, creta_del_primo_uomo



**Sequenza 5 — Dream Stealer** (tier `mid`)

> Entra nei sogni per rubare ricordi e formule di pozione.

- Modificatori: spiritualita_max +0.15, evasione +0.08

  - **Furto dei sogni** (`error_furto_dei_sogni`) — costo 16 spiritualità, cooldown 20.0s. `steal`(categoria=conoscenza, durata_prestito=0, probabilita=0.85); `debuff_stat`(stat=precisione, valore=-0.25, durata=8.0, moltiplicativo=True)

    *Entra nel sogno di un dormiente e ne porta via ricordi e formule. Solo di notte (condizione dai dati, l'engine la fa valere). Il derubato dei ricordi combatte peggio.*

    tag sinergia: furto, sonno, conoscenza

  - **Incubo parassita** (`error_incubo_parassita`) — costo 14 spiritualità, cooldown 12.0s. `dot`(danno_tick=6, tick_rate=1.5, durata=8.0, tag_danno=follia); `debuff_stat`(stat=difesa, valore=-0.2, durata=8.0, moltiplicativo=True)

    *Lascia un incubo che si nutre da solo: logora la mente del bersaglio finche' dura.*

    tag sinergia: sonno, parassita, follia

- Recitazione (3 azioni):

  - Ruba 12 sogni: ricordi e formule prese mentre l'altro dorme → +0.4 (evento `ability_used`, target 12)

  - Passa 600 secondi nella notte, quando i sogni sono raggiungibili → +0.35 (evento `time_in_state`, target 600)

  - Infliggi 2500 danni da follia con gli incubi impiantati → +0.25 (evento `damage_dealt`, target 2500)

- Pozione: ingredienti cuscino_di_un_dormiente_inquieto, sabbia_del_sonno_rubata, ricordo_altrui_in_bottiglia



**Sequenza 4 — Parasite** (tier `saint`)

> Si attacca a un ospite: ne usa sensi, movimento e risorse restando nascosto.

- Modificatori: hp_max +120, evasione +0.12, velocita +0.1

  - **Innesto parassita** (`error_innesto_parassita`) — costo 22 spiritualità, cooldown 26.0s. `possess`(durata=10.0, soglia_resistenza=4, controllo=sensi, vulnerabilita_corpo=0.4)

    *Il Parasite si attacca a un ospite e ne condivide i sensi (controllo 'sensi': nessun controllo motorio). Come soul_detach: il corpo del caster resta a terra, meno vulnerabile del solito perche' nascosto (0.4). L'ospite che agisce e' combat (fase 6).*

    tag sinergia: parassita, possessione, occultamento

  - **Simbiosi furtiva** (`error_simbiosi_furtiva`) — costo 14 spiritualità, cooldown 16.0s. `shadow_meld`(durata=8.0, velocita=0.2, richiede_ombra=False); `heal`(quantita=20, istantaneo=True, bersaglio=self)

    *Attinge alle risorse dell'ospite per rimarginare le proprie ferite, restando occultato.*

    tag sinergia: parassita, occultamento, guarigione

- Recitazione (3 azioni):

  - Innestati su 10 ospiti → +0.4 (evento `ability_used`, target 10)

  - Passa 500 secondi in ombra: il Parasite non si fa mai vedere → +0.35 (evento `time_in_state`, target 500)

  - Sconfiggi 15 nemici usando i sensi e il movimento di un ospite → +0.25 (evento `enemy_defeated`, target 15)

- Pozione: ingredienti vischio_che_si_aggrappa, cuore_condiviso, muta_di_pelle_altrui

- Rituale di avanzamento: luogo `['nebbia_grigia', 'crocevia']`, fase lunare `None`, sacrifici ['un_ricordo_a_cui_tenevi']



**Sequenza 3 — Mentor of Deceit** (tier `saint`)

> Crea avatar autonomi che agiscono come lui; inganni a piu' livelli.

- Modificatori: hp_max +160, spiritualita_max +0.2, precisione +0.1

  - **Proietta avatar** (`error_proietta_avatar`) — costo 28 spiritualità, cooldown 32.0s. `summon`(entita_id=avatar_error_mentore, quantita=2, durata=30.0, comportamento=aggressivo)

    *Il Mentor of Deceit proietta da se' avatar autonomi (materia prima 'avatar' in ownership.json: non cadaveri, non costrutti, non illusioni - agiscono davvero). Persistenza vera fuori dal combat e' fase 6: qui durata 30s.*

    tag sinergia: inganno, evocazione, singolo

  - **Inganno stratificato** (`error_inganno_stratificato`) — costo 20 spiritualità, cooldown 16.0s. `illusion`(raggio=6, durata=8.0, potenza=2, tipo_illusione=copia_nemico); `debuff_stat`(stat=precisione, valore=-0.2, durata=6.0, moltiplicativo=True)

    *Inganni dentro inganni: esche che sembrano nemici veri, mentre chi guarda perde la mira. Le esche 'vere' nel combat sono fase 6.*

    tag sinergia: inganno, illusione, area

- Recitazione (3 azioni):

  - Proietta 12 avatar autonomi → +0.4 (evento `ability_used`, target 12)

  - Sconfiggi 20 nemici muovendo gli altri come pedine → +0.35 (evento `enemy_defeated`, target 20)

  - Infliggi 4000 danni da follia con gli inganni stratificati → +0.25 (evento `damage_dealt`, target 4000)

- Pozione: ingredienti specchio_che_riflette_un_altro, sillaba_di_un_nome_non_tuo, filo_del_burattinaio

- Rituale di avanzamento: luogo `['nebbia_grigia', 'vicolo']`, fase lunare `None`, sacrifici ['la_tua_faccia_vera_per_un_giorno']



**Sequenza 2 — Trojan Horse of Destiny** (tier `angel`)

> Impianta un errore nel destino di un bersaglio: i suoi piani falliscono.

- Modificatori: hp_max +280, spiritualita_max +0.3, precisione +0.15

  - **Cavallo di Troia** (`error_cavallo_di_troia`) — costo 32 spiritualità, cooldown 28.0s. `curse`(effetto=destino_segnato, durata=15.0, condizione_rimozione=); `debuff_stat`(stat=forza, valore=-0.35, durata=12.0, moltiplicativo=True); `dot`(danno_tick=10, tick_rate=1.0, durata=12.0, tag_danno=follia)

    *Un errore impiantato nel destino: da qui in avanti i piani del bersaglio falliscono. Reso con curse(destino_segnato) + debuff + dot follia, come hermit_1 (SENZA rule_bind).*

    tag sinergia: inganno, destino, maledizione

  - **Il piano che crolla** (`error_piano_che_crolla`) — costo 22 spiritualità, cooldown 14.0s. `debuff_stat`(stat=difesa, valore=-0.4, durata=10.0, moltiplicativo=True); `debuff_stat`(stat=evasione, valore=-0.3, durata=10.0, moltiplicativo=True)

    *Ogni appiglio che il bersaglio credeva di avere cede nello stesso momento.*

    tag sinergia: destino, singolo, cavillo

- Recitazione (3 azioni):

  - Impianta 12 errori nel destino altrui → +0.4 (evento `ability_used`, target 12)

  - Sconfiggi 18 nemici i cui piani sono gia' crollati → +0.35 (evento `enemy_defeated`, target 18)

  - Infliggi 6000 danni da follia mentre i loro piani falliscono → +0.25 (evento `damage_dealt`, target 6000)

- Pozione: ingredienti chiodo_nell_ingranaggio_del_fato, lettera_mai_consegnata, voto_infranto_alla_radice

- Rituale di avanzamento: luogo `['crocevia', 'nebbia_grigia']`, fase lunare `calante`, sacrifici ['un_piano_a_cui_tenevi_davvero']



**Sequenza 1 — Worm of Time** (tier `angel`)

> Riavvolge brevi tratti di tempo in un raggio limitato.

- Modificatori: hp_max +420, spiritualita_max +0.35, evasione +0.15

  - **Riavvolgi** (`error_riavvolgi`) — costo 26 spiritualità, cooldown 20.0s. `time_rewind`(secondi=3.0, ripristina=['hp', 'spiritualita'], costo_follia=6.0)

    *Il Worm of Time riavvolge se stesso di 3 secondi: hp e spiritualita' tornano a com'erano. Il prezzo e' follia. Il raggio su altre entita' e' fase 6.*

    tag sinergia: tempo, singolo, cavillo

  - **Verme del tempo** (`error_verme_del_tempo`) — costo 34 spiritualità, cooldown 40.0s. `time_rewind`(secondi=5.0, ripristina=['hp', 'spiritualita', 'posizione'], costo_follia=10.0); `buff_stat`(stat=velocita, valore=0.2, durata=6.0, moltiplicativo=True)

    *Un riavvolgimento piu' lungo che riporta anche il corpo dov'era: si esce da una posizione persa. Costa molta follia.*

    tag sinergia: tempo, viaggio, singolo

- Recitazione (3 azioni):

  - Riavvolgi il tempo 15 volte → +0.4 (evento `ability_used`, target 15)

  - Subisci 5000 danni che poi il riavvolgimento cancella → +0.35 (evento `damage_taken`, target 5000)

  - Scava 8 gallerie nel tempo (riavvolgimento con posizione) → +0.25 (evento `ability_used`, target 8)

- Pozione: ingredienti clessidra_che_cola_all_indietro, eco_di_un_istante_gia_passato, verme_che_mangia_i_minuti

- Rituale di avanzamento: luogo `['nebbia_grigia', 'soglia']`, fase lunare `eclissi`, sacrifici ['ancora_del_giocatore']



**Sequenza 0 — Error** (tier `god`)

> Sfrutta i buchi nelle regole del mondo stesso.

- Modificatori: hp_max +700, spiritualita_max +0.6, precisione +0.2, evasione +0.2

  - **Falla nelle regole** (`error_falla_nelle_regole`) — costo 55 spiritualità, cooldown 60.0s. `aura`(raggio=15, durata=-1, effetto=destino_segnato, tick_rate=2.0, bersagli=nemici); `debuff_stat`(stat=difesa, valore=-0.3, durata=8.0, moltiplicativo=True)

    *L'abilita' di dominio dell'Error: nel raggio le regole hanno una falla e chiunque vi entri e' gia' segnato dal fato. Aura persistente + debuff, come i Seq 0 di fase 5.*

    tag sinergia: dominio, cavillo, area

  - **Ultima scappatoia** (`error_ultima_scappatoia`) — costo 45 spiritualità, cooldown 50.0s. `time_rewind`(secondi=6.0, ripristina=['hp', 'spiritualita', 'posizione'], costo_follia=14.0); `heal`(quantita=60, istantaneo=True, bersaglio=self)

    *Non esiste situazione senza uscita per l'Error: riavvolge fino a sei secondi e si rimargina. La follia che costa e' enorme.*

    tag sinergia: tempo, dominio, singolo

- Recitazione (3 azioni):

  - Apri 5 falle nelle regole del mondo → +0.4 (evento `ability_used`, target 5)

  - Sconfiggi 30 nemici senza che nessuna regola ti fermi → +0.35 (evento `enemy_defeated`, target 30)

  - Usa l'ultima scappatoia 10 volte → +0.25 (evento `ability_used`, target 10)

- Pozione: ingredienti riga_bianca_nel_regolamento_del_mondo, cavillo_primordiale, porta_che_non_c_e_mai_stata

- Rituale di avanzamento: luogo `['porta_senza_stanza']`, fase lunare `eclissi`, sacrifici ['il_detentore_precedente_della_sequenza_0']





### Fool (`fool`)

*Falsificare la realta' e controllare i nemici come marionette*

- god_title: Fool · tag: inganno, spirito, destino, illusione



**Sequenza 9 — Seer** (tier `low`)

> Divinazione col pendolo e lettura delle intenzioni nemiche. Nessuna offesa: il Seer osserva.

- Modificatori: spiritualita_max +25, percezione +0.1

  - **Divinazione col pendolo** (`fool_divinazione_pendolo`) — costo 8 spiritualità, cooldown 20.0s. `reveal_info`(raggio=30, categoria=pericolo, durata=10.0)

    *Abilita' di apertura del Pathway. Deliberatamente non offensiva: il Fool a Sequenza 9 non combatte, osserva.*

    tag sinergia: divinazione, destino, spirito, non_letale

  - **Velo illusorio** (`fool_velo_illusorio`) — costo 12 spiritualità, cooldown 6.0s. `illusion`(raggio=4, durata=8.0, potenza=1, tipo_illusione=copia_statica); `buff_stat`(stat=evasione, valore=0.15, durata=8.0, moltiplicativo=False)

    tag sinergia: illusione, inganno, occultamento, non_letale

  - **Lettura delle espressioni** (`fool_lettura_espressioni`) — costo 4 spiritualità, cooldown 2.0s. `reveal_info`(raggio=8, categoria=intenzione_nemico, durata=5.0)

    *Mostra il tell del prossimo attacco nemico. Aggancio diretto alla regola di telegrafia del combat.*

    tag sinergia: mente, analisi, inganno, singolo

- Recitazione (3 azioni):

  - Esegui 20 divinazioni → +0.25 (evento `ability_used`, target 20)

  - Inganna 10 NPC facendogli cambiare comportamento → +0.35 (evento `npc_influenced`, target 10)

  - Completa 3 aree ostili senza uccidere nessuno → +0.4 (evento `area_cleared`, target 3)

- Pozione: ingredienti sangue_di_gufo_lunare, polvere_di_specchio_incrinato, radice_di_veggente



**Sequenza 8 — Clown** (tier `low`)

> Destrezza acrobatica, travestimento, illusioni brevi per rompere l'aggro.

- Modificatori: velocita +0.12, evasione +0.1

  - **Acrobazia** (`fool_acrobazia`) — costo 6 spiritualità, cooldown 4.0s. `dash`(distanza=90, durata=0.2, invulnerabile=True, attraversa_nemici=True)

    *Il Clown esce da ogni angolo: uno scatto invulnerabile che attraversa i nemici. Nessuna primitiva nuova.*

    tag sinergia: agilita', non_letale, inganno

  - **Travestimento lampo** (`fool_travestimento_lampo`) — costo 10 spiritualità, cooldown 12.0s. `illusion`(raggio=3, durata=6.0, potenza=1, tipo_illusione=aspetto); `debuff_stat`(stat=precisione, valore=-0.15, durata=5.0, moltiplicativo=True)

    *Cambia aspetto per un attimo: i nemici perdono il bersaglio (rompe l'aggro). L'eredita' vera dei permessi sociali e' il Faceless (Seq 6); qui e' solo scena.*

    tag sinergia: illusione, inganno, occultamento

- Recitazione (3 azioni):

  - Esegui 20 acrobazie per uscire dai guai → +0.35 (evento `ability_used`, target 20)

  - Rompi l'aggro 15 volte con un travestimento lampo → +0.35 (evento `ability_used`, target 15)

  - Completa 2 aree ostili senza uccidere: solo scena → +0.3 (evento `area_cleared`, target 2)

- Pozione: ingredienti naso_finto_di_ceramica, sonaglio_che_confonde, cerone_da_palcoscenico



**Sequenza 7 — Magician** (tier `low`)

> Illusioni solide che infliggono danno percepito; oggetti evocati dal nulla per un colpo.

- Modificatori: spiritualita_max +0.1, precisione +0.08

  - **Illusione solida** (`fool_illusione_solida`) — costo 14 spiritualità, cooldown 8.0s. `illusion`(raggio=5, durata=8.0, potenza=3, tipo_illusione=danno_percepito)

    *Un'illusione talmente convincente che ferisce: dot a tag follia (potenza = intensita' del danno percepito) che sparisce se il bersaglio capisce. Rimovibile da light_purify come ogni dot.*

    tag sinergia: illusione, follia, singolo

  - **Oggetto dal nulla** (`fool_oggetto_dal_nulla`) — costo 10 spiritualità, cooldown 3.0s. `illusion`(raggio=2, durata=1.0, potenza=1, tipo_illusione=oggetto_evocato); `melee_arc`(danno=20, angolo=90, raggio=1.8, stagger=25, tag_danno=fisico)

    *Un bastone, un mattone, una sedia: l'oggetto non c'e' finche' non colpisce. illusion(oggetto_evocato) + melee_arc per il colpo vero.*

    tag sinergia: illusione, inganno, singolo

- Recitazione (3 azioni):

  - Lancia 15 illusioni solide → +0.35 (evento `ability_used`, target 15)

  - Infliggi 2500 danni percepiti (tag follia): fanno male perche' ci credi → +0.35 (evento `damage_dealt`, target 2500)

  - Evoca 15 oggetti dal nulla per colpire → +0.3 (evento `ability_used`, target 15)

- Pozione: ingredienti cilindro_a_doppio_fondo, colomba_che_non_esiste, asso_sempre_in_cima_al_mazzo



**Sequenza 6 — Faceless** (tier `mid`)

> Assume aspetto e voce di un NPC e ne eredita i permessi sociali: apre porte chiuse.

- Modificatori: spiritualita_max +0.12, evasione +0.1

  - **Volto rubato** (`fool_volto_rubato`) — costo 18 spiritualità, cooldown 25.0s. `illusion`(raggio=3, durata=20.0, potenza=1, tipo_illusione=aspetto); `buff_stat`(stat=evasione, valore=0.2, durata=20.0, moltiplicativo=False)

    *Il Faceless prende aspetto e voce di qualcuno: chi lo cerca non lo trova. L'eredita' dei permessi sociali (gate npc) e' fase 6; in 5b e' illusion(aspetto) + evasione, e la truffa la conta la recitazione (npc_influenced).*

    tag sinergia: illusione, inganno, occultamento

  - **Voce prestata** (`fool_voce_prestata`) — costo 12 spiritualità, cooldown 10.0s. `debuff_stat`(stat=precisione, valore=-0.25, durata=8.0, moltiplicativo=True); `debuff_stat`(stat=difesa, valore=-0.15, durata=8.0, moltiplicativo=True)

    *Parla con una voce di cui il bersaglio si fida: abbassa la guardia.*

    tag sinergia: inganno, mente, singolo

- Recitazione (3 azioni):

  - Ruba 12 volti → +0.35 (evento `ability_used`, target 12)

  - Inganna 12 NPC con un volto che non e' il tuo → +0.4 (evento `npc_influenced`, target 12)

  - Attraversa 2 aree ostili senza uccidere: il Faceless passa, non combatte → +0.25 (evento `area_cleared`, target 2)

- Pozione: ingredienti maschera_senza_lineamenti, voce_registrata_su_cera, ritratto_che_cambia_faccia



**Sequenza 5 — Marionettist** (tier `mid`)

> Fili spirituali: controlla un nemico come marionetta e lo usa contro gli altri.

- Modificatori: spiritualita_max +0.15, precisione +0.1

  - **Fili della marionetta** (`fool_fili_marionetta`) — costo 30 spiritualità, cooldown 25.0s. `possess`(durata=12.0, soglia_resistenza=4, controllo=totale); `debuff_stat`(stat=difesa, valore=-0.3, durata=12.0, moltiplicativo=True)

    *STRESS TEST. Marionettista: possess con soglia legata alla Sequenza del bersaglio. Nessuna primitiva nuova.*

    tag sinergia: inganno, spirito, controllo, singolo

  - **Scambio dei bersagli** (`fool_scambio_bersagli`) — costo 16 spiritualità, cooldown 14.0s. `fear`(raggio=6, durata=5.0, soglia_resistenza=3); `debuff_stat`(stat=difesa, valore=-0.2, durata=8.0, moltiplicativo=True)

    *Gli altri nemici vedono un alleato voltarsi contro di loro: panico e guardia rotta. Il nemico controllato che attacca davvero e' combat (fase 6).*

    tag sinergia: inganno, controllo, area

- Recitazione (3 azioni):

  - Attacca 12 fili a 12 marionette → +0.4 (evento `ability_used`, target 12)

  - Sconfiggi 15 nemici mettendoli l'uno contro l'altro → +0.35 (evento `enemy_defeated`, target 15)

  - Semina lo scompiglio 12 volte tra i nemici → +0.25 (evento `ability_used`, target 12)

- Pozione: ingredienti filo_spirituale_annodato, croce_di_legno_del_burattinaio, articolazione_di_marionetta



**Sequenza 4 — Bizarro Sorcerer** (tier `saint`)

> Sostituisce se stesso con un oggetto a distanza; gioco di prestigio su scala di stanza.

- Modificatori: hp_max +130, velocita +0.12, evasione +0.12

  - **Scambio con un oggetto** (`fool_scambio_con_oggetto`) — costo 16 spiritualità, cooldown 12.0s. `teleport`(distanza=180, richiede_visuale=True, porta_alleati=False); `illusion`(raggio=2, durata=6.0, potenza=1, tipo_illusione=copia_statica)

    *Il Bizarro Sorcerer si scambia con un oggetto a distanza: teleport via, un'esca statica al suo posto. teleport gia' implementata (US-506).*

    tag sinergia: illusione, spazio, inganno

  - **Prestigio di stanza** (`fool_prestigio_di_stanza`) — costo 20 spiritualità, cooldown 16.0s. `illusion`(raggio=8, durata=10.0, potenza=2, tipo_illusione=copia_nemico); `debuff_stat`(stat=precisione, valore=-0.2, durata=6.0, moltiplicativo=True)

    *Riempie una stanza di copie: 2 esche (potenza = numero) e chi guarda non sa piu' dove mirare.*

    tag sinergia: illusione, inganno, area

- Recitazione (3 azioni):

  - Scambiati con un oggetto 12 volte → +0.4 (evento `ability_used`, target 12)

  - Riempi 12 stanze di illusioni → +0.35 (evento `ability_used`, target 12)

  - Chiudi 3 aree ostili con la sola messinscena → +0.25 (evento `area_cleared`, target 3)

- Pozione: ingredienti cappello_a_cilindro_senza_fondo, specchio_da_camerino_incrinato, sipario_di_velluto_polveroso

- Rituale di avanzamento: luogo `['teatro', 'palco']`, fase lunare `None`, sacrifici ['la_certezza_di_sapere_chi_sei']



**Sequenza 3 — Scholar of Yore** (tier `saint`)

> Richiama dal passato una versione precedente di se' o di un oggetto distrutto.

- Modificatori: hp_max +150, spiritualita_max +0.22, evasione +0.12

  - **Richiamo dal passato** (`fool_richiamo_dal_passato`) — costo 24 spiritualità, cooldown 22.0s. `time_rewind`(secondi=4.0, ripristina=['hp', 'spiritualita'], costo_follia=7.0); `illusion`(raggio=4, durata=8.0, potenza=1, tipo_illusione=copia_statica)

    *Lo Scholar of Yore richiama una versione precedente di se': time_rewind (gia' implementata, US-5B03) sul caster + un'immagine di com'era. Gli avatar del Fool sono FINTI (decisione: illusion, non la materia prima 'avatar' dell'Error).*

    tag sinergia: tempo, illusione, singolo

  - **Eco di ieri** (`fool_eco_di_ieri`) — costo 18 spiritualità, cooldown 14.0s. `illusion`(raggio=6, durata=10.0, potenza=2, tipo_illusione=copia_nemico); `debuff_stat`(stat=precisione, valore=-0.2, durata=6.0, moltiplicativo=True)

    *Echi di nemici che il bersaglio ha gia' affrontato: 2 esche dal passato che confondono la mira.*

    tag sinergia: illusione, tempo, area

- Recitazione (3 azioni):

  - Richiama 12 volte una versione precedente di te → +0.4 (evento `ability_used`, target 12)

  - Evoca 12 echi di nemici passati → +0.35 (evento `ability_used`, target 12)

  - Infliggi 4000 danni da follia con i ricordi altrui → +0.25 (evento `damage_dealt`, target 4000)

- Pozione: ingredienti pagina_strappata_da_un_diario, polvere_di_un_oggetto_gia_distrutto, ritratto_di_te_da_bambino

- Rituale di avanzamento: luogo `['nebbia_grigia', 'biblioteca']`, fase lunare `None`, sacrifici ['una_pagina_del_tuo_passato']



**Sequenza 2 — Miracle Invoker** (tier `angel`)

> Converte spiritualita' in eventi improbabili: il miracolo come risorsa spendibile.

- Modificatori: hp_max +260, spiritualita_max +0.3, evasione +0.15

  - **Miracolo** (`fool_miracolo`) — costo 40 spiritualità, cooldown 30.0s. `buff_stat`(stat=evasione, valore=0.5, durata=6.0, moltiplicativo=False); `buff_stat`(stat=precisione, valore=0.4, durata=6.0, moltiplicativo=True)

    *L'improbabile reso risorsa: costa molta spiritualita', dura poco, ma per quei secondi tutto ti riesce. VARIANZA ALTA DICHIARATA: nei dati e' un bonus grande e breve; la manipolazione vera della probabilita' resta a Wheel of Fortune (differito). Nessuna primitiva differita.*

    tag sinergia: fortuna, destino, singolo

  - **Sfortuna altrui** (`fool_sfortuna_altrui`) — costo 22 spiritualità, cooldown 16.0s. `curse`(effetto=sfortuna, durata=20.0, condizione_rimozione=); `debuff_stat`(stat=evasione, valore=-0.3, durata=12.0, moltiplicativo=True)

    *Scarica l'improbabile sul bersaglio: inciampa, manca, si ferisce da solo. curse(sfortuna) gia' esistente (Knight of Misfortune del Darkness) + debuff. Nessuna primitiva differita.*

    tag sinergia: fortuna, maledizione, singolo

- Recitazione (3 azioni):

  - Invoca 12 miracoli spendendo spiritualita' → +0.4 (evento `ability_used`, target 12)

  - Scarica la sfortuna su 12 bersagli → +0.35 (evento `ability_used`, target 12)

  - Vinci 10 scontri contro ogni pronostico, senza un graffio → +0.25 (evento `enemy_defeated`, target 10)

- Pozione: ingredienti biglietto_della_lotteria_vincente, quadrifoglio_a_cinque_foglie, moneta_caduta_sempre_di_taglio

- Rituale di avanzamento: luogo `['nebbia_grigia', 'crocevia']`, fase lunare `piena`, sacrifici ['tutta_la_fortuna_che_ti_restava']



**Sequenza 1 — Attendant of Mysteries** (tier `angel`)

> Crea un'area di segretezza in cui la realta' locale puo' essere manomessa.

- Modificatori: hp_max +400, spiritualita_max +0.35, evasione +0.18

  - **Area di segretezza** (`fool_area_di_segretezza`) — costo 30 spiritualità, cooldown 24.0s. `terrain_modify`(tipo_modifica=area_di_segretezza, raggio=8, durata=15.0, permanente=False); `illusion`(raggio=8, durata=15.0, potenza=3, tipo_illusione=copia_nemico)

    *Un'area in cui la realta' locale e' manomettibile: terrain_modify a tempo (non permanente) + 3 esche. Cosa la 'segretezza' faccia davvero a schermo e' fase 6; qui e' un campo dichiarato + illusioni.*

    tag sinergia: illusione, occultamento, area

  - **Realta' manomessa** (`fool_realta_manomessa`) — costo 26 spiritualità, cooldown 18.0s. `debuff_stat`(stat=difesa, valore=-0.4, durata=10.0, moltiplicativo=True); `debuff_stat`(stat=precisione, valore=-0.3, durata=10.0, moltiplicativo=True); `curse`(effetto=sfortuna, durata=15.0, condizione_rimozione=)

    *Dentro l'area di segretezza le regole cedono per chi non e' il Fool.*

    tag sinergia: inganno, maledizione, area

- Recitazione (3 azioni):

  - Apri 15 aree di segretezza → +0.4 (evento `ability_used`, target 15)

  - Manometti 12 volte la realta' locale → +0.35 (evento `ability_used`, target 12)

  - Risolvi 3 aree ostili restando dietro le quinte → +0.25 (evento `area_cleared`, target 3)

- Pozione: ingredienti angolo_di_stanza_che_non_esiste, silenzio_tra_due_battiti, regola_locale_scritta_a_matita

- Rituale di avanzamento: luogo `['nebbia_grigia', 'soglia']`, fase lunare `eclissi`, sacrifici ['ancora_del_giocatore']



**Sequenza 0 — Fool** (tier `god`)

> Falsifica la realta' su scala di mondo.

- Modificatori: hp_max +700, spiritualita_max +0.6, evasione +0.25

  - **Realta' falsificata** (`fool_realta_falsificata`) — costo 55 spiritualità, cooldown 60.0s. `aura`(raggio=15, durata=-1, effetto=sfortuna, tick_rate=2.0, bersagli=nemici); `illusion`(raggio=15, durata=12.0, potenza=4, tipo_illusione=copia_nemico)

    *L'abilita' di dominio del Fool: nel raggio la realta' e' quella che dice lui - sfortuna cronica per i nemici + 4 esche. Aura persistente + illusion, come i Seq 0 di fase 5.*

    tag sinergia: illusione, dominio, area

  - **Nessuno** (`fool_nessuno`) — costo 45 spiritualità, cooldown 45.0s. `illusion`(raggio=10, durata=10.0, potenza=1, tipo_illusione=aspetto); `buff_stat`(stat=evasione, valore=0.6, durata=10.0, moltiplicativo=False)

    *Il Fool non e' nessuno: nessun aspetto fisso, nessun bersaglio possibile.*

    tag sinergia: illusione, occultamento, dominio

- Recitazione (3 azioni):

  - Falsifica la realta' 5 volte su scala d'area → +0.4 (evento `ability_used`, target 5)

  - Diventa nessuno 10 volte → +0.35 (evento `ability_used`, target 10)

  - Sconfiggi 30 nemici: per il mondo non e' successo niente → +0.25 (evento `enemy_defeated`, target 30)

- Pozione: ingredienti battuta_finale_mai_detta, specchio_che_non_riflette_nessuno, copione_del_mondo_con_le_correzioni

- Rituale di avanzamento: luogo `['porta_senza_stanza']`, fase lunare `eclissi`, sacrifici ['il_detentore_precedente_della_sequenza_0']





## Gruppo Demon of Knowledge

### Hermit (`hermit`)

*Praticare magia rituale, pergamene e costellazioni*

- god_title: Hermit · tag: occulto, rituale, stella, divinazione



**Sequenza 9 — Mystery Pryer** (tier `low`)

> Percepisce il misticismo e traccia rituali di base.

- Modificatori: hp_max +20, spiritualita_max +0.15

  - **Percezione mistica** (`hermit_percezione_mistica`) — costo 5 spiritualità, cooldown 12.0s. `reveal_info`(raggio=10, categoria=densita_mistica, durata=25.0)

    *Il Mystery Pryer percepisce il misticismo. Hermit E' il divinatore sistemico: qui la categoria puo' essere piu' ampia che negli altri Pathway.*

    tag sinergia: occulto, divinazione, area

  - **Traccia rituale** (`hermit_traccia_rituale`) — costo 6 spiritualità, cooldown 14.0s. `buff_stat`(stat=spiritualita_max, valore=0.1, durata=15.0, moltiplicativo=True)

    *Tracciare un rituale di base: il cerchio disegnato rinsalda lo spirito.*

    tag sinergia: occulto, rituale, singolo

- Recitazione (3 azioni):

  - Percepisci il misticismo 20 volte → +0.4 (evento `ability_used`, target 20)

  - Traccia 15 rituali di base → +0.35 (evento `ability_used`, target 15)

  - Sconfiggi 10 nemici studiando l'occulto → +0.25 (evento `enemy_defeated`, target 10)

- Pozione: ingredienti gesso_consacrato, polvere_di_sale_nero, filo_di_lana_rossa



**Sequenza 8 — Melee Scholar** (tier `low`)

> Combatte applicando la conoscenza: sigilli incisi sull'arma in tempo reale.

- Modificatori: hp_max +40, forza +5

  - **Sigillo sull'arma** (`hermit_sigillo_su_arma`) — costo 8 spiritualità, cooldown 6.0s. `buff_stat`(stat=forza, valore=0.2, durata=10.0, moltiplicativo=True); `melee_arc`(danno=16, angolo=60, raggio=1.8, stagger=20, tag_danno=luce)

    *Il Melee Scholar incide un sigillo sull'arma mentre combatte: colpo di luce potenziato.*

    tag sinergia: occulto, conoscenza, forza

  - **Conoscenza applicata** (`hermit_conoscenza_applicata`) — costo 7 spiritualità, cooldown 16.0s. `buff_stat`(stat=precisione, valore=6, durata=12.0, moltiplicativo=False); `buff_stat`(stat=difesa, valore=0.1, durata=12.0, moltiplicativo=True)

    *Combattere applicando la conoscenza: sai dove parare e dove colpire.*

    tag sinergia: conoscenza, difesa, singolo

- Recitazione (3 azioni):

  - Incidi 20 sigilli sull'arma → +0.4 (evento `ability_used`, target 20)

  - Infliggi 2500 danni di luce → +0.35 (evento `damage_dealt`, target 2500)

  - Sconfiggi 12 nemici combattendo col sapere → +0.25 (evento `enemy_defeated`, target 12)

- Pozione: ingredienti punta_d_argento, cera_di_candela_rituale, inchiostro_luminescente



**Sequenza 7 — Warlock** (tier `low`)

> Incantesimi tradizionali ed evocazione minore.

- Modificatori: hp_max +55, spiritualita_max +0.2

  - **Evocazione minore** (`hermit_evocazione_minore`) — costo 10 spiritualità, cooldown 24.0s. `summon`(entita_id=evocazione_famiglio, quantita=1, durata=30.0, comportamento=difensivo)

    *Il Warlock evoca un famiglio. entita_id evocazione_: la materia prima e' il rituale (matrice di proprieta').*

    tag sinergia: occulto, rituale, singolo

  - **Incantesimo tradizionale** (`hermit_incantesimo_tradizionale`) — costo 9 spiritualità, cooldown 7.0s. `projectile`(danno=18, velocita=10, gittata=10, pierce=1, tag_danno=spirito); `debuff_stat`(stat=velocita, valore=-0.2, durata=6.0, moltiplicativo=True)

    *Un incantesimo tradizionale: dardo di spirito che rallenta chi colpisce.*

    tag sinergia: occulto, spirito, singolo

- Recitazione (3 azioni):

  - Evoca un famiglio 15 volte → +0.4 (evento `ability_used`, target 15)

  - Lancia 18 incantesimi tradizionali → +0.35 (evento `ability_used`, target 18)

  - Sconfiggi 12 nemici col famiglio e gli incantesimi → +0.25 (evento `enemy_defeated`, target 12)

- Pozione: ingredienti ossa_di_gatto_nero, incenso_di_mirra, chiodo_di_ferro_freddo



**Sequenza 6 — Scrolls Professor** (tier `mid`)

> Prepara pergamene monouso: magia precotta da spendere al momento giusto.

- Modificatori: hp_max +90, spiritualita_max +0.3

  - **Pergamena pronta** (`hermit_pergamena_pronta`) — costo 12 spiritualità, cooldown 18.0s. `buff_stat`(stat=spiritualita_max, valore=0.15, durata=20.0, moltiplicativo=True); `shield`(assorbimento=40, durata=20.0, riflette=0, tag_bloccati=[], bersaglio=self)

    *Lo Scrolls Professor prepara pergamene monouso: magia precotta pronta da spendere. La produzione dell'oggetto pergamena (stored_ability_id, US-306) e' aggancio di fase 6.*

    tag sinergia: occulto, conoscenza, difesa

  - **Scarica precotta** (`hermit_scarica_precotta`) — costo 10 spiritualità, cooldown 6.0s. `projectile`(danno=30, velocita=14, gittata=12, pierce=2, tag_danno=luce)

    *Spendere una pergamena al momento giusto: scarica di luce che perfora.*

    tag sinergia: occulto, conoscenza, singolo

- Recitazione (3 azioni):

  - Prepara 15 pergamene → +0.4 (evento `ability_used`, target 15)

  - Scarica 18 pergamene → +0.35 (evento `ability_used`, target 18)

  - Sconfiggi 12 nemici con la magia precotta → +0.25 (evento `enemy_defeated`, target 12)

- Pozione: ingredienti pergamena_di_qualita, sigillo_di_ceralacca, inchiostro_ferrogallico



**Sequenza 5 — Constellations Master** (tier `mid`)

> Costellazioni: potenziamenti stellari legati alla posizione e all'ora.

- Modificatori: hp_max +130, spiritualita_max +0.35

  - **Costellazione del Guerriero** (`hermit_costellazione_del_guerriero`) — costo 14 spiritualità, cooldown 25.0s. `buff_stat`(stat=forza, valore=0.3, durata=15.0, moltiplicativo=True)

    *La costellazione del Guerriero: potenziamento stellare, ma solo di notte quando le stelle si vedono.*

    tag sinergia: stella, forza, singolo

  - **Costellazione del Custode** (`hermit_costellazione_del_custode`) — costo 14 spiritualità, cooldown 25.0s. `buff_stat`(stat=difesa, valore=0.35, durata=15.0, moltiplicativo=True)

    *La costellazione del Custode: scudo stellare, ma solo a luna piena.*

    tag sinergia: stella, difesa, singolo

- Recitazione (3 azioni):

  - Invoca la costellazione del Guerriero 15 volte → +0.4 (evento `ability_used`, target 15)

  - Invoca la costellazione del Custode 15 volte → +0.35 (evento `ability_used`, target 15)

  - Sconfiggi 15 nemici sotto le stelle giuste → +0.25 (evento `enemy_defeated`, target 15)

- Pozione: ingredienti polvere_di_meteora, astrolabio_tascabile, frammento_di_cielo_notturno



**Sequenza 4 — Mysticologist** (tier `saint`)

> Crea incantesimi propri combinando conoscenze acquisite.

- Modificatori: hp_max +200, spiritualita_max +0.4

  - **Incantesimo su misura** (`hermit_incantesimo_su_misura`) — costo 18 spiritualità, cooldown 12.0s. `dot`(danno_tick=14, tick_rate=1.0, durata=8.0, tag_danno=spirito); `debuff_stat`(stat=precisione, valore=-0.3, durata=8.0, moltiplicativo=True)

    *Il Mysticologist crea incantesimi propri: un maleficio spirituale su misura per il bersaglio.*

    tag sinergia: occulto, conoscenza, spirito

  - **Teoria in pratica** (`hermit_teoria_in_pratica`) — costo 16 spiritualità, cooldown 24.0s. `aura`(raggio=8, durata=15.0, effetto=area_viva, tick_rate=2.0, bersagli=alleati); `buff_stat`(stat=spiritualita_max, valore=0.15, durata=15.0, moltiplicativo=True)

    *La conoscenza mistica messa in pratica: un'area benedetta e piu' spirito per tutti.*

    tag sinergia: occulto, conoscenza, area

- Recitazione (3 azioni):

  - Crea 15 incantesimi su misura → +0.4 (evento `ability_used`, target 15)

  - Infliggi 3000 danni da spirito → +0.35 (evento `damage_dealt`, target 3000)

  - Metti in pratica la teoria 12 volte → +0.25 (evento `ability_used`, target 12)

- Pozione: ingredienti quintessenza_distillata, grimorio_bianco, chiave_di_soluzione

- Rituale di avanzamento: luogo `['torre_di_osservazione', 'vetta']`, fase lunare `nuova`, sacrifici ['un_incantesimo_che_avevi_inventato_tu_bruciato_davanti_a_un_maestro']



**Sequenza 3 — Clairvoyant** (tier `saint`)

> Vede e sente le esistenze nascoste, incluse quelle che non vogliono essere viste.

- Modificatori: hp_max +250, spiritualita_max +0.4

  - **Veggenza** (`hermit_veggenza`) — costo 18 spiritualità, cooldown 14.0s. `mind_read`(raggio=12, profondita=3, rivela=intenzione)

    *Il Clairvoyant vede e sente le esistenze nascoste, incluse quelle che non vogliono essere viste. mind_read: Hermit e' l'unico Pathway attivo che la usa.*

    tag sinergia: divinazione, occulto, singolo

  - **Occhio interiore** (`hermit_occhio_interiore`) — costo 15 spiritualità, cooldown 20.0s. `reveal_info`(raggio=15, categoria=esistenza_nascosta, durata=20.0); `buff_stat`(stat=evasione, valore=0.2, durata=15.0, moltiplicativo=True)

    *L'occhio interiore rivela cio' che si nasconde e ti fa schivare cio' che non vedevi.*

    tag sinergia: divinazione, occulto, area

- Recitazione (3 azioni):

  - Leggi 15 menti → +0.4 (evento `ability_used`, target 15)

  - Apri l'occhio interiore 15 volte → +0.35 (evento `ability_used`, target 15)

  - Sconfiggi 18 nemici prevedendone le mosse → +0.25 (evento `enemy_defeated`, target 18)

- Pozione: ingredienti occhio_di_vetro_nero, polvere_di_terza_vista, specchio_annerito_dal_fumo

- Rituale di avanzamento: luogo `['torre_di_osservazione', 'cripta']`, fase lunare `nuova`, sacrifici ['il_ricordo_del_volto_di_una_persona_a_cui_volevi_bene']



**Sequenza 2 — Sage** (tier `angel`)

> Drena potere direttamente dalla conoscenza mistica accumulata.

- Modificatori: hp_max +400, spiritualita_max +0.5

  - **Potere dal sapere** (`hermit_potere_dal_sapere`) — costo 26 spiritualità, cooldown 30.0s. `buff_stat`(stat=spiritualita_max, valore=0.3, durata=20.0, moltiplicativo=True); `buff_stat`(stat=forza, valore=0.2, durata=20.0, moltiplicativo=True)

    *Il Sage drena potere direttamente dalla conoscenza accumulata.*

    tag sinergia: conoscenza, occulto, forza

  - **Estrazione arcana** (`hermit_estrazione_arcana`) — costo 20 spiritualità, cooldown 12.0s. `dot`(danno_tick=20, tick_rate=1.0, durata=8.0, tag_danno=spirito); `heal`(quantita=25, istantaneo=True, bersaglio=self)

    *Estrarre potere arcano dal nemico: si consuma lui, si rafforza il Sage.*

    tag sinergia: conoscenza, spirito, singolo

- Recitazione (3 azioni):

  - Attingi al sapere 15 volte → +0.4 (evento `ability_used`, target 15)

  - Sconfiggi 20 nemici col potere della conoscenza → +0.35 (evento `enemy_defeated`, target 20)

  - Estrai potere arcano 12 volte → +0.25 (evento `ability_used`, target 12)

- Pozione: ingredienti essenza_di_biblioteca, cristallo_mnemonico, polvere_di_pagine_antiche

- Rituale di avanzamento: luogo `['biblioteca', 'archivio']`, fase lunare `None`, sacrifici ['dieci_libri_che_avevi_amato_letti_e_poi_bruciati']



**Sequenza 1 — Knowledge Emperor** (tier `angel`)

> Legge e altera il destino tessuto di una persona.

- Modificatori: hp_max +600, spiritualita_max +0.55

  - **Marchio del destino** (`hermit_marchio_del_destino`) — costo 34 spiritualità, cooldown 22.0s. `curse`(effetto=destino_segnato, durata=15.0, condizione_rimozione=purificazione); `debuff_stat`(stat=difesa, valore=-0.5, durata=15.0, moltiplicativo=True); `reveal_info`(raggio=5, categoria=filo_del_destino, durata=15.0)

    *Il Knowledge Emperor legge e altera il destino tessuto di una persona. SENZA rule_bind (differita): curse(destino_segnato) + debuff pesante + reveal_info. Come darkness_1/paragon_1.*

    tag sinergia: destino, occulto, singolo

  - **Riscrittura** (`hermit_riscrittura`) — costo 24 spiritualità, cooldown 18.0s. `mind_read`(raggio=8, profondita=5, rivela=futuro_prossimo); `debuff_stat`(stat=precisione, valore=-0.4, durata=10.0, moltiplicativo=True)

    *Leggere il futuro prossimo del bersaglio e riscriverne un frammento: sbaglia i colpi che avrebbe azzeccato.*

    tag sinergia: destino, divinazione, singolo

  - **Intercessione Arcana** (`hermit_intercessione_arcana`) — costo 26 spiritualità, cooldown 24.0s. `heal`(quantita=30, istantaneo=False, durata=8.0, bersaglio=self)

    *US-714. Il Knowledge Emperor non prega un dio: legge la propria formula di guarigione dal destino gia' scritto. heal su self, come le altre cure del Pathway.*

    tag sinergia: rituale, conoscenza

- Recitazione (3 azioni):

  - Segna 15 destini → +0.4 (evento `ability_used`, target 15)

  - Sconfiggi 15 nemici gia' segnati → +0.35 (evento `enemy_defeated`, target 15)

  - Riscrivi 12 frammenti di futuro → +0.25 (evento `ability_used`, target 12)

- Pozione: ingredienti ago_che_cuce_il_fato, filo_reciso_dalle_parche, inchiostro_che_non_si_cancella

- Rituale di avanzamento: luogo `['sala_dei_sigilli']`, fase lunare `None`, sacrifici ['ancora_del_giocatore']



**Sequenza 0 — Hermit** (tier `god`)

> L'occulto come dominio.

- Modificatori: hp_max +900, spiritualita_max +0.75, difesa +0.4

  - **Occulto come dominio** (`hermit_occulto_come_dominio`) — costo 55 spiritualità, cooldown 60.0s. `aura`(raggio=16, durata=-1, effetto=destino_segnato, tick_rate=2.0, bersagli=nemici)

    *L'occulto come dominio: chi vi si oppone e' gia' segnato.*

    tag sinergia: occulto, dominio, area

  - **Verita ultima** (`hermit_verita_ultima`) — costo 48 spiritualità, cooldown 45.0s. `mind_read`(raggio=20, profondita=9, rivela=ogni_segreto); `buff_stat`(stat=spiritualita_max, valore=0.3, durata=20.0, moltiplicativo=True)

    *Nessun segreto resiste all'Hermit di Sequenza 0.*

    tag sinergia: conoscenza, divinazione, area

- Recitazione (3 azioni):

  - Imponi l'occulto come dominio 5 volte → +0.4 (evento `ability_used`, target 5)

  - Sconfiggi 30 nemici → +0.35 (evento `enemy_defeated`, target 30)

  - Estrai ogni segreto 10 volte → +0.25 (evento `ability_used`, target 10)

- Pozione: ingredienti primo_libro_mai_scritto, chiave_di_ogni_serratura, domanda_senza_risposta

- Rituale di avanzamento: luogo `['biblioteca_di_tutto']`, fase lunare `eclissi`, sacrifici ['il_detentore_precedente_della_sequenza_0']





### Paragon (`paragon`)

*Costruire oggetti Beyonder e piegare le leggi fisiche*

- god_title: Paragon · tag: scienza, crafting, invenzione, conoscenza



**Sequenza 9 — Savant** (tier `low`)

> Conoscenza scientifica: analizza oggetti e ne rivela le proprieta'.

- Modificatori: hp_max +20, spiritualita_max +0.12

  - **Analisi** (`paragon_analisi`) — costo 5 spiritualità, cooldown 10.0s. `reveal_info`(raggio=8, categoria=proprieta_oggetto, durata=20.0)

    *Il Savant analizza: proprieta' di un oggetto rivelate. Divinazione fuori da Hermit -> solo la categoria (matrice di proprieta').*

    tag sinergia: scienza, analisi, singolo

  - **Deduzione** (`paragon_deduzione`) — costo 6 spiritualità, cooldown 14.0s. `buff_stat`(stat=precisione, valore=8, durata=12.0, moltiplicativo=False)

    *Ragionare a mente fredda: la mira si fa piu' precisa.*

    tag sinergia: scienza, conoscenza, singolo

- Recitazione (3 azioni):

  - Analizza 20 oggetti → +0.4 (evento `ability_used`, target 20)

  - Deduci 15 volte → +0.35 (evento `ability_used`, target 15)

  - Sconfiggi 10 nemici studiandone le debolezze → +0.25 (evento `enemy_defeated`, target 10)

- Pozione: ingredienti lente_graduata, polvere_reagente, taccuino_di_appunti



**Sequenza 8 — Archaeologist** (tier `low`)

> Scava, identifica reperti e disinnesca trappole antiche.

- Modificatori: hp_max +35, spiritualita_max +0.12

  - **Scavo** (`paragon_scavo`) — costo 8 spiritualità, cooldown 16.0s. `terrain_modify`(tipo_modifica=scavo, raggio=3, durata=10.0, permanente=False); `reveal_info`(raggio=5, categoria=reperto, durata=15.0)

    *L'Archaeologist scava e identifica: cosa c'e' sepolto e dove.*

    tag sinergia: analisi, terra, area

  - **Disinnesco** (`paragon_disinnesco`) — costo 7 spiritualità, cooldown 12.0s. `light_purify`(raggio=4, potenza=2, riduce_sequenza=False)

    *Disinnesca trappole antiche: gli effetti d'area ostili nel raggio spariscono.*

    tag sinergia: analisi, purificazione, area

- Recitazione (3 azioni):

  - Scava 18 siti → +0.4 (evento `ability_used`, target 18)

  - Disinnesca 15 trappole → +0.35 (evento `ability_used`, target 15)

  - Subisci 600 danni esplorando rovine → +0.25 (evento `damage_taken`, target 600)

- Pozione: ingredienti spazzola_da_scavo, resina_conservante, frammento_di_tavoletta



**Sequenza 7 — Appraiser** (tier `low`)

> Valuta e identifica gli Oggetti Sigillati, rivelandone gli effetti collaterali.

- Modificatori: hp_max +55, spiritualita_max +0.15

  - **Perizia** (`paragon_perizia`) — costo 10 spiritualità, cooldown 22.0s. `reveal_info`(raggio=6, categoria=sigillo, durata=20.0)

    *L'Appraiser valuta un Oggetto Sigillato e ne rivela l'effetto_collaterale (dato di fase 3). Nessun if per Paragon nel sistema sigilli.*

    tag sinergia: analisi, conoscenza, singolo

  - **Stima** (`paragon_stima`) — costo 8 spiritualità, cooldown 15.0s. `buff_stat`(stat=precisione, valore=0.15, durata=10.0, moltiplicativo=True); `buff_stat`(stat=evasione, valore=5, durata=10.0, moltiplicativo=False)

    *Stimare il valore di tutto in tempo reale: sai dove colpire e dove non farti colpire.*

    tag sinergia: scienza, conoscenza, singolo

- Recitazione (3 azioni):

  - Perizia 18 Oggetti Sigillati → +0.4 (evento `ability_used`, target 18)

  - Stima 15 volte → +0.35 (evento `ability_used`, target 15)

  - Sconfiggi 12 nemici sfruttando cio' che hai valutato → +0.25 (evento `enemy_defeated`, target 12)

- Pozione: ingredienti bilancia_di_precisione, acido_da_saggio, cristallo_di_riferimento



**Sequenza 6 — Artisan** (tier `mid`)

> Costruisce armi e congegni Beyonder: il Pathway del crafting.

- Modificatori: hp_max +90, spiritualita_max +0.25

  - **Congegno offensivo** (`paragon_congegno_offensivo`) — costo 13 spiritualità, cooldown 22.0s. `summon`(entita_id=costrutto_torretta, quantita=1, durata=30.0, comportamento=difensivo)

    *L'Artisan costruisce una torretta Beyonder. entita_id costrutto_: la fonte e' il crafting (matrice di proprieta'). Il flusso vero passa per Forge di fase 3.*

    tag sinergia: crafting, invenzione, singolo

  - **Arma Beyonder** (`paragon_arma_beyonder`) — costo 10 spiritualità, cooldown 8.0s. `buff_stat`(stat=forza, valore=0.25, durata=12.0, moltiplicativo=True); `projectile`(danno=20, velocita=12, gittata=12, pierce=2, tag_danno=fisico)

    *Un'arma Beyonder appena forgiata: colpo che passa attraverso e forza in piu'.*

    tag sinergia: crafting, forza, singolo

- Recitazione (3 azioni):

  - Costruisci 15 congegni → +0.4 (evento `ability_used`, target 15)

  - Forgia 15 armi Beyonder → +0.35 (evento `ability_used`, target 15)

  - Sconfiggi 15 nemici con le tue creazioni → +0.25 (evento `enemy_defeated`, target 15)

- Pozione: ingredienti ingranaggio_di_precisione, lega_beyonder, olio_conduttore



**Sequenza 5 — Astronomer** (tier `mid`)

> Strumenti ottici e mappe: previsione e ricognizione a distanza.

- Modificatori: hp_max +130, spiritualita_max +0.3

  - **Ricognizione** (`paragon_ricognizione`) — costo 9 spiritualità, cooldown 18.0s. `reveal_info`(raggio=20, categoria=mappa, durata=30.0)

    *L'Astronomer usa strumenti ottici: ricognizione a distanza, categoria mappa. Paragon MISURA, non legge le menti.*

    tag sinergia: scienza, analisi, area

  - **Previsione** (`paragon_previsione`) — costo 11 spiritualità, cooldown 16.0s. `buff_stat`(stat=evasione, valore=0.2, durata=12.0, moltiplicativo=True)

    *Prevedere le traiettorie: sai da dove arrivera' il colpo prima che parta.*

    tag sinergia: scienza, conoscenza, singolo

- Recitazione (3 azioni):

  - Fai ricognizione 15 volte → +0.4 (evento `ability_used`, target 15)

  - Prevedi 15 attacchi → +0.35 (evento `ability_used`, target 15)

  - Mappa 10 aree completamente → +0.25 (evento `area_cleared`, target 10)

- Pozione: ingredienti lente_di_lungo_fuoco, carta_millimetrata, inchiostro_stellare



**Sequenza 4 — Alchemist** (tier `saint`)

> Trasmutazione dei materiali; alchimia applicata al crafting.

- Modificatori: hp_max +200, spiritualita_max +0.4

  - **Trasmutazione** (`paragon_trasmutazione`) — costo 18 spiritualità, cooldown 16.0s. `terrain_modify`(tipo_modifica=materiale_trasmutato, raggio=5, durata=20.0, permanente=False); `debuff_stat`(stat=difesa, valore=-0.3, durata=8.0, moltiplicativo=True)

    *L'Alchemist trasmuta i materiali intorno: il terreno cambia sostanza e le armature avversarie cedono.*

    tag sinergia: crafting, invenzione, area

  - **Costrutto pesante** (`paragon_costrutto_pesante`) — costo 26 spiritualità, cooldown 45.0s. `summon`(entita_id=costrutto_titano, quantita=1, durata=45.0, comportamento=aggressivo); `buff_stat`(stat=difesa, valore=0.2, durata=45.0, moltiplicativo=True)

    *Un costrutto titanico: combatte per te mentre tu resti al riparo.*

    tag sinergia: crafting, difesa, evocazione

- Recitazione (3 azioni):

  - Trasmuta 15 volte → +0.4 (evento `ability_used`, target 15)

  - Sconfiggi 18 nemici → +0.35 (evento `enemy_defeated`, target 18)

  - Erigi 10 costrutti titanici → +0.25 (evento `ability_used`, target 10)

- Pozione: ingredienti mercurio_filosofale, crogiolo_indistruttibile, catalizzatore_proibito

- Rituale di avanzamento: luogo `['officina', 'torre_di_osservazione']`, fase lunare `None`, sacrifici ['il_tuo_strumento_migliore_distrutto_di_tua_mano']



**Sequenza 3 — Arcane Scholar** (tier `saint`)

> Unisce scienza e misticismo: incisioni che funzionano su entrambi i piani.

- Modificatori: hp_max +250, spiritualita_max +0.35

  - **Incisione duale** (`paragon_incisione_duale`) — costo 20 spiritualità, cooldown 22.0s. `buff_stat`(stat=spiritualita_max, valore=0.2, durata=15.0, moltiplicativo=True); `shield`(assorbimento=60, durata=15.0, riflette=0.2, tag_bloccati=[], bersaglio=self)

    *L'Arcane Scholar incide sigilli che funzionano su scienza E misticismo: barriera che riflette e spirito piu' saldo.*

    tag sinergia: scienza, conoscenza, difesa

  - **Sigillo ibrido** (`paragon_sigillo_ibrido`) — costo 16 spiritualità, cooldown 12.0s. `curse`(effetto=decadimento, durata=10.0, condizione_rimozione=purificazione); `debuff_stat`(stat=precisione, valore=-0.35, durata=10.0, moltiplicativo=True)

    *Un sigillo ibrido inciso sul bersaglio: si corrode e perde la mira.*

    tag sinergia: scienza, decadimento, singolo

- Recitazione (3 azioni):

  - Incidi 15 sigilli duali → +0.4 (evento `ability_used`, target 15)

  - Sconfiggi 18 nemici → +0.35 (evento `enemy_defeated`, target 18)

  - Applica 12 sigilli ibridi → +0.25 (evento `ability_used`, target 12)

- Pozione: ingredienti inchiostro_di_due_mondi, stilo_di_ossidiana, pergamena_a_doppia_faccia

- Rituale di avanzamento: luogo `['sala_dei_sigilli', 'studio']`, fase lunare `None`, sacrifici ['una_teoria_a_cui_tenevi_dimostrata_falsa_da_te_stesso']



**Sequenza 2 — Knowledge Magister** (tier `angel`)

> Infonde spirito negli oggetti creati: costrutti autonomi e permanenti.

- Modificatori: hp_max +400, spiritualita_max +0.45

  - **Costrutto vivo** (`paragon_costrutto_vivo`) — costo 55 spiritualità, cooldown 120.0s. `summon`(entita_id=costrutto_animato, quantita=2, durata=-1, comportamento=difensivo); `buff_stat`(stat=qualita_crafting, valore=0.25, durata=-1, moltiplicativo=False)

    *STRESS TEST. Stessa primitiva summon di Death con parametri diversi: la prova che il registro chiuso funziona.*

    tag sinergia: scienza, invenzione, evocazione, crafting

  - **Officina mobile** (`paragon_officina_mobile`) — costo 38 spiritualità, cooldown 90.0s. `summon`(entita_id=costrutto_autonomo, quantita=2, durata=-1, comportamento=difensivo)

    *Il Knowledge Magister infonde spirito negli oggetti: due costrutti autonomi e PERMANENTI, serializzati nel save.*

    tag sinergia: crafting, invenzione, evocazione

- Recitazione (3 azioni):

  - Anima 8 costrutti vivi → +0.4 (evento `ability_used`, target 8)

  - Sconfiggi 20 nemici coi costrutti → +0.35 (evento `enemy_defeated`, target 20)

  - Schiera 6 officine mobili → +0.25 (evento `ability_used`, target 6)

- Pozione: ingredienti nucleo_spirituale_stabile, telaio_di_precisione_assoluta, memoria_cristallizzata

- Rituale di avanzamento: luogo `['officina']`, fase lunare `None`, sacrifici ['il_primo_costrutto_che_avevi_creato_e_a_cui_ti_eri_affezionato']



**Sequenza 1 — Illuminator** (tier `angel`)

> Altera le leggi fisiche locali in un raggio.

- Modificatori: hp_max +600, spiritualita_max +0.5

  - **Campo alterato** (`paragon_campo_alterato`) — costo 34 spiritualità, cooldown 40.0s. `aura`(raggio=10, durata=-1, effetto=gravita_alterata, tick_rate=2.0, bersagli=nemici); `terrain_modify`(tipo_modifica=legge_locale_sospesa, raggio=10, durata=20.0, permanente=False)

    *L'Illuminator altera le leggi fisiche locali. SENZA rule_bind (differita): aura(gravita_alterata) + terrain_modify. Il feel resta, la manipolazione VERA delle regole resta a un Pathway differito.*

    tag sinergia: invenzione, dominio, area

  - **Dettato fisico** (`paragon_dettato_fisico`) — costo 22 spiritualità, cooldown 18.0s. `buff_stat`(stat=evasione, valore=0.3, durata=12.0, moltiplicativo=True); `buff_stat`(stat=velocita, valore=0.2, durata=12.0, moltiplicativo=True)

    *Dentro il tuo campo, riscrivi la fisica a tuo favore: piu' veloce, piu' difficile da colpire.*

    tag sinergia: invenzione, scienza, singolo

- Recitazione (3 azioni):

  - Altera le leggi locali 12 volte → +0.4 (evento `ability_used`, target 12)

  - Sconfiggi 15 nemici nel tuo campo alterato → +0.35 (evento `enemy_defeated`, target 15)

  - Detta la fisica 15 volte → +0.25 (evento `ability_used`, target 15)

- Pozione: ingredienti costante_universale_incrinata, prisma_che_devia_la_luce, numero_che_non_dovrebbe_esistere

- Rituale di avanzamento: luogo `['torre_di_osservazione', 'sala_dei_sigilli']`, fase lunare `None`, sacrifici ['ancora_del_giocatore']



**Sequenza 0 — Paragon** (tier `god`)

> La civilta' come dominio.

- Modificatori: hp_max +900, spiritualita_max +0.7, difesa +0.5

  - **Civilta come dominio** (`paragon_civilta_come_dominio`) — costo 55 spiritualità, cooldown 60.0s. `aura`(raggio=16, durata=-1, effetto=gravita_alterata, tick_rate=2.0, bersagli=nemici)

    *La civilta' come dominio: dove arriva il Paragon, le regole sono le sue.*

    tag sinergia: scienza, dominio, area

  - **Legione meccanica** (`paragon_legione_meccanica`) — costo 50 spiritualità, cooldown 50.0s. `summon`(entita_id=costrutto_legione, quantita=5, durata=40.0, comportamento=aggressivo)

    *Cinque costrutti da guerra: la civilta' che si difende da sola.*

    tag sinergia: crafting, evocazione, area

- Recitazione (3 azioni):

  - Imponi la civilta' come dominio 5 volte → +0.4 (evento `ability_used`, target 5)

  - Sconfiggi 30 nemici → +0.35 (evento `enemy_defeated`, target 30)

  - Schiera 10 legioni meccaniche → +0.25 (evento `ability_used`, target 10)

- Pozione: ingredienti progetto_del_mondo_perfetto, lega_impossibile_da_replicare, prima_ruota_mai_costruita

- Rituale di avanzamento: luogo `['biblioteca_di_tutto']`, fase lunare `eclissi`, sacrifici ['il_detentore_precedente_della_sequenza_0']





## Gruppo Goddess of Origin

### Moon (`moon`)

*Domare bestie, evocare e distillare pozioni potenti*

- god_title: Moon · tag: pozione, bestia, evocazione, sangue



**Sequenza 9 — Apothecary** (tier `low`)

> Pozioni di base ed erboristeria: la porta d'ingresso all'alchimia.

- Modificatori: hp_max +20, spiritualita_max +0.1

  - **Distillato curativo** (`moon_distillato_curativo`) — costo 5 spiritualità, cooldown 8.0s. `heal`(quantita=25, istantaneo=True, bersaglio=self)

    *La prima pozione dell'Apothecary: un sorso e la ferita si chiude.*

    tag sinergia: pozione, guarigione, singolo

  - **Tonico alle erbe** (`moon_tonico_erbe`) — costo 6 spiritualità, cooldown 14.0s. `buff_stat`(stat=precisione, valore=5, durata=10.0, moltiplicativo=False); `buff_stat`(stat=velocita, valore=0.08, durata=10.0, moltiplicativo=True)

    *Erboristeria di base: mano ferma e passo svelto per qualche istante.*

    tag sinergia: pozione, agilita', singolo

- Recitazione (3 azioni):

  - Distilla 20 pozioni curative → +0.4 (evento `ability_used`, target 20)

  - Prepara 15 tonici alle erbe → +0.35 (evento `ability_used`, target 15)

  - Sconfiggi 10 nemici mentre impari il mestiere → +0.25 (evento `enemy_defeated`, target 10)

- Pozione: ingredienti radice_di_valeriana, rugiada_notturna, fiore_di_luna



**Sequenza 8 — Beast Tamer** (tier `low`)

> Doma le bestie: il primo pet permanente del gioco.

- Modificatori: hp_max +35, spiritualita_max +0.12

  - **Richiamo del compagno** (`moon_richiamo_compagno`) — costo 10 spiritualità, cooldown 25.0s. `summon`(entita_id=bestia_compagna, quantita=1, durata=40.0, comportamento=difensivo)

    *Il Beast Tamer chiama una bestia al fianco. La doma PERMANENTE del pet passa per PetSystem (fase 3); questa e' un compagno a tempo.*

    tag sinergia: bestia, evocazione, singolo

  - **Legame bestiale** (`moon_legame_bestiale`) — costo 7 spiritualità, cooldown 16.0s. `buff_stat`(stat=difesa, valore=0.15, durata=12.0, moltiplicativo=True); `heal`(quantita=4, istantaneo=False, durata=12.0, bersaglio=self)

    *Il legame con la bestia protegge e cura chi lo tiene.*

    tag sinergia: bestia, difesa, guarigione

- Recitazione (3 azioni):

  - Chiama un compagno bestiale 15 volte → +0.4 (evento `ability_used`, target 15)

  - Sconfiggi 15 nemici con una bestia al fianco → +0.35 (evento `enemy_defeated`, target 15)

  - Rinsalda il legame 10 volte → +0.25 (evento `ability_used`, target 10)

- Pozione: ingredienti pelo_di_lupo_bianco, zanna_di_latte, sangue_di_cervo



**Sequenza 7 — Vampire** (tier `low`)

> Drena sangue, rigenera e guadagna forza di notte.

- Modificatori: hp_max +55, forza +5

  - **Morso** (`moon_morso`) — costo 8 spiritualità, cooldown 6.0s. `debuff_stat`(stat=forza, valore=-0.3, durata=8.0, moltiplicativo=True); `heal`(quantita=20, istantaneo=True, bersaglio=self)

    *Il Vampiro morde: il nemico si indebolisce, tu ti rigeneri.*

    tag sinergia: sangue, bestia, singolo

  - **Furia notturna** (`moon_furia_notturna`) — costo 9 spiritualità, cooldown 20.0s. `buff_stat`(stat=forza, valore=0.25, durata=10.0, moltiplicativo=True)

    *Di notte il sangue del Vampiro ribolle: forza in piu', ma solo al buio.*

    tag sinergia: sangue, notte, forza

- Recitazione (3 azioni):

  - Mordi 25 volte → +0.4 (evento `ability_used`, target 25)

  - Infliggi 3000 danni → +0.35 (evento `damage_dealt`, target 3000)

  - Scatena la furia notturna 12 volte → +0.25 (evento `ability_used`, target 12)

- Pozione: ingredienti sangue_rappreso, petalo_di_belladonna, argento_annerito



**Sequenza 6 — Potions Professor** (tier `mid`)

> Pozioni avanzate con qualita' superiore e effetti combinati.

- Modificatori: hp_max +90, spiritualita_max +0.25

  - **Elisir superiore** (`moon_elisir_superiore`) — costo 12 spiritualità, cooldown 16.0s. `heal`(quantita=20, istantaneo=False, durata=8.0, bersaglio=self); `buff_stat`(stat=difesa, valore=0.2, durata=8.0, moltiplicativo=True)

    *Pozioni avanzate: cura nel tempo e protezione insieme.*

    tag sinergia: pozione, guarigione, difesa

  - **Veleno raffinato** (`moon_veleno_raffinato`) — costo 10 spiritualità, cooldown 10.0s. `dot`(danno_tick=12, tick_rate=1.0, durata=8.0, tag_danno=veleno); `debuff_stat`(stat=precisione, valore=-0.3, durata=8.0, moltiplicativo=True)

    *Il Potions Professor conosce anche i veleni: colpo lento, effetto duraturo.*

    tag sinergia: pozione, decadimento, singolo

- Recitazione (3 azioni):

  - Prepara 15 elisir superiori → +0.4 (evento `ability_used`, target 15)

  - Infliggi 3500 danni da veleno → +0.35 (evento `damage_dealt`, target 3500)

  - Raffina 15 veleni → +0.25 (evento `ability_used`, target 15)

- Pozione: ingredienti ambra_grigia, fiala_di_luna_piena, muschio_di_caverna



**Sequenza 5 — Scarlet Scholar** (tier `mid`)

> Sangue come materiale rituale: potenzia i rituali di avanzamento.

- Modificatori: hp_max +130, forza +8

  - **Patto di sangue** (`moon_patto_di_sangue`) — costo 14 spiritualità, cooldown 18.0s. `buff_stat`(stat=forza, valore=0.3, durata=12.0, moltiplicativo=True); `debuff_stat`(stat=hp_max, valore=-0.15, durata=12.0, moltiplicativo=True)

    *Lo Scarlet Scholar versa il proprio sangue: piu' forte, ma piu' fragile.*

    tag sinergia: sangue, forza, rituale

  - **Richiamo scarlatto** (`moon_richiamo_scarlatto`) — costo 16 spiritualità, cooldown 26.0s. `summon`(entita_id=bestia_di_sangue, quantita=2, durata=30.0, comportamento=aggressivo)

    *Bestie evocate dal sangue versato: feroci, ma di breve durata.*

    tag sinergia: sangue, bestia, evocazione

- Recitazione (3 azioni):

  - Sigilla 15 patti di sangue → +0.4 (evento `ability_used`, target 15)

  - Sconfiggi 18 nemici → +0.35 (evento `enemy_defeated`, target 18)

  - Subisci 3000 danni: il prezzo del sangue → +0.25 (evento `damage_taken`, target 3000)

- Pozione: ingredienti calice_incrinato, sale_scarlatto, radice_di_ferro_lunare



**Sequenza 4 — Shaman King** (tier `saint`)

> Comanda branchi e spiriti bestiali; il pet acquisisce un branco.

- Modificatori: hp_max +200, spiritualita_max +0.4

  - **Convoca il branco** (`moon_convoca_branco`) — costo 24 spiritualità, cooldown 40.0s. `summon`(entita_id=bestia_branco, quantita=4, durata=45.0, comportamento=aggressivo); `buff_stat`(stat=velocita, valore=0.15, durata=45.0, moltiplicativo=True)

    *Lo Shaman King chiama il branco: quattro bestie e la corsa condivisa.*

    tag sinergia: bestia, evocazione, area

  - **Spirito totem** (`moon_spirito_totem`) — costo 30 spiritualità, cooldown 60.0s. `aura`(raggio=12, durata=-1, effetto=decadimento, tick_rate=2.0, bersagli=nemici)

    *Uno spirito-totem piantato nel terreno: consuma i nemici che gli si avvicinano finche' lo Shaman vive.*

    tag sinergia: bestia, dominio, area

- Recitazione (3 azioni):

  - Convoca il branco 12 volte → +0.4 (evento `ability_used`, target 12)

  - Sconfiggi 25 nemici col branco → +0.35 (evento `enemy_defeated`, target 25)

  - Pianta 8 spiriti-totem → +0.25 (evento `ability_used`, target 8)

- Pozione: ingredienti corno_di_alce_spettrale, pietra_di_marea, fiore_che_sboccia_solo_di_notte

- Rituale di avanzamento: luogo `['radura_lunare', 'grotta_di_marea']`, fase lunare `piena`, sacrifici ['sangue_del_giocatore', 'un_pelo_del_tuo_pet']



**Sequenza 3 — High Summoner** (tier `saint`)

> Evoca creature da grande distanza, anche mai incontrate.

- Modificatori: hp_max +260, spiritualita_max +0.35

  - **Evocazione remota** (`moon_evocazione_remota`) — costo 48 spiritualità, cooldown 80.0s. `summon`(entita_id=bestia_remota, quantita=1, durata=180.0, comportamento=legame_pet); `buff_stat`(stat=bond_pet, valore=0.15, durata=180.0, moltiplicativo=False)

    *STRESS TEST. Aggancio diretto al sistema pet tramite lo stat bond_pet.*

    tag sinergia: bestia, evocazione, pozione, singolo

  - **Chiamata lontana** (`moon_chiamata_lontana`) — costo 20 spiritualità, cooldown 24.0s. `summon`(entita_id=bestia_ignota, quantita=2, durata=35.0, comportamento=aggressivo); `buff_stat`(stat=spiritualita_max, valore=0.1, durata=35.0, moltiplicativo=True)

    *La High Summoner chiama creature che non ha mai incontrato, da lontano. Materia prima: la distanza (matrice di proprieta').*

    tag sinergia: bestia, evocazione, area

- Recitazione (3 azioni):

  - Evoca da remoto 15 volte → +0.4 (evento `ability_used`, target 15)

  - Chiama creature ignote 12 volte → +0.35 (evento `ability_used`, target 12)

  - Sconfiggi 20 nemici con creature evocate → +0.25 (evento `enemy_defeated`, target 20)

- Pozione: ingredienti seme_di_stella_cadente, voce_di_creatura_mai_vista, filo_d_argento_lunare

- Rituale di avanzamento: luogo `['grotta_di_marea', 'bosco_antico']`, fase lunare `crescente`, sacrifici ['il_richiamo_di_un_amico_che_non_verra_piu']



**Sequenza 2 — Life-Giver** (tier `angel`)

> Dona vita: crea creature durature che coltivano insieme al giocatore.

- Modificatori: hp_max +380, spiritualita_max +0.45

  - **Creatura vivente** (`moon_creatura_vivente`) — costo 34 spiritualità, cooldown 90.0s. `summon`(entita_id=bestia_custode, quantita=1, durata=-1, comportamento=coltivatore)

    *La Life-Giver crea un essere che dura e coltiva insieme al giocatore. comportamento 'coltivatore': l'aggancio a giardino/BaseSystem e' dati, non codice.*

    tag sinergia: bestia, crescita, evocazione

  - **Dono della vita** (`moon_dono_della_vita`) — costo 22 spiritualità, cooldown 30.0s. `heal`(quantita=60, istantaneo=True, bersaglio=self); `buff_stat`(stat=hp_max, valore=0.1, durata=15.0, moltiplicativo=True)

    *Dona vita: una cura piena e un aumento momentaneo della resistenza.*

    tag sinergia: crescita, guarigione, singolo

- Recitazione (3 azioni):

  - Crea 8 esseri viventi duraturi → +0.4 (evento `ability_used`, target 8)

  - Sconfiggi 20 nemici → +0.35 (evento `enemy_defeated`, target 20)

  - Dona vita 12 volte → +0.25 (evento `ability_used`, target 12)

- Pozione: ingredienti goccia_di_prima_pioggia, cuore_di_quercia_madre, luce_di_luna_imbottigliata

- Rituale di avanzamento: luogo `['sorgente', 'altare_di_radici']`, fase lunare `crescente`, sacrifici ['una_creatura_che_avevi_evocato_e_amato']



**Sequenza 1 — Beauty Goddess** (tier `angel`)

> Fascino assoluto: dominio sui viventi senza combattimento.

- Modificatori: hp_max +550, spiritualita_max +0.5

  - **Fascino assoluto** (`moon_fascino_assoluto`) — costo 30 spiritualità, cooldown 18.0s. `curse`(effetto=affascinato, durata=12.0, condizione_rimozione=purificazione); `debuff_stat`(stat=forza, valore=-0.4, durata=12.0, moltiplicativo=True)

    *La Beauty Goddess incanta: il bersaglio non ti attacca piu' e combatte distratto. Dominio sui viventi SENZA combattimento. Non e' possess (Fool).*

    tag sinergia: mente, dominio, singolo

  - **Corte incantata** (`moon_corte_incantata`) — costo 40 spiritualità, cooldown 70.0s. `aura`(raggio=10, durata=-1, effetto=affascinato, tick_rate=3.0, bersagli=nemici)

    *Un raggio di fascino permanente: chi entra e' incantato finche' la Dea vive.*

    tag sinergia: mente, dominio, area

- Recitazione (3 azioni):

  - Incanta 15 bersagli → +0.4 (evento `ability_used`, target 15)

  - Sconfiggi 12 nemici senza che ti tocchino → +0.35 (evento `enemy_defeated`, target 12)

  - Tieni una corte incantata 6 volte → +0.25 (evento `ability_used`, target 6)

- Pozione: ingredienti specchio_di_luna_nera, rosa_che_non_appassisce, lacrima_di_amante

- Rituale di avanzamento: luogo `['radura_lunare']`, fase lunare `piena`, sacrifici ['ancora_del_giocatore']



**Sequenza 0 — Moon** (tier `god`)

> La luna come dominio.

- Modificatori: hp_max +850, spiritualita_max +0.7

  - **Dominio lunare** (`moon_dominio_lunare`) — costo 55 spiritualità, cooldown 60.0s. `aura`(raggio=16, durata=-1, effetto=affascinato, tick_rate=2.0, bersagli=nemici)

    *La luna come dominio: tutto cio' che le sta sotto e' incantato.*

    tag sinergia: mente, dominio, area

  - **Marea di bestie** (`moon_marea_di_bestie`) — costo 50 spiritualità, cooldown 50.0s. `summon`(entita_id=bestia_marea, quantita=6, durata=40.0, comportamento=aggressivo)

    *Sei bestie da ogni direzione, come la marea che sale.*

    tag sinergia: bestia, evocazione, area

- Recitazione (3 azioni):

  - Imponi il dominio lunare 5 volte → +0.4 (evento `ability_used`, target 5)

  - Sconfiggi 30 nemici → +0.35 (evento `enemy_defeated`, target 30)

  - Scatena la marea di bestie 10 volte → +0.25 (evento `ability_used`, target 10)

- Pozione: ingredienti frammento_di_luna, respiro_dell_oceano, prima_notte_del_mondo

- Rituale di avanzamento: luogo `['radice_del_mondo']`, fase lunare `eclissi`, sacrifici ['il_detentore_precedente_della_sequenza_0']





### Mother (`mother`)

*Far crescere piante, curare e creare chimere*

- god_title: Mother · tag: crescita, terra, guarigione, genetica



**Sequenza 9 — Planter** (tier `low`)

> Coltiva e accelera la crescita delle piante; base del ciclo ingredienti.

- Modificatori: hp_max +25, spiritualita_max +0.1

  - **Germoglio rapido** (`mother_germoglio_rapido`) — costo 5 spiritualità, cooldown 8.0s. `plant_growth`(raggio=4, specie=rampicante_utile, velocita=3.0, persistente=False)

    *Il Planter accelera la crescita: rampicanti in pochi secondi dove serve.*

    tag sinergia: crescita, terra, area

  - **Mano verde** (`mother_mano_verde`) — costo 6 spiritualità, cooldown 14.0s. `heal`(quantita=5, istantaneo=False, durata=15.0, bersaglio=self); `buff_stat`(stat=velocita, valore=0.05, durata=15.0, moltiplicativo=True)

    *La linfa che scorre nelle vene: cura lenta e passo piu' svelto.*

    tag sinergia: crescita, guarigione, singolo

- Recitazione (3 azioni):

  - Fai germogliare 20 volte → +0.4 (evento `ability_used`, target 20)

  - Usa la mano verde 15 volte → +0.35 (evento `ability_used`, target 15)

  - Sconfiggi 10 nemici imparando il ciclo → +0.25 (evento `enemy_defeated`, target 10)

- Pozione: ingredienti seme_dormiente, terriccio_di_prima_luna, goccia_di_linfa



**Sequenza 8 — Doctor** (tier `low`)

> Cura le ferite e diagnostica veleni e maledizioni.

- Modificatori: hp_max +40, spiritualita_max +0.12

  - **Diagnosi** (`mother_diagnosi`) — costo 7 spiritualità, cooldown 12.0s. `light_purify`(raggio=3, potenza=2, riduce_sequenza=False)

    *Il Doctor diagnostica e rimuove: veleni e maledizioni via, fino a 2 effetti.*

    tag sinergia: guarigione, purificazione, singolo

  - **Sutura** (`mother_sutura`) — costo 8 spiritualità, cooldown 10.0s. `heal`(quantita=35, istantaneo=True, bersaglio=self)

    *Una sutura pulita: la ferita si chiude subito.*

    tag sinergia: guarigione, singolo

- Recitazione (3 azioni):

  - Diagnostica 18 volte → +0.4 (evento `ability_used`, target 18)

  - Sutura 15 ferite → +0.35 (evento `ability_used`, target 15)

  - Subisci 700 danni e curati → +0.25 (evento `damage_taken`, target 700)

- Pozione: ingredienti corteccia_febbrifuga, fiore_di_camomilla_selvatica, radice_amara



**Sequenza 7 — Harvest Priest** (tier `low`)

> Benedice i raccolti e rigenera un'area viva intorno a se'.

- Modificatori: hp_max +55, spiritualita_max +0.15

  - **Benedizione del raccolto** (`mother_benedizione_raccolto`) — costo 11 spiritualità, cooldown 22.0s. `aura`(raggio=8, durata=20.0, effetto=area_viva, tick_rate=2.0, bersagli=alleati)

    *Lo Harvest Priest benedice il terreno: chi vi sta sopra si rigenera.*

    tag sinergia: crescita, guarigione, area

  - **Terra generosa** (`mother_terra_generosa`) — costo 13 spiritualità, cooldown 30.0s. `plant_growth`(raggio=6, specie=campo_fiorito, velocita=2.0, persistente=True)

    *Un campo fiorito che RESTA: la terra rigenerata entra nello stato del mondo (come i varchi permanenti del Twilight Giant).*

    tag sinergia: crescita, terra, area

- Recitazione (3 azioni):

  - Benedici il raccolto 15 volte → +0.4 (evento `ability_used`, target 15)

  - Rendi generosa la terra 12 volte → +0.35 (evento `ability_used`, target 12)

  - Assorbi 400 danni diretti agli alleati → +0.25 (evento `damage_absorbed_for_ally`, target 400)

- Pozione: ingredienti spiga_dorata, miele_selvatico, acqua_di_fonte_benedetta



**Sequenza 6 — Biologist** (tier `mid`)

> Modifica le creature: innesti e primi ibridi.

- Modificatori: hp_max +95, spiritualita_max +0.25

  - **Innesto** (`mother_innesto`) — costo 13 spiritualità, cooldown 22.0s. `summon`(entita_id=chimera_semplice, quantita=1, durata=35.0, comportamento=difensivo); `buff_stat`(stat=difesa, valore=0.15, durata=35.0, moltiplicativo=True)

    *Il Biologist innesta: una chimera semplice al fianco. Materia prima: ingredienti vivi (matrice di proprieta').*

    tag sinergia: genetica, bestia, difesa

  - **Mutazione rapida** (`mother_mutazione_rapida`) — costo 10 spiritualità, cooldown 10.0s. `debuff_stat`(stat=velocita, valore=-0.35, durata=8.0, moltiplicativo=True); `dot`(danno_tick=8, tick_rate=1.5, durata=8.0, tag_danno=veleno)

    *Innesca una mutazione ostile: il bersaglio rallenta e si corrompe.*

    tag sinergia: genetica, decadimento, singolo

- Recitazione (3 azioni):

  - Innesta 15 chimere → +0.4 (evento `ability_used`, target 15)

  - Infliggi 3000 danni da veleno → +0.35 (evento `damage_dealt`, target 3000)

  - Sconfiggi 15 nemici → +0.25 (evento `enemy_defeated`, target 15)

- Pozione: ingredienti cellula_madre, enzima_dormiente, fungo_a_specchio



**Sequenza 5 — Druid** (tier `mid`)

> Comanda la vegetazione come arma e come terreno: terraforming tattico.

- Modificatori: hp_max +135, forza +8

  - **Dominio druidico** (`mother_dominio_druidico`) — costo 40 spiritualità, cooldown 45.0s. `plant_growth`(raggio=9, specie=rampicante_ostile, velocita=3.0, persistente=True); `terrain_modify`(tipo_modifica=terreno_vivo, raggio=9, durata=30.0, permanente=False); `dot`(danno_tick=8, tick_rate=1.0, durata=30.0, tag_danno=veleno)

    *STRESS TEST. Tre primitive composte per il terraforming tattico. Nessuna nuova.*

    tag sinergia: crescita, terra, area, disastro

  - **Muraglia di rovi** (`mother_muraglia_di_rovi`) — costo 15 spiritualità, cooldown 18.0s. `plant_growth`(raggio=5, specie=rovi_taglienti, velocita=4.0, persistente=False); `terrain_modify`(tipo_modifica=terreno_impraticabile, raggio=5, durata=15.0, permanente=False)

    *Il Druido alza una muraglia di rovi: terreno impraticabile per 15 secondi.*

    tag sinergia: crescita, terra, area

- Recitazione (3 azioni):

  - Domina il terreno 12 volte → +0.4 (evento `ability_used`, target 12)

  - Alza 15 muraglie di rovi → +0.35 (evento `ability_used`, target 15)

  - Sconfiggi 18 nemici col terreno come arma → +0.25 (evento `enemy_defeated`, target 18)

- Pozione: ingredienti ghianda_millenaria, spina_di_rovo_antico, muschio_luminoso



**Sequenza 4 — Classical Alchemist** (tier `saint`)

> Alchimia della vita: omuncoli e materiali organici artificiali.

- Modificatori: hp_max +210, spiritualita_max +0.4

  - **Omuncolo** (`mother_omuncolo`) — costo 24 spiritualità, cooldown 40.0s. `summon`(entita_id=chimera_omuncolo, quantita=2, durata=40.0, comportamento=aggressivo)

    *Il Classical Alchemist forgia omuncoli da materia organica. entita_id chimera_: la fonte e' dichiarata.*

    tag sinergia: genetica, bestia, evocazione

  - **Materia vivente** (`mother_materia_vivente`) — costo 18 spiritualità, cooldown 26.0s. `heal`(quantita=45, istantaneo=True, bersaglio=self); `buff_stat`(stat=hp_max, valore=0.12, durata=15.0, moltiplicativo=True)

    *Trasmuta materia inerte in tessuto vivo: cura piena e corpo piu' saldo.*

    tag sinergia: genetica, guarigione, singolo

- Recitazione (3 azioni):

  - Forgia 12 omuncoli → +0.4 (evento `ability_used`, target 12)

  - Sconfiggi 20 nemici con le tue creazioni → +0.35 (evento `enemy_defeated`, target 20)

  - Trasmuta materia viva 12 volte → +0.25 (evento `ability_used`, target 12)

- Pozione: ingredienti sale_della_vita, argilla_rossa_del_fiume, seme_dell_albero_madre

- Rituale di avanzamento: luogo `['bosco_antico', 'sorgente']`, fase lunare `None`, sacrifici ['un_organo_donato_da_un_alleato_consenziente']



**Sequenza 3 — Pallbearer** (tier `saint`)

> Drena forza vitale dai nemici e dall'ambiente, restituendola alla terra.

- Modificatori: hp_max +250, spiritualita_max +0.35

  - **Drenaggio vitale** (`mother_drenaggio_vitale`) — costo 20 spiritualità, cooldown 12.0s. `dot`(danno_tick=15, tick_rate=1.0, durata=8.0, tag_danno=decadimento); `heal`(quantita=30, istantaneo=True, bersaglio=self)

    *Il Pallbearer drena la forza vitale del nemico e la restituisce a se'.*

    tag sinergia: crescita, decadimento, singolo

  - **Restituzione** (`mother_restituzione`) — costo 18 spiritualità, cooldown 24.0s. `aura`(raggio=10, durata=15.0, effetto=area_viva, tick_rate=2.0, bersagli=alleati); `heal`(quantita=5, istantaneo=False, durata=15.0, bersaglio=self)

    *Quello che si drena si restituisce alla terra e a chi vi cammina.*

    tag sinergia: crescita, guarigione, area

- Recitazione (3 azioni):

  - Drena 15 volte → +0.4 (evento `ability_used`, target 15)

  - Sconfiggi 20 nemici restituendo alla terra → +0.35 (evento `enemy_defeated`, target 20)

  - Infliggi 5000 danni da decadimento → +0.25 (evento `damage_dealt`, target 5000)

- Pozione: ingredienti cenere_di_bosco, radice_che_beve, ultima_foglia_dell_autunno

- Rituale di avanzamento: luogo `['altare_di_radici', 'luogo_in_decadenza']`, fase lunare `calante`, sacrifici ['la_forza_vitale_di_un_bosco_che_hai_fatto_crescere']



**Sequenza 2 — Desolate Matriarch** (tier `angel`)

> Crea esseri viventi da zero: chimere su misura per il giocatore.

- Modificatori: hp_max +400, spiritualita_max +0.45

  - **Chimera su misura** (`mother_chimera_su_misura`) — costo 36 spiritualità, cooldown 90.0s. `summon`(entita_id=chimera_su_misura, quantita=1, durata=-1, comportamento=aggressivo)

    *La Desolate Matriarch crea esseri viventi da zero, su misura. durata -1: la chimera resta, entra nel save.*

    tag sinergia: genetica, bestia, evocazione

  - **Madre dei mostri** (`mother_madre_dei_mostri`) — costo 30 spiritualità, cooldown 45.0s. `buff_stat`(stat=spiritualita_max, valore=0.2, durata=20.0, moltiplicativo=True); `summon`(entita_id=chimera_prole, quantita=3, durata=30.0, comportamento=aggressivo)

    *Una nidiata di prole: tre chimere e la forza spirituale per comandarle.*

    tag sinergia: genetica, evocazione, area

- Recitazione (3 azioni):

  - Crea 8 chimere su misura → +0.4 (evento `ability_used`, target 8)

  - Sconfiggi 20 nemici con la prole → +0.35 (evento `enemy_defeated`, target 20)

  - Genera 10 nidiate → +0.25 (evento `ability_used`, target 10)

- Pozione: ingredienti placenta_di_pietra, codice_della_vita_inciso, sangue_di_ogni_bestia

- Rituale di avanzamento: luogo `['bosco_antico']`, fase lunare `nuova`, sacrifici ['una_delle_tue_chimere_persistenti']



**Sequenza 1 — Naturewalker** (tier `angel`)

> La natura risponde ai suoi comandi senza bisogno di rituali.

- Modificatori: hp_max +600, forza +12, difesa +0.3

  - **La natura risponde** (`mother_natura_risponde`) — costo 32 spiritualità, cooldown 16.0s. `terrain_modify`(tipo_modifica=terreno_vivo, raggio=8, durata=20.0, permanente=False); `buff_stat`(stat=forza, valore=0.3, durata=20.0, moltiplicativo=True)

    *La Naturewalker non comanda la natura con rituali: le basta chiedere. Il terreno si anima e la rende piu' forte.*

    tag sinergia: terra, forza, area

  - **Camminatrice** (`mother_camminatrice`) — costo 20 spiritualità, cooldown 22.0s. `heal`(quantita=8, istantaneo=False, durata=20.0, bersaglio=self); `buff_stat`(stat=velocita, valore=0.15, durata=20.0, moltiplicativo=True)

    *Camminare nel bosco cura: la Naturewalker non si ferma mai a lungo.*

    tag sinergia: crescita, guarigione, singolo

  - **Benedizione della Covata** (`mother_benedizione_della_covata`) — costo 28 spiritualità, cooldown 30.0s. `aura`(raggio=8, durata=-1, effetto=area_viva, tick_rate=2.0, bersagli=evocati)

    *US-714. La Naturewalker benedice cio' che ha generato: aura(area_viva) su bersagli 'evocati', stesso effetto gia' usato dal terreno benedetto dell'Harvest Priest (US-714 lo riusa).*

    tag sinergia: crescita, guarigione, evocazione

- Recitazione (3 azioni):

  - Fai rispondere la natura 15 volte → +0.4 (evento `ability_used`, target 15)

  - Sconfiggi 15 nemici col terreno che ti obbedisce → +0.35 (evento `enemy_defeated`, target 15)

  - Cammina e curati 12 volte → +0.25 (evento `ability_used`, target 12)

- Pozione: ingredienti polline_dorato, spina_dell_ultimo_inverno, radice_maestra

- Rituale di avanzamento: luogo `['bosco_antico', 'sorgente']`, fase lunare `None`, sacrifici ['ancora_del_giocatore']



**Sequenza 0 — Mother** (tier `god`)

> La terra come dominio.

- Modificatori: hp_max +900, difesa +0.6, spiritualita_max +0.7

  - **Dominio della terra** (`mother_dominio_della_terra`) — costo 55 spiritualità, cooldown 60.0s. `aura`(raggio=16, durata=-1, effetto=decadimento, tick_rate=2.0, bersagli=nemici)

    *La terra come dominio: tutto cio' che le si oppone marcisce.*

    tag sinergia: terra, dominio, area

  - **Rinascita** (`mother_rinascita`) — costo 50 spiritualità, cooldown 50.0s. `heal`(quantita=150, istantaneo=True, bersaglio=self); `plant_growth`(raggio=12, specie=eden, velocita=5.0, persistente=True)

    *Dove passa, un giardino. La rinascita e' permanente: entra nel mondo.*

    tag sinergia: crescita, guarigione, terra

- Recitazione (3 azioni):

  - Imponi il dominio della terra 5 volte → +0.4 (evento `ability_used`, target 5)

  - Sconfiggi 30 nemici → +0.35 (evento `enemy_defeated`, target 30)

  - Fai rinascere un eden 10 volte → +0.25 (evento `ability_used`, target 10)

- Pozione: ingredienti seme_del_primo_giorno, respiro_della_foresta_del_mondo, cuore_del_pianeta

- Rituale di avanzamento: luogo `['radice_del_mondo']`, fase lunare `eclissi`, sacrifici ['il_detentore_precedente_della_sequenza_0']





## Pathway Non-Standard: Eternal Aeon

Categoria `non_standard` — avanza ricevendo **Boon** da un'entità invece di bere pozioni (`BoonSystem`, fase 9). god_title: Eternal Aeon. tag: tempo, conoscenza, destino, spirito, occulto.


### Eternal Aeon (`eternal_aeon`)

*Servire un patto con un'entita' che esiste fuori dal tempo, ricevendo doni in cambio di prove di fedelta'*

- god_title: Eternal Aeon · tag: tempo, conoscenza, destino, spirito, occulto



**Sequenza 9 — Vigilant** (tier `low`)

> Il giocatore impara a percepire il ritmo nascosto degli scontri: parate perfette ripetute rivelano schemi che si ripetono all'infinito.

- Modificatori: spiritualita_max +0.08, evasione +0.04

  - **Eco del colpo** (`ea_eco_del_colpo`) — costo 8 spiritualità, cooldown 10.0s. `shield`(assorbimento=25, durata=4.0, riflette=0.0, tag_bloccati=[], bersaglio=self)

    *Per un istante il colpo e' gia' accaduto: lo si e' visto, e non fa piu' male allo stesso modo.*

    tag sinergia: tempo, difesa, singolo

- Boon (1 requisiti): `comportamento`



**Sequenza 8 — Witness** (tier `low`)

> Il giocatore resta esposto alla notte senza cedere, e cede un piccolo oggetto legato al tempo in cambio della prossima Sequenza.

- Modificatori: spiritualita_max +0.1, precisione +0.05

  - **Respiro immutabile** (`ea_respiro_immutabile`) — costo 10 spiritualità, cooldown 14.0s. `heal`(quantita=20, istantaneo=False, durata=10.0, bersaglio=self)

    *Chi impara a restare fermo abbastanza a lungo guarisce come guarisce la pietra: piano, ma senza fretta.*

    tag sinergia: tempo, spirito, singolo

- Boon (2 requisiti): `comportamento`; `sacrificio`



**Sequenza 7 — Archivist** (tier `low`)

> Il giocatore lascia una traccia concreta nel mondo (un oggetto prodotto) e dimostra di saper gia' usare il primo dono ricevuto.

- Modificatori: spiritualita_max +0.12, evasione +0.06

  - **Pagina ritrovata** (`ea_pagina_ritrovata`) — costo 12 spiritualità, cooldown 16.0s. `reveal_info`(raggio=8.0, categoria=eco_del_passato, durata=6.0)

    *L'Archivista non inventa: legge quel che e' gia' stato scritto nel luogo, un'eco alla volta.*

    tag sinergia: conoscenza, tempo, area

- Boon (2 requisiti): `quest`; `comportamento`



**Sequenza 6 — Cycle Warden** (tier `mid`)

> Il giocatore paga con la propria lucidita' il diritto di toccare un istante gia' passato e riportarlo indietro.

- Modificatori: spiritualita_max +0.15, precisione +0.07

  - **Richiamo del momento perduto** (`ea_richiamo_del_momento_perduto`) — costo 18 spiritualità, cooldown 24.0s. `time_rewind`(secondi=2.0, ripristina=['hp'], costo_follia=3.0)

    *Riavvolge se stesso di 2 secondi: l'hp torna a com'era. Il prezzo, come sempre con l'Aeon, e' un poco di se'.*

    tag sinergia: tempo, singolo

- Boon (1 requisiti): `sacrificio`



**Sequenza 5 — Silent Oracle** (tier `mid`)

> Il giocatore dimostra di non usare il proprio potere per incutere paura, padroneggia il dono del ciclo precedente, e cede un ricordo per vedere piu' lontano: tutte e tre le fonti insieme.

- Modificatori: spiritualita_max +0.18, evasione +0.08

  - **Sguardo che non dimentica** (`ea_sguardo_che_non_dimentica`) — costo 14 spiritualità, cooldown 18.0s. `mind_read`(raggio=10, profondita=4, rivela=intento_immediato, categoria=intento_immediato)

    *L'Oracolo Silente non chiede: vede l'intenzione un istante prima che diventi un gesto.*

    tag sinergia: conoscenza, mente, area

- Boon (3 requisiti): `quest`; `comportamento`; `sacrificio`



**Sequenza 4 — Unbound Scribe** (tier `saint`)

> Il giocatore scrive un verso che il bersaglio non riesce a cancellare: una prova di controllo sulla narrazione altrui, non solo sulla propria.

- Modificatori: spiritualita_max +0.22, hp_max +100

  - **Verso che lega** (`ea_verso_che_lega`) — costo 22 spiritualità, cooldown 24.0s. `curse`(effetto=destino_segnato, durata=18.0, condizione_rimozione=purificazione)

    *Un verso scritto sul bersaglio non e' una minaccia: e' un fatto che deve ancora accadere (status 'destino_segnato', gia' in data/status_effects.json).*

    tag sinergia: conoscenza, destino, singolo

- Boon (1 requisiti): `comportamento`



**Sequenza 3 — Voice of the Aeon** (tier `saint`)

> Il giocatore presta la gola all'Aeon per un istante: chi ascolta sente una voce che non dovrebbe esistere.

- Modificatori: spiritualita_max +0.26, hp_max +140, precisione +0.08

  - **Voce che non dovrebbe esistere** (`ea_voce_che_non_dovrebbe_esistere`) — costo 26 spiritualità, cooldown 22.0s. `fear`(raggio=8, durata=6.0, soglia_resistenza=4)

    *Per un istante non parla piu' il giocatore: parla qualcosa che ha visto ogni fine possibile.*

    tag sinergia: conoscenza, spirito, area

- Boon (2 requisiti): `quest`; `sacrificio`



**Sequenza 2 — Herald Eternal** (tier `angel`)

> Il giocatore attraversa lo spazio come l'Aeon attraversa il tempo: il messaggio arriva prima del messaggero.

- Modificatori: spiritualita_max +0.32, hp_max +220, evasione +0.1

  - **Messaggio senza distanza** (`ea_messaggio_senza_distanza`) — costo 28 spiritualità, cooldown 24.0s. `teleport`(distanza=350, richiede_visuale=False, porta_alleati=False)

    *L'Araldo non copre la distanza: la cancella, come l'Aeon cancella l'attesa.*

    tag sinergia: tempo, spazio, singolo

- Boon (1 requisiti): `quest`



**Sequenza 1 — Aeon-Touched** (tier `angel`)

> Il giocatore non distingue piu' il proprio ricordo da quello dell'Aeon: il corpo resta indietro per un momento, e cio' che si muove non e' piu' soltanto umano.

- Modificatori: spiritualita_max +0.4, hp_max +350, precisione +0.12

  - **Distacco dal presente** (`ea_distacco_dal_presente`) — costo 32 spiritualità, cooldown 30.0s. `soul_detach`(durata=10.0, vulnerabilita_corpo=0.5, velocita=1.5)

    *Il corpo resta indietro per un momento, e cio' che si muove non e' piu' soltanto umano.*

    tag sinergia: tempo, spirito, singolo

- Boon (2 requisiti): `comportamento`; `sacrificio`



**Sequenza 0 — Eternal Aeon** (tier `god`)

> Il giocatore diventa un aspetto vivente dell'Aeon stesso: puo' richiamare indietro cio' che il tempo aveva gia' reclamato, al prezzo piu' alto che l'Aeon abbia mai chiesto.

- Modificatori: spiritualita_max +0.55, hp_max +600, evasione +0.15, precisione +0.15

  - **Ritorno che non dovrebbe essere** (`ea_ritorno_che_non_dovrebbe_essere`) — costo 50 spiritualità, cooldown 55.0s. `resurrect`(bersaglio=alleato, hp_ripristinati=150, costo_follia=8.0, cooldown=40.0)

    *L'Aeon non chiede il permesso al tempo: richiama indietro cio' che il tempo aveva gia' reclamato.*

    tag sinergia: tempo, spirito, singolo

- Boon (2 requisiti): `comportamento`; `sacrificio`




## 5. Le sinergie: come le abilità si parlano fra loro

Non ripetuto per intero qui (`data/synergies/*.json` è un sistema a sé,
`SynergyEngine` fase 4): ogni abilità dichiara `tag_sinergia` (visti sopra
per ognuna), e una sinergia si attiva quando il giocatore possiede una
combinazione di tag da fonti diverse (abilità + inventario + pet + stanza
+ talento). 44 sinergie scritte, 26 raggiungibili con i 10 Pathway attivi
di oggi; le altre 17 aspettano tag che vivono solo nei 12 gruppi di
Pathway differiti (sotto).

## 6. Proposte per il futuro

Nessuna richiede una primitiva nuova (il registro basta per tutto quello
che segue) né tocca `AbilityEngine.execute` — solo contenuto sullo schema
già in piedi.

### US-D05: Le 4 primitive senza handler restano un vuoto silenzioso

**Descrizione:** Come sviluppatore, voglio sapere se `chain`/
`probability_shift`/`weather_control`/`rule_bind` (dichiarate ma senza
`_p_<primitiva>` in `ability_engine.gd`) vanno implementate quando la
prima Sequenza attiva le richiederà, o tolte dal registro se non servono
più a nessun Pathway attivo pianificato.

**Acceptance Criteria:**
- [ ] Decisione esplicita documentata (implementare al bisogno / rimuovere
      dal registro) — non un'implementazione "per completezza" oggi.

### US-D06: Un secondo Pathway Non-Standard

**Descrizione:** Come giocatore, voglio un secondo bestower oltre a
Eternal Aeon (Chaos Primogenitor, Scrooge o Dreamless dal materiale di
riferimento), per varietà nella scelta di creazione personaggio.

**Acceptance Criteria:**
- [ ] Un nuovo file `data/pathways_non_standard/<id>.json`, 10 Sequenze
      complete (nessuna stub), un `Boon` per Sequenza con requisiti
      combinati come Eternal Aeon.
- [ ] `GameData.pathway_ids_non_standard()` lo espone, il selettore di
      creazione personaggio lo mostra.
- [ ] Tests pass. `python tools/validate_data.py` esce 0.

*(Nota: questo è già in roadmap come Fase 13 — opzionale, non
pianificata. La story qui sopra la formalizza solo in caso si decida di
farla senza aspettare un PRD dedicato.)*

### US-D07: Più sinergie raggiungibili dai 10 Pathway attivi

**Descrizione:** Come giocatore, voglio che le 17 sinergie oggi
irraggiungibili (chiedono tag dei 12 Pathway differiti) abbiano
equivalenti raggiungibili con i 10 Pathway attivi, così ogni combinazione
di build ha una sinergia da scoprire.

**Acceptance Criteria:**
- [ ] Almeno 3 nuove sinergie in `data/synergies/*.json` che combinano
      solo tag già raggiungibili da abilità/inventario/pet/stanza/talento
      dei Pathway attivi.
- [ ] `python tools/validate_data.py` esce 0 (il warning delle sinergie
      irraggiungibili scende sotto 17). Tests pass.

## 7. Non-Goals

- I 12 Pathway differiti (`data/pathways_deferred/`) non sono descritti
  qui: sono completi nei dati ma fuori scope per design (CLAUDE.md, "10
  Pathway invece di 22" — riattivarne uno significa riattivare il suo
  gruppo intero, una decisione presa con l'utente).
- Il motore (`ability_engine.gd`, `progression.gd`, `potion_system.gd`,
  `boon_system.gd`) non è documentato qui in dettaglio tecnico: questo
  documento è design/contenuto, non architettura.
- Le sinergie non sono catalogate una per una (44 voci): meritano un
  documento a sé se servirà, questo si limita a spiegare il meccanismo.

## 8. Open Questions

- Il registro delle primitive ha **27** voci con `implemented: true` e
  **4** senza handler (`chain`, `probability_shift`, `weather_control`,
  `rule_bind`) — ma `CLAUDE.md` dice ancora "28 attive + 3 differite".
  Discrepanza reale trovata scrivendo questo documento: quale numero è
  quello aggiornato da tenere in `CLAUDE.md`?
- Fase 12 (Atto II e Atto III, pianificata) aggiungerà contenuto narrativo
  attorno a tribolazioni/duelli/rituali già meccanici: tocca solo
  quest/dialoghi, non abilità — resta fuori da questo documento?
