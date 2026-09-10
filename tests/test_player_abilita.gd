extends "res://tests/test_case.gd"
## US-802 — le abilita' possedute si lanciano dai tasti 1-4 (hotbar), via
## AbilityEngine.execute; nessuna logica di bersaglio nuova (la fa gia'
## execute). Twilight Giant Sequenza 9 ha esattamente 2 abilita'
## (data/pathways/twilight_giant.json): buon caso per uno slot pieno
## (0) e uno vuoto (3).

const PlayerScene := preload("res://scenes/player.tscn")


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func prepara() -> void:
	_n("/root/AbilityEngine").call("clear_cooldowns")
	_n("/root/AbilityEngine").call("clear_granted")
	_n("/root/EventTracker").call("azzera")
	_n("/root/Progression").call("configura", "twilight_giant", 9)


func _giocatore() -> Node:
	var player: Node = PlayerScene.instantiate()
	Engine.get_main_loop().root.add_child(player)
	return player


func test_lancia_abilita_slot_esegue_la_n_esima_posseduta() -> void:
	var player: Node = _giocatore()
	var owned: Array = _n("/root/AbilityEngine").call("owned_abilities", player)
	assert_eq(owned.size(), 2, "Twilight Giant Sequenza 9 ha 2 abilita'")

	var r0: Dictionary = player.call("lancia_abilita_slot", 0)
	assert_true(bool(r0.get("ok", false)),
		"slot 0 (%s) eseguito: %s" % [owned[0], r0.get("reason", "")])
	assert_almost_eq(
		_n("/root/EventTracker").call("count", "ability_used", {"ability_id": str(owned[0])}),
		1.0, "ability_used tracciato per l'abilita' dello slot 0")

	player.free()


func test_lancia_abilita_slot_oltre_le_possedute_non_esegue_nulla() -> void:
	var player: Node = _giocatore()
	var r: Dictionary = player.call("lancia_abilita_slot", 3)  # solo 2 possedute
	assert_false(bool(r.get("ok", false)), "slot 3 vuoto: nessuna esecuzione")
	assert_almost_eq(_n("/root/EventTracker").call("count", "ability_used", {}), 0.0,
		"nessun evento emesso per uno slot vuoto")

	player.free()


func test_input_abilita_1_lancia_lo_slot_0() -> void:
	var player: Node = _giocatore()
	var owned: Array = _n("/root/AbilityEngine").call("owned_abilities", player)

	Input.action_press("abilita_1")
	player.call("_gestisci_input_abilita")
	Input.action_release("abilita_1")

	assert_almost_eq(
		_n("/root/EventTracker").call("count", "ability_used", {"ability_id": str(owned[0])}),
		1.0, "il tasto abilita_1 lancia la prima abilita' posseduta")

	player.free()


func test_input_ignorato_durante_un_attacco() -> void:
	var player: Node = _giocatore()
	player.call("_inizia_attacco")

	Input.action_press("abilita_1")
	player.call("_gestisci_input_abilita")
	Input.action_release("abilita_1")

	assert_almost_eq(_n("/root/EventTracker").call("count", "ability_used", {}), 0.0,
		"nessuna abilita' lanciata mentre _attaccando e' true")

	player.free()


## Onboarding: il giocatore porta una Label col nome, come gli NPC, cosi' a
## schermo si capisce quale figura si controlla.
func test_giocatore_ha_una_label_col_nome() -> void:
	var gs: Node = _n("/root/GameState")
	var salvato: String = str(gs.get("nome_personaggio"))
	gs.set("nome_personaggio", "Tester")
	var player: Node = _giocatore()

	var lbl: Label = player.get_node_or_null("Nome")
	assert_false(lbl == null, "il giocatore ha una Label 'Nome'")
	assert_eq(lbl.text, "Tester", "la Label mostra il nome del personaggio corrente")

	player.free()
	gs.set("nome_personaggio", salvato)
