extends "res://tests/test_case.gd"
## US-203C — primitiva terrain_modify + stato del mondo persistente (WorldState).

const Stats := preload("res://scripts/stats_component.gd")

const SLOT := 902


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


func _world() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("WorldState")


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SaveSystem")


func prepara() -> void:
	var e: Node = _engine()
	if e != null:
		e.call("clear_cooldowns")
		e.call("flush_effects")
	if _world() != null:
		_world().call("pulisci")


func _caster() -> Node2D:
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	Engine.get_main_loop().root.add_child(c)
	s.call("configure_from_balance", 9)
	c.global_position = Vector2(100, 200)
	return c


func _cleanup(c: Node) -> void:
	Engine.get_main_loop().root.remove_child(c)
	c.free()


func test_terrain_modify_nel_registro() -> void:
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	assert_false((gd.call("get_primitive", "terrain_modify") as Dictionary).is_empty(),
		"terrain_modify nel registro chiuso")


func test_permanente_incide_nello_stato_del_mondo() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var rec: Dictionary = e.call("_p_terrain_modify",
		{"tipo_modifica": "apre_varco", "raggio": 3.0, "durata": 0.0, "permanente": true},
		c, c.get_node("Stats"), "ab")
	assert_true(rec["applied"], "modifica permanente registrata")

	var terreni: Array = _world().call("terreni")
	assert_eq(terreni.size(), 1, "una modifica nello stato del mondo")
	assert_eq((terreni[0] as Dictionary)["tipo_modifica"], "apre_varco", "tipo registrato")
	assert_eq((terreni[0] as Dictionary)["posizione"], [100.0, 200.0], "posizione del caster")
	_cleanup(c)


func test_permanente_sopravvive_al_round_trip_del_save() -> void:
	var e: Node = _engine()
	var s: Node = _save()
	var c: Node2D = _caster()
	e.call("_p_terrain_modify",
		{"tipo_modifica": "frantuma", "raggio": 6.0, "permanente": true},
		c, c.get_node("Stats"), "ab")
	_cleanup(c)

	if s.esiste(SLOT):
		s.cancella(SLOT)
	var snap: Dictionary = {"nome_personaggio": "Enel", "mondo": _world().call("per_salvataggio")}
	assert_true(s.salva(SLOT, snap)["ok"], "salva ok")

	_world().call("pulisci")
	assert_eq((_world().call("terreni") as Array).size(), 0, "stato del mondo azzerato")

	var caricato: Dictionary = s.carica(SLOT)
	_world().call("da_salvataggio", (caricato["dati"] as Dictionary)["mondo"])
	var terreni: Array = _world().call("terreni")
	assert_eq(terreni.size(), 1, "modifica ripristinata dal save")
	assert_eq((terreni[0] as Dictionary)["tipo_modifica"], "frantuma", "tipo ripristinato")
	s.cancella(SLOT)


func test_temporanea_va_in_coda_e_scade() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var rec: Dictionary = e.call("_p_terrain_modify",
		{"tipo_modifica": "fango", "raggio": 2.0, "durata": 5.0, "permanente": false},
		c, c.get_node("Stats"), "ab")
	assert_true(rec["applied"], "effetto temporaneo attivo")
	assert_eq(e.call("pending_count"), 1, "una entry temporanea in coda")
	assert_eq((_world().call("terreni") as Array).size(), 0, "niente nello stato del mondo permanente")

	e.call("tick_effects", 5.5)
	assert_eq(e.call("pending_count"), 0, "effetto temporaneo scaduto")
	_cleanup(c)


func test_da_salvataggio_scarta_le_voci_malformate() -> void:
	var w: Node = _world()
	w.call("da_salvataggio", {"terrain_mods": [
		{"tipo_modifica": "ok", "posizione": [1, 2], "raggio": 3},
		{"posizione": [1, 2]},               # manca tipo_modifica
		{"tipo_modifica": "x", "posizione": "NE"},  # posizione non lista
		"non un oggetto",
	]})
	assert_eq((w.call("terreni") as Array).size(), 1, "solo la voce valida sopravvive")

	w.call("da_salvataggio", "niente dizionario")
	assert_eq((w.call("terreni") as Array).size(), 0, "raw non-oggetto -> lista vuota, nessun crash")


func test_migrazione_da_v3_aggiunge_lo_stato_del_mondo() -> void:
	var s: Node = _save()
	if s.esiste(SLOT):
		s.cancella(SLOT)
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open("user://saves/slot_%d.json" % SLOT, FileAccess.WRITE)
	f.store_string('{"schema_version": 3, "nome_personaggio": "v3", "posizione": [0, 0], "statistiche": {}, "evocazioni": [], "progressione": {"pathway_id": "", "sequence": 9}}')
	f.close()

	var c: Dictionary = s.carica(SLOT)
	assert_true(c["ok"] and c["migrato"], "migrazione applicata")
	assert_eq(((c["dati"] as Dictionary)["mondo"] as Dictionary)["terrain_mods"], [], "campo mondo aggiunto vuoto")
	s.cancella(SLOT)


func test_composizione_terrain_piu_purify_via_execute() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var r: Dictionary = e.call("execute", "tg_spezza_barriera", c)
	assert_true(r["ok"], "tg_spezza_barriera eseguita")
	assert_eq((r["warnings"] as PackedStringArray).size(), 0, "nessun warning di primitiva")
	assert_eq((r["effects"] as Array).size(), 2, "terrain_modify + light_purify")
	assert_eq((_world().call("terreni") as Array).size(), 1, "varco inciso nello stato del mondo")
	_cleanup(c)
