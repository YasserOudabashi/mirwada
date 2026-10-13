# forge3d — copia fissata della skill sprite-forge

Copiata il 2026-10-13 da `sprite-forge/scripts/forge3d/` (US-8B02), così la
rigenerazione degli asset non dipende da una cartella fuori dal repo:
stessi parametri + stesso seed = stessi PNG, anche su un altro PC.

- Gli script in `tools/art/` importano **questa** copia, non la skill.
- I terreni nuovi del progetto vanno qui (`terrain.py`, una riga in `TERRAINS`).
- `ORIGINE.sha256`: hash dei file al momento della copia, per vedere cosa
  abbiamo cambiato rispetto all'originale (`sha256sum -c ORIGINE.sha256`).
- Dipendenze: Python 3, `numpy`, `pillow`.

## Modifiche rispetto all'originale

| Data | File | Cosa | Perché |
|---|---|---|---|
| 2026-10-13 | `terrain.py` | `hash(name)` → `zlib.crc32(name.encode())` | `hash()` sulle stringhe cambia a ogni avvio di Python: la texture dei terreni era diversa a ogni lancio, anche con lo stesso seed. Da riportare anche nella skill. |
| 2026-10-13 | `terrain.py` | campo `contrast` (default 1), `accent`, `cells`; `_voronoi()` estratto da `cobbles` | US-8B11a: con `contrast` < 1 le macchie di fondo si attenuano e la ripetizione del tile non forma più un disegno visibile. |
| 2026-10-13 | `terrain.py` | 8 motivi nuovi: `slabs`, `rows`, `planks`, `herringbone`, `strata`, `plates`, `embers`, `dunes` | US-8B11a: lastre, filari, assi, parquet, strati di roccia, lamiera e grate, crepe di lava, dune di neve. Misure in frazioni di S: valgono a 32 e a 64 px. |
| 2026-10-13 | `terrain.py` | ritocchi: `grass` contrast 0.45, `water` turchese (`#1fb5d6` extra), `snow` dune + contrast 0.2 | Risposte dell'utente (US-8B11). |
