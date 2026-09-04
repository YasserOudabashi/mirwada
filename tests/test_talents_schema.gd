extends "res://tests/test_case.gd"
## US-330 — schema dei talenti e vocabolario dei comportamenti.


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


func test_vocabolario_comportamenti() -> void:
	var gd: Node = _gd()
	assert_eq((gd.call("tracked_talents") as Dictionary).size(), 7, "7 comportamenti-talento")
	assert_false(gd.call("get_tracked_talent", "ingredienti_coltivati").is_empty(), "esiste")
	assert_true(gd.call("get_tracked_talent", "comportamento_inventato").is_empty(), "id ignoto -> {}")


func test_get_talent() -> void:
	var gd: Node = _gd()
	var t: Dictionary = gd.call("get_talent", "forza_innata")
	assert_false(t.is_empty(), "forza_innata esiste")
	assert_eq(t.get("tipo"), "innato", "tipo corretto")
	assert_true(gd.call("get_talent", "talento_inventato").is_empty(), "id ignoto -> {}")


func test_almeno_4_innati_e_8_acquisiti() -> void:
	var gd: Node = _gd()
	assert_gt(float((gd.call("talents_per_tipo", "innato") as Array).size()), 3.0, ">= 4 innati")
	assert_gt(float((gd.call("talents_per_tipo", "acquisito") as Array).size()), 7.0, ">= 8 acquisiti")


func test_ogni_i18n_dei_talenti_risolve() -> void:
	var gd: Node = _gd()
	var rotte: Array = []
	for tid in gd.call("talent_ids"):
		var t: Dictionary = gd.call("get_talent", tid)
		for campo in ["name_i18n", "descrizione_i18n"]:
			var k: String = str(t.get(campo, ""))
			if not k.is_empty() and gd.call("tr_data", k) == k and not gd.call("has_translation", k):
				rotte.append(k)
	assert_eq(rotte.size(), 0, "chiavi i18n dei talenti che non risolvono: %s" % [rotte])
