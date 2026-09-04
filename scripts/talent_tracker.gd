extends Node
## Contatore dei comportamenti-talento (US-330/331): quello che i 12 eventi
## di EventTracker non catturano da soli. STESSO motore di EventTracker
## (log + count() con filtri), vocabolario diverso
## (data/schema/tracked_talents.json invece di tracked_events.json) - due
## autoload separati perche' sono due vocabolari chiusi distinti, non due
## fasi dello stesso sistema.
##
## NIENTE class_name: coerente col resto del progetto.

signal comportamento_emesso(nome: String, dati: Dictionary)

var _log: Array = []


func _vocabolario() -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("tracked_talents") if gd != null else {}


func emit_event(nome: String, dati: Dictionary = {}) -> void:
	if not _vocabolario().has(nome):
		push_error("[TalentTracker] comportamento fuori vocabolario: '%s' (i 7 sono chiusi in data/schema/tracked_talents.json)" % nome)
		return
	_log.append({"nome": nome, "dati": dati.duplicate(true)})
	comportamento_emesso.emit(nome, dati)


func count(evento: String, filtri: Dictionary = {}) -> float:
	var spec: Dictionary = _vocabolario().get(evento, {})
	if spec.is_empty():
		push_error("[TalentTracker] count su comportamento fuori vocabolario: '%s'" % evento)
		return 0.0

	var ammessi: Array = spec.get("filtri", [])
	for k in filtri:
		if not ammessi.has(k):
			push_error("[TalentTracker] filtro '%s' non ammesso per '%s' (ammessi: %s)" % [k, evento, ammessi])
			return 0.0

	var misura: String = str(spec.get("misura", "conteggio"))
	var totale: float = 0.0
	for voce in _log:
		var v: Dictionary = voce
		if str(v["nome"]) != evento:
			continue
		if not _corrisponde(v["dati"], filtri):
			continue
		if misura == "conteggio":
			totale += 1.0
		else:
			var q: Variant = (v["dati"] as Dictionary).get("quantita", 0.0)
			totale += q if typeof(q) in [TYPE_FLOAT, TYPE_INT] else 0.0
	return totale


func _corrisponde(dati: Dictionary, filtri: Dictionary) -> bool:
	for k in filtri:
		var atteso: Variant = filtri[k]
		var avuto: Variant = dati.get(k)
		if str(k).ends_with("_max"):
			var campo: String = str(k).trim_suffix("_max")
			var val: Variant = dati.get(campo)
			if not (typeof(val) in [TYPE_FLOAT, TYPE_INT]) or float(val) > float(atteso):
				return false
		elif str(k).ends_with("_min"):
			var campo2: String = str(k).trim_suffix("_min")
			var val2: Variant = dati.get(campo2)
			if not (typeof(val2) in [TYPE_FLOAT, TYPE_INT]) or float(val2) < float(atteso):
				return false
		elif typeof(atteso) == TYPE_BOOL and atteso:
			if avuto != true:
				return false
		elif avuto != atteso:
			return false
	return true


# --- Salvataggio ---------------------------------------------------------

func per_salvataggio() -> Dictionary:
	return {"log": _log.duplicate(true)}


func da_salvataggio(raw: Variant) -> void:
	_log = []
	var d: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var lista: Variant = d.get("log", [])
	if typeof(lista) != TYPE_ARRAY:
		return
	for entry in lista:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = entry
		if typeof(e.get("nome")) != TYPE_STRING:
			continue
		var dati: Variant = e.get("dati", {})
		_log.append({"nome": str(e["nome"]),
				"dati": dati if typeof(dati) == TYPE_DICTIONARY else {}})


func azzera() -> void:
	_log.clear()


func comportamenti_totali() -> int:
	return _log.size()
