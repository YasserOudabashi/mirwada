extends "res://tests/test_case.gd"
## US-331 — TalentSystem + emettitori dei nuovi comportamenti.

const StatsComponent := preload("res://scripts/stats_component.gd")

var _p: Node2D = null


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/TalentSystem") != null:
		_n("/root/TalentSystem").call("pulisci")
	if _n("/root/TalentTracker") != null:
		_n("/root/TalentTracker").call("azzera")
	if _n("/root/EventTracker") != null:
		_n("/root/EventTracker").call("azzera")
	_p = Node2D.new()
	_p.add_to_group("player")
	var st: Node = StatsComponent.new()
	st.name = "StatsComponent"
	st.call("configure_from_balance", 9)
	_p.add_child(st)
	Engine.get_main_loop().root.add_child(_p)


func _pulisci_giocatore() -> void:
	_n("/root/TalentSystem").call("pulisci")
	_p.free()


func test_comportamento_oltre_soglia_sblocca_applica_effetto_ed_emette_segnale() -> void:
	var ts: Node = _n("/root/TalentSystem")
	var stats: Node = _p.get_node("StatsComponent")
	var visto: Dictionary = {"id": ""}
	var cb := func(id: String) -> void:
		visto["id"] = id
	ts.talento_sbloccato.connect(cb)

	var vel0: float = stats.call("get_stat", "velocita")
	assert_false(ts.call("possiede", "viandante_instancabile"), "non ancora posseduto")

	# viandante_instancabile: sblocco distanza_percorsa (misura somma) target 5000
	_n("/root/TalentTracker").call("emit_event", "distanza_percorsa", {"quantita": 6000.0})

	assert_true(ts.call("possiede", "viandante_instancabile"), "sbloccato oltre la soglia")
	assert_almost_eq(stats.call("get_stat", "velocita"), vel0 + 5.0, "effetto stat_modifier applicato")
	assert_eq(visto["id"], "viandante_instancabile", "segnale talento_sbloccato con l'id giusto")
	_pulisci_giocatore()


func test_sotto_soglia_niente() -> void:
	var ts: Node = _n("/root/TalentSystem")
	_n("/root/TalentTracker").call("emit_event", "distanza_percorsa", {"quantita": 100.0})
	assert_false(ts.call("possiede", "viandante_instancabile"), "sotto soglia: niente")
	_pulisci_giocatore()


func test_concedi_innato_applica_subito_leffetto() -> void:
	var ts: Node = _n("/root/TalentSystem")
	var stats: Node = _p.get_node("StatsComponent")
	var forza0: float = stats.call("get_stat", "forza")
	assert_true(ts.call("concedi", "forza_innata"), "concedi riesce")
	assert_true(ts.call("possiede", "forza_innata"), "posseduto")
	assert_almost_eq(stats.call("get_stat", "forza"), forza0 + 0.1, "effetto applicato subito")
	_pulisci_giocatore()


func test_concedi_due_volte_o_id_ignoto_fallisce() -> void:
	var ts: Node = _n("/root/TalentSystem")
	ts.call("concedi", "forza_innata")
	assert_false(ts.call("concedi", "forza_innata"), "gia' posseduto -> false")
	assert_false(ts.call("concedi", "talento_inventato"), "id ignoto -> false")
	_pulisci_giocatore()


func test_tag_attivi_dai_talenti_tag_grant() -> void:
	var ts: Node = _n("/root/TalentSystem")
	assert_false((ts.call("tag_attivi") as Dictionary).has("pozione"), "premessa: niente ancora")
	ts.call("concedi", "pollice_verde")   # effetto: tag_grant "pozione"
	assert_true((ts.call("tag_attivi") as Dictionary).has("pozione"), "il tag_grant conta")
	_pulisci_giocatore()


func test_bonus_int_somma_leffetto_sblocco_sistema() -> void:
	var ts: Node = _n("/root/TalentSystem")
	assert_eq(ts.call("bonus_int", "alchimia_qualita"), 0, "0 senza il talento")
	ts.call("concedi", "sperimentatore_temerario")   # sblocco_sistema alchimia_qualita: 1
	assert_eq(ts.call("bonus_int", "alchimia_qualita"), 1, "il bonus_int riflette il talento")
	_pulisci_giocatore()


func test_round_trip_del_save() -> void:
	var ts: Node = _n("/root/TalentSystem")
	var tt: Node = _n("/root/TalentTracker")
	ts.call("concedi", "forza_innata")
	tt.call("emit_event", "ingredienti_coltivati", {})

	var snap_ts: Dictionary = ts.call("per_salvataggio")
	var snap_tt: Dictionary = tt.call("per_salvataggio")
	ts.call("pulisci")
	tt.call("azzera")
	assert_false(ts.call("possiede", "forza_innata"), "svuotato")

	ts.call("da_salvataggio", snap_ts)
	tt.call("da_salvataggio", snap_tt)
	assert_true(ts.call("possiede", "forza_innata"), "il talento torna dal save")
	assert_almost_eq(tt.call("count", "ingredienti_coltivati", {}), 1.0, "il log del tracker torna dal save")
	_pulisci_giocatore()


func test_da_salvataggio_non_fidato() -> void:
	var ts: Node = _n("/root/TalentSystem")
	ts.call("da_salvataggio", "non un oggetto")
	assert_eq((ts.call("posseduti") as Array).size(), 0, "raw non-oggetto -> niente")
	ts.call("da_salvataggio", {"posseduti": ["forza_innata", "talento_inventato", "forza_innata"]})
	var pos: Array = ts.call("posseduti")
	assert_eq(pos.size(), 1, "id ignoto scartato, duplicato non ripetuto")
	assert_true(pos.has("forza_innata"), "quello valido resta")
	_pulisci_giocatore()
