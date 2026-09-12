extends "res://tests/test_case.gd"
## US-209 — Concoction: preparare e bere la pozione, avanzamento / digestione.

const ING9 := ["ferro_temperato", "sangue_di_toro", "radice_di_quercia"]


func _ps() -> Node: return Engine.get_main_loop().root.get_node_or_null("PotionSystem")
func _prog() -> Node: return Engine.get_main_loop().root.get_node_or_null("Progression")
func _store() -> Node: return Engine.get_main_loop().root.get_node_or_null("CharacteristicStore")
func _et() -> Node: return Engine.get_main_loop().root.get_node_or_null("EventTracker")
func _acting() -> Node: return Engine.get_main_loop().root.get_node_or_null("Acting")
func _madness() -> Node: return Engine.get_main_loop().root.get_node_or_null("Madness")
func _found() -> Node: return Engine.get_main_loop().root.get_node_or_null("Foundation")


func prepara() -> void:
	_prog().configura("", 9)
	_store().call("pulisci")
	_store().call("aggiungi", "char_twilight_giant_9")
	_et().call("azzera")
	_acting().call("_riparti")
	_madness().call("azzera")
	_found().call("da_salvataggio", {})   # torna all'iniziale (50)
	_ps().call("scarta_pozione")


func _recita_completa() -> void:
	for i in 3:
		_et().call("emit_event", "enemy_defeated", {"senza_abilita": true})
	_et().call("emit_event", "damage_dealt", {"tag_danno": "fisico", "quantita": 2000})
	# tg_9_protettore (US-804): riscritta da damage_absorbed_for_ally a
	# perfect_parry x12 (nessun alleato in scena in questa fase).
	for i in 12:
		_et().call("emit_event", "perfect_parry", {})


func test_concoct_completa() -> void:
	var r: Dictionary = _ps().call("concoct", "formula_twilight_giant_9", "char_twilight_giant_9", ING9)
	assert_true(r["ok"], "concoct riuscita")
	assert_false((r["pozione"] as Dictionary)["parziale"], "pozione completa")
	assert_eq(_store().call("conta", "char_twilight_giant_9"), 0, "Caratteristica consumata")


func test_concoct_parziale() -> void:
	var r: Dictionary = _ps().call("concoct", "formula_twilight_giant_9", "char_twilight_giant_9", ["ferro_temperato", "sangue_di_toro"])
	assert_true(r["ok"], "2 ingredienti su 3 = sopra soglia")
	assert_true((r["pozione"] as Dictionary)["parziale"], "pozione parziale")


func test_concoct_sotto_soglia() -> void:
	var r: Dictionary = _ps().call("concoct", "formula_twilight_giant_9", "char_twilight_giant_9", ["ferro_temperato"])
	assert_false(r["ok"], "1 ingrediente = sotto soglia")
	assert_eq(r["reason"], "ingredienti_insufficienti", "motivo")
	assert_eq(_store().call("conta", "char_twilight_giant_9"), 1, "Caratteristica NON consumata su fallimento")


func test_concoct_caratteristica_incoerente() -> void:
	var r: Dictionary = _ps().call("concoct", "formula_twilight_giant_9", "char_twilight_giant_8", ING9)
	assert_false(r["ok"], "Caratteristica di Sequenza sbagliata")
	assert_eq(r["reason"], "caratteristica_incoerente", "motivo")


func test_concoct_caratteristica_non_posseduta() -> void:
	_store().call("pulisci")
	var r: Dictionary = _ps().call("concoct", "formula_twilight_giant_9", "char_twilight_giant_9", ING9)
	assert_false(r["ok"], "non si possiede la Caratteristica")
	assert_eq(r["reason"], "caratteristica_mancante", "motivo")


func test_bevi_con_acting_completo_avanza() -> void:
	_recita_completa()
	assert_true(_acting().call("e_completo"), "recitazione completa")
	_ps().call("concoct", "formula_twilight_giant_9", "char_twilight_giant_9", ING9)

	var found0: float = _found().call("valore")
	var e: Dictionary = _ps().call("bevi", false)
	assert_true(e["avanzato"], "avanzato")
	assert_false(e["forzato"], "non forzato")
	assert_eq(_prog().call("sequence"), 8, "Sequenza 9 -> 8")
	assert_true(_acting().call("acting_progress") < 0.05, "acting_progress resettato sulla nuova Sequenza")
	assert_almost_eq(_found().call("valore"), found0 + 8.0, "bonus fondamenta per recitazione completa")


func test_bevi_con_acting_incompleto_digerita_male() -> void:
	_ps().call("concoct", "formula_twilight_giant_9", "char_twilight_giant_9", ING9)
	var found0: float = _found().call("valore")

	var e: Dictionary = _ps().call("bevi", false)
	assert_false(e["avanzato"], "nessun avanzamento")
	assert_eq(_prog().call("sequence"), 9, "resta a Sequenza 9")
	assert_almost_eq(_found().call("valore"), found0 - 10.0, "fondamenta giu' (malus_digestione_difficile)")
	assert_gt(_madness().call("valore"), 0.0, "follia su (madness_on_force * moltiplicatore)")
	assert_true(_ps().call("pozione_pronta").is_empty(), "pozione sprecata")


func test_bevi_forzato_avanza_con_malus_pesante() -> void:
	_ps().call("concoct", "formula_twilight_giant_9", "char_twilight_giant_9", ING9)
	var found0: float = _found().call("valore")

	var e: Dictionary = _ps().call("bevi", true)   # forza
	assert_true(e["avanzato"] and e["forzato"], "avanzato forzando")
	assert_eq(_prog().call("sequence"), 8, "avanzato a 8")
	assert_almost_eq(_found().call("valore"), found0 - 25.0, "malus_avanzamento_forzato")
	assert_gt(_madness().call("valore"), 0.0, "follia da avanzamento forzato")


func test_pozione_parziale_penalizza_la_follia() -> void:
	_recita_completa()
	_ps().call("concoct", "formula_twilight_giant_9", "char_twilight_giant_9", ["ferro_temperato", "sangue_di_toro"])
	var e: Dictionary = _ps().call("bevi", false)
	assert_true(e["avanzato"], "avanzato (acting completo)")
	assert_gt(float(e["follia"]), 0.0, "la pozione parziale aggiunge follia")
	assert_gt(_madness().call("valore"), 0.0, "follia registrata")


func test_bevi_pozione_per_altra_sequenza() -> void:
	# pozione di formula_twilight_giant_8 (si beve a Sequenza 8) mentre si e' a 9
	_store().call("aggiungi", "char_twilight_giant_8")
	_ps().call("concoct", "formula_twilight_giant_8", "char_twilight_giant_8",
		["osso_di_pugile", "sale_di_roccia", "estratto_di_muscolo"])
	var e: Dictionary = _ps().call("bevi", false)
	assert_false(e["ok"], "pozione per un'altra Sequenza rifiutata")
