extends "res://tests/test_case.gd"
## US-210B — i sistemi di fase 1 emettono gli eventi tracciati.

const Stats := preload("res://scripts/stats_component.gd")
const EnemyScene := preload("res://scenes/enemy.tscn")
const PlayerScript := preload("res://scripts/player.gd")


func _et() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("EventTracker")


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


func prepara() -> void:
	if _et() != null:
		_et().call("azzera")
	if _engine() != null:
		_engine().call("clear_cooldowns")
		_engine().call("clear_granted")
		_engine().call("flush_effects")


func _in_scena(n: Node) -> Node:
	Engine.get_main_loop().root.add_child(n)
	return n


func _fuori(n: Node) -> void:
	Engine.get_main_loop().root.remove_child(n)
	n.free()


func test_ability_used_emesso_su_esecuzione() -> void:
	var e: Node = _engine()
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	_in_scena(c)
	s.call("configure_from_balance", 9)

	e.call("execute", "fool_velo_illusorio", c)
	assert_almost_eq(_et().call("count", "ability_used", {}), 1.0, "un'abilita' usata")
	assert_almost_eq(_et().call("count", "ability_used", {"ability_id": "fool_velo_illusorio"}), 1.0,
		"filtrata per ability_id")
	_fuori(c)


func test_enemy_defeated_emesso_alla_morte() -> void:
	var enemy: Node = _in_scena(EnemyScene.instantiate())
	await Engine.get_main_loop().process_frame
	var st: Node = enemy.get_node("StatsComponent")
	st.set("hp", 0.0)  # -> died -> _su_morte
	await Engine.get_main_loop().process_frame
	assert_almost_eq(_et().call("count", "enemy_defeated", {}), 1.0, "un nemico sconfitto")
	_fuori(enemy)


func test_player_emette_danno_e_parata() -> void:
	# I gestori di combattimento sono metodi puri: si esercitano senza montare
	# l'intera scena del giocatore (che finirebbe nel gruppo "player" e
	# sporcherebbe altri test).
	var player: Node = PlayerScript.new()

	player.call("_su_colpo_inflitto", null, 15.0)
	player.call("_su_danno_subito", 8.0, 0.0, null)
	player.call("_su_parata_riuscita", true, null)
	player.call("_su_parata_riuscita", false, null)  # blocco, non perfetta

	assert_almost_eq(_et().call("count", "damage_dealt", {}), 15.0, "danno inflitto sommato")
	assert_almost_eq(_et().call("count", "damage_taken", {}), 8.0, "danno subito sommato")
	assert_almost_eq(_et().call("count", "perfect_parry", {}), 1.0, "solo la parata perfetta contata")
	player.free()
