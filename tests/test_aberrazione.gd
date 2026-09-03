extends "res://tests/test_case.gd"
## US-312 — il fallimento peggiore: un esperimento evoca un'aberrazione ostile
## temporanea, aggiunge follia, degrada le fondamenta.

const StatsComponent := preload("res://scripts/stats_component.gd")


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/SummonRegistry") != null:
		_n("/root/SummonRegistry").call("pulisci")
	if _n("/root/Madness") != null:
		_n("/root/Madness").call("da_salvataggio", {})
	if _n("/root/Foundation") != null:
		_n("/root/Foundation").call("da_salvataggio", {})


func test_aberrazione_evoca_e_costa() -> void:
	var ps: Node = _n("/root/PotionSystem")
	var reg: Node = _n("/root/SummonRegistry")
	var mad: Node = _n("/root/Madness")
	var found: Node = _n("/root/Foundation")
	var follia0: float = float(mad.call("valore"))
	var fond0: float = float(found.call("valore"))

	ps.call("forza_esito", "aberrazione")

	assert_eq(reg.call("conta_temporanee"), 1, "una evocazione ostile temporanea")
	assert_eq(str((reg.call("temporanee")[0] as Dictionary).get("comportamento")), "ostile", "ostile")
	assert_gt(float(mad.call("valore")), follia0, "la follia e' salita")
	assert_true(float(found.call("valore")) < fond0, "le fondamenta sono scese")


func test_l_aberrazione_non_e_persistente() -> void:
	var ps: Node = _n("/root/PotionSystem")
	var reg: Node = _n("/root/SummonRegistry")
	ps.call("forza_esito", "aberrazione")
	assert_eq(reg.call("conta"), 0, "NON e' fra le evocazioni persistenti")
	assert_true((reg.call("per_salvataggio") as Array).is_empty(), "non entra nel save")


func test_l_aberrazione_scade() -> void:
	var reg: Node = _n("/root/SummonRegistry")
	reg.call("evoca_temporanea", "aberrazione_alchemica", "ostile", 1.0, 30.0)
	assert_eq(reg.call("conta_temporanee"), 1, "presente")
	# simula il tempo (SummonRegistry._process)
	reg.call("_process", 0.6)
	assert_eq(reg.call("conta_temporanee"), 1, "ancora viva a 0.6s")
	reg.call("_process", 0.6)
	assert_eq(reg.call("conta_temporanee"), 0, "scaduta dopo 1.2s")
