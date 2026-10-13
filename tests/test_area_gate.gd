extends "res://tests/test_case.gd"
## US-611 — AreaGate applica regions.json.gating[]: una barriera che si apre o
## chiude secondo i 6 modi di gate_types.json, e che un terrain_modify
## permanente apre per sempre (WorldState.gate_aperti, salvato).

const AreaGate := preload("res://scripts/area_gate.gd")
const SPM := 120.0  # data/balance.json tempo.secondi_per_momento


func _root() -> Node: return Engine.get_main_loop().root
func _ws() -> Node: return _root().get_node("WorldState")
func _ts() -> Node: return _root().get_node("TimeSystem")
func _ks() -> Node: return _root().get_node("KnowledgeStore")
func _pr() -> Node: return _root().get_node("Progression")


func prepara() -> void:
	_ws().call("pulisci")
	_ts().call("da_salvataggio", {})       # tick 0 -> "alba"
	_ks().call("dimentica_tutto")
	_pr().call("configura", "twilight_giant", 9)


## Crea una AreaGate in scena, gia' configurata, a una posizione nota.
func _gate_in_scena(region_id: String, gate: Dictionary, pos: Vector2 = Vector2.ZERO) -> Area2D:
	var ag: Area2D = AreaGate.new()
	ag.call("configura", region_id, gate)
	_root().add_child(ag)
	ag.global_position = pos
	return ag


func test_gate_momento_chiuso_di_giorno_aperto_di_notte() -> void:
	var ag: Area2D = _gate_in_scena("marche_crepuscolo",
		{"tipo": "momento", "valore": "notte_fonda", "area": "cripte"})
	assert_false(ag.call("e_aperto"), "all'alba il gate notte_fonda e' chiuso")
	_ts().call("avanza", SPM * 3.0 + 5.0)  # -> notte_fonda
	assert_eq(str(_ts().call("momento")), "notte_fonda", "siamo a notte_fonda")
	assert_true(ag.call("e_aperto"), "di notte fonda il gate si apre")
	ag.free()


func test_gate_fase_lunare() -> void:
	var ag: Area2D = _gate_in_scena("valle_madre",
		{"tipo": "fase_lunare", "valore": "piena", "area": "grotte_di_marea"})
	assert_false(ag.call("e_aperto"), "a luna nuova il gate 'piena' e' chiuso")
	_ts().call("avanza", SPM * 4 * 3 * 2)  # 2 fasi: nuova -> crescente -> piena
	assert_eq(str(_ts().call("fase_lunare")), "piena", "siamo a luna piena")
	assert_true(ag.call("e_aperto"), "a luna piena il gate si apre")
	ag.free()


func test_gate_conoscenza_si_apre_col_flag() -> void:
	var ag: Area2D = _gate_in_scena("archivio_sepolto",
		{"tipo": "conoscenza", "valore": "testi_ordine_minore", "area": "ali_interne"})
	assert_false(ag.call("e_aperto"), "senza il flag l'ala interna e' chiusa")
	_ks().call("impara", "testi_ordine_minore")
	assert_true(ag.call("e_aperto"), "letto il testo, l'ala si apre")
	ag.free()


func test_gate_sequenza_respinge_chi_e_troppo_avanti() -> void:
	var ag: Area2D = _gate_in_scena("frontiera_porte",
		{"tipo": "sequenza", "valore": 4, "area": "ingresso"})
	_pr().call("configura", "twilight_giant", 9)
	assert_true(ag.call("e_aperto"), "Sequenza 9 (bassa) puo' entrare")
	_pr().call("configura", "twilight_giant", 2)
	assert_false(ag.call("e_aperto"), "Sequenza 2 (alta) e' respinta")
	ag.free()


func test_gate_primitiva_legge_le_abilita_del_pathway() -> void:
	var ag: Area2D = _gate_in_scena("marche_crepuscolo",
		{"tipo": "primitiva", "primitiva": "shadow_meld", "area": "passaggi_ombra"})
	_pr().call("configura", "twilight_giant", 9)
	assert_false(ag.call("e_aperto"), "il Twilight Giant non ha shadow_meld")
	_pr().call("configura", "darkness", 4)  # il Nightwatcher compone shadow_meld
	assert_true(ag.call("e_aperto"), "raggiunta la Sequenza che usa shadow_meld, il gate si apre")

	var ag2: Area2D = _gate_in_scena("valle_madre",
		{"tipo": "primitiva", "primitiva": "plant_growth", "area": "ponti_di_radici"})
	assert_false(ag2.call("e_aperto"), "il Darkness non compone plant_growth")
	ag.free()
	ag2.free()


func test_terrain_modify_permanente_apre_per_sempre() -> void:
	var ag: Area2D = _gate_in_scena("marche_crepuscolo",
		{"tipo": "momento", "valore": "notte_fonda", "area": "cripte"}, Vector2(500, 500))
	assert_false(ag.call("e_aperto"), "chiuso di giorno")

	# un varco forzato permanente (WorldState.registra_terreno emette il
	# segnale solo per i permanenti) che copre la barriera
	_ws().call("registra_terreno", "apre_varco", Vector2(500, 500), 60.0)
	assert_true(ag.call("e_aperto"), "il varco forzato apre la barriera")

	# round-trip del save del mondo: resta aperta
	var snap: Dictionary = _ws().call("per_salvataggio")
	_ws().call("pulisci")
	_ws().call("da_salvataggio", snap)
	assert_true(ag.call("e_aperto"), "dopo il reload il gate e' ancora aperto")
	assert_true(_ws().call("gate_e_aperto", ag.call("id")), "l'id del gate e' fra i gate_aperti")
	ag.free()


func test_region_scene_crea_una_areagate_per_gating() -> void:
	var cont := Node2D.new()
	_root().add_child(cont)
	var marche: Node = load("res://scenes/regioni/marche_crepuscolo.tscn").instantiate()
	cont.add_child(marche)
	var n_gate := 0
	for c in marche.get_children():
		if c.get_script() == AreaGate:
			n_gate += 1
	assert_eq(n_gate, 2, "le Marche del Crepuscolo hanno 2 voci di gating -> 2 AreaGate")
	cont.free()

	var cont2 := Node2D.new()
	_root().add_child(cont2)
	var mirwada: Node = load("res://scenes/regioni/mirwada.tscn").instantiate()
	cont2.add_child(mirwada)
	var n_gate_hub := 0
	for c in mirwada.get_children():
		if c.get_script() == AreaGate:
			n_gate_hub += 1
	assert_eq(n_gate_hub, 0, "la citta' neutra non ha gating")
	cont2.free()
