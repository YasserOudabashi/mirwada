extends Node
## Registro centrale delle strutture COSTRUITE (US-319). Il base building
## (US-326+) le crea, le abilita' d'area con colpisce_oggetti:true (US-320,
## tg_2) le danneggiano, tg_2 le lascia decadere volontariamente.
##
## Come SummonRegistry: le istanze non sono figlie della scena, sopravvivono
## al cambio scena e al salvataggio. Lo spawn del Node vero lo fara' il
## sistema del mondo leggendo attive().
##
## NIENTE class_name: coerente col resto del progetto.

signal struttura_costruita(instance_id: String, struct_id: String)
signal struttura_distrutta(instance_id: String, volontario: bool)

## Array di { id: String, struct_id: String, posizione: [x, y], hp: float }.
var _strutture: Array = []
var _prossimo: int = 1


func _gd() -> Node:
	return get_node_or_null("/root/GameData")


func _eventi() -> Node:
	return get_node_or_null("/root/EventTracker")


## Piazza una nuova struttura. struct_id sconosciuto -> "" e nessuna istanza:
## errore gestito, non crash. Restituisce l'instance_id.
func costruisci(struct_id: String, posizione: Vector2) -> String:
	var tipo: Dictionary = _gd().call("get_structure", struct_id) if _gd() != null else {}
	if tipo.is_empty():
		push_error("[StructureRegistry] struct_id sconosciuto: '%s' (vedi data/structures/)" % struct_id)
		return ""
	var id: String = "str_%d" % _prossimo
	_prossimo += 1
	_strutture.append({
		"id": id, "struct_id": struct_id,
		"posizione": [posizione.x, posizione.y],
		"hp": float(tipo.get("hp_max", 1)),
	})
	struttura_costruita.emit(id, struct_id)
	return id


## Infligge danno a una struttura. Portata a <= 0 -> crolla (distruzione NON
## volontaria: la struttura e' stata abbattuta, non lasciata decadere).
func danneggia(instance_id: String, quantita: float) -> void:
	var e: Dictionary = _trova(instance_id)
	if e.is_empty():
		return
	e["hp"] = float(e["hp"]) - maxf(0.0, quantita)
	if float(e["hp"]) <= 0.0:
		distruggi(instance_id, false)


## Rimuove la struttura ed emette structure_destroyed{volontario}. volontario
## true = tg_2 la lascia decadere di proposito; false = e' stata abbattuta.
func distruggi(instance_id: String, volontario: bool) -> bool:
	for i in _strutture.size():
		if str(_strutture[i]["id"]) == instance_id:
			_strutture.remove_at(i)
			if _eventi() != null:
				_eventi().call("emit_event", "structure_destroyed", {"volontario": volontario})
			struttura_distrutta.emit(instance_id, volontario)
			return true
	return false


func attive() -> Array:
	return _strutture.duplicate(true)


func conta() -> int:
	return _strutture.size()


## Le istanze in raggio da una posizione (US-320: le abilita' d'area le cercano).
func in_raggio(centro: Vector2, raggio: float) -> Array:
	var out: Array = []
	for e in _strutture:
		var p: Array = e["posizione"]
		if Vector2(p[0], p[1]).distance_to(centro) <= raggio:
			out.append(str(e["id"]))
	return out


func pulisci() -> void:
	_strutture.clear()


func _trova(instance_id: String) -> Dictionary:
	for e in _strutture:
		if str(e["id"]) == instance_id:
			return e
	return {}


# --- Salvataggio --------------------------------------------------------

func per_salvataggio() -> Array:
	return _strutture.duplicate(true)


## Rilettura NON FIDATA. Una struttura il cui tipo non esiste piu' nei dati
## non viene ricreata: errore gestito, non crash.
func da_salvataggio(raw: Variant) -> void:
	_strutture = []
	if typeof(raw) != TYPE_ARRAY:
		return
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = entry
		var struct_id: Variant = e.get("struct_id")
		if typeof(struct_id) != TYPE_STRING or (struct_id as String).is_empty():
			push_warning("[StructureRegistry] struttura senza 'struct_id': scartata.")
			continue
		if _gd() != null and (_gd().call("get_structure", struct_id) as Dictionary).is_empty():
			push_warning("[StructureRegistry] tipo '%s' non piu' nei dati: struttura non ricreata." % struct_id)
			continue
		var pos: Variant = e.get("posizione")
		var px: float = 0.0
		var py: float = 0.0
		if typeof(pos) == TYPE_ARRAY and (pos as Array).size() == 2:
			px = float(pos[0])
			py = float(pos[1])
		var id: String = str(e.get("id", "str_%d" % _prossimo))
		_prossimo += 1
		_strutture.append({
			"id": id, "struct_id": str(struct_id),
			"posizione": [px, py],
			"hp": float(e.get("hp", 0.0)) if typeof(e.get("hp")) in [TYPE_FLOAT, TYPE_INT] else 0.0,
		})
