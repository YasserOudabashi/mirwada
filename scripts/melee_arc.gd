extends Area2D
## Arco di mischia generato dalla primitiva "melee_arc".
##
## La finestra attiva vera la decidera' la macchina di animazione di US-021,
## che legge i frame da data/animations.json. Fino ad allora il nodo vive
## VITA_S secondi e poi si libera da solo: senza questa scadenza ogni attacco
## lasciava un Area2D permanente sul caster.

const VITA_S := 0.25

var danno: float = 0.0
var vita: float = VITA_S
var angolo: float = 90.0
var raggio: float = 32.0
var stagger: float = 0.0
## Un tipo di danno per colpo, dal vocabolario chiuso data/schema/damage_tags.json.
var tag_danno: String = ""
var origine: String = ""

var _direzione: Vector2 = Vector2.RIGHT


func setup(spec: Dictionary, direzione: Vector2) -> void:
	danno = float(spec.get("danno", 0.0))
	angolo = float(spec.get("angolo", 90.0))
	raggio = float(spec.get("raggio", 32.0))
	stagger = float(spec.get("stagger", 0.0))
	tag_danno = str(spec.get("tag_danno", ""))
	origine = str(spec.get("origine", ""))
	_direzione = direzione.normalized() if direzione.length() > 0.0 else Vector2.RIGHT
	rotation = _direzione.angle()

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = raggio
	shape.shape = circle
	add_child(shape)


func _process(delta: float) -> void:
	vita -= delta
	if vita <= 0.0 and not is_queued_for_deletion():
		queue_free()


## true se il bersaglio cade dentro l'arco. Il cerchio della collisione e'
## solo un filtro grossolano: l'angolo lo decide questo controllo.
func dentro_arco(punto_globale: Vector2) -> bool:
	var verso: Vector2 = punto_globale - global_position
	if verso.length() > raggio:
		return false
	if verso.length() == 0.0:
		return true
	return absf(rad_to_deg(_direzione.angle_to(verso))) <= angolo * 0.5
