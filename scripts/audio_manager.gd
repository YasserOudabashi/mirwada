extends Node
## Bus audio e feedback di colpo, dai dati (data/audio.json).
##
## Il feedback di colpo NON e' tre cose separate: sfx, hitstop e shake sono
## lo stesso evento e vanno riprodotti INSIEME. feedback("hit_light") fa
## partire tutti e tre secondo data/audio.json.combat_feedback. hitstop e
## shake NON sono hardcoded negli script di combattimento: quelli chiamano
## solo feedback(nome).
##
## Non posso produrre file audio: gli sfx placeholder sono sintetizzati qui
## (click/burst con frequenza diversa per categoria). Bastano a distinguere
## le voci — parry_perfect suona davvero diverso da parry_normal — e si
## sostituiscono con file veri senza toccare il codice.
##
## NIENTE class_name: coerente col progetto.

signal shake_richiesto(intensita: float)

const BUS_PADRE := {"master": "Master"}
const SR := 22050

## sfx placeholder: nome -> [frequenza_hz, durata_s, rumore 0..1]
const SFX_SPEC := {
	"sfx_hit_light": [320.0, 0.08, 0.35],
	"sfx_hit_heavy": [180.0, 0.14, 0.45],
	"sfx_hit_crit": [140.0, 0.18, 0.55],
	"sfx_parry": [620.0, 0.09, 0.10],
	"sfx_parry_perf": [1040.0, 0.26, 0.0],
	"sfx_posture_break": [90.0, 0.32, 0.6],
	"sfx_dash": [440.0, 0.06, 0.25],
	"sfx_hurt": [240.0, 0.12, 0.30],
	"sfx_death": [70.0, 0.5, 0.20],
}

var _feedback: Dictionary = {}
var _acc: Dictionary = {}
var _sfx_cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i: int = 0
## Fine dell'hitstop in tempo REALE (ms). Non un await su SceneTreeTimer:
## quelli non scorrono nel runner dei test e lasciano time_scale a 0.05.
var _hitstop_fine_ms: int = 0


func _ready() -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd != null:
		_costruisci_bus(gd.call("get_audio", "buses"))
		_feedback = gd.call("get_audio", "combat_feedback")
		_acc = (gd.call("get_audio", "accessibilita") as Dictionary).duplicate(true)

	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "sfx" if AudioServer.get_bus_index("sfx") != -1 else "Master"
		add_child(p)
		_pool.append(p)


# --- API -----------------------------------------------------------------

## Fa partire sfx + hitstop + shake per una voce di combat_feedback.
func feedback(nome: String) -> void:
	var fb: Dictionary = _feedback.get(nome, {})
	if fb.is_empty():
		push_warning("[AudioManager] combat_feedback senza voce '%s'" % nome)
		return

	_suona(str(fb.get("sfx", "")), float(fb.get("pitch_var", 0.0)))

	var ms: float = float(fb.get("hitstop_ms", 0.0))
	if bool(_acc.get("riduci_hitstop", false)):
		ms *= 0.35
	if ms > 0.0:
		_hitstop(ms)

	var sh: float = float(fb.get("shake", 0.0))
	if sh > 0.0 and not bool(_acc.get("disattiva_shake", false)):
		shake_richiesto.emit(sh)


## Opzioni di accessibilita' (riduci_hitstop, disattiva_shake,
## disattiva_sussurri...). Le legge una UI di impostazioni, per ora l'API.
func imposta_accessibilita(chiave: String, valore: Variant) -> void:
	_acc[chiave] = valore


func accessibilita(chiave: String) -> Variant:
	return _acc.get(chiave, null)


func hitstop_in_corso() -> bool:
	return Time.get_ticks_msec() < _hitstop_fine_ms


# --- Interno -----------------------------------------------------------

func _costruisci_bus(buses: Dictionary) -> void:
	for nome in buses:
		if str(nome).begins_with("_") or nome == "master":
			if nome == "master":
				AudioServer.set_bus_volume_db(0, float((buses[nome] as Dictionary).get("volume_db", 0.0)))
			continue
		var idx: int = AudioServer.get_bus_index(nome)
		if idx == -1:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, nome)
		var cfg: Dictionary = buses[nome]
		AudioServer.set_bus_volume_db(idx, float(cfg.get("volume_db", 0.0)))
		var padre: String = str(cfg.get("parent", "master"))
		AudioServer.set_bus_send(idx, BUS_PADRE.get(padre, "Master"))


func _suona(sfx: String, pitch_var: float) -> void:
	if sfx.is_empty():
		return
	var stream: AudioStream = _stream_per(sfx)
	if stream == null:
		return
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func _stream_per(sfx: String) -> AudioStream:
	if _sfx_cache.has(sfx):
		return _sfx_cache[sfx]
	var spec: Array = SFX_SPEC.get(sfx, [300.0, 0.1, 0.3])
	var w: AudioStreamWAV = _sintetizza(spec[0], spec[1], spec[2])
	_sfx_cache[sfx] = w
	return w


## Burst con inviluppo esponenziale: click percussivo, non un tono pulito.
func _sintetizza(freq: float, durata: float, rumore: float) -> AudioStreamWAV:
	var n: int = int(SR * durata)
	var dati := PackedByteArray()
	dati.resize(n * 2)
	for i in n:
		var t: float = float(i) / float(SR)
		var env: float = exp(-t * 16.0)
		var s: float = sin(TAU * freq * t)
		if rumore > 0.0:
			s = lerpf(s, randf() * 2.0 - 1.0, rumore)
		dati.encode_s16(i * 2, int(clampf(s * env, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = dati
	return w


func _process(_delta: float) -> void:
	if _hitstop_fine_ms > 0 and Time.get_ticks_msec() >= _hitstop_fine_ms:
		_hitstop_fine_ms = 0
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	# rilascia gli AudioStreamWAV sintetizzati prima che il sottosistema
	# risorse chiuda: evita il "resources still in use at exit".
	for p in _pool:
		p.stream = null
	_sfx_cache.clear()


## Congela il tempo di gioco per ms REALI (time_scale basso). Piu' colpi
## ravvicinati estendono la finestra invece di sovrapporsi.
func _hitstop(ms: float) -> void:
	_hitstop_fine_ms = maxi(_hitstop_fine_ms, Time.get_ticks_msec() + int(ms))
	Engine.time_scale = 0.05
