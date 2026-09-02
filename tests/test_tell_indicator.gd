extends "res://tests/test_case.gd"
## US-020 — indicatore visivo/direzionale del tell.

const Scene := preload("res://scenes/tell_indicator.tscn")


func _overlay() -> Control:
	var cl: CanvasLayer = Scene.instantiate()
	Engine.get_main_loop().root.add_child(cl)
	var o: Control = cl.get_node("Overlay")
	o.size = Vector2(640, 360)  # in headless il layout non gira da solo
	return o


func test_un_tell_crea_un_indicatore_che_scade() -> void:
	var o: Control = _overlay()
	o.call("_su_tell", Vector2(100, 100), "schivabile")
	assert_eq(o.call("indicatori_attivi"), 1, "un indicatore attivo dopo il tell")
	o.call("_process", 1.0)  # DURATA = 0.6
	assert_eq(o.call("indicatori_attivi"), 0, "l'indicatore scade da solo")
	o.get_parent().free()


func test_il_punto_direzionale_resta_dentro_lo_schermo() -> void:
	var o: Control = _overlay()
	var rect := Rect2(Vector2.ZERO, Vector2(640, 360))
	for ang in [0.0, 1.0, 2.5, -1.7, 3.0, -2.9]:
		var dir := Vector2(cos(ang), sin(ang))
		var p: Vector2 = o.call("_punto_sul_bordo", rect.size * 0.5, dir, rect)
		assert_true(rect.grow(1.0).has_point(p),
			"freccia dentro lo schermo per angolo %s" % ang)
	o.get_parent().free()
