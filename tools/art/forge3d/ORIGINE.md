# forge3d — copia fissata della skill sprite-forge

Copiata il 2026-10-13 da `sprite-forge/scripts/forge3d/` (US-8B02), così la
rigenerazione degli asset non dipende da una cartella fuori dal repo:
stessi parametri + stesso seed = stessi PNG, anche su un altro PC.

- Gli script in `tools/art/` importano **questa** copia, non la skill.
- I terreni nuovi del progetto vanno qui (`terrain.py`, una riga in `TERRAINS`).
- `ORIGINE.sha256`: hash dei file al momento della copia, per vedere cosa
  abbiamo cambiato rispetto all'originale (`sha256sum -c ORIGINE.sha256`).
- Dipendenze: Python 3, `numpy`, `pillow`.
