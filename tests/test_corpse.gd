extends "res://tests/test_case.gd"
## US-214B — pulizia di default del cadavere del nemico.

const EnemyScene := preload("res://scenes/enemy.tscn")


func _root() -> Node:
	return Engine.get_main_loop().root


func _nemico(cfg_cadavere: Dictionary) -> Node:
	var e: Node = EnemyScene.instantiate()
	_root().add_child(e)
	await Engine.get_main_loop().process_frame
	# sovrascrive la config letta da GameData col caso di test
	var cfg: Dictionary = e.get("_cfg").duplicate(true)
	cfg["cadavere"] = cfg_cadavere
	cfg["caratteristica"] = {}   # niente drop in questi test
	e.set("_cfg", cfg)
	return e


func test_permanenza_zero_il_cadavere_resta() -> void:
	var e: Node = await _nemico({"permanenza_s": 0.0, "dissolvenza_s": 1.0})
	e.get_node("StatsComponent").set("hp", 0.0)
	for i in 20:
		await Engine.get_main_loop().process_frame
	assert_true(is_instance_valid(e), "permanenza_s 0 -> il cadavere non si libera (lo gestira' un altro sistema)")
	assert_eq(e.call("stato"), "MORTO", "resta MORTO")
	e.free()


func test_cadavere_sfuma_e_si_libera() -> void:
	var e: Node = await _nemico({"permanenza_s": 0.05, "dissolvenza_s": 0.05})
	e.get_node("StatsComponent").set("hp", 0.0)
	# permanenza + dissolvenza = ~0.1s reali
	await Engine.get_main_loop().create_timer(0.4).timeout
	assert_false(is_instance_valid(e), "il cadavere e' stato liberato dopo permanenza + dissolvenza")


func test_il_segnale_morto_resta_disponibile() -> void:
	# La dissolvenza NON sostituisce il segnale: chi lo vuole gestire lo riceve
	# comunque, prima che il cadavere sfumi.
	var e: Node = await _nemico({"permanenza_s": 0.0})
	var visto: Array = []
	e.morto.connect(func(chi: Node) -> void: visto.append(chi))
	e.get_node("StatsComponent").set("hp", 0.0)
	await Engine.get_main_loop().process_frame
	assert_eq(visto.size(), 1, "segnale morto emesso")
	e.free()
