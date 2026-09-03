extends "res://tests/test_case.gd"
## US-311 — sperimentazione: combini ingredienti e a volte scopri una ricetta.

const StatsComponent := preload("res://scripts/stats_component.gd")


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/Inventory") != null:
		_n("/root/Inventory").call("pulisci")
	if _n("/root/KnowledgeStore") != null:
		_n("/root/KnowledgeStore").call("dimentica_tutto")
	if _n("/root/Madness") != null:
		_n("/root/Madness").call("da_salvataggio", {})
	if _n("/root/Foundation") != null:
		_n("/root/Foundation").call("da_salvataggio", {})


func _combo_di(recipe_id: String) -> Array:
	var gd: Node = _n("/root/GameData")
	var out: Array = []
	for ing in (gd.call("get_recipe", recipe_id).get("ingredienti", {}) as Dictionary):
		var q: int = int(gd.call("get_recipe", recipe_id)["ingredienti"][ing])
		for i in q:
			out.append(ing)
	return out


func _fornisci(combo: Array) -> void:
	var inv: Node = _n("/root/Inventory")
	for x in combo:
		inv.call("aggiungi", str(x), 1)


func test_combo_di_una_avanzata_la_scopre() -> void:
	var ps: Node = _n("/root/PotionSystem")
	var combo: Array = _combo_di("ric_elisir_ombra")   # avanzata
	_fornisci(combo)
	var r: Dictionary = ps.call("sperimenta", combo)
	assert_eq(r.get("esito"), "scoperta", "la combinazione giusta scopre la ricetta")
	assert_eq(r.get("recipe_id"), "ric_elisir_ombra", "quella ricetta")
	assert_true(bool(_n("/root/KnowledgeStore").call("conosce", "ricetta:ric_elisir_ombra")),
		"il flag KnowledgeStore e' impostato")
	assert_eq(_n("/root/Inventory").call("conta", "elisir_ombra"), 1, "la pozione e' prodotta")
	assert_eq(_n("/root/Inventory").call("conta", "radice_crepuscolo"), 0, "ingredienti consumati")


func test_combo_ignota_e_un_fallimento_deterministico() -> void:
	var ps: Node = _n("/root/PotionSystem")
	var inv: Node = _n("/root/Inventory")
	inv.call("aggiungi", "polvere_ossa", 2)
	ps.call("imposta_seed", 12345)
	var r1: Dictionary = ps.call("sperimenta", ["polvere_ossa", "polvere_ossa"])
	assert_true(r1.get("ok", false) and r1.get("esito") in _n("/root/GameData").call("experiment_outcomes").keys(),
		"combinazione ignota -> un esito del vocabolario chiuso")
	assert_eq(inv.call("conta", "polvere_ossa"), 0, "gli ingredienti si consumano anche sul fallimento")
	# stesso seed, stessa combo -> stesso esito
	inv.call("aggiungi", "polvere_ossa", 2)
	ps.call("imposta_seed", 12345)
	var r2: Dictionary = ps.call("sperimenta", ["polvere_ossa", "polvere_ossa"])
	assert_eq(r2.get("esito"), r1.get("esito"), "RNG seedabile: esito riproducibile")


func test_ingredienti_mancanti_non_consuma() -> void:
	var ps: Node = _n("/root/PotionSystem")
	var inv: Node = _n("/root/Inventory")
	inv.call("aggiungi", "erba_lunare", 1)
	var r: Dictionary = ps.call("sperimenta", ["erba_lunare", "erba_lunare"])
	assert_eq(r.get("esito"), "ingredienti_mancanti", "senza abbastanza ingredienti -> rifiuto")
	assert_eq(inv.call("conta", "erba_lunare"), 1, "e non consuma nulla")


func test_follia_alta_aumenta_gli_esiti_mostruosi() -> void:
	var ps: Node = _n("/root/PotionSystem")
	var mostruosi := ["ustione", "contaminazione", "aberrazione"]

	# follia bassa / fondamenta piene
	var m_basso := 0
	ps.call("imposta_seed", 1)
	for i in 300:
		_n("/root/Inventory").call("aggiungi", "polvere_ossa", 1)
		var e: String = str(ps.call("sperimenta", ["polvere_ossa"]).get("esito"))
		if e in mostruosi:
			m_basso += 1

	# follia alta / fondamenta a zero -> moltiplicatore ~2.5
	_n("/root/Foundation").call("applica", -100.0, "test")
	var m_alto := 0
	ps.call("imposta_seed", 1)
	for i in 300:
		_n("/root/Inventory").call("aggiungi", "polvere_ossa", 1)
		var e2: String = str(ps.call("sperimenta", ["polvere_ossa"]).get("esito"))
		if e2 in mostruosi:
			m_alto += 1

	assert_gt(float(m_alto), float(m_basso), "con la follia alta gli esiti mostruosi sono piu' frequenti (%d vs %d)" % [m_alto, m_basso])
