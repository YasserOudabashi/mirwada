extends "res://tests/test_case.gd"
## US-1502 — Il nemico che colpisce da lontano: si tiene a distanza, indietreggia se ci si avvicina, e dopo il suo
## tell tira un proiettile verso il giocatore (lo stesso delle abilita'). Il suo tiro non colpisce gli altri nemici.

func _root() -> Node: return Engine.get_main_loop().root

var _madre: Node2D = null
var _bersaglio: CharacterBody2D = null


func _scena(tipo: String, dist: float) -> Node:
	_madre = Node2D.new()
	_root().add_child(_madre)
	_bersaglio = preload("res://scenes/player.tscn").instantiate()
	_madre.add_child(_bersaglio)
	_bersaglio.global_position = Vector2(dist, 0)
	var e: Node = preload("res://scenes/enemy.tscn").instantiate()
	e.set("tipo", tipo)
	_madre.add_child(e)
	e.set("_bersaglio", _bersaglio)
	return e


func _proiettili() -> Array:
	return _madre.get_children().filter(func(c): return c.get_script() == preload("res://scripts/projectile.gd"))


func test_da_lontano_tira_dopo_il_tell() -> void:
	var e: Node = _scena("contrabbandiere_balestra", 130.0)
	e.call("_vai", 1)                                    # INSEGUIMENTO
	e.call("_physics_process", 0.016)
	assert_eq(str(e.call("stato")), "ANTICIPO", "a tiro comincia il tell, senza avvicinarsi")
	assert_eq(_proiettili().size(), 0, "durante il tell non tira")
	for i in 60:
		e.call("_physics_process", 0.016)
	var p: Array = _proiettili()
	assert_eq(p.size(), 1, "finito il tell, un proiettile")
	if not p.is_empty():
		assert_gt(float((p[0] as Node).get("danno")), 0.0, "che fa danno")
		var prima: float = (p[0] as Node2D).global_position.x
		(p[0] as Node).call("_physics_process", 0.1)
		assert_gt((p[0] as Node2D).global_position.x, prima, "e vola verso il giocatore")
	_madre.free()


func test_da_vicino_indietreggia() -> void:
	var e: Node = _scena("contrabbandiere_balestra", 30.0)
	e.call("_vai", 1)
	e.call("_physics_process", 0.016)
	assert_eq(str(e.call("stato")), "INSEGUIMENTO", "troppo vicino: non tira subito")
	assert_true((e as CharacterBody2D).velocity.x < 0.0, "si allontana dal giocatore")
	for i in 90:
		e.call("_physics_process", 0.016)
	assert_ne(str(e.call("stato")), "INSEGUIMENTO", "se non riesce a staccarsi, tira lo stesso")
	_madre.free()


func test_chi_combatte_in_mischia_non_tira() -> void:
	var e: Node = _scena("soldato_caduto", 20.0)
	e.call("_vai", 1)
	for i in 80:
		e.call("_physics_process", 0.016)
	assert_eq(_proiettili().size(), 0, "il soldato caduto colpisce da vicino")
	_madre.free()


func test_il_tiro_non_colpisce_un_altro_nemico() -> void:
	var e: Node = _scena("contrabbandiere_balestra", 130.0)
	var altro: Node = preload("res://scenes/enemy.tscn").instantiate()
	_madre.add_child(altro)
	var p := preload("res://scripts/projectile.gd").new()
	p.setup({"danno": 10.0}, Vector2.ZERO, Vector2.RIGHT, e)
	_madre.add_child(p)
	var hp: float = float(altro.get_node("StatsComponent").get("hp"))
	p.call("_su_area_entrata", altro.get_node("Hurtbox"))
	assert_eq(float(altro.get_node("StatsComponent").get("hp")), hp, "l'altro nemico non si fa male")
	p.call("_su_area_entrata", _bersaglio.get_node("Hurtbox"))
	assert_true(float(_bersaglio.get_node("StatsComponent").get("hp")) < float(_bersaglio.get_node("StatsComponent").get_stat("hp_max")), "il giocatore si'")
	_madre.free()
