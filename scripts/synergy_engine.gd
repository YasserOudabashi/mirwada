extends Node
## Il motore delle sinergie (fase 4). Legge SynergySources.tag_sinergia_globali()
## e decide quali sinergie sono ATTIVE — richiede_tag tutti soddisfatti, nessun
## esclude_tag presente.
##
## US-401: solo la risoluzione tag -> insieme attivo. Gli EFFETTI
## (modifica_stat, modifica_follia, ...) li applicano US-403..405; la
## rivalutazione reattiva coi segnali e' US-402; anti-sinergie US-407.
##
## E' l'UNICO sistema che conosce le regole di sinergia. Nessuna fonte le
## conosce, nessun if per una sinergia specifica.
##
## NIENTE class_name: coerente col resto del progetto.

## Solo per i test: se non vuoto, sostituisce SynergySources.tag_sinergia_globali().
var _tag_override: Dictionary = {}


func _gd() -> Node:
	return get_node_or_null("/root/GameData")


## { tag: conteggio } di tutto cio' che il giocatore porta. Da SynergySources,
## o dall'override nei test.
func tag_globali() -> Dictionary:
	if not _tag_override.is_empty():
		return _tag_override.duplicate()
	var ss: Node = get_node_or_null("/root/SynergySources")
	return (ss.call("tag_sinergia_globali") as Dictionary) if ss != null else {}


## Gli id delle sinergie soddisfatte dai tag correnti, in ordine lessicografico.
func attive() -> Array:
	if _gd() == null:
		return []
	var tg: Dictionary = tag_globali()
	var out: Array = []
	for id in _gd().call("synergy_ids"):
		if _soddisfatta(_gd().call("get_synergy", id), tg):
			out.append(str(id))
	out.sort()
	return out


func e_attiva(id: String) -> bool:
	return attive().has(id)


## { tag: quanti ne mancano } per completare la sinergia. {} se gia' soddisfatta
## o id ignoto. Usato dalla UI del registro (US-409/410).
func tag_mancanti(id: String) -> Dictionary:
	var syn: Dictionary = _gd().call("get_synergy", id) if _gd() != null else {}
	if syn.is_empty():
		return {}
	var tg: Dictionary = tag_globali()
	var out: Dictionary = {}
	for t in syn.get("richiede_tag", {}):
		var manca: int = int(syn["richiede_tag"][t]) - int(tg.get(t, 0))
		if manca > 0:
			out[str(t)] = manca
	return out


func pulisci() -> void:
	_tag_override = {}


# --- Interno --------------------------------------------------------

func _soddisfatta(syn: Dictionary, tg: Dictionary) -> bool:
	if syn.is_empty():
		return false
	for t in syn.get("richiede_tag", {}):
		if int(tg.get(t, 0)) < int(syn["richiede_tag"][t]):
			return false
	for t in syn.get("esclude_tag", {}):
		if int(tg.get(t, 0)) >= int(syn["esclude_tag"][t]):
			return false
	return true


# --- Solo test -----------------------------------------------------

## Sostituisce la lettura di SynergySources con un set di tag fisso.
func imposta_override_tag(d: Dictionary) -> void:
	_tag_override = d.duplicate(true)
