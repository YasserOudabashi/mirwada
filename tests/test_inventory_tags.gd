extends "res://tests/test_case.gd"
## US-306 — i tag di cio' che si porta addosso, esposti per il motore
## sinergie di fase 4.

const StatsComponent := preload("res://scripts/stats_component.gd")


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/Equipment") != null:
		_n("/root/Equipment").call("pulisci")
	if _n("/root/Inventory") != null:
		_n("/root/Inventory").call("pulisci")


func _giocatore_finto() -> Node2D:
	var p := Node2D.new()
	p.add_to_group("player")
	var st: Node = StatsComponent.new()
	st.name = "StatsComponent"
	st.call("configure_from_balance", 9)
	p.add_child(st)
	Engine.get_main_loop().root.add_child(p)
	return p


func _equipaggia(item_id: String) -> void:
	var inv: Node = _n("/root/Inventory")
	inv.call("aggiungi", item_id, 1)
	for v in inv.call("per_categoria", "equip"):
		if str((v as Dictionary).get("item_id")) == item_id and not str((v as Dictionary).get("item_id")) in _n("/root/Equipment").call("slot_pieni").values():
			_n("/root/Equipment").call("equipaggia", str((v as Dictionary).get("instance_id")))
			return


func test_solo_l_equip_indossato_conta() -> void:
	var p: Node2D = _giocatore_finto()
	var inv: Node = _n("/root/Inventory")
	# spada_ferrea ha tag ["arma", "forza"]; nello zaino NON deve contare
	inv.call("aggiungi", "spada_ferrea", 1)
	assert_eq(inv.call("tag_attivi"), {}, "un equip nello zaino non produce tag")
	# equipaggiata, i suoi tag compaiono
	for v in inv.call("per_categoria", "equip"):
		_n("/root/Equipment").call("equipaggia", str((v as Dictionary).get("instance_id")))
	var t: Dictionary = inv.call("tag_attivi")
	assert_eq(int(t.get("arma", 0)), 1, "tag 'arma' dall'equip indossato")
	assert_eq(int(t.get("forza", 0)), 1, "tag 'forza' dall'equip indossato")
	_n("/root/Equipment").call("pulisci")
	p.free()


func test_due_equip_con_tag_condiviso_sommano() -> void:
	var p: Node2D = _giocatore_finto()
	var inv: Node = _n("/root/Inventory")
	var eq: Node = _n("/root/Equipment")
	# spada_ferrea [arma, forza, guerra] su 'arma' + corazza_cuoio [difesa, guerra] su 'armatura'
	for item in ["spada_ferrea", "corazza_cuoio"]:
		inv.call("aggiungi", item, 1)
	for v in inv.call("per_categoria", "equip"):
		eq.call("equipaggia", str((v as Dictionary).get("instance_id")))
	assert_eq(int((inv.call("tag_attivi") as Dictionary).get("guerra", 0)), 2,
		"il tag 'guerra' condiviso da due equip su slot diversi -> conteggio 2")
	eq.call("rimuovi_slot", "armatura")
	assert_eq(int((inv.call("tag_attivi") as Dictionary).get("guerra", 0)), 1,
		"smontare un equip aggiorna il conteggio")
	eq.call("pulisci")
	p.free()
