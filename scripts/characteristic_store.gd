extends Node
## Le Caratteristiche Beyonder raccolte dal giocatore. Servono a preparare le
## pozioni (US-209). Un magazzino minimo: la fase 3 portera' l'inventario vero.
##
## NIENTE class_name: coerente col resto del progetto.

signal caratteristica_raccolta(id: String)
signal caratteristica_consumata(id: String)

## Lista di id (con ripetizioni: si possono avere piu' Caratteristiche uguali).
var _held: Array = []


func aggiungi(id: String) -> void:
	if id.is_empty():
		return
	_held.append(id)
	caratteristica_raccolta.emit(id)


## Rimuove UNA occorrenza. true se ce n'era una.
func consuma(id: String) -> bool:
	var i: int = _held.find(id)
	if i < 0:
		return false
	_held.remove_at(i)
	caratteristica_consumata.emit(id)
	return true


func possiede(id: String) -> bool:
	return _held.has(id)


func conta(id: String = "") -> int:
	if id.is_empty():
		return _held.size()
	return _held.count(id)


func posseduti() -> Array:
	return _held.duplicate()


func pulisci() -> void:
	_held.clear()


# --- Salvataggio ---------------------------------------------------------

func per_salvataggio() -> Array:
	return _held.duplicate()


## NON FIDATO: tiene solo le stringhe, scarta il resto.
func da_salvataggio(raw: Variant) -> void:
	_held = []
	if typeof(raw) != TYPE_ARRAY:
		return
	for v in raw:
		if typeof(v) == TYPE_STRING and not (v as String).is_empty():
			_held.append(v)
