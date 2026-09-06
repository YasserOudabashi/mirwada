extends TileMapLayer
## Scena placeholder di una regione (US-602/603). UNA sola implementazione per
## tutte e 5 le regioni: il contenuto (id, location_tags, palette) viene dai
## dati (data/world/regions.json via GameData). Una scena .tscn per regione
## imposta solo region_id nell'inspector.
##
## Come la zona di test di US-006, e' un tilemap diagnostico: bordo di muri e
## un pavimento, con una Area2D per ogni location_tag della regione (marcata
## col tag, cosi' entrando ci si legge dove si e') e i passaggi verso le altre
## regioni (hub-and-spoke: la citta' e' collegata a tutte, ognuna torna alla
## citta'). L'arte vera e i biomi disegnati a mano sono un non-goal di questa
## fase; il gating dei passaggi si applica in US-611.
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
## La regione hub: collegata a tutte le altre (design-world cap. 2.1).
const HUB := "mirwada"

## Regione da caricare. Le .tscn in scenes/regioni/ lo impostano.
@export var region_id: String = ""

var _tag_corrente: String = ""
var _in_viaggio: bool = false


func _ready() -> void:
	tile_set = load("res://assets/placeholder/tileset.tres")
	_dipingi()
	_tinta_di_fondo()
	_crea_zone()
	_crea_passaggi()
	_colloca_giocatore()
	_registra_regione()


func _regione_dati() -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("get_region", region_id) if gd != null else {}


func _dipingi() -> void:
	for x in W:
		for y in H:
			var bordo: bool = x == 0 or y == 0 or x == W - 1 or y == H - 1
			set_cell(Vector2i(x, y), SORGENTE, MURO if bordo else PAVIMENTO)


## Densita' mistica visiva minima: una tinta di sfondo dalla palette_visiva
## della regione (design-world cap. 2). 'neutra' non ha palette -> niente
## tinta (la citta' resta piatta).
func _tinta_di_fondo() -> void:
	var pal_id: String = str(_regione_dati().get("palette_visiva", ""))
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null or pal_id.is_empty() or pal_id == "neutra":
		return
	var pal: Dictionary = gd.call("get_vfx_palette", pal_id)
	var hex: String = str(pal.get("primario", ""))
	if not hex.begins_with("#"):
		return
	var c := Color(hex)
	c.a = 0.14
	var rect := ColorRect.new()
	rect.name = "TintaRegione"
	rect.color = c
	rect.position = Vector2.ZERO
	rect.size = Vector2(W * TILE, H * TILE)
	rect.z_index = -100
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


## Una Area2D per location_tag, disposte a griglia nell'interno. Ogni zona
## porta il proprio tag come meta: entrando, il giocatore "legge" dove si
## trova (US-602). La grafica e' assente: e' un rettangolo invisibile.
func _crea_zone() -> void:
	var tags: Array = (_regione_dati().get("location_tags", []) as Array)
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


## I passaggi verso le altre regioni. Hub-and-spoke: la citta' ha un passaggio
## per ogni altra regione lungo il bordo destro; ogni altra regione ne ha uno
## verso la citta' lungo il bordo sinistro. Gli id di destinazione escono dai
## dati (GameData.get_regions), nessun nome hardcoded.
func _crea_passaggi() -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return
	var destinazioni: Array = []
	if region_id == HUB:
		for r in gd.call("get_regions"):
			var rid: String = str((r as Dictionary).get("id", ""))
			if rid != HUB and not rid.is_empty():
				destinazioni.append(rid)
	elif not region_id.is_empty():
		destinazioni.append(HUB)

	for i in destinazioni.size():
		var lato_destro: bool = region_id == HUB
		var x: float = float(W - 3) * TILE if lato_destro else 3.0 * TILE
		var y: float = TILE * 3 + (float(H - 6) * TILE) * (float(i) + 0.5) / float(maxi(destinazioni.size(), 1))
		var area := Area2D.new()
		area.name = "Passaggio_%s" % destinazioni[i]
		area.set_meta("target_region", destinazioni[i])
		area.position = Vector2(x, y)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE * 1.5, TILE * 2)
		shape.shape = rect
		area.add_child(shape)
		var marker := ColorRect.new()
		marker.color = Color(0.9, 0.85, 0.3, 0.5)
		marker.position = -rect.size * 0.5
		marker.size = rect.size
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.add_child(marker)
		area.body_entered.connect(_su_passaggio.bind(str(destinazioni[i])))
		add_child(area)


func _su_ingresso_zona(body: Node, location_tag: String) -> void:
	if not body.is_in_group("player"):
		return
	if location_tag == _tag_corrente:
		return
	_tag_corrente = location_tag
	zona_cambiata.emit(location_tag)


func _su_passaggio(body: Node, target: String) -> void:
	if _in_viaggio or not body.is_in_group("player"):
		return
	_in_viaggio = true
	_viaggia_verso.call_deferred(target)


## Sostituisce questa scena di regione con quella della destinazione. Il player
## e gli overlay vivono in main.tscn (fratelli): restano, la nuova regione li
## riposiziona nel suo _ready. Finche' il gating (US-611) non c'e', ogni
## passaggio e' aperto.
func _viaggia_verso(target: String) -> void:
	var scena_path: String = "res://scenes/regioni/%s.tscn" % target
	var padre: Node = get_parent()
	if padre == null or not ResourceLoader.exists(scena_path):
		_in_viaggio = false
		return
	var nuova: Node = load(scena_path).instantiate()
	padre.add_child(nuova)
	queue_free()


## Il location_tag della zona in cui si trova il giocatore ("" fuori da ogni
## zona nominata). Lo leggeranno il gating (US-611) e le condizioni
## in_zona_tag delle abilita' (US-605).
func tag_corrente() -> String:
	return _tag_corrente


## Gli id di regione raggiungibili da un passaggio di questa scena.
func passaggi_verso() -> Array:
	var out: Array = []
	for c in get_children():
		if c is Area2D and c.has_meta("target_region"):
			out.append(str(c.get_meta("target_region")))
	return out


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
