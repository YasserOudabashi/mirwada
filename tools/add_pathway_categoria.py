#!/usr/bin/env python3
"""
Aggiunge il campo 'categoria' ('standard') a ogni file di data/pathways/ e
data/pathways_deferred/ (fase 9, US-901): distingue i Pathway standard
(pozione+recitazione) da quelli non_standard (Boon,
data/pathways_non_standard/, vedi data/schema/boon.schema.json).

Esecuzione (dalla root del progetto):
    python tools/add_pathway_categoria.py

Idempotente: un file che ha gia' 'categoria' non viene toccato. Come
generate_i18n_stubs.py, riscrive i dati esistenti invece di editarli a mano.
"""

import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DATA = os.path.join(ROOT, "data")
DIRS = ["pathways", "pathways_deferred"]


def _con_categoria(doc):
    """Nuovo dict con 'categoria': 'standard' inserito subito dopo 'id',
    tutte le altre chiavi nello stesso ordine."""
    out = {}
    for k, v in doc.items():
        out[k] = v
        if k == "id":
            out["categoria"] = "standard"
    if "categoria" not in out:
        out["categoria"] = "standard"
    return out


def main():
    toccati = 0
    for sub in DIRS:
        d = os.path.join(DATA, sub)
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            if not fn.endswith(".json"):
                continue
            path = os.path.join(d, fn)
            with open(path, encoding="utf-8") as fh:
                doc = json.load(fh)
            if doc.get("categoria") == "standard":
                continue
            doc = _con_categoria(doc)
            with open(path, "w", encoding="utf-8") as fh:
                json.dump(doc, fh, indent=2, ensure_ascii=False)
                fh.write("\n")
            toccati += 1
            print(f"  {sub}/{fn}: categoria aggiunta")
    print(f"fatto: {toccati} file aggiornati")


if __name__ == "__main__":
    main()
