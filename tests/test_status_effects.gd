extends "res://tests/test_case.gd"
## US-218C — sistema di status sulle entita' + campi d'area per aura/decay.

const Stats := preload("res://scripts/stats_component.gd")
const Hurtbox := preload("res://scripts/hurtbox.gd")


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node("GameData")


func prepara() -> void:
	if _engine() != null:
		_engine().call("clear_cooldowns")
		_engine().call("flush_effects")


func _stats() -> Node:
	var s: Node = Stats.new()
	Engine.get_main_loop().root.add_child(s)
	s.call("configure_from_balance", 9)
	return s


func test_status_caricati_dai_dati() -> void:
	var st: Dictionary = _gd().call("get_status_effect", "decadimento")
	assert_false(st.is_empty(), "status 'decadimento' caricato")
	assert_eq(st["tag"], "decadimento", "tag")


func test_applica_e_rimuovi_status() -> void:
	var s: Node = _stats()
	s.call("applica_status", "sfortuna", -1.0)
	assert_true(s.call("ha_status", "sfortuna"), "status applicato")
	assert_true("sfortuna" in (s.call("status_attivi") as Array), "elencato fra gli attivi")
	assert_true(s.call("rimuovi_status", "sfortuna"), "rimosso")
	assert_false(s.call("ha_status", "sfortuna"), "non piu' attivo")
	s.free()


func test_gli_stat_modifiers_dello_status_si_applicano() -> void:
	var s: Node = _stats()
	var difesa0: float = float(s.call("get_stat", "difesa"))
	s.call("applica_status", "decadimento", -1.0)   # difesa -0.2, velocita -0.1
	assert_almost_eq(float(s.call("get_stat", "difesa")), difesa0 - 0.2, "difesa abbassata dallo status")
	s.call("rimuovi_status", "decadimento")
	assert_almost_eq(float(s.call("get_stat", "difesa")), difesa0, "ripristinata")
	s.free()


func test_status_scade_da_solo() -> void:
	var s: Node = _stats()
	s.call("applica_status", "taunt", 3.0)
	s.call("_process", 2.0)
	assert_true(s.call("ha_status", "taunt"), "ancora attivo a 2s")
	s.call("_process", 1.5)
	assert_false(s.call("ha_status", "taunt"), "scaduto dopo 3s")
	s.free()


func test_rimuovi_per_tag() -> void:
	var s: Node = _stats()
	s.call("applica_status", "sfortuna", -1.0)      # tag maledizione
	s.call("applica_status", "decadimento", -1.0)   # tag decadimento
	assert_eq(s.call("rimuovi_status_per_tag", "decadimento"), 1, "un solo status con quel tag")
	assert_true(s.call("ha_status", "sfortuna"), "l'altro resta")
	assert_false(s.call("ha_status", "decadimento"), "quello col tag e' via")
	s.free()


func test_light_purify_toglie_gli_status_negativi_per_tag() -> void:
	var e: Node = _engine()
	var s: Node = _stats()
	s.call("applica_status", "sfortuna", -1.0)      # negativo
	s.call("applica_status", "taunt", -1.0)         # non negativo

	var rec: Dictionary = e.call("_p_light_purify", {"potenza": 3}, null, s, "cura")
	assert_gt(float(rec["rimossi"]), 0.0, "ha rimosso almeno la maledizione")
	assert_false(s.call("ha_status", "sfortuna"), "status negativo rimosso")
	assert_true(s.call("ha_status", "taunt"), "status non negativo intatto")
	s.free()


func test_campo_aura_applica_lo_status_solo_nel_raggio() -> void:
	var root: Node = Engine.get_main_loop().root
	var caster := Node2D.new()
	root.add_child(caster)
	caster.global_position = Vector2.ZERO

	var vicino := _bersaglio_con_hurtbox(Vector2(10, 0))
	var lontano := _bersaglio_con_hurtbox(Vector2(400, 0))
	await Engine.get_main_loop().physics_frame

	_engine().call("_p_aura",
		{"raggio": 40.0, "durata": 5.0, "effetto": "taunt", "tick_rate": 0.1}, caster, null, "ab")

	for i in 12:
		await Engine.get_main_loop().physics_frame
		await Engine.get_main_loop().process_frame

	assert_true(vicino["stats"].call("ha_status", "taunt"), "bersaglio nel raggio: status applicato")
	assert_false(lontano["stats"].call("ha_status", "taunt"), "bersaglio fuori raggio: niente status")

	caster.free()
	vicino["host"].free()
	lontano["host"].free()


func _bersaglio_con_hurtbox(pos: Vector2) -> Dictionary:
	var host := Node2D.new()
	var s: Node = Stats.new()
	s.name = "StatsComponent"
	host.add_child(s)
	var hb: Area2D = Hurtbox.new()
	hb.collision_layer = 4
	host.add_child(hb)
	Engine.get_main_loop().root.add_child(host)
	host.global_position = pos
	s.call("configure_from_balance", 9)
	return {"host": host, "stats": s, "hurtbox": hb}
