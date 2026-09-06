extends "res://tests/test_case.gd"
## US-320 — le abilita' d'area con colpisce_oggetti:true danneggiano le
## strutture di StructureRegistry (decay, e ogni altra che lo dichiari).

const Stats := preload("res://scripts/stats_component.gd")


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


func _reg() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("StructureRegistry")


func _eventi() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("EventTracker")


func prepara() -> void:
	var e: Node = _engine()
	if e != null:
		e.call("clear_cooldowns")
		e.call("flush_effects")
	if _reg() != null:
		_reg().call("pulisci")
	if _eventi() != null:
		_eventi().call("azzera")


func _caster(pos: Vector2) -> Node2D:
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	Engine.get_main_loop().root.add_child(c)
	s.call("configure_from_balance", 9)
	c.global_position = pos
	return c


func _cleanup(c: Node) -> void:
	Engine.get_main_loop().root.remove_child(c)
	c.free()


func _hp(iid: String) -> float:
	for e in _reg().call("attive"):
		if str((e as Dictionary)["id"]) == iid:
			return float((e as Dictionary)["hp"])
	return -1.0


func test_decay_in_raggio_danneggia_la_struttura() -> void:
	var iid: String = _reg().call("costruisci", "deposito", Vector2.ZERO)  # hp 60
	var c: Node2D = _caster(Vector2(10, 0))
	var rec: Dictionary = _engine().call("_p_decay",
		{"danno": 20.0, "raggio": 50.0, "colpisce_oggetti": true, "durata": 10.0},
		c, c.get_node("Stats"), "ab")
	assert_eq((rec["strutture_colpite"] as Array).size(), 1, "una struttura colpita")
	assert_almost_eq(_hp(iid), 40.0, "hp 60 -> 40 col danno totale del decay")
	_cleanup(c)


func test_decay_fuori_raggio_lascia_intatta_la_struttura() -> void:
	var iid: String = _reg().call("costruisci", "deposito", Vector2.ZERO)
	var c: Node2D = _caster(Vector2(500, 0))
	var rec: Dictionary = _engine().call("_p_decay",
		{"danno": 20.0, "raggio": 50.0, "colpisce_oggetti": true, "durata": 10.0},
		c, c.get_node("Stats"), "ab")
	assert_eq((rec["strutture_colpite"] as Array).size(), 0, "nessuna struttura in raggio")
	assert_almost_eq(_hp(iid), 60.0, "struttura intatta")
	_cleanup(c)


func test_decay_senza_colpisce_oggetti_non_tocca_le_strutture() -> void:
	var iid: String = _reg().call("costruisci", "deposito", Vector2.ZERO)
	var c: Node2D = _caster(Vector2(10, 0))
	_engine().call("_p_decay",
		{"danno": 20.0, "raggio": 50.0, "durata": 10.0},
		c, c.get_node("Stats"), "ab")
	assert_almost_eq(_hp(iid), 60.0, "colpisce_oggetti assente -> struttura intatta")
	_cleanup(c)


func test_decay_che_azzera_la_struttura_la_distrugge_non_volontariamente() -> void:
	_reg().call("costruisci", "totem_veglia", Vector2.ZERO)  # hp 25
	var c: Node2D = _caster(Vector2.ZERO)
	_engine().call("_p_decay",
		{"danno": 30.0, "raggio": 40.0, "colpisce_oggetti": true, "durata": 10.0},
		c, c.get_node("Stats"), "ab")
	assert_eq(_reg().call("conta"), 0, "struttura crollata")
	assert_eq(_eventi().call("count", "structure_destroyed"), 1.0, "evento emesso")
	assert_eq(_eventi().call("count", "structure_destroyed", {"volontario": true}), 0.0,
		"il crollo da AoE NON alimenta tg_2_accetta_decadimento (serve distruggi(.,true))")
	_cleanup(c)


func test_tg_crepuscolo_via_execute_degrada_la_struttura() -> void:
	# L'abilita' firma del Twilight Giant ha decay colpisce_oggetti:true.
	var iid: String = _reg().call("costruisci", "palizzata", Vector2.ZERO)  # hp 40
	var c: Node2D = _caster(Vector2.ZERO)
	var r: Dictionary = _engine().call("execute", "tg_crepuscolo", c)
	assert_true(r["ok"], "tg_crepuscolo eseguita")
	assert_true(_hp(iid) < 40.0 or _reg().call("conta") == 0,
		"la palizzata ha perso hp (o e' crollata) per il Crepuscolo")
	_cleanup(c)
