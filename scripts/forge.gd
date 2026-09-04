extends Node
## Forgiatura dell'equipaggiamento (US-316). Autoload SEPARATO da PotionSystem
## (Open Question #1 del PRD fase 3, decisa 'separati' finche' la duplicazione
## non supera ~30 righe): stesso pattern di prepara() — verifica noto +
## materiali, consuma, produce nell'inventario con una qualita' — ma dati
## diversi (data/forge/blueprints.json invece di data/potions/recipes.json).
##
## NIENTE class_name: coerente col resto del progetto.

signal oggetto_forgiato(blueprint_id: String, item_id: String, qualita: String)


## true se il blueprint e' forgiabile: nota_da_subito, oppure un flag
## KnowledgeStore 'progetto:<id>' (gating come le ricette, US-308).
func blueprint_nota(blueprint_id: String) -> bool:
	var gd: Node = _gd()
	var b: Dictionary = gd.call("get_blueprint", blueprint_id) if gd != null else {}
	if b.is_empty():
		return false
	if bool(b.get("nota_da_subito", false)):
		return true
	var kn: Node = get_node_or_null("/root/KnowledgeStore")
	return kn != null and bool(kn.call("conosce", "progetto:" + blueprint_id))


## Forgia un blueprint noto consumando i materiali dall'inventario.
##   -> { ok, reason, item_id, instance_id, qualita }
func forgia(blueprint_id: String) -> Dictionary:
	var gd: Node = _gd()
	var inv: Node = get_node_or_null("/root/Inventory")
	if gd == null or inv == null:
		return {"ok": false, "reason": "sistema_assente", "item_id": "", "instance_id": "", "qualita": ""}
	var b: Dictionary = gd.call("get_blueprint", blueprint_id)
	if b.is_empty():
		return {"ok": false, "reason": "blueprint_inesistente", "item_id": "", "instance_id": "", "qualita": ""}
	if not blueprint_nota(blueprint_id):
		return {"ok": false, "reason": "blueprint_ignoto", "item_id": "", "instance_id": "", "qualita": ""}
	var materiali: Dictionary = b.get("materiali", {})
	for item_id in materiali:
		if inv.call("conta", item_id) < int(materiali[item_id]):
			return {"ok": false, "reason": "materiali_mancanti", "item_id": "", "instance_id": "", "qualita": ""}
	# tutto presente: consuma e produce
	for item_id in materiali:
		inv.call("rimuovi", item_id, int(materiali[item_id]))
	var qualita: String = _qualita_finale(b)
	var out_id: String = str(b.get("output", ""))
	var creati: Array = inv.call("aggiungi", out_id, 1)
	var instance_id: String = str(creati[0]) if not creati.is_empty() else ""
	_traccia_item_crafted("equip", qualita)
	oggetto_forgiato.emit(blueprint_id, out_id, qualita)
	return {"ok": true, "reason": "", "item_id": out_id, "instance_id": instance_id, "qualita": qualita}


## Scala CONDIVISA con l'alchimia (data/schema/potion_quality.json): non e'
## una qualita' "di pozione", e' la scala crescente generica di ogni output
## di crafting. qualita_base del blueprint + bonus della stanza_rituale
## (BaseSystem.bonus, US-326/327) + bonus talenti (US-329, 0 finche' non
## c'e' TalentSystem), clampato.
func _qualita_finale(b: Dictionary) -> String:
	var scala: Array = _gd().call("potion_quality")
	var base: int = maxi(0, scala.find(str(b.get("qualita_base", "pura"))))
	var bonus: int = _bonus_stanza("stanza_rituale", "qualita_forgia") + _bonus_talento("forgiatura_qualita")
	return str(scala[clampi(base + bonus, 0, scala.size() - 1)])


func _bonus_stanza(tipo: String, chiave: String) -> int:
	var bs: Node = get_node_or_null("/root/BaseSystem")
	if bs == null:
		return 0
	return int((bs.call("bonus", tipo) as Dictionary).get(chiave, 0))


func _bonus_talento(chiave: String) -> int:
	var ts: Node = get_node_or_null("/root/TalentSystem")
	if ts == null or not ts.has_method("bonus_int"):
		return 0
	return int(ts.call("bonus_int", chiave))


func _gd() -> Node:
	return get_node_or_null("/root/GameData")


## US-331: item_crafted (uno dei 12 tracked_events) alimenta gli sblocco dei
## talenti di forgiatura (es. fabbro_indomito). Stesso schema di
## PotionSystem._traccia_item_crafted: qualita' come indice sulla scala, non
## come nome, perche' il filtro qualita_min lavora su numeri.
func _traccia_item_crafted(categoria: String, qualita: String) -> void:
	var et: Node = get_node_or_null("/root/EventTracker")
	if et == null:
		return
	var indice: int = maxi(0, (_gd().call("potion_quality") as Array).find(qualita))
	et.call("emit_event", "item_crafted", {"categoria": categoria, "qualita": indice})
