extends "res://tests/test_case.gd"
## US-302 — autoload Inventory: magazzino unico, serializzato.


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func _inv() -> Node:
	return _n("/root/Inventory")


func prepara() -> void:
	if _inv() != null:
		_inv().call("pulisci")


func test_stackable_aggiungi_conta_rimuovi() -> void:
	var inv: Node = _inv()
	inv.call("aggiungi", "erba_lunare", 5)
	assert_eq(inv.call("conta", "erba_lunare"), 5, "impilabile: contatore")
	assert_true(inv.call("rimuovi", "erba_lunare", 2), "rimuove 2")
	assert_eq(inv.call("conta", "erba_lunare"), 3, "restano 3")
	assert_false(inv.call("rimuovi", "erba_lunare", 99), "rimozione oltre il posseduto -> false")
	assert_eq(inv.call("conta", "erba_lunare"), 3, "e non rimuove nulla")


func test_non_stackable_sono_istanze_distinte() -> void:
	var inv: Node = _inv()
	inv.call("aggiungi", "spada_ferrea", 2)
	assert_eq(inv.call("conta", "spada_ferrea"), 2, "due spade = due istanze")
	var voci: Array = inv.call("per_categoria", "equip")
	var ids: Array = []
	for v in voci:
		if str((v as Dictionary).get("item_id")) == "spada_ferrea":
			ids.append((v as Dictionary).get("instance_id"))
	assert_eq(ids.size(), 2, "due instance_id")
	assert_ne(ids[0], ids[1], "instance_id distinti")
	assert_true(inv.call("rimuovi_istanza", ids[0]), "rimuove per instance_id")
	assert_eq(inv.call("conta", "spada_ferrea"), 1, "ne resta una")


func test_item_ignoto_non_esplode() -> void:
	var inv: Node = _inv()
	inv.call("aggiungi", "item_che_non_esiste", 3)
	assert_eq(inv.call("conta", "item_che_non_esiste"), 0, "item ignoto -> non aggiunto, nessun crash")


func test_segnali() -> void:
	var inv: Node = _inv()
	var visti: Dictionary = {"add": 0, "rem": 0}
	var a := func(_id: String, _q: int) -> void: visti["add"] += 1
	var r := func(_id: String, _q: int) -> void: visti["rem"] += 1
	inv.item_aggiunto.connect(a)
	inv.item_rimosso.connect(r)
	inv.call("aggiungi", "moneta_comune", 10)
	inv.call("rimuovi", "moneta_comune", 4)
	assert_eq(visti["add"], 1, "un item_aggiunto")
	assert_eq(visti["rem"], 1, "un item_rimosso")
	inv.item_aggiunto.disconnect(a)
	inv.item_rimosso.disconnect(r)


func test_ricchezza() -> void:
	var inv: Node = _inv()
	inv.call("aggiungi", "moneta_comune", 30)   # valore 1
	inv.call("aggiungi", "sigillo_reale", 2)    # valore 50
	assert_eq(inv.call("ricchezza"), 130, "30*1 + 2*50")


func test_round_trip_del_save() -> void:
	var inv: Node = _inv()
	var gs: Node = _n("/root/GameState")
	inv.call("aggiungi", "erba_lunare", 4)
	inv.call("aggiungi", "spada_ferrea", 1)
	var snap: Dictionary = gs.call("snapshot")
	inv.call("pulisci")
	assert_eq(inv.call("conta", "erba_lunare"), 0, "svuotato")
	gs.call("applica", snap)
	assert_eq(inv.call("conta", "erba_lunare"), 4, "stack ripristinato")
	assert_eq(inv.call("conta", "spada_ferrea"), 1, "istanza ripristinata")


func test_da_salvataggio_non_fidato() -> void:
	var inv: Node = _inv()
	inv.call("da_salvataggio", "non un oggetto")
	assert_eq(inv.call("tutto").get("stack"), {}, "raw non-oggetto -> inventario vuoto")
	inv.call("da_salvataggio", {"stack": {"erba_lunare": 3, "item_falso": 9, "radice_crepuscolo": -1}})
	assert_eq(inv.call("conta", "erba_lunare"), 3, "voce buona tenuta")
	assert_eq(inv.call("conta", "item_falso"), 0, "item_id che non risolve scartato")
	assert_eq(inv.call("conta", "radice_crepuscolo"), 0, "quantita' non positiva scartata")
