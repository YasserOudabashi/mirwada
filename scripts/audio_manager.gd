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
## Tell sonoro di un attacco nemico partito. posizione_mondo e categoria
## servono all'indicatore visivo (US-020): chi non sente l'audio deve avere
## lo stesso dato (che minaccia, da dove).
signal tell_emesso(posizione_mondo: Vector2, categoria: String)

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
	# Tell degli attacchi nemici (US-020). Le 5 categorie devono suonare
	# nettamente diverse: freq, durata e rumore tutti distinti.
	"sfx_tell_light": [880.0, 0.10, 0.15],
	"sfx_tell_heavy": [150.0, 0.35, 0.25],
	"sfx_tell_unblock": [330.0, 0.30, 0.85],
	"sfx_tell_ranged": [560.0, 0.22, 0.05],
	"sfx_tell_ritual": [110.0, 0.80, 0.10],
	# One-shot casuali della follia (US-214): suoni senza causa visibile.
	"sfx_whisper_name": [430.0, 0.5, 0.4],
	"sfx_step_behind": [90.0, 0.18, 0.6],
	"sfx_door_close": [120.0, 0.3, 0.35],
	"sfx_breath": [200.0, 0.6, 0.7],
	# Wash dei sussurri per soglia di follia (loop sintetizzati).
	"amb_whisper_faint": [70.0, 1.2, 0.85],
	"amb_whisper_words": [90.0, 1.2, 0.8],
	"amb_whisper_names": [110.0, 1.4, 0.75],
	"amb_whisper_chorus": [140.0, 1.6, 0.7],
	# Layer ambientali della percezione per Sequenza (US-218), sintetizzati.
	"amb_spirit_faint": [180.0, 1.5, 0.5],
	"amb_ley_hum": [55.0, 2.0, 0.2],
	"amb_outer_drone": [40.0, 2.4, 0.15],
	"amb_beyond": [28.0, 3.0, 0.3],
}

var _feedback: Dictionary = {}
var _telegraph: Dictionary = {}
var _acc: Dictionary = {}
var _sfx_cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i: int = 0
## Fine dell'hitstop in tempo REALE (ms). Non un await su SceneTreeTimer:
## quelli non scorrono nel runner dei test e lasciano time_scale a 0.05.
var _hitstop_fine_ms: int = 0

## --- Layer audio della follia (US-214) ---
var _madness_layer: Dictionary = {}
var _whisper: AudioStreamPlayer = null
var _music_db_base: float = 0.0
var _music_ducked: bool = false
var _one_shot_left: float = 0.0
var _follia_corrente: float = 0.0
## Nomi che i sussurri di soglia 55 pronunciano (NPC incontrati, Ancore).
## Li popola AnchorSystem / il sistema NPC; se vuoto si usa un set generico.
var _nomi_sussurro: Array = []
const _NOMI_GENERICI := ["...", "torna", "sei qui", "non e' reale"]


func _ready() -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd != null:
		_costruisci_bus(gd.call("get_audio", "buses"))
		_feedback = gd.call("get_audio", "combat_feedback")
		_telegraph = gd.call("get_audio", "telegraph")
		_acc = (gd.call("get_audio", "accessibilita") as Dictionary).duplicate(true)
		_madness_layer = gd.call("get_audio", "madness_layer")

	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "sfx" if AudioServer.get_bus_index("sfx") != -1 else "Master"
		add_child(p)
		_pool.append(p)

	_whisper = AudioStreamPlayer.new()
	_whisper.bus = "whisper" if AudioServer.get_bus_index("whisper") != -1 else "Master"
	add_child(_whisper)
	var mi: int = AudioServer.get_bus_index("music")
	if mi != -1:
		_music_db_base = AudioServer.get_bus_volume_db(mi)

	var follia: Node = get_node_or_null("/root/Madness")
	if follia != null and follia.has_signal("madness_changed"):
		follia.madness_changed.connect(func(v: float, _s: int) -> void: aggiorna_follia(v))
	_ripianifica_one_shot()


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


## Tell sonoro di un attacco nemico, da data/audio.json.telegraph[id]. Suona
## SEMPRE, che il nemico sia inquadrato o no: e' cosi' che il giocatore reagisce
## a una minaccia fuori schermo (requisito di leggibilita', non atmosfera, non
## silenziabile dalle opzioni audio). Restituisce la durata in secondi della
## fase di anticipo: e' il tell a fissarla, non l'animazione.
func tell(id: String, posizione_mondo: Vector2) -> float:
	var t: Dictionary = _telegraph.get(id, {})
	if t.is_empty():
		push_warning("[AudioManager] telegraph senza voce '%s'" % id)
		return 0.0
	_suona(str(t.get("sfx", "")), 0.05)
	tell_emesso.emit(posizione_mondo, str(t.get("categoria", "")))
	return float(t.get("anticipo_ms", 0.0)) / 1000.0


## Opzioni di accessibilita' (riduci_hitstop, disattiva_shake,
## disattiva_sussurri...). Le legge una UI di impostazioni, per ora l'API.
func imposta_accessibilita(chiave: String, valore: Variant) -> void:
	_acc[chiave] = valore
	if chiave == "disattiva_sussurri":
		aggiorna_follia(_follia_corrente)


func accessibilita(chiave: String) -> Variant:
	return _acc.get(chiave, null)


func hitstop_in_corso() -> bool:
	return Time.get_ticks_msec() < _hitstop_fine_ms


# --- Layer audio della follia (US-214) --------------------------------------

## Guida il bus "whisper" e il duck della musica dal valore di follia. La
## MECCANICA non passa da qui: disattiva_sussurri silenzia solo l'audio.
func aggiorna_follia(valore: float) -> void:
	_follia_corrente = valore
	var wi: int = AudioServer.get_bus_index("whisper")
	if wi == -1:
		return

	var soglia: Dictionary = _soglia_follia_attiva(valore)
	var silenzia: bool = bool(_acc.get("disattiva_sussurri", false))
	AudioServer.set_bus_mute(wi, silenzia or soglia.is_empty())

	if not soglia.is_empty():
		AudioServer.set_bus_volume_db(wi, float(soglia.get("volume_db", -24.0)))
		if _whisper != null:
			_whisper.pitch_scale = 1.0 + float(soglia.get("detune", 0.0))
			var loop_sfx: String = str(soglia.get("loop", "amb_whisper_faint"))
			if not _whisper.playing or _whisper.get_meta("loop", "") != loop_sfx:
				_whisper.stream = _stream_per(loop_sfx)
				_whisper.set_meta("loop", loop_sfx)
				_whisper.play()
	elif _whisper != null:
		_whisper.stop()

	# Duck della musica alla soglia che lo dichiara (80).
	var duck: float = float(soglia.get("duck_music_db", 0.0)) if not soglia.is_empty() else 0.0
	_applica_duck(duck)


func imposta_nomi_sussurro(nomi: Array) -> void:
	_nomi_sussurro = nomi.duplicate()


## Taglio secco al silenzio (US-217): un rituale interrotto muta music,
## ambience e whisper per durata_s, poi li ripristina. Il silenzio
## improvviso e' il momento piu' spaventoso che il gioco produce.
var _silenzio_fino_ms: int = 0
var _bus_mutati: PackedStringArray = []


func silenzio_secco(durata_s: float) -> void:
	_silenzio_fino_ms = Time.get_ticks_msec() + int(maxf(0.0, durata_s) * 1000.0)
	_bus_mutati = PackedStringArray()
	for nome in ["music", "ambience", "whisper"]:
		var i: int = AudioServer.get_bus_index(nome)
		if i != -1 and not AudioServer.is_bus_mute(i):
			AudioServer.set_bus_mute(i, true)
			_bus_mutati.append(nome)


func silenzio_secco_attivo() -> bool:
	return Time.get_ticks_msec() < _silenzio_fino_ms


## Layer ambientali della percezione per Sequenza (US-218): un AudioStreamPlayer
## per layer sul bus ambience, acceso/spento in base alla lista corrente.
var _amb_players: Dictionary = {}


func imposta_layers_ambientali(layers: Array) -> void:
	for nome in _amb_players.keys():
		if not layers.has(nome):
			(_amb_players[nome] as AudioStreamPlayer).stop()
	for nome in layers:
		var p: AudioStreamPlayer = _amb_players.get(nome)
		if p == null:
			p = AudioStreamPlayer.new()
			p.bus = "ambience" if AudioServer.get_bus_index("ambience") != -1 else "Master"
			p.stream = _stream_per(str(nome))
			add_child(p)
			_amb_players[nome] = p
		if not p.playing:
			p.play()


func layers_ambientali_attivi() -> Array:
	var out: Array = []
	for nome in _amb_players:
		if (_amb_players[nome] as AudioStreamPlayer).playing:
			out.append(nome)
	return out


func nomi_sussurro() -> Array:
	return _nomi_sussurro if not _nomi_sussurro.is_empty() else _NOMI_GENERICI


## Un one-shot casuale della follia. Pubblico per i test.
func tenta_one_shot() -> bool:
	var spec: Dictionary = _madness_layer.get("one_shot_casuali", {})
	if _follia_corrente < float(spec.get("madness_min", 25.0)):
		return false
	if bool(_acc.get("disattiva_sussurri", false)):
		return false
	var lista: Array = spec.get("sfx", [])
	if lista.is_empty():
		return false
	_suona(str(lista[randi() % lista.size()]), 0.1)
	return true


func _soglia_follia_attiva(valore: float) -> Dictionary:
	var scelta: Dictionary = {}
	for s in _madness_layer.get("soglie", []):
		if typeof(s) == TYPE_DICTIONARY and valore >= float((s as Dictionary).get("madness_min", 999.0)):
			scelta = s
	return scelta


func _applica_duck(duck_db: float) -> void:
	var mi: int = AudioServer.get_bus_index("music")
	if mi == -1:
		return
	var vuole_duck: bool = duck_db < 0.0
	if vuole_duck and not _music_ducked:
		AudioServer.set_bus_volume_db(mi, _music_db_base + duck_db)
		_music_ducked = true
	elif not vuole_duck and _music_ducked:
		AudioServer.set_bus_volume_db(mi, _music_db_base)
		_music_ducked = false


func _ripianifica_one_shot() -> void:
	var spec: Dictionary = _madness_layer.get("one_shot_casuali", {})
	var iv: Array = spec.get("intervallo_secondi", [45, 180])
	var lo: float = float(iv[0]) if iv.size() > 0 else 45.0
	var hi: float = float(iv[1]) if iv.size() > 1 else 180.0
	_one_shot_left = randf_range(lo, hi)


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


func _process(delta: float) -> void:
	if _hitstop_fine_ms > 0 and Time.get_ticks_msec() >= _hitstop_fine_ms:
		_hitstop_fine_ms = 0
		Engine.time_scale = 1.0

	# Fine del silenzio secco (US-217): ripristina i bus mutati.
	if _silenzio_fino_ms > 0 and Time.get_ticks_msec() >= _silenzio_fino_ms:
		_silenzio_fino_ms = 0
		for nome in _bus_mutati:
			var i: int = AudioServer.get_bus_index(nome)
			if i != -1:
				AudioServer.set_bus_mute(i, false)
		_bus_mutati = PackedStringArray()
		aggiorna_follia(_follia_corrente)  # ri-sincronizza il whisper con la follia

	# One-shot casuali della follia (US-214).
	if _follia_corrente >= float((_madness_layer.get("one_shot_casuali", {}) as Dictionary).get("madness_min", 25.0)):
		_one_shot_left -= delta
		if _one_shot_left <= 0.0:
			tenta_one_shot()
			_ripianifica_one_shot()


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
