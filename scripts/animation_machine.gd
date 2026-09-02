extends AnimatedSprite2D
## Macchina di animazione generica, guidata da data/animations.json via
## AnimationSpec. NON conosce nessuna animazione per nome: costruisce lo
## SpriteFrames a runtime dagli spritesheet placeholder e riproduce cio' che
## il JSON dichiara. Cambiare un fps o un indice di frame nel JSON (e premere
## F5) cambia la resa senza ricompilare.
##
## Emette segnali per gli eventi per frame (footstep, hitbox_on/off,
## tell_audio, tell_visivo, ability_release...) e per il cambio di fase del
## combat. iframe_window e finestra_perfetta restano interrogabili tramite
## spec_corrente(), per il dash di US-009 e la parata di US-010.
##
## NIENTE class_name: coerente col progetto, i test fanno preload.

signal evento_frame(nome: String)
signal fase_cambiata(fase: String)
signal animazione_finita(stato: String)

const AnimationSpec := preload("res://scripts/animation_spec.gd")
const DIM := 32

var _categoria: String = ""
var _stato: String = ""
var _spec: RefCounted = null
var _ultima_fase: String = ""
var _ultimo_frame_visto: int = -1


## Connette i segnali una volta sola. Chiamato da configura() e non da
## _ready() cosi' la macchina e' usabile anche fuori dall'albero (test).
func _assicura_connessioni() -> void:
	if not frame_changed.is_connected(_su_frame_cambiato):
		frame_changed.connect(_su_frame_cambiato)
	if not animation_finished.is_connected(_su_animazione_finita):
		animation_finished.connect(_su_animazione_finita)
	var gd: Node = _game_data()
	if gd != null and gd.has_signal("data_reloaded") \
			and not gd.data_reloaded.is_connected(_su_dati_ricaricati):
		gd.data_reloaded.connect(_su_dati_ricaricati)


func _su_animazione_finita() -> void:
	animazione_finita.emit(_stato)


func _su_dati_ricaricati(_files: int, _errors: int) -> void:
	if not _categoria.is_empty():
		configura(_categoria)


## Costruisce lo SpriteFrames per tutte le animazioni della categoria
## ("personaggio", "nemico_base", "pet"). Una sotto-animazione per direzione
## sulle animazioni direzionali ("<nome>_<dir>"), una sola ("<nome>") sulle
## altre.
func configura(categoria: String) -> void:
	_categoria = categoria
	_assicura_connessioni()
	var gd: Node = _game_data()
	if gd == null:
		push_warning("[AnimationMachine] GameData assente: nessuna animazione costruita")
		return

	var direzioni: Array = gd.call("animation_convention", "direzioni")
	if direzioni == null:
		direzioni = ["down", "up", "left", "right"]

	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	for nome in gd.call("animation_names", categoria):
		var spec: RefCounted = AnimationSpec.new(gd.call("get_animation", categoria, nome))
		if not spec.is_valid():
			continue
		var tex: Texture2D = load("res://assets/placeholder/%s_%s.png" % [categoria, nome])
		if tex == null:
			push_warning("[AnimationMachine] manca lo spritesheet per %s/%s" % [categoria, nome])
			continue

		var righe: Array = direzioni if spec.is_directional() else ["down"]
		for riga in righe.size():
			var chiave: String = nome
			if spec.is_directional():
				chiave = "%s_%s" % [nome, direzioni[riga]]
			sf.add_animation(chiave)
			sf.set_animation_speed(chiave, spec.fps())
			sf.set_animation_loop(chiave, spec.loops())
			for col in spec.frame_count():
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(col * DIM, riga * DIM, DIM, DIM)
				sf.add_frame(chiave, at)

	sprite_frames = sf


## Riproduce lo stato nella direzione data (gia' ridotta a 4: le diagonali
## riusano l'orizzontale). Se lo stato non esiste nei dati, non fa nulla.
func riproduci(stato: String, direzione: String = "down") -> void:
	var gd: Node = _game_data()
	if gd == null:
		return
	var anim_dict: Dictionary = gd.call("get_animation", _categoria, stato)
	if anim_dict.is_empty():
		return
	var spec: RefCounted = AnimationSpec.new(anim_dict)

	var chiave: String = stato
	if spec.is_directional():
		chiave = "%s_%s" % [stato, direzione]
	if sprite_frames == null or not sprite_frames.has_animation(chiave):
		return

	if animation == chiave and is_playing():
		return

	_stato = stato
	_spec = spec
	_ultima_fase = ""
	_ultimo_frame_visto = -1
	animation = chiave
	frame = 0
	play()
	_processa_frame(0)


## AnimationSpec dello stato in riproduzione: da qui US-009 legge la finestra
## di i-frame e US-010 quella di parata perfetta.
func spec_corrente() -> RefCounted:
	return _spec


func stato_corrente() -> String:
	return _stato


func _su_frame_cambiato() -> void:
	_processa_frame(frame)


func _processa_frame(f: int) -> void:
	if _spec == null or f == _ultimo_frame_visto:
		return
	_ultimo_frame_visto = f
	for ev in _spec.events_at(f):
		evento_frame.emit(ev)
	var fase: String = _spec.phase_of(f)
	if fase != _ultima_fase:
		_ultima_fase = fase
		fase_cambiata.emit(fase)


func _game_data() -> Node:
	var loop := Engine.get_main_loop()
	if loop == null:
		return null
	return (loop as SceneTree).root.get_node_or_null("GameData")
