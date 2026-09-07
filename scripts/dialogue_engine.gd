extends Node
## US-613 — il motore dei dialoghi: legge un grafo a nodi di data/dialogues/,
## valuta le condizioni di ogni scelta (nasconde quelle non disponibili),
## applica gli effetti di una scelta e segue il goto. Il MONDO SI FERMA durante
## un dialogo (TimeSystem.imposta_pausa).
##
## Le condizioni riusano il vocabolario condiviso (scripts/conditions.gd, FR-3):
## un dialogo che si apre solo di notte usa la stessa condizione di un'abilita'
## notturna. Gli effetti sono un vocabolario CHIUSO di 5 voci - niente scripting
## libero: se un dialogo sembra chiedere un effetto nuovo, e' un flag + una quest.
##
## Nessuna pagina del libro qui (page_dialogo = US-613b): l'engine e' agnostico
## dalla UI, emette segnali che una pagina ascoltera'.
##
## NIENTE class_name: coerente col resto del progetto.

signal dialogo_avviato(dialogue_id: String)
signal nodo_cambiato(node_id: String)
signal dialogo_finito(dialogue_id: String)
signal apri_vendita(npc_id: String)
signal avvia_quest(quest_id: String)

const Conditions := preload("res://scripts/conditions.gd")
const EFFETTI := ["emit_event", "flag", "reputazione", "apri_vendita", "avvia_quest"]

var _dialogo: Dictionary = {}
var _dialogue_id: String = ""
var _interlocutore: String = ""   # l'NPC con cui si parla (per npc_influenced)
var _nodo_id: String = ""


## Avvia un dialogo. interlocutore_id = l'NPC toccato (i dlg_generic sono
## condivisi: e' lui a essere influenzato, non lo speaker nei dati). false se
## il dialogo non esiste o non ha il nodo di start.
func avvia(dialogue_id: String, interlocutore_id: String = "") -> bool:
	var gd: Node = get_node_or_null("/root/GameData")
	var doc: Dictionary = gd.call("get_dialogue", dialogue_id) if gd != null else {}
	var start: String = str(doc.get("start", ""))
	if doc.is_empty() or not (doc.get("nodes", {}) as Dictionary).has(start):
		return false
	_dialogo = doc
	_dialogue_id = dialogue_id
	_interlocutore = interlocutore_id
	_nodo_id = start
	_ferma_il_mondo(true)
	dialogo_avviato.emit(dialogue_id)
	nodo_cambiato.emit(_nodo_id)
	return true


func in_corso() -> bool:
	return not _nodo_id.is_empty()


func dialogue_id() -> String:
	return _dialogue_id


## L'NPC con cui si sta parlando (per la UI: i dlg_generic hanno uno speaker
## fisso nei dati, ma a schermo va il nome dell'interlocutore vero).
func interlocutore() -> String:
	return _interlocutore


## Il nodo corrente grezzo ({} fuori da un dialogo).
func nodo_corrente() -> Dictionary:
	return (_dialogo.get("nodes", {}) as Dictionary).get(_nodo_id, {}) if in_corso() else {}


## Le scelte del nodo corrente le cui condizioni sono TUTTE soddisfatte, con
## l'indice originale (serve alla UI e a scegli()).
func scelte_valide() -> Array:
	var out: Array = []
	var choices: Array = nodo_corrente().get("choices", [])
	for i in choices.size():
		var c: Dictionary = choices[i]
		if Conditions.tutte_soddisfatte(c.get("condizioni", [])):
			out.append({"indice": i, "text_i18n": str(c.get("text_i18n", ""))})
	return out


## Sceglie la i-esima scelta VALIDA (l'indice di scelte_valide, non del nodo).
## Applica gli effetti, poi segue il goto; goto null/assente -> fine dialogo.
func scegli(indice_valido: int) -> bool:
	var valide: Array = scelte_valide()
	if indice_valido < 0 or indice_valido >= valide.size():
		return false
	var choice: Dictionary = nodo_corrente().get("choices", [])[int(valide[indice_valido]["indice"])]
	for eff in choice.get("effetti", []):
		_applica_effetto(eff)
	var goto: Variant = choice.get("goto")
	if typeof(goto) == TYPE_STRING and (_dialogo.get("nodes", {}) as Dictionary).has(goto):
		_nodo_id = str(goto)
		nodo_cambiato.emit(_nodo_id)
	else:
		termina()
	return true


func termina() -> void:
	if _nodo_id.is_empty():
		return
	var chiuso: String = _dialogue_id
	_dialogo = {}
	_dialogue_id = ""
	_interlocutore = ""
	_nodo_id = ""
	_ferma_il_mondo(false)
	dialogo_finito.emit(chiuso)


# --- Effetti (vocabolario chiuso di 5) -------------------------------

func _applica_effetto(eff: Variant) -> void:
	if typeof(eff) != TYPE_DICTIONARY:
		return
	var e: Dictionary = eff
	match str(e.get("tipo", "")):
		"emit_event":
			var evento: String = str(e.get("evento", ""))
			var modo: String = str(e.get("modo", ""))
			# npc_influenced passa da NpcSystem (aggiorna la memoria dell'NPC
			# toccato ed emette l'evento). Gli altri dei 12: EventTracker diretto.
			if evento == "npc_influenced" and not _interlocutore.is_empty():
				var ns: Node = get_node_or_null("/root/NpcSystem")
				if ns != null:
					ns.call("influenza", _interlocutore, modo)
					return
			var et: Node = get_node_or_null("/root/EventTracker")
			if et != null:
				var dati: Dictionary = {}
				if not modo.is_empty():
					dati["modo"] = modo
				et.call("emit_event", evento, dati)
		"flag":
			var ks: Node = get_node_or_null("/root/KnowledgeStore")
			if ks != null:
				ks.call("imposta", str(e.get("id", "")), bool(e.get("valore", true)))
		"reputazione":
			# US-615: FactionSystem non esiste ancora -> no-op.
			var fs: Node = get_node_or_null("/root/FactionSystem")
			if fs != null:
				fs.call("modifica", str(e.get("faction_id", "")), float(e.get("delta", 0.0)), "dialogo")
		"apri_vendita":
			apri_vendita.emit(str(e.get("npc_id", _interlocutore)))
		"avvia_quest":
			# US-616: QuestSystem non esiste ancora -> il segnale resta per la UI.
			var qs: Node = get_node_or_null("/root/QuestSystem")
			if qs != null:
				qs.call("avvia", str(e.get("quest_id", "")))
			avvia_quest.emit(str(e.get("quest_id", "")))


func _ferma_il_mondo(fermo: bool) -> void:
	var ts: Node = get_node_or_null("/root/TimeSystem")
	if ts != null:
		ts.call("imposta_pausa", fermo)
