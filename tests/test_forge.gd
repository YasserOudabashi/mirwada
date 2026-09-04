extends "res://tests/test_case.gd"
## US-316 — forgiatura dell'equipaggiamento.


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


func _inv() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Inventory")


func _forge() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Forge")


func prepara() -> void:
	_inv().call("pulisci")


func test_forgia_con_materiali_produce_equip() -> void:
	var inv: Node = _inv()
	inv.call("aggiungi", "lingotto_ferro", 3)
	var r: Dictionary = _forge().call("forgia", "bp_spada_ferrea")
	assert_true(bool(r.get("ok")), "forgia riesce con i materiali giusti")
	assert_eq(r.get("item_id"), "spada_ferrea", "produce l'output del blueprint")
	assert_false(str(r.get("instance_id", "")).is_empty(), "restituisce l'instance_id creato")
	assert_true(inv.call("istanza", r.get("instance_id")).size() > 0, "l'istanza e' davvero in inventario")
	assert_eq(inv.call("conta", "lingotto_ferro"), 0, "i materiali sono stati consumati")


func test_materiali_mancanti_rifiuta_senza_consumo() -> void:
	var inv: Node = _inv()
	inv.call("aggiungi", "lingotto_ferro", 1)   # ne servono 3
	var r: Dictionary = _forge().call("forgia", "bp_spada_ferrea")
	assert_false(bool(r.get("ok")), "rifiutato senza abbastanza materiali")
	assert_eq(r.get("reason"), "materiali_mancanti", "motivo esplicito")
	assert_eq(inv.call("conta", "lingotto_ferro"), 1, "nessun materiale consumato sul rifiuto")


func test_blueprint_inesistente_gestito() -> void:
	var r: Dictionary = _forge().call("forgia", "bp_che_non_esiste")
	assert_false(bool(r.get("ok")), "blueprint ignoto -> gestito, non crash")
	assert_eq(r.get("reason"), "blueprint_inesistente", "motivo esplicito")


func test_equip_forgiato_ha_i_tag_del_blueprint() -> void:
	var gd: Node = _gd()
	var inv: Node = _inv()
	inv.call("aggiungi", "lingotto_ferro", 3)
	var r: Dictionary = _forge().call("forgia", "bp_spada_ferrea")
	var def: Dictionary = gd.call("get_item", r.get("item_id"))
	assert_true((def.get("tag", []) as Array).size() > 0, "l'output ha dei tag (contano una volta equipaggiato)")


func test_qualita_e_quella_di_base_senza_stanza_ne_talenti() -> void:
	# BaseSystem/TalentSystem non esistono ancora (US-326/331): il bonus e'
	# 0 e la qualita' resta quella dichiarata dal blueprint. Stessa scelta
	# documentata per PotionSystem (US-310).
	var inv: Node = _inv()
	inv.call("aggiungi", "lingotto_ferro", 3)
	var r: Dictionary = _forge().call("forgia", "bp_spada_ferrea")
	assert_eq(r.get("qualita"), "pura", "qualita' = qualita_base del blueprint")


func test_ogni_blueprint_e_ben_formato() -> void:
	var gd: Node = _gd()
	for bid in gd.call("blueprint_ids"):
		var bp: Dictionary = gd.call("get_blueprint", bid)
		assert_false(gd.call("get_item", bp.get("output", {}).get("item_id", "")).is_empty(),
			"%s: output risolve" % bid)
