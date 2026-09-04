extends "res://tests/test_case.gd"
## US-327 — le stanze alimentano i loro sistemi: nessun if di caso speciale,
## solo BaseSystem.bonus(tipo) letto per chiave.


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/BaseSystem") != null:
		_n("/root/BaseSystem").call("pulisci")
	if _n("/root/Inventory") != null:
		_n("/root/Inventory").call("pulisci")
	if _n("/root/KnowledgeStore") != null:
		_n("/root/KnowledgeStore").call("dimentica_tutto")


func _costruisci(tipo: String) -> void:
	var bs: Node = _n("/root/BaseSystem")
	var inv: Node = _n("/root/Inventory")
	var costo: Dictionary = bs.call("prossimo_costo", tipo)
	for item_id in costo:
		inv.call("aggiungi", item_id, int(costo[item_id]))
	bs.call("costruisci", tipo)


func _potenzia(tipo: String) -> void:
	var bs: Node = _n("/root/BaseSystem")
	var inv: Node = _n("/root/Inventory")
	var costo: Dictionary = bs.call("prossimo_costo", tipo)
	for item_id in costo:
		inv.call("aggiungi", item_id, int(costo[item_id]))
	bs.call("potenzia", tipo)


func test_laboratorio_alza_la_qualita_delle_pozioni() -> void:
	var ps: Node = _n("/root/PotionSystem")
	var inv: Node = _n("/root/Inventory")
	_costruisci("laboratorio")   # bonus qualita_pozione: 1

	var gd: Node = _n("/root/GameData")
	for ing in (gd.call("get_recipe", "ric_cura_minore").get("ingredienti", {}) as Dictionary):
		inv.call("aggiungi", ing, int(gd.call("get_recipe", "ric_cura_minore")["ingredienti"][ing]))
	var r: Dictionary = ps.call("prepara", "ric_cura_minore")
	assert_true(r.get("ok", false), "prepara riesce: %s" % r.get("reason"))
	assert_eq(r.get("qualita"), "eccelsa", "qualita_base 'pura' + bonus 1 = 'eccelsa' sulla scala")


func test_senza_laboratorio_qualita_base_invariata() -> void:
	var ps: Node = _n("/root/PotionSystem")
	var inv: Node = _n("/root/Inventory")
	var gd: Node = _n("/root/GameData")
	for ing in (gd.call("get_recipe", "ric_cura_minore").get("ingredienti", {}) as Dictionary):
		inv.call("aggiungi", ing, int(gd.call("get_recipe", "ric_cura_minore")["ingredienti"][ing]))
	var r: Dictionary = ps.call("prepara", "ric_cura_minore")
	assert_eq(r.get("qualita"), "pura", "senza laboratorio: qualita_base della ricetta, nessun bonus")


func test_laboratorio_riduce_il_peso_degli_esiti_mostruosi() -> void:
	var ps: Node = _n("/root/PotionSystem")
	var inv: Node = _n("/root/Inventory")
	var mostruosi := ["ustione", "contaminazione", "aberrazione"]

	# senza laboratorio: peso pieno
	var senza := 0
	ps.call("imposta_seed", 7)
	for i in 300:
		inv.call("aggiungi", "polvere_ossa", 1)
		var e: String = str(ps.call("sperimenta", ["polvere_ossa"]).get("esito"))
		if e in mostruosi:
			senza += 1

	# livello 2 (rischio_esperimento: 40%) riduce il peso mostruoso
	_costruisci("laboratorio")
	_potenzia("laboratorio")
	var con := 0
	ps.call("imposta_seed", 7)
	for i in 300:
		inv.call("aggiungi", "polvere_ossa", 1)
		var e2: String = str(ps.call("sperimenta", ["polvere_ossa"]).get("esito"))
		if e2 in mostruosi:
			con += 1

	assert_gt(float(senza), float(con), "col laboratorio gli esiti mostruosi sono meno frequenti (%d vs %d)" % [senza, con])


func test_stanza_rituale_alza_la_qualita_della_forgiatura() -> void:
	var forge: Node = _n("/root/Forge")
	var inv: Node = _n("/root/Inventory")
	_costruisci("stanza_rituale")   # bonus qualita_forgia: 1
	inv.call("aggiungi", "lingotto_ferro", 3)
	var r: Dictionary = forge.call("forgia", "bp_spada_ferrea")
	assert_true(r.get("ok", false), "forgia riesce: %s" % r.get("reason"))
	assert_eq(r.get("qualita"), "eccelsa", "qualita_base 'pura' + bonus 1 = 'eccelsa'")


func test_biblioteca_rende_nota_una_ricetta_avanzata_senza_sperimentare() -> void:
	var ps: Node = _n("/root/PotionSystem")
	assert_false(ps.call("ricetta_nota", "ric_cura_maggiore"), "avanzata, ignota senza biblioteca")
	_costruisci("biblioteca")
	_potenzia("biblioteca")   # livello 2: ricette_note ha ric_cura_maggiore
	assert_true(ps.call("ricetta_nota", "ric_cura_maggiore"),
		"la biblioteca la rende nota, senza flag KnowledgeStore")
