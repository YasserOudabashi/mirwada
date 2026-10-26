"""Icone degli oggetti (US-8B70): un'icona 32x32 per ogni oggetto di data/items/, da forge3d/icone.py.

    python tools/art/build_icone.py            # abbina gli oggetti nuovi, poi disegna le icone usate
    python tools/art/build_icone.py --rifai    # riabbina anche quelli gia' abbinati (perde i ritocchi a mano)

L'abbinamento oggetto -> icona e' un dato: data/ui/icone.json "oggetti" (id dell'oggetto -> "<forma>_<tinta>"
o "<forma>"). Lo propone questo script con le regole qui sotto (la prima parola dell'id che dice una forma, le
parole e i tag che dicono un colore); poi si ritocca nel JSON e un nuovo lancio lo lascia com'e'. Le icone vanno
in assets/icone/oggetti/<icona>.png (solo quelle usate) e il foglio di controllo in arte/revisione/.
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from forge3d import materials as M  # noqa: E402
from forge3d.icone import FORME, LATO, icona  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATI = os.path.join(ROOT, "data", "ui", "icone.json")
OUT = os.path.join(ROOT, "assets", "icone", "oggetti")
REVISIONE = os.path.join(ROOT, "arte", "revisione", "icone_oggetti.png")
SEED = 1

LIQUIDI = ["viola", "rosso", "blu", "verde", "oro", "nero", "argento", "ciano", "bianco", "ambra", "terra"]
METALLI = ["ferro", "argento", "oro", "bronzo", "nero"]
OSSA = ["osso", "nero", "argento", "oro"]
NASTRI = ["rosso", "blu", "verde", "viola", "nero", "oro", "argento", "terra"]
# tinte ammesse per forma (la prima e' quella di default); [] = la forma non cambia colore
TINTE_FORMA = {
    "fiala": LIQUIDI, "goccia": ["blu"] + LIQUIDI, "cristallo": LIQUIDI[:10], "polvere": ["terra"] + LIQUIDI + ["pietra"],
    "fiore": ["rosso", "blu", "viola", "oro", "nero", "argento", "bianco"], "sfera": ["ciano"] + LIQUIDI[:9],
    "stoffa": ["rosso", "blu", "verde", "viola", "oro", "nero", "argento", "bianco", "terra"],
    "candela": ["bianco", "nero", "rosso", "ambra", "oro", "viola"], "lingotto": METALLI,
    "erba": ["verde", "argento", "nero", "oro", "viola"], "radice": ["terra", "nero", "argento", "oro"],
    "fungo": ["terra", "rosso", "blu", "viola", "argento", "nero", "oro"], "seme": ["legno", "oro", "argento", "nero", "verde"],
    "piuma": ["bianco", "nero", "argento", "oro", "ciano", "rosso"], "osso": OSSA, "zanna": OSSA, "corno": OSSA,
    "occhio": ["blu", "verde", "oro", "rosso", "nero", "viola", "argento"], "cuore": ["rosso", "nero", "argento", "oro", "verde"],
    "pelo": ["terra", "bianco", "nero", "argento", "rosso"], "filo": ["rosso", "argento", "nero", "oro", "bianco", "viola", "blu",
                                                                    "ciano"],
    "chiave": ["ferro", "oro", "argento", "osso", "nero"], "chiodo": ["ferro", "argento", "nero", "oro", "terra"],
    "carta": [], "pergamena": NASTRI, "libro": NASTRI, "specchio": ["blu", "nero", "argento", "viola"],
    "moneta": ["oro", "argento", "bronzo"], "sigillo": ["rosso", "nero", "blu", "verde", "viola", "oro", "ciano"],
    "ingranaggio": ["bronzo", "ferro", "oro", "argento"], "clessidra": ["terra", "oro", "argento", "nero", "blu"],
    "calice": ["oro", "argento", "ferro", "bronzo"], "campana": ["bronzo", "oro", "argento", "ferro"],
    "maschera": ["bianco", "nero", "oro", "argento"], "corona": ["oro", "argento", "osso", "nero"],
    "porta": ["viola", "legno", "ciano", "oro", "nero", "blu"], "tavoletta": ["pietra", "terra", "legno", "nero", "bianco"],
    "dado": [], "spada": ["argento", "ferro", "oro", "nero"], "ascia": ["argento", "ferro", "oro", "nero"],
    "corazza": ["terra", "ferro", "argento", "rosso", "oro"], "scudo": ["rosso", "blu", "verde", "nero", "oro", "terra"],
    "anello": ["blu", "rosso", "verde", "viola", "ciano", "argento", "bianco"], "amuleto": ["argento", "oro", "blu", "rosso", "viola"],
}
assert set(TINTE_FORMA) == set(FORME), set(TINTE_FORMA) ^ set(FORME)

# parola dell'id -> forma (vince la prima parola dell'id che c'e' qui)
PAROLE_FORMA = {
    "chiave": ["chiave", "grimaldello", "serratura", "cardine"],
    "chiodo": ["chiodo", "ago", "punta", "stilo"],
    "piuma": ["piuma", "ala", "colomba"],
    "osso": ["osso", "ossa", "articolazione"],
    "zanna": ["dente", "zanna", "spina"],
    "corno": ["corno"],
    "occhio": ["occhio"],
    "cuore": ["cuore", "fegato", "cellula", "placenta", "battito", "muscolo", "tendine", "lingua"],
    "pelo": ["pelo", "muta", "cuoio", "spazzola"],
    "filo": ["filo", "corda"],
    "fiore": ["fiore", "petalo", "rosa"],
    "radice": ["radice", "corteccia", "verme"],
    "fungo": ["fungo", "muffa"],
    "erba": ["erba", "foglia", "quadrifoglio", "vischio", "spiga", "muschio"],
    "seme": ["seme", "ghianda", "grano", "trottola"],
    "cristallo": ["cristallo", "prisma", "ambra", "ossidiana", "pietra", "memoria", "tempo"],
    "lingotto": ["lingotto", "acciaio", "argento", "ferro", "lega", "metallo", "oro", "platino"],
    "polvere": ["polvere", "cenere", "sale", "sabbia", "zolfo", "polline", "terra", "terriccio", "argilla", "creta",
                "gesso", "gessetto", "cesto", "pastura", "scarto"],
    "goccia": ["lacrima", "goccia", "rugiada", "linfa", "mercurio", "resina"],
    "fiala": ["acqua", "fiala", "essenza", "estratto", "balsamo", "sangue", "fiele", "inchiostro", "olio", "acido",
              "catalizzatore", "quintessenza", "enzima", "ectoplasma", "miele", "cerone", "nebbia", "ricordo",
              "luce", "ombra", "pozione", "elisir", "tonico", "filtro", "ambrosia"],
    "candela": ["cera", "candela", "incenso", "mano"],
    "carta": ["carta", "biglietto", "lettera", "pagina", "contratto", "copione", "regola", "riga", "domanda", "numero",
              "costante", "cavillo", "sillaba", "battuta", "asso", "ritratto"],
    "pergamena": ["pergamena", "mappa", "progetto"],
    "libro": ["libro", "grimorio", "taccuino", "quaderno"],
    "specchio": ["specchio", "lente"],
    "moneta": ["moneta", "obolo", "refurtiva"],
    "sigillo": ["sigillo", "timbro", "segreto", "voto"],
    "ingranaggio": ["ingranaggio", "bussola", "astrolabio", "ruota", "bilancia", "telaio"],
    "clessidra": ["clessidra"],
    "calice": ["calice", "boccale", "crogiolo"],
    "campana": ["campana", "campanaccio", "sonaglio"],
    "maschera": ["maschera", "naso"],
    "corona": ["corona", "mitra", "scettro"],
    "porta": ["porta", "soglia", "angolo", "confine", "distanza"],
    "tavoletta": ["tavoletta", "stele", "reliquia", "croce", "codice"],
    "dado": ["dado"],
    "stoffa": ["velo", "sipario", "stendardo", "guanto", "cuscino", "suola", "cappello", "cilindro"],
    "spada": ["spada", "lama"],
    "ascia": ["ascia"],
    "corazza": ["corazza"],
    "scudo": ["scudo"],
    "anello": ["anello"],
    "amuleto": ["amuleto"],
    "sfera": ["eco", "voce", "respiro", "soffio", "silenzio", "favilla", "caratteristica", "nucleo"],
}
# parole generiche: danno la forma solo se nessun'altra parola dell'id ne dice una
DEBOLI = {"frammento": "cristallo", "scheggia": "cristallo", "prima": "sfera", "primo": "sfera", "ultimo": "sfera",
          "ultima": "sfera"}
FORMA_DI = {p: f for f, parole in PAROLE_FORMA.items() for p in parole}
FORMA_CATEGORIA = {"ingrediente": "fiala", "consumabile": "fiala", "equip": "spada", "sigillo": "sigillo",
                   "pergamena": "pergamena", "materiale": "lingotto", "valuta": "moneta"}

# parola dell'id o tag -> tinta (si provano nell'ordine delle parole dell'id, poi i tag)
PAROLE_TINTA = {
    "nero": ["nero", "nera", "ombra", "notte", "mezzanotte", "annerito", "lutto", "oblio", "incubo", "ossidiana",
             "bara", "cimitero", "lapidi", "limbo", "abissale", "seppia", "carbone", "fumo", "oltretomba", "sepolcrale",
             "impiccato", "forca", "demone", "vedova", "gatto", "morte", "decaduta", "profanata", "sepolcro", "cilindro",
             "borseggiatore"],
    "rosso": ["sangue", "scarlatto", "rossa", "rosso", "rappreso", "amante", "toro", "cervo", "rovo", "rosa", "muscolo",
              "guarigione", "pentimento"],
    "oro": ["oro", "dorato", "dorata", "solare", "alba", "sole", "divina", "benedetto", "benedetta", "paladino",
            "consacrato", "re", "titano", "favilla", "luce", "luminoso", "luminescente", "giorno", "fortuna", "forza",
            "vincente", "ambrosia", "zolfo", "autunno", "reale"],
    "argento": ["argento", "luna", "lunare", "stella", "stellare", "stelle", "platino", "mercurio", "meteora", "cielo",
                "costellazioni", "bianco", "bianca", "pallido", "inverno", "silenzio", "veglia", "spazio"],
    "blu": ["acqua", "marea", "maree", "oceano", "pioggia", "rugiada", "sorgiva", "fonte", "stige", "sonno",
            "dormiente", "mente", "difesa", "seppia"],
    "ciano": ["spirito", "spirituale", "spettro", "spettrale", "ectoplasma", "anima", "eco", "voce", "soffio", "respiro",
              "mnemonico", "memoria", "ricordo", "vento", "viaggio", "venti"],
    "verde": ["crescita", "foresta", "linfa", "quercia", "vita", "veleno", "acido", "enzima", "muschio", "erba",
              "quadrifoglio", "vischio", "febbrifuga", "valeriana", "camomilla", "madre", "fiele"],
    "viola": ["occulto", "rituale", "crepuscolo", "crepuscolare", "belladonna", "destino", "fato", "parche",
              "proibito", "vista", "veggente", "illusione", "maledizione", "inganno", "papavero", "mondi"],
    "bianco": ["sale", "gesso", "gessetto", "latte", "colomba", "silenzio", "camomilla"],
    "ambra": ["ambra", "miele", "resina", "olio", "grigia"],
    "terra": ["terra", "argilla", "creta", "terriccio", "arena", "sabbia", "deserti", "bosco", "cuoio", "arrugginito",
              "carne", "crafting", "decadimento", "bestia", "selvatico", "vimini"],
    "ferro": ["ferro", "ferrea", "guerra", "temperato", "freddo"],
    "bronzo": ["bronzo", "rame", "ottone", "precisione"],
    "osso": ["osso", "ossa", "ossario", "teschio", "dente"],
    "legno": ["legno", "ghianda", "intagliata", "intagliato"],
    "pietra": ["pietra", "cenere", "roccia", "stele", "rosetta"],
}
# colori di ripiego di una parola, se l'id e i tag non ne dicono altri
TINTA_DEBOLE = {"inchiostro": "nero", "nebbia": "bianco", "acciaio": "argento"}


def tinte_di(item, dopo=None):
    """Le tinte che l'oggetto suggerisce: prima l'aggettivo subito dopo la parola della forma (\"sale_scarlatto\"),
    poi le parole dell'id in ordine, poi i tag, poi i colori di ripiego."""
    parole = item["id"].split("_")
    prima = [parole[dopo + 1]] if dopo is not None and dopo + 1 < len(parole) else []
    out = []
    for p in prima + parole + list(item.get("tag", [])):
        for tinta, lista in PAROLE_TINTA.items():
            if p in lista and tinta not in out:
                out.append(tinta)
    out += [TINTA_DEBOLE[p] for p in parole if p in TINTA_DEBOLE and TINTA_DEBOLE[p] not in out]
    return out


def proponi(item):
    """L'icona proposta per un oggetto: forma dalla prima parola che ne dice una, tinta dalla prima ammessa."""
    parole = item["id"].split("_")
    i = next((k for k, p in enumerate(parole) if p in FORMA_DI), None)
    if i is None:
        i = next((k for k, p in enumerate(parole) if p in DEBOLI), None)
    forma = (FORMA_DI.get(parole[i]) or DEBOLI[parole[i]]) if i is not None else \
        FORMA_CATEGORIA.get(item.get("categoria"), "fiala")
    ammesse = TINTE_FORMA[forma]
    if not ammesse:
        return forma
    tinta = next((t for t in tinte_di(item, i) if t in ammesse), ammesse[0])
    return f"{forma}_{tinta}"


def oggetti():
    out = []
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "items", "*.json"))):
        out += json.load(open(path)).get("items", [])
    return out


def separa(icona_id):
    forma, _, tinta = icona_id.partition("_")
    return forma, tinta


def foglio(icone, path):
    """Foglio di controllo: tutte le icone usate, ingrandite x4, su carta e su fondo scuro."""
    cols = 16
    rows = (len(icone) + cols - 1) // cols
    passo = LATO + 2
    fogli = []
    for bg in ((234, 212, 170), (38, 43, 68)):
        tela = np.zeros((rows * passo, cols * passo, 3), np.uint8)
        tela[:] = bg
        for i, (_, img) in enumerate(icone):
            y, x = (i // cols) * passo + 1, (i % cols) * passo + 1
            a = img[..., 3:4] / 255.0
            tela[y:y + LATO, x:x + LATO] = (img[..., :3] * a + tela[y:y + LATO, x:x + LATO] * (1 - a)).astype(np.uint8)
        fogli.append(tela)
    im = np.concatenate(fogli, 0)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(im).resize((im.shape[1] * 4, im.shape[0] * 4), Image.NEAREST).save(path)


def main():
    rifai = "--rifai" in sys.argv
    doc = json.load(open(DATI)) if os.path.exists(DATI) and not rifai else {}
    abbinati = doc.get("oggetti", {})
    items = oggetti()
    ids = {it["id"] for it in items}
    nuovi = 0
    for it in items:
        if it["id"] not in abbinati:
            abbinati[it["id"]] = proponi(it)
            nuovi += 1
    abbinati = {k: v for k, v in sorted(abbinati.items()) if k in ids}
    categorie = {c: (f"{f}_{TINTE_FORMA[f][0]}" if TINTE_FORMA[f] else f) for c, f in FORMA_CATEGORIA.items()}
    doc = {
        "_comment": "US-8B70: icona di ogni oggetto (assets/icone/oggetti/<icona>.png, tools/art/build_icone.py). "
                    "Icona = <forma> o <forma>_<tinta>; 'forme' e' il vocabolario chiuso con le tinte ammesse; "
                    "un oggetto senza voce in 'oggetti' usa l'icona della sua categoria. Si ritocca qui: "
                    "un nuovo lancio dello script tiene gli abbinamenti esistenti.",
        "lato": LATO,
        "forme": TINTE_FORMA,
        "categorie": categorie,
        "oggetti": abbinati,
    }
    with open(DATI, "w") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
        f.write("\n")

    usate = sorted(set(abbinati.values()) | set(categorie.values()))
    consentiti = {M.hex_to_rgb(c) for c in M.E32.values()}
    os.makedirs(OUT, exist_ok=True)
    for vecchia in glob.glob(os.path.join(OUT, "*.png")):
        if os.path.basename(vecchia)[:-4] not in usate:
            os.remove(vecchia)
            if os.path.exists(vecchia + ".import"):
                os.remove(vecchia + ".import")
    disegni = []
    for ic in usate:
        forma, tinta = separa(ic)
        assert forma in FORME and (tinta in TINTE_FORMA[forma] if TINTE_FORMA[forma] else not tinta), ic
        img = icona(forma, tinta, SEED)
        piene = img[..., 3] > 0
        assert set(np.unique(img[..., 3])) <= {0, 255}, f"{ic}: alpha non 0/255"
        fuori = {tuple(int(c) for c in p) for p in img[piene][:, :3]} - consentiti
        assert not fuori, f"{ic}: colori fuori palette {sorted(fuori)[:4]}"
        Image.fromarray(img).save(os.path.join(OUT, ic + ".png"))
        disegni.append((ic, img))
    foglio(disegni, REVISIONE)
    print(f"{len(abbinati)} oggetti ({nuovi} abbinati ora), {len(usate)} icone in assets/icone/oggetti/, "
          f"foglio in {os.path.relpath(REVISIONE, ROOT)}")


if __name__ == "__main__":
    main()
