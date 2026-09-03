extends "res://tests/test_case.gd"
## US-305 — la valuta e' un item come ogni altro (design-master cap. 5).


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func _inv() -> Node:
	return _n("/root/Inventory")


func prepara() -> void:
	if _inv() != null:
		_inv().call("pulisci")


func test_la_valuta_e_categoria_valuta() -> void:
	var gd: Node = _n("/root/GameData")
	var m: Dictionary = gd.call("get_item", "moneta_comune")
	assert_eq(m.get("categoria"), "valuta", "moneta_comune e' categoria:valuta")
	assert_true(bool(m.get("impilabile")), "impilabile")
	assert_eq(m.get("valore"), 1, "valore 1")


func test_si_maneggia_come_ogni_item() -> void:
	var inv: Node = _inv()
	inv.call("aggiungi", "moneta_comune", 50)
	assert_eq(inv.call("conta", "moneta_comune"), 50, "conta come ogni stack")
	assert_true(inv.call("rimuovi", "moneta_comune", 20), "rimuove come ogni stack")
	assert_eq(inv.call("conta", "moneta_comune"), 30, "restano 30")
	var voci: Array = inv.call("per_categoria", "valuta")
	assert_gt(float(voci.size()), 0.0, "compare in per_categoria('valuta')")


func test_ricchezza_somma_tutte_le_valute() -> void:
	var inv: Node = _inv()
	assert_eq(inv.call("ricchezza"), 0, "a mani vuote la ricchezza e' 0")
	inv.call("aggiungi", "moneta_comune", 30)   # valore 1
	inv.call("aggiungi", "sigillo_reale", 4)    # valore 50
	assert_eq(inv.call("ricchezza"), 230, "30*1 + 4*50 = 230")
