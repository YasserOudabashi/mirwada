extends "res://tests/test_case.gd"
## US-1305c — I luoghi dei rituali sono posti dove il giocatore puo' stare: dentro un interno si e' nella sua zona,
## e una zona vale anche come gli altri luoghi di regions.json "zone_anche".

const Mondo := preload("res://scripts/world/mondo.gd")

func _root() -> Node: return Engine.get_main_loop().root
func _ws() -> Node: return _root().get_node("WorldState")
func _rs() -> Node: return _root().get_node("RitualSystem")


func prepara() -> void:
	_rs().call("imposta_luogo", [])
	_ws().call("pulisci")


func test_una_zona_vale_anche_come_altri_luoghi() -> void:
	var r := {"location_tags": ["vetta"], "sacrifices": [], "sigils": []}
	_ws().call("entra_regione", "marche_crepuscolo")
	_ws().call("imposta_zona", "altura")
	assert_false(_rs().call("prerequisiti", r)["ok"], "sul passo non si e' sulla vetta")
	_ws().call("imposta_zona", "trono_del_gigante")
	assert_true(_rs().call("prerequisiti", r)["ok"], "al Trono del Gigante si e' sulla vetta")
	_ws().call("pulisci")


func test_dentro_un_interno_si_e_nella_sua_zona() -> void:
	_root().get_node("Progression").call("configura", "fool", 4)        # la Frontiera e' aperta
	var m: Node2D = Mondo.new()
	var p: Node2D = preload("res://scenes/player.tscn").instantiate()
	m.add_child(p)
	_root().add_child(m)
	var varco: Area2D = m.get_node_or_null("Varco_teatro")
	assert_true(varco != null, "il teatro abbandonato ha il suo ingresso nella Frontiera")
	if varco != null:
		assert_true(m.call("entra", varco), "ci si entra")
		assert_eq(str(_ws().call("zona_corrente")), "teatro", "dentro si e' nel teatro (\"zona\" dell'interno)")
		var r := {"location_tags": ["palco"], "sacrifices": [], "sigils": []}
		assert_true(_rs().call("prerequisiti", r)["ok"], "che vale anche come palco")
		m.call("esci")
		m.call("aggiorna_regione", p.position)
		assert_ne(str(_ws().call("zona_corrente")), "teatro", "usciti, la zona torna quella della mappa")
	m.free()
	_ws().call("pulisci")
	_root().get_node("Progression").call("configura", "twilight_giant", 9)
