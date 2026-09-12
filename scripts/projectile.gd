extends Area2D
## Proiettile generato dalla primitiva "projectile".
##
## Non sa quale abilita' l'abbia creato: riceve i parametri gia' risolti dal
## motore. Si autodistrugge a fine gittata, cosi' nessuno deve ripulirlo.
##
## US-803: colpisce davvero. collision_mask 4 = le Hurtbox (layer 3, come
## hitbox.gd e field.gd); su area_entered chiama subisci() con la stessa
## firma di hitbox.gd:61, esclusa la hurtbox del caster.

var danno: float = 0.0
var velocita: float = 200.0
var gittata: float = 100.0
var pierce: int = 0
## Un tipo di danno per colpo, dal vocabolario chiuso data/schema/damage_tags.json.
var tag_danno: String = ""
var origine: String = ""

var _direzione: Vector2 = Vector2.RIGHT
var _percorso: float = 0.0
var _colpiti: Array = []
var _caster: Node = null


func setup(spec: Dictionary, posizione: Vector2, direzione: Vector2, caster: Node = null) -> void:
	danno = float(spec.get("danno", 0.0))
	velocita = float(spec.get("velocita", 200.0))
	gittata = float(spec.get("gittata", 100.0))
	pierce = int(spec.get("pierce", 0))
	tag_danno = str(spec.get("tag_danno", ""))
	origine = str(spec.get("origine", ""))
	global_position = posizione
	_direzione = direzione.normalized() if direzione.length() > 0.0 else Vector2.RIGHT
	_caster = caster

	collision_layer = 0
	collision_mask = 4  # le Hurtbox stanno sul layer 3 (bit 4), come hitbox.gd
	monitoring = true

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	add_child(shape)


func _ready() -> void:
	area_entered.connect(_su_area_entrata)


func _su_area_entrata(area: Area2D) -> void:
	if not area.has_method("subisci"):
		return
	if _caster != null and area.get_parent() == _caster:
		return  # non colpisce la hurtbox di chi l'ha lanciato
	if not registra_colpo(area):
		return
	area.call("subisci", danno, 0.0, _caster, {"tag_danno": tag_danno})


func _physics_process(delta: float) -> void:
	var passo: float = velocita * delta
	global_position += _direzione * passo
	_percorso += passo
	if _percorso >= gittata:
		queue_free()


## Quante entita' puo' ancora attraversare. pierce 0 = si ferma alla prima.
func colpi_residui() -> int:
	return pierce + 1 - _colpiti.size()


func registra_colpo(bersaglio: Node) -> bool:
	if _colpiti.has(bersaglio):
		return false
	_colpiti.append(bersaglio)
	if colpi_residui() <= 0:
		queue_free()
	return true
