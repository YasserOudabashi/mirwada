---
name: arte-effetti
description: Effetti delle abilita' di Mirwada (VFX) con una forma e un movimento propri per ogni primitiva, non solo un colore diverso. Usala prima di toccare forge3d/vfx.py, tools/art/build_vfx.py o data/vfx.json.
---

# Effetti con individualita'

## Giudizio dell'utente (2026-11-18)
"le animazioni delle abilita' sono troppo simili, cambia solo il colore, non c'e' individualita'".

## Regole (fonti: guida VFX di League of Legends, "shape, color and motion" su 80.lv)
1. **Forma + movimento + colore**, in quest'ordine. Il colore del Pathway resta (shader), ma due primitive diverse
   devono distinguersi in bianco e nero e da ferme.
2. **Una forma primaria e una secondaria** per primitiva. Esempi:
   - cura: croci e gocce che salgono; scudo: esagoni che si chiudono a cupola; paura: occhi e strappi che si allargano;
   - maledizione: catene/sigillo che si stringe sul bersaglio; possessione: fili che tirano; anima recisa: taglio
     verticale con la sagoma che esce; furto: mano che afferra e torna; fioritura: petali e germogli dal basso;
   - teletrasporto: colonna che si apre e si richiude; illusione: copie sfasate; tempo: anelli d'orologio che girano
     al contrario.
3. **Movimento diverso**: esplode, sale, si stringe, gira, scorre, pulsa. Mai due primitive con lo stesso movimento.
4. **Leggibile a 32-64 px**: tratti larghi, pochi elementi, impatto in 1 frame bianco (spento con riduci_flash).
5. **Per Pathway** si possono aggiungere motivi (il "tratto" di vfx.json: pennellata carica, secca...).

## Controllo
- Dashboard, scheda Tecniche: ogni effetto grande, in tutti i colori dei Pathway, velocita' regolabile.
- Test: metti due effetti in scala di grigi uno accanto all'altro; se sembrano uguali, rifai.
