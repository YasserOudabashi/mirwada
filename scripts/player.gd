extends CharacterBody2D
## Giocatore: movimento a 8 direzioni + attacco leggero in mischia.
##
## Le animazioni e il loro timing vengono da data/animations.json tramite
## AnimationMachine: questo script decide solo QUALE stato
## ("walk"/"idle"/"attack_light") e in quale delle 4 direzioni. Le diagonali
## riusano la direzione orizzontale, come da convenzioni.direzioni.
##
## L'attacco: l'input avvia l'animazione "attack_light"; la hitbox si apre e
## si chiude sugli eventi hitbox_on/hitbox_off che la macchina di animazione
## emette dai frame del JSON. Non si puo' ri-attaccare finche' l'animazione
## non e' finita (quindi nemmeno durante il recupero). Danno, arco e hitstop
## vengono da data/balance.json (sezione combattimento).
##
## NIENTE class_name: coerente col resto del progetto.

const ACCELERAZIONE := 1400.0
const ATTRITO := 1600.0
const SOGLIA_MOTO := 5.0
const CATEGORIA_ANIM := "personaggio"
const STATO_ATTACCO := "attack_light"

const FACING := {
	"down": Vector2.DOWN, "up": Vector2.UP,
	"left": Vector2.LEFT, "right": Vector2.RIGHT,
}

@onready var _stats: Node = $StatsComponent
@onready var _anim: AnimatedSprite2D = $AnimationMachine
@onready var _hitbox: Area2D = $Hitbox

var _dir_sguardo: String = "down"
var _attaccando: bool = false
var _in_hitstop: bool = false
var _combat: Dictionary = {}


func _ready() -> void:
	_anim.call("configura", CATEGORIA_ANIM)
	_anim.evento_frame.connect(_su_evento_anim)
	_anim.animazione_finita.connect(_su_anim_finita)
	_hitbox.ha_colpito.connect(_su_colpo_inflitto)

	var gd: Node = get_node_or_null("/root/GameData")
	if gd != null:
		_combat = gd.call("get_balance", "combattimento")
	var arco: Dictionary = _combat.get("attacco_leggero", {})
	_hitbox.call("configura",
		float(arco.get("angolo", 100.0)), float(arco.get("raggio", 22.0)))

	_anim.call("riproduci", "idle", _dir_sguardo)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("attacco") and not _attaccando:
		_inizia_attacco()

	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var vel_max: float = _stats.get_stat("velocita")

	if input != Vector2.ZERO:
		# get_vector normalizza gia' la diagonale: nessuna spinta extra in obliquo.
		velocity = velocity.move_toward(input * vel_max, ACCELERAZIONE * delta)
		if not _attaccando:
			_aggiorna_sguardo(input)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, ATTRITO * delta)

	move_and_slide()
	_aggiorna_animazione()


## Direzione guardata come vettore. La cerca ability_engine per orientare
## proiettili e archi (get_facing).
func get_facing() -> Vector2:
	return FACING.get(_dir_sguardo, Vector2.DOWN)


func sta_attaccando() -> bool:
	return _attaccando


func _inizia_attacco() -> void:
	_attaccando = true
	var facing: Vector2 = get_facing()
	_hitbox.position = Vector2(0, -4) + facing * 4.0
	_hitbox.rotation = facing.angle()
	_anim.call("riproduci", STATO_ATTACCO, _dir_sguardo)


func _su_evento_anim(nome: String) -> void:
	match nome:
		"hitbox_on":
			var arco: Dictionary = _combat.get("attacco_leggero", {})
			_hitbox.call("attiva",
				float(arco.get("danno", 12.0)), float(arco.get("stagger", 6.0)), self)
		"hitbox_off":
			_hitbox.call("disattiva")


func _su_anim_finita(stato: String) -> void:
	if stato == STATO_ATTACCO:
		_attaccando = false
		_hitbox.call("disattiva")


func _su_colpo_inflitto(_bersaglio: Node, _danno: float) -> void:
	_hitstop()


func _hitstop() -> void:
	if _in_hitstop:
		return
	_in_hitstop = true
	var ms: float = float(_combat.get("hitstop_ms", 70.0))
	Engine.time_scale = 0.05
	await get_tree().create_timer(ms / 1000.0, true, false, true).timeout
	Engine.time_scale = 1.0
	_in_hitstop = false


## La direzione dominante decide lo sprite. In obliquo vince l'orizzontale:
## e' la scelta di data/animations.json (nessuno sprite diagonale).
func _aggiorna_sguardo(input: Vector2) -> void:
	if absf(input.x) >= absf(input.y):
		_dir_sguardo = "right" if input.x > 0.0 else "left"
	else:
		_dir_sguardo = "down" if input.y > 0.0 else "up"


func _aggiorna_animazione() -> void:
	if _attaccando:
		return
	var stato: String = "walk" if velocity.length() > SOGLIA_MOTO else "idle"
	_anim.call("riproduci", stato, _dir_sguardo)
