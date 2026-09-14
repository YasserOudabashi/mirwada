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


# --- US-707: cambio verso un vicino con percorso di fusione stub --------

func test_cambio_verso_percorso_stub_riesce_senza_fusioni() -> void:
	var g: Node2D = _giocatore()
	var eg: Node = Engine.get_main_loop().root.get_node("EndgameState")
	_prog().configura("hermit", 4)
	var res: Dictionary = _pc().call("cambia", "paragon")
	assert_true(res["ok"], "Hermit -> Paragon: cambio riuscito (stesso gruppo)")
	assert_eq(_prog().call("pathway"), "paragon", "ora su Paragon")
	assert_gt(float((res["conservate"] as Array).size()), 0.0, "abilita basse conservate lo stesso")
	assert_eq((eg.get("fusioni") as Array).size(), 0, "percorso stub: endgame.fusioni resta []")
	_cleanup(g)


# --- US-903: un Pathway non_standard non ha gruppo/vicini -------------------

func _gd() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


## Un Pathway non_standard di prova, iniettato direttamente nel registro
## separato di GameData (mai su disco, stesso pattern di test_boon_system.gd):
## GameData.reload() lo pota via alla fine di ogni test qui sotto.
func _inietta_pathway_non_standard() -> void:
	var m: Dictionary = _gd().get("_pathways_non_standard")
	m["fixture_ns"] = {"id": "fixture_ns", "categoria": "non_standard", "group": null}


func test_cambio_verso_un_pathway_non_standard_e_rifiutato() -> void:
	_inietta_pathway_non_standard()
	_prog().configura("error", 4)
	assert_false(_pc().call("puo_cambiare", "fixture_ns"), "non si cambia verso un Pathway non_standard")
	var res: Dictionary = _pc().call("cambia", "fixture_ns")
	assert_false(res["ok"], "cambia rifiuta")
	assert_eq(res["reason"], "pathway_non_standard", "motivo esplicito")
	assert_eq(_prog().call("pathway"), "error", "Pathway non toccato dal rifiuto")
	_gd().call("reload")


func test_cambio_da_un_pathway_non_standard_e_rifiutato() -> void:
	_inietta_pathway_non_standard()
	_prog().configura("fixture_ns", 4)
	assert_false(_pc().call("puo_cambiare", "error"), "non si cambia da un Pathway non_standard")
	var res: Dictionary = _pc().call("cambia", "error")
	assert_false(res["ok"], "cambia rifiuta")
	assert_eq(res["reason"], "pathway_non_standard", "motivo esplicito")
	_gd().call("reload")
