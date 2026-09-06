# Mirwada — Mondo: regioni, biomi, gating, tempo

Figlio di `design-master.md`. Materia di fase 6 (le fondamenta dei vocabolari
si anticipano a fase 5, perche' i rituali le usano gia'). Vincoli ereditati:
**niente open world senza gating, niente generazione procedurale** (non-goals),
4-6 regioni disegnate a mano (roadmap fase 6).

---

## 1. Il principio: una regione per gruppo di pathway

Dieci pathway in quattro gruppi (design-pathways.md) → **quattro regioni a
tema + la citta' neutra**. Non e' una decorazione: e' il terzo canale
dell'identita' di pathway (design-master, principio 2). La palette audio di
ogni pathway ha gia' un riverbero — cattedrale, cripta, bosco, teatro, officina
— e quei riverberi *sono* i luoghi delle regioni. Un giocatore di Mother sente
la Valle come casa perche' il suo pathway suona gia' di `bosco`.

La **base del giocatore** non e' una regione: e' la zona `base_giocatore` gia'
in audio.json, un luogo dentro (o ai margini di) la citta', che il base
building di fase 3 riempie.

## 2. Le cinque regioni

Nomi provvisori (decisione aperta n. 1 del master; chiavi i18n `region.*`).

### 2.1 Mirwada — la citta' (hub, neutra)

Porto, quartiere operaio, mercato, l'archivio di un ordine minore. E' la citta'
implicita in design-lore.md: tutti e 8 gli NPC ci vivono all'inizio. Densita'
mistica bassa: qui la coltivazione e' lenta e i poteri *si notano* — usare
abilita' in citta' alza l'attenzione di Doran (design-npc-quest).

- **Biomi interni**: vicoli e tetti (verticalita' leggera), porto (notte,
  contrabbando), quartiere operaio (Lena, la vita che stai perdendo), archivio
  (Ottavia, gating di conoscenza).
- **Gating d'ingresso**: nessuno. Gating *interno* sociale: il porto di notte
  richiede Bruno (`npc`), l'archivio richiede la conoscenza concessa da
  Ottavia (`conoscenza`).
- **Zona musica**: `citta` (esiste gia' in audio.json).
- **location_tags**: `porto`, `archivio`, `vicolo`, `piazza`, `sotterraneo`.

### 2.2 Marche del Crepuscolo — eternal_darkness (TG, Darkness, Death)

Brughiera in un tramonto che non finisce, campi di battaglia antichi, cripte,
rovine, alture. **Ospita tutti gli 8 location_tags gia' usati dai rituali del
Twilight Giant** — la regione esiste implicitamente da quando quei rituali sono
stati scritti; qui viene solo nominata.

- **Biomi interni**: brughiera aperta (combat leggibile, orizzonte basso),
  campo di battaglia (armi spezzate = ingredienti TG), cripte e catacombe
  (Death: cadaveri, `luogo_di_massacro`), il tempio abbandonato, la vetta.
- **Gating**: `shadow_meld` apre i passaggi in ombra (Darkness); alcune cripte
  solo con `momento: notte_fonda`; il `trono_del_gigante` e' il sito unico del
  rituale di Sequenza 0 del TG.
- **Densita' mistica**: media-alta. Zona musica nuova: `marche`.
- **location_tags**: `altura`, `luogo_di_battaglia`, `tempio_abbandonato`,
  `rovina`, `luogo_in_decadenza`, `vetta`, `luogo_di_massacro`, `cripta`,
  `trono_del_gigante`.

### 2.3 Valle della Madre — goddess_of_origin (Mother, Moon)

Foresta antica, radure lunari, grotte di marea, sorgenti. La dispensa del
gioco: ingredienti alchemici, erbe, bestie da domare (il pet di Moon).

- **Biomi interni**: foresta fitta (visuale corta, suono che conta piu' della
  vista — aggancio diretto ai tell sonori), radure lunari (di notte, con la
  luna giusta, fioriture rare), grotte di marea (si aprono con `fase_lunare:
  piena` o `nuova`), sorgenti (guarigione, rituali di Mother).
- **Gating**: `plant_growth` crea ponti di radici sui burroni; le grotte
  seguono la luna; le bestie profonde attaccano solo chi non ha un pet.
- **Densita' mistica**: media, alta nelle radure. Zona musica: `valle`.
- **location_tags**: `bosco_antico`, `radura_lunare`, `grotta_di_marea`,
  `sorgente`, `altare_di_radici`.

### 2.4 Archivio Sepolto — demon_of_knowledge (Hermit, Paragon)

Una citta' di studiosi collassata: biblioteca sepolta, officine meccaniche
ferme, torri d'osservazione. Il dungeon "a enigmi" del gioco.

- **Biomi interni**: sale della biblioteca (lore, formule, gating di
  conoscenza), officine (Paragon: crafting, costrutti dormienti), torri
  (Hermit: costellazioni — i buff stellari di hermit_5 qui sono potenziati),
  la sala dei sigilli.
- **Gating**: di **conoscenza** — le porte sigillate si aprono avendo *letto*
  i testi giusti (flag da Ottavia, da libri trovati, da sinergie `lore`);
  i sigilli incisi (crafting di fase 3) aprono le ali interne.
- **Densita' mistica**: alta. Zona musica: `archivio`.
- **location_tags**: `biblioteca`, `officina`, `torre_di_osservazione`,
  `sala_dei_sigilli`, `studio`.

### 2.5 Frontiera delle Porte — lord_of_mysteries (Fool, Error, Door)

La regione di endgame: nebbia grigia, spazio non euclideo, un teatro
abbandonato dove le cose recitano se stesse, soglie che portano altrove.

- **Biomi interni**: la nebbia (isole di terreno collegate solo da soglie),
  il teatro (Fool: il palco e' un luogo rituale), il crocevia (Door), zone
  dove le regole locali sono *sbagliate* (Error: gravita', tempo, riflessi).
- **Gating**: visibile presto, inaccessibile fino a `sequenza_max: 4` circa
  (gating per sequenza); dentro, il movimento tra le isole richiede `teleport`
  o le porte del Door. E' l'unica regione dove il fast travel e' meccanica
  primaria e non scorciatoia.
- **Densita' mistica**: massima. Zona musica: `frontiera`.
- **location_tags**: `teatro`, `crocevia`, `soglia`, `nebbia_grigia`, `palco`.

## 3. Il vocabolario chiuso dei luoghi

`data/schema/location_tags.json` (**creato in fase 5, US-501** — anticipato
da fase 6 perche' i rituali dei 5 Pathway nuovi lo richiedono): le 29 voci
elencate sopra. Gli 8 tag gia' usati dai rituali del TG sono entrati identici,
**zero migrazione**. Il validator ora rifiuta un `advancement_ritual` con un
`location_tag` fuori vocabolario. Le regioni di fase 6 devono realizzare a
schermo ogni tag qui presente.

I **siti unici dei rituali di Sequenza 0** degli altri 9 pathway (gli analoghi
di `trono_del_gigante`) si aggiungono al vocabolario con le story di fase 5,
uno per pathway, nella regione del suo gruppo (il `palco` del teatro e' il
candidato naturale per il Fool). Il vocabolario e' chiuso ma versionato:
aggiungere una voce e' una story di dati con motivazione, non un liberi tutti.

## 4. Gating: i modi ammessi

Vocabolario chiuso dei tipi di gate (entra in `region.schema.json`):

| tipo | esempio | sistema che lo serve |
|---|---|---|
| `primitiva` | `shadow_meld` apre il passaggio in ombra | motore abilita' (le primitive di movimento/terreno) |
| `momento` | cripta aperta solo `notte_fonda` | ciclo giorno/notte |
| `fase_lunare` | grotta di marea con luna `piena` | ciclo lunare |
| `npc` | Bruno sblocca il porto notturno (modo `aiutato`) | `npc_influenced`, gia' nel vocabolario eventi |
| `conoscenza` | flag `testi_ordine_minore` | dialoghi, libri, sinergie lore |
| `sequenza` | la Frontiera respinge chi e' sopra Sequenza ~4 | stato di progressione |

`terrain_modify` con `permanente: true` (tg_mano_divina, tg_spezza_barriera)
**apre gate in modo permanente e salvato**: la mappa alterata fa parte dello
stato del mondo nel save (design-master cap. 3.1). Un varco aperto e' aperto
per sempre: e' la firma del TG sull'esplorazione.

## 5. Tempo: momento e fase lunare

Vocabolario in `data/schema/time.json` (creato nel risanamento):
`momento ∈ {alba, mezzogiorno, crepuscolo, notte_fonda}`,
`fase_lunare ∈ {nuova, crescente, piena, calante, eclissi}` — `eclissi` e'
l'**evento raro schedulato**, non una tappa del ciclo: e' il momento dei
rituali piu' alti (il TG ne richiede due) e delle fioriture uniche.

Effetti meccanici (fase 6): condizioni `e_notte`/`fase_lunare` gia' ammesse
da `ability.schema.json` e mai usate — sono il gancio gratuito; l'evento
`time_in_state` con `stato: notte` e' gia' tracciabile (Darkness ci recita);
il ciclo cambia ambienti sonori e spawn per zona. Il ciclo **non scorre
durante i dialoghi e le pagine del libro** (il libro ferma il mondo:
design-ui-libro).

## 6. Densita' mistica

Un numero per zona (0..1) in `regions.json`. Cosa muove:

- la **percezione per Sequenza** (`audio.json.sequence_perception` rivela
  `densita_mistica` da Sequenza 5): nelle zone dense il giocatore *sente* di
  piu' — e' il radar dell'esplorazione;
- la velocita' di recupero della spiritualita' e l'efficacia dei rituali;
- la frequenza degli spawn Beyonder e dei segreti.

La citta' e' volutamente bassa: coltivare richiede uscire. E' il motore
dell'esplorazione e, insieme a Doran, la pressione che spinge fuori casa.

## 7. Fast travel

Regola: **il viaggio costa, le scorciatoie sono poteri**. Niente teletrasporto
da menu. Il viaggio spirituale del Door (door_5) e i passaggi del Death
(death_5) sono il fast travel *dei loro pathway* — matrice di proprieta' del
master: Door scorciatoie istantanee, Death permanenza esplorabile. Per tutti
gli altri: strade, e i varchi permanenti che il TG apre. Coerente col verbo del
Door: "il combattimento e' geografia" — e la geografia e' un privilegio.

## 8. Schema dati (forma, non contenuto)

`data/world/regions.json` + `data/schema/region.schema.json`
(`additionalProperties: false` come gli altri):

```json
{
  "schema_version": 1,
  "regions": [
    {
      "id": "marche_crepuscolo",
      "name_i18n": "region.marche_crepuscolo",
      "group_affinity": "eternal_darkness",
      "densita_mistica": 0.6,
      "location_tags": ["altura", "rovina", "cripta"],
      "music_zone": "marche",
      "gating": [
        { "tipo": "primitiva", "primitiva": "shadow_meld", "area": "passaggi_ombra" },
        { "tipo": "momento", "valore": "notte_fonda", "area": "cripte" }
      ],
      "palette_visiva": "eternal_darkness"
    }
  ]
}
```

Check del validator che nascono con questo file: `location_tags` ⊆ vocabolario;
`music_zone` esistente in audio.json; `gating[].tipo` nel vocabolario dei modi;
`gating[].primitiva` attiva nel registro; `palette_visiva` esistente in
`data/vfx.json`; `group_affinity` tra i gruppi validi o `"neutra"`.
