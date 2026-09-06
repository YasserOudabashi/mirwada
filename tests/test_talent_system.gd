extends "res://tests/test_case.gd"
## US-331 — TalentTracker + TalentSystem: i comportamenti oltre soglia
## sbloccano i talenti, l'effetto si applica, tutto persiste nel save.

const StatsComponent := preload("res://scripts/stats_component.gd")
const SLOT := 910

var _p: Node2D = null


func _ts() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("TalentSystem")


func _tt() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("TalentTracker")


func _et() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("EventTracker")


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SaveSystem")


func prepara() -> void:
	if _ts() != null:
		_ts().call("pulisci")
	if _tt() != null:
		_tt().call("azzera")
	if _et() != null:
		_et().call("azzera")
	_p = Node2D.new()
	_p.add_to_group("player")
	var st: Node = StatsComponent.new()
	st.name = "StatsComponent"
	st.call("configure_from_balance", 9)
	_p.add_child(st)
	Engine.get_main_loop().root.add_child(_p)


func _fine() -> void:
	if is_instance_valid(_p):
		_p.free()


func _stats() -> Node:
	return _p.get_node("StatsComponent")


func test_concedi_applica_lo_stat_modifier_additivo() -> void:
	var prima: float = _stats().call("get_stat", "precisione")
	assert_true(_ts().call("concedi", "mano_ferma"), "talento concesso")
	assert_true(_ts().call("possiede", "mano_ferma"), "ora e' posseduto")
	assert_almost_eq(_stats().call("get_stat", "precisione"), prima + 6.0,
		"precisione +6 dal modificatore talent:mano_ferma")
	_fine()


func test_concedi_applica_lo_stat_modifier_moltiplicativo() -> void:
	var base: float = _stats().call("get_base", "hp_max")
	_ts().call("concedi", "costituzione_robusta")  # +10% moltiplicativo
	assert_almost_eq(_stats().call("get_stat", "hp_max"), base * 1.1,
		"hp_max +10% del valore base")
	_fine()


func test_comportamento_talento_oltre_soglia_sblocca_e_segnala() -> void:
	var visti: Array = []
	_ts().connect("talento_sbloccato", func(id: String) -> void: visti.append(id))

	_tt().call("registra", "distanza_percorsa", 5000.0)
	_ts().call("_process", 0.0)
	assert_false(_ts().call("possiede", "passo_lungo"), "a 5000 < 8000 non sbloccato")

	_tt().call("registra", "distanza_percorsa", 4000.0)  # totale 9000
	_ts().call("_process", 0.0)
	assert_true(_ts().call("possiede", "passo_lungo"), "oltre 8000 -> passo_lungo sbloccato")
	assert_true(visti.has("passo_lungo"), "segnale talento_sbloccato emesso")
	_fine()


func test_evento_dei_12_oltre_soglia_sblocca_un_talento() -> void:
	for _i in 50:
		_et().call("emit_event", "enemy_defeated", {})
	_ts().call("_process", 0.0)
	assert_true(_ts().call("possiede", "veterano"), "50 nemici -> veterano (sblocco su un evento dei 12)")
	_fine()


func test_tag_grant_entra_in_tag_concessi() -> void:
	_tt().call("registra", "giocato_di_notte", 700.0)
	_ts().call("_process", 0.0)
	assert_true(_ts().call("possiede", "figlio_della_notte"), "sbloccato")
	assert_true((_ts().call("tag_concessi") as Array).has("notte"),
		"il tag 'notte' e' fra quelli concessi (US-334)")
	_fine()


func test_sblocco_sistema_lo_legge_bonus_int() -> void:
	_ts().call("concedi", "pollice_verde")
	assert_eq(_ts().call("bonus_int", "resa_bonus_talento"), 1,
		"pollice_verde: bonus_int('resa_bonus_talento') = 1")
	assert_eq(_ts().call("bonus_int", "chiave_a_caso"), 0, "chiave senza talenti -> 0")
	_fine()


func test_round_trip_del_save() -> void:
	var s: Node = _save()
	if s.esiste(SLOT):
		s.cancella(SLOT)
	_ts().call("concedi", "mano_ferma")
	_tt().call("registra", "distanza_percorsa", 1234.0)
	var snap: Dictionary = {"nome_personaggio": "Enel", "talenti": {
		"posseduti": _ts().call("per_salvataggio"),
		"comportamenti": _tt().call("per_salvataggio"),
	}}
	s.salva(SLOT, snap)
	_ts().call("pulisci")
	_tt().call("azzera")

	var caricato: Dictionary = s.carica(SLOT)
	var tal: Dictionary = (caricato["dati"] as Dictionary)["talenti"]
	_tt().call("da_salvataggio", tal.get("comportamenti", {}))
	_ts().call("da_salvataggio", tal.get("posseduti", []))
	assert_true(_ts().call("possiede", "mano_ferma"), "talento ripristinato")
	assert_almost_eq(_tt().call("count", "distanza_percorsa"), 1234.0, "conteggio ripristinato")
	s.cancella(SLOT)
	_fine()


func test_migrazione_da_v18() -> void:
	var s: Node = _save()
	if s.esiste(SLOT):
		s.cancella(SLOT)
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open("user://saves/slot_%d.json" % SLOT, FileAccess.WRITE)
	f.store_string('{"schema_version": 18, "nome_personaggio": "v18", "posizione": [0, 0], "statistiche": {}}')
	f.close()
	var c: Dictionary = s.carica(SLOT)
	assert_true(c["ok"] and c["migrato"], "migrazione applicata")
	var tal: Dictionary = (c["dati"] as Dictionary)["talenti"]
	assert_eq(tal.get("posseduti"), [], "posseduti vuoto")
	assert_eq(tal.get("comportamenti"), {}, "comportamenti vuoto")
	s.cancella(SLOT)
	_fine()
