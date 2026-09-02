extends Area2D
## Arco offensivo di un attacco. Non ha vita propria: qualcuno la accende
## (attiva) e la spegne (disattiva) — per gli attacchi del giocatore lo fa
## la macchina di animazione sugli eventi hitbox_on / hitbox_off, cioe' dai
## frame di data/animations.json.
##
## Colpisce ogni Hurtbox che tocca UNA volta per attivazione. La forma e la
## grafica placeholder sono un settore circolare (angolo, raggio) costruito
## a runtime: nella direzione guardata.
##
## Layer/mask: monitoring su mask 3 (le Hurtbox stanno sul layer 3).
##
## NIENTE class_name: coerente col progetto.

signal ha_colpito(bersaglio: Node, danno: float)

var _danno: float = 0.0
var _stagger: float = 0.0
var _origine: Node = null
var _colpiti: Array = []

var _forma: CollisionShape2D
var _grafica: Polygon2D


func _ready() -> void:
	monitoring = false
	_costruisci(100.0, 22.0)
	disattiva()


## Ricostruisce settore e grafica. angolo in gradi, raggio in px.
func configura(angolo: float, raggio: float) -> void:
	_costruisci(angolo, raggio)


## Accende la hitbox: da qui in avanti chi tocca viene colpito, una volta sola.
func attiva(danno: float, stagger: float, origine: Node) -> void:
	_danno = danno
	_stagger = stagger
	_origine = origine
	_colpiti.clear()
	monitoring = true
	visible = true


func disattiva() -> void:
	monitoring = false
	visible = false


func _physics_process(_delta: float) -> void:
	if not monitoring:
		return
	for a in get_overlapping_areas():
		if not a.has_method("subisci") or _colpiti.has(a):
			continue
		_colpiti.append(a)
		a.call("subisci", _danno, _stagger, _origine)
		ha_colpito.emit(a, _danno)


func _costruisci(angolo: float, raggio: float) -> void:
	var punti: PackedVector2Array = [Vector2.ZERO]
	var passi: int = 10
	var mezza: float = deg_to_rad(angolo) * 0.5
	for i in passi + 1:
		var t: float = -mezza + (2.0 * mezza) * (float(i) / float(passi))
		punti.append(Vector2(cos(t), sin(t)) * raggio)

	if _forma == null:
		_forma = CollisionShape2D.new()
		add_child(_forma)
	var poly := ConvexPolygonShape2D.new()
	poly.points = punti
	_forma.shape = poly

	if _grafica == null:
		_grafica = Polygon2D.new()
		_grafica.color = Color(1.0, 0.96, 0.7, 0.55)
		_grafica.z_index = 5
		add_child(_grafica)
	_grafica.polygon = punti
