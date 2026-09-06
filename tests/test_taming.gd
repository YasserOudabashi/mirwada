extends "res://tests/test_case.gd"
## US-322 — Taming: PetSystem.doma, un pet per volta, il pet entra come Ancora.


func _ps() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("PetSystem")


func _anc() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AnchorSystem")


func _madness() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Madness")


func prepara() -> void:
	if _ps() != null:
		_ps().call("pulisci")
	if _anc() != null:
		_anc().call("pulisci")
	if _madness() != null:
		_madness().call("azzera")


func test_doma_riuscita_imposta_il_pet_e_attiva_l_ancora() -> void:
	# bonus 1.0 -> soglia clampata a 1.0 -> randf() >= 1.0 non capita: successo certo
	assert_true(_ps().call("doma", "lupo_cinereo", 1.0), "doma riuscita")
	assert_eq(str((_ps().call("pet_attivo") as Dictionary)["pet_id"]), "lupo_cinereo",
		"pet impostato")
	assert_true((_anc().call("active") as Array).has("anchor_pet"),
		"l'Ancora del pet e' attiva")


func test_doma_fallita_non_lascia_nulla() -> void:
	# bonus -1.0 -> soglia 0.0 -> randf() >= 0.0 sempre: fallimento certo
	assert_false(_ps().call("doma", "corvo_veggente", -1.0), "doma fallita")
	assert_false(_ps().call("ha_pet"), "nessun pet")
	assert_false((_anc().call("active") as Array).has("anchor_pet"), "nessuna Ancora")


func test_rng_seedabile_e_deterministico() -> void:
	_ps().call("imposta_seed", 12345)
	var primo: bool = _ps().call("doma", "corvo_veggente")  # domabilita 0.5, nessun bonus
	_ps().call("pulisci")
	_ps().call("imposta_seed", 12345)
	var secondo: bool = _ps().call("doma", "corvo_veggente")
	assert_eq(primo, secondo, "stesso seed -> stesso esito")


func test_un_solo_pet_per_volta() -> void:
	assert_true(_ps().call("doma", "lupo_cinereo", 1.0), "primo taming ok")
	assert_false(_ps().call("doma", "corvo_veggente", 1.0),
		"secondo taming bloccato finche' non liberi")
	assert_eq(str((_ps().call("pet_attivo") as Dictionary)["pet_id"]), "lupo_cinereo",
		"resta il primo pet")


func test_libera_rilascia_l_ancora_senza_colpo_di_follia() -> void:
	_ps().call("doma", "lupo_cinereo", 1.0)
	var follia_prima: float = float(_madness().call("valore")) if _madness() != null else 0.0
	_ps().call("libera")
	assert_false(_ps().call("ha_pet"), "pet liberato")
	assert_false((_anc().call("active") as Array).has("anchor_pet"),
		"Ancora rilasciata")
	if _madness() != null:
		assert_almost_eq(float(_madness().call("valore")), follia_prima,
			"liberare NON aggiunge follia (non e' la morte del pet)")
	# e ora si puo' domare di nuovo
	assert_true(_ps().call("doma", "corvo_veggente", 1.0), "dopo libera() si doma un altro")
