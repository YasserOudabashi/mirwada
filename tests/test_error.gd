extends "res://tests/test_case.gd"
## US-5B01 / US-5B02 / US-5B03 — Error, 10/10 Sequenze: ogni abilita' si esegue
## senza warning di primitiva (steal, possess, time_rewind implementate qui);
## steal presta un'abilita' via grant_temporary; steal "conoscenza" scrive un
## flag in KnowledgeStore; possess applica 'posseduto' e registra il corpo a
## terra; time_rewind riporta gli hp del caster al valore di N secondi fa e
## costa follia; summon 'avatar_error' risolve; le acting_actions sommano 1.0.

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
const ABILITA_3_0 := [
	"error_proietta_avatar", "error_inganno_stratificato",
	"error_cavallo_di_troia", "error_piano_che_crolla",
	"error_riavvolgi", "error_verme_del_tempo",
	"error_falla_nelle_regole", "error_ultima_scappatoia",
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
		e.call("clear_snapshots")
		e.call("flush_effects")
	var m: Node = Engine.get_main_loop().root.get_node_or_null("Madness")
	if m != null:
		m.call("azzera")


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


func test_ogni_abilita_error_3_0_si_esegue_senza_warning() -> void:
	var e: Node = _engine()
	for aid in ABILITA_3_0:
		var c: Node2D = _caster()
		var r: Dictionary = e.call("execute", aid, c)
		assert_true(r["ok"], "%s eseguita" % aid)
		assert_eq((r["warnings"] as PackedStringArray).size(), 0,
			"%s: nessun warning di primitiva (time_rewind/summon implementate): %s" % [aid, r["warnings"]])
		e.call("clear_cooldowns")
		e.call("clear_snapshots")
		_cleanup(c)


func test_time_rewind_riporta_gli_hp_indietro_e_costa_follia() -> void:
	var e: Node = _engine()
	var m: Node = Engine.get_main_loop().root.get_node_or_null("Madness")
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	var hp_pieni: float = float(s.get("hp"))
	# 1a esecuzione: entra nel ring buffer con hp pieni.
	e.call("execute", "error_scasso", c)
	assert_gt(float(e.call("snapshot_count", c)), 0.0, "il caster e' nel ring buffer")
	# subisce danno, poi ricampiona (snapshot piu' recente con hp bassi).
	s.set("hp", hp_pieni - 80.0)
	e.call("campiona_snapshots")
	var follia0: float = m.call("valore") if m != null else 0.0
	# riavvolge di 5s: nessuno snapshot e' cosi' vecchio -> prende il piu' vecchio (hp pieni).
	var rec: Dictionary = e.call("_p_time_rewind",
		{"tipo": "time_rewind", "secondi": 5.0, "ripristina": ["hp", "spiritualita"],
		"costo_follia": 8.0}, c, s, "ab")
	assert_true(bool(rec["applied"]), "time_rewind ha letto uno snapshot")
	assert_almost_eq(float(s.get("hp")), hp_pieni,
		"gli hp del caster tornano al valore di prima del danno", 0.5)
	if m != null:
		assert_gt(m.call("valore"), follia0, "time_rewind costa follia")
	_cleanup(c)


func test_proietta_avatar_evoca_una_materia_prima_avatar() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var r: Dictionary = e.call("execute", "error_proietta_avatar", c)
	assert_true(r["ok"], "proietta avatar eseguito")
	var rec: Dictionary = (r["effects"] as Array)[0]
	assert_eq(str(rec["tipo"]), "summon", "e' una summon")
	assert_true(str(rec["entita_id"]).begins_with("avatar_"),
		"entita_id ha il prefisso della materia prima 'avatar' (ownership.json)")
	_cleanup(c)


func test_error_e_contenuto_completo_10_su_10() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "error")
	var madness_prec: float = -1.0
	var n: int = 0
	for seq in (pw.get("sequences", []) as Array):
		var d: Dictionary = seq
		n += 1
		assert_false(bool(d.get("stub", false)),
			"error_%d non e' piu' stub" % int(d.get("sequence")))
		var somma: float = 0.0
		for a in (d.get("acting_actions", []) as Array):
			somma += float((a as Dictionary).get("progresso", 0.0))
		assert_almost_eq(somma, 1.0,
			"error_%d: le acting_actions sommano 1.0" % int(d.get("sequence")))
		var mf: float = float(d.get("madness_on_force", 0.0))
		assert_gt(mf, madness_prec,
			"error_%d: madness_on_force cresce lungo il Pathway" % int(d.get("sequence")))
		madness_prec = mf
	assert_eq(n, 10, "Error ha 10 Sequenze, tutte contenuto")


func test_error_1_sacrifica_un_ancora() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "error")
	for seq in (pw.get("sequences", []) as Array):
		if int((seq as Dictionary).get("sequence", -1)) != 1:
			continue
		var rit: Dictionary = (seq as Dictionary).get("advancement_ritual", {})
		assert_true("ancora_del_giocatore" in (rit.get("sacrifices", []) as Array),
			"il rituale di Sequenza 1 sacrifica un'Ancora del giocatore (come twilight_giant_1)")


func test_error_4_ha_un_rituale_con_luogo_valido() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "error")
	for seq in (pw.get("sequences", []) as Array):
		if int((seq as Dictionary).get("sequence", -1)) != 4:
			continue
		var rit: Dictionary = (seq as Dictionary).get("advancement_ritual", {})
		assert_false(rit.is_empty(), "error_4 (Seq <= 4) ha un advancement_ritual")
		assert_gt(float((rit.get("location_tags", []) as Array).size()), 0.0,
			"col suo luogo (nebbia_grigia / crocevia)")
