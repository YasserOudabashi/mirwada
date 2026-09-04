extends "res://tests/test_case.gd"
## US-324 — coltivazione del pet: avanza di Sequenza consumando una risorsa.


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/PetSystem") != null:
		_n("/root/PetSystem").call("pulisci")
	if _n("/root/Inventory") != null:
		_n("/root/Inventory").call("pulisci")
	# Progression e' un autoload persistente per tutta la suite: riparte
	# sempre dal default (Sequenza 9), altrimenti uno stato lasciato da
	# un altro file contaminerebbe il cap "non oltre la Sequenza del
	# giocatore" (lezione della contaminazione gia' vista in US-317).
	if _n("/root/Progression") != null:
		_n("/root/Progression").call("configura", "", 9)


func _pet_con_bond(pet_id: String, bond: float, sequenza: int) -> void:
	_n("/root/PetSystem").call("da_salvataggio", {"pet_id": pet_id, "bond": bond, "sequenza": sequenza})


func test_avanza_con_bond_alto_e_risorsa() -> void:
	var ps: Node = _n("/root/PetSystem")
	_n("/root/Progression").call("configura", "", 5)   # il giocatore e' gia' oltre
	_pet_con_bond("lupo_ombra", 100.0, 9)
	_n("/root/Inventory").call("aggiungi", "pastura_spirituale", 1)

	assert_true(ps.call("avanza_pet"), "bond alto + risorsa -> avanza")
	var p: Dictionary = ps.call("pet_attivo")
	assert_eq(int(p.get("sequenza")), 8, "sequenza scesa di uno")
	assert_almost_eq(float(p.get("hp")), 46.0, "hp_max dalla curva della specie a Sequenza 8")
	assert_eq(_n("/root/Inventory").call("conta", "pastura_spirituale"), 0, "la risorsa e' consumata")


func test_bond_basso_rifiuta() -> void:
	var ps: Node = _n("/root/PetSystem")
	_n("/root/Progression").call("configura", "", 5)
	_pet_con_bond("lupo_ombra", 10.0, 9)   # sotto soglia_avanzamento_bond (40)
	_n("/root/Inventory").call("aggiungi", "pastura_spirituale", 1)

	assert_false(ps.call("avanza_pet"), "bond basso -> rifiuto")
	assert_eq(int((ps.call("pet_attivo") as Dictionary).get("sequenza")), 9, "sequenza invariata")
	assert_eq(_n("/root/Inventory").call("conta", "pastura_spirituale"), 1, "la risorsa NON si consuma sul rifiuto")


func test_senza_risorsa_rifiuta() -> void:
	var ps: Node = _n("/root/PetSystem")
	_n("/root/Progression").call("configura", "", 5)
	_pet_con_bond("lupo_ombra", 100.0, 9)
	assert_false(ps.call("avanza_pet"), "bond alto ma nessuna risorsa -> rifiuto")


func test_non_supera_la_sequenza_del_giocatore() -> void:
	var ps: Node = _n("/root/PetSystem")
	# il giocatore e' ANCORA a Sequenza 9: il pet non puo' avanzare a 8,
	# lo supererebbe.
	_n("/root/Progression").call("configura", "", 9)
	_pet_con_bond("lupo_ombra", 100.0, 9)
	_n("/root/Inventory").call("aggiungi", "pastura_spirituale", 1)

	assert_false(ps.call("avanza_pet"), "il pet non puo' superare la Sequenza del giocatore")
	assert_eq(_n("/root/Inventory").call("conta", "pastura_spirituale"), 1, "e non consuma la risorsa")


func test_sequenza_zero_non_avanza_oltre() -> void:
	var ps: Node = _n("/root/PetSystem")
	_n("/root/Progression").call("configura", "", 0)
	_pet_con_bond("lupo_ombra", 100.0, 0)
	_n("/root/Inventory").call("aggiungi", "pastura_spirituale", 1)
	assert_false(ps.call("avanza_pet"), "gia' a Sequenza 0: nessun avanzamento oltre")


func test_senza_pet_rifiuta() -> void:
	assert_false(_n("/root/PetSystem").call("avanza_pet"), "nessun pet attivo -> false")
