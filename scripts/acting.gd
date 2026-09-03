extends Node
## Acting Method: la barra di recitazione della Sequenza corrente.
##
## Ogni acting_action della Sequenza (da Progression.sequence_data()) e' un
## contatore su un evento tracciato (EventTracker). Il progresso di un'azione:
##   min(1.0, (count_ora - baseline) / target) * progresso_dichiarato
## dove baseline e' il conteggio al momento in cui si e' entrati nella
## Sequenza (l'Acting riparte da zero a ogni avanzamento).
##
## acting_progress() totale = somma dei contributi meno il decadimento, in
## [0, 1]. Il decadimento cresce quando si compie un'azione INCOERENTE col
## ruolo (es. usare un'abilita' Beyonder mentre si recita "duello puro").
##
## NIENTE class_name: coerente col resto del progetto.

signal acting_progress_changed(valore: float)

var _baseline: Dictionary = {}   # acting_action.id -> conteggio all'ingresso
var _latched: Dictionary = {}    # acting_action.id -> contributo bloccato (non ripetibili)
var _decadimento: float = 0.0


func _ready() -> void:
	var prog: Node = _prog()
	if prog != null and prog.has_signal("sequence_changed"):
		prog.sequence_changed.connect(_su_avanzamento)
	var et: Node = _et()
	if et != null and et.has_signal("evento_emesso"):
		et.evento_emesso.connect(_su_evento)
	_riparti()


# --- Lettura -------------------------------------------------------------

## Progresso totale della recitazione della Sequenza corrente, in [0, 1].
func acting_progress() -> float:
	var totale: float = 0.0
	for azione in _azioni_correnti():
		totale += _contributo(azione)
	return clampf(totale - _decadimento, 0.0, 1.0)


## true se la recitazione e' completa: si puo' avanzare per via normale (US-212).
## Tolleranza sull'ultima cifra: la somma di 0.35+0.30+0.35 in virgola mobile
## non fa esattamente 1.0.
func e_completo() -> bool:
	return acting_progress() >= 0.9999


func decadimento() -> float:
	return _decadimento


# --- Ripartenza e avanzamento -----------------------------------------

## Rileva le baseline dai conteggi attuali e azzera decadimento e blocchi.
## Chiamata a ogni avanzamento di Sequenza e al load.
func _riparti() -> void:
	_baseline.clear()
	_latched.clear()
	_decadimento = 0.0
	var et: Node = _et()
	for azione in _azioni_correnti():
		var id: String = str(azione.get("id", ""))
		_baseline[id] = et.call("count", str(azione.get("evento", "")), azione.get("filtri", {})) if et != null else 0.0
	acting_progress_changed.emit(acting_progress())


func _su_avanzamento(_nuova: int, _vecchia: int) -> void:
	_riparti()


# --- Interno ----------------------------------------------------------

func _contributo(azione: Dictionary) -> float:
	var id: String = str(azione.get("id", ""))
	var evento: String = str(azione.get("evento", ""))
	var target: float = float(azione.get("target", 1))
	var progresso: float = float(azione.get("progresso", 0.0))
	var ripetibile: bool = bool(azione.get("ripetibile", true))

	if not ripetibile and _latched.has(id):
		return float(_latched[id])

	var et: Node = _et()
	var ora: float = et.call("count", evento, azione.get("filtri", {})) if et != null else 0.0
	var delta: float = ora - float(_baseline.get(id, 0.0))
	var frazione: float = clampf(delta / target, 0.0, 1.0) if target > 0.0 else 0.0
	var contributo: float = frazione * progresso

	# Un'azione non ripetibile, una volta raggiunta, resta acquisita.
	if not ripetibile and frazione >= 1.0:
		_latched[id] = contributo
	return contributo


## Vero se la Sequenza corrente chiede di recitare SENZA usare abilita'
## Beyonder: allora usarne una e' incoerente e fa decadere il progresso.
func _sequenza_vieta_abilita() -> bool:
	for azione in _azioni_correnti():
		var filtri: Dictionary = azione.get("filtri", {})
		if filtri.get("senza_abilita") == true:
			return true
	return false


func _su_evento(nome: String, _dati: Dictionary) -> void:
	if nome == "ability_used" and _sequenza_vieta_abilita():
		var quanto: float = _decadimento_incoerente()
		if quanto > 0.0:
			_decadimento += quanto
	# Ogni evento che una acting_action della Sequenza conta puo' aver
	# cambiato il progresso: la HUD e i sistemi dipendenti devono saperlo.
	if nome == "ability_used" or _evento_conta_per_la_sequenza(nome):
		acting_progress_changed.emit(acting_progress())


func _evento_conta_per_la_sequenza(nome: String) -> bool:
	for azione in _azioni_correnti():
		if str(azione.get("evento", "")) == nome:
			return true
	return false


func _decadimento_incoerente() -> float:
	var gd: Node = _gd()
	if gd == null:
		return 0.05
	var acting: Dictionary = gd.call("get_balance", "acting")
	var v: Variant = acting.get("decadimento_azione_incoerente", 0.05)
	return v if typeof(v) in [TYPE_FLOAT, TYPE_INT] else 0.05


func _azioni_correnti() -> Array:
	var prog: Node = _prog()
	if prog == null:
		return []
	var sd: Dictionary = prog.call("sequence_data")
	var a: Variant = sd.get("acting_actions", [])
	return a if typeof(a) == TYPE_ARRAY else []


func _prog() -> Node:
	return get_node_or_null("/root/Progression")


func _et() -> Node:
	return get_node_or_null("/root/EventTracker")


func _gd() -> Node:
	return get_node_or_null("/root/GameData")


# --- Salvataggio -----------------------------------------------------

func per_salvataggio() -> Dictionary:
	return {"decadimento": _decadimento, "baseline": _baseline.duplicate(true),
			"latched": _latched.duplicate(true)}


func da_salvataggio(raw: Variant) -> void:
	var d: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var dec: Variant = d.get("decadimento", 0.0)
	_decadimento = float(dec) if typeof(dec) in [TYPE_FLOAT, TYPE_INT] else 0.0
	_baseline = (d.get("baseline") as Dictionary).duplicate(true) if typeof(d.get("baseline")) == TYPE_DICTIONARY else {}
	_latched = (d.get("latched") as Dictionary).duplicate(true) if typeof(d.get("latched")) == TYPE_DICTIONARY else {}
	acting_progress_changed.emit(acting_progress())
