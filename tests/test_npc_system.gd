extends "res://tests/test_case.gd"
## US-612 — NpcSystem: memoria per modo di npc_influenced, conosciuti (per i
## sussurri), presenza in scena da schedule + momento, round-trip del save.

const SPM := 120.0


func _root() -> Node: return Engine.get_main_loop().root
func _ns() -> Node: return _root().get_node("NpcSystem")
func _ts() -> Node: return _root().get_node("TimeSystem")
func _et() -> Node: return _root().get_node("EventTracker")
func _gd() -> Node: return _root().get_node("GameData")
func _am() -> Node: return _root().get_node("AudioManager")


func prepara() -> void:
	_ns().call("pulisci")
	_ts().call("da_salvataggio", {})   # -> "alba"
	_et().call("azzera")


func test_roster_caricato_da_gamedata() -> void:
	var npcs: Array = _gd().call("get_npcs")
	# 8 del roster originale + 10 npc_generic_* + npc_antagonista (US-712) +
	# npc_rosalba (US-1108B) + npc_bram (US-1109) - gli NPC crafter di fase 11.
	assert_eq(npcs.size(), 21, "10 nominali + 10 npc_generic_* + npc_antagonista")
	var bruno: Dictionary = _gd().call("get_npc", "npc_bruno")
	assert_eq(str(bruno.get("faction_id")), "porto", "Bruno e' del porto")
	assert_true(_gd().call("get_npc", "non_esiste").is_empty(), "id ignoto -> {}")


func test_influenza_aggiorna_memoria_ed_emette_evento() -> void:
	var ns: Node = _ns()
	var visti: Array = []
	var cb := func(id: String, modo: String) -> void: visti.append([id, modo])
	ns.connect("npc_influenzato", cb)
	assert_true(ns.call("influenza", "npc_mirco", "aiutato"), "influenza valida -> true")
	assert_false(ns.call("influenza", "npc_mirco", "modo_inventato"), "modo fuori dai 5 -> false")
	assert_false(ns.call("influenza", "npc_inesistente", "aiutato"), "id ignoto -> false")
	ns.disconnect("npc_influenzato", cb)
	assert_eq(ns.call("memoria", "npc_mirco"), {"aiutato": 1}, "la memoria conta il modo")
	assert_eq(_et().call("count", "npc_influenced", {"modo": "aiutato"}), 1.0,
		"npc_influenced { modo: aiutato } entra in EventTracker")
	assert_eq(visti.size(), 1, "un solo segnale npc_influenzato (solo la valida)")
	assert_true(ns.call("conosce", "npc_mirco"), "influenzare = anche incontrare")


func test_ha_influenza_per_i_gate_npc() -> void:
	var ns: Node = _ns()
	ns.call("influenza", "npc_ottavia", "persuaso")
	assert_true(ns.call("ha_influenza", "npc_ottavia:persuaso"), "modo giusto")
	assert_false(ns.call("ha_influenza", "npc_ottavia:intimidito"), "modo mai usato")
	assert_true(ns.call("ha_influenza", "npc_ottavia"), "senza modo: influenzato comunque")
	assert_false(ns.call("ha_influenza", "npc_lena"), "mai influenzato")


func test_nomi_sussurro_include_conosciuti_e_ancore() -> void:
	var ns: Node = _ns()
	ns.call("incontra", "npc_mirco")
	assert_true("npc.mirco.name" in _am().call("nomi_sussurro"),
		"un NPC incontrato entra nei nomi dei sussurri")
	assert_true(ns.call("promuovi_ancora", "npc_vesna"), "Vesna e' anchor_candidate")
	assert_false(ns.call("promuovi_ancora", "npc_sidon"), "Sidon non lo e'")
	assert_true("npc.vesna.name" in _am().call("nomi_sussurro"), "un'Ancora del roster c'e'")


func test_presenti_segue_lo_schedule_e_il_momento() -> void:
	var ns: Node = _ns()
	var alba: Dictionary = ns.call("presenti", "mirwada")
	assert_eq(str(alba.get("npc_mirco")), "piazza", "all'alba Mirco e' in piazza")
	assert_false(alba.has("npc_bruno"), "all'alba Bruno non e' in scena (location_tag null)")
	_ts().call("avanza", SPM * 3.0)  # -> notte_fonda
	assert_eq(str(_ts().call("momento")), "notte_fonda", "siamo a notte_fonda")
	var notte: Dictionary = ns.call("presenti", "mirwada")
	assert_eq(str(notte.get("npc_bruno")), "porto", "di notte Bruno e' al porto")
	assert_false(notte.has("npc_mirco"), "di notte Mirco non e' in scena")


func test_round_trip_del_save() -> void:
	var ns: Node = _ns()
	ns.call("influenza", "npc_doran", "intimidito")
	ns.call("influenza", "npc_doran", "intimidito")
	ns.call("incontra", "npc_lena")
	ns.call("promuovi_ancora", "npc_lena")
	var snap: Dictionary = ns.call("per_salvataggio")
	ns.call("pulisci")
	assert_eq(ns.call("conosciuti"), [], "pulisci azzera")
	ns.call("da_salvataggio", snap)
	assert_eq(ns.call("memoria", "npc_doran"), {"intimidito": 2}, "memoria round-trip")
	assert_true(ns.call("conosce", "npc_lena"), "conosciuti round-trip")
	assert_true("npc_lena" in ns.call("ancore_attive"), "ancore round-trip")


func test_da_salvataggio_non_fidato() -> void:
	var ns: Node = _ns()
	ns.call("da_salvataggio", {"conosciuti": "npc_mirco", "memoria": [1, 2], "ancore": {}})
	assert_eq(ns.call("conosciuti"), [], "conosciuti malformati -> vuoto")
	assert_eq(ns.call("ancore_attive"), [], "ancore malformate -> vuoto")
	ns.call("da_salvataggio", {"memoria": {"npc_x": {"modo_falso": 3, "aiutato": "no"}}})
	assert_eq(ns.call("memoria", "npc_x"), {}, "voci di memoria malformate scartate")
