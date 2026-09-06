extends "res://tests/test_case.gd"
## US-319 — StructureRegistry: il registro comune fra base building (crea) e
## tg_2 (distrugge). Le istanze sopravvivono al salvataggio.

const SLOT := 903


func _reg() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("StructureRegistry")


func _eventi() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("EventTracker")


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SaveSystem")


func prepara() -> void:
	if _reg() != null:
		_reg().call("pulisci")
	if _eventi() != null:
		_eventi().call("azzera")


func test_costruisci_rende_la_struttura_attiva() -> void:
	var iid: String = _reg().call("costruisci", "palizzata", Vector2(10, 20))
	assert_ne(iid, "", "costruisci restituisce un instance_id")
	assert_eq(_reg().call("conta"), 1, "una struttura attiva")
	var att: Array = _reg().call("attive")
	assert_eq(str((att[0] as Dictionary)["struct_id"]), "palizzata", "tipo giusto")
	assert_eq(float((att[0] as Dictionary)["hp"]), 40.0, "hp iniziale = hp_max dai dati")


func test_struct_id_sconosciuto_non_crea_nulla() -> void:
	var iid: String = _reg().call("costruisci", "non_esiste", Vector2.ZERO)
	assert_eq(iid, "", "struct_id ignoto -> instance_id vuoto")
	assert_eq(_reg().call("conta"), 0, "nessuna struttura creata")


func test_danneggia_fino_a_zero_distrugge_ed_emette_evento() -> void:
	var iid: String = _reg().call("costruisci", "totem_veglia", Vector2.ZERO)  # hp_max 25
	_reg().call("danneggia", iid, 10.0)
	assert_eq(_reg().call("conta"), 1, "a hp>0 la struttura resta")
	_reg().call("danneggia", iid, 20.0)
	assert_eq(_reg().call("conta"), 0, "portata a <= 0 -> distrutta")
	assert_eq(_eventi().call("count", "structure_destroyed"), 1.0, "un evento structure_destroyed")
	assert_eq(_eventi().call("count", "structure_destroyed", {"volontario": true}), 0.0,
		"il crollo NON e' volontario")


func test_distruggi_volontario_e_contato_col_filtro() -> void:
	var iid: String = _reg().call("costruisci", "deposito", Vector2.ZERO)
	assert_true(_reg().call("distruggi", iid, true), "distruggi trova la struttura")
	assert_eq(_eventi().call("count", "structure_destroyed", {"volontario": true}), 1.0,
		"structure_destroyed{volontario:true} contato (alimenta tg_2_accetta_decadimento)")


func test_in_raggio_filtra_per_distanza() -> void:
	_reg().call("costruisci", "palizzata", Vector2(0, 0))
	_reg().call("costruisci", "palizzata", Vector2(100, 0))
	var vicine: Array = _reg().call("in_raggio", Vector2(0, 0), 50.0)
	assert_eq(vicine.size(), 1, "solo la struttura entro 50px")


func test_round_trip_del_save() -> void:
	var s: Node = _save()
	if s.esiste(SLOT):
		s.cancella(SLOT)
	_reg().call("costruisci", "palizzata", Vector2(5, 5))
	_reg().call("danneggia", _reg().call("attive")[0]["id"], 15.0)  # hp 40 -> 25

	var snap: Dictionary = {"nome_personaggio": "Enel", "strutture": _reg().call("per_salvataggio")}
	assert_true(s.salva(SLOT, snap)["ok"], "salva ok")
	_reg().call("pulisci")
	assert_eq(_reg().call("conta"), 0, "registro azzerato")

	var caricato: Dictionary = s.carica(SLOT)
	_reg().call("da_salvataggio", (caricato["dati"] as Dictionary)["strutture"])
	assert_eq(_reg().call("conta"), 1, "struttura ripristinata dal save")
	assert_eq(float(_reg().call("attive")[0]["hp"]), 25.0, "hp danneggiato ripristinato")
	s.cancella(SLOT)


func test_da_salvataggio_scarta_le_voci_malformate() -> void:
	_reg().call("da_salvataggio", [
		{"id": "str_1", "struct_id": "palizzata", "posizione": [1, 2], "hp": 30},
		{"id": "str_2", "posizione": [0, 0]},              # manca struct_id
		{"id": "str_3", "struct_id": "tipo_sparito", "posizione": [0, 0]},  # tipo assente dai dati
		"non un oggetto",
	])
	assert_eq(_reg().call("conta"), 1, "solo la voce valida sopravvive")

	_reg().call("da_salvataggio", "niente lista")
	assert_eq(_reg().call("conta"), 0, "raw non-lista -> vuoto, nessun crash")


func test_migrazione_da_v15_aggiunge_le_strutture() -> void:
	var s: Node = _save()
	if s.esiste(SLOT):
		s.cancella(SLOT)
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open("user://saves/slot_%d.json" % SLOT, FileAccess.WRITE)
	f.store_string('{"schema_version": 15, "nome_personaggio": "v15", "posizione": [0, 0], "statistiche": {}}')
	f.close()

	var c: Dictionary = s.carica(SLOT)
	assert_true(c["ok"] and c["migrato"], "migrazione applicata")
	assert_eq((c["dati"] as Dictionary)["strutture"], [], "campo strutture aggiunto vuoto")
	s.cancella(SLOT)
