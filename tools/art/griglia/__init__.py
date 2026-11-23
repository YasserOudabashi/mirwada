"""Pixel art a griglia su scheletro (scelte artistiche dell'utente, 2026-11-18).

Lo scheletro (corpo.py) e' comune: dice solo dove stanno le giunture in ogni fotogramma e da che parte si guarda.
Tutto quello che si vede e' del personaggio: testa e faccia disegnate a griglia per ogni vista, forma e colori del
corpo, vestiti, accessori, arma (figure/<id>.py). Due personaggi non condividono nessun disegno.

pixel.py   tela, rampe a 3 toni, segmenti ombreggiati, griglie, contorno nero di 1 px (fuori e fra le parti)
corpo.py   scheletro umano e a quattro zampe, proiezione top-down 3/4, ordine di profondita'
pose.py    chiavi di posa a tempo normalizzato (0..1): il numero di frame viene da data/animations.json
"""
