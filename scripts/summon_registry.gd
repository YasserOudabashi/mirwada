extends Node
## Registro centrale delle evocazioni PERSISTENTI (primitiva summon con
## durata: -1). Non sono figlie della scena di combattimento: sopravvivono al
## cambio scena e al salvataggio (design-pathways.md — Death, Paragon).
##
## Fase 2 non ha ancora scene di entita': "ricreare" un'evocazione al load
## significa ripopolare questo registro. Lo spawn del Node vero lo fara' il
## sistema del mondo/combat leggendo evocazioni().
##
## NIENTE class_name: coerente col resto del progetto.

signal evocazione_aggiunta(id: String, tipo: String)
signal evocazione_rimossa(id: String)

## Array di { id: String, tipo: String, comportamento: String,
##            posizione: [x, y], hp: float }.
var _summons: Array = []
var _prossimo: int = 1


## Registra una nuova evocazione persistente. Restituisce il suo id univoco.
func evoca(tipo: String, comportamento: String, posizione: Vector2, hp: float) -> String:
	var id: String = "sum_%d" % _prossimo
	_prossimo += 1
	_summons.append({
		"id": id, "tipo": tipo, "comportamento": comportamento,
		"posizione": [posizione.x, posizione.y], "hp": hp,
	})
	evocazione_aggiunta.emit(id, tipo)
	return id


func evocazioni() -> Array:
	return _summons.duplicate(true)


func conta() -> int:
	return _summons.size()


func rimuovi(id: String) -> bool:
	for i in _summons.size():
		if str(_summons[i]["id"]) == id:
			_summons.remove_at(i)
			evocazione_rimossa.emit(id)
			return true
	return false


func pulisci() -> void:
	_summons.clear()


# --- Salvataggio ---------------------------------------------------------

## Lo slot "evocazioni" del save esiste gia' da US-015: qui lo si riempie.
func per_salvataggio() -> Array:
	return _summons.duplicate(true)


## Rilettura NON FIDATA. Un'evocazione la cui FONTE non e' piu' valida (tipo
## assente o vuoto) non viene ricreata: errore gestito, non crash.
func da_salvataggio(raw: Variant) -> void:
	_summons = []
	if typeof(raw) != TYPE_ARRAY:
		return
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = entry
		var tipo: Variant = e.get("tipo")
		if typeof(tipo) != TYPE_STRING or (tipo as String).is_empty():
			push_warning("[SummonRegistry] evocazione senza 'tipo' valido: fonte persa, non ricreata.")
			continue
		var pos: Variant = e.get("posizione")
		var px: float = 0.0
		var py: float = 0.0
		if typeof(pos) == TYPE_ARRAY and (pos as Array).size() == 2:
			px = float(pos[0])
			py = float(pos[1])
		var id: String = str(e.get("id", "sum_%d" % _prossimo))
		_prossimo += 1
		_summons.append({
			"id": id, "tipo": str(tipo),
			"comportamento": str(e.get("comportamento", "")),
			"posizione": [px, py],
			"hp": float(e.get("hp", 0.0)) if typeof(e.get("hp")) in [TYPE_FLOAT, TYPE_INT] else 0.0,
		})
