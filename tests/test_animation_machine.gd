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


## US-8B01: frame da 64 px ritagliati a 64 e sprite a mezza grandezza, cosi'
## occupa sempre un tile (32 unita') e a schermo mostra tutti i suoi pixel.
func test_frame_a_64_px_occupano_un_tile() -> void:
	var m: AnimatedSprite2D = _nuova()
	var tex: Texture2D = m.sprite_frames.get_frame_texture("walk_down", 1)
	assert_eq(tex.get_size(), Vector2(64, 64), "frame ritagliato a 64x64")
	assert_eq((tex as AtlasTexture).region.position, Vector2(64, 0), "frame 1 = seconda colonna da 64")
	assert_almost_eq(m.scale.x, 0.5, "scala 0.5: 64 px -> 32 unita'")
	assert_eq(tex.get_size() * m.scale, Vector2(32, 32), "a schermo occupa un tile")
	m.free()


## Revisione arte 2.1: i piedi (riga piedi_px della cella) cadono sull'origine
## del nodo, dove stanno la collisione e l'ordinamento per profondita'.
func test_piedi_sull_origine() -> void:
	var m: AnimatedSprite2D = _nuova()
	var piedi: float = float(_gd().call("animation_convention", "piedi_px"))
	# AnimatedSprite2D centrato: riga y della cella -> y - 32 + offset.y
	assert_almost_eq((piedi - 32.0 + m.offset.y) * m.scale.y, 0.0, "piedi a y = 0")
	m.free()


## Revisione arte 2.2: ombra a terra disegnata dal gioco, dietro lo sprite,
## misurata in unita' di gioco (annulla la scala 0.5).
func test_ombra_a_terra_dai_dati() -> void:
	var m: AnimatedSprite2D = _nuova()
	var ombra: Node2D = m.get_node_or_null("OmbraTerra")
	assert_true(ombra != null, "ombra creata")
	assert_true(ombra.show_behind_parent, "ombra dietro lo sprite")
	assert_almost_eq(ombra.scale.x * m.scale.x, 1.0, "ombra in unita' di gioco")
	m.free()


## Revisione arte 1.7: il lampo del colpo lo fa il gioco e rispetta riduci_flash.
func test_lampo_rispetta_riduci_flash() -> void:
	var am: Node = _gd().get_node("/root/AudioManager")
	var prima: Variant = am.call("accessibilita", "riduci_flash")
	var m: AnimatedSprite2D = _nuova()
	am.call("imposta_accessibilita", "riduci_flash", false)
	m.call("lampo")
	var pieno: float = m.self_modulate.r
	am.call("imposta_accessibilita", "riduci_flash", true)
	m.call("lampo")
	var ridotto: float = m.self_modulate.r
	am.call("imposta_accessibilita", "riduci_flash", bool(prima) if prima != null else false)
	assert_true(pieno > ridotto, "riduci_flash attenua il lampo")
	assert_true(ridotto > 1.0, "anche ridotto il colpo si vede")
	assert_almost_eq(m.modulate.r, 1.0, "le tinte di stato (modulate) restano libere")
	m.free()

func test_frame_fps_e_loop_dai_dati() -> void:
	var m: AnimatedSprite2D = _nuova()
	var sf: SpriteFrames = m.sprite_frames
	# animations.json personaggio.walk: 6 frame, durate_ms, loop true.
	# Velocita' 1000 = la durata di ogni frame e' in ms.
	assert_eq(sf.get_frame_count("walk_down"), 6, "6 frame in walk")
	assert_almost_eq(sf.get_animation_speed("walk_down"), 1000.0, "durate in ms")
	assert_almost_eq(sf.get_frame_duration("walk_down", 0), 120.0, "frame 0: 120 ms")
	assert_almost_eq(sf.get_frame_duration("walk_down", 1), 150.0, "frame 1 (contatto): 150 ms")
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


func test_finestra_iframe_del_dash_segnalata() -> void:
	var m: AnimatedSprite2D = _nuova()
	Engine.get_main_loop().root.add_child(m)
	var eventi: Array = []
	m.finestra_cambiata.connect(func(nome: String, attiva: bool) -> void:
		eventi.append([nome, attiva]))

	m.call("riproduci", "dash", "left")  # animations.json: iframe 0..2
	# frame 0 e' gia' dentro la finestra -> primo evento (iframe, true)
	m.frame = 3  # fuori -> (iframe, false)

	assert_true(eventi.has(["iframe", true]), "iframe apre entrando nel dash")
	assert_true(eventi.has(["iframe", false]), "iframe chiude uscendo dalla finestra")
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


## US-8B32: le specie di pet hanno tempi comuni e fogli propri; una specie
## senza fogli ripiega sul segnaposto della categoria.
func test_aspetto_sceglie_i_fogli_della_specie() -> void:
	var m: AnimatedSprite2D = AnimationMachine.new()
	m.call("configura", "pet", "lupo_cinereo")
	var tex: AtlasTexture = m.sprite_frames.get_frame_texture("idle_down", 0)
	assert_eq(tex.atlas.resource_path, "res://assets/placeholder/pet_lupo_cinereo_idle.png", "foglio della specie")
	assert_true(m.sprite_frames.has_animation("death"), "death del pet dai dati")
	m.call("configura", "pet", "specie_senza_fogli")
	tex = m.sprite_frames.get_frame_texture("idle_down", 0)
	assert_eq(tex.atlas.resource_path, "res://assets/placeholder/pet_idle.png", "ripiego sul segnaposto")
	m.free()


func _gd() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameData")
