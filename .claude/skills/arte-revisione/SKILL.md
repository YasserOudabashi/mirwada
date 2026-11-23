---
name: arte-revisione
description: Il giro di revisione dell'arte con l'utente attraverso la dashboard (Officina di Mirwada) - leggere i suoi giudizi e le note, trasformarli in story, rifare, rifotografare, ripubblicare. Usala a inizio sessione e ogni volta che l'utente dice di aver messo note sul sito.
---

# Revisione con la dashboard

Pagina: vedi CLAUDE.md "Dashboard del progetto" (link, comandi, regola di fine sessione).

1. **Leggi i giudizi**: ArtifactData `list` su `giudizi` (limit 1000, out_dir nello scratchpad). Ogni documento
   `<tipo>:<id>` = {stato "ok"|"no", nota}. I "no" sono lavoro; gli "ok" non si toccano senza chiedere.
2. **Raggruppa** le note per skill: personaggi/nemici/boss -> arte-personaggi; case/luoghi/villaggi/interni ->
   arte-architettura e arte-mondo; abilita'/effetti -> arte-effetti; oggetti/stati -> arte-icone.
3. **Scelte artistiche prima dei disegni**: se le note chiedono un cambio di stile, proponi all'utente 2-3 prove
   affiancate (stesso soggetto) e fai scegliere; solo dopo rifai tutto con lo stesso stile.
4. **Rifai, guarda, rifotografa**: rigenera, guarda ingrandito, `python tools/dashboard/build.py --foto`, ripubblica
   allo stesso link. Non cancellare i giudizi: l'utente li ricambia lui.
5. **Annota** in progress.txt quali note hai chiuso e con cosa.
