extends "res://tests/test_case.gd"
## US-410 — la sezione Sinergie della pagina inventario: contatore in cima,
## attiva col suo effetto e le fonti, visibile coi tag mancanti, vista
## offuscata, anti-sinergia marcata.

const OverlayScene := preload("res://scenes/book_overlay.tscn")


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func _se() -> Node:
	return _n("/root/SynergyEngine")


func prepara() -> void:
	if _n("/root/Book") != null:
		_n("/root/Book").call("azzera")
	Engine.get_main_loop().root.get_tree().paused = false
	if _se() != null:
		_se().call("pulisci")


func _fine() -> void:
	if _se() != null:
		_se().call("pulisci")


func _pagina_sinergie() -> Array:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var b: Node = _n("/root/Book")
	b.call("apri")
	b.call("vai_a", "inventario")
	for i in 5:
		ov.call("_process", 0.2)
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)
	pag.call("_mostra", "sinergie")
	var sc: Node = null
	for c in pag.get_children():
		if c is ScrollContainer:
			sc = c
	return [ov, sc.get_child(0).get_children()]


func _testo(righe: Array) -> String:
	var out := ""
	for r in righe:
		if r is Label:
			out += " | " + r.text
		else:
			for c in r.get_children():
				if c is Label:
					out += " | " + c.text
	return out


func test_il_contatore_e_la_prima_riga() -> void:
	var res: Array = _pagina_sinergie()
	assert_true(_testo(res[1]).contains(tr("BOOK_SYN_CONTATORE").split(" ")[0]),
		"in cima c'e' il contatore scoperte / totali")
	res[0].free()
	_fine()


func test_una_sinergia_visibile_mostra_i_tag_mancanti() -> void:
	# tag non correlati -> sinergia_crescita_pozione (scoperta 'visibile') non e' attiva
	_se().call("imposta_override_tag", {"guerra": 1})
	var res: Array = _pagina_sinergie()
	var t: String = _testo(res[1])
	assert_true(t.contains(tr("BOOK_SYN_MANCA")), "una riga 'visibile' dice cosa manca")
	assert_true(t.contains("crescita x2") or t.contains("pozione x2"),
		"coi nomi dei tag e le quantita'")
	res[0].free()
	_fine()


func test_una_sinergia_attiva_mostra_effetto_e_fonti() -> void:
	_se().call("imposta_override_tag", {"crescita": 2, "pozione": 2})
	_se().call("rivaluta")
	var res: Array = _pagina_sinergie()
	var t: String = _testo(res[1])
	assert_true(t.contains("modifica_qualita_crafting"), "la riga attiva riassume l'effetto")
	assert_true(t.contains("stanza") and t.contains("pet"), "e mostra le fonti della sinergia")
	res[0].free()
	_fine()


func test_una_sinergia_vista_e_una_riga_offuscata() -> void:
	_se().call("imposta_override_tag", {"occulto": 1, "conoscenza": 1})
	_se().call("rivaluta")  # attiva sinergia_studio_sereno (nascosta)
	_se().call("imposta_override_tag", {})
	_se().call("rivaluta")  # ora non piu' attiva -> 'vista'
	var res: Array = _pagina_sinergie()
	var offuscata := false
	for r in res[1]:
		if r is Label and absf(r.modulate.a - 0.55) < 0.01:
			offuscata = true
	assert_true(offuscata, "una sinergia gia' vista ma non piu' attiva e' offuscata (alpha 0.55)")
	res[0].free()
	_fine()


func test_una_anti_sinergia_attiva_e_marcata() -> void:
	# anti_furia_e_calma: guerra 2 + occulto 1
	_se().call("imposta_override_tag", {"guerra": 2, "occulto": 1})
	_se().call("rivaluta")
	var res: Array = _pagina_sinergie()
	var t: String = _testo(res[1])
	assert_true(t.contains("▲"), "l'anti-sinergia attiva ha un marcatore")
	assert_true(t.contains("neutralizza"), "e la riga dice quale sinergia neutralizza")
	res[0].free()
	_fine()
