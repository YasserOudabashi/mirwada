extends Node
## Stato di partita corrente: il minimo che va nel save. Tiene il tempo di
## gioco e il nome del personaggio (default da design-lore.md, cambiabile
## alla creazione personaggio quando esistera'), e sa assemblare/riapplicare
## uno snapshot per SaveSystem.
##
## F9 salva, F10 carica lo slot 0 — solo in debug, finche' non c'e' la UI a
## libro (design-ui-libro.md).
##
## NIENTE class_name: coerente col progetto.

const SLOT_RAPIDO := 0
const NOME_DEFAULT := "Enel"

signal partita_iniziata(nome: String)

var nome_personaggio: String = NOME_DEFAULT
var tempo_gioco: float = 0.0
## false al boot (sei sul menu del libro), true dopo nuova_partita()/carica_slot().
var _partita_attiva: bool = false
## Slot su cui gira la partita corrente (-1 = nessuno).
var _slot_corrente: int = -1


func _process(delta: float) -> void:
	tempo_gioco += delta


func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F9:
		var r: Dictionary = salva_rapido()
		print("[GameState] salvataggio rapido: ", "ok" if r.get("ok") else r.get("reason"))
	elif key.keycode == KEY_F10:
		var r: Dictionary = carica_rapido()
		print("[GameState] caricamento rapido: ", "ok" if r.get("ok") else r.get("reason"))


func _progression() -> Node:
	return get_node_or_null("/root/Progression")


func _world() -> Node:
	return get_node_or_null("/root/WorldState")


func _summons() -> Node:
	return get_node_or_null("/root/SummonRegistry")


func _strutture() -> Node:
	return get_node_or_null("/root/StructureRegistry")


func _pet() -> Node:
	return get_node_or_null("/root/PetSystem")


func _base() -> Node:
	return get_node_or_null("/root/BaseSystem")


func _talenti() -> Node:
	return get_node_or_null("/root/TalentSystem")


func _sinergie() -> Node:
	return get_node_or_null("/root/SynergyEngine")


func _talent_tracker() -> Node:
	return get_node_or_null("/root/TalentTracker")


func _eventi() -> Node:
	return get_node_or_null("/root/EventTracker")


func _acting() -> Node:
	return get_node_or_null("/root/Acting")


func _caratteristiche() -> Node:
	return get_node_or_null("/root/CharacteristicStore")


func _follia() -> Node:
	return get_node_or_null("/root/Madness")


func _fondamenta() -> Node:
	return get_node_or_null("/root/Foundation")


func _ancore() -> Node:
	return get_node_or_null("/root/AnchorSystem")


func _rituale() -> Node:
	return get_node_or_null("/root/RitualSystem")


func _conoscenza() -> Node:
	return get_node_or_null("/root/KnowledgeStore")


func _inventario() -> Node:
	return get_node_or_null("/root/Inventory")


func _equip() -> Node:
	return get_node_or_null("/root/Equipment")


func salva_rapido() -> Dictionary:
	return salva_slot(SLOT_RAPIDO)


func carica_rapido() -> Dictionary:
	return carica_slot(SLOT_RAPIDO)


## Salva la partita corrente sullo slot indicato (US-223).
func salva_slot(slot: int) -> Dictionary:
	var r: Dictionary = get_node("/root/SaveSystem").call("salva", slot, snapshot())
	if r.get("ok", false):
		_slot_corrente = slot
	return r


## Carica lo slot e applica lo stato. La partita diventa attiva (US-223).
func carica_slot(slot: int) -> Dictionary:
	var r: Dictionary = get_node("/root/SaveSystem").call("carica", slot)
	if r.get("ok", false):
		applica(r["dati"])
		_partita_attiva = true
		_slot_corrente = slot
		partita_iniziata.emit(nome_personaggio)
	return r


## Creazione personaggio (US-223): fissa il nome, riparte da zero, salva sullo
## slot scelto. Il Pathway/Sequenza di partenza vengono dai dati (Progression).
## talenti_innati (US-332): id di talenti 'innato' scelti alla creazione — solo
## quelli veri entrano in TalentSystem, il resto e' ignorato.
func nuova_partita(nome: String, slot: int, talenti_innati: Array = []) -> Dictionary:
	nome_personaggio = nome.strip_edges() if not nome.strip_edges().is_empty() else NOME_DEFAULT
	tempo_gioco = 0.0
	_partita_attiva = true
	_slot_corrente = slot
	var ts: Node = _talenti()
	var gd: Node = get_node_or_null("/root/GameData")
	if ts != null:
		ts.call("pulisci")
		var maxn: int = 99
		if gd != null:
			maxn = int((gd.call("get_balance", "talenti") as Dictionary).get("innati_alla_creazione", 99))
		var presi: int = 0
		for tid in talenti_innati:
			if presi >= maxn:
				break
			var t: Dictionary = gd.call("get_talent", str(tid)) if gd != null else {}
			if str(t.get("tipo", "")) == "innato" and ts.call("concedi", str(tid)):
				presi += 1
	partita_iniziata.emit(nome_personaggio)
	return get_node("/root/SaveSystem").call("salva", slot, snapshot())


func partita_in_corso() -> bool:
	return _partita_attiva


func nome_default() -> String:
	return NOME_DEFAULT


func slot_corrente() -> int:
	return _slot_corrente


## Lo scaffale segna quale tomo si sta per iniziare; il frontespizio lo legge.
var _slot_scelto: int = 0


func scegli_slot(slot: int) -> void:
	_slot_scelto = slot


func slot_scelto() -> int:
	return _slot_scelto


## Raccoglie lo stato dal giocatore vivo. Se non c'e' un giocatore in scena,
## salva comunque nome e tempo.
func snapshot() -> Dictionary:
	var dati: Dictionary = {
		"nome_personaggio": nome_personaggio,
		"tempo_gioco": tempo_gioco,
		"posizione": Vector2.ZERO,
		"statistiche": {},
		"evocazioni": _summons().per_salvataggio() if _summons() != null else [],
		"progressione": _progression().per_salvataggio() if _progression() != null else {},
		"mondo": _world().per_salvataggio() if _world() != null else {},
		"eventi": _eventi().per_salvataggio() if _eventi() != null else {},
		"acting": _acting().per_salvataggio() if _acting() != null else {},
		"caratteristiche": _caratteristiche().per_salvataggio() if _caratteristiche() != null else [],
		"follia": _follia().per_salvataggio() if _follia() != null else {},
		"fondamenta": _fondamenta().per_salvataggio() if _fondamenta() != null else {},
		"ancore": _ancore().per_salvataggio() if _ancore() != null else [],
		"rituale": _rituale().per_salvataggio() if _rituale() != null else {},
		"strutture": _strutture().per_salvataggio() if _strutture() != null else [],
		"pet": _pet().per_salvataggio() if _pet() != null else {},
		"base": _base().per_salvataggio() if _base() != null else {},
		"talenti": {
			"posseduti": _talenti().per_salvataggio() if _talenti() != null else [],
			"comportamenti": _talent_tracker().per_salvataggio() if _talent_tracker() != null else {},
		},
		"sinergie": _sinergie().per_salvataggio() if _sinergie() != null else {},
		"conoscenza": _conoscenza().per_salvataggio() if _conoscenza() != null else [],
		"inventario": _inventario().per_salvataggio() if _inventario() != null else {},
		"equipaggiamento": _equip().per_salvataggio() if _equip() != null else {},
	}
	var p: Node = get_tree().get_first_node_in_group("player")
	if p is Node2D:
		dati["posizione"] = (p as Node2D).global_position
	var stats: Node = p.get_node_or_null("StatsComponent") if p != null else null
	if stats != null:
		dati["statistiche"] = {
			"hp": float(stats.get("hp")),
			"spiritualita": float(stats.get("spiritualita")),
		}
	return dati


func applica(dati: Dictionary) -> void:
	nome_personaggio = str(dati.get("nome_personaggio", NOME_DEFAULT))
	tempo_gioco = float(dati.get("tempo_gioco", 0.0))
	if _progression() != null:
		_progression().da_salvataggio(dati.get("progressione", {}))
	if _world() != null:
		_world().da_salvataggio(dati.get("mondo", {}))
	if _summons() != null:
		_summons().da_salvataggio(dati.get("evocazioni", []))
	if _eventi() != null:
		_eventi().da_salvataggio(dati.get("eventi", {}))
	# Acting DOPO progressione ed eventi: legge la Sequenza e i conteggi.
	if _acting() != null:
		_acting().da_salvataggio(dati.get("acting", {}))
	if _caratteristiche() != null:
		_caratteristiche().da_salvataggio(dati.get("caratteristiche", []))
	if _follia() != null:
		_follia().da_salvataggio(dati.get("follia", {}))
	if _fondamenta() != null:
		_fondamenta().da_salvataggio(dati.get("fondamenta", {}))
	if _ancore() != null:
		_ancore().da_salvataggio(dati.get("ancore", []))
	if _rituale() != null:
		_rituale().da_salvataggio(dati.get("rituale", {}))
	if _strutture() != null:
		_strutture().da_salvataggio(dati.get("strutture", []))
	if _pet() != null:
		_pet().da_salvataggio(dati.get("pet", {}))
	if _base() != null:
		_base().da_salvataggio(dati.get("base", {}))
	var tal: Dictionary = dati.get("talenti", {})
	if _talent_tracker() != null:
		_talent_tracker().da_salvataggio(tal.get("comportamenti", {}))
	# TalentSystem DOPO il tracker: riapplica gli effetti dei talenti posseduti.
	if _talenti() != null:
		_talenti().da_salvataggio(tal.get("posseduti", []))
	if _conoscenza() != null:
		_conoscenza().da_salvataggio(dati.get("conoscenza", []))
	if _inventario() != null:
		_inventario().da_salvataggio(dati.get("inventario", {}))
	# Equipment DOPO Inventory: le istanze equipaggiate non sono nello zaino.
	if _equip() != null:
		_equip().da_salvataggio(dati.get("equipaggiamento", {}))
	var p: Node = get_tree().get_first_node_in_group("player")
	if p is Node2D and dati.has("posizione"):
		(p as Node2D).global_position = dati["posizione"]
	var stats: Node = p.get_node_or_null("StatsComponent") if p != null else null
	var s: Dictionary = dati.get("statistiche", {})
	if stats != null and s.has("hp"):
		stats.set("hp", float(s["hp"]))
	# SynergyEngine PER ULTIMO: legge i tag di tutte le fonti gia' ripristinate.
	# Le sinergie ATTIVE si riderivano dai tag; il save porta solo le VISTE.
	if _sinergie() != null:
		_sinergie().da_salvataggio(dati.get("sinergie", {}))
		_sinergie().call("rivaluta")
		_sinergie().call("riapplica")
