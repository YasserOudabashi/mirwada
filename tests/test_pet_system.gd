extends "res://tests/test_case.gd"
## US-321 — schema e magazzino dei pet.


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/PetSystem") != null:
		_n("/root/PetSystem").call("pulisci")


func test_vocabolario_pet_caricato() -> void:
	var gd: Node = _n("/root/GameData")
	assert_gt(float((gd.call("pet_species_ids") as Array).size()), 0.0, "almeno una specie di pet")
	var lupo: Dictionary = gd.call("get_pet_species", "lupo_ombra")
	assert_false(lupo.is_empty(), "lupo_ombra esiste")
	assert_eq(lupo.get("ancora_id"), "anchor_pet_lupo_ombra", "ancora_id del lupo")
	assert_false(gd.call("get_anchor", "anchor_pet_lupo_ombra").is_empty(),
		"il pet E' un'Ancora: risolve in data/anchors.json")


func test_nessun_pet_di_default() -> void:
	assert_true(_n("/root/PetSystem").call("pet_attivo").is_empty(), "nessun pet all'avvio")
	assert_eq(_n("/root/PetSystem").call("sequenza_pet"), -1, "-1 senza pet")
	assert_almost_eq(_n("/root/PetSystem").call("bond"), 0.0, "bond 0 senza pet")


func test_imposta_pet() -> void:
	var ps: Node = _n("/root/PetSystem")
	assert_true(ps.call("imposta_pet", "lupo_ombra"), "imposta un lupo")
	var p: Dictionary = ps.call("pet_attivo")
	assert_eq(p.get("pet_id"), "lupo_ombra", "specie corretta")
	assert_almost_eq(float(p.get("hp")), 40.0, "hp = hp_max della specie")
	assert_eq(int(p.get("sequenza")), 8, "sequenza_iniziale della specie")
	assert_eq(ps.call("sequenza_pet"), 8, "sequenza_pet legge lo stato")


func test_specie_ignota_non_imposta() -> void:
	var ps: Node = _n("/root/PetSystem")
	assert_false(ps.call("imposta_pet", "drago_inventato"), "specie ignota -> false")
	assert_true(ps.call("pet_attivo").is_empty(), "nessun pet impostato")


func test_round_trip_del_save() -> void:
	var ps: Node = _n("/root/PetSystem")
	ps.call("imposta_pet", "corvo_predittivo")
	var snap: Dictionary = ps.call("per_salvataggio")
	ps.call("pulisci")
	assert_true(ps.call("pet_attivo").is_empty(), "svuotato")
	ps.call("da_salvataggio", snap)
	var p: Dictionary = ps.call("pet_attivo")
	assert_eq(p.get("pet_id"), "corvo_predittivo", "specie tornata dal save")
	assert_almost_eq(float(p.get("hp")), 22.0, "hp preservato")


func test_da_salvataggio_non_fidato() -> void:
	var ps: Node = _n("/root/PetSystem")
	ps.call("da_salvataggio", "non un oggetto")
	assert_true(ps.call("pet_attivo").is_empty(), "raw non-oggetto -> nessun pet")
	ps.call("da_salvataggio", {"pet_id": "specie_inventata"})
	assert_true(ps.call("pet_attivo").is_empty(), "pet_id ignoto -> nessun pet")
