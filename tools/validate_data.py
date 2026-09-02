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
        for tid, t in audio.get("telegraph", {}).items():
            if tid.startswith("_"):
                continue
            if not t.get("anticipo_ms", 0) > 0:
                err(f"data/audio.json [telegraph.{tid}]: anticipo_ms deve essere > 0, "
                    f"altrimenti il tell suona insieme all'impatto ed e' inutile.")
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
