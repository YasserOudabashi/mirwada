---
name: arte-mondo
description: Rendere il mondo di Mirwada pieno e vivo - dettagli per bioma e quartiere, scene raccontate dai luoghi (campo di battaglia con resti, cantiere con navi), gente e animali, sottosuolo con stanze diverse. Usala prima di toccare forge3d/world.py, esporta_mondo.py, fauna.json o il popolamento del mondo.
---


> Scelta dell'utente (2026-11-18): terreni, alberi e arredi **a griglia** nello stesso stile delle figure; la modalita' cupa ha **disegni propri** (rovine, nebbia, forme delle concept); mappa e biomi approvati restano.

# Mondo pieno e vivo

## Giudizi dell'utente (2026-11-18)
- "il mondo deve sembrare piu' pieno, vivo"; "niente ha il suo dettaglio, la sua particolarita'";
- campo di battaglia: dove sono sangue, scheletri, armi, segni? Cantiere navale: dove sono le navi?
- il sottosuolo e i paesi sono tutti uguali: un rettangolo con dentro tre blocchi.

## Regole
1. **Ogni luogo racconta qualcosa.** Per ogni luogo di `mondo.json luoghi` un "set" di oggetti di scena che ne dice la
   storia (dato in `data/world/scene.json`, posato da esporta_mondo): campo di battaglia = armi piantate, elmi, ossa,
   carri rotti, stendardi strappati, crateri; cantiere = navi sugli scali, legname, gru; mercato = banchi, ceste, gente.
2. **Tre scale di dettaglio.** Grandi (case, alberi), medi (carri, recinti, pozzi, statue), piccoli (fiori, sassi,
   erba alta, pozzanghere). Il mondo di oggi ha quasi solo i grandi.
3. **Vita.** Gente che cammina fra luoghi (NPC comparse con orari), animali (fauna), fumo dai comignoli, bucato, barche
   che passano, uccelli: tutto da dati, mai a mano.
4. **Sottosuolo a stanze.** Fogne, catacombe, grotte, miniere con stanze tipo (cripta con nicchie, cisterna, galleria con
   binari, sala del boss, nido) collegate da corridoi; ogni tipo con i suoi oggetti e luci.
5. **Densita' misurata.** Conta gli oggetti per blocco e per tipo: un blocco abitato ne ha almeno 20 piccoli.

## Controllo
- Dashboard, scheda Mondo: foto di ogni luogo, giudizio dell'utente; le note "rifare" diventano story.
