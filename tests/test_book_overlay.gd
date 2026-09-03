extends "res://tests/test_case.gd"
## US-222 — rappresentazione visiva del libro: voltata, navigazione, stato.
## Il controller (Book) e' testato in test_book.gd; qui il nodo di presentazione.

const OverlayScene := preload("res://scenes/book_overlay.tscn")


func _book() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Book")


func prepara() -> void:
	var b: Node = _book()
	if b != null:
		b.call("azzera")
	Engine.get_main_loop().root.get_tree().paused = false
	var am: Node = Engine.get_main_loop().root.get_node_or_null("AudioManager")
	if am != null:
		am.call("imposta_accessibilita", "riduci_animazioni", false)


func _monta() -> CanvasLayer:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	return ov


## Fa avanzare l'animazione di voltata fino in fondo.
func _completa_voltata(ov: CanvasLayer) -> void:
	for i in 4:
		ov.call("_process", 0.2)


func test_apri_mostra_il_titolo_della_pagina() -> void:
	var ov: CanvasLayer = _monta()
	_book().call("apri")
	assert_true(ov.call("e_visibile"), "overlay visibile a libro aperto")
	# copertina -> ui.page.copertina -> "Scaffale" (data/i18n/it.json)
	assert_eq(ov.call("titolo"), "Scaffale", "titolo dalla chiave i18n della pagina")
	_book().call("chiudi")
	assert_false(ov.call("e_visibile"), "overlay nascosto a libro chiuso")
	ov.free()


func test_navigazione_cambia_pagina() -> void:
	var ov: CanvasLayer = _monta()
	_book().call("apri")
	_book().call("avanti")            # copertina -> frontespizio
	_completa_voltata(ov)
	assert_eq(_book().call("pagina_corrente"), "frontespizio", "avanti passa alla pagina dopo")
	assert_eq(ov.call("titolo"), "Frontespizio", "il titolo segue la pagina")
	_book().call("indietro")
	_completa_voltata(ov)
	assert_eq(ov.call("titolo"), "Scaffale", "indietro torna alla pagina prima")
	_book().call("chiudi")
	ov.free()


func test_pagina_bianca_mostra_l_appunto() -> void:
	var ov: CanvasLayer = _monta()
	_book().call("apri")
	_book().call("vai_a", "mappa")   # sbloccata_da fase 6, oggi bianca
	_completa_voltata(ov)
	assert_true(ov.call("corpo").to_lower().contains("appunto a matita"),
		"una pagina non ancora sbloccata mostra l'appunto a matita, non e' assente")
	_book().call("chiudi")
	ov.free()


func test_voltata_ha_una_durata_finita() -> void:
	var ov: CanvasLayer = _monta()
	_book().call("apri")
	_book().call("avanti")
	assert_true(ov.call("voltata_in_corso"), "la voltata parte")
	_completa_voltata(ov)
	assert_false(ov.call("voltata_in_corso"), "la voltata finisce (durata = voltata_ms)")
	_book().call("chiudi")
	ov.free()


func test_riduci_animazioni_scorcia_la_voltata() -> void:
	var am: Node = Engine.get_main_loop().root.get_node_or_null("AudioManager")
	if am == null:
		return
	am.call("imposta_accessibilita", "riduci_animazioni", true)
	var ov: CanvasLayer = _monta()
	_book().call("apri")
	_book().call("avanti")
	# con riduci_animazioni la dissolvenza dura ~80 ms: un solo tick da 0.2s la chiude
	ov.call("_process", 0.2)
	assert_false(ov.call("voltata_in_corso"), "dissolvenza ridotta: finisce in un tick")
	assert_eq(ov.call("titolo"), "Frontespizio", "l'informazione (titolo) c'e' comunque")
	_book().call("chiudi")
	am.call("imposta_accessibilita", "riduci_animazioni", false)
	ov.free()
