extends CharacterBody2D
## Giocatore: movimento a 8 direzioni con accelerazione e attrito.
##
## Gli sprite sono a 4 direzioni (data/animations.json, convenzioni.direzioni):
## le diagonali riusano la direzione orizzontale. Questa e' una resa
## placeholder minima — la macchina di animazione data-driven arriva con
## US-021 e sostituira' _aggiorna_sprite() leggendo frames/fps dal JSON.
##
## La velocita' massima viene da StatsComponent (quindi da data/balance.json).
## Accelerazione e attrito sono ancora costanti: il loro posto nei dati e'
## data/animations.json, ma il contratto per il "feel" lo fissa US-021.
##
## NIENTE class_name: coerente con gli altri script del progetto (vedi
## stats_component.gd), evita lo stallo del runner dei test in Godot 4.3.

const ACCELERAZIONE := 1400.0
const ATTRITO := 1600.0
const SOGLIA_MOTO := 5.0

## Riga dello spritesheet per direzione, ordine di data/animations.json.
const RIGA := {"down": 0, "up": 1, "left": 2, "right": 3}

const TEX_IDLE: Texture2D = preload("res://assets/placeholder/personaggio_idle.png")
const TEX_WALK: Texture2D = preload("res://assets/placeholder/personaggio_walk.png")
const FRAMES_IDLE := 4
const FRAMES_WALK := 6

@onready var _stats: Node = $StatsComponent
@onready var _sprite: Sprite2D = $Sprite2D

var _dir_sguardo: String = "down"
var _fase_anim: float = 0.0


func _ready() -> void:
	_sprite.region_enabled = true
	_aggiorna_sprite(0.0)


func _physics_process(delta: float) -> void:
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var vel_max: float = _stats.get_stat("velocita")

	if input != Vector2.ZERO:
		# get_vector normalizza gia' la diagonale: nessuna spinta extra in obliquo.
		velocity = velocity.move_toward(input * vel_max, ACCELERAZIONE * delta)
		_aggiorna_sguardo(input)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, ATTRITO * delta)

	move_and_slide()
	_aggiorna_sprite(delta)


## La direzione dominante decide lo sprite. In obliquo vince l'orizzontale:
## e' la scelta di data/animations.json (nessuno sprite diagonale).
func _aggiorna_sguardo(input: Vector2) -> void:
	if absf(input.x) >= absf(input.y):
		_dir_sguardo = "right" if input.x > 0.0 else "left"
	else:
		_dir_sguardo = "down" if input.y > 0.0 else "up"


func _aggiorna_sprite(delta: float) -> void:
	var in_moto: bool = velocity.length() > SOGLIA_MOTO
	var tex: Texture2D = TEX_WALK if in_moto else TEX_IDLE
	var n_frame: int = FRAMES_WALK if in_moto else FRAMES_IDLE

	if in_moto:
		_fase_anim += delta * 10.0
	else:
		_fase_anim = 0.0

	var col: int = int(_fase_anim) % n_frame
	var riga: int = RIGA[_dir_sguardo]
	_sprite.texture = tex
	_sprite.region_rect = Rect2(col * 32, riga * 32, 32, 32)
