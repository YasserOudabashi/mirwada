extends "res://tests/test_case.gd"
## US-303 — equipaggiamento a slot: i bonus contano davvero.

const StatsComponent := preload("res://scripts/stats_component.gd")


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/Equipment") != null:
		_n("/root/Equipment").call("pulisci")
	if _n("/root/Inventory") != null:
		_n("/root/Inventory").call("pulisci")


## Player finto in gruppo 'player', liberato a fine test (come test_progression).
func _giocatore_finto() -> Node2D:
	var p := Node2D.new()
	p.add_to_group("player")
	var stats: Node = StatsComponent.new()
	stats.name = "StatsComponent"
	stats.call("configure_from_balance", 9)
	p.add_child(stats)
	Engine.get_main_loop().root.add_child(p)
	return p


func _prima_istanza(item_id: String) -> String:
	var inv: Node = _n("/root/Inventory")
	inv.call("aggiungi", item_id, 1)
	for v in inv.call("per_categoria", "equip"):
		if str((v as Dictionary).get("item_id")) == item_id:
			return str((v as Dictionary).get("instance_id"))
	return ""


func test_equipaggia_applica_i_modificatori() -> void:
	var p: Node2D = _giocatore_finto()
	var stats: Node = p.get_node("StatsComponent")
	var eq: Node = _n("/root/Equipment")
	var forza0: float = stats.call("get_stat", "forza")
	assert_true(eq.call("equipaggia", _prima_istanza("spada_ferrea")), "equipaggia la spada")
	assert_eq(eq.call("slot_pieni").get("arma"), "spada_ferrea", "slot arma occupato")
	assert_almost_eq(stats.call("get_stat", "forza"), forza0 + 0.1, "forza salita di 0.1")
	assert_true(stats.call("has_modifier", "equip:arma"), "modificatore per id 'equip:arma'")
	assert_eq(_n("/root/Inventory").call("conta", "spada_ferrea"), 0, "la spada e' uscita dallo zaino")
	eq.call("pulisci")
	p.free()


func test_rimuovi_slot_toglie_i_modificatori_e_restituisce() -> void:
	var p: Node2D = _giocatore_finto()
	var stats: Node = p.get_node("StatsComponent")
	var eq: Node = _n("/root/Equipment")
	var forza0: float = stats.call("get_stat", "forza")
	eq.call("equipaggia", _prima_istanza("spada_ferrea"))
	assert_true(eq.call("rimuovi_slot", "arma"), "smonta la spada")
	assert_almost_eq(stats.call("get_stat", "forza"), forza0, "forza tornata al valore base")
	assert_false(stats.call("has_modifier", "equip:arma"), "modificatore rimosso")
	assert_eq(_n("/root/Inventory").call("conta", "spada_ferrea"), 1, "la spada e' tornata nello zaino")
	eq.call("pulisci")
	p.free()


func test_accessori_su_slot_diversi() -> void:
	var p: Node2D = _giocatore_finto()
	var eq: Node = _n("/root/Equipment")
	eq.call("equipaggia", _prima_istanza("amuleto_lunare"))
	eq.call("equipaggia", _prima_istanza("amuleto_lunare"))
	var pieni: Dictionary = eq.call("slot_pieni")
	assert_true(pieni.has("accessorio_1") and pieni.has("accessorio_2"),
		"due accessori vanno su accessorio_1 e accessorio_2")
	eq.call("pulisci")
	p.free()


func test_instance_id_inesistente_non_esplode() -> void:
	var p: Node2D = _giocatore_finto()
	assert_false(_n("/root/Equipment").call("equipaggia", "inv_99999"),
		"instance_id inesistente -> false, nessun crash")
	p.free()


func test_round_trip_del_save() -> void:
	var p: Node2D = _giocatore_finto()
	var stats: Node = p.get_node("StatsComponent")
	var eq: Node = _n("/root/Equipment")
	var gs: Node = _n("/root/GameState")
	eq.call("equipaggia", _prima_istanza("corazza_cuoio"))   # {difesa: 0.15}
	var dif0: float = stats.call("get_stat", "difesa")
	var snap: Dictionary = gs.call("snapshot")
	eq.call("pulisci")
	assert_false(stats.call("has_modifier", "equip:armatura"), "svuotato")
	gs.call("applica", snap)
	assert_eq(eq.call("slot_pieni").get("armatura"), "corazza_cuoio", "corazza ri-equipaggiata")
	assert_almost_eq(stats.call("get_stat", "difesa"), dif0, "e il modificatore riapplicato")
	eq.call("pulisci")
	p.free()


func test_da_salvataggio_non_fidato() -> void:
	var eq: Node = _n("/root/Equipment")
	eq.call("da_salvataggio", "non un oggetto")
	assert_eq(eq.call("slot_pieni"), {}, "raw non-oggetto -> niente equip")
	eq.call("da_salvataggio", {"slot": {"arma": {"instance_id": "x", "item_id": "erba_lunare"}}})
	assert_eq(eq.call("slot_pieni"), {}, "item non-equip in uno slot -> scartato")
