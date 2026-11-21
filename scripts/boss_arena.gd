extends Node2D
## US-1505: il bordo dell'arena di un boss, a terra: un cerchio di trattini che pulsa piano. Lo crea e lo toglie
## scripts/boss.gd; colore e raggio dai dati (balance.json boss.<id>.arena). Sta nel mondo (y_sort) al centro dell'arena.
##
## NIENTE class_name: coerente col progetto.

var raggio: float = 160.0
var colore: Color = Color("#e43b44")
var _t: float = 0.0


func _ready() -> void:
	z_index = -4                                  # a terra: sopra il terreno (-10) e le botole (-5), sotto le figure


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := colore
	c.a = 0.8 + 0.2 * sin(_t * 3.0)
	var n: int = int(raggio / 6.0)
	for i in n:                                   # trattini: meta' pieni, meta' vuoti
		var a0: float = TAU * float(i) / float(n)
		var a1: float = a0 + TAU / float(n) * 0.55
		draw_arc(Vector2.ZERO, raggio, a0, a1, 3, Color(0.094, 0.078, 0.145, c.a), 4.0)   # contorno #181425: si
		draw_arc(Vector2.ZERO, raggio, a0, a1, 3, c, 2.0)                                  # legge su ogni terreno
