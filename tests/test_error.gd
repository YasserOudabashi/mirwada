extends "res://tests/test_case.gd"
## US-5B01 / US-5B02 — Error, Sequenze 9-4: le abilita' si eseguono senza
## warning di primitiva (steal e possess implementate qui); steal presta
## un'abilita' via grant_temporary e la scadenza la revoca; steal "conoscenza"
## scrive un flag in KnowledgeStore; possess applica lo status 'posseduto' e
## registra il corpo del caster a terra; le acting_actions delle Sequenze
## sommano 1.0.

const Stats := preload("res://scripts/stats_component.gd")

const ABILITA_9_7 := [
	"error_scasso", "error_pugnalata_furtiva",
	"error_parlantina", "error_patto_truffaldino",
	"error_decifrazione", "error_lettura_rubata",
]
const ABILITA_6_4 := [
	"error_furto_prometeo", "error_scintilla_rubata",
	"error_furto_dei_sogni", "error_incubo_parassita",
	"error_innesto_parassita", "error_simbiosi_furtiva",
]


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node("GameData")


func _ks() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("KnowledgeStore")


func prepara() -> void:
	var e: Node = _engine()
	if e != null:
		e.call("clear_cooldowns")
		e.call("clear_granted")
		e.call("flush_effects")


func _caster() -> Node2D:
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	Engine.get_main_loop().root.add_child(c)
	s.call("configure_from_balance", 7)
	return c


func _cleanup(c: Node) -> void:
	Engine.get_main_loop().root.remove_child(c)
	c.free()


func test_ogni_abilita_error_9_7_si_esegue_senza_warning() -> void:
	var e: Node = _engine()
	for aid in ABILITA_9_7:
		var c: Node2D = _caster()
		var r: Dictionary = e.call("execute", aid, c)
		assert_true(r["ok"], "%s eseguita" % aid)
		assert_eq((r["warnings"] as PackedStringArray).size(), 0,
			"%s: nessun warning di primitiva (steal implementata): %s" % [aid, r["warnings"]])
		e.call("clear_cooldowns")
		_cleanup(c)


func test_steal_abilita_presta_e_scade() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var prim: Dictionary = {"tipo": "steal", "categoria": "abilita",
		"ability_id": "error_pugnalata_furtiva", "durata_prestito": 5.0, "probabilita": 1.0}
	var r: Dictionary = e.call("_p_steal", prim, c, null, "ab")
	assert_true(bool(r["applied"]), "steal 'abilita' ha prestato l'ability_id")
	assert_true(e.call("is_granted", c, "error_pugnalata_furtiva"),
		"l'abilita' rubata e' eseguibile per la durata del prestito")
	e.call("tick_effects", 5.5)
	assert_false(e.call("is_granted", c, "error_pugnalata_furtiva"),
		"scaduto il prestito, l'abilita' rubata non e' piu' eseguibile")
	_cleanup(c)


func test_steal_conoscenza_scrive_un_flag() -> void:
	var e: Node = _engine()
	var ks: Node = _ks()
	if ks != null:
		ks.call("dimentica", "rubata:error_decifrazione")
	var c: Node2D = _caster()
	e.call("execute", "error_decifrazione", c)
	if ks != null:
		assert_true(ks.call("conosce", "rubata:error_decifrazione"),
			"steal 'conoscenza' fa imparare un flag a KnowledgeStore")
	_cleanup(c)


func test_steal_oggetto_registra_il_furto_e_marca_sottratto() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var r: Dictionary = e.call("_p_steal",
		{"tipo": "steal", "categoria": "oggetto", "durata_prestito": 0, "probabilita": 0.8},
		c, null, "ab")
	assert_true(bool(r["applied"]), "steal 'oggetto' registra il furto")
	assert_true(bool(r["sottratto"]),
		"senza non_sottrae il bersaglio resta privo (matrice di proprieta')")
	_cleanup(c)


func test_ogni_abilita_error_6_4_si_esegue_senza_warning() -> void:
	var e: Node = _engine()
	for aid in ABILITA_6_4:
		var c: Node2D = _caster()
		var r: Dictionary = e.call("execute", aid, c)
		assert_true(r["ok"], "%s eseguita" % aid)
		assert_eq((r["warnings"] as PackedStringArray).size(), 0,
			"%s: nessun warning di primitiva (possess implementata): %s" % [aid, r["warnings"]])
		e.call("clear_cooldowns")
		e.call("clear_granted")
		_cleanup(c)


func test_possess_applica_posseduto_e_registra_il_corpo_a_terra() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	var vel0: float = s.call("get_stat", "velocita")
	var r: Dictionary = e.call("execute", "error_innesto_parassita", c)
	assert_true(r["ok"], "innesto parassita eseguito")
	assert_true(s.call("ha_status", "posseduto"),
		"possess applica lo status 'posseduto' al bersaglio")
	assert_gt(vel0, s.call("get_stat", "velocita"),
		"il posseduto non e' piu' padrone del corpo (velocita' crollata)")
	var rec: Dictionary = (r["effects"] as Array)[0]
	assert_true(bool(rec["corpo_a_terra"]),
		"il record dichiara il corpo del caster a terra (come soul_detach)")
	assert_eq(str(rec["controllo"]), "sensi", "il tipo di controllo viene dai dati")
	_cleanup(c)


func test_prometeo_presta_l_abilita_dichiarata_nei_dati() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	e.call("execute", "error_furto_prometeo", c)
	assert_true(e.call("is_granted", c, "tg_fendente_pesante"),
		"steal 'abilita' presta l'ability_id dichiarato dal Prometheus")
	e.call("tick_effects", 12.5)
	assert_false(e.call("is_granted", c, "tg_fendente_pesante"),
		"il prestito breve del Prometheus scade")
	e.call("clear_granted")
	_cleanup(c)


func test_error_sequenze_scritte_sono_contenuto_e_le_acting_sommano_uno() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "error")
	for seq in (pw.get("sequences", []) as Array):
		var d: Dictionary = seq
		if int(d.get("sequence", -1)) < 4:
			continue
		assert_false(bool(d.get("stub", false)),
			"error_%d non e' piu' stub" % int(d.get("sequence")))
		var somma: float = 0.0
		for a in (d.get("acting_actions", []) as Array):
			somma += float((a as Dictionary).get("progresso", 0.0))
		assert_almost_eq(somma, 1.0,
			"error_%d: le acting_actions sommano 1.0" % int(d.get("sequence")))
		assert_gt(float(d.get("madness_on_force", 0.0)), 0.0,
			"error_%d: madness_on_force > 0" % int(d.get("sequence")))


func test_error_4_ha_un_rituale_con_luogo_valido() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "error")
	for seq in (pw.get("sequences", []) as Array):
		if int((seq as Dictionary).get("sequence", -1)) != 4:
			continue
		var rit: Dictionary = (seq as Dictionary).get("advancement_ritual", {})
		assert_false(rit.is_empty(), "error_4 (Seq <= 4) ha un advancement_ritual")
		assert_gt(float((rit.get("location_tags", []) as Array).size()), 0.0,
			"col suo luogo (nebbia_grigia / crocevia)")
