extends "res://tests/test_case.gd"
## US-320 — colpisce_oggetti: un decay con questo flag danneggia anche le
## strutture nel raggio (via StructureRegistry), non solo le hurtbox.


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func _engine() -> Node:
	return _n("/root/AbilityEngine")


func prepara() -> void:
	if _n("/root/StructureRegistry") != null:
		_n("/root/StructureRegistry").call("pulisci")


## Unit test diretto su Field: nessun frame da aspettare, deterministico.
func test_campo_decay_colpisce_oggetti_danneggia_solo_le_strutture_in_raggio() -> void:
	var reg: Node = _n("/root/StructureRegistry")
	var vicina: String = reg.call("costruisci", "palizzata_lignea", Vector2(10, 0))   # hp 60
	var lontana: String = reg.call("costruisci", "torretta_vedetta", Vector2(400, 0))  # hp 50

	var caster := Node2D.new()
	Engine.get_main_loop().root.add_child(caster)
	caster.global_position = Vector2.ZERO

	var campo: Node = preload("res://scripts/field.gd").new()
	caster.add_child(campo)
	campo.call("setup", {"tipo": "decay", "raggio": 50.0, "durata": 10.0,
		"tick_rate": 1.0, "danno_tick": 15.0, "colpisce_oggetti": true}, caster)
	campo.call("_applica_tick_strutture")

	assert_almost_eq(float(reg.call("struttura", vicina).get("hp")), 45.0,
		"struttura in raggio: -15 hp")
	assert_almost_eq(float(reg.call("struttura", lontana).get("hp")), 50.0,
		"struttura fuori raggio: intatta")

	caster.free()


## decay SENZA colpisce_oggetti: le strutture in raggio restano intatte.
func test_campo_decay_senza_colpisce_oggetti_non_tocca_le_strutture() -> void:
	var reg: Node = _n("/root/StructureRegistry")
	var iid: String = reg.call("costruisci", "palizzata_lignea", Vector2(0, 0))

	var caster := Node2D.new()
	Engine.get_main_loop().root.add_child(caster)
	caster.global_position = Vector2.ZERO

	var campo: Node = preload("res://scripts/field.gd").new()
	caster.add_child(campo)
	campo.call("setup", {"tipo": "decay", "raggio": 50.0, "durata": 10.0,
		"tick_rate": 1.0, "danno_tick": 15.0, "colpisce_oggetti": false}, caster)
	campo.call("_applica_tick_strutture")

	assert_almost_eq(float(reg.call("struttura", iid).get("hp")), 60.0, "intatta senza colpisce_oggetti")
	caster.free()


## Integrazione: _p_decay (la primitiva vera, non il campo a mano) propaga
## colpisce_oggetti dal dato dell'abilita' fino al campo spawnato.
func test_p_decay_propaga_colpisce_oggetti_al_campo() -> void:
	var reg: Node = _n("/root/StructureRegistry")
	var iid: String = reg.call("costruisci", "palizzata_lignea", Vector2(5, 0))

	var caster := Node2D.new()
	Engine.get_main_loop().root.add_child(caster)
	caster.global_position = Vector2.ZERO

	var rec: Dictionary = _engine().call("_p_decay",
		{"danno": 100.0, "raggio": 30.0, "durata": 10.0, "tick_rate": 1.0, "colpisce_oggetti": true},
		caster, null, "test_ability")
	assert_true(bool(rec.get("campo", false)), "premessa: il campo e' stato spawnato")

	# il campo appena creato e' l'ultimo figlio del caster.
	var campo: Node = caster.get_child(caster.get_child_count() - 1)
	campo.call("_applica_tick_strutture")

	assert_almost_eq(float(reg.call("struttura", iid).get("hp")), 50.0,
		"danno_tick = 100/10*1 = 10, la struttura perde 10 hp")
	caster.free()
