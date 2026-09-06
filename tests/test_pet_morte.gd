extends "res://tests/test_case.gd"
## US-325 — la morte del pet e' la perdita di un'Ancora: colpo di follia vero,
## slot pet svuotato, il pet non torna al load.

const SLOT := 907


func _ps() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("PetSystem")


func _anc() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AnchorSystem")


func _madness() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Madness")


func _audio() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AudioManager")


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SaveSystem")


func prepara() -> void:
	if _ps() != null:
		_ps().call("pulisci")
	if _anc() != null:
		_anc().call("pulisci")
	if _madness() != null:
		_madness().call("azzera")


func test_morte_distrugge_l_ancora_e_alza_la_follia() -> void:
	_ps().call("doma", "lupo_cinereo", 1.0)
	assert_true((_anc().call("active") as Array).has("anchor_pet"), "Ancora attiva prima")
	var persa: Array = []
	_anc().connect("anchor_lost", func(id: String) -> void: persa.append(id))

	assert_true(_ps().call("morte"), "morte() con un pet -> true")
	assert_false((_anc().call("active") as Array).has("anchor_pet"), "Ancora distrutta")
	assert_true(persa.has("anchor_pet"), "segnale anchor_lost emesso")
	# anchor_pet.penalita = 16 in data/anchors.json, NON bufferizzata
	assert_almost_eq(float(_madness().call("valore")), 16.0,
		"follia += penalita dell'Ancora del pet")


func test_dopo_la_morte_pet_attivo_e_vuoto() -> void:
	_ps().call("doma", "corvo_veggente", 1.0)
	_ps().call("morte")
	assert_false(_ps().call("ha_pet"), "nessun pet")
	assert_eq(_ps().call("pet_attivo"), {}, "pet_attivo() torna {}")


func test_morte_senza_pet_non_fa_nulla() -> void:
	assert_false(_ps().call("morte"), "morte() senza pet -> false")
	assert_almost_eq(float(_madness().call("valore")), 0.0, "nessuna follia")


func test_i_sussurri_smettono_di_nominare_il_pet() -> void:
	_ps().call("doma", "lupo_cinereo", 1.0)
	if _audio() != null:
		assert_true((_audio().call("nomi_sussurro") as Array).has("anchor.pet"),
			"i sussurri nominano il pet finche' e' vivo")
	_ps().call("morte")
	if _audio() != null:
		assert_false((_audio().call("nomi_sussurro") as Array).has("anchor.pet"),
			"dopo la morte i sussurri non lo nominano piu'")


func test_il_pet_morto_non_torna_al_load() -> void:
	var s: Node = _save()
	if s.esiste(SLOT):
		s.cancella(SLOT)
	_ps().call("doma", "lupo_cinereo", 1.0)
	_ps().call("morte")
	var snap: Dictionary = {"nome_personaggio": "Enel", "pet": _ps().call("per_salvataggio")}
	s.salva(SLOT, snap)

	var caricato: Dictionary = s.carica(SLOT)
	assert_eq((caricato["dati"] as Dictionary)["pet"], {}, "slot pet vuoto nel save")
	_ps().call("da_salvataggio", (caricato["dati"] as Dictionary)["pet"])
	assert_false(_ps().call("ha_pet"), "il pet morto non si ricrea al load")
	s.cancella(SLOT)
