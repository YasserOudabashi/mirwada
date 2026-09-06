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
        if not isinstance(doc.get("gameplay_verb"), str) or len(doc.get("gameplay_verb", "")) < 10:
            err(f"{rel}: gameplay_verb mancante o troppo generico")
        for t in doc.get("tags", []):
            if t not in valid_tags:
                err(f"{rel}: tag di pathway sconosciuto '{t}' (aggiungilo a data/tags.json o correggilo)")
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

            for aid in seq.get("abilities", []):
                ability_refs.append((rel, sid, aid))

            # US-208: le pozioni non-stub devono puntare a una formula valida
            pot = seq.get("potion", {})
            if not stub and pot.get("formula_id"):
                potion_refs.append((rel, sid, n, pot))

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
            if seq.get("acting_actions") and total_prog < 0.999:  # tolleranza virgola mobile
                err(f"{rel} [{sid}]: le acting_actions sommano a {total_prog:.2f} < 1.0: "
                    f"il giocatore non puo' completare la recitazione e resta bloccato qui per sempre.")
            if seq.get("acting_actions") and total_prog > 1.001:
                warn(f"{rel} [{sid}]: le acting_actions sommano a {total_prog:.2f} > 1.0: "
                     f"il surplus rende saltabile l'azione meno comoda. Se non e' voluto, riporta la somma a 1.0.")

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

    for name, values in (("pathway", pathway_ids), ("sequenza", sequence_ids)):
        dupes = [k for k, v in Counter(values).items() if v > 1]
        if dupes:
            err(f"id {name} duplicati: {dupes}")

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
                        if not isinstance(p.get("entita_id"), str) or not p.get("entita_id"):
                            err(f"{rel} [{aid}]: summon senza entita_id (la fonte dell'evocazione)")
                        dur = p.get("durata")
                        if dur == 0 or dur is None:
                            err(f"{rel} [{aid}]: summon.durata deve essere -1 (persistente) o > 0 "
                                f"(temporanea), mai 0")
                    td = p.get("tag_danno")
                    if td is not None and td not in valid_damage_tags:
                        err(f"{rel} [{aid}]: tag_danno '{td}' non nel vocabolario "
                            f"di data/schema/damage_tags.json")
                    for tb in p.get("tag_bloccati", []):
                        if tb not in valid_damage_tags:
                            err(f"{rel} [{aid}]: tag_bloccati contiene '{tb}', non nel "
                                f"vocabolario di data/schema/damage_tags.json")
                for t in ab.get("tag_sinergia", []):
                    if t not in valid_tags:
                        err(f"{rel} [{aid}]: tag sconosciuto '{t}'")
                    obtainable_tags.add(t)
                if not ab.get("tag_sinergia"):
                    err(f"{rel} [{aid}]: nessun tag_sinergia. Un'abilita' senza tag e' invisibile al motore delle sinergie.")

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
    # ogni Sequenza non-stub in scope (twilight_giant) deve avere la sua Caratteristica
    tg_path = os.path.join(pdir, "twilight_giant.json")
    tg = load_json(tg_path)
    if tg:
        for s in tg.get("sequences", []):
            if s.get("stub"):
                continue
            cs = s.get("potion", {}).get("characteristic_sequence")
            if cs is not None and ("twilight_giant", cs) not in char_by_ps:
                err(f"data/pathways/twilight_giant.json [{s.get('id')}]: manca la Caratteristica "
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

    # --- sinergie ---
    sdir = os.path.join(DATA, "synergies")
    if os.path.isdir(sdir):
        syn_ids = set()
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
                for t in list(syn.get("richiede_tag", {})) + list(syn.get("esclude_tag", {})):
                    if t not in valid_tags:
                        err(f"{rel} [{sid}]: tag sconosciuto '{t}'")
                if len(set(syn.get("fonti", []))) < 2:
                    err(f"{rel} [{sid}]: una sinergia deve pescare da almeno 2 fonti diverse "
                        f"(pilastro di design: le sinergie attraversano i sistemi)")
                # L'output della sinergia deve esistere: un'abilita' fantasma si
                # scoprirebbe solo al momento in cui il giocatore la sblocca.
                eff = syn.get("effetto", {})
                if eff.get("tipo") == "aggiungi_abilita" and not syn.get("stub"):
                    if eff.get("ability_id") not in ability_ids:
                        err(f"{rel} [{sid}]: effetto aggiunge l'abilita' inesistente "
                            f"'{eff.get('ability_id')}'. Scrivila, o marca la sinergia \"stub\": true.")
                irraggiungibili = [t for t in syn.get("richiede_tag", {})
                                   if t in valid_tags and t not in obtainable_tags]
                if irraggiungibili:
                    warn(f"{rel} [{sid}]: richiede i tag {irraggiungibili} che nessun pathway "
                         f"attivo porta: sinergia irraggiungibile finche' il suo gruppo resta differito.")

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
            for comp in pet.get("comportamenti", []):
                if not isinstance(comp, dict) or not comp.get("id"):
                    err(f"{rel} [{pid}]: comportamento senza 'id'")
                    continue
                b = comp.get("bond")
                if not isinstance(b, int) or not (0 <= b <= 100):
                    err(f"{rel} [{pid}]: comportamento '{comp.get('id')}': bond deve essere 0..100")
    if n_pets < 1:
        err("data/pets/: nessuna specie di pet, attesa almeno 1")

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
    if len(page_types) != 8:
        err(f"data/schema/page_types.json: vocabolario di {len(page_types)} tipi, attesi 8 "
            f"(design-ui-libro.md). Un tipo nuovo e' codice: va discusso.")
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
