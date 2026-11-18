---
name: arte-icone
description: Icone degli oggetti di Mirwada, ognuna riconoscibile - niente due oggetti con lo stesso disegno, famiglie leggibili (minore/maggiore, ingredienti diversi). Usala prima di toccare forge3d/icone.py, tools/art/build_icone.py o data/ui/icone.json.
---


> Scelta dell'utente (2026-11-18): **ogni oggetto il suo disegno** 32x32 a griglia, contorno nero 1 px, 3 toni, famiglie riconoscibili (la maggiore piu' grande e decorata della minore).

# Icone riconoscibili

## Giudizio dell'utente (2026-11-18)
"la pozione di cura e la cura maggiore sono uguali, e un altro oggetto ha lo stesso disegno".
Oggi `fiala_rosso` e' usata da piu' di 8 oggetti (dashboard, Oggetti, filtro "solo icone uguali ad altre").

## Regole
1. **Un oggetto, un'icona.** Il validator dovra' rifiutare due oggetti con la stessa icona (salvo varianti volute,
   scritte nei dati).
2. **Famiglie con gradi visibili**: minore = fiala piccola e stretta; normale = boccetta; maggiore = fiasco grande col
   tappo di cera; rara = fiasco con aura. La grandezza e la forma cambiano, non solo il colore.
3. **Ingredienti da cio' che sono**: sangue = goccia nel vetro, radice = radice, polvere = mucchietto, ossa = osso...
   La forma viene dal nome (parole chiave in icone.py), il colore dalla materia.
4. **Silhouette diversa a 16 px** (nel libro le icone sono a 16 unita'): prova in nero.
5. Coerenza: stessa luce, contorno 1 px, palette Endesga 32.

## Controllo
- Dashboard, scheda Oggetti, filtro "solo icone uguali ad altre": deve restare vuoto.
