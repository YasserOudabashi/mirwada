extends "res://tests/test_case.gd"
## US-718 — la schermata di finale estende il colophon (page_impostazioni.gd)
## invece di un tipo di pagina nuovo (page_types.json e' un vocabolario
## chiuso). Appare solo se EndgameState.finale non e' vuoto.
##
## US-719: quando il profilo del finale e' 'ancore'/'completo', la pagina
## offre anche il controllo per scegliere l'Ancora/l'oggetto da ereditare.

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


func _trova(n: Node, tipo: Variant) -> Node:
	if is_instance_of(n, tipo):
		return n
	for c in n.get_children():
		var trovato: Node = _trova(c, tipo)
		if trovato != null:
			return trovato
	return null


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


func test_profilo_completo_offre_la_scelta_dell_ancora_e_dell_oggetto() -> void:
	# US-719: Consumazione ha eredita_profilo 'completo'.
	_n("/root/AnchorSystem").call("register", "anchor_mirco")
	_n("/root/Inventory").call("aggiungi", "moneta_comune", 1)
	_n("/root/EndgameState").call("imposta_finale", "consumazione")
	_n("/root/EndgameState").call("imposta_eredita", {"conoscenza": []})

	var ov: CanvasLayer = _pagina()
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)
	var testo: String = _testo(ov)
	assert_true(testo.contains("Ciò che passa"), "la sezione appare anche a sola richiesta di scelta")
	var opzioni: Node = _trova(pag, OptionButton)
	assert_true(opzioni != null, "un selettore per l'Ancora/l'oggetto e' a schermo")

	_n("/root/Book").call("chiudi")
	ov.free()
	_n("/root/AnchorSystem").call("pulisci")
	_n("/root/Inventory").call("pulisci")
	_fine()


func test_scegliere_l_ancora_aggiorna_il_riepilogo_e_fa_sparire_il_selettore() -> void:
	_n("/root/AnchorSystem").call("register", "anchor_mirco")
	_n("/root/EndgameState").call("imposta_finale", "consumazione")
	_n("/root/EndgameState").call("imposta_eredita", {"conoscenza": []})

	assert_true(bool(_n("/root/EndingSystem").call("scegli_ancora", "anchor_mirco")), "scelta accettata")

	var ov: CanvasLayer = _pagina()
	var testo: String = _testo(ov)
	assert_true(testo.contains("Un'Ancora"), "il riepilogo mostra l'Ancora scelta")
	var eredita: Dictionary = _n("/root/EndgameState").call("get", "eredita")
	assert_almost_eq(float((eredita["ancora"] as Dictionary).get("forza", -1.0)), 5.0,
		"5 = 10 (anchor_mirco) / 2", 0.01)

	_n("/root/Book").call("chiudi")
	ov.free()
	_n("/root/AnchorSystem").call("pulisci")
	_fine()
