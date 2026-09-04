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
signal sigillo_incastonato(mount: String, sigillo_instance_id: String)
signal sigillo_rimosso(mount: String, sigillo_instance_id: String)

## slot di aggancio -> { instance_id, item_id }
var _slot: Dictionary = {}

## Sigilli incastonati per ISTANZA di equip (US-317), non per slot: restano
## nell'oggetto quando lo smonti e lo rimetti nello zaino, non nel mount.
## equip_instance_id -> Array[{ instance_id, item_id }] (del sigillo).
var _sigilli: Dictionary = {}


func _ready() -> void:
	# il player entra in scena dopo gli autoload: chiama lui
	# riapplica_al_giocatore() nel suo _ready (come Progression).
	pass


func _process(delta: float) -> void:
	tick_effetti_collaterali(delta)


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
	# Se questa istanza aveva gia' dei sigilli incastonati (era stata smontata
	# in precedenza), il loro modificatore si riaccende con lei.
	for voce in _sigilli.get(instance_id, []):
		var v: Dictionary = voce
		_applica_mod_sigillo(str(v.get("instance_id", "")), str(v.get("item_id", "")))
	equip_cambiato.emit(mount)
	return true


func rimuovi_slot(mount: String) -> bool:
	if not _slot.has(mount):
		return false
	var e: Dictionary = _slot[mount]
	_rimuovi_mod(mount)
	# I sigilli restano incastonati nell'oggetto (US-317: _sigilli e' per
	# istanza, non per slot), ma il loro modificatore vale solo mentre e'
	# INDOSSATO: smontato, si spegne finche' non lo rimonti.
	for voce in _sigilli.get(str(e.get("instance_id", "")), []):
		_rimuovi_mod_sigillo(str((voce as Dictionary).get("instance_id", "")))
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


## Tag degli item equipaggiati (US-306: fonte per il motore sinergie) + i tag
## propri dei sigilli incastonati e quelli che un effetto tag_grant aggiunge
## (US-317: "i sigilli incastonati contano in tag_attivi").
func tag_attivi() -> Dictionary:
	var out: Dictionary = {}
	for m in _slot:
		var def: Dictionary = _def(str(_slot[m].get("item_id", "")))
		for t in def.get("tag", []):
			out[t] = int(out.get(t, 0)) + 1
		# US-318: il tag_grant dell'effetto_collaterale di un equip Sigillato
		# (es. un tag che attira nemici) conta anche lui, sempre, indossato.
		var ec: Dictionary = def.get("effetto_collaterale", {})
		if bool(def.get("sigillato", false)) and str(ec.get("tipo", "")) == "tag_grant" and ec.has("tag"):
			out[str(ec["tag"])] = int(out.get(str(ec["tag"]), 0)) + 1
		for voce in _sigilli.get(str(_slot[m].get("instance_id", "")), []):
			var v: Dictionary = voce
			var sig_item_id: String = str(v.get("item_id", ""))
			for t in _def(sig_item_id).get("tag", []):
				out[t] = int(out.get(t, 0)) + 1
			var sdef: Dictionary = _sigil_def(sig_item_id)
			for campo in ["effetto", "effetto_collaterale"]:
				var e: Dictionary = sdef.get(campo, {})
				if str(e.get("tipo", "")) == "tag_grant" and e.has("tag"):
					out[str(e["tag"])] = int(out.get(str(e["tag"]), 0)) + 1
	return out


## Ability id concessi dai sigilli incastonati (effetto/effetto_collaterale
## tipo:stored_ability_id): chi vuole eseguirli passa da
## AbilityEngine.execute_stored, come una pergamena (US-304).
func stored_abilities() -> Array:
	var out: Array = []
	for m in _slot:
		for voce in _sigilli.get(str(_slot[m].get("instance_id", "")), []):
			var sdef: Dictionary = _sigil_def(str((voce as Dictionary).get("item_id", "")))
			for campo in ["effetto", "effetto_collaterale"]:
				var e: Dictionary = sdef.get(campo, {})
				if str(e.get("tipo", "")) == "stored_ability_id" and e.has("ability_id"):
					out.append(str(e["ability_id"]))
	return out


## Sigilli incastonati nell'equip montato su `mount`: [{ instance_id, item_id }].
func sigilli_incastonati(mount: String) -> Array:
	if not _slot.has(mount):
		return []
	return _sigilli.get(str(_slot[mount].get("instance_id", "")), []).duplicate(true)


## Incastona un sigillo dallo zaino nell'equip montato su `mount`. false se lo
## slot e' vuoto, l'istanza non e' un sigillo, o non c'e' piu' capacita'
## (slot_sigilli dell'equip).
func incastona(mount: String, sigillo_instance_id: String) -> bool:
	if not _slot.has(mount):
		return false
	var equip_iid: String = str(_slot[mount].get("instance_id", ""))
	var capacita: int = int(_def(str(_slot[mount].get("item_id", ""))).get("slot_sigilli", 0))
	var incastonati: Array = _sigilli.get(equip_iid, [])
	if incastonati.size() >= capacita:
		return false
	var inv: Node = _inv()
	if inv == null:
		return false
	var inst: Dictionary = inv.call("istanza", sigillo_instance_id)
	if inst.is_empty():
		return false
	var sig_item_id: String = str(inst.get("item_id", ""))
	if str(_def(sig_item_id).get("categoria", "")) != "sigillo":
		return false
	inv.call("rimuovi_istanza", sigillo_instance_id)
	incastonati.append({"instance_id": sigillo_instance_id, "item_id": sig_item_id})
	_sigilli[equip_iid] = incastonati
	_applica_mod_sigillo(sigillo_instance_id, sig_item_id)
	sigillo_incastonato.emit(mount, sigillo_instance_id)
	return true


## Estrae un sigillo incastonato e lo restituisce allo zaino. false se non
## era incastonato li'.
func rimuovi_sigillo(mount: String, sigillo_instance_id: String) -> bool:
	if not _slot.has(mount):
		return false
	var equip_iid: String = str(_slot[mount].get("instance_id", ""))
	var incastonati: Array = _sigilli.get(equip_iid, [])
	for i in incastonati.size():
		if str((incastonati[i] as Dictionary).get("instance_id", "")) == sigillo_instance_id:
			var sig_item_id: String = str((incastonati[i] as Dictionary).get("item_id", ""))
			incastonati.remove_at(i)
			_sigilli[equip_iid] = incastonati
			_rimuovi_mod_sigillo(sigillo_instance_id)
			var inv: Node = _inv()
			if inv != null:
				inv.call("restituisci_istanza", sigillo_instance_id, sig_item_id)
			sigillo_rimosso.emit(mount, sigillo_instance_id)
			return true
	return false


func riapplica_al_giocatore() -> void:
	for m in _slot:
		_applica_mod(m)
		for voce in _sigilli.get(str(_slot[m].get("instance_id", "")), []):
			var v: Dictionary = voce
			_applica_mod_sigillo(str(v.get("instance_id", "")), str(v.get("item_id", "")))


func pulisci() -> void:
	for m in _slot.keys():
		_rimuovi_mod(m)
		for voce in _sigilli.get(str(_slot[m].get("instance_id", "")), []):
			_rimuovi_mod_sigillo(str((voce as Dictionary).get("instance_id", "")))
	_slot.clear()
	_sigilli.clear()


# --- Salvataggio -----------------------------------------------------

## { slot: <mount -> {instance_id, item_id}>, sigilli: <equip_instance_id ->
## [{instance_id, item_id}]> }. Prima di US-317 questa chiave ERA la mappa
## slot nuda: da_salvataggio riconosce ancora quella forma (vedi sotto), non
## serve un bump di schema_version per un salvataggio vecchio.
func per_salvataggio() -> Dictionary:
	return {"slot": _slot.duplicate(true), "sigilli": _sigilli.duplicate(true)}


## NON FIDATO: tiene solo le voci ben formate con item_id equip che risolve.
## Accetta sia la forma nuova {slot:.., sigilli:..} sia quella nuda pre-US-317
## (raw stesso e' la mappa dei mount, senza sigilli).
func da_salvataggio(raw: Variant) -> void:
	pulisci()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var d: Dictionary = raw
	var slot_raw: Variant = d["slot"] if d.has("slot") else raw
	var sigilli_raw: Variant = d.get("sigilli", {})
	if typeof(slot_raw) != TYPE_DICTIONARY:
		return
	var validi: Array = _mount_validi()
	for m in (slot_raw as Dictionary):
		var e: Variant = (slot_raw as Dictionary)[m]
		if not validi.has(str(m)) or typeof(e) != TYPE_DICTIONARY:
			continue
		var item_id: String = str((e as Dictionary).get("item_id", ""))
		var iid: String = str((e as Dictionary).get("instance_id", ""))
		if iid.is_empty() or str(_def(item_id).get("categoria", "")) != "equip":
			continue
		_slot[str(m)] = {"instance_id": iid, "item_id": item_id}
	if typeof(sigilli_raw) == TYPE_DICTIONARY:
		for equip_iid in (sigilli_raw as Dictionary):
			var lista: Variant = (sigilli_raw as Dictionary)[equip_iid]
			if typeof(lista) != TYPE_ARRAY:
				continue
			var validati: Array = []
			for voce in (lista as Array):
				if typeof(voce) != TYPE_DICTIONARY:
					continue
				var sid: String = str((voce as Dictionary).get("instance_id", ""))
				var sitem: String = str((voce as Dictionary).get("item_id", ""))
				if not sid.is_empty() and str(_def(sitem).get("categoria", "")) == "sigillo":
					validati.append({"instance_id": sid, "item_id": sitem})
			if not validati.is_empty():
				_sigilli[str(equip_iid)] = validati
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


## Applica l'effetto E l'effetto_collaterale del sigillo (US-309/317: entrambi
## contano, l'effetto_collaterale e' sempre uno svantaggio) come UN modificatore
## per id "sigillo:<instance_id>". Solo i tipi stat_modifier toccano lo
## StatsComponent: tag_grant/stored_ability_id si leggono da tag_attivi() /
## stored_abilities(), non sono un modificatore.
func _applica_mod_sigillo(instance_id: String, sig_item_id: String) -> void:
	var stats: Node = _stats()
	if stats == null:
		return
	var sdef: Dictionary = _sigil_def(sig_item_id)
	var deltas: Dictionary = {}
	_accumula_stat_modifier(deltas, sdef.get("effetto", {}), stats)
	_accumula_stat_modifier(deltas, sdef.get("effetto_collaterale", {}), stats)
	if not deltas.is_empty():
		stats.call("apply_modifier", "sigillo:" + instance_id, deltas)


func _accumula_stat_modifier(deltas: Dictionary, eff: Variant, stats: Node) -> void:
	if typeof(eff) != TYPE_DICTIONARY:
		return
	var e: Dictionary = eff
	if str(e.get("tipo", "")) != "stat_modifier":
		return
	var stat: String = str(e.get("stat", ""))
	var valore: float = float(e.get("valore", 0.0))
	# Stesso motore di AbilityEngine._mod_stat: un moltiplicativo diventa il
	# delta equivalente sulla base, cosi' resta un semplice delta additivo.
	var delta: float = valore
	if bool(e.get("moltiplicativo", false)):
		delta = float(stats.call("get_base", stat)) * valore
	deltas[stat] = float(deltas.get(stat, 0.0)) + delta


func _rimuovi_mod_sigillo(instance_id: String) -> void:
	var stats: Node = _stats()
	if stats != null:
		stats.call("remove_modifier", "sigillo:" + instance_id)


## Applica l'effetto_collaterale degli equip 'sigillato:true' indossati
## (US-318: un Sigillato paga un prezzo SEMPRE, non solo quando lo incastoni
## con qualcosa). Continuo, scalato dal delta - come AbilityEngine.tick_effects
## per un dot/decay/transform, non un accumulatore a scatti. Pubblica di
## proposito: i test la chiamano con un delta scelto invece di aspettare
## secondi veri.
func tick_effetti_collaterali(delta: float) -> void:
	for m in _slot:
		var def: Dictionary = _def(str(_slot[m].get("item_id", "")))
		if not bool(def.get("sigillato", false)):
			continue
		var ec: Dictionary = def.get("effetto_collaterale", {})
		var tipo: String = str(ec.get("tipo", ""))
		var valore: float = float(ec.get("valore", 0.0))
		match tipo:
			"follia_al_secondo":
				var madness: Node = get_node_or_null("/root/Madness")
				if madness != null and valore > 0.0:
					madness.call("add", valore * delta, "sigillato:" + str(m))
			"drain_spiritualita_al_secondo":
				var stats: Node = _stats()
				if stats != null and valore > 0.0:
					stats.set("spiritualita", maxf(0.0, float(stats.get("spiritualita")) - valore * delta))


func _sigil_def(sig_item_id: String) -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return {}
	return gd.call("get_sigil", str(_def(sig_item_id).get("sigillo_ref", "")))


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
