extends "res://tests/test_case.gd"
## US-011 — nemico base: macchina a stati, componenti, segnale di morte.

const EnemyScene := preload("res://scenes/enemy.tscn")
const Stato_ANTICIPO := 2  # enum Stato { IDLE, INSEGUIMENTO, ANTICIPO, ... }


func _nemico() -> CharacterBody2D:
	var e: CharacterBody2D = EnemyScene.instantiate()
	Engine.get_main_loop().root.add_child(e)
	return e


func test_parte_in_idle_con_i_componenti() -> void:
	var e: CharacterBody2D = _nemico()
	assert_eq(e.stato(), "IDLE", "stato iniziale IDLE")
	assert_true(e.get_node("StatsComponent").has_method("spend_spiritualita"), "ha StatsComponent")
	assert_true(e.get_node("PosturaComponent").has_method("erodi"), "ha PosturaComponent")
	assert_true(e.is_in_group("nemici"), "nel gruppo nemici")
	e.free()


func test_alla_morte_emette_segnale_e_non_si_distrugge() -> void:
	var e: CharacterBody2D = _nemico()
	var morti: Array = []
	e.morto.connect(func(chi: Node) -> void: morti.append(chi))

	var stats: Node = e.get_node("StatsComponent")
	stats.set("hp", 0.0)

	assert_eq(morti.size(), 1, "segnale morto emesso una volta")
	assert_eq(e.stato(), "MORTO", "stato MORTO")
	assert_true(is_instance_valid(e), "il nodo non si e' auto-distrutto")
	e.free()


func test_la_rottura_di_postura_manda_in_stagger() -> void:
	var e: CharacterBody2D = _nemico()
	var stati: Array = []
	e.stato_cambiato.connect(func(s: String) -> void: stati.append(s))
	e.get_node("PosturaComponent").call("erodi", 999.0)
	assert_true(stati.has("STAGGER"), "postura rotta -> STAGGER")
	e.free()


## US-020: la fase di anticipo fa partire il tell sonoro, e succede ANCHE se
## il nemico e' lontanissimo dall'inquadratura — e' il senso del tell.
func test_nemico_fuori_schermo_produce_comunque_il_tell() -> void:
	var am: Node = Engine.get_main_loop().root.get_node_or_null("AudioManager")
	var tell: Array = []
	var cb := func(_pos: Vector2, cat: String) -> void: tell.append(cat)
	am.tell_emesso.connect(cb)

	var e: CharacterBody2D = _nemico()
	e.global_position = Vector2(50000, 50000)  # ben oltre qualsiasi camera
	e.call("_vai", Stato_ANTICIPO)

	assert_eq(tell.size(), 1, "il tell parte entrando in ANTICIPO")
	assert_false(str(tell[0]).is_empty(), "il tell porta una categoria")

	am.tell_emesso.disconnect(cb)
	e.free()


## US-020: e' anticipo_ms del tell (audio.json.telegraph), non l'animazione,
## a fissare quanto dura la fase di anticipo.
func test_anticipo_ms_dei_dati_fissa_la_durata_della_fase() -> void:
	var e: CharacterBody2D = _nemico()
	e.call("_vai", Stato_ANTICIPO)
	assert_eq(e.stato(), "ANTICIPO", "entrato in anticipo")
	# wind_up_light = 300 ms in data/audio.json.telegraph.
	e.call("_physics_process", 0.2)
	assert_eq(e.stato(), "ANTICIPO", "a 0.2s ancora in anticipo")
	e.call("_physics_process", 0.2)
	assert_eq(e.stato(), "ATTACCO", "dopo i 300 ms passa ad ATTACCO")
	e.free()
