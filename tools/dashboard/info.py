"""Dashboard: le schede informative di ogni elemento (perche' esiste, cosa fa nel gioco, dove si trova).

Tutto si ricava dai dati: chi sta in un luogo (orari degli NPC), quali nemici e oggetti ci sono (layout), quali rituali
lo chiedono, dove si trova un oggetto (a terra, nei forzieri, nei negozi, dai nemici) e a cosa serve (pozioni, ricette,
rituali). Una scheda e' una lista di [titolo, [righe]]; la pagina le mostra nel dettaglio.
"""
import glob
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA = os.path.join(ROOT, "data")

# Cosa fa ogni primitiva, in parole semplici (solo per la dashboard: il gioco usa i parametri dei dati).
PRIMITIVE = {
    "projectile": "tira un colpo che vola dritto e colpisce il primo nemico", "melee_arc": "colpo a semicerchio davanti a se'",
    "aura": "cerchio attorno a chi lancia che fa effetto a chi c'e' dentro", "dot": "danno a poco a poco nel tempo",
    "heal": "cura", "buff_stat": "alza per un po' una statistica di chi lancia", "debuff_stat": "abbassa una statistica del nemico",
    "dash": "scatto veloce in una direzione", "summon": "chiama una creatura che aiuta", "shield": "scudo che assorbe danno",
    "transform": "cambia forma (fogli e statistiche della forma)", "teleport": "sparisce e ricompare poco piu' in la'",
    "reveal_info": "mostra cose nascoste (pericoli, tesori, intenzioni)", "illusion": "crea un'immagine falsa che inganna",
    "curse": "maledizione sul nemico", "possess": "prende il controllo di un nemico per un po'", "soul_sever": "strappa via l'anima: danno grosso",
    "fear": "spaventa: il nemico scappa", "light_purify": "luce che toglie gli stati negativi", "steal": "ruba un oggetto o un effetto",
    "bloom": "fa crescere piante: cura o intralcia", "decay": "fa marcire: danno spalmato nel tempo", "time_shift": "rallenta o accelera il tempo vicino",
    "gate": "apre un passaggio", "conjure": "crea un oggetto", "mirage": "copia ingannevole", "grip": "trattiene il nemico sul posto",
    "ward": "barriera che protegge un luogo",
}


def j(*p):
    with open(os.path.join(ROOT, *p), encoding="utf-8") as f:
        return json.load(f)


def _layouts():
    out = {}
    for f in glob.glob(os.path.join(DATA, "world", "layouts", "*.json")):
        lay = json.load(open(f, encoding="utf-8"))
        out[lay["region_id"]] = lay
    return out


def _in_zona(x, y, r):
    return r[0] <= x < r[0] + r[2] and r[1] <= y < r[1] + r[3]


def costruisci(dati, tr):
    """dati: il dizionario della dashboard gia' pieno. Ritorna {chiave: [[titolo, [righe]]]}."""
    INFO = {}
    nome_ogg = {o["id"]: o["nome"] for o in dati["oggetti"]}
    nome_nem = {n["id"]: n["nome"] for n in dati["nemici"]}
    nome_npc = {n["id"]: n["nome"] for n in dati["personaggi"]["npc"]}
    regioni = {r["id"]: r for r in j("data", "world", "regions.json")["regions"]}
    mondo = j("assets", "world", "mondo.json")
    reg_img = np.asarray(Image.open(os.path.join(ROOT, "assets", "world", "regioni.png")))
    ordine = mondo["regioni"]
    layouts = _layouts()
    no = lambda i: nome_ogg.get(i, i.replace("_", " "))

    def add(k, titolo, righe):
        righe = [r for r in righe if r]
        if righe:
            INFO.setdefault(k, []).append([titolo, righe])

    # --- dove si trova ogni oggetto e a cosa serve ----------------------------------------------------------------
    fonti, usi = {}, {}
    f = lambda i, t: fonti.setdefault(i, []).append(t)
    for rid, lay in layouts.items():
        rn = regioni.get(rid, {}).get("name", rid)
        for o in lay.get("oggetti", []):
            zona = next((t for t, r in lay.get("zone", {}).items() if _in_zona(o["x"], o["y"], r)), None)
            f(o["item_id"], f"a terra: {rn}" + (f", zona {zona.replace('_', ' ')}" if zona else ""))
        for seq, items in lay.get("drop", {}).items():
            for i in items:
                f(i, f"lo lasciano i nemici di Sequenza {seq} in {rn}")
    for fi in glob.glob(os.path.join(DATA, "world", "interni", "*.json")):
        it = json.load(open(fi, encoding="utf-8"))
        for o in it.get("oggetti", []):
            f(o.get("item_id"), "a terra nell'interno " + os.path.basename(fi)[:-5].replace("_", " "))
    bott = j("data", "world", "bottino.json")
    for tab, t in bott["tabelle"].items():
        if tab.startswith("_"):
            continue
        for v in t.get("voci", []):
            f(v["item_id"], f"nei forzieri e nelle case (tabella {tab})")
    for n in j("data", "npc", "roster.json")["npcs"]:
        for i in (n.get("vendor") or {}).get("listino", []):
            f(i, "in vendita da " + nome_npc.get(n["id"], n["id"]))
    for r in j("data", "potions", "recipes.json")["recipes"].values() if isinstance(j("data", "potions", "recipes.json")["recipes"], dict) else []:
        out = (r.get("output") or {}).get("item_id")
        for i in r.get("ingredienti", {}):
            usi.setdefault(i, []).append("ricetta: " + no(out))
        if out:
            f(out, "si prepara con una ricetta (" + ", ".join(no(i) for i in r.get("ingredienti", {})) + ")")
    for pw in dati["tecniche"]["pathway"]:
        p = json.load(open(os.path.join(DATA, "pathways", pw["id"] + ".json"), encoding="utf-8"))
        for s in p["sequences"]:
            for i in (s.get("potion") or {}).get("ingredients", []):
                usi.setdefault(i, []).append(f"pozione di {pw['nome']} (per lasciare la Sequenza {s['sequence']})")
            rit = s.get("advancement_ritual") or {}
            for i in rit.get("sacrifices", []) + rit.get("sigils", []):
                usi.setdefault(i, []).append(f"rituale di {pw['nome']}, Sequenza {s['sequence']}")
    icone = {}
    for o in dati["oggetti"]:
        icone.setdefault(o["icona"], []).append(o["nome"])
    for o in dati["oggetti"]:
        k = "oggetto:" + o["id"]
        add(k, "Cos'e'", [o["descrizione"]])
        add(k, "Dove si trova", sorted(set(fonti.get(o["id"], []))) or ["in nessun posto dei dati: non si trova ancora nel gioco"])
        add(k, "A cosa serve", sorted(set(usi.get(o["id"], []))))
        altri = [x for x in icone.get(o["icona"], []) if x != o["nome"]]
        add(k, "Icona", [f"{o['icona']}" + (f" — uguale a: {', '.join(altri[:8])}" + (" e altri" if len(altri) > 8 else "") if altri else " — solo sua")])

    # --- luoghi e villaggi ------------------------------------------------------------------------------------------
    for tipo, el in (("luogo", dati["mondo"]["luoghi"]), ("villaggio", dati["mondo"]["villaggi"])):
        for l in el:
            k = f"{tipo}:{l['id']}"
            ri = int(reg_img[min(l["y"], reg_img.shape[0] - 1), min(l["x"], reg_img.shape[1] - 1)])
            rid = ordine[ri] if ri < len(ordine) else ""
            reg = regioni.get(rid, {})
            tag = (reg.get("luoghi_mondo") or {}).get(l["id"], l["id"])
            rn = reg.get("name", rid.replace("_", " "))
            add(k, "Dove", [f"Regione: {rn}" + (f" (zona {tag.replace('_', ' ')})" if tag in reg.get("location_tags", []) else ""),
                            f"Casella {l['x']}, {l['y']}", "Come ci si arriva: " + ", ".join(reg.get("accesso", ["a piedi"])) if reg.get("accesso") else None])
            chi = []
            for n in j("data", "npc", "roster.json")["npcs"]:
                if n.get("region_id") == rid:
                    m = [s["momento"].replace("_", " ") for s in n.get("schedule", []) if s.get("location_tag") == tag]
                    if m:
                        chi.append(f"{nome_npc.get(n['id'], n['id'])} ({', '.join(m)})" + (" — negozio" if n.get("vendor") else ""))
            add(k, "Chi ci trovi", chi)
            lay = layouts.get(rid, {})
            z = (lay.get("zone") or {}).get(tag)
            if z:
                nem = {}
                for n in lay.get("nemici", []):
                    if _in_zona(n["x"], n["y"], z):
                        nn = nome_nem.get(n.get("tipo"), n.get("tipo")) + (" (boss)" if n.get("boss") else "")
                        nem[nn] = nem.get(nn, 0) + 1
                add(k, "Nemici", [f"{n} ×{c}" for n, c in nem.items()])
                add(k, "Oggetti a terra", sorted({no(o["item_id"]) for o in lay.get("oggetti", []) if _in_zona(o["x"], o["y"], z)}))
            rit = []
            for pw in dati["tecniche"]["pathway"]:
                p = json.load(open(os.path.join(DATA, "pathways", pw["id"] + ".json"), encoding="utf-8"))
                for s in p["sequences"]:
                    if tag in ((s.get("advancement_ritual") or {}).get("location_tags") or []):
                        rit.append(f"{pw['nome']}, per lasciare la Sequenza {s['sequence']}")
            add(k, "Rituali che si fanno qui", rit)
            if tipo == "villaggio":
                add(k, "Edifici", [f"{n} {t.replace('_', ' ')}" for t, n in l.get("edifici", {}).items()])
                add(k, "Porte verso gli interni", [p.replace("_", " ") for p in l.get("porte", [])])

    # --- interni ------------------------------------------------------------------------------------------------------
    for i in dati["mondo"]["interni"]:
        it = j("data", "world", "interni", i["id"] + ".json")
        k = "interno:" + i["id"]
        add(k, "Cos'e'", [f"Stile {it.get('stile', '')}".strip()])
        add(k, "Nemici", [nome_nem.get(n.get("tipo"), n.get("tipo")) for n in it.get("nemici", [])])
        add(k, "Oggetti a terra", [no(o.get("item_id")) for o in it.get("oggetti", [])])
        add(k, "Forzieri", [f"{x.get('id')}: tabella {x.get('tabella')}" for x in it.get("forzieri", [])])
        add(k, "Arredi", sorted({a.get("tipo", a.get("id", "")) if isinstance(a, dict) else str(a) for a in it.get("arredi", [])}))

    # --- nemici, boss -------------------------------------------------------------------------------------------------
    drop_di = {}
    for rid, lay in layouts.items():
        for n in lay.get("nemici", []):
            for seq, items in lay.get("drop", {}).items():
                if str(n.get("sequenza")) == seq:
                    drop_di.setdefault(n.get("tipo"), set()).update(items)
    spiega_comp = {"mischia": "si avvicina e colpisce da vicino", "distanza": "resta lontano e tira", "carica": "prende la rincorsa e carica in linea retta",
                   "volo": "vola sopra i dislivelli (non sopra l'acqua)"}
    for n in dati["nemici"]:
        k = "nemico:" + n["id"]
        add(k, "Come combatte", [spiega_comp.get(n["comportamento"], n["comportamento"]),
                                 "tell lungo e leggibile" if n["rarita"] == "comune" else "tell corto: piu' teso da affrontare"])
        add(k, "Dove", [f"{r.replace('_', ' ')} ×{c}" for r, c in n["dove"].items()] or ["non posato nel mondo"])
        add(k, "Cosa lascia", sorted(no(i) for i in drop_di.get(n["id"], [])))
    for b in dati["boss"]:
        k = "boss:" + b["id"]
        add(k, "Dove", [f"{b['posato'].get('regione', '').replace('_', ' ')}, Sequenza {b['posato'].get('sequenza')}" if b["posato"] else "non posato"])
        add(k, "Come funziona", [f"Vita ×{b['vita_x']}. Arena di {b['arena']['raggio']} unita' che si chiude quando ti affronta.",
                                 "Battuto non torna."])

    # --- personaggi ---------------------------------------------------------------------------------------------------
    for n in dati["personaggi"]["npc"]:
        k = "npc:" + n["id"]
        add(k, "Chi e'", [n["ruolo"]])
        add(k, "Dove e quando", [f"{o['momento'].replace('_', ' ')}: {(o.get('location_tag') or 'non c'+chr(39)+'e').replace('_', ' ')}" for o in n["orari"]])
        add(k, "Quest", n["quest"])
        ven = next((x for x in j("data", "npc", "roster.json")["npcs"] if x["id"] == n["id"]), {}).get("vendor")
        if ven:
            add(k, "Vende", [no(i) for i in ven.get("listino", [])][:40])

    # --- abilita' -------------------------------------------------------------------------------------------------------
    for pw in dati["tecniche"]["pathway"]:
        for s in pw["sequenze"]:
            for a in s["abilita"]:
                k = "abilita:" + a["id"]
                add(k, "Di chi e'", [f"{pw['nome']}, Sequenza {s['n']} ({s['nome']})"])
                add(k, "Cosa fa", [f"{p.replace('_', ' ')}: {PRIMITIVE.get(p, '')}" for p in a["primitive"]] + [a["note"]])
                add(k, "Costo", [f"{a['costo']} spiritualita'" if a["costo"] is not None else None, f"ricarica {a['cd']} secondi" if a["cd"] else None])
    for e in dati["tecniche"]["effetti"]:
        add("effetto:" + e["sprite"], "Cos'e'", [f"L'effetto che si vede quando parte la primitiva {e['primitiva'].replace('_', ' ')}: {PRIMITIVE.get(e['primitiva'], '')}",
                                                  "Colori: quelli del Pathway di chi la lancia."])
    for sid, s in dati["stati"].items():
        add("stato:" + sid, "Cos'e'", [s["descrizione"]])
    return INFO
