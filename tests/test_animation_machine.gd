extends "res://tests/test_case.gd"
## US-021B — macchina di animazione costruita a runtime dai dati.

const AnimationMachine := preload("res://scripts/animation_machine.gd")


func _nuova() -> AnimatedSprite2D:
	var m: AnimatedSprite2D = AnimationMachine.new()
	m.call("configura", "personaggio")
	return m


func test_spriteframes_costruito_dai_dati() -> void:
	var m: AnimatedSprite2D = _nuova()
	var sf: SpriteFrames = m.sprite_frames
	assert_true(sf != null, "SpriteFrames creato")
	# direzionali -> una sotto-animazione per direzione
	assert_true(sf.has_animation("walk_down"), "walk_down presente")
	assert_true(sf.has_animation("walk_up"), "walk_up presente")
	assert_true(sf.has_animation("attack_light_right"), "attack_light_right presente")
	# non direzionale -> una sola
	assert_true(sf.has_animation("death"), "death (non direzionale) presente")
	assert_false(sf.has_animation("death_down"), "death non ha varianti di direzione")
	m.free()


func test_frame_fps_e_loop_dai_dati() -> void:
	var m: AnimatedSprite2D = _nuova()
	var sf: SpriteFrames = m.sprite_frames
	# animations.json personaggio.walk: 6 frame, 12 fps, loop true
	assert_eq(sf.get_frame_count("walk_down"), 6, "6 frame in walk")
	assert_almost_eq(sf.get_animation_speed("walk_down"), 12.0, "12 fps in walk")
	assert_true(sf.get_animation_loop("walk_down"), "walk in loop")
	# attack_light: 5 frame, non in loop
	assert_eq(sf.get_frame_count("attack_light_down"), 5, "5 frame in attack_light")
	assert_false(sf.get_animation_loop("attack_light_down"), "attack_light non in loop")
	m.free()


func test_eventi_per_frame_emessi() -> void:
	var m: AnimatedSprite2D = _nuova()
	Engine.get_main_loop().root.add_child(m)
	var eventi: Array = []
	m.evento_frame.connect(func(n: String) -> void: eventi.append(n))

	m.call("riproduci", "attack_light", "right")
	m.frame = 2  # animations.json: hitbox_on al frame 2
	m.frame = 3  # hitbox_off al frame 3

	assert_true(eventi.has("hitbox_on"), "hitbox_on emesso al frame 2")
	assert_true(eventi.has("hitbox_off"), "hitbox_off emesso al frame 3")
	m.free()


func test_cambio_di_fase_del_combat() -> void:
	var m: AnimatedSprite2D = _nuova()
	Engine.get_main_loop().root.add_child(m)
	var fasi: Array = []
	m.fase_cambiata.connect(func(f: String) -> void: fasi.append(f))

	m.call("riproduci", "attack_light", "down")  # frame 0 -> anticipo
	m.frame = 2  # -> attivi
	m.frame = 3  # -> recupero

	assert_eq(fasi, ["anticipo", "attivi", "recupero"], "fasi in ordine")
	m.free()


func test_spec_corrente_espone_le_finestre() -> void:
	var m: AnimatedSprite2D = _nuova()
	Engine.get_main_loop().root.add_child(m)
	m.call("riproduci", "dash", "left")
	var spec: RefCounted = m.call("spec_corrente")
	assert_true(spec != null, "spec del dash disponibile")
	assert_eq(spec.iframe_window(), Vector2i(0, 2), "finestra i-frame del dash da spec_corrente")
	m.free()


func test_stato_inesistente_non_esplode() -> void:
	var m: AnimatedSprite2D = _nuova()
	Engine.get_main_loop().root.add_child(m)
	m.call("riproduci", "stato_che_non_esiste", "down")
	assert_eq(m.call("stato_corrente"), "", "nessuno stato impostato")
	m.free()
