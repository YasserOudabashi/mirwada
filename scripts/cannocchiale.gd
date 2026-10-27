extends Area2D
## US-8B24: un cannocchiale fisso (data/world/cannocchiali.json). "interagisci" vicino: la vista vola fino al bersaglio
## (un luogo del mondo) con una telecamera sua, si guarda, e con "interagisci" (o annulla) torna sul giocatore. Intanto il
## giocatore resta fermo. Disegno: l'arredo cannocchiale (tools/art/build_interni.py), piedi in basso al centro della
## casella, che non si attraversa.
##
## NIENTE class_name: coerente col progetto.

signal vista_cambiata(aperta: bool)

const TILE := 32

var cannocchiale_id: String = ""
var bersaglio := Vector2.ZERO                  # nelle coordinate del genitore (il mondo), come position
var durata_volo := 1.6

var _vicino := false
var _chi: Node2D = null
var _guardando := false
var _camera: Camera2D = null
var _tween: Tween = null
var _prompt: Label


## Prima di aggiungerlo all'albero: id, centro della casella, bersaglio, secondi del volo della vista.
func setup(id: String, posizione: Vector2, verso: Vector2, volo: float) -> void:
	cannocchiale_id = id
	position = posizione
	bersaglio = verso
	durata_volo = volo


func _ready() -> void:
	name = "Cannocchiale_%s" % cannocchiale_id
	var area := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(TILE, TILE) * 2.4                  # fino alle caselle accanto, come il forziere
	area.shape = r
	add_child(area)
	var corpo := StaticBody2D.new()
	var forma := CollisionShape2D.new()
	var rc := RectangleShape2D.new()
	rc.size = Vector2(TILE, TILE) * 0.8
	forma.shape = rc
	corpo.add_child(forma)
	add_child(corpo)
	var gs: Node = get_node_or_null("/root/GameState")
	var path: String = "res://assets/interni/%s/arredi/cannocchiale.png" % (str(gs.call("tema_arte")) if gs != null else "luminoso")
	if FileAccess.file_exists(path):
		var spr := Sprite2D.new()
		spr.texture = preload("res://scripts/world/mondo.gd")._texture(path)
		spr.centered = false
		var f := FileAccess.open("res://assets/interni/arredi.json", FileAccess.READ)
		var an: Array = ((JSON.parse_string(f.get_as_text()) as Dictionary) if f != null else {}).get("cannocchiale", [0, 0])
		spr.offset = -Vector2(float(an[0]), float(an[1]))
		spr.position = Vector2(0, TILE / 2.0)
		add_child(spr)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 10)
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt.add_theme_color_override("font_outline_color", Color("#181425"))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(TILE * 3, TILE * 0.5)
	_prompt.position = Vector2(-TILE * 1.5, -TILE * 1.6)
	_prompt.z_index = 10
	_prompt.text = tr("HUD_PROMPT_GUARDA").format({"tasto": _tasto_interagisci()})
	_prompt.hide()
	add_child(_prompt)
	body_entered.connect(_su_corpo.bind(true))
	body_exited.connect(_su_corpo.bind(false))


func sta_guardando() -> bool:
	return _guardando


## La vista vola al bersaglio. false se non c'e' nessuno accanto o si sta gia' guardando.
func guarda() -> bool:
	if _guardando or not is_instance_valid(_chi):
		return false
	_guardando = true
	_chi.set_physics_process(false)                     # fermo: legge i tasti nel suo _physics_process
	if _chi is CharacterBody2D:
		(_chi as CharacterBody2D).velocity = Vector2.ZERO
	var sua: Camera2D = _chi.get_node_or_null("Camera2D") as Camera2D
	_camera = Camera2D.new()
	get_parent().add_child(_camera)
	_camera.global_position = sua.get_screen_center_position() if sua != null and sua.is_inside_tree() else _chi.global_position
	if sua != null:
		_camera.zoom = sua.zoom
	_camera.make_current()
	_prompt.hide()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_camera, "global_position", get_parent().to_global(bersaglio), durata_volo)
	vista_cambiata.emit(true)
	return true


## La vista torna sul giocatore; a volo finito la telecamera e' di nuovo la sua e lui si muove.
func torna() -> void:
	if not _guardando or _camera == null:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_camera, "global_position", _chi.global_position if is_instance_valid(_chi) else global_position,
			durata_volo * 0.6)
	_tween.tween_callback(_tornato)


func _tornato() -> void:
	if is_instance_valid(_chi):
		var sua: Camera2D = _chi.get_node_or_null("Camera2D") as Camera2D
		if sua != null:
			sua.make_current()
			sua.reset_smoothing()
		_chi.set_physics_process(true)
	if _camera != null:
		_camera.queue_free()
		_camera = null
	_guardando = false
	_prompt.visible = _vicino
	vista_cambiata.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	if _guardando:
		if event.is_action_pressed("interagisci") or event.is_action_pressed("ui_cancel"):
			torna()
			get_viewport().set_input_as_handled()
		return
	if not _vicino or not event.is_action_pressed("interagisci"):
		return
	var book: Node = get_node_or_null("/root/Book")
	var de: Node = get_node_or_null("/root/DialogueEngine")
	if (book != null and bool(book.call("e_aperto"))) or (de != null and bool(de.call("in_corso"))):
		return
	if guarda():
		get_viewport().set_input_as_handled()


func _su_corpo(body: Node, dentro: bool) -> void:
	if not body.is_in_group("player"):
		return
	_vicino = dentro
	if dentro:
		_chi = body as Node2D
	_prompt.visible = dentro and not _guardando


func _tasto_interagisci() -> String:
	for ev in InputMap.action_get_events("interagisci"):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return "F"
