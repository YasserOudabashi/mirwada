extends "res://tests/test_case.gd"
## US-329 — la base nel libro: le 4 stanze + il giardino nella pagina
## inventario.

const OverlayScene := preload("res://scenes/book_overlay.tscn")
const StatsComponent := preload("res://scripts/stats_component.gd")

var _p: Node2D = null


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func prepara() -> void:
	if _n("/root/Book") != null:
		_n("/root/Book").call("azzera")
	Engine.get_main_loop().root.get_tree().paused = false
	for a in ["/root/Inventory", "/root/BaseSystem"]:
		if _n(a) != null:
			_n(a).call("pulisci")
	if _n("/root/GameState") != null:
		_n("/root/GameState").set("tempo_gioco", 0.0)
	_p = Node2D.new()
	_p.add_to_group("player")
	var st: Node = StatsComponent.new()
	st.name = "StatsComponent"
	st.call("configure_from_balance", 9)
	_p.add_child(st)
	Engine.get_main_loop().root.add_child(_p)


func _pagina_base(ov: CanvasLayer) -> Node:
	var b: Node = _n("/root/Book")
	b.call("apri")
	b.call("vai_a", "inventario")
	for i in 4:
		ov.call("_process", 0.2)
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)
	pag.call("_mostra", "base")
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


func _bottone(pag: Node, testo: String) -> Button:
	for r in _righe(pag):
		for c in r.get_children():
			if c is Button and c.text == testo:
				return c
	return null


func test_stanze_non_costruite_mostrano_il_pulsante_costruisci() -> void:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var pag: Node = _pagina_base(ov)
	assert_true(_testo(pag).contains(tr("BOOK_STANZA_NON_COSTRUITA")), "le 4 stanze partono non costruite")
	assert_true(_bottone(pag, tr("BOOK_STANZA_COSTRUISCI")) != null, "c'e' un pulsante per costruire")
	_n("/root/Book").call("chiudi")
	ov.free()
	_p.free()


func test_pulsante_costruisci_disabilitato_senza_materiali() -> void:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var pag: Node = _pagina_base(ov)
	var b: Button = _bottone(pag, tr("BOOK_STANZA_COSTRUISCI"))
	assert_true(b.disabled, "senza materiali il pulsante e' disabilitato")
	_n("/root/Book").call("chiudi")
	ov.free()
	_p.free()


func test_costruisci_dal_libro_sale_di_livello() -> void:
	_n("/root/Inventory").call("aggiungi", "lingotto_ferro", 2)
	_n("/root/Inventory").call("aggiungi", "cristallo_grezzo", 1)
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var pag: Node = _pagina_base(ov)
	var b: Button = _bottone(pag, tr("BOOK_STANZA_COSTRUISCI"))
	assert_false(b.disabled, "col costo coperto il pulsante e' attivo")
	b.emit_signal("pressed")
	assert_eq(_n("/root/BaseSystem").call("livello", "laboratorio"), 1, "costruita dal libro")
	_n("/root/Book").call("chiudi")
	ov.free()
	_p.free()


func test_giardino_mostra_appezzamento_vuoto_e_lo_pianta() -> void:
	_n("/root/Inventory").call("aggiungi", "cuoio_conciato", 1)
	_n("/root/BaseSystem").call("costruisci", "giardino")
	_n("/root/Inventory").call("aggiungi", "erba_lunare", 1)

	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var pag: Node = _pagina_base(ov)
	assert_true(_testo(pag).contains(tr("BOOK_GIARDINO_VUOTO")), "l'appezzamento vuoto e' mostrato")
	var pianta: Button = _bottone(pag, tr("BOOK_GIARDINO_PIANTA"))
	assert_true(pianta != null, "c'e' un pulsante per piantare l'ingrediente posseduto")
	pianta.emit_signal("pressed")
	assert_eq((_n("/root/BaseSystem").call("appezzamenti") as Array).size(), 1, "piantato")
	_n("/root/Book").call("chiudi")
	ov.free()
	_p.free()


func test_giardino_appezzamento_pronto_mostra_raccogli() -> void:
	_n("/root/Inventory").call("aggiungi", "cuoio_conciato", 1)
	_n("/root/BaseSystem").call("costruisci", "giardino")
	_n("/root/Inventory").call("aggiungi", "erba_lunare", 1)
	_n("/root/BaseSystem").call("pianta", "erba_lunare")
	_n("/root/GameState").set("tempo_gioco", 999.0)

	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var pag: Node = _pagina_base(ov)
	assert_true(_testo(pag).contains(tr("BOOK_GIARDINO_PRONTO")), "l'appezzamento pronto e' segnalato")
	var raccogli: Button = _bottone(pag, tr("BOOK_GIARDINO_RACCOGLI"))
	assert_true(raccogli != null, "c'e' un pulsante raccogli")
	raccogli.emit_signal("pressed")
	assert_eq(_n("/root/Inventory").call("conta", "erba_lunare"), 2, "raccolto nell'inventario")
	_n("/root/Book").call("chiudi")
	ov.free()
	_p.free()
