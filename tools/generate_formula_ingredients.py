#!/usr/bin/env python3
"""
Genera gli item mancanti in data/items/ingredienti.json a partire dagli
ingredienti citati dalle formule dei 10 Pathway attivi
(data/potions/formulas.json).

Esecuzione (dalla root del progetto):
    python tools/generate_formula_ingredients.py            # item + i18n (US-808)
    python tools/generate_formula_ingredients.py --drops    # layout.drop per le 5 regioni (US-809a)
    python tools/generate_formula_ingredients.py --listini  # vendor.listino di Sidon/Vesna/Bruno (US-809b)

Idempotente: le voci gia' presenti (le 8 scritte a mano e ogni id generato
in un run precedente) si PRESERVANO tal quali (merge per id, come
generate_pathways.py) — il tool aggiunge solo gli id di data/potions/
formulas.json ancora assenti.

Per ogni id mancante genera:
  - name/descrizione: testo IT in chiaro (seed per generate_i18n_stubs.py).
  - name_i18n/descrizione_i18n: "item.<id>" / "item.<id>.desc".
  - tag: da una tabella CHIUSA parola -> tag di data/tags.json (un tag
    fuori da quel vocabolario e' un errore del tool, non un problema da
    scoprire nel validator dopo). Ogni item ha sempre almeno "pozione".
  - valore: dalla sequenza piu' bassa (= piu' vicina a Sequenza 0, quindi
    piu' rara) fra tutte le formule che citano l'ingrediente.
  - impilabile: sempre true.

Scrive anche la traduzione EN diretta in data/i18n/en.json (generate_i18n_
stubs.py non traduce: preserva solo cio' che trova gia' scritto). Un id e'
tradotto in EN solo se OGNI sua parola e' nel dizionario EN_DICT; altrimenti
resta assente da en.json (coerente con "catalogo incompleto per scelta") e
le parole ignote finiscono nel report a fine run.

Poi lancia tools/generate_i18n_stubs.py per allineare i due cataloghi.
"""

import json
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DATA = os.path.join(ROOT, "data")
FORMULAS_PATH = os.path.join(DATA, "potions", "formulas.json")
ITEMS_PATH = os.path.join(DATA, "items", "ingredienti.json")
TAGS_PATH = os.path.join(DATA, "tags.json")
IT_PATH = os.path.join(DATA, "i18n", "it.json")
EN_PATH = os.path.join(DATA, "i18n", "en.json")
REGIONS_PATH = os.path.join(DATA, "world", "regions.json")
PATHWAYS_DIR = os.path.join(DATA, "pathways")
LAYOUTS_DIR = os.path.join(DATA, "world", "layouts")
ROSTER_PATH = os.path.join(DATA, "npc", "roster.json")

# Sequenza minima che cita l'ingrediente -> valore (9 e' la piu' debole/comune,
# 0 la piu' rara). Tabella dell'AC di US-808, non bilanciata.
VALORE_PER_SEQUENZA = {
    9: 3, 8: 5, 7: 8, 6: 12, 5: 18, 4: 27, 3: 40, 2: 60, 1: 90, 0: 120,
}

# Parole che perdono l'accento diventando un id (snake_case, ASCII): la
# forma corretta va ripristinata a mano. Tabella aperta, si estende quando
# se ne incontra una nuova.
ACCENTI = {
    "piu": "più", "gia": "già", "cosi": "così", "perche": "perché",
    "poiche": "poiché", "puo": "può", "verita": "verità", "citta": "città",
    "eta": "età", "virtu": "virtù", "ne": "né", "se": "sé", "li": "lì",
    "la'": "là", "sara": "sarà", "sara'": "sarà", "portera": "porterà",
    "cadra": "cadrà", "morira": "morirà",
}

# Parole che elidono l'articolo/preposizione davanti alla parola dopo
# (apostrofo, niente spazio): "filo dell incantesimo" -> "filo dell'incantesimo".
ELISIONI = {"dell", "nell", "dall", "sull", "all", "quell", "un'", "l", "d"}

# Dizionario IT -> EN parola per parola (~200 voci, le piu' frequenti nei
# 299 id). Copertura parziale per scelta (AC): un id con una parola fuori
# da questo dizionario NON viene tradotto, finisce nel report a fine run.
EN_DICT = {
    # funzionali
    "di": "of", "che": "that", "del": "of the", "della": "of the",
    "dello": "of the", "dell": "of the", "delle": "of the", "dei": "of the",
    "degli": "of the", "non": "not", "da": "from", "a": "to", "un": "a",
    "una": "a", "uno": "a", "in": "in", "e": "and", "con": "with",
    "senza": "without", "su": "on", "sui": "on the", "tra": "between",
    "fra": "between", "si": "", "il": "the", "la": "the", "le": "the",
    "i": "the", "gli": "the", "lo": "the", "gia": "already", "mai": "never",
    "sempre": "always", "ogni": "every", "prima": "first", "primo": "first",
    "ultimo": "last", "due": "two", "tre": "three", "tutto": "all",
    "tutti": "all", "solo": "only", "sola": "only", "altrui": "of others",
    "dove": "where", "tu": "you", "al": "to the", "nel": "in the",
    "nella": "in the", "dal": "from the", "dalla": "from the",
    "quando": "when", "cui": "which", "trovi": "find", "vuoi": "want",
    "esiste": "exists", "chiude": "closes", "apre": "opens", "cola": "drips",
    "vince": "wins", "riflette": "reflects", "indietro": "back",
    "detta": "said", "fatta": "made",
    # materiali / oggetti
    "polvere": "dust", "radice": "root", "filo": "thread",
    "specchio": "mirror", "chiave": "key", "inchiostro": "ink",
    "frammento": "shard", "sale": "salt", "argento": "silver",
    "cenere": "ash", "ferro": "iron", "acciaio": "steel", "cuore": "heart",
    "respiro": "breath", "sangue": "blood", "acqua": "water",
    "porta": "door", "stella": "star", "cera": "wax", "chiodo": "nail",
    "seme": "seed", "fiore": "flower", "notte": "night",
    "incenso": "incense", "lacrima": "tear", "lente": "lens",
    "occhio": "eye", "pietra": "stone", "sabbia": "sand", "voce": "voice",
    "fonte": "spring", "fato": "fate", "biglietto": "ticket",
    "punta": "tip", "cilindro": "cylinder", "fondo": "bottom",
    "cardine": "hinge", "cielo": "sky", "rituale": "ritual",
    "veglia": "vigil", "serratura": "lock", "ingranaggio": "gear",
    "vita": "life", "corona": "crown", "cristallo": "crystal",
    "burattinaio": "puppeteer", "quercia": "oak", "eco": "echo",
    "potere": "power", "essenza": "essence", "parche": "fates",
    "gesso": "chalk", "goccia": "drop", "linfa": "sap",
    "confine": "border", "lega": "alloy", "moneta": "coin",
    "muschio": "moss", "nucleo": "core", "crepuscolo": "twilight",
    "gufo": "owl", "ombra": "shadow", "ossidiana": "obsidian",
    "lupo": "wolf", "pergamena": "parchment", "faccia": "face",
    "soglia": "threshold", "vista": "sight", "resina": "resin",
    "ritratto": "portrait", "giorno": "day", "spina": "thorn",
    "mondo": "world", "mondi": "worlds", "luna": "moon", "acido": "acid",
    "saggio": "sage", "stige": "styx", "ago": "needle", "cuce": "sews",
    "ala": "wing", "falena": "moth", "ambra": "amber", "angolo": "corner",
    "stanza": "room", "argilla": "clay", "fiume": "river",
    "articolazione": "joint", "marionetta": "marionette", "asso": "ace",
    "cima": "top", "mazzo": "deck", "astrolabio": "astrolabe",
    "balsamo": "balm", "battuta": "line", "lotteria": "lottery",
    "bilancia": "scale", "bussola": "compass", "calice": "chalice",
    "campana": "bell", "cappello": "hat", "caratteristica": "characteristic",
    "carbone": "coal", "anima": "soul", "catalizzatore": "catalyst",
    "cellula": "cell", "bosco": "wood", "re": "king", "spirito": "spirit",
    "candela": "candle", "palcoscenico": "stage", "cifrario": "cipher",
    "soluzione": "solution", "denti": "teeth", "dente": "tooth",
    "forca": "gallows", "bara": "coffin", "freddo": "cold",
    "clessidra": "hourglass", "codice": "code", "colomba": "dove",
    "contratto": "contract", "clausola": "clause", "copione": "script",
    "corda": "rope", "impiccato": "hanged man", "corno": "horn",
    "alce": "elk", "papavero": "poppy", "corteccia": "bark",
    "costante": "constant", "universale": "universal", "creta": "clay",
    "uomo": "man", "riferimento": "reference", "mnemonico": "mnemonic",
    "croce": "cross", "legno": "wood", "crogiolo": "crucible",
    "indistruttibile": "indestructible", "condiviso": "shared",
    "pianeta": "planet", "montagna": "mountain", "cuscino": "cushion",
    "inquieto": "restless", "dado": "die", "truccato": "loaded",
    "teschio": "skull", "distanza": "distance", "ridotta": "reduced",
    "orologio": "clock", "specchi": "mirrors", "carta": "card",
    "carte": "cards", "libro": "book", "pagina": "page",
    "lettera": "letter", "sigillo": "seal", "cera_lacca": "sealing wax",
    "spada": "sword", "lama": "blade", "manico": "handle",
    "guanto": "glove", "maschera": "mask", "sipario": "curtain",
    "teatro": "theater", "attore": "actor", "pubblico": "audience",
    "poltrona": "seat", "biglietteria": "box office", "scena": "scene",
    "atto": "act", "finale": "final", "silenzio": "silence",
    "sussurro": "whisper", "urlo": "scream", "sogno": "dream",
    "incubo": "nightmare", "veleno": "poison", "cura": "cure",
    "ferita": "wound", "cicatrice": "scar", "osso": "bone",
    "ossa": "bones", "carne": "flesh", "pelle": "skin", "unghia": "nail",
    "capello": "hair", "sudore": "sweat", "lacrime": "tears",
    "sorriso": "smile", "maledizione": "curse", "benedizione": "blessing",
    "profezia": "prophecy", "oracolo": "oracle", "veggente": "seer",
    "indovino": "fortune teller", "destino": "destiny", "caso": "chance",
    "probabilita": "probability", "regola": "rule", "legge": "law",
    "giudice": "judge", "sentenza": "verdict", "processo": "trial",
    "colpa": "guilt", "peccato": "sin", "penitenza": "penance",
    "altare": "altar", "tempio": "temple", "prete": "priest",
    "monaco": "monk", "preghiera": "prayer", "reliquia": "relic",
    "cripta": "crypt", "tomba": "tomb", "sepolcro": "sepulcher",
    "fantasma": "ghost", "spettro": "phantom",
    # aggettivi/participi frequenti
    "d": "of", "nero": "black", "nera": "black", "luce": "light",
    "stellare": "stellar", "dormiente": "dormant", "bianco": "white",
    "incrinato": "cracked", "incrinata": "cracked", "annerito": "blackened",
    "lunare": "lunar", "precisione": "precision", "madre": "mother",
    "gigante": "giant", "spettrale": "spectral", "spirituale": "spiritual",
    "rossa": "red", "rosso": "red", "impossibile": "impossible",
    "più": "more", "primordiale": "primordial", "arrugginito": "rusty",
    "imbottigliata": "bottled", "graduata": "graduated",
    "estratto": "extract", "muscolo": "muscle", "platino": "platinum",
    "stendardo": "banner", "lacero": "torn", "progetto": "design",
    "perfetto": "perfect", "dorme": "sleeps", "doppia": "double",
    "doppio": "double", "consegnata": "delivered", "amara": "bitter",
    "scheggia": "splinter", "divina": "divine", "fiala": "vial",
    "piena": "full", "sonno": "sleep", "rubata": "stolen",
    "stabile": "stable", "terza": "third", "nessuno": "no one",
    "profanata": "desecrated", "zolfo": "sulfur", "fosse": "pits",
    "benedetta": "blessed", "benedetto": "blessed", "enzima": "enzyme",
    "crepuscolare": "twilit", "timbro": "stamp", "eterna": "eternal",
    "fiele": "bile", "demone": "demon", "roccia": "rock", "oro": "gold",
    "camerino": "dressing room", "marea": "tide", "oltretomba": "afterlife",
    "olio": "oil", "conduttore": "conductor", "ectoplasma": "ectoplasm",
    "rovo": "bramble", "antico": "ancient", "stilo": "stylus",
    "battito": "heartbeat", "telaio": "frame", "assoluta": "absolute",
    "vetro": "glass", "obolo": "obol", "bronzo": "bronze",
    "placenta": "placenta", "mirra": "myrrh", "solidificata": "solidified",
    "valeriana": "valerian", "prisma": "prism", "devia": "deflects",
    "scarlatto": "scarlet", "toro": "bull", "temperato": "tempered",
}

# Parola -> tag chiuso (data/tags.json). Ogni item ha SEMPRE "pozione" in
# aggiunta a quelli trovati qui. Tabella parziale per scelta: una parola
# senza corrispondenza non aggiunge nessun tag extra.
TAG_MAP = {
    "sangue": "sangue", "ferro": "forza", "acciaio": "forza",
    "radice": "crescita", "erba": "crescita", "seme": "crescita",
    "quercia": "crescita", "fiore": "crescita", "muschio": "crescita",
    "corteccia": "crescita", "linfa": "crescita",
    "specchio": "specchio", "specchi": "specchio",
    "nebbia": "occultamento", "ombra": "ombra", "ossidiana": "ombra",
    "osso": "morte", "ossa": "morte", "teschio": "morte", "bara": "morte",
    "forca": "morte", "tomba": "morte", "sepolcro": "morte",
    "cripta": "morte", "cadavere": "morte", "fantasma": "spirito",
    "spettro": "spirito", "luna": "luna", "notte": "notte",
    "notturna": "notte", "stella": "stella", "stellare": "stella",
    "astrolabio": "stella", "cielo": "stella", "pianeta": "stella",
    "luce": "luce", "fuoco": "fuoco", "acqua": "acqua", "sonno": "sonno",
    "veglia": "sonno", "dormiente": "sonno", "sogno": "sogno",
    "incubo": "sogno", "spirito": "spirito", "spirituale": "spirito",
    "spettrale": "spirito", "anima": "anima", "eco": "spirito",
    "fortuna": "fortuna", "lotteria": "fortuna", "dado": "fortuna",
    "asso": "fortuna", "mazzo": "fortuna", "moneta": "fortuna",
    "fato": "destino", "destino": "destino", "tempo": "tempo",
    "clessidra": "tempo", "orologio": "tempo", "morte": "morte",
    "maschera": "inganno", "marionetta": "inganno",
    "burattinaio": "inganno", "specchio_incrinato": "inganno",
    "follia": "follia", "guarigione": "guarigione", "cura": "guarigione",
    "veggente": "divinazione", "profezia": "predizione",
    "oracolo": "divinazione", "indovino": "divinazione",
    "bussola": "divinazione", "rituale": "rituale", "altare": "rituale",
    "preghiera": "rituale", "reliquia": "rituale", "sigillo": "sigillo",
    "silenzio": "silenzioso", "silenzioso": "silenzioso",
    "sussurro": "sussurro", "contratto": "contratto",
    "clausola": "contratto", "vento": "vento", "tempesta": "tempesta",
    "fulmine": "fulmine", "terra": "terra", "argilla": "terra",
    "creta": "terra", "sabbia": "terra", "pietra": "terra",
    "cenere": "terra", "carne": "carne", "pelle": "carne",
    "sigillo": "sigillo", "libro": "conoscenza", "pagina": "conoscenza",
    "lettera": "conoscenza", "codice": "conoscenza",
    "cifrario": "conoscenza", "carta": "destino", "carte": "destino",
    "veleno": "morte", "maledizione": "maledizione",
    "benedizione": "purificazione", "giudice": "giudizio",
    "sentenza": "giudizio", "processo": "giudizio", "legge": "legge",
    "regola": "legge", "teatro": "illusione", "sipario": "illusione",
    "maschera": "illusione", "attore": "illusione", "gigante": "forza",
    "spada": "arma", "lama": "arma",
}

# Sottoinsieme di EN_DICT che sono aggettivi: per un id di ESATTAMENTE 2
# parole "nome aggettivo" (il caso piu' comune, es. "ferro_temperato"), la
# traduzione EN inverte l'ordine ("Tempered iron", non "Iron tempered").
# Id piu' lunghi restano nell'ordine letterale (US-808: ordine invertito
# "dove serve" — il caso a 2 parole e' quello a beneficio/costo migliore).
AGGETTIVI = {
    "temperato", "stellare", "annerito", "benedetto", "benedetta",
    "tascabile", "incrinato", "incrinata", "millimetrata", "proibito",
    "primordiale", "condiviso", "febbrifuga", "mnemonico",
    "indistruttibile", "truccato", "dormiente", "spettrale", "consacrato",
    "millenaria", "cantante", "bianco", "nero", "nera", "rosso", "rossa",
    "grigia", "grigio", "luminescente", "graduata", "cristallizzata",
    "filosofale", "beyonder", "eterna", "scarlatto", "arrugginito",
    "antico", "divina", "impossibile", "assoluta", "universale",
    "costante", "ridotta", "solidificata", "imbottigliata",
    "profanata", "rubata", "stabile", "amara", "piena", "perfetto",
    "doppio", "doppia", "spirituale", "notturna", "lunare", "gigante",
    "vincente", "madre", "finale", "lacero",
}


def swap_aggettivo(parole):
    """Nome+aggettivo di 2 parole -> aggettivo+nome, per l'ordine EN."""
    if len(parole) == 2 and parole[1] in AGGETTIVI and parole[0] not in AGGETTIVI:
        return [parole[1], parole[0]]
    return parole


def load_json(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def save_json(path, doc):
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(doc, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def parse_formula_id(fid):
    """'formula_twilight_giant_9' -> ('twilight_giant', 9). Il pathway_id
    puo' contenere '_' (twilight_giant): si taglia solo l'ULTIMO segmento
    come numero di Sequenza."""
    rest = fid[len("formula_"):]
    pid, seq = rest.rsplit("_", 1)
    return pid, int(seq)


def nome_it(item_id):
    parole = item_id.split("_")
    out = []
    for i, w in enumerate(parole):
        w = ACCENTI.get(w, w)
        if w in ELISIONI and i < len(parole) - 1:
            w += "'"
        out.append(w)
    testo = ""
    for i, w in enumerate(out):
        if i > 0 and not out[i - 1].endswith("'"):
            testo += " "
        testo += w
    return testo[:1].upper() + testo[1:] if testo else testo


def nome_en(item_id):
    """None se una parola non e' nel dizionario: l'id resta non tradotto."""
    parole = swap_aggettivo(item_id.split("_"))
    tradotte = []
    for w in parole:
        w = ACCENTI.get(w, w)
        if w not in EN_DICT:
            return None
        tr = EN_DICT[w]
        if tr:
            tradotte.append(tr)
    if not tradotte:
        return None
    testo = " ".join(tradotte)
    return testo[:1].upper() + testo[1:]


def tag_per(item_id):
    parole = set(item_id.split("_"))
    tag = {"pozione"}
    for w in parole:
        t = TAG_MAP.get(w)
        if t:
            tag.add(t)
    return sorted(tag)


def format_drop_block(drop):
    """Serializza layout.drop nello stile a 2 spazi annidato sotto la radice
    (coerente con un ipotetico json.dumps(doc, indent=2)). Usata per una
    sostituzione TESTUALE mirata di '  "drop": ...' — mai un re-dump
    dell'intero file: nemici/oggetti/zone/passaggi sono scritti a mano in
    stile compatto (un oggetto per riga) che json.dump(indent=2) su tutto
    il documento distruggerebbe (scoperto e corretto in US-809a, vedi
    progress.txt)."""
    if not drop:
        return "{}"
    righe = ["{"]
    sequenze = sorted(drop.keys(), key=int)
    for i, seq in enumerate(sequenze):
        righe.append(f'    "{seq}": [')
        ingredienti = drop[seq]
        for j, ing in enumerate(ingredienti):
            virgola = "," if j < len(ingredienti) - 1 else ""
            righe.append(f'      "{ing}"{virgola}')
        virgola = "," if i < len(sequenze) - 1 else ""
        righe.append(f'    ]{virgola}')
    righe.append("  }")
    return "\n".join(righe)


def splice_drop_block(text, drop):
    """'drop' e' sempre l'ultima chiave del layout (US-806): sostituisce
    tutto da '  "drop": ' a fine file, qualunque fosse il contenuto
    precedente (una riga o gia' multi-riga da un run precedente)."""
    marker = '  "drop": '
    idx = text.index(marker)
    return text[:idx] + marker + format_drop_block(drop) + "\n}\n"


def add_boss_drop_probabilita(text):
    """Il boss di ogni regione (override.caratteristica, sequenza fissa
    piu' bassa) lascia SEMPRE il suo drop: aggiunge drop_probabilita: 1.0
    come sorella di "caratteristica" dentro override, con l'indentazione
    di quella riga. Idempotente: se gia' presente prima di "drop", no-op."""
    testa = text[:text.index('"drop":')]
    if '"drop_probabilita"' in testa:
        return text
    idx = text.index('"caratteristica":')
    line_start = text.rfind("\n", 0, idx) + 1
    line_end = text.index("\n", idx)
    line = text[line_start:line_end]
    indent = line[:len(line) - len(line.lstrip())]
    nuova = line + ",\n" + indent + '"drop_probabilita": 1.0'
    return text[:line_start] + nuova + text[line_end:]


def per_pathway_seq(formulas):
    """pathway_id -> {sequenza: {ingrediente, ...}}. Condivisa da --drops e
    --listini: entrambe le opzioni partono dalla stessa scomposizione delle
    formule per (Pathway, Sequenza)."""
    out = {}
    for fid, f in formulas.items():
        pid, seq = parse_formula_id(fid)
        out.setdefault(pid, {}).setdefault(seq, set()).update(f.get("ingredients", []))
    return out


def group_by_pathway():
    """pathway_id -> group, letto da data/pathways/*.json (mai hardcoded).
    Condivisa da --drops e --listini."""
    out = {}
    for fn in sorted(os.listdir(PATHWAYS_DIR)):
        if not fn.endswith(".json"):
            continue
        pw = load_json(os.path.join(PATHWAYS_DIR, fn))
        out[pw["id"]] = pw.get("group")
    return out


def write_drops(formulas):
    """US-809a, opzione --drops: scrive layout.drop per le 5 regioni e
    drop_probabilita: 1.0 sul boss di ciascuna. Pura funzione di
    formulas.json + regions.json + pathways/*.json (group): nessuna voce
    scritta a mano da preservare qui, a differenza degli item — ogni run
    ricalcola tutto da zero (idempotente per costruzione). Scrive con
    sostituzioni testuali mirate (mai un re-dump json.dump dell'intero
    file: vedi format_drop_block).

    Per le 4 regioni con group_affinity reale: una chiave per ogni Sequenza
    0..9 che ha almeno una formula fra i Pathway attivi di quel gruppo,
    valore = gli ingredienti di quelle formule. Per la regione neutra
    (l'hub): solo le chiavi "9"/"8", ingredienti di TUTTI i Pathway attivi.
    """
    regions_doc = load_json(REGIONS_PATH)
    group_by_region = {r["id"]: r.get("group_affinity") for r in regions_doc.get("regions", [])}

    gbp = group_by_pathway()
    pps = per_pathway_seq(formulas)
    tutti_pathway = sorted(pps.keys())

    scritti = 0
    for region_id, group in sorted(group_by_region.items()):
        layout_path = os.path.join(LAYOUTS_DIR, f"{region_id}.json")
        if not os.path.exists(layout_path):
            print(f"  {region_id}: nessun layout, saltata (atteso solo prima di US-807d)")
            continue

        drop = {}
        if group == "neutra":
            for seq in (9, 8):
                ids = set()
                for pid in tutti_pathway:
                    ids.update(pps.get(pid, {}).get(seq, set()))
                if ids:
                    drop[str(seq)] = sorted(ids)
        else:
            pids_del_gruppo = [pid for pid, g in gbp.items() if g == group]
            for seq in range(10):
                ids = set()
                for pid in pids_del_gruppo:
                    ids.update(pps.get(pid, {}).get(seq, set()))
                if ids:
                    drop[str(seq)] = sorted(ids)

        with open(layout_path, encoding="utf-8") as fh:
            originale = fh.read()
        testo = add_boss_drop_probabilita(originale)
        testo = splice_drop_block(testo, drop)
        if testo != originale:
            with open(layout_path, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(testo)
            scritti += 1
        print(f"  {region_id} ({group}): drop su {len(drop)} Sequenze, "
              f"{sum(len(v) for v in drop.values())} voci totali")

    print(f"OK: --drops ha aggiornato layout.drop/drop_probabilita per {scritti} "
          f"regioni (le altre erano gia' corrette: idempotente).")


def write_listini(formulas):
    """US-809b, opzione --listini: estende vendor.listino di npc_sidon/
    npc_vesna/npc_bruno in data/npc/roster.json. Solo APPEND: fa l'unione
    col listino gia' scritto a mano, non toglie mai nulla. roster.json e'
    gia' in formato json.dump(indent=2) puro (verificato: round-trip
    identico byte-per-byte), a differenza dei layout — qui save_json normale
    basta, nessuna sostituzione testuale mirata necessaria.

    Sidon: ingredienti di Sequenza 9+8 di TUTTI i Pathway attivi (stesso
    calcolo del drop "9"/"8" della regione neutra in write_drops).
    Vesna: ogni item categoria:ingrediente col tag 'guarigione' o 'crescita'
    (non e' per-Sequenza: scorre gli item gia' generati da questo stesso
    tool in US-808).
    Bruno: ingredienti di Sequenza 9+8+7 dei Pathway del gruppo
    eternal_darkness (letto da pathways/*.json.group, mai hardcoded).
    """
    pps = per_pathway_seq(formulas)
    gbp = group_by_pathway()
    tutti_pathway = sorted(pps.keys())

    sidon = set()
    for pid in tutti_pathway:
        for seq in (9, 8):
            sidon.update(pps.get(pid, {}).get(seq, set()))

    items_doc = load_json(ITEMS_PATH)
    vesna = set()
    for it in items_doc.get("items", []):
        if it.get("categoria") != "ingrediente":
            continue
        tag = set(it.get("tag", []))
        if "guarigione" in tag or "crescita" in tag:
            vesna.add(it["id"])

    pids_eternal_darkness = [pid for pid, g in gbp.items() if g == "eternal_darkness"]
    bruno = set()
    for pid in pids_eternal_darkness:
        for seq in (9, 8, 7):
            bruno.update(pps.get(pid, {}).get(seq, set()))

    nuovi_per_npc = {"npc_sidon": sidon, "npc_vesna": vesna, "npc_bruno": bruno}

    roster_doc = load_json(ROSTER_PATH)
    cambiato = False
    for npc in roster_doc.get("npcs", []):
        nid = npc.get("id")
        if nid not in nuovi_per_npc:
            continue
        ven = npc.get("vendor")
        if ven is None:
            continue
        esistente = set(ven.get("listino", []))
        unione = sorted(esistente | nuovi_per_npc[nid])
        aggiunti = len(unione) - len(esistente)
        if unione != ven.get("listino", []):
            ven["listino"] = unione
            cambiato = True
        print(f"  {nid}: {aggiunti} id nuovi, {len(unione)} totali nel listino")

    if cambiato:
        save_json(ROSTER_PATH, roster_doc)
        print("OK: --listini ha aggiornato data/npc/roster.json.")
    else:
        print("OK: --listini non ha trovato nulla da aggiungere (idempotente).")


def main():
    if "--drops" in sys.argv[1:]:
        formulas_doc = load_json(FORMULAS_PATH)
        formulas = formulas_doc.get("formulas", formulas_doc)
        write_drops(formulas)
        return 0

    if "--listini" in sys.argv[1:]:
        formulas_doc = load_json(FORMULAS_PATH)
        formulas = formulas_doc.get("formulas", formulas_doc)
        write_listini(formulas)
        return 0

    formulas_doc = load_json(FORMULAS_PATH)
    formulas = formulas_doc.get("formulas", formulas_doc)

    tags_doc = load_json(TAGS_PATH)
    valid_tags = set(tags_doc.get("tags", tags_doc))
    for t in set(TAG_MAP.values()):
        if t not in valid_tags:
            print(f"ERRORE: TAG_MAP usa '{t}', fuori dal vocabolario chiuso di data/tags.json", file=sys.stderr)
            return 1

    pathway_ids_attivi = {parse_formula_id(fid)[0] for fid in formulas}

    it_doc = load_json(IT_PATH) if os.path.exists(IT_PATH) else {}
    nomi_pathway = {pid: it_doc.get(f"pathway.{pid}", pid) for pid in pathway_ids_attivi}

    # per ogni ingrediente: la sequenza piu' bassa fra le formule che lo citano
    # (= la piu' vicina a Sequenza 0), e il pathway/sequenza di quella formula
    # per la descrizione.
    migliore = {}  # id -> (sequenza, pathway_id)
    for fid, f in formulas.items():
        pid, seq = parse_formula_id(fid)
        for ing in f.get("ingredients", []):
            if ing not in migliore or seq < migliore[ing][0]:
                migliore[ing] = (seq, pid)

    items_doc = load_json(ITEMS_PATH)
    esistenti = {it["id"]: it for it in items_doc["items"]}

    NOTA_VALORE = (
        " US-808: gli ingredienti citati dalle formule (data/potions/formulas.json) "
        "sono generati da tools/generate_formula_ingredients.py — non modificarli a mano, "
        "rilancia il tool. valore dalla sequenza minima che li cita: "
        "9->3, 8->5, 7->8, 6->12, 5->18, 4->27, 3->40, 2->60, 1->90, 0->120."
    )
    if NOTA_VALORE not in items_doc.get("_comment", ""):
        items_doc["_comment"] = items_doc.get("_comment", "").rstrip() + NOTA_VALORE

    creati = 0
    parole_ignote = set()
    for ing, (seq, pid) in sorted(migliore.items()):
        if ing in esistenti:
            continue
        nome = nome_it(ing)
        pathway_nome = nomi_pathway.get(pid, pid)
        nuovo = {
            "id": ing,
            "categoria": "ingrediente",
            "name_i18n": f"item.{ing}",
            "descrizione_i18n": f"item.{ing}.desc",
            "name": nome,
            "descrizione": f"Ingrediente alchemico. Compare nella formula di Sequenza {seq} di {pathway_nome}.",
            "tag": tag_per(ing),
            "impilabile": True,
            "valore": VALORE_PER_SEQUENZA[seq],
        }
        items_doc["items"].append(nuovo)
        esistenti[ing] = nuovo
        creati += 1
        for w in ing.split("_"):
            w2 = ACCENTI.get(w, w)
            if w2 not in EN_DICT:
                parole_ignote.add(w)

    items_doc["items"].sort(key=lambda it: it["id"])
    save_json(ITEMS_PATH, items_doc)

    # traduzioni EN dirette (generate_i18n_stubs.py non traduce: preserva
    # solo quello che trova gia' scritto).
    en_doc = load_json(EN_PATH) if os.path.exists(EN_PATH) else {}
    tradotti = 0
    for ing in migliore:
        chiave = f"item.{ing}"
        if chiave in en_doc and not str(en_doc[chiave]).startswith("TODO "):
            continue
        en = nome_en(ing)
        if en is not None:
            en_doc[chiave] = en
            en_doc[f"item.{ing}.desc"] = "Alchemical ingredient."
            tradotti += 1
    save_json(EN_PATH, en_doc)

    print(f"OK: {creati} ingredienti nuovi in data/items/ingredienti.json "
          f"({len(esistenti)} totali, {len(migliore)} citati dalle formule).")
    print(f"    {tradotti} tradotti anche in EN direttamente da questo tool.")
    if parole_ignote:
        print(f"    {len(parole_ignote)} parole fuori dal dizionario EN "
              f"(gli id che le contengono restano senza traduzione EN):")
        for w in sorted(parole_ignote):
            print(f"      {w}")

    # allinea it.json/en.json alle chiavi *_i18n (usa i seed name/descrizione
    # appena scritti per il catalogo IT; l'EN gia' scritto sopra si preserva).
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "generate_i18n_stubs.py")])
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
