extends "res://tests/test_case.gd"
## US-8B73b — le due facciate del libro: niente si scrive sulla piega. Una pagina sta a sinistra col titolo, la sua
## `destra` sulla facciata destra; solo "doppia_pagina" (la mappa) usa le due facciate come un foglio.

const OverlayScene := preload("res://scenes/book_overlay.tscn")


func _root() -> Node:
	return Engine.get_main_loop().root


func _monta() -> CanvasLayer:
	var ov: CanvasLayer = OverlayScene.instantiate()
	_root().add_child(ov)
	return ov


func test_il_dialogo_sta_a_sinistra_e_le_scelte_a_destra() -> void:
	var de: Node = _root().get_node("DialogueEngine")
	de.call("termina")
	_root().get_node("Book").call("azzera")
	_root().get_node("Progression").call("configura", "twilight_giant", 9)
	var ov: CanvasLayer = _monta()
	de.call("avvia", "dlg_mirco", "npc_mirco")
	var pagina: Control = ov.get_node("Pagina")
	var sx: Control = ov.get_node("Pagina/Contenuto")
	var dx: Control = ov.get_node("Pagina/Destra")
	var centro: float = pagina.size.x / 2.0
	assert_true(sx.position.x + sx.size.x <= centro - 8.0, "la facciata sinistra finisce prima della piega")
	assert_true(dx.position.x >= centro + 8.0, "la destra comincia dopo la piega")
	assert_true(dx.visible, "la facciata destra si usa")
	var scelte: Array = dx.find_children("*", "Button", true, false)
	assert_eq(scelte.size(), 2, "le 2 scelte sulla facciata destra")
	assert_eq(sx.find_children("*", "Button", true, false).size(), 0, "a sinistra nessuna scelta")
	assert_true(sx.find_child("Ritratto", true, false) != null, "il ritratto a sinistra")
	var titolo: Control = ov.get_node("Pagina/Titolo")
	assert_true(titolo.position.x + titolo.size.x <= centro + 0.5, "il titolo sulla facciata sinistra")
	de.call("termina")
	ov.free()


## US-8B73c: ogni pagina sta nelle sue facciate: niente chiede piu' larghezza di quella che la facciata ha (una
## larghezza minima fissa troppo grande, come i 360 dello scaffale, la spingerebbe oltre la piega).
func test_nessuna_pagina_e_piu_larga_della_sua_facciata() -> void:
	var b: Node = _root().get_node("Book")
	b.call("azzera")
	var ov: CanvasLayer = _monta()
	b.call("apri")
	var provate := 0
	for p in b.call("pagine"):
		var pid: String = str((p as Dictionary).get("id", ""))
		if bool((p as Dictionary).get("transitoria", false)):
			continue                                   # il dialogo: provato sopra, con un dialogo vero
		b.call("vai_a", pid)
		for i in 4:
			ov.call("_process", 0.2)                   # finisce la voltata: la pagina nuova e' disegnata
		for nodo in ["Pagina/Contenuto", "Pagina/Destra"]:
			var f: Control = ov.get_node(nodo)
			if f.visible:
				assert_true(f.get_combined_minimum_size().x <= f.size.x + 0.5,
					"%s: %s chiede %d unita', la facciata ne ha %d" % [pid, nodo,
					int(f.get_combined_minimum_size().x), int(f.size.x)])
		provate += 1
	assert_gt(float(provate), 6.0, "tutte le pagine del libro")
	b.call("chiudi")
	ov.free()


func test_la_mappa_usa_la_doppia_pagina() -> void:
	var b: Node = _root().get_node("Book")
	b.call("azzera")
	var ov: CanvasLayer = _monta()
	b.call("apri_a", "mappa")
	var pagina: Control = ov.get_node("Pagina")
	var sx: Control = ov.get_node("Pagina/Contenuto")
	assert_true(bool((b.call("pagina", "mappa") as Dictionary).get("doppia_pagina", false)), "dato in book.json")
	assert_true(sx.position.x + sx.size.x > pagina.size.x / 2.0, "il contenuto attraversa le due facciate")
	assert_false((ov.get_node("Pagina/Destra") as Control).visible, "niente facciata destra separata")
	b.call("chiudi")
	ov.free()
