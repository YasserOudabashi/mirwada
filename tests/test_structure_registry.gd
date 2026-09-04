extends "res://tests/test_case.gd"
## US-319 — StructureRegistry: costruite, danneggiate, distrutte.


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/StructureRegistry") != null:
		_n("/root/StructureRegistry").call("pulisci")
	if _n("/root/EventTracker") != null:
		_n("/root/EventTracker").call("azzera")


func test_costruisci_e_attiva() -> void:
	var reg: Node = _n("/root/StructureRegistry")
	var iid: String = reg.call("costruisci", "palizzata_lignea", Vector2(10, 20))
	assert_false(iid.is_empty(), "costruisci restituisce un instance_id")
	var attive: Array = reg.call("attive")
	assert_eq(attive.size(), 1, "una struttura attiva")
	assert_eq((attive[0] as Dictionary).get("struct_id"), "palizzata_lignea", "tipo corretto")
	assert_almost_eq(float((attive[0] as Dictionary).get("hp")), 60.0, "hp = hp_max alla costruzione")


func test_tipo_ignoto_non_costruisce() -> void:
	var reg: Node = _n("/root/StructureRegistry")
	assert_eq(reg.call("costruisci", "struttura_inventata", Vector2.ZERO), "",
		"tipo ignoto -> stringa vuota, nessun crash")
	assert_eq((reg.call("attive") as Array).size(), 0, "nessuna struttura creata")


func test_danneggia_fino_a_zero_distrugge_ed_emette_levento() -> void:
	var reg: Node = _n("/root/StructureRegistry")
	var et: Node = _n("/root/EventTracker")
	var iid: String = reg.call("costruisci", "altare_domestico", Vector2.ZERO)   # hp_max 40
	reg.call("danneggia", iid, 25.0)
	assert_eq((reg.call("attive") as Array).size(), 1, "danneggiata ma ancora in piedi")
	reg.call("danneggia", iid, 25.0)   # 40 -25 -25 = sotto zero
	assert_eq((reg.call("attive") as Array).size(), 0, "distrutta a 0 hp")
	assert_true(reg.call("struttura", iid).is_empty(), "non piu' recuperabile")
	assert_almost_eq(et.call("count", "structure_destroyed", {"volontario": false}), 1.0,
		"danneggiata a 0 -> distruzione INvolontaria")


func test_distruggi_volontario_conta_diversamente() -> void:
	var reg: Node = _n("/root/StructureRegistry")
	var et: Node = _n("/root/EventTracker")
	var iid: String = reg.call("costruisci", "torretta_vedetta", Vector2.ZERO)
	assert_true(reg.call("distruggi", iid, true), "distruggi volontario riesce")
	assert_almost_eq(et.call("count", "structure_destroyed", {"volontario": true}), 1.0,
		"structure_destroyed{volontario:true} contato")
	assert_almost_eq(et.call("count", "structure_destroyed", {"volontario": false}), 0.0,
		"non nel bucket involontario")


func test_distruggi_id_ignoto_gestito() -> void:
	assert_false(_n("/root/StructureRegistry").call("distruggi", "struct_9999", true),
		"instance_id ignoto -> false, nessun crash")


func test_in_raggio() -> void:
	var reg: Node = _n("/root/StructureRegistry")
	reg.call("costruisci", "palizzata_lignea", Vector2(0, 0))
	reg.call("costruisci", "torretta_vedetta", Vector2(500, 500))
	var vicine: Array = reg.call("in_raggio", Vector2(0, 0), 50.0)
	assert_eq(vicine.size(), 1, "solo la struttura in raggio")
	assert_eq((vicine[0] as Dictionary).get("struct_id"), "palizzata_lignea", "quella giusta")


## Round trip a livello di StructureRegistry direttamente, non di GameState
## (vedi la nota in test_sigilli_incastonatura.gd sulla contaminazione fra
## file quando si passa da GameState con autoload persistenti per suite).
func test_round_trip_del_save() -> void:
	var reg: Node = _n("/root/StructureRegistry")
	var iid: String = reg.call("costruisci", "altare_domestico", Vector2(3, 4))
	reg.call("danneggia", iid, 10.0)   # hp 40 -> 30, ancora in piedi
	var snap: Array = reg.call("per_salvataggio")
	reg.call("pulisci")
	assert_eq((reg.call("attive") as Array).size(), 0, "svuotato")
	reg.call("da_salvataggio", snap)
	var attive: Array = reg.call("attive")
	assert_eq(attive.size(), 1, "la struttura torna dal save")
	assert_eq((attive[0] as Dictionary).get("instance_id"), iid, "stesso instance_id")
	assert_almost_eq(float((attive[0] as Dictionary).get("hp")), 30.0, "hp preservato, non resettato a hp_max")


func test_da_salvataggio_non_fidato() -> void:
	var reg: Node = _n("/root/StructureRegistry")
	reg.call("da_salvataggio", "non una lista")
	assert_eq((reg.call("attive") as Array).size(), 0, "raw non-array -> niente strutture")
	reg.call("da_salvataggio", [{"struct_id": "struttura_inventata", "instance_id": "x"}])
	assert_eq((reg.call("attive") as Array).size(), 0, "struct_id ignoto -> voce scartata")
