extends "res://tests/test_case.gd"
## US-301 — vocabolario e schema degli item.


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


func test_vocabolari_caricati() -> void:
	var gd: Node = _gd()
	assert_eq((gd.call("item_categories") as Array).size(), 7, "7 categorie di item")
	assert_eq((gd.call("equip_slots") as Array).size(), 4, "4 slot di equipaggiamento")
	assert_true((gd.call("equip_slot_tipi") as Array).has("accessorio"), "'accessorio' fra i tipi")


func test_get_item() -> void:
	var gd: Node = _gd()
	var erba: Dictionary = gd.call("get_item", "erba_lunare")
	assert_false(erba.is_empty(), "erba_lunare esiste")
	assert_eq(erba.get("categoria"), "ingrediente", "categoria corretta")
	assert_true(gd.call("get_item", "item_inventato").is_empty(), "id ignoto -> {}")


func test_ogni_categoria_ha_almeno_un_item() -> void:
	var gd: Node = _gd()
	for cat in gd.call("item_categories"):
		assert_gt(float((gd.call("items_per_categoria", cat) as Array).size()), 0.0,
			"almeno un item di categoria '%s'" % cat)


func test_almeno_12_item() -> void:
	assert_gt(float((_gd().call("item_ids") as Array).size()), 11.0, ">= 12 item di esempio")


func test_equip_ha_slot_e_modificatori_validi() -> void:
	var gd: Node = _gd()
	var tipi: Array = gd.call("equip_slot_tipi")
	var note: Array = ["hp_max", "spiritualita_max", "velocita", "difesa", "evasione", "precisione", "forza"]
	for it in gd.call("items_per_categoria", "equip"):
		var d: Dictionary = it
		assert_true(tipi.has(d.get("slot", "")), "%s ha uno slot valido" % d.get("id"))
		for k in (d.get("stat_modifiers", {}) as Dictionary):
			assert_true(note.has(k), "%s: stat '%s' nota" % [d.get("id"), k])


func test_pergamena_ha_stored_ability_che_risolve() -> void:
	var gd: Node = _gd()
	var perg: Array = gd.call("items_per_categoria", "pergamena")
	assert_gt(float(perg.size()), 0.0, "ci sono pergamene")
	for it in perg:
		var d: Dictionary = it
		var aid: String = str(d.get("stored_ability_id", ""))
		var ric: String = str(d.get("insegna_ricetta", ""))
		# una pergamena porta un'abilita' OPPURE insegna una ricetta
		if not aid.is_empty():
			assert_false(gd.call("get_ability", aid).is_empty(),
				"%s: stored_ability_id '%s' risolve" % [d.get("id"), aid])
		else:
			assert_false(ric.is_empty(), "%s: una pergamena ha stored_ability_id o insegna_ricetta" % d.get("id"))


func test_ogni_name_i18n_degli_item_risolve() -> void:
	var gd: Node = _gd()
	var rotte: Array = []
	for iid in gd.call("item_ids"):
		var it: Dictionary = gd.call("get_item", iid)
		for campo in ["name_i18n", "descrizione_i18n"]:
			var k: String = str(it.get(campo, ""))
			if not k.is_empty() and gd.call("tr_data", k) == k and not gd.call("has_translation", k):
				rotte.append(k)
	assert_eq(rotte.size(), 0, "chiavi i18n degli item che non risolvono: %s" % [rotte])
