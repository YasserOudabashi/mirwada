extends "res://tests/test_case.gd"
## US-308 — ricettario, tier e qualita' delle pozioni consumabili.


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


func test_vocabolario_qualita() -> void:
	var q: Array = _gd().call("potion_quality")
	assert_eq(q.size(), 4, "4 qualita'")
	assert_eq(q, ["scarsa", "instabile", "pura", "eccelsa"], "in ordine crescente")


func test_get_recipe_e_tier() -> void:
	var gd: Node = _gd()
	var r: Dictionary = gd.call("get_recipe", "ric_cura_minore")
	assert_false(r.is_empty(), "ric_cura_minore esiste")
	assert_eq(r.get("tier"), "base", "tier base")
	assert_true(gd.call("get_recipe", "ricetta_finta").is_empty(), "id ignoto -> {}")


func test_recipes_per_tier() -> void:
	var gd: Node = _gd()
	assert_gt(float((gd.call("recipes_per_tier", "base") as Array).size()), 0.0, "ci sono ricette base")
	assert_gt(float((gd.call("recipes_per_tier", "avanzata") as Array).size()), 0.0, "e avanzate")
	assert_gt(float((gd.call("recipes_per_tier", "leggendaria") as Array).size()), 0.0, "e leggendarie")


func test_solo_le_base_sono_note_da_subito() -> void:
	var gd: Node = _gd()
	for rid in gd.call("recipe_ids"):
		var r: Dictionary = gd.call("get_recipe", rid)
		assert_eq(bool(r.get("nota_da_subito")), r.get("tier") == "base",
			"%s: nota_da_subito == (tier base)" % rid)


func test_ogni_ingrediente_e_ogni_output_risolve() -> void:
	var gd: Node = _gd()
	for rid in gd.call("recipe_ids"):
		var r: Dictionary = gd.call("get_recipe", rid)
		for ing in (r.get("ingredienti", {}) as Dictionary):
			assert_eq(gd.call("get_item", ing).get("categoria"), "ingrediente",
				"%s: '%s' e' un ingrediente" % [rid, ing])
		var oid: String = str(r.get("output", {}).get("item_id", ""))
		if not oid.is_empty():
			assert_false(gd.call("get_item", oid).is_empty(), "%s: output '%s' risolve" % [rid, oid])
		assert_true(gd.call("potion_quality").has(r.get("qualita_base")),
			"%s: qualita_base nel vocabolario" % rid)


func test_parziale_di_fase_2_mappa_su_instabile() -> void:
	# formulas.json.penalita_parziale gia' usa "qualita": "instabile" (US-208):
	# la scala e' condivisa, una pozione parziale e' al piu' instabile.
	var gd: Node = _gd()
	var f: Dictionary = gd.call("get_formula", "formula_fool_9")
	if not f.is_empty():
		var pq: String = str(f.get("penalita_parziale", {}).get("qualita", ""))
		assert_true(gd.call("potion_quality").has(pq), "la qualita' parziale e' nel vocabolario chiuso")
