extends "res://tests/test_case.gd"
## US-317 (fusa con US-309) — incisione dei sigilli sull'equip.

const StatsComponent := preload("res://scripts/stats_component.gd")


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/Equipment") != null:
		_n("/root/Equipment").call("pulisci")
	if _n("/root/Inventory") != null:
		_n("/root/Inventory").call("pulisci")


func _giocatore_finto() -> Node2D:
	var p := Node2D.new()
	p.add_to_group("player")
	var stats: Node = StatsComponent.new()
	stats.name = "StatsComponent"
	stats.call("configure_from_balance", 9)
	p.add_child(stats)
	Engine.get_main_loop().root.add_child(p)
	return p


func _prima_istanza(item_id: String) -> String:
	var creati: Array = _n("/root/Inventory").call("aggiungi", item_id, 1)
	return str(creati[0]) if not creati.is_empty() else ""


func test_incastona_fino_al_limite_poi_rifiuta() -> void:
	var p: Node2D = _giocatore_finto()
	var eq: Node = _n("/root/Equipment")
	# amuleto_lunare ha slot_sigilli: 2.
	eq.call("equipaggia", _prima_istanza("amuleto_lunare"))
	assert_true(eq.call("incastona", "accessorio_1", _prima_istanza("sigillo_forza_minore")),
		"1o sigillo incastonato")
	assert_true(eq.call("incastona", "accessorio_1", _prima_istanza("sigillo_agilita_minore")),
		"2o sigillo incastonato")
	assert_false(eq.call("incastona", "accessorio_1", _prima_istanza("sigillo_vento_minore")),
		"il 3o supera slot_sigilli: rifiutato")
	assert_eq((eq.call("sigilli_incastonati", "accessorio_1") as Array).size(), 2, "solo 2 incastonati")
	eq.call("pulisci")
	p.free()


func test_effetto_e_collaterale_applicati_e_rimossi_con_lequip() -> void:
	var p: Node2D = _giocatore_finto()
	var stats: Node = p.get_node("StatsComponent")
	var eq: Node = _n("/root/Equipment")
	eq.call("equipaggia", _prima_istanza("amuleto_lunare"))
	var evasione0: float = stats.call("get_stat", "evasione")
	var spirmax0: float = stats.call("get_stat", "spiritualita_max")
	var sig_iid: String = _prima_istanza("sigillo_ombra_fame")   # +evasione 0.08, -spiritualita_max 10
	assert_true(eq.call("incastona", "accessorio_1", sig_iid), "incastona ombra_fame")
	assert_true(stats.call("has_modifier", "sigillo:" + sig_iid), "modificatore per id 'sigillo:<instance_id>'")
	assert_almost_eq(stats.call("get_stat", "evasione"), evasione0 + 0.08, "effetto applicato")
	assert_almost_eq(stats.call("get_stat", "spiritualita_max"), spirmax0 - 10.0, "effetto_collaterale applicato")

	assert_true(eq.call("rimuovi_sigillo", "accessorio_1", sig_iid), "estrae il sigillo")
	assert_false(stats.call("has_modifier", "sigillo:" + sig_iid), "modificatore rimosso")
	assert_almost_eq(stats.call("get_stat", "evasione"), evasione0, "effetto tolto")
	assert_almost_eq(stats.call("get_stat", "spiritualita_max"), spirmax0, "effetto_collaterale tolto")
	assert_eq(_n("/root/Inventory").call("conta", "sigillo_ombra_fame"), 1, "il sigillo torna nello zaino")
	eq.call("pulisci")
	p.free()


func test_sigillo_incastonato_conta_nei_tag_attivi() -> void:
	var p: Node2D = _giocatore_finto()
	var eq: Node = _n("/root/Equipment")
	eq.call("equipaggia", _prima_istanza("amuleto_lunare"))
	eq.call("incastona", "accessorio_1", _prima_istanza("sigillo_forza_minore"))
	assert_true((eq.call("tag_attivi") as Dictionary).has("forza"), "il tag del sigillo incastonato conta")
	eq.call("pulisci")
	p.free()


func test_smontare_spegne_il_modificatore_ma_non_dimentica_il_sigillo() -> void:
	var p: Node2D = _giocatore_finto()
	var stats: Node = p.get_node("StatsComponent")
	var eq: Node = _n("/root/Equipment")
	var equip_iid: String = _prima_istanza("amuleto_lunare")
	eq.call("equipaggia", equip_iid)
	var sig_iid: String = _prima_istanza("sigillo_forza_minore")
	eq.call("incastona", "accessorio_1", sig_iid)
	eq.call("rimuovi_slot", "accessorio_1")
	assert_false(stats.call("has_modifier", "sigillo:" + sig_iid), "smontato: il modificatore si spegne")
	# rimonta la STESSA istanza: e' tornata nello zaino con lo stesso instance_id.
	eq.call("equipaggia", equip_iid)
	assert_true(stats.call("has_modifier", "sigillo:" + sig_iid), "rimontato: il sigillo era ancora incastonato, il modificatore torna")
	eq.call("pulisci")
	p.free()


func test_round_trip_del_save_preserva_i_sigilli() -> void:
	var p: Node2D = _giocatore_finto()
	var stats: Node = p.get_node("StatsComponent")
	var eq: Node = _n("/root/Equipment")
	var gs: Node = _n("/root/GameState")
	eq.call("equipaggia", _prima_istanza("amuleto_lunare"))
	var sig_iid: String = _prima_istanza("sigillo_forza_minore")
	eq.call("incastona", "accessorio_1", sig_iid)
	var forza0: float = stats.call("get_stat", "forza")
	var snap: Dictionary = gs.call("snapshot")
	eq.call("pulisci")
	assert_false(stats.call("has_modifier", "sigillo:" + sig_iid), "svuotato")
	gs.call("applica", snap)
	assert_eq((eq.call("sigilli_incastonati", "accessorio_1") as Array).size(), 1, "il sigillo torna dal save")
	assert_true(stats.call("has_modifier", "sigillo:" + sig_iid), "e il modificatore riapplicato")
	assert_almost_eq(stats.call("get_stat", "forza"), forza0, "stesso valore di prima")
	eq.call("pulisci")
	p.free()


func test_formato_di_salvataggio_pre_us317_si_legge_ancora() -> void:
	var eq: Node = _n("/root/Equipment")
	# Forma nuda pre-US-317: raw stesso era la mappa dei mount, senza wrapper
	# {slot:.., sigilli:..} e senza sigilli incastonati.
	eq.call("da_salvataggio", {"arma": {"instance_id": "x1", "item_id": "spada_ferrea"}})
	assert_eq(eq.call("slot_pieni").get("arma"), "spada_ferrea", "formato vecchio letto correttamente")
	eq.call("pulisci")


func test_capacita_zero_di_un_equip_gia_sigillato() -> void:
	var p: Node2D = _giocatore_finto()
	var eq: Node = _n("/root/Equipment")
	eq.call("equipaggia", _prima_istanza("lama_del_pentimento"))   # slot_sigilli: 0
	assert_false(eq.call("incastona", "arma", _prima_istanza("sigillo_forza_minore")),
		"un equip gia' Sigillato non ha capacita' per altri sigilli")
	eq.call("pulisci")
	p.free()
