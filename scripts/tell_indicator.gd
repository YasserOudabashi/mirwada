extends Control
## US-020 — indicatore visivo del tell sonoro degli attacchi nemici.
##
## Il gioco usa il tell audio come canale informativo (che tipo di attacco
## arriva, da che direzione). Chi non lo sente deve avere lo stesso dato: due
## opzioni di data/audio.json.accessibilita lo governano.
##   indicatore_visivo_tell     -> anello sulla posizione del nemico, se inquadrato
##   indicatore_direzione_suono -> freccia sul bordo schermo, se il nemico e' fuori
##
## Ascolta AudioManager.tell_emesso, che scatta a OGNI tell a prescindere dal
## fatto che il nemico sia visibile.
##
## NIENTE class_name: coerente col progetto.

const DURATA := 0.6

## Un colore per categoria di attacco: e' l'altra meta' del dato, non decoro.
const COLORE_CATEGORIA := {
	"schivabile": Color(1.0, 0.85, 0.2),
	"parabile": Color(0.3, 0.8, 1.0),
	"solo_schivata": Color(1.0, 0.25, 0.2),
	"coprirsi": Color(1.0, 0.55, 0.15),
	"interrompere": Color(1.0, 0.3, 0.9),
}
const COLORE_DEFAULT := Color(1, 1, 1)

var _attivi: Array = []  # [{pos: Vector2 mondo, colore: Color, left: float}]
var _mostra_visivo := true
var _mostra_direzione := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.tell_emesso.connect(_su_tell)


func _su_tell(pos_mondo: Vector2, categoria: String) -> void:
	# Le opzioni si rileggono a ogni tell: cambiarle dal menu ha effetto subito.
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		_mostra_visivo = bool(am.call("accessibilita", "indicatore_visivo_tell"))
		_mostra_direzione = bool(am.call("accessibilita", "indicatore_direzione_suono"))
	_attivi.append({
		"pos": pos_mondo,
		"colore": COLORE_CATEGORIA.get(categoria, COLORE_DEFAULT),
		"left": DURATA,
	})
	queue_redraw()


func _process(delta: float) -> void:
	if _attivi.is_empty():
		return
	for m in _attivi:
		m["left"] -= delta
	_attivi = _attivi.filter(func(m: Dictionary) -> bool: return m["left"] > 0.0)
	queue_redraw()


func _draw() -> void:
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	var rect := Rect2(Vector2.ZERO, size)
	var centro: Vector2 = size * 0.5
	for m in _attivi:
		var t: float = float(m["left"]) / DURATA  # 1 -> 0
		var col: Color = m["colore"]
		col.a = t
		var schermo: Vector2 = canvas * (m["pos"] as Vector2)
		if rect.has_point(schermo):
			if _mostra_visivo:
				draw_arc(schermo, 6.0 + 26.0 * t, 0.0, TAU, 24, col, 2.0)
		elif _mostra_direzione:
			var dir: Vector2 = (schermo - centro).normalized()
			_freccia(_punto_sul_bordo(centro, dir, rect), dir, col)


## Punto in cui il raggio da 'origine' lungo 'dir' incontra il bordo di 'rect'
## (con un margine, cosi' la freccia resta dentro lo schermo).
func _punto_sul_bordo(origine: Vector2, dir: Vector2, rect: Rect2) -> Vector2:
	var m := 18.0
	var tx := INF
	var ty := INF
	if dir.x > 0.001:
		tx = (rect.end.x - m - origine.x) / dir.x
	elif dir.x < -0.001:
		tx = (rect.position.x + m - origine.x) / dir.x
	if dir.y > 0.001:
		ty = (rect.end.y - m - origine.y) / dir.y
	elif dir.y < -0.001:
		ty = (rect.position.y + m - origine.y) / dir.y
	return origine + dir * minf(tx, ty)


func _freccia(punta: Vector2, dir: Vector2, col: Color) -> void:
	var perp := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([
		punta,
		punta - dir * 14.0 + perp * 7.0,
		punta - dir * 14.0 - perp * 7.0,
	]), col)


## Per i test: numero di indicatori attivi in questo momento.
func indicatori_attivi() -> int:
	return _attivi.size()
