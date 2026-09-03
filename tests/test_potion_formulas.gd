extends "res://tests/test_case.gd"
## US-208 — formule delle pozioni: dati, formula completa vs parziale.

func _gd() -> Node:
	return Engine.get_main_loop().root.get_node("GameData")


func test_formule_caricate() -> void:
	var f: Dictionary = _gd().call("get_formula", "formula_twilight_giant_5")
	assert_false(f.is_empty(), "formula_twilight_giant_5 caricata")
	assert_eq(int(f["characteristic_sequence"]), 5, "characteristic_sequence")
	assert_eq((f["ingredients"] as Array).size(), 3, "tre ingredienti completi")
	assert_true(f.has("soglia_parziale"), "soglia parziale dichiarata")
	assert_false((f["penalita_parziale"] as Dictionary).is_empty(), "penalita parziale esplicita nei dati")


func test_formula_inesistente() -> void:
	assert_true((_gd().call("get_formula", "formula_che_non_esiste") as Dictionary).is_empty(),
		"formula ignota -> {}")


func test_vocabolario_ingredienti_copre_le_formule() -> void:
	var vocab: Array = _gd().call("ingredient_ids")
	assert_gt(float(vocab.size()), 0.0, "vocabolario ingredienti non vuoto")
	for fid in ["formula_twilight_giant_9", "formula_twilight_giant_5", "formula_twilight_giant_0"]:
		var f: Dictionary = _gd().call("get_formula", fid)
		for ing in (f.get("ingredients", []) as Array):
			assert_true(vocab.has(ing), "ingrediente '%s' nel vocabolario" % ing)


func test_soglia_parziale_e_coerente() -> void:
	# soglia_parziale: si puo' fare la pozione con almeno N ingredienti;
	# sotto soglia no. Per le formule a 3 ingredienti, soglia 2.
	var f: Dictionary = _gd().call("get_formula", "formula_twilight_giant_9")
	var n: int = (f["ingredients"] as Array).size()
	var soglia: int = int(f["soglia_parziale"])
	assert_true(soglia >= 1 and soglia <= n, "soglia fra 1 e numero ingredienti")
	assert_true(soglia < n, "soglia < completo: una pozione parziale e' possibile")


func test_ogni_sequenza_non_stub_del_tg_ha_una_formula() -> void:
	# Le 10 Sequenze del Twilight Giant sono tutte piene.
	for seq in range(0, 10):
		var f: Dictionary = _gd().call("get_formula", "formula_twilight_giant_%d" % seq)
		assert_false(f.is_empty(), "formula per la Sequenza %d" % seq)
		assert_eq(int(f["characteristic_sequence"]), seq, "characteristic_sequence = %d" % seq)
