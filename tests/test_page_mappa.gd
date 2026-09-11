extends "res://tests/test_case.gd"
## US-617 — la pagina mappa del libro: fog of war sulle regioni scoperte;
## il fast travel e' un potere (primitiva teleport nelle Sequenze raggiunte o
## un varco permanente del TG), non un menu.

const PageMappa := preload("res://scenes/pages/page_mappa.tscn")


func _root() -> Node: return Engine.get_main_loop().root
func _ws() -> Node: return _root().get_node("WorldState")
func _pr() -> Node: return _root().get_node("Progression")


func prepara() -> void:
	_ws().call("pulisci")
	_pr().call("configura", "twilight_giant", 9)
	_root().get_tree().paused = false


func _monta() -> Node:
	var p: Node = PageMappa.instantiate()
	_root().add_child(p)
	return p


func _testo(p: Node) -> String:
	var t := ""
	for c in p.get_children():
		for x in (c.get_children() if not (c is Label) else [c]):
			if x is Label:
				t += " | " + x.text
	return t


func test_fog_of_war_sulle_regioni_scoperte() -> void:
	_ws().call("entra_regione", "mirwada")
	var p: Node = _monta()
	p.call("aggiorna")
	var t: String = _testo(p)
	assert_true(t.contains("Mirwada"), "la regione corrente e' sulla mappa")
	assert_false(t.contains("Marche"), "una regione mai visitata e' assente (fog of war)")
	_ws().call("entra_regione", "marche_crepuscolo")
	p.call("aggiorna")
	assert_true(_testo(p).contains("Marche"), "dopo la visita compare")
	p.free()


func test_senza_mezzo_non_si_viaggia() -> void:
	_ws().call("entra_regione", "mirwada")
	_ws().call("entra_regione", "marche_crepuscolo")
	_ws().call("entra_regione", "mirwada")
	var p: Node = _monta()
	p.call("aggiorna")
	assert_true(_testo(p).contains(tr("BOOK_MAPPA_MEZZO_NO")), "il Twilight Giant a Seq 9 non ha scorciatoie")
	var bottoni_attivi := 0
	for c in p.get_children():
		for x in (c.get_children() if c is HBoxContainer else []):
			if x is Button and not x.disabled:
				bottoni_attivi += 1
	assert_eq(bottoni_attivi, 0, "nessun bottone Viaggia attivo")
	p.free()


func test_con_una_primitiva_teleport_si_viaggia() -> void:
	_ws().call("entra_regione", "mirwada")
	_ws().call("entra_regione", "marche_crepuscolo")
	_ws().call("entra_regione", "mirwada")
	_pr().call("configura", "death", 5)   # death_5 compone teleport
	var p: Node = _monta()
	p.call("aggiorna")
	assert_true(_testo(p).contains(tr("BOOK_MAPPA_MEZZO_SI")), "il Death a Seq 5 ha il passo tra i mondi")
	var attivi := 0
	for c in p.get_children():
		for x in (c.get_children() if c is HBoxContainer else []):
			if x is Button and not x.disabled:
				attivi += 1
	assert_gt(float(attivi), 0.0, "il bottone Viaggia e' attivo")
	p.free()


func test_un_varco_permanente_del_tg_abilita_il_viaggio() -> void:
	_ws().call("entra_regione", "mirwada")
	_ws().call("registra_terreno", "apre_varco", Vector2(10, 10), 5.0)
	var p: Node = _monta()
	p.call("aggiorna")
	assert_true(_testo(p).contains(tr("BOOK_MAPPA_MEZZO_SI")), "un varco permanente basta")
	p.free()


## US-1002B (fase 10, mondo continuo): un solo world_scene.gd, viaggia_a
## riposiziona invece di ricaricare - il gating d'ingresso (US-611) resta
## lo stesso controllo di prima, solo senza una scena da (ri)caricare.
func test_viaggia_a_rispetta_il_gating_d_ingresso() -> void:
	var cont := Node2D.new()
	_root().add_child(cont)
	var player := Node2D.new()
	player.name = "Player"
	player.add_to_group("player")
	cont.add_child(player)
	var mondo: Node = load("res://scenes/world_scene.tscn").instantiate()
	cont.add_child(mondo)

	_pr().call("configura", "twilight_giant", 9)
	assert_true(mondo.call("viaggia_a", "mirwada"), "Mirwada non ha gating d'ingresso")

	_pr().call("configura", "twilight_giant", 2)   # "sopra" la Sequenza 4
	assert_false(mondo.call("viaggia_a", "frontiera_porte"), "la Frontiera respinge chi e' troppo avanti")
	cont.free()
