extends "res://tests/test_case.gd"
## US-221 — shell del libro, parte 1: controller e dati.


func _book() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Book")


func _data() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


## Stato pulito prima di ogni test: libro chiuso, mondo non in pausa.
func prepara() -> void:
	var b: Node = _book()
	if b != null:
		b.call("chiudi")
	Engine.get_main_loop().root.get_tree().paused = false


func test_autoload_e_dati_caricati() -> void:
	var b: Node = _book()
	assert_true(b != null, "autoload Book registrato")
	assert_eq(_data().call("page_types").size(), 8, "8 tipi di pagina nel vocabolario")
	assert_gt(float((b.call("pagine") as Array).size()), 0.0, "pagine caricate da book.json")


func test_tipi_delle_pagine_nel_vocabolario() -> void:
	var vocab: Array = _data().call("page_types")
	for p in _book().call("pagine"):
		assert_true(vocab.has((p as Dictionary).get("tipo", "")),
			"tipo '%s' nel vocabolario chiuso" % [(p as Dictionary).get("tipo")])


func test_pagine_bianche_vs_sbloccate_in_fase_2() -> void:
	var b: Node = _book()
	# Fase 2 (data/balance.json gioco.fase): queste sono navigabili subito.
	for pid in ["copertina", "frontespizio", "diagramma", "colophon"]:
		assert_true(b.call("pagina_sbloccata", pid), "%s sbloccata in fase 2" % pid)
	# Queste esistono ma sono bianche finche' la fase non le raggiunge.
	for pid in ["inventario", "sinergie", "mappa", "journal"]:
		assert_false(b.call("pagina_sbloccata", pid), "%s ancora bianca in fase 2" % pid)
		assert_false(b.call("pagina", pid).is_empty(), "%s esiste comunque nei dati" % pid)


func test_apri_ferma_il_mondo_chiudi_lo_riavvia() -> void:
	var b: Node = _book()
	var tree: SceneTree = Engine.get_main_loop().root.get_tree()
	assert_false(tree.paused, "mondo non in pausa a libro chiuso")
	b.call("apri")
	assert_true(b.call("e_aperto"), "libro aperto")
	assert_true(tree.paused, "il mondo e' in pausa mentre il libro e' aperto")
	b.call("chiudi")
	assert_false(b.call("e_aperto"), "libro chiuso")
	assert_false(tree.paused, "il mondo riparte alla chiusura")


func test_alterna_stesso_ingresso() -> void:
	var b: Node = _book()
	b.call("alterna")
	assert_true(b.call("e_aperto"), "alterna apre")
	b.call("alterna")
	assert_false(b.call("e_aperto"), "alterna richiude")


func test_riapre_sull_ultima_pagina_consultata() -> void:
	var b: Node = _book()
	b.call("apri")
	var vista: Array = []
	var cb := func(n: String, _v: String) -> void: vista.append(n)
	b.pagina_cambiata.connect(cb)
	b.call("vai_a", "colophon")
	assert_eq(b.call("pagina_corrente"), "colophon", "pagina cambiata")
	assert_eq(vista, ["colophon"], "segnale pagina_cambiata emesso una volta")
	b.call("vai_a", "pagina_che_non_esiste")
	assert_eq(b.call("pagina_corrente"), "colophon", "pagina inesistente -> no-op")
	b.pagina_cambiata.disconnect(cb)
	b.call("chiudi")
	b.call("apri")
	assert_eq(b.call("pagina_corrente"), "colophon", "riapre sull'ultima consultata")
	b.call("chiudi")


func test_segnalibri_puntano_a_pagine_esistenti() -> void:
	var b: Node = _book()
	for s in b.call("segnalibri"):
		assert_false(b.call("pagina", s).is_empty(), "segnalibro '%s' e' una pagina" % s)
