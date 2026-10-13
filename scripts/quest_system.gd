extends Node
## US-616 — il motore delle quest: un LETTORE di data/quests/. Per ogni quest
## attiva osserva EventTracker (step 'evento') e KnowledgeStore (step 'flag') e
## avanza. Zero verbi di quest nuovi: ogni step e' uno dei 12 eventi tracciati
## o un flag scritto da un dialogo/quest. Stessa architettura dell'Acting Method.
##
## avvia(quest_id) lo chiama l'effetto dialogo 'avvia_quest' (DialogueEngine).
## fallibile:true + una condizione di fallimento (fallisci(), o una quest di
## exclusive_with avviata) -> stato 'fallita', e il journal la mostra fallita.
##
## NIENTE class_name: coerente col resto del progetto.

signal quest_avviata(quest_id: String)
signal step_completato(quest_id: String, step_id: String)
signal quest_completata(quest_id: String)
signal quest_fallita(quest_id: String)
signal apri_vendita(npc_id: String)

## quest_id -> { passo: int, baseline: float }
var _attive: Dictionary = {}
var _completate: Array = []
var _fallite: Array = []
## Applicare un effetto 'flag' emette KnowledgeStore.appreso, che rientrerebbe
## in _rivaluta mentre stiamo gia' avanzando: la guardia lo impedisce.
var _in_rivaluta: bool = false


func _ready() -> void:
	var et: Node = get_node_or_null("/root/EventTracker")
	if et != null and et.has_signal("evento_emesso"):
		et.evento_emesso.connect(func(_n, _d): _rivaluta())
	var ks: Node = get_node_or_null("/root/KnowledgeStore")
	if ks != null and ks.has_signal("appreso"):
		ks.appreso.connect(func(_f): _rivaluta())


# --- API ----------------------------------------------------------

func stato(quest_id: String) -> String:
	if quest_id in _completate:
		return "completata"
	if quest_id in _fallite:
		return "fallita"
	if _attive.has(quest_id):
		return "attiva"
	return "non_iniziata"


## Avvia una quest. No-op se non e' 'non_iniziata' o se il dato non esiste.
## Le quest di exclusive_with ancora attive e fallibili diventano 'fallite'.
func avvia(quest_id: String) -> bool:
	if stato(quest_id) != "non_iniziata" or _quest(quest_id).is_empty():
		return false
	for altra in _quest(quest_id).get("exclusive_with", []):
		if stato(str(altra)) == "attiva" and bool(_quest(str(altra)).get("fallibile", false)):
			_fallisci_interno(str(altra))
	_attive[quest_id] = {"passo": 0, "baseline": _conteggio_step(quest_id, 0)}
	quest_avviata.emit(quest_id)
	_rivaluta()   # uno step gia' soddisfatto all'avvio si chiude subito
	return true


## Fallimento esplicito (NPC morto, tempo scaduto: il chiamante decide). No-op
## se la quest non e' attiva o non e' fallibile.
func fallisci(quest_id: String) -> bool:
	if stato(quest_id) != "attiva" or not bool(_quest(quest_id).get("fallibile", false)):
		return false
	_fallisci_interno(quest_id)
	return true


func passo_corrente(quest_id: String) -> int:
	return int((_attive.get(quest_id, {}) as Dictionary).get("passo", -1))


func attive() -> Array: return _attive.keys()
func completate() -> Array: return _completate.duplicate()
func fallite() -> Array: return _fallite.duplicate()


# --- Motore -----------------------------------------------------

func _rivaluta() -> void:
	if _in_rivaluta:
		return
	_in_rivaluta = true
	# copia le chiavi: _avanza puo' mutare _attive durante l'iterazione
	for qid in _attive.keys():
		if _attive.has(qid):
			_prova_ad_avanzare(qid)
	_in_rivaluta = false


func _prova_ad_avanzare(quest_id: String) -> void:
	var q: Dictionary = _quest(quest_id)
	var passo: int = int(_attive[quest_id]["passo"])
	var steps: Array = q.get("steps", [])
	while passo < steps.size() and _step_soddisfatto(quest_id, passo):
		var step: Dictionary = steps[passo]
		for eff in step.get("on_complete", []):
			_applica_effetto(eff)
		step_completato.emit(quest_id, str(step.get("id", "")))
		passo += 1
		if passo < steps.size():
			_attive[quest_id] = {"passo": passo, "baseline": _conteggio_step(quest_id, passo)}
	if passo >= steps.size():
		_attive.erase(quest_id)
		_completate.append(quest_id)
		for eff in q.get("ricompense", []):
			_applica_effetto(eff)
		quest_completata.emit(quest_id)


func _step_soddisfatto(quest_id: String, passo: int) -> bool:
	var c: Dictionary = _step(quest_id, passo).get("completamento", {})
	match str(c.get("tipo", "")):
		"flag":
			var ks: Node = get_node_or_null("/root/KnowledgeStore")
			return ks != null and bool(ks.call("conosce", str(c.get("id", ""))))
		"evento":
			var ora: float = _conteggio_step(quest_id, passo)
			return ora - float(_attive[quest_id]["baseline"]) >= float(c.get("target", 1))
	return false


## Il conteggio corrente dell'evento dello step (0 per gli step 'flag').
func _conteggio_step(quest_id: String, passo: int) -> float:
	var c: Dictionary = _step(quest_id, passo).get("completamento", {})
	if str(c.get("tipo", "")) != "evento":
		return 0.0
	var et: Node = get_node_or_null("/root/EventTracker")
	return float(et.call("count", str(c.get("evento", "")), c.get("filtri", {}))) if et != null else 0.0


func _fallisci_interno(quest_id: String) -> void:
	_attive.erase(quest_id)
	if quest_id not in _fallite:
		_fallite.append(quest_id)
	quest_fallita.emit(quest_id)


# --- Effetti (on_complete + ricompense, vocabolario chiuso di 5) --

func _applica_effetto(eff: Variant) -> void:
	if typeof(eff) != TYPE_DICTIONARY:
		return
	var e: Dictionary = eff
	match str(e.get("tipo", "")):
		"flag":
			var ks: Node = get_node_or_null("/root/KnowledgeStore")
			if ks != null:
				ks.call("imposta", str(e.get("id", "")), bool(e.get("valore", true)))
		"item":
			var inv: Node = get_node_or_null("/root/Inventory")
			if inv != null:
				inv.call("aggiungi", str(e.get("item_id", "")), int(e.get("quantita", 1)))
		"reputazione":
			var fs: Node = get_node_or_null("/root/FactionSystem")
			if fs != null:
				fs.call("modifica", str(e.get("faction_id", "")), float(e.get("delta", 0.0)), "quest")
		"ancora":
			var ns: Node = get_node_or_null("/root/NpcSystem")
			if ns != null:
				ns.call("promuovi_ancora", str(e.get("npc_id", "")))
		"apri_vendita":
			apri_vendita.emit(str(e.get("npc_id", "")))


# --- Dati -------------------------------------------------------

func _quest(quest_id: String) -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("get_quest", quest_id) if gd != null else {}


func _step(quest_id: String, passo: int) -> Dictionary:
	var steps: Array = _quest(quest_id).get("steps", [])
	return steps[passo] if passo >= 0 and passo < steps.size() else {}


# --- Salvataggio (mondo.quest, US-616; nessun bump) -----------

func per_salvataggio() -> Dictionary:
	return {
		"attive": _attive.duplicate(true),
		"completate": _completate.duplicate(),
		"fallite": _fallite.duplicate(),
	}


func da_salvataggio(raw: Variant) -> void:
	_attive = {}
	_completate = []
	_fallite = []
	var d: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var att: Variant = d.get("attive")
	if typeof(att) == TYPE_DICTIONARY:
		for qid in att:
			if typeof(qid) == TYPE_STRING and typeof(att[qid]) == TYPE_DICTIONARY and not _quest(qid).is_empty():
				_attive[qid] = {
					"passo": int((att[qid] as Dictionary).get("passo", 0)),
					"baseline": float((att[qid] as Dictionary).get("baseline", 0.0)),
				}
	_completate = _solo_stringhe(d.get("completate"))
	_fallite = _solo_stringhe(d.get("fallite"))


func pulisci() -> void:
	_attive.clear()
	_completate.clear()
	_fallite.clear()


func _solo_stringhe(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for v in raw:
		if typeof(v) == TYPE_STRING and not out.has(v):
			out.append(v)
	return out
