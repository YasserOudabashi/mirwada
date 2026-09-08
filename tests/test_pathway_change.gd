extends "res://tests/test_case.gd"
## US-704 — cambio di Pathway solo tra vicini dello stesso gruppo. La
## relazione "vicini" e' il campo `group` dei dati: nessun id di Pathway qui.

const Stats := preload("res://scripts/stats_component.gd")


func _pc() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("PathwayChange")


func _prog() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Progression")


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


func prepara() -> void:
	var e: Node = _engine()
	if e != null:
		e.call("clear_cooldowns")
		e.call("clear_granted")
		e.call("flush_effects")
	var eg: Node = Engine.get_main_loop().root.get_node_or_null("EndgameState")
	if eg != null:
		eg.call("pulisci")


func _giocatore() -> Node2D:
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	Engine.get_main_loop().root.add_child(c)
	c.add_to_group("player")
	s.call("configure_from_balance", 9)
	return c


func _cleanup(c: Node) -> void:
	Engine.get_main_loop().root.remove_child(c)
	c.free()


func test_error_seq4_verso_door_e_ammesso() -> void:
	_prog().configura("error", 4)
	assert_true(_pc().call("puo_cambiare", "door"), "Error Seq 4 -> Door: stesso gruppo, avanzato")


func test_error_verso_death_rifiutato_gruppo_diverso() -> void:
	_prog().configura("error", 4)
	assert_false(_pc().call("puo_cambiare", "death"), "Error -> Death: gruppo diverso")
	var res: Dictionary = _pc().call("cambia", "death")
	assert_false(res["ok"], "cambia rifiuta")
	assert_eq(res["reason"], "gruppo_diverso", "motivo: gruppo diverso")
	assert_eq(_prog().call("pathway"), "error", "Pathway non toccato dal rifiuto")


func test_error_seq9_verso_door_rifiutato_troppo_presto() -> void:
	_prog().configura("error", 9)
	assert_false(_pc().call("puo_cambiare", "door"), "Error Seq 9: troppo presto")
	assert_eq((_pc().call("cambia", "door") as Dictionary)["reason"], "troppo_presto", "motivo: troppo presto")


func test_dopo_il_cambio_le_abilita_basse_del_vecchio_pathway_restano() -> void:
	var g: Node2D = _giocatore()
	_prog().configura("error", 4)
	var res: Dictionary = _pc().call("cambia", "door")
	assert_true(res["ok"], "cambio riuscito")
	assert_eq(_prog().call("pathway"), "door", "ora su Door")
	assert_eq(int(_prog().call("sequence")), 4, "stessa Sequenza numerica")
	assert_true("error_scasso" in (res["conservate"] as Array), "error_9 conservata")

	var e: Node = _engine()
	# un'abilita' di error_9 (vecchio Pathway) e' ancora lanciabile
	var r1: Dictionary = e.call("execute", "error_scasso", g)
	assert_ne(r1["reason"], "abilita_non_posseduta", "error_scasso ancora posseduta dopo il cambio")
	# un'abilita' di door_4 (nuovo Pathway, Sequenza raggiunta) e' lanciabile
	var r2: Dictionary = e.call("execute", "door_occultamento_totale", g)
	assert_ne(r2["reason"], "abilita_non_posseduta", "door_4 posseduta sul nuovo Pathway")
	_cleanup(g)
