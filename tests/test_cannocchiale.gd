extends "res://tests/test_case.gd"
## US-8B24 — cannocchiale: fisso accanto al faro (data/world/cannocchiali.json), la vista vola fino alla Frontiera e
## torna; intanto il giocatore e' fermo.

const Cannocchiale := preload("res://scripts/cannocchiale.gd")


func _root() -> Node:
	return Engine.get_main_loop().root


func test_il_cannocchiale_sta_al_faro_e_guarda_la_frontiera() -> void:
	var m: Node2D = preload("res://scripts/world/mondo.gd").new()
	m.set("tema", "luminoso")
	assert_true(m.call("carica"), "mondo caricato")
	m.call("crea_cannocchiali")
	var tutti: Array = m.get_children().filter(func(c): return c.get_script() == Cannocchiale)
	assert_eq(tutti.size(), 1, "il cannocchiale del faro")
	var c: Area2D = tutti[0]
	var luoghi: Dictionary = (m.get("dati") as Dictionary)["luoghi"]
	var cella := Vector2i(floori(c.position.x / m.tile), floori(c.position.y / m.tile))
	var faro := Vector2(luoghi["faro"][0], luoghi["faro"][1])
	assert_true(Vector2(cella).distance_to(faro) < 8.0, "accanto al faro")
	assert_false(bool(m.call("bloccata", cella.x, cella.y)), "su una casella libera")
	var frontiera := Vector2(luoghi["approdo_frontiera"][0], luoghi["approdo_frontiera"][1])
	assert_true((c.get("bersaglio") as Vector2 / m.tile).distance_to(frontiera) < 10.0, "guarda la Frontiera")
	assert_eq(str(c.get_meta("livello")), "superficie", "sotto terra non c'e'")
	m.free()


func test_la_vista_vola_al_bersaglio_e_torna() -> void:
	var mondo := Node2D.new()
	_root().add_child(mondo)
	var p: CharacterBody2D = preload("res://scenes/player.tscn").instantiate()
	mondo.add_child(p)
	p.position = Vector2(100, 100)
	var c: Area2D = Cannocchiale.new()
	c.call("setup", "prova", Vector2(100, 68), Vector2(900, 700), {"volo": 1.0, "lente": 0.4, "nebbia": 2.0})
	mondo.add_child(c)
	assert_false(bool(c.call("guarda")), "senza nessuno accanto non si guarda")
	c.call("_su_corpo", p, true)
	assert_true(bool(c.call("guarda")), "accanto: si guarda")
	assert_true(bool(c.call("sta_guardando")), "sta guardando")
	assert_false(p.is_physics_processing(), "il giocatore e' fermo")
	var cam: Camera2D = c.get("_camera")
	assert_eq(mondo.get_viewport().get_camera_2d(), cam, "la vista e' la telecamera del cannocchiale")
	var lente: CanvasLayer = c.get("_lente")
	assert_true(lente != null and lente.layer > 1, "la lente sopra il mondo")
	var mat: ShaderMaterial = c.get("_mat")
	assert_eq(float(mat.get_shader_parameter("nebbia")), 1.0, "partendo c'e' la nebbia")
	(c.get("_tween") as Tween).custom_step(1.0)
	assert_true(cam.global_position.distance_to(Vector2(900, 700)) < 1.0, "e' arrivata sul bersaglio")
	assert_almost_eq(float(mat.get_shader_parameter("raggio")), 0.4, "la lente stretta al suo raggio", 0.001)
	(c.get("_tween") as Tween).custom_step(3.0)
	assert_almost_eq(float(mat.get_shader_parameter("nebbia")), 0.0, "arrivati, la nebbia si dirada", 0.001)
	c.call("torna")
	(c.get("_tween") as Tween).custom_step(5.0)
	assert_false(bool(c.call("sta_guardando")), "tornata")
	assert_true(p.is_physics_processing(), "il giocatore si muove di nuovo")
	assert_eq(mondo.get_viewport().get_camera_2d(), p.get_node("Camera2D"), "con la sua telecamera")
	assert_true(c.get("_lente") == null, "la lente se ne va")
	mondo.free()
