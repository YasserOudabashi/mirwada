#!/usr/bin/env python3
"""
Validator dei dati di gioco. Esce con codice 1 se qualcosa non torna.

Esecuzione (dalla root del progetto):
    python tools/validate_data.py

Va in CI e nei criteri di accettazione di ogni story di dati.
Non richiede dipendenze esterne: i controlli sono espliciti, non basati su
una libreria jsonschema, cosi' che il comando giri ovunque senza pip install.
Gli schema in data/schema/ restano la documentazione formale del formato.
"""

import json
import os
import struct
import sys
from collections import Counter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DATA = os.path.join(ROOT, "data")

EXPECTED_PATHWAYS = 10  # 4 gruppi completi. Gli altri 12 sono in data/pathways_deferred/ (fuori scope, non cancellati).
EXPECTED_SEQUENCES_PER_PATHWAY = 10
VALID_GROUPS = {
    "lord_of_mysteries", "god_almighty", "eternal_darkness",
    "calamity_of_destruction", "demon_of_knowledge", "key_of_light",
    "goddess_of_origin", "father_of_devils", "the_anarchy",
}
VALID_TIERS = {"low", "mid", "saint", "angel", "god"}

errors = []
warnings = []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def load_json(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception as exc:  # noqa: BLE001
        err(f"{os.path.relpath(path, ROOT)}: JSON non leggibile: {exc}")
        return None


def expected_tier(seq_num):
    if seq_num >= 7:
        return "low"
    if seq_num >= 5:
        return "mid"
    if seq_num >= 3:
        return "saint"
    if seq_num >= 1:
        return "angel"
    return "god"


VALID_BOON_TIPI = {"quest", "comportamento", "sacrificio"}
VALID_COSTO_TIPI = {"oggetto", "caratteristica", "follia"}


def valida_boon(rel, sid, boon, events, quest_ids, item_ids, char_ids):
    """Valida il campo 'boon' di una Sequenza di un Pathway non_standard
    (fase 9, US-901: data/schema/boon.schema.json). Ritorna una lista di
    stringhe di errore, il chiamante le passa a err()."""
    out = []
    requisiti = boon.get("requisiti", [])
    if not isinstance(requisiti, list) or not requisiti:
        out.append(f"{rel} [{sid}]: boon.requisiti deve essere una lista non vuota")
        return out
    for i, req in enumerate(requisiti):
        etichetta = f"{rel} [{sid}] boon.requisiti[{i}]"
        tipo = req.get("tipo")
        if tipo not in VALID_BOON_TIPI:
            out.append(f"{etichetta}: tipo '{tipo}' non nel vocabolario chiuso {sorted(VALID_BOON_TIPI)}")
            continue
        if tipo == "quest":
            qid = req.get("quest_id")
            if qid not in quest_ids:
                out.append(f"{etichetta}: quest_id '{qid}' non esiste in data/quests/")
        elif tipo == "comportamento":
            ev = req.get("evento")
            if ev not in events:
                out.append(f"{etichetta}: evento '{ev}' non nel vocabolario chiuso di "
                            f"data/schema/tracked_events.json. Un evento nuovo e' CODICE: "
                            f"va discusso, non aggiunto di slancio.")
            else:
                allowed = set(events[ev].get("filtri", []))
                for f in req.get("filtri", {}):
                    if f not in allowed:
                        out.append(f"{etichetta}: filtro '{f}' non ammesso per l'evento "
                                    f"'{ev}' (ammessi: {sorted(allowed)})")
            if not req.get("target", 0) > 0:
                out.append(f"{etichetta}: target deve essere un numero > 0")
        elif tipo == "sacrificio":
            costo = req.get("costo", {})
            ctipo = costo.get("tipo")
            if ctipo not in VALID_COSTO_TIPI:
                out.append(f"{etichetta}: costo.tipo '{ctipo}' non nel vocabolario chiuso "
                            f"{sorted(VALID_COSTO_TIPI)}")
            elif ctipo == "oggetto" and costo.get("id") not in item_ids:
                out.append(f"{etichetta}: costo.id '{costo.get('id')}' non e' un item esistente")
            elif ctipo == "caratteristica" and costo.get("id") not in char_ids:
                out.append(f"{etichetta}: costo.id '{costo.get('id')}' non e' una Caratteristica esistente")
            if ctipo in ("oggetto", "caratteristica") and not (
                    isinstance(costo.get("quantita"), (int, float)) and costo.get("quantita") > 0):
                out.append(f"{etichetta}: costo.quantita deve essere un numero > 0")
    return out


def main():
    # --- vocabolari di riferimento ---
    prim_doc = load_json(os.path.join(DATA, "schema", "primitives.json"))
    tags_doc = load_json(os.path.join(DATA, "tags.json"))
    ev_doc = load_json(os.path.join(DATA, "schema", "tracked_events.json"))
    dmg_doc = load_json(os.path.join(DATA, "schema", "damage_tags.json"))
    time_doc = load_json(os.path.join(DATA, "schema", "time.json"))
    if None in (prim_doc, tags_doc, ev_doc, dmg_doc, time_doc):
        report()
        return 1

    all_primitives = set(prim_doc["primitives"].keys())
    primitives = {k for k, v in prim_doc["primitives"].items() if not v.get("deferred")}
    deferred_primitives = all_primitives - primitives
    # Il registro dichiara i parametri di ogni primitiva: un nome sbagliato nei
    # dati diventerebbe silenziosamente il default a runtime (danno a zero).
    prim_params = {k: set(v.get("params", [])) for k, v in prim_doc["primitives"].items()}
    events = ev_doc["events"]
    valid_tags = set(tags_doc["tags"])
    # Il vocabolario e' chiuso: un doppione e' un errore (di solito un
    # copia-incolla), e maschererebbe il conteggio come guardia.
    if len(tags_doc["tags"]) != len(valid_tags):
        seen = set()
        dups = sorted({t for t in tags_doc["tags"] if t in seen or seen.add(t)})
        err(f"data/tags.json: tag duplicati nel vocabolario chiuso: {dups}")
    valid_damage_tags = set(dmg_doc["damage_tags"])
    valid_momenti = set(time_doc["momenti"])
    valid_fasi_lunari = set(time_doc["fasi_lunari"])
    # US-501: vocabolario chiuso dei luoghi dei rituali di avanzamento.
    _loc_doc = load_json(os.path.join(DATA, "schema", "location_tags.json")) or {}
    valid_location_tags = set(_loc_doc.get("location_tags", []))
    # US-502: matrice di proprieta' - materie prime dei summon, tag vietati.
    _own_doc = load_json(os.path.join(DATA, "schema", "ownership.json")) or {}
    summon_materie = set(_own_doc.get("summon_materie_prime", []))
    tag_vietati_attivi = set(_own_doc.get("tag_vietati_pathway_attivi", []))
    # US-703: vocabolari chiusi della fase 7.
    _trib_doc = load_json(os.path.join(DATA, "schema", "tribulation_effects.json")) or {}
    valid_tribulation_effects = set(_trib_doc.get("effetti", {}))
    _pray_doc = load_json(os.path.join(DATA, "schema", "prayer_effects.json")) or {}
    valid_prayer_effects = set(_pray_doc.get("preghiere", {}))
    for _nome, _vocab, _chiave in (
        ("data/schema/tribulation_effects.json", _trib_doc, "effetti"),
        ("data/schema/prayer_effects.json", _pray_doc, "preghiere"),
    ):
        _v = _vocab.get(_chiave, {})
        if not isinstance(_v, dict) or not _v:
            err(f"{_nome}: '{_chiave}' deve essere un oggetto non vuoto (US-703).")
        elif len(_v) > 6:
            err(f"{_nome}: {len(_v)} voci, atteso <= 6 (vocabolario chiuso, US-703).")
    for _p, _spec in _pray_doc.get("preghiere", {}).items():
        if _spec.get("primitiva") not in prim_params:
            err(f"data/schema/prayer_effects.json [{_p}]: 'primitiva' "
                f"'{_spec.get('primitiva')}' non e' del registro (US-703).")
    # Tag ottenibili nella build attiva: servono a segnalare le sinergie
    # irraggiungibili (richiedono tag che nessun pathway attivo porta).
    obtainable_tags = set()

    # --- pathway ---
    pdir = os.path.join(DATA, "pathways")
    files = sorted(f for f in os.listdir(pdir) if f.endswith(".json"))
    if len(files) != EXPECTED_PATHWAYS:
        err(f"data/pathways/: trovati {len(files)} pathway, attesi {EXPECTED_PATHWAYS}")

    pathway_ids = []
    sequence_ids = []
    ability_refs = []
    potion_refs = []  # (rel, sid, seq_num, potion) delle Sequenze non-stub (US-208)
    total_sequences = 0
    stub_count = 0

    for fname in files:
        path = os.path.join(pdir, fname)
        doc = load_json(path)
        if doc is None:
            continue
        rel = f"data/pathways/{fname}"
        pid = doc.get("id")
        pathway_ids.append(pid)

        if fname != f"{pid}.json":
            err(f"{rel}: il nome file non corrisponde all'id '{pid}'")
        if doc.get("group") not in VALID_GROUPS:
            err(f"{rel}: gruppo non valido '{doc.get('group')}'")
        # US-901: distingue Pathway standard (pozione+recitazione) da quelli
        # non_standard (Boon, data/pathways_non_standard/) - un file qui
        # dev'essere sempre 'standard', l'altra categoria vive altrove.
        if doc.get("categoria") != "standard":
            err(f"{rel}: categoria deve essere 'standard' per un pathway in "
                f"data/pathways/ (trovato: {doc.get('categoria')!r})")
        if not isinstance(doc.get("gameplay_verb"), str) or len(doc.get("gameplay_verb", "")) < 10:
            err(f"{rel}: gameplay_verb mancante o troppo generico")
        for t in doc.get("tags", []):
            if t not in valid_tags:
                err(f"{rel}: tag di pathway sconosciuto '{t}' (aggiungilo a data/tags.json o correggilo)")
            if t in tag_vietati_attivi:
                err(f"{rel}: tag '{t}' vietato nei Pathway attivi (matrice di proprieta', "
                    f"US-502: appartiene a un Pathway differito).")
            obtainable_tags.add(t)

        seqs = doc.get("sequences", [])
        total_sequences += len(seqs)
        if len(seqs) != EXPECTED_SEQUENCES_PER_PATHWAY:
            err(f"{rel}: {len(seqs)} sequenze, attese {EXPECTED_SEQUENCES_PER_PATHWAY}")

        seen_nums = []
        for seq in seqs:
            n = seq.get("sequence")
            seen_nums.append(n)
            sid = seq.get("id")
            sequence_ids.append(sid)

            if sid != f"{pid}_{n}":
                err(f"{rel}: id sequenza '{sid}' non coerente con pathway/numero")
            if seq.get("tier") not in VALID_TIERS:
                err(f"{rel} [{sid}]: tier non valido '{seq.get('tier')}'")
            elif seq["tier"] != expected_tier(n):
                err(f"{rel} [{sid}]: tier '{seq['tier']}' errato, atteso '{expected_tier(n)}'")
            if not seq.get("name"):
                err(f"{rel} [{sid}]: nome sequenza mancante")
            if len(seq.get("concept", "")) < 20:
                err(f"{rel} [{sid}]: concept mancante o troppo vago. "
                    f"Ogni sequenza deve dichiarare COSA FA IL GIOCATORE a quel livello.")

            # Una sequenza "stub" e' un guscio dichiarato: contenuto da scrivere,
            # esente dai controlli di completezza. Senza il flag, una sequenza
            # vuota passava la validazione E bloccava il giocatore per sempre.
            stub = bool(seq.get("stub"))
            if stub:
                stub_count += 1
                if seq.get("acting_actions"):
                    err(f"{rel} [{sid}]: marcata stub ma ha acting_actions: togli il flag o svuotala")
            else:
                if not seq.get("acting_actions"):
                    err(f"{rel} [{sid}]: nessuna acting_action e nessun flag stub: "
                        f"il giocatore non ha un percorso di recitazione a questa Sequenza.")
                if not seq.get("madness_on_force", 0) > 0:
                    err(f"{rel} [{sid}]: madness_on_force deve essere > 0 su una sequenza non-stub: "
                        f"forzare l'avanzamento non puo' essere gratis.")

            # rituale obbligatorio da Sequenza 4 in giu' (avanzamento da 5 in su)
            ritual = seq.get("advancement_ritual")
            if n <= 4 and ritual is None:
                err(f"{rel} [{sid}]: advancement_ritual obbligatorio per Sequenza <= 4")
            if n > 4 and ritual is not None:
                warn(f"{rel} [{sid}]: advancement_ritual presente sopra Sequenza 4 (inatteso ma non fatale)")
            if isinstance(ritual, dict):
                if "moon_phase" in ritual:
                    err(f"{rel} [{sid}]: 'moon_phase' non esiste piu': usa 'momento' e/o "
                        f"'fase_lunare' dal vocabolario di data/schema/time.json")
                mom = ritual.get("momento")
                if mom is not None and mom not in valid_momenti:
                    err(f"{rel} [{sid}]: momento '{mom}' non nel vocabolario ({sorted(valid_momenti)})")
                fase = ritual.get("fase_lunare")
                if fase is not None and fase not in valid_fasi_lunari:
                    err(f"{rel} [{sid}]: fase_lunare '{fase}' non nel vocabolario ({sorted(valid_fasi_lunari)})")
                if not stub and not ritual.get("location_tags"):
                    err(f"{rel} [{sid}]: rituale senza location_tags su una sequenza non-stub: "
                        f"un rituale senza luogo non e' eseguibile.")
                # US-501: i location_tags dichiarati devono stare nel vocabolario
                # chiuso, come i tag di sinergia. Vale anche per i pathway differiti.
                fuori = [t for t in ritual.get("location_tags", []) if t not in valid_location_tags]
                if valid_location_tags and fuori:
                    err(f"{rel} [{sid}]: location_tags {fuori} fuori dal vocabolario di "
                        f"data/schema/location_tags.json")

            for aid in seq.get("abilities", []):
                ability_refs.append((rel, sid, aid))

            # US-208: le pozioni non-stub devono puntare a una formula valida
            pot = seq.get("potion", {})
            if not stub and pot.get("formula_id"):
                potion_refs.append((rel, sid, n, pot))
            # US-901: 'boon' e' riservato ai Pathway non_standard (data/
            # pathways_non_standard/) - qui sarebbe sempre un errore di
            # collocazione, mai una scelta valida.
            if seq.get("boon") is not None:
                err(f"{rel} [{sid}]: 'boon' su un Pathway standard - il campo e' "
                    f"riservato ai Pathway non_standard (US-901).")

            total_prog = 0.0
            for act in seq.get("acting_actions", []):
                aid_act = act.get("id")
                prog = act.get("progresso", 0)
                total_prog += prog
                if not (0 < prog <= 1):
                    err(f"{rel} [{sid}]: acting_action '{aid_act}' con progresso fuori range (0,1]")
                ev = act.get("evento")
                if ev not in events:
                    err(f"{rel} [{sid}]: acting_action '{aid_act}' usa l'evento '{ev}', "
                        f"non nel vocabolario chiuso di data/schema/tracked_events.json. "
                        f"Un evento nuovo e' CODICE: va discusso, non aggiunto di slancio.")
                else:
                    allowed = set(events[ev].get("filtri", []))
                    for f, fv in act.get("filtri", {}).items():
                        if f not in allowed:
                            err(f"{rel} [{sid}]: acting_action '{aid_act}': filtro '{f}' "
                                f"non ammesso per l'evento '{ev}' (ammessi: {sorted(allowed)})")
                        elif f == "tag_danno" and fv not in valid_damage_tags:
                            err(f"{rel} [{sid}]: acting_action '{aid_act}': tag_danno '{fv}' "
                                f"non nel vocabolario di data/schema/damage_tags.json")
                if not act.get("target", 0) > 0:
                    err(f"{rel} [{sid}]: acting_action '{aid_act}' senza target numerico")
            # US-504: la somma dev'essere esattamente 1.0 (tolleranza 0.001).
            # < 1.0 = il giocatore resta bloccato. > 1.0 = un'azione e' saltabile:
            # errore, tranne se la Sequenza lo dichiara voluto in notes con
            # 'acting_surplus_voluto'.
            if seq.get("acting_actions"):
                surplus_voluto = "acting_surplus_voluto" in str(seq.get("notes", ""))
                if total_prog < 0.999:
                    err(f"{rel} [{sid}]: le acting_actions sommano a {total_prog:.2f} < 1.0: "
                        f"il giocatore non puo' completare la recitazione e resta bloccato qui per sempre.")
                elif total_prog > 1.001 and not surplus_voluto:
                    err(f"{rel} [{sid}]: le acting_actions sommano a {total_prog:.2f} > 1.0: "
                        f"un'azione diventa saltabile. Riporta la somma a 1.0, o dichiara "
                        f"'acting_surplus_voluto' in notes se e' una scelta di design.")

        if sorted(seen_nums, reverse=True) != list(range(9, -1, -1)):
            err(f"{rel}: le sequenze non coprono esattamente 9..0 (trovate {sorted(seen_nums, reverse=True)})")

    # I gruppi devono essere completi: il cambio di Pathway (fase 7) e' possibile
    # solo tra vicini dello stesso gruppo, quindi un gruppo a meta' rende quel
    # sistema parzialmente inutilizzabile.
    GROUP_SIZES = {"lord_of_mysteries": 3, "god_almighty": 5, "eternal_darkness": 3,
                   "calamity_of_destruction": 2, "demon_of_knowledge": 2, "key_of_light": 1,
                   "goddess_of_origin": 2, "father_of_devils": 2, "the_anarchy": 2}
    present = Counter()
    for fname in files:
        d = load_json(os.path.join(pdir, fname))
        if d:
            present[d.get("group")] += 1
    for g, n in present.items():
        if g in GROUP_SIZES and n != GROUP_SIZES[g]:
            err(f"gruppo '{g}' incompleto: {n} pathway su {GROUP_SIZES[g]}. "
                f"Il cambio di Pathway funziona solo dentro un gruppo intero.")

    if total_sequences != EXPECTED_PATHWAYS * EXPECTED_SEQUENCES_PER_PATHWAY:
        err(f"totale sequenze {total_sequences}, attese {EXPECTED_PATHWAYS * EXPECTED_SEQUENCES_PER_PATHWAY}")
    if stub_count:
        warn(f"{stub_count} sequenze su {total_sequences} sono stub dichiarati: "
             f"contenuto ancora da scrivere (fase 5), non un errore.")

    # US-904: gli id delle Sequenze dei Pathway non_standard entrano anche
    # loro in sequence_ids - servono alla validazione delle abilita' (sotto,
    # sequence_id deve risolvere sia su uno standard che su un non_standard)
    # e al controllo duplicati subito dopo. La validazione PIENA di questi
    # file (categoria, group, boon...) resta nel blocco dedicato piu' in
    # basso, dove quest_ids/item_ids/char_ids sono gia' disponibili: qui e'
    # solo una raccolta di id, una seconda lettura dei file e' il prezzo di
    # non riordinare tutto il resto dello script.
    pnsdir_early = os.path.join(DATA, "pathways_non_standard")
    if os.path.isdir(pnsdir_early):
        for fn in sorted(f for f in os.listdir(pnsdir_early) if f.endswith(".json")):
            _doc_early = load_json(os.path.join(pnsdir_early, fn))
            if _doc_early is None:
                continue
            for _seq_early in _doc_early.get("sequences", []):
                _sid_early = _seq_early.get("id")
                if _sid_early:
                    sequence_ids.append(_sid_early)

    for name, values in (("pathway", pathway_ids), ("sequenza", sequence_ids)):
        dupes = [k for k, v in Counter(values).items() if v > 1]
        if dupes:
            err(f"id {name} duplicati: {dupes}")

    # --- categoria dei Pathway differiti (data/pathways_deferred/, US-901) ---
    # Non sono caricati da GameData e restano fuori dalla validazione piena
    # dei Pathway attivi (vedi sopra): qui solo il campo 'categoria' aggiunto
    # in fase 9, per coerenza col resto del vocabolario (sono tutti standard,
    # nessun Pathway differito e' non_standard).
    pddir = os.path.join(DATA, "pathways_deferred")
    if os.path.isdir(pddir):
        for fn in sorted(f for f in os.listdir(pddir) if f.endswith(".json")):
            _d = load_json(os.path.join(pddir, fn))
            if _d is None:
                continue
            if _d.get("categoria") != "standard":
                err(f"data/pathways_deferred/{fn}: categoria deve essere 'standard' "
                    f"(trovato: {_d.get('categoria')!r})")

    # --- percorsi di fusione (data/fusions/, fase 7 US-702) ---
    # Il cambio di Pathway funziona solo tra vicini dello STESSO gruppo. I
    # percorsi possibili sono uno per coppia non ordinata dentro un gruppo
    # attivo: FusionEngine li legge, il codice non conosce le coppie.
    pathway_group = {}
    for _fn in files:
        _d = load_json(os.path.join(pdir, _fn)) or {}
        if _d.get("id"):
            pathway_group[_d["id"]] = _d.get("group")
    # gruppi attivi (tutti i loro Pathway sono in data/pathways/)
    _active_groups = {g for g, n in present.items()
                      if g in GROUP_SIZES and n == GROUP_SIZES[g]}
    expected_fusions = set()
    for g in sorted(_active_groups):
        _members = sorted(p for p, gg in pathway_group.items() if gg == g)
        for i in range(len(_members)):
            for j in range(i + 1, len(_members)):
                expected_fusions.add(f"{_members[i]}_{_members[j]}")
    fdir = os.path.join(DATA, "fusions")
    fusion_stub = 0
    seen_fusions = set()
    if not os.path.isdir(fdir):
        err("data/fusions/: cartella mancante (fase 7, US-702).")
    else:
        for fn in sorted(f for f in os.listdir(fdir) if f.endswith(".json")):
            doc = load_json(os.path.join(fdir, fn))
            if doc is None:
                continue
            rel = f"data/fusions/{fn}"
            fid = doc.get("id")
            seen_fusions.add(fid)
            if fn != f"{fid}.json":
                err(f"{rel}: nome file diverso dall'id '{fid}'")
            a, b = doc.get("pathway_a"), doc.get("pathway_b")
            if a not in pathway_group or b not in pathway_group:
                err(f"{rel}: pathway_a/pathway_b '{a}'/'{b}' non sono Pathway attivi")
            elif pathway_group[a] != pathway_group[b]:
                err(f"{rel}: '{a}' e '{b}' non sono dello stesso gruppo "
                    f"({pathway_group[a]} / {pathway_group[b]}): non sono vicini fondibili")
            elif doc.get("gruppo") != pathway_group[a]:
                err(f"{rel}: campo 'gruppo' '{doc.get('gruppo')}' incoerente col gruppo dei Pathway ({pathway_group[a]})")
            elif fid != f"{min(a, b)}_{max(a, b)}":
                err(f"{rel}: id '{fid}' non e' '<pathA>_<pathB>' alfabetico ('{min(a, b)}_{max(a, b)}')")
            is_stub = bool(doc.get("stub"))
            fuse = doc.get("abilita_fuse", [])
            if is_stub:
                fusion_stub += 1
                if fuse:
                    err(f"{rel}: marcato stub ma ha abilita_fuse: svuotalo o togli il flag")
            elif not fuse:
                err(f"{rel}: non stub ma senza abilita_fuse")
            for ab in fuse:
                aid = ab.get("id")
                dseq = ab.get("da_sequenza")
                if not isinstance(dseq, int) or not (7 <= dseq <= 9):
                    err(f"{rel} [{aid}]: da_sequenza '{dseq}' fuori da 7..9 (le Sequenze conservate)")
                if not str(ab.get("name_i18n", "")).startswith("ability.fusion."):
                    err(f"{rel} [{aid}]: name_i18n senza prefisso 'ability.fusion.'")
                for p in ab.get("primitive", []):
                    tipo = p.get("tipo")
                    if tipo in deferred_primitives:
                        err(f"{rel} [{aid}]: primitiva '{tipo}' e' DIFFERITA")
                    elif tipo not in primitives:
                        err(f"{rel} [{aid}]: primitiva sconosciuta '{tipo}'")
                    else:
                        ignoti = set(p) - {"tipo"} - prim_params[tipo]
                        if ignoti:
                            err(f"{rel} [{aid}]: parametri non dichiarati per '{tipo}': {sorted(ignoti)}")
                    td = p.get("tag_danno")
                    if td is not None and td not in valid_damage_tags:
                        err(f"{rel} [{aid}]: tag_danno '{td}' non nel vocabolario")
                for t in ab.get("tag_sinergia", []):
                    if t not in valid_tags:
                        err(f"{rel} [{aid}]: tag_sinergia sconosciuto '{t}'")
                    obtainable_tags.add(t)
        _mancanti = sorted(expected_fusions - seen_fusions)
        if _mancanti:
            err(f"data/fusions/: mancano i percorsi di fusione {_mancanti} "
                f"(uno per coppia di Pathway vicini in un gruppo attivo).")
        _extra = sorted(seen_fusions - expected_fusions)
        if _extra:
            err(f"data/fusions/: percorsi di fusione non attesi {_extra} "
                f"(le coppie devono essere dentro un gruppo attivo).")
        if fusion_stub:
            warn(f"{fusion_stub} percorsi di fusione su {len(expected_fusions)} sono stub "
                 f"dichiarati (fase 7b): contenuto da scrivere, non un errore.")

    # --- tribolazioni (data/tribulations/, fase 7 US-710) ---
    # Una prova per salto di fascia (7->6, 5->4, 3->2, 1->0). Lettore di
    # eventi + flag: 'superamento' e' uno dei 12 tracked_events o un flag,
    # 'condizioni' il vocabolario chiuso di conditions.gd, 'mentre_in_corso'
    # una voce di tribulation_effects.json. Una sola tribolazione per salto.
    TRIB_COND = {"e_notte", "fase_lunare", "in_zona_tag", "foundation_min",
                 "tier_min", "madness_min", "follia_min", "madness_max",
                 "acting_progress_min", "reputazione_min", "flag"}
    twelve_events = set(ev_doc.get("events", {}))
    tdir = os.path.join(DATA, "tribulations")
    salti_attesi = {7: 6, 5: 4, 3: 2, 1: 0}
    salti_visti = {}
    trib_flags = []   # (rel, tid, flag) da riconciliare coi flag scritti (US-712)
    if not os.path.isdir(tdir):
        err("data/tribulations/: cartella mancante (fase 7, US-710).")
    else:
        for fn in sorted(os.listdir(tdir)):
            if not fn.endswith(".json"):
                continue
            rel = f"data/tribulations/{fn}"
            doc = load_json(os.path.join(tdir, fn))
            if doc is None:
                err(f"{rel}: JSON illeggibile")
                continue
            tid = doc.get("id")
            salto = doc.get("salto", {})
            da, a = salto.get("da"), salto.get("a")
            if da not in salti_attesi or salti_attesi[da] != a:
                err(f"{rel}: salto {da}->{a} non e' un salto di fascia valido "
                    f"(attesi {salti_attesi})")
            else:
                salti_visti.setdefault(da, []).append(tid)
            for c in doc.get("condizioni", []):
                ct = c.get("tipo") if isinstance(c, dict) else None
                if ct not in TRIB_COND:
                    err(f"{rel} [{tid}]: condizione di tipo sconosciuto '{ct}' "
                        f"(vocabolario di conditions.gd: {sorted(TRIB_COND)})")
            mic = doc.get("mentre_in_corso")
            if mic not in valid_tribulation_effects:
                err(f"{rel} [{tid}]: mentre_in_corso '{mic}' non e' in "
                    f"data/schema/tribulation_effects.json")
            sup = doc.get("superamento", {})
            has_ev, has_flag = "evento" in sup, "flag" in sup
            if has_ev == has_flag:
                err(f"{rel} [{tid}]: 'superamento' deve avere O 'evento' O 'flag', non entrambi/nessuno")
            if has_ev and sup.get("evento") not in twelve_events:
                err(f"{rel} [{tid}]: superamento.evento '{sup.get('evento')}' non e' uno dei 12 eventi tracciati")
            if has_ev and not (isinstance(sup.get("target"), (int, float)) and sup.get("target") >= 1):
                err(f"{rel} [{tid}]: superamento con 'evento' ha bisogno di 'target' >= 1")
            if has_flag and not (isinstance(sup.get("flag"), str) and sup.get("flag")):
                err(f"{rel} [{tid}]: superamento.flag vuoto")
            elif has_flag:
                trib_flags.append((rel, tid, sup.get("flag")))
        for da in salti_attesi:
            n = len(salti_visti.get(da, []))
            if n == 0:
                err(f"data/tribulations/: manca la tribolazione del salto {da}->{salti_attesi[da]}")
            elif n > 1:
                err(f"data/tribulations/: {n} tribolazioni per il salto {da}->{salti_attesi[da]} "
                    f"({salti_visti[da]}): ne serve UNA sola")

    # --- finali (data/endings.json, fase 7 US-716) ---
    # 3 voci esatte (FR-9), condizioni dal vocabolario di conditions.gd (nessun
    # tipo nuovo), eredita_profilo nell'enum, epiloghi_per_gruppo copre i 4
    # gruppi di Pathway attivi. 'rituale_sequenza_0_completato' e' posto dal
    # CODICE (EndingSystem ascolta RitualSystem, non un dialogo/quest): unico
    # flag esente dalla riconciliazione con flag_scritti qui sotto.
    ENDING_COND = TRIB_COND
    ENDING_IDS = {"apoteosi", "consumazione", "rinuncia"}
    EREDITA_PROFILI = {"completo", "ancore", "solo_conoscenza"}
    GRUPPI_ATTIVI = {"eternal_darkness_i18n", "goddess_of_origin_i18n",
                      "demon_of_knowledge_i18n", "lord_of_mysteries_i18n"}
    FLAG_ENDING_ESENTI = {"rituale_sequenza_0_completato"}
    ending_flags = []   # (rel, eid, flag) da riconciliare coi flag scritti (come trib_flags)
    end_doc = load_json(os.path.join(DATA, "endings.json"))
    if end_doc is None:
        err("data/endings.json: mancante o illeggibile (fase 7, US-716).")
    else:
        endings = end_doc.get("endings", [])
        seen_ids = set()
        for e in endings:
            eid = e.get("id")
            rel = "data/endings.json"
            if eid in seen_ids:
                err(f"{rel}: id finale duplicato '{eid}'")
            seen_ids.add(eid)
            for c in e.get("condizioni", []):
                ct = c.get("tipo") if isinstance(c, dict) else None
                if ct not in ENDING_COND:
                    err(f"{rel} [{eid}]: condizione di tipo sconosciuto '{ct}' "
                        f"(vocabolario di conditions.gd: {sorted(ENDING_COND)})")
                if ct == "flag":
                    flag = c.get("valore")
                    if not isinstance(flag, str) or not flag:
                        err(f"{rel} [{eid}]: condizione 'flag' senza 'valore' valido")
                    elif flag not in FLAG_ENDING_ESENTI:
                        ending_flags.append((rel, eid, flag))
            if e.get("eredita_profilo") not in EREDITA_PROFILI:
                err(f"{rel} [{eid}]: eredita_profilo '{e.get('eredita_profilo')}' "
                    f"non nell'enum {sorted(EREDITA_PROFILI)}")
            epg = e.get("epiloghi_per_gruppo", {})
            mancanti = GRUPPI_ATTIVI - set(epg)
            extra = set(epg) - GRUPPI_ATTIVI
            if mancanti:
                err(f"{rel} [{eid}]: epiloghi_per_gruppo manca {sorted(mancanti)}")
            if extra:
                err(f"{rel} [{eid}]: epiloghi_per_gruppo ha gruppi ignoti {sorted(extra)}")
        if seen_ids != ENDING_IDS:
            err(f"data/endings.json: attesi esattamente i finali {sorted(ENDING_IDS)}, "
                f"trovati {sorted(seen_ids)} (FR-9)")

    # --- abilita' ---
    adir = os.path.join(DATA, "abilities")
    ability_ids = set()
    transform_forms = []  # (rel, aid, forma_id) da verificare contro data/forms.json
    status_refs = []      # (rel, aid, effetto) di aura/curse -> data/status_effects.json
    if os.path.isdir(adir):
        for fname in sorted(os.listdir(adir)):
            if not fname.endswith(".json"):
                continue
            doc = load_json(os.path.join(adir, fname))
            if doc is None:
                continue
            rel = f"data/abilities/{fname}"
            for ab in (doc if isinstance(doc, list) else doc.get("abilities", [])):
                aid = ab.get("id")
                if aid in ability_ids:
                    err(f"{rel}: id abilita' duplicato '{aid}'")
                ability_ids.add(aid)
                if ab.get("sequence_id") not in set(sequence_ids):
                    err(f"{rel} [{aid}]: sequence_id '{ab.get('sequence_id')}' inesistente")
                for p in ab.get("primitive", []):
                    tipo = p.get("tipo")
                    if tipo in deferred_primitives:
                        err(f"{rel} [{aid}]: primitiva '{tipo}' e' DIFFERITA (nessun Pathway attivo "
                            f"la richiede). Non implementarla: e' codice che nessuno usa.")
                    elif tipo not in primitives:
                        err(f"{rel} [{aid}]: primitiva sconosciuta '{tipo}'. "
                            f"Il registro e' chiuso: parametrizza una primitiva esistente.")
                    else:
                        # Un parametro fuori registro a runtime diventa il default
                        # della primitiva: danno silenziosamente a zero.
                        ignoti = set(p) - {"tipo"} - prim_params[tipo]
                        if ignoti:
                            err(f"{rel} [{aid}]: parametri non dichiarati per '{tipo}': "
                                f"{sorted(ignoti)} (registro: {sorted(prim_params[tipo])})")
                    if tipo == "transform" and p.get("forma_id"):
                        transform_forms.append((rel, aid, p.get("forma_id")))
                    if tipo == "terrain_modify":
                        if not isinstance(p.get("tipo_modifica"), str) or not p.get("tipo_modifica"):
                            err(f"{rel} [{aid}]: terrain_modify senza tipo_modifica")
                        if not isinstance(p.get("permanente"), bool):
                            err(f"{rel} [{aid}]: terrain_modify.permanente deve essere true/false "
                                f"(permanente decide se la modifica va nel save)")
                    if tipo in ("aura", "curse") and p.get("effetto"):
                        status_refs.append((rel, aid, p.get("effetto")))
                    if tipo == "summon":
                        eid = p.get("entita_id")
                        if not isinstance(eid, str) or not eid:
                            err(f"{rel} [{aid}]: summon senza entita_id (la fonte dell'evocazione)")
                        # US-502: entita_id dichiara la materia prima nel prefisso
                        # (matrice di proprieta', data/schema/ownership.json).
                        elif summon_materie and not any(eid.startswith(m + "_") for m in summon_materie):
                            err(f"{rel} [{aid}]: summon.entita_id '{eid}' senza prefisso di materia "
                                f"prima ({sorted(summon_materie)}): ogni evocazione dichiara da cosa "
                                f"nasce (matrice di proprieta', US-502).")
                        dur = p.get("durata")
                        if dur == 0 or dur is None:
                            err(f"{rel} [{aid}]: summon.durata deve essere -1 (persistente) o > 0 "
                                f"(temporanea), mai 0")
                    # US-502: la divinazione fuori da Hermit rivela solo la categoria.
                    if tipo in ("reveal_info", "mind_read") \
                            and not str(ab.get("sequence_id", "")).startswith("hermit_") \
                            and not p.get("categoria"):
                        err(f"{rel} [{aid}]: {tipo} fuori da Hermit senza 'categoria': "
                            f"solo Hermit e' il divinatore sistemico, gli altri rivelano una "
                            f"categoria (matrice di proprieta', US-502).")
                    td = p.get("tag_danno")
                    if td is not None and td not in valid_damage_tags:
                        err(f"{rel} [{aid}]: tag_danno '{td}' non nel vocabolario "
                            f"di data/schema/damage_tags.json")
                    for tb in p.get("tag_bloccati", []):
                        if tb not in valid_damage_tags:
                            err(f"{rel} [{aid}]: tag_bloccati contiene '{tb}', non nel "
                                f"vocabolario di data/schema/damage_tags.json")
                # US-605: le condizioni delle abilita' - un solo vocabolario in
                # tutto il gioco (FR-3). follia_min/reputazione_min/flag sono
                # nell'enum condiviso ma servono ai DIALOGHI (US-613): nessuna
                # abilita' li usa.
                ABILITY_COND = {"acting_progress_min", "madness_max", "madness_min",
                                "e_notte", "fase_lunare", "foundation_min", "tier_min",
                                "in_zona_tag"}
                SOLO_DIALOGO = {"follia_min", "reputazione_min", "flag"}
                for cnd in ab.get("condizioni", []):
                    ct = cnd.get("tipo") if isinstance(cnd, dict) else None
                    if ct in SOLO_DIALOGO:
                        err(f"{rel} [{aid}]: condizione '{ct}' e' riservata ai dialoghi "
                            f"(US-613), un'abilita' non la usa.")
                    elif ct not in ABILITY_COND:
                        err(f"{rel} [{aid}]: condizione di tipo sconosciuto '{ct}' "
                            f"(ammessi: {sorted(ABILITY_COND)})")
                    elif "valore" not in cnd:
                        err(f"{rel} [{aid}]: condizione '{ct}' senza 'valore'")

                for t in ab.get("tag_sinergia", []):
                    if t in tag_vietati_attivi:
                        err(f"{rel} [{aid}]: tag_sinergia '{t}' vietato nei Pathway attivi "
                            f"(matrice di proprieta', US-502).")
                    if t not in valid_tags:
                        err(f"{rel} [{aid}]: tag sconosciuto '{t}'")
                    obtainable_tags.add(t)
                if not ab.get("tag_sinergia"):
                    err(f"{rel} [{aid}]: nessun tag_sinergia. Un'abilita' senza tag e' invisibile al motore delle sinergie.")

                # US-714: preghiera (Sequenze alte) - puramente semantica/i18n,
                # ma deve essere nel vocabolario e coerente con le primitive
                # dell'abilita' (data/schema/prayer_effects.json).
                pray = ab.get("preghiera")
                if pray is not None:
                    if pray not in valid_prayer_effects:
                        err(f"{rel} [{aid}]: preghiera '{pray}' non nel vocabolario di "
                            f"data/schema/prayer_effects.json")
                    else:
                        spec = _pray_doc["preghiere"][pray]
                        prim_richiesta = spec.get("primitiva")
                        prims_ab = ab.get("primitive", [])
                        if prim_richiesta and not any(p.get("tipo") == prim_richiesta for p in prims_ab):
                            err(f"{rel} [{aid}]: preghiera '{pray}' richiede una primitiva "
                                f"'{prim_richiesta}', assente dall'abilita'")
                        bersagli_richiesti = spec.get("richiede", {}).get("bersagli")
                        if bersagli_richiesti and not any(
                                p.get("tipo") == prim_richiesta and p.get("bersagli") == bersagli_richiesti
                                for p in prims_ab):
                            err(f"{rel} [{aid}]: preghiera '{pray}' richiede '{prim_richiesta}' "
                                f"con bersagli '{bersagli_richiesti}'")

    for rel, sid, aid in ability_refs:
        if ability_ids and aid not in ability_ids:
            err(f"{rel} [{sid}]: riferimento ad abilita' inesistente '{aid}'")

    # --- forme (data/forms.json, primitiva transform, US-203B) ---
    # Le forme sono dati: transform legge forma_id da qui, il motore non sa
    # nulla di quali forme esistano.
    forms_doc = load_json(os.path.join(DATA, "forms.json"))
    forms = (forms_doc or {}).get("forms", {})
    known_stats = {"hp_max", "spiritualita_max", "velocita", "difesa", "evasione", "precisione", "forza"}
    for fid, f in forms.items():
        if not isinstance(f.get("name_i18n"), str) or not f["name_i18n"]:
            err(f"data/forms.json [{fid}]: name_i18n mancante o vuoto")
        sm = f.get("stat_modifiers")
        if not isinstance(sm, dict) or not sm:
            err(f"data/forms.json [{fid}]: stat_modifiers deve essere un oggetto non vuoto")
        else:
            for k, v in sm.items():
                if k not in known_stats:
                    err(f"data/forms.json [{fid}]: stat_modifiers ha una stat ignota '{k}'")
                if not isinstance(v, (int, float)):
                    err(f"data/forms.json [{fid}]: stat_modifiers['{k}'] non e' un numero")
            if all((v if isinstance(v, (int, float)) else 0) >= 0 for v in sm.values()):
                err(f"data/forms.json [{fid}]: nessun trade-off negativo. Una forma non e' solo vantaggi.")
    for rel, aid, fid in transform_forms:
        if fid not in forms:
            err(f"{rel} [{aid}]: transform punta a forma_id '{fid}' inesistente in data/forms.json")

    # --- status effects (data/status_effects.json, US-218C) ---
    st_doc = load_json(os.path.join(DATA, "status_effects.json"))
    statuses = (st_doc or {}).get("statuses", {})
    known_stats_st = {"hp_max", "spiritualita_max", "velocita", "difesa", "evasione", "precisione", "forza"}
    for sid, st in statuses.items():
        if st.get("tag") not in valid_tags:
            err(f"data/status_effects.json [{sid}]: tag '{st.get('tag')}' non nel vocabolario dei tag")
        dd = st.get("durata_default")
        if not isinstance(dd, (int, float)) or (dd <= 0 and dd != -1):
            err(f"data/status_effects.json [{sid}]: durata_default deve essere > 0 o -1")
        for k in (st.get("stat_modifiers") or {}):
            if k not in known_stats_st:
                err(f"data/status_effects.json [{sid}]: stat_modifiers ha una stat ignota '{k}'")
    for rel, aid, eff in status_refs:
        if eff not in statuses:
            err(f"{rel} [{aid}]: aura/curse punta a effetto '{eff}' inesistente in data/status_effects.json")

    # --- ancore (data/anchors.json, US-216) ---
    anch_doc = load_json(os.path.join(DATA, "anchors.json"))
    anchors = (anch_doc or {}).get("anchors", [])
    anchor_ids = set()
    for a in anchors:
        aid = a.get("id")
        if aid in anchor_ids:
            err(f"data/anchors.json: id duplicato '{aid}'")
        anchor_ids.add(aid)
        if not isinstance(a.get("name_i18n"), str) or not a.get("name_i18n"):
            err(f"data/anchors.json [{aid}]: name_i18n mancante o vuoto")
        if not isinstance(a.get("forza"), (int, float)) or a.get("forza", 0) <= 0:
            err(f"data/anchors.json [{aid}]: forza deve essere > 0")
        if not isinstance(a.get("penalita"), (int, float)) or a.get("penalita", 0) <= 0:
            err(f"data/anchors.json [{aid}]: penalita deve essere > 0 (perdere un'Ancora e' un colpo)")
    # il rituale di Seq 1 sacrifica 'ancora_del_giocatore': serve almeno un'Ancora
    if anchors == [] or not anchor_ids:
        err("data/anchors.json: nessuna Ancora. Il rituale di Sequenza 1 del "
            "Twilight Giant sacrifica 'ancora_del_giocatore': deve poter esistere.")

    # --- caratteristiche Beyonder (data/characteristics.json, US-207) ---
    ch_doc = load_json(os.path.join(DATA, "characteristics.json"))
    chars = (ch_doc or {}).get("characteristics", [])
    char_ids = set()
    char_by_ps = set()  # (pathway_id, sequence)
    for c in chars:
        cid = c.get("id")
        if cid in char_ids:
            err(f"data/characteristics.json: id duplicato '{cid}'")
        char_ids.add(cid)
        if c.get("pathway_id") not in pathway_ids:
            err(f"data/characteristics.json [{cid}]: pathway_id '{c.get('pathway_id')}' non e' un Pathway attivo")
        sq = c.get("sequence")
        if not isinstance(sq, int) or not (0 <= sq <= 9):
            err(f"data/characteristics.json [{cid}]: sequence '{sq}' fuori da [0, 9]")
        if not isinstance(c.get("name_i18n"), str) or not c.get("name_i18n"):
            err(f"data/characteristics.json [{cid}]: name_i18n mancante o vuoto")
        char_by_ps.add((c.get("pathway_id"), sq))
    # il nemico da banco deve poter lasciare una Caratteristica che esiste
    _bal = load_json(os.path.join(DATA, "balance.json"))
    if _bal:
        nc = _bal.get("nemico_base", {}).get("caratteristica")
        if isinstance(nc, dict):
            if (nc.get("pathway_id"), nc.get("sequence")) not in char_by_ps:
                err(f"data/balance.json [nemico_base.caratteristica]: nessuna Caratteristica "
                    f"per ({nc.get('pathway_id')}, Seq {nc.get('sequence')}) in data/characteristics.json")
    # ogni Sequenza non-stub di OGNI Pathway attivo deve avere la sua
    # Caratteristica (US-505: generalizzato da twilight_giant a tutti).
    for _fname in files:
        _pw = load_json(os.path.join(pdir, _fname))
        if not _pw:
            continue
        _pid = _pw.get("id")
        for s in _pw.get("sequences", []):
            if s.get("stub"):
                continue
            cs = s.get("potion", {}).get("characteristic_sequence")
            if cs is not None and (_pid, cs) not in char_by_ps:
                err(f"data/pathways/{_fname} [{s.get('id')}]: manca la Caratteristica "
                    f"per characteristic_sequence {cs} in data/characteristics.json")

    # --- formule delle pozioni (data/potions/formulas.json, US-208) ---
    fdoc = load_json(os.path.join(DATA, "potions", "formulas.json"))
    formulas = (fdoc or {}).get("formulas", {})
    ingredient_vocab = set((fdoc or {}).get("ingredients", []))
    for fid, f in formulas.items():
        ingr = f.get("ingredients", [])
        if not isinstance(ingr, list) or not ingr:
            err(f"data/potions/formulas.json [{fid}]: ingredients deve essere una lista non vuota")
            ingr = []
        for ing in ingr:
            if ing not in ingredient_vocab:
                err(f"data/potions/formulas.json [{fid}]: ingrediente '{ing}' non nel vocabolario 'ingredients'")
        sp = f.get("soglia_parziale")
        if not isinstance(sp, int) or not (1 <= sp <= max(1, len(ingr))):
            err(f"data/potions/formulas.json [{fid}]: soglia_parziale '{sp}' fuori da [1, {len(ingr)}]")
        if not isinstance(f.get("penalita_parziale"), dict) or not f.get("penalita_parziale"):
            err(f"data/potions/formulas.json [{fid}]: penalita_parziale mancante (una pozione parziale non e' gratis)")
    for rel, sid, n, pot in potion_refs:
        fid = pot.get("formula_id")
        if fid not in formulas:
            err(f"{rel} [{sid}]: potion.formula_id '{fid}' non risolve in data/potions/formulas.json")
            continue
        f = formulas[fid]
        if f.get("characteristic_sequence") != n:
            err(f"{rel} [{sid}]: la formula '{fid}' chiede characteristic_sequence "
                f"{f.get('characteristic_sequence')}, ma la Sequenza e' {n}")
        if pot.get("ingredients") and pot["ingredients"] != f.get("ingredients"):
            err(f"{rel} [{sid}]: gli ingredienti inline della pozione non combaciano con quelli "
                f"della formula '{fid}' (la formula e' la fonte)")

    # --- progressione (US-201) ---
    # Il Pathway di partenza vive nei dati, non nel codice (FR-1): qui si
    # verifica che punti a un Pathway attivo e che la Sequenza sia valida.
    balance_doc = load_json(os.path.join(DATA, "balance.json"))
    if balance_doc:
        prog = balance_doc.get("progressione", {})
        pd = prog.get("pathway_default")
        if pd not in pathway_ids:
            err(f"data/balance.json [progressione.pathway_default]: '{pd}' non e' "
                f"un Pathway attivo ({sorted(p for p in pathway_ids if p)}).")
        si = prog.get("sequenza_iniziale")
        if not isinstance(si, int) or not (0 <= si <= 9):
            err(f"data/balance.json [progressione.sequenza_iniziale]: '{si}' fuori "
                f"dall'intervallo 0-9.")

        # US-604: il ciclo del tempo (TimeSystem) legge la sezione "tempo".
        tempo = balance_doc.get("tempo", {})
        for k in ("secondi_per_momento", "durata_eclissi_s"):
            v = tempo.get(k)
            if not isinstance(v, (int, float)) or v <= 0:
                err(f"data/balance.json [tempo.{k}]: deve essere un numero > 0 "
                    f"(il ciclo giorno/notte di US-604 lo usa).")
        for k in ("momenti_per_giorno", "giorni_per_fase_lunare", "cicli_lunari_per_eclissi"):
            v = tempo.get(k)
            if not isinstance(v, int) or v < 1:
                err(f"data/balance.json [tempo.{k}]: deve essere un intero >= 1.")

        # US-618: la densita' mistica (recupero spiritualita', forzatura, spawn).
        dm = balance_doc.get("densita_mistica", {})
        for k in ("recupero_spiritualita_al_sec", "molt_recupero_per_densita",
                  "efficacia_forzatura_per_densita", "spawn_base_al_min", "spawn_per_densita"):
            v = dm.get(k)
            if not isinstance(v, (int, float)) or v < 0:
                err(f"data/balance.json [densita_mistica.{k}]: deve essere un numero >= 0 (US-618).")
        db = dm.get("densita_baseline")
        if not isinstance(db, (int, float)) or not (0.0 <= db <= 1.0):
            err("data/balance.json [densita_mistica.densita_baseline]: numero 0..1.")
        sp = dm.get("sequenza_percezione")
        if not isinstance(sp, int) or not (0 <= sp <= 9):
            err("data/balance.json [densita_mistica.sequenza_percezione]: intero 0-9.")

    # --- animazioni ---
    anim_doc = load_json(os.path.join(DATA, "animations.json"))
    if anim_doc:
        for cat in ("personaggio", "nemico_base", "pet"):
            for name, an in anim_doc.get(cat, {}).items():
                if name.startswith("_"):
                    continue
                n = an.get("frames", 0)
                if n <= 0:
                    err(f"data/animations.json [{cat}.{name}]: frames deve essere > 0")
                    continue
                # ogni indice di frame citato deve esistere davvero
                for key in ("anticipo", "attivi", "recupero", "finestra_perfetta"):
                    for idx in an.get(key, []):
                        if not 0 <= idx < n:
                            err(f"data/animations.json [{cat}.{name}]: {key} cita il frame {idx} "
                                f"ma l'animazione ne ha {n}")
                for ev in an.get("eventi", []):
                    if not 0 <= ev.get("frame", -1) < n:
                        err(f"data/animations.json [{cat}.{name}]: evento '{ev.get('evento')}' "
                            f"sul frame {ev.get('frame')} inesistente")
                # una hitbox aperta deve chiudersi, o resta attiva per sempre
                evs = [e.get("evento") for e in an.get("eventi", [])]
                if evs.count("hitbox_on") != evs.count("hitbox_off"):
                    err(f"data/animations.json [{cat}.{name}]: hitbox_on e hitbox_off non sono "
                        f"in pari. Una hitbox che non si chiude resta attiva per sempre.")
                if an.get("attivi") and not an.get("anticipo") and not an.get("anticipo_in_stato"):
                    warn(f"data/animations.json [{cat}.{name}]: ha frame attivi ma nessun anticipo. "
                         f"Un attacco senza anticipo non e' leggibile dal giocatore. "
                         f"Se il tell e' in uno stato separato, dichiaralo con anticipo_in_stato.")
                if an.get("anticipo_in_stato") and an["anticipo_in_stato"] not in anim_doc.get(cat, {}):
                    err(f"data/animations.json [{cat}.{name}]: anticipo_in_stato punta a "
                        f"'{an['anticipo_in_stato']}', che non esiste in {cat}.")

    # --- audio ---
    audio = load_json(os.path.join(DATA, "audio.json"))
    if audio:
        # ogni pathway attivo deve avere una palette timbrica: senza, le sue
        # abilita' non hanno un suono e il Pathway e' muto in gioco
        palette = audio.get("pathway_palette", {})
        for pid in pathway_ids:
            if pid and pid not in palette:
                err(f"data/audio.json: manca la pathway_palette per '{pid}'. "
                    f"Senza palette le abilita' di quel Pathway non hanno timbro.")
        # ogni categoria di tell deve avere un anticipo positivo, altrimenti
        # il suono arriva insieme al colpo e non serve a niente
        telegraph_ids = set()
        for tid, t in audio.get("telegraph", {}).items():
            if tid.startswith("_"):
                continue
            telegraph_ids.add(tid)
            if not t.get("anticipo_ms", 0) > 0:
                err(f"data/audio.json [telegraph.{tid}]: anticipo_ms deve essere > 0, "
                    f"altrimenti il tell suona insieme all'impatto ed e' inutile.")
        # chi usa un tell deve puntare a un id che esiste: il nemico base ne
        # ricava anche la durata reale della fase di anticipo (US-020)
        balance = load_json(os.path.join(DATA, "balance.json"))
        if balance:
            nb_tell = balance.get("nemico_base", {}).get("telegraph")
            if nb_tell is not None and nb_tell not in telegraph_ids:
                err(f"data/balance.json [nemico_base.telegraph]: '{nb_tell}' non e' "
                    f"un id di data/audio.json.telegraph ({sorted(telegraph_ids)}).")
        # le soglie di follia devono essere ordinate e coerenti con balance.json
        soglie = [x.get("madness_min", -1) for x in audio.get("madness_layer", {}).get("soglie", [])]
        if soglie != sorted(soglie):
            err("data/audio.json [madness_layer]: le soglie non sono in ordine crescente.")

        # US-619: struttura a layer + ambienti giorno/notte.
        mus = audio.get("music", {})
        layer = mus.get("layer", {})
        if layer.get("sempre_attivo") != "base":
            err("data/audio.json [music.layer.sempre_attivo]: deve essere 'base' (stem sempre attivo).")
        if not layer.get("in_crossfade"):
            err("data/audio.json [music.layer.in_crossfade]: elenco degli stem in crossfade vuoto.")
        stati = set(mus.get("stati", []))
        sps = layer.get("stato_per_stem", {})
        if stati and set(sps) != stati:
            err(f"data/audio.json [music.layer.stato_per_stem]: le chiavi {sorted(sps)} non "
                f"coincidono con music.stati {sorted(stati)}.")
        stem_validi = set(layer.get("in_crossfade", [])) | {"base"}
        for st, elenco in sps.items():
            for s in elenco:
                if s not in stem_validi:
                    err(f"data/audio.json [music.layer.stato_per_stem.{st}]: stem '{s}' non "
                        f"e' in in_crossfade ({sorted(stem_validi)}).")
        amb = mus.get("ambienti", {})
        for zid, z in mus.get("zone", {}).items():
            if zid.startswith("_"):
                continue
            if not isinstance(z, dict):
                continue
            if "riverbero" in z and not (0.0 <= float(z["riverbero"]) <= 1.0):
                err(f"data/audio.json [music.zone.{zid}.riverbero]: fuori da 0..1.")
        for zid, a in amb.items():
            if zid.startswith("_"):
                continue
            if not isinstance(a, dict) or "giorno" not in a or "notte" not in a:
                err(f"data/audio.json [music.ambienti.{zid}]: servono 'giorno' e 'notte'.")

    # --- regioni (data/world/regions.json, US-601) ---
    # Le regioni sono DATI: gating, audio, NPC, spawn leggono questo vocabolario
    # chiuso. Un 'if' per una regione specifica e' un bug: si riformula sui dati.
    gt_doc = load_json(os.path.join(DATA, "schema", "gate_types.json")) or {}
    valid_gate_types = set(gt_doc.get("gate_types", []))
    if len(valid_gate_types) != 6:
        err(f"data/schema/gate_types.json: {len(valid_gate_types)} modi di gate, attesi 6 "
            f"(design-world.md cap. 4). Un modo nuovo e' codice: va discusso.")
    _vfx_for_reg = load_json(os.path.join(DATA, "vfx.json")) or {}
    valid_palette_visiva = set(_vfx_for_reg.get("pathway_palette_visiva", {})) | {"neutra"}
    music_zone_ids = set((audio or {}).get("music", {}).get("zone", {}))
    region_group_ok = VALID_GROUPS | {"neutra"}
    regions_doc = load_json(os.path.join(DATA, "world", "regions.json"))
    region_ids = set()
    region_location_tags = set()  # unione dei location_tags di tutte le regioni
    if regions_doc is None:
        err("data/world/regions.json: mancante o illeggibile (US-601).")
    else:
        for reg in regions_doc.get("regions", []):
            rid = reg.get("id")
            rel = "data/world/regions.json"
            if rid in region_ids:
                err(f"{rel}: id regione duplicato '{rid}'")
            region_ids.add(rid)
            n_i = reg.get("name_i18n", "")
            if not isinstance(n_i, str) or not n_i.startswith("region."):
                err(f"{rel} [{rid}]: name_i18n '{n_i}' deve avere il prefisso 'region.'")
            if reg.get("group_affinity") not in region_group_ok:
                err(f"{rel} [{rid}]: group_affinity '{reg.get('group_affinity')}' non valido "
                    f"(un gruppo di Pathway o 'neutra')")
            dm = reg.get("densita_mistica")
            if not isinstance(dm, (int, float)) or not (0.0 <= dm <= 1.0):
                err(f"{rel} [{rid}]: densita_mistica deve essere un numero in [0, 1]")
            for t in reg.get("location_tags", []):
                if valid_location_tags and t not in valid_location_tags:
                    err(f"{rel} [{rid}]: location_tag '{t}' fuori dal vocabolario di "
                        f"data/schema/location_tags.json")
                region_location_tags.add(t)
            if music_zone_ids and reg.get("music_zone") not in music_zone_ids:
                err(f"{rel} [{rid}]: music_zone '{reg.get('music_zone')}' non e' una zona di "
                    f"data/audio.json music.zone ({sorted(music_zone_ids)})")
            if reg.get("palette_visiva") not in valid_palette_visiva:
                err(f"{rel} [{rid}]: palette_visiva '{reg.get('palette_visiva')}' non e' una "
                    f"palette di data/vfx.json (o 'neutra')")
            for g in reg.get("gating", []):
                gt = g.get("tipo")
                if valid_gate_types and gt not in valid_gate_types:
                    err(f"{rel} [{rid}]: gating.tipo '{gt}' non nel vocabolario di gate_types.json")
                    continue
                if gt == "primitiva":
                    if g.get("primitiva") not in primitives:
                        err(f"{rel} [{rid}]: gating primitiva '{g.get('primitiva')}' non e' una "
                            f"primitiva attiva del registro")
                elif gt == "momento":
                    if g.get("valore") not in valid_momenti:
                        err(f"{rel} [{rid}]: gating momento '{g.get('valore')}' non nel vocabolario time.json")
                elif gt == "fase_lunare":
                    if g.get("valore") not in valid_fasi_lunari:
                        err(f"{rel} [{rid}]: gating fase_lunare '{g.get('valore')}' non nel vocabolario time.json")
                elif gt == "sequenza":
                    if not isinstance(g.get("valore"), int) or not (0 <= g.get("valore") <= 9):
                        err(f"{rel} [{rid}]: gating sequenza.valore deve essere un int 0..9")
        # check informativo: le regioni devono ospitare i luoghi dei rituali
        rituali_tags = set()
        for _fn in files:
            _pw = load_json(os.path.join(pdir, _fn)) or {}
            for _s in _pw.get("sequences", []):
                if _s.get("stub"):
                    continue
                _r = _s.get("advancement_ritual")
                if isinstance(_r, dict):
                    rituali_tags.update(_r.get("location_tags", []))
        senza_regione = sorted(rituali_tags - region_location_tags)
        if senza_regione:
            err(f"data/world/regions.json: i location_tags {senza_regione} sono usati da un "
                f"rituale non-stub ma nessuna regione li ospita (US-601: le regioni realizzano "
                f"a schermo i luoghi dei rituali).")

        # US-619: ogni music_zone usata da una regione ha un ambiente giorno/notte.
        amb_zone = set((audio or {}).get("music", {}).get("ambienti", {}))
        for reg in regions_doc.get("regions", []):
            mz = reg.get("music_zone")
            if mz and mz not in amb_zone:
                err(f"data/audio.json [music.ambienti]: manca la zona '{mz}' usata dalla "
                    f"regione '{reg.get('id')}' (US-619: ambiente giorno/notte per ogni zona).")

    # --- layout disegnati a mano (data/world/layouts/*.json, US-805) ---
    # Sostituiscono il rettangolo piatto generato da region_scene.gd per una
    # regione; una regione SENZA file qui resta piatta come oggi (fallback
    # esplicito in codice) -> solo un warning, non un errore, finche' US-807
    # non disegna le altre 4.
    LEGENDA_LAYOUT = set(".,=#ot~+")
    CALPESTABILI_LAYOUT = set(".,=+")
    region_tags_by_id = {}
    if regions_doc is not None:
        for reg in regions_doc.get("regions", []):
            region_tags_by_id[reg.get("id")] = set(reg.get("location_tags", []))

    layouts_dir = os.path.join(DATA, "world", "layouts")
    layout_region_ids = set()
    if os.path.isdir(layouts_dir):
        for fn in sorted(os.listdir(layouts_dir)):
            if not fn.endswith(".json"):
                continue
            rel = f"data/world/layouts/{fn}"
            doc = load_json(os.path.join(layouts_dir, fn))
            if doc is None:
                continue
            rid = doc.get("region_id")
            if rid not in region_ids:
                err(f"{rel}: region_id '{rid}' non esiste in data/world/regions.json")
                continue
            if rid in layout_region_ids:
                err(f"{rel}: region_id '{rid}' duplicato tra i layout")
            layout_region_ids.add(rid)

            mappa = doc.get("mappa", [])
            if not isinstance(mappa, list) or len(mappa) != 36:
                err(f"{rel} [{rid}]: mappa deve avere 36 righe "
                    f"(trovate {len(mappa) if isinstance(mappa, list) else 'n/a'})")
                mappa = []
            righe_valide = True
            for y, riga in enumerate(mappa):
                if not isinstance(riga, str) or len(riga) != 48:
                    err(f"{rel} [{rid}]: riga {y} deve avere 48 caratteri")
                    righe_valide = False
                    continue
                fuori = set(riga) - LEGENDA_LAYOUT
                if fuori:
                    err(f"{rel} [{rid}]: riga {y} usa caratteri fuori dalla legenda: {sorted(fuori)}")

            if len(mappa) == 36 and righe_valide:
                bordo_ok = all(c == "#" for c in mappa[0]) and all(c == "#" for c in mappa[35])
                bordo_ok = bordo_ok and all(riga[0] == "#" and riga[47] == "#" for riga in mappa)
                if not bordo_ok:
                    err(f"{rel} [{rid}]: il bordo esterno (riga 0, riga 35, colonna 0, "
                        f"colonna 47) deve essere tutto '#'")

            spawn = doc.get("spawn", [])
            if not (isinstance(spawn, list) and len(spawn) == 2
                    and all(isinstance(v, int) for v in spawn)):
                err(f"{rel} [{rid}]: spawn deve essere [x, y] di interi")
            elif len(mappa) == 36 and righe_valide:
                sx, sy = spawn
                if not (0 <= sx < 48 and 0 <= sy < 36):
                    err(f"{rel} [{rid}]: spawn {spawn} fuori dai limiti (48x36)")
                elif mappa[sy][sx] not in CALPESTABILI_LAYOUT:
                    err(f"{rel} [{rid}]: spawn {spawn} non e' su una cella calpestabile "
                        f"('{mappa[sy][sx]}')")

            region_tags = region_tags_by_id.get(rid, set())
            zone = doc.get("zone", {})
            if not isinstance(zone, dict):
                err(f"{rel} [{rid}]: zone deve essere un dict")
                zone = {}
            for tag, rect in zone.items():
                if tag not in region_tags:
                    err(f"{rel} [{rid}]: zone['{tag}'] non e' un location_tag della regione "
                        f"({sorted(region_tags)})")
                if not (isinstance(rect, list) and len(rect) == 4
                        and all(isinstance(v, int) for v in rect)):
                    err(f"{rel} [{rid}]: zone['{tag}'] deve essere [x, y, w, h] di interi")
                    continue
                zx, zy, zw, zh = rect
                if zx < 0 or zy < 0 or zw <= 0 or zh <= 0 or zx + zw > 48 or zy + zh > 36:
                    err(f"{rel} [{rid}]: zone['{tag}'] {rect} fuori dai limiti (48x36)")
            mancanti = region_tags - set(zone)
            if mancanti:
                err(f"{rel} [{rid}]: mancano zone per i location_tags {sorted(mancanti)} "
                    f"(una regione CON layout deve coprirli tutti)")

            passaggi = doc.get("passaggi", {})
            if not isinstance(passaggi, dict):
                err(f"{rel} [{rid}]: passaggi deve essere un dict")
                passaggi = {}
            for dest in passaggi:
                if dest not in region_ids:
                    err(f"{rel} [{rid}]: passaggi['{dest}'] punta a una regione inesistente")

    for _rid in sorted(region_ids - layout_region_ids):
        err(f"data/world/regions.json [{_rid}]: nessun layout in data/world/layouts/ "
            f"(US-807d: tutte e 5 le regioni hanno un layout da questa story in poi; "
            f"un layout mancante non e' piu' atteso).")

    # --- fonti di tag di fase 3 (US-334): stanze costruibili, specie di pet
    # (+ comportamenti), tag_grant dei talenti. Rendono raggiungibili le
    # sinergie che pescano da questi sistemi. La VALIDAZIONE piena di quei
    # file sta piu' sotto; qui si raccolgono solo i tag prima del check.
    _rooms_doc = load_json(os.path.join(DATA, "base", "rooms.json")) or {}
    for _t in _rooms_doc.get("rooms", {}).values():
        for _tag in (_t.get("tag", []) if isinstance(_t, dict) else []):
            obtainable_tags.add(_tag)
    _pdir = os.path.join(DATA, "pets")
    for _fn in sorted(os.listdir(_pdir)) if os.path.isdir(_pdir) else []:
        if not _fn.endswith(".json"):
            continue
        for _pet in (load_json(os.path.join(_pdir, _fn)) or {}).get("pets", []):
            for _tag in _pet.get("tag", []):
                obtainable_tags.add(_tag)
            for _comp in _pet.get("comportamenti", []):
                for _tag in (_comp.get("tag", []) if isinstance(_comp, dict) else []):
                    obtainable_tags.add(_tag)
    _tdir = os.path.join(DATA, "talents")
    for _fn in sorted(os.listdir(_tdir)) if os.path.isdir(_tdir) else []:
        if not _fn.endswith(".json"):
            continue
        for _tal in (load_json(os.path.join(_tdir, _fn)) or {}).get("talents", []):
            _eff = _tal.get("effetto", {})
            if _eff.get("tipo") == "tag_grant" and _eff.get("tag"):
                obtainable_tags.add(_eff["tag"])

    # --- sinergie ---
    sdir = os.path.join(DATA, "synergies")
    _rec_for_syn = load_json(os.path.join(DATA, "potions", "recipes.json")) or {}
    recipe_ids_all = set((_rec_for_syn.get("recipes", {}) or {}).keys())
    if os.path.isdir(sdir):
        syn_ids = set()
        lore_syn_ids = set()   # US-621: sinergie scoperta:"lore" (le insegna una fonte lore)
        syn_neutralizza = {}  # sid -> [id, ...]
        unreachable_syns = []  # (sid, [tag, ...]) - sinergie di gruppi differiti
        for fname in sorted(os.listdir(sdir)):
            if not fname.endswith(".json"):
                continue
            doc = load_json(os.path.join(sdir, fname))
            if doc is None:
                continue
            rel = f"data/synergies/{fname}"
            for syn in (doc if isinstance(doc, list) else doc.get("synergies", [])):
                sid = syn.get("id")
                if sid in syn_ids:
                    err(f"{rel}: id sinergia duplicato '{sid}'")
                syn_ids.add(sid)
                if syn.get("scoperta") == "lore":
                    lore_syn_ids.add(sid)
                for t in list(syn.get("richiede_tag", {})) + list(syn.get("esclude_tag", {})):
                    if t not in valid_tags:
                        err(f"{rel} [{sid}]: tag sconosciuto '{t}'")
                if len(set(syn.get("fonti", []))) < 2:
                    err(f"{rel} [{sid}]: una sinergia deve pescare da almeno 2 fonti diverse "
                        f"(pilastro di design: le sinergie attraversano i sistemi)")
                if "priorita" in syn and not isinstance(syn["priorita"], int):
                    err(f"{rel} [{sid}]: 'priorita' deve essere un intero")
                # --- effetto ben formato per tipo (fase 4, US-401) ---
                eff = syn.get("effetto", {})
                et = eff.get("tipo")
                syn_stats = {"hp_max", "spiritualita_max", "velocita", "difesa",
                             "evasione", "precisione", "forza"}
                if et == "modifica_stat":
                    if eff.get("stat") not in syn_stats:
                        err(f"{rel} [{sid}]: effetto.stat '{eff.get('stat')}' non e' una stat nota")
                    if not isinstance(eff.get("valore"), (int, float)):
                        err(f"{rel} [{sid}]: effetto.valore deve essere numerico")
                    if not isinstance(eff.get("moltiplicativo"), bool):
                        err(f"{rel} [{sid}]: effetto.moltiplicativo deve essere true/false")
                elif et == "modifica_follia":
                    if not isinstance(eff.get("delta_al_minuto"), (int, float)):
                        err(f"{rel} [{sid}]: effetto.delta_al_minuto deve essere numerico")
                elif et == "modifica_qualita_crafting":
                    if eff.get("categoria") not in ("pozioni", "forgia"):
                        err(f"{rel} [{sid}]: effetto.categoria deve essere 'pozioni' o 'forgia'")
                    if not isinstance(eff.get("delta"), int):
                        err(f"{rel} [{sid}]: effetto.delta deve essere un intero (passi di qualita')")
                elif et == "sblocca_ricetta":
                    if eff.get("recipe_id") not in recipe_ids_all:
                        err(f"{rel} [{sid}]: effetto.recipe_id '{eff.get('recipe_id')}' non risolve")
                elif et == "aggiungi_abilita":
                    if not syn.get("stub") and eff.get("ability_id") not in ability_ids:
                        err(f"{rel} [{sid}]: effetto aggiunge l'abilita' inesistente "
                            f"'{eff.get('ability_id')}'. Scrivila, o marca la sinergia \"stub\": true.")
                elif et == "modifica_primitiva":
                    pn = eff.get("primitiva")
                    pspec = prim_doc["primitives"].get(pn, {})
                    if not pspec or pspec.get("deferred"):
                        err(f"{rel} [{sid}]: effetto.primitiva '{pn}' non e' una primitiva attiva")
                    elif eff.get("parametro") not in pspec.get("params", []):
                        err(f"{rel} [{sid}]: effetto.parametro '{eff.get('parametro')}' non e' un "
                            f"parametro di '{pn}' ({pspec.get('params', [])})")
                    if not isinstance(eff.get("delta"), (int, float)):
                        err(f"{rel} [{sid}]: effetto.delta deve essere numerico")
                    if not isinstance(eff.get("moltiplicativo"), bool):
                        err(f"{rel} [{sid}]: effetto.moltiplicativo deve essere true/false")
                else:
                    err(f"{rel} [{sid}]: effetto.tipo '{et}' non riconosciuto")
                if syn.get("neutralizza"):
                    if not syn.get("anti"):
                        err(f"{rel} [{sid}]: 'neutralizza' ha senso solo su una anti-sinergia (anti:true)")
                    syn_neutralizza[sid] = list(syn["neutralizza"])
                irraggiungibili = [t for t in syn.get("richiede_tag", {})
                                   if t in valid_tags and t not in obtainable_tags]
                if irraggiungibili:
                    unreachable_syns.append((sid, irraggiungibili))
        # US-415: una riga sola invece di N warning che annegano gli altri.
        if unreachable_syns:
            lista = ", ".join(sorted(s for s, _ in unreachable_syns))
            warn(f"{len(unreachable_syns)} sinergie irraggiungibili (attese: richiedono tag di "
                 f"gruppi di Pathway differiti, si accenderanno riattivando il gruppo): {lista}")
        for anti_id, bersagli in syn_neutralizza.items():
            for b in bersagli:
                if b not in syn_ids:
                    err(f"data/synergies/: [{anti_id}] neutralizza '{b}', che non e' una sinergia esistente")

    # --- oggetti (data/items/, US-301) ---
    ic_doc = load_json(os.path.join(DATA, "schema", "item_categories.json"))
    item_categories = set((ic_doc or {}).get("item_categories", []))
    es_doc = load_json(os.path.join(DATA, "schema", "equip_slots.json"))
    equip_tipi = set((es_doc or {}).get("tipi", []))
    sig_doc = load_json(os.path.join(DATA, "schema", "sigillato_effect_types.json"))
    sigillato_tick_tipi = set((sig_doc or {}).get("tick", []))
    sigillato_tag_tipi = set((sig_doc or {}).get("tag", []))
    idir = os.path.join(DATA, "items")
    item_ids = set()
    item_cat = {}   # id -> categoria
    nutre_pet_ids = set()   # item con nutre_pet:true (US-324)
    sigillo_refs = []   # [(rel, iid, sigillo_ref)] - risolti dopo aver caricato i sigilli
    n_sigillati = 0
    known_item_stats = {"hp_max", "spiritualita_max", "velocita", "difesa",
                        "evasione", "precisione", "forza"}
    if os.path.isdir(idir):
        for fn in sorted(os.listdir(idir)):
            if not fn.endswith(".json"):
                continue
            doc = load_json(os.path.join(idir, fn))
            if doc is None:
                continue
            rel = f"data/items/{fn}"
            for it in doc.get("items", []):
                iid = it.get("id")
                if iid in item_ids:
                    err(f"{rel}: id item duplicato '{iid}'")
                item_ids.add(iid)
                cat = it.get("categoria")
                item_cat[iid] = cat
                if it.get("nutre_pet") is True:
                    nutre_pet_ids.add(iid)
                if cat not in item_categories:
                    err(f"{rel} [{iid}]: categoria '{cat}' non nel vocabolario chiuso "
                        f"({sorted(item_categories)})")
                if not isinstance(it.get("name_i18n"), str) or not it.get("name_i18n"):
                    err(f"{rel} [{iid}]: name_i18n mancante")
                for t in it.get("tag", []):
                    if t not in valid_tags:
                        err(f"{rel} [{iid}]: tag sconosciuto '{t}'")
                if not isinstance(it.get("valore"), int) or it.get("valore", -1) < 0:
                    err(f"{rel} [{iid}]: valore deve essere un intero >= 0")
                if not isinstance(it.get("impilabile"), bool):
                    err(f"{rel} [{iid}]: impilabile deve essere true/false")
                if cat == "equip":
                    if it.get("slot") not in equip_tipi:
                        err(f"{rel} [{iid}]: slot '{it.get('slot')}' non in equip_slots.tipi "
                            f"({sorted(equip_tipi)})")
                    for k, v in (it.get("stat_modifiers") or {}).items():
                        if k not in known_item_stats:
                            err(f"{rel} [{iid}]: stat_modifiers ha una stat ignota '{k}'")
                    ec = it.get("effetto_collaterale")
                    if it.get("sigillato"):
                        n_sigillati += 1
                    if it.get("sigillato") and not ec:
                        err(f"{rel} [{iid}]: sigillato:true senza effetto_collaterale "
                            f"(un Sigillato senza prezzo e' un bug di dati, US-318)")
                    elif it.get("sigillato") and isinstance(ec, dict):
                        et = ec.get("tipo")
                        if et in sigillato_tick_tipi:
                            if not isinstance(ec.get("valore"), (int, float)) or ec.get("valore", 0) <= 0:
                                err(f"{rel} [{iid}]: effetto_collaterale.valore deve essere numerico > 0 "
                                    f"(e' sempre uno svantaggio che sale col tempo)")
                        elif et in sigillato_tag_tipi:
                            if ec.get("tag") not in valid_tags:
                                err(f"{rel} [{iid}]: effetto_collaterale.tag sconosciuto '{ec.get('tag')}'")
                        else:
                            err(f"{rel} [{iid}]: effetto_collaterale.tipo '{et}' non nel vocabolario chiuso "
                                f"({sorted(sigillato_tick_tipi | sigillato_tag_tipi)})")
                if cat == "sigillo":
                    sref = it.get("sigillo_ref")
                    if not sref:
                        err(f"{rel} [{iid}]: item categoria:sigillo senza sigillo_ref")
                    else:
                        sigillo_refs.append((rel, iid, sref))
                sab = it.get("stored_ability_id")
                if sab is not None and ability_ids and sab not in ability_ids:
                    err(f"{rel} [{iid}]: stored_ability_id '{sab}' non risolve a un'abilita'")
                sfl = it.get("stored_flag")
                if sfl is not None:
                    if not isinstance(sfl, str) or not sfl:
                        err(f"{rel} [{iid}]: stored_flag deve essere una stringa non vuota (US-621)")
                    if it.get("categoria") != "pergamena":
                        err(f"{rel} [{iid}]: stored_flag e' per gli item categoria:pergamena (libri)")
                    if sab is not None or it.get("insegna_ricetta") is not None:
                        err(f"{rel} [{iid}]: una pergamena porta UNA sola cosa "
                            f"(stored_ability_id | insegna_ricetta | stored_flag)")
                ins = it.get("insegna_ricetta")
                if ins is not None:
                    _r = load_json(os.path.join(DATA, "potions", "recipes.json")) or {}
                    _rec = _r.get("recipes", {}).get(ins, {})
                    if not _rec:
                        err(f"{rel} [{iid}]: insegna_ricetta '{ins}' non risolve a una ricetta")
                    elif _rec.get("tier") != "leggendaria":
                        err(f"{rel} [{iid}]: insegna_ricetta '{ins}' non e' una ricetta 'leggendaria' "
                            f"(le base/avanzata non si insegnano con una pergamena)")
                eff = it.get("effetto")
                if isinstance(eff, dict):
                    et = eff.get("tipo")
                    if et in deferred_primitives:
                        err(f"{rel} [{iid}]: effetto usa la primitiva DIFFERITA '{et}'")
                    elif et not in primitives:
                        err(f"{rel} [{iid}]: effetto usa la primitiva sconosciuta '{et}'")
    if len(item_ids) < 12:
        err(f"data/items/: solo {len(item_ids)} item, attesi >= 12 che coprano le 7 categorie")
    if n_sigillati < 3:
        err(f"data/items/: solo {n_sigillati} equip sigillato:true, attesi >= 3 (US-318)")
    coperte = {it_cat for f in (os.listdir(idir) if os.path.isdir(idir) else [])
               if f.endswith(".json")
               for it_cat in [i.get("categoria") for i in (load_json(os.path.join(idir, f)) or {}).get("items", [])]}
    for c in item_categories:
        if c not in coperte:
            warn(f"data/items/: nessun item di esempio per la categoria '{c}'")

    # --- nemici/oggetti dei layout (US-806) ---
    # Rilegge data/world/layouts/*.json (item_ids/pathway_ids non erano ancora
    # pronti nel blocco "layouts" piu' sopra, US-805). Un boss e' dati
    # (sequenza + override + scala), mai un flag: qui si valida solo la forma.
    _bal_nemici = load_json(os.path.join(DATA, "balance.json")) or {}
    nemico_base_keys = set((_bal_nemici.get("nemico_base", {}) or {}).keys())
    if os.path.isdir(layouts_dir):
        for fn in sorted(os.listdir(layouts_dir)):
            if not fn.endswith(".json"):
                continue
            rel = f"data/world/layouts/{fn}"
            doc = load_json(os.path.join(layouts_dir, fn)) or {}
            rid = doc.get("region_id")
            mappa = doc.get("mappa", [])
            righe_ok = isinstance(mappa, list) and len(mappa) == 36 and all(
                isinstance(r, str) and len(r) == 48 for r in mappa)

            def _calpestabile(x, y):
                return righe_ok and 0 <= x < 48 and 0 <= y < 36 and mappa[y][x] in CALPESTABILI_LAYOUT

            for nm in doc.get("nemici", []):
                nx, ny = nm.get("x"), nm.get("y")
                if not (isinstance(nx, int) and isinstance(ny, int) and _calpestabile(nx, ny)):
                    err(f"{rel} [{rid}]: nemico a ({nx},{ny}) non e' su una cella calpestabile")
                seq = nm.get("sequenza")
                if not (isinstance(seq, int) and 0 <= seq <= 9):
                    err(f"{rel} [{rid}]: nemico sequenza '{seq}' deve essere un int 0..9")
                scala = nm.get("scala", 1.0)
                if not (isinstance(scala, (int, float)) and 0.5 <= scala <= 3):
                    err(f"{rel} [{rid}]: nemico scala '{scala}' deve essere in [0.5, 3]")
                ov = nm.get("override", {})
                if not isinstance(ov, dict):
                    err(f"{rel} [{rid}]: nemico override deve essere un dict")
                    ov = {}
                fuori = set(ov) - nemico_base_keys
                if fuori:
                    err(f"{rel} [{rid}]: nemico override ha chiavi fuori da "
                        f"balance.json.nemico_base: {sorted(fuori)}")
                car = ov.get("caratteristica")
                if isinstance(car, dict) and car.get("pathway_id") not in pathway_ids:
                    err(f"{rel} [{rid}]: nemico override.caratteristica.pathway_id "
                        f"'{car.get('pathway_id')}' non e' un Pathway attivo")

            for og in doc.get("oggetti", []):
                ox, oy = og.get("x"), og.get("y")
                if not (isinstance(ox, int) and isinstance(oy, int) and _calpestabile(ox, oy)):
                    err(f"{rel} [{rid}]: oggetto a ({ox},{oy}) non e' su una cella calpestabile")
                if og.get("item_id") not in item_ids:
                    err(f"{rel} [{rid}]: oggetto item_id '{og.get('item_id')}' non esiste in data/items/")

    # --- ingredienti delle formule (US-808) ---
    # Ogni ingrediente citato da una formula di potion (tutte quelle in
    # data/potions/formulas.json appartengono ai 10 Pathway attivi: il file
    # non ne contiene di differiti) deve esistere come item di categoria
    # 'ingrediente' in data/items/ — generato da
    # tools/generate_formula_ingredients.py, mai un id fantasma citato solo
    # nella formula.
    for _fid, _f in formulas.items():
        for _ing in _f.get("ingredients", []):
            if _ing not in item_cat:
                err(f"data/potions/formulas.json [{_fid}]: ingrediente '{_ing}' non esiste come item "
                    f"in data/items/ (lancia tools/generate_formula_ingredients.py)")
            elif item_cat[_ing] != "ingrediente":
                err(f"data/potions/formulas.json [{_fid}]: ingrediente '{_ing}' esiste come item ma "
                    f"con categoria '{item_cat[_ing]}', non 'ingrediente'")

    # --- sigilli (data/sigils/, US-315) ---
    set_doc = load_json(os.path.join(DATA, "schema", "sigil_effect_types.json"))
    sigil_effetti_tipi = set((set_doc or {}).get("effetti", []))
    sigil_collaterale_tipi = set((set_doc or {}).get("effetti_collaterali", []))
    sigils_doc = load_json(os.path.join(DATA, "sigils", "core.json"))
    sigils = (sigils_doc or {}).get("sigils", {})

    def _check_sigil_effect(rel, sid, campo, eff, tipi_ammessi, richiedi_svantaggio):
        if not isinstance(eff, dict):
            err(f"{rel} [{sid}]: {campo} deve essere un oggetto")
            return
        tipo = eff.get("tipo")
        if tipo not in tipi_ammessi:
            err(f"{rel} [{sid}]: {campo}.tipo '{tipo}' non nel vocabolario chiuso ({sorted(tipi_ammessi)})")
            return
        if tipo == "stat_modifier":
            if eff.get("stat") not in known_item_stats:
                err(f"{rel} [{sid}]: {campo} stat sconosciuta '{eff.get('stat')}'")
            if not isinstance(eff.get("valore"), (int, float)):
                err(f"{rel} [{sid}]: {campo}.valore deve essere numerico")
            elif richiedi_svantaggio and eff.get("valore") >= 0:
                err(f"{rel} [{sid}]: {campo} e' un effetto_collaterale ma valore >= 0: "
                    f"un collaterale e' sempre uno svantaggio (US-315)")
        elif tipo == "stored_ability_id":
            if eff.get("ability_id") not in ability_ids:
                err(f"{rel} [{sid}]: {campo}.ability_id '{eff.get('ability_id')}' non risolve a un'abilita'")
        elif tipo == "tag_grant":
            if eff.get("tag") not in valid_tags:
                err(f"{rel} [{sid}]: {campo}.tag sconosciuto '{eff.get('tag')}'")

    n_con_collaterale = 0
    for sid, sig in sigils.items():
        rel = "data/sigils/core.json"
        if not isinstance(sig.get("name_i18n"), str) or not sig.get("name_i18n"):
            err(f"{rel} [{sid}]: name_i18n mancante")
        for t in sig.get("tag", []):
            if t not in valid_tags:
                err(f"{rel} [{sid}]: tag sconosciuto '{t}'")
        _check_sigil_effect(rel, sid, "effetto", sig.get("effetto"), sigil_effetti_tipi, False)
        collaterale = sig.get("effetto_collaterale")
        if collaterale is not None:
            n_con_collaterale += 1
            _check_sigil_effect(rel, sid, "effetto_collaterale", collaterale, sigil_collaterale_tipi, True)
    if len(sigils) < 8:
        err(f"data/sigils/: solo {len(sigils)} sigilli, attesi >= 8")
    if n_con_collaterale < 2:
        err(f"data/sigils/: solo {n_con_collaterale} sigilli con effetto_collaterale, attesi >= 2")
    for rel, iid, sref in sigillo_refs:
        if sref not in sigils:
            err(f"{rel} [{iid}]: sigillo_ref '{sref}' non risolve a un sigillo di data/sigils/")

    # --- ricette delle pozioni consumabili (data/potions/recipes.json, US-308) ---
    pq_doc = load_json(os.path.join(DATA, "schema", "potion_quality.json"))
    potion_quality = set((pq_doc or {}).get("qualita", []))
    if len(potion_quality) != 4:
        err(f"data/schema/potion_quality.json: {len(potion_quality)} qualita', attese 4")
    rec_doc = load_json(os.path.join(DATA, "potions", "recipes.json"))
    recipes = (rec_doc or {}).get("recipes", {})
    VALID_TIER = {"base", "avanzata", "leggendaria"}
    for rid, r in recipes.items():
        tier = r.get("tier")
        if tier not in VALID_TIER:
            err(f"data/potions/recipes.json [{rid}]: tier '{tier}' non valido ({sorted(VALID_TIER)})")
        if not isinstance(r.get("nota_da_subito"), bool):
            err(f"data/potions/recipes.json [{rid}]: nota_da_subito deve essere true/false")
        elif r.get("nota_da_subito") != (tier == "base"):
            err(f"data/potions/recipes.json [{rid}]: nota_da_subito deve essere true SSE tier e' 'base'")
        if r.get("qualita_base") not in potion_quality:
            err(f"data/potions/recipes.json [{rid}]: qualita_base '{r.get('qualita_base')}' "
                f"non nel vocabolario ({sorted(potion_quality)})")
        ingr = r.get("ingredienti", {})
        if not isinstance(ingr, dict) or not ingr:
            err(f"data/potions/recipes.json [{rid}]: 'ingredienti' deve essere un oggetto non vuoto")
        for ing, q in (ingr if isinstance(ingr, dict) else {}).items():
            if item_cat.get(ing) != "ingrediente":
                err(f"data/potions/recipes.json [{rid}]: ingrediente '{ing}' non e' un item categoria:ingrediente")
            if not isinstance(q, int) or q <= 0:
                err(f"data/potions/recipes.json [{rid}]: quantita' di '{ing}' deve essere un intero > 0")
        out = r.get("output", {})
        oid = out.get("item_id")
        oeff = out.get("effetto")
        if oid is not None:
            if oid not in item_ids:
                err(f"data/potions/recipes.json [{rid}]: output.item_id '{oid}' non risolve")
        elif isinstance(oeff, dict):
            if oeff.get("tipo") not in primitives or oeff.get("tipo") in deferred_primitives:
                err(f"data/potions/recipes.json [{rid}]: output.effetto.tipo '{oeff.get('tipo')}' "
                    f"non e' una primitiva implementabile")
        else:
            err(f"data/potions/recipes.json [{rid}]: output deve avere item_id o effetto")

    # --- blueprint di forgiatura (data/forge/blueprints.json, US-316) ---
    bp_doc = load_json(os.path.join(DATA, "forge", "blueprints.json"))
    blueprints = (bp_doc or {}).get("blueprints", {})
    for bid, bp in blueprints.items():
        rel = "data/forge/blueprints.json"
        if not isinstance(bp.get("name_i18n"), str) or not bp.get("name_i18n"):
            err(f"{rel} [{bid}]: name_i18n mancante")
        if not isinstance(bp.get("nota_da_subito"), bool):
            err(f"{rel} [{bid}]: nota_da_subito deve essere true/false")
        if bp.get("qualita_base") not in potion_quality:
            err(f"{rel} [{bid}]: qualita_base '{bp.get('qualita_base')}' non nel vocabolario "
                f"({sorted(potion_quality)})")
        oid = bp.get("output", {}).get("item_id")
        if oid not in item_ids:
            err(f"{rel} [{bid}]: output.item_id '{oid}' non risolve")
        elif item_cat.get(oid) != "equip":
            err(f"{rel} [{bid}]: output.item_id '{oid}' non e' un item categoria:equip")
        materiali = bp.get("materiali", {})
        if not isinstance(materiali, dict) or not materiali:
            err(f"{rel} [{bid}]: 'materiali' deve essere un oggetto non vuoto")
        for mid, q in (materiali if isinstance(materiali, dict) else {}).items():
            if item_cat.get(mid) != "materiale":
                err(f"{rel} [{bid}]: materiale '{mid}' non e' un item categoria:materiale")
            if not isinstance(q, int) or q <= 0:
                err(f"{rel} [{bid}]: quantita' di '{mid}' deve essere un intero > 0")
    if len(blueprints) < 1:
        err("data/forge/blueprints.json: nessun blueprint, atteso almeno 1")

    # --- NPC (data/npc/roster.json, US-612) ---
    # Un NPC e' DATO: schedule sui momenti/location_tags, vendor sugli item.
    # faction_id -> data/factions.json (US-615) e dialogue_id -> data/dialogues/
    # (US-614): finche' quei file non esistono il check e' indulgente.
    roster_doc = load_json(os.path.join(DATA, "npc", "roster.json"))
    faction_ids = set()
    _fac_path = os.path.join(DATA, "factions.json")
    if os.path.exists(_fac_path):
        _fac_doc = load_json(_fac_path) or {}
        faction_ids = {f.get("id") for f in _fac_doc.get("factions", [])}
    dlg_dir = os.path.join(DATA, "dialogues")
    dlg_ids = set()
    if os.path.isdir(dlg_dir):
        for fn in os.listdir(dlg_dir):
            d = load_json(os.path.join(dlg_dir, fn)) or {}
            if d.get("id"):
                dlg_ids.add(d["id"])
    if roster_doc is None:
        err("data/npc/roster.json: mancante o illeggibile (US-612).")
    else:
        rel = "data/npc/roster.json"
        npc_ids = set()
        n_generici = 0
        for npc in roster_doc.get("npcs", []):
            nid = npc.get("id", "")
            if nid in npc_ids:
                err(f"{rel}: id NPC duplicato '{nid}'")
            npc_ids.add(nid)
            if not isinstance(nid, str) or not nid.startswith("npc_"):
                err(f"{rel} [{nid}]: id deve avere il prefisso 'npc_'")
            if nid.startswith("npc_generic_"):
                n_generici += 1
            for campo in ("name_i18n", "role_i18n"):
                v = npc.get(campo)
                if not isinstance(v, str) or not v.startswith("npc."):
                    err(f"{rel} [{nid}]: {campo} '{v}' deve avere il prefisso 'npc.'")
            if npc.get("region_id") not in region_ids:
                err(f"{rel} [{nid}]: region_id '{npc.get('region_id')}' non e' una regione di regions.json")
            for voce in npc.get("schedule", []):
                mom = voce.get("momento")
                if mom not in valid_momenti:
                    err(f"{rel} [{nid}]: schedule momento '{mom}' non nel vocabolario time.json")
                lt = voce.get("location_tag")
                if lt is not None and valid_location_tags and lt not in valid_location_tags:
                    err(f"{rel} [{nid}]: schedule location_tag '{lt}' fuori dal vocabolario di location_tags.json")
            ven = npc.get("vendor")
            if ven is not None:
                for iid in ven.get("listino", []):
                    if iid not in item_ids:
                        err(f"{rel} [{nid}]: vendor.listino '{iid}' non e' un item esistente")
            fid = npc.get("faction_id")
            if fid is not None and faction_ids and fid not in faction_ids:
                err(f"{rel} [{nid}]: faction_id '{fid}' non e' in data/factions.json")
            did = npc.get("dialogue_id")
            if dlg_ids and did not in dlg_ids:
                err(f"{rel} [{nid}]: dialogue_id '{did}' non ha un file in data/dialogues/")
        for atteso in ("npc_mirco", "npc_sidon", "npc_vesna", "npc_aldo",
                       "npc_ottavia", "npc_bruno", "npc_lena", "npc_doran"):
            if atteso not in npc_ids:
                err(f"{rel}: manca l'NPC del roster '{atteso}' (design-npc-quest cap. 2)")
        if n_generici < 10:
            err(f"{rel}: solo {n_generici} npc_generic_*, attesi >= 10 (fool_9_inganno ne inganna 10)")

    # --- fonti degli ingredienti (US-809c, chiusura "fonti nel mondo") ---
    # Ogni ingrediente citato da una formula deve avere ALMENO UNA fonte in
    # gioco: un drop di nemico (US-809a, layout.drop), un venditore (US-809b,
    # roster.json vendor.listino) o la raccolta a terra (US-809c, layout.
    # oggetti). roster_doc e' definito subito sopra (blocco NPC); item_ids
    # gia' in scope dal blocco item piu' in alto.
    ingredienti_citati = set()
    for _fid, _f in formulas.items():
        ingredienti_citati.update(_f.get("ingredients", []))

    fonti_trovate = set()
    if roster_doc is not None:
        for npc in roster_doc.get("npcs", []):
            ven = npc.get("vendor")
            if ven is not None:
                fonti_trovate.update(ven.get("listino", []))
    if os.path.isdir(layouts_dir):
        for fn in sorted(os.listdir(layouts_dir)):
            if not fn.endswith(".json"):
                continue
            _ldoc = load_json(os.path.join(layouts_dir, fn)) or {}
            for lst in _ldoc.get("drop", {}).values():
                fonti_trovate.update(lst)
            for og in _ldoc.get("oggetti", []):
                fonti_trovate.add(og.get("item_id"))

    _mancanti = sorted(ingredienti_citati - fonti_trovate)
    if _mancanti:
        err(f"data/potions/formulas.json: {len(_mancanti)} ingredienti senza "
            f"nessuna fonte in gioco (ne' drop, ne' listino, ne' oggetti a "
            f"terra): {', '.join(_mancanti)}")

    # --- fazioni (data/factions.json, US-615) ---
    tracked_ev0 = load_json(os.path.join(DATA, "schema", "tracked_events.json")) or {}
    ev_names0 = set(tracked_ev0.get("events", {}).keys())
    fac_path = os.path.join(DATA, "factions.json")
    if not os.path.exists(fac_path):
        err("data/factions.json: mancante o illeggibile (US-615).")
    else:
        fdoc = load_json(fac_path) or {}
        rel = "data/factions.json"
        ids_visti = set()
        for f in fdoc.get("factions", []):
            fid = f.get("id", "")
            if fid in ids_visti:
                err(f"{rel}: id fazione duplicato '{fid}'")
            ids_visti.add(fid)
            ni = f.get("name_i18n")
            if not isinstance(ni, str) or not ni.startswith("faction."):
                err(f"{rel} [{fid}]: name_i18n '{ni}' deve avere il prefisso 'faction.'")
            soglie = f.get("soglie", {})
            if not isinstance(soglie, dict) or len(soglie) < 2 or not all(isinstance(v, (int, float)) for v in soglie.values()):
                err(f"{rel} [{fid}]: 'soglie' deve avere >= 2 nomi di livello con valore numerico")
            for m in f.get("membri", []):
                if roster_doc is not None and m not in npc_ids:
                    err(f"{rel} [{fid}]: membro '{m}' non e' nel roster")
                elif roster_doc is not None:
                    m_fid = next((n.get("faction_id") for n in roster_doc.get("npcs", []) if n.get("id") == m), None)
                    if m_fid != fid:
                        err(f"{rel} [{fid}]: il membro '{m}' ha faction_id '{m_fid}' nel roster (incoerente)")
            rp = f.get("reazione_al_potere")
            if isinstance(rp, dict) and roster_doc is not None and rp.get("membro") not in npc_ids:
                err(f"{rel} [{fid}]: reazione_al_potere.membro '{rp.get('membro')}' non e' nel roster")
            sp = f.get("sospetto")
            if isinstance(sp, dict):
                if sp.get("evento") not in ev_names0:
                    err(f"{rel} [{fid}]: sospetto.evento '{sp.get('evento')}' non e' uno dei 12 eventi tracciati")
                if sp.get("regione") not in region_ids:
                    err(f"{rel} [{fid}]: sospetto.regione '{sp.get('regione')}' non e' una regione")
        for atteso in ("ordine_minore", "porto", "quartiere", "giustizia"):
            if atteso not in ids_visti:
                err(f"{rel}: manca la fazione '{atteso}' (design-npc-quest cap. 3)")

    # --- antagonisti (data/lore/antagonisti.json, US-620) ---
    ant_path = os.path.join(DATA, "lore", "antagonisti.json")
    if not os.path.exists(ant_path):
        err("data/lore/antagonisti.json: mancante o illeggibile (US-620).")
    else:
        adoc = load_json(ant_path) or {}
        rel = "data/lore/antagonisti.json"
        coperti = set()
        for a in adoc.get("antagonisti", []):
            pid = a.get("pathway_id")
            coperti.add(pid)
            if pathway_ids and pid not in pathway_ids:
                err(f"{rel} [{a.get('id')}]: pathway_id '{pid}' non e' un Pathway attivo")
            ni = a.get("name_i18n")
            if not isinstance(ni, str) or not ni.startswith("antagonist."):
                err(f"{rel} [{a.get('id')}]: name_i18n '{ni}' senza prefisso 'antagonist.'")
            indizi = a.get("indizi", [])
            if not indizi:
                err(f"{rel} [{a.get('id')}]: nessun indizio")
            for ind in indizi:
                ti = ind.get("text_i18n") if isinstance(ind, dict) else None
                if not isinstance(ti, str) or not ti.startswith("antagonist."):
                    err(f"{rel} [{a.get('id')}]: un indizio senza text_i18n 'antagonist.*'")
        for pid in pathway_ids:
            if pid and pid not in coperti:
                err(f"{rel}: manca l'antagonista per il Pathway attivo '{pid}' (US-620: uno per Pathway).")

    # --- avanzamento_temporale nel roster (US-620) ---
    if roster_doc is not None:
        for npc in roster_doc.get("npcs", []):
            av = npc.get("avanzamento_temporale")
            if av is not None:
                for k in ("sequenza_iniziale", "ogni_momenti", "sequenza_minima"):
                    v = av.get(k)
                    if not isinstance(v, int) or v < 0:
                        err(f"data/npc/roster.json [{npc.get('id')}]: avanzamento_temporale.{k} intero >= 0.")

    # --- dialoghi (data/dialogues/, US-613) ---
    # Un grafo a nodi: start valido, ogni goto verso un nodo esistente o null,
    # nessun nodo orfano (irraggiungibile dallo start), speaker nel roster,
    # effetti dal vocabolario chiuso di 5, emit_event solo sui 12 eventi.
    DLG_COND = {"acting_progress_min", "madness_max", "madness_min", "e_notte",
                "fase_lunare", "foundation_min", "tier_min", "in_zona_tag",
                "follia_min", "reputazione_min", "flag"}
    DLG_EFFETTI = {"emit_event", "flag", "reputazione", "apri_vendita", "avvia_quest", "impara_sinergia"}
    _dlg_quest_ids = set()   # quest_id nominati da un effetto avvia_quest
    tracked_ev = load_json(os.path.join(DATA, "schema", "tracked_events.json")) or {}
    ev_names = set(tracked_ev.get("events", {}).keys())
    modi_influenced = set(tracked_ev.get("events", {}).get("npc_influenced", {}).get("valori_modo", []))
    if os.path.isdir(dlg_dir):
        for fn in sorted(os.listdir(dlg_dir)):
            if not fn.endswith(".json"):
                continue
            rel = f"data/dialogues/{fn}"
            doc = load_json(os.path.join(dlg_dir, fn)) or {}
            nodes = doc.get("nodes", {})
            start = doc.get("start")
            if start not in nodes:
                err(f"{rel}: start '{start}' non e' un nodo del grafo")
            # raggiungibilita' dallo start
            visti = set()
            frontiera = [start] if start in nodes else []
            while frontiera:
                nid = frontiera.pop()
                if nid in visti:
                    continue
                visti.add(nid)
                for ch in nodes.get(nid, {}).get("choices", []):
                    g = ch.get("goto")
                    if g is not None and g not in nodes:
                        err(f"{rel} [{nid}]: goto '{g}' verso un nodo inesistente")
                    elif isinstance(g, str):
                        frontiera.append(g)
            orfani = sorted(set(nodes) - visti)
            if orfani:
                err(f"{rel}: nodi irraggiungibili dallo start: {orfani}")
            for nid, nd in nodes.items():
                sp = nd.get("speaker")
                if roster_doc is not None and sp not in npc_ids:
                    err(f"{rel} [{nid}]: speaker '{sp}' non e' nel roster")
                for ch in nd.get("choices", []):
                    for cnd in ch.get("condizioni", []):
                        if cnd.get("tipo") not in DLG_COND:
                            err(f"{rel} [{nid}]: condizione '{cnd.get('tipo')}' fuori dal vocabolario "
                                f"({sorted(DLG_COND)})")
                    for eff in ch.get("effetti", []):
                        et = eff.get("tipo")
                        if et not in DLG_EFFETTI:
                            err(f"{rel} [{nid}]: effetto '{et}' fuori dal vocabolario chiuso "
                                f"({sorted(DLG_EFFETTI)})")
                        if et == "emit_event":
                            if eff.get("evento") not in ev_names:
                                err(f"{rel} [{nid}]: emit_event.evento '{eff.get('evento')}' non e' "
                                    f"uno dei 12 eventi tracciati")
                            if eff.get("evento") == "npc_influenced" and eff.get("modo") not in modi_influenced:
                                err(f"{rel} [{nid}]: emit_event npc_influenced.modo '{eff.get('modo')}' "
                                    f"non e' uno dei 5 ({sorted(modi_influenced)})")
                        if et == "avvia_quest":
                            _dlg_quest_ids.add(eff.get("quest_id"))
                        if et == "impara_sinergia" and lore_syn_ids and eff.get("id") not in lore_syn_ids:
                            err(f"{rel} [{nid}]: impara_sinergia.id '{eff.get('id')}' non e' una "
                                f"sinergia scoperta:'lore' ({sorted(lore_syn_ids)})")

    # --- quest (data/quests/, US-616) ---
    # Un lettore di eventi + flag: ogni step e' uno dei 12 eventi (coi filtri
    # validi come le acting_actions) o un flag. giver nel roster; il flag di
    # completamento e' scritto da almeno un dialogo o una quest; ricompense reali.
    quests_dir = os.path.join(DATA, "quests")
    quest_docs = {}
    flag_scritti = set()          # flag scritti da un effetto (dialogo o quest on_complete/ricompensa)
    if os.path.isdir(dlg_dir):
        for fn in os.listdir(dlg_dir):
            dd = load_json(os.path.join(dlg_dir, fn)) or {}
            for nd in dd.get("nodes", {}).values():
                for ch in nd.get("choices", []):
                    for eff in ch.get("effetti", []):
                        if eff.get("tipo") == "flag" and eff.get("valore", True):
                            flag_scritti.add(eff.get("id"))
    if os.path.isdir(quests_dir):
        for fn in sorted(os.listdir(quests_dir)):
            if fn.endswith(".json"):
                q = load_json(os.path.join(quests_dir, fn)) or {}
                quest_docs[q.get("id")] = q
                for st in q.get("steps", []):
                    for eff in st.get("on_complete", []) + q.get("ricompense", []):
                        if eff.get("tipo") == "flag" and eff.get("valore", True):
                            flag_scritti.add(eff.get("id"))
    # US-712: il flag di superamento di una tribolazione dev'essere posto da un
    # dialogo o una quest (nessun verbo nuovo: e' lo stesso contratto delle quest).
    for rel, tid, flag in trib_flags:
        if flag not in flag_scritti:
            err(f"{rel} [{tid}]: superamento.flag '{flag}' non e' scritto da nessun dialogo o quest")

    # US-716: la condizione 'flag' di un finale (eccetto quelli posti dal
    # codice, FLAG_ENDING_ESENTI) deve essere scritta da un dialogo o una quest.
    for rel, eid, flag in ending_flags:
        if flag not in flag_scritti:
            err(f"{rel} [{eid}]: condizione flag '{flag}' non e' scritta da nessun dialogo o quest")

    QUEST_EFF = {"flag", "item", "reputazione", "ancora", "apri_vendita"}
    for qid, q in quest_docs.items():
        rel = f"data/quests/{qid}.json"
        if roster_doc is not None and q.get("giver") not in npc_ids:
            err(f"{rel}: giver '{q.get('giver')}' non e' nel roster")
        for altra in q.get("exclusive_with", []):
            if altra not in quest_docs:
                err(f"{rel}: exclusive_with '{altra}' non e' una quest esistente")
        for st in q.get("steps", []):
            comp = st.get("completamento", {})
            if comp.get("tipo") == "evento":
                ev = comp.get("evento")
                if ev not in events:
                    err(f"{rel} [{st.get('id')}]: evento '{ev}' non e' nel vocabolario dei 12")
                else:
                    allowed = set(events[ev].get("filtri", []))
                    for f in comp.get("filtri", {}):
                        if f not in allowed:
                            err(f"{rel} [{st.get('id')}]: filtro '{f}' non ammesso per '{ev}' "
                                f"(ammessi: {sorted(allowed)})")
            elif comp.get("tipo") == "flag":
                if comp.get("id") not in flag_scritti:
                    err(f"{rel} [{st.get('id')}]: completamento.flag '{comp.get('id')}' non e' "
                        f"scritto da nessun dialogo o quest")
            for eff in st.get("on_complete", []):
                if eff.get("tipo") not in QUEST_EFF:
                    err(f"{rel} [{st.get('id')}]: on_complete effetto '{eff.get('tipo')}' fuori vocabolario")
        for eff in q.get("ricompense", []):
            if eff.get("tipo") not in QUEST_EFF:
                err(f"{rel}: ricompensa effetto '{eff.get('tipo')}' fuori vocabolario ({sorted(QUEST_EFF)})")
            if eff.get("tipo") == "item" and eff.get("item_id") not in item_ids:
                err(f"{rel}: ricompensa item '{eff.get('item_id')}' non e' un item esistente")
            if eff.get("tipo") == "ancora" and roster_doc is not None and eff.get("npc_id") not in npc_ids:
                err(f"{rel}: ricompensa ancora '{eff.get('npc_id')}' non e' nel roster")
    for qid in _dlg_quest_ids:
        if quest_docs and qid not in quest_docs:
            err(f"data/dialogues/: un effetto avvia_quest punta a '{qid}', quest inesistente")

    # --- strutture costruibili (data/structures/, US-319) ---
    struct_dir = os.path.join(DATA, "structures")
    structure_ids = set()
    n_structures = 0
    for fn in sorted(os.listdir(struct_dir)) if os.path.isdir(struct_dir) else []:
        if not fn.endswith(".json"):
            continue
        rel = f"data/structures/{fn}"
        sdoc = load_json(os.path.join(struct_dir, fn)) or {}
        for s in sdoc.get("structures", []):
            sid = s.get("id", "")
            if not sid:
                err(f"{rel}: una struttura non ha 'id'")
                continue
            if sid in structure_ids:
                err(f"{rel}: id struttura duplicato '{sid}'")
            structure_ids.add(sid)
            n_structures += 1
            if not isinstance(s.get("name_i18n"), str) or not s.get("name_i18n"):
                err(f"{rel} [{sid}]: name_i18n mancante o vuoto")
            hp = s.get("hp_max")
            if not isinstance(hp, (int, float)) or hp <= 0:
                err(f"{rel} [{sid}]: hp_max deve essere un numero > 0")
            for t in s.get("tag", []):
                if t not in valid_tags:
                    err(f"{rel} [{sid}]: tag sconosciuto '{t}' (aggiungilo a data/tags.json o correggilo)")
    if n_structures < 1:
        err("data/structures/: nessun tipo di struttura, atteso almeno 1 "
            "(tg_2 e il base building parlano tramite questo registro)")

    # --- specie di pet (data/pets/, US-321) ---
    pet_dir = os.path.join(DATA, "pets")
    pet_ids_seen = set()
    n_pets = 0
    for fn in sorted(os.listdir(pet_dir)) if os.path.isdir(pet_dir) else []:
        if not fn.endswith(".json"):
            continue
        rel = f"data/pets/{fn}"
        pdoc = load_json(os.path.join(pet_dir, fn)) or {}
        for pet in pdoc.get("pets", []):
            pid = pet.get("id", "")
            if not pid:
                err(f"{rel}: un pet non ha 'id'")
                continue
            if pid in pet_ids_seen:
                err(f"{rel}: id pet duplicato '{pid}'")
            pet_ids_seen.add(pid)
            n_pets += 1
            if not isinstance(pet.get("name_i18n"), str) or not pet.get("name_i18n"):
                err(f"{rel} [{pid}]: name_i18n mancante o vuoto")
            hp = pet.get("hp_max")
            if not isinstance(hp, (int, float)) or hp <= 0:
                err(f"{rel} [{pid}]: hp_max deve essere un numero > 0")
            seq = pet.get("sequenza_iniziale")
            if not isinstance(seq, int) or not (0 <= seq <= 9):
                err(f"{rel} [{pid}]: sequenza_iniziale deve essere un intero 0..9")
            dom = pet.get("domabilita")
            if not isinstance(dom, (int, float)) or not (0.0 <= dom <= 1.0):
                err(f"{rel} [{pid}]: domabilita deve essere un numero 0..1")
            anc = pet.get("ancora_id")
            if anc not in anchor_ids:
                err(f"{rel} [{pid}]: ancora_id '{anc}' non risolve a un'Ancora di data/anchors.json "
                    f"(il pet E' un'Ancora)")
            for aid in pet.get("abilita", []):
                if ability_ids and aid not in ability_ids:
                    err(f"{rel} [{pid}]: abilita '{aid}' non risolve a un'abilita' esistente")
            for tg in pet.get("tag", []):
                if tg not in valid_tags:
                    err(f"{rel} [{pid}]: tag sconosciuto '{tg}' (vocabolario chiuso di data/tags.json)")
            for comp in pet.get("comportamenti", []):
                if not isinstance(comp, dict) or not comp.get("id"):
                    err(f"{rel} [{pid}]: comportamento senza 'id'")
                    continue
                b = comp.get("bond")
                if not isinstance(b, int) or not (0 <= b <= 100):
                    err(f"{rel} [{pid}]: comportamento '{comp.get('id')}': bond deve essere 0..100")
                for tg in comp.get("tag", []):
                    if tg not in valid_tags:
                        err(f"{rel} [{pid}]: comportamento '{comp.get('id')}': tag sconosciuto '{tg}'")
            av = pet.get("avanzamento")
            if not isinstance(av, dict) or not av:
                err(f"{rel} [{pid}]: manca 'avanzamento' (soglia_bond + nutrimento + hp_per_sequenza)")
            else:
                sb = av.get("soglia_bond")
                if not isinstance(sb, int) or not (0 <= sb <= 100):
                    err(f"{rel} [{pid}]: avanzamento.soglia_bond deve essere 0..100")
                nut = av.get("nutrimento")
                if nut not in nutre_pet_ids:
                    err(f"{rel} [{pid}]: avanzamento.nutrimento '{nut}' non e' un item con nutre_pet:true")
                hps = av.get("hp_per_sequenza", {})
                if not isinstance(hps, dict) or not hps:
                    err(f"{rel} [{pid}]: avanzamento.hp_per_sequenza mancante")
                for k, v in (hps.items() if isinstance(hps, dict) else []):
                    if not (isinstance(k, str) and k.isdigit() and 0 <= int(k) <= 9):
                        err(f"{rel} [{pid}]: hp_per_sequenza: chiave '{k}' non e' una Sequenza 0..9")
                    if not isinstance(v, (int, float)) or v <= 0:
                        err(f"{rel} [{pid}]: hp_per_sequenza['{k}'] deve essere > 0")
    if n_pets < 1:
        err("data/pets/: nessuna specie di pet, attesa almeno 1")

    # --- base building (data/base/, data/schema/room_types.json, US-326) ---
    ATTESI_ROOM_TYPES = {"laboratorio", "stanza_rituale", "biblioteca", "giardino"}
    rt_doc = load_json(os.path.join(DATA, "schema", "room_types.json")) or {}
    room_tipi = rt_doc.get("tipi", [])
    bonus_ammessi = rt_doc.get("bonus_ammessi", {})
    if set(room_tipi) != ATTESI_ROOM_TYPES:
        err(f"data/schema/room_types.json: 'tipi' deve essere esattamente {sorted(ATTESI_ROOM_TYPES)}, "
            f"e' {sorted(room_tipi)} (vocabolario chiuso)")
    rooms_doc = load_json(os.path.join(DATA, "base", "rooms.json")) or {}
    rooms = rooms_doc.get("rooms", {})
    for tipo in sorted(ATTESI_ROOM_TYPES):
        if tipo not in rooms:
            err(f"data/base/rooms.json: manca la stanza '{tipo}'")
            continue
        room = rooms[tipo]
        rel = "data/base/rooms.json"
        if not isinstance(room.get("name_i18n"), str) or not room.get("name_i18n"):
            err(f"{rel} [{tipo}]: name_i18n mancante o vuoto")
        for tg in room.get("tag", []):
            if tg not in valid_tags:
                err(f"{rel} [{tipo}]: tag sconosciuto '{tg}' (vocabolario chiuso di data/tags.json)")
        livelli = room.get("livelli", [])
        if not isinstance(livelli, list) or not livelli:
            err(f"{rel} [{tipo}]: 'livelli' deve essere una lista non vuota")
            continue
        chiavi_ok = set(bonus_ammessi.get(tipo, []))
        for i, lv in enumerate(livelli, start=1):
            costo = lv.get("costo", {})
            if not isinstance(costo, dict) or not costo:
                err(f"{rel} [{tipo} lv{i}]: 'costo' deve essere un oggetto non vuoto")
            for item_id, q in (costo.items() if isinstance(costo, dict) else []):
                if item_id not in item_ids:
                    err(f"{rel} [{tipo} lv{i}]: costo '{item_id}' non risolve a un item esistente")
                if not isinstance(q, int) or q <= 0:
                    err(f"{rel} [{tipo} lv{i}]: quantita' di '{item_id}' deve essere un intero > 0")
            bon = lv.get("bonus", {})
            if not isinstance(bon, dict) or not bon:
                err(f"{rel} [{tipo} lv{i}]: 'bonus' deve essere un oggetto non vuoto")
            for k, v in (bon.items() if isinstance(bon, dict) else []):
                if k not in chiavi_ok:
                    err(f"{rel} [{tipo} lv{i}]: chiave di bonus '{k}' non ammessa per '{tipo}' "
                        f"({sorted(chiavi_ok)}) - vedi room_types.json")
                if not isinstance(v, (int, float)):
                    err(f"{rel} [{tipo} lv{i}]: bonus '{k}' deve essere numerico")

    # --- pesi del bond (data/balance.json pet_bond, US-323) ---
    pet_bond = (balance_doc or {}).get("pet_bond", {})
    for k in ("per_nemico_sconfitto", "per_area_completata"):
        v = pet_bond.get(k)
        if not isinstance(v, (int, float)) or v < 0:
            err(f"data/balance.json [pet_bond.{k}]: peso mancante o negativo")

    # --- giardino (data/balance.json giardino + ingredienti coltivabili, US-328) ---
    giardino = (balance_doc or {}).get("giardino", {})
    tc = giardino.get("tempo_crescita_s")
    if not isinstance(tc, (int, float)) or tc <= 0:
        err("data/balance.json [giardino.tempo_crescita_s]: deve essere un numero > 0")
    if not isinstance(giardino.get("resa_base"), int) or giardino.get("resa_base", 0) < 1:
        err("data/balance.json [giardino.resa_base]: deve essere un intero >= 1")
    coltivabili = 0
    for fn in sorted(os.listdir(idir)) if os.path.isdir(idir) else []:
        if not fn.endswith(".json"):
            continue
        for it in (load_json(os.path.join(idir, fn)) or {}).get("items", []):
            if "coltivabile" in it:
                if not isinstance(it["coltivabile"], bool):
                    err(f"data/items/{fn} [{it.get('id')}]: 'coltivabile' deve essere true/false")
                if it["coltivabile"]:
                    if it.get("categoria") != "ingrediente":
                        err(f"data/items/{fn} [{it.get('id')}]: coltivabile:true ma non e' "
                            f"categoria:ingrediente (il giardino pianta solo ingredienti)")
                    coltivabili += 1
    if coltivabili < 1:
        err("data/items/: nessun ingrediente con coltivabile:true (il giardino, US-328, "
            "non avrebbe nulla da piantare)")

    # --- talenti (data/talents/, data/schema/tracked_talents.json, US-330) ---
    tt_doc = load_json(os.path.join(DATA, "schema", "tracked_talents.json")) or {}
    tracked_talents = tt_doc.get("talents", {})
    for tk, tv in tracked_talents.items():
        if tv.get("misura") not in ("conteggio", "somma", "secondi"):
            err(f"data/schema/tracked_talents.json [{tk}]: 'misura' deve essere "
                f"conteggio|somma|secondi")
        if not isinstance(tv.get("filtri"), list):
            err(f"data/schema/tracked_talents.json [{tk}]: 'filtri' deve essere una lista")
    # evento di sblocco: uno dei 12 eventi O uno dei comportamenti-talento
    eventi_ok = {}  # nome -> filtri ammessi
    for en, ev in events.items():
        eventi_ok[en] = set(ev.get("filtri", []))
    for tk, tv in tracked_talents.items():
        eventi_ok[tk] = set(tv.get("filtri", []))
    talent_stats = {"hp_max", "spiritualita_max", "velocita", "difesa", "evasione",
                    "precisione", "forza"}
    tal_dir = os.path.join(DATA, "talents")
    tal_ids = set()
    n_innati = n_acquisiti = 0
    for fn in sorted(os.listdir(tal_dir)) if os.path.isdir(tal_dir) else []:
        if not fn.endswith(".json"):
            continue
        rel = f"data/talents/{fn}"
        for t in (load_json(os.path.join(tal_dir, fn)) or {}).get("talents", []):
            tid = t.get("id", "")
            if not tid:
                err(f"{rel}: un talento non ha 'id'")
                continue
            if tid in tal_ids:
                err(f"{rel}: id talento duplicato '{tid}'")
            tal_ids.add(tid)
            for campo in ("name_i18n", "descrizione_i18n"):
                if not isinstance(t.get(campo), str) or not t.get(campo):
                    err(f"{rel} [{tid}]: {campo} mancante o vuoto")
            tipo = t.get("tipo")
            if tipo == "innato":
                n_innati += 1
                if "sblocco" in t:
                    err(f"{rel} [{tid}]: un talento 'innato' non ha 'sblocco'")
            elif tipo == "acquisito":
                n_acquisiti += 1
                sb = t.get("sblocco")
                if not isinstance(sb, dict):
                    err(f"{rel} [{tid}]: un talento 'acquisito' richiede 'sblocco'")
                else:
                    ev = sb.get("evento")
                    if ev not in eventi_ok:
                        err(f"{rel} [{tid}]: sblocco.evento '{ev}' non e' nei 12 eventi ne' "
                            f"nei comportamenti-talento")
                    else:
                        for fk in (sb.get("filtri", {}) or {}):
                            if fk not in eventi_ok[ev]:
                                err(f"{rel} [{tid}]: filtro '{fk}' non ammesso per '{ev}'")
                    if not isinstance(sb.get("target"), (int, float)) or sb.get("target", 0) <= 0:
                        err(f"{rel} [{tid}]: sblocco.target deve essere un numero > 0")
            else:
                err(f"{rel} [{tid}]: 'tipo' deve essere 'innato' o 'acquisito'")
            eff = t.get("effetto", {})
            et = eff.get("tipo")
            if et == "stat_modifier":
                if eff.get("stat") not in talent_stats:
                    err(f"{rel} [{tid}]: effetto.stat '{eff.get('stat')}' non e' una stat nota")
                if not isinstance(eff.get("valore"), (int, float)):
                    err(f"{rel} [{tid}]: effetto.valore deve essere numerico")
                if not isinstance(eff.get("moltiplicativo"), bool):
                    err(f"{rel} [{tid}]: effetto.moltiplicativo deve essere true/false")
            elif et == "tag_grant":
                if eff.get("tag") not in valid_tags:
                    err(f"{rel} [{tid}]: effetto.tag '{eff.get('tag')}' non nel vocabolario chiuso")
            elif et == "sblocco_sistema":
                if not eff.get("sistema") or not eff.get("chiave"):
                    err(f"{rel} [{tid}]: effetto sblocco_sistema richiede 'sistema' e 'chiave'")
            else:
                err(f"{rel} [{tid}]: effetto.tipo '{et}' non e' stat_modifier|tag_grant|sblocco_sistema")
    if n_innati < 4:
        err(f"data/talents/: solo {n_innati} talenti 'innato', attesi >= 4 (la scelta alla "
            f"creazione, US-332)")
    if n_acquisiti < 8:
        err(f"data/talents/: solo {n_acquisiti} talenti 'acquisito', attesi >= 8")
    # US-332: quanti innati si scelgono alla creazione
    n_creaz = (balance_doc or {}).get("talenti", {}).get("innati_alla_creazione")
    if not isinstance(n_creaz, int) or n_creaz < 1:
        err("data/balance.json [talenti.innati_alla_creazione]: deve essere un intero >= 1")
    elif n_creaz > n_innati:
        err(f"data/balance.json [talenti.innati_alla_creazione] = {n_creaz} ma ci sono solo "
            f"{n_innati} talenti 'innato'")

    # --- esiti degli esperimenti (data/potions/experiment_outcomes.json, US-311) ---
    eo_doc = load_json(os.path.join(DATA, "potions", "experiment_outcomes.json"))
    outcomes = (eo_doc or {}).get("outcomes", {})
    EXPECTED_OUTCOMES = {"fumo", "scarto", "ustione", "contaminazione", "aberrazione"}
    if set(outcomes) != EXPECTED_OUTCOMES:
        err(f"data/potions/experiment_outcomes.json: esiti {sorted(outcomes)}, "
            f"attesi {sorted(EXPECTED_OUTCOMES)} (vocabolario chiuso)")
    for name, o in outcomes.items():
        if not isinstance(o.get("peso"), int) or o.get("peso", -1) < 0:
            err(f"data/potions/experiment_outcomes.json [{name}]: peso deve essere un intero >= 0")
        if not isinstance(o.get("mostruoso"), bool):
            err(f"data/potions/experiment_outcomes.json [{name}]: 'mostruoso' deve essere true/false")
        if o.get("produce") is not None and o["produce"] not in item_ids:
            err(f"data/potions/experiment_outcomes.json [{name}]: produce '{o.get('produce')}' non risolve a un item")

    # --- libro / UI (data/ui/book.json, US-221) ---
    pt_doc = load_json(os.path.join(DATA, "schema", "page_types.json"))
    page_types = set((pt_doc or {}).get("page_types", []))
    if len(page_types) != 9:
        err(f"data/schema/page_types.json: vocabolario di {len(page_types)} tipi, attesi 9 "
            f"(design-ui-libro.md + page_dialogo US-613b). Un tipo nuovo e' codice: va discusso.")
    book = load_json(os.path.join(DATA, "ui", "book.json"))
    if book:
        pages = book.get("pages", [])
        seen_ids, seen_ord = Counter(), Counter()
        for p in pages:
            pid = p.get("id")
            seen_ids[pid] += 1
            seen_ord[p.get("ordine")] += 1
            if p.get("tipo") not in page_types:
                err(f"data/ui/book.json [{pid}]: tipo '{p.get('tipo')}' non nel "
                    f"vocabolario chiuso ({sorted(page_types)})")
            if not isinstance(p.get("ordine"), int):
                err(f"data/ui/book.json [{pid}]: 'ordine' mancante o non intero")
            if not isinstance(p.get("name_i18n"), str) or not p.get("name_i18n"):
                err(f"data/ui/book.json [{pid}]: name_i18n mancante o vuoto")
            sb = p.get("sbloccata_da")
            if sb is not None and (not isinstance(sb, dict) or not isinstance(sb.get("fase"), int)):
                err(f"data/ui/book.json [{pid}]: sbloccata_da dev'essere {{'fase': int}}")
        for pid, n in seen_ids.items():
            if n > 1:
                err(f"data/ui/book.json: id pagina duplicato '{pid}'")
        for o, n in seen_ord.items():
            if n > 1:
                err(f"data/ui/book.json: 'ordine' {o} usato da {n} pagine (dev'essere unico)")
        page_id_set = set(seen_ids)
        for b in book.get("segnalibri", []):
            if b not in page_id_set:
                err(f"data/ui/book.json: segnalibro '{b}' non e' una pagina esistente")
        lib = book.get("libro", {})
        if not isinstance(lib.get("voltata_ms"), int) or lib.get("voltata_ms", 0) <= 0:
            err("data/ui/book.json [libro]: voltata_ms dev'essere un intero > 0")
        if not isinstance(lib.get("slot"), int) or not (1 <= lib.get("slot", 0) <= 12):
            err("data/ui/book.json [libro]: slot dev'essere un intero in [1, 12] "
                "(quanti tomi mostra lo scaffale, US-223)")
        # gioco.fase deve esistere: le pagine si sbloccano contro questo numero
        _bg = load_json(os.path.join(DATA, "balance.json"))
        if _bg and not isinstance(_bg.get("gioco", {}).get("fase"), int):
            err("data/balance.json [gioco.fase]: intero mancante. Le pagine del libro "
                "si sbloccano confrontando sbloccata_da.fase con questo valore.")

    # --- i18n dei dati (data/i18n/, US-220 / R-12) ---
    # Ogni chiave *_i18n referenziata dai dati attivi deve avere una voce in
    # data/i18n/it.json. Una chiave che punta nel vuoto e' testo mancante che
    # si scoprirebbe solo a schermo. pathways_deferred/ e schema/ sono fuori
    # scope (Pathway differiti / documentazione del formato).
    i18n_it = load_json(os.path.join(DATA, "i18n", "it.json")) or {}
    skip = {os.path.join(DATA, "schema"), os.path.join(DATA, "i18n"),
            os.path.join(DATA, "pathways_deferred")}
    referenced = {}  # chiave -> primo file che la usa

    def walk_i18n(node, where):
        if isinstance(node, dict):
            for k, v in node.items():
                if k.endswith("_i18n") and isinstance(v, str):
                    referenced.setdefault(v, where)
                else:
                    walk_i18n(v, where)
        elif isinstance(node, list):
            for x in node:
                walk_i18n(x, where)

    for dirpath, dirnames, filenames in os.walk(DATA):
        if any(dirpath == s or dirpath.startswith(s + os.sep) for s in skip):
            dirnames[:] = []
            continue
        for fn in sorted(filenames):
            if fn.endswith(".json"):
                p = os.path.join(dirpath, fn)
                walk_i18n(load_json(p), os.path.relpath(p, ROOT).replace(os.sep, "/"))

    for key, where in sorted(referenced.items()):
        if key not in i18n_it:
            err(f"{where}: chiave i18n '{key}' non ha una voce in data/i18n/it.json. "
                f"Lancia: python tools/generate_i18n_stubs.py")
    orphans = sorted(k for k in i18n_it if k not in referenced)
    if orphans:
        warn(f"data/i18n/it.json: {len(orphans)} chiavi non piu' referenziate dai dati "
             f"(es. {orphans[0]}). Lancia generate_i18n_stubs.py per ripulire.")
    stubs = sum(1 for v in i18n_it.values() if isinstance(v, str) and v.startswith("TODO "))
    if stubs:
        warn(f"data/i18n/it.json: {stubs}/{len(i18n_it)} stringhe ancora da tradurre "
             f"(valore 'TODO ...'). Non e' un errore: e' lavoro di traduzione.")

    # --- VFX (data/vfx.json, US-226) ---
    vfx = load_json(os.path.join(DATA, "vfx.json"))
    if vfx:
        tratto_vocab = set(vfx.get("tratto_vocabolario", []))
        if len(tratto_vocab) != EXPECTED_PATHWAYS:
            err(f"data/vfx.json: tratto_vocabolario ha {len(tratto_vocab)} voci, "
                f"attese {EXPECTED_PATHWAYS} (uno per Pathway attivo — il tratto e' la firma)")
        hex_re = ("inchiostro", "primario", "accento")
        pal = vfx.get("pathway_palette_visiva", {})
        for pid in pathway_ids:
            if not pid:
                continue
            if pid not in pal:
                err(f"data/vfx.json: manca la pathway_palette_visiva per '{pid}' "
                    f"(come il check audio: un Pathway senza palette e' invisibile in gioco)")
                continue
            pv = pal[pid]
            for c in hex_re:
                v = pv.get(c, "")
                if not (isinstance(v, str) and len(v) == 7 and v[0] == "#"
                        and all(ch in "0123456789abcdefABCDEF" for ch in v[1:])):
                    err(f"data/vfx.json [{pid}]: colore '{c}' = '{v}' non e' #rrggbb")
            if pv.get("tratto") not in tratto_vocab:
                err(f"data/vfx.json [{pid}]: tratto '{pv.get('tratto')}' non nel vocabolario chiuso")
        # ogni tratto usato una volta sola: e' la firma del Pathway
        used = [pv.get("tratto") for pv in pal.values() if pv.get("tratto") in tratto_vocab]
        dup_tr = [t for t, n in Counter(used).items() if n > 1]
        if dup_tr:
            err(f"data/vfx.json: tratto condiviso da piu' Pathway {dup_tr} (dev'essere unico)")
        # ogni primitiva ATTIVA e IMPLEMENTATA ha una voce in primitive_vfx
        pvfx = vfx.get("primitive_vfx", {})
        for name, spec in prim_doc["primitives"].items():
            if spec.get("deferred") or not spec.get("implemented"):
                continue
            if name not in pvfx:
                err(f"data/vfx.json: primitiva implementata '{name}' senza voce in primitive_vfx")
            else:
                e = pvfx[name]
                if not isinstance(e.get("frames"), int) or e["frames"] <= 0:
                    err(f"data/vfx.json [primitive_vfx.{name}]: frames dev'essere un intero > 0")
                if not isinstance(e.get("impact_frame"), bool):
                    err(f"data/vfx.json [primitive_vfx.{name}]: impact_frame dev'essere true/false")
        # nessun campo VFX sulle abilita': ability.schema.json non si tocca
        for fn in sorted(os.listdir(adir)) if os.path.isdir(adir) else []:
            if not fn.endswith(".json"):
                continue
            doc = load_json(os.path.join(adir, fn)) or {}
            for ab in (doc if isinstance(doc, list) else doc.get("abilities", [])):
                if any(k.startswith("vfx") for k in ab):
                    err(f"data/abilities/{fn} [{ab.get('id')}]: campo VFX su un'abilita'. "
                        f"I VFX vivono per Pathway + primitiva, mai sull'abilita'.")

    # --- chiusura fase 3 (US-336): ogni file di dati introdotto nella fase
    # deve esistere. Se una story futura ne cancella uno per sbaglio, il
    # validator lo dice subito invece di lasciare un sistema senza dati.
    FASE_3_DATA = [
        "schema/item_categories.json", "schema/equip_slots.json",
        "schema/item.schema.json", "schema/sigil.schema.json",
        "schema/sigil_effect_types.json", "schema/sigillato_effect_types.json",
        "schema/forge_blueprint.schema.json", "schema/structure.schema.json",
        "schema/pet.schema.json", "schema/room_types.json", "schema/room.schema.json",
        "schema/talent.schema.json", "schema/tracked_talents.json",
        "sigils/core.json", "forge/blueprints.json", "structures/core.json",
        "pets/core.json", "base/rooms.json", "talents/core.json",
        "potions/recipes.json", "potions/formulas.json",
        "potions/experiment_outcomes.json", "schema/potion_quality.json",
    ]
    for rel in FASE_3_DATA:
        if not os.path.exists(os.path.join(DATA, rel)):
            err(f"data/{rel}: file di dati della fase 3 mancante (US-336: la fase e' chiusa, "
                f"nessuno di questi file va cancellato)")

    # --- chiusura fase 4 (US-416): i file nuovi della fase devono esistere, e
    # almeno M sinergie devono restare raggiungibili coi gruppi attivi (se
    # scende sotto, una story ha rotto le fonti di tag o le sinergie).
    FASE_4_DATA = [
        "synergies/core.json", "synergies/batch_1.json",
        "synergies/batch_2.json", "synergies/batch_3.json",
        "abilities/synergy.json",
    ]
    for rel in FASE_4_DATA:
        if not os.path.exists(os.path.join(DATA, rel)):
            err(f"data/{rel}: file di dati della fase 4 mancante (US-416: la fase e' chiusa, "
                f"nessuno di questi file va cancellato)")
    if os.path.isdir(sdir):
        raggiungibili = len(syn_ids) - len(unreachable_syns)
        M = 15
        if raggiungibili < M:
            err(f"data/synergies/: solo {raggiungibili} sinergie raggiungibili coi 10 Pathway "
                f"attivi, attese >= {M} (US-416). Una story ha rotto una fonte di tag o una "
                f"richiede_tag.")

    # --- chiusura fase 5 (US-522): i 5 Pathway nuovi hanno tutte e 10 le
    # Sequenze non-stub; ogni primitiva marcata 'implemented' ha un handler
    # (verificato a runtime da tests/test_vfx.gd; qui il controllo di dati).
    FASE_5_DATA = [
        "schema/location_tags.json", "schema/ownership.json",
        "abilities/death.json", "abilities/moon.json", "abilities/mother.json",
        "abilities/paragon.json", "abilities/hermit.json", "synergies/batch_4.json",
    ]
    for rel in FASE_5_DATA:
        if not os.path.exists(os.path.join(DATA, rel)):
            err(f"data/{rel}: file di dati della fase 5 mancante (US-522: la fase e' chiusa).")
    FASE_5_PATHWAY = ["death", "moon", "mother", "paragon", "hermit"]
    for _pid in FASE_5_PATHWAY:
        _pw = load_json(os.path.join(pdir, f"{_pid}.json")) or {}
        _stub = [s.get("sequence") for s in _pw.get("sequences", []) if s.get("stub")]
        if _stub:
            err(f"data/pathways/{_pid}.json: Sequenze ancora stub {sorted(_stub)} - "
                f"la fase 5 e' chiusa, i 5 Pathway devono essere completi (US-522).")
    # ogni primitiva 'implemented' deve avere params dichiarati e non essere differita
    for _name, _spec in prim_doc["primitives"].items():
        if _spec.get("implemented") and _spec.get("deferred"):
            err(f"data/schema/primitives.json [{_name}]: 'implemented' e 'deferred' insieme.")

    # --- chiusura fase 5b (US-5B12): il gruppo Lord of Mysteries e' completo ---
    # Fool/Error/Door a 10/10 Sequenze non-stub; le primitive-firma del gruppo
    # (steal, possess, time_rewind) implementate; nessuna abilita' attiva usa
    # una primitiva differita.
    FASE_5B_PATHWAY = ["fool", "error", "door"]
    for _pid in FASE_5B_PATHWAY:
        _pw = load_json(os.path.join(pdir, f"{_pid}.json")) or {}
        _stub = [s.get("sequence") for s in _pw.get("sequences", []) if s.get("stub")]
        if _stub:
            err(f"data/pathways/{_pid}.json: Sequenze ancora stub {sorted(_stub)} - "
                f"la fase 5b e' chiusa, il gruppo Lord of Mysteries deve essere "
                f"completo (US-5B12).")
    for _name in ("steal", "possess", "time_rewind"):
        if not prim_doc["primitives"].get(_name, {}).get("implemented"):
            err(f"data/schema/primitives.json [{_name}]: primitiva-firma del "
                f"gruppo Lord of Mysteries non marcata 'implemented' (US-5B12).")
    if os.path.exists(os.path.join(DATA, "synergies", "batch_5.json")):
        pass
    else:
        err("data/synergies/batch_5.json: mancante (US-5B12: le sinergie del "
            "gruppo Lord of Mysteries).")
    # nessuna Sequenza stub in tutto il gioco: 100/100 non-stub (US-5B12).
    if stub_count:
        err(f"{stub_count} Sequenze ancora stub su {total_sequences}: con la fase "
            f"5b chiusa il gioco e' a 100/100 Sequenze non-stub (US-5B12).")

    # --- chiusura fase 6 (US-622): il mondo esiste ed e' coerente ---
    # (NON si controlla "zero Sequenze stub": lo fa il check di chiusura fase 5b
    #  qui sopra. Il "22/22 Pathway completi" arriva con la fase 5b.)
    FASE_6_DATA = [
        "world/regions.json", "npc/roster.json", "factions.json",
        "lore/antagonisti.json", "schema/npc.schema.json", "schema/dialogue.schema.json",
        "schema/quest.schema.json", "schema/faction.schema.json", "schema/gate_types.json",
    ]
    for rel in FASE_6_DATA:
        if not os.path.exists(os.path.join(DATA, rel)):
            err(f"data/{rel}: file di dati della fase 6 mancante (US-622: la fase e' chiusa).")
    # ogni dialogue_id del roster ha un file
    if roster_doc is not None and os.path.isdir(dlg_dir):
        _dlg_files = {f[:-5] for f in os.listdir(dlg_dir) if f.endswith(".json")}
        for _npc in roster_doc.get("npcs", []):
            if _npc.get("dialogue_id") not in _dlg_files:
                err(f"data/dialogues/: manca il file per dialogue_id '{_npc.get('dialogue_id')}' "
                    f"dell'NPC '{_npc.get('id')}' (US-622).")
    # le quest di Atto I esistono
    for _qid in ("q_mirco_01", "q_sidon_01", "q_vesna_01", "q_lena_01"):
        if not os.path.exists(os.path.join(DATA, "quests", f"{_qid}.json")):
            err(f"data/quests/{_qid}.json: quest di Atto I mancante (US-622).")

    # --- chiusura fase 7 (US-721): l'endgame esiste ed e' coerente ---
    FASE_7_DATA = [
        "schema/fusion.schema.json", "schema/tribulation.schema.json",
        "schema/ending.schema.json", "schema/tribulation_effects.json",
        "schema/prayer_effects.json", "endings.json",
    ]
    for rel in FASE_7_DATA:
        if not os.path.exists(os.path.join(DATA, rel)):
            err(f"data/{rel}: file di dati della fase 7 mancante (US-721: la fase e' chiusa).")
    if not os.path.isdir(os.path.join(DATA, "fusions")) or not os.listdir(os.path.join(DATA, "fusions")):
        err("data/fusions/: cartella mancante o vuota (US-721).")
    if not os.path.isdir(os.path.join(DATA, "tribulations")) or not os.listdir(os.path.join(DATA, "tribulations")):
        err("data/tribulations/: cartella mancante o vuota (US-721).")
    # door_error e' l'UNICO percorso di fusione completo (US-706): gli altri 7
    # restano stub dichiarati per la fase 7b, il validator li conta (warning).
    _fus_ed = load_json(os.path.join(DATA, "fusions", "door_error.json"))
    if _fus_ed is None:
        err("data/fusions/door_error.json: mancante (US-721: e' il percorso completo).")
    elif bool(_fus_ed.get("stub", False)):
        err("data/fusions/door_error.json: ancora stub - la fase 7 e' chiusa, questo "
            "percorso deve essere completo (US-706/721).")
    _end_doc = load_json(os.path.join(DATA, "endings.json"))
    _end_ids = {e.get("id") for e in (_end_doc or {}).get("endings", [])}
    if _end_ids != {"apoteosi", "consumazione", "rinuncia"}:
        err(f"data/endings.json: attesi esattamente i 3 finali con la fase 7 chiusa, "
            f"trovati {sorted(_end_ids)} (US-721).")

    # --- Pathway Non-Standard (data/pathways_non_standard/, fase 9 US-901) ---
    # Terza categoria, separata da data/pathways/ (10 standard attivi) e
    # data/pathways_deferred/ (12 standard differiti): avanzano per Boon, non
    # per pozione+recitazione (data/schema/boon.schema.json). Non hanno
    # gruppo (fusione/cambio Pathway restano solo fra Pathway standard,
    # US-903) e non contano nell'EXPECTED_PATHWAYS/GROUP_SIZES di sopra:
    # vivono in una cartella diversa, quel codice non li legge mai. La
    # cartella non esiste finche' US-904 non scrive il primo file (Eternal
    # Aeon): nessun errore se assente, e' lo stato atteso di questa story.
    _quest_ids_tutte = set(quest_docs.keys())
    pnsdir = os.path.join(DATA, "pathways_non_standard")
    if os.path.isdir(pnsdir):
        for fn in sorted(f for f in os.listdir(pnsdir) if f.endswith(".json")):
            _doc = load_json(os.path.join(pnsdir, fn))
            if _doc is None:
                continue
            _rel = f"data/pathways_non_standard/{fn}"
            _pid = _doc.get("id")
            if fn != f"{_pid}.json":
                err(f"{_rel}: il nome file non corrisponde all'id '{_pid}'")
            if _doc.get("categoria") != "non_standard":
                err(f"{_rel}: categoria deve essere 'non_standard' (trovato: {_doc.get('categoria')!r})")
            if _doc.get("group") is not None:
                err(f"{_rel}: group deve essere null per un Pathway non_standard "
                    f"(non appartiene a nessun gruppo, US-903).")
            _seqs = _doc.get("sequences", [])
            if len(_seqs) != EXPECTED_SEQUENCES_PER_PATHWAY:
                err(f"{_rel}: {len(_seqs)} sequenze, attese {EXPECTED_SEQUENCES_PER_PATHWAY}")
            _seen_nums = []
            for _seq in _seqs:
                _n = _seq.get("sequence")
                _seen_nums.append(_n)
                _sid = _seq.get("id")
                if _sid != f"{_pid}_{_n}":
                    err(f"{_rel}: id sequenza '{_sid}' non coerente con pathway/numero")
                if _seq.get("tier") not in VALID_TIERS:
                    err(f"{_rel} [{_sid}]: tier non valido '{_seq.get('tier')}'")
                elif _seq.get("tier") != expected_tier(_n):
                    err(f"{_rel} [{_sid}]: tier '{_seq.get('tier')}' errato, atteso '{expected_tier(_n)}'")
                if not _seq.get("name"):
                    err(f"{_rel} [{_sid}]: nome sequenza mancante")
                if len(_seq.get("concept", "")) < 20:
                    err(f"{_rel} [{_sid}]: concept mancante o troppo vago. Ogni sequenza "
                        f"deve dichiarare COSA FA IL GIOCATORE a quel livello.")
                _stub = bool(_seq.get("stub"))
                _has_potion = _seq.get("potion") is not None
                _has_boon = _seq.get("boon") is not None
                if _has_potion:
                    err(f"{_rel} [{_sid}]: 'potion' su un Pathway non_standard - usa 'boon' (US-901).")
                if _stub:
                    if _has_boon:
                        err(f"{_rel} [{_sid}]: marcata stub ma ha un boon: togli il flag o svuotalo.")
                elif not _has_boon:
                    err(f"{_rel} [{_sid}]: nessun 'boon' e nessun flag stub: il giocatore "
                        f"non ha un percorso di avanzamento a questa Sequenza.")
                elif isinstance(_seq.get("boon"), dict):
                    for _e in valida_boon(_rel, _sid, _seq["boon"], events,
                                           _quest_ids_tutte, item_ids, char_ids):
                        err(_e)
            if sorted(_seen_nums, reverse=True) != list(range(9, -1, -1)):
                err(f"{_rel}: le sequenze non coprono esattamente 9..0 "
                    f"(trovate {sorted(_seen_nums, reverse=True)})")

    # --- chiusura fase 8 (US-814): la vertical slice e' giocabile ---
    # "ogni ingrediente attivo ha una fonte" e' gia' il blocco US-809c qui
    # sopra (fonti_trovate/senza fonte): non lo riscrivo.
    _FASE_8_REGIONI = ["mirwada", "marche_crepuscolo", "valle_madre",
                        "archivio_sepolto", "frontiera_porte"]
    for _rid in _FASE_8_REGIONI:
        if not os.path.exists(os.path.join(layouts_dir, f"{_rid}.json")):
            err(f"data/world/layouts/{_rid}.json: layout della fase 8 mancante (US-814: "
                f"le 5 regioni devono avere tutte un layout disegnato a mano).")
        else:
            _lay = load_json(os.path.join(layouts_dir, f"{_rid}.json")) or {}
            _nemici_lay = _lay.get("nemici", [])
            if not any(float(n.get("scala", 1.0)) > 1.0 for n in _nemici_lay if isinstance(n, dict)):
                err(f"data/world/layouts/{_rid}.json: nessun nemico con scala > 1.0 - "
                    f"ogni regione deve avere almeno un boss (US-814/US-806).")

    def _png_size(path):
        try:
            with open(path, "rb") as fh:
                head = fh.read(24)
            if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
                return None
            w, h = struct.unpack(">II", head[16:24])
            return w, h
        except OSError:
            return None

    _PLACEHOLDER = os.path.join(ROOT, "assets", "placeholder")
    _anim_doc = load_json(os.path.join(DATA, "animations.json")) or {}
    _n_direzioni = len((_anim_doc.get("convenzioni", {}) or {}).get("direzioni", [])) or 4
    _fogli_attesi = {}
    for _cat in ("personaggio", "nemico_base", "pet"):
        for _nome, _spec in (_anim_doc.get(_cat, {}) or {}).items():
            _righe = _n_direzioni if _spec.get("direzionale", True) else 1
            _fogli_attesi[f"{_cat}_{_nome}.png"] = (32 * int(_spec.get("frames", 1)), 32 * _righe)
    _fogli_attesi.update({
        "npc_popolano.png": (32, 32 * 6),
        "oggetti.png": (32 * 9, 32),
        "passaggio.png": (32, 32),
        "gate.png": (32, 32),
    })
    if len(_fogli_attesi) != 23:
        err(f"tools/validate_data.py: attesi 19+4=23 fogli sprite, il calcolo ne da' "
            f"{len(_fogli_attesi)} (US-814: data/animations.json e' cambiato?).")
    for _nome_file, (_w_atteso, _h_atteso) in _fogli_attesi.items():
        _path = os.path.join(_PLACEHOLDER, _nome_file)
        if not os.path.exists(_path):
            err(f"assets/placeholder/{_nome_file}: foglio sprite mancante (US-814: la fase 8 "
                f"e' chiusa, i 19+4 fogli devono esistere - rilancia tools/generate_sprites.py).")
            continue
        _dim = _png_size(_path)
        if _dim != (_w_atteso, _h_atteso):
            err(f"assets/placeholder/{_nome_file}: dimensione {_dim}, attesa "
                f"({_w_atteso}, {_h_atteso}) (US-814).")

    report()
    return 1 if errors else 0


def report():
    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}", file=sys.stderr)
    if errors:
        print(f"\n{len(errors)} errori, {len(warnings)} warning. VALIDAZIONE FALLITA.", file=sys.stderr)
    else:
        print(f"\nOK. {len(warnings)} warning, 0 errori.")


if __name__ == "__main__":
    sys.exit(main())
