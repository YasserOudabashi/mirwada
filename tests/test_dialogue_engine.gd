extends "res://tests/test_case.gd"
## US-613 — DialogueEngine: legge un grafo di data/dialogues/, nasconde le
## scelte con condizioni non soddisfatte, applica gli effetti del vocabolario
## chiuso, segue il goto, ferma il mondo.

func _root() -> Node: return Engine.get_main_loop().root
func _de() -> Node: return _root().get_node("DialogueEngine")
func _ks() -> Node: return _root().get_node("KnowledgeStore")
func _ns() -> Node: return _root().get_node("NpcSystem")
func _ts() -> Node: return _root().get_node("TimeSystem")
func _et() -> Node: return _root().get_node("EventTracker")
func _pr() -> Node: return _root().get_node("Progression")


func prepara() -> void:
	_de().call("termina")
	_ks().call("dimentica_tutto")
	_ns().call("pulisci")
	_ts().call("da_salvataggio", {})
	_ts().call("imposta_pausa", false)
	_et().call("azzera")
	_pr().call("configura", "twilight_giant", 9)   # tier low


func test_avvia_e_nodo_corrente() -> void:
	var de: Node = _de()
	assert_false(de.call("avvia", "dlg_inesistente"), "dialogo ignoto -> false")
	assert_true(de.call("avvia", "dlg_mirco", "npc_mirco"), "dlg_mirco parte")
	assert_true(de.call("in_corso"), "dialogo in corso")
	assert_eq(str(de.call("nodo_corrente").get("speaker")), "npc_mirco", "nodo di start")


func test_le_condizioni_nascondono_le_scelte() -> void:
	var de: Node = _de()
	de.call("avvia", "dlg_mirco", "npc_mirco")
	var a_low: Array = de.call("scelte_valide")
	assert_eq(a_low.size(), 2, "a tier low: la scelta con tier_min:mid e' nascosta")
	de.call("termina")
	_pr().call("configura", "twilight_giant", 6)   # tier mid
	de.call("avvia", "dlg_mirco", "npc_mirco")
	assert_eq((de.call("scelte_valide") as Array).size(), 3, "a tier mid compare la terza scelta")


func test_scegli_applica_effetti_e_segue_goto() -> void:
	var de: Node = _de()
	de.call("avvia", "dlg_mirco", "npc_mirco")
	# scelta 0 valida = "n1.a": emit_event npc_influenced modo persuaso, goto n2
	assert_true(de.call("scegli", 0), "scelta applicata")
	assert_eq(str(de.call("nodo_corrente").get("text_i18n")), "dialogue.mirco.n2", "goto -> n2")
	assert_eq(_et().call("count", "npc_influenced", {"modo": "persuaso"}), 1.0,
		"emit_event npc_influenced e' passato dall'EventTracker")
	assert_eq(_ns().call("memoria", "npc_mirco"), {"persuaso": 1},
		"e ha aggiornato la memoria dell'NPC toccato")


func test_effetto_flag_scrive_su_knowledgestore() -> void:
	var de: Node = _de()
	_pr().call("configura", "twilight_giant", 6)   # per sbloccare la scelta "b"
	de.call("avvia", "dlg_mirco", "npc_mirco")
	# scelte valide a mid: [n1.a, n1.b, congedo]. La 1 e' "b": flag mirco_sa_del_potere
	assert_true(de.call("scegli", 1), "scelta 'b'")
	assert_true(_ks().call("conosce", "mirco_sa_del_potere"), "l'effetto flag ha scritto")


func test_congedo_termina_e_riavvia_il_mondo() -> void:
	var de: Node = _de()
	_ts().call("imposta_pausa", false)
	de.call("avvia", "dlg_mirco", "npc_mirco")
	assert_true(de.call("in_corso"), "in corso: il mondo e' fermo")
	# ultima scelta valida a low = congedo (goto null)
	var valide: Array = de.call("scelte_valide")
	assert_true(de.call("scegli", valide.size() - 1), "congedo")
	assert_false(de.call("in_corso"), "dialogo finito")


func test_goto_verso_nodo_assente_termina_senza_crash() -> void:
	# dlg_generic: le 3 scelte hanno tutte goto null -> ognuna termina
	var de: Node = _de()
	assert_true(de.call("avvia", "dlg_generic", "npc_generic_03"), "dlg_generic parte")
	assert_true(de.call("scegli", 0), "prima scelta (aiuta)")
	assert_false(de.call("in_corso"), "goto null -> fine")
	assert_eq(_ns().call("memoria", "npc_generic_03"), {"aiutato": 1},
		"l'interlocutore giusto e' stato influenzato")


func test_tutti_i_dialoghi_del_roster_esistono() -> void:
	var gd: Node = _root().get_node("GameData")
	for short in ["mirco", "sidon", "vesna", "aldo", "ottavia", "bruno", "lena", "doran", "generic"]:
		assert_false(gd.call("get_dialogue", "dlg_" + short).is_empty(),
			"dlg_%s caricato da GameData" % short)
