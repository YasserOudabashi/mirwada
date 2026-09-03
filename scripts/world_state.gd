extends Node
## Stato persistente del mondo: le modifiche al terreno che restano incise
## anche dopo il cambio scena e il salvataggio (primitiva terrain_modify con
## permanente: true — design-world.md cap. 4: un varco aperto resta aperto).
##
## Fase 2 non ha ancora un mondo vero: qui si registra solo il fatto (tipo,
## posizione, raggio). Chi disegna le zone (fase 6) lo leggera' per applicare
## la modifica al tilemap.
##
## NIENTE class_name: coerente col resto del progetto.

signal terreno_modificato(tipo_modifica: String, posizione: Vector2, raggio: float)

## Array di { tipo_modifica: String, posizione: [x, y], raggio: float }.
var _terrain_mods: Array = []


## Incide una modifica permanente. Le duplicate esatte (stesso tipo, stessa
## cella, stesso raggio) non si accumulano.
func registra_terreno(tipo_modifica: String, posizione: Vector2, raggio: float) -> void:
	var voce: Dictionary = {
		"tipo_modifica": tipo_modifica,
		"posizione": [posizione.x, posizione.y],
		"raggio": raggio,
	}
	for esistente in _terrain_mods:
		if esistente == voce:
			return
	_terrain_mods.append(voce)
	terreno_modificato.emit(tipo_modifica, posizione, raggio)


func terreni() -> Array:
	return _terrain_mods.duplicate(true)


func pulisci() -> void:
	_terrain_mods.clear()


# --- Salvataggio ---------------------------------------------------------

func per_salvataggio() -> Dictionary:
	return {"terrain_mods": _terrain_mods.duplicate(true)}


## Rilettura NON FIDATA: ogni voce validata con typeof(), le voci malformate
## scartate una a una senza far crashare il load.
func da_salvataggio(raw: Variant) -> void:
	_terrain_mods = []
	var d: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var lista: Variant = d.get("terrain_mods", [])
	if typeof(lista) != TYPE_ARRAY:
		return
	for entry in lista:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = entry
		var pos: Variant = e.get("posizione")
		if typeof(e.get("tipo_modifica")) != TYPE_STRING:
			continue
		if typeof(pos) != TYPE_ARRAY or (pos as Array).size() != 2:
			continue
		_terrain_mods.append({
			"tipo_modifica": str(e["tipo_modifica"]),
			"posizione": [float(pos[0]), float(pos[1])],
			"raggio": float(e.get("raggio", 0.0)) if typeof(e.get("raggio")) in [TYPE_FLOAT, TYPE_INT] else 0.0,
		})
