extends Node
## Ciclo del tempo di gioco (US-604): il momento del giorno e la fase lunare.
## Due assi separati (data/schema/time.json): il momento avanza in fretta
## (alba -> mezzogiorno -> crepuscolo -> notte_fonda), la fase lunare su un
## ciclo lungo (nuova -> crescente -> piena -> calante). L'eclissi NON e' una
## tappa del ciclo: e' un evento raro schedulato (o forzato da un rituale di
## Sequenza alta) che per la sua durata mette fase_lunare() a "eclissi".
##
## Il ciclo si ferma quando il mondo e' in pausa: il libro fa gia'
## get_tree().paused (scripts/book.gd) e _process non gira; il motore dialoghi
## (US-613) chiamera' imposta_pausa(true). Le condizioni e_notte/fase_lunare
## delle abilita' (US-605) leggono da qui.
##
## NIENTE class_name: coerente col resto del progetto.

signal momento_cambiato(momento: String)
signal fase_lunare_cambiata(fase: String)
signal eclissi_iniziata()
signal eclissi_finita()

## Difesi se time.json e' irraggiungibile al boot.
const MOMENTI_FALLBACK := ["alba", "mezzogiorno", "crepuscolo", "notte_fonda"]
const FASI_FALLBACK := ["nuova", "crescente", "piena", "calante"]
const NOTTE := ["crepuscolo", "notte_fonda"]

var _tick: float = 0.0
var _pausa: bool = false
var _eclissi_fino: float = -1.0
var _prossima_eclissi_ciclo: int = 0

var _momento_corrente: String = "alba"
var _fase_corrente: String = "nuova"
## US-711: momento bloccato da una tribolazione (notte_perenne) o da un
## rituale. "" = il ciclo procede normale. Finche' e' impostato, _ricalcola
## non tocca _momento_corrente.
var _momento_forzato: String = ""
## US-607: zone di oscurita' create da terrain_modify tipo_modifica "oscurita"
## (il Nightwatcher del Darkness). { c: Vector2, r: float, fino: float(tick) }.
## e_notte(posizione) le legge come notte LOCALE. Transitorie, non nel save.
var _oscurita: Array = []


func _ready() -> void:
	_prossima_eclissi_ciclo = int(_cfg("cicli_lunari_per_eclissi", 8))
	_ricalcola(true)
	# Il libro ferma il mondo (design-ui-libro): oltre a get_tree().paused,
	# lo diciamo esplicitamente a TimeSystem (AC US-604). Book e' un autoload
	# piu' in basso: la connessione va differita a quando esiste. Il motore
	# dialoghi (US-613) fara' lo stesso con imposta_pausa().
	_connetti_book.call_deferred()


func _connetti_book() -> void:
	var book: Node = get_node_or_null("/root/Book")
	if book == null:
		return
	if book.has_signal("libro_aperto"):
		book.libro_aperto.connect(func(_p): imposta_pausa(true))
	if book.has_signal("libro_chiuso"):
		book.libro_chiuso.connect(func(): imposta_pausa(false))


func _process(delta: float) -> void:
	if not _pausa:
		avanza(delta)


# --- Configurazione (data/balance.json sezione "tempo") -------------------

func _cfg(chiave: String, fallback: float) -> float:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return fallback
	var t: Dictionary = gd.call("get_balance", "tempo")
	var v: Variant = t.get(chiave)
	return float(v) if typeof(v) in [TYPE_FLOAT, TYPE_INT] else fallback


func _momenti() -> Array:
	var doc: Array = _time_doc().get("momenti", [])
	return doc if not doc.is_empty() else MOMENTI_FALLBACK.duplicate()


func _time_doc() -> Dictionary:
	# time.json e' uno schema, non passa da GameData: lettura diretta.
	if not FileAccess.file_exists("res://data/schema/time.json"):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/schema/time.json"))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _fasi() -> Array:
	var td: Dictionary = _time_doc()
	var f: Array = td.get("fasi_lunari", [])
	# "eclissi" e' un evento, non una tappa: fuori dal ciclo regolare.
	f = f.filter(func(x): return x != "eclissi")
	return f if not f.is_empty() else FASI_FALLBACK.duplicate()


# --- Avanzamento --------------------------------------------------------

## Pubblica di proposito: i test la chiamano con un delta scelto invece di
## aspettare secondi veri (come AbilityEngine.tick_effects).
func avanza(delta: float) -> void:
	if delta <= 0.0:
		return
	_tick += delta
	if not _oscurita.is_empty():
		_oscurita = _oscurita.filter(func(z): return _tick < float(z["fino"]))

	# time_in_state { stato: notte }: EventTracker lo somma (misura "secondi").
	# Darkness ci recita (darkness_4 "dominio della notte").
	if e_notte():
		var et: Node = get_node_or_null("/root/EventTracker")
		if et != null:
			et.call("emit_event", "time_in_state", {"stato": "notte", "quantita": delta})

	# eclissi in corso -> finisce a scadenza
	if _eclissi_fino >= 0.0 and _tick >= _eclissi_fino:
		_eclissi_fino = -1.0
		eclissi_finita.emit()

	_ricalcola(false)

	# eclissi schedulata: ogni N cicli lunari completi
	var ciclo: int = _ciclo_lunare()
	if _eclissi_fino < 0.0 and ciclo >= _prossima_eclissi_ciclo:
		_prossima_eclissi_ciclo = ciclo + int(_cfg("cicli_lunari_per_eclissi", 8))
		forza_eclissi()


func _ricalcola(silenzioso: bool) -> void:
	var momenti: Array = _momenti()
	var fasi: Array = _fasi()
	var spm: float = maxf(_cfg("secondi_per_momento", 120.0), 0.001)
	var mpg: int = maxi(int(_cfg("momenti_per_giorno", momenti.size())), 1)
	var gpf: int = maxi(int(_cfg("giorni_per_fase_lunare", 3)), 1)

	var m_idx: int = int(_tick / spm) % momenti.size()
	var giorno: int = int(_tick / (spm * mpg))
	var f_idx: int = int(giorno / gpf) % fasi.size()

	var nuovo_momento: String = str(momenti[m_idx])
	var nuova_fase: String = str(fasi[f_idx])
	if _momento_forzato.is_empty() and nuovo_momento != _momento_corrente:
		_momento_corrente = nuovo_momento
		if not silenzioso:
			momento_cambiato.emit(_momento_corrente)
	if nuova_fase != _fase_corrente:
		_fase_corrente = nuova_fase
		if not silenzioso:
			fase_lunare_cambiata.emit(_fase_corrente)


func _ciclo_lunare() -> int:
	var spm: float = maxf(_cfg("secondi_per_momento", 120.0), 0.001)
	var mpg: int = maxi(int(_cfg("momenti_per_giorno", 4)), 1)
	var gpf: int = maxi(int(_cfg("giorni_per_fase_lunare", 3)), 1)
	var fasi: int = maxi(_fasi().size(), 1)
	var giorno: int = int(_tick / (spm * mpg))
	return int(giorno / (gpf * fasi))


# --- Lettura -----------------------------------------------------------

func momento() -> String:
	return _momento_corrente


## US-711: blocca il momento del giorno (tribolazione notte_perenne). Il ciclo
## lunare e il tick continuano; solo il momento resta fermo finche' non si
## chiama libera_momento().
func forza_momento(m: String) -> void:
	_momento_forzato = str(m)
	if not _momento_forzato.is_empty() and _momento_forzato != _momento_corrente:
		_momento_corrente = _momento_forzato
		momento_cambiato.emit(_momento_corrente)


func libera_momento() -> void:
	_momento_forzato = ""
	_ricalcola(false)


func momento_forzato() -> bool:
	return not _momento_forzato.is_empty()


## "eclissi" mentre un'eclissi e' in corso, altrimenti la fase del ciclo.
func fase_lunare() -> String:
	return "eclissi" if _eclissi_fino >= 0.0 else _fase_corrente


## Senza argomento: la notte del ciclo. Con una posizione: anche una zona di
## oscurita' attiva che la contiene (US-607, gancio per combat/mondo di fase 6).
func e_notte(posizione: Variant = null) -> bool:
	if _momento_corrente in NOTTE:
		return true
	if typeof(posizione) == TYPE_VECTOR2:
		for z in _oscurita:
			if _tick < float(z["fino"]) and (posizione as Vector2).distance_to(z["c"]) <= float(z["r"]):
				return true
	return false


## Crea una zona di oscurita' che vale come notte locale per 'durata' secondi
## di gioco. La chiama _p_terrain_modify quando tipo_modifica == "oscurita".
func crea_oscurita(centro: Vector2, raggio: float, durata: float) -> void:
	_oscurita.append({"c": centro, "r": maxf(raggio, 1.0), "fino": _tick + maxf(durata, 0.1)})


func in_eclissi() -> bool:
	return _eclissi_fino >= 0.0


func imposta_pausa(valore: bool) -> void:
	_pausa = valore


## Forza un'eclissi ora (evento schedulato, o un rituale di Sequenza alta).
func forza_eclissi() -> void:
	if _eclissi_fino >= 0.0:
		return
	_eclissi_fino = _tick + maxf(_cfg("durata_eclissi_s", 90.0), 1.0)
	eclissi_iniziata.emit()


# --- Salvataggio (dentro mondo.tempo, US-604; nessun bump: US-602 e' l'unico) ---

func per_salvataggio() -> Dictionary:
	return {"tick": _tick, "momento": _momento_corrente, "fase_lunare": _fase_corrente}


func da_salvataggio(raw: Variant) -> void:
	var d: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	_tick = float(d["tick"]) if typeof(d.get("tick")) in [TYPE_FLOAT, TYPE_INT] else 0.0
	_oscurita.clear()
	_eclissi_fino = -1.0
	_prossima_eclissi_ciclo = _ciclo_lunare() + int(_cfg("cicli_lunari_per_eclissi", 8))
	_ricalcola(true)
