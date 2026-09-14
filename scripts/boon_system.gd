extends Node
## BoonSystem (fase 9, US-902): il motore generico dei Pathway Non-Standard,
## gemello di PotionSystem per i Pathway standard. Il codice non sa nulla di
## "Eternal Aeon": legge solo il campo 'boon' della Sequenza corrente
## (Progression.sequence_data(), data/schema/boon.schema.json).
##
## Un Boon e' un dono UNA TANTUM: quando TUTTI i requisiti dichiarati sono
## soddisfatti si puo' riceverlo (ricevi_boon()), che paga i sacrifici
## dichiarati e avanza la Sequenza (Progression.avanza()) - mai un
## avanzamento forzato/parziale come PotionSystem.bevi(forza:true): se un
## requisito manca, ricevi_boon() non fa nulla (FR-3 del PRD di fase 9).
##
## I requisiti 'comportamento' contano un evento tracciato da una baseline
## PROPRIA alla Sequenza corrente - stesso principio di
## Acting._baseline/_riparti, ma un registro separato: Acting alimenta la
## recitazione dei Pathway standard, mescolarli avrebbe fatto decadere la
## recitazione di un Pathway standard per un evento contato da un Boon (o
## viceversa).
##
## NIENTE class_name: coerente col resto del progetto.

var _baseline: Dictionary = {}   # "<sequence_id>:<indice_requisito>" -> conteggio all'ingresso


func _ready() -> void:
	var prog: Node = _prog()
	if prog != null and prog.has_signal("sequence_changed"):
		prog.sequence_changed.connect(func(_n, _v): _riparti())
	_riparti()


# --- Lettura -------------------------------------------------------------

## Lo stato di ogni requisito del Boon della Sequenza corrente. [] se la
## Sequenza non ha 'boon' (Pathway standard, o nessun avanzamento dichiarato
## a questa Sequenza).
func requisiti_stato() -> Array:
	var out: Array = []
	var boon: Dictionary = _boon_corrente()
	var requisiti: Array = boon.get("requisiti", [])
	var et: Node = _et()
	for i in requisiti.size():
		var req: Dictionary = requisiti[i]
		var tipo: String = str(req.get("tipo", ""))
		var voce: Dictionary = {"tipo": tipo, "soddisfatto": false}
		match tipo:
			"quest":
				var qid: String = str(req.get("quest_id", ""))
				var qs: Node = _quest()
				voce["quest_id"] = qid
				voce["soddisfatto"] = qs != null and str(qs.call("stato", qid)) == "completata"
			"comportamento":
				var target: float = float(req.get("target", 1))
				var ora: float = float(et.call("count", str(req.get("evento", "")), req.get("filtri", {}))) if et != null else 0.0
				var base: float = float(_baseline.get(_chiave_baseline(i), 0.0))
				var progresso: float = maxf(0.0, ora - base)
				voce["evento"] = str(req.get("evento", ""))
				voce["filtri"] = req.get("filtri", {})
				voce["target"] = target
				voce["progresso"] = progresso
				voce["soddisfatto"] = progresso >= target
			"sacrificio":
				var costo: Dictionary = req.get("costo", {})
				voce["costo"] = costo
				voce["soddisfatto"] = _sacrificio_disponibile(costo)
		out.append(voce)
	return out


## true solo se la Sequenza corrente ha un Boon E ogni suo requisito e'
## soddisfatto. Una Sequenza senza 'boon' (nessun requisito) non e' mai
## "pronta": non c'e' nulla da ricevere.
func puo_ricevere() -> bool:
	if _boon_corrente().is_empty():
		return false
	for s in requisiti_stato():
		if not bool(s.get("soddisfatto", false)):
			return false
	return true


## Riceve il Boon: paga i sacrifici dichiarati e avanza la Sequenza. Se un
## requisito manca non consuma nulla e non avanza (FR-3: atomico, mai un
## avanzamento parziale/forzato).
func ricevi_boon() -> Dictionary:
	if _boon_corrente().is_empty():
		return {"ok": false, "avanzato": false, "reason": "nessun_boon"}
	if not puo_ricevere():
		return {"ok": false, "avanzato": false, "reason": "requisiti_mancanti"}
	for s in requisiti_stato():
		if str(s.get("tipo", "")) == "sacrificio":
			_paga_sacrificio(s.get("costo", {}))
	var prog: Node = _prog()
	var avanzato: bool = prog != null and bool(prog.call("avanza"))
	return {"ok": true, "avanzato": avanzato, "reason": ""}


# --- Interno ---------------------------------------------------------------

func _boon_corrente() -> Dictionary:
	var prog: Node = _prog()
	if prog == null:
		return {}
	var sd: Dictionary = prog.call("sequence_data")
	var b: Variant = sd.get("boon")
	return b if typeof(b) == TYPE_DICTIONARY else {}


func _sacrificio_disponibile(costo: Dictionary) -> bool:
	var tipo: String = str(costo.get("tipo", ""))
	var q: float = float(costo.get("quantita", 0))
	match tipo:
		"oggetto":
			var inv: Node = _inv()
			return inv != null and int(inv.call("conta", str(costo.get("id", "")))) >= int(q)
		"caratteristica":
			var cs: Node = _car()
			return cs != null and bool(cs.call("possiede", str(costo.get("id", ""))))
		"follia":
			# E' un costo che SI PAGA (aumenta la Follia): sempre disponibile,
			# non una soglia da raggiungere prima.
			return true
	return false


func _paga_sacrificio(costo: Dictionary) -> void:
	var tipo: String = str(costo.get("tipo", ""))
	var q: float = float(costo.get("quantita", 0))
	match tipo:
		"oggetto":
			var inv: Node = _inv()
			if inv != null:
				inv.call("rimuovi", str(costo.get("id", "")), int(q))
		"caratteristica":
			var cs: Node = _car()
			if cs != null:
				cs.call("consuma", str(costo.get("id", "")))
		"follia":
			var mad: Node = _madness()
			if mad != null:
				mad.call("add", q, "boon_sacrificio")


## Rileva le baseline dai conteggi attuali. Chiamata a ogni avanzamento di
## Sequenza e al load (stesso ruolo di Acting._riparti).
func _riparti() -> void:
	_baseline.clear()
	var boon: Dictionary = _boon_corrente()
	var requisiti: Array = boon.get("requisiti", [])
	var et: Node = _et()
	for i in requisiti.size():
		var req: Dictionary = requisiti[i]
		if str(req.get("tipo", "")) == "comportamento" and et != null:
			_baseline[_chiave_baseline(i)] = et.call("count", str(req.get("evento", "")), req.get("filtri", {}))


func _chiave_baseline(indice: int) -> String:
	var prog: Node = _prog()
	var sid: String = str(prog.call("sequence_data").get("id", "")) if prog != null else ""
	return "%s:%d" % [sid, indice]


# --- Salvataggio -----------------------------------------------------------

func per_salvataggio() -> Dictionary:
	return {"baseline": _baseline.duplicate(true)}


func da_salvataggio(raw: Variant) -> void:
	var d: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var b: Variant = d.get("baseline", {})
	_baseline = (b as Dictionary).duplicate(true) if typeof(b) == TYPE_DICTIONARY else {}
	# Save piu' vecchio (senza baseline salvata) o Sequenza senza requisiti
	# 'comportamento': si rideriva, meglio un requisito da rifare che uno
	# segnato completo per errore.
	if _baseline.is_empty():
		_riparti()


func _prog() -> Node:
	return get_node_or_null("/root/Progression")


func _et() -> Node:
	return get_node_or_null("/root/EventTracker")


func _quest() -> Node:
	return get_node_or_null("/root/QuestSystem")


func _inv() -> Node:
	return get_node_or_null("/root/Inventory")


func _car() -> Node:
	return get_node_or_null("/root/CharacteristicStore")


func _madness() -> Node:
	return get_node_or_null("/root/Madness")
