extends "res://tests/test_case.gd"
## US-307 — pagina inventario del libro.

const OverlayScene := preload("res://scenes/book_overlay.tscn")
const StatsComponent := preload("res://scripts/stats_component.gd")

var _p: Node2D = null


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func prepara() -> void:
	if _n("/root/Book") != null:
		_n("/root/Book").call("azzera")
	Engine.get_main_loop().root.get_tree().paused = false
	for a in ["/root/Inventory", "/root/Equipment"]:
		if _n(a) != null:
			_n(a).call("pulisci")
	_p = Node2D.new()
	_p.add_to_group("player")
	var st: Node = StatsComponent.new()
	st.name = "StatsComponent"
	st.call("configure_from_balance", 9)
	_p.add_child(st)
	Engine.get_main_loop().root.add_child(_p)


func _pagina(ov: CanvasLayer) -> Node:
	var b: Node = _n("/root/Book")
	b.call("apri")
	b.call("vai_a", "inventario")
	for i in 4:
		ov.call("_process", 0.2)
	return ov.get_node("Pagina/Contenuto").get_child(0)


func _righe(pag: Node) -> Array:
	# ScrollContainer > VBox (il "corpo")
	var sc: Node = null
	for c in pag.get_children():
		if c is ScrollContainer:
			sc = c
	return sc.get_child(0).get_children() if sc != null else []


func test_pagina_inventario_e_istanziata() -> void:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var pag: Node = _pagina(ov)
	assert_eq(pag.call("testo_visibile"), "inventario", "la pagina inventario e' scritta, non bianca")
	_n("/root/Book").call("chiudi")
	ov.free()
	_p.free()


func test_lo_zaino_elenca_gli_item() -> void:
	_n("/root/Inventory").call("aggiungi", "erba_lunare", 3)
	_n("/root/Inventory").call("aggiungi", "spada_ferrea", 1)
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var pag: Node = _pagina(ov)
	var testo := ""
	for r in _righe(pag):
		testo += (r.get("text") if r is Label else "")
		for c in (r.get_children() if not (r is Label) else []):
			if c is Label:
				testo += " " + c.text
	assert_true(testo.contains("Erba lunare"), "l'erba lunare compare nello zaino")
	assert_true(testo.contains("Spada ferrea"), "la spada compare nello zaino")
	_n("/root/Book").call("chiudi")
	ov.free()
	_p.free()


func test_equipaggia_dalla_pagina() -> void:
	_n("/root/Inventory").call("aggiungi", "spada_ferrea", 1)
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var pag: Node = _pagina(ov)
	# trova il bottone "Indossa" e premilo
	var premuto := false
	for r in _righe(pag):
		for c in (r.get_children() if not (r is Label) else []):
			if c is Button and c.text == tr("BOOK_INV_EQUIPAGGIA"):
				c.emit_signal("pressed")
				premuto = true
	assert_true(premuto, "c'e' un pulsante per equipaggiare")
	assert_eq(_n("/root/Equipment").call("slot_pieni").get("arma"), "spada_ferrea",
		"equipaggiata dalla pagina del libro")
	_n("/root/Equipment").call("pulisci")
	_n("/root/Book").call("chiudi")
	ov.free()
	_p.free()


func test_sezione_indosso_mostra_i_quattro_slot() -> void:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var pag: Node = _pagina(ov)
	pag.call("_mostra", "indosso")
	var testo := ""
	for r in _righe(pag):
		for c in (r.get_children() if not (r is Label) else [r]):
			if c is Label:
				testo += " " + c.text
	for etichetta in ["Arma", "Armatura", "Accessorio I", "Accessorio II"]:
		assert_true(testo.contains(etichetta), "lo slot '%s' e' elencato" % etichetta)
	_n("/root/Book").call("chiudi")
	ov.free()
	_p.free()


func _testo_righe(pag: Node) -> String:
	var t := ""
	for r in _righe(pag):
		if r is Label:
			t += " " + r.text
	return t


func test_sezione_journal_riflette_lo_stato_delle_quest() -> void:
	var qs: Node = _n("/root/QuestSystem")
	var ks: Node = _n("/root/KnowledgeStore")
	var et: Node = _n("/root/EventTracker")
	qs.call("pulisci"); ks.call("dimentica_tutto"); et.call("azzera")
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var pag: Node = _pagina(ov)

	pag.call("_mostra", "journal")
	assert_true(_testo_righe(pag).contains(tr("BOOK_JOURNAL_VUOTO")), "diario vuoto all'inizio")

	qs.call("avvia", "q_mirco_01")
	# aperta su 'journal': il segnale ridisegna dal vivo
	assert_true(_testo_righe(pag).contains("Le basi"), "la quest attiva compare nel diario")
	assert_true(_testo_righe(pag).contains(tr("BOOK_JOURNAL_ATTIVE")), "sezione 'In corso'")

	for i in 3:
		et.call("emit_event", "enemy_defeated", {"senza_abilita": true})
	assert_eq(str(qs.call("stato", "q_mirco_01")), "completata", "quest completata")
	assert_true(_testo_righe(pag).contains(tr("BOOK_JOURNAL_COMPLETATE")), "ora e' sotto 'Completate'")

	qs.call("pulisci"); ks.call("dimentica_tutto"); et.call("azzera")
	_n("/root/Book").call("chiudi")
	ov.free()
	_p.free()
