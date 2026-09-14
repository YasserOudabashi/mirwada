# PRD: Design del gioco — Oggetti ed Economia

## 1. Introduzione/Overview

Questo documento non descrive una feature da costruire: descrive **quello
che il gioco ha già**, oggetto per oggetto, così com'è nei dati dopo la
fase 11 (Villaggi ed Economia, chiusa). È il primo di cinque documenti
"bibbia di design" (gli altri: mondo/regioni, NPC/boss, abilità/pathway,
il libro — ognuno in `006_PRD/prd-design-*.md`) che mettono per iscritto,
in prosa leggibile, tutto ciò che oggi è solo JSON. La sezione 6 fa
l'eccezione: propone cosa manca ancora nell'economia del gioco, in formato
story verificabile, per quando si deciderà di scriverlo davvero.

Ogni voce del catalogo sotto è **tratta dai dati reali** (`data/items/*.json`
+ `data/i18n/it.json`), non inventata: nome, descrizione, rarità, valore,
tag ed effetto meccanico sono esattamente quelli con cui il gioco gira
oggi. 351 oggetti in tutto, su 7 categorie chiuse
(`data/schema/item_categories.json`).

## 2. Il sistema di rarità

Introdotto in fase 11 (US-1101/1102), è un vocabolario chiuso di 4 livelli
(`data/schema/item_rarity.json`) che ogni oggetto dichiara con un campo
facoltativo `rarita` (assente = `comune`, per compatibilità con gli oggetti
scritti prima):

| Rarità | Peso nel drop pesato | Moltiplicatore di prezzo |
|---|---|---|
| `comune` | 100 | ×1.0 |
| `non_comune` | 30 | ×2.0 |
| `raro` | 8 | ×5.0 |
| `leggendario` | 1 | ×12.0 |

Due comportamenti reali derivano da questi numeri, non solo un colore
diverso nello zaino:

- **Il drop pesa la rarità** (`enemy.gd::_scegli_drop_pesato`, US-1104): fra
  gli oggetti droppabili da un nemico/una zona, uno `leggendario` esce
  100× più raramente di uno `comune` a parità di tabella.
- **Il prezzo in negozio scala** (`page_dialogo.gd::_prezzo_con_rarita`,
  US-1103): il campo `valore` nei dati resta sempre il prezzo BASE di un
  oggetto comune; quello che il giocatore paga davvero è
  `valore × moltiplicatore(rarità)`. Un oggetto leggendario con `valore`
  200 (Ambrosia, sotto) costa davvero 2400 monete al banco di un mercante,
  non 200 — la differenza si vede giocando, non solo nel JSON.

Ogni oggetto del gioco ha oggi una rarità esplicita: il retrofit di
US-1102 l'ha scritta su tutti i 351, derivandola — per i 314 ingredienti —
dalla Sequenza della formula di pozione che li referenzia (Sequenza alta =
comune, Sequenza bassa = raro/leggendario, coerente col fatto che un
rituale di potere maggiore chiede componenti più difficili da trovare).

## 3. Le 7 categorie di oggetto

Vocabolario **chiuso** (`data/schema/item_categories.json`): ogni cosa che
il giocatore raccoglie è un item con una di queste 7 categorie, mai un tipo
speciale scritto nel codice. Aggiungerne una nuova sarebbe codice, va
discussa esplicitamente (stessa regola delle primitive e degli eventi
tracciati).

- **`ingrediente`** — si consuma per preparare una pozione (avanzamento di
  Sequenza) o una ricetta (consumabile). Mai equipaggiato, mai un effetto
  proprio: il suo unico ruolo è essere l'input di una formula/ricetta.
- **`equip`** — arma, armatura o accessorio: occupa uno slot
  (`arma`/`armatura`/`accessorio`), applica `stat_modifiers` finché
  indossato, e può avere slot per sigilli.
- **`sigillo`** — si incastra in uno slot di un `equip` (`sigillo_ref`
  punta a `data/forge/sigils.json`), aggiunge un effetto di forgiatura.
- **`pergamena`** — immagazzina un'abilità (`stored_ability_id`): usarla
  lancia quell'abilità una tantum, senza doverla conoscere.
- **`materiale`** — l'input grezzo della forgiatura (`Forge.forgia`),
  parallelo agli ingredienti ma per l'equip invece che le pozioni.
- **`valuta`** — moneta: si accumula, non si equipaggia, compra tutto il
  resto.
- **`consumabile`** — pozione/pasto/tonico con un `effetto` immediato o a
  durata (`heal`, `buff_stat`, ...), sparisce all'uso.

## 4. Catalogo esaustivo

### Equipaggiamento (9)

**`spada_ferrea`** — *Spada ferrea* (non_comune, ~80 monete in negozio)

> Onesta, pesante, senza pretese. Un incavo per un sigillo.

- Categoria: `equip` · Tag: arma, forza, guerra · Impilabile: no

- Slot: `arma` · Modificatori: forza +10% · Slot sigilli: 1



**`corazza_cuoio`** — *Corazza di cuoio* (non_comune, ~70 monete in negozio)

> Cuoio bollito e cucito stretto. Ferma un coltello, non una lama.

- Categoria: `equip` · Tag: difesa, guerra · Impilabile: no

- Slot: `armatura` · Modificatori: difesa +15% · Slot sigilli: 1



**`amuleto_lunare`** — *Amuleto lunare* (non_comune, ~120 monete in negozio)

> Un disco d argento freddo al tatto. Due alveoli per i sigilli.

- Categoria: `equip` · Tag: luna, spirito · Impilabile: no

- Slot: `accessorio` · Modificatori: spiritualita_max +20 · Slot sigilli: 2



**`lama_del_pentimento`** — *Lama del pentimento* (raro, non acquistabile in negozio (solo trovato/ottenuto nel mondo))

> Taglia piu a fondo di quanto dovrebbe. Chi la impugna non dorme.

- Categoria: `equip` · Tag: arma, sangue, maledizione · Impilabile: no

- Slot: `arma` · Modificatori: forza +35%, difesa -10% · Slot sigilli: 0



**`corazza_espiazione`** — *Corazza dell'espiazione* (raro, non acquistabile in negozio (solo trovato/ottenuto nel mondo))

> Assorbe il colpo. Assorbe anche te, un poco alla volta.

- Categoria: `equip` · Tag: difesa, sangue · Impilabile: no

- Slot: `armatura` · Modificatori: difesa +30% · Slot sigilli: 0



**`anello_del_richiamo`** — *Anello del richiamo* (raro, non acquistabile in negozio (solo trovato/ottenuto nel mondo))

> Affila la mira. Chiama anche l'attenzione di cio' che non vorresti.

- Categoria: `equip` · Tag: spirito · Impilabile: no

- Slot: `accessorio` · Modificatori: precisione +20% · Slot sigilli: 0



**`ascia_da_guerra`** — *Ascia da guerra* (non_comune, ~110 monete in negozio)

> Un'arma pesante forgiata da un fabbro, non da chi la usa.

- Categoria: `equip` · Tag: forza, arma · Impilabile: no

- Slot: `arma` · Modificatori: forza +15% · Slot sigilli: 0



**`scudo_rinforzato`** — *Scudo rinforzato* (non_comune, ~100 monete in negozio)

> Cuoio e ferro, cuciti insieme per reggere un colpo vero.

- Categoria: `equip` · Tag: difesa · Impilabile: no

- Slot: `armatura` · Modificatori: difesa +20% · Slot sigilli: 0



**`anello_di_cristallo`** — *Anello di cristallo* (raro, ~350 monete in negozio)

> Un cristallo grezzo inciso con cura instabile - risuona con lo spirito di chi lo porta.

- Categoria: `equip` · Tag: spirito · Impilabile: no

- Slot: `accessorio` · Modificatori: spiritualita_max +15, evasione +5% · Slot sigilli: 0



### Consumabili (9)

**`pozione_cura_minore`** — *Pozione di cura minore* (comune, ~12 monete in negozio)

> Rimargina le ferite superficiali. Amara.

- Categoria: `consumabile` · Tag: pozione, guarigione · Impilabile: sì

- Effetto: `heal` (quantita=25.0, istantaneo=True)



**`elisir_del_vigore`** — *Elisir del vigore* (non_comune, ~36 monete in negozio)

> Per un poco i muscoli rispondono meglio di quanto dovrebbero.

- Categoria: `consumabile` · Tag: pozione, forza · Impilabile: sì

- Effetto: `buff_stat` (stat=forza, valore=0.15, durata=20.0, moltiplicativo=False)



**`pastura_spirituale`** — *Pastura spirituale* (comune, ~22 monete in negozio)

> Non nutre il corpo: nutre cio che hai legato a te.

- Categoria: `consumabile` · Tag: spirito, bestia · Impilabile: sì



**`pozione_cura_maggiore`** — *Pozione di cura maggiore* (non_comune, ~80 monete in negozio)

> Rimette in sesto anche una ferita seria. Sa di miele e ferro.

- Categoria: `consumabile` · Tag: pozione, guarigione, luce · Impilabile: sì

- Effetto: `heal` (quantita=70.0, istantaneo=True)



**`elisir_ombra`** — *Elisir d ombra* (non_comune, ~90 monete in negozio)

> Ti fa scivolare via dai colpi come se non fossi del tutto li.

- Categoria: `consumabile` · Tag: pozione, ombra, agilita' · Impilabile: sì

- Effetto: `buff_stat` (stat=evasione, valore=0.2, durata=15.0, moltiplicativo=False)



**`ambrosia`** — *Ambrosia* (leggendario, ~2400 monete in negozio)

> Cibo degli dei minori. Una sola sorsata richiude qualunque cosa.

- Categoria: `consumabile` · Tag: pozione, luna, anima, guarigione · Impilabile: sì

- Effetto: `heal` (quantita=200.0, istantaneo=True)



**`tonico_di_forza`** — *Tonico di forza* (non_comune, ~40 monete in negozio)

> Amaro in bocca, caldo nei muscoli.

- Categoria: `consumabile` · Tag: forza · Impilabile: sì

- Effetto: `buff_stat` (stat=forza, valore=0.2, durata=25.0, moltiplicativo=False)



**`filtro_di_chiarezza`** — *Filtro di chiarezza* (comune, ~15 monete in negozio)

> Schiarisce la vista e la mano insieme.

- Categoria: `consumabile` · Tag: mente · Impilabile: sì

- Effetto: `buff_stat` (stat=precisione, valore=0.15, durata=20.0, moltiplicativo=False)



**`essenza_rara_di_guarigione`** — *Essenza rara di guarigione* (raro, ~225 monete in negozio)

> Poche gocce, ma bastano.

- Categoria: `consumabile` · Tag: guarigione · Impilabile: sì

- Effetto: `heal` (quantita=120, istantaneo=True)



### Pergamene (5)

**`pergamena_vigore`** — *Pergamena del vigore* (raro, ~125 monete in negozio)

> Si legge una volta sola: la forza scorre, poi la carta si sbriciola.

- Categoria: `pergamena` · Tag: occulto, forza · Impilabile: no

- Abilità immagazzinata: `tg_stretta_ferrea`



**`pergamena_alba`** — *Pergamena dell alba* (raro, ~150 monete in negozio)

> Un usbergo di luce per un istante. Poi cenere.

- Categoria: `pergamena` · Tag: occulto, luce · Impilabile: no

- Abilità immagazzinata: `tg_armatura_alba`



**`pergamena_hermit`** — *Pergamena dell eremita* (raro, ~175 monete in negozio)

> Un foglio fitto di glifi. Letto ad alta voce, mostra cio che il nemico ha memorizzato.

- Categoria: `pergamena` · Tag: occulto, conoscenza, rituale · Impilabile: no

- Abilità immagazzinata: `hermit_pergamena`



**`pergamena_ambrosia`** — *Pergamena dell ambrosia* (leggendario, ~1440 monete in negozio)

> La ricetta di una cura leggendaria, scritta da una mano che non c e piu.

- Categoria: `pergamena` · Tag: conoscenza, pozione, luna · Impilabile: no



**`libro_ordine_minore`** — *Trattato dell'Ordine Minore* (raro, ~225 monete in negozio)

> Un tomo scomodo da leggere. Chi lo finisce puo' varcare le ali interne dell'Archivio Sepolto.

- Categoria: `pergamena` · Tag: occulto, conoscenza · Impilabile: no



### Sigilli (8)

**`sigillo_forza_minore`** — *Sigillo di forza minore* (non_comune, ~40 monete in negozio)

> Inciso su un equip, rende il colpo piu duro.

- Categoria: `sigillo` · Tag: sigillo, forza · Impilabile: no

- Sigillo referenziato: `sig_forza_1`



**`sigillo_ombra_fame`** — *Sigillo dell ombra affamata* (non_comune, ~90 monete in negozio)

> Ruba vigore ai nemici. E un poco anche a te.

- Categoria: `sigillo` · Tag: sigillo, ombra · Impilabile: no

- Sigillo referenziato: `sig_ombra_fame`



**`sigillo_difesa_minore`** — *Sigillo di difesa minore* (non_comune, ~40 monete in negozio)

> Inciso su un equip, assorbe un poco di ogni colpo.

- Categoria: `sigillo` · Tag: sigillo, difesa · Impilabile: no

- Sigillo referenziato: `sig_difesa_1`



**`sigillo_vento_leggero`** — *Sigillo del vento leggero* (non_comune, ~50 monete in negozio)

> Inciso su un equip, alleggerisce il passo.

- Categoria: `sigillo` · Tag: sigillo, vento · Impilabile: no

- Sigillo referenziato: `sig_velocita_1`



**`sigillo_mira_ferma`** — *Sigillo della mira ferma* (non_comune, ~40 monete in negozio)

> Inciso su un equip, raddrizza la mano che colpisce.

- Categoria: `sigillo` · Tag: sigillo, guerra · Impilabile: no

- Sigillo referenziato: `sig_precisione_1`



**`sigillo_custode`** — *Sigillo del custode* (non_comune, ~60 monete in negozio)

> Inciso su un equip, ne rinforza la guardia.

- Categoria: `sigillo` · Tag: sigillo, difesa · Impilabile: no

- Sigillo referenziato: `sig_custode`



**`sigillo_eco_lama`** — *Sigillo dell'eco di lama* (non_comune, ~110 monete in negozio)

> Custodisce l'eco di un fendente, pronto a ripetersi.

- Categoria: `sigillo` · Tag: sigillo, guerra · Impilabile: no

- Sigillo referenziato: `sig_eco_lama`



**`sigillo_sangue_avido`** — *Sigillo del sangue avido* (non_comune, ~100 monete in negozio)

> Rende il colpo brutale. Il prezzo si paga in vita.

- Categoria: `sigillo` · Tag: sigillo, sangue · Impilabile: no

- Sigillo referenziato: `sig_sangue_avido`



### Materiali da crafting (4)

**`lingotto_ferro`** — *Lingotto di ferro* (comune, ~8 monete in negozio)

> Metallo grezzo da fucina.

- Categoria: `materiale` · Tag: crafting · Impilabile: sì



**`cuoio_conciato`** — *Cuoio conciato* (comune, ~6 monete in negozio)

> Pelle trattata, pronta a essere tagliata.

- Categoria: `materiale` · Tag: crafting, carne · Impilabile: sì



**`cristallo_grezzo`** — *Cristallo grezzo* (comune, ~15 monete in negozio)

> Vibra piano se lo tieni vicino a un rituale.

- Categoria: `materiale` · Tag: crafting, occulto · Impilabile: sì



**`scarto_alchemico`** — *Scarto alchemico* (comune, non acquistabile in negozio (solo trovato/ottenuto nel mondo))

> Poltiglia annerita. Non serve a niente, ma non si butta.

- Categoria: `materiale` · Tag: decadimento · Impilabile: sì



### Valuta (2)

**`moneta_comune`** — *Moneta comune* (comune, ~1 monete in negozio)

> Rame consumato. Passa di mano in mano da secoli.

- Categoria: `valuta` · Tag: — · Impilabile: sì



**`sigillo_reale`** — *Sigillo reale* (non_comune, ~100 monete in negozio)

> Oro con l impronta di una corona che non governa piu.

- Categoria: `valuta` · Tag: — · Impilabile: sì



### Ingredienti alchemici (314)

Ogni ingrediente è raccolto nel mondo o comprato, e serve a preparare una pozione di avanzamento di Sequenza (`data/potions/formulas.json`) o una ricetta di consumabile (`data/potions/recipes.json`). La rarità è derivata dalla Sequenza della formula che lo referenzia (Sequenza alta = comune, Sequenza bassa = raro/leggendario): più un ingrediente serve a un rituale di potere maggiore, più è difficile da trovare.


| id | nome | rarità | valore | formula (pathway.sequenza) | tag |

|---|---|---|---|---|---|

| `acciaio_stellare` | Acciaio stellare | comune | 8 | twilight_giant.7 | forza, pozione, stella |

| `acido_da_saggio` | Acido da saggio | comune | 8 | paragon.7 | pozione |

| `acqua_dello_stige` | Acqua dello stige | raro | 40 | death.3 | acqua, pozione |

| `acqua_di_fonte_benedetta` | Acqua di fonte benedetta | comune | 8 | mother.7 | acqua, pozione |

| `acqua_di_fonte_cieca` | Acqua di fonte cieca | non_comune | 12 | darkness.6 | acqua, pozione |

| `acqua_di_un_pozzo_che_non_trovi_piu` | Acqua di un pozzo che non trovi più | raro | 40 | door.3 | acqua, pozione |

| `acqua_sorgiva` | Acqua sorgiva | comune | 1 | — | acqua, purificazione |

| `ago_che_cuce_il_fato` | Ago che cuce il fato | raro | 90 | hermit.1 | destino, pozione |

| `ala_di_falena_crepuscolare` | Ala di falena crepuscolare | non_comune | 27 | darkness.4 | pozione |

| `ambra_grigia` | Ambra grigia | non_comune | 12 | moon.6 | pozione |

| `angolo_di_stanza_che_non_esiste` | Angolo di stanza che non esiste | raro | 90 | fool.1 | pozione |

| `argento_annerito` | Argento annerito | comune | 8 | moon.7 | pozione |

| `argento_benedetto` | Argento benedetto | non_comune | 27 | twilight_giant.4 | pozione |

| `argilla_rossa_del_fiume` | Argilla rossa del fiume | non_comune | 27 | mother.4 | pozione, terra |

| `articolazione_di_marionetta` | Articolazione di marionetta | non_comune | 18 | fool.5 | inganno, pozione |

| `asso_sempre_in_cima_al_mazzo` | Asso sempre in cima al mazzo | comune | 8 | fool.7 | fortuna, pozione |

| `astrolabio_tascabile` | Astrolabio tascabile | non_comune | 18 | hermit.5 | pozione, stella |

| `balsamo_di_silenzio` | Balsamo di silenzio | non_comune | 12 | darkness.6 | pozione, silenzioso |

| `battuta_finale_mai_detta` | Battuta finale mai detta | leggendario | 120 | fool.0 | pozione |

| `biglietto_della_lotteria_vincente` | Biglietto della lotteria vincente | raro | 60 | fool.2 | fortuna, pozione |

| `biglietto_di_sola_andata_e_ritorno` | Biglietto di sola andata e ritorno | non_comune | 18 | door.5 | pozione |

| `bilancia_di_precisione` | Bilancia di precisione | comune | 8 | paragon.7 | pozione |

| `boccale_dei_contrabbandieri` | Boccale dei contrabbandieri | comune | 3 | — | occultamento, notte |

| `bussola_che_punta_a_dove_vuoi_tu` | Bussola che punta a dove vuoi tu | raro | 40 | door.3 | divinazione, pozione |

| `calice_incrinato` | Calice incrinato | non_comune | 18 | moon.5 | pozione |

| `campana_incrinata` | Campana incrinata | raro | 40 | darkness.3 | pozione |

| `campanaccio_di_capra_smarrita` | Campanaccio di capra smarrita | comune | 2 | — | bestia |

| `cappello_a_cilindro_senza_fondo` | Cappello a cilindro senza fondo | non_comune | 27 | fool.4 | pozione |

| `caratteristica_del_gigante` | Caratteristica del gigante | leggendario | 120 | twilight_giant.0 | forza, pozione |

| `cardine_arrugginito_di_una_porta_perduta` | Cardine arrugginito di una porta perduta | comune | 3 | door.9 | pozione |

| `cardine_del_cielo` | Cardine del cielo | raro | 90 | door.1 | pozione, stella |

| `carta_carbone_dell_anima` | Carta carbone dell'anima | non_comune | 12 | door.6 | anima, destino, pozione |

| `carta_millimetrata` | Carta millimetrata | non_comune | 18 | paragon.5 | destino, pozione |

| `carta_stellare_con_una_stella_in_piu` | Carta stellare con una stella in più | comune | 8 | door.7 | destino, pozione, stella |

| `catalizzatore_proibito` | Catalizzatore proibito | non_comune | 27 | paragon.4 | pozione |

| `cavillo_primordiale` | Cavillo primordiale | leggendario | 120 | error.0 | pozione |

| `cellula_madre` | Cellula madre | non_comune | 12 | mother.6 | pozione |

| `cenere_di_bosco` | Cenere di bosco | raro | 40 | mother.3 | pozione, terra |

| `cenere_di_re` | Cenere di re | raro | 90 | death.1 | pozione, terra |

| `cenere_di_spirito` | Cenere di spirito | non_comune | 27 | twilight_giant.4 | pozione, spirito, terra |

| `cenere_di_stella_morta` | Cenere di stella morta | comune | 3 | darkness.9 | pozione, stella, terra |

| `cera_di_candela_rituale` | Cera di candela rituale | comune | 5 | hermit.8 | pozione, rituale |

| `cera_di_veglia` | Cera di veglia | comune | 5 | death.8 | pozione, sonno |

| `cerone_da_palcoscenico` | Cerone da palcoscenico | comune | 5 | fool.8 | pozione |

| `cesto_di_vimini_intrecciato` | Cesto di vimini intrecciato | comune | 2 | — | crescita |

| `chiave_che_chiude_e_non_apre` | Chiave che chiude e non apre | non_comune | 27 | door.4 | pozione |

| `chiave_d_ossa` | Chiave d'ossa | non_comune | 18 | death.5 | morte, pozione |

| `chiave_dell_oltretomba` | Chiave dell'oltretomba | leggendario | 120 | death.0 | pozione |

| `chiave_di_cifrario` | Chiave di cifrario | comune | 8 | error.7 | conoscenza, pozione |

| `chiave_di_ogni_serratura` | Chiave di ogni serratura | leggendario | 120 | hermit.0 | pozione |

| `chiave_di_soluzione` | Chiave di soluzione | non_comune | 27 | hermit.4 | pozione |

| `chiave_fatta_di_luce_di_stella` | Chiave fatta di luce di stella | raro | 90 | door.1 | luce, pozione, stella |

| `chiave_senza_denti` | Chiave senza denti | comune | 3 | door.9 | pozione |

| `chiodo_arrugginito_di_forca` | Chiodo arrugginito di forca | raro | 90 | darkness.1 | morte, pozione |

| `chiodo_di_bara` | Chiodo di bara | non_comune | 27 | death.8, darkness.4 | morte, pozione |

| `chiodo_di_ferro_freddo` | Chiodo di ferro freddo | comune | 8 | hermit.7 | forza, pozione |

| `chiodo_nell_ingranaggio_del_fato` | Chiodo nell'ingranaggio del fato | raro | 60 | error.2 | destino, pozione |

| `cilindro_a_doppio_fondo` | Cilindro a doppio fondo | comune | 8 | fool.7 | pozione |

| `clessidra_che_cola_all_indietro` | Clessidra che cola all'indietro | raro | 90 | error.1 | pozione, tempo |

| `codice_della_vita_inciso` | Codice della vita inciso | raro | 60 | mother.2 | conoscenza, pozione |

| `colomba_che_non_esiste` | Colomba che non esiste | comune | 8 | fool.7 | pozione |

| `contratto_con_la_clausola_nascosta` | Contratto con la clausola nascosta | comune | 5 | error.8 | contratto, pozione |

| `copione_del_mondo_con_le_correzioni` | Copione del mondo con le correzioni | leggendario | 120 | fool.0 | pozione |

| `corda_di_impiccato` | Corda di impiccato | comune | 5 | darkness.8 | pozione |

| `corno_da_richiamo_intagliato` | Corno da richiamo intagliato | comune | 3 | — | bestia |

| `corno_di_alce_spettrale` | Corno di alce spettrale | non_comune | 27 | moon.4 | pozione, spirito |

| `corona_di_ossa` | Corona di ossa | raro | 60 | death.2 | morte, pozione |

| `corona_di_papavero_nero` | Corona di papavero nero | non_comune | 12 | darkness.6 | pozione |

| `corteccia_febbrifuga` | Corteccia febbrifuga | comune | 5 | mother.8 | crescita, pozione |

| `costante_universale_incrinata` | Costante universale incrinata | raro | 90 | paragon.1 | pozione |

| `creta_del_primo_uomo` | Creta del primo uomo | non_comune | 12 | error.6 | pozione, terra |

| `cristallo_di_riferimento` | Cristallo di riferimento | comune | 8 | paragon.7 | pozione |

| `cristallo_mnemonico` | Cristallo mnemonico | raro | 60 | hermit.2 | pozione |

| `croce_di_legno_del_burattinaio` | Croce di legno del burattinaio | non_comune | 18 | fool.5 | inganno, pozione |

| `crogiolo_indistruttibile` | Crogiolo indistruttibile | non_comune | 27 | paragon.4 | pozione |

| `cuore_che_non_si_ferma` | Cuore che non si ferma | non_comune | 27 | death.4 | pozione |

| `cuore_condiviso` | Cuore condiviso | non_comune | 27 | error.4 | pozione |

| `cuore_del_pianeta` | Cuore del pianeta | leggendario | 120 | mother.0 | pozione, stella |

| `cuore_di_montagna` | Cuore di montagna | non_comune | 18 | twilight_giant.5 | pozione |

| `cuore_di_quercia_madre` | Cuore di quercia madre | raro | 60 | moon.2 | crescita, pozione |

| `cuscino_di_un_dormiente_inquieto` | Cuscino di un dormiente inquieto | non_comune | 18 | error.5 | pozione, sonno |

| `dado_truccato` | Dado truccato | comune | 5 | error.8 | fortuna, pozione |

| `dente_di_teschio` | Dente di teschio | comune | 3 | death.9 | morte, pozione |

| `distanza_ridotta_a_zero` | Distanza ridotta a zero | leggendario | 120 | door.0 | pozione |

| `domanda_senza_risposta` | Domanda senza risposta | leggendario | 120 | hermit.0 | pozione |

| `eco_di_un_istante_gia_passato` | Eco di un istante già passato | raro | 90 | error.1 | pozione, spirito |

| `eco_di_un_potere_visto_una_volta_sola` | Eco di un potere visto una volta sola | raro | 60 | door.2 | pozione, spirito |

| `ectoplasma` | Ectoplasma | comune | 8 | death.7 | pozione |

| `enzima_dormiente` | Enzima dormiente | non_comune | 12 | mother.6 | pozione, sonno |

| `erba_lunare` | Erba lunare | comune | 3 | — | luna, crescita, pozione |

| `essenza_di_biblioteca` | Essenza di biblioteca | raro | 60 | hermit.2 | pozione |

| `essenza_spettrale` | Essenza spettrale | non_comune | 12 | death.6 | pozione, spirito |

| `estratto_di_muscolo` | Estratto di muscolo | comune | 5 | twilight_giant.8 | pozione |

| `favilla_del_titano_incatenato` | Favilla del titano incatenato | non_comune | 12 | error.6 | pozione |

| `fegato_sempre_rigenerato` | Fegato sempre rigenerato | non_comune | 12 | error.6 | pozione |

| `ferro_delle_lapidi` | Ferro delle lapidi | non_comune | 12 | death.6 | forza, pozione |

| `ferro_temperato` | Ferro temperato | comune | 3 | twilight_giant.9 | forza, pozione |

| `fiala_di_luna_piena` | Fiala di luna piena | non_comune | 12 | moon.6 | luna, pozione |

| `fiele_di_demone` | Fiele di demone | non_comune | 27 | twilight_giant.4 | pozione |

| `filo_d_argento_lunare` | Filo d'argento lunare | raro | 40 | moon.3 | pozione |

| `filo_del_burattinaio` | Filo del burattinaio | raro | 40 | error.3 | inganno, pozione |

| `filo_dell_oblio` | Filo dell'oblio | raro | 60 | darkness.2 | pozione |

| `filo_delle_parche` | Filo delle parche | raro | 40 | death.3 | pozione |

| `filo_di_lana_rossa` | Filo di lana rossa | comune | 3 | hermit.9 | pozione |

| `filo_di_lutto` | Filo di lutto | non_comune | 18 | darkness.5 | pozione |

| `filo_reciso_dalle_parche` | Filo reciso dalle parche | raro | 90 | hermit.1 | pozione |

| `filo_spirituale_annodato` | Filo spirituale annodato | non_comune | 18 | fool.5 | pozione, spirito |

| `filo_teso_tra_due_stanze` | Filo teso tra due stanze | comune | 5 | door.8 | pozione |

| `fiore_che_sboccia_solo_di_notte` | Fiore che sboccia solo di notte | non_comune | 27 | moon.4 | crescita, notte, pozione |

| `fiore_di_camomilla_selvatica` | Fiore di camomilla selvatica | comune | 5 | mother.8 | crescita, pozione |

| `fiore_di_luna` | Fiore di luna | comune | 3 | moon.9 | crescita, luna, pozione |

| `frammento_di_alba` | Frammento di alba | non_comune | 12 | twilight_giant.6 | pozione |

| `frammento_di_cielo_notturno` | Frammento di cielo notturno | non_comune | 18 | hermit.5 | pozione, stella |

| `frammento_di_luna` | Frammento di luna | leggendario | 120 | moon.0 | luna, pozione |

| `frammento_di_notte_primordiale` | Frammento di notte primordiale | leggendario | 120 | darkness.0 | notte, pozione |

| `frammento_di_tavoletta` | Frammento di tavoletta | comune | 5 | paragon.8 | pozione |

| `frammento_di_una_porta_tra_i_mondi` | Frammento di una porta tra i mondi | raro | 60 | door.2 | pozione |

| `fungo_a_specchio` | Fungo a specchio | non_comune | 12 | mother.6 | pozione, specchio |

| `fungo_cavernicolo` | Fungo cavernicolo | comune | 2 | — | terra, follia |

| `gessetto_che_disegna_porte` | Gessetto che disegna porte | comune | 5 | door.8 | pozione |

| `gesso_consacrato` | Gesso consacrato | comune | 3 | hermit.9 | pozione |

| `ghianda_millenaria` | Ghianda millenaria | non_comune | 18 | mother.5 | pozione |

| `goccia_di_linfa` | Goccia di linfa | comune | 3 | mother.9 | crescita, pozione |

| `goccia_di_prima_pioggia` | Goccia di prima pioggia | raro | 60 | moon.2 | pozione |

| `grimaldello_cantante` | Grimaldello cantante | comune | 3 | error.9 | pozione |

| `grimorio_bianco` | Grimorio bianco | non_comune | 27 | hermit.4 | pozione |

| `guanto_del_borseggiatore` | Guanto del borseggiatore | comune | 3 | error.9 | pozione |

| `il_confine_del_mondo` | Il confine del mondo | leggendario | 120 | death.0 | pozione |

| `incenso_dei_riti` | Incenso dei riti | non_comune | 12 | death.6 | pozione |

| `incenso_di_cenere` | Incenso di cenere | raro | 40 | darkness.3 | pozione, terra |

| `incenso_di_mirra` | Incenso di mirra | comune | 8 | hermit.7 | pozione |

| `inchiostro_che_copia_da_solo` | Inchiostro che copia da solo | non_comune | 12 | door.6 | pozione |

| `inchiostro_che_non_si_cancella` | Inchiostro che non si cancella | raro | 90 | hermit.1 | pozione |

| `inchiostro_di_due_mondi` | Inchiostro di due mondi | raro | 40 | paragon.3 | pozione |

| `inchiostro_di_seppia_abissale` | Inchiostro di seppia abissale | comune | 5 | darkness.8 | pozione |

| `inchiostro_ferrogallico` | Inchiostro ferrogallico | non_comune | 12 | hermit.6 | pozione |

| `inchiostro_luminescente` | Inchiostro luminescente | comune | 5 | hermit.8 | pozione |

| `inchiostro_simpatico_rubato` | Inchiostro simpatico rubato | comune | 8 | error.7 | pozione |

| `inchiostro_stellare` | Inchiostro stellare | non_comune | 18 | paragon.5 | pozione, stella |

| `ingranaggio_di_precisione` | Ingranaggio di precisione | non_comune | 12 | paragon.6 | pozione |

| `lacrima_di_amante` | Lacrima di amante | raro | 90 | moon.1 | pozione |

| `lacrima_di_luna` | Lacrima di luna | comune | 30 | — | luna, spirito, anima |

| `lacrima_di_paladino` | Lacrima di paladino | raro | 40 | twilight_giant.3 | pozione |

| `lacrima_di_vedova` | Lacrima di vedova | comune | 5 | darkness.8 | pozione |

| `lama_di_luce_solidificata` | Lama di luce solidificata | raro | 40 | twilight_giant.3 | arma, luce, pozione |

| `lega_beyonder` | Lega beyonder | non_comune | 12 | paragon.6 | pozione |

| `lega_impossibile_da_replicare` | Lega impossibile da replicare | leggendario | 120 | paragon.0 | pozione |

| `lente_di_lungo_fuoco` | Lente di lungo fuoco | non_comune | 18 | paragon.5 | fuoco, pozione |

| `lente_graduata` | Lente graduata | comune | 3 | paragon.9 | pozione |

| `lente_puntata_sempre_a_nord` | Lente puntata sempre a nord | comune | 8 | door.7 | pozione |

| `lettera_mai_consegnata` | Lettera mai consegnata | raro | 60 | error.2 | conoscenza, pozione |

| `linfa_di_gigante` | Linfa di gigante | non_comune | 12 | twilight_giant.6 | crescita, forza, pozione |

| `lingua_d_argento_falsa` | Lingua d'argento falsa | comune | 5 | error.8 | pozione |

| `luce_di_luna_imbottigliata` | Luce di luna imbottigliata | raro | 60 | moon.2 | luce, luna, pozione |

| `mano_di_gloria` | Mano di gloria | comune | 5 | death.8 | pozione |

| `mappa_che_si_ripiega_su_se_stessa` | Mappa che si ripiega su sé stessa | non_comune | 18 | door.5 | pozione |

| `mappa_delle_costellazioni_perdute` | Mappa delle costellazioni perdute | comune | 5 | — | divinazione |

| `maschera_senza_lineamenti` | Maschera senza lineamenti | non_comune | 12 | fool.6 | illusione, pozione |

| `memoria_cristallizzata` | Memoria cristallizzata | raro | 60 | paragon.2 | pozione |

| `mercurio_filosofale` | Mercurio filosofale | non_comune | 27 | paragon.4 | pozione |

| `metallo_impossibile` | Metallo impossibile | raro | 90 | twilight_giant.1 | pozione |

| `miele_selvatico` | Miele selvatico | comune | 8 | mother.7 | pozione |

| `mitra_di_vescovo_apostata` | Mitra di vescovo apostata | raro | 40 | darkness.3 | pozione |

| `moneta_caduta_sempre_di_taglio` | Moneta caduta sempre di taglio | raro | 60 | fool.2 | fortuna, pozione |

| `moneta_del_traghettatore` | Moneta del traghettatore | comune | 8 | death.7 | fortuna, pozione |

| `muffa_sepolcrale` | Muffa sepolcrale | comune | 3 | death.9 | pozione |

| `muschio_di_caverna` | Muschio di caverna | non_comune | 12 | moon.6 | crescita, pozione |

| `muschio_luminoso` | Muschio luminoso | non_comune | 18 | mother.5 | crescita, pozione |

| `muta_di_pelle_altrui` | Muta di pelle altrui | non_comune | 27 | error.4 | carne, pozione |

| `naso_finto_di_ceramica` | Naso finto di ceramica | comune | 5 | fool.8 | pozione |

| `nebbia_del_limbo` | Nebbia del limbo | non_comune | 18 | death.5 | occultamento, pozione |

| `nucleo_del_crepuscolo` | Nucleo del crepuscolo | leggendario | 120 | twilight_giant.0 | pozione |

| `nucleo_spirituale_stabile` | Nucleo spirituale stabile | raro | 60 | paragon.2 | pozione, spirito |

| `numero_che_non_dovrebbe_esistere` | Numero che non dovrebbe esistere | raro | 90 | paragon.1 | pozione |

| `obolo_di_bronzo` | Obolo di bronzo | raro | 40 | death.3 | pozione |

| `occhio_che_non_dorme` | Occhio che non dorme | comune | 3 | darkness.9 | pozione |

| `occhio_del_gufo_del_giudizio` | Occhio del gufo del giudizio | leggendario | 120 | darkness.0 | pozione |

| `occhio_di_vetro_nero` | Occhio di vetro nero | raro | 40 | hermit.3 | pozione |

| `olio_conduttore` | Olio conduttore | non_comune | 12 | paragon.6 | pozione |

| `ombra_imbottigliata` | Ombra imbottigliata | non_comune | 27 | darkness.4 | ombra, pozione |

| `ombra_ritagliata_con_le_forbici` | Ombra ritagliata con le forbici | non_comune | 27 | door.4 | ombra, pozione |

| `oro_bianco` | Oro bianco | non_comune | 12 | twilight_giant.6 | pozione |

| `ossa_di_gatto_nero` | Ossa di gatto nero | comune | 8 | hermit.7 | morte, pozione |

| `ossidiana_decaduta` | Ossidiana decaduta | raro | 60 | twilight_giant.2 | ombra, pozione |

| `osso_di_pugile` | Osso di pugile | comune | 5 | twilight_giant.8 | morte, pozione |

| `pagina_strappata_da_un_diario` | Pagina strappata da un diario | raro | 40 | fool.3 | conoscenza, pozione |

| `pelo_di_lupo_bianco` | Pelo di lupo bianco | comune | 5 | moon.8 | pozione |

| `pergamena_a_doppia_faccia` | Pergamena a doppia faccia | raro | 40 | paragon.3 | pozione |

| `pergamena_di_qualita` | Pergamena di qualita | non_comune | 12 | hermit.6 | pozione |

| `petalo_di_belladonna` | Petalo di belladonna | comune | 8 | moon.7 | pozione |

| `petalo_solare` | Petalo solare | comune | 4 | — | luce, guarigione |

| `pietra_di_marea` | Pietra di marea | non_comune | 27 | moon.4 | pozione, terra |

| `pietra_di_soglia` | Pietra di soglia | non_comune | 18 | death.5 | pozione, terra |

| `piuma_di_civetta_nera` | Piuma di civetta nera | comune | 8 | darkness.7 | pozione |

| `placenta_di_pietra` | Placenta di pietra | raro | 60 | mother.2 | pozione, terra |

| `platino_rituale` | Platino rituale | raro | 40 | twilight_giant.3 | pozione, rituale |

| `polline_dorato` | Polline dorato | raro | 90 | mother.1 | pozione |

| `polvere_di_arena` | Polvere di arena | comune | 8 | twilight_giant.7 | pozione |

| `polvere_di_confine` | Polvere di confine | raro | 60 | darkness.2 | pozione |

| `polvere_di_crepuscolo` | Polvere di crepuscolo | raro | 60 | twilight_giant.2 | pozione |

| `polvere_di_gesso_stellare` | Polvere di gesso stellare | comune | 3 | door.9 | pozione, stella |

| `polvere_di_incubo` | Polvere di incubo | comune | 8 | darkness.7 | pozione, sogno |

| `polvere_di_meteora` | Polvere di meteora | non_comune | 18 | hermit.5 | pozione |

| `polvere_di_ossario` | Polvere di ossario | raro | 60 | death.2 | pozione |

| `polvere_di_pagine_antiche` | Polvere di pagine antiche | raro | 60 | hermit.2 | pozione |

| `polvere_di_sale_nero` | Polvere di sale nero | comune | 3 | hermit.9 | pozione |

| `polvere_di_specchio_incrinato` | Polvere di specchio incrinato | comune | 3 | fool.9 | pozione, specchio |

| `polvere_di_terza_vista` | Polvere di terza vista | raro | 40 | hermit.3 | pozione |

| `polvere_di_un_oggetto_gia_distrutto` | Polvere di un oggetto già distrutto | raro | 40 | fool.3 | pozione |

| `polvere_di_un_piano_gia_chiuso` | Polvere di un piano già chiuso | raro | 60 | door.2 | pozione |

| `polvere_ossa` | Polvere d ossa | comune | 4 | — | morte, rituale |

| `polvere_reagente` | Polvere reagente | comune | 3 | paragon.9 | pozione |

| `porta_che_non_c_e_mai_stata` | Porta che non c e mai stata | leggendario | 120 | error.0 | pozione |

| `prima_notte_del_mondo` | Prima notte del mondo | leggendario | 120 | moon.0 | notte, pozione |

| `prima_porta_mai_aperta` | Prima porta mai aperta | leggendario | 120 | door.0 | pozione |

| `prima_ruota_mai_costruita` | Prima ruota mai costruita | leggendario | 120 | paragon.0 | pozione |

| `primo_libro_mai_scritto` | Primo libro mai scritto | leggendario | 120 | hermit.0 | conoscenza, pozione |

| `prisma_che_devia_la_luce` | Prisma che devia la luce | raro | 90 | paragon.1 | luce, pozione |

| `progetto_del_mondo_perfetto` | Progetto del mondo perfetto | leggendario | 120 | paragon.0 | pozione |

| `punta_d_argento` | Punta d'argento | comune | 5 | hermit.8 | pozione |

| `quaderno_di_appunti_sulle_maree` | Quaderno di appunti sulle maree | comune | 4 | — | luna |

| `quadrifoglio_a_cinque_foglie` | Quadrifoglio a cinque foglie | raro | 60 | fool.2 | pozione |

| `quintessenza_distillata` | Quintessenza distillata | non_comune | 27 | hermit.4 | pozione |

| `radice_amara` | Radice amara | comune | 5 | mother.8 | crescita, pozione |

| `radice_che_beve` | Radice che beve | raro | 40 | mother.3 | crescita, pozione |

| `radice_crepuscolo` | Radice del crepuscolo | comune | 5 | — | decadimento, ombra |

| `radice_di_ferro_lunare` | Radice di ferro lunare | non_comune | 18 | moon.5 | crescita, forza, pozione |

| `radice_di_immortelle` | Radice di immortelle | non_comune | 27 | death.4 | crescita, pozione |

| `radice_di_mandragora_urlante` | Radice di mandragora urlante | comune | 8 | darkness.7 | crescita, pozione |

| `radice_di_quercia` | Radice di quercia | comune | 3 | twilight_giant.9 | crescita, pozione |

| `radice_di_valeriana` | Radice di valeriana | comune | 3 | moon.9 | crescita, pozione |

| `radice_di_veggente` | Radice di veggente | comune | 3 | fool.9 | crescita, divinazione, pozione |

| `radice_maestra` | Radice maestra | raro | 90 | mother.1 | crescita, pozione |

| `refurtiva_dimenticata` | Refurtiva dimenticata | comune | 3 | error.9 | pozione |

| `regola_locale_scritta_a_matita` | Regola locale scritta a matita | raro | 90 | fool.1 | legge, pozione |

| `reliquia_profanata` | Reliquia profanata | non_comune | 18 | darkness.5 | pozione, rituale |

| `resina_conservante` | Resina conservante | comune | 5 | paragon.8 | pozione |

| `resina_di_ferro` | Resina di ferro | non_comune | 18 | twilight_giant.5 | forza, pozione |

| `respiro_dell_oceano` | Respiro dell'oceano | leggendario | 120 | moon.0 | pozione |

| `respiro_della_foresta_del_mondo` | Respiro della foresta del mondo | leggendario | 120 | mother.0 | pozione |

| `respiro_finale` | Respiro finale | leggendario | 120 | death.0 | pozione |

| `ricordo_altrui_in_bottiglia` | Ricordo altrui in bottiglia | non_comune | 18 | error.5 | pozione |

| `riga_bianca_nel_regolamento_del_mondo` | Riga bianca nel regolamento del mondo | leggendario | 120 | error.0 | pozione |

| `ritratto_che_cambia_faccia` | Ritratto che cambia faccia | non_comune | 12 | fool.6 | pozione |

| `ritratto_di_te_da_bambino` | Ritratto di te da bambino | raro | 40 | fool.3 | pozione |

| `rosa_che_non_appassisce` | Rosa che non appassisce | raro | 90 | moon.1 | pozione |

| `rugiada_notturna` | Rugiada notturna | comune | 3 | moon.9 | notte, pozione |

| `sabbia_del_sonno_rubata` | Sabbia del sonno rubata | non_comune | 18 | error.5 | pozione, sonno, terra |

| `sabbia_di_due_deserti_lontani` | Sabbia di due deserti lontani | non_comune | 18 | door.5 | pozione, terra |

| `sabbia_di_meridiana_notturna` | Sabbia di meridiana notturna | comune | 8 | door.7 | notte, pozione, terra |

| `sale_della_veglia_eterna` | Sale della veglia eterna | non_comune | 27 | death.4 | pozione, sonno |

| `sale_della_vita` | Sale della vita | non_comune | 27 | mother.4 | pozione |

| `sale_di_roccia` | Sale di roccia | comune | 5 | twilight_giant.8 | pozione |

| `sale_scarlatto` | Sale scarlatto | non_comune | 18 | moon.5 | pozione |

| `sale_versato` | Sale versato | raro | 90 | darkness.1 | pozione |

| `sangue_di_cervo` | Sangue di cervo | comune | 5 | moon.8 | pozione, sangue |

| `sangue_di_gufo_lunare` | Sangue di gufo lunare | comune | 3 | fool.9 | pozione, sangue |

| `sangue_di_lupo` | Sangue di lupo | comune | 6 | — | sangue, bestia, forza |

| `sangue_di_ogni_bestia` | Sangue di ogni bestia | raro | 60 | mother.2 | pozione, sangue |

| `sangue_di_toro` | Sangue di toro | comune | 3 | twilight_giant.9 | pozione, sangue |

| `sangue_rappreso` | Sangue rappreso | comune | 8 | moon.7 | pozione, sangue |

| `scettro_pallido` | Scettro pallido | raro | 90 | death.1 | pozione |

| `scheggia_divina` | Scheggia divina | raro | 90 | twilight_giant.1 | pozione |

| `scudo_fuso` | Scudo fuso | non_comune | 18 | twilight_giant.5 | pozione |

| `segreto_sigillato_in_cera_nera` | Segreto sigillato in cera nera | non_comune | 27 | door.4 | pozione |

| `seme_del_primo_giorno` | Seme del primo giorno | leggendario | 120 | mother.0 | crescita, pozione |

| `seme_dell_albero_madre` | Seme dell'albero madre | non_comune | 27 | mother.4 | crescita, pozione |

| `seme_di_stella_cadente` | Seme di stella cadente | raro | 40 | moon.3 | crescita, pozione, stella |

| `seme_dormiente` | Seme dormiente | comune | 3 | mother.9 | crescita, pozione, sonno |

| `serratura_dell_orizzonte` | Serratura dell'orizzonte | raro | 90 | door.1 | pozione |

| `sigillo_di_ceralacca` | Sigillo di ceralacca | non_comune | 12 | hermit.6 | pozione, sigillo |

| `silenzio_tra_due_battiti` | Silenzio tra due battiti | raro | 90 | fool.1 | pozione, silenzioso |

| `sillaba_di_un_nome_non_tuo` | Sillaba di un nome non tuo | raro | 40 | error.3 | pozione |

| `sipario_di_velluto_polveroso` | Sipario di velluto polveroso | non_comune | 27 | fool.4 | illusione, pozione |

| `soffio_di_spettro` | Soffio di spettro | comune | 8 | death.7 | pozione, spirito |

| `soglia_tra_tutto_e_tutto` | Soglia tra tutto e tutto | leggendario | 120 | door.0 | pozione |

| `sonaglio_che_confonde` | Sonaglio che confonde | comune | 5 | fool.8 | pozione |

| `spazzola_da_scavo` | Spazzola da scavo | comune | 5 | paragon.8 | pozione |

| `specchio_annerito` | Specchio annerito | raro | 60 | darkness.2 | pozione, specchio |

| `specchio_annerito_dal_fumo` | Specchio annerito dal fumo | raro | 40 | hermit.3 | pozione, specchio |

| `specchio_che_non_riflette_nessuno` | Specchio che non riflette nessuno | leggendario | 120 | fool.0 | pozione, specchio |

| `specchio_che_riflette_un_altro` | Specchio che riflette un altro | raro | 40 | error.3 | pozione, specchio |

| `specchio_da_borsetta_a_due_facce` | Specchio da borsetta a due facce | comune | 5 | door.8 | pozione, specchio |

| `specchio_da_camerino_incrinato` | Specchio da camerino incrinato | non_comune | 27 | fool.4 | pozione, specchio |

| `specchio_di_luna_nera` | Specchio di luna nera | raro | 90 | moon.1 | luna, pozione, specchio |

| `spiga_dorata` | Spiga dorata | comune | 8 | mother.7 | pozione |

| `spina_dell_ultimo_inverno` | Spina dell'ultimo inverno | raro | 90 | mother.1 | pozione |

| `spina_di_rovo_antico` | Spina di rovo antico | non_comune | 18 | mother.5 | pozione |

| `stele_di_rosetta_infranta` | Stele di rosetta infranta | comune | 8 | error.7 | pozione |

| `stendardo_lacero` | Stendardo lacero | raro | 60 | death.2 | pozione |

| `stilo_di_ossidiana` | Stilo di ossidiana | raro | 40 | paragon.3 | ombra, pozione |

| `suola_consumata_da_mille_strade` | Suola consumata da mille strade | raro | 40 | door.3 | pozione |

| `taccuino_di_appunti` | Taccuino di appunti | comune | 3 | paragon.9 | pozione |

| `telaio_di_precisione_assoluta` | Telaio di precisione assoluta | raro | 60 | paragon.2 | pozione |

| `tempo_solidificato` | Tempo solidificato | leggendario | 120 | twilight_giant.0 | pozione, tempo |

| `tendine_di_lupo` | Tendine di lupo | comune | 8 | twilight_giant.7 | pozione |

| `terra_di_cimitero` | Terra di cimitero | comune | 3 | death.9 | pozione, terra |

| `terriccio_di_prima_luna` | Terriccio di prima luna | comune | 3 | mother.9 | luna, pozione |

| `timbro_di_ogni_potere` | Timbro di ogni potere | non_comune | 12 | door.6 | pozione |

| `tredicesimo_grano_di_rosario` | Tredicesimo grano di rosario | raro | 90 | darkness.1 | pozione |

| `trottola_di_legno_intagliata` | Trottola di legno intagliata | comune | 2 | — | emozione |

| `ultima_foglia_dell_autunno` | Ultima foglia dell'autunno | raro | 40 | mother.3 | pozione |

| `ultimo_battito` | Ultimo battito | raro | 90 | death.1 | pozione |

| `ultimo_respiro` | Ultimo respiro | raro | 60 | twilight_giant.2 | pozione |

| `ultimo_respiro_del_giorno` | Ultimo respiro del giorno | leggendario | 120 | darkness.0 | pozione |

| `velo_di_mezzanotte` | Velo di mezzanotte | comune | 3 | darkness.9 | pozione |

| `verme_che_mangia_i_minuti` | Verme che mangia i minuti | raro | 90 | error.1 | pozione |

| `vischio_che_si_aggrappa` | Vischio che si aggrappa | non_comune | 27 | error.4 | pozione |

| `voce_del_gigante` | Voce del gigante | raro | 90 | twilight_giant.1 | forza, pozione |

| `voce_di_creatura_mai_vista` | Voce di creatura mai vista | raro | 40 | moon.3 | pozione |

| `voce_registrata_su_cera` | Voce registrata su cera | non_comune | 12 | fool.6 | pozione |

| `voto_infranto_alla_radice` | Voto infranto alla radice | raro | 60 | error.2 | crescita, pozione |

| `zanna_di_latte` | Zanna di latte | comune | 5 | moon.8 | pozione |

| `zolfo_delle_fosse` | Zolfo delle fosse | non_comune | 18 | darkness.5 | pozione |


## 5. L'economia in pratica: chi vende, chi crea

Il giocatore non è mai l'unico che produce oggetti: dalla fase 11 esistono
NPC che **creano** oggetti su richiesta (il giocatore porta i materiali,
l'NPC forgia/prepara) accanto ai mercanti tradizionali che vendono da un
listino fisso.

**Crafting NPC** (7° effetto di dialogo `crea_su_richiesta`, US-1106):
l'NPC "conosce il suo mestiere" a prescindere da cosa il giocatore ha
scoperto — un blueprint/ricetta con `nota_da_subito: false` (il giocatore
non lo saprebbe fare da solo) è comunque forgiabile/preparabile tramite
l'NPC, e il bypass non insegna nulla al giocatore dopo.

| NPC | Ruolo | Dove | Cosa crea |
|---|---|---|---|
| Rosalba | Erborista dell'avamposto | Valle della Madre | `ric_cura_maggiore`, `ric_filtro_di_chiarezza` |
| Bram | Fabbro di Mirwada | Mirwada | `bp_spada_ferrea`, `bp_anello_di_cristallo` (esclusivo, non scopribile da soli) |
| Fenwick | Fabbro del villaggio fuori le mura | Marche del Crepuscolo | `bp_ascia_da_guerra`, `bp_scudo_rinforzato` |
| Orsolya | Alchimista del villaggio dell'Archivio | Archivio Sepolto | `ric_tonico_di_forza`, `ric_essenza_rara_di_guarigione` (esclusivo) |

**Mercanti** (listino fisso, effetto di dialogo `apri_vendita`):

| NPC | Ruolo | Dove | Listino |
|---|---|---|---|
| Sidon | Mercante di reagenti e voci | Mirwada (porto) | 64 oggetti — il più grande del gioco, soprattutto ingredienti |
| Vesna | Guaritrice ai margini | Mirwada | 26 oggetti |
| Bruno | Contrabbandiere del porto | Mirwada (porto, di notte) | 29 oggetti |
| Greta | Mercante del villaggio fuori le mura | Marche del Crepuscolo | 4 oggetti |
| Dario | Mercante del villaggio dell'Archivio | Archivio Sepolto | 3 oggetti, incluso **Ambrosia** (leggendario, ~2400 monete — il prezzo più alto del gioco) |

Il giocatore può anche **vendere** qualunque oggetto a un mercante (stesso
`_prezzo_con_rarita`, a metà del prezzo di acquisto) e **forgiare/preparare
da solo** un blueprint/ricetta che ha scoperto (`Forge.forgia`,
`PotionSystem.prepara`, senza il parametro `ignora_scoperta`).

## 6. Proposte per il futuro

Quello che segue non esiste ancora: sono proposte in formato story, da
convertire in un vero `prd.json` quando si deciderà di farle. Nessuna
richiede una primitiva/evento/categoria nuovi — solo più contenuto sullo
schema già in piedi.

### US-D01: Più mercanti con un listino a tema

**Descrizione:** Come giocatore, voglio mercanti diversi specializzati per
tipo di merce (armi, ingredienti rari, oggetti di più regioni), non solo
generalisti.

**Acceptance Criteria:**
- [ ] Almeno 2 nuovi NPC vendor con un `listino` a tema (es. solo `equip`,
      o solo oggetti `raro`+) in regioni che oggi hanno un solo mercante o
      nessuno (Valle della Madre, Frontiera delle Porte).
- [ ] `python tools/validate_data.py` esce 0. Tests pass.

### US-D02: Oggetti leggendari unici per pathway

**Descrizione:** Come giocatore, voglio che ogni gruppo di Pathway abbia
almeno un oggetto leggendario a tema (oggi solo Ambrosia esiste), premio
per aver esplorato quella parte del mondo.

**Acceptance Criteria:**
- [ ] Almeno 3 nuovi oggetti `leggendario` (equip o consumabile), ognuno
      con tag coerenti a un gruppo di Pathway attivo, venduti da un
      mercante o droppati da un boss di quella regione.
- [ ] `python tools/validate_data.py` esce 0. Tests pass.

### US-D03: Sigilli con effetti di forgiatura distinti per rarità

**Descrizione:** Come giocatore, voglio che un sigillo `raro`+ abbia un
effetto meccanicamente più forte (non solo un prezzo più alto), oggi gli 8
sigilli hanno tutti effetti dello stesso ordine di grandezza.

**Acceptance Criteria:**
- [ ] Almeno 1 sigillo `raro` o `leggendario` nuovo con un effetto di
      forgiatura chiaramente più forte dei sigilli `non_comune` esistenti
      (documentato nel confronto).
- [ ] Tests pass. `python tools/validate_data.py` esce 0.

### US-D04: Il negozio mostra la rarità a colpo d'occhio

**Descrizione:** Come giocatore, voglio vedere la rarità di un oggetto nel
negozio (non solo nello zaino, dove `_colore_rarita` esiste già da
US-1105), per decidere cosa comprare senza aprire l'inventario.

**Acceptance Criteria:**
- [ ] `page_dialogo.gd::_disegna_negozio` applica lo stesso
      `_COLORE_RARITA` di `page_inventario.gd` al nome di ogni riga.
- [ ] Tests pass. Verifica a schermo con Xvfb.

## 7. Non-Goals

- Questo documento non introduce nessuna primitiva, evento tracciato o
  categoria di oggetto nuova: cataloga quello che esiste e propone solo
  contenuto sullo schema già chiuso.
- Non copre gli oggetti dei 12 Pathway differiti (`data/pathways_deferred/`):
  fuori scope per design (CLAUDE.md, "10 Pathway invece di 22").
- Non copre le formule di avanzamento di Sequenza in sé (quella è materia
  del documento su abilità/pathway) né il motore di forgiatura/alchimia in
  dettaglio tecnico (quello vive nel codice, `scripts/forge.gd`/
  `scripts/potion_system.gd`).

## 8. Open Questions

- Il moltiplicatore di prezzo leggendario (×12) rende Ambrosia quasi
  irraggiungibile senza grinding mirato — è l'effetto voluto (un vero
  traguardo) o va ritarato?
- I 3 equip `raro` a valore 0 (`lama_del_pentimento`, `corazza_espiazione`,
  `anello_del_richiamo`) non sono acquistabili né referenziati da nessuna
  formula/drop table oggi: sono ricompense pensate per un sistema non
  ancora scritto (sinergie/quest?) o materiale abbandonato da ripulire?
