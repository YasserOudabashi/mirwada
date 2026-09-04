extends "res://tests/test_case.gd"
## US-333 — la sezione talenti nel libro: posseduti con effetto, acquisiti
## non ancora presi con una barra di progresso, offuscati finche' il
## giocatore non ha visto nessun progresso verso il loro sblocco.

const OverlayScene := preload("res://scenes/book_overlay.tscn")


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func prepara() -> void:
	if _n("/root/Book") != null:
		_n("/root/Book").call("azzera")
	Engine.get_main_loop().root.get_tree().paused = false
	if _n("/root/TalentSystem") != null:
		_n("/root/TalentSystem").call("pulisci")
	if _n("/root/TalentTracker") != null:
		_n("/root/TalentTracker").call("azzera")
	if _n("/root/EventTracker") != null:
		_n("/root/EventTracker").call("azzera")


func _pagina_talenti(ov: CanvasLayer) -> Node:
	var b: Node = _n("/root/Book")
	b.call("apri")
	b.call("vai_a", "inventario")
	for i in 4:
		ov.call("_process", 0.2)
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)
	pag.call("_mostra", "talenti")
	return pag


func _righe(pag: Node) -> Array:
	var sc: Node = null
	for c in pag.get_children():
		if c is ScrollContainer:
			sc = c
	return sc.get_child(0).get_children() if sc != null else []


func _testo(pag: Node) -> String:
	var t := ""
	for r in _righe(pag):
		if r is Label:
			t += " " + (r as Label).text
		for c in r.get_children():
			if c is Label:
				t += " " + c.text
	return t


func _ha_barra(pag: Node) -> bool:
	for r in _righe(pag):
		for c in r.get_children():
			if c is ProgressBar:
				return true
	return false


func test_talento_posseduto_mostra_nome_ed_effetto() -> void:
	_n("/root/TalentSystem").call("concedi", "spirito_innato")
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var pag: Node = _pagina_talenti(ov)
	var gd: Node = _n("/root/GameData")
	var nome: String = str(gd.call("tr_data", gd.call("get_talent", "spirito_innato").get("name_i18n", "")))
	var t: String = _testo(pag)
	assert_true(t.contains(nome), "il talento posseduto e' mostrato per nome")
	assert_true(t.contains("spiritualita_max"), "l'effetto e' mostrato in chiaro")
	_n("/root/Book").call("chiudi")
	ov.free()


func test_acquisito_senza_progresso_e_offuscato() -> void:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var pag: Node = _pagina_talenti(ov)
	var gd: Node = _n("/root/GameData")
	var t: String = _testo(pag)
	assert_true(t.contains(tr("BOOK_TAL_SCONOSCIUTO")), "acquisito senza progresso: offuscato")
	var nome: String = str(gd.call("tr_data", gd.call("get_talent", "viandante_instancabile").get("name_i18n", "")))
	assert_false(t.contains(nome), "il nome resta nascosto finche' non c'e' progresso")
	_n("/root/Book").call("chiudi")
	ov.free()


func test_acquisito_con_progresso_mostra_nome_e_barra() -> void:
	_n("/root/TalentTracker").call("emit_event", "distanza_percorsa", {"quantita": 100.0})
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var pag: Node = _pagina_talenti(ov)
	var gd: Node = _n("/root/GameData")
	var nome: String = str(gd.call("tr_data", gd.call("get_talent", "viandante_instancabile").get("name_i18n", "")))
	var t: String = _testo(pag)
	assert_true(t.contains(nome), "col progresso il nome e' visibile")
	assert_true(_ha_barra(pag), "c'e' una barra di progresso")
	_n("/root/Book").call("chiudi")
	ov.free()


func test_talento_sbloccato_passa_ai_posseduti() -> void:
	_n("/root/TalentTracker").call("emit_event", "distanza_percorsa", {"quantita": 6000.0})
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var pag: Node = _pagina_talenti(ov)
	assert_true(_n("/root/TalentSystem").call("possiede", "viandante_instancabile"), "premessa: sbloccato")
	var gd: Node = _n("/root/GameData")
	var nome: String = str(gd.call("tr_data", gd.call("get_talent", "viandante_instancabile").get("name_i18n", "")))
	assert_true(_testo(pag).contains(nome), "sbloccato: mostrato tra i posseduti")
	_n("/root/Book").call("chiudi")
	ov.free()
