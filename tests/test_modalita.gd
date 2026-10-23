extends "res://tests/test_case.gd"
## Modalita' di gioco (decisione 2026-10-20): scelta a inizio partita, fissa,
## nel salvataggio; i numeri vengono da data/modalita.json.

const SLOT := 912


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func prepara() -> void:
	if _n("/root/GameState") != null:
		_n("/root/GameState").set("_partita_attiva", false)


func _fine() -> void:
	_n("/root/SaveSystem").call("cancella", SLOT)
	_n("/root/GameState").set("_partita_attiva", false)
	_n("/root/GameState").set("modalita", "facile")


func test_i_dati_hanno_le_due_modalita() -> void:
	var gd: Node = _n("/root/GameData")
	assert_true("facile" in (gd.call("modalita_ids") as Array), "facile nei dati")
	assert_true("difficile" in (gd.call("modalita_ids") as Array), "difficile nei dati")
	assert_eq(str((gd.call("get_modalita", "difficile") as Dictionary).get("tema_arte")), "cupo", "difficile = arte cupa")


func test_la_modalita_scelta_resta_e_dice_i_numeri() -> void:
	var gs: Node = _n("/root/GameState")
	gs.call("nuova_partita", "Enel", SLOT, [], "difficile")
	assert_eq(str(gs.get("modalita")), "difficile", "modalita' scelta")
	assert_eq(str(gs.call("tema_arte")), "cupo", "tema dell'arte dai dati")
	var atteso: float = float(((_n("/root/GameData").call("get_modalita", "difficile") as Dictionary)
		.get("moltiplicatori", {}) as Dictionary).get("danno_al_giocatore", 1.0))
	assert_almost_eq(float(gs.call("moltiplicatore", "danno_al_giocatore")), atteso, "numero dai dati")
	assert_almost_eq(float(gs.call("moltiplicatore", "numero_che_non_esiste")), 1.0, "nome assente = 1")
	_fine()


func test_facile_non_cambia_niente() -> void:
	var gs: Node = _n("/root/GameState")
	gs.call("nuova_partita", "Enel", SLOT, [], "facile")
	for nome in ["danno_al_giocatore", "danno_ai_nemici", "cure"]:
		assert_almost_eq(float(gs.call("moltiplicatore", nome)), 1.0, "facile: %s = 1" % nome)
	assert_eq(str(gs.call("tema_arte")), "luminoso", "facile = arte luminosa")
	_fine()


func test_la_modalita_si_salva_e_si_ricarica() -> void:
	var gs: Node = _n("/root/GameState")
	var s: Node = _n("/root/SaveSystem")
	gs.call("nuova_partita", "Enel", SLOT, [], "difficile")
	gs.set("modalita", "facile")
	var r: Dictionary = s.call("carica", SLOT)
	gs.call("applica", r["dati"])
	assert_eq(str(gs.get("modalita")), "difficile", "torna dal save")
	_fine()


func test_save_vecchio_e_modalita_sconosciuta_diventano_il_default() -> void:
	var gs: Node = _n("/root/GameState")
	gs.set("modalita", "difficile")
	gs.call("applica", {"nome_personaggio": "Enel"})
	assert_eq(str(gs.get("modalita")), "facile", "save senza il campo -> default dei dati")
	gs.call("nuova_partita", "Enel", SLOT, [], "impossibile")
	assert_eq(str(gs.get("modalita")), "facile", "modalita' che non esiste -> default")
	_fine()
