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
## US-602: il giocatore e' entrato in una regione diversa (o l'ha scoperta).
signal regione_cambiata(id: String)

## Array di { tipo_modifica: String, posizione: [x, y], raggio: float }.
var _terrain_mods: Array = []

## US-602: dove si trova il giocatore, quali regioni ha scoperto, quali gate
## (AreaGate, US-611) ha aperto in modo permanente. Tutto nel save (campo
## "mondo"), tutto rilettura NON FIDATA.
var _regione: String = ""
var _scoperte: Array = []   # id di regione, stringhe
var _gate_aperti: Array = []  # id di gate, stringhe
## Il location_tag della zona in cui si trova il giocatore ("" fuori da una
## zona nominata). TRANSITORIO: e' posizione, non stato del mondo, non va nel
## save. Lo aggiorna region_scene entrando/uscendo dalle Area2D delle zone;
## lo legge la condizione in_zona_tag delle abilita' (US-605).
var _zona_tag: String = ""
## US-618: una zona puo' modificare localmente la densita' mistica della
## regione (>= 0 = override attivo, -1 = usa quella di regions.json).
## TRANSITORIO: e' posizione, non stato del mondo.
var _densita_override: float = -1.0


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
	_regione = ""
	_scoperte.clear()
	_gate_aperti.clear()
	_zona_tag = ""
	_densita_override = -1.0


# --- Regione corrente e scoperte (US-602) -------------------------------

func regione_corrente() -> String:
	return _regione


func scoperte() -> Array:
	return _scoperte.duplicate()


func e_scoperta(id: String) -> bool:
	return id in _scoperte


## Entra in una regione: la segna corrente e come scoperta. Emette una sola
## volta anche se la regione era gia' quella (idempotente sul valore).
func entra_regione(id: String) -> void:
	if id.is_empty():
		return
	var cambia: bool = id != _regione or id not in _scoperte
	_regione = id
	_zona_tag = ""
	_densita_override = -1.0
	if id not in _scoperte:
		_scoperte.append(id)
	if cambia:
		regione_cambiata.emit(id)


## Il location_tag della zona corrente del giocatore, o "" (US-605).
func zona_corrente() -> String:
	return _zona_tag


func imposta_zona(location_tag: String) -> void:
	_zona_tag = location_tag


# --- Densita' mistica (US-618) -----------------------------------------

## La densita' mistica dove si trova il giocatore: quella della regione
## corrente (regions.json), o l'override locale di una zona. Fuori da ogni
## regione: 0.2 (bassa, come la citta').
func densita_mistica_corrente() -> float:
	if _densita_override >= 0.0:
		return _densita_override
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null or _regione.is_empty():
		return 0.2
	var v: Variant = gd.call("get_region", _regione).get("densita_mistica", 0.2)
	return float(v) if typeof(v) in [TYPE_FLOAT, TYPE_INT] else 0.2


func imposta_densita_override(valore: float) -> void:
	_densita_override = valore   # < 0 = nessun override


## Frequenza di spawn (Beyonder / segreti) per la densita' corrente, al minuto.
## Lo spawner vero e' fase 7: qui e' il gancio che legge il dato.
func spawn_rate_corrente() -> float:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return 0.0
	var c: Dictionary = gd.call("get_balance", "densita_mistica")
	return float(c.get("spawn_base_al_min", 0.5)) + densita_mistica_corrente() * float(c.get("spawn_per_densita", 4.0))


func gate_aperti() -> Array:
	return _gate_aperti.duplicate()


func gate_e_aperto(id: String) -> bool:
	return id in _gate_aperti


## Un AreaGate aperto da un terrain_modify permanente (US-611): resta aperto
## per sempre, salvato nel mondo.
func apri_gate(id: String) -> void:
	if not id.is_empty() and id not in _gate_aperti:
		_gate_aperti.append(id)


# --- Salvataggio ---------------------------------------------------------

func per_salvataggio() -> Dictionary:
	return {
		"terrain_mods": _terrain_mods.duplicate(true),
		"regione": _regione,
		"scoperte": _scoperte.duplicate(),
		"gate_aperti": _gate_aperti.duplicate(),
	}


## Rilettura NON FIDATA: ogni voce validata con typeof(), le voci malformate
## scartate una a una senza far crashare il load.
func da_salvataggio(raw: Variant) -> void:
	_terrain_mods = []
	var d: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}

	# US-602: regione corrente + scoperte + gate aperti. Campi assenti (save
	# v20) o di tipo sbagliato -> default vuoti, nessun crash.
	_regione = str(d["regione"]) if typeof(d.get("regione")) == TYPE_STRING else ""
	_scoperte = _solo_stringhe(d.get("scoperte"))
	_gate_aperti = _solo_stringhe(d.get("gate_aperti"))
	if not _regione.is_empty() and _regione not in _scoperte:
		_scoperte.append(_regione)

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


## Lista di sole stringhe, scartando le voci malformate (rilettura non fidata).
func _solo_stringhe(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for v in raw:
		if typeof(v) == TYPE_STRING and not out.has(v):
			out.append(v)
	return out
