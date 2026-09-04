extends "res://tests/test_case.gd"
## US-331 — gli emettitori reali agganciati ai sistemi esistenti (non il
## meccanismo generico di sblocco, gia' coperto da test_talent_system.gd).

const StatsComponent := preload("res://scripts/stats_component.gd")


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	for a in ["/root/Inventory", "/root/BaseSystem", "/root/Equipment"]:
		if _n(a) != null:
			_n(a).call("pulisci")
	if _n("/root/TalentTracker") != null:
		_n("/root/TalentTracker").call("azzera")
	if _n("/root/EventTracker") != null:
		_n("/root/EventTracker").call("azzera")
	if _n("/root/KnowledgeStore") != null:
		_n("/root/KnowledgeStore").call("dimentica_tutto")


func test_prepara_una_pozione_traccia_item_crafted() -> void:
	var ps: Node = _n("/root/PotionSystem")
	var inv: Node = _n("/root/Inventory")
	var gd: Node = _n("/root/GameData")
	for ing in (gd.call("get_recipe", "ric_cura_minore").get("ingredienti", {}) as Dictionary):
		inv.call("aggiungi", ing, int(gd.call("get_recipe", "ric_cura_minore")["ingredienti"][ing]))
	ps.call("prepara", "ric_cura_minore")
	assert_almost_eq(_n("/root/EventTracker").call("count", "item_crafted", {}), 1.0,
		"la preparazione di una pozione traccia item_crafted")


func test_forgiare_traccia_item_crafted() -> void:
	var forge: Node = _n("/root/Forge")
	var inv: Node = _n("/root/Inventory")
	inv.call("aggiungi", "lingotto_ferro", 3)
	forge.call("forgia", "bp_spada_ferrea")
	assert_almost_eq(_n("/root/EventTracker").call("count", "item_crafted", {}), 1.0,
		"forgiare un equip traccia item_crafted")


func test_raccogliere_dal_giardino_traccia_ingredienti_coltivati() -> void:
	var bs: Node = _n("/root/BaseSystem")
	var inv: Node = _n("/root/Inventory")
	var costo: Dictionary = bs.call("prossimo_costo", "giardino")
	for item_id in costo:
		inv.call("aggiungi", item_id, int(costo[item_id]))
	bs.call("costruisci", "giardino")
	inv.call("aggiungi", "erba_lunare", 1)
	var idx: int = bs.call("pianta", "erba_lunare")
	_n("/root/GameState").set("tempo_gioco", 999.0)
	bs.call("raccogli", idx)
	assert_almost_eq(_n("/root/TalentTracker").call("count", "ingredienti_coltivati", {}), 1.0,
		"raccogliere traccia ingredienti_coltivati")


func test_usare_una_pergamena_traccia_abilita_prestate_usate() -> void:
	var inv: Node = _n("/root/Inventory")
	var creati: Array = inv.call("aggiungi", "pergamena_vigore", 1)
	var p := Node2D.new()
	p.add_to_group("player")
	var st: Node = StatsComponent.new()
	st.name = "StatsComponent"
	st.call("configure_from_balance", 9)
	p.add_child(st)
	Engine.get_main_loop().root.add_child(p)

	inv.call("usa", str(creati[0]))
	assert_almost_eq(_n("/root/TalentTracker").call("count", "abilita_prestate_usate", {}), 1.0,
		"usare una pergamena traccia abilita_prestate_usate")
	p.free()
