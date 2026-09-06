extends "res://tests/test_case.gd"
## US-324 — coltivazione del pet: avanza_pet richiede bond + nutrimento, non
## supera la Sequenza del giocatore, la curva hp e' nei dati.


func _ps() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("PetSystem")


func _prog() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Progression")


func _inv() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Inventory")


func prepara() -> void:
	if _ps() != null:
		_ps().call("pulisci")
	if _inv() != null:
		_inv().call("pulisci")
	if _prog() != null:
		_prog().call("configura", "", 7)  # giocatore a Sequenza 7


func _fine() -> void:
	if _prog() != null:
		_prog().call("configura", "", 9)


func _dai_pastura(n: int) -> void:
	_inv().call("aggiungi", "pastura_spirituale", n)


func test_bond_basso_rifiuta_l_avanzamento() -> void:
	_ps().call("imposta_pet", "lupo_cinereo")  # soglia_bond 60
	_ps().call("imposta_bond", 40)
	_dai_pastura(1)
	assert_false(_ps().call("avanza_pet"), "bond 40 < 60: rifiutato")
	assert_eq(_ps().call("sequenza_pet"), 9, "Sequenza invariata")
	assert_eq(_inv().call("conta", "pastura_spirituale"), 1, "il nutrimento non e' stato consumato")
	_fine()


func test_senza_nutrimento_rifiuta() -> void:
	_ps().call("imposta_pet", "lupo_cinereo")
	_ps().call("imposta_bond", 80)
	assert_false(_ps().call("avanza_pet"), "niente pastura in zaino: rifiutato")
	assert_eq(_ps().call("sequenza_pet"), 9, "Sequenza invariata")
	_fine()


func test_bond_e_nutrimento_fanno_avanzare_e_consumano_la_risorsa() -> void:
	_ps().call("imposta_pet", "lupo_cinereo")
	_ps().call("imposta_bond", 80)
	_dai_pastura(2)
	assert_true(_ps().call("avanza_pet"), "bond 80 + pastura: avanza")
	assert_eq(_ps().call("sequenza_pet"), 8, "Sequenza 9 -> 8")
	assert_eq(_inv().call("conta", "pastura_spirituale"), 1, "consumata una pastura")
	assert_eq(float((_ps().call("pet_attivo") as Dictionary)["hp"]), 95.0,
		"hp aggiornato dalla curva hp_per_sequenza (8 -> 95)")
	_fine()


func test_il_pet_non_supera_la_sequenza_del_giocatore() -> void:
	_ps().call("imposta_pet", "lupo_cinereo")
	_ps().call("imposta_bond", 90)
	_dai_pastura(5)
	assert_true(_ps().call("avanza_pet"), "9 -> 8 (giocatore a 7)")
	assert_true(_ps().call("avanza_pet"), "8 -> 7 (pari al giocatore, ammesso)")
	assert_false(_ps().call("avanza_pet"), "7 -> 6 rifiutato: supererebbe il giocatore")
	assert_eq(_ps().call("sequenza_pet"), 7, "bloccato alla Sequenza del giocatore")
	assert_eq(_inv().call("conta", "pastura_spirituale"), 3, "consumate solo le 2 riuscite")
	_fine()


func test_avanzamento_persiste_nel_save() -> void:
	var s: Node = Engine.get_main_loop().root.get_node_or_null("SaveSystem")
	var SLOT := 906
	if s.esiste(SLOT):
		s.cancella(SLOT)
	_ps().call("imposta_pet", "corvo_veggente")
	_ps().call("imposta_bond", 80)
	_dai_pastura(1)
	_ps().call("avanza_pet")
	var snap: Dictionary = {"nome_personaggio": "Enel", "pet": _ps().call("per_salvataggio")}
	s.salva(SLOT, snap)
	_ps().call("pulisci")
	var caricato: Dictionary = s.carica(SLOT)
	_ps().call("da_salvataggio", (caricato["dati"] as Dictionary)["pet"])
	assert_eq(_ps().call("sequenza_pet"), 8, "Sequenza avanzata ripristinata dal save")
	s.cancella(SLOT)
	_fine()
