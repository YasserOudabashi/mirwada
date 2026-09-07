extends Node
## US-615 — reputazione con le 4 fazioni di Mirwada (data/factions.json). Un
## numero per fazione; livello() lo mappa sui nomi di soglia. La reputazione e'
## un effetto di dialogo/quest (DialogueEngine 'reputazione') e una condizione
## (Conditions 'reputazione_min', gia' nell'enum).
##
## Due comportamenti automatici, entrambi DICHIARATI NEI DATI (nessun if per
## una fazione qui dentro):
##  - factions.json[].reazione_al_potere: usare un potere mentre quel membro e'
##    presente nella tua stessa location_tag costa reputazione (Vesna);
##  - factions.json[].sospetto: quell'evento, in quella regione, alza la
##    reputazione della fazione; a soglia scrive un flag (Doran).
##
## NIENTE class_name: coerente col resto del progetto.

signal reputazione_cambiata(faction_id: String, valore: float, livello: String)

var _rep: Dictionary = {}   # faction_id -> float


func _ready() -> void:
	var et: Node = get_node_or_null("/root/EventTracker")
	if et != null and et.has_signal("evento_emesso"):
		et.evento_emesso.connect(_su_evento)
	var ae: Node = get_node_or_null("/root/AbilityEngine")
	if ae != null and ae.has_signal("ability_executed"):
		ae.ability_executed.connect(_su_abilita)


# --- Lettura --------------------------------------------------------

func reputazione(faction_id: String) -> float:
	return float(_rep.get(faction_id, 0.0))


## Il nome di soglia corrente: la soglia col valore piu' alto <= reputazione,
## o (sotto tutte) quella col valore piu' basso. Direzione-agnostico: vale sia
## per le fazioni normali sia per 'giustizia' (soglie invertite = sospetto).
func livello(faction_id: String) -> String:
	var soglie: Dictionary = _faction(faction_id).get("soglie", {})
	if soglie.is_empty():
		return ""
	var rep: float = reputazione(faction_id)
	var ordinate: Array = soglie.keys()
	ordinate.sort_custom(func(a, b): return float(soglie[a]) > float(soglie[b]))
	for nome in ordinate:
		if rep >= float(soglie[nome]):
			return str(nome)
	return str(ordinate[-1])


# --- Mutazione -----------------------------------------------------

## delta puo' essere negativo. 'sorgente' e' solo diagnostica.
func modifica(faction_id: String, delta: float, _sorgente: String = "") -> void:
	if _faction(faction_id).is_empty() or is_equal_approx(delta, 0.0):
		return
	_rep[faction_id] = reputazione(faction_id) + delta
	_applica_soglie(faction_id)
	reputazione_cambiata.emit(faction_id, _rep[faction_id], livello(faction_id))


# --- Comportamenti automatici (dai dati) --------------------------

## Un evento tracciato: se una fazione dichiara un blocco 'sospetto' che lo
## nomina e siamo nella sua regione, la reputazione sale del delta.
func _su_evento(nome: String, _dati: Dictionary) -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	var regione: String = str(ws.call("regione_corrente")) if ws != null else ""
	for f in _factions():
		var s: Variant = (f as Dictionary).get("sospetto")
		if typeof(s) != TYPE_DICTIONARY:
			continue
		if str(s.get("evento")) == nome and str(s.get("regione")) == regione:
			modifica(str((f as Dictionary).get("id", "")), float(s.get("delta", 0.0)), "sospetto")


## Un potere eseguito dal GIOCATORE: ogni fazione con 'reazione_al_potere' il
## cui membro e' presente nella location_tag del giocatore perde reputazione.
func _su_abilita(_ability_id: String, caster: Node, _result: Dictionary) -> void:
	if caster == null or not caster.is_in_group("player"):
		return
	var ns: Node = get_node_or_null("/root/NpcSystem")
	var ws: Node = get_node_or_null("/root/WorldState")
	if ns == null or ws == null:
		return
	var presenti: Dictionary = ns.call("presenti", str(ws.call("regione_corrente")))
	var mia_zona: String = str(ws.call("zona_corrente"))
	for f in _factions():
		var r: Variant = (f as Dictionary).get("reazione_al_potere")
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var membro: String = str(r.get("membro", ""))
		if presenti.has(membro) and str(presenti[membro]) == mia_zona and not mia_zona.is_empty():
			modifica(str((f as Dictionary).get("id", "")), float(r.get("delta", 0.0)), "potere_visto")


## Dopo un modifica: se una fazione dichiara un blocco 'sospetto' e la sua
## reputazione ha raggiunto la soglia, scrive il flag (una volta, KnowledgeStore
## e' un set).
func _applica_soglie(faction_id: String) -> void:
	var s: Variant = _faction(faction_id).get("sospetto")
	if typeof(s) != TYPE_DICTIONARY:
		return
	if reputazione(faction_id) >= float(s.get("soglia", 0.0)):
		var ks: Node = get_node_or_null("/root/KnowledgeStore")
		if ks != null:
			ks.call("imposta", str(s.get("flag", "")), true)


# --- Dati ---------------------------------------------------------

func _factions() -> Array:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("get_factions") if gd != null else []


func _faction(id: String) -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("get_faction", id) if gd != null else {}


# --- Salvataggio (mondo.reputazione, US-615; nessun bump) --------

func per_salvataggio() -> Dictionary:
	return _rep.duplicate()


func da_salvataggio(raw: Variant) -> void:
	_rep = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for id in (raw as Dictionary):
		if typeof(id) == TYPE_STRING and typeof(raw[id]) in [TYPE_FLOAT, TYPE_INT]:
			_rep[id] = float(raw[id])


func pulisci() -> void:
	_rep.clear()
