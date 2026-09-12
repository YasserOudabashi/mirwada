extends "res://tests/test_case.gd"
## Bug report utente 2026-09-10: "era a zero [hp] ma non morivo". A 0 hp il
## giocatore restava giocabile all'infinito: StatsComponent.died esiste da
## sempre ma solo enemy.gd lo ascoltava, player.gd non faceva nulla alla
## morte. Qui si verifica solo il collegamento e lo stato (is_dead/_morto/
## hp), senza aspettare i frame reali dell'animazione "death": _respawn()
## e' l'equivalente di lasciarla finire (stesso pattern di
## lancia_abilita_slot in test_player_abilita.gd, che bypassa Input).

const PlayerScene := preload("res://scenes/player.tscn")


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func prepara() -> void:
	_n("/root/Progression").call("configura", "twilight_giant", 9)


func _giocatore() -> Node:
	var player: Node = PlayerScene.instantiate()
	Engine.get_main_loop().root.add_child(player)
	return player


func test_hp_a_zero_marca_morto_e_ferma_il_giocatore() -> void:
	var player: Node = _giocatore()
	var stats: Node = player.get_node("StatsComponent")

	stats.set("hp", 0.0)
	assert_true(bool(stats.call("is_dead")), "0 hp -> StatsComponent.is_dead()")
	assert_true(bool(player.get("_morto")), "il player si segna 'morto'")

	player.free()


func test_respawn_risuscita_a_hp_pieni() -> void:
	var player: Node = _giocatore()
	var stats: Node = player.get_node("StatsComponent")

	stats.set("hp", 0.0)
	player.call("_respawn")  # fine dell'animazione "death"

	assert_false(bool(stats.call("is_dead")), "risorto: non e' piu' morto")
	assert_false(bool(player.get("_morto")), "il player non e' piu' 'morto'")
	assert_almost_eq(float(stats.get("hp")), float(stats.call("get_stat", "hp_max")),
		"hp pieni dopo il respawn")

	player.free()


func test_una_seconda_morte_nella_stessa_sessione_scatta_ancora() -> void:
	# Bug latente evitato da StatsComponent.revivi(): senza il reset di
	# _dead, il setter di hp non avrebbe piu' potuto emettere 'died' una
	# seconda volta nella stessa partita.
	var player: Node = _giocatore()
	var stats: Node = player.get_node("StatsComponent")

	stats.set("hp", 0.0)
	player.call("_respawn")
	stats.set("hp", 0.0)
	assert_true(bool(stats.call("is_dead")), "una seconda morte scatta ancora")

	player.free()
