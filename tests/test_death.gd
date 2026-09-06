extends "res://tests/test_case.gd"
## US-505 — Death, Sequenze 9-7: le 6 abilita' si eseguono senza warning di
## primitiva (fear e reveal_info implementate qui); fear applica lo status
## 'paura'; reveal_info emette il segnale; le acting sommano 1.0.

const Stats := preload("res://scripts/stats_component.gd")

const ABILITA_9_7 := [
	"death_tocco_gelido", "death_pelle_di_tomba",
	"death_rianima_servo", "death_stretta_della_terra",
	"death_seduta_spiritica", "death_lamento_funebre",
]
const ABILITA_6_4 := [
	"death_scaglia_spirito", "death_falange_spettrale",
	"death_passo_tra_i_mondi", "death_porta_di_fuga",
	"death_carne_ostinata", "death_rialzati",
]


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node("GameData")


func prepara() -> void:
	var e: Node = _engine()
	if e != null:
		e.call("clear_cooldowns")
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


func test_ogni_abilita_death_9_7_si_esegue_senza_warning() -> void:
	var e: Node = _engine()
	for aid in ABILITA_9_7:
		var c: Node2D = _caster()
		var r: Dictionary = e.call("execute", aid, c)
		assert_true(r["ok"], "%s eseguita" % aid)
		assert_eq((r["warnings"] as PackedStringArray).size(), 0,
			"%s: nessun warning di primitiva (tutte implementate): %s" % [aid, r["warnings"]])
		e.call("clear_cooldowns")
		_cleanup(c)


func test_fear_applica_lo_status_paura() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	var prec0: float = s.call("get_stat", "precisione")
	var r: Dictionary = e.call("execute", "death_lamento_funebre", c)
	assert_true(r["ok"], "lamento funebre eseguito")
	assert_true(s.call("ha_status", "paura"), "la primitiva fear ha applicato lo status 'paura'")
	assert_gt(prec0, s.call("get_stat", "precisione"),
		"il bersaglio spaventato colpisce peggio (precisione scesa)")
	_cleanup(c)


func test_reveal_info_emette_il_segnale_con_la_categoria() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var visto: Array = []
	var cb := func(categoria: String, _raggio: float, _origine: Vector2) -> void: visto.append(categoria)
	e.connect("info_rivelata", cb)
	e.call("execute", "death_seduta_spiritica", c)
	e.disconnect("info_rivelata", cb)
	assert_true(visto.has("voce_dei_morti"),
		"reveal_info emette info_rivelata con la categoria dichiarata nei dati")
	_cleanup(c)


func test_ogni_abilita_death_6_4_si_esegue_senza_warning() -> void:
	var e: Node = _engine()
	for aid in ABILITA_6_4:
		var c: Node2D = _caster()
		var r: Dictionary = e.call("execute", aid, c)
		assert_true(r["ok"], "%s eseguita" % aid)
		assert_eq((r["warnings"] as PackedStringArray).size(), 0,
			"%s: nessun warning di primitiva (teleport implementata): %s" % [aid, r["warnings"]])
		e.call("clear_cooldowns")
		_cleanup(c)


func test_teleport_consegna_l_ordine_e_non_crasha() -> void:
	# come _p_dash: se il caster non sa muoversi, applied=false e nessun crash.
	var e: Node = _engine()
	var r: Dictionary = e.call("_p_teleport",
		{"distanza": 200, "richiede_visuale": false, "porta_alleati": false}, null, null, "ab")
	assert_eq(str(r["tipo"]), "teleport", "record della primitiva")
	assert_almost_eq(float(r["distanza"]), 200.0, "distanza dai dati")
	assert_false(bool(r["applied"]), "caster senza teleport_verso -> non applicato")


func test_death_4_ha_un_rituale_con_luogo_valido() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "death")
	for seq in (pw.get("sequences", []) as Array):
		if int((seq as Dictionary).get("sequence", -1)) != 4:
			continue
		var rit: Dictionary = (seq as Dictionary).get("advancement_ritual", {})
		assert_false(rit.is_empty(), "death_4 (Seq <= 4) ha un advancement_ritual")
		assert_gt(float((rit.get("location_tags", []) as Array).size()), 0.0, "col suo luogo")


func test_le_acting_di_death_9_4_sommano_uno() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "death")
	for seq in (pw.get("sequences", []) as Array):
		var n: int = int((seq as Dictionary).get("sequence", -1))
		if n < 4 or n > 9:
			continue
		var somma: float = 0.0
		for a in ((seq as Dictionary).get("acting_actions", []) as Array):
			somma += float((a as Dictionary).get("progresso", 0.0))
		assert_almost_eq(somma, 1.0, "death_%d: le acting_actions sommano esattamente 1.0" % n)
		assert_false(bool((seq as Dictionary).get("stub", false)), "death_%d non e' piu' stub" % n)
