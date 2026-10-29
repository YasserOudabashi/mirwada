extends "res://tests/test_case.gd"
## 2026-10-25 — aspetto del libro dai dati (data/ui/book.json "tema", immagini da
## tools/art/build_libro.py): carta disegnata, font del libro, inchiostro, segnalibri di stoffa.

const OverlayScene := preload("res://scenes/book_overlay.tscn")


func _tema() -> Dictionary:
	return (Engine.get_main_loop().root.get_node("GameData").call("get_ui_book") as Dictionary).get("tema", {})


func test_il_tema_del_libro_e_nei_dati_e_i_file_esistono() -> void:
	var t: Dictionary = _tema()
	assert_false(t.is_empty(), "book.json ha il tema del libro")
	for k in ["carta", "ornamento", "segnalibro", "spunta_no", "spunta_si", "font", "font_titolo"]:
		assert_true(FileAccess.file_exists(str(t.get(k, ""))), "tema.%s esiste" % k)


func test_la_pagina_usa_carta_font_e_inchiostro_dei_dati() -> void:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var pagina: Control = ov.get_node("Pagina")
	var carta: TextureRect = pagina.get_node_or_null("Carta")
	assert_true(carta != null and carta.texture != null, "la carta disegnata sta sotto la pagina")
	assert_eq(carta.get_index(), 0, "la carta e' il primo figlio: tutto il resto ci sta sopra")
	assert_false((pagina.get_node("Piega") as CanvasItem).visible, "la piega piatta lascia il posto a quella disegnata")
	assert_true(pagina.theme != null and pagina.theme.default_font != null, "le pagine hanno il font del libro")
	var inchiostro := Color(str(_tema()["colori"]["inchiostro"]))
	assert_eq(pagina.theme.get_color("font_color", "Label"), inchiostro, "testo color inchiostro")
	assert_true(pagina.get_node_or_null("Ornamento") != null, "il filetto sotto il titolo")
	for r in ov.get_node("Segnalibri").get_children():
		assert_true((r as Control).has_theme_stylebox_override("normal"), "i segnalibri sono nastri di stoffa")
	ov.free()
