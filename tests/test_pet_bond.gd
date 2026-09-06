extends "res://tests/test_case.gd"
## US-323 — bond: sale ascoltando EventTracker mentre hai un pet, a soglia
## (per specie) sblocca i comportamenti, persiste nel save.

const SLOT := 905


func _ps() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("PetSystem")


func _et() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("EventTracker")


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SaveSystem")


func prepara() -> void:
	if _ps() != null:
		_ps().call("pulisci")
	if _et() != null:
		_et().call("azzera")


func test_eventi_condivisi_alzano_il_bond() -> void:
	_ps().call("imposta_pet", "lupo_cinereo")
	_et().call("emit_event", "enemy_defeated", {})
	_et().call("emit_event", "enemy_defeated", {})
	assert_eq(_ps().call("bond"), 4, "2 nemici * peso 2 = bond 4")
	_et().call("emit_event", "area_cleared", {})
	assert_eq(_ps().call("bond"), 16, "+12 per l'area completata")


func test_eventi_non_pertinenti_non_toccano_il_bond() -> void:
	_ps().call("imposta_pet", "lupo_cinereo")
	_et().call("emit_event", "ability_used", {"ability_id": "tg_crepuscolo"})
	assert_eq(_ps().call("bond"), 0, "ability_used non conta per il legame")


func test_senza_pet_gli_eventi_non_fanno_nulla() -> void:
	_et().call("emit_event", "enemy_defeated", {})
	assert_false(_ps().call("ha_pet"), "nessun pet, nessun crash")


func test_a_soglia_si_sblocca_un_comportamento_e_scatta_il_segnale() -> void:
	_ps().call("imposta_pet", "lupo_cinereo")  # difendi@35, assalto_coordinato@70
	var visti: Array = []
	_ps().connect("bond_cambiato", func(v: int, comp: String) -> void:
		visti.append([v, comp]))

	_ps().call("imposta_bond", 34)
	assert_true((_ps().call("comportamenti_sbloccati") as Array).is_empty(),
		"a bond 34 nessun comportamento (difendi e' a 35)")

	_et().call("emit_event", "area_cleared", {})  # 34 -> 46, attraversa 35
	assert_true((_ps().call("comportamenti_sbloccati") as Array).has("difendi"),
		"a bond 46 'difendi' e' sbloccato")
	var ultimo: Array = visti[visti.size() - 1]
	assert_eq(int(ultimo[0]), 46, "segnale col valore nuovo")
	assert_eq(str(ultimo[1]), "difendi", "segnale con la soglia attraversata")


func test_nessuna_soglia_attraversata_segnale_con_stringa_vuota() -> void:
	_ps().call("imposta_pet", "lupo_cinereo")
	var comp_visti: Array = []
	_ps().connect("bond_cambiato", func(_v: int, comp: String) -> void:
		comp_visti.append(comp))
	_et().call("emit_event", "enemy_defeated", {})  # 0 -> 2, nessuna soglia
	assert_eq(str(comp_visti[0]), "", "nessun comportamento attraversato")


func test_il_bond_persiste_nel_save() -> void:
	var s: Node = _save()
	if s.esiste(SLOT):
		s.cancella(SLOT)
	_ps().call("imposta_pet", "corvo_veggente")
	_ps().call("imposta_bond", 42)
	var snap: Dictionary = {"nome_personaggio": "Enel", "pet": _ps().call("per_salvataggio")}
	s.salva(SLOT, snap)
	_ps().call("pulisci")

	var caricato: Dictionary = s.carica(SLOT)
	_ps().call("da_salvataggio", (caricato["dati"] as Dictionary)["pet"])
	assert_eq(_ps().call("bond"), 42, "bond ripristinato dal save")
	s.cancella(SLOT)
