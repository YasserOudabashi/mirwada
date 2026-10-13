extends "res://tests/test_case.gd"
## US-616 — QuestSystem: un lettore di data/quests/ che osserva EventTracker
## (step 'evento') e KnowledgeStore (step 'flag'), avanza gli step, applica
## on_complete e ricompense; fallibile:true -> 'fallita'.

func _root() -> Node: return Engine.get_main_loop().root
func _qs() -> Node: return _root().get_node("QuestSystem")
func _ks() -> Node: return _root().get_node("KnowledgeStore")
func _et() -> Node: return _root().get_node("EventTracker")
func _ns() -> Node: return _root().get_node("NpcSystem")
func _inv() -> Node: return _root().get_node("Inventory")
func _fs() -> Node: return _root().get_node("FactionSystem")
func _de() -> Node: return _root().get_node("DialogueEngine")


func prepara() -> void:
	_qs().call("pulisci")
	_ks().call("dimentica_tutto")
	_et().call("azzera")
	_ns().call("pulisci")
	_inv().call("pulisci")
	_fs().call("pulisci")
	_de().call("termina")


func test_avvia_e_stato() -> void:
	var qs: Node = _qs()
	assert_eq(str(qs.call("stato", "q_mirco_01")), "non_iniziata", "prima di avviare")
	assert_true(qs.call("avvia", "q_mirco_01"), "avvia ok")
	assert_eq(str(qs.call("stato", "q_mirco_01")), "attiva", "ora attiva")
	assert_false(qs.call("avvia", "q_mirco_01"), "avviare due volte -> no-op")
	assert_false(qs.call("avvia", "q_inesistente"), "quest inesistente -> false")


func test_step_evento_completa_e_da_la_ricompensa() -> void:
	var qs: Node = _qs()
	qs.call("avvia", "q_mirco_01")
	for i in 3:
		_et().call("emit_event", "enemy_defeated", {"senza_abilita": true})
	assert_eq(str(qs.call("stato", "q_mirco_01")), "completata", "3 nemici senza abilita' -> completata")
	assert_eq(_inv().call("conta", "lingotto_ferro"), 2, "ricompensa: 2 lingotti nello zaino")
	assert_true(_ks().call("conosce", "q_mirco_01_done"), "flag di fine quest scritto")


func test_evento_non_conta_se_i_filtri_non_combaciano() -> void:
	var qs: Node = _qs()
	qs.call("avvia", "q_mirco_01")
	for i in 5:
		_et().call("emit_event", "enemy_defeated", {})   # senza il filtro senza_abilita
	assert_eq(str(qs.call("stato", "q_mirco_01")), "attiva", "nemici con abilita' non contano")


func test_step_flag_completa_e_rende_l_npc_un_ancora() -> void:
	var qs: Node = _qs()
	qs.call("avvia", "q_lena_01")
	assert_eq(str(qs.call("stato", "q_lena_01")), "attiva", "attiva prima del flag")
	_ks().call("impara", "lena_ricorda_il_gioco")
	assert_eq(str(qs.call("stato", "q_lena_01")), "completata", "flag scritto -> completata")
	assert_true("npc_lena" in _ns().call("ancore_attive"), "on_complete: Lena e' un'Ancora")


func test_fallibile() -> void:
	var qs: Node = _qs()
	qs.call("avvia", "q_vesna_01")
	assert_true(qs.call("fallisci", "q_vesna_01"), "una quest fallibile puo' fallire")
	assert_eq(str(qs.call("stato", "q_vesna_01")), "fallita", "stato fallita")
	qs.call("avvia", "q_mirco_01")
	assert_false(qs.call("fallisci", "q_mirco_01"), "una quest non fallibile non fallisce")


func test_avvia_quest_da_un_dialogo() -> void:
	var qs: Node = _qs()
	# dlg_lena "gioca": flag lena_ricorda_il_gioco + avvia_quest q_lena_01
	_de().call("avvia", "dlg_lena", "npc_lena")
	_de().call("scegli", 0)
	assert_eq(str(qs.call("stato", "q_lena_01")), "completata",
		"il dialogo avvia la quest e il flag gia' scritto la chiude subito")


func test_round_trip_del_save() -> void:
	var qs: Node = _qs()
	qs.call("avvia", "q_sidon_01")
	qs.call("avvia", "q_vesna_01")
	qs.call("fallisci", "q_vesna_01")
	var snap: Dictionary = qs.call("per_salvataggio")
	qs.call("pulisci")
	qs.call("da_salvataggio", snap)
	assert_eq(str(qs.call("stato", "q_sidon_01")), "attiva", "attiva round-trip")
	assert_eq(str(qs.call("stato", "q_vesna_01")), "fallita", "fallita round-trip")
