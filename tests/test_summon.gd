extends "res://tests/test_case.gd"
## US-205 — evocazioni persistenti serializzate (primitiva summon + SummonRegistry).

const Stats := preload("res://scripts/stats_component.gd")

const SLOT := 903


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


func _reg() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SummonRegistry")


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SaveSystem")


func prepara() -> void:
	var e: Node = _engine()
	if e != null:
		e.call("clear_cooldowns")
		e.call("clear_granted")
		e.call("flush_effects")
	if _reg() != null:
		_reg().call("pulisci")


func _caster() -> Node2D:
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	Engine.get_main_loop().root.add_child(c)
	s.call("configure_from_balance", 9)
	c.global_position = Vector2(50, 60)
	return c


func _cleanup(c: Node) -> void:
	Engine.get_main_loop().root.remove_child(c)
	c.free()


func test_summon_nel_registro() -> void:
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	assert_false((gd.call("get_primitive", "summon") as Dictionary).is_empty(),
		"summon nel registro chiuso")


func test_summon_persistente_va_nel_registro_non_nella_scena() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var rec: Dictionary = e.call("_p_summon",
		{"entita_id": "non_morto_legionario", "quantita": 3, "durata": -1.0, "comportamento": "aggressivo"},
		c, c.get_node("Stats"), "ab")
	assert_true(rec["applied"], "evocazione applicata")
	assert_eq((rec["persistenti"] as Array).size(), 3, "tre id restituiti")
	assert_eq(_reg().call("conta"), 3, "tre evocazioni nel registro centrale")

	var evo: Array = _reg().call("evocazioni")
	assert_eq((evo[0] as Dictionary)["tipo"], "non_morto_legionario", "tipo = entita_id")
	assert_eq((evo[0] as Dictionary)["posizione"], [50.0, 60.0], "posizione del caster")

	# NIENTE figli aggiunti al caster o alla sua scena
	assert_eq(c.get_child_count(), 1, "solo lo StatsComponent: nessun Node evocazione in scena")
	_cleanup(c)


func test_summon_temporanea_scade_e_non_tocca_il_registro() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	e.call("_p_summon",
		{"entita_id": "bestia_remota", "quantita": 1, "durata": 180.0, "comportamento": "legame_pet"},
		c, c.get_node("Stats"), "ab")
	assert_eq(_reg().call("conta"), 0, "una temporanea non entra nel registro persistente")
	assert_eq(e.call("pending_count"), 1, "e' un'entry a tempo")
	e.call("tick_effects", 181.0)
	assert_eq(e.call("pending_count"), 0, "scaduta")
	_cleanup(c)


func test_round_trip_del_save() -> void:
	var e: Node = _engine()
	var s: Node = _save()
	var c: Node2D = _caster()
	e.call("_p_summon",
		{"entita_id": "costrutto_animato", "quantita": 2, "durata": -1.0, "comportamento": "difensivo"},
		c, c.get_node("Stats"), "ab")
	_cleanup(c)

	if s.esiste(SLOT):
		s.cancella(SLOT)
	var snap: Dictionary = {"nome_personaggio": "Enel", "evocazioni": _reg().call("per_salvataggio")}
	assert_true(s.salva(SLOT, snap)["ok"], "salva ok")

	_reg().call("pulisci")
	assert_eq(_reg().call("conta"), 0, "registro azzerato")

	var caricato: Dictionary = s.carica(SLOT)
	_reg().call("da_salvataggio", (caricato["dati"] as Dictionary)["evocazioni"])
	assert_eq(_reg().call("conta"), 2, "due evocazioni ricreate dal save")
	assert_eq((_reg().call("evocazioni")[0] as Dictionary)["tipo"], "costrutto_animato", "tipo ripristinato")
	s.cancella(SLOT)


func test_evocazione_con_fonte_persa_non_viene_ricreata() -> void:
	var r: Node = _reg()
	r.call("da_salvataggio", [
		{"id": "sum_1", "tipo": "non_morto_legionario", "posizione": [1, 2], "hp": 10},
		{"id": "sum_2", "posizione": [3, 4]},          # manca 'tipo': fonte persa
		{"id": "sum_3", "tipo": "", "posizione": [5, 6]},  # tipo vuoto
		"non un oggetto",
	])
	assert_eq(r.call("conta"), 1, "solo l'evocazione con fonte valida e' ricreata")

	r.call("da_salvataggio", "niente lista")
	assert_eq(r.call("conta"), 0, "raw non-lista -> vuoto, nessun crash")


func test_execute_death_legione_compone_summon_e_aura() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var r: Dictionary = e.call("execute", "death_legione", c)
	assert_true(r["ok"], "death_legione eseguita")
	assert_eq((r["warnings"] as PackedStringArray).size(), 0, "nessun warning di primitiva")
	assert_eq((r["effects"] as Array).size(), 2, "summon + aura")
	assert_eq(_reg().call("conta"), 8, "8 legionari persistenti (quantita dai dati)")
	_cleanup(c)
