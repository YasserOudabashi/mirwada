extends "res://tests/test_case.gd"
## US-223 — pagina scaffale (menu principale) e frontespizio (creazione
## personaggio) dentro la shell del libro.

const OverlayScene := preload("res://scenes/book_overlay.tscn")


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	var b: Node = _n("/root/Book")
	if b != null:
		b.call("azzera")
	Engine.get_main_loop().root.get_tree().paused = false
	# slot puliti: lo scaffale legge 0..3 (book.json libro.slot = 4)
	var ss: Node = _n("/root/SaveSystem")
	if ss != null:
		for s in 4:
			ss.call("cancella", s)


func _monta() -> CanvasLayer:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	return ov


func _pagina_corrente_node(ov: CanvasLayer) -> Node:
	var cont: Node = ov.get_node("Pagina/Contenuto")
	return cont.get_child(0) if cont.get_child_count() > 0 else null


func test_scaffale_slot_vuoti_offrono_nuova_partita() -> void:
	var ov: CanvasLayer = _monta()
	_n("/root/Book").call("apri")   # apre su 'copertina' = menu_principale
	var pag: Node = _pagina_corrente_node(ov)
	assert_true(pag != null, "la pagina scaffale e' istanziata")
	var bottoni: Array = pag.get_children().filter(func(c: Node) -> bool: return c is Button)
	assert_eq(bottoni.size(), 4, "un tomo per slot (book.json libro.slot)")
	assert_eq((bottoni[0] as Button).text, tr("BOOK_SCAFFALE_TOMO_NUOVO"), "slot vuoto = tomo nuovo")
	_n("/root/Book").call("chiudi")
	ov.free()


func test_tomo_corrotto_e_bruciato_non_caricabile() -> void:
	# US-015: un save corrotto e' leggibile come danno, mai crash, mai cancellato.
	var f := FileAccess.open("user://saves/slot_1.json", FileAccess.WRITE)
	f.store_string("{ questo non e' json valido")
	f.close()
	var ov: CanvasLayer = _monta()
	_n("/root/Book").call("apri")
	var pag: Node = _pagina_corrente_node(ov)
	var b1: Button = pag.get_children().filter(func(c: Node) -> bool: return c is Button)[1]
	assert_eq(b1.text, tr("BOOK_SCAFFALE_TOMO_BRUCIATO"), "slot corrotto = tomo bruciato")
	assert_true(b1.disabled, "il tomo bruciato non e' caricabile")
	assert_true(FileAccess.file_exists("user://saves/slot_1.json"), "il file corrotto NON e' stato toccato")
	_n("/root/Book").call("chiudi")
	ov.free()


func test_tomo_valido_mostra_il_nome_e_carica() -> void:
	var gs: Node = _n("/root/GameState")
	gs.call("nuova_partita", "Sidon", 2)   # scrive slot 2
	gs.set("_partita_attiva", false)       # simulo un riavvio: partita non attiva
	var ov: CanvasLayer = _monta()
	_n("/root/Book").call("apri")
	var pag: Node = _pagina_corrente_node(ov)
	var b2: Button = pag.get_children().filter(func(c: Node) -> bool: return c is Button)[2]
	assert_true(b2.text.begins_with("Sidon"), "il tomo valido mostra il nome del personaggio")
	b2.emit_signal("pressed")
	assert_true(bool(gs.call("partita_in_corso")), "aprire il tomo carica la partita")
	assert_eq(str(gs.get("nome_personaggio")), "Sidon", "nome caricato dallo slot")
	ov.free()


func test_frontespizio_nome_default_e_conferma() -> void:
	var gs: Node = _n("/root/GameState")
	var ov: CanvasLayer = _monta()
	var book: Node = _n("/root/Book")
	book.call("apri")
	gs.call("scegli_slot", 3)
	book.call("vai_a", "frontespizio")
	for i in 4:
		ov.call("_process", 0.2)
	var pag: Node = _pagina_corrente_node(ov)
	var campo: LineEdit = pag.get_children().filter(func(c: Node) -> bool: return c is LineEdit)[0]
	assert_eq(campo.text, gs.call("nome_default"), "il campo nome parte da 'Enel'")
	campo.text = "Mirco"
	pag.call("conferma")
	assert_true(bool(gs.call("partita_in_corso")), "conferma -> partita iniziata")
	assert_eq(str(gs.get("nome_personaggio")), "Mirco", "il nome scritto finisce nello stato")
	assert_eq(_n("/root/SaveSystem").call("stato_slot", 3), 1, "e nel save dello slot scelto")
	ov.free()


func test_frontespizio_a_partita_in_corso_mostra_chi_sei() -> void:
	var gs: Node = _n("/root/GameState")
	gs.call("nuova_partita", "Enel", 0)
	var ov: CanvasLayer = _monta()
	var book: Node = _n("/root/Book")
	book.call("apri")
	book.call("vai_a", "frontespizio")
	for i in 4:
		ov.call("_process", 0.2)
	var pag: Node = _pagina_corrente_node(ov)
	var campi: Array = pag.get_children().filter(func(c: Node) -> bool: return c is LineEdit)
	assert_eq(campi.size(), 0, "a partita in corso non c'e' piu' il campo nome")
	assert_true(pag.call("testo_visibile").contains("Enel"), "mostra il nome del personaggio")
	ov.free()
