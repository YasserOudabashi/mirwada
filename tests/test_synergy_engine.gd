extends "res://tests/test_case.gd"
## US-401 — SynergyEngine: risoluzione tag -> insieme delle sinergie attive.
## Solo la risoluzione; gli effetti sono US-403+.


func _se() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SynergyEngine")


func _ss() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SynergySources")


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


func prepara() -> void:
	for a in ["/root/SynergyEngine", "/root/BaseSystem", "/root/PetSystem",
			"/root/TalentSystem", "/root/Inventory"]:
		var n: Node = Engine.get_main_loop().root.get_node_or_null(a)
		if n != null:
			n.call("pulisci")


func test_synergy_ids_espone_le_sinergie_dei_dati() -> void:
	var ids: Array = _gd().call("synergy_ids")
	assert_true(ids.has("sinergia_crescita_pozione"), "una sinergia di core.json e' elencata")
	assert_true(ids.size() >= 3, "almeno le 3 di riferimento")


func test_richiede_tag_soddisfatti_rende_attiva() -> void:
	# sinergia_crescita_pozione: richiede { crescita: 2, pozione: 2 }
	_se().call("imposta_override_tag", {"crescita": 2, "pozione": 2, "bestia": 1})
	assert_true(_se().call("e_attiva", "sinergia_crescita_pozione"),
		"tag sufficienti -> sinergia attiva")
	assert_true((_se().call("attive") as Array).has("sinergia_crescita_pozione"),
		"e compare in attive()")


func test_richiede_tag_sotto_soglia_non_attiva() -> void:
	_se().call("imposta_override_tag", {"crescita": 2, "pozione": 1})  # pozione 1 < 2
	assert_false(_se().call("e_attiva", "sinergia_crescita_pozione"),
		"un richiede_tag sotto soglia -> non attiva")
	assert_eq(_se().call("tag_mancanti", "sinergia_crescita_pozione"), {"pozione": 1},
		"tag_mancanti dice quanto manca")


func test_esclude_tag_presente_blocca_la_sinergia() -> void:
	# sinergia_studio_sereno: richiede { occulto:1, conoscenza:1 }, esclude { corruzione:1 }
	_se().call("imposta_override_tag", {"occulto": 1, "conoscenza": 1})
	assert_true(_se().call("e_attiva", "sinergia_studio_sereno"), "senza corruzione -> attiva")
	_se().call("imposta_override_tag", {"occulto": 1, "conoscenza": 1, "corruzione": 1})
	assert_false(_se().call("e_attiva", "sinergia_studio_sereno"),
		"un esclude_tag presente -> non attiva")


func test_attive_e_ordinata_e_deterministica() -> void:
	_se().call("imposta_override_tag", {"crescita": 2, "pozione": 2, "occulto": 1, "conoscenza": 1})
	var a: Array = _se().call("attive")
	var b: Array = a.duplicate()
	b.sort()
	assert_eq(a, b, "attive() e' in ordine lessicografico")


func test_rivaluta_emette_solo_sui_cambi_reali() -> void:
	var attivate: Array = []
	var disattivate: Array = []
	_se().connect("sinergia_attivata", func(id: String) -> void: attivate.append(id))
	_se().connect("sinergia_disattivata", func(id: String) -> void: disattivate.append(id))

	_se().call("imposta_override_tag", {"crescita": 2, "pozione": 2})
	_se().call("rivaluta")
	assert_true(attivate.has("sinergia_crescita_pozione"), "prima rivaluta -> attivata")

	attivate.clear()
	_se().call("rivaluta")  # stesso stato
	assert_true(attivate.is_empty(), "stesso stato -> nessun segnale")

	_se().call("imposta_override_tag", {"crescita": 1})
	_se().call("rivaluta")
	assert_true(disattivate.has("sinergia_crescita_pozione"), "tolto un tag -> disattivata")


func test_un_segnale_di_una_fonte_fa_rivalutare() -> void:
	var attivate: Array = []
	_se().connect("sinergia_attivata", func(id: String) -> void: attivate.append(id))
	var bs: Node = Engine.get_main_loop().root.get_node_or_null("BaseSystem")
	var inv: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	var ps: Node = Engine.get_main_loop().root.get_node_or_null("PetSystem")
	# giardino (crescita+pozione) + laboratorio (pozione) + capra (crescita) ->
	# crescita 2, pozione 2 -> sinergia_crescita_pozione
	for tipo in ["giardino", "laboratorio"]:
		for item_id in bs.call("costo_prossimo", tipo):
			inv.call("aggiungi", item_id, int(bs.call("costo_prossimo", tipo)[item_id]))
		bs.call("costruisci", tipo)
	ps.call("imposta_pet", "capra_lunare")  # emette pet_impostato -> rivaluta
	assert_true(_se().call("e_attiva", "sinergia_crescita_pozione"),
		"i segnali delle fonti hanno riportato la sinergia attiva senza chiamare rivaluta a mano")
	assert_true(attivate.has("sinergia_crescita_pozione"), "e sinergia_attivata e' stato emesso")


func test_synergy_sources_include_la_fonte_sequenza() -> void:
	var prog: Node = Engine.get_main_loop().root.get_node_or_null("Progression")
	prog.call("configura", "twilight_giant", 9)
	var pf: Dictionary = _ss().call("per_fonte")
	assert_true(pf.has("sequenza"), "per_fonte espone la fonte 'sequenza'")
	var tg_tags: Array = (_gd().call("get_pathway", "twilight_giant") as Dictionary).get("tags", [])
	if not tg_tags.is_empty():
		assert_true((pf["sequenza"] as Dictionary).has(str(tg_tags[0])),
			"i tag del Pathway attivo sono nella fonte sequenza")
	prog.call("configura", "", 9)
