extends Node
## Talenti posseduti dal giocatore (US-331). Gli innati entrano alla
## creazione del personaggio (US-332, concedi()); gli acquisiti si
## sbloccano da soli quando il conteggio del loro sblocco.evento raggiunge
## il target - un solo listener sui segnali generici di EventTracker E
## TalentTracker (i due vocabolari da cui sblocco.evento puo' pescare,
## US-330), nessun rilevatore scritto a mano per talento.
##
## NIENTE class_name: coerente col resto del progetto.

signal talento_sbloccato(id: String)

var _posseduti: Array = []   # [id]


func _ready() -> void:
	var et: Node = get_node_or_null("/root/EventTracker")
	if et != null and et.has_signal("evento_emesso"):
		et.evento_emesso.connect(_su_evento)
	var tt: Node = get_node_or_null("/root/TalentTracker")
	if tt != null and tt.has_signal("comportamento_emesso"):
		tt.comportamento_emesso.connect(_su_evento)


func posseduti() -> Array:
	return _posseduti.duplicate()


func possiede(id: String) -> bool:
	return _posseduti.has(id)


## Somma degli effetti sblocco_sistema con quella chiave, fra i talenti
## posseduti. Cosi' PotionSystem/Forge/PetSystem leggono un bonus di
## talento senza sapere quale talento specifico lo dia (US-310/311/316/322).
func bonus_int(chiave: String) -> int:
	var tot: int = 0
	for id in _posseduti:
		var eff: Dictionary = _def(id).get("effetto", {})
		if str(eff.get("tipo", "")) == "sblocco_sistema" and str(eff.get("chiave", "")) == chiave:
			tot += int(eff.get("valore", 0))
	return tot


## Tag dei tag_grant dei talenti posseduti (US-334: fonte per il motore
## sinergie).
func tag_attivi() -> Dictionary:
	var out: Dictionary = {}
	for id in _posseduti:
		var eff: Dictionary = _def(id).get("effetto", {})
		if str(eff.get("tipo", "")) == "tag_grant" and eff.has("tag"):
			var t: String = str(eff["tag"])
			out[t] = int(out.get(t, 0)) + 1
	return out


## Concede un talento (innato alla creazione, US-332; o un acquisito gia'
## sbloccato da _su_evento). false se non esiste o e' gia' posseduto.
func concedi(id: String) -> bool:
	if _posseduti.has(id) or _def(id).is_empty():
		return false
	_posseduti.append(id)
	_applica_effetto(id)
	talento_sbloccato.emit(id)
	return true


func riapplica_al_giocatore() -> void:
	for id in _posseduti:
		_applica_effetto(id)


func pulisci() -> void:
	for id in _posseduti:
		_rimuovi_effetto(id)
	_posseduti.clear()


# --- Salvataggio -----------------------------------------------------

func per_salvataggio() -> Dictionary:
	return {"posseduti": _posseduti.duplicate()}


## NON FIDATO: scarta id ignoti o duplicati. Non riapplica gli effetti da
## solo (come Equipment/Progression: chi carica chiama riapplica_al_giocatore
## quando il giocatore e' in scena).
func da_salvataggio(raw: Variant) -> void:
	pulisci()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var lista: Variant = (raw as Dictionary).get("posseduti", [])
	if typeof(lista) != TYPE_ARRAY:
		return
	for id in lista:
		if typeof(id) == TYPE_STRING and not _def(id).is_empty() and not _posseduti.has(id):
			_posseduti.append(id)


# --- Sblocco automatico degli acquisiti ---------------------------------

func _su_evento(_nome: String, _dati: Dictionary) -> void:
	for t in _gd().call("talents_per_tipo", "acquisito"):
		var d: Dictionary = t
		var id: String = str(d.get("id", ""))
		if _posseduti.has(id):
			continue
		if _sblocco_raggiunto(d.get("sblocco", {})):
			concedi(id)


func _sblocco_raggiunto(sblocco: Dictionary) -> bool:
	if sblocco.is_empty():
		return false
	return _conteggio_sblocco(sblocco) >= float(sblocco.get("target", 0))


## Conteggio corrente verso uno sblocco, pescando dal vocabolario giusto
## (EventTracker o TalentTracker, US-330). Estratto da _sblocco_raggiunto
## perche' la UI (US-333) deve poter mostrare lo stesso numero in una barra
## di progresso, non solo il booleano "raggiunto o no".
func _conteggio_sblocco(sblocco: Dictionary) -> float:
	var evento: String = str(sblocco.get("evento", ""))
	var filtri: Dictionary = sblocco.get("filtri", {})
	var gd: Node = _gd()
	if gd == null:
		return 0.0
	if not (gd.call("get_tracked_event", evento) as Dictionary).is_empty():
		var et: Node = get_node_or_null("/root/EventTracker")
		return et.call("count", evento, filtri) if et != null else 0.0
	var tt: Node = get_node_or_null("/root/TalentTracker")
	return tt.call("count", evento, filtri) if tt != null else 0.0


## Progresso verso lo sblocco di un acquisito non ancora posseduto (US-333,
## per la barra di progresso della pagina Talenti). {} se id non esiste o
## non e' un acquisito.
func progresso(id: String) -> Dictionary:
	var t: Dictionary = _def(id)
	if t.is_empty() or str(t.get("tipo", "")) != "acquisito":
		return {}
	var sblocco: Dictionary = t.get("sblocco", {})
	return {"conteggio": _conteggio_sblocco(sblocco), "target": float(sblocco.get("target", 0))}


# --- Interno -----------------------------------------------------------

## Applica l'effetto E' solo per stat_modifier: tag_grant/sblocco_sistema
## si leggono da tag_attivi()/bonus_int(), non sono un modificatore.
func _applica_effetto(id: String) -> void:
	var eff: Dictionary = _def(id).get("effetto", {})
	if str(eff.get("tipo", "")) != "stat_modifier":
		return
	var stats: Node = _stats()
	if stats == null:
		return
	var stat: String = str(eff.get("stat", ""))
	var valore: float = float(eff.get("valore", 0.0))
	var delta: float = valore
	if bool(eff.get("moltiplicativo", false)):
		delta = float(stats.call("get_base", stat)) * valore
	stats.call("apply_modifier", "talent:" + id, {stat: delta})


func _rimuovi_effetto(id: String) -> void:
	var eff: Dictionary = _def(id).get("effetto", {})
	if str(eff.get("tipo", "")) != "stat_modifier":
		return
	var stats: Node = _stats()
	if stats != null:
		stats.call("remove_modifier", "talent:" + id)


func _def(id: String) -> Dictionary:
	var gd: Node = _gd()
	return gd.call("get_talent", id) if gd != null else {}


func _stats() -> Node:
	var p: Node = get_tree().get_first_node_in_group("player")
	return p.get_node_or_null("StatsComponent") if p != null else null


func _gd() -> Node:
	return get_node_or_null("/root/GameData")
