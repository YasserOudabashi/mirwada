extends "res://tests/test_case.gd"
## US-325 — la morte del pet e' la perdita di un'Ancora, un colpo vero.


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/PetSystem") != null:
		_n("/root/PetSystem").call("pulisci")
	if _n("/root/AnchorSystem") != null:
		_n("/root/AnchorSystem").call("pulisci")
	if _n("/root/SummonRegistry") != null:
		_n("/root/SummonRegistry").call("pulisci")
	if _n("/root/Madness") != null:
		_n("/root/Madness").call("azzera")


func test_morte_distrugge_lancora_e_aggiunge_follia() -> void:
	var ps: Node = _n("/root/PetSystem")
	var anc: Node = _n("/root/AnchorSystem")
	var madness: Node = _n("/root/Madness")
	ps.call("imposta_pet", "lupo_ombra")
	anc.call("register", "anchor_pet_lupo_ombra")
	var f0: float = madness.call("valore")

	assert_true(ps.call("morte"), "morte riesce")
	assert_false((anc.call("active") as Array).has("anchor_pet_lupo_ombra"), "l'Ancora e' distrutta")
	assert_gt(madness.call("valore"), f0, "la follia sale - un colpo vero, non bufferizzato")


func test_morte_svuota_il_pet_attivo() -> void:
	var ps: Node = _n("/root/PetSystem")
	ps.call("imposta_pet", "corvo_predittivo")
	assert_true(ps.call("morte"))
	assert_true((ps.call("pet_attivo") as Dictionary).is_empty(), "pet_attivo() torna {}")


func test_morte_rimuove_levocazione() -> void:
	var ps: Node = _n("/root/PetSystem")
	var reg: Node = _n("/root/SummonRegistry")
	ps.call("imposta_pet", "lupo_ombra")
	# simula quello che doma() farebbe: registra un'evocazione persistente
	var sid: String = reg.call("evoca", "lupo_ombra", "alleato", Vector2.ZERO, 40.0)
	# inietta il summon_id nello stato del pet come farebbe doma()
	ps.call("da_salvataggio", {"pet_id": "lupo_ombra", "bond": 0.0, "sequenza": 9, "summon_id": sid})
	assert_eq(reg.call("conta"), 1, "premessa: un'evocazione attiva")

	ps.call("morte")
	assert_eq(reg.call("conta"), 0, "l'evocazione del pet e' rimossa alla morte")


func test_morte_senza_pet_fallisce() -> void:
	assert_false(_n("/root/PetSystem").call("morte"), "niente da far morire -> false")


func test_pet_morto_non_persiste_nel_save() -> void:
	var ps: Node = _n("/root/PetSystem")
	ps.call("imposta_pet", "lupo_ombra")
	ps.call("morte")
	var snap: Dictionary = ps.call("per_salvataggio")
	assert_true(snap.is_empty(), "lo slot pet del save e' vuoto dopo la morte")
	ps.call("da_salvataggio", snap)
	assert_true((ps.call("pet_attivo") as Dictionary).is_empty(), "e non si ricrea al load")


func test_lancora_del_pet_morto_non_e_piu_nei_sussurri() -> void:
	# AnchorSystem._aggiorna_nomi_sussurro gira dentro destroy(): se
	# AudioManager e' assente (come nei test) non fa nulla di osservabile
	# qui, ma l'Ancora deve comunque sparire da active() - i sussurri
	# leggono SOLO active(), quindi non hanno piu' nulla da pronunciare.
	var ps: Node = _n("/root/PetSystem")
	var anc: Node = _n("/root/AnchorSystem")
	ps.call("imposta_pet", "corvo_predittivo")
	anc.call("register", "anchor_pet_corvo")
	ps.call("morte")
	assert_false((anc.call("active") as Array).has("anchor_pet_corvo"),
		"l'Ancora del pet morto non e' piu' fra quelle attive: nessun sussurro la nominera'")
