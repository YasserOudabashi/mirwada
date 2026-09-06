extends "res://tests/test_case.gd"
## US-509 — Moon, Sequenze 9-7 (Apothecary / Beast Tamer / Vampire): le 6
## abilita' eseguono senza warning (nessuna primitiva nuova), il morso del
## Vampiro cura il caster, le acting sommano 1.0.

const Stats := preload("res://scripts/stats_component.gd")

const ABILITA_9_7 := [
	"moon_distillato_curativo", "moon_tonico_erbe",
	"moon_richiamo_compagno", "moon_legame_bestiale",
	"moon_morso", "moon_furia_notturna",
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
	s.call("configure_from_balance", 8)
	return c


func _cleanup(c: Node) -> void:
	Engine.get_main_loop().root.remove_child(c)
	c.free()


func test_ogni_abilita_moon_9_7_si_esegue_senza_warning() -> void:
	var e: Node = _engine()
	for aid in ABILITA_9_7:
		var c: Node2D = _caster()
		var r: Dictionary = e.call("execute", aid, c)
		assert_true(r["ok"], "%s eseguita" % aid)
		assert_eq((r["warnings"] as PackedStringArray).size(), 0,
			"%s: nessun warning di primitiva (Moon 9-7 non introduce primitive): %s" % [aid, r["warnings"]])
		e.call("clear_cooldowns")
		_cleanup(c)
	var reg: Node = Engine.get_main_loop().root.get_node_or_null("SummonRegistry")
	if reg != null:
		reg.call("pulisci")


func test_il_morso_del_vampiro_cura_il_caster() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	s.set("hp", 30.0)
	e.call("execute", "moon_morso", c)
	assert_almost_eq(float(s.get("hp")), 50.0, "moon_morso: +20 hp al caster (il drenaggio)")
	_cleanup(c)


func test_moon_9_7_sono_contenuto() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "moon")
	for seq in (pw.get("sequences", []) as Array):
		var n: int = int((seq as Dictionary).get("sequence", -1))
		if n < 7 or n > 9:
			continue
		assert_false(bool((seq as Dictionary).get("stub", false)), "moon_%d non e' piu' stub" % n)
		var somma: float = 0.0
		for a in ((seq as Dictionary).get("acting_actions", []) as Array):
			somma += float((a as Dictionary).get("progresso", 0.0))
		assert_almost_eq(somma, 1.0, "moon_%d: acting sommano 1.0" % n)
		var fid: String = "formula_moon_%d" % n
		assert_false((_gd().call("get_formula", fid) as Dictionary).is_empty(), "%s esiste" % fid)
