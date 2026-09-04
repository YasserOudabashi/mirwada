extends "res://tests/test_case.gd"
## US-318 — oggetti Sigillati: molto potenti, ma con un prezzo sempre pagato.

const StatsComponent := preload("res://scripts/stats_component.gd")


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/Equipment") != null:
		_n("/root/Equipment").call("pulisci")
	if _n("/root/Inventory") != null:
		_n("/root/Inventory").call("pulisci")
	if _n("/root/Madness") != null:
		_n("/root/Madness").call("da_salvataggio", {})


func _giocatore_finto() -> Node2D:
	var p := Node2D.new()
	p.add_to_group("player")
	var stats: Node = StatsComponent.new()
	stats.name = "StatsComponent"
	stats.call("configure_from_balance", 9)
	p.add_child(stats)
	Engine.get_main_loop().root.add_child(p)
	return p


func _equipaggia(item_id: String) -> String:
	var inv: Node = _n("/root/Inventory")
	var eq: Node = _n("/root/Equipment")
	var creati: Array = inv.call("aggiungi", item_id, 1)
	eq.call("equipaggia", creati[0])
	return (eq.call("slot_pieni") as Dictionary).keys()[0]


func test_equipaggiare_un_sigillato_fa_salire_la_follia_nel_tempo() -> void:
	var p: Node2D = _giocatore_finto()
	var eq: Node = _n("/root/Equipment")
	_equipaggia("lama_del_pentimento")   # follia_al_secondo: 0.4
	var mad: Node = _n("/root/Madness")
	assert_almost_eq(float(mad.call("valore")), 0.0, "follia a 0 prima del tick")
	eq.call("tick_effects", 1.0)
	assert_almost_eq(float(mad.call("valore")), 0.4, "un secondo di tick aggiunge 0.4 follia", 0.01)
	eq.call("tick_effects", 2.0)
	assert_almost_eq(float(mad.call("valore")), 1.2, "il tick continua ad accumularsi", 0.01)
	p.free()


func test_rimuovere_il_sigillato_ferma_il_tick() -> void:
	var p: Node2D = _giocatore_finto()
	var eq: Node = _n("/root/Equipment")
	var mount: String = _equipaggia("lama_del_pentimento")
	eq.call("tick_effects", 1.0)
	var mad: Node = _n("/root/Madness")
	var follia_con_equip: float = float(mad.call("valore"))
	assert_true(eq.call("rimuovi_slot", mount), "smonta la lama")
	eq.call("tick_effects", 5.0)   # se non si e' fermato, salirebbe ancora
	assert_almost_eq(float(mad.call("valore")), follia_con_equip, "follia ferma dopo la rimozione", 0.01)
	p.free()


func test_spiritualita_drain_al_secondo() -> void:
	var p: Node2D = _giocatore_finto()
	var stats: Node = p.get_node("StatsComponent")
	var eq: Node = _n("/root/Equipment")
	var sp0: float = float(stats.get("spiritualita"))   # a piena carica dopo configure_from_balance
	_equipaggia("corazza_espiazione")   # spiritualita_drain_al_secondo: 0.5
	eq.call("tick_effects", 2.0)
	assert_almost_eq(float(stats.get("spiritualita")), sp0 - 1.0, "2s di drain a 0.5/s = -1.0", 0.01)
	p.free()


func test_tag_negativo_conta_in_tag_attivi() -> void:
	var p: Node2D = _giocatore_finto()
	var eq: Node = _n("/root/Equipment")
	var prima: int = int((eq.call("tag_attivi") as Dictionary).get("maledizione", 0))
	_equipaggia("anello_del_richiamo")   # tag_negativo: maledizione
	assert_eq(int((eq.call("tag_attivi") as Dictionary).get("maledizione", 0)), prima + 1,
		"il tag_negativo del Sigillato conta come un tag attivo")
	p.free()


func test_riequipaggiare_non_accumula_il_tick() -> void:
	var p: Node2D = _giocatore_finto()
	var eq: Node = _n("/root/Equipment")
	var mount: String = _equipaggia("lama_del_pentimento")
	eq.call("rimuovi_slot", mount)
	_equipaggia("lama_del_pentimento")
	eq.call("tick_effects", 1.0)
	var mad: Node = _n("/root/Madness")
	assert_almost_eq(float(mad.call("valore")), 0.4, "un solo tick attivo, non due impilati", 0.01)
	p.free()


func test_un_equip_non_sigillato_non_produce_alcun_tick() -> void:
	var p: Node2D = _giocatore_finto()
	var eq: Node = _n("/root/Equipment")
	_equipaggia("spada_ferrea")
	eq.call("tick_effects", 5.0)
	assert_almost_eq(float(_n("/root/Madness").call("valore")), 0.0, "nessun tick senza sigillato:true")
	p.free()
