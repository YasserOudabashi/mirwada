extends Node
## Magazzino unico degli oggetti del giocatore (US-302). Ogni sistema di fase 3
## (alchimia, forgiatura, pet, base) legge e scrive qui: nessuno tiene una
## propria lista.
##
## Due forme di deposito:
##   * item impilabile:true  -> un contatore in _stack (item_id -> quantita)
##   * item impilabile:false -> istanze distinte in _istanze, ognuna con un
##     instance_id univoco (l'equip che si equipaggia, i sigilli che si
##     incastonano — servono un'identita' stabile)
##
## Nessun cap spaziale ne' peso: lista categorizzata (design-ui-libro).
##
## NIENTE class_name: coerente col resto del progetto.

signal item_aggiunto(item_id: String, quantita: int)
signal item_rimosso(item_id: String, quantita: int)

var _stack: Dictionary = {}      # item_id -> int
var _istanze: Array = []         # [{ instance_id: String, item_id: String }]
var _next_iid: int = 1


# --- API ---------------------------------------------------------------

## -> instance_id creati (vuoto per un item impilabile: e' un contatore, non
## ha identita'). Usato dai sistemi di crafting (US-316) per sapere quale
## istanza equip/sigillo hanno appena prodotto.
func aggiungi(item_id: String, quantita: int = 1) -> Array:
	if quantita <= 0:
		return []
	var it: Dictionary = _def(item_id)
	if it.is_empty():
		push_warning("[Inventory] item ignoto: %s" % item_id)
		return []
	var creati: Array = []
	if bool(it.get("impilabile", false)):
		_stack[item_id] = int(_stack.get(item_id, 0)) + quantita
	else:
		for i in quantita:
			var iid: String = "inv_%d" % _next_iid
			_istanze.append({"instance_id": iid, "item_id": item_id})
			_next_iid += 1
			creati.append(iid)
	item_aggiunto.emit(item_id, quantita)
	return creati


## Rimuove `quantita` copie. false se non ce n'erano abbastanza (nessuna
## rimozione parziale).
func rimuovi(item_id: String, quantita: int = 1) -> bool:
	if quantita <= 0 or conta(item_id) < quantita:
		return false
	if _def(item_id).get("impilabile", false):
		_stack[item_id] = int(_stack[item_id]) - quantita
		if _stack[item_id] <= 0:
			_stack.erase(item_id)
	else:
		var tolti: int = 0
		for i in range(_istanze.size() - 1, -1, -1):
			if str(_istanze[i].get("item_id", "")) == item_id:
				_istanze.remove_at(i)
				tolti += 1
				if tolti == quantita:
					break
	item_rimosso.emit(item_id, quantita)
	return true


## Rimuove UNA istanza per instance_id (per l'equip: US-303). false se assente.
func rimuovi_istanza(instance_id: String) -> bool:
	for i in _istanze.size():
		if str(_istanze[i].get("instance_id", "")) == instance_id:
			var iid: String = str(_istanze[i].get("item_id", ""))
			_istanze.remove_at(i)
			item_rimosso.emit(iid, 1)
			return true
	return false


## Rimette in inventario un'istanza tolta (equip smontato, sigillo estratto).
func restituisci_istanza(instance_id: String, item_id: String) -> void:
	_istanze.append({"instance_id": instance_id, "item_id": item_id})
	item_aggiunto.emit(item_id, 1)


## Usa un'istanza (US-304). Se l'item porta uno stored_ability_id, esegue
## quell'abilita' come se il giocatore la possedesse (una volta, senza costo
## ne' cooldown ne' controllo di ownership - il motore c'e' gia': US-206), poi
## consuma l'item. Un item senza stored_ability_id -> esito gestito, non crash.
##   -> { ok: bool, reason: String, risultato: Dictionary }
func usa(instance_id: String, bersaglio: Node = null) -> Dictionary:
	var inst: Dictionary = istanza(instance_id)
	if inst.is_empty():
		return {"ok": false, "reason": "istanza_assente", "risultato": {}}
	var def: Dictionary = _def(str(inst.get("item_id", "")))

	# Pergamena che insegna una ricetta leggendaria (US-313).
	var ric: String = str(def.get("insegna_ricetta", ""))
	if not ric.is_empty():
		var kn: Node = get_node_or_null("/root/KnowledgeStore")
		if kn != null:
			kn.call("impara", "ricetta:" + ric)
		rimuovi_istanza(instance_id)
		return {"ok": true, "reason": "", "risultato": {"ricetta_appresa": ric}}

	var sab: String = str(def.get("stored_ability_id", ""))
	if sab.is_empty():
		return {"ok": false, "reason": "nessuna_abilita", "risultato": {}}
	var giocatore: Node = get_tree().get_first_node_in_group("player")
	if giocatore == null:
		return {"ok": false, "reason": "nessun_giocatore", "risultato": {}}
	var eng: Node = get_node_or_null("/root/AbilityEngine")
	if eng == null:
		return {"ok": false, "reason": "motore_assente", "risultato": {}}
	var r: Dictionary = eng.call("execute_stored", sab, giocatore)
	if not bool(r.get("ok", false)):
		return {"ok": false, "reason": str(r.get("reason", "esecuzione_fallita")), "risultato": r}
	rimuovi_istanza(instance_id)   # consumo: 1 uso
	var tt: Node = get_node_or_null("/root/TalentTracker")   # US-331
	if tt != null:
		tt.call("emit_event", "abilita_prestate_usate", {})
	return {"ok": true, "reason": "", "risultato": r}


func conta(item_id: String) -> int:
	if _def(item_id).get("impilabile", false):
		return int(_stack.get(item_id, 0))
	var n: int = 0
	for e in _istanze:
		if str(e.get("item_id", "")) == item_id:
			n += 1
	return n


func possiede(item_id: String, quantita: int = 1) -> bool:
	return conta(item_id) >= quantita


func istanza(instance_id: String) -> Dictionary:
	for e in _istanze:
		if str(e.get("instance_id", "")) == instance_id:
			return e
	return {}


## Voci di una categoria: {item_id, quantita, instance_id (solo non impilabili)}.
func per_categoria(categoria: String) -> Array:
	var out: Array = []
	for item_id in _stack:
		if str(_def(item_id).get("categoria", "")) == categoria:
			out.append({"item_id": item_id, "quantita": int(_stack[item_id])})
	for e in _istanze:
		if str(_def(str(e.get("item_id", ""))).get("categoria", "")) == categoria:
			out.append({"item_id": e["item_id"], "quantita": 1, "instance_id": e["instance_id"]})
	return out


func tutto() -> Dictionary:
	return {"stack": _stack.duplicate(), "istanze": _istanze.duplicate(true)}


## Tag di cio' che il giocatore PORTA ADDOSSO (US-306): equip indossato +
## sigilli incastonati (US-317). Gli item nello zaino NON contano - una
## sinergia e' cio' che indossi, non cio' che hai in tasca.
##
## API di SOLA LETTURA: non conosce le sinergie. E' fase 4 (SynergySources,
## US-334) a comporla con pet, talenti e stanze e a risolvere le regole.
func tag_attivi() -> Dictionary:
	var eq: Node = get_node_or_null("/root/Equipment")
	return eq.call("tag_attivi") if eq != null else {}


## Comodita' di sola lettura per la UI (US-305): valore totale delle valute.
func ricchezza() -> int:
	var gd: Node = _gd()
	var tot: int = 0
	if gd == null:
		return 0
	for id in gd.call("items_per_categoria", "valuta"):
		var v: Dictionary = id
		tot += conta(str(v.get("id", ""))) * int(v.get("valore", 0))
	return tot


func pulisci() -> void:
	_stack.clear()
	_istanze.clear()
	_next_iid = 1


# --- Salvataggio ------------------------------------------------------

func per_salvataggio() -> Dictionary:
	return {"stack": _stack.duplicate(), "istanze": _istanze.duplicate(true), "next_iid": _next_iid}


## NON FIDATO: scarta ogni voce malformata o con item_id che non risolve.
func da_salvataggio(raw: Variant) -> void:
	pulisci()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var d: Dictionary = raw
	for k in _dict_or_empty(d.get("stack")):
		var q: Variant = d["stack"][k]
		if typeof(k) == TYPE_STRING and typeof(q) in [TYPE_FLOAT, TYPE_INT] \
				and int(q) > 0 and not _def(k).is_empty():
			_stack[k] = int(q)
	for e in _arr_or_empty(d.get("istanze")):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var iid: String = str((e as Dictionary).get("instance_id", ""))
		var item_id: String = str((e as Dictionary).get("item_id", ""))
		if not iid.is_empty() and not _def(item_id).is_empty():
			_istanze.append({"instance_id": iid, "item_id": item_id})
	var ni: Variant = d.get("next_iid", 1)
	_next_iid = int(ni) if typeof(ni) in [TYPE_FLOAT, TYPE_INT] and int(ni) > 0 else _istanze.size() + 1


# --- Interno ---------------------------------------------------------

func _def(item_id: String) -> Dictionary:
	var gd: Node = _gd()
	return gd.call("get_item", item_id) if gd != null else {}


func _gd() -> Node:
	return get_node_or_null("/root/GameData")


static func _dict_or_empty(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func _arr_or_empty(v: Variant) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []
