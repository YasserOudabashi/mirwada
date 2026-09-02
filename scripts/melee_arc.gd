extends Area2D
## Arco di mischia generato dalla primitiva "melee_arc".
##
## Vive un solo frame di logica: la finestra attiva vera la decidera' la
## macchina di animazione di US-021, che legge i frame da data/animations.json.

var danno: float = 0.0
var angolo: float = 90.0
var raggio: float = 32.0
var stagger: float = 0.0
var tag_danno: Array = []
var origine: String = ""

var _direzione: Vector2 = Vector2.RIGHT


func setup(spec: Dictionary, direzione: Vector2) -> void:
	danno = float(spec.get("danno", 0.0))
	angolo = float(spec.get("angolo", 90.0))
	raggio = float(spec.get("raggio", 32.0))
	stagger = float(spec.get("stagger", 0.0))
	tag_danno = spec.get("tag_danno", [])
	origine = str(spec.get("origine", ""))
	_direzione = direzione.normalized() if direzione.length() > 0.0 else Vector2.RIGHT
	rotation = _direzione.angle()

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = raggio
	shape.shape = circle
	add_child(shape)


## true se il bersaglio cade dentro l'arco. Il cerchio della collisione e'
## solo un filtro grossolano: l'angolo lo decide questo controllo.
func dentro_arco(punto_globale: Vector2) -> bool:
	var verso: Vector2 = punto_globale - global_position
	if verso.length() > raggio:
		return false
	if verso.length() == 0.0:
		return true
	return absf(rad_to_deg(_direzione.angle_to(verso))) <= angolo * 0.5
