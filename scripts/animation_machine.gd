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
## Emesso quando il frame corrente entra/esce dalla finestra iframe_da..a
## (US-009) o da finestra_perfetta (US-010).
signal finestra_cambiata(nome: String, attiva: bool)

const AnimationSpec := preload("res://scripts/animation_spec.gd")
## Un tile e' 32 unita' di gioco: lo sprite si scala per occupare sempre un
## tile, qualunque sia la dimensione_frame dei dati (64 px -> scala 0.5).
const UNITA_TILE := 32.0

var _categoria: String = ""
## Specie o variante del disegno (es. l'id del pet): stessi tempi della
## categoria, fogli propri. Vuoto = i fogli della categoria.
var _aspetto: String = ""
var _stato: String = ""
var _spec: RefCounted = null
var _ultima_fase: String = ""
var _ultimo_frame_visto: int = -1
var _invuln_attiva: bool = false
var _parata_attiva: bool = false
## Ombra a terra (vfx.json.ombra_terra): figlia disegnata dietro lo sprite,
## non risente di self_modulate (il lampo) ma segue modulate (dissolvenze).
var _ombra: Node2D = null
var _ombra_raggi: Vector2 = Vector2.ZERO
var _ombra_colore: Color = Color(0, 0, 0, 0)
var _lampo: Tween = null


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
		configura(_categoria, _aspetto)


## Costruisce lo SpriteFrames per tutte le animazioni della categoria
## ("personaggio", "nemico_base", "pet"). Una sotto-animazione per direzione
## sulle animazioni direzionali ("<nome>_<dir>"), una sola ("<nome>") sulle
## altre. aspetto (facoltativo) sceglie i fogli "<categoria>_<aspetto>_<nome>";
## se mancano si ripiega su "<categoria>_<nome>".
func configura(categoria: String, aspetto: String = "") -> void:
	_categoria = categoria
	_aspetto = aspetto
	_assicura_connessioni()
	var gd: Node = _game_data()
	if gd == null:
		push_warning("[AnimationMachine] GameData assente: nessuna animazione costruita")
		return

	var direzioni: Array = gd.call("animation_convention", "direzioni")
	if direzioni == null:
		direzioni = ["down", "up", "left", "right"]

	var dim_dati = gd.call("animation_convention", "dimensione_frame")
	var dim: int = int(dim_dati[0]) if dim_dati is Array and not dim_dati.is_empty() else 32
	scale = Vector2.ONE * (UNITA_TILE / float(dim))
	# piedi sull'origine del nodo: offset in pixel della cella, prima della scala
	var piedi = gd.call("animation_convention", "piedi_px")
	offset = Vector2(0, dim / 2.0 - float(piedi)) if piedi != null else Vector2.ZERO
	_configura_ombra(gd.call("get_vfx", "ombra_terra"))

	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	for nome in gd.call("animation_names", categoria):
		var spec: RefCounted = AnimationSpec.new(gd.call("get_animation", categoria, nome))
		if not spec.is_valid():
			continue
		var tex: Texture2D = _foglio(categoria, aspetto, nome)
		if tex == null:
			push_warning("[AnimationMachine] manca lo spritesheet per %s/%s" % [categoria, nome])
			continue

		var righe: Array = direzioni if spec.is_directional() else ["down"]
		var durate: Array = spec.frame_durations_ms()
		for riga in righe.size():
			var chiave: String = nome
			if spec.is_directional():
				chiave = "%s_%s" % [nome, direzioni[riga]]
			sf.add_animation(chiave)
			# 1000 "fps": la durata di ogni frame e' direttamente in ms.
			sf.set_animation_speed(chiave, 1000.0)
			sf.set_animation_loop(chiave, spec.loops())
			for col in spec.frame_count():
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(col * dim, riga * dim, dim, dim)
				sf.add_frame(chiave, at, durate[col])

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
	_invuln_attiva = false
	_parata_attiva = false
	animation = chiave
	frame = 0
	play()
	_processa_frame(0)


## Lampo del colpo subito (vfx.json.lampo_colpito): schiarisce lo sprite e
## torna normale. Con riduci_flash l'intensita' e' attenuata. Usa
## self_modulate, cosi' non tocca le tinte di stato messe su modulate.
func lampo() -> void:
	var gd: Node = _game_data()
	var dati: Dictionary = gd.call("get_vfx", "lampo_colpito") if gd != null else {}
	var am: Node = _nodo("AudioManager")
	var ridotto: bool = am != null and bool(am.call("accessibilita", "riduci_flash"))
	var i: float = float(dati.get("intensita_ridotta" if ridotto else "intensita", 1.0))
	self_modulate = Color(i, i, i)
	if _lampo != null:
		_lampo.kill()
	if not is_inside_tree():
		return
	_lampo = create_tween()
	_lampo.tween_property(self, "self_modulate", Color.WHITE,
		float(dati.get("durata_ms", 120)) / 1000.0)


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

	var invuln: bool = _spec.is_invulnerable_at(f)
	if invuln != _invuln_attiva:
		_invuln_attiva = invuln
		finestra_cambiata.emit("iframe", invuln)
	var parata: bool = _spec.is_perfect_parry_at(f)
	if parata != _parata_attiva:
		_parata_attiva = parata
		finestra_cambiata.emit("parata_perfetta", parata)


func _foglio(categoria: String, aspetto: String, nome: String) -> Texture2D:
	var proprio: String = "res://assets/placeholder/%s_%s_%s.png" % [categoria, aspetto, nome]
	if not aspetto.is_empty() and ResourceLoader.exists(proprio):
		return load(proprio)
	return load("res://assets/placeholder/%s_%s.png" % [categoria, nome])


func _configura_ombra(dati: Dictionary) -> void:
	var r = _dict(dati.get("raggi")).get(_categoria)
	if not r is Array or r.size() < 2:
		return
	_ombra_raggi = Vector2(float(r[0]), float(r[1]))
	_ombra_colore = Color(str(dati.get("colore", "#181425")))
	_ombra_colore.a = float(dati.get("alpha", 0.3))
	if _ombra == null:
		_ombra = Node2D.new()
		_ombra.name = "OmbraTerra"
		_ombra.show_behind_parent = true
		_ombra.draw.connect(_disegna_ombra)
		add_child(_ombra)
	# l'ombra si misura in unita' di gioco: annulla la scala dello sprite
	_ombra.scale = Vector2.ONE / scale
	_ombra.queue_redraw()


## Ellisse a righe di un pixel di schermo (mezza unita'): bordo a scalini
## netti, senza le punte del poligono di draw_circle schiacciato.
func _disegna_ombra() -> void:
	var px: float = 0.5
	var righe: int = int(round(_ombra_raggi.y / px))
	for j in range(-righe, righe):
		var yc: float = (j + 0.5) * px / _ombra_raggi.y
		var w: float = snappedf(_ombra_raggi.x * sqrt(maxf(1.0 - yc * yc, 0.0)), px)
		if w > 0.0:
			_ombra.draw_rect(Rect2(-w, j * px, 2.0 * w, px), _ombra_colore)


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _game_data() -> Node:
	return _nodo("GameData")


func _nodo(nome: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop == null:
		return null
	return (loop as SceneTree).root.get_node_or_null(nome)
