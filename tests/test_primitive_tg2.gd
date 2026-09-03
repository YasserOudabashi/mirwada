extends "res://tests/test_case.gd"
## US-203 — primitive del Twilight Giant, parte 2a: debuff_stat, light_purify.

const Stats := preload("res://scripts/stats_component.gd")


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


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


func test_primitive_nel_registro() -> void:
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	for tipo in ["debuff_stat", "light_purify"]:
		assert_false((gd.call("get_primitive", tipo) as Dictionary).is_empty(),
			"'%s' nel registro chiuso" % tipo)


func test_debuff_stat_abbassa_e_scade() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	# velocita base 140, moltiplicativo -0.5 -> delta -70 -> effettiva 70
	e.call("_p_debuff_stat",
		{"stat": "velocita", "valore": -0.5, "durata": 6.0, "moltiplicativo": true},
		c, s, "ab")
	assert_almost_eq(float(s.call("get_stat", "velocita")), 70.0, "velocita dimezzata")
	assert_true(s.call("has_modifier", "ab:debuff:velocita"), "id di debuff separato")

	e.call("tick_effects", 6.5)
	assert_almost_eq(float(s.call("get_stat", "velocita")), 140.0, "tornata alla base dopo la durata")
	_cleanup(c)


func test_buff_e_debuff_sulla_stessa_stat_coesistono() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	e.call("_p_buff_stat", {"stat": "difesa", "valore": 10.0}, c, s, "ab")
	e.call("_p_debuff_stat", {"stat": "difesa", "valore": -4.0}, c, s, "ab")
	# id distinti: i due modificatori non si sovrascrivono
	assert_almost_eq(float(s.call("get_stat", "difesa")), 6.0, "buff +10 e debuff -4 sommati")
	_cleanup(c)


func test_light_purify_toglie_un_dot() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	s.set("hp", 100.0)
	e.call("_p_dot", {"danno_tick": 10.0, "tick_rate": 1.0, "durata": 10.0}, c, s, "ab")
	assert_eq(e.call("pending_count"), 1, "dot in coda")

	var rec: Dictionary = e.call("_p_light_purify",
		{"raggio": 6.0, "potenza": 4, "riduce_sequenza": true}, c, s, "cura")
	assert_eq(int(rec["rimossi"]), 1, "un effetto negativo rimosso")
	assert_true(rec["riduce_sequenza"], "riduce_sequenza registrato")
	assert_eq(e.call("pending_count"), 0, "coda ripulita")

	e.call("tick_effects", 3.0)
	assert_almost_eq(float(s.get("hp")), 100.0, "il dot rimosso non fa piu' danno")
	_cleanup(c)


func test_light_purify_ripristina_una_stat_debuffata() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	e.call("_p_debuff_stat", {"stat": "difesa", "valore": -5.0, "durata": 20.0}, c, s, "ab")
	assert_almost_eq(float(s.call("get_stat", "difesa")), -5.0, "difesa debuffata")

	e.call("_p_light_purify", {"potenza": 1}, c, s, "cura")
	assert_almost_eq(float(s.call("get_stat", "difesa")), 0.0, "debuff rimosso, stat ripristinata")
	assert_false(s.call("has_modifier", "ab:debuff:difesa"), "modificatore tolto dallo stats")
	_cleanup(c)


func test_light_purify_limitato_dalla_potenza() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	e.call("_p_dot", {"danno_tick": 5.0, "tick_rate": 1.0, "durata": 10.0}, c, s, "a")
	e.call("_p_decay", {"danno": 30.0, "durata": 10.0}, c, s, "b")
	e.call("_p_debuff_stat", {"stat": "difesa", "valore": -3.0, "durata": 10.0}, c, s, "d")
	assert_eq(e.call("pending_count"), 3, "tre effetti negativi")

	var rec: Dictionary = e.call("_p_light_purify", {"potenza": 2}, c, s, "cura")
	assert_eq(int(rec["rimossi"]), 2, "potenza 2 -> solo 2 rimossi")
	assert_eq(e.call("pending_count"), 1, "uno resta")
	_cleanup(c)


func test_composizione_decay_piu_debuff_via_execute() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var r: Dictionary = e.call("execute", "tg_crepuscolo", c)
	assert_true(r["ok"], "abilita' eseguita")
	assert_eq((r["warnings"] as PackedStringArray).size(), 0, "nessun warning di primitiva")
	assert_eq((r["effects"] as Array).size(), 2, "decay + debuff_stat eseguite")
	_cleanup(c)
