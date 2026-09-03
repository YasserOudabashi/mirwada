extends "res://tests/test_case.gd"
## US-213 — Follia: cumulativa 0-100, effetti a soglia, abilita' autonome.

const SLOT := 907


func _m() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Madness")


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SaveSystem")


func prepara() -> void:
	if _m() != null:
		_m().call("azzera")


func test_add_accumula_e_registra_la_sorgente() -> void:
	var m: Node = _m()
	m.call("add", 10.0, "avanzamento_forzato")
	m.call("add", 5.0, "pozione_parziale")
	assert_almost_eq(m.call("valore"), 15.0, "follia sommata")
	var sorg: Array = m.call("sorgenti")
	assert_eq(sorg.size(), 2, "due sorgenti nel log")
	assert_eq((sorg[0] as Dictionary)["sorgente"], "avanzamento_forzato", "prima sorgente")


func test_clamp_0_100() -> void:
	var m: Node = _m()
	m.call("add", 250.0, "x")
	assert_almost_eq(m.call("valore"), 100.0, "cap a 100")
	m.call("add", -400.0, "y")
	assert_almost_eq(m.call("valore"), 0.0, "floor a 0")


func test_soglie_e_segnale() -> void:
	var m: Node = _m()
	var visto: Dictionary = {"soglia": -99}
	var cb := func(_v: float, soglia: int) -> void:
		if soglia != -1:
			visto["soglia"] = soglia
	m.madness_changed.connect(cb)

	m.call("add", 14.0, "x")
	assert_eq(m.call("soglia_corrente"), 0, "sotto la prima soglia")
	m.call("add", 2.0, "x")   # -> 16, supera 15
	assert_eq(m.call("soglia_corrente"), 15, "soglia distorsioni")
	assert_eq(visto["soglia"], 15, "segnale con la soglia attraversata")

	m.call("add", 30.0, "x")  # -> 46
	assert_eq(m.call("soglia_corrente"), 40, "soglia abilita autonome")
	m.call("add", 30.0, "x")  # -> 76
	assert_eq(m.call("soglia_corrente"), 70, "soglia perdita input")
	assert_true(m.call("perdita_input_attiva"), "perdita input attiva a 76")
	m.call("add", 30.0, "x")  # -> 100
	assert_true(m.call("stato_mostro"), "stato mostro a 100")

	m.madness_changed.disconnect(cb)


func test_abilita_autonoma_solo_sopra_soglia_40() -> void:
	var m: Node = _m()
	# sotto 40: nessuna attivazione, mai
	m.call("add", 30.0, "x")
	var sotto: int = 0
	for i in 500:
		if m.call("tenta_abilita_autonoma"):
			sotto += 1
	assert_eq(sotto, 0, "sotto soglia 40: nessuna abilita' autonoma")

	# sopra 40: attivazioni con probabilita' ~0.08
	m.call("add", 20.0, "x")  # -> 50
	var conta: int = 0
	var emessi: Dictionary = {"n": 0}
	var cb := func() -> void: emessi["n"] += 1
	m.abilita_autonoma.connect(cb)
	for i in 2000:
		if m.call("tenta_abilita_autonoma"):
			conta += 1
	m.abilita_autonoma.disconnect(cb)
	assert_gt(float(conta), 0.0, "sopra soglia 40: qualche abilita' autonoma su 2000 tiri")
	assert_true(conta < 2000, "non sempre (probabilita' < 1)")
	assert_eq(emessi["n"], conta, "il segnale abilita_autonoma e' stato emesso ogni volta")


func test_non_si_azzera_del_tutto_col_cap_delle_ancore() -> void:
	# US-213: riduci() qui clampa a 0. Il CAP frazionario (riduzione_max_ancore
	# 0.60) lo applica AnchorSystem in US-216: qui si verifica solo che
	# passando la quantita' gia' cappata la follia non va sotto zero.
	var m: Node = _m()
	m.call("add", 50.0, "x")
	m.call("riduci", 30.0, "ancore")  # 60% di 50 = 30
	assert_almost_eq(m.call("valore"), 20.0, "ridotta della quantita' passata, resta > 0")


func test_persistenza_e_migrazione() -> void:
	var m: Node = _m()
	var s: Node = _save()
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	m.call("add", 42.0, "avanzamento_forzato")

	if s.esiste(SLOT):
		s.cancella(SLOT)
	assert_true(s.salva(SLOT, gs.snapshot())["ok"], "salva ok")
	m.call("azzera")
	var c: Dictionary = s.carica(SLOT)
	gs.applica(c["dati"])
	assert_almost_eq(m.call("valore"), 42.0, "follia ripristinata dal save")
	s.cancella(SLOT)

	# migrazione da v7
	if s.esiste(SLOT):
		s.cancella(SLOT)
	var f := FileAccess.open("user://saves/slot_%d.json" % SLOT, FileAccess.WRITE)
	f.store_string('{"schema_version": 7, "nome_personaggio": "v7", "posizione": [0,0], "statistiche": {}, "evocazioni": [], "progressione": {"pathway_id": "", "sequence": 9}, "mondo": {"terrain_mods": []}, "eventi": {"log": []}, "acting": {}, "caratteristiche": []}')
	f.close()
	var c2: Dictionary = s.carica(SLOT)
	assert_true(c2["migrato"], "migrato da v7")
	assert_almost_eq(float(((c2["dati"] as Dictionary)["follia"] as Dictionary)["valore"]), 0.0, "follia 0 dopo migrazione")
	s.cancella(SLOT)
