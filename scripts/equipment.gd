extends Node
## Equipaggiamento del giocatore (US-303). Legge le voci dallo zaino
## (Inventory) e le monta sui 4 slot di data/schema/equip_slots.json.
##
## Gli stat_modifiers dell'equip si applicano allo StatsComponent del
## giocatore come modificatore PER ID ("equip:<slot>", US-007): a ogni cambio
## il vecchio si rimuove e il nuovo si applica, senza sapere nulla degli altri
## bonus attivi.
##
## NIENTE class_name: coerente col resto del progetto.

signal equip_cambiato(slot: String)

## slot di aggancio -> { instance_id, item_id }
var _slot: Dictionary = {}


func _ready() -> void:
	# il player entra in scena dopo gli autoload: chiama lui
	# riapplica_al_giocatore() nel suo _ready (come Progression).
	pass


# --- API ---------------------------------------------------------------

func equipaggia(instance_id: String) -> bool:
	var inv: Node = _inv()
	if inv == null:
		return false
	var inst: Dictionary = inv.call("istanza", instance_id)
	if inst.is_empty():
		return false
	var item_id: String = str(inst.get("item_id", ""))
	var def: Dictionary = _def(item_id)
	if str(def.get("categoria", "")) != "equip":
		return false
	var mount: String = _mount_per(str(def.get("slot", "")))
	if mount.is_empty():
		return false
	if _slot.has(mount):
		rimuovi_slot(mount)
	inv.call("rimuovi_istanza", instance_id)
	_slot[mount] = {"instance_id": instance_id, "item_id": item_id}
	_applica_mod(mount)
	equip_cambiato.emit(mount)
	return true


func rimuovi_slot(mount: String) -> bool:
	if not _slot.has(mount):
		return false
	var e: Dictionary = _slot[mount]
	_rimuovi_mod(mount)
	_slot.erase(mount)
	var inv: Node = _inv()
	if inv != null:
		inv.call("restituisci_istanza", str(e.get("instance_id", "")), str(e.get("item_id", "")))
	equip_cambiato.emit(mount)
	return true


## Definizione dell'item nello slot, {} se vuoto.
func equipaggiato(mount: String) -> Dictionary:
	if not _slot.has(mount):
		return {}
	return _def(str(_slot[mount].get("item_id", "")))


func slot_pieni() -> Dictionary:
	var out: Dictionary = {}
	for m in _slot:
		out[m] = _slot[m].get("item_id", "")
	return out


## Tag degli item equipaggiati (US-306: fonte per il motore sinergie).
func tag_attivi() -> Dictionary:
	var out: Dictionary = {}
	for m in _slot:
		for t in _def(str(_slot[m].get("item_id", ""))).get("tag", []):
			out[t] = int(out.get(t, 0)) + 1
	return out


func riapplica_al_giocatore() -> void:
	for m in _slot:
		_applica_mod(m)


func pulisci() -> void:
	for m in _slot.keys():
		_rimuovi_mod(m)
	_slot.clear()


# --- Salvataggio -----------------------------------------------------

func per_salvataggio() -> Dictionary:
	return _slot.duplicate(true)


## NON FIDATO: tiene solo le voci ben formate con item_id equip che risolve.
func da_salvataggio(raw: Variant) -> void:
	pulisci()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var validi: Array = _mount_validi()
	for m in raw:
		var e: Variant = raw[m]
		if not validi.has(str(m)) or typeof(e) != TYPE_DICTIONARY:
			continue
		var item_id: String = str((e as Dictionary).get("item_id", ""))
		var iid: String = str((e as Dictionary).get("instance_id", ""))
		if iid.is_empty() or str(_def(item_id).get("categoria", "")) != "equip":
			continue
		_slot[str(m)] = {"instance_id": iid, "item_id": item_id}
	riapplica_al_giocatore()


# --- Interno ---------------------------------------------------------

func _applica_mod(mount: String) -> void:
	var stats: Node = _stats()
	if stats == null or not _slot.has(mount):
		return
	var sm: Dictionary = _def(str(_slot[mount].get("item_id", ""))).get("stat_modifiers", {})
	stats.call("apply_modifier", "equip:" + mount, sm)


func _rimuovi_mod(mount: String) -> void:
	var stats: Node = _stats()
	if stats != null:
		stats.call("remove_modifier", "equip:" + mount)


## "arma"/"armatura" -> se stesso. "accessorio" -> primo accessorio_N libero
## (accessorio_1 se pieni entrambi: equipaggia() smonta prima).
func _mount_per(tipo: String) -> String:
	if tipo == "arma" or tipo == "armatura":
		return tipo
	if tipo == "accessorio":
		for m in ["accessorio_1", "accessorio_2"]:
			if not _slot.has(m):
				return m
		return "accessorio_1"
	return ""


func _mount_validi() -> Array:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("equip_slots") if gd != null else ["arma", "armatura", "accessorio_1", "accessorio_2"]


func _def(item_id: String) -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("get_item", item_id) if gd != null else {}


func _inv() -> Node:
	return get_node_or_null("/root/Inventory")


func _stats() -> Node:
	var p: Node = get_tree().get_first_node_in_group("player")
	return p.get_node_or_null("StatsComponent") if p != null else null
