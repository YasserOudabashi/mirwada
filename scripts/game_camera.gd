extends Camera2D
## Camera di gioco: segue il nodo padre con smoothing e resta dentro i
## limiti della zona corrente.
##
## I limiti NON sono della camera ma della ZONA: e' la zona (US-006) a
## chiamare apply_zone_limits() col proprio rettangolo giocabile. Finche'
## nessuno lo fa, valgono i limiti di default di Godot (praticamente
## infiniti) e la camera segue senza vincoli.
##
## NIENTE class_name: coerente col resto del progetto.

const VELOCITA_SMOOTHING := 5.0
## Quanto in fretta il trauma di shake decade (unita' al secondo).
const DECADIMENTO_TRAUMA := 1.6
## Ampiezza massima dello scuotimento in px a trauma pieno.
const AMPIEZZA_MAX := 6.0

var _trauma: float = 0.0


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = VELOCITA_SMOOTHING
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null and am.has_signal("shake_richiesto"):
		am.shake_richiesto.connect(_su_shake)


## Lo shake e' un canale di feedback guidato dai dati (audio.json.
## combat_feedback[*].shake), instradato qui da AudioManager. Modello a
## "trauma": si accumula, poi decade; l'ampiezza va col quadrato cosi' i
## colpi piccoli non fanno tremare tutto.
func _su_shake(intensita: float) -> void:
	_trauma = minf(_trauma + intensita, 1.0)


func _process(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = maxf(_trauma - DECADIMENTO_TRAUMA * delta, 0.0)
		var a: float = _trauma * _trauma * AMPIEZZA_MAX
		offset = Vector2(randf_range(-a, a), randf_range(-a, a))
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO


## world_rect: area giocabile in coordinate mondo. La camera non mostrera'
## nulla oltre questi bordi (Camera2D li clampa contro meta' viewport).
func apply_zone_limits(world_rect: Rect2) -> void:
	limit_left = int(world_rect.position.x)
	limit_top = int(world_rect.position.y)
	limit_right = int(world_rect.end.x)
	limit_bottom = int(world_rect.end.y)


## Ripristina i limiti aperti (cambio zona senza confini, o zona non ancora
## caricata).
func clear_zone_limits() -> void:
	limit_left = -10000000
	limit_top = -10000000
	limit_right = 10000000
	limit_bottom = 10000000
