extends CharacterBody2D
## Nemico base con telegrafia. Macchina a stati esplicita; ogni attacco ha
## una fase di ANTICIPO leggibile (il tell) la cui durata vive in
## data/animations.json (nemico_base.anticipo), non qui.
##
## Monta StatsComponent (hp) e PosturaComponent (guardia, US-010). Alla morte
## NON si distrugge: emette "morto" e lascia decidere a chi l'ha generato.
##
## NIENTE class_name: coerente col progetto.

signal morto(chi: Node)
signal stato_cambiato(nuovo: String)

enum Stato { IDLE, INSEGUIMENTO, ANTICIPO, ATTACCO, RECUPERO, STAGGER, MORTO }

const CATEGORIA_ANIM := "nemico_base"

@onready var _anim: AnimatedSprite2D = $AnimationMachine
@onready var _stats: Node = $StatsComponent
@onready var _postura: Node = $PosturaComponent
@onready var _hitbox: Area2D = $Hitbox
@onready var _hurtbox: Area2D = $Hurtbox

var _stato: int = Stato.IDLE
var _bersaglio: Node2D = null
var _cfg: Dictionary = {}
var _dir_sguardo: String = "down"
var _recupero_left: float = 0.0


func _ready() -> void:
	add_to_group("nemici")
	var gd: Node = get_node_or_null("/root/GameData")
	if gd != null:
		_cfg = gd.call("get_balance", "nemico_base")

	_postura.call("configura",
		float(_cfg.get("postura_massimo", 60.0)), 3.0, 15.0)
	_hitbox.call("configura",
		float(_cfg.get("angolo_arco", 90.0)), float(_cfg.get("raggio_arco", 24.0)))
	_hitbox.collision_mask = 4  # colpisce le hurtbox (layer 3)

	_anim.call("configura", CATEGORIA_ANIM)
	_anim.evento_frame.connect(_su_evento_anim)
	_anim.animazione_finita.connect(_su_anim_finita)
	_hitbox.ha_colpito.connect(_su_colpo_inflitto)
	_stats.died.connect(_su_morte)
	_postura.postura_rotta.connect(_su_postura_rotta)
	_postura.vulnerabilita_finita.connect(func() -> void:
		if _stato == Stato.STAGGER:
			_vai(Stato.IDLE))

	_bersaglio = get_tree().get_first_node_in_group("player")
	_vai(Stato.IDLE)


func _physics_process(delta: float) -> void:
	if _stato == Stato.MORTO:
		return

	var dist: float = INF
	if is_instance_valid(_bersaglio):
		dist = global_position.distance_to(_bersaglio.global_position)
		_guarda_verso(_bersaglio.global_position)

	match _stato:
		Stato.IDLE:
			velocity = Vector2.ZERO
			if dist <= float(_cfg.get("raggio_aggro", 140.0)):
				_vai(Stato.INSEGUIMENTO)
		Stato.INSEGUIMENTO:
			if dist <= float(_cfg.get("raggio_attacco", 26.0)):
				_vai(Stato.ANTICIPO)
			elif dist > float(_cfg.get("raggio_aggro", 140.0)) * 1.3:
				_vai(Stato.IDLE)
			elif is_instance_valid(_bersaglio):
				var v: float = _stats.get_stat("velocita")
				velocity = global_position.direction_to(_bersaglio.global_position) * v
		Stato.ANTICIPO, Stato.ATTACCO, Stato.STAGGER:
			velocity = Vector2.ZERO
		Stato.RECUPERO:
			velocity = Vector2.ZERO
			_recupero_left -= delta
			if _recupero_left <= 0.0:
				_vai(Stato.IDLE)

	move_and_slide()
	_aggiorna_anim_locomozione()


func _vai(nuovo: int) -> void:
	if _stato == nuovo:
		return
	_stato = nuovo
	stato_cambiato.emit(Stato.keys()[nuovo])
	match nuovo:
		Stato.ANTICIPO:
			_anim.modulate = Color(1.0, 0.5, 0.4)  # tell visivo
			_anim.call("riproduci", "anticipo", _dir_sguardo)
		Stato.ATTACCO:
			_anim.modulate = Color.WHITE
			var facing: Vector2 = _vettore_sguardo()
			_hitbox.position = facing * 6.0
			_hitbox.rotation = facing.angle()
			_anim.call("riproduci", "attack", _dir_sguardo)
		Stato.RECUPERO:
			_hitbox.call("disattiva")
			_recupero_left = float(_cfg.get("recupero_s", 0.6))
		Stato.STAGGER:
			_anim.modulate = Color(0.7, 0.7, 1.0)
			_hitbox.call("disattiva")
			_anim.call("riproduci", "stagger", _dir_sguardo)
		Stato.IDLE:
			_anim.modulate = Color.WHITE


func _su_evento_anim(nome: String) -> void:
	match nome:
		"hitbox_on":
			_hitbox.call("attiva",
				float(_cfg.get("danno_attacco", 10.0)),
				float(_cfg.get("stagger_attacco", 8.0)), self)
		"hitbox_off":
			_hitbox.call("disattiva")


func _su_anim_finita(stato_anim: String) -> void:
	if _stato == Stato.MORTO:
		return
	match stato_anim:
		"anticipo":
			_vai(Stato.ATTACCO)
		"attack":
			_vai(Stato.RECUPERO)


func _su_colpo_inflitto(_bersaglio: Node, _danno: float) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("feedback", "hit_light")


func _su_postura_rotta() -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("feedback", "posture_break")
	if _stato != Stato.MORTO:
		_vai(Stato.STAGGER)


func _su_morte() -> void:
	_stato = Stato.MORTO
	stato_cambiato.emit("MORTO")
	velocity = Vector2.ZERO
	_hitbox.call("disattiva")
	set_deferred("collision_layer", 0)
	_hurtbox.set_deferred("monitorable", false)
	_anim.modulate = Color.WHITE
	_anim.call("riproduci", "death", _dir_sguardo)
	morto.emit(self)


func stato() -> String:
	return Stato.keys()[_stato]


func _guarda_verso(punto: Vector2) -> void:
	var d: Vector2 = global_position.direction_to(punto)
	if absf(d.x) >= absf(d.y):
		_dir_sguardo = "right" if d.x > 0.0 else "left"
	else:
		_dir_sguardo = "down" if d.y > 0.0 else "up"


func _vettore_sguardo() -> Vector2:
	match _dir_sguardo:
		"up": return Vector2.UP
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
		_: return Vector2.DOWN


func _aggiorna_anim_locomozione() -> void:
	if _stato == Stato.IDLE:
		_anim.call("riproduci", "idle", _dir_sguardo)
	elif _stato == Stato.INSEGUIMENTO:
		_anim.call("riproduci", "walk", _dir_sguardo)
