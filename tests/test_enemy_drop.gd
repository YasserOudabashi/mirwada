extends "res://tests/test_case.gd"
## US-809a — drop degli item alla morte dei nemici (enemy.gd::_lascia_oggetto).

const EnemyScene := preload("res://scenes/enemy.tscn")
const ItemPickup := preload("res://scripts/item_pickup.gd")


func _root() -> Node:
	return Engine.get_main_loop().root


func _uccidi(enemy: Node) -> void:
	_root().add_child(enemy)
	await Engine.get_main_loop().process_frame
	enemy.get_node("StatsComponent").set("hp", 0.0)  # -> died -> _su_morte
	await Engine.get_main_loop().process_frame


func _pickup_item(item_id: String) -> Node:
	for n in _root().get_children():
		if n.get_script() == ItemPickup and str(n.get("char_id")) == item_id:
			return n
	return null


func test_drop_probabilita_1_lascia_sempre_l_item() -> void:
	var enemy: Node = EnemyScene.instantiate()
	enemy.set("override", {
		"oggetti_a_morte": ["erba_lunare"],
		"drop_probabilita": 1.0,
	})
	await _uccidi(enemy)

	var pickup: Node = _pickup_item("erba_lunare")
	assert_true(pickup != null, "item a terra (drop garantito, probabilita 1.0)")

	if pickup != null:
		assert_true(pickup.call("raccogli"), "raccolta")
		assert_false(pickup.call("raccogli"), "non si raccoglie due volte")
	_root().remove_child(enemy)
	enemy.free()


func test_drop_probabilita_0_non_lascia_niente() -> void:
	var enemy: Node = EnemyScene.instantiate()
	enemy.set("override", {
		"oggetti_a_morte": ["erba_lunare"],
		"drop_probabilita": 0.0,
	})
	await _uccidi(enemy)

	assert_true(_pickup_item("erba_lunare") == null, "nessun drop con probabilita 0")
	_root().remove_child(enemy)
	enemy.free()


func test_oggetti_a_morte_vuoto_non_lascia_niente() -> void:
	var enemy: Node = EnemyScene.instantiate()
	# override di default (nessun layout): oggetti_a_morte assente.
	await _uccidi(enemy)

	var trovato := false
	for n in _root().get_children():
		if n.get_script() == ItemPickup:
			trovato = true
	assert_false(trovato, "il nemico da banco di prova non lascia oggetti")
	_root().remove_child(enemy)
	enemy.free()
