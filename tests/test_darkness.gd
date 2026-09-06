extends "res://tests/test_case.gd"
## US-606 — Darkness, Sequenze 9-7 (Sleepless / Midnight Poet / Nightmare).
## BLOCCO C: chiude la fase 5b per il gruppo eternal_darkness. Nessuna
## primitiva nuova (fear/debuff/dot/light_purify/buff gia' esistono).

const Stats := preload("res://scripts/stats_component.gd")

const ABILITA_9_7 := [
	"darkness_forza_del_buio", "darkness_veglia_perpetua",
	"darkness_verso_cupo", "darkness_poesia_amara",
	"darkness_incubo", "darkness_terrore_notturno",
]


func _root() -> Node: return Engine.get_main_loop().root
func _e() -> Node: return _root().get_node("AbilityEngine")
func _gd() -> Node: return _root().get_node("GameData")


func prepara() -> void:
	_e().call("clear_cooldowns")
	_e().call("flush_effects")


func _caster() -> Node2D:
	# Node2D NUDO (non nel gruppo "player"): le condizioni e_notte sono ignorate
	# (US-605), il test isola l'esecuzione delle primitive.
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	_root().add_child(c)
	s.call("configure_from_balance", 7)
	s.set("spiritualita", 9999.0)
	return c


func _cleanup(c: Node) -> void:
	_root().remove_child(c)
	c.free()


func test_ogni_abilita_darkness_9_7_si_esegue_senza_warning() -> void:
	for aid in ABILITA_9_7:
		var c: Node2D = _caster()
		var r: Dictionary = _e().call("execute", aid, c)
		assert_true(r["ok"], "%s eseguita: %s" % [aid, r.get("reason")])
		assert_eq((r["warnings"] as PackedStringArray).size(), 0,
			"%s: nessun warning di primitiva: %s" % [aid, r["warnings"]])
		_e().call("clear_cooldowns")
		_cleanup(c)


func test_incubo_applica_paura_e_abbassa_la_precisione() -> void:
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	var prec0: float = s.call("get_stat", "precisione")
	var r: Dictionary = _e().call("execute", "darkness_incubo", c)
	assert_true(r["ok"], "incubo eseguito")
	assert_true(s.call("ha_status", "paura"), "fear applica lo status 'paura'")
	assert_gt(prec0, s.call("get_stat", "precisione"), "l'incubo disorienta la mira (precisione scesa)")
	_cleanup(c)


func test_forza_del_buio_ha_la_condizione_e_notte() -> void:
	var ab: Dictionary = _gd().call("get_ability", "darkness_forza_del_buio")
	var cond: Array = ab.get("condizioni", [])
	assert_eq(cond.size(), 1, "una condizione dichiarata")
	assert_eq(str((cond[0] as Dictionary).get("tipo")), "e_notte", "e' e_notte (Sleepless al buio)")


func test_darkness_9_8_7_non_piu_stub_acting_1() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "darkness")
	var madness_prec: float = -1.0
	for seq in (pw.get("sequences", []) as Array):
		var d: Dictionary = seq
		var n: int = int(d.get("sequence"))
		if n < 7 or n > 9:
			continue
		assert_false(bool(d.get("stub", false)), "darkness_%d non e' piu' stub" % n)
		var somma: float = 0.0
		for a in (d.get("acting_actions", []) as Array):
			somma += float((a as Dictionary).get("progresso", 0.0))
		assert_almost_eq(somma, 1.0, "darkness_%d: acting sommano 1.0" % n)
		var mf: float = float(d.get("madness_on_force", 0.0))
		assert_gt(mf, madness_prec, "darkness_%d: madness_on_force cresce" % n)
		madness_prec = mf
		assert_false(_gd().call("get_formula", "formula_darkness_%d" % n).is_empty(),
			"formula_darkness_%d esiste" % n)
