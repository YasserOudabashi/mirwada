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


## US-1002B (fase 10, mondo continuo): non c'e' piu' una scena per regione -
## world_scene.gd le dipinge tutte nello stesso nodo, ognuna con un confine
## (Area2D grande quanto il suo rettangolo) che registra WorldState quando
## il giocatore lo attraversa (qui: chiamata diretta all'handler, stesso
## pattern gia' in uso nel resto della suite per bypassare la fisica reale
## nei test headless - vedi tests/test_world_scene.gd).
func test_ogni_regione_ha_un_confine_e_si_registra() -> void:
	var ws: Node = _ws()
	ws.call("pulisci")
	var cont := Node2D.new()
	_root().add_child(cont)
	var player := Node2D.new()
	player.name = "Player"
	player.add_to_group("player")
	cont.add_child(player)
	var mondo: Node = load("res://scenes/world_scene.tscn").instantiate()
	cont.add_child(mondo)

	for r in _gd().call("get_regions"):
		var rid: String = str((r as Dictionary).get("id", ""))
		var confine: Node = mondo.get_node_or_null("Confine_%s" % rid)
		assert_false(confine == null, "la regione '%s' ha un confine nel mondo continuo" % rid)
		mondo.call("_su_ingresso_regione", player, rid)
		assert_eq(str(ws.call("regione_corrente")), rid,
			"attraversare il confine di '%s' registra la regione corrente" % rid)

	cont.free()
	ws.call("pulisci")


## Nel mondo continuo ogni regione e' raggiungibile a piedi da ogni altra
## (world_scene.gd::passaggi_verso, US-1002B): non esiste piu' un elenco di
## "passaggi" discreti per singola regione, hub-and-spoke o meno.
func test_passaggi_verso_elenca_tutte_le_regioni() -> void:
	var cont := Node2D.new()
	_root().add_child(cont)
	var mondo: Node = load("res://scenes/world_scene.tscn").instantiate()
	cont.add_child(mondo)

	var ids_attesi: Array = []
	for r in _gd().call("get_regions"):
		ids_attesi.append(str((r as Dictionary).get("id", "")))
	var raggiungibili: Array = mondo.call("passaggi_verso")
	assert_eq(raggiungibili.size(), ids_attesi.size(), "tutte le regioni sono raggiungibili")
	for rid in ids_attesi:
		assert_true(raggiungibili.has(rid), "'%s' e' fra le regioni raggiungibili" % rid)
	cont.free()


func test_ritual_di_sequenza_0_ospitato_da_una_regione() -> void:
	# US-715: ogni Pathway attivo ha un sito reale per il rituale di Sequenza
	# 0 (uno per gruppo, condiviso dai Pathway vicini che si fondono in fase 7).
	var regioni: Array = _gd().call("get_regions")
	for pid in _gd().call("pathway_ids"):
		var pw: Dictionary = _gd().call("get_pathway", pid)
		for seq in (pw.get("sequences", []) as Array):
			var s: Dictionary = seq
			if int(s.get("sequence", -1)) != 0:
				continue
			var rit: Dictionary = s.get("advancement_ritual", {})
			var tags: Array = rit.get("location_tags", [])
			assert_true(tags.size() > 0, "%s Seq 0 ha almeno un location_tag" % pid)
			for t in tags:
				var ospitato := false
				for r in regioni:
					if (r as Dictionary).get("location_tags", []).has(t):
						ospitato = true
						break
				assert_true(ospitato, "%s Seq 0: location_tag '%s' ospitato da una regione" % [pid, t])


## US-1001 (fase 10, mondo continuo): ogni regione dichiara un world_offset
## nell'unica griglia condivisa, e nessuna coppia di rettangoli si sovrappone
## (stesso check del validator Python, qui contro i dati veri caricati).
func test_world_offset_esiste_e_non_si_sovrappone() -> void:
	var regioni: Array = _gd().call("get_regions")
	var rettangoli: Dictionary = {}
	for r in regioni:
		var rid: String = str((r as Dictionary).get("id", ""))
		var wo: Variant = (r as Dictionary).get("world_offset")
		assert_true(typeof(wo) == TYPE_ARRAY and (wo as Array).size() == 2,
			"'%s' ha un world_offset [x, y]" % rid)
		if typeof(wo) != TYPE_ARRAY:
			continue
		var ox: int = int((wo as Array)[0])
		var oy: int = int((wo as Array)[1])
		var layout: Dictionary = _gd().call("get_layout", rid)
		var mappa: Array = layout.get("mappa", [])
		var w: int = str(mappa[0]).length() if mappa.size() > 0 else 48
		var h: int = mappa.size() if mappa.size() > 0 else 36
		rettangoli[rid] = Rect2i(ox, oy, w, h)

	var ids: Array = rettangoli.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Rect2i = rettangoli[ids[i]]
			var b: Rect2i = rettangoli[ids[j]]
			assert_false(a.intersects(b),
				"'%s' %s e '%s' %s non si sovrappongono" % [ids[i], a, ids[j], b])


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
