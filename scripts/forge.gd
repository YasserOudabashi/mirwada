extends Node
## Forgiatura dell'equipaggiamento (US-316): combina materiali (categoria:
## materiale) per produrre un pezzo di equip da un blueprint noto.
##
## La qualita' finale segue lo stesso schema di PotionSystem._qualita_finale
## (stessa scala data/schema/potion_quality.json): indice di qualita_base +
## bonus_stanza(stanza_rituale, qualita_forgia) + bonus_talento(forgiatura_qualita).
## Entrambi i bonus restano 0 finche' BaseSystem/TalentSystem non esistono
## (US-326/331): e' il gancio, non l'implementazione del bonus.
##
## NIENTE class_name: coerente col resto del progetto.

signal equip_forgiato(blueprint_id: String, item_id: String, qualita: String)


func blueprint_noto(blueprint_id: String) -> bool:
	var gd: Node = _gd()
	var bp: Dictionary = gd.call("get_blueprint", blueprint_id) if gd != null else {}
	if bp.is_empty():
		return false
	return bool(bp.get("nota_da_subito", false))


## ignora_scoperta (fase 11, US-1106): un NPC fabbro conosce il SUO mestiere
## a prescindere da cosa il giocatore ha scoperto - salta blueprint_noto().
## Default false: nessuna regressione sulla forgiatura del giocatore.
## -> { ok, reason, item_id, instance_id, qualita }
func forgia(blueprint_id: String, ignora_scoperta: bool = false) -> Dictionary:
	var gd: Node = _gd()
	var inv: Node = get_node_or_null("/root/Inventory")
	if gd == null or inv == null:
		return {"ok": false, "reason": "sistema_assente"}
	var bp: Dictionary = gd.call("get_blueprint", blueprint_id)
	if bp.is_empty():
		return {"ok": false, "reason": "blueprint_inesistente"}
	if not ignora_scoperta and not blueprint_noto(blueprint_id):
		return {"ok": false, "reason": "blueprint_ignoto"}

	var materiali: Dictionary = bp.get("materiali", {})
	for item_id in materiali:
		if inv.call("conta", item_id) < int(materiali[item_id]):
			return {"ok": false, "reason": "materiali_mancanti"}
	for item_id in materiali:
		inv.call("rimuovi", item_id, int(materiali[item_id]))

	var out_id: String = str(bp.get("output", {}).get("item_id", ""))
	var creati: Array = inv.call("aggiungi", out_id, 1)
	var qualita: String = _qualita_finale(bp)
	var iid: String = str(creati[0]) if not creati.is_empty() else ""
	_traccia_item_crafted(out_id, qualita)
	equip_forgiato.emit(blueprint_id, out_id, qualita)
	return {"ok": true, "reason": "", "item_id": out_id, "instance_id": iid, "qualita": qualita}


## US-804: un oggetto e' stato prodotto (tracked_events.json: categoria,
## qualita_min). "categoria" viene dai dati dell'item stesso, mai scritta
## qui. Stesso contratto di PotionSystem._traccia_item_crafted.
func _traccia_item_crafted(item_id: String, qualita: String) -> void:
	var et: Node = get_node_or_null("/root/EventTracker")
	if et == null:
		return
	var item: Dictionary = _gd().call("get_item", item_id)
	et.call("emit_event", "item_crafted",
		{"categoria": str(item.get("categoria", "")), "qualita": qualita})


func _qualita_finale(bp: Dictionary) -> String:
	var scala: Array = _gd().call("potion_quality")
	var base: int = maxi(0, scala.find(str(bp.get("qualita_base", "pura"))))
	var se: Node = get_node_or_null("/root/SynergyEngine")
	var bonus: int = _bonus_stanza("stanza_rituale", "qualita_forgia") \
		+ _bonus_talento("forgiatura_qualita") \
		+ (int(se.call("bonus_qualita", "forgia")) if se != null else 0)
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
