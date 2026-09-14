extends "res://tests/test_case.gd"
## US-906 — sezione "Dono" nel diagramma per i Pathway non_standard: quando
## la Sequenza corrente ha 'boon' invece di 'potion', la pagina mostra i
## requisiti (BoonSystem.requisiti_stato()) e un bottone "Ricevi il Dono"
## (BoonSystem.ricevi_boon()) al posto di Prepara/Bevi. Stesso schema di
## tests/test_page_avanzamento.gd (US-810), ma sul ramo 'boon'. Usa
## eternal_aeon Sequenza 5 (US-904/905): quest + comportamento + sacrificio
## insieme, cosi' un solo test esercita tutti e tre i rami di _riga_requisito.

const OverlayScene := preload("res://scenes/book_overlay.tscn")


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	var b: Node = _n("/root/Book")
	if b != null:
		b.call("azzera")
	Engine.get_main_loop().root.get_tree().paused = false
	# Sequenza 5 e' anche uno dei 4 "salti di fascia" di TribulationSystem
	# (fase 7, Pathway-agnostico): senza questo Progression.avanza() resta
	# bloccato anche a requisiti del Boon tutti soddisfatti (stesso motivo
	# per cui test_page_avanzamento.gd la chiama nella sua prepara()).
	_n("/root/TribulationSystem").call("marca_superate_tutte")
	_n("/root/Progression").call("configura", "eternal_aeon", 5)
	_n("/root/BoonSystem").call("_riparti")
	_n("/root/EventTracker").call("azzera")
	_n("/root/Inventory").call("pulisci")
	(_n("/root/QuestSystem").get("_completate") as Array).clear()
	var kn: Node = _n("/root/KnowledgeStore")
	if kn != null:
		kn.call("dimentica_tutto")


func _pagina() -> Node:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var b: Node = _n("/root/Book")
	b.call("apri")
	b.call("vai_a", "diagramma")
	for i in 4:
		ov.call("_process", 0.2)
	return ov


func _completa_quest(quest_id: String) -> void:
	(_n("/root/QuestSystem").get("_completate") as Array).append(quest_id)


func test_sezione_dono_al_posto_di_prepara_bevi() -> void:
	var ov: CanvasLayer = _pagina()
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)
	var stato: Dictionary = pag.call("avanzamento_stato")
	assert_true(bool(stato.get("boon", false)), "il ramo 'boon' e' quello attivo, non 'potion'")
	assert_eq((stato.get("requisiti", []) as Array).size(), 3,
		"eternal_aeon_5: tre requisiti (quest+comportamento+sacrificio)")
	assert_false(bool(stato.get("puo_ricevere", true)), "nessun requisito soddisfatto ancora")
	_n("/root/Book").call("chiudi")
	ov.free()


func test_ricevi_dono_rifiutato_finche_mancano_requisiti() -> void:
	var ov: CanvasLayer = _pagina()
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)
	var res: Dictionary = pag.call("ricevi_dono")
	assert_false(bool(res.get("ok", false)), "ricevi_dono rifiutato")
	assert_eq(str(res.get("reason", "")), "requisiti_mancanti", "motivo esplicito")
	assert_eq(int(_n("/root/Progression").call("sequence")), 5, "Sequenza invariata")
	_n("/root/Book").call("chiudi")
	ov.free()


func test_ricevi_dono_con_tutti_i_requisiti_soddisfatti_avanza() -> void:
	_completa_quest("q_vesna_01")
	for i in 4:
		_n("/root/EventTracker").call("emit_event", "ability_used",
			{"ability_id": "ea_richiamo_del_momento_perduto"})
	_n("/root/Inventory").call("aggiungi", "memoria_cristallizzata", 2)

	var ov: CanvasLayer = _pagina()
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)
	var stato: Dictionary = pag.call("avanzamento_stato")
	assert_true(bool(stato.get("puo_ricevere", false)), "tutti e tre i requisiti soddisfatti")

	var res: Dictionary = pag.call("ricevi_dono")
	assert_true(bool(res.get("ok", false)), "ricevi_dono ok")
	assert_true(bool(res.get("avanzato", false)), "Sequenza avanzata")
	assert_eq(int(_n("/root/Progression").call("sequence")), 4, "5 -> 4")

	_n("/root/Book").call("chiudi")
	ov.free()
	_n("/root/Progression").call("configura", "eternal_aeon", 9)


func test_sequenza_standard_mostra_ancora_prepara_bevi() -> void:
	# Nessuna regressione: un Pathway standard resta sul ramo 'potion'.
	_n("/root/Progression").call("configura", "twilight_giant", 9)
	var ov: CanvasLayer = _pagina()
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)
	var stato: Dictionary = pag.call("avanzamento_stato")
	assert_false(bool(stato.get("boon", false)), "twilight_giant_9 resta sul ramo 'potion'")
	assert_true(stato.has("potion"), "la chiave 'potion' e' quella popolata, come prima di US-906")
	_n("/root/Book").call("chiudi")
	ov.free()
	_n("/root/Progression").call("configura", "eternal_aeon", 5)
