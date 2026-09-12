extends "res://tests/test_case.gd"
## US-212 — blocco dell'avanzamento sotto acting_progress 1.0: le query di
## stato dell'avanzamento e il floor delle fondamenta.

const ING9 := ["ferro_temperato", "sangue_di_toro", "radice_di_quercia"]


func _ps() -> Node: return Engine.get_main_loop().root.get_node_or_null("PotionSystem")
func _prog() -> Node: return Engine.get_main_loop().root.get_node_or_null("Progression")
func _store() -> Node: return Engine.get_main_loop().root.get_node_or_null("CharacteristicStore")
func _et() -> Node: return Engine.get_main_loop().root.get_node_or_null("EventTracker")
func _acting() -> Node: return Engine.get_main_loop().root.get_node_or_null("Acting")
func _found() -> Node: return Engine.get_main_loop().root.get_node_or_null("Foundation")


func prepara() -> void:
	_prog().configura("", 9)
	# US-711: questo test e' sul floor delle fondamenta, non sulle tribolazioni.
	Engine.get_main_loop().root.get_node("TribulationSystem").call("marca_superate_tutte")
	_store().call("pulisci")
	_store().call("aggiungi", "char_twilight_giant_9")
	_et().call("azzera")
	_acting().call("_riparti")
	_found().call("da_salvataggio", {})
	_ps().call("scarta_pozione")


func _recita_completa() -> void:
	for i in 3:
		_et().call("emit_event", "enemy_defeated", {"senza_abilita": true})
	_et().call("emit_event", "damage_dealt", {"tag_danno": "fisico", "quantita": 2000})
	# tg_9_protettore (US-804): riscritta da damage_absorbed_for_ally a
	# perfect_parry x12 (nessun alleato in scena in questa fase).
	for i in 12:
		_et().call("emit_event", "perfect_parry", {})


func test_stato_avanzamento_senza_pozione() -> void:
	assert_false(_ps().call("avanzamento_disponibile"), "nessuna pozione -> non disponibile")
	assert_false(_ps().call("avanzamento_forzabile"), "nessuna pozione -> non forzabile")


func test_pozione_pronta_ma_recitazione_incompleta_solo_forzabile() -> void:
	_ps().call("concoct", "formula_twilight_giant_9", "char_twilight_giant_9", ING9)
	assert_false(_ps().call("avanzamento_disponibile"), "acting < 1.0 -> avanzamento normale bloccato")
	assert_true(_ps().call("avanzamento_forzabile"), "si puo' solo forzare")


func test_recitazione_completa_avanzamento_disponibile() -> void:
	_ps().call("concoct", "formula_twilight_giant_9", "char_twilight_giant_9", ING9)
	_recita_completa()
	assert_true(_ps().call("avanzamento_disponibile"), "acting completo -> avanzamento normale")
	assert_false(_ps().call("avanzamento_forzabile"), "non serve forzare")


func test_bere_senza_recitazione_non_avanza() -> void:
	_ps().call("concoct", "formula_twilight_giant_9", "char_twilight_giant_9", ING9)
	var e: Dictionary = _ps().call("bevi", false)
	assert_false(e["avanzato"], "avanzamento bloccato per via normale")
	assert_eq(_prog().call("sequence"), 9, "resta a Sequenza 9")


func test_fondamenta_non_scendono_sotto_zero() -> void:
	var f: Node = _found()
	assert_almost_eq(f.call("valore"), 50.0, "iniziale")
	f.call("applica", -25.0, "x")
	assert_almost_eq(f.call("valore"), 25.0, "primo malus")
	f.call("applica", -25.0, "x")
	assert_almost_eq(f.call("valore"), 0.0, "secondo malus -> 0")
	f.call("applica", -25.0, "x")
	assert_almost_eq(f.call("valore"), 0.0, "terzo malus -> resta a 0 (floor)")


func test_moltiplicatore_follia_sale_a_fondamenta_basse() -> void:
	var f: Node = _found()
	f.call("da_salvataggio", {"valore": 100.0})
	assert_almost_eq(f.call("moltiplicatore_follia"), 1.0, "fondamenta piene -> 1.0")
	f.call("da_salvataggio", {"valore": 0.0})
	assert_almost_eq(f.call("moltiplicatore_follia"), 2.5, "fondamenta a zero -> 2.5")
	f.call("da_salvataggio", {"valore": 50.0})
	assert_almost_eq(f.call("moltiplicatore_follia"), 1.75, "a meta' -> 1.75")


func test_forzare_ripetutamente_non_sfora_il_floor() -> void:
	for seq in [9, 8, 7, 6, 5]:
		_store().call("aggiungi", "char_twilight_giant_%d" % seq)
		_ps().call("concoct", "formula_twilight_giant_%d" % seq, "char_twilight_giant_%d" % seq,
			(Engine.get_main_loop().root.get_node("GameData").call("get_formula", "formula_twilight_giant_%d" % seq) as Dictionary)["ingredients"])
		_ps().call("bevi", true)
		assert_true(_found().call("valore") >= 0.0, "fondamenta mai negative alla Sequenza %d" % seq)
	assert_eq(_prog().call("sequence"), 4, "9 -> 4 forzando cinque volte")
	assert_almost_eq(_found().call("valore"), 0.0, "fondamenta a zero, non sotto")
