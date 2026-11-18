extends "res://tests/test_case.gd"
## 2026-11-18 — Il pet si doma nel mondo: ogni specie vive nel suo luogo; senza il nutrimento non si prova, con il
## nutrimento se ne consuma uno e si tira la domabilita'; se va male scappa, se va bene ti segue.

func _root() -> Node: return Engine.get_main_loop().root
func _ps() -> Node: return _root().get_node("PetSystem")
func _inv() -> Node: return _root().get_node("Inventory")

var _m: Node2D = null


func _mondo() -> Node:
	_ps().call("pulisci")
	_root().get_node("AnchorSystem").call("pulisci")
	_inv().call("pulisci")
	_m = preload("res://scripts/world/mondo.gd").new()
	var p: Node2D = preload("res://scenes/player.tscn").instantiate()
	_m.add_child(p)
	_root().add_child(_m)
	_m.get_node("Pet").call("aggiorna")
	return _m.get_node("Pet")


func _fine() -> void:
	_m.free()
	_ps().call("pulisci")
	_root().get_node("AnchorSystem").call("pulisci")
	_inv().call("pulisci")


func test_ogni_specie_vive_nel_suo_luogo() -> void:
	var pet: Node = _mondo()
	for pid in _root().get_node("GameData").call("pet_ids"):
		assert_true(pet.get_node_or_null("Selvatico_%s" % pid) != null, "%s e' nel mondo, da domare" % pid)
	_fine()


func test_senza_nutrimento_non_si_prova() -> void:
	var pet: Node = _mondo()
	assert_eq(str(pet.call("prova_a_domare", "corvo_veggente")), "serve", "serve la pastura")
	assert_true((_ps().call("pet_attivo") as Dictionary).is_empty(), "e nessun pet")
	_fine()


func test_domato_ti_segue_e_diventa_un_ancora() -> void:
	var pet: Node = _mondo()
	_inv().call("aggiungi", "pastura_spirituale", 1)
	_ps().call("imposta_seed", 1)
	var esito := ""
	for i in 20:                                        # al massimo una pastura per volta
		_inv().call("aggiungi", "pastura_spirituale", 1)
		pet.set("_spaventati", [])
		esito = str(pet.call("prova_a_domare", "capra_lunare"))
		if esito == "riuscita":
			break
	assert_eq(esito, "riuscita", "prima o poi si doma")
	assert_eq(str((_ps().call("pet_attivo") as Dictionary).get("pet_id", "")), "capra_lunare", "e' il compagno")
	assert_true("anchor_pet" in _root().get_node("AnchorSystem").call("active"), "ed e' un'Ancora")
	assert_true(pet.call("compagno") != null, "ti segue nel mondo")
	var sel: Node = pet.get_node_or_null("Selvatico_capra_lunare")
	assert_true(sel == null or sel.is_queued_for_deletion(), "non e' piu' fra i selvatici")
	assert_eq(str(pet.call("prova_a_domare", "lupo_cinereo")), "hai_gia", "un compagno per volta")
	_fine()


func test_se_va_male_scappa() -> void:
	var pet: Node = _mondo()
	_ps().call("imposta_seed", 7)
	var scappato := false
	for i in 30:
		_inv().call("aggiungi", "pastura_spirituale", 1)
		pet.set("_spaventati", [])
		pet.call("aggiorna")
		if str(pet.call("prova_a_domare", "lupo_cinereo")) == "fallita":
			scappato = true
			break
		_ps().call("libera")
		pet.call("aggiorna")
	assert_true(scappato, "a volte non riesce")
	assert_true(pet.get_node_or_null("Selvatico_lupo_cinereo") == null or (pet.get_node("Selvatico_lupo_cinereo") as Node).is_queued_for_deletion(), "e il lupo scappa")
	_fine()
