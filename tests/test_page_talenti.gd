extends "res://tests/test_case.gd"
## US-333 — la sezione Talenti della pagina inventario: posseduti con effetto,
## acquisiti non presi con barra di progresso, offuscati se progresso 0.

const OverlayScene := preload("res://scenes/book_overlay.tscn")


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func prepara() -> void:
	if _n("/root/Book") != null:
		_n("/root/Book").call("azzera")
	Engine.get_main_loop().root.get_tree().paused = false
	for a in ["/root/TalentSystem", "/root/TalentTracker", "/root/EventTracker"]:
		if _n(a) != null:
			_n(a).call("pulisci" if a.ends_with("TalentSystem") else "azzera")


func _pagina_talenti() -> Array:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var b: Node = _n("/root/Book")
	b.call("apri")
	b.call("vai_a", "inventario")
	for i in 5:
		ov.call("_process", 0.2)
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)
	pag.call("_mostra", "talenti")
	var sc: Node = null
	for c in pag.get_children():
		if c is ScrollContainer:
			sc = c
	return [ov, sc.get_child(0).get_children()]


func _tutti_i_label(righe: Array) -> Array:
	var out: Array = []
	for r in righe:
		if r is Label:
			out.append(r)
		else:
			for c in r.get_children():
				if c is Label:
					out.append(c)
	return out


func test_un_talento_posseduto_compare_col_suo_effetto() -> void:
	_n("/root/TalentSystem").call("concedi", "mano_ferma")
	var res: Array = _pagina_talenti()
	var testo := ""
	for l in _tutti_i_label(res[1]):
		testo += " | " + l.text
	assert_true(testo.contains("Mano ferma"), "il talento posseduto e' elencato")
	assert_true(testo.to_lower().contains("precisione"), "col suo effetto")
	res[0].free()


func test_un_acquisito_con_progresso_ha_la_barra_e_il_conteggio() -> void:
	_n("/root/TalentTracker").call("registra", "distanza_percorsa", 2000.0)  # target 8000
	var res: Array = _pagina_talenti()
	var barra_trovata := false
	var conteggio_trovato := false
	for r in res[1]:
		for c in (r.get_children() if not (r is Label) else []):
			if c is ProgressBar:
				barra_trovata = true
				assert_almost_eq(c.value, 2000.0, "la barra e' al valore del contatore")
			if c is Label and c.text == "2000 / 8000":
				conteggio_trovato = true
	assert_true(barra_trovata, "l'acquisito in corso ha una barra di progresso")
	assert_true(conteggio_trovato, "e il conteggio count / target")
	res[0].free()


func test_un_acquisito_senza_progresso_e_offuscato() -> void:
	var res: Array = _pagina_talenti()
	var offuscato_trovato := false
	for l in _tutti_i_label(res[1]):
		if l.text == tr("BOOK_TAL_SCONOSCIUTO") and absf(l.modulate.a - 0.55) < 0.01:
			offuscato_trovato = true
	assert_true(offuscato_trovato,
		"un acquisito di cui non hai fatto nulla e' una riga offuscata, non il suo nome")
	res[0].free()
