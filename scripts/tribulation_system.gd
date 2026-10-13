extends Node
## TribulationSystem (fase 7, US-711). La prova ai salti di FASCIA: le
## Sequenze 7->6, 5->4, 3->2, 1->0. E' un LETTORE di eventi + flag, non ha
## verbi propri:
##   - quando il personaggio arriva a una Sequenza di salto, attiva la prova
##     (applica 'mentre_in_corso' come handicap);
##   - Progression.avanza e' RIFIUTATO finche' 'superamento' non e' raggiunto
##     (un contatore su uno dei 12 tracked_events, o un flag di KnowledgeStore);
##   - al superamento toglie l'handicap e registra endgame.tribolazioni_superate.
##
## I dati stanno in data/tribulations/ (US-710). Nessun `if` per un id qui:
## ogni tribolazione dichiara salto/condizioni/effetto/superamento.
##
## NIENTE class_name: coerente col resto del progetto.

signal tribolazione_attivata(da: int)
signal tribolazione_superata(da: int)
signal progresso_cambiato(da: int, progresso: float)

const _SALTI := [7, 5, 3, 1]
const _MOD_SPIRITUALITA := "tribolazione:spiritualita_dimezzata"

## Il "da" della tribolazione con l'handicap attivo adesso. -1 = nessuna.
var _attiva_da: int = -1
var _progresso: float = 0.0
## Accumulatore per follia_accelerata (delta al minuto -> al secondo).
var _follia_acc: float = 0.0


func _ready() -> void:
	var prog: Node = _n("/root/Progression")
	if prog != null:
		prog.connect("sequence_changed", _on_sequence_changed)
	var et: Node = _n("/root/EventTracker")
	if et != null:
		et.connect("evento_emesso", _on_evento)
	var ks: Node = _n("/root/KnowledgeStore")
	if ks != null:
		ks.connect("appreso", _on_flag)


func _process(delta: float) -> void:
	if _attiva_da == -1:
		return
	var t: Dictionary = _dati(_attiva_da)
	if str(t.get("mentre_in_corso", "")) != "follia_accelerata":
		return
	var madness: Node = _n("/root/Madness")
	if madness == null:
		return
	var per_min: float = _param_effetto("follia_accelerata", 1.5)
	_follia_acc += delta
	if _follia_acc >= 1.0:
		madness.call("add", per_min / 60.0 * _follia_acc, "tribolazione", false)
		_follia_acc = 0.0


# --- API ----------------------------------------------------------------

## La tribolazione del salto che parte dalla Sequenza `da` (7/5/3/1). {} se
## nessuna (delega ai dati).
func tribolazione_per(da: int) -> Dictionary:
	return _dati(da)


## true se c'e' una tribolazione per il salto che parte da `da` e non e'
## ancora superata: Progression.avanza deve rifiutare.
func avanzamento_bloccato(da: int) -> bool:
	return not _dati(da).is_empty() and not superata(da)


func superata(da: int) -> bool:
	var eg: Node = _n("/root/EndgameState")
	return eg != null and bool(eg.call("tribolazione_superata", da))


## Attiva la prova del salto `da`: applica l'handicap 'mentre_in_corso'.
## Idempotente. Non fa nulla se non c'e' la tribolazione o e' gia' superata.
func attiva(da: int) -> void:
	if _attiva_da == da or _dati(da).is_empty() or superata(da):
		return
	_rimuovi_effetto()
	_attiva_da = da
	_progresso = 0.0
	_follia_acc = 0.0
	_applica_effetto(_dati(da))
	_ricalcola_progresso()
	tribolazione_attivata.emit(da)


func stato() -> Dictionary:
	return {
		"in_corso": _attiva_da != -1,
		"da": _attiva_da,
		"superata": _attiva_da != -1 and superata(_attiva_da),
		"progresso": _progresso,
	}


## Handicap esposti per i sistemi che li leggono (densita' mistica, gate
## abilita', overlay US-713). Valori neutri se nessuna tribolazione e' attiva.
func moltiplicatore_spawn() -> float:
	if _attiva_da != -1 and str(_dati(_attiva_da).get("mentre_in_corso", "")) == "nemici_rinforzati":
		return _param_effetto("nemici_rinforzati", 1.6)
	return 1.0


func sequenza_bloccata() -> bool:
	return _attiva_da != -1 and str(_dati(_attiva_da).get("mentre_in_corso", "")) == "abilita_bloccate"


## Per i test / debug: marca tutte le tribolazioni come superate. Le suite che
## non riguardano le tribolazioni la chiamano in prepara().
func marca_superate_tutte() -> void:
	_rimuovi_effetto()
	_attiva_da = -1
	var eg: Node = _n("/root/EndgameState")
	if eg != null:
		for da in _SALTI:
			eg.call("segna_tribolazione", da)


func azzera() -> void:
	_rimuovi_effetto()
	_attiva_da = -1
	_progresso = 0.0
	_follia_acc = 0.0


# --- Interno ----------------------------------------------------------

func _on_sequence_changed(nuova: int, vecchia: int) -> void:
	# avanzato oltre una fascia: la prova di quel salto e' finita
	if vecchia in _SALTI and nuova < vecchia and _attiva_da == vecchia:
		_rimuovi_effetto()
		_attiva_da = -1
	# arrivato a una Sequenza di salto: attiva la prova
	if nuova in _SALTI:
		attiva(nuova)


func _on_evento(_nome: String, _dati_ev: Dictionary) -> void:
	_ricalcola_progresso()


func _on_flag(_flag: String) -> void:
	_ricalcola_progresso()


## Ricalcola il progresso verso il superamento di OGNI salto non ancora
## superato (una prova puo' essere passata anche prima di essere "attiva":
## il flag/l'evento c'e' gia'). Al 100% registra il superamento; se era la
## prova attiva, toglie l'handicap.
func _ricalcola_progresso() -> void:
	for da in _SALTI:
		if superata(da):
			continue
		var t: Dictionary = _dati(da)
		if t.is_empty():
			continue
		var p: float = _progresso_di(t.get("superamento", {}))
		if da == _attiva_da and not is_equal_approx(p, _progresso):
			_progresso = p
			progresso_cambiato.emit(da, p)
		if p < 1.0:
			continue
		var eg: Node = _n("/root/EndgameState")
		if eg != null:
			eg.call("segna_tribolazione", da)
		if da == _attiva_da:
			_rimuovi_effetto()
			_attiva_da = -1   # prova finita: l'handicap non e' piu' attivo
		tribolazione_superata.emit(da)


func _progresso_di(sup: Dictionary) -> float:
	if sup.has("flag"):
		var ks: Node = _n("/root/KnowledgeStore")
		return 1.0 if (ks != null and bool(ks.call("conosce", str(sup["flag"])))) else 0.0
	if sup.has("evento"):
		var et: Node = _n("/root/EventTracker")
		var target: float = maxf(float(sup.get("target", 1)), 1.0)
		var fatti: float = et.call("count", str(sup["evento"]), sup.get("filtri", {})) if et != null else 0.0
		return clampf(fatti / target, 0.0, 1.0)
	return 0.0


func _applica_effetto(t: Dictionary) -> void:
	match str(t.get("mentre_in_corso", "")):
		"spiritualita_dimezzata":
			var stats: Node = _stats_giocatore()
			if stats != null:
				var base: float = float(stats.call("get_base", "spiritualita_max"))
				var mult: float = _param_effetto("spiritualita_dimezzata", 0.5)
				stats.call("apply_modifier", _MOD_SPIRITUALITA,
					{"spiritualita_max": -(1.0 - mult) * base})
		"notte_perenne":
			var ts: Node = _n("/root/TimeSystem")
			if ts != null:
				ts.call("forza_momento", str(_param_effetto_str("notte_perenne", "notte_fonda")))
		# follia_accelerata -> _process; nemici_rinforzati / abilita_bloccate ->
		# query moltiplicatore_spawn() / sequenza_bloccata().
		_:
			pass


func _rimuovi_effetto() -> void:
	var stats: Node = _stats_giocatore()
	if stats != null:
		stats.call("remove_modifier", _MOD_SPIRITUALITA)
	var ts: Node = _n("/root/TimeSystem")
	if ts != null and bool(ts.call("momento_forzato")):
		ts.call("libera_momento")
	_follia_acc = 0.0


func _dati(da: int) -> Dictionary:
	var gd: Node = _n("/root/GameData")
	return gd.call("tribulation_per_salto", da) if gd != null else {}


func _param_effetto(chiave: String, fallback: float) -> float:
	var doc: Dictionary = _effetti_vocab().get(chiave, {})
	var v: Variant = doc.get("default", fallback)
	return float(v) if typeof(v) in [TYPE_FLOAT, TYPE_INT] else fallback


func _param_effetto_str(chiave: String, fallback: String) -> String:
	var doc: Dictionary = _effetti_vocab().get(chiave, {})
	return str(doc.get("default", fallback))


func _effetti_vocab() -> Dictionary:
	var f := FileAccess.open("res://data/schema/tribulation_effects.json", FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return (d.get("effetti", {}) as Dictionary) if typeof(d) == TYPE_DICTIONARY else {}


func _stats_giocatore() -> Node:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p == null:
		return null
	if p.has_method("get_base"):
		return p
	for c in p.get_children():
		if c.has_method("get_base"):
			return c
	return null


func _n(path: String) -> Node:
	return get_node_or_null(path)
