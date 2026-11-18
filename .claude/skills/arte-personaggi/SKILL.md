---
name: arte-personaggi
description: Disegnare personaggi, nemici, boss, pet e creature di Mirwada con forge3d in modo leggibile (arti staccati, faccia visibile, pose chiare, tempi giusti). Usala prima di generare o correggere qualunque figura animata (tools/art/build_personaggi.py, build_npc.py, build_nemici.py, build_forme.py, build_fauna.py).
---

# Personaggi leggibili (Mirwada, forge3d)

Motore: `tools/art/forge3d` (copia del progetto di sprite-forge). Le figure sono modelli 3D semplici fotografati a 64 px.
Questa skill dice **come devono venire**; i comandi e i dati restano quelli di CLAUDE.md.

## Cosa non andava (giudizio dell'utente, 2026-11-18)
- mani, piedi e corpo attaccati fra loro: la figura e' un blocco unico;
- la faccia non si vede; i dettagli si perdono;
- le pose (chinarsi, meditare, raccogliere) non si capiscono;
- i boss non dicono cosa fanno.

## Regole
1. **Silhouette prima di tutto.** Riempi la figura di nero: deve restare riconoscibile (testa, due braccia, due gambe,
   arma). Se no, cambia la posa o le proporzioni, non i colori.
2. **Arti staccati.** `humanoid(..., stacco=1.0..1.5)` allarga spalle e anche; il render con `group_lines=True` traccia
   1 px scuro dove una parte del corpo tocca un'altra (braccio sul busto, gamba sulla gamba, testa sul collo).
   Le maniche dello stesso colore del busto vanno comunque staccate: usa `group_lines`, non un colore a caso.
3. **Faccia.** Testa grande (`head` 1.0-1.15 per gli umani a 64 px), occhi di almeno 2 px con il bianco, capelli che
   lasciano libera la fronte (mai `hair_style` che copre tutta la testa vista di fronte). La pelle deve staccare dai
   capelli di almeno due toni.
4. **Valori.** Un personaggio scuro (Enel) ha bisogno del bordo di luce (`bordo_luce` di build_personaggi) e di un
   accento chiaro (sciarpa, occhi): mai tre zone vicine con lo stesso valore.
5. **Pose estreme, mai sottili.** Ogni azione ha una posa chiave leggibile anche ferma:
   - *chinarsi / raccogliere*: busto inclinato in avanti di 35-50 gradi, ginocchia piegate, braccio teso verso terra;
   - *meditare*: seduto a gambe incrociate, mani sulle ginocchia, testa dritta, respiro di 1 px;
   - *bere*: gomito alto, testa indietro;
   - *rituale*: braccia alzate sopra la testa, aperte;
   - *tell del nemico* (`anticipo`): carica all'indietro esagerata, arma lontana dal corpo.
   Prova sempre la posa di lato: se di lato non si capisce, non si capisce.
6. **Tempi.** I frame d'impatto si tengono (`durate_ms` in data/animations.json); il ciclo si chiude.
7. **Boss.** Una figura grande (celle 96-128) con un segno che dice il suo modo di combattere: il Re dei Ratti e' coperto di
   ratti, la Madre delle Radici ha radici che toccano terra, il Custode senza Nome e' tutto armatura, il Gigante ha la
   spada piantata, il Burattinaio ha i fili. Ogni fase cambia qualcosa di **visibile** (colore degli occhi, arma, postura).

## Controllo (sempre)
- Foglio a x4 su chiaro, scuro ed erba (dashboard: dettaglio del personaggio, sfondi e velocita').
- Test del nero: `python tools/art/controlla_silhouette.py FILE.png` se esiste, altrimenti riempi a mano in PIL.
- Ogni animazione provata coi tasti nella dashboard (campo di prova) per i tempi.
- Poi giudizio dell'utente nella dashboard: una nota "rifare" e' lavoro da fare (skill arte-revisione).
