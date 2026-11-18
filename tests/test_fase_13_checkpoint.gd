extends "res://tests/test_case.gd"
## US-1312 — IL CHECKPOINT DELLA FASE 13 (Atto II e III). Stesso schema dei checkpoint delle fasi 5-11:
## i contenuti nuovi esistono e puntano solo a id validi, e il motore non nomina niente di specifico (Pathway,
## NPC, quest, flag della storia): le liste dei nomi vietati si leggono dai dati.
## I compagni giocati con Xvfb sono tests/manual/qa_atto_2.gd e qa_atto_3.gd (fuori dalla suite headless).

const QUEST_DELLA_FASE := ["q_ottavia_02", "q_bruno_02", "q_lena_02", "q_lena_03"]
const SCENE_DELLA_FASE := {"dlg_doran": "n4", "dlg_lena": "n4", "dlg_vesna": "n4", "dlg_ottavia": "n3",
	"dlg_bruno": "n3", "dlg_aldo_vinto": "n1", "dlg_aldo_perso": "n1"}

func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")


## Tutti i flag che un dialogo o una quest scrive.
func _flag_scritti() -> Dictionary:
	var out: Dictionary = {}
	for f in DirAccess.get_files_at("res://data/dialogues"):
		var d: Dictionary = _gd().call("get_dialogue", f.trim_suffix(".json"))
		for n in (d.get("nodes", {}) as Dictionary).values():
			for c in (n as Dictionary).get("choices", []):
				for e in (c as Dictionary).get("effetti", []):
					if str((e as Dictionary).get("tipo", "")) == "flag":
						out[str(e["id"])] = true
	for f in DirAccess.get_files_at("res://data/quests"):
		var q: Dictionary = _gd().call("get_quest", f.trim_suffix(".json"))
		for s in q.get("steps", []):
			for e in (s as Dictionary).get("on_complete", []) + q.get("ricompense", []):
				if str((e as Dictionary).get("tipo", "")) == "flag":
					out[str(e["id"])] = true
	return out


func test_le_quest_della_fase_esistono_e_puntano_a_id_validi() -> void:
	var scritti: Dictionary = _flag_scritti()
	for qid in QUEST_DELLA_FASE:
		var q: Dictionary = _gd().call("get_quest", qid)
		assert_false(q.is_empty(), "%s esiste" % qid)
		assert_true(int(q.get("atto", 1)) >= 2, "%s e' dell'Atto II o III" % qid)
		assert_false((_gd().call("get_npc", str(q.get("giver", ""))) as Dictionary).is_empty(), "%s: il giver e' nel roster" % qid)
		for s in q.get("steps", []):
			var c: Dictionary = (s as Dictionary).get("completamento", {})
			if str(c.get("tipo", "")) == "evento":
				assert_false((_gd().call("get_tracked_event", str(c.get("evento", ""))) as Dictionary).is_empty(),
					"%s: l'evento %s e' fra i 12" % [qid, c.get("evento")])
			else:
				assert_true(scritti.has(str(c.get("id", ""))), "%s: il flag %s lo scrive qualcuno" % [qid, c.get("id")])
		for altra in q.get("exclusive_with", []):
			assert_false((_gd().call("get_quest", str(altra)) as Dictionary).is_empty(), "%s: %s esiste" % [qid, altra])


func test_le_scene_della_fase_esistono_e_i_loro_flag_tornano() -> void:
	var scritti: Dictionary = _flag_scritti()
	for did in SCENE_DELLA_FASE:
		var d: Dictionary = _gd().call("get_dialogue", did)
		var nodi: Dictionary = d.get("nodes", {})
		assert_true(nodi.has(SCENE_DELLA_FASE[did]), "%s ha la scena %s" % [did, SCENE_DELLA_FASE[did]])
		for nid in nodi:
			for c in (nodi[nid] as Dictionary).get("choices", []):
				var goto: Variant = (c as Dictionary).get("goto")
				assert_true(goto == null or nodi.has(str(goto)), "%s.%s: goto %s esiste" % [did, nid, goto])
				for cond in (c as Dictionary).get("condizioni", []):
					if str((cond as Dictionary).get("tipo", "")) in ["flag", "flag_assente"]:
						assert_true(scritti.has(str(cond["valore"])), "%s.%s: il flag %s lo scrive qualcuno" % [did, nid, cond["valore"]])
				for e in (c as Dictionary).get("effetti", []):
					if str((e as Dictionary).get("tipo", "")) == "avvia_quest":
						assert_false((_gd().call("get_quest", str(e["quest_id"])) as Dictionary).is_empty(), "%s: la quest %s esiste" % [did, e["quest_id"]])
	var aldo: Dictionary = (_gd().call("get_npc", "npc_aldo") as Dictionary).get("duello", {})
	for k in ["dialogo_vinto", "dialogo_perso"]:
		assert_false((_gd().call("get_dialogue", str(aldo.get(k, ""))) as Dictionary).is_empty(), "il duello ha il suo %s" % k)


func test_nessun_codice_nomina_pathway_npc_quest_o_flag_della_storia() -> void:
	var vietati: Array = []
	for pid in _gd().call("pathway_ids"):
		vietati.append("\"%s\"" % pid)
	for n in _gd().call("get_npcs"):
		vietati.append("\"%s\"" % str((n as Dictionary).get("id", "")))
	for qid in QUEST_DELLA_FASE:
		vietati.append("\"%s\"" % qid)
	for f in _flag_scritti():
		if not f.begins_with("tribolazione_"):        # i flag delle prove li legge TribulationSystem dai dati
			vietati.append("\"%s\"" % f)
	var colpevoli: PackedStringArray = []
	for dir in ["res://scripts", "res://scripts/pages", "res://scripts/world"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var righe: PackedStringArray = FileAccess.get_file_as_string(dir + "/" + f).split("\n")
			for i in righe.size():
				var codice: String = righe[i].split("##")[0].split("#")[0]
				for v in vietati:
					if codice.contains(v) and not (v == "\"death\"" and codice.contains("riproduci")):   # lo stato d'animazione
						colpevoli.append("%s:%d %s" % [f, i + 1, righe[i].strip_edges()])
	assert_eq(colpevoli.size(), 0, "nessun Pathway, NPC, quest o flag della storia nel codice (checkpoint fase 13): %s" % colpevoli)


func test_le_partite_giocate_dell_atto_ii_e_iii_ci_sono() -> void:
	for f in ["qa_atto_2.gd", "qa_atto_3.gd"]:
		assert_true(FileAccess.file_exists("res://tests/manual/" + f), "tests/manual/%s c'e'" % f)
