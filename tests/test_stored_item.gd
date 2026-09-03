extends "res://tests/test_case.gd"
## US-304 — stored_ability_id: usare una pergamena esegue l'abilita' e consuma
## l'item (contratto P0, motore gia' pronto: AbilityEngine.execute_stored).

const StatsComponent := preload("res://scripts/stats_component.gd")


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/Inventory") != null:
		_n("/root/Inventory").call("pulisci")


func _giocatore_finto() -> Node2D:
	var p := Node2D.new()
	p.add_to_group("player")
	var stats: Node = StatsComponent.new()
	stats.name = "StatsComponent"
	stats.call("configure_from_balance", 9)
	p.add_child(stats)
	Engine.get_main_loop().root.add_child(p)
	return p


func _istanza(item_id: String) -> String:
	var inv: Node = _n("/root/Inventory")
	inv.call("aggiungi", item_id, 1)
	for v in inv.call("per_categoria", "pergamena") + inv.call("per_categoria", "equip"):
		if str((v as Dictionary).get("item_id")) == item_id:
			return str((v as Dictionary).get("instance_id"))
	return ""


func test_usa_pergamena_esegue_e_consuma() -> void:
	var p: Node2D = _giocatore_finto()
	var inv: Node = _n("/root/Inventory")
	var iid: String = _istanza("pergamena_vigore")   # stored: tg_stretta_ferrea (buff_stat)
	var r: Dictionary = inv.call("usa", iid)
	assert_true(r.get("ok", false), "usa() riesce: %s" % r.get("reason"))
	assert_true(bool(r.get("risultato", {}).get("ok", false)), "l'abilita' e' stata eseguita")
	assert_eq(inv.call("conta", "pergamena_vigore"), 0, "la pergamena e' consumata (1 uso)")
	p.free()


func test_seconda_usa_sulla_stessa_istanza_e_rifiutata() -> void:
	var p: Node2D = _giocatore_finto()
	var inv: Node = _n("/root/Inventory")
	var iid: String = _istanza("pergamena_vigore")
	inv.call("usa", iid)
	var r2: Dictionary = inv.call("usa", iid)
	assert_false(r2.get("ok", true), "l'istanza consumata non si riusa")
	assert_eq(r2.get("reason"), "istanza_assente", "esito gestito, non crash")
	p.free()


func test_item_senza_abilita_e_gestito() -> void:
	var p: Node2D = _giocatore_finto()
	var inv: Node = _n("/root/Inventory")
	var iid: String = _istanza("spada_ferrea")   # equip, niente stored_ability_id
	var r: Dictionary = inv.call("usa", iid)
	assert_false(r.get("ok", true), "un item senza stored_ability_id non si 'usa'")
	assert_eq(r.get("reason"), "nessuna_abilita", "esito gestito")
	assert_eq(inv.call("conta", "spada_ferrea"), 1, "e non viene consumato")
	p.free()


func test_pergamena_hermit_risolve_il_contratto() -> void:
	var p: Node2D = _giocatore_finto()
	var inv: Node = _n("/root/Inventory")
	var iid: String = _istanza("pergamena_hermit")   # stored: hermit_pergamena (reveal_info, non-impl)
	var r: Dictionary = inv.call("usa", iid)
	assert_true(r.get("ok", false), "la pergamena dell'eremita si usa (l'item funziona anche se il VFX arrivera' in fase 5)")
	assert_eq(inv.call("conta", "pergamena_hermit"), 0, "consumata")
	p.free()
