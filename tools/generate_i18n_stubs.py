#!/usr/bin/env python3
"""
Genera/aggiorna i cataloghi di stringhe dei DATI: data/i18n/it.json e
data/i18n/en.json.

Esecuzione (dalla root del progetto):
    python tools/generate_i18n_stubs.py            # applica
    python tools/generate_i18n_stubs.py --check    # solo diagnosi, exit 1 se serve un run

Cosa fa:
  1. Scandisce data/ (esclusi schema/, i18n/, pathways_deferred/) per ogni
     campo che finisce in "_i18n".
  2. Convenzione unica (vedi CLAUDE.md sez. i18n):
         <categoria>[.<pathway_id>].<local>
     - il segmento <pathway_id> c'e' per le entita' di un Pathway
       (sequence, ability, acting, characteristic, form); non c'e' per le
       entita' globali (anchor, synergy) ne' per 'pathway' stesso
     - local: l'id dell'entita' verbatim (per anchor/synergy meno il prefisso
       di tipo ridondante), o il numero per sequence/characteristic
     Le chiavi 'acting.*' e 'ability.*' erano le uniche a divergere e vengono
     riscritte sul posto nei file di dati. Le altre categorie erano gia'
     coerenti: le chiavi si raccolgono verbatim.
  3. Scrive data/i18n/it.json e en.json:
     - chiave gia' tradotta: valore preservato
     - chiave nuova: stub "TODO <chiave>" (leggibile a schermo, greppabile)
     - chiave sparita: rimossa
     it.json ha una voce per ogni chiave; en.json solo quelle davvero tradotte.

pathways_deferred/ e' fuori scope: se un gruppo viene riattivato, ri-lancia
questo tool e traduci i nuovi stub.

NON tocca assets/i18n/strings.csv: quello e' il sistema tr() di Godot per la
UI chrome (HUD). Sistemi separati, per scelta documentata in CLAUDE.md.
"""

import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DATA = os.path.join(ROOT, "data")
I18N_DIR = os.path.join(DATA, "i18n")
STUB_PREFIX = "TODO "
EXCLUDE_DIRS = {"schema", "i18n", "pathways_deferred"}


def rel(path):
    return os.path.relpath(path, ROOT).replace(os.sep, "/")


def is_stub(v):
    return isinstance(v, str) and v.startswith(STUB_PREFIX)


def json_files():
    for dirpath, dirnames, filenames in os.walk(DATA):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
        for fn in sorted(filenames):
            if fn.endswith(".json"):
                yield os.path.join(dirpath, fn)


def collect(apply):
    """Ritorna (keys:set, rewrites:list, seed:dict). seed = testo italiano gia'
    presente nei dati come campo gemello in chiaro (descrizione_i18n -> 'descrizione',
    name_i18n -> 'name'). Se apply, riscrive le chiavi non canoniche nei dati."""
    keys, rewrites, seed = set(), [], {}

    for path in json_files():
        with open(path, encoding="utf-8") as fh:
            doc = json.load(fh)
        changed = False
        r = rel(path)

        def register(key, obj, field):
            keys.add(key)
            plain = obj.get(field[:-5])  # descrizione_i18n -> descrizione, name_i18n -> name
            if isinstance(plain, str) and plain.strip():
                seed[key] = plain.strip()

        def take(obj):
            """Raccoglie ogni campo *_i18n verbatim."""
            for field in obj:
                if field.endswith("_i18n") and isinstance(obj[field], str):
                    register(obj[field], obj, field)

        def canon(obj, field, want):
            """Raccoglie e, se diverge, riscrive alla forma canonica."""
            nonlocal changed
            have = obj.get(field)
            register(want, obj, field)
            if have != want:
                rewrites.append(f"{r}: {have}  ->  {want}")
                if apply:
                    obj[field] = want
                    changed = True

        if "/pathways/" in r:
            pid = doc.get("id", "")
            take(doc)
            for seq in doc.get("sequences", []):
                take(seq)
                for act in seq.get("acting_actions", []):
                    if "descrizione_i18n" in act:
                        canon(act, "descrizione_i18n", f"acting.{pid}.{act.get('id', '')}")

        elif "/abilities/" in r:
            for ab in (doc if isinstance(doc, list) else doc.get("abilities", [])):
                scope = re.sub(r"_\d+$", "", ab.get("sequence_id", "")) or "unknown"
                if "name_i18n" in ab:
                    canon(ab, "name_i18n", f"ability.{scope}.{ab.get('id', '')}")

        else:
            def walk(v):
                if isinstance(v, dict):
                    take(v)
                    for x in v.values():
                        walk(x)
                elif isinstance(v, list):
                    for x in v:
                        walk(x)
            walk(doc)

        if apply and changed:
            with open(path, "w", encoding="utf-8", newline="\n") as fh:
                json.dump(doc, fh, ensure_ascii=False, indent=2)
                fh.write("\n")

    return keys, rewrites, seed


def write_catalog(locale, keys, seed, every_key):
    path = os.path.join(I18N_DIR, f"{locale}.json")
    existing = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as fh:
            existing = json.load(fh)

    out = {}
    for k in sorted(keys):
        if k in existing and not is_stub(existing[k]):
            out[k] = existing[k]                     # traduzione autoriale: preservata
        elif locale == "it" and k in seed:
            out[k] = seed[k]                         # testo gia' in chiaro nei dati
        elif every_key:
            out[k] = STUB_PREFIX + k

    os.makedirs(I18N_DIR, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=2, sort_keys=True)
        fh.write("\n")
    return len(out), sum(1 for v in out.values() if is_stub(v))


def main():
    check = "--check" in sys.argv
    keys, rewrites, seed = collect(apply=not check)

    if rewrites:
        print(f"{'DA CANONICALIZZARE' if check else 'CANONICALIZZATE'}: {len(rewrites)} chiavi")
        for x in rewrites:
            print("  " + x)

    it_path = os.path.join(I18N_DIR, "it.json")
    if check:
        existing = json.load(open(it_path, encoding="utf-8")) if os.path.exists(it_path) else {}
        missing = sorted(k for k in keys if k not in existing)
        if missing:
            print(f"MANCANTI in data/i18n/it.json: {len(missing)}")
            for m in missing[:20]:
                print("  " + m)
        return 1 if (rewrites or missing) else 0

    it_n, it_stubs = write_catalog("it", keys, seed, every_key=True)
    en_n, _ = write_catalog("en", keys, seed, every_key=False)
    print(f"data/i18n/it.json: {it_n} chiavi, {it_stubs} da tradurre (TODO ...)")
    print(f"data/i18n/en.json: {en_n} chiavi tradotte (catalogo incompleto per scelta)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
