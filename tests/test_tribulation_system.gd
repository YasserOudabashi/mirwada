extends "res://tests/test_case.gd"
## US-711 — TribulationSystem: la prova al salto di fascia blocca
## Progression.avanza finche' 'superamento' (evento o flag) non e' raggiunto;
## 'mentre_in_corso' e' un handicap applicato e tolto; il superamento va nel save.

const Stats := preload("res://scripts/stats_component.gd")

var _player: Node2D = null


func _root() -> Node: return Engine.get_main_loop().root
func _ts() -> Node: return _root().get_node("TribulationSystem")
func _prog() -> Node: return _root().get_node("Progression")
func _et() -> Node: return _root().get_node("EventTracker")
func _ks() -> Node: return _root().get_node("KnowledgeStore")
func _eg() -> Node: return _root().get_node("EndgameState")
func _gd() -> Node: return _root().get_node("GameData")
func _madness() -> Node: return _root().get_node("Madness")


func prepara() -> void:
	if _player != null and is_instance_valid(_player):
		_player.free()
	for stale in _root().get_tree().get_nodes_in_group("player"):
		stale.remove_from_group("player")
	_player = Node2D.new()
	_player.add_to_group("player")
	var s: Node = Stats.new()
	s.name = "StatsComponent"
	_player.add_child(s)
	_root().add_child(_player)
	s.call("configure_from_balance", 3)

	_et().call("azzera")
	_ks().call("dimentica_tutto")
	_madness().call("azzera")
	_eg().call("pulisci")
	_ts().call("azzera")
	_prog().configura("twilight_giant", 3)


func _fine() -> void:
	_eg().call("pulisci")
	_ts().call("azzera")
	_prog().configura("", 9)
	if is_instance_valid(_player):
		_player.free()


func _flag_di(da: int) -> String:
	return str(_gd().call("tribulation_per_salto", da).get("superamento", {}).get("flag", ""))


func test_salto_di_fascia_bloccato_finche_non_superata() -> void:
	assert_true(_ts().call("avanzamento_bloccato", 3), "c'e' una tribolazione per il salto 3->2")
	assert_false(_prog().call("avanza"), "avanza rifiutato: prova non superata")
	assert_eq(int(_prog().call("sequence")), 3, "resta a Sequenza 3")

	_ks().call("impara", _flag_di(3))
	assert_false(_ts().call("avanzamento_bloccato", 3), "flag posto -> non piu' bloccato")
	assert_true(_prog().call("avanza"), "ora avanza")
	assert_eq(int(_prog().call("sequence")), 2, "arrivato a Sequenza 2")
	assert_true(bool(_eg().call("tribolazione_superata", 3)), "superamento registrato in endgame")
	_fine()


func test_superamento_per_evento_conta_sul_tracker() -> void:
	# trib_5_4: superamento = npc_influenced x3
	_prog().configura("twilight_giant", 5)
	_ts().call("attiva", 5)
	assert_false(_prog().call("avanza"), "5->4 bloccato: 0/3 npc_influenced")
	for i in 3:
		_et().call("emit_event", "npc_influenced", {})
	assert_almost_eq(float(_ts().call("stato")["progresso"]), 1.0, "3/3 -> progresso pieno")
	assert_true(_prog().call("avanza"), "raggiunto il target -> avanza")
	assert_eq(int(_prog().call("sequence")), 4, "a Sequenza 4")
	_fine()


func test_mentre_in_corso_applicato_e_rimosso() -> void:
	# trib_3_2 -> follia_accelerata: la follia sale finche' la prova e' aperta
	_ts().call("attiva", 3)
	assert_eq(int(_ts().call("stato")["da"]), 3, "prova attiva")
	var prima: float = float(_madness().call("valore"))
	for i in 150:
		_ts().call("_process", 0.1)
	var durante: float = float(_madness().call("valore"))
	assert_gt(durante, prima, "follia_accelerata: la follia e' salita mentre la prova era aperta")

	_ks().call("impara", _flag_di(3))
	assert_false(bool(_ts().call("stato")["in_corso"]), "superata: prova non piu' in corso")
	var dopo: float = float(_madness().call("valore"))
	for i in 150:
		_ts().call("_process", 0.1)
	assert_almost_eq(float(_madness().call("valore")), dopo, "niente piu' follia extra dopo il superamento", 0.02)
	_fine()


func test_round_trip_nel_save() -> void:
	_ts().call("attiva", 3)          # applica l'handicap
	_ks().call("impara", _flag_di(3))  # il flag posto -> _ricalcola_progresso -> superata
	assert_true(bool(_eg().call("tribolazione_superata", 3)), "superata dopo il flag")

	var gs: Node = _root().get_node("GameState")
	var snap: Dictionary = gs.call("snapshot")
	assert_true((snap.get("endgame", {}).get("tribolazioni_superate", []) as Array).has(3),
		"il superamento e' nello snapshot")
	_eg().call("pulisci")
	gs.call("applica", snap)
	assert_true(bool(_eg().call("tribolazione_superata", 3)), "e torna dopo applica")
	_fine()
