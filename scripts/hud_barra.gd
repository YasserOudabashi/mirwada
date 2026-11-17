extends Control
## US-8B75d: una barra dell'HUD (vita, spiritualita', recitazione) disegnata a pixel: contorno di 1 px, fondo scuro,
## il pieno in tre toni (luce sopra, ombra sotto), le tacche ogni quarto e la scia del danno appena preso, che resta
## un attimo e poi scende piano. Quando si guarisce il pieno sale morbido. Sotto la soglia di poca vita batte.
## Misure e colori dai dati (data/ui/hud.json barre.<id>); il valore lo da' hud.gd con imposta().
##
## NIENTE class_name: coerente col progetto.

const PX := 0.5                     # un pixel vero (1 unita' = 2 pixel)

var cfg: Dictionary = {}            # barre.<id> di hud.json
var comune: Dictionary = {}         # tutto hud.json (contorno, fondo, scia, poca_vita)
var pieno: float = 0.0              # quello che si vede (0..1)
var scia: float = 0.0
var obiettivo: float = 0.0
var _attesa: float = 0.0
var _tempo: float = 0.0
var _batte: bool = false


func configura(barra: Dictionary, tutto: Dictionary, batte: bool = false) -> void:
	cfg = barra
	comune = tutto
	_batte = batte
	custom_minimum_size = Vector2(float(cfg.get("larghezza", 80)), float(cfg.get("altezza", 4)))
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Il valore nuovo (0..1). subito: senza scia ne' salita (la prima volta, o un cambio di Sequenza).
func imposta(frazione: float, subito: bool = false) -> void:
	obiettivo = clampf(frazione, 0.0, 1.0)
	if subito:
		pieno = obiettivo
		scia = obiettivo
	elif obiettivo < pieno:                          # un colpo: il pieno scende subito, la scia aspetta
		scia = maxf(scia, pieno)
		pieno = obiettivo
		_attesa = float((comune.get("scia", {}) as Dictionary).get("attesa_s", 0.45))
	queue_redraw()


func _process(delta: float) -> void:
	var s: Dictionary = comune.get("scia", {})
	var muove := false
	if pieno < obiettivo:                            # cura: sale morbida
		pieno = minf(obiettivo, pieno + delta / maxf(float(s.get("salita_s", 0.25)), 0.01))
		muove = true
	if scia > pieno:
		if _attesa > 0.0:
			_attesa -= delta
		else:
			scia = maxf(pieno, scia - delta * float(s.get("discesa_per_s", 0.55)))
		muove = true
	scia = maxf(scia, pieno)
	var poca: Dictionary = comune.get("poca_vita", {})
	if _batte and obiettivo > 0.0 and obiettivo <= float(poca.get("soglia", 0.3)):
		_tempo += delta
		muove = true
	if muove:
		queue_redraw()


func _px(x: float) -> float:
	return roundf(x / PX) * PX


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var toni: Array = cfg.get("toni", ["#3a4466", "#8b9bb4", "#c0cbdc"])
	var ombra := Color(str(toni[0]))
	var tinta := Color(str(toni[1]))
	var luce := Color(str(toni[2]))
	var ink := Color(str(comune.get("contorno", "#181425")))
	var fondo := Color(str(comune.get("fondo", "#262b44")))
	fondo.a = float(comune.get("fondo_alpha", 0.78))
	var poca: Dictionary = comune.get("poca_vita", {})
	if _batte and obiettivo > 0.0 and obiettivo <= float(poca.get("soglia", 0.3)):
		var t: float = 0.5 + 0.5 * sin(_tempo * TAU / maxf(float(poca.get("battito_s", 0.9)), 0.1))
		tinta = tinta.lerp(luce, 0.45 * t)
	draw_rect(Rect2(-PX, -PX, w + 2 * PX, h + 2 * PX), ink)          # contorno
	draw_rect(Rect2(0, 0, w, h), fondo)
	var ws: float = _px(w * scia)
	if ws > 0.0:
		draw_rect(Rect2(0, 0, ws, h), Color(str(cfg.get("scia", "#ead4aa"))))
	var wp: float = _px(w * pieno)
	if wp > 0.0:
		draw_rect(Rect2(0, 0, wp, h), tinta)
		if h >= 2.0:
			draw_rect(Rect2(0, 0, wp, PX), luce)                          # luce in alto
			draw_rect(Rect2(0, h - PX, wp, PX), ombra)                    # ombra in basso
		if wp < w:
			draw_rect(Rect2(wp - PX, 0, PX, h), luce)                     # il bordo del pieno, acceso
	if h >= 4.0:                                                          # tacche ogni quarto
		var tacca := ink
		tacca.a = float(comune.get("tacche_alpha", 0.3))
		for i in range(1, 4):
			draw_rect(Rect2(_px(w * i / 4.0), PX, PX, h - 2 * PX), tacca)
