extends "res://tests/test_case.gd"
## US-228 — darkness_1 (Knight of Misfortune) senza probability_shift.
## L'abilita' darkness_sfortuna_cronica compone solo primitive ATTIVE.

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


func _caster() -> Node2D:
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	Engine.get_main_loop().root.add_child(c)
	s.call("configure_from_balance", 9)
	return c


func _cleanup(c: Node) -> void:
	Engine.get_main_loop().root.remove_child(c)
	c.free()


func test_curse_attiva_nel_registro_probability_shift_no() -> void:
	assert_false((_gd().call("get_primitive", "curse") as Dictionary).is_empty(),
		"curse nel registro (attiva)")
	# probability_shift resta nel registro ma differita: nessuna abilita' attiva
	# deve usarla. Qui verifichiamo solo che darkness_1 non la nomini.
	var ab: Dictionary = _gd().call("get_ability", "darkness_sfortuna_cronica")
	assert_false(ab.is_empty(), "l'abilita' di darkness_1 esiste")
	for p in (ab.get("primitive", []) as Array):
		assert_ne((p as Dictionary).get("tipo"), "probability_shift",
			"nessuna primitiva probability_shift")


func test_curse_marca_e_scade_ed_e_purificabile() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")

	e.call("_p_curse",
		{"effetto": "sfortuna", "durata": 10.0, "condizione_rimozione": "purificazione"},
		c, s, "ab")
	assert_true(s.call("ha_status", "sfortuna"), "maledizione come status nominato (US-218C)")

	# light_purify la toglie PER TAG (lo status 'sfortuna' e' marcato negativo)
	var rec: Dictionary = e.call("_p_light_purify", {"potenza": 1}, c, s, "cura")
	assert_eq(int(rec["rimossi"]), 1, "la maledizione conta come effetto negativo")
	assert_false(s.call("ha_status", "sfortuna"), "maledizione rimossa dalla purifica")
	_cleanup(c)


func test_curse_scade_da_sola() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	e.call("_p_curse", {"effetto": "sfortuna", "durata": 5.0}, c, s, "ab")
	s.call("_process", 5.5)   # StatsComponent scade gli status nel _process
	assert_false(s.call("ha_status", "sfortuna"), "maledizione scaduta dopo la durata")
	_cleanup(c)


func test_darkness_sfortuna_cronica_si_esegue_con_primitive_attive() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")

	var r: Dictionary = e.call("execute", "darkness_sfortuna_cronica", c)
	assert_true(r["ok"], "abilita' eseguita")
	assert_eq((r["warnings"] as PackedStringArray).size(), 0,
		"nessun warning: nessuna primitiva non implementata ne' fuori registro")
	# curse + debuff_stat(evasione) + debuff_stat(velocita) + dot
	assert_eq((r["effects"] as Array).size(), 4, "quattro primitive composte")
	assert_true(s.call("ha_status", "sfortuna"), "maledizione (status) attiva")
	assert_true(s.call("has_modifier", "darkness_sfortuna_cronica:debuff:evasione"), "debuff evasione")
	assert_true(s.call("has_modifier", "darkness_sfortuna_cronica:debuff:precisione"), "debuff precisione")
	_cleanup(c)
