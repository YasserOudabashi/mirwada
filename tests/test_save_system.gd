extends "res://tests/test_case.gd"
## US-015 — salvataggio versionato: round-trip, atomicita', campi non fidati,
## migrazione, rifiuto di versioni future, corruzione gestita.

const SLOT := 900


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SaveSystem")


func _pulisci() -> void:
	var s: Node = _save()
	if s.esiste(SLOT):
		s.cancella(SLOT)
	DirAccess.remove_absolute("user://saves/slot_%d.json.tmp" % SLOT)


func _scrivi_grezzo(testo: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open("user://saves/slot_%d.json" % SLOT, FileAccess.WRITE)
	f.store_string(testo)
	f.close()


func test_round_trip() -> void:
	var s: Node = _save()
	_pulisci()
	var snap := {
		"nome_personaggio": "Enel",
		"tempo_gioco": 123.5,
		"posizione": Vector2(240, 496),
		"statistiche": {"hp": 80.0, "sequenza": 9},
		"evocazioni": [{"id": "scheletro", "durata": -1}],
	}
	var r: Dictionary = s.salva(SLOT, snap)
	assert_true(r["ok"], "salva ok")

	var c: Dictionary = s.carica(SLOT)
	assert_true(c["ok"], "carica ok")
	var d: Dictionary = c["dati"]
	assert_eq(d["nome_personaggio"], "Enel", "nome round-trip")
	assert_almost_eq(d["tempo_gioco"], 123.5, "tempo round-trip")
	assert_eq(d["posizione"], Vector2(240, 496), "posizione round-trip")
	assert_eq(int((d["statistiche"] as Dictionary)["sequenza"]), 9, "statistiche round-trip")
	assert_eq((d["evocazioni"] as Array).size(), 1, "evocazione persistente serializzata")
	_pulisci()


func test_scrittura_atomica_niente_tmp_residuo() -> void:
	var s: Node = _save()
	_pulisci()
	s.salva(SLOT, {"nome_personaggio": "X"})
	assert_true(s.esiste(SLOT), "file finale creato")
	assert_false(FileAccess.file_exists("user://saves/slot_%d.json.tmp" % SLOT), "nessun .tmp residuo")
	_pulisci()


func test_json_corrotto_gestito_senza_cancellare() -> void:
	var s: Node = _save()
	_pulisci()
	_scrivi_grezzo("{ questo non e' json valido ")
	var c: Dictionary = s.carica(SLOT)
	assert_false(c["ok"], "carica fallisce sul json rotto")
	assert_eq(c["reason"], s.ERR_JSON, "motivo json_malformato")
	assert_eq(s.stato_slot(SLOT), s.Slot.CORROTTO, "slot segnalato corrotto")
	assert_true(s.esiste(SLOT), "il file corrotto NON e' stato cancellato")
	_pulisci()


func test_versione_futura_rifiutata_senza_toccare_il_file() -> void:
	var s: Node = _save()
	_pulisci()
	_scrivi_grezzo('{"schema_version": 99, "nome_personaggio": "dal futuro"}')
	var c: Dictionary = s.carica(SLOT)
	assert_false(c["ok"], "rifiuto della versione futura")
	assert_eq(c["reason"], s.ERR_FUTURA, "motivo versione futura")
	assert_true(s.esiste(SLOT), "il file non e' stato toccato")
	_pulisci()


func test_migrazione_da_versione_vecchia() -> void:
	var s: Node = _save()
	_pulisci()
	# v1: non aveva il campo evocazioni
	_scrivi_grezzo('{"schema_version": 1, "nome_personaggio": "vecchio", "tempo_gioco": 10.0, "posizione": [1, 2], "statistiche": {}}')
	var c: Dictionary = s.carica(SLOT)
	assert_true(c["ok"], "carica ok dopo migrazione")
	assert_true(c["migrato"], "flag migrato")
	assert_eq(int((c["dati"] as Dictionary)["schema_version"]), s.VERSIONE_CORRENTE, "portato alla versione corrente")
	assert_eq(((c["dati"] as Dictionary)["evocazioni"] as Array), [], "campo evocazioni aggiunto vuoto")
	_pulisci()


func test_campi_non_fidati_default_sano() -> void:
	var s: Node = _save()
	_pulisci()
	# posizione come stringa, tempo_gioco come oggetto: tipi sbagliati
	_scrivi_grezzo('{"schema_version": 2, "nome_personaggio": 123, "tempo_gioco": "molto", "posizione": "NE::12,34", "statistiche": [], "evocazioni": {}}')
	var c: Dictionary = s.carica(SLOT)
	assert_true(c["ok"], "carica non esplode su tipi sbagliati")
	var d: Dictionary = c["dati"]
	assert_eq(d["posizione"], Vector2.ZERO, "posizione malformata -> zero")
	assert_eq(d["nome_personaggio"], "", "nome di tipo sbagliato -> stringa vuota")
	assert_almost_eq(d["tempo_gioco"], 0.0, "tempo di tipo sbagliato -> 0")
	assert_eq((d["statistiche"] as Dictionary), {}, "statistiche di tipo sbagliato -> {}")
	_pulisci()


func test_gamestate_round_trip_col_giocatore() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("GameState")
	var s: Node = _save()
	if gs == null:
		assert_true(false, "autoload GameState assente")
		return
	# niente giocatore in scena nei test: salva comunque nome e tempo
	gs.nome_personaggio = "Provaccia"
	gs.tempo_gioco = 42.0
	var slot: int = gs.SLOT_RAPIDO
	if s.esiste(slot):
		s.cancella(slot)
	var r: Dictionary = gs.salva_rapido()
	assert_true(r["ok"], "salva_rapido ok")

	gs.nome_personaggio = "cambiato"
	gs.tempo_gioco = 0.0
	var c: Dictionary = gs.carica_rapido()
	assert_true(c["ok"], "carica_rapido ok")
	assert_eq(gs.nome_personaggio, "Provaccia", "nome ripristinato")
	assert_almost_eq(gs.tempo_gioco, 42.0, "tempo ripristinato")
	s.cancella(slot)


## US-1004 (fase 10, mondo continuo): "posizione" resta Node2D.global_position
## cosi' com'e' dal round-trip di sempre (test_round_trip sopra) - nessun
## campo nuovo, nessun bump di schema_version. Cambia solo COSA significano
## i numeri: da US-1002 in poi sono una posizione ASSOLUTA nell'unico
## TileMapLayer condiviso, non piu' locale a una scena per regione. Qui si
## prova il caso che lo dimostra: si salva a meta' di Marche del Crepuscolo
## (world_offset [0,0], lontano dalla cella di spawn di Mirwada [220,180]),
## si sposta il player altrove, si ricarica - riappare ESATTAMENTE li'.
## WorldState.regione_corrente() (gia' salvato da _mondo_snapshot(), US-602)
## resta la fonte di verita' per la regione, aggiornata dal confine di
## world_scene.gd (US-1002), non da un campo derivato dalla posizione.
func test_round_trip_posizione_nel_mondo_continuo() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("GameState")
	var ws: Node = Engine.get_main_loop().root.get_node_or_null("WorldState")
	var s: Node = _save()
	if gs == null or ws == null:
		assert_true(false, "autoload GameState/WorldState assente")
		return

	var player := Node2D.new()
	player.name = "Player"
	player.add_to_group("player")
	Engine.get_main_loop().root.add_child(player)

	var punto_lontano := Vector2(600, 700)  # dentro Marche, lontano dallo spawn di Mirwada
	player.global_position = punto_lontano
	ws.call("pulisci")
	ws.call("entra_regione", "marche_crepuscolo")

	var slot: int = gs.SLOT_RAPIDO
	if s.esiste(slot):
		s.cancella(slot)
	var r: Dictionary = gs.salva_rapido()
	assert_true(r["ok"], "salva_rapido ok")

	# si "perde" la posizione/regione corrente prima di ricaricare, cosi' il
	# round-trip prova davvero qualcosa (non solo che i valori non cambiano).
	player.global_position = Vector2.ZERO
	ws.call("pulisci")

	var c: Dictionary = gs.carica_rapido()
	assert_true(c["ok"], "carica_rapido ok")
	assert_eq(player.global_position, punto_lontano,
		"il personaggio riappare ESATTAMENTE nello stesso punto del mondo continuo")
	assert_eq(str(ws.call("regione_corrente")), "marche_crepuscolo",
		"WorldState.regione_corrente() torna quella salvata - nessun campo nuovo")

	player.free()
	s.cancella(slot)


func test_slot_vuoto() -> void:
	var s: Node = _save()
	_pulisci()
	var c: Dictionary = s.carica(SLOT)
	assert_false(c["ok"], "slot vuoto non carica")
	assert_eq(c["reason"], s.ERR_ASSENTE, "motivo slot_vuoto")
	assert_eq(s.stato_slot(SLOT), s.Slot.VUOTO, "stato VUOTO")


func test_migrazione_v21_a_v22_aggiunge_endgame() -> void:
	# US-701: un save di fase 6 (v21) non aveva il campo 'endgame'.
	var s: Node = _save()
	_pulisci()
	_scrivi_grezzo('{"schema_version": 21, "nome_personaggio": "pre-endgame", "tempo_gioco": 5.0, "posizione": [0, 0], "statistiche": {}, "mondo": {"terrain_mods": [], "regione": "mirwada"}}')
	var c: Dictionary = s.carica(SLOT)
	assert_true(c["ok"] and c["migrato"], "carica ok, migrato")
	assert_eq(int((c["dati"] as Dictionary)["schema_version"]), s.VERSIONE_CORRENTE, "portato alla versione corrente")
	var eg: Dictionary = (c["dati"] as Dictionary)["endgame"]
	assert_eq(str(eg.get("pathway_precedente", "MANCANTE")), "", "endgame.pathway_precedente vuoto")
	assert_eq((eg.get("fusioni", ["MANCANTE"]) as Array), [], "endgame.fusioni vuoto")
	assert_eq(str((c["dati"] as Dictionary).get("mondo", {}).get("regione", "")), "mirwada",
		"il campo mondo pre-esistente non e' stato toccato")
	_pulisci()


func test_endgame_round_trip() -> void:
	var s: Node = _save()
	_pulisci()
	var snap := {
		"nome_personaggio": "Ereditiere",
		"endgame": {
			"pathway_precedente": "error",
			"fusioni": ["fus_door_error_scasso_spaziale"],
			"tribolazioni_superate": [7, 3],
			"eredita": {"conoscenza": ["pathway:door"], "ancora": {"id": "anchor_mirco", "forza": 3.0},
				"reputazione": {"ordine_minore": 2.5}, "oggetto": "chiave_d_ossa"},
			"finale": "consumazione",
		},
	}
	assert_true(s.salva(SLOT, snap)["ok"], "salva ok")
	var d: Dictionary = s.carica(SLOT)["dati"]
	var eg: Dictionary = d["endgame"]
	assert_eq(str(eg["pathway_precedente"]), "error", "pathway_precedente round-trip")
	assert_eq((eg["fusioni"] as Array).size(), 1, "fusioni round-trip")
	var trib: Array = []
	for v in (eg["tribolazioni_superate"] as Array):
		trib.append(int(v))
	assert_eq(trib, [7, 3], "tribolazioni round-trip")
	assert_eq(str((eg["eredita"] as Dictionary)["oggetto"]), "chiave_d_ossa", "eredita.oggetto round-trip")
	assert_eq(str(eg["finale"]), "consumazione", "finale round-trip")
	_pulisci()


func test_endgame_state_scarta_le_voci_malformate() -> void:
	var es: Node = Engine.get_main_loop().root.get_node_or_null("EndgameState")
	if es == null:
		return
	es.call("da_salvataggio", {"pathway_precedente": 42, "fusioni": ["ok", 7, ""],
		"tribolazioni_superate": [7, 99, "x"], "eredita": "non un dict", "finale": ["lista"]})
	assert_eq(str(es.get("pathway_precedente")), "", "pathway_precedente non-stringa -> ''")
	assert_eq((es.get("fusioni") as Array), ["ok"], "fusioni: solo le stringhe non vuote")
	assert_eq((es.get("tribolazioni_superate") as Array), [7], "tribolazioni: solo i salti validi")
	assert_eq((es.get("eredita") as Dictionary), {}, "eredita non-dict -> {}")
	assert_eq(str(es.get("finale")), "", "finale non-stringa -> ''")
	es.call("pulisci")
