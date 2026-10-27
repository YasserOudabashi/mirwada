extends "res://tests/test_case.gd"
## US-8B74 — all'avvio il libro e' piu' piccolo e intorno scorre il panorama a strati (data/ui/book.json tema).

const OverlayScene := preload("res://scenes/book_overlay.tscn")


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func _overlay(in_partita: bool) -> CanvasLayer:
	_n("/root/GameState").set("_partita_attiva", in_partita)
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var b: Node = _n("/root/Book")
	b.call("azzera")
	b.call("apri")
	return ov


func _chiudi(ov: CanvasLayer) -> void:
	_n("/root/Book").call("chiudi")
	_n("/root/GameState").set("_partita_attiva", false)
	ov.free()


func test_ogni_ora_ha_il_suo_momento() -> void:
	var ov := _overlay(false)
	var attesi := {5: "alba", 8: "alba", 9: "mezzogiorno", 16: "mezzogiorno", 17: "crepuscolo", 20: "crepuscolo",
		21: "notte_fonda", 0: "notte_fonda", 4: "notte_fonda"}
	for ora in attesi:
		assert_eq(ov.call("momento_da_ora", ora), attesi[ora], "alle %d" % ora)
	_chiudi(ov)


func test_all_avvio_il_libro_e_piccolo_col_panorama() -> void:
	var ov := _overlay(false)
	var b: Node = _n("/root/Book")
	assert_eq(str((b.call("pagina", b.call("pagina_corrente")) as Dictionary).get("tipo")), "menu_principale",
		"l'avvio apre lo scaffale")
	var pano: Node2D = ov.get_node("Panorama")
	assert_true(pano.visible, "il panorama si vede")
	assert_eq(pano.get_child_count(), 6, "6 strati")
	for s in pano.get_children():
		assert_true((s as Sprite2D).texture != null, "lo strato %s ha il disegno" % s.name)
	assert_eq((ov.get_node("Pagina") as Control).size, Vector2(440, 250), "il libro piccolo")
	assert_false((ov.get_node("Sfondo") as CanvasItem).visible, "niente velo scuro sopra il panorama")
	_chiudi(ov)


func test_gli_strati_scorrono_a_velocita_diverse() -> void:
	var ov := _overlay(false)
	var nuvole: Sprite2D = ov.get_node("Panorama/clouds")
	var cielo: Sprite2D = ov.get_node("Panorama/sky")
	var x0: float = nuvole.region_rect.position.x
	ov.call("_process", 1.0)
	assert_almost_eq(nuvole.region_rect.position.x - x0, 3.0, "le nuvole scorrono di 3 unita' al secondo", 0.01)
	assert_eq(cielo.region_rect.position.x, 0.0, "il cielo sta fermo")
	_chiudi(ov)


func test_in_partita_il_libro_torna_grande_sopra_il_mondo() -> void:
	var ov := _overlay(true)
	assert_false((ov.get_node("Panorama") as Node2D).visible, "in partita dietro il libro c'e' il mondo")
	assert_eq((ov.get_node("Pagina") as Control).size, Vector2(600, 340), "il libro grande")
	assert_true((ov.get_node("Sfondo") as CanvasItem).visible, "col velo scuro di sempre")
	_chiudi(ov)
