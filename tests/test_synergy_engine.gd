extends "res://tests/test_case.gd"
## US-401/402/403 — SynergyEngine: risoluzione dei tag, rivalutazione reattiva,
## effetti modifica_stat e modifica_follia.

const StatsComponent := preload("res://scripts/stats_component.gd")

var _p: Node2D = null


func _se() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SynergyEngine")


func _ss() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SynergySources")


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


func prepara() -> void:
	for vecchio in Engine.get_main_loop().root.get_tree().get_nodes_in_group("player"):
		vecchio.free()
	for a in ["/root/SynergyEngine", "/root/BaseSystem", "/root/PetSystem",
			"/root/TalentSystem", "/root/Inventory"]:
		var n: Node = Engine.get_main_loop().root.get_node_or_null(a)
		if n != null:
			n.call("pulisci")
	if Engine.get_main_loop().root.get_node_or_null("Madness") != null:
		Engine.get_main_loop().root.get_node_or_null("Madness").call("azzera")
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


func test_synergy_ids_espone_le_sinergie_dei_dati() -> void:
	var ids: Array = _gd().call("synergy_ids")
	assert_true(ids.has("sinergia_crescita_pozione"), "una sinergia di core.json e' elencata")
	assert_true(ids.size() >= 3, "almeno le 3 di riferimento")
	_fine()


func test_richiede_tag_soddisfatti_rende_attiva() -> void:
	# sinergia_crescita_pozione: richiede { crescita: 2, pozione: 2 }
	_se().call("imposta_override_tag", {"crescita": 2, "pozione": 2, "bestia": 1})
	assert_true(_se().call("e_attiva", "sinergia_crescita_pozione"),
		"tag sufficienti -> sinergia attiva")
	assert_true((_se().call("attive") as Array).has("sinergia_crescita_pozione"),
		"e compare in attive()")
	_fine()


func test_richiede_tag_sotto_soglia_non_attiva() -> void:
	_se().call("imposta_override_tag", {"crescita": 2, "pozione": 1})  # pozione 1 < 2
	assert_false(_se().call("e_attiva", "sinergia_crescita_pozione"),
		"un richiede_tag sotto soglia -> non attiva")
	assert_eq(_se().call("tag_mancanti", "sinergia_crescita_pozione"), {"pozione": 1},
		"tag_mancanti dice quanto manca")
	_fine()


func test_esclude_tag_presente_blocca_la_sinergia() -> void:
	# sinergia_studio_sereno: richiede { occulto:1, conoscenza:1 }, esclude { corruzione:1 }
	_se().call("imposta_override_tag", {"occulto": 1, "conoscenza": 1})
	assert_true(_se().call("e_attiva", "sinergia_studio_sereno"), "senza corruzione -> attiva")
	_se().call("imposta_override_tag", {"occulto": 1, "conoscenza": 1, "corruzione": 1})
	assert_false(_se().call("e_attiva", "sinergia_studio_sereno"),
		"un esclude_tag presente -> non attiva")
	_fine()


func test_attive_e_ordinata_e_deterministica() -> void:
	_se().call("imposta_override_tag", {"crescita": 2, "pozione": 2, "occulto": 1, "conoscenza": 1})
	var a: Array = _se().call("attive")
	var b: Array = a.duplicate()
	b.sort()
	assert_eq(a, b, "attive() e' in ordine lessicografico")
	_fine()


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
	_fine()


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
	_fine()


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
	_fine()


func test_modifica_stat_si_applica_e_si_toglie() -> void:
	# sinergia_studio_sereno: modifica_stat spiritualita_max +10% moltiplicativo
	var base: float = _stats().call("get_base", "spiritualita_max")
	_se().call("imposta_override_tag", {"occulto": 1, "conoscenza": 1})
	_se().call("rivaluta")
	assert_almost_eq(_stats().call("get_stat", "spiritualita_max"), base * 1.1,
		"la sinergia attiva alza spiritualita_max del 10% del base")
	_se().call("imposta_override_tag", {})
	_se().call("rivaluta")
	assert_almost_eq(_stats().call("get_stat", "spiritualita_max"), base,
		"disattivata -> il modificatore synergy:<id> e' tolto")
	_fine()


func test_riapplica_rimette_i_modificatori_dopo_un_load() -> void:
	_se().call("imposta_override_tag", {"occulto": 1, "conoscenza": 1})
	_se().call("rivaluta")
	_stats().call("clear_modifiers")  # simulo un giocatore appena comparso in scena
	assert_false(_stats().call("has_modifier", "synergy:sinergia_studio_sereno"), "modificatore perso")
	_se().call("riapplica")
	assert_true(_stats().call("has_modifier", "synergy:sinergia_studio_sereno"),
		"riapplica() rimette i modificatori delle sinergie attive")
	_fine()


func test_modifica_follia_versa_il_delta_al_minuto_in_madness() -> void:
	var m: Node = Engine.get_main_loop().root.get_node_or_null("Madness")
	# anti_ordine_disordine: modifica_follia delta_al_minuto 0.5 (una anti-sinergia
	# soddisfatta accelera la follia)
	_se().call("imposta_override_tag", {"ordine": 2, "disordine": 2})
	_se().call("rivaluta")
	assert_true(_se().call("e_attiva", "anti_ordine_disordine"), "l'anti-sinergia e' soddisfatta")
	var prima: float = m.call("valore")
	_se().call("_process", 60.0)  # un minuto simulato
	assert_almost_eq(m.call("valore"), prima + 0.5,
		"la follia e' salita del delta_al_minuto in un minuto", 0.05)
	_se().call("imposta_override_tag", {})
	_se().call("rivaluta")
	var dopo_stop: float = m.call("valore")
	_se().call("_process", 60.0)
	assert_almost_eq(m.call("valore"), dopo_stop, "disattivata -> non versa piu' nulla")
	_fine()
