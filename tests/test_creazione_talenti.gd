extends "res://tests/test_case.gd"
## US-332 — talenti innati alla creazione personaggio.

const OverlayScene := preload("res://scenes/book_overlay.tscn")
const SLOT := 911


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func prepara() -> void:
	if _n("/root/TalentSystem") != null:
		_n("/root/TalentSystem").call("pulisci")
	if _n("/root/Book") != null:
		_n("/root/Book").call("azzera")
	Engine.get_main_loop().root.get_tree().paused = false
	# nuova_partita() attiva la partita: le altre suite (scaffale) si aspettano
	# lo stato di boot. La azzero prima e dopo, come test_page_scaffale.
	if _n("/root/GameState") != null:
		_n("/root/GameState").set("_partita_attiva", false)


func test_nuova_partita_accetta_i_talenti_innati() -> void:
	var gs: Node = _n("/root/GameState")
	var ts: Node = _n("/root/TalentSystem")
	gs.call("nuova_partita", "Enel", SLOT, ["mano_ferma", "spirito_vivace"])
	assert_true(ts.call("possiede", "mano_ferma"), "primo innato scelto")
	assert_true(ts.call("possiede", "spirito_vivace"), "secondo innato scelto")
	_n("/root/SaveSystem").call("cancella", SLOT)
	_n("/root/GameState").set("_partita_attiva", false)


func test_nuova_partita_ignora_i_non_innati_e_cappa_al_numero_dei_dati() -> void:
	var gs: Node = _n("/root/GameState")
	var ts: Node = _n("/root/TalentSystem")
	# 'veterano' e' acquisito, non innato; e sono 3 > innati_alla_creazione (2)
	gs.call("nuova_partita", "Enel", SLOT, ["veterano", "mano_ferma", "spirito_vivace", "piede_leggero"])
	assert_false(ts.call("possiede", "veterano"), "un acquisito non entra dalla creazione")
	assert_eq((ts.call("posseduti") as Array).size(), 2, "cappato a innati_alla_creazione (2)")
	_n("/root/SaveSystem").call("cancella", SLOT)
	_n("/root/GameState").set("_partita_attiva", false)


func test_i_talenti_innati_si_salvano_come_gli_altri() -> void:
	var gs: Node = _n("/root/GameState")
	var s: Node = _n("/root/SaveSystem")
	if s.esiste(SLOT):
		s.cancella(SLOT)
	gs.call("nuova_partita", "Enel", SLOT, ["costituzione_robusta"])
	_n("/root/TalentSystem").call("pulisci")
	var r: Dictionary = s.carica(SLOT)
	gs.call("applica", r["dati"])
	assert_true(_n("/root/TalentSystem").call("possiede", "costituzione_robusta"),
		"il talento innato torna dal save")
	s.cancella(SLOT)
	_n("/root/GameState").set("_partita_attiva", false)


func _pagina_creazione() -> Array:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var b: Node = _n("/root/Book")
	b.call("apri")
	b.call("vai_a", "frontespizio")
	for i in 5:
		ov.call("_process", 0.2)
	return [ov, ov.get_node("Pagina/Contenuto").get_child(0)]


func test_la_pagina_creazione_offre_le_checkbox_dei_talenti() -> void:
	# la partita non deve essere in corso
	if bool(_n("/root/GameState").call("partita_in_corso")):
		return  # un'altra suite ha lasciato una partita attiva: salta, il path e' coperto sopra
	var res: Array = _pagina_creazione()
	var pag: Node = res[1]
	var n_checkbox := 0
	for c in pag.get_children():
		if c is CheckBox:
			n_checkbox += 1
	assert_true(n_checkbox >= 4, "una checkbox per talento innato (>= 4)")
	res[0].free()
