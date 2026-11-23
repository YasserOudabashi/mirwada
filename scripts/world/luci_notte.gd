extends Node
## US-8B27: le luci della notte (data/world/luce.json "luci"). Finestre accese delle case e la lanterna del faro col suo
## fascio che gira: aloni a gradini (pixel, niente sfumature) che si sommano a cio' che hanno sotto, su uno strato fuori
## dal mondo come le lucciole, cosi' il buio (luce.gd) non li spegne. Quanto sono forti lo dice il momento del giorno
## ("forza"); di giorno non ci sono. Le case accese sono sempre le stesse (dipende dalla casella della casa).
##
## NIENTE class_name: coerente col progetto.

var _mondo: Node
var _strato: CanvasLayer
var _per_blocco: Dictionary = {}          # blocco -> [Sprite2D]
var _faro: Node2D = null
var _fascio: Sprite2D = null
var _forza: float = 0.0
var _aloni: Dictionary = {}               # chiave colore+passi -> texture


func _ready() -> void:
	name = "LuciNotte"
	if _mondo == null:
		_mondo = get_parent()
	_strato = CanvasLayer.new()
	_strato.name = "Luci"
	_strato.follow_viewport_enabled = true
	_strato.layer = 0                                # sopra il mondo, sotto l'HUD e il libro
	add_child(_strato)
	if _mondo is CanvasItem:
		(_mondo as CanvasItem).visibility_changed.connect(func() -> void: _aggiorna_visibile())
	if _mondo.has_signal("blocco_costruito"):
		_mondo.blocco_costruito.connect(_su_blocco)
		_mondo.blocco_scaricato.connect(_via_blocco)
	if _mondo.has_signal("livello_cambiato"):
		_mondo.livello_cambiato.connect(func(_l: String) -> void: _aggiorna_visibile())
	_forza = forza_voluta()
	_monta_faro.call_deferred()


func _dati() -> Dictionary:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	var l: Variant = (gd.call("get_luce") as Dictionary).get("luci") if gd != null else null
	return l if l is Dictionary else {}


## Quanto sono accese le luci adesso (0 = spente): luce.json luci.forza per momento del giorno.
func forza_voluta() -> float:
	var ts: Node = Engine.get_main_loop().root.get_node_or_null("TimeSystem")
	var momento: String = str(ts.call("momento")) if ts != null else ""
	return float((_dati().get("forza", {}) as Dictionary).get(momento, 0.0))


func _aggiorna_visibile() -> void:
	_strato.visible = (_mondo as CanvasItem).is_visible_in_tree() and str(_mondo.get("livello")) == "superficie"


func _process(delta: float) -> void:
	_forza = move_toward(_forza, forza_voluta(), delta / maxf(float(_dati().get("transizione", 3.0)), 0.01))
	for b in _per_blocco:
		for s in _per_blocco[b]:
			(s as Sprite2D).modulate.a = _forza
	if _faro != null:
		_faro.modulate.a = _forza
		_fascio.rotation += delta * TAU * float((_dati().get("faro", {}) as Dictionary).get("giri_al_minuto", 4.0)) / 60.0


## Le case del blocco appena costruito: una su `probabilita` ha le finestre accese, sempre la stessa.
func _su_blocco(b: Vector2i) -> void:
	var cfg: Dictionary = _dati().get("finestre", {})
	if cfg.is_empty() or _per_blocco.has(b):
		return
	var lato: int = int(_mondo.get("BLOCCO"))
	var tile: float = float(_mondo.get("tile"))
	var luci: Array = []
	for e in (_mondo.get("dati") as Dictionary).get("edifici", []):
		var x: int = int(e[0])
		var y: int = int(e[1])
		if Vector2i(x / lato, y / lato) != b or not accesa(x, y):
			continue
		var s := _alone(str(cfg.get("colore", "#ffc46b")), float(cfg.get("raggio", 1.4)) * tile)
		# davanti alla facciata: in mezzo alla casa, sulla riga piu' a sud del sedime
		s.position = Vector2((x + float(e[2]) / 2.0) * tile, (y + float(e[3]) - 0.6) * tile)
		s.modulate.a = _forza
		_strato.add_child(s)
		luci.append(s)
	_per_blocco[b] = luci


func _via_blocco(b: Vector2i) -> void:
	for s in _per_blocco.get(b, []):
		(s as Node).queue_free()
	_per_blocco.erase(b)


## La casa in (x, y) ha le finestre accese? Dipende solo dalla sua casella: stesse case a ogni partita.
func accesa(x: int, y: int) -> bool:
	var p: float = float((_dati().get("finestre", {}) as Dictionary).get("probabilita", 0.0))
	return float(posmod(hash(Vector2i(x, y)), 1000)) / 1000.0 < p


func luci_del_blocco(b: Vector2i) -> Array:
	return _per_blocco.get(b, [])


## La lanterna del faro: un alone grande e un fascio che gira, sopra la soglia del faro (mezzi.json).
func _monta_faro() -> void:
	var cfg: Dictionary = _dati().get("faro", {})
	var soglia: Node2D = _mondo.get_node_or_null(str(cfg.get("nodo", ""))) as Node2D
	if cfg.is_empty() or soglia == null:
		return
	var tile: float = float(_mondo.get("tile"))
	var sc: Array = cfg.get("scostamento", [0, 0])
	_faro = Node2D.new()
	_faro.name = "Faro"
	_faro.position = soglia.position + Vector2(float(sc[0]), float(sc[1]))
	_faro.modulate.a = _forza
	_faro.add_child(_alone(str(cfg.get("colore", "#fff2c2")), float(cfg.get("raggio", 3.0)) * tile))
	_fascio = Sprite2D.new()
	_fascio.name = "Fascio"
	_fascio.texture = _texture_fascio(str(cfg.get("colore", "#fff2c2")), int(float(cfg.get("lunghezza", 9.0)) * tile))
	_fascio.centered = false
	_fascio.scale = Vector2(2, 2)                    # 1 texel = 2 unita', come gli aloni
	_fascio.offset = Vector2(0, -_fascio.texture.get_height() / 2.0)
	_fascio.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fascio.material = _somma()
	_faro.add_child(_fascio)
	_strato.add_child(_faro)


func faro() -> Node2D:
	return _faro


func _somma() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## Un alone tondo a 4 gradini netti (nessuna sfumatura), del colore dato, largo 2 * raggio unita'.
func _alone(colore: String, raggio: float) -> Sprite2D:
	var lato: int = maxi(8, int(raggio))            # 1 texel = 2 unita': la grana dei pixel del mondo
	var chiave: String = "%s:%d" % [colore, lato]
	if not _aloni.has(chiave):
		var img := Image.create(lato, lato, false, Image.FORMAT_RGBA8)
		var c := Color(colore)
		var mezzo: float = lato / 2.0
		for y in lato:
			for x in lato:
				var d: float = Vector2(x + 0.5 - mezzo, y + 0.5 - mezzo).length() / mezzo
				var a: float = 0.0 if d > 1.0 else (0.12 if d > 0.75 else (0.24 if d > 0.5 else (0.4 if d > 0.25 else 0.6)))
				img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
		_aloni[chiave] = ImageTexture.create_from_image(img)
	var s := Sprite2D.new()
	s.texture = _aloni[chiave]
	s.scale = Vector2(2, 2)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.material = _somma()
	return s


## Il fascio: un cuneo che parte dalla lanterna e si allarga, a due gradini.
func _texture_fascio(colore: String, lunghezza: int) -> Texture2D:
	var w: int = maxi(8, lunghezza / 2)
	var h: int = maxi(8, w / 3)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := Color(colore)
	for y in h:
		for x in w:
			var apertura: float = (float(x) / w) * h / 2.0
			var d: float = absf(y + 0.5 - h / 2.0)
			if d <= apertura:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.3 if d <= apertura * 0.5 else 0.14))
	return ImageTexture.create_from_image(img)
