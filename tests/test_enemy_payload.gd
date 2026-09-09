extends "res://tests/test_case.gd"
## US-804 — payload di enemy_defeated con i filtri veri (senza_abilita,
## senza_subire_danno, sequenza_bersaglio, tag_nemico), tracciati dal
## momento in cui il nemico entra in INSEGUIMENTO fino alla morte.

const EnemyScene := preload("res://scenes/enemy.tscn")
const EnemyScript := preload("res://scripts/enemy.gd")
const Hurtbox := preload("res://scripts/hurtbox.gd")
const Stats := preload("res://scripts/stats_component.gd")


func _root() -> Node: return Engine.get_main_loop().root
func _et() -> Node: return _root().get_node("EventTracker")
func _ae() -> Node: return _root().get_node("AbilityEngine")


func prepara() -> void:
	_et().call("azzera")
	_ae().call("clear_cooldowns")
	_ae().call("clear_granted")
	_root().get_node("Progression").call("configura", "twilight_giant", 9)


## Un player minimo, in scena PRIMA del nemico cosi' enemy._ready()
## (get_first_node_in_group("player")) lo trova come bersaglio: gruppo
## "player", una Hurtbox (per senza_subire_danno) e uno StatsComponent
## (find_stats di AbilityEngine, per poter eseguire un'abilita' vera).
func _player_finto() -> Node2D:
	var p := Node2D.new()
	p.add_to_group("player")
	var s: Node = Stats.new()
	s.name = "Stats"
	p.add_child(s)
	var hb: Area2D = Hurtbox.new()
	hb.name = "Hurtbox"
	p.add_child(hb)
	_root().add_child(p)
	s.call("configure_from_balance", 9)
	return p


## Istanzia il nemico e lo fa entrare in INSEGUIMENTO (_vai, chiamato
## direttamente come dentro_arco/colpi_residui in test_ability_engine.gd):
## e' li' che US-804 comincia a tracciare lo scontro.
func _nemico_a_caccia(player: Node2D) -> Node:
	var enemy: Node = EnemyScene.instantiate()
	_root().add_child(enemy)
	enemy.global_position = player.global_position + Vector2(10, 0)
	enemy.call("_vai", EnemyScript.Stato.INSEGUIMENTO)
	return enemy


func test_senza_abilita_true_se_ucciso_senza_lanciare_nulla() -> void:
	var player: Node2D = _player_finto()
	var enemy: Node = _nemico_a_caccia(player)

	enemy.get_node("StatsComponent").set("hp", 0.0)  # -> died -> _su_morte

	assert_almost_eq(_et().call("count", "enemy_defeated", {"senza_abilita": true}), 1.0,
		"nessuna abilita' lanciata durante lo scontro -> senza_abilita true")

	enemy.free()
	player.free()


func test_senza_abilita_false_dopo_un_abilita_del_player() -> void:
	var player: Node2D = _player_finto()
	var enemy: Node = _nemico_a_caccia(player)

	var r: Dictionary = _ae().call("execute", "tg_fendente_pesante", player)
	assert_true(bool(r.get("ok", false)), "l'abilita' di prova deve eseguire: %s" % r.get("reason", ""))

	enemy.get_node("StatsComponent").set("hp", 0.0)

	assert_almost_eq(_et().call("count", "enemy_defeated", {"senza_abilita": true}), 0.0,
		"un'abilita' lanciata durante lo scontro -> senza_abilita false, non matcha piu' il filtro")
	assert_almost_eq(_et().call("count", "enemy_defeated", {}), 1.0,
		"il nemico e' comunque contato senza filtri")

	enemy.free()
	player.free()


func test_senza_subire_danno_false_dopo_un_colpo_subito() -> void:
	var player: Node2D = _player_finto()
	var enemy: Node = _nemico_a_caccia(player)

	player.get_node("Hurtbox").call("subisci", 5.0, 0.0, enemy)

	enemy.get_node("StatsComponent").set("hp", 0.0)

	assert_almost_eq(_et().call("count", "enemy_defeated", {"senza_subire_danno": true}), 0.0,
		"il player ha subito danno durante lo scontro -> senza_subire_danno false")

	enemy.free()
	player.free()


func test_senza_subire_danno_true_se_la_parata_perfetta_annulla_il_danno() -> void:
	var player: Node2D = _player_finto()
	var enemy: Node = _nemico_a_caccia(player)
	var hb: Area2D = player.get_node("Hurtbox")
	hb.call("set_parata", Hurtbox.Parata.PERFETTA)

	hb.call("subisci", 5.0, 0.0, enemy)  # parata perfetta -> danno 0 (hurtbox.gd)

	enemy.get_node("StatsComponent").set("hp", 0.0)

	assert_almost_eq(_et().call("count", "enemy_defeated", {"senza_subire_danno": true}), 1.0,
		"un colpo annullato dalla parata perfetta (danno 0) non conta come subito")

	enemy.free()
	player.free()


func test_sequenza_bersaglio_nel_payload() -> void:
	var player: Node2D = _player_finto()
	var enemy: Node = _nemico_a_caccia(player)
	enemy.sequenza = 7

	enemy.get_node("StatsComponent").set("hp", 0.0)

	assert_almost_eq(_et().call("count", "enemy_defeated", {"sequenza_bersaglio_max": 7}), 1.0,
		"sequenza_bersaglio 7 passa il filtro _max:7")
	assert_almost_eq(_et().call("count", "enemy_defeated", {"sequenza_bersaglio_max": 6}), 0.0,
		"sequenza_bersaglio 7 non passa il filtro _max:6 (7 e' PIU' debole, non incluso)")

	enemy.free()
	player.free()
