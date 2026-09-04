extends "res://tests/test_case.gd"
## US-317 — incisione dei sigilli sull'equip (fusione US-309).

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


## Aggiunge item_id e ne restituisce la PRIMA istanza (funziona per equip e
## sigilli: entrambi impilabile:false).
func _istanza(item_id: String) -> String:
	var inv: Node = _n("/root/Inventory")
	var creati: Array = inv.call("aggiungi", item_id, 1)
	return str(creati[0]) if not creati.is_empty() else ""


## Equipaggia amuleto_lunare (accessorio, slot_sigilli: 2) e torna il mount.
func _con_amuleto_equipaggiato() -> String:
	var eq: Node = _n("/root/Equipment")
	eq.call("equipaggia", _istanza("amuleto_lunare"))
	return eq.call("slot_pieni").keys()[0]


func test_incastona_applica_leffetto() -> void:
	var p: Node2D = _giocatore_finto()
	var stats: Node = p.get_node("StatsComponent")
	var eq: Node = _n("/root/Equipment")
	var mount: String = _con_amuleto_equipaggiato()
	var forza0: float = stats.call("get_stat", "forza")
	var sid: String = _istanza("sigillo_forza_minore")   # sig_forza_1: forza +0.08 flat
	assert_true(eq.call("incastona", mount, sid), "incastona riesce")
	assert_almost_eq(stats.call("get_stat", "forza"), forza0 + 0.08, "la stat sale del delta dichiarato")
	assert_true(stats.call("has_modifier", "sigillo:" + sid), "modificatore per id sigillo:<instance_id>")
	assert_eq(_n("/root/Inventory").call("conta", "sigillo_forza_minore"), 0,
		"il sigillo e' uscito dallo zaino")
	p.free()


func test_incastona_fino_al_limite_poi_fallisce() -> void:
	var p: Node2D = _giocatore_finto()
	var eq: Node = _n("/root/Equipment")
	var mount: String = _con_amuleto_equipaggiato()   # slot_sigilli: 2
	assert_true(eq.call("incastona", mount, _istanza("sigillo_forza_minore")), "1o sigillo")
	assert_true(eq.call("incastona", mount, _istanza("sigillo_difesa_minore")), "2o sigillo")
	assert_false(eq.call("incastona", mount, _istanza("sigillo_vento_leggero")),
		"3o sigillo rifiutato: slot_sigilli esaurito")
	assert_eq((eq.call("sigilli_incastonati", mount) as Array).size(), 2, "solo 2 incastonati")
	p.free()


func test_effetto_collaterale_applicato_e_rimosso() -> void:
	var p: Node2D = _giocatore_finto()
	var stats: Node = p.get_node("StatsComponent")
	var eq: Node = _n("/root/Equipment")
	var mount: String = _con_amuleto_equipaggiato()
	var spirit0: float = stats.call("get_stat", "spiritualita_max")
	var sid: String = _istanza("sigillo_ombra_fame")   # evasione +12% / spiritualita_max -15
	eq.call("incastona", mount, sid)
	assert_true(stats.call("has_modifier", "sigillo:" + sid), "effetto applicato")
	assert_true(stats.call("has_modifier", "sigillo:" + sid + ":collaterale"), "collaterale applicato")
	assert_almost_eq(stats.call("get_stat", "spiritualita_max"), spirit0 - 15.0,
		"il collaterale drena spiritualita_max")
	assert_true(eq.call("rimuovi_sigillo", mount, sid), "estrazione riesce")
	assert_false(stats.call("has_modifier", "sigillo:" + sid), "effetto rimosso")
	assert_false(stats.call("has_modifier", "sigillo:" + sid + ":collaterale"), "collaterale rimosso")
	assert_almost_eq(stats.call("get_stat", "spiritualita_max"), spirit0, "spiritualita_max tornata al valore base")
	assert_eq(_n("/root/Inventory").call("conta", "sigillo_ombra_fame"), 1, "il sigillo e' tornato nello zaino")
	p.free()


func test_sigilli_incastonati_contano_in_tag_attivi() -> void:
	var p: Node2D = _giocatore_finto()
	var eq: Node = _n("/root/Equipment")
	var inv: Node = _n("/root/Inventory")
	var mount: String = _con_amuleto_equipaggiato()
	var prima: int = int((inv.call("tag_attivi") as Dictionary).get("forza", 0))
	eq.call("incastona", mount, _istanza("sigillo_forza_minore"))   # sig_forza_1 tag: ["forza"]
	assert_eq(int((inv.call("tag_attivi") as Dictionary).get("forza", 0)), prima + 1,
		"il tag del sigillo incastonato conta")
	p.free()


func test_rimuovi_slot_estrae_i_sigilli_senza_perdita() -> void:
	var p: Node2D = _giocatore_finto()
	var stats: Node = p.get_node("StatsComponent")
	var eq: Node = _n("/root/Equipment")
	var inv: Node = _n("/root/Inventory")
	var mount: String = _con_amuleto_equipaggiato()
	var sid: String = _istanza("sigillo_forza_minore")
	eq.call("incastona", mount, sid)
	assert_true(eq.call("rimuovi_slot", mount), "smonta l'amuleto")
	assert_false(stats.call("has_modifier", "sigillo:" + sid), "effetto del sigillo rimosso")
	assert_eq(inv.call("conta", "amuleto_lunare"), 1, "l'amuleto e' tornato nello zaino")
	assert_eq(inv.call("conta", "sigillo_forza_minore"), 1, "il sigillo e' tornato nello zaino, non perso")
	assert_eq((eq.call("sigilli_incastonati", mount) as Array).size(), 0, "lo slot non ricorda piu' il sigillo")
	p.free()


func test_round_trip_del_save_con_sigilli() -> void:
	var p: Node2D = _giocatore_finto()
	var stats: Node = p.get_node("StatsComponent")
	var eq: Node = _n("/root/Equipment")
	var gs: Node = _n("/root/GameState")
	# gs.call("applica") sincronizza anche Progression (sequence:N, un
	# modificatore SUO, non del sigillo): lo si stabilizza PRIMA di misurare,
	# cosi' il confronto isola solo il contributo del sigillo.
	gs.call("applica", gs.call("snapshot"))
	var mount: String = _con_amuleto_equipaggiato()
	var sid: String = _istanza("sigillo_forza_minore")
	eq.call("incastona", mount, sid)
	var forza_con_sigillo: float = stats.call("get_stat", "forza")
	var snap: Dictionary = gs.call("snapshot")
	eq.call("pulisci")
	assert_false(stats.call("has_modifier", "sigillo:" + sid), "svuotato")
	gs.call("applica", snap)
	assert_eq((eq.call("sigilli_incastonati", mount) as Array).size(), 1, "il sigillo torna incastonato")
	assert_true(stats.call("has_modifier", "sigillo:" + sid), "il modificatore torna applicato")
	assert_almost_eq(stats.call("get_stat", "forza"), forza_con_sigillo, "stessa forza di prima")
	p.free()
