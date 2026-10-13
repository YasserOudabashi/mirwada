extends "res://tests/test_case.gd"
## US-614 — gli 8 grafi di dialogo del roster + i popolani generici: coerenti
## col ruolo meccanico di design-npc-quest cap. 2 (Ottavia concede testi_*,
## Bruno apre il porto notturno con 'aiutato', ecc.).

const AreaGate := preload("res://scripts/area_gate.gd")


func _root() -> Node: return Engine.get_main_loop().root
func _de() -> Node: return _root().get_node("DialogueEngine")
func _ks() -> Node: return _root().get_node("KnowledgeStore")
func _ns() -> Node: return _root().get_node("NpcSystem")
func _ts() -> Node: return _root().get_node("TimeSystem")
func _pr() -> Node: return _root().get_node("Progression")


func prepara() -> void:
	_de().call("termina")
	_ks().call("dimentica_tutto")
	_ns().call("pulisci")
	_ts().call("da_salvataggio", {})
	_ts().call("imposta_pausa", false)
	_pr().call("configura", "twilight_giant", 9)


func test_ogni_dialogo_del_roster_si_gioca_fino_in_fondo() -> void:
	var gd: Node = _root().get_node("GameData")
	for short in ["mirco", "sidon", "vesna", "aldo", "ottavia", "bruno", "lena", "doran", "generic"]:
		var did: String = "dlg_" + short
		assert_false(gd.call("get_dialogue", did).is_empty(), "%s caricato" % did)
		# scelta l'ultima valida (il congedo) a ogni nodo: si arriva a fine senza loop infiniti
		assert_true(_de().call("avvia", did, "npc_%s" % (short if short != "generic" else "generic_01")),
			"%s parte" % did)
		var passi := 0
		while bool(_de().call("in_corso")) and passi < 20:
			var valide: Array = _de().call("scelte_valide")
			assert_true(valide.size() > 0, "%s: ogni nodo ha almeno una scelta valida" % did)
			_de().call("scegli", valide.size() - 1)
			passi += 1
		assert_false(_de().call("in_corso"), "%s termina" % did)


func test_ottavia_concede_il_flag_che_apre_l_archivio() -> void:
	_pr().call("configura", "twilight_giant", 6)   # tier mid: la prima scelta di Ottavia
	assert_true(_de().call("avvia", "dlg_ottavia", "npc_ottavia"), "dlg_ottavia parte")
	_de().call("scegli", 0)                         # "vorrei leggere..." -> n2
	_de().call("scegli", 0)                         # "grazie" -> flag testi_ordine_minore
	assert_true(_ks().call("conosce", "testi_ordine_minore"), "Ottavia concede il flag")
	# e quel flag apre il gate 'conoscenza' dell'Archivio Sepolto (US-611)
	var ag: Area2D = AreaGate.new()
	ag.call("configura", "archivio_sepolto",
		{"tipo": "conoscenza", "valore": "testi_ordine_minore", "area": "ali_interne"})
	_root().add_child(ag)
	assert_true(ag.call("e_aperto"), "l'ala interna dell'Archivio ora e' aperta")
	ag.free()


func test_bruno_apre_il_porto_notturno_solo_di_notte() -> void:
	# di giorno la scelta 'aiuta' (e_notte:true) e' nascosta
	_de().call("avvia", "dlg_bruno", "npc_bruno")
	for sc in (_de().call("scelte_valide") as Array):
		assert_false(str(sc["text_i18n"]).ends_with(".aiuta"), "di giorno 'aiuta' e' nascosta")
	_de().call("termina")
	_ts().call("avanza", 120.0 * 3.0)              # -> notte_fonda
	_de().call("avvia", "dlg_bruno", "npc_bruno")
	_de().call("scegli", 0)                         # aiuta
	assert_true(_ks().call("conosce", "bruno_porto_notturno"), "aiutato di notte -> flag")
	assert_eq(int(_ns().call("memoria", "npc_bruno").get("aiutato", 0)), 1, "modo 'aiutato' registrato")


func test_i18n_dei_dialoghi_tradotto() -> void:
	var gd: Node = _root().get_node("GameData")
	# nessun testo del roster resta uno stub TODO
	for k in ["dialogue.ottavia.n1", "dialogue.bruno.n1", "dialogue.doran.n1", "dialogue.lena.n2"]:
		var t: String = str(gd.call("tr_data", k))
		assert_false(t.begins_with("TODO"), "%s tradotto" % k)
		assert_ne(t, k, "%s risolve a testo" % k)
