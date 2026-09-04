extends "res://tests/test_case.gd"
## US-328 — il giardino: ingredienti che crescono col tempo di GIOCO.


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/BaseSystem") != null:
		_n("/root/BaseSystem").call("pulisci")
	if _n("/root/Inventory") != null:
		_n("/root/Inventory").call("pulisci")
	if _n("/root/GameState") != null:
		_n("/root/GameState").set("tempo_gioco", 0.0)


func _costruisci_giardino() -> void:
	var bs: Node = _n("/root/BaseSystem")
	var inv: Node = _n("/root/Inventory")
	var costo: Dictionary = bs.call("prossimo_costo", "giardino")
	for item_id in costo:
		inv.call("aggiungi", item_id, int(costo[item_id]))
	bs.call("costruisci", "giardino")


func test_senza_giardino_pianta_rifiuta() -> void:
	var bs: Node = _n("/root/BaseSystem")
	_n("/root/Inventory").call("aggiungi", "erba_lunare", 1)
	assert_eq(bs.call("pianta", "erba_lunare"), -1, "nessun giardino costruito -> rifiuto")


func test_solo_ingrediente_coltivabile() -> void:
	_costruisci_giardino()
	var bs: Node = _n("/root/BaseSystem")
	var inv: Node = _n("/root/Inventory")
	inv.call("aggiungi", "polvere_ossa", 1)   # ingrediente, NON coltivabile
	assert_eq(bs.call("pianta", "polvere_ossa"), -1, "non coltivabile -> rifiuto")
	inv.call("aggiungi", "spada_ferrea", 1)   # non e' nemmeno un ingrediente
	assert_eq(bs.call("pianta", "spada_ferrea"), -1, "non e' un ingrediente -> rifiuto")


func test_pianta_non_e_subito_pronto() -> void:
	_costruisci_giardino()
	var bs: Node = _n("/root/BaseSystem")
	_n("/root/Inventory").call("aggiungi", "erba_lunare", 1)
	var idx: int = bs.call("pianta", "erba_lunare")
	assert_true(idx >= 0, "piantato in un appezzamento")
	assert_false(bs.call("e_pronto", idx), "non ancora pronto")
	assert_eq(_n("/root/Inventory").call("conta", "erba_lunare"), 0, "il seme e' consumato")
	var app: Dictionary = (bs.call("appezzamenti") as Array)[idx]
	assert_false(app.get("pronto"), "appezzamenti() concorda")
	assert_gt(float(app.get("tempo_rimasto")), 0.0, "tempo rimanente positivo")


func test_avanza_il_tempo_di_gioco_oltre_tempo_crescita_diventa_pronto() -> void:
	_costruisci_giardino()
	var bs: Node = _n("/root/BaseSystem")
	var gs: Node = _n("/root/GameState")
	_n("/root/Inventory").call("aggiungi", "erba_lunare", 1)
	var idx: int = bs.call("pianta", "erba_lunare")
	assert_false(bs.call("e_pronto", idx), "premessa: non pronto")

	gs.set("tempo_gioco", 999.0)   # ben oltre tempo_crescita (balance.json.giardino: 60.0)
	assert_true(bs.call("e_pronto", idx), "col tempo di gioco avanzato: pronto")


func test_raccogli_mette_litem_nellinventario_secondo_la_resa() -> void:
	_costruisci_giardino()
	var bs: Node = _n("/root/BaseSystem")
	var inv: Node = _n("/root/Inventory")
	inv.call("aggiungi", "erba_lunare", 1)
	var idx: int = bs.call("pianta", "erba_lunare")
	_n("/root/GameState").set("tempo_gioco", 999.0)

	assert_true(bs.call("raccogli", idx), "raccogli riesce")
	assert_eq(inv.call("conta", "erba_lunare"), 2, "resa del livello 1 del giardino (bonus.resa: 2)")
	assert_eq((bs.call("appezzamenti") as Array).size(), 0, "l'appezzamento si e' liberato")


func test_raccogli_prima_del_tempo_rifiuta() -> void:
	_costruisci_giardino()
	var bs: Node = _n("/root/BaseSystem")
	_n("/root/Inventory").call("aggiungi", "erba_lunare", 1)
	var idx: int = bs.call("pianta", "erba_lunare")
	assert_false(bs.call("raccogli", idx), "ancora in crescita -> rifiuto")
	assert_eq((bs.call("appezzamenti") as Array).size(), 1, "l'appezzamento resta occupato")


func test_appezzamenti_limitati_al_livello_del_giardino() -> void:
	_costruisci_giardino()   # livello 1 -> 1 appezzamento
	var bs: Node = _n("/root/BaseSystem")
	var inv: Node = _n("/root/Inventory")
	inv.call("aggiungi", "erba_lunare", 2)
	assert_true(bs.call("pianta", "erba_lunare") >= 0, "1o appezzamento")
	assert_eq(bs.call("pianta", "erba_lunare"), -1, "il livello 1 ha un solo appezzamento")


func test_round_trip_a_meta_crescita() -> void:
	_costruisci_giardino()
	var bs: Node = _n("/root/BaseSystem")
	var gs: Node = _n("/root/GameState")
	_n("/root/Inventory").call("aggiungi", "erba_lunare", 1)
	var idx: int = bs.call("pianta", "erba_lunare")
	gs.set("tempo_gioco", 30.0)   # a meta' dei 60s di tempo_crescita

	var snap: Dictionary = bs.call("per_salvataggio")
	bs.call("pulisci")
	assert_eq((bs.call("appezzamenti") as Array).size(), 0, "svuotato")
	bs.call("da_salvataggio", snap)

	var app: Array = bs.call("appezzamenti")
	assert_eq(app.size(), 1, "l'appezzamento torna dal save")
	assert_false(bs.call("e_pronto", idx), "ancora non pronto: l'istante di maturazione e' preservato")
	gs.set("tempo_gioco", 999.0)
	assert_true(bs.call("e_pronto", idx), "e continua a maturare da dove era rimasto")
