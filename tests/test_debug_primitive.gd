extends "res://tests/test_case.gd"
## US-018 — AbilityEngine.esegui_primitiva: le 5 primitive isolate per la
## scena di debug.

const StatsComponent := preload("res://scripts/stats_component.gd")


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


func _caster() -> Node:
	var host := CharacterBody2D.new()
	var st: Node = StatsComponent.new()
	st.name = "StatsComponent"
	st.configure_from_balance(9)
	host.add_child(st)
	Engine.get_main_loop().root.add_child(host)
	return host


func test_buff_stat_isolato() -> void:
	var c: Node = _caster()
	var st: Node = c.get_node("StatsComponent")
	var v0: float = st.get_stat("velocita")
	var r: Dictionary = _engine().call("esegui_primitiva", "buff_stat",
		{"stat": "velocita", "valore": 30.0, "durata": 2.0}, c)
	assert_true(r["ok"], "esito ok")
	assert_almost_eq(st.get_stat("velocita"), v0 + 30.0, "buff applicato")
	_engine().call("flush_effects")
	c.free()


func test_heal_isolato() -> void:
	var c: Node = _caster()
	var st: Node = c.get_node("StatsComponent")
	st.set("hp", 40.0)
	_engine().call("esegui_primitiva", "heal", {"quantita": 15.0, "istantaneo": true}, c)
	assert_almost_eq(st.get("hp"), 55.0, "cura applicata")
	c.free()


func test_primitiva_ignota() -> void:
	var c: Node = _caster()
	var r: Dictionary = _engine().call("esegui_primitiva", "non_esiste", {}, c)
	assert_false(r["ok"], "primitiva ignota -> ok false, nessun crash")
	c.free()
