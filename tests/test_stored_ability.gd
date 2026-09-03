extends "res://tests/test_case.gd"
## US-206 — hook stored_ability_id: eseguire l'abilita' "portata da un oggetto"
## al consumo, senza costo di spiritualita' ne' cooldown, senza ownership.

const Stats := preload("res://scripts/stats_component.gd")

const FAKE_ID := "_stored_fake_ability"


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node("GameData")


func prepara() -> void:
	var e: Node = _engine()
	if e != null:
		e.call("clear_cooldowns")
		e.call("clear_granted")
		e.call("flush_effects")
	if _prog() != null:
		_prog().configura("", 9)


func _prog() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Progression")


func _consumer() -> Node2D:
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


func _inietta_abilita_finta(costo: float) -> void:
	var abilities: Dictionary = _gd().get("_abilities")
	abilities[FAKE_ID] = {
		"id": FAKE_ID, "costo_spiritualita": costo, "cooldown": 40.0,
		"primitive": [{"tipo": "heal", "quantita": 25.0, "istantaneo": true}],
	}


func _rimuovi_abilita_finta() -> void:
	(_gd().get("_abilities") as Dictionary).erase(FAKE_ID)


func test_execute_stored_esegue_senza_costo_di_spiritualita() -> void:
	var e: Node = _engine()
	var c: Node2D = _consumer()
	var s: Node = c.get_node("Stats")
	s.set("hp", 40.0)
	var sp0: float = float(s.get("spiritualita"))
	_inietta_abilita_finta(30.0)

	var r: Dictionary = e.call("execute_stored", FAKE_ID, c)
	assert_true(r["ok"], "abilita' stored eseguita")
	assert_almost_eq(float(s.get("hp")), 65.0, "l'effetto e' applicato (heal 25)")
	assert_almost_eq(float(s.get("spiritualita")), sp0, "nessun costo di spiritualita' scalato")

	_rimuovi_abilita_finta()
	_cleanup(c)


func test_execute_stored_non_avvia_cooldown() -> void:
	var e: Node = _engine()
	var c: Node2D = _consumer()
	var s: Node = c.get_node("Stats")
	s.set("hp", 10.0)
	_inietta_abilita_finta(0.0)

	e.call("execute_stored", FAKE_ID, c)
	assert_false(e.call("is_on_cooldown", c, FAKE_ID), "nessun cooldown dopo un uso stored")
	# secondo uso: il singolo uso lo garantisce l'inventario consumando
	# l'oggetto, non il motore -> una seconda chiamata riesce ancora.
	var r2: Dictionary = e.call("execute_stored", FAKE_ID, c)
	assert_true(r2["ok"], "una seconda chiamata non e' bloccata dal cooldown")

	_rimuovi_abilita_finta()
	_cleanup(c)


func test_execute_stored_ignora_l_ownership() -> void:
	var e: Node = _engine()
	var c: Node2D = _consumer()
	c.add_to_group("player")  # ha un Pathway: execute() lo limiterebbe
	_inietta_abilita_finta(0.0)

	# execute() normale rifiuterebbe (non e' nel Pathway del giocatore)
	assert_eq((e.call("execute", FAKE_ID, c) as Dictionary)["reason"], e.ERR_NON_POSSEDUTA,
		"execute() normale: non posseduta")
	# execute_stored la esegue lo stesso: l'abilita' e' dell'oggetto
	assert_true((e.call("execute_stored", FAKE_ID, c) as Dictionary)["ok"],
		"execute_stored ignora l'ownership")

	_rimuovi_abilita_finta()
	_cleanup(c)


func test_execute_stored_abilita_ignota_errore_gestito() -> void:
	var e: Node = _engine()
	var c: Node2D = _consumer()
	var r: Dictionary = e.call("execute_stored", "abilita_che_non_esiste", c)
	assert_false(r["ok"], "rifiutata, non crash")
	assert_eq(r["reason"], e.ERR_SCONOSCIUTA, "motivo: abilita sconosciuta")
	assert_eq((r["effects"] as Array).size(), 0, "nessun effetto")
	_cleanup(c)


func test_execute_stored_consumer_senza_stats() -> void:
	var e: Node = _engine()
	var nudo := Node2D.new()
	Engine.get_main_loop().root.add_child(nudo)
	_inietta_abilita_finta(0.0)
	var r: Dictionary = e.call("execute_stored", FAKE_ID, nudo)
	assert_false(r["ok"], "rifiutata")
	assert_eq(r["reason"], e.ERR_NO_STATS, "motivo: consumer senza stats")
	_rimuovi_abilita_finta()
	Engine.get_main_loop().root.remove_child(nudo)
	nudo.free()
