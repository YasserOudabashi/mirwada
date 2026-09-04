extends Node
## Registro delle strutture costruite (US-319). Stesso principio di
## SummonRegistry: fase 3 non ha ancora scene fisiche di struttura (arrivano
## col base building, US-326+); "costruire" oggi significa registrare
## id/hp/posizione qui. tg_2 (che le distrugge) e il base building (che le
## crea) parlano la stessa lingua attraverso questo autoload.
##
## NIENTE class_name: coerente col resto del progetto.

signal struttura_costruita(instance_id: String, struct_id: String)
signal struttura_danneggiata(instance_id: String, hp: float)
signal struttura_distrutta(instance_id: String, volontario: bool)

## Array di { instance_id, struct_id, posizione: [x, y], hp, hp_max }.
var _strutture: Array = []
var _prossimo: int = 1


## Registra una struttura del tipo `struct_id` (data/structures/). ""
## (stringa vuota) se il tipo non esiste - errore gestito, non un crash.
func costruisci(struct_id: String, posizione: Vector2) -> String:
	var gd: Node = get_node_or_null("/root/GameData")
	var def: Dictionary = gd.call("get_structure", struct_id) if gd != null else {}
	if def.is_empty():
		return ""
	var hp_max: float = float(def.get("hp_max", 0.0))
	var iid: String = "struct_%d" % _prossimo
	_prossimo += 1
	_strutture.append({
		"instance_id": iid, "struct_id": struct_id,
		"posizione": [posizione.x, posizione.y], "hp": hp_max, "hp_max": hp_max,
	})
	struttura_costruita.emit(iid, struct_id)
	return iid


## Toglie hp; a 0 la struttura si distrugge da sola (involontaria: US-320,
## la colpisce un'abilita' con colpisce_oggetti:true, non il proprietario).
func danneggia(instance_id: String, quantita: float) -> void:
	if quantita <= 0.0:
		return
	for s in _strutture:
		var d: Dictionary = s
		if str(d.get("instance_id", "")) != instance_id:
			continue
		d["hp"] = maxf(0.0, float(d["hp"]) - quantita)
		struttura_danneggiata.emit(instance_id, float(d["hp"]))
		if float(d["hp"]) <= 0.0:
			distruggi(instance_id, false)
		return


## volontario: true quando e' il giocatore a lasciarla decadere di proposito
## (tg_2_accetta_decadimento, US-320); false quando la distrugge un colpo
## esterno (danneggia() a 0, o un'altra fonte). Emette sempre
## structure_destroyed{volontario} - evento gia' nel vocabolario dei 12.
func distruggi(instance_id: String, volontario: bool) -> bool:
	for i in _strutture.size():
		if str((_strutture[i] as Dictionary).get("instance_id", "")) == instance_id:
			_strutture.remove_at(i)
			struttura_distrutta.emit(instance_id, volontario)
			var et: Node = get_node_or_null("/root/EventTracker")
			if et != null:
				et.call("emit_event", "structure_destroyed", {"volontario": volontario})
			return true
	return false


func attive() -> Array:
	return _strutture.duplicate(true)


## Strutture entro `raggio` da `centro` (US-320: colpisce_oggetti). Sola
## lettura: chi vuole danneggiarle chiama danneggia() per ognuna.
func in_raggio(centro: Vector2, raggio: float) -> Array:
	var out: Array = []
	for s in _strutture:
		var d: Dictionary = s
		var pos: Array = d.get("posizione", [0.0, 0.0])
		var p := Vector2(float(pos[0]), float(pos[1]))
		if centro.distance_to(p) <= raggio:
			out.append(d)
	return out


func struttura(instance_id: String) -> Dictionary:
	for s in _strutture:
		if str((s as Dictionary).get("instance_id", "")) == instance_id:
			return s
	return {}


func pulisci() -> void:
	_strutture.clear()
	_prossimo = 1


# --- Salvataggio -----------------------------------------------------

func per_salvataggio() -> Array:
	return _strutture.duplicate(true)


## NON FIDATA: scarta ogni voce malformata o con struct_id che non risolve.
func da_salvataggio(raw: Variant) -> void:
	pulisci()
	if typeof(raw) != TYPE_ARRAY:
		return
	var gd: Node = get_node_or_null("/root/GameData")
	var max_visto: int = 0
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = entry
		var struct_id: String = str(e.get("struct_id", ""))
		var def: Dictionary = gd.call("get_structure", struct_id) if gd != null else {}
		if def.is_empty():
			continue
		var iid: String = str(e.get("instance_id", ""))
		if iid.is_empty():
			continue
		var pos: Variant = e.get("posizione")
		var px := 0.0
		var py := 0.0
		if typeof(pos) == TYPE_ARRAY and (pos as Array).size() == 2:
			px = float(pos[0])
			py = float(pos[1])
		var hp_max: float = float(def.get("hp_max", 0.0))
		var hp_raw: Variant = e.get("hp")
		var hp: float = float(hp_raw) if typeof(hp_raw) in [TYPE_FLOAT, TYPE_INT] else hp_max
		_strutture.append({
			"instance_id": iid, "struct_id": struct_id,
			"posizione": [px, py], "hp": clampf(hp, 0.0, hp_max), "hp_max": hp_max,
		})
		var n: int = iid.trim_prefix("struct_").to_int()
		if n >= max_visto:
			max_visto = n + 1
	_prossimo = maxi(_prossimo, max_visto)
