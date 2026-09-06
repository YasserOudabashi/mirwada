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


func test_le_acting_di_death_9_7_sommano_uno() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "death")
	for seq in (pw.get("sequences", []) as Array):
		var n: int = int((seq as Dictionary).get("sequence", -1))
		if n < 7 or n > 9:
			continue
		var somma: float = 0.0
		for a in ((seq as Dictionary).get("acting_actions", []) as Array):
			somma += float((a as Dictionary).get("progresso", 0.0))
		assert_almost_eq(somma, 1.0, "death_%d: le acting_actions sommano esattamente 1.0" % n)
		assert_false(bool((seq as Dictionary).get("stub", false)), "death_%d non e' piu' stub" % n)
