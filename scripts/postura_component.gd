extends Node
## Postura: la "guardia" di un'entita'. Colpi (via lo stagger delle hitbox) e
## parate perfette la erodono; a zero l'entita' e' VULNERABILE per un tempo,
## poi la postura torna piena. Fuori dalla vulnerabilita' si ricarica da sola
## dopo una breve pausa.
##
## Riusabile: il nemico di US-011 la monta come StatsComponent.
## NIENTE class_name: coerente col progetto.

signal postura_changed(postura: float, postura_max: float)
signal postura_rotta
signal vulnerabilita_finita

var _max: float = 100.0
var _postura: float = 100.0
var _durata_vulnerabile: float = 3.0
var _recupero_al_sec: float = 15.0

var _vulnerabile: bool = false
var _vuln_left: float = 0.0
var _pausa_recupero: float = 0.0


func configura(massimo: float, durata_vulnerabile: float, recupero_al_sec: float) -> void:
	_max = maxf(massimo, 1.0)
	_durata_vulnerabile = durata_vulnerabile
	_recupero_al_sec = recupero_al_sec
	_postura = _max
	_vulnerabile = false


## Erode la postura. Ignorata mentre l'entita' e' gia' vulnerabile.
func erodi(quanta: float) -> void:
	if _vulnerabile or quanta <= 0.0:
		return
	_postura = maxf(_postura - quanta, 0.0)
	_pausa_recupero = 0.8
	postura_changed.emit(_postura, _max)
	if _postura <= 0.0:
		_vulnerabile = true
		_vuln_left = _durata_vulnerabile
		postura_rotta.emit()


func is_vulnerabile() -> bool:
	return _vulnerabile


func postura() -> float:
	return _postura


func postura_max() -> float:
	return _max


func _process(delta: float) -> void:
	if _vulnerabile:
		_vuln_left -= delta
		if _vuln_left <= 0.0:
			_vulnerabile = false
			_postura = _max
			postura_changed.emit(_postura, _max)
			vulnerabilita_finita.emit()
		return
	if _postura < _max:
		_pausa_recupero = maxf(_pausa_recupero - delta, 0.0)
		if _pausa_recupero <= 0.0:
			_postura = minf(_postura + _recupero_al_sec * delta, _max)
			postura_changed.emit(_postura, _max)
