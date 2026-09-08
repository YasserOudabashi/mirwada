extends "res://tests/test_case.gd"
## US-713 — overlay della tribolazione in corso: nome, descrizione, handicap
## attivo, progresso. Reattivo ai segnali di TribulationSystem.

const Overlay := preload("res://scenes/tribulation_overlay.tscn")


func _root() -> Node: return Engine.get_main_loop().root
func _ts() -> Node: return _root().get_node("TribulationSystem")
func _et() -> Node: return _root().get_node("EventTracker")
func _ks() -> Node: return _root().get_node("KnowledgeStore")
func _eg() -> Node: return _root().get_node("EndgameState")
func _gd() -> Node: return _root().get_node("GameData")


func prepara() -> void:
	_et().call("azzera")
	_ks().call("dimentica_tutto")
	_eg().call("pulisci")
	_ts().call("azzera")
	_root().get_node("Progression").call("configura", "twilight_giant", 5)


func _overlay() -> Node:
	var o: Node = Overlay.instantiate()
	_root().add_child(o)
	return o


func _via(o: Node) -> void:
	_root().remove_child(o)
	o.free()


func test_nascosto_senza_tribolazione_in_corso() -> void:
	var o: Node = _overlay()
	assert_false(bool(o.call("visibile")), "nessuna prova attiva -> overlay nascosto")
	_via(o)


func test_appare_coi_dati_della_prova() -> void:
	var o: Node = _overlay()
	_ts().call("attiva", 5)   # trib_5_4
	assert_true(bool(o.call("visibile")), "prova attiva -> overlay visibile")
	var s: Dictionary = o.call("stato_mostrato")
	var t: Dictionary = _gd().call("tribulation_per_salto", 5)
	assert_eq(s["nome"], _gd().call("tr_data", t["name_i18n"]), "mostra il nome della prova")
	assert_ne(str(s["descrizione"]), "", "mostra la descrizione")
	assert_true(str(s["effetto"]).length() > 0, "mostra l'handicap mentre_in_corso")
	_via(o)


func test_progresso_reattivo_e_sparizione_al_superamento() -> void:
	var o: Node = _overlay()
	_ts().call("attiva", 5)   # trib_5_4: npc_influenced x3
	_et().call("emit_event", "npc_influenced", {})
	assert_almost_eq(float((o.call("stato_mostrato") as Dictionary)["progresso"]), 1.0 / 3.0,
		"1/3 -> progresso aggiornato dal vivo")
	_et().call("emit_event", "npc_influenced", {})
	_et().call("emit_event", "npc_influenced", {})
	assert_false(bool(o.call("visibile")), "superata -> overlay sparisce")
	_via(o)
