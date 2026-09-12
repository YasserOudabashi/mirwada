extends "res://tests/test_case.gd"
## US-225 — SettingsStore + colophon: persistenza rigorosa e applicazione a
## runtime.

const OverlayScene := preload("res://scenes/book_overlay.tscn")


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func _ss() -> Node:
	return _n("/root/SettingsStore")


func prepara() -> void:
	var d := DirAccess.open("user://")
	if d != null:
		d.remove("settings.json")
		d.remove("settings.json.tmp")
	if _ss() != null:
		_ss().call("azzera")
	TranslationServer.set_locale("it")
	var b: Node = _n("/root/Book")
	if b != null:
		b.call("azzera")
	Engine.get_main_loop().root.get_tree().paused = false


func test_scrittura_atomica_e_round_trip() -> void:
	_ss().call("set_val", "audio", "volume_sfx", -8.0)
	assert_true(FileAccess.file_exists("user://settings.json"), "settings.json scritto")
	assert_false(FileAccess.file_exists("user://settings.json.tmp"), "nessun .tmp residuo (scrittura atomica)")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
	assert_eq(typeof(raw), TYPE_DICTIONARY, "file JSON valido")
	assert_almost_eq(float((raw as Dictionary)["audio"]["volume_sfx"]), -8.0, "valore persistito")


func test_file_corrotto_non_e_fatale() -> void:
	var f := FileAccess.open("user://settings.json", FileAccess.WRITE)
	f.store_string("{ non e' json")
	f.close()
	_ss().call("_carica")
	assert_eq(_ss().call("get_val", "audio", "volume_sfx", -3.0), -3.0,
		"file corrotto -> si riparte dal default, nessun crash")


func test_tipo_incoerente_scartato() -> void:
	# un settings.json manomesso passa una stringa dove serve un numero
	_ss().set("_dati", {"audio": {"volume_sfx": "molto alto"}})
	assert_eq(_ss().call("get_val", "audio", "volume_sfx", -3.0), -3.0,
		"tipo diverso dal default -> default")


func test_volume_applicato_a_runtime() -> void:
	_ss().call("set_val", "audio", "volume_music", -14.0)
	var idx: int = AudioServer.get_bus_index("music")
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), -14.0, "il bus music cambia subito", 0.2)
	_ss().call("set_val", "audio", "volume_music", -6.0)   # ripristino default


func test_lingua_applicata_a_runtime() -> void:
	_ss().call("set_val", "lingua", "locale", "en")
	assert_true(TranslationServer.get_locale().begins_with("en"), "locale cambiato senza riavvio")
	TranslationServer.set_locale("it")


func test_toggle_accessibilita_raggiunge_audiomanager() -> void:
	_ss().call("set_val", "audio", "disattiva_sussurri", true)
	var am: Node = _n("/root/AudioManager")
	assert_true(bool(am.call("accessibilita", "disattiva_sussurri")),
		"il toggle arriva ad AudioManager (che i VFX gia' leggono)")
	_ss().call("set_val", "audio", "disattiva_sussurri", false)


func test_rimappatura_tasti() -> void:
	_ss().call("set_val", "input", "pagina_indietro", KEY_Y)
	var trovato := false
	for ev in InputMap.action_get_events("pagina_indietro"):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_Y:
			trovato = true
	assert_true(trovato, "l'azione ora risponde al nuovo tasto")
	_ss().call("set_val", "input", "pagina_indietro", KEY_Q)   # ripristino


func test_azioni_include_hotbar_e_interagisci() -> void:
	var az: Array = _ss().call("azioni")
	for a in ["abilita_1", "abilita_2", "abilita_3", "abilita_4", "interagisci"]:
		assert_true(a in az, "'%s' e' fra le azioni rimappabili del colophon" % a)


func test_colophon_elenca_i_tasti_abilita_e_interagisci() -> void:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var b: Node = _n("/root/Book")
	b.call("apri")
	b.call("vai_a", "colophon")
	for i in 4:
		ov.call("_process", 0.2)
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)

	var testi: Array = []
	var da_visitare: Array = [pag.get_child(0)]
	while not da_visitare.is_empty():
		var n: Node = da_visitare.pop_back()
		for c in n.get_children():
			da_visitare.append(c)
			if c is Label:
				testi.append((c as Label).text)

	assert_true(tr("COLOPHON_AZIONE_INTERAGISCI") in testi,
		"il colophon elenca l'azione 'interagisci' con etichetta leggibile")
	assert_true(tr("COLOPHON_AZIONE_ABILITA_1") in testi,
		"il colophon elenca 'Abilità 1'")
	b.call("chiudi")
	ov.free()


func test_colophon_costruisce_le_sezioni() -> void:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var b: Node = _n("/root/Book")
	b.call("apri")
	b.call("vai_a", "colophon")
	for i in 4:
		ov.call("_process", 0.2)
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)
	assert_eq(pag.call("testo_visibile"), "impostazioni", "la pagina colophon e' istanziata")
	var vbox: Node = pag.get_child(0)
	assert_gt(float(vbox.get_child_count()), 10.0, "sezioni e controlli costruiti")
	b.call("chiudi")
	ov.free()
