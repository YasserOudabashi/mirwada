extends CanvasLayer
## Overlay visivo della follia (US-215). Vive FUORI dal libro. Le soglie
## vengono da data/balance.json.madness, i parametri da .madness_vfx: nessun
## numero in questo script.
##
##   soglia_distorsioni (15) -> vignetta d'inchiostro che respira ai bordi
##   soglia_abilita_autonome (40) -> scatti di distorsione a schermo
##   soglia_perdita_input (70) -> il nero di scena si attiva da solo
##
## FR-8: con riduci_flash la versione ridotta e' STATICA (vignetta fissa,
## nero a bassa opacita' costante) ma MAI assente: la follia resta leggibile
## anche senza lampeggii. Nessuna informazione vive solo qui: e' lo specchio
## visivo del layer audio (US-214), guidato dallo stesso valore di follia.
##
## NIENTE class_name: coerente col progetto.

@onready var _vignetta: ColorRect = $Vignetta
@onready var _distorsione: ColorRect = $Distorsione
@onready var _nero: ColorRect = $Nero

var _soglie: Dictionary = {}
var _vfx: Dictionary = {}
var _follia: float = 0.0
var _t: float = 0.0
var _distorsione_left: float = 0.0
var _nero_left: float = 0.0


func _ready() -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd != null:
		_soglie = gd.call("get_balance", "madness")
		_vfx = gd.call("get_balance", "madness_vfx")
	var follia: Node = get_node_or_null("/root/Madness")
	if follia != null and follia.has_signal("madness_changed"):
		follia.madness_changed.connect(func(v: float, _s: int) -> void: _follia = v)
		_follia = follia.call("valore")
	_ripianifica_distorsione()
	_ripianifica_nero()
	_aggiorna(0.0)


var _prossima_distorsione: float = 0.0
var _prossimo_nero: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	_distorsione_left = maxf(0.0, _distorsione_left - delta)
	_nero_left = maxf(0.0, _nero_left - delta)

	# scatti di distorsione: soglia 40, disattivati da riduci_distorsione
	if _follia >= _soglia("soglia_abilita_autonome") and not _flag_ridotto("riduci_distorsione"):
		if _t >= _prossima_distorsione:
			_distorsione_left = _num("distorsione_durata_s")
			_ripianifica_distorsione()

	# nero di scena che si attiva da solo: soglia 70, disattivato da riduci_flash
	if _follia >= _soglia("soglia_perdita_input") and not _flag_ridotto("riduci_flash"):
		if _t >= _prossimo_nero:
			_nero_left = _num("nero_durata_s")
			_ripianifica_nero()

	_aggiorna(delta)


func _ripianifica_distorsione() -> void:
	var iv: Array = _vfx.get("distorsione_intervallo_s", [3.0, 9.0])
	_prossima_distorsione = _t + randf_range(float(iv[0]), float(iv[1]))


func _ripianifica_nero() -> void:
	var iv: Array = _vfx.get("nero_intervallo_s", [7.0, 18.0])
	_prossimo_nero = _t + randf_range(float(iv[0]), float(iv[1]))


func _aggiorna(_delta: float) -> void:
	# --- vignetta ---
	var intensita: float = 0.0
	if _follia >= _soglia("soglia_distorsioni"):
		var s0: float = _soglia("soglia_distorsioni")
		var frazione: float = clampf((_follia - s0) / maxf(1.0, 100.0 - s0), 0.0, 1.0)
		intensita = _num("vignetta_alpha_max") * lerpf(0.35, 1.0, frazione)
		if not _flag_ridotto("riduci_flash"):
			intensita += sin(_t * TAU * _num("respiro_al_secondo")) * _num("respiro_ampiezza") * intensita
	if _vignetta.material is ShaderMaterial:
		(_vignetta.material as ShaderMaterial).set_shader_parameter("intensita", maxf(0.0, intensita))

	# --- distorsione ---
	_distorsione.color.a = 0.0 if _distorsione_left <= 0.0 else 0.25

	# --- nero di scena ---
	var nero_a: float = 0.0
	if _follia >= _soglia("soglia_perdita_input"):
		if _flag_ridotto("riduci_flash"):
			nero_a = _num("nero_alpha_statico")   # statico, mai assente
		elif _nero_left > 0.0:
			nero_a = _num("nero_alpha")
	_nero.color.a = nero_a


# --- Interrogabile dai test ---------------------------------------------

func intensita_vignetta() -> float:
	if _vignetta.material is ShaderMaterial:
		return float((_vignetta.material as ShaderMaterial).get_shader_parameter("intensita"))
	return 0.0


func alpha_nero() -> float:
	return _nero.color.a


func forza_scatto_nero() -> void:
	_nero_left = _num("nero_durata_s")


func forza_scatto_distorsione() -> void:
	_distorsione_left = _num("distorsione_durata_s")


# --- Interno ----------------------------------------------------------

func _soglia(nome: String) -> float:
	var v: Variant = _soglie.get(nome, 999.0)
	return v if typeof(v) in [TYPE_FLOAT, TYPE_INT] else 999.0


func _num(nome: String) -> float:
	var v: Variant = _vfx.get(nome, 0.0)
	return v if typeof(v) in [TYPE_FLOAT, TYPE_INT] else 0.0


func _flag_ridotto(chiave: String) -> bool:
	var am: Node = get_node_or_null("/root/AudioManager")
	return bool(am.call("accessibilita", chiave)) if am != null else false
