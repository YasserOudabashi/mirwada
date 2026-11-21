#!/usr/bin/env python3
"""Consumo di token delle sessioni di Claude Code su questo progetto e quanto costerebbero all'API (dashboard).

    python tools/dashboard/consumo.py                 # tutte le sessioni trovate -> build/dashboard/consumo.json
    python tools/dashboard/consumo.py FILE.jsonl ...  # solo quelle

Claude Code salva ogni sessione in ~/.claude/projects/<cartella>/<sessione>.jsonl con i token di ogni risposta
(entrata, cache scritta a 5 minuti o a 1 ora, cache letta, uscita) e il modello. Qui si sommano, una risposta una
volta sola (stesso id = stessa risposta), si moltiplicano per il listino API e si dividono per giorno e per story:
una risposta conta per la prima story chiusa dopo di lei (commit "US-...: ..."). Con l'abbonamento non si paga
questa cifra: e' quanto costerebbe lo stesso lavoro con l'API.
"""
import glob
import json
import os
import re
import subprocess
import sys
from datetime import datetime

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
# Listino API in dollari per milione di token (skill claude-api, aggiornato il 2026-11-03). Cache scritta: 1.25x
# l'entrata a 5 minuti, 2x a 1 ora; cache letta: il suo prezzo.
PREZZI = {
    "claude-opus-5-5": {"in": 4.0, "out": 20.0, "letta": 0.20},
    "claude-fable-5-2": {"in": 8.0, "out": 40.0, "letta": 0.20},
    "claude-sonnet-5-5": {"in": 2.0, "out": 10.0, "letta": 0.10},
    "claude-haiku-5-5": {"in": 0.10, "out": 0.50, "letta": 0.01},
}
LISTINO = "listino API del 2026-11-03"


def costo(modello, u):
    p = PREZZI.get(modello)
    if p is None:
        return None
    return (u["input"] * p["in"] + u["cache_5m"] * p["in"] * 1.25 + u["cache_1h"] * p["in"] * 2.0
            + u["cache_letta"] * p["letta"] + u["output"] * p["out"]) / 1e6


def commit_storie():
    out = []
    log = subprocess.run(["git", "log", "--all", "--pretty=format:%cI\t%s"], cwd=ROOT, capture_output=True, text=True).stdout
    for riga in log.splitlines():
        d, m = riga.split("\t", 1)
        k = re.match(r"(US-[A-Z0-9]+[a-z]?)", m)
        if k:
            out.append((datetime.fromisoformat(d), k.group(1)))
    return sorted(out)


def leggi(path):
    risposte = {}
    inizio = fine = None
    for riga in open(path, encoding="utf-8"):
        try:
            d = json.loads(riga)
        except ValueError:
            continue
        ts = d.get("timestamp")
        m = d.get("message")
        if not ts:
            continue
        inizio = inizio or ts
        fine = ts
        if not isinstance(m, dict) or not m.get("usage") or m.get("model", "").startswith("<"):
            continue
        u = m["usage"]
        cc = u.get("cache_creation") or {}
        risposte[m.get("id") or d.get("uuid")] = (ts, m["model"], {
            "input": u.get("input_tokens", 0), "output": u.get("output_tokens", 0),
            "cache_letta": u.get("cache_read_input_tokens", 0),
            "cache_1h": cc.get("ephemeral_1h_input_tokens", 0),
            "cache_5m": cc.get("ephemeral_5m_input_tokens", u.get("cache_creation_input_tokens", 0) if not cc else 0)})
    return risposte, inizio, fine


def sessione(path, storie):
    risposte, inizio, fine = leggi(path)
    if not risposte:
        return None
    modelli, giorni, per_storia = {}, {}, {}
    for ts, mod, u in risposte.values():
        t = modelli.setdefault(mod, {"chiamate": 0, "input": 0, "output": 0, "cache_letta": 0, "cache_1h": 0, "cache_5m": 0})
        t["chiamate"] += 1
        for k in ("input", "output", "cache_letta", "cache_1h", "cache_5m"):
            t[k] += u[k]
        c = costo(mod, u) or 0.0
        giorni[ts[:10]] = giorni.get(ts[:10], 0.0) + c
        quando = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        st = next((s for d, s in storie if d >= quando), "in corso")
        per_storia[st] = per_storia.get(st, 0.0) + c
    for mod, t in modelli.items():
        t["costo"] = round(costo(mod, t) or 0.0, 2) if mod in PREZZI else None
    tot = round(sum(t["costo"] or 0.0 for t in modelli.values()), 2)
    return {"id": os.path.basename(path)[:-6], "inizio": inizio, "fine": fine, "listino": LISTINO,
            "modelli": modelli, "costo": tot,
            "giorni": {k: round(v, 2) for k, v in sorted(giorni.items())},
            "storie": {k: round(v, 2) for k, v in sorted(per_storia.items(), key=lambda kv: -kv[1])}}


def main():
    files = sys.argv[1:] or [f for f in glob.glob(os.path.expanduser("~/.claude/projects/*/*.jsonl"))]
    storie = commit_storie()
    out = [s for s in (sessione(f, storie) for f in files) if s]
    os.makedirs(os.path.join(ROOT, "build", "dashboard"), exist_ok=True)
    dest = os.path.join(ROOT, "build", "dashboard", "consumo.json")
    with open(dest, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    for s in out:
        print(f"{s['id']}: {s['inizio'][:10]}..{s['fine'][:10]}, circa {s['costo']} $ "
              + ", ".join(f"{m} {t['chiamate']} risposte" for m, t in s["modelli"].items()))
    print("->", os.path.relpath(dest, ROOT))


if __name__ == "__main__":
    main()
