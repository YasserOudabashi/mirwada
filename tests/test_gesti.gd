extends "res://tests/test_case.gd"
## US-8B80 — gesti di Enel fuori dal combattimento: interact, pickup, drink, ritual (data/animations.json).


func _root() -> Node:
	return Engine.get_main_loop().root


func _player() -> CharacterBody2D:
	var p: CharacterBody2D = preload("res://scenes/player.tscn").instantiate()
	_root().add_child(p)
	return p


func _stato(p: Node) -> String:
	return str(p.get_node("AnimationMachine").call("stato_corrente"))


func test_un_gesto_resta_finche_dura_e_camminare_lo_interrompe() -> void:
	var p := _player()
	p.call("gesto", "interact")
	assert_eq(_stato(p), "interact", "parte il gesto")
	p.velocity = Vector2.ZERO
	p.call("_aggiorna_animazione")
	assert_eq(_stato(p), "interact", "da fermo il gesto non lo copre l'idle")
	p.get_node("AnimationMachine").animazione_finita.emit("interact")
	assert_eq(str(p.call("gesto_corrente")), "", "finita l'animazione, finito il gesto")
	p.call("gesto", "pickup")
	p.velocity = Vector2(80, 0)
	p.call("_aggiorna_animazione")
	assert_eq(_stato(p), "walk", "camminare interrompe il gesto")
	p.free()


func test_bere_e_il_rituale_dai_loro_sistemi() -> void:
	var p := _player()
	_root().get_node("PotionSystem").pozione_bevuta.emit(true, false)
	assert_eq(_stato(p), "drink", "la pozione bevuta: Enel beve")
	p.get_node("AnimationMachine").animazione_finita.emit("drink")
	var rs: Node = _root().get_node("RitualSystem")
	rs.rituale_avviato.emit(9)
	assert_eq(_stato(p), "ritual", "il rituale comincia")
	p.velocity = Vector2.ZERO
	p.call("_aggiorna_animazione")
	assert_eq(_stato(p), "ritual", "dura quanto il rituale")
	rs.rituale_completato.emit(9)
	assert_eq(str(p.call("gesto_corrente")), "", "finito il rituale")
	assert_eq(_stato(p), "idle", "torna fermo")
	p.free()


func test_raccogliere_da_fermo_piega_enel() -> void:
	var p := _player()
	var oggetto := preload("res://scripts/item_pickup.gd").new()
	oggetto.set("char_id", "lingotto_ferro")
	_root().add_child(oggetto)
	p.velocity = Vector2.ZERO
	oggetto.call("_raccolto_da", p)
	assert_eq(_stato(p), "pickup", "da fermo si piega a raccogliere")
	var altro := preload("res://scripts/item_pickup.gd").new()
	altro.set("char_id", "lingotto_ferro")
	_root().add_child(altro)
	p.call("fine_gesto", "pickup")
	p.get_node("AnimationMachine").animazione_finita.emit("pickup")
	p.velocity = Vector2(80, 0)
	altro.call("_raccolto_da", p)
	assert_ne(_stato(p), "pickup", "camminandoci sopra niente gesto (scivolerebbe)")
	_root().get_node("Inventory").call("rimuovi", "lingotto_ferro", 2)
	p.free()
