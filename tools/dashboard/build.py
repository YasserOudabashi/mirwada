#!/usr/bin/env python3
"""Dashboard del progetto: raccoglie dai dati e dalle immagini del gioco tutto quello che la pagina mostra.

    python tools/dashboard/build.py            # -> build/dashboard/ (dati.json, img/, foto/ gia' fatte)
    python tools/dashboard/build.py --foto     # rifa anche le foto dal gioco (Godot + Xvfb, ~5 minuti)

La pagina e' tools/dashboard/pagina.html (copiata come index.html). Si pubblica come pagina privata su claude.ai
(vedi CLAUDE.md, "Dashboard"). Niente qui cambia il gioco: legge soltanto.

Le immagini diventano pochi file (la pagina ne tiene al massimo ~500): ogni figura animata e' un foglio unico con
tutte le sue animazioni una sotto l'altra, le icone stanno in atlanti a griglia, la mappa e' una miniatura 2 px per
casella con i colori veri delle tessere.
"""
import argparse
import glob
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA = os.path.join(ROOT, "data")
PH = os.path.join(ROOT, "assets", "placeholder")
OUT = os.path.join(ROOT, "build", "dashboard")
IMG = os.path.join(OUT, "img")


def j(*p):
    with open(os.path.join(ROOT, *p), encoding="utf-8") as f:
        return json.load(f)


IT = j("data", "i18n", "it.json")


def tr(k, alt=""):
    return IT.get(k, alt or k) if k else alt


def senza_commenti(d):
    return {k: v for k, v in d.items() if not str(k).startswith("_")}


# --- figure animate ---------------------------------------------------------------------------------------------
ANIM = j("data", "animations.json")
FIGURE = {}


# --- versioni delle cose da testare ------------------------------------------------------------------------------
# Ogni cosa della pagina "Da testare" ha un'impronta del suo disegno (sha dei file). Quando cambia, il registro
# (tools/dashboard/versioni.json, nel repo) segna da quando: un giudizio dato prima torna "da testare" e la sua nota
# va fra quelle sistemate. Cosi' una nota mandata, appena la cosa e' rifatta, lascia il posto a una nuova prova.
REGISTRO = os.path.join(ROOT, "tools", "dashboard", "versioni.json")
GIUDICATO = "e501670"         # il commit che l'utente ha giudicato per primo (la pagina Da testare del 2026-11-18)


def _sha(*blobs):
    import hashlib
    h = hashlib.sha256()
    for b in blobs:
        h.update(b)
    return h.hexdigest()[:12]


def _file_prova():
    """chiave -> lista di percorsi (dalla radice del repo) che fanno quella cosa."""
    out = {}
    pers = [n for n, a in senza_commenti(ANIM["personaggio"]).items() if isinstance(a, dict) and "frames" in a]
    lupo = [n for n, a in senza_commenti(ANIM["nemico_base"]).items() if isinstance(a, dict) and "frames" in a]
    for n in pers:
        out[f"prova:enel_{n}"] = [f"assets/placeholder/personaggio_{n}.png"]
    out["prova:enel"] = [f"assets/placeholder/personaggio_{n}.png" for n in pers]
    for n in lupo:
        out[f"prova:lupo_{n}"] = [f"assets/placeholder/nemico_base_lupo_della_luna_{n}.png"]
    out["prova:lupo"] = [f"assets/placeholder/nemico_base_lupo_della_luna_{n}.png" for n in lupo]
    for f in glob.glob(os.path.join(ROOT, "arte", "prova", "personaggio_dash_*.png")):
        vid = os.path.basename(f)[len("personaggio_dash_"):-4]
        out[f"prova:schivata_{vid}"] = [f"arte/prova/personaggio_dash_{vid}.png"]
    for k, sp in (("fendente_pesante", "vfx_fendente_pesante"), ("incantesimo", "vfx_incantesimo"),
                  ("incantesimo_scoppio", "vfx_incantesimo_scoppio")):
        out[f"prova:{k}"] = [f"assets/vfx/{sp}.png"]
    out["prova:carica"] = ["assets/placeholder/personaggio_attack_heavy.png", "scripts/player.gd"]
    out["prova:stretta_ferrea"] = ["assets/vfx/vfx_stretta_ferrea.png"]
    for f in glob.glob(os.path.join(ROOT, "arte", "prova", "edificio_*.png")):          # edifici a griglia
        out["prova:" + os.path.basename(f)[:-4]] = [os.path.relpath(f, ROOT)]
    giro = [(asp, "personaggio", tuple(pers), "assets/placeholder") for asp in GIRO2["personaggi"]]
    giro += [(sp, "fauna", ("idle", "fuga"), "assets/placeholder") for sp in GIRO2["animali"]]
    giro += [(asp, "nemico_base", tuple(lupo), "assets/placeholder") for asp in GIRO2["nemici"]]
    giro += [(b, "nemico_base", tuple(lupo), "arte/prova") for b in GIRO2["boss"]]
    for asp, cat, anims, cart in giro:
        fs = [f"{cart}/{cat}_{asp}_{n}.png" for n in anims]
        out[f"prova:{asp}"] = fs
        for n, f in zip(anims, fs):
            out[f"prova:{asp}_{n}"] = [f]
    for nome in GIRO2["abilita"]:
        out[f"prova:{nome}"] = [f"assets/vfx/vfx_{nome}.png"]
    for f in glob.glob(os.path.join(ROOT, "arte", "prova", "oggetto_*.png")):
        out["prova:" + os.path.basename(f)[:-4]] = [os.path.relpath(f, ROOT)]
    for asp, cat, anims in (("mercante", "personaggio", ("idle", "walk")), ("cervo", "fauna", ("idle", "fuga"))):
        fs = [f"assets/placeholder/{cat}_{asp}_{n}.png" for n in anims]
        out[f"prova:{asp}"] = fs
        for n, f in zip(anims, fs):
            out[f"prova:{asp}_{n}"] = [f]
    return out


# Il giro di disegni da testare del 2026-11-22 (regola dell'utente: 1 personaggio completo, 5 edifici, 5 animali,
# 5 nemici, 1 boss, 10 abilita', 10 oggetti). Gli edifici si prendono tutti da arte/prova/edificio_*.png.
GIRO2 = {
    "personaggi": ("rivale", "investigatore", "guaritrice"),
    "animali": ("lepre", "volpe", "cinghiale", "capra", "orso", "cavallo", "mucca", "pecora", "maiale", "cane", "gatto",
                "tasso", "riccio", "scoiattolo", "lontra"),
    "nemici": ("scheletro_catacombe", "pirata_naufrago", "soldato_caduto", "ratto_delle_fogne", "granchio_corazzato",
               "tagliaborse", "scaricatore_ubriaco", "guardia_corrotta", "devoto_fuori_controllo",
               "contrabbandiere_balestra", "alfiere_spettrale", "custode_della_cripta", "lettore_proibito",
               "cervo_corna_rosse", "belva_dei_moli"),
    "boss": ("re_dei_ratti", "madre_delle_radici", "archivista_capo"),
    # effetto -> (abilita', frame, dove: chi_lancia | corpo | nemico)
    "abilita": {"incubo": ("darkness_incubo", 8, "nemico"), "tocco_gelido": ("death_tocco_gelido", 7, "chi_lancia"),
                "passo_breve": ("door_passo_breve", 7, "corpo"),
                "pugnalata_furtiva": ("error_pugnalata_furtiva", 6, "chi_lancia"),
                "velo_illusorio": ("fool_velo_illusorio", 8, "corpo"),
                "sigillo_su_arma": ("hermit_sigillo_su_arma", 8, "corpo"),
                "richiamo_compagno": ("moon_richiamo_compagno", 8, "chi_lancia"),
                "germoglio_rapido": ("mother_germoglio_rapido", 8, "chi_lancia"),
                "analisi": ("paragon_analisi", 7, "nemico"), "contrattacco": ("tg_contrattacco", 7, "chi_lancia"),
                "terrore_notturno": ("darkness_terrore_notturno", 8, "nemico"),
                "poesia_amara": ("darkness_poesia_amara", 8, "nemico"),
                "rianima_servo": ("death_rianima_servo", 8, "chi_lancia"),
                "lamento_funebre": ("death_lamento_funebre", 8, "chi_lancia"),
                "scambio_di_posto": ("door_scambio_di_posto", 7, "corpo"),
                "occhio_nell_ombra": ("door_occhio_nell_ombra", 8, "chi_lancia"),
                "scasso": ("error_scasso", 7, "chi_lancia"), "lettura_rubata": ("error_lettura_rubata", 7, "nemico"),
                "acrobazia": ("fool_acrobazia", 7, "corpo"), "oggetto_dal_nulla": ("fool_oggetto_dal_nulla", 8, "chi_lancia"),
                "percezione_mistica": ("hermit_percezione_mistica", 8, "corpo"),
                "evocazione_minore": ("hermit_evocazione_minore", 8, "chi_lancia"),
                "distillato_curativo": ("moon_distillato_curativo", 8, "corpo"),
                "legame_bestiale": ("moon_legame_bestiale", 7, "corpo"), "sutura": ("mother_sutura", 8, "corpo"),
                "mano_verde": ("mother_mano_verde", 8, "chi_lancia"), "scavo": ("paragon_scavo", 7, "chi_lancia"),
                "disinnesco": ("paragon_disinnesco", 8, "chi_lancia"),
                "carica_spalla": ("tg_carica_spalla", 7, "chi_lancia"), "turbine": ("tg_turbine", 8, "corpo")},
}
PROVA_DIR = os.path.join(ROOT, "arte", "prova")


def _anims(cat):
    return [n for n, a in senza_commenti(ANIM[cat]).items() if isinstance(a, dict) and "frames" in a]


def versioni():
    reg = json.load(open(REGISTRO, encoding="utf-8")) if os.path.isfile(REGISTRO) else {}
    adesso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    out = {}
    for k, files in _file_prova().items():
        dati = [open(os.path.join(ROOT, f), "rb").read() for f in files if os.path.isfile(os.path.join(ROOT, f))]
        if not dati:
            continue
        v = _sha(*dati)
        if k not in reg:                          # prima volta: com'era al commit giudicato?
            prima = []
            for f in files:
                r = subprocess.run(["git", "show", f"{GIUDICATO}:{f}"], cwd=ROOT, capture_output=True)
                prima.append(r.stdout if r.returncode == 0 else b"")
            reg[k] = {"v": v, "dal": "2026-11-18T00:00:00Z" if _sha(*prima) == v else adesso}
        elif reg[k]["v"] != v:
            reg[k] = {"v": v, "dal": adesso}
        out[k] = reg[k]
    with open(REGISTRO, "w", encoding="utf-8") as fh:
        json.dump(reg, fh, ensure_ascii=False, indent=1, sort_keys=True)
    return out


def _descrizioni():
    """Le descrizioni stanno nel codice dei disegni (docstring): chiave della prova -> testo."""
    import importlib
    sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
    out = {}
    pulisci = lambda d: " ".join((d or "").split("\n\n")[0].split())
    for mod in os.listdir(os.path.join(ROOT, "tools", "art", "griglia", "figure")):
        if mod.endswith(".py") and not mod.startswith("_"):
            m = importlib.import_module("griglia.figure." + mod[:-3])
            out["prova:" + getattr(m, "ASPETTO", mod[:-3])] = pulisci(m.__doc__)
    from griglia.edifici import EDIFICI
    from griglia.effetti import EFFETTI
    from griglia.oggetti import OGGETTI
    out.update({"prova:edificio_" + k: pulisci(f.__doc__) for k, f in EDIFICI.items()})
    out.update({"prova:" + k[4:]: pulisci(f.__doc__) for k, (f, _) in EFFETTI.items()})
    out.update({"prova:oggetto_" + k: pulisci(f.__doc__) for k, f in OGGETTI.items()})
    return out


def giro2():
    """Le figure e le icone dei giri di disegni da testare per la pagina Da testare."""
    out = {"personaggi": [], "animali": [], "nemici": [], "boss": [], "oggetti": [], "descr": _descrizioni()}
    for asp in GIRO2["personaggi"]:
        if figura("npc_" + asp, "personaggio", asp):
            out["personaggi"].append({"id": asp, "figura": "npc_" + asp})
    for sp in GIRO2["animali"]:
        if figura("fauna_" + sp, "fauna", sp):
            out["animali"].append({"id": sp, "figura": "fauna_" + sp})
    for asp in GIRO2["nemici"]:
        if figura("nem_" + asp, "nemico_base", asp):
            out["nemici"].append({"id": asp, "figura": "nem_" + asp})
    for b in GIRO2["boss"]:
        if figura("boss_" + b, "nemico_base", b, cartella=PROVA_DIR):
            out["boss"].append({"id": b, "figura": "boss_" + b})
    nomi = {}
    for f in glob.glob(os.path.join(DATA, "items", "*.json")):
        for it in json.load(open(f, encoding="utf-8")).get("items", []):
            nomi[it["id"]] = (tr(it.get("name_i18n"), it.get("name", it["id"])),
                              tr(it.get("descrizione_i18n"), it.get("descrizione", "")))
    for f in sorted(glob.glob(os.path.join(PROVA_DIR, "oggetto_*.png"))):
        iid = os.path.basename(f)[len("oggetto_"):-4]
        shutil.copy(f, os.path.join(IMG, f"oggetto_{iid}.png"))
        out["oggetti"].append({"id": iid, "file": f"img/oggetto_{iid}.png", "nome": nomi.get(iid, (iid, ""))[0],
                               "descrizione": nomi.get(iid, ("", ""))[1]})
    return out


def edifici_prova():
    """Gli edifici a griglia da giudicare (arte/prova/edificio_<id>.png, tools/art/build_griglia.py --edifici)."""
    out = []
    for f in sorted(glob.glob(os.path.join(ROOT, "arte", "prova", "edificio_*.png"))):
        nome = os.path.basename(f)[:-4]
        shutil.copy(f, os.path.join(IMG, nome + ".png"))
        im = Image.open(f)
        out.append({"id": nome, "file": f"img/{nome}.png", "w": im.width, "h": im.height})
    return out


def varianti_schivata():
    """Le versioni della schivata da scegliere (tools/art/build_griglia.py -> arte/prova/): una figura ciascuna."""
    import importlib
    sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
    mod = importlib.import_module("griglia.figure.personaggio")
    a = ANIM["personaggio"]["dash"]
    for vid, v in getattr(mod, "VARIANTI", {}).get("dash", {}).items():
        src = os.path.join(ROOT, "arte", "prova", f"personaggio_dash_{vid}.png")
        if not os.path.isfile(src):
            continue
        im = Image.open(src)
        nome_file = f"img/fig_dash_{vid}.png"
        im.save(os.path.join(OUT, nome_file), optimize=True)
        n = int(a["frames"])
        FIGURE["dash_" + vid] = {"file": nome_file, "nome": v["nome"], "anims": [{
            "nome": "dash", "y": 0, "righe": 4, "frames": n, "w": im.width // n, "h": im.height // 4,
            "durate": [int(1000 / float(a.get("fps", 20)))] * n, "loop": True}]}


def figura(fid, categoria, aspetto="", spec_cat=None, cartella=None):
    """Un foglio unico con tutte le animazioni di <categoria>[_<aspetto>]_<anim>.png una sotto l'altra."""
    spec = senza_commenti(ANIM[spec_cat or categoria])
    pezzi, meta, y, larg = [], [], 0, 0
    for nome, a in spec.items():
        if not isinstance(a, dict) or "frames" not in a:
            continue
        pre = f"{categoria}_{aspetto}_" if aspetto else f"{categoria}_"
        f = os.path.join(cartella or PH, f"{pre}{nome}.png")
        if not os.path.isfile(f):
            continue
        im = Image.open(f).convert("RGBA")
        righe = 4 if a.get("direzionale") else 1
        frames = int(a["frames"])
        cw, ch = im.width // frames, im.height // righe
        durate = a.get("durate_ms") or [int(1000 / float(a.get("fps", 8)))] * frames
        meta.append({"nome": nome, "y": y, "righe": righe, "frames": frames, "w": cw, "h": ch,
                     "durate": durate, "loop": bool(a.get("loop", True))})
        pezzi.append(im)
        y += im.height
        larg = max(larg, im.width)
    if not pezzi:
        return None
    foglio = Image.new("RGBA", (larg, y))
    yy = 0
    for im in pezzi:
        foglio.paste(im, (0, yy))
        yy += im.height
    nome_file = f"img/fig_{fid}.png"
    foglio.save(os.path.join(OUT, nome_file), optimize=True)
    FIGURE[fid] = {"file": nome_file, "anims": meta}
    return fid


# --- atlanti di icone -------------------------------------------------------------------------------------------
ATLANTI = {}


def atlante(nome, files, lato=None):
    """files: {id: percorso}. Griglia di celle uguali (la piu' grande), a 16 colonne."""
    ims = {k: Image.open(v).convert("RGBA") for k, v in sorted(files.items()) if os.path.isfile(v)}
    if not ims:
        return
    cw = max(i.width for i in ims.values())
    ch = max(i.height for i in ims.values())
    cols = 16 if len(ims) > 16 else len(ims)
    rows = (len(ims) + cols - 1) // cols
    out = Image.new("RGBA", (cols * cw, rows * ch))
    indice = {}
    for n, (k, im) in enumerate(ims.items()):
        x, y = (n % cols) * cw, (n // cols) * ch
        out.paste(im, (x + (cw - im.width) // 2, y + (ch - im.height) // 2))
        indice[k] = n
    f = f"img/atl_{nome}.png"
    out.save(os.path.join(OUT, f), optimize=True)
    ATLANTI[nome] = {"file": f, "w": cw, "h": ch, "cols": cols, "indice": indice}


# --- mappa ------------------------------------------------------------------------------------------------------
def mappa(mondo, tema="luminoso", sotto=False):
    """2 px per casella: ogni tessera ridotta a 2x2 col suo colore medio, poi gli oggetti di scena col loro.
    sotto=True: il sottosuolo (secondo livello sulla stessa griglia, senza oggetti di scena)."""
    cart = os.path.join(ROOT, "assets", "world", tema, *(["sotto"] if sotto else []))
    nfogli = int((mondo["sottosuolo"]["fogli"] if sotto else mondo["fogli"])[tema])
    cols, righe = int(mondo["colonne_foglio"]), int(mondo["righe_foglio"])
    t = int(mondo["tile"])
    medie = []
    for k in range(nfogli):
        a = np.asarray(Image.open(os.path.join(cart, f"tessere_{k}.png")).convert("RGB"), dtype=np.float32)
        r_k = a.shape[0] // t                                                  # l'ultimo foglio e' piu' corto
        a = a[:r_k * t].reshape(r_k, t, cols, t, 3).transpose(0, 2, 1, 3, 4)  # (r, c, t, t, 3)
        a = a.reshape(r_k, cols, 2, t // 2, 2, t // 2, 3).mean(axis=(3, 5))    # (r, c, 2, 2, 3)
        blocco = np.zeros((righe * cols, 2, 2, 3), np.float32)
        blocco[:r_k * cols] = a.reshape(r_k * cols, 2, 2, 3)
        medie.append(blocco)
    medie = np.concatenate(medie)
    ind = np.asarray(Image.open(os.path.join(cart, "indici.png")).convert("RGB")).astype(np.int64)
    idx = np.clip(ind[..., 0] + 256 * ind[..., 1], 0, len(medie) - 1)
    H, W = idx.shape
    img = medie[idx].transpose(0, 2, 1, 3, 4).reshape(H * 2, W * 2, 3)
    # oggetti di scena (alberi, rocce, case): il loro colore medio, alla base
    colori = {}
    ogg_dir = os.path.join(cart, "oggetti")
    for nome, x, y in ((o[0], o[1], o[2]) for o in ([] if sotto else mondo["oggetti"])):
        if nome not in colori:
            p = os.path.join(ogg_dir, nome + ".png")
            if os.path.isfile(p):
                a = np.asarray(Image.open(p).convert("RGBA"), dtype=np.float32)
                m = a[..., 3] > 128
                colori[nome] = a[..., :3][m].mean(axis=0) if m.any() else None
            else:
                colori[nome] = None
        c = colori[nome]
        if c is None:
            continue
        px, py = int(x * 2), int(y * 2) - 2
        if 0 <= px < W * 2 - 1 and 0 <= py < H * 2 - 1:
            img[py:py + 2, px:px + 2] = c * 0.85
    nome = "img/mappa_sotto.png" if sotto else "img/mappa.png"
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(os.path.join(OUT, nome), optimize=True)
    return {"file": nome, "w": W, "h": H, "scala": 2}


def mappa_dettaglio(mondo, tema="luminoso", sotto=False):
    """La mappa da ingrandire fino alle caselle vere: le tessere del gioco e gli indici (la pagina compone solo il
    pezzo che si vede), e gli oggetti di scena impacchettati in pochi atlanti con la loro ancora (come mondo.gd)."""
    cart = os.path.join(ROOT, "assets", "world", tema, *(["sotto"] if sotto else []))
    cartella = "mondo_sotto" if sotto else "mondo"
    dest = os.path.join(OUT, "img", cartella)
    os.makedirs(dest, exist_ok=True)
    tessere = []
    for k in range(int((mondo["sottosuolo"]["fogli"] if sotto else mondo["fogli"])[tema])):
        shutil.copy(os.path.join(cart, f"tessere_{k}.png"), os.path.join(dest, f"tessere_{k}.png"))
        tessere.append(f"img/{cartella}/tessere_{k}.png")
    shutil.copy(os.path.join(cart, "indici.png"), os.path.join(dest, "indici.png"))
    nomi = sorted({o[0] for o in ([] if sotto else mondo["oggetti"])})
    ims = {n: Image.open(os.path.join(cart, "oggetti", n + ".png")).convert("RGBA") for n in nomi
           if os.path.isfile(os.path.join(cart, "oggetti", n + ".png"))}
    LARGO, atlanti, sprite = 2048, [], {}
    fogli, x, y, riga = [Image.new("RGBA", (LARGO, LARGO))], 0, 0, 0
    for n in sorted(ims, key=lambda n: -ims[n].height):        # scaffali: prima i piu' alti
        im = ims[n]
        if x + im.width > LARGO:
            x, y, riga = 0, y + riga, 0
        if y + im.height > LARGO:
            fogli.append(Image.new("RGBA", (LARGO, LARGO)))
            x, y, riga = 0, 0, 0
        fogli[-1].paste(im, (x, y))
        m = mondo["sprite"].get(n, {})
        sprite[n] = [len(fogli) - 1, x, y, im.width, im.height, m.get("ax", 0), m.get("ay", 0)]
        x += im.width
        riga = max(riga, im.height)
    for i, f in enumerate(fogli):
        f.save(os.path.join(dest, f"oggetti_{i}.png"), optimize=True)
        atlanti.append(f"img/{cartella}/oggetti_{i}.png")
    nomi_ok = [n for n in nomi if n in sprite]
    idx = {n: i for i, n in enumerate(nomi_ok)}
    ogg = [[idx[o[0]], round(o[1], 2), round(o[2], 2)] for o in ([] if sotto else mondo["oggetti"]) if o[0] in idx]
    ogg.sort(key=lambda o: o[2])
    with open(os.path.join(OUT, cartella + ".json"), "w", encoding="utf-8") as f:
        json.dump({"tile": mondo["tile"], "colonne": mondo["colonne_foglio"], "righe": mondo["righe_foglio"],
                   "tessere": tessere, "indici": f"img/{cartella}/indici.png", "atlanti": atlanti,
                   "sprite": [sprite[n] for n in nomi_ok], "nomi": nomi_ok, "oggetti": ogg}, f, separators=(",", ":"))
    return cartella + ".json"


# --- avanzamento ------------------------------------------------------------------------------------------------
def git(*a):
    return subprocess.run(["git", *a], cwd=ROOT, capture_output=True, text=True).stdout


def avanzamento():
    prd = j("prd.json")
    storie = [{"id": s["id"], "titolo": s.get("title", ""), "fase": str(s.get("fase", "")),
               "priorita": s.get("priority", 999), "fatta": bool(s.get("passes")), "note": s.get("notes", ""),
               "descrizione": s.get("description", ""), "criteri": s.get("acceptanceCriteria", [])}
              for s in prd.get("userStories", [])]
    commit = []
    for riga in git("log", "-400", "--pretty=format:%h\t%cI\t%s").splitlines():
        h, d, m = riga.split("\t", 2)
        commit.append({"sha": h, "data": d, "msg": m})
    n_test = sum(len(re.findall(r"^func test_", open(f, encoding="utf-8").read(), re.M))
                 for f in glob.glob(os.path.join(ROOT, "tests", "*.gd")))
    v = subprocess.run([sys.executable, "tools/validate_data.py"], cwd=ROOT, capture_output=True, text=True)
    ultima = (v.stdout.strip().splitlines() or [""])[-1]
    # le sezioni di progress.txt (titoli "## ...")
    prog = [r[3:].strip() for r in open(os.path.join(ROOT, "progress.txt"), encoding="utf-8") if r.startswith("## ")]
    return {"storie": storie, "commit": commit, "test": n_test, "validator": ultima,
            "validator_ok": v.returncode == 0, "progress": prog[-40:]}


# --- nemici e boss -----------------------------------------------------------------------------------------------
def nemici():
    bal = j("data", "balance.json")
    tipi = senza_commenti(bal["nemici_tipi"])
    base = senza_commenti(bal["nemico_base"])
    dove = {}
    for f in glob.glob(os.path.join(DATA, "world", "layouts", "*.json")):
        lay = json.load(open(f, encoding="utf-8"))
        for n in lay.get("nemici", []):
            d = dove.setdefault(n.get("tipo"), {})
            d[lay["region_id"]] = d.get(lay["region_id"], 0) + 1
    for f in glob.glob(os.path.join(DATA, "world", "interni", "*.json")):
        lay = json.load(open(f, encoding="utf-8"))
        for n in lay.get("nemici", []):
            d = dove.setdefault(n.get("tipo"), {})
            k = "interno:" + os.path.basename(f)[:-5]
            d[k] = d.get(k, 0) + 1
    figura("nemico_base", "nemico_base")
    out = []
    for tid, t in tipi.items():
        asp = t.get("aspetto", "nemico_base")
        fid = "nemico_base" if asp == "nemico_base" else figura("nem_" + asp, "nemico_base", asp)
        num = {k: t.get(k, base.get(k)) for k in ("danno_attacco", "raggio_aggro", "raggio_attacco", "postura_massimo",
                                                   "recupero_s", "telegraph")}
        out.append({"id": tid, "nome": tr(t.get("name_i18n"), tid), "rarita": t.get("rarita"),
                    "comportamento": t.get("comportamento"), "tag": t.get("tag", base.get("tag")),
                    "aspetto": asp, "figura": fid, "numeri": num, "dove": dove.get(tid, {})})
    boss = []
    posati = {}
    for f in glob.glob(os.path.join(DATA, "world", "layouts", "*.json")):
        lay = json.load(open(f, encoding="utf-8"))
        for n in lay.get("nemici", []):
            if n.get("boss"):
                posati[n["boss"]] = {"regione": lay["region_id"], "tipo": n.get("tipo"), "sequenza": n.get("sequenza")}
    for bid, b in senza_commenti(bal.get("boss", {})).items():
        p = posati.get(bid, {})
        asp = tipi.get(p.get("tipo"), {}).get("aspetto", "nemico_base")
        boss.append({"id": bid, "nome": tr(b.get("name_i18n"), bid), "vita_x": b.get("vita_x"), "arena": b.get("arena"),
                     "fasi": b.get("fasi"), "posato": p,
                     "figura": "nemico_base" if asp == "nemico_base" else "nem_" + asp})
    return out, boss


# --- personaggi --------------------------------------------------------------------------------------------------
def personaggi():
    figura("enel", "personaggio")
    varianti_schivata()
    forme = []
    for fid_, f in senza_commenti(j("data", "forms.json").get("forms", {})).items():
        if f.get("aspetto") and figura("forma_" + f["aspetto"], "personaggio", f["aspetto"]):
            forme.append({"id": fid_, "nome": tr(f.get("name_i18n"), fid_), "figura": "forma_" + f["aspetto"]})
    fazioni = {x["id"]: tr(x.get("name_i18n"), x["id"]) for x in j("data", "factions.json").get("factions", [])} \
        if os.path.isfile(os.path.join(DATA, "factions.json")) else {}
    quest_di = {}
    for f in glob.glob(os.path.join(DATA, "quests", "*.json")):
        q = json.load(open(f, encoding="utf-8"))
        quest_di.setdefault(q.get("giver"), []).append(tr(q.get("name_i18n"), q.get("name", q.get("id"))))
    npc = []
    ritratti = {}
    for n in j("data", "npc", "roster.json")["npcs"]:
        asp = (n.get("aspetto") or {}).get("sprite")
        fid = figura("npc_" + asp, "personaggio", asp) if asp else None
        if asp:
            ritratti[asp] = os.path.join(ROOT, "assets", "ritratti", asp + ".png")
        npc.append({"id": n["id"], "nome": tr(n.get("name_i18n"), n.get("name")), "ruolo": tr(n.get("role_i18n"), n.get("role", "")),
                    "regione": n.get("region_id"), "fazione": fazioni.get(n.get("faction_id"), n.get("faction_id")),
                    "ancora": bool(n.get("anchor_candidate")), "negozio": bool(n.get("vendor")),
                    "dialogo": n.get("dialogue_id"), "orari": n.get("schedule", []), "figura": fid,
                    "ritratto": asp, "quest": quest_di.get(n["id"], [])})
    ant = []
    for a in j("data", "lore", "antagonisti.json").get("antagonisti", []):
        asp = a.get("aspetto")
        fid = figura("npc_" + asp, "personaggio", asp) if asp else None
        if asp:
            ritratti[asp] = os.path.join(ROOT, "assets", "ritratti", asp + ".png")
        ant.append({"id": a["id"], "nome": tr(a.get("name_i18n"), a.get("name", a["id"])), "pathway": a.get("pathway_id"),
                    "figura": fid, "ritratto": asp})
    ritratti["personaggio"] = os.path.join(ROOT, "assets", "ritratti", "personaggio.png")
    atlante("ritratti", ritratti)
    pet = []
    for p in j("data", "pets", "core.json").get("pets", []):
        pet.append({"id": p["id"], "nome": tr(p.get("name_i18n"), p.get("name")), "figura": figura("pet_" + p["id"], "pet", p["id"]),
                    "tag": p.get("tag", []), "domabilita": p.get("domabilita")})
    fauna = []
    for sp in senza_commenti(j("data", "world", "fauna.json").get("specie", {})):
        fid = figura("fauna_" + sp, "fauna", sp)
        if fid:
            fauna.append({"id": sp, "figura": fid})
    return {"enel": "enel", "forme": forme, "npc": npc, "antagonisti": ant, "pet": pet, "fauna": fauna}


# --- tecniche ----------------------------------------------------------------------------------------------------
def tecniche():
    abil = {}
    for f in glob.glob(os.path.join(DATA, "abilities", "*.json")):
        for a in json.load(open(f, encoding="utf-8")).get("abilities", []):
            abil[a["id"]] = a
    vfx = j("data", "vfx.json")
    pal = senza_commenti(vfx["pathway_palette_visiva"])
    pw = []
    for f in sorted(glob.glob(os.path.join(DATA, "pathways", "*.json"))):
        p = json.load(open(f, encoding="utf-8"))
        seq = []
        for s in sorted(p.get("sequences", []), key=lambda s: -s["sequence"]):
            ab = []
            for aid in s.get("abilities", []):
                a = abil.get(aid, {})
                ab.append({"id": aid, "nome": tr(a.get("name_i18n"), aid), "costo": a.get("costo_spiritualita"),
                           "cd": a.get("cooldown"), "primitive": [x.get("tipo") for x in a.get("primitive", [])],
                           "tag": a.get("tag_sinergia", []), "note": a.get("note", ""), "_prim": a.get("primitive", [])})
            seq.append({"n": s["sequence"], "nome": tr(s.get("name_i18n"), s.get("name")), "tier": s.get("tier"),
                        "concetto": s.get("concept", ""), "abilita": ab,
                        "recitazione": [x.get("descrizione", "") for x in s.get("acting_actions", [])]})
        pw.append({"id": p["id"], "nome": tr(p.get("name_i18n"), p.get("name")), "gruppo": p.get("group"),
                   "verbo": p.get("gameplay_verb", ""), "palette": pal.get(p["id"], {}), "sequenze": seq})
    prim = {os.path.basename(f)[:-4]: f for f in glob.glob(os.path.join(ROOT, "assets", "icone", "primitive", "*.png"))}
    atlante("primitive", prim)
    effetti = []
    for pid, e in senza_commenti(vfx["primitive_vfx"]).items():
        for nome, fr in ((e.get("sprite"), e.get("frames")), ((e.get("scoppio") or {}).get("sprite"), (e.get("scoppio") or {}).get("frames"))):
            if not nome:
                continue
            src = os.path.join(ROOT, "assets", "vfx", nome + ".png")
            if os.path.isfile(src) and not any(x["sprite"] == nome for x in effetti):
                shutil.copy(src, os.path.join(IMG, nome + ".png"))
                effetti.append({"primitiva": pid, "sprite": nome, "file": f"img/{nome}.png", "frames": fr or 1,
                                "lampo": bool(e.get("impact_frame")), "su": e.get("su", "chi_lancia"),
                                "gira": bool(e.get("gira")), "vola": bool(e.get("sul_proiettile")),
                                "scoppio": (e.get("scoppio") or {}).get("sprite") if nome == e.get("sprite") else None})
    # effetti unici del nuovo stile (tools/art/griglia/effetti.py): uno per abilita', non per primitiva
    for nome, fr, ab, vola, scoppio in (("vfx_fendente_pesante", 8, "attack_heavy", False, None),
                                        ("vfx_incantesimo", 4, "hermit_incantesimo_tradizionale", True,
                                         "vfx_incantesimo_scoppio"),
                                        ("vfx_incantesimo_scoppio", 7, "hermit_incantesimo_tradizionale", False, None),
                                        ("vfx_stretta_ferrea", 8, "tg_stretta_ferrea", False, None),
                                        *[(f"vfx_{k}", v[1], v[0], False, None) for k, v in GIRO2["abilita"].items()]):
        src = os.path.join(ROOT, "assets", "vfx", nome + ".png")
        if os.path.isfile(src):
            shutil.copy(src, os.path.join(IMG, nome + ".png"))
            effetti.append({"primitiva": None, "abilita": ab, "sprite": nome, "file": f"img/{nome}.png", "frames": fr,
                            "lampo": True, "su": "chi_lancia", "gira": not vola, "vola": vola, "scoppio": scoppio,
                            "unico": True, "centro": nome == "vfx_stretta_ferrea" or
                            GIRO2["abilita"].get(nome[4:], ("", 0, ""))[2] == "corpo",
                            "sul_nemico": GIRO2["abilita"].get(nome[4:], ("", 0, ""))[2] == "nemico"})
    return {"pathway": pw, "effetti": effetti}


# --- oggetti ------------------------------------------------------------------------------------------------------
def oggetti():
    ic = j("data", "ui", "icone.json")["oggetti"]
    out, files = [], {}
    for f in sorted(glob.glob(os.path.join(DATA, "items", "*.json"))):
        for it in json.load(open(f, encoding="utf-8")).get("items", []):
            icona = ic.get(it["id"])
            if icona:
                files[icona] = os.path.join(ROOT, "assets", "icone", "oggetti", icona + ".png")
            out.append({"id": it["id"], "nome": tr(it.get("name_i18n"), it.get("name", it["id"])),
                        "descrizione": tr(it.get("descrizione_i18n"), it.get("descrizione", "")),
                        "categoria": it.get("categoria"), "rarita": it.get("rarita"), "valore": it.get("valore"),
                        "tag": it.get("tag", []), "icona": icona, "file": os.path.basename(f)[:-5]})
    atlante("oggetti", files)
    stati = {os.path.basename(f)[:-4]: f for f in glob.glob(os.path.join(ROOT, "assets", "icone", "stati", "*.png"))}
    atlante("stati", stati)
    st = {k: {"nome": tr(v.get("name_i18n"), k), "negativo": bool(v.get("negativo")), "descrizione": v.get("descrizione", "")}
          for k, v in senza_commenti(j("data", "status_effects.json")["statuses"]).items()}
    return out, st


# --- mondo --------------------------------------------------------------------------------------------------------
def mondo():
    m = j("assets", "world", "mondo.json")
    reg = {r["id"]: {"nome": tr(r.get("name_i18n"), r.get("name", r["id"])), "accesso": r.get("accesso"),
                     "gating": r.get("gating", [])} for r in j("data", "world", "regions.json")["regions"]}
    foto = {}
    fj = os.path.join(OUT, "foto", "foto.json")
    if os.path.isfile(fj):
        for x in json.load(open(fj, encoding="utf-8")):
            foto[f"{x['tipo']}:{x['id']}"] = "foto/" + x["file"]
    porte = {}
    for f in glob.glob(os.path.join(DATA, "world", "layouts", "*.json")):
        lay = json.load(open(f, encoding="utf-8"))
        for e in lay.get("edifici", []):
            porte.setdefault(e.get("villaggio") or lay["region_id"], []).append(e.get("interno_id"))
    interni = []
    for f in sorted(glob.glob(os.path.join(DATA, "world", "interni", "*.json"))):
        i = json.load(open(f, encoding="utf-8"))
        iid = os.path.basename(f)[:-5]
        interni.append({"id": iid, "nome": tr(i.get("name_i18n"), i.get("name", iid)),
                        "nemici": len(i.get("nemici", [])), "oggetti": len(i.get("oggetti", [])),
                        "forzieri": len(i.get("forzieri", [])), "npc": [n.get("npc_id", n.get("id")) for n in i.get("npc", [])],
                        "foto": foto.get("interno:" + iid)})
    edifici_per_villaggio = {}
    for x, y, w, h, tipo in m["edifici"]:
        vic = min(m["villaggi"].items(), key=lambda kv: (kv[1][0] - x) ** 2 + (kv[1][1] - y) ** 2)
        if (vic[1][0] - x) ** 2 + (vic[1][1] - y) ** 2 < 40 ** 2:
            edifici_per_villaggio.setdefault(vic[0], {}).setdefault(tipo, 0)
            edifici_per_villaggio[vic[0]][tipo] += 1
    return {"w": m["larghezza"], "h": m["altezza"], "partenza": m["partenza"], "regioni": reg,
            "riquadri": m["riquadri"], "mappa": mappa(m), "dettaglio": mappa_dettaglio(m),
            "sotto": {"mappa": mappa(m, sotto=True), "dettaglio": mappa_dettaglio(m, sotto=True)},
            "luoghi": [{"id": k, "x": v[0], "y": v[1], "foto": foto.get("luogo:" + k)} for k, v in m["luoghi"].items()],
            "villaggi": [{"id": k, "x": v[0], "y": v[1], "foto": foto.get("villaggio:" + k),
                          "edifici": edifici_per_villaggio.get(k, {}), "porte": porte.get(k, [])} for k, v in m["villaggi"].items()],
            "ingressi": [{"id": k, "x": v[0], "y": v[1], "verso": v[2]} for k, v in m["sottosuolo"]["ingressi"].items()],
            "boss_sotto": [{"id": k, "x": v[0], "y": v[1]} for k, v in m["sottosuolo"]["boss"].items()],
            "edifici": len(m["edifici"]), "oggetti_scena": len(m["oggetti"]), "interni": interni,
            "libro": sorted([{"id": k.split(":", 1)[1], "foto": v} for k, v in foto.items() if k.startswith(("libro:", "hud:"))],
                            key=lambda x: x["id"])}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--foto", action="store_true", help="rifa le foto dal gioco (Godot + Xvfb)")
    a = ap.parse_args()
    os.makedirs(IMG, exist_ok=True)
    if a.foto:
        os.makedirs(os.path.join(OUT, "foto"), exist_ok=True)
        subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", os.environ.get("GODOT", "godot"),
                        "--display-driver", "x11", "--rendering-driver", "opengl3", "--path", ROOT,
                        "--script", "res://tests/manual/qa_dashboard_foto.gd", "--", os.path.join(OUT, "foto")], check=True)
    dati = {"generato": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "commit": git("rev-parse", "--short", "HEAD").strip(), "ramo": git("rev-parse", "--abbrev-ref", "HEAD").strip()}
    dati["avanzamento"] = avanzamento()
    dati["nemici"], dati["boss"] = nemici()
    dati["personaggi"] = personaggi()
    dati["tecniche"] = tecniche()
    dati["edifici_prova"] = edifici_prova()
    dati["giro2"] = giro2()
    dati["versioni"] = versioni()
    dati["domande"] = json.load(open(os.path.join(ROOT, "tools", "dashboard", "domande.json"), encoding="utf-8"))
    dati["combattimento"] = senza_commenti(json.load(open(os.path.join(DATA, "balance.json"), encoding="utf-8"))["combattimento"])
    dati["oggetti"], dati["stati"] = oggetti()
    dati["mondo"] = mondo()
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import info
    dati["info"] = info.costruisci(dati, tr)
    for pw in dati["tecniche"]["pathway"]:                     # la frase precisa va anche sulla carta e nella prova
        for sq in pw["sequenze"]:
            for ab in sq["abilita"]:
                ab["cosa"] = [info.spiega(p) for p in ab.pop("_prim")]
    dati["previsti"] = json.load(open(os.path.join(ROOT, "tools", "dashboard", "previsti.json"), encoding="utf-8"))["voci"]
    dati["figure"] = FIGURE
    dati["atlanti"] = ATLANTI
    with open(os.path.join(OUT, "dati.json"), "w", encoding="utf-8") as f:
        json.dump(dati, f, ensure_ascii=False, separators=(",", ":"))
    shutil.copy(os.path.join(ROOT, "tools", "dashboard", "pagina.html"), os.path.join(OUT, "index.html"))
    n = sum(len(fs) for _, _, fs in os.walk(OUT))
    print(f"build/dashboard: {len(FIGURE)} figure, {len(ATLANTI)} atlanti, {n} file, "
          f"dati.json {os.path.getsize(os.path.join(OUT, 'dati.json')) // 1024} KB")


if __name__ == "__main__":
    main()
