extends "res://tests/test_case.gd"
## US-323 — bond: il legame cresce dalle azioni condivise.


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/PetSystem") != null:
		_n("/root/PetSystem").call("pulisci")
	if _n("/root/EventTracker") != null:
		_n("/root/EventTracker").call("azzera")


func test_enemy_defeated_fa_salire_il_bond() -> void:
	var ps: Node = _n("/root/PetSystem")
	ps.call("imposta_pet", "lupo_ombra")
	var b0: float = ps.call("bond")
	_n("/root/EventTracker").call("emit_event", "enemy_defeated", {})
	assert_almost_eq(ps.call("bond"), b0 + 2.0, "bond_per_enemy_defeated (balance.json.pet)")


func test_area_cleared_fa_salire_il_bond() -> void:
	var ps: Node = _n("/root/PetSystem")
	ps.call("imposta_pet", "corvo_predittivo")
	var b0: float = ps.call("bond")
	_n("/root/EventTracker").call("emit_event", "area_cleared", {})
	assert_almost_eq(ps.call("bond"), b0 + 5.0, "bond_per_area_cleared")


func test_time_in_state_esplorazione_fa_salire_solo_con_quello_stato() -> void:
	var ps: Node = _n("/root/PetSystem")
	ps.call("imposta_pet", "lupo_ombra")
	_n("/root/EventTracker").call("emit_event", "time_in_state", {"stato": "meditazione"})
	assert_almost_eq(ps.call("bond"), 0.0, "un altro stato non conta")
	_n("/root/EventTracker").call("emit_event", "time_in_state", {"stato": "esplorazione"})
	assert_almost_eq(ps.call("bond"), 0.1, "bond_per_time_in_state_esplorazione")


func test_senza_pet_attivo_nessun_crash_ne_bond() -> void:
	_n("/root/EventTracker").call("emit_event", "enemy_defeated", {})
	assert_true(_n("/root/PetSystem").call("pet_attivo").is_empty(), "ancora nessun pet, nessun crash")


func test_soglia_di_bond_sblocca_comportamento_ed_emette_segnale() -> void:
	var ps: Node = _n("/root/PetSystem")
	ps.call("imposta_pet", "lupo_ombra")   # soglia_bond 20 -> fiuto_base
	var visto: Dictionary = {"soglia": -99}
	var cb := func(_v: float, soglia: int) -> void:
		if soglia != -1:
			visto["soglia"] = soglia
	ps.bond_cambiato.connect(cb)

	for i in 9:   # 9 * 2.0 = 18, sotto 20
		_n("/root/EventTracker").call("emit_event", "enemy_defeated", {})
	assert_false((ps.call("comportamenti_sbloccati") as Array).has("fiuto_base"), "ancora sotto soglia")
	assert_eq(visto["soglia"], -99, "nessun segnale ancora")

	_n("/root/EventTracker").call("emit_event", "enemy_defeated", {})   # -> 20, tocca la soglia
	assert_true((ps.call("comportamenti_sbloccati") as Array).has("fiuto_base"), "sbloccato a soglia 20")
	assert_eq(visto["soglia"], 20, "segnale con la soglia attraversata")


func test_bond_persiste_nel_save() -> void:
	var ps: Node = _n("/root/PetSystem")
	ps.call("imposta_pet", "corvo_predittivo")
	_n("/root/EventTracker").call("emit_event", "area_cleared", {})
	var b0: float = ps.call("bond")
	var snap: Dictionary = ps.call("per_salvataggio")
	ps.call("pulisci")
	ps.call("da_salvataggio", snap)
	assert_almost_eq(ps.call("bond"), b0, "bond preservato dal round-trip")
