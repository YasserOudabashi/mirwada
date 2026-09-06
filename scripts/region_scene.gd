extends TileMapLayer
## Scena placeholder di una regione (US-602/603). UNA sola implementazione per
## tutte e 5 le regioni: il contenuto (id, location_tags) viene dai dati
## (data/world/regions.json via GameData). Una scena .tscn per regione imposta
## solo region_id nell'inspector.
##
## Come la zona di test di US-006, e' un tilemap diagnostico: bordo di muri e
## un pavimento, con una Area2D per ogni location_tag della regione (marcata
## col tag, cosi' entrando ci si legge dove si e'). L'arte vera e i biomi
## disegnati a mano sono un non-goal di questa fase.
##
## NIENTE class_name: coerente col resto del progetto.

signal zona_cambiata(location_tag: String)

const TILE := 32
const W := 48
const H := 36

const SORGENTE := 0
const PAVIMENTO := Vector2i(0, 0)
const MURO := Vector2i(1, 0)

## Cella di comparsa del giocatore.
const SPAWN := Vector2i(4, 4)

## Regione da caricare. Le .tscn in scenes/regioni/ lo impostano.
@export var region_id: String = ""

var _tag_corrente: String = ""


func _ready() -> void:
	tile_set = load("res://assets/placeholder/tileset.tres")
	_dipingi()
	_crea_zone()
	_colloca_giocatore()
	_registra_regione()


func _dipingi() -> void:
	for x in W:
		for y in H:
			var bordo: bool = x == 0 or y == 0 or x == W - 1 or y == H - 1
			set_cell(Vector2i(x, y), SORGENTE, MURO if bordo else PAVIMENTO)


## Una Area2D per location_tag, disposte a griglia nell'interno. Ogni zona
## porta il proprio tag come meta: entrando, il giocatore "legge" dove si
## trova (US-602). La grafica e' assente: e' un rettangolo invisibile.
func _crea_zone() -> void:
	var tags: Array = []
	var gd: Node = get_node_or_null("/root/GameData")
	if gd != null:
		var reg: Dictionary = gd.call("get_region", region_id)
		tags = (reg.get("location_tags", []) as Array)
	if tags.is_empty():
		return

	# griglia di celle-zona nell'area interna (dentro il bordo di muri)
	var cols: int = int(ceil(sqrt(float(tags.size()))))
	var righe: int = int(ceil(float(tags.size()) / float(cols)))
	var cell_w: float = float(W - 2) * TILE / float(cols)
	var cell_h: float = float(H - 2) * TILE / float(righe)

	for i in tags.size():
		var col: int = i % cols
		var row: int = i / cols
		var centro := Vector2(
			TILE + cell_w * (col + 0.5),
			TILE + cell_h * (row + 0.5))
		var area := Area2D.new()
		area.name = "Zona_%s" % str(tags[i])
		area.set_meta("location_tag", str(tags[i]))
		area.position = centro
		# monitora il corpo del giocatore (layer 1): mask di default 1 basta.
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(cell_w, cell_h)
		shape.shape = rect
		area.add_child(shape)
		area.body_entered.connect(_su_ingresso_zona.bind(str(tags[i])))
		add_child(area)


func _su_ingresso_zona(body: Node, location_tag: String) -> void:
	if not body.is_in_group("player"):
		return
	if location_tag == _tag_corrente:
		return
	_tag_corrente = location_tag
	zona_cambiata.emit(location_tag)


## Il location_tag della zona in cui si trova il giocatore ("" fuori da ogni
## zona nominata). Lo leggeranno il gating (US-611) e le condizioni
## in_zona_tag delle abilita' (US-605).
func tag_corrente() -> String:
	return _tag_corrente


func _colloca_giocatore() -> void:
	var player := get_parent().get_node_or_null("Player") as Node2D
	if player == null:
		return
	player.global_position = to_global(map_to_local(SPAWN))
	var cam := player.get_node_or_null("Camera2D")
	if cam != null and cam.has_method("apply_zone_limits"):
		cam.call("apply_zone_limits", Rect2(global_position, Vector2(W * TILE, H * TILE)))


func _registra_regione() -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null and not region_id.is_empty():
		ws.call("entra_regione", region_id)
