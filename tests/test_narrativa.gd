extends "res://tests/test_case.gd"
## US-620 — gli indizi dell'antagonista + le scene degli atti come flag/dati:
## antagonisti.json per Pathway; Aldo avanza di Sequenza col tempo di gioco;
## flag aldo_duello_disponibile ai passaggi di tier; flag atto_1_concluso al
## primo rituale di Sequenza <= 6.

const SPM := 120.0


func _root() -> Node: return Engine.get_main_loop().root
func _ns() -> Node: return _root().get_node("NpcSystem")
func _ks() -> Node: return _root().get_node("KnowledgeStore")
func _ts() -> Node: return _root().get_node("TimeSystem")
func _pr() -> Node: return _root().get_node("Progression")
func _rs() -> Node: return _root().get_node("RitualSystem")
func _gd() -> Node: return _root().get_node("GameData")


func prepara() -> void:
	_ns().call("pulisci")
	_ks().call("dimentica_tutto")
	_ts().call("da_salvataggio", {})
	_pr().call("configura", "twilight_giant", 9)
	# US-711: i flag narrativi ai passaggi di tier, non la prova della tribolazione.
	_root().get_node("TribulationSystem").call("marca_superate_tutte")


func test_antagonista_per_pathway() -> void:
	var gd: Node = _gd()
	assert_eq(gd.call("get_antagonisti").size(), 10, "un antagonista per Pathway attivo")
	assert_true(gd.call("get_antagonista", "nonesiste").is_empty(), "Pathway ignoto -> {}")
	_pr().call("configura", "darkness", 9)
	var a: Dictionary = _ns().call("antagonista_del_giocatore")
	assert_eq(str(a.get("pathway_id")), "darkness", "l'antagonista segue il Pathway del giocatore")
	assert_true(str(a.get("name_i18n", "")).begins_with("antagonist."), "chiave i18n del nome")
	assert_gt(float((a.get("indizi", []) as Array).size()), 0.0, "ha indizi")


func test_aldo_avanza_col_tempo_di_gioco() -> void:
	var ns: Node = _ns()
	assert_eq(ns.call("sequenza_npc", "npc_aldo"), 9, "Aldo parte dalla Sequenza 9")
	# ogni_momenti = 8, sequenza_minima = 4: dopo ~40 momenti e' a 4
	for i in 40:
		_ts().call("avanza", SPM)
	assert_eq(ns.call("sequenza_npc", "npc_aldo"), 4, "col tempo Aldo scende fino alla Sequenza minima")
	var altri: int = ns.call("sequenza_npc", "npc_mirco")
	assert_eq(altri, 9, "un NPC senza avanzamento_temporale resta fermo")


func test_flag_aldo_duello_al_passaggio_di_tier() -> void:
	_pr().call("configura", "twilight_giant", 7)   # tier low
	assert_false(_ks().call("conosce", "aldo_duello_disponibile"), "niente flag prima")
	_pr().call("avanza")                            # 7 -> 6: low -> mid
	assert_true(_ks().call("conosce", "aldo_duello_disponibile"),
		"al passaggio di tier Aldo offre il duello")
	_pr().call("configura", "twilight_giant", 9)


func test_flag_atto_1_concluso_al_primo_rituale() -> void:
	_rs().rituale_completato.emit(7)
	assert_false(_ks().call("conosce", "atto_1_concluso"), "un rituale di Seq 7 non chiude l'Atto I")
	_rs().rituale_completato.emit(5)
	assert_true(_ks().call("conosce", "atto_1_concluso"),
		"il primo rituale di Sequenza <= 6 chiude l'Atto I")


func test_seq_npc_round_trip() -> void:
	var ns: Node = _ns()
	for i in 16:
		_ts().call("avanza", SPM)
	var s: int = ns.call("sequenza_npc", "npc_aldo")
	assert_true(s < 9, "Aldo e' avanzato")
	var snap: Dictionary = ns.call("per_salvataggio")
	ns.call("pulisci")
	assert_eq(ns.call("sequenza_npc", "npc_aldo"), 9, "pulisci riporta al default")
	ns.call("da_salvataggio", snap)
	assert_eq(ns.call("sequenza_npc", "npc_aldo"), s, "la Sequenza di Aldo sopravvive al save")
