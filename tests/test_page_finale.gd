extends "res://tests/test_case.gd"
## US-718 — la schermata di finale estende il colophon (page_impostazioni.gd)
## invece di un tipo di pagina nuovo (page_types.json e' un vocabolario
## chiuso). Appare solo se EndgameState.finale non e' vuoto.

const OverlayScene := preload("res://scenes/book_overlay.tscn")


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	var b: Node = _n("/root/Book")
	if b != null:
		b.call("azzera")
	Engine.get_main_loop().root.get_tree().paused = false
	_n("/root/EndgameState").call("pulisci")
	_n("/root/Progression").call("configura", "twilight_giant", 0)


func _fine() -> void:
	_n("/root/EndgameState").call("pulisci")
	_n("/root/Progression").call("configura", "", 9)
	if bool(_n("/root/Book").call("e_aperto")):
		_n("/root/Book").call("chiudi")


func _pagina() -> CanvasLayer:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var b: Node = _n("/root/Book")
	b.call("apri")
	b.call("vai_a", "colophon")
	for i in 4:
		ov.call("_process", 0.2)
	return ov


func _testo(ov: CanvasLayer) -> String:
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)
	var out: Array = []
	_raccogli_testo(pag, out)
	return "\n".join(out)


func _raccogli_testo(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_raccogli_testo(c, out)


func test_nessun_finale_niente_sezione() -> void:
	var ov: CanvasLayer = _pagina()
	var testo: String = _testo(ov)
	assert_false(testo.contains("Ciò che passa"), "senza finale raggiunto, nessuna sezione")
	_n("/root/Book").call("chiudi")
	ov.free()
	_fine()


func test_finale_raggiunto_mostra_nome_ed_epilogo() -> void:
	var gd: Node = _n("/root/GameData")
	_n("/root/EndgameState").call("imposta_finale", "apoteosi")
	var ov: CanvasLayer = _pagina()
	var testo: String = _testo(ov)
	var nome: String = str(gd.call("tr_data", gd.call("get_ending", "apoteosi").get("name_i18n")))
	assert_true(testo.contains(nome), "il titolo del finale e' mostrato")
	# twilight_giant e' del gruppo eternal_darkness
	var epg: Dictionary = gd.call("get_ending", "apoteosi").get("epiloghi_per_gruppo", {})
	var epilogo: String = str(gd.call("tr_data", epg.get("eternal_darkness_i18n")))
	assert_true(testo.contains(epilogo), "l'epilogo della VARIANTE DI GRUPPO giusta e' mostrato")
	_n("/root/Book").call("chiudi")
	ov.free()
	_fine()


func test_eredita_vuota_non_mostra_il_riepilogo() -> void:
	# Finche' US-719 non compila endgame.eredita, nessun placeholder finto.
	_n("/root/EndgameState").call("imposta_finale", "apoteosi")
	var ov: CanvasLayer = _pagina()
	var testo: String = _testo(ov)
	assert_false(testo.contains("Ciò che passa"), "eredita vuota: nessuna sezione 'Cio che passa'")
	_n("/root/Book").call("chiudi")
	ov.free()
	_fine()


func test_eredita_compilata_mostra_il_riepilogo() -> void:
	_n("/root/EndgameState").call("imposta_finale", "apoteosi")
	_n("/root/EndgameState").call("imposta_eredita", {"conoscenza": ["pathway:darkness", "sequenza:moon:5"]})
	var ov: CanvasLayer = _pagina()
	var testo: String = _testo(ov)
	assert_true(testo.contains("Ciò che passa"), "eredita compilata: la sezione appare")
	assert_true(testo.contains("2"), "il conteggio della conoscenza ereditata e' mostrato")
	_n("/root/Book").call("chiudi")
	ov.free()
	_fine()
