extends "res://tests/test_case.gd"
## US-1503 — Il nemico che carica (tell, scatto in linea, si ferma contro un muro, poi resta scoperto a lungo) e il
## nemico che vola (passa sopra i dislivelli, non sopra l'acqua).

func _root() -> Node: return Engine.get_main_loop().root

var _madre: Node2D = null


func _nemico(tipo: String) -> Node:
	_madre = Node2D.new()
	_root().add_child(_madre)
	var e: Node = preload("res://scenes/enemy.tscn").instantiate()
	e.set("tipo", tipo)
	_madre.add_child(e)
	return e


func _muro(x: float, strato: int) -> void:
	var muro := StaticBody2D.new()
	muro.collision_layer = strato
	var f := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 400)
	f.shape = r
	muro.add_child(f)
	muro.position = Vector2(x, 0)
	_madre.add_child(muro)


func test_la_carica_si_ferma_contro_un_muro_e_resta_scoperta() -> void:
	var e: CharacterBody2D = _nemico("scaricatore_ubriaco")
	var bersaglio := Node2D.new()
	bersaglio.position = Vector2(100, 0)
	_madre.add_child(bersaglio)
	e.set("_bersaglio", bersaglio)
	_muro(60, 1)
	await Engine.get_main_loop().physics_frame
	await Engine.get_main_loop().physics_frame
	e.call("_vai", 1)
	e.call("_physics_process", 0.016)
	assert_eq(str(e.call("stato")), "ANTICIPO", "a portata di carica comincia il tell")
	for i in 80:
		e.call("_physics_process", 0.016)
		if str(e.call("stato")) == "ATTACCO":
			break
	assert_eq(str(e.call("stato")), "ATTACCO", "finito il tell scatta")
	for i in 60:
		e.call("_physics_process", 0.016)
		if str(e.call("stato")) != "ATTACCO":
			break
	assert_eq(str(e.call("stato")), "RECUPERO", "si ferma")
	assert_true(e.position.x < 60.0 - 8.0 + 1.0, "contro il muro, non dall'altra parte (x %.1f)" % e.position.x)
	var tipi: Dictionary = Engine.get_main_loop().root.get_node("GameData").call("get_balance", "nemico_base")
	assert_almost_eq(float(e.get("_recupero_left")), float(tipi["carica"]["recupero_s"]), "e resta scoperto a lungo", 0.05)
	_madre.free()


func test_chi_vola_passa_sopra_i_dislivelli_ma_non_l_acqua() -> void:
	var e: CharacterBody2D = _nemico("corvo_della_battaglia")
	var mondo := preload("res://scripts/world/mondo.gd")
	assert_eq(e.collision_mask & mondo.STRATO_DISLIVELLI, 0, "i dislivelli non lo fermano")
	assert_ne(e.collision_mask & mondo.STRATO_COLLISIONE, 0, "l'acqua e i muri si'")
	assert_true((e.get_node("AnimationMachine") as Node2D).position.y < 0.0, "e la figura sta piu' in alto")
	_madre.free()
	var a: CharacterBody2D = _nemico("soldato_caduto")
	assert_ne(a.collision_mask & mondo.STRATO_DISLIVELLI, 0, "chi cammina si ferma ai dislivelli")
	_madre.free()
