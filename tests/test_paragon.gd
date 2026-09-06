extends "res://tests/test_case.gd"
## US-515/516/517 — Paragon: le abilita' eseguono senza warning (reveal_info
## gia' implementata in US-505), le acting sommano 1.0, paragon_1 non usa
## rule_bind (primitiva differita).

const Stats := preload("res://scripts/stats_component.gd")


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node("GameData")


func prepara() -> void:
	var e: Node = _engine()
	if e != null:
		e.call("clear_cooldowns")
		e.call("flush_effects")
	var ws: Node = Engine.get_main_loop().root.get_node_or_null("WorldState")
	if ws != null:
		ws.call("pulisci")


func _caster() -> Node2D:
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	Engine.get_main_loop().root.add_child(c)
	s.call("configure_from_balance", 8)
	return c


func _cleanup(c: Node) -> void:
	Engine.get_main_loop().root.remove_child(c)
	c.free()


func test_ogni_abilita_paragon_non_stub_si_esegue_senza_warning() -> void:
	var e: Node = _engine()
	var pw: Dictionary = _gd().call("get_pathway", "paragon")
	var provate := 0
	for seq in (pw.get("sequences", []) as Array):
		if bool((seq as Dictionary).get("stub", false)):
			continue
		for aid in ((seq as Dictionary).get("abilities", []) as Array):
			var c: Node2D = _caster()
			c.get_node("Stats").set("spiritualita", 9999.0)
			var r: Dictionary = e.call("execute", str(aid), c)
			assert_true(r["ok"], "%s eseguita" % aid)
			assert_eq((r["warnings"] as PackedStringArray).size(), 0,
				"%s: nessun warning di primitiva: %s" % [aid, r["warnings"]])
			e.call("clear_cooldowns")
			_cleanup(c)
			provate += 1
	assert_gt(provate, 5.0, "provate le abilita' delle Sequenze Paragon scritte (%d)" % provate)
	var reg: Node = Engine.get_main_loop().root.get_node_or_null("SummonRegistry")
	if reg != null:
		reg.call("pulisci")


func test_le_acting_di_paragon_sommano_uno() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "paragon")
	for seq in (pw.get("sequences", []) as Array):
		if bool((seq as Dictionary).get("stub", false)):
			continue
		var somma: float = 0.0
		for a in ((seq as Dictionary).get("acting_actions", []) as Array):
			somma += float((a as Dictionary).get("progresso", 0.0))
		assert_almost_eq(somma, 1.0,
			"paragon_%d: acting sommano 1.0" % int((seq as Dictionary).get("sequence")))


func test_nessuna_abilita_paragon_usa_una_primitiva_differita() -> void:
	# US-517: paragon_1 (Illuminator) non deve puntare a rule_bind (differita).
	var differite := ["rule_bind", "weather_control", "probability_shift"]
	for aid in (_gd().call("get_pathway", "paragon").get("sequences", []) as Array):
		for ab_id in ((aid as Dictionary).get("abilities", []) as Array):
			for p in (_gd().call("get_ability", str(ab_id)).get("primitive", []) as Array):
				assert_false(differite.has(str((p as Dictionary).get("tipo"))),
					"%s: nessuna primitiva differita" % ab_id)
