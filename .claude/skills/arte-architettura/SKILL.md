---
name: arte-architettura
description: Case, botteghe, edifici speciali e citta' di Mirwada (vista top-down 3/4): ogni edificio con il suo carattere, porte su lati diversi, insegne, monumenti riconoscibili (cattedrale, faro, museo, mercato, dogana, cantiere navale, centro antico). Usala prima di toccare forge3d/creatures.py edificio(), esporta_mondo.py --edifici o gli interni.
---

# Architettura (Mirwada)

## Giudizi dell'utente (2026-11-18), da rispettare
- "le case sono tutte uguali": serve un **kit** (pareti, tetti, porte, finestre, dettagli) che si combina, piu' i
  **monumenti** fatti a mano nel generatore;
- ogni NPC importante ha la **sua casa riconoscibile** ("ah, questa e' di quel NPC");
- le porte non devono stare tutte sullo stesso lato; le case troppo vicine non si leggono;
- la cattedrale deve sembrare una cattedrale, il faro e' piu' alto, il museo deve esistere, il centro antico deve
  sembrare antico, il mercato deve avere banchi, gente e insegne, la dogana guardie e un motivo, il cantiere navi.

## Regole (fonti: SLYNYRD Pixelblog 3 e 45, guide di tilesets RPG)
1. **Proiezione unica** (3/4, camera di `forge3d` a 40 gradi): mai mescolare viste.
2. **Prima la porta.** Larghezza della porta in caselle intere, sul lato che guarda la strada; la casa si costruisce
   attorno. Lati: fronte (sud), fianco (est/ovest) con la porta visibile di lato. Mai una porta senza strada davanti.
3. **Varieta' da un kit, non da numeri casuali.** Almeno 5 forme di tetto (due falde, padiglione, a capanna corta, piatto
   con merli, cupola/cono) x 4 materiali di parete (pietra, intonaco, legno, graticcio) x dettagli (comignolo, balcone,
   insegna, persiane, vasi, scala esterna). Per quartiere una famiglia di colori di tetto (come Pokemon: forma uguale,
   colore diverso per zona).
4. **Elementi diversi dal muro.** Finestre, porte e comignoli mai dello stesso colore della parete; telai chiari.
5. **Distanza.** Fra due case almeno 2 caselle di passaggio o un vicolo; il tetto sporge a nord 3-4 caselle (vedi CLAUDE.md):
   la casa dietro deve stare piu' in alto di quella misura.
6. **Insegne.** Ogni bottega ha un'insegna appesa con un simbolo (fiala, incudine, pane, pesce, libro): e' un dato
   (`edifici` con `insegna`) e un disegno del kit.
7. **Monumenti = modelli propri** in creatures.py (o un modulo `architettura.py`): cattedrale (navata + 2 campanili +
   rosone + contrafforti + scalinata), faro (torre alta 3x una casa, lanterna, ballatoio), museo (colonnato, timpano,
   scalinata, stendardi), mercato (banchi con tende a strisce, casse, persone), dogana (cancello, garitta, guardie,
   bilancia), cantiere (scalo, nave in costruzione con le costole, gru di legno), centro antico (colonne spezzate,
   archi, pietra consumata, edera).
8. **Interni coerenti con l'esterno.** Ogni interno ha stanze diverse per uso (non "un rettangolo con tre blocchi"):
   letto e focolare nella casa, bancone e scaffali nella bottega, navata e altare in cattedrale.

## Controllo
- Guarda ogni edificio nella dashboard (Paesi e case) e nella mappa; fai la foto del gioco (`build.py --foto`).
- Prima di committare: nessun tetto che copre una porta, nessuna porta senza accesso (test di raggiungibilita').
