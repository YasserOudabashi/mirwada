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


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = VELOCITA_SMOOTHING


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
