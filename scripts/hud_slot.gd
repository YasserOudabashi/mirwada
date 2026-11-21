extends Control
## US-8B75d: uno slot della hotbar, solo simbolo: cornice a pixel, il glifo della prima primitiva dell'abilita'
## (colorato dalla rampa del Pathway), la cifra del tasto nell'angolo, la ricarica come un velo che scende dall'alto,
## un velo blu se non basta la spiritualita' e un lampo quando parte. Il nome dell'abilita' sta solo nel libro.
## Colori e misure da data/ui/hud.json hotbar; lo riempie hud.gd con imposta().
##
## NIENTE class_name: coerente col progetto.

const PX := 0.5

var cfg: Dictionary = {}
var comune: Dictionary = {}
var abilita: String = ""            # id dell'abilita' nello slot ("" = vuoto): per i test e per il libro
var ricarica: float = 0.0           # 0..1: quanto manca
var senza_spirito: bool = false
var lampo: float = 0.0

var _glifo := TextureRect.new()
var _sopra := Control.new()
var _cifra := TextureRect.new()


func configura(hotbar: Dictionary, tutto: Dictionary, tasto: int, rampa: Material) -> void:
	cfg = hotbar
	comune = tutto
	var lato: float = float(cfg.get("lato", 22))
	custom_minimum_size = Vector2(lato, lato)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glifo.name = "Glifo"
	_glifo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glifo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_glifo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glifo.material = rampa
	_glifo.size = Vector2(16, 16)                    # 32 pixel del glifo a 1:1
	_glifo.position = Vector2((lato - 16.0) / 2.0, (lato - 16.0) / 2.0)
	_glifo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glifo)
	_sopra.name = "Sopra"
	_sopra.size = Vector2(lato, lato)
	_sopra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sopra.draw.connect(_disegna_sopra)
	add_child(_sopra)
	_cifra.name = "Cifra"
	_cifra.texture = load("res://assets/ui/hud/cifra_%d.png" % tasto) as Texture2D
	_cifra.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cifra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cifra.size = Vector2(3, 4)                      # 6x8 pixel
	_cifra.position = Vector2(PX * 2, PX * 2)
	_cifra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cifra)


func imposta(ability_id: String, glifo: Texture2D, frazione_ricarica: float, poco_spirito: bool) -> void:
	abilita = ability_id
	_glifo.texture = glifo
	_glifo.visible = glifo != null
	ricarica = clampf(frazione_ricarica, 0.0, 1.0)
	senza_spirito = poco_spirito
	_glifo.modulate.a = 0.55 if ricarica > 0.0 or senza_spirito else 1.0
	_cifra.modulate.a = 0.45 if ability_id.is_empty() else 0.9
	queue_redraw()
	_sopra.queue_redraw()


## Il lampo quando l'abilita' parte.
func lampeggia() -> void:
	lampo = 1.0
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		lampo = v
		_sopra.queue_redraw(), 1.0, 0.0, float(cfg.get("lampo_s", 0.35)))


func _draw() -> void:
	var l: float = size.x
	var ink := Color(str(comune.get("contorno", "#181425")))
	var fondo := Color(str(comune.get("fondo", "#262b44")))
	fondo.a = float(cfg.get("fondo_alpha", 0.55)) * (0.6 if abilita.is_empty() else 1.0)
	draw_rect(Rect2(-PX, -PX, l + 2 * PX, l + 2 * PX), ink)
	draw_rect(Rect2(0, 0, l, l), fondo)
	var bordo := Color(str(cfg.get("bordo", "#3a4466")))
	var luce := Color(str(cfg.get("luce", "#5a6988")))
	draw_rect(Rect2(0, 0, l, PX), luce)                            # luce in alto a sinistra
	draw_rect(Rect2(0, 0, PX, l), luce)
	draw_rect(Rect2(0, l - PX, l, PX), bordo)                      # ombra in basso a destra
	draw_rect(Rect2(l - PX, 0, PX, l), bordo)


func _disegna_sopra() -> void:
	var l: float = size.x
	if senza_spirito and ricarica <= 0.0:
		var blu := Color(str(cfg.get("senza_spirito", "#124e89")))
		blu.a = 0.45
		_sopra.draw_rect(Rect2(PX, PX, l - 2 * PX, l - 2 * PX), blu)
	if ricarica > 0.0:                               # il velo scende dall'alto: quel che resta e' quanto manca
		var velo := Color(str(comune.get("contorno", "#181425")))
		velo.a = float(cfg.get("ricarica_alpha", 0.72))
		var h: float = roundf((l - 2 * PX) * ricarica / PX) * PX
		_sopra.draw_rect(Rect2(PX, l - PX - h, l - 2 * PX, h), velo)
	if lampo > 0.0:
		var bianco := Color(1, 1, 1, 0.8 * lampo)
		_sopra.draw_rect(Rect2(0, 0, l, l), bianco, false, 1.0)
		_sopra.draw_rect(Rect2(PX, PX, l - 2 * PX, l - 2 * PX), Color(1, 1, 1, 0.25 * lampo))
