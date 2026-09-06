extends "res://tests/test_case.gd"
## US-326 — schema della base e delle 4 stanze: costruisci / potenzia / bonus /
## round-trip del save.

const SLOT := 908


func _bs() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("BaseSystem")


func _inv() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Inventory")


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SaveSystem")


func prepara() -> void:
	if _bs() != null:
		_bs().call("pulisci")
	if _inv() != null:
		_inv().call("pulisci")


func _rifornisci(costo: Dictionary) -> void:
	for item_id in costo:
		_inv().call("aggiungi", item_id, int(costo[item_id]))


func test_i_4_tipi_sono_un_vocabolario_chiuso() -> void:
	var tipi: Array = _gd().call("room_type_ids")
	assert_eq(tipi.size(), 4, "4 tipi di stanza")
	for t in ["laboratorio", "stanza_rituale", "biblioteca", "giardino"]:
		assert_true(tipi.has(t), "'%s' fra i tipi" % t)
		assert_false((_gd().call("room_levels", t) as Array).is_empty(),
			"'%s' ha livelli nei dati" % t)


func test_costruisci_porta_al_livello_1_e_consuma_il_costo() -> void:
	var costo: Dictionary = _bs().call("costo_prossimo", "laboratorio")
	_rifornisci(costo)
	_inv().call("aggiungi", "lingotto_ferro", 2)  # margine
	assert_true(_bs().call("costruisci", "laboratorio"), "costruita")
	assert_eq(_bs().call("livello", "laboratorio"), 1, "livello 1")
	assert_eq(int(_inv().call("conta", "lingotto_ferro")), 2, "consumato il costo, resta il margine")


func test_costo_non_coperto_non_costruisce_nulla() -> void:
	assert_false(_bs().call("costruisci", "laboratorio"), "senza materiali -> false")
	assert_eq(_bs().call("livello", "laboratorio"), 0, "non costruita")


func test_non_si_ricostruisce_una_stanza_gia_costruita() -> void:
	_rifornisci(_bs().call("costo_prossimo", "biblioteca"))
	_bs().call("costruisci", "biblioteca")
	assert_false(_bs().call("costruisci", "biblioteca"), "gia' costruita -> false")


func test_tipo_sconosciuto() -> void:
	assert_false(_bs().call("costruisci", "torre_astronomica"), "tipo ignoto -> false")


func test_potenzia_sale_di_livello_e_aggiorna_il_bonus() -> void:
	_rifornisci(_bs().call("costo_prossimo", "laboratorio"))
	_bs().call("costruisci", "laboratorio")
	var b1: Dictionary = _bs().call("bonus", "laboratorio")
	assert_eq(b1.size(), 1, "il livello 1 ha una sola chiave di bonus")
	assert_almost_eq(float(b1.get("rischio_esperimento", 0.0)), -10.0, "rischio del livello 1")

	_rifornisci(_bs().call("costo_prossimo", "laboratorio"))
	assert_true(_bs().call("potenzia", "laboratorio"), "potenziata")
	assert_eq(_bs().call("livello", "laboratorio"), 2, "livello 2")
	var b: Dictionary = _bs().call("bonus", "laboratorio")
	assert_almost_eq(float(b.get("rischio_esperimento", 0.0)), -20.0, "rischio del livello 2 (punti %)")
	assert_eq(int(b.get("qualita_pozione", 0)), 1, "qualita_pozione del livello 2")


func test_potenzia_richiede_una_stanza_costruita() -> void:
	assert_false(_bs().call("potenzia", "giardino"), "non costruita -> potenzia false")


func test_potenzia_bloccata_al_livello_massimo() -> void:
	for _i in 2:
		_rifornisci(_bs().call("costo_prossimo", "stanza_rituale"))
		if _bs().call("livello", "stanza_rituale") == 0:
			_bs().call("costruisci", "stanza_rituale")
		else:
			_bs().call("potenzia", "stanza_rituale")
	assert_eq(_bs().call("livello", "stanza_rituale"), 2, "al massimo (2 livelli nei dati)")
	assert_eq(_bs().call("costo_prossimo", "stanza_rituale"), {}, "nessun costo oltre il massimo")
	assert_false(_bs().call("potenzia", "stanza_rituale"), "gia' al massimo -> false")


func test_bonus_di_una_stanza_non_costruita_e_vuoto() -> void:
	assert_eq(_bs().call("bonus", "giardino"), {}, "stanza non costruita -> bonus {}")


func test_da_salvataggio_scarta_i_dati_malformati() -> void:
	_bs().call("da_salvataggio", {
		"laboratorio": 2,
		"stanza_inventata": 3,
		"biblioteca": "NaN",
		"giardino": 99,
	})
	assert_eq(_bs().call("livello", "laboratorio"), 2, "livello valido tenuto")
	assert_eq(_bs().call("livello", "stanza_inventata"), 0, "tipo ignoto scartato")
	assert_eq(_bs().call("livello", "biblioteca"), 0, "livello non numerico scartato")
	assert_eq(_bs().call("livello", "giardino"), 2, "livello oltre il massimo clampato al massimo")

	_bs().call("da_salvataggio", "niente dizionario")
	assert_eq(_bs().call("stanze"), {}, "raw non-oggetto -> base vuota, nessun crash")


func test_round_trip_del_save() -> void:
	var s: Node = _save()
	if s.esiste(SLOT):
		s.cancella(SLOT)
	_rifornisci(_bs().call("costo_prossimo", "biblioteca"))
	_bs().call("costruisci", "biblioteca")
	var snap: Dictionary = {"nome_personaggio": "Enel", "base": _bs().call("per_salvataggio")}
	s.salva(SLOT, snap)
	_bs().call("pulisci")
	assert_eq(_bs().call("livello", "biblioteca"), 0, "base azzerata")

	var caricato: Dictionary = s.carica(SLOT)
	_bs().call("da_salvataggio", (caricato["dati"] as Dictionary)["base"])
	assert_eq(_bs().call("livello", "biblioteca"), 1, "biblioteca ripristinata dal save")
	s.cancella(SLOT)


func test_migrazione_da_v17_aggiunge_la_base_vuota() -> void:
	var s: Node = _save()
	if s.esiste(SLOT):
		s.cancella(SLOT)
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open("user://saves/slot_%d.json" % SLOT, FileAccess.WRITE)
	f.store_string('{"schema_version": 17, "nome_personaggio": "v17", "posizione": [0, 0], "statistiche": {}}')
	f.close()
	var c: Dictionary = s.carica(SLOT)
	assert_true(c["ok"] and c["migrato"], "migrazione applicata")
	assert_eq((c["dati"] as Dictionary)["base"], {}, "campo base aggiunto vuoto")
	s.cancella(SLOT)
