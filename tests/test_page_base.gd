extends "res://tests/test_case.gd"
## US-329 — la sezione Base della pagina inventario: le 4 stanze (livello,
## costo, bonus, costruisci/potenzia) e il giardino (appezzamenti + raccogli).

const OverlayScene := preload("res://scenes/book_overlay.tscn")


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func prepara() -> void:
	if _n("/root/Book") != null:
		_n("/root/Book").call("azzera")
	Engine.get_main_loop().root.get_tree().paused = false
	for a in ["/root/Inventory", "/root/BaseSystem"]:
		if _n(a) != null:
			_n(a).call("pulisci")


func _pagina_base() -> Array:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var b: Node = _n("/root/Book")
	b.call("apri")
	b.call("vai_a", "inventario")
	for i in 4:
		ov.call("_process", 0.2)
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)
	pag.call("_mostra", "base")
	var sc: Node = null
	for c in pag.get_children():
		if c is ScrollContainer:
			sc = c
	return [ov, sc.get_child(0).get_children(), pag]


func _testo(righe: Array) -> String:
	var t := ""
	for r in righe:
		for c in (r.get_children() if not (r is Label) else [r]):
			if c is Label:
				t += " | " + c.text
	return t


func _rifornisci(tipo: String) -> void:
	var bs: Node = _n("/root/BaseSystem")
	var costo: Dictionary = bs.call("costo_prossimo", tipo)
	for item_id in costo:
		_n("/root/Inventory").call("aggiungi", item_id, int(costo[item_id]))


func test_le_4_stanze_compaiono_col_loro_stato() -> void:
	var res: Array = _pagina_base()
	var t: String = _testo(res[1])
	for nome in ["Laboratorio", "Stanza rituale", "Biblioteca", "Giardino"]:
		assert_true(t.contains(nome), "la stanza '%s' e' elencata" % nome)
	assert_true(t.contains(tr("BOOK_BASE_NON_COSTRUITA")), "una stanza non costruita lo dichiara")
	res[0].free()


func test_costruisci_dalla_pagina_solo_col_costo_coperto() -> void:
	# solo il laboratorio ha i materiali: il suo bottone e' attivo, gli altri no
	_rifornisci("laboratorio")
	var res: Array = _pagina_base()
	var lab_attivo := false
	var altri_disabilitati := false
	for r in res[1]:
		for c in (r.get_children() if not (r is Label) else []):
			if c is Button and c.text == tr("BOOK_BASE_COSTRUISCI"):
				if not c.disabled:
					c.emit_signal("pressed")
					lab_attivo = true
				else:
					altri_disabilitati = true
	assert_true(lab_attivo, "col costo coperto il pulsante Costruisci e' attivo")
	assert_true(altri_disabilitati, "senza materiali gli altri pulsanti sono disabilitati")
	assert_eq(int(_n("/root/BaseSystem").call("livello", "laboratorio")), 1,
		"laboratorio costruito dalla pagina del libro")
	res[0].free()


func test_il_giardino_in_crescita_mostra_il_conto_alla_rovescia() -> void:
	var bs: Node = _n("/root/BaseSystem")
	_rifornisci("giardino")
	bs.call("costruisci", "giardino")
	_n("/root/Inventory").call("aggiungi", "erba_lunare", 1)
	bs.call("pianta", "erba_lunare")

	var res: Array = _pagina_base()
	var t: String = _testo(res[1])
	assert_true(t.contains(tr("BOOK_BASE_GIARDINO_TITOLO")), "il giardino ha la sua sezione")
	assert_true(t.to_lower().contains("crescita"), "l'appezzamento in crescita mostra il conto alla rovescia")
	res[0].free()


func test_raccogli_dalla_pagina_quando_l_appezzamento_e_pronto() -> void:
	var bs: Node = _n("/root/BaseSystem")
	_rifornisci("giardino")
	bs.call("costruisci", "giardino")
	_n("/root/Inventory").call("aggiungi", "erba_lunare", 1)
	bs.call("pianta", "erba_lunare")
	bs.call("_process", 999.0)  # matura

	var res: Array = _pagina_base()
	var raccolto := false
	for r in res[1]:
		for c in (r.get_children() if not (r is Label) else []):
			if c is Button and c.text == tr("BOOK_BASE_RACCOGLI"):
				c.emit_signal("pressed")
				raccolto = true
	assert_true(raccolto, "un appezzamento pronto ha il pulsante Raccogli")
	assert_gt(float(_n("/root/Inventory").call("conta", "erba_lunare")), 0.0,
		"raccolto dalla pagina del libro -> erba lunare in zaino")
	res[0].free()
