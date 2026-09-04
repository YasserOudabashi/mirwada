extends "res://tests/test_case.gd"
## US-315 — schema dei sigilli.


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


func test_almeno_8_sigilli() -> void:
	var gd: Node = _gd()
	assert_gt(float((gd.call("sigil_ids") as Array).size()), 7.0, ">= 8 sigilli")


func test_get_sigil_e_id_ignoto() -> void:
	var gd: Node = _gd()
	var s: Dictionary = gd.call("get_sigil", "sig_forza_1")
	assert_false(s.is_empty(), "sig_forza_1 esiste")
	assert_eq(s.get("effetto", {}).get("tipo"), "stat_modifier", "effetto stat_modifier")
	assert_true(gd.call("get_sigil", "sig_che_non_esiste").is_empty(), "id ignoto -> {}")


func test_almeno_due_sigilli_con_effetto_collaterale() -> void:
	var gd: Node = _gd()
	var n := 0
	for sid in gd.call("sigil_ids"):
		var s: Dictionary = gd.call("get_sigil", sid)
		if s.has("effetto_collaterale"):
			n += 1
	assert_gt(float(n), 1.0, ">= 2 sigilli con effetto_collaterale")


func test_effetto_collaterale_e_sempre_uno_svantaggio() -> void:
	var gd: Node = _gd()
	for sid in gd.call("sigil_ids"):
		var s: Dictionary = gd.call("get_sigil", sid)
		var c: Dictionary = s.get("effetto_collaterale", {})
		if c.is_empty():
			continue
		if c.get("tipo") == "stat_modifier":
			assert_true(float(c.get("valore", 0)) < 0.0, "%s: il collaterale peggiora la stat" % sid)


func test_stored_ability_id_del_sigillo_risolve() -> void:
	var gd: Node = _gd()
	var s: Dictionary = gd.call("get_sigil", "sig_eco_lama")
	var ability_id: String = str(s.get("effetto", {}).get("ability_id", ""))
	assert_false(gd.call("get_ability", ability_id).is_empty(), "l'abilita' del sigillo esiste")


func test_ogni_item_sigillo_referenzia_un_sigillo_esistente() -> void:
	var gd: Node = _gd()
	for it in gd.call("items_per_categoria", "sigillo"):
		var sref: String = str((it as Dictionary).get("sigillo_ref", ""))
		assert_false(sref.is_empty(), "%s: sigillo_ref presente" % (it as Dictionary).get("id"))
		assert_false(gd.call("get_sigil", sref).is_empty(),
			"%s: sigillo_ref '%s' risolve" % [(it as Dictionary).get("id"), sref])
