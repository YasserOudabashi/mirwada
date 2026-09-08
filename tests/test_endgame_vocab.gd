extends "res://tests/test_case.gd"
## US-703 — i due vocabolari chiusi della fase 7: tribulation_effects.json
## (cosa fa una tribolazione mentre e' in corso) e prayer_effects.json (gli
## effetti semantici delle preghiere, ognuno appoggiato a una primitiva
## esistente). Nessuna primitiva nuova.


func _json(path: String) -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if typeof(v) == TYPE_DICTIONARY else {}


func test_tribulation_effects_chiuso_e_non_vuoto() -> void:
	var d: Dictionary = _json("res://data/schema/tribulation_effects.json")
	var eff: Dictionary = d.get("effetti", {})
	assert_gt(float(eff.size()), 0.0, "tribulation_effects ha almeno una voce")
	assert_true(eff.size() <= 6, "vocabolario chiuso: <= 6 voci")
	for k in eff:
		assert_true((eff[k] as Dictionary).has("_comment"), "%s ha un _comment" % k)


func test_prayer_effects_si_appoggiano_a_primitive_esistenti() -> void:
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	var d: Dictionary = _json("res://data/schema/prayer_effects.json")
	var pr: Dictionary = d.get("preghiere", {})
	assert_gt(float(pr.size()), 0.0, "prayer_effects ha almeno una voce")
	assert_true(pr.size() <= 6, "vocabolario chiuso: <= 6 voci")
	for k in pr:
		var prim: String = str((pr[k] as Dictionary).get("primitiva", ""))
		assert_false(gd.call("get_primitive", prim).is_empty(),
			"la preghiera '%s' si appoggia alla primitiva esistente '%s'" % [k, prim])
