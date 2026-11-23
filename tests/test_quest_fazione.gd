extends "res://tests/test_case.gd"
## US-1303 — La posizione di fazione dell'Atto II: le carte dell'Archivio finite al porto. Ottavia offre la quest
## solo da tier mid; al porto si sceglie nel dialogo di Bruno da che parte stare, e la reputazione si prende una
## volta sola (sta nelle ricompense delle due quest, che si escludono).

func _root() -> Node: return Engine.get_main_loop().root
func _qs() -> Node: return _root().get_node("QuestSystem")
func _ks() -> Node: return _root().get_node("KnowledgeStore")
func _fs() -> Node: return _root().get_node("FactionSystem")
func _de() -> Node: return _root().get_node("DialogueEngine")
func _pr() -> Node: return _root().get_node("Progression")
func _ts() -> Node: return _root().get_node("TimeSystem")


func prepara() -> void:
	_qs().call("pulisci")
	_ks().call("dimentica_tutto")
	_root().get_node("EventTracker").call("azzera")
	_root().get_node("NpcSystem").call("pulisci")
	_fs().call("pulisci")
	_de().call("termina")
	_pr().call("configura", "twilight_giant", 6)
	_ts().call("forza_momento", "notte_fonda")


## La suite non ha un 'dopo': ogni test rimette a posto ora e Sequenza alla fine.
func _dopo() -> void:
	_ts().call("libera_momento")
	_de().call("termina")
	_pr().call("configura", "twilight_giant", 9)


## Sceglie la scelta con quella chiave fra quelle visibili; false se non si vede.
func _scegli(chiave: String) -> bool:
	var valide: Array = _de().call("scelte_valide")
	for i in valide.size():
		if str(valide[i]["text_i18n"]) == chiave:
			return bool(_de().call("scegli", i))
	return false


## Fino al momento della scelta: lasciapassare, quest presa, una mano a Bruno, la domanda sulle carte.
func _fino_alla_scelta() -> void:
	_ks().call("imposta", "testi_ordine_minore", true)
	_de().call("avvia", "dlg_ottavia", "npc_ottavia")
	_scegli("dialogue.ottavia.n1.ordine")
	_scegli("dialogue.ottavia.n3.accetta")
	_de().call("avvia", "dlg_bruno", "npc_bruno")
	_scegli("dialogue.bruno.n1.aiuta")
	_de().call("avvia", "dlg_bruno", "npc_bruno")
	_scegli("dialogue.bruno.n1.carte")


func test_ottavia_la_offre_solo_da_tier_mid() -> void:
	_ks().call("imposta", "testi_ordine_minore", true)
	_pr().call("configura", "twilight_giant", 8)
	_de().call("avvia", "dlg_ottavia", "npc_ottavia")
	assert_false(_scegli("dialogue.ottavia.n1.ordine"), "a tier low Ottavia non offre la quest")
	_de().call("termina")
	_pr().call("configura", "twilight_giant", 6)
	_de().call("avvia", "dlg_ottavia", "npc_ottavia")
	assert_true(_scegli("dialogue.ottavia.n1.ordine"), "a tier mid si'")
	assert_true(_scegli("dialogue.ottavia.n3.accetta"), "e si accetta")
	assert_eq(str(_qs().call("stato", "q_ottavia_02")), "attiva", "la quest parte")
	_dopo()


func test_bruno_parla_delle_carte_solo_a_chi_gli_ha_dato_una_mano() -> void:
	_de().call("avvia", "dlg_bruno", "npc_bruno")
	assert_false(_scegli("dialogue.bruno.n1.carte"), "senza la quest e senza aiuto Bruno non ne parla")
	_de().call("termina")
	_fino_alla_scelta()
	assert_eq(str(_de().call("nodo_corrente").get("text_i18n", "")), "dialogue.bruno.n3", "ora si' : il nodo della scelta")
	assert_eq(int(_qs().call("passo_corrente", "q_ottavia_02")), 1, "il primo passo (evento npc_influenced) e' fatto")
	_dopo()


func test_con_l_ordine() -> void:
	_fino_alla_scelta()
	_scegli("dialogue.bruno.n3.ordine")
	assert_eq(str(_qs().call("stato", "q_ottavia_02")), "completata", "le carte tornano all'Archivio")
	assert_eq(float(_fs().call("reputazione", "ordine_minore")), 25.0, "l'Ordine se ne ricorda")
	assert_eq(float(_fs().call("reputazione", "porto")), -15.0, "il porto anche")
	# cambiare idea dopo non si puo': l'altra quest non parte e la reputazione non si muove
	_de().call("avvia", "dlg_bruno", "npc_bruno")
	_scegli("dialogue.bruno.n1.carte")
	_scegli("dialogue.bruno.n3.porto")
	assert_eq(str(_qs().call("stato", "q_bruno_02")), "non_iniziata", "il lato e' gia' scelto")
	assert_eq(float(_fs().call("reputazione", "porto")), -15.0, "niente reputazione due volte")
	_dopo()


func test_con_il_porto() -> void:
	_fino_alla_scelta()
	_scegli("dialogue.bruno.n3.porto")
	assert_eq(str(_qs().call("stato", "q_bruno_02")), "completata", "le carte restano al porto")
	assert_eq(str(_qs().call("stato", "q_ottavia_02")), "fallita", "la quest di Ottavia fallisce")
	assert_eq(float(_fs().call("reputazione", "porto")), 25.0, "il porto ti conta fra i suoi")
	assert_eq(float(_fs().call("reputazione", "ordine_minore")), -15.0, "l'Ordine no")
	_de().call("avvia", "dlg_bruno", "npc_bruno")
	_scegli("dialogue.bruno.n1.carte")
	_scegli("dialogue.bruno.n3.ordine")
	assert_eq(float(_fs().call("reputazione", "ordine_minore")), -15.0, "ripensarci non cambia niente")
	_dopo()
