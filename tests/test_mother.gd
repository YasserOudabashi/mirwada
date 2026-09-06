extends "res://tests/test_case.gd"
## US-512 — Mother, Sequenze 9-7 (Planter / Doctor / Harvest Priest) +
## primitiva plant_growth. Le 6 abilita' eseguono senza warning;
## plant_growth persistente entra nel WorldState; le acting sommano 1.0.

const Stats := preload("res://scripts/stats_component.gd")

const ABILITA_9_7 := [
	"mother_germoglio_rapido", "mother_mano_verde",
	"mother_diagnosi", "mother_sutura",
	"mother_benedizione_raccolto", "mother_terra_generosa",
]


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node("GameData")


func _ws() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("WorldState")


func prepara() -> void:
	var e: Node = _engine()
	if e != null:
		e.call("clear_cooldowns")
		e.call("flush_effects")
	if _ws() != null:
		_ws().call("pulisci")


func _caster() -> Node2D:
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	Engine.get_main_loop().root.add_child(c)
	s.call("configure_from_balance", 8)
	return c


func _cleanup(c: Node) -> void:
	Engine.get_main_loop().root.remove_child(c)
	c.free()


func test_ogni_abilita_mother_9_7_si_esegue_senza_warning() -> void:
	var e: Node = _engine()
	for aid in ABILITA_9_7:
		var c: Node2D = _caster()
		var r: Dictionary = e.call("execute", aid, c)
		assert_true(r["ok"], "%s eseguita" % aid)
		assert_eq((r["warnings"] as PackedStringArray).size(), 0,
			"%s: nessun warning di primitiva (plant_growth implementata): %s" % [aid, r["warnings"]])
		e.call("clear_cooldowns")
		_cleanup(c)


func test_plant_growth_persistente_entra_nel_world_state() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	assert_eq(int(_ws().call("terreni").size()), 0, "nessun terreno all'inizio")
	e.call("execute", "mother_terra_generosa", c)  # plant_growth persistente:true
	var terreni: Array = _ws().call("terreni")
	assert_eq(terreni.size(), 1, "il campo fiorito persistente e' registrato nel WorldState")
	assert_true(str((terreni[0] as Dictionary).get("tipo_modifica", "")).begins_with("vegetazione:"),
		"registrato come vegetazione: %s" % terreni[0])
	_cleanup(c)


func test_plant_growth_temporaneo_non_tocca_il_world_state() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	e.call("execute", "mother_germoglio_rapido", c)  # persistente:false
	assert_eq(int(_ws().call("terreni").size()), 0,
		"un germoglio temporaneo non entra nel WorldState (e' consumo di fase 6)")
	_cleanup(c)


func test_mother_9_7_sono_contenuto() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "mother")
	for seq in (pw.get("sequences", []) as Array):
		var n: int = int((seq as Dictionary).get("sequence", -1))
		if n < 7 or n > 9:
			continue
		assert_false(bool((seq as Dictionary).get("stub", false)), "mother_%d non e' piu' stub" % n)
		var somma: float = 0.0
		for a in ((seq as Dictionary).get("acting_actions", []) as Array):
			somma += float((a as Dictionary).get("progresso", 0.0))
		assert_almost_eq(somma, 1.0, "mother_%d: acting sommano 1.0" % n)
