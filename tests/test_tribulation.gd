extends "res://tests/test_case.gd"
## US-710 — tribulation.schema.json + data/tribulations/: una prova per salto
## di fascia (7->6, 5->4, 3->2, 1->0). Il motore e' US-711.

const SALTI := {7: 6, 5: 4, 3: 2, 1: 0}


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node("GameData")


func _effetti_validi() -> Array:
	var doc: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/schema/tribulation_effects.json"))
	return (doc.get("effetti", {}) as Dictionary).keys()


func _dodici_eventi() -> Array:
	var doc: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/schema/tracked_events.json"))
	return (doc.get("events", {}) as Dictionary).keys()


func test_una_tribolazione_per_ogni_salto_di_fascia() -> void:
	var gd: Node = _gd()
	var visti: Array = []
	for da in SALTI:
		var t: Dictionary = gd.call("tribulation_per_salto", da)
		assert_false(t.is_empty(), "tribolazione per il salto %d->%d" % [da, SALTI[da]])
		assert_eq(int(t.get("salto", {}).get("a", -1)), SALTI[da], "salto.a coerente per %d" % da)
		visti.append(str(t.get("id")))
	assert_eq(visti.size(), 4, "4 tribolazioni distinte")
	# un salto che non e' di fascia non ha tribolazione
	assert_true((gd.call("tribulation_per_salto", 8) as Dictionary).is_empty(), "8->7 non e' un salto di fascia")
	assert_true((gd.call("tribulation_per_salto", 2) as Dictionary).is_empty(), "2->1 non e' un salto di fascia")


func test_ogni_tribolazione_risolve_i_suoi_riferimenti() -> void:
	var gd: Node = _gd()
	var effetti: Array = _effetti_validi()
	var eventi: Array = _dodici_eventi()
	for tid in gd.call("tribulation_ids"):
		var t: Dictionary = gd.call("get_tribulation", tid)
		assert_true(str(t.get("name_i18n", "")).begins_with("tribulation."), "%s: name_i18n" % tid)
		assert_true(t.get("mentre_in_corso") in effetti,
			"%s: mentre_in_corso '%s' nel vocabolario" % [tid, t.get("mentre_in_corso")])
		var sup: Dictionary = t.get("superamento", {})
		var has_ev: bool = sup.has("evento")
		var has_flag: bool = sup.has("flag")
		assert_true(has_ev != has_flag, "%s: superamento e' evento XOR flag" % tid)
		if has_ev:
			assert_true(sup["evento"] in eventi, "%s: evento nei 12 tracciati" % tid)
			assert_gt(float(sup.get("target", 0)), 0.0, "%s: target >= 1" % tid)
		else:
			assert_false(str(sup["flag"]).is_empty(), "%s: flag non vuoto" % tid)


# --- US-712: contenuto (i18n + flag posti da dialoghi) -----------------

func test_ogni_tribolazione_e_tradotta_e_le_condizioni_sono_valide() -> void:
	var gd: Node = _gd()
	for tid in gd.call("tribulation_ids"):
		var t: Dictionary = gd.call("get_tribulation", tid)
		for k in [str(t.get("name_i18n")), str(t.get("descrizione_i18n"))]:
			assert_true(gd.call("has_translation", k), "%s: '%s' tradotta (non TODO)" % [tid, k])
		# le condizioni sono nel vocabolario di conditions.gd (Conditions le valuta)
		for c in (t.get("condizioni", []) as Array):
			assert_false(str((c as Dictionary).get("tipo", "")).is_empty(), "%s: condizione con un tipo" % tid)


func test_i_flag_di_superamento_sono_posti_da_un_dialogo() -> void:
	# I due flag (Doran e l'antagonista) devono essere scritti da un effetto
	# 'flag' in un grafo di dialogo: nessun verbo nuovo.
	var flag_scritti: Dictionary = {}
	for did in ["dlg_doran", "dlg_antagonista"]:
		var dlg: Dictionary = _gd().call("get_dialogue", did)
		for nodo in (dlg.get("nodes", {}) as Dictionary).values():
			for ch in ((nodo as Dictionary).get("choices", []) as Array):
				for eff in ((ch as Dictionary).get("effetti", []) as Array):
					if str((eff as Dictionary).get("tipo", "")) == "flag":
						flag_scritti[str((eff as Dictionary).get("id", ""))] = true
	for tid in _gd().call("tribulation_ids"):
		var sup: Dictionary = _gd().call("get_tribulation", tid).get("superamento", {})
		if sup.has("flag"):
			assert_true(flag_scritti.has(str(sup["flag"])),
				"%s: il flag '%s' e' posto da un dialogo" % [tid, sup["flag"]])
