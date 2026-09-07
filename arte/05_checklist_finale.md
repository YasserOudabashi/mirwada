# Checklist finale — prima di committare un'immagine

Da `006_PRD/art-brief-gemini.md` cap. 7-8, valida per qualunque categoria
(personaggi, regioni, sprite, VFX, UI).

## Checklist di qualita'

- [ ] **Palette**: inchiostro scuro + massimo 2 colori in piu' per le
      illustrazioni, outline + 3 colori per la pixel art. Un colore in piu' =
      rifiuta e ridisegna.
- [ ] **Stile**: neri pieni, tratto a pennello, spazio negativo. Se sembra un
      render 3D o un disegno "anime carino" = rifiuta.
- [ ] Niente testo, watermark, firme o cornici decorative sull'immagine.
- [ ] Guardaroba e ambiente coerenti con l'inizio del Novecento — non
      moderni, non fantasy generico con armature di piastre.
- [ ] Key art di regione: nessun elemento di UI, nessun HUD nell'immagine.
- [ ] Ritratti in serie: sfondo, luce e inquadratura identici su tutto il
      set (vedi `01_personaggi.md` cap. 3).
- [ ] Sprite generati con IA: sono un **riferimento**, non un asset — nessuno
      li droppa in `assets/` senza la post-produzione (griglia 32px esatta,
      sfondo trasparente, frame tagliati agli indici giusti).
- [ ] Combattimento/VFX: l'effetto resta leggibile anche con
      `riduci_flash`/`riduci_distorsione` attivi.

## Dove finisce ogni cosa

```
assets/concept/
  regioni/       mirwada.png, marche_crepuscolo.png, valle_madre.png,
                 archivio_sepolto.png, frontiera_porte.png,
                 trono_del_gigante.png
  ritratti/      enel.png, mirco.png, sidon.png, vesna.png, aldo.png,
                 ottavia.png, bruno.png, lena.png, doran.png
  ui/            scaffale.png, pagina_pulita.png, pagina_follia.png,
                 bordi.png, erbario.png, frontespizio.png, voltata.png
  sprite_ref/    enel_turnaround.png, nemico_turnaround.png,
                 tileset_<regione>.png

assets/placeholder/   <-- ASSET REALI di gioco, caricati dal codice.
                          Convenzione nome file: <categoria>_<nome>.png
                          (es. personaggio_idle.png, nemico_base_attack.png)
```

`assets/concept/` e' materiale di **riferimento**, versionato ma mai caricato
dal gioco. `assets/placeholder/` (nome storico: resta cosi' anche quando
l'arte non e' piu' un vero placeholder) e' cio' che il codice usa davvero.

## Come verificare

1. Se e' uno sprite/animazione: rilancia il gioco (hot-reload F5) e controlla
   a schermo che il timing sia quello di `data/animations.json` — un frame
   ritagliato male sposta silenziosamente il tempismo del combattimento.
2. Se e' un dato che il validator controlla (regioni, palette, location_tags):
   ```bash
   python tools/validate_data.py
   ```
   deve uscire 0.
3. Se e' materiale di riferimento (`assets/concept/`): nessuna verifica
   automatica, solo la checklist di qualita' sopra.

## Nota IP (richiamo da `CLAUDE.md`)

Il sistema di riferimento narrativo di Mirwada e' opera protetta di terzi.
Progetto personale, non distribuibile ne' monetizzabile con i nomi attuali.
L'arte generata con IA e' esplicitamente "alla maniera di" uno stile
esistente (manhwa coreano): materiale di riferimento interno, mai da
pubblicare o ridistribuire come opera originale.
