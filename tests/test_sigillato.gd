extends "res://tests/test_case.gd"
## US-318 — oggetti Sigillati: l'effetto_collaterale e' sempre attivo mentre
## sono indossati, indipendentemente da qualunque sigillo incastonato.

const StatsComponent := preload("res://scripts/stats_component.gd")


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/Equipment") != null:
		_n("/root/Equipment").call("pulisci")
	if _n("/root/Inventory") != null:
		_n("/root/Inventory").call("pulisci")
	if _n("/root/Madness") != null:
		_n("/root/Madness").call("azzera")
	if _n("/root/AnchorSystem") != null:
		_n("/root/AnchorSystem").call("pulisci")


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
	var creati: Array = _n("/root/Inventory").call("aggiungi", item_id, 1)
	return str(creati[0]) if not creati.is_empty() else ""


func test_almeno_3_equip_sigillati() -> void:
	var gd: Node = _n("/root/GameData")
	var n: int = 0
	for it in gd.call("items_per_categoria", "equip"):
		if bool((it as Dictionary).get("sigillato", false)):
			n += 1
	assert_gt(float(n), 2.0, ">= 3 equip Sigillati di esempio")


func test_indossare_un_sigillato_fa_salire_la_follia_nel_tempo() -> void:
	var p: Node2D = _giocatore_finto()
	var eq: Node = _n("/root/Equipment")
	var madness: Node = _n("/root/Madness")
	var f0: float = madness.call("valore")
	eq.call("equipaggia", _prima_istanza("lama_del_pentimento"))   # follia_al_secondo: 0.4
	eq.call("tick_effetti_collaterali", 2.0)
	var f1: float = madness.call("valore")
	assert_almost_eq(f1, f0 + 0.8, "0.4/s * 2s = 0.8 di follia in piu'")
	eq.call("pulisci")
	p.free()


func test_smontare_ferma_il_tick() -> void:
	var p: Node2D = _giocatore_finto()
	var eq: Node = _n("/root/Equipment")
	var madness: Node = _n("/root/Madness")
	eq.call("equipaggia", _prima_istanza("lama_del_pentimento"))
	eq.call("rimuovi_slot", "arma")
	var f0: float = madness.call("valore")
	eq.call("tick_effetti_collaterali", 5.0)
	var f1: float = madness.call("valore")
	assert_almost_eq(f1, f0, "smontato: nessun tick, la follia non si muove")
	eq.call("pulisci")
	p.free()


func test_drain_spiritualita_al_secondo() -> void:
	var p: Node2D = _giocatore_finto()
	var stats: Node = p.get_node("StatsComponent")
	var eq: Node = _n("/root/Equipment")
	var spir0: float = stats.call("get_stat", "spiritualita_max")   # premessa: c'e' capienza
	stats.set("spiritualita", spir0)
	eq.call("equipaggia", _prima_istanza("manopola_del_divoratore"))   # drain 0.3/s
	eq.call("tick_effetti_collaterali", 2.0)
	assert_almost_eq(float(stats.get("spiritualita")), spir0 - 0.6, "0.3/s * 2s = 0.6 drenati")
	eq.call("pulisci")
	p.free()


func test_tag_grant_collaterale_conta_in_tag_attivi() -> void:
	var p: Node2D = _giocatore_finto()
	var eq: Node = _n("/root/Equipment")
	eq.call("equipaggia", _prima_istanza("corona_dell_assedio"))   # effetto_collaterale: tag_grant "provocazione"
	assert_true((eq.call("tag_attivi") as Dictionary).has("provocazione"),
		"il tag_grant dell'effetto_collaterale conta, sempre indossato")
	eq.call("pulisci")
	p.free()
