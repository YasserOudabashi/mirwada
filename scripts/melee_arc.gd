extends Area2D
## Arco di mischia generato dalla primitiva "melee_arc".
##
## La finestra attiva vera la decidera' la macchina di animazione di US-021,
## che legge i frame da data/animations.json. Fino ad allora il nodo vive
## VITA_S secondi e poi si libera da solo: senza questa scadenza ogni attacco
## lasciava un Area2D permanente sul caster.
##
## US-803: colpisce davvero. collision_mask 4 = le Hurtbox (layer 3, come
## hitbox.gd e field.gd); su area_entered, se il bersaglio cade dentro
## l'arco (dentro_arco: il cerchio della collisione e' solo un filtro
## grossolano) chiama subisci() con la stessa firma di hitbox.gd:61, un
## bersaglio una sola volta, esclusa la hurtbox del caster.

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
var _caster: Node = null
var _colpiti: Array = []


func setup(spec: Dictionary, direzione: Vector2, caster: Node = null) -> void:
	danno = float(spec.get("danno", 0.0))
	angolo = float(spec.get("angolo", 90.0))
	raggio = float(spec.get("raggio", 32.0))
	stagger = float(spec.get("stagger", 0.0))
	tag_danno = str(spec.get("tag_danno", ""))
	origine = str(spec.get("origine", ""))
	_direzione = direzione.normalized() if direzione.length() > 0.0 else Vector2.RIGHT
	rotation = _direzione.angle()
	_caster = caster

	collision_layer = 0
	collision_mask = 4  # le Hurtbox stanno sul layer 3 (bit 4), come hitbox.gd
	monitoring = true

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = raggio
	shape.shape = circle
	add_child(shape)


func _ready() -> void:
	area_entered.connect(_su_area_entrata)


func _su_area_entrata(area: Area2D) -> void:
	if not area.has_method("subisci") or _colpiti.has(area):
		return
	if _caster != null and area.get_parent() == _caster:
		return  # non colpisce la hurtbox di chi l'ha lanciato
	if not dentro_arco(area.global_position):
		return
	_colpiti.append(area)
	area.call("subisci", danno, stagger, _caster, {"tag_danno": tag_danno})


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
