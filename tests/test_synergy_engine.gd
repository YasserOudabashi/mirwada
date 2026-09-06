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
	if _se() != null:
		_se().call("pulisci")  # azzera override + effetti, non contaminare le altre suite
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


func test_modifica_qualita_crafting_alza_la_qualita_delle_pozioni() -> void:
	var ps: Node = Engine.get_main_loop().root.get_node_or_null("PotionSystem")
	var inv: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	var gd := _gd()
	var ric: Dictionary = gd.call("get_recipe", "ric_cura_minore")  # qualita_base "pura"
	for ing in ric.get("ingredienti", {}):
		inv.call("aggiungi", ing, int(ric["ingredienti"][ing]))
	var senza: Dictionary = ps.call("prepara", "ric_cura_minore")
	assert_eq(str(senza.get("qualita")), "pura", "senza sinergia: qualita' di base")

	# sinergia_crescita_pozione: modifica_qualita_crafting pozioni delta 1
	_se().call("imposta_override_tag", {"crescita": 2, "pozione": 2})
	_se().call("rivaluta")
	for ing in ric.get("ingredienti", {}):
		inv.call("aggiungi", ing, int(ric["ingredienti"][ing]))
	var con: Dictionary = ps.call("prepara", "ric_cura_minore")
	assert_eq(str(con.get("qualita")), "eccelsa", "la sinergia alza di un passo -> eccelsa")
	_fine()


func test_sblocca_ricetta_impara_e_resta_nota() -> void:
	var ps: Node = Engine.get_main_loop().root.get_node_or_null("PotionSystem")
	var kn: Node = Engine.get_main_loop().root.get_node_or_null("KnowledgeStore")
	if kn != null:
		kn.call("dimentica_tutto")
	assert_false(ps.call("ricetta_nota", "ric_cura_maggiore"), "prima: non nota")
	# sinergia_ricettario_condiviso: sblocca_ricetta ric_cura_maggiore
	_se().call("imposta_override_tag", {"conoscenza": 1, "crescita": 1})
	_se().call("rivaluta")
	assert_true(ps.call("ricetta_nota", "ric_cura_maggiore"), "attivata -> nota")
	_se().call("imposta_override_tag", {})
	_se().call("rivaluta")
	assert_true(ps.call("ricetta_nota", "ric_cura_maggiore"),
		"disattivata -> resta nota (imparare non si dimentica)")
	_fine()


func test_modifica_primitiva_altera_il_parametro_prima_dell_handler() -> void:
	var ae: Node = Engine.get_main_loop().root.get_node_or_null("AbilityEngine")
	# execute_stored: esegue le primitive senza il controllo di possesso, e
	# passa comunque da _esegui_primitive (dove vive l'hook US-405).
	var senza: Dictionary = ae.call("execute_stored", "tg_crepuscolo", _p)
	var r_senza := 0.0
	for e in (senza["effects"] as Array):
		if str((e as Dictionary).get("tipo")) == "decay":
			r_senza = float((e as Dictionary).get("raggio", 0.0))
	assert_almost_eq(r_senza, 7.0, "senza sinergia: raggio base del decay (tg_crepuscolo)")

	# sinergia_marea_crepuscolare: modifica_primitiva decay.raggio +20
	_se().call("imposta_override_tag", {"crescita": 1, "bestia": 1})
	_se().call("rivaluta")
	var con: Dictionary = ae.call("execute_stored", "tg_crepuscolo", _p)
	var r_con := 0.0
	for e in (con["effects"] as Array):
		if str((e as Dictionary).get("tipo")) == "decay":
			r_con = float((e as Dictionary).get("raggio", 0.0))
	assert_almost_eq(r_con, 27.0, "con la sinergia: raggio 7 + 20 = 27")

	_se().call("imposta_override_tag", {})
	_se().call("rivaluta")
	assert_true(float(_gd().call("get_ability", "tg_crepuscolo").get("primitive", [{}])[0].get("raggio", 0)) == 7.0,
		"i DATI dell'abilita' non sono stati toccati (la copia)")
	_fine()


func test_conflitto_cumulativo_le_modifica_stat_si_sommano() -> void:
	var base: float = _stats().call("get_base", "spiritualita_max")
	# studio_sereno (+10%) + meditazione_profonda (+5%) sulla stessa stat
	_se().call("imposta_override_tag", {"occulto": 1, "conoscenza": 1, "notte": 1})
	_se().call("rivaluta")
	assert_true(_se().call("e_attiva", "sinergia_studio_sereno") and _se().call("e_attiva", "sinergia_meditazione_profonda"),
		"entrambe attive")
	assert_almost_eq(_stats().call("get_stat", "spiritualita_max"), base * 1.15,
		"i due modificatori synergy:<id> si sommano (+10% +5% = +15%)")
	_fine()


func test_conflitto_esclusivo_vince_la_priorita_piu_alta() -> void:
	var ps: Node = Engine.get_main_loop().root.get_node_or_null("PotionSystem")
	var inv: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	var ric: Dictionary = _gd().call("get_recipe", "ric_cura_minore")  # "pura" (idx 2)
	# crescita_pozione (delta 1, pri 0) + maestria_alchemica (delta 2, pri 10),
	# stessa categoria "pozioni" -> vince maestria (pri 10) -> +2 non +3
	_se().call("imposta_override_tag", {"crescita": 2, "pozione": 2, "scienza": 1})
	_se().call("rivaluta")
	assert_eq(_se().call("bonus_qualita", "pozioni"), 2,
		"esclusivo: vince il delta della priorita' piu' alta, non la somma")
	for ing in ric.get("ingredienti", {}):
		inv.call("aggiungi", ing, int(ric["ingredienti"][ing]))
	# pura (2) + 2 -> clamp a eccelsa (3), la scala e' scarsa/instabile/pura/eccelsa
	assert_eq(str(ps.call("prepara", "ric_cura_minore").get("qualita")), "eccelsa",
		"la pozione sale del solo bonus vincente")

	var sp: Dictionary = _se().call("spiega", "sinergia_crescita_pozione")
	assert_false(bool(sp["applicato"]), "spiega: crescita_pozione non e' applicata")
	assert_eq(str(sp["sovrascritta_da"]), "sinergia_maestria_alchemica",
		"spiega: sovrascritta dalla sinergia a priorita' piu' alta")
	_fine()


func test_aggiungi_abilita_concede_e_revoca() -> void:
	var ae: Node = Engine.get_main_loop().root.get_node_or_null("AbilityEngine")
	# sinergia_istinto_bestiale: aggiungi_abilita mother_dominio_druidico
	assert_false(ae.call("is_granted", _p, "mother_dominio_druidico"), "prima: non prestata")
	_se().call("imposta_override_tag", {"bestia": 1, "guerra": 1})
	_se().call("rivaluta")
	assert_true(ae.call("is_granted", _p, "mother_dominio_druidico"),
		"sinergia attiva -> abilita' prestata permanentemente")
	_se().call("imposta_override_tag", {})
	_se().call("rivaluta")
	assert_false(ae.call("is_granted", _p, "mother_dominio_druidico"),
		"sinergia spenta -> abilita' revocata")
	_fine()
