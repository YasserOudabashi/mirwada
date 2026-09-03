extends "res://tests/test_case.gd"
## US-203B — primitiva transform + data/forms.json.

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


func test_transform_nel_registro_e_forme_caricate() -> void:
	assert_false((_gd().call("get_primitive", "transform") as Dictionary).is_empty(),
		"transform nel registro chiuso")
	assert_false((_gd().call("get_form", "tg_forma_gigante") as Dictionary).is_empty(),
		"tg_forma_gigante caricata da forms.json")
	assert_true((_gd().call("get_form", "forma_che_non_esiste") as Dictionary).is_empty(),
		"forma ignota -> {}")


func test_transform_applica_gli_stat_modifiers_della_forma() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	var hp_base: float = float(s.call("get_base", "hp_max"))
	var vel_base: float = float(s.call("get_base", "velocita"))

	var rec: Dictionary = e.call("_p_transform",
		{"forma_id": "tg_forma_gigante", "durata": 15.0, "costo_al_secondo": 0.0}, c, s, "ab")
	assert_true(rec["applied"], "trasformazione applicata")
	# tg_forma_gigante: hp_max +120, velocita -35, difesa +0.25
	assert_almost_eq(float(s.call("get_stat", "hp_max")), hp_base + 120.0, "hp_max della forma")
	assert_almost_eq(float(s.call("get_stat", "velocita")), vel_base - 35.0, "velocita della forma (trade-off)")
	assert_true(s.call("has_modifier", "transform:ab"), "modificatore per id transform:ab")
	_cleanup(c)


func test_transform_reversibile_alla_scadenza() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	var hp_base: float = float(s.call("get_base", "hp_max"))

	e.call("_p_transform", {"forma_id": "tg_forma_gigante", "durata": 10.0}, c, s, "ab")
	e.call("tick_effects", 6.0)
	assert_true(s.call("has_modifier", "transform:ab"), "ancora trasformato a 6s")
	e.call("tick_effects", 5.0)
	assert_false(s.call("has_modifier", "transform:ab"), "forma annullata dopo la durata")
	assert_almost_eq(float(s.call("get_stat", "hp_max")), hp_base, "stat tornate alla base")
	_cleanup(c)


func test_transform_reversibile_su_richiesta() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	e.call("_p_transform", {"forma_id": "tg_arma_luce", "durata": 25.0}, c, s, "ab")
	assert_true(s.call("has_modifier", "transform:ab"), "trasformato")

	assert_true(e.call("annulla_transform", "ab"), "annulla_transform trova la forma")
	assert_false(s.call("has_modifier", "transform:ab"), "forma annullata su richiesta")
	assert_eq(e.call("pending_count"), 0, "entry rimossa dalla coda")
	_cleanup(c)


func test_transform_finisce_quando_la_spiritualita_si_esaurisce() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	s.set("spiritualita", 25.0)

	# durata 0 + costo_al_secondo: dura finche' c'e' spiritualita'
	e.call("_p_transform",
		{"forma_id": "tg_arma_luce", "durata": 0.0, "costo_al_secondo": 10.0}, c, s, "ab")
	e.call("tick_effects", 1.0)
	assert_almost_eq(float(s.get("spiritualita")), 15.0, "spiritualita' drenata di costo*tempo")
	assert_true(s.call("has_modifier", "transform:ab"), "ancora trasformato con spiritualita' > 0")

	e.call("tick_effects", 3.0)
	assert_almost_eq(float(s.get("spiritualita")), 0.0, "spiritualita' a zero")
	assert_false(s.call("has_modifier", "transform:ab"), "forma annullata a spiritualita' esaurita")
	_cleanup(c)


func test_transform_forma_ignota_non_applica_nulla() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	var rec: Dictionary = e.call("_p_transform", {"forma_id": "forma_inventata"}, c, s, "ab")
	assert_false(rec["applied"], "forma ignota -> non applicata")
	assert_false(s.call("has_modifier", "transform:ab"), "nessun modificatore")
	_cleanup(c)


func test_composizione_transform_piu_buff_via_execute() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var r: Dictionary = e.call("execute", "tg_crescita", c)
	assert_true(r["ok"], "tg_crescita eseguita")
	assert_eq((r["warnings"] as PackedStringArray).size(), 0, "nessun warning di primitiva")
	assert_eq((r["effects"] as Array).size(), 2, "transform + buff_stat")
	assert_true(c.get_node("Stats").call("has_modifier", "transform:tg_crescita"), "forma attiva")
	_cleanup(c)
