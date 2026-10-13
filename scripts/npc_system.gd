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
## US-620: la Sequenza degli NPC che avanzano col tempo di gioco (Aldo, lo
## specchio). id -> numero di Sequenza. Nel save (mondo.npc).
var _seq_npc: Dictionary = {}
## Momenti di TimeSystem passati da quando NpcSystem e' vivo. TRANSITORIO.
var _momenti_contati: int = 0


func _ready() -> void:
	_collega_narrativa.call_deferred()


## US-620: gancio narrativo. Connesso in differita perche' RitualSystem e
## Progression possono non esistere ancora all'_init di NpcSystem.
func _collega_narrativa() -> void:
	var ts: Node = get_node_or_null("/root/TimeSystem")
	if ts != null and ts.has_signal("momento_cambiato") and not ts.momento_cambiato.is_connected(_su_momento):
		ts.momento_cambiato.connect(_su_momento)
	var rs: Node = get_node_or_null("/root/RitualSystem")
	if rs != null and rs.has_signal("rituale_completato") and not rs.rituale_completato.is_connected(_su_rituale):
		rs.rituale_completato.connect(_su_rituale)
	var prog: Node = get_node_or_null("/root/Progression")
	if prog != null and prog.has_signal("sequence_changed") \
			and not prog.sequence_changed.is_connected(_su_sequenza_giocatore):
		prog.sequence_changed.connect(_su_sequenza_giocatore)


func _su_momento(_m: String) -> void:
	_momenti_contati += 1
	for n in _roster():
		var av: Variant = (n as Dictionary).get("avanzamento_temporale")
		if typeof(av) != TYPE_DICTIONARY:
			continue
		var id: String = str((n as Dictionary).get("id", ""))
		var iniz: int = int(av.get("sequenza_iniziale", 9))
		var ogni: int = maxi(int(av.get("ogni_momenti", 8)), 1)
		var minima: int = int(av.get("sequenza_minima", 0))
		var attesa: int = maxi(iniz - int(_momenti_contati / ogni), minima)
		if attesa < int(_seq_npc.get(id, iniz)):
			_seq_npc[id] = attesa


func _su_rituale(sequenza: int) -> void:
	# design-npc-quest cap. 5: l'Atto I finisce quando "il primo rituale non
	# basta piu'" - il primo advancement_ritual di Sequenza <= 6.
	if sequenza <= 6:
		var ks: Node = get_node_or_null("/root/KnowledgeStore")
		if ks != null:
			ks.call("imposta", "atto_1_concluso", true)


func _su_sequenza_giocatore(nuova: int, vecchia: int) -> void:
	var prog: Node = get_node_or_null("/root/Progression")
	var gd: Node = get_node_or_null("/root/GameData")
	var ks: Node = get_node_or_null("/root/KnowledgeStore")
	if prog == null or gd == null or ks == null:
		return
	var pid: String = str(prog.call("pathway"))
	var t_nuova: String = str(gd.call("get_sequence", "%s_%d" % [pid, nuova]).get("tier", ""))
	var t_vecchia: String = str(gd.call("get_sequence", "%s_%d" % [pid, vecchia]).get("tier", ""))
	if t_nuova == t_vecchia or t_nuova.is_empty():
		return
	# un passaggio di tier: gli NPC "sfida_ai_tier" (Aldo) offrono il duello
	for n in _roster():
		if bool((n as Dictionary).get("sfida_ai_tier", false)):
			var corto: String = str((n as Dictionary).get("id", "")).trim_prefix("npc_")
			ks.call("imposta", "%s_duello_disponibile" % corto, true)


## La Sequenza corrente di un NPC che avanza col tempo (Aldo). Il default e'
## la sequenza_iniziale del suo avanzamento_temporale, o 9.
func sequenza_npc(id: String) -> int:
	var av: Variant = _npc(id).get("avanzamento_temporale")
	var iniz: int = int(av.get("sequenza_iniziale", 9)) if typeof(av) == TYPE_DICTIONARY else 9
	return int(_seq_npc.get(id, iniz))


## L'antagonista del Pathway del giocatore (data/lore/antagonisti.json). {} se
## non c'e' un Pathway o un antagonista per quel Pathway.
func antagonista_del_giocatore() -> Dictionary:
	var prog: Node = get_node_or_null("/root/Progression")
	var gd: Node = get_node_or_null("/root/GameData")
	if prog == null or gd == null:
		return {}
	return gd.call("get_antagonista", str(prog.call("pathway")))


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
		"seq_npc": _seq_npc.duplicate(),
	}


## Rilettura NON FIDATA: conosciuti/ancore solo stringhe; memoria solo
## { str: { modo valido: int } }. Le voci malformate si scartano.
func da_salvataggio(raw: Variant) -> void:
	_conosciuti = []
	_memoria = {}
	_ancore = []
	_seq_npc = {}
	var d: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	_conosciuti = _solo_stringhe(d.get("conosciuti"))
	_ancore = _solo_stringhe(d.get("ancore"))
	var sn: Variant = d.get("seq_npc")
	if typeof(sn) == TYPE_DICTIONARY:
		for id in (sn as Dictionary):
			if typeof(id) == TYPE_STRING and typeof(sn[id]) in [TYPE_INT, TYPE_FLOAT]:
				_seq_npc[id] = clampi(int(sn[id]), 0, 9)
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
	_seq_npc.clear()
	_momenti_contati = 0
	_aggiorna_sussurri()


func _solo_stringhe(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for v in raw:
		if typeof(v) == TYPE_STRING and not out.has(v):
			out.append(v)
	return out
