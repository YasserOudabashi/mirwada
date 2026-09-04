extends "res://tests/test_case.gd"
## US-316 — forgiatura: combina materiali per forgiare un pezzo di equip.


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/Inventory") != null:
		_n("/root/Inventory").call("pulisci")
	if _n("/root/KnowledgeStore") != null:
		_n("/root/KnowledgeStore").call("dimentica_tutto")


func _fornisci(blueprint_id: String) -> void:
	var gd: Node = _n("/root/GameData")
	var inv: Node = _n("/root/Inventory")
	var mat: Dictionary = gd.call("get_blueprint", blueprint_id).get("materiali", {})
	for m in mat:
		inv.call("aggiungi", m, int(mat[m]))


func test_forgia_con_materiali_produce_equip() -> void:
	var forge: Node = _n("/root/Forge")
	var inv: Node = _n("/root/Inventory")
	_fornisci("bp_spada_ferrea")
	var r: Dictionary = forge.call("forgia", "bp_spada_ferrea")
	assert_true(r.get("ok", false), "forgia riesce: %s" % r.get("reason"))
	assert_eq(r.get("item_id"), "spada_ferrea", "output corretto")
	assert_false(str(r.get("instance_id", "")).is_empty(), "l'equip forgiato ha un'istanza")
	assert_eq(r.get("qualita"), "pura", "qualita' = qualita_base (nessun bonus stanza/talento ancora)")
	assert_eq(inv.call("conta", "spada_ferrea"), 1, "l'equip e' nell'inventario")
	assert_eq(inv.call("conta", "lingotto_ferro"), 0, "i materiali sono stati consumati")


func test_materiali_mancanti_non_consuma() -> void:
	var forge: Node = _n("/root/Forge")
	var inv: Node = _n("/root/Inventory")
	inv.call("aggiungi", "lingotto_ferro", 1)   # ne servono 3
	var r: Dictionary = forge.call("forgia", "bp_spada_ferrea")
	assert_false(r.get("ok", true), "senza tutti i materiali non si forgia")
	assert_eq(r.get("reason"), "materiali_mancanti", "esito gestito")
	assert_eq(inv.call("conta", "lingotto_ferro"), 1, "e non consuma nulla")


func test_blueprint_inesistente() -> void:
	var r: Dictionary = _n("/root/Forge").call("forgia", "bp_falso")
	assert_eq(r.get("reason"), "blueprint_inesistente", "id ignoto gestito, nessun crash")


func test_blueprint_nota() -> void:
	var forge: Node = _n("/root/Forge")
	assert_true(forge.call("blueprint_nota", "bp_spada_ferrea"), "nota_da_subito:true e' sempre forgiabile")
	assert_false(forge.call("blueprint_nota", "bp_inesistente"), "id ignoto -> false")
