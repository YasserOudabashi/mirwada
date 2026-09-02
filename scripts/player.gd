extends CharacterBody2D
## Giocatore: movimento a 8 direzioni con accelerazione e attrito.
##
## Le animazioni e il loro timing vengono da data/animations.json tramite
## AnimationMachine (US-021B): questo script decide solo QUALE stato
## ("walk"/"idle") e in quale delle 4 direzioni. Le diagonali riusano la
## direzione orizzontale, come da convenzioni.direzioni.
##
## La velocita' massima viene da StatsComponent (quindi da data/balance.json).
## Accelerazione e attrito sono ancora costanti: il "feel" si tara con la
## fase di combattimento.
##
## NIENTE class_name: coerente col resto del progetto.

const ACCELERAZIONE := 1400.0
const ATTRITO := 1600.0
const SOGLIA_MOTO := 5.0
const CATEGORIA_ANIM := "personaggio"

@onready var _stats: Node = $StatsComponent
@onready var _anim: AnimatedSprite2D = $AnimationMachine

var _dir_sguardo: String = "down"


func _ready() -> void:
	_anim.call("configura", CATEGORIA_ANIM)
	_anim.call("riproduci", "idle", _dir_sguardo)


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
	_aggiorna_animazione()


## La direzione dominante decide lo sprite. In obliquo vince l'orizzontale:
## e' la scelta di data/animations.json (nessuno sprite diagonale).
func _aggiorna_sguardo(input: Vector2) -> void:
	if absf(input.x) >= absf(input.y):
		_dir_sguardo = "right" if input.x > 0.0 else "left"
	else:
		_dir_sguardo = "down" if input.y > 0.0 else "up"


func _aggiorna_animazione() -> void:
	var stato: String = "walk" if velocity.length() > SOGLIA_MOTO else "idle"
	_anim.call("riproduci", stato, _dir_sguardo)
