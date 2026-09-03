extends "res://tests/test_case.gd"
## US-313 — ricette leggendarie: si imparano leggendo una pergamena.

const StatsComponent := preload("res://scripts/stats_component.gd")


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/Inventory") != null:
		_n("/root/Inventory").call("pulisci")
	if _n("/root/KnowledgeStore") != null:
		_n("/root/KnowledgeStore").call("dimentica_tutto")


func _istanza(item_id: String) -> String:
	var inv: Node = _n("/root/Inventory")
	inv.call("aggiungi", item_id, 1)
	for v in inv.call("per_categoria", "pergamena"):
		if str((v as Dictionary).get("item_id")) == item_id:
			return str((v as Dictionary).get("instance_id"))
	return ""


func test_leggendaria_ignota_non_si_prepara() -> void:
	var ps: Node = _n("/root/PotionSystem")
	assert_false(ps.call("ricetta_nota", "ric_ambrosia"), "leggendaria: ignota di default")
	# fornisci gli ingredienti comunque
	var gd: Node = _n("/root/GameData")
	for ing in (gd.call("get_recipe", "ric_ambrosia").get("ingredienti", {}) as Dictionary):
		_n("/root/Inventory").call("aggiungi", ing, 9)
	assert_eq(ps.call("prepara", "ric_ambrosia").get("reason"), "ricetta_ignota",
		"senza il flag non si prepara nemmeno con gli ingredienti")


func test_la_pergamena_insegna_la_ricetta() -> void:
	var inv: Node = _n("/root/Inventory")
	var ps: Node = _n("/root/PotionSystem")
	var iid: String = _istanza("pergamena_ambrosia")
	var r: Dictionary = inv.call("usa", iid)
	assert_true(r.get("ok", false), "la pergamena si usa")
	assert_eq(r.get("risultato", {}).get("ricetta_appresa"), "ric_ambrosia", "insegna la ricetta")
	assert_eq(inv.call("conta", "pergamena_ambrosia"), 0, "e si consuma")
	assert_true(ps.call("ricetta_nota", "ric_ambrosia"), "ora la ricetta e' nota")
	assert_true(bool(_n("/root/KnowledgeStore").call("conosce", "ricetta:ric_ambrosia")), "flag impostato")


func test_dopo_averla_appresa_si_prepara() -> void:
	var inv: Node = _n("/root/Inventory")
	var ps: Node = _n("/root/PotionSystem")
	inv.call("usa", _istanza("pergamena_ambrosia"))
	var gd: Node = _n("/root/GameData")
	for ing in (gd.call("get_recipe", "ric_ambrosia").get("ingredienti", {}) as Dictionary):
		inv.call("aggiungi", ing, int(gd.call("get_recipe", "ric_ambrosia")["ingredienti"][ing]))
	assert_true(ps.call("prepara", "ric_ambrosia").get("ok", false), "la leggendaria appresa si prepara")
	assert_eq(inv.call("conta", "ambrosia"), 1, "e produce l'ambrosia")
