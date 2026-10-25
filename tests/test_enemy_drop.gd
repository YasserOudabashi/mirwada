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


## US-1104 (fase 11): con piu' di un oggetto in oggetti_a_morte, la scelta
## pesa per rarita' invece di essere uniforme - un comune esce molto piu'
## spesso di un leggendario dalla stessa tabella. Non chiama _uccidi/pickup
## (che consuma un frame reale per estrazione, troppo lento per centinaia di
## prove): chiama direttamente enemy._scegli_drop_pesato in un ciclo, stesso
## principio statistico, tempo di esecuzione trascurabile.
func test_us1104_il_drop_pesa_per_rarita() -> void:
	var gd: Node = _root().get_node("GameData")
	var comune_id := ""
	var leggendario_id := ""
	for cat in (gd.call("item_categories") as Array):
		for it in (gd.call("items_per_categoria", str(cat)) as Array):
			var item: Dictionary = it as Dictionary
			var r: String = str(item.get("rarita", "comune"))
			if r == "comune" and comune_id.is_empty():
				comune_id = str(item.get("id", ""))
			elif r == "leggendario" and leggendario_id.is_empty():
				leggendario_id = str(item.get("id", ""))
	assert_false(comune_id.is_empty(), "esiste almeno un item comune")
	assert_false(leggendario_id.is_empty(), "esiste almeno un item leggendario")

	var enemy: Node = EnemyScene.instantiate()
	_root().add_child(enemy)
	var oggetti: Array = [comune_id, leggendario_id]
	var conteggio_comune := 0
	const PROVE := 400
	for _i in PROVE:
		if str(enemy.call("_scegli_drop_pesato", oggetti)) == comune_id:
			conteggio_comune += 1
	# peso_drop: comune=100, leggendario=1 (data/schema/item_rarity.json) ->
	# il comune ci si aspetta ~99% delle volte. Tolleranza larga (>80%) per
	# non rendere il test instabile pur restando una prova statistica vera.
	assert_true(conteggio_comune > PROVE * 0.8,
		"il comune esce nettamente piu' spesso del leggendario (%d/%d)" % [conteggio_comune, PROVE])
	_root().remove_child(enemy)
	enemy.free()
