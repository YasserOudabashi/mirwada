extends "res://tests/test_case.gd"
## US-601/602 — le regioni sono dati caricati da GameData; WorldState tiene la
## regione corrente + le scoperte + i gate aperti e li serializza; il save
## migra da v20 a v21 aggiungendo i campi del mondo di fase 6.

const SLOT := 901


func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")
func _ws() -> Node: return _root().get_node("WorldState")
func _save() -> Node: return _root().get_node("SaveSystem")


func _scrivi_grezzo(testo: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open("user://saves/slot_%d.json" % SLOT, FileAccess.WRITE)
	f.store_string(testo)
	f.close()


func _pulisci_slot() -> void:
	if _save().esiste(SLOT):
		_save().cancella(SLOT)


func test_gamedata_carica_le_5_regioni() -> void:
	var regs: Array = _gd().call("get_regions")
	assert_eq(regs.size(), 5, "5 regioni caricate da data/world/regions.json")
	var mirwada: Dictionary = _gd().call("get_region", "mirwada")
	assert_false(mirwada.is_empty(), "get_region('mirwada') risolve")
	assert_eq(str(mirwada.get("group_affinity")), "neutra", "Mirwada e' la citta' neutra")
	assert_true(mirwada.get("location_tags", []).size() > 0, "Mirwada ha location_tags")
	assert_true(_gd().call("get_region", "nonesiste").is_empty(), "id ignoto -> {}")


func test_worldstate_regione_corrente_e_scoperte() -> void:
	var ws: Node = _ws()
	ws.call("pulisci")
	assert_eq(str(ws.call("regione_corrente")), "", "al boot nessuna regione")
	var visti: Array = []
	var cb := func(id: String) -> void: visti.append(id)
	ws.connect("regione_cambiata", cb)
	ws.call("entra_regione", "mirwada")
	ws.call("entra_regione", "mirwada")  # idempotente: nessun secondo segnale
	ws.disconnect("regione_cambiata", cb)
	assert_eq(str(ws.call("regione_corrente")), "mirwada", "regione corrente impostata")
	assert_true(ws.call("e_scoperta", "mirwada"), "mirwada e' fra le scoperte")
	assert_eq(visti.size(), 1, "regione_cambiata emesso una sola volta")
	ws.call("pulisci")


func test_worldstate_round_trip_del_mondo() -> void:
	var ws: Node = _ws()
	ws.call("pulisci")
	ws.call("entra_regione", "mirwada")
	ws.call("entra_regione", "marche_crepuscolo")
	ws.call("apri_gate", "cripta_nord")
	var snap: Dictionary = ws.call("per_salvataggio")
	ws.call("pulisci")
	ws.call("da_salvataggio", snap)
	assert_eq(str(ws.call("regione_corrente")), "marche_crepuscolo", "regione round-trip")
	assert_true(ws.call("e_scoperta", "mirwada"), "scoperta precedente conservata")
	assert_true(ws.call("gate_e_aperto", "cripta_nord"), "gate aperto conservato")
	ws.call("pulisci")


func test_da_salvataggio_non_fidato() -> void:
	var ws: Node = _ws()
	ws.call("pulisci")
	# tipi sbagliati: regione come numero, scoperte come stringa, gate come dict
	ws.call("da_salvataggio", {"regione": 42, "scoperte": "mirwada", "gate_aperti": {}})
	assert_eq(str(ws.call("regione_corrente")), "", "regione malformata -> vuota")
	assert_eq((ws.call("scoperte") as Array).size(), 0, "scoperte malformate -> vuote")
	ws.call("pulisci")


func test_migrazione_save_v20_a_v21() -> void:
	_pulisci_slot()
	# un save v20 non ha i campi regione/scoperte/gate_aperti in "mondo"
	_scrivi_grezzo('{"schema_version": 20, "nome_personaggio": "vecchio", "tempo_gioco": 5.0, "mondo": {"terrain_mods": []}}')
	var c: Dictionary = _save().call("carica", SLOT)
	assert_true(c["ok"], "carica ok dopo migrazione")
	assert_true(c["migrato"], "flag migrato")
	assert_eq(int((c["dati"] as Dictionary)["schema_version"]), _save().VERSIONE_CORRENTE, "portato a v21")
	var mondo: Dictionary = (c["dati"] as Dictionary)["mondo"]
	assert_eq(str(mondo.get("regione")), "", "campo mondo.regione aggiunto vuoto")
	assert_eq((mondo.get("scoperte") as Array), [], "campo mondo.scoperte aggiunto vuoto")
	assert_eq((mondo.get("gate_aperti") as Array), [], "campo mondo.gate_aperti aggiunto vuoto")
	_pulisci_slot()
