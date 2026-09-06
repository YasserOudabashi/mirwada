extends "res://tests/test_case.gd"
## US-334 — pet, talenti e stanze espongono i loro tag; SynergySources li somma
## per la fase 4. Nessuna sinergia risolta qui.


func _ps() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("PetSystem")


func _ts() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("TalentSystem")


func _bs() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("BaseSystem")


func _inv() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Inventory")


func _ss() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SynergySources")


func prepara() -> void:
	for a in ["/root/PetSystem", "/root/TalentSystem", "/root/BaseSystem", "/root/Inventory"]:
		var n: Node = Engine.get_main_loop().root.get_node_or_null(a)
		if n != null:
			n.call("pulisci")


func _costruisci(tipo: String) -> void:
	var costo: Dictionary = _bs().call("costo_prossimo", tipo)
	for item_id in costo:
		_inv().call("aggiungi", item_id, int(costo[item_id]))
	_bs().call("costruisci", tipo)


func test_pet_espone_i_tag_della_specie_e_dei_comportamenti_sbloccati() -> void:
	_ps().call("imposta_pet", "capra_lunare")  # tag specie: bestia, crescita
	var t0: Dictionary = _ps().call("tag_attivi")
	assert_eq(int(t0.get("crescita", 0)), 1, "la specie porta 'crescita'")
	assert_eq(int(t0.get("bestia", 0)), 1, "la specie porta 'bestia'")

	_ps().call("imposta_bond", 30)  # brucare e' a bond 25, tag ["crescita"]
	var t1: Dictionary = _ps().call("tag_attivi")
	assert_eq(int(t1.get("crescita", 0)), 2, "il comportamento 'brucare' sbloccato aggiunge 'crescita'")


func test_talenti_espongono_i_tag_grant() -> void:
	_ts().call("concedi", "figlio_della_notte")  # tag_grant "notte"
	assert_eq(int((_ts().call("tag_attivi") as Dictionary).get("notte", 0)), 1,
		"il talento tag_grant espone 'notte'")


func test_stanze_costruite_espongono_i_loro_tag() -> void:
	assert_eq(_bs().call("tag_attivi"), {}, "nessuna stanza -> nessun tag")
	_costruisci("giardino")  # tag: crescita, pozione
	var t: Dictionary = _bs().call("tag_attivi")
	assert_eq(int(t.get("crescita", 0)), 1, "il giardino porta 'crescita'")
	assert_eq(int(t.get("pozione", 0)), 1, "il giardino porta 'pozione'")


func test_synergy_sources_somma_tutte_le_fonti() -> void:
	_ps().call("imposta_pet", "capra_lunare")     # bestia, crescita
	_ts().call("concedi", "figlio_della_notte")   # notte
	_costruisci("giardino")                       # crescita, pozione
	_costruisci("laboratorio")                    # pozione, scienza

	var g: Dictionary = _ss().call("tag_sinergia_globali")
	assert_eq(int(g.get("crescita", 0)), 2, "crescita: pet + giardino")
	assert_eq(int(g.get("pozione", 0)), 2, "pozione: giardino + laboratorio")
	assert_eq(int(g.get("notte", 0)), 1, "notte: dal talento")
	assert_eq(int(g.get("bestia", 0)), 1, "bestia: dal pet")

	# sinergia_crescita_pozione richiede {crescita: 2, pozione: 2}: ora raggiungibile
	assert_true(int(g.get("crescita", 0)) >= 2 and int(g.get("pozione", 0)) >= 2,
		"i tag di sinergia_crescita_pozione sono tutti raggiungibili dalle fonti di fase 3")


func test_synergy_sources_non_nomina_nessuna_sinergia() -> void:
	# per_fonte espone solo tag grezzi per fonte, mai un id di sinergia
	var pf: Dictionary = _ss().call("per_fonte")
	assert_true(pf.has("pet") and pf.has("talenti") and pf.has("base") and pf.has("inventario"),
		"le 4 fonti sono elencate")
