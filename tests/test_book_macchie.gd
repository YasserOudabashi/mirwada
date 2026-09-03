extends "res://tests/test_case.gd"
## US-229 — macchie di follia sulle pagine del libro (equivalente scritto dei
## sussurri di US-214).

const OverlayScene := preload("res://scenes/book_overlay.tscn")


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	var b: Node = _n("/root/Book")
	if b != null:
		b.call("azzera")
	Engine.get_main_loop().root.get_tree().paused = false
	var mad: Node = _n("/root/Madness")
	if mad != null:
		mad.call("da_salvataggio", {})   # follia a 0
	var am: Node = _n("/root/AudioManager")
	if am != null:
		am.call("imposta_accessibilita", "disattiva_sussurri", false)
		am.call("imposta_accessibilita", "riduci_animazioni", false)
	var ss: Node = _n("/root/SettingsStore")
	if ss != null:
		ss.call("set_val", "video", "macchie_follia", true)


func _monta() -> CanvasLayer:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	_n("/root/Book").call("apri")
	return ov


func _intensita(ov: CanvasLayer) -> float:
	var m: ColorRect = ov.get_node("Pagina/Macchie")
	return float((m.material as ShaderMaterial).get_shader_parameter("intensita"))


func test_niente_macchie_a_follia_zero() -> void:
	var ov: CanvasLayer = _monta()
	assert_eq(_intensita(ov), 0.0, "a follia 0 le pagine sono pulite")
	assert_false((ov.get_node("Pagina/NoteMargine") as Label).visible, "nessuna nota a margine")
	_n("/root/Book").call("chiudi")
	ov.free()


func test_bordi_scuri_sopra_la_prima_soglia() -> void:
	var ov: CanvasLayer = _monta()
	_n("/root/Madness").call("add", 30.0, "test")   # > soglia_distorsioni (15)
	assert_gt(_intensita(ov), 0.0, "sopra soglia 15 i bordi si scuriscono")
	_n("/root/Book").call("chiudi")
	ov.free()


func test_note_a_margine_sopra_la_seconda_soglia() -> void:
	var ov: CanvasLayer = _monta()
	_n("/root/Madness").call("add", 50.0, "test")   # > soglia_abilita_autonome (40)
	var nota: Label = ov.get_node("Pagina/NoteMargine")
	assert_true(nota.visible, "sopra soglia 40 compare la nota a margine")
	assert_false(nota.text.is_empty(), "la nota ha un testo (grafia non tua)")
	_n("/root/Book").call("chiudi")
	ov.free()


func test_toggle_dati_congela_le_macchie() -> void:
	var ov: CanvasLayer = _monta()
	_n("/root/Madness").call("add", 80.0, "test")
	var acceso: float = _intensita(ov)
	_n("/root/SettingsStore").call("set_val", "video", "macchie_follia", false)
	ov.get_node("Pagina").get_parent()  # no-op, solo per chiarezza
	# forziamo un ricalcolo aprendo di nuovo la pagina
	_n("/root/Book").call("vai_a", "frontespizio")
	for i in 4:
		ov.call("_process", 0.2)
	assert_eq(_intensita(ov), 0.0, "toggle 'macchie di follia' spento -> pagine pulite")
	assert_gt(acceso, 0.0, "(erano accese prima)")
	_n("/root/Book").call("chiudi")
	ov.free()


func test_disattiva_sussurri_congela_ma_non_azzera_la_follia() -> void:
	var ov: CanvasLayer = _monta()
	_n("/root/Madness").call("add", 80.0, "test")
	_n("/root/AudioManager").call("imposta_accessibilita", "disattiva_sussurri", true)
	_n("/root/Book").call("vai_a", "frontespizio")
	for i in 4:
		ov.call("_process", 0.2)
	var congelata: float = _intensita(ov)
	assert_gt(congelata, 0.0, "congelata != assente: la macchia resta visibile (FR-8)")
	assert_true(congelata <= 0.30, "ma a uno stato neutro fisso, non pulsante")
	assert_almost_eq(float(_n("/root/Madness").call("valore")), 80.0, "la follia NON e' cambiata", 0.01)
	_n("/root/Book").call("chiudi")
	ov.free()
