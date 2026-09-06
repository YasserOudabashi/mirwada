extends "res://tests/test_case.gd"
## US-321 — schema e magazzino dei pet: caricamento, imposta/leggi, round-trip
## del save. Taming (US-322), bond dagli eventi (US-323) e coltivazione
## (US-324) sono story successive.

const SLOT := 904


func _ps() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("PetSystem")


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SaveSystem")


func prepara() -> void:
	if _ps() != null:
		_ps().call("pulisci")


func test_le_specie_si_caricano_dai_dati() -> void:
	assert_false((_gd().call("get_pet", "lupo_cinereo") as Dictionary).is_empty(),
		"lupo_cinereo caricato")
	assert_true((_gd().call("pet_ids") as Array).size() >= 2, "almeno 2 specie")


func test_ogni_pet_e_un_ancora_esistente() -> void:
	for pid in _gd().call("pet_ids"):
		var anc: String = str((_gd().call("get_pet", pid) as Dictionary).get("ancora_id", ""))
		assert_false((_gd().call("get_anchor", anc) as Dictionary).is_empty(),
			"ancora_id di '%s' risolve" % pid)


func test_nessun_pet_di_default() -> void:
	assert_false(_ps().call("ha_pet"), "nessun pet all'avvio")
	assert_eq(_ps().call("pet_attivo"), {}, "pet_attivo() vuoto")
	assert_eq(_ps().call("sequenza_pet"), -1, "sequenza_pet() = -1 senza pet")


func test_imposta_pet_prende_i_valori_dalla_specie() -> void:
	assert_true(_ps().call("imposta_pet", "lupo_cinereo"), "imposta_pet ok")
	var p: Dictionary = _ps().call("pet_attivo")
	assert_eq(str(p["pet_id"]), "lupo_cinereo", "pet_id giusto")
	assert_eq(int(p["bond"]), 0, "bond parte da 0")
	assert_eq(float(p["hp"]), 60.0, "hp = hp_max della specie")
	assert_eq(int(p["sequenza"]), 9, "sequenza = sequenza_iniziale")
	assert_eq(_ps().call("bond"), 0, "bond() concorda")
	assert_eq(_ps().call("sequenza_pet"), 9, "sequenza_pet() concorda")


func test_specie_sconosciuta_non_cambia_nulla() -> void:
	_ps().call("imposta_pet", "corvo_veggente")
	assert_false(_ps().call("imposta_pet", "grifone_inventato"), "specie ignota -> false")
	assert_eq(str((_ps().call("pet_attivo") as Dictionary)["pet_id"]), "corvo_veggente",
		"il pet precedente resta")


func test_libera_azzera_il_pet() -> void:
	_ps().call("imposta_pet", "lupo_cinereo")
	_ps().call("libera")
	assert_false(_ps().call("ha_pet"), "dopo libera() nessun pet")


func test_round_trip_del_save() -> void:
	var s: Node = _save()
	if s.esiste(SLOT):
		s.cancella(SLOT)
	_ps().call("imposta_pet", "corvo_veggente")
	var snap: Dictionary = {"nome_personaggio": "Enel", "pet": _ps().call("per_salvataggio")}
	assert_true(s.salva(SLOT, snap)["ok"], "salva ok")

	_ps().call("pulisci")
	assert_false(_ps().call("ha_pet"), "pet azzerato")

	var caricato: Dictionary = s.carica(SLOT)
	_ps().call("da_salvataggio", (caricato["dati"] as Dictionary)["pet"])
	assert_eq(str((_ps().call("pet_attivo") as Dictionary)["pet_id"]), "corvo_veggente",
		"pet ripristinato dal save")
	s.cancella(SLOT)


func test_da_salvataggio_scarta_i_dati_malformati() -> void:
	_ps().call("da_salvataggio", {"pet_id": "specie_sparita", "bond": 50})
	assert_false(_ps().call("ha_pet"), "specie non nei dati -> nessun pet")

	_ps().call("da_salvataggio", "niente dizionario")
	assert_false(_ps().call("ha_pet"), "raw non-oggetto -> nessun pet, nessun crash")

	_ps().call("da_salvataggio", {"pet_id": "lupo_cinereo", "bond": 999, "sequenza": 42})
	var p: Dictionary = _ps().call("pet_attivo")
	assert_eq(int(p["bond"]), 100, "bond clampato a 100")
	assert_eq(int(p["sequenza"]), 9, "sequenza clampata a 0..9")


func test_migrazione_da_v16_aggiunge_il_pet_vuoto() -> void:
	var s: Node = _save()
	if s.esiste(SLOT):
		s.cancella(SLOT)
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open("user://saves/slot_%d.json" % SLOT, FileAccess.WRITE)
	f.store_string('{"schema_version": 16, "nome_personaggio": "v16", "posizione": [0, 0], "statistiche": {}}')
	f.close()

	var c: Dictionary = s.carica(SLOT)
	assert_true(c["ok"] and c["migrato"], "migrazione applicata")
	assert_eq((c["dati"] as Dictionary)["pet"], {}, "campo pet aggiunto vuoto")
	s.cancella(SLOT)
