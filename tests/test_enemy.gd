extends "res://tests/test_case.gd"
## US-011 — nemico base: macchina a stati, componenti, segnale di morte.

const EnemyScene := preload("res://scenes/enemy.tscn")


func _nemico() -> CharacterBody2D:
	var e: CharacterBody2D = EnemyScene.instantiate()
	Engine.get_main_loop().root.add_child(e)
	return e


func test_parte_in_idle_con_i_componenti() -> void:
	var e: CharacterBody2D = _nemico()
	assert_eq(e.stato(), "IDLE", "stato iniziale IDLE")
	assert_true(e.get_node("StatsComponent").has_method("spend_spiritualita"), "ha StatsComponent")
	assert_true(e.get_node("PosturaComponent").has_method("erodi"), "ha PosturaComponent")
	assert_true(e.is_in_group("nemici"), "nel gruppo nemici")
	e.free()


func test_alla_morte_emette_segnale_e_non_si_distrugge() -> void:
	var e: CharacterBody2D = _nemico()
	var morti: Array = []
	e.morto.connect(func(chi: Node) -> void: morti.append(chi))

	var stats: Node = e.get_node("StatsComponent")
	stats.set("hp", 0.0)

	assert_eq(morti.size(), 1, "segnale morto emesso una volta")
	assert_eq(e.stato(), "MORTO", "stato MORTO")
	assert_true(is_instance_valid(e), "il nodo non si e' auto-distrutto")
	e.free()


func test_la_rottura_di_postura_manda_in_stagger() -> void:
	var e: CharacterBody2D = _nemico()
	var stati: Array = []
	e.stato_cambiato.connect(func(s: String) -> void: stati.append(s))
	e.get_node("PosturaComponent").call("erodi", 999.0)
	assert_true(stati.has("STAGGER"), "postura rotta -> STAGGER")
	e.free()
