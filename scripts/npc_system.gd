extends Node
## US-612 — lo stato vivo degli NPC: chi il giocatore ha incontrato, come li ha
## influenzati (il contatore per modo di npc_influenced), quali candidati Ancora
## sono diventati Ancore. I DATI degli NPC (schedule, faction, vendor) stanno in
## data/npc/roster.json via GameData; qui c'e' solo cio' che cambia giocando.
##
## Contratti gia' vivi nei dati che questo sistema onora (design-npc-quest 2):
##  - i sussurri di follia a soglia 55 pronunciano i nomi degli NPC incontrati
##    e delle Ancore -> AudioManager.nomi_sussurro li prende da qui;
##  - tg_6_giuramento (aiuta 8) / fool_9_inganno (inganna 10) contano
##    npc_influenced: influenza() lo emette sull'EventTracker.
##
## NIENTE class_name: coerente col resto del progetto.

signal npc_influenzato(id: String, modo: String)
signal npc_conosciuto(id: String)

## I 5 modi di npc_influenced (data/schema/tracked_events.json). Un modo fuori
## lista non viene registrato ne' emesso.
const MODI := ["persuaso", "ingannato", "aiutato", "intimidito", "risparmiato"]

var _conosciuti: Array = []          # id degli NPC incontrati, in ordine
var _memoria: Dictionary = {}        # id -> { modo: conteggio }
var _ancore: Array = []              # anchor_candidate diventati Ancore


## Il giocatore ha incrociato un NPC: entra fra i conosciuti (i sussurri lo
## pronunceranno). Idempotente.
func incontra(id: String) -> void:
	if id.is_empty() or id in _conosciuti or _npc(id).is_empty():
		return
	_conosciuti.append(id)
	_aggiorna_sussurri()
	npc_conosciuto.emit(id)


func conosciuti() -> Array:
	return _conosciuti.duplicate()


func conosce(id: String) -> bool:
	return id in _conosciuti


## Aggiorna la memoria dell'NPC (contatore per modo) ed emette npc_influenced
## sull'EventTracker con { modo } - lo stesso evento che l'Acting Method conta.
## Chi non e' ancora fra i conosciuti ci entra ora. false se modo/id non validi.
func influenza(id: String, modo: String) -> bool:
	if modo not in MODI or _npc(id).is_empty():
		return false
	incontra(id)
	var mem: Dictionary = _memoria.get(id, {})
	mem[modo] = int(mem.get(modo, 0)) + 1
	_memoria[id] = mem
	var et: Node = get_node_or_null("/root/EventTracker")
	if et != null:
		et.call("emit_event", "npc_influenced", {"modo": modo})
	npc_influenzato.emit(id, modo)
	return true


## Il contatore per modo di un NPC ({} se mai influenzato).
func memoria(id: String) -> Dictionary:
	return (_memoria.get(id, {}) as Dictionary).duplicate()


## Un gate di tipo "npc" (US-611): il giocatore ha influenzato l'NPC in QUEL
## modo almeno una volta. valore = "<id>:<modo>" oppure solo "<id>".
func ha_influenza(valore: String) -> bool:
	var parti: PackedStringArray = valore.split(":")
	var id: String = parti[0] if parti.size() > 0 else ""
	if parti.size() >= 2:
		return int(memoria(id).get(parti[1], 0)) > 0
	return not memoria(id).is_empty()


# --- Ancore -----------------------------------------------------------

## Un anchor_candidate del roster e' diventato un'Ancora del giocatore.
func promuovi_ancora(id: String) -> bool:
	if id in _ancore or not bool(_npc(id).get("anchor_candidate", false)):
		return false
	_ancore.append(id)
	_aggiorna_sussurri()
	return true


func ancore_attive() -> Array:
	return _ancore.duplicate()


# --- Presenza in scena (schedule + momento corrente) -----------------

## Gli NPC presenti ORA nella regione data e nel momento corrente di TimeSystem:
## id -> location_tag. Uno schedule senza voce per il momento, o con
## location_tag null, = "non in scena" (Bruno di giorno).
func presenti(region_id: String) -> Dictionary:
	var ts: Node = get_node_or_null("/root/TimeSystem")
	var momento: String = str(ts.call("momento")) if ts != null else "alba"
	var out: Dictionary = {}
	for n in _roster():
		if str((n as Dictionary).get("region_id", "")) != region_id:
			continue
		var tag: Variant = _tag_per_momento(n, momento)
		if typeof(tag) == TYPE_STRING and not (tag as String).is_empty():
			out[str((n as Dictionary).get("id", ""))] = tag
	return out


func _tag_per_momento(npc: Dictionary, momento: String) -> Variant:
	for voce in npc.get("schedule", []):
		if typeof(voce) == TYPE_DICTIONARY and str((voce as Dictionary).get("momento", "")) == momento:
			return (voce as Dictionary).get("location_tag")
	return null


# --- Sussurri (i nomi che la follia pronuncia, US-214) ---------------

## Le chiavi i18n dei nomi da dare ad AudioManager: conosciuti + Ancore.
func nomi_i18n() -> Array:
	var out: Array = []
	for id in _conosciuti + _ancore:
		var k: String = str(_npc(str(id)).get("name_i18n", ""))
		if not k.is_empty() and k not in out:
			out.append(k)
	return out


func _aggiorna_sussurri() -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("imposta_nomi_npc"):
		am.call("imposta_nomi_npc", nomi_i18n())


# --- Dati (roster.json) ---------------------------------------------

func _roster() -> Array:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("get_npcs") if gd != null else []


func _npc(id: String) -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("get_npc", id) if gd != null else {}


# --- Salvataggio (mondo.npc, US-612; nessun bump: US-602 e' l'unico) ---

func per_salvataggio() -> Dictionary:
	return {
		"conosciuti": _conosciuti.duplicate(),
		"memoria": _memoria.duplicate(true),
		"ancore": _ancore.duplicate(),
	}


## Rilettura NON FIDATA: conosciuti/ancore solo stringhe; memoria solo
## { str: { modo valido: int } }. Le voci malformate si scartano.
func da_salvataggio(raw: Variant) -> void:
	_conosciuti = []
	_memoria = {}
	_ancore = []
	var d: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	_conosciuti = _solo_stringhe(d.get("conosciuti"))
	_ancore = _solo_stringhe(d.get("ancore"))
	var mem: Variant = d.get("memoria")
	if typeof(mem) == TYPE_DICTIONARY:
		for id in (mem as Dictionary):
			if typeof(id) != TYPE_STRING or typeof(mem[id]) != TYPE_DICTIONARY:
				continue
			var per_modo: Dictionary = {}
			for modo in (mem[id] as Dictionary):
				if modo in MODI and typeof((mem[id] as Dictionary)[modo]) in [TYPE_INT, TYPE_FLOAT]:
					per_modo[modo] = int((mem[id] as Dictionary)[modo])
			if not per_modo.is_empty():
				_memoria[id] = per_modo
	_aggiorna_sussurri()


func pulisci() -> void:
	_conosciuti.clear()
	_memoria.clear()
	_ancore.clear()
	_aggiorna_sussurri()


func _solo_stringhe(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for v in raw:
		if typeof(v) == TYPE_STRING and not out.has(v):
			out.append(v)
	return out
