extends "res://tests/test_case.gd"
## US-314 — la sezione ricettario della pagina inventario.

const OverlayScene := preload("res://scenes/book_overlay.tscn")


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func prepara() -> void:
	if _n("/root/Book") != null:
		_n("/root/Book").call("azzera")
	Engine.get_main_loop().root.get_tree().paused = false
	for a in ["/root/Inventory", "/root/KnowledgeStore"]:
		if _n(a) != null:
			_n(a).call("pulisci" if a.ends_with("Inventory") else "dimentica_tutto")


func _pagina_ricettario() -> Array:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var b: Node = _n("/root/Book")
	b.call("apri")
	b.call("vai_a", "inventario")
	for i in 4:
		ov.call("_process", 0.2)
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)
	pag.call("_mostra", "ricettario")
	var sc: Node = null
	for c in pag.get_children():
		if c is ScrollContainer:
			sc = c
	return [ov, sc.get_child(0).get_children()]


func _testo(righe: Array) -> String:
	var t := ""
	for r in righe:
		for c in (r.get_children() if not (r is Label) else [r]):
			if c is Label:
				t += " | " + c.text
	return t


func test_le_base_sono_sempre_visibili_le_altre_offuscate() -> void:
	var res: Array = _pagina_ricettario()
	var t: String = _testo(res[1])
	assert_true(t.contains("Cura minore"), "una ricetta base e' visibile per nome")
	assert_true(t.to_lower().contains("sconosciuta"), "le non note sono righe offuscate, non assenti")
	res[0].free()


func test_una_avanzata_scoperta_compare_col_nome() -> void:
	_n("/root/KnowledgeStore").call("impara", "ricetta:ric_elisir_ombra")
	var res: Array = _pagina_ricettario()
	assert_true(_testo(res[1]).contains("Elisir d ombra"), "l'avanzata scoperta ora si legge")
	res[0].free()


func test_prepara_dal_ricettario() -> void:
	var inv: Node = _n("/root/Inventory")
	var gd: Node = _n("/root/GameData")
	for ing in (gd.call("get_recipe", "ric_cura_minore").get("ingredienti", {}) as Dictionary):
		inv.call("aggiungi", ing, 3)
	var res: Array = _pagina_ricettario()
	var premuto := false
	for r in res[1]:
		for c in (r.get_children() if not (r is Label) else []):
			if c is Button and c.text == tr("BOOK_RIC_PREPARA") and not c.disabled:
				c.emit_signal("pressed")
				premuto = true
				break
		if premuto:
			break
	assert_true(premuto, "c'e' un pulsante Prepara attivo per una ricetta con ingredienti")
	assert_gt(float(inv.call("conta", "pozione_cura_minore")), 0.0, "la pozione e' stata preparata")
	res[0].free()
