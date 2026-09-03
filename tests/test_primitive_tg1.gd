extends "res://tests/test_case.gd"
## US-202 — primitive del Twilight Giant, parte 1: shield, aura, dot, decay.
## Tutte lette dal registro chiuso data/schema/primitives.json.

const Stats := preload("res://scripts/stats_component.gd")
const Hurtbox := preload("res://scripts/hurtbox.gd")


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


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
	s.call("configure_from_balance", 9)
	return c


func _cleanup(c: Node) -> void:
	Engine.get_main_loop().root.remove_child(c)
	c.free()


func test_le_quattro_primitive_sono_nel_registro() -> void:
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	for tipo in ["shield", "aura", "dot", "decay"]:
		assert_false((gd.call("get_primitive", tipo) as Dictionary).is_empty(),
			"'%s' nel registro chiuso" % tipo)


func test_shield_assorbe_prima_degli_hp() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	var hb: Area2D = Hurtbox.new()
	c.add_child(hb)

	var rec: Dictionary = e.call("_p_shield",
		{"assorbimento": 50.0, "durata": 10.0, "riflette": 0.0, "tag_bloccati": []},
		c, s, "ab")
	assert_true(rec["applied"], "scudo applicato su self")
	assert_almost_eq(float(s.call("scudo")), 50.0, "riserva di scudo = assorbimento")

	var hp0: float = float(s.get("hp"))
	hb.subisci(30.0, 0.0, null)
	assert_almost_eq(float(s.get("hp")), hp0, "colpo entro lo scudo: hp intatti")
	assert_almost_eq(float(s.call("scudo")), 20.0, "scudo ridotto del danno assorbito")

	hb.subisci(30.0, 0.0, null)
	assert_almost_eq(float(s.get("hp")), hp0 - 10.0, "eccedenza oltre lo scudo va agli hp")
	assert_almost_eq(float(s.call("scudo")), 0.0, "scudo esaurito")
	_cleanup(c)


func test_shield_scade_dopo_la_durata() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")

	e.call("_p_shield", {"assorbimento": 40.0, "durata": 5.0}, c, s, "ab")
	assert_eq(e.call("pending_count"), 1, "scadenza dello scudo in coda")
	e.call("tick_effects", 3.0)
	assert_almost_eq(float(s.call("scudo")), 40.0, "ancora attivo a 3s")
	e.call("tick_effects", 2.5)
	assert_almost_eq(float(s.call("scudo")), 0.0, "azzerato dopo 5s")
	assert_eq(e.call("pending_count"), 0, "coda svuotata")
	_cleanup(c)


func test_shield_bersaglio_non_self_non_scuda_il_caster() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	var rec: Dictionary = e.call("_p_shield",
		{"assorbimento": 90.0, "bersaglio": "alleato"}, c, s, "ab")
	assert_false(rec["applied"], "bersaglio non risolvibile: scudo non applicato")
	assert_almost_eq(float(s.call("scudo")), 0.0, "caster senza scudo")
	_cleanup(c)


func test_dot_danneggia_a_ogni_tick() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	s.set("hp", 100.0)

	e.call("_p_dot", {"danno_tick": 10.0, "tick_rate": 1.0, "durata": 3.0, "tag_danno": "luce"},
		c, s, "ab")
	e.call("tick_effects", 1.0)
	assert_almost_eq(float(s.get("hp")), 90.0, "primo tick")
	e.call("tick_effects", 2.0)
	assert_almost_eq(float(s.get("hp")), 70.0, "tre tick in totale sulla durata")
	assert_eq(e.call("pending_count"), 0, "dot concluso")
	_cleanup(c)


func test_decay_spalma_il_danno_totale_sulla_durata() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	s.set("hp", 100.0)

	var rec: Dictionary = e.call("_p_decay",
		{"danno": 60.0, "raggio": 7.0, "colpisce_oggetti": true, "durata": 10.0},
		c, s, "ab")
	assert_almost_eq(float(rec["raggio"]), 7.0, "raggio registrato")
	assert_true(rec["colpisce_oggetti"], "colpisce_oggetti registrato")

	e.call("tick_effects", 5.0)
	assert_almost_eq(float(s.get("hp")), 70.0, "meta' del danno a meta' durata")
	e.call("tick_effects", 8.0)
	assert_almost_eq(float(s.get("hp")), 40.0, "danno totale = 60, mai di piu' con delta grosso")
	assert_eq(e.call("pending_count"), 0, "decay concluso")
	_cleanup(c)


func test_aura_persistente_vive_finche_il_caster_e_valido() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var rec: Dictionary = e.call("_p_aura",
		{"raggio": 999.0, "durata": -1.0, "effetto": "autorita", "tick_rate": 5.0, "bersagli": "mondo"},
		c, c.get_node("Stats"), "ab")
	assert_true(rec["persistente"], "durata -1 -> persistente")
	assert_eq(e.call("pending_count"), 1, "aura in coda")

	e.call("tick_effects", 100.0)
	assert_eq(e.call("pending_count"), 1, "una aura persistente non scade nel tempo")

	_cleanup(c)  # il caster sparisce
	e.call("tick_effects", 1.0)
	assert_eq(e.call("pending_count"), 0, "aura rimossa col caster non piu' valido")


func test_aura_a_durata_scade() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	e.call("_p_aura", {"raggio": 5.0, "durata": 4.0, "effetto": "decadimento", "bersagli": "nemici"},
		c, c.get_node("Stats"), "ab")
	assert_eq(e.call("pending_count"), 1, "aura a tempo in coda")
	e.call("tick_effects", 4.5)
	assert_eq(e.call("pending_count"), 0, "aura scaduta dopo la durata")
	_cleanup(c)


func test_composizione_shield_piu_buff_via_execute() -> void:
	# tg_armatura_alba compone shield + buff_stat: entrambe implementate,
	# nessun warning "non implementata" ne' "fuori registro".
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")

	var r: Dictionary = e.call("execute", "tg_armatura_alba", c)
	assert_true(r["ok"], "abilita' eseguita")
	assert_eq((r["warnings"] as PackedStringArray).size(), 0, "nessun warning di primitiva")
	assert_eq((r["effects"] as Array).size(), 2, "due primitive eseguite")
	assert_almost_eq(float(s.call("scudo")), 80.0, "scudo da 80 (dati) applicato")
	assert_true(s.call("has_modifier", "tg_armatura_alba:difesa"), "buff_stat applicato per id")
	_cleanup(c)
