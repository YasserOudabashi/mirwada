extends Area2D
## US-8B24: un cannocchiale fisso (data/world/cannocchiali.json). "interagisci" vicino: la vista vola fino al bersaglio
## (un luogo del mondo) con una telecamera sua, si guarda, e con "interagisci" (o annulla) torna sul giocatore. Intanto il
## giocatore resta fermo. Disegno: l'arredo cannocchiale (tools/art/build_interni.py), piedi in basso al centro della
## casella, che non si attraversa. US-8B24b: mentre si guarda, la lente (shaders/lente_cannocchiale.gdshader: fuori
## buio, anello d'ottone) con la nebbia che si dirada quando la vista e' arrivata; l'HUD (gruppo "hud") si nasconde.
##
## NIENTE class_name: coerente col progetto.

signal vista_cambiata(aperta: bool)

const TILE := 32

const LENTE_APERTA := 1.2                       # raggio che non copre niente: la lente si stringe da qui
const STRATO_LENTE := 80                        # sopra il mondo e l'HUD, sotto il libro (85)

var cannocchiale_id: String = ""
var bersaglio := Vector2.ZERO                  # nelle coordinate del genitore (il mondo), come position
var durata_volo := 1.6
## data/world/cannocchiali.json "vista": volo, lente (raggio), nebbia (secondi per diradarsi), colori.
var vista: Dictionary = {}

var _vicino := false
var _chi: Node2D = null
var _guardando := false
var _camera: Camera2D = null
var _tween: Tween = null
var _prompt: Label
var _lente: CanvasLayer = null
var _mat: ShaderMaterial = null
var _tempo := 0.0


## Prima di aggiungerlo all'albero: id, centro della casella, bersaglio, la "vista" dei dati.
func setup(id: String, posizione: Vector2, verso: Vector2, dati_vista: Dictionary) -> void:
	cannocchiale_id = id
	position = posizione
	bersaglio = verso
	vista = dati_vista
	durata_volo = float(vista.get("volo", durata_volo))


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
	_apri_lente()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_camera, "global_position", get_parent().to_global(bersaglio), durata_volo)
	_tween.parallel().tween_method(_raggio, LENTE_APERTA, float(vista.get("lente", 0.42)), 0.35)
	_tween.tween_method(_nebbia, 1.0, 0.0, float(vista.get("nebbia", 2.0)))      # arrivati: la nebbia si dirada
	vista_cambiata.emit(true)
	return true


## La vista torna sul giocatore; a volo finito la telecamera e' di nuovo la sua e lui si muove.
func torna() -> void:
	if not _guardando or _camera == null:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_nebbia, _nebbia_ora(), 1.0, 0.25)                         # la nebbia torna, poi si vola
	_tween.tween_property(_camera, "global_position", _chi.global_position if is_instance_valid(_chi) else global_position,
			durata_volo * 0.6)
	_tween.tween_method(_raggio, float(vista.get("lente", 0.42)), LENTE_APERTA, 0.25)
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
	if _lente != null:
		_lente.queue_free()
		_lente = null
		_mat = null
	_mostra_hud(true)
	_guardando = false
	_prompt.visible = _vicino
	vista_cambiata.emit(false)


func _process(delta: float) -> void:
	if _mat != null:
		_tempo += delta
		_mat.set_shader_parameter("tempo", _tempo)


## La lente sopra il mondo e l'HUD, colori dai dati; l'HUD si nasconde (dentro il cerchio si vedrebbe).
func _apri_lente() -> void:
	_lente = CanvasLayer.new()
	_lente.name = "Lente"
	_lente.layer = STRATO_LENTE
	var vetro := ColorRect.new()
	vetro.set_anchors_preset(Control.PRESET_FULL_RECT)
	vetro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/lente_cannocchiale.gdshader")
	var colori: Dictionary = vista.get("colori", {})
	for k in colori:
		_mat.set_shader_parameter("colore_" + str(k), Color(str(colori[k])))
	_mat.set_shader_parameter("raggio", LENTE_APERTA)
	_mat.set_shader_parameter("nebbia", 1.0)
	vetro.material = _mat
	_lente.add_child(vetro)
	add_child(_lente)
	_mostra_hud(false)


func _raggio(r: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("raggio", r)


func _nebbia(n: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("nebbia", n)


func _nebbia_ora() -> float:
	return float(_mat.get_shader_parameter("nebbia")) if _mat != null else 1.0


func _mostra_hud(si: bool) -> void:
	if is_inside_tree():
		for h in get_tree().get_nodes_in_group("hud"):
			(h as CanvasLayer).visible = si


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
