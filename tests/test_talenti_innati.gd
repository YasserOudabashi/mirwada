extends "res://tests/test_case.gd"
## US-332 — talenti innati alla creazione del personaggio.

const OverlayScene := preload("res://scenes/book_overlay.tscn")


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/Book") != null:
		_n("/root/Book").call("azzera")
	Engine.get_main_loop().root.get_tree().paused = false
	var ss: Node = _n("/root/SaveSystem")
	if ss != null:
		for s in 4:
			ss.call("cancella", s)
	if _n("/root/TalentSystem") != null:
		_n("/root/TalentSystem").call("pulisci")
	var gs: Node = _n("/root/GameState")
	if gs != null:
		gs.set("_partita_attiva", false)


func _pagina_frontespizio() -> Dictionary:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var book: Node = _n("/root/Book")
	book.call("apri")
	_n("/root/GameState").call("scegli_slot", 3)
	book.call("vai_a", "frontespizio")
	for i in 4:
		ov.call("_process", 0.2)
	var cont: Node = ov.get_node("Pagina/Contenuto")
	var pag: Node = cont.get_child(0) if cont.get_child_count() > 0 else null
	return {"ov": ov, "pag": pag}


func _checkbox(pag: Node) -> Array:
	return pag.get_children().filter(func(c: Node) -> bool: return c is CheckBox)


func test_una_checkbox_per_ogni_talento_innato() -> void:
	var r: Dictionary = _pagina_frontespizio()
	var pag: Node = r["pag"]
	var gd: Node = _n("/root/GameData")
	var attesi: Array = gd.call("talents_per_tipo", "innato")
	assert_eq((_checkbox(pag) as Array).size(), attesi.size(), "una checkbox per ogni talento innato")
	_n("/root/Book").call("chiudi")
	(r["ov"] as CanvasLayer).free()


func test_selezione_limitata_al_numero_di_balance() -> void:
	var r: Dictionary = _pagina_frontespizio()
	var pag: Node = r["pag"]
	var gd: Node = _n("/root/GameData")
	var limite: int = int((gd.call("get_balance", "talenti") as Dictionary).get("innati_da_scegliere", 2))
	var box: Array = _checkbox(pag)
	assert_gt(float(box.size()), float(limite), "premessa: ci sono piu' talenti del limite")
	for i in box.size():
		(box[i] as CheckBox).button_pressed = true
		(box[i] as CheckBox).emit_signal("toggled", true)
	var selezionati: int = 0
	for c in box:
		if (c as CheckBox).button_pressed:
			selezionati += 1
	assert_eq(selezionati, limite, "oltre il limite, il tocco in eccesso si annulla da solo")
	_n("/root/Book").call("chiudi")
	(r["ov"] as CanvasLayer).free()


func test_conferma_concede_i_talenti_selezionati() -> void:
	var r: Dictionary = _pagina_frontespizio()
	var pag: Node = r["pag"]
	var box: Array = _checkbox(pag)
	(box[0] as CheckBox).button_pressed = true
	(box[0] as CheckBox).emit_signal("toggled", true)
	(box[1] as CheckBox).button_pressed = true
	(box[1] as CheckBox).emit_signal("toggled", true)
	var scelti: Array = pag.call("_talenti_selezionati")
	assert_eq(scelti.size(), 2, "2 selezionati")

	pag.call("conferma")
	var ts: Node = _n("/root/TalentSystem")
	for tid in scelti:
		assert_true(ts.call("possiede", tid), "%s concesso alla creazione" % tid)
	(r["ov"] as CanvasLayer).free()


func test_identita_mostra_i_talenti_posseduti() -> void:
	var gs: Node = _n("/root/GameState")
	gs.call("nuova_partita", "Enel", 0, ["forza_innata"])
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var book: Node = _n("/root/Book")
	book.call("apri")
	book.call("vai_a", "frontespizio")
	for i in 4:
		ov.call("_process", 0.2)
	var cont: Node = ov.get_node("Pagina/Contenuto")
	var pag: Node = cont.get_child(0)
	var gd: Node = _n("/root/GameData")
	var nome: String = str(gd.call("tr_data", gd.call("get_talent", "forza_innata").get("name_i18n", "")))
	assert_true(str(pag.call("testo_visibile")).contains(nome), "il talento posseduto e' mostrato")
	ov.free()
