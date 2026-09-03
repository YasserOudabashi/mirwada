extends CanvasLayer
## Equivalente VISIVO della percezione per Sequenza (US-218, FR-7). Vive fuori
## dal libro, sotto l'overlay della follia.
##
##   spiriti_vicini  -> sagome dei nemici disegnate ANCHE oltre i muri
##   densita_mistica -> grana d'inchiostro nell'aria (velo tenue)
##   segreti_adiacenti / preghiere_dei_seguaci -> marcatori (placeholder)
##
## Nessuna informazione vive solo qui: ogni reveal ha anche un layer audio.
##
## NIENTE class_name: coerente col progetto.

@onready var _grana: ColorRect = $Grana
@onready var _sagome: Control = $Sagome

var _perc: Node = null


func _ready() -> void:
	_perc = get_node_or_null("/root/PerceptionSystem")
	if _perc != null and _perc.has_signal("percezione_cambiata"):
		_perc.percezione_cambiata.connect(func(_l: Array, _r: Array) -> void: _aggiorna())
	_aggiorna()
	_sagome.draw.connect(_disegna_sagome)


func _process(_delta: float) -> void:
	if _sagome.visible:
		_sagome.queue_redraw()


func _aggiorna() -> void:
	var reveal: Array = _perc.call("reveal_attivi") if _perc != null else []
	_grana.visible = reveal.has("densita_mistica")
	_sagome.visible = reveal.has("spiriti_vicini")


func _disegna_sagome() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var meta := get_viewport().get_visible_rect().size * 0.5
	for n in get_tree().get_nodes_in_group("nemici"):
		if not (n is Node2D):
			continue
		var pos: Vector2 = (n as Node2D).global_position - cam.get_screen_center_position() + meta
		_sagome.draw_circle(pos, 5.0, Color(0.6, 0.7, 1.0, 0.55))
		_sagome.draw_arc(pos, 8.0, 0.0, TAU, 16, Color(0.6, 0.7, 1.0, 0.3), 1.0)
