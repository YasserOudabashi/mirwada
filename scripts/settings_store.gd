extends Node
## Impostazioni del giocatore (US-225), colophon del libro.
##
## Scritte in user://settings.json con lo STESSO rigore del save
## (design-ui-libro.md cap. 2): scrittura atomica (tmp + rename), typeof() su
## ogni campo al load, un file corrotto NON e' fatale (si riparte dai default
## dei dati). Le opzioni si applicano a runtime, senza riavvio.
##
## Sezioni:
##   audio  -> volume_<bus> (float dB), piu' i toggle di accessibilita' di
##             data/audio.json.accessibilita
##   video  -> scala_finestra (1/2/3), fullscreen (bool), + toggle vfx
##   input  -> <azione> -> physical_keycode (int) che sostituisce il primo
##             evento tastiera dell'azione
##   lingua -> "it" | "en"
##
## AudioManager e i sistemi VFX NON leggono i default: leggono i valori
## spinti qui dentro (_applica_tutto all'avvio, e set_val a ogni modifica).
##
## NIENTE class_name: coerente col resto del progetto.

signal cambiata(sezione: String, chiave: String, valore: Variant)

const PATH := "user://settings.json"
const AZIONI := ["move_up", "move_down", "move_left", "move_right",
	"attacco", "schivata", "parata",
	"abilita_1", "abilita_2", "abilita_3", "abilita_4", "interagisci",
	"libro", "pagina_avanti", "pagina_indietro"]

var _dati: Dictionary = {}


func _ready() -> void:
	_carica()
	# un frame: gli autoload esistono ma la finestra si assesta dopo
	await get_tree().process_frame
	_applica_tutto()


# --- API -----------------------------------------------------------------

func azioni() -> Array:
	return AZIONI.duplicate()


func get_val(sezione: String, chiave: String, default: Variant) -> Variant:
	var s: Dictionary = _dati.get(sezione, {})
	if typeof(s) != TYPE_DICTIONARY or not s.has(chiave):
		return default
	var v: Variant = s[chiave]
	# tipo coerente col default: un settings.json manomesso non deve passare
	# una stringa dove il codice si aspetta un numero.
	if default != null and typeof(v) != typeof(default):
		if typeof(default) == TYPE_FLOAT and typeof(v) == TYPE_INT:
			return float(v)
		if typeof(default) == TYPE_INT and typeof(v) == TYPE_FLOAT:
			return int(v)
		return default
	return v


func set_val(sezione: String, chiave: String, valore: Variant) -> void:
	if not _dati.has(sezione) or typeof(_dati[sezione]) != TYPE_DICTIONARY:
		_dati[sezione] = {}
	_dati[sezione][chiave] = valore
	_applica(sezione, chiave, valore)
	_salva()
	cambiata.emit(sezione, chiave, valore)


func sezione(nome: String) -> Dictionary:
	var s: Variant = _dati.get(nome, {})
	return s.duplicate() if typeof(s) == TYPE_DICTIONARY else {}


func azzera() -> void:
	_dati.clear()
	_salva()
	_applica_tutto()


# --- Applicazione a runtime --------------------------------------------

func _applica_tutto() -> void:
	# lingua
	var loc: String = str(get_val("lingua", "locale", TranslationServer.get_locale()))
	TranslationServer.set_locale(loc)
	# audio: volumi dei bus
	var am: Node = _n("/root/AudioManager")
	for bus_nome in ["master", "music", "sfx", "ambience", "ui", "whisper"]:
		var idx: int = AudioServer.get_bus_index(bus_nome)
		if idx != -1 and _ha("audio", "volume_" + bus_nome):
			AudioServer.set_bus_volume_db(idx, float(get_val("audio", "volume_" + bus_nome, 0.0)))
	# audio: toggle di accessibilita'
	if am != null:
		for chiave in _acc_chiavi():
			if _ha("audio", chiave):
				am.call("imposta_accessibilita", chiave, bool(get_val("audio", chiave, false)))
	# video
	_applica_video()
	# input
	for azione in AZIONI:
		if _ha("input", azione):
			_rimappa(azione, int(get_val("input", azione, 0)))


func _applica(sezione: String, chiave: String, valore: Variant) -> void:
	match sezione:
		"lingua":
			TranslationServer.set_locale(str(valore))
		"audio":
			if chiave.begins_with("volume_"):
				var idx: int = AudioServer.get_bus_index(chiave.trim_prefix("volume_"))
				if idx != -1:
					AudioServer.set_bus_volume_db(idx, float(valore))
			else:
				var am: Node = _n("/root/AudioManager")
				if am != null:
					am.call("imposta_accessibilita", chiave, bool(valore))
		"video":
			_applica_video()
		"input":
			_rimappa(chiave, int(valore))


func _applica_video() -> void:
	var scala: int = int(get_val("video", "scala_finestra", 2))
	var full: bool = bool(get_val("video", "fullscreen", false))
	if full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(640 * scala, 360 * scala))
	# i toggle vfx passano dallo stesso canale accessibilita' di AudioManager
	var am: Node = _n("/root/AudioManager")
	if am != null:
		for chiave in ["disattiva_shake", "riduci_hitstop", "riduci_flash",
				"riduci_distorsione", "riduci_animazioni"]:
			if _ha("video", chiave):
				am.call("imposta_accessibilita", chiave, bool(get_val("video", chiave, false)))


func _rimappa(azione: String, physical_keycode: int) -> void:
	if not InputMap.has_action(azione) or physical_keycode == 0:
		return
	# sostituisce il PRIMO evento tastiera, lascia gli altri (mouse, joypad)
	for ev in InputMap.action_get_events(azione):
		if ev is InputEventKey:
			InputMap.action_erase_event(azione, ev)
			break
	var nuovo := InputEventKey.new()
	nuovo.physical_keycode = physical_keycode
	InputMap.action_add_event(azione, nuovo)


# --- Persistenza (atomica, non fidata) --------------------------------

func _carica() -> void:
	_dati = {}
	if not FileAccess.file_exists(PATH):
		return
	var testo: String = FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(testo)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[SettingsStore] settings.json corrotto: si riparte dai default")
		return
	for k in parsed:
		if typeof(parsed[k]) == TYPE_DICTIONARY:
			_dati[k] = parsed[k]


func _salva() -> void:
	var tmp: String = PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("[SettingsStore] impossibile scrivere %s" % tmp)
		return
	f.store_string(JSON.stringify(_dati, "  "))
	f.close()
	var d := DirAccess.open("user://")
	if d != null:
		d.rename(tmp, PATH)


# --- Interno ----------------------------------------------------------

func _ha(sezione: String, chiave: String) -> bool:
	var s: Variant = _dati.get(sezione, {})
	return typeof(s) == TYPE_DICTIONARY and (s as Dictionary).has(chiave)


func _acc_chiavi() -> Array:
	var gd: Node = _n("/root/GameData")
	if gd == null:
		return []
	var acc: Dictionary = gd.call("get_audio", "accessibilita")
	return acc.keys().filter(func(k: String) -> bool: return not k.begins_with("_"))


func _n(path: String) -> Node:
	return get_node_or_null(path)
