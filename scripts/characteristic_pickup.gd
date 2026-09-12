extends Area2D
## Caratteristica Beyonder a terra: la lascia un Beyonder alla morte (US-207).
## Il giocatore ci passa sopra e la raccoglie -> entra in CharacteristicStore.
##
## Costruita a runtime come projectile/melee_arc: nessuna scena dedicata.
##
## NIENTE class_name: coerente col resto del progetto.

const RAGGIO := 10.0

var char_id: String = ""
var _raccolta: bool = false


func setup(id: String, posizione: Vector2) -> void:
	char_id = id
	global_position = posizione
	# Non blocca il movimento (monitora e basta), reagisce al giocatore.
	monitoring = true
	var shape := CollisionShape2D.new()
	var cerchio := CircleShape2D.new()
	cerchio.radius = RAGGIO
	shape.shape = cerchio
	add_child(shape)
	add_child(_crea_marker())


## Segnaposto visivo di default: un piccolo rombo chiaro. item_pickup.gd lo
## sovrascrive con l'icona della categoria dell'item (US-813).
func _crea_marker() -> Node2D:
	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([Vector2(0, -6), Vector2(5, 0), Vector2(0, 6), Vector2(-5, 0)])
	marker.color = Color(0.9, 0.85, 0.5)
	return marker


func _ready() -> void:
	body_entered.connect(_su_corpo)
	area_entered.connect(_su_area)


func _su_corpo(body: Node) -> void:
	if body != null and body.is_in_group("player"):
		raccogli()


func _su_area(area: Node) -> void:
	# La Hurtbox del giocatore e' figlia del nodo player.
	var p: Node = area.get_parent() if area != null else null
	if p != null and p.is_in_group("player"):
		raccogli()


## Raccoglie la Caratteristica: la mette nel magazzino e si distrugge. Pubblica
## per i test (la collisione fisica non e' affidabile in headless).
func raccogli() -> bool:
	if _raccolta or char_id.is_empty():
		return false
	_raccolta = true
	var store: Node = Engine.get_main_loop().root.get_node_or_null("CharacteristicStore")
	if store != null:
		store.call("aggiungi", char_id)
	queue_free()
	return true
