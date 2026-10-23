extends Node2D
## Mondo unico (US-8B12): carica il mondo esportato da tools/art/esporta_mondo.py
## (assets/world/) e costruisce solo il pezzo attorno al giocatore.
##   - terreno: le tessere 32x32 gia' composte in Python (pareti, bordi e
##     varianti compresi), un TileMapLayer con un atlante per foglio;
##   - ostacoli: blocchi.png (255 = non si passa), un TileMapLayer invisibile con
##     una tessera quadrata di collisione;
##   - oggetti (alberi, rocce, trono...): Sprite2D figli di questo nodo, che ha
##     l'ordinamento per profondita' (y_sort): il giocatore va messo qui dentro.
## La modalita' (luminoso | cupo) viene da GameState.tema_arte(): stessi dati,
## altri fogli e altri sprite.
##
## NIENTE class_name: coerente col progetto.

const BLOCCO := 16                       # caselle per lato di un blocco caricato
const STRATO_COLLISIONE := 1             # lo stesso dei muri delle scene di regione

@export var cartella: String = "res://assets/world"
## "" = quello della modalita' della partita (GameState.tema_arte()).
@export var tema: String = ""
## Blocchi caricati attorno al giocatore, per lato (2 -> 5x5 blocchi = 80x80 caselle).
@export var raggio_blocchi: int = 2

var dati: Dictionary = {}
var larghezza: int = 0
var altezza: int = 0
var tile: int = 32

var _indici: PackedByteArray        # RGB per casella: R + 256 * G = tessera
var _blocchi: PackedByteArray       # 1 byte per casella
var _regioni: PackedByteArray       # 1 byte per casella
var _per_foglio: int = 8192
var _colonne: int = 64
var _terreno: TileMapLayer
var _ostacoli: TileMapLayer
var _caricati: Dictionary = {}      # Vector2i blocco -> Array di Sprite2D
var _oggetti_per_blocco: Dictionary = {}
var _texture_oggetti: Dictionary = {}
var _blocco_centro := Vector2i(-9999, -9999)
var _tema_caricato: String = ""
var _cella_regione := Vector2i(-9999, -9999)


func _ready() -> void:
	y_sort_enabled = true
	if dati.is_empty() and not carica():
		return
	for c in get_children():                       # il giocatore della scena parte dalla casa al porto
		if c.is_in_group("player") and c is Node2D:
			colloca(c as Node2D, partenza())
	segui(partenza())


## Mette un nodo (il giocatore) in una posizione e porta subito li' la sua
## telecamera: con lo scorrimento morbido scivolerebbe da (0, 0) attraverso la mappa.
func colloca(nodo: Node2D, pos: Vector2) -> void:
	nodo.position = pos
	for cam in nodo.find_children("*", "Camera2D", true, false):
		(cam as Camera2D).reset_smoothing()
	segui(pos)


## Legge i dati e prepara i livelli; i blocchi si costruiscono con segui().
func carica() -> bool:
	var f := FileAccess.open(cartella.path_join("mondo.json"), FileAccess.READ)
	if f == null:
		push_error("[Mondo] manca %s: lancia tools/art/esporta_mondo.py" % cartella.path_join("mondo.json"))
		return false
	dati = JSON.parse_string(f.get_as_text())
	larghezza = int(dati["larghezza"])
	altezza = int(dati["altezza"])
	tile = int(dati["tile"])
	_colonne = int(dati["colonne_foglio"])
	_per_foglio = _colonne * int(dati["righe_foglio"])
	_tema_caricato = tema if not tema.is_empty() else _tema_partita()
	var cart_tema: String = cartella.path_join(_tema_caricato)
	_indici = _immagine(cart_tema.path_join("indici.png"), Image.FORMAT_RGB8)
	_blocchi = _immagine(cartella.path_join("blocchi.png"), Image.FORMAT_L8)
	_regioni = _immagine(cartella.path_join("regioni.png"), Image.FORMAT_L8)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile, tile)
	for k in int((dati["fogli"] as Dictionary).get(_tema_caricato, 0)):
		var src := TileSetAtlasSource.new()
		src.texture = _texture(cart_tema.path_join("tessere_%d.png" % k))
		src.texture_region_size = Vector2i(tile, tile)
		ts.add_source(src, k)
	_terreno = TileMapLayer.new()
	_terreno.name = "Terreno"
	_terreno.tile_set = ts
	_terreno.z_index = -10                    # sotto gli oggetti e il giocatore
	add_child(_terreno)

	var ts_ost := TileSet.new()
	ts_ost.tile_size = Vector2i(tile, tile)
	ts_ost.add_physics_layer()
	ts_ost.set_physics_layer_collision_layer(0, STRATO_COLLISIONE)
	var vuota := Image.create(tile, tile, false, Image.FORMAT_RGBA8)
	var src_ost := TileSetAtlasSource.new()
	src_ost.texture = ImageTexture.create_from_image(vuota)
	src_ost.texture_region_size = Vector2i(tile, tile)
	src_ost.create_tile(Vector2i.ZERO)
	ts_ost.add_source(src_ost, 0)
	var td: TileData = src_ost.get_tile_data(Vector2i.ZERO, 0)
	var h: float = tile / 2.0
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
	_ostacoli = TileMapLayer.new()
	_ostacoli.name = "Ostacoli"
	_ostacoli.tile_set = ts_ost
	_ostacoli.visible = false
	add_child(_ostacoli)

	for o in dati["oggetti"]:
		var b := Vector2i(int(float(o[1]) / BLOCCO), int(float(o[2]) / BLOCCO))
		if not _oggetti_per_blocco.has(b):
			_oggetti_per_blocco[b] = []
		_oggetti_per_blocco[b].append(o)
	return true


## Posizione (unita' di gioco) dove comincia la partita: la casa al porto.
func partenza() -> Vector2:
	var p: Array = dati.get("partenza", [0, 0])
	return Vector2((float(p[0]) + 0.5) * tile, (float(p[1]) + 0.5) * tile)


## Costruisce i blocchi attorno a una posizione e libera quelli lontani.
func segui(pos: Vector2) -> void:
	var c := Vector2i(floori(pos.x / (tile * BLOCCO)), floori(pos.y / (tile * BLOCCO)))
	if c == _blocco_centro:
		return
	_blocco_centro = c
	var voluti: Dictionary = {}
	for by in range(c.y - raggio_blocchi, c.y + raggio_blocchi + 1):
		for bx in range(c.x - raggio_blocchi, c.x + raggio_blocchi + 1):
			if bx >= 0 and by >= 0 and bx * BLOCCO < larghezza and by * BLOCCO < altezza:
				voluti[Vector2i(bx, by)] = true
	for b in _caricati.keys():
		if not voluti.has(b):
			_scarica(b)
	for b in voluti:
		if not _caricati.has(b):
			_costruisci(b)


func _process(_delta: float) -> void:
	var p: Node = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if p is Node2D and not dati.is_empty():
		var pos: Vector2 = (p as Node2D).global_position - global_position
		segui(pos)
		aggiorna_regione(pos)


## Regione e zona dalla posizione (US-8B12b): la regione della casella
## (regioni.png) se e' una regione dei dati, altrimenti nessuna (mare, terra di
## mezzo, isole); la zona e' il location_tag del luogo della mappa piu' vicino
## entro RAGGIO_ZONA caselle (regions.json luoghi_mondo abbina i nomi diversi).
const RAGGIO_ZONA := 12.0


func aggiorna_regione(pos: Vector2) -> void:
	var c := Vector2i(floori(pos.x / tile), floori(pos.y / tile))
	if c == _cella_regione:
		return
	_cella_regione = c
	var ws: Node = Engine.get_main_loop().root.get_node_or_null("WorldState")
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	if ws == null or gd == null:
		return
	var rid: String = regione_a(c.x, c.y)
	var reg: Dictionary = gd.call("get_region", rid)
	if reg.is_empty():
		ws.call("esci_regione")
		return
	if str(ws.call("regione_corrente")) != rid:
		ws.call("entra_regione", rid)
	var tag: String = _zona(c, reg)
	if str(ws.call("zona_corrente")) != tag:
		ws.call("imposta_zona", tag)


func _zona(c: Vector2i, reg: Dictionary) -> String:
	var tags: Array = reg.get("location_tags", [])
	var alias: Dictionary = reg.get("luoghi_mondo", {})
	var migliore: String = ""
	var dist: float = RAGGIO_ZONA
	for luogo in (dati.get("luoghi", {}) as Dictionary):
		var tag: String = str(alias.get(luogo, luogo))
		if tag not in tags:
			continue
		var p: Array = dati["luoghi"][luogo]
		var d: float = Vector2(c).distance_to(Vector2(float(p[0]), float(p[1])))
		if d <= dist:
			dist = d
			migliore = tag
	return migliore


# --- Interrogabile (giocatore, test, regioni) ---------------------------------

func tessera_a(x: int, y: int) -> int:
	if not _dentro(x, y):
		return -1
	var i: int = (y * larghezza + x) * 3
	return _indici[i] + 256 * _indici[i + 1]


func bloccata(x: int, y: int) -> bool:
	return not _dentro(x, y) or _blocchi[y * larghezza + x] > 0


func regione_a(x: int, y: int) -> String:
	if not _dentro(x, y):
		return ""
	return str((dati["regioni"] as Array)[_regioni[y * larghezza + x]])


func blocchi_caricati() -> int:
	return _caricati.size()


func tema_caricato() -> String:
	return _tema_caricato


# --- Interno -------------------------------------------------------------------

func _costruisci(b: Vector2i) -> void:
	for y in range(b.y * BLOCCO, mini((b.y + 1) * BLOCCO, altezza)):
		for x in range(b.x * BLOCCO, mini((b.x + 1) * BLOCCO, larghezza)):
			var t: int = tessera_a(x, y)
			var foglio: int = t / _per_foglio
			var r: int = t % _per_foglio
			var at := Vector2i(r % _colonne, r / _colonne)
			var src := _terreno.tile_set.get_source(foglio) as TileSetAtlasSource
			if not src.has_tile(at):
				src.create_tile(at)
			_terreno.set_cell(Vector2i(x, y), foglio, at)
			if bloccata(x, y):
				_ostacoli.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var sprite: Array = []
	for o in _oggetti_per_blocco.get(b, []):
		var chiave: String = str(o[0])
		var meta: Dictionary = (dati["sprite"] as Dictionary).get(chiave, {})
		var s := Sprite2D.new()
		s.texture = _texture_oggetto(chiave)
		s.centered = false
		s.offset = Vector2(-float(meta.get("ax", 0)), -float(meta.get("ay", 0)))
		s.position = Vector2(float(o[1]) * tile, float(o[2]) * tile)
		add_child(s)
		sprite.append(s)
	_caricati[b] = sprite


func _scarica(b: Vector2i) -> void:
	for y in range(b.y * BLOCCO, mini((b.y + 1) * BLOCCO, altezza)):
		for x in range(b.x * BLOCCO, mini((b.x + 1) * BLOCCO, larghezza)):
			_terreno.erase_cell(Vector2i(x, y))
			_ostacoli.erase_cell(Vector2i(x, y))
	for s in _caricati[b]:
		(s as Node).queue_free()
	_caricati.erase(b)


func _texture_oggetto(chiave: String) -> Texture2D:
	if not _texture_oggetti.has(chiave):
		_texture_oggetti[chiave] = _texture(cartella.path_join(_tema_caricato).path_join("oggetti/%s.png" % chiave))
	return _texture_oggetti[chiave]


func _dentro(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < larghezza and y < altezza


## Le PNG si leggono dal disco, senza l'import dell'editor (vale anche headless).
static func _texture(path: String) -> Texture2D:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		push_error("[Mondo] PNG non leggibile: " + path)
		return null
	return ImageTexture.create_from_image(img)


static func _immagine(path: String, formato: int) -> PackedByteArray:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		push_error("[Mondo] PNG non leggibile: " + path)
		return PackedByteArray()
	if img.get_format() != formato:
		img.convert(formato)
	return img.get_data()


func _tema_partita() -> String:
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("GameState")
	return str(gs.call("tema_arte")) if gs != null else "luminoso"
