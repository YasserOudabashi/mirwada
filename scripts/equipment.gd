extends Node
## Equipaggiamento del giocatore (US-303). Legge le voci dallo zaino
## (Inventory) e le monta sui 4 slot di data/schema/equip_slots.json.
##
## Gli stat_modifiers dell'equip si applicano allo StatsComponent del
## giocatore come modificatore PER ID ("equip:<slot>", US-007): a ogni cambio
## il vecchio si rimuove e il nuovo si applica, senza sapere nulla degli altri
## bonus attivi.
##
## US-317: ogni slot puo' portare fino a slot_sigilli sigilli incastonati.
## effetto/effetto_collaterale del sigillo si applicano come modificatore
## "sigillo:<instance_id>[:collaterale]", stesso principio.
##
## NIENTE class_name: coerente col resto del progetto.

signal equip_cambiato(slot: String)

## slot di aggancio -> { instance_id, item_id }
var _slot: Dictionary = {}

## slot di aggancio -> Array[{ instance_id, item_id, sigillo_ref }] (US-317).
## Smontare l'equip (rimuovi_slot) estrae prima ogni sigillo incastonato e lo
## restituisce allo zaino: nessuna perdita silenziosa di oggetti.
var _sigilli: Dictionary = {}


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
	# Estrae prima ogni sigillo incastonato: nessuna perdita silenziosa (US-317).
	for se in (_sigilli.get(mount, []) as Array).duplicate(true):
		rimuovi_sigillo(mount, str((se as Dictionary).get("instance_id", "")))
	var e: Dictionary = _slot[mount]
	_rimuovi_mod(mount)
	_slot.erase(mount)
	var inv: Node = _inv()
	if inv != null:
		inv.call("restituisci_istanza", str(e.get("instance_id", "")), str(e.get("item_id", "")))
	equip_cambiato.emit(mount)
	return true


## Incastona un sigillo (istanza di zaino, categoria:sigillo) nello slot equip
## occupato da 'mount'. Fallisce se il mount e' vuoto, se non ci sono
## slot_sigilli liberi, o se l'istanza non e' un sigillo che risolve (US-317).
func incastona(mount: String, sigillo_instance_id: String) -> bool:
	if not _slot.has(mount):
		return false
	var cap: int = int(equipaggiato(mount).get("slot_sigilli", 0))
	var attuali: Array = (_sigilli.get(mount, []) as Array).duplicate(true)
	if attuali.size() >= cap:
		return false
	var inv: Node = _inv()
	if inv == null:
		return false
	var inst: Dictionary = inv.call("istanza", sigillo_instance_id)
	if inst.is_empty():
		return false
	var item_id: String = str(inst.get("item_id", ""))
	if str(_def(item_id).get("categoria", "")) != "sigillo":
		return false
	var sref: String = str(_def(item_id).get("sigillo_ref", ""))
	var sig: Dictionary = _sigil(sref)
	if sig.is_empty():
		return false
	inv.call("rimuovi_istanza", sigillo_instance_id)
	attuali.append({"instance_id": sigillo_instance_id, "item_id": item_id, "sigillo_ref": sref})
	_sigilli[mount] = attuali
	_applica_sigillo(sigillo_instance_id, sig)
	equip_cambiato.emit(mount)
	return true


## Estrae un sigillo incastonato e lo restituisce allo zaino.
func rimuovi_sigillo(mount: String, sigillo_instance_id: String) -> bool:
	var attuali: Array = (_sigilli.get(mount, []) as Array).duplicate(true)
	for i in attuali.size():
		if str((attuali[i] as Dictionary).get("instance_id", "")) == sigillo_instance_id:
			_rimuovi_mod_sigillo(sigillo_instance_id)
			var e: Dictionary = attuali[i]
			attuali.remove_at(i)
			_sigilli[mount] = attuali
			var inv: Node = _inv()
			if inv != null:
				inv.call("restituisci_istanza", sigillo_instance_id, str(e.get("item_id", "")))
			equip_cambiato.emit(mount)
			return true
	return false


func sigilli_incastonati(mount: String) -> Array:
	return (_sigilli.get(mount, []) as Array).duplicate(true)


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


## Tag degli item equipaggiati + dei sigilli incastonati (US-306/317: fonte
## per il motore sinergie).
func tag_attivi() -> Dictionary:
	var out: Dictionary = {}
	for m in _slot:
		for t in _def(str(_slot[m].get("item_id", ""))).get("tag", []):
			out[t] = int(out.get(t, 0)) + 1
	for m in _sigilli:
		for se in (_sigilli[m] as Array):
			for t in _sigil(str((se as Dictionary).get("sigillo_ref", ""))).get("tag", []):
				out[t] = int(out.get(t, 0)) + 1
	return out


func riapplica_al_giocatore() -> void:
	for m in _slot:
		_applica_mod(m)
	for m in _sigilli:
		for se in (_sigilli[m] as Array):
			var sig: Dictionary = _sigil(str((se as Dictionary).get("sigillo_ref", "")))
			if not sig.is_empty():
				_applica_sigillo(str((se as Dictionary).get("instance_id", "")), sig)


func pulisci() -> void:
	for m in _slot.keys():
		_rimuovi_mod(m)
	for m in _sigilli.keys():
		for se in (_sigilli[m] as Array):
			_rimuovi_mod_sigillo(str((se as Dictionary).get("instance_id", "")))
	_slot.clear()
	_sigilli.clear()


# --- Salvataggio -----------------------------------------------------

func per_salvataggio() -> Dictionary:
	return {"slot": _slot.duplicate(true), "sigilli": _sigilli.duplicate(true)}


## NON FIDATO: tiene solo le voci ben formate con item_id equip/sigillo che
## risolvono. Formato { slot: {mount:{instance_id,item_id}}, sigilli:
## {mount:[{instance_id,item_id,sigillo_ref}]} } (US-317; SaveSystem migra
## il formato piatto v14 in _migra_14_a_15).
func da_salvataggio(raw: Variant) -> void:
	pulisci()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var d: Dictionary = raw
	var validi: Array = _mount_validi()
	for m in _dict_or_empty(d.get("slot")):
		var e: Variant = d["slot"][m]
		if not validi.has(str(m)) or typeof(e) != TYPE_DICTIONARY:
			continue
		var item_id: String = str((e as Dictionary).get("item_id", ""))
		var iid: String = str((e as Dictionary).get("instance_id", ""))
		if iid.is_empty() or str(_def(item_id).get("categoria", "")) != "equip":
			continue
		_slot[str(m)] = {"instance_id": iid, "item_id": item_id}
	for m in _dict_or_empty(d.get("sigilli")):
		if not validi.has(str(m)) or not _slot.has(str(m)) or typeof(d["sigilli"][m]) != TYPE_ARRAY:
			continue
		var cap: int = int(equipaggiato(str(m)).get("slot_sigilli", 0))
		var out: Array = []
		for se in (d["sigilli"][m] as Array):
			if out.size() >= cap or typeof(se) != TYPE_DICTIONARY:
				continue
			var sid: String = str((se as Dictionary).get("instance_id", ""))
			var iitem: String = str((se as Dictionary).get("item_id", ""))
			var sref: String = str((se as Dictionary).get("sigillo_ref", ""))
			if sid.is_empty() or str(_def(iitem).get("categoria", "")) != "sigillo" or _sigil(sref).is_empty():
				continue
			out.append({"instance_id": sid, "item_id": iitem, "sigillo_ref": sref})
		if not out.is_empty():
			_sigilli[str(m)] = out
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


## Applica effetto + (se presente) effetto_collaterale di un sigillo appena
## incastonato, come modificatori per id "sigillo:<instance_id>[:collaterale]".
func _applica_sigillo(instance_id: String, sig: Dictionary) -> void:
	_applica_effetto(instance_id, sig.get("effetto", {}), "")
	if sig.has("effetto_collaterale"):
		_applica_effetto(instance_id, sig.get("effetto_collaterale", {}), ":collaterale")


## Solo stat_modifier produce un modificatore reale: tag_grant vive in
## tag_attivi(), stored_ability_id non ha ancora un consumatore (US-317
## copre lo schema; l'uso attivo e' materia di una story futura).
## moltiplicativo converte in delta sulla stat BASE, come ability_engine._mod_stat.
func _applica_effetto(instance_id: String, eff: Dictionary, suffisso: String) -> void:
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
	stats.call("apply_modifier", "sigillo:" + instance_id + suffisso, {stat: delta})


func _rimuovi_mod_sigillo(instance_id: String) -> void:
	var stats: Node = _stats()
	if stats == null:
		return
	stats.call("remove_modifier", "sigillo:" + instance_id)
	stats.call("remove_modifier", "sigillo:" + instance_id + ":collaterale")


func _sigil(sigillo_ref: String) -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("get_sigil", sigillo_ref) if gd != null else {}


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


static func _dict_or_empty(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}
