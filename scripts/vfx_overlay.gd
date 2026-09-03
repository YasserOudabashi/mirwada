extends CanvasLayer
## Overlay dei VFX di combattimento (US-227), FUORI dal libro, sotto la follia.
##   * impact frame: sui colpi che contano, un lampo a inversione bianco/nero
##     per durata_frames (data/vfx.json.impact_frames), legato a
##     combat_feedback.hitstop_ms. Con riduci_flash -> un bordo spesso, stessa
##     informazione senza il lampo (fotosensibilita').
##   * nero di scena: lo sfondo si mangia di nero nei momenti forti
##     (parry_perfect, posture_break, abilita' di Sequenza <= 4) per durata_ms.
##
## Contatori in _process (come madness_overlay), non Tween. NIENTE class_name.

@onready var _impatto: Control = $Impatto
@onready var _nero: ColorRect = $Nero

var _impatto_left: float = 0.0
var _impatto_durata: float = 0.033
var _nero_left: float = 0.0


func _ready() -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd != null:
		var imf: Dictionary = gd.call("get_vfx", "impact_frames")
		# durata_frames a 60 fps; si tara con hitstop_ms (design-vfx cap. 4)
		_impatto_durata = float(imf.get("durata_frames", 2)) / 60.0
	_impatto.draw.connect(_disegna_impatto)
	_impatto.hide()
	_nero.color.a = 0.0


func _process(delta: float) -> void:
	if _impatto_left > 0.0:
		_impatto_left = maxf(0.0, _impatto_left - delta)
		_impatto.visible = _impatto_left > 0.0
		_impatto.queue_redraw()
	if _nero_left > 0.0:
		_nero_left = maxf(0.0, _nero_left - delta)
		_nero.color.a = 0.85 if _nero_left > 0.0 else 0.0


# --- API -------------------------------------------------------------------

func impatto() -> void:
	_impatto_left = _impatto_durata


func nero(durata_ms: float) -> void:
	_nero_left = maxf(_nero_left, durata_ms / 1000.0)
	if _nero_left > 0.0:
		_nero.color.a = 0.85


# --- Interrogabile dai test ---------------------------------------------

func impatto_attivo() -> bool:
	return _impatto_left > 0.0


func alpha_nero() -> float:
	return _nero.color.a


# --- Interno ----------------------------------------------------------

func _disegna_impatto() -> void:
	var r := Rect2(Vector2.ZERO, _impatto.size)
	if _flash_ridotto():
		# bordo spesso: stessa informazione (un colpo importante), niente lampo
		_impatto.draw_rect(r, Color.WHITE, false, 18.0)
	else:
		_impatto.draw_rect(r, Color(1, 1, 1, 0.9))


func _flash_ridotto() -> bool:
	var am: Node = get_node_or_null("/root/AudioManager")
	return bool(am.call("accessibilita", "riduci_flash")) if am != null else false
