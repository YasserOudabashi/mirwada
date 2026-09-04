extends "res://tests/test_case.gd"
## US-315 — schema dei sigilli.


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


func test_almeno_8_sigilli() -> void:
	assert_gt(float((_gd().call("sigil_ids") as Array).size()), 7.0, ">= 8 sigilli")


func test_get_sigil() -> void:
	var gd: Node = _gd()
	var s: Dictionary = gd.call("get_sigil", "sig_forza_1")
	assert_false(s.is_empty(), "sig_forza_1 esiste")
	assert_eq((s.get("effetto", {}) as Dictionary).get("tipo"), "stat_modifier", "effetto tipizzato")
	assert_true(gd.call("get_sigil", "sig_inventato").is_empty(), "id ignoto -> {}")


func test_vocabolario_effetti() -> void:
	var tipi: Array = _gd().call("sigil_effect_types")
	for t in ["stat_modifier", "stored_ability_id", "tag_grant"]:
		assert_true(tipi.has(t), "'%s' nel vocabolario dei tipi di effetto" % t)


func test_almeno_2_con_effetto_collaterale() -> void:
	var gd: Node = _gd()
	var n: int = 0
	for sid in gd.call("sigil_ids"):
		if not (gd.call("get_sigil", sid) as Dictionary).get("effetto_collaterale", {}).is_empty():
			n += 1
	assert_gt(float(n), 1.0, ">= 2 sigilli con effetto_collaterale")


func test_ogni_sigillo_item_risolve_al_suo_sigil_ref() -> void:
	var gd: Node = _gd()
	for it in gd.call("items_per_categoria", "sigillo"):
		var d: Dictionary = it
		var ref: String = str(d.get("sigillo_ref", ""))
		assert_false(gd.call("get_sigil", ref).is_empty(),
			"%s: sigillo_ref '%s' risolve" % [d.get("id"), ref])


func test_ogni_name_i18n_dei_sigilli_risolve() -> void:
	var gd: Node = _gd()
	var rotte: Array = []
	for sid in gd.call("sigil_ids"):
		var k: String = str((gd.call("get_sigil", sid) as Dictionary).get("name_i18n", ""))
		if not k.is_empty() and gd.call("tr_data", k) == k and not gd.call("has_translation", k):
			rotte.append(k)
	assert_eq(rotte.size(), 0, "chiavi i18n dei sigilli che non risolvono: %s" % [rotte])
