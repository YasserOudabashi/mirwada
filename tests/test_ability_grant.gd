extends "res://tests/test_case.gd"
## US-204 — AbilityEngine esegue un'abilita' NON posseduta, con un prestito
## a tempo. Serve allo stress test (Error, Sequenza 6: usa abilita' altrui).

const Stats := preload("res://scripts/stats_component.gd")


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


func _prog() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Progression")


func prepara() -> void:
	var e: Node = _engine()
	if e != null:
		e.call("clear_cooldowns")
		e.call("clear_granted")
		e.call("flush_effects")
	if _prog() != null:
		_prog().configura("", 9)


## Caster generico (nessun Pathway): non in gruppo "player".
func _caster() -> Node2D:
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	Engine.get_main_loop().root.add_child(c)
	s.call("configure_from_balance", 9)
	return c


## Caster giocatore: nel gruppo "player", ownership = abilita' del Pathway.
func _giocatore() -> Node2D:
	var c: Node2D = _caster()
	c.add_to_group("player")
	return c


func _cleanup(c: Node) -> void:
	Engine.get_main_loop().root.remove_child(c)
	c.free()


func test_grant_registra_ed_e_ispezionabile() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	assert_true(e.call("grant_temporary", "tg_armatura_alba", c, 10.0), "prestito concesso")
	assert_true(e.call("is_granted", c, "tg_armatura_alba"), "is_granted true")
	assert_true("tg_armatura_alba" in (e.call("granted_abilities", c) as Array),
		"granted_abilities elenca il prestito")
	_cleanup(c)


func test_grant_di_abilita_inesistente_fallisce() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	assert_false(e.call("grant_temporary", "abilita_che_non_esiste", c, 10.0),
		"nessun prestito per un'abilita' inesistente")
	_cleanup(c)


func test_giocatore_non_puo_lanciare_abilita_non_posseduta() -> void:
	var e: Node = _engine()
	var g: Node2D = _giocatore()
	# twilight_giant Sequenza 9: possiede tg_fendente_pesante / tg_stretta_ferrea,
	# NON tg_armatura_alba (Sequenza 6).
	var owned: Array = e.call("owned_abilities", g)
	assert_false("tg_armatura_alba" in owned, "tg_armatura_alba non e' posseduta a Seq 9")

	var r: Dictionary = e.call("execute", "tg_armatura_alba", g)
	assert_false(r["ok"], "esecuzione rifiutata")
	assert_eq(r["reason"], e.ERR_NON_POSSEDUTA, "motivo: abilita non posseduta")
	_cleanup(g)


func test_prestito_sblocca_l_esecuzione_e_scade() -> void:
	var e: Node = _engine()
	var g: Node2D = _giocatore()
	var s: Node = g.get_node("Stats")
	s.set("spiritualita", 50.0)

	assert_true(e.call("grant_temporary", "tg_armatura_alba", g, 5.0), "prestito concesso")
	var r: Dictionary = e.call("execute", "tg_armatura_alba", g)
	assert_true(r["ok"], "con il prestito l'abilita' si esegue")

	# scadenza gestita da tick_effects
	e.call("tick_effects", 5.5)
	assert_false(e.call("is_granted", g, "tg_armatura_alba"), "prestito scaduto")
	assert_true((e.call("granted_abilities", g) as Array).is_empty(), "niente piu' prestiti")

	e.call("clear_cooldowns")
	var r2: Dictionary = e.call("execute", "tg_armatura_alba", g)
	assert_false(r2["ok"], "dopo la scadenza torna rifiutata")
	assert_eq(r2["reason"], e.ERR_NON_POSSEDUTA, "rifiuto gestito, non crash")
	_cleanup(g)


func test_caster_senza_pathway_non_ha_restrizioni() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()  # non nel gruppo "player"
	assert_true((e.call("owned_abilities", c) as Array).is_empty(),
		"ownership sconosciuta per un caster senza Pathway")
	var r: Dictionary = e.call("execute", "tg_armatura_alba", c)
	assert_true(r["ok"], "un caster non-giocatore esegue senza restrizioni (flusso invariato)")
	_cleanup(c)


func test_prestito_muore_col_caster() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	e.call("grant_temporary", "tg_armatura_alba", c, 30.0)
	assert_eq((e.call("granted_abilities", c) as Array).size(), 1, "un prestito")
	_cleanup(c)  # caster liberato mentre il prestito e' valido
	e.call("sweep_cooldowns")
	# nessun crash; la voce del caster liberato e' sparita
	e.call("tick_effects", 1.0)
	assert_eq(e.call("pending_count"), 0, "coda ripulita")
