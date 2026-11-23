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

# Cosa fa ogni primitiva: una frase precisa coi numeri dei dati e una semplice (solo per la dashboard).
STAT = {"spiritualita_max": "spiritualita' massima", "hp_max": "vita massima", "velocita": "velocita'", "difesa": "difesa",
        "evasione": "schivata", "precisione": "precisione", "percezione": "percezione", "danno": "danno", "forza": "forza"}


def _pc(v, molt):
    if v is None:
        return ""
    return f"{v * 100:+.0f}%" if molt else f"{v:+g}"


def _s(v):
    return "per sempre (finche' resta attiva)" if v in (-1, None) else ("all'istante" if v == 0 else f"per {v:g} secondi")


def spiega(p):
    """-> (frase precisa, frase semplice) per una primitiva coi suoi parametri."""
    t, g = p.get("tipo"), p.get
    st = STAT.get(g("stat"), str(g("stat", "")).replace("_", " "))
    tag = f" ({str(g('tag_danno')).replace('_', ' ')})" if g("tag_danno") else ""
    D = {
        "projectile": (f"Tira un colpo da {g('danno')} di danno{tag} a velocita' {g('velocita')}, fino a {g('gittata')} caselle; "
                       f"attraversa {g('pierce', 1)} nemic{'o' if g('pierce', 1) == 1 else 'i'}.", "Un colpo che vola dritto davanti a te."),
        "melee_arc": (f"Colpo a ventaglio di {g('angolo')} gradi, raggio {g('raggio')} caselle: {g('danno')} di danno{tag}, "
                      f"{g('stagger')} di sbilanciamento.", "Un fendente davanti a te."),
        "aura": (f"Cerchio di {g('raggio')} caselle attorno a te {_s(g('durata'))}: ogni {g('tick_rate')} s applica "
                 f"'{str(g('effetto')).replace('_', ' ')}' a {str(g('bersagli', '')).replace('_', ' ')}.", "Un'area attorno a te che fa effetto a chi ci sta dentro."),
        "buff_stat": (f"{st.capitalize()} {_pc(g('valore'), g('moltiplicativo'))} {_s(g('durata'))}.", f"Ti rende piu' forte in {st} per un tempo."),
        "debuff_stat": (f"{st.capitalize()} del bersaglio {_pc(g('valore'), g('moltiplicativo'))} {_s(g('durata'))}.", f"Indebolisce il nemico in {st}."),
        "curse": (f"Maledizione '{str(g('effetto')).replace('_', ' ')}' {_s(g('durata'))}" + (f"; si toglie con {g('condizione_rimozione')}." if g("condizione_rimozione") else "."), "Una maledizione sul nemico."),
        "dash": (f"Scatto di {g('distanza')} caselle in {g('durata')} s" + ("; invulnerabile" if g("invulnerabile") else "") + ("; passa attraverso i nemici" if g("attraversa_nemici") else "") + ".", "Uno scatto veloce."),
        "decay": (f"{g('danno')} di danno spalmati in {g('durata')} s su un raggio di {g('raggio')} caselle" + (", rovina anche gli oggetti" if g("colpisce_oggetti") else "") + ".", "Fa marcire tutto attorno, piano piano."),
        "dot": (f"{g('danno_tick')} di danno{tag} ogni {g('tick_rate')} s {_s(g('durata'))} (in tutto circa {round(g('danno_tick', 0) * g('durata', 0) / max(g('tick_rate', 1), 0.01))}).", "Danno a poco a poco."),
        "fear": (f"Paura {_s(g('durata'))}" + (f" in un raggio di {g('raggio')} caselle" if g("raggio") else " sul bersaglio") + f"; resiste chi supera {g('soglia_resistenza')}.", "Il nemico scappa spaventato."),
        "heal": (f"Cura {g('quantita')} di vita " + ("subito" if g("istantaneo") else _s(g("durata"))) + f" a {'te' if g('bersaglio') in (None, 'self') else g('bersaglio')}.", "Ti cura."),
        "illusion": (f"Illusione '{str(g('tipo_illusione')).replace('_', ' ')}' di potenza {g('potenza')}, raggio {g('raggio')} caselle, {_s(g('durata'))}.", "Un'immagine falsa che inganna i nemici."),
        "light_purify": (f"Luce di potenza {g('potenza')} in {g('raggio')} caselle: toglie gli stati negativi" + (" e abbassa la Sequenza" if g("riduce_sequenza") else "") + ".", "Luce che pulisce i mali."),
        "mind_read": (f"Legge {str(g('rivela', '')).replace('_', ' ')} (profondita' {g('profondita')}) entro {g('raggio')} caselle.", "Capisci cosa pensa il nemico."),
        "plant_growth": (f"Fa crescere {str(g('specie', '')).replace('_', ' ')} in {g('raggio')} caselle a velocita' {g('velocita')}" + (", restano" if g("persistente") else "") + ".", "Fa spuntare piante."),
        "possess": (f"Prende i {str(g('controllo', '')).replace('_', ' ')} del bersaglio {_s(g('durata'))}; il tuo corpo prende {g('vulnerabilita_corpo', 0) * 100:.0f}% di danno in piu'; resiste oltre {g('soglia_resistenza')}.", "Controlli un nemico."),
        "reveal_info": (f"Mostra {str(g('categoria', '')).replace('_', ' ')} entro {g('raggio')} caselle {_s(g('durata'))}.", "Vedi cose nascoste."),
        "resurrect": (f"Riporta in vita {str(g('bersaglio', '')).replace('_', ' ')} con {g('hp_ripristinati')} di vita; costa {g('costo_follia')} di follia; ricarica {g('cooldown')} s.", "Fa risorgere."),
        "shadow_meld": (f"Ti fondi nell'ombra {_s(g('durata'))}, velocita' x{g('velocita')}" + (", solo nell'ombra" if g("richiede_ombra") else "") + ".", "Sparisci nell'ombra."),
        "shield": (f"Scudo che assorbe {g('assorbimento')} di danno {_s(g('durata'))}" + (f", rimanda il {g('riflette') * 100:.0f}%" if g("riflette") else "") + (f"; blocca {', '.join(g('tag_bloccati'))}" if g("tag_bloccati") else "") + ".", "Uno scudo che para i colpi."),
        "soul_detach": (f"L'anima esce dal corpo {_s(g('durata'))} a velocita' x{g('velocita')}; il corpo prende {g('vulnerabilita_corpo', 0) * 100:.0f}% di danno in piu'.", "Lasci il corpo e vai in giro come spirito."),
        "steal": (f"Ruba {str(g('categoria', '')).replace('_', ' ')} con probabilita' {g('probabilita', 0) * 100:.0f}%" + (f", per {g('durata_prestito')} s" if g("durata_prestito") else "") + ".", "Rubi qualcosa al nemico."),
        "summon": (f"Chiama {g('quantita')} {str(g('entita_id', '')).replace('_', ' ')} ({g('comportamento')}) {_s(g('durata'))}.", "Chiami aiuto."),
        "teleport": ("Ti sposti " + ("ovunque" if g("distanza", 0) >= 999 else f"fino a {g('distanza')} caselle") + (" anche senza vederlo" if not g("richiede_visuale") else "") + (", con gli alleati" if g("porta_alleati") else "") + ".", "Sparisci e ricompari altrove."),
        "terrain_modify": (f"{str(g('tipo_modifica', '')).capitalize()} il terreno in {g('raggio')} caselle" + (", per sempre" if g("permanente") else f" {_s(g('durata'))}") + ".", "Cambia il terreno."),
        "time_rewind": (f"Torna indietro di {g('secondi')} s ({', '.join(g('ripristina', []))}); costa {g('costo_follia')} di follia.", "Torni indietro nel tempo."),
        "transform": (f"Diventi {str(g('forma_id', '')).replace('_', ' ')} {_s(g('durata'))}, costa {g('costo_al_secondo')} di spiritualita' al secondo.", "Cambi forma."),
    }
    return D.get(t, (f"{t}: " + ", ".join(f"{k} {v}" for k, v in p.items() if k != "tipo"), t.replace("_", " ")))


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
                prim = a.get("_prim", [])
                add(k, "Cosa fa, in breve", [spiega(p)[1] for p in prim])
                add(k, "Cosa fa, nel dettaglio", [spiega(p)[0] for p in prim])
                add(k, "Note di design", [a["note"]])
                add(k, "Costo", [f"{a['costo']} spiritualita'" if a["costo"] is not None else None, f"ricarica {a['cd']} secondi" if a["cd"] else None])
    for e in dati["tecniche"]["effetti"]:
        if e.get("unico"):
            add("effetto:" + e["sprite"], "Cos'e'", [f"Disegno unico (nuovo stile, in prova) dell'abilita' {e['abilita']}: "
                                                      "non e' la forma della primitiva ricolorata."])
            continue
        add("effetto:" + e["sprite"], "Cos'e'", [f"L'effetto che si vede quando parte la primitiva {e['primitiva'].replace('_', ' ')}: {spiega({'tipo': e['primitiva']})[1]}",
                                                  "Colori: quelli del Pathway di chi la lancia."])
    for sid, s in dati["stati"].items():
        add("stato:" + sid, "Cos'e'", [s["descrizione"]])
    return INFO
