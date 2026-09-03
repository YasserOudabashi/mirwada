extends Node
## Stato di progressione del giocatore: quale Pathway sta percorrendo e a
## quale Sequenza e' arrivato. Fonte unica per ogni sistema di fase 2
## (Acting, pozioni, follia, rituale, diagramma del libro).
##
## Regola n.1 del progetto e FR-1: NIENTE nome di Pathway o Sequenza qui
## dentro. Solo `pathway_id` (una chiave dei dati) e il numero di Sequenza.
## Il Pathway di partenza vive in data/balance.json [progressione], non nel
## codice: il flag SERIAL_NUMBERS_FILED_OFF deve poter rinominare tutto
## sostituendo file di dati.
##
## I `stat_modifiers` della Sequenza corrente sono applicati allo
## StatsComponent del giocatore come un modificatore per id (US-007), con id
## "sequence:<n>": a ogni avanzamento il vecchio si rimuove e il nuovo si
## applica, senza sapere nulla degli altri buff attivi.
##
## NIENTE class_name: coerente col resto del progetto (i test usano preload).

signal sequence_changed(nuova: int, vecchia: int)

## Sequenza 9 = la piu' bassa, dove comincia ogni personaggio; 0 = Vero Dio.
const _SEQ_FALLBACK := 9
const _PATHWAY_FALLBACK := ""

var _pathway_id: String = ""
var _sequence: int = _SEQ_FALLBACK


func _ready() -> void:
	# Partenza da partita nuova: i default vengono dai dati. Un load successivo
	# chiama da_salvataggio() e sovrascrive.
	if _pathway_id.is_empty():
		_pathway_id = _pathway_default()
	_applica_modificatori(-1, _sequence)


# --- Lettura (sola lettura, come da criterio) -------------------------------

func pathway() -> String:
	return _pathway_id


func sequence() -> int:
	return _sequence


## tier ("low"/"mid"/... ) derivato dai dati della Sequenza corrente, mai
## calcolato qui. "" se la Sequenza non esiste nei dati.
func tier() -> String:
	return str(sequence_data().get("tier", ""))


## Voce grezza della Sequenza corrente da GameData. {} se non risolve.
func sequence_data() -> Dictionary:
	return _sequenza_di(_pathway_id, _sequence)


func stat_modifiers() -> Dictionary:
	var m: Variant = sequence_data().get("stat_modifiers")
	return m if typeof(m) == TYPE_DICTIONARY else {}


# --- Mutazione -------------------------------------------------------------

## Imposta Pathway e Sequenza in un colpo: creazione personaggio, load,
## debug e test. Non emette sequence_changed (non e' un avanzamento giocato).
func configura(pathway_id: String, sequenza: int) -> void:
	var prima: int = _sequence
	_pathway_id = pathway_id if not pathway_id.is_empty() else _pathway_default()
	_sequence = clampi(sequenza, 0, 9)
	_applica_modificatori(prima, _sequence)


## Avanza di una Sequenza (9 -> 8 -> ... -> 0). true se e' avvenuto.
## Chi decide SE si puo' avanzare e' PotionSystem/RitualSystem (US-209/217):
## qui si esegue e basta.
func avanza() -> bool:
	if _sequence <= 0:
		return false
	var vecchia: int = _sequence
	_sequence -= 1
	_applica_modificatori(vecchia, _sequence)
	sequence_changed.emit(_sequence, vecchia)
	return true


# --- Salvataggio ---------------------------------------------------------

## Forma serializzata nel save (GameState la infila in "progressione").
func per_salvataggio() -> Dictionary:
	return {"pathway_id": _pathway_id, "sequence": _sequence}


## Rilettura NON FIDATA: ogni campo con typeof() + default sano, come il
## resto del save (design-master cap. 3.1). Un "progressione" vuoto ({},
## come lo lascia la migrazione da fase 1) ricade sui default dei dati.
func da_salvataggio(raw: Variant) -> void:
	var d: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var pid: Variant = d.get("pathway_id", "")
	var pathway_id: String = str(pid) if typeof(pid) == TYPE_STRING else ""

	var sv: Variant = d.get("sequence", _SEQ_FALLBACK)
	var seq: int = _SEQ_FALLBACK
	if typeof(sv) == TYPE_FLOAT or typeof(sv) == TYPE_INT:
		seq = clampi(int(sv), 0, 9)

	configura(pathway_id, seq)


## Riapplica i modificatori della Sequenza corrente al giocatore. Il player
## la chiama in _ready(): se e' entrato in scena DOPO il load (ordine di
## autoload/scene) altrimenti si perderebbe i bonus di Sequenza.
func riapplica_al_giocatore() -> void:
	_applica_modificatori(-1, _sequence)


# --- Interno -----------------------------------------------------------

func _applica_modificatori(vecchia: int, nuova: int) -> void:
	var stats: Node = _stats_giocatore()
	if stats == null:
		return
	if vecchia >= 0 and vecchia != nuova:
		stats.call("remove_modifier", _mod_id(vecchia))
	stats.call("apply_modifier", _mod_id(nuova), stat_modifiers())


func _mod_id(seq: int) -> String:
	return "sequence:%d" % seq


func _stats_giocatore() -> Node:
	var p: Node = get_tree().get_first_node_in_group("player")
	return p.get_node_or_null("StatsComponent") if p != null else null


func _sequenza_di(pathway_id: String, seq: int) -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null or pathway_id.is_empty():
		return {}
	return gd.call("get_sequence", "%s_%d" % [pathway_id, seq])


func _pathway_default() -> String:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return _PATHWAY_FALLBACK
	return str(gd.call("get_balance", "progressione").get("pathway_default", _PATHWAY_FALLBACK))
