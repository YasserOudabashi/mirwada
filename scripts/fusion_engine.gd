extends Node
## FusionEngine (fase 7, US-705). Compone le abilita' fuse di un cambio di
## Pathway leggendo data/fusions/: un file per coppia di Pathway vicini dello
## stesso gruppo. Il codice NON conosce una singola coppia — cerca il file la
## cui {pathway_a, pathway_b} combacia in qualsiasi ordine.
##
## Un'abilita' fusa e' un'abilita' come le altre: GameData.get_ability risolve
## il suo id "fus_*", AbilityEngine.execute la esegue senza modifiche.
##
## NIENTE class_name: coerente col resto del progetto.

signal fusione_concessa(percorso_id: String, abilita: Array)


## Il percorso di fusione tra i due Pathway (in qualsiasi ordine). {} se non
## esiste o e' ancora uno stub (contenuto non scritto, fase 7b).
func percorso(pathway_x: String, pathway_y: String) -> Dictionary:
	var gd: Node = _gd()
	if gd == null or pathway_x.is_empty() or pathway_y.is_empty():
		return {}
	var coppia: Array = [pathway_x, pathway_y]
	for fid in gd.call("fusion_ids"):
		var doc: Dictionary = gd.call("get_fusion", fid)
		var a: String = str(doc.get("pathway_a", ""))
		var b: String = str(doc.get("pathway_b", ""))
		if a in coppia and b in coppia and a != b:
			return {} if bool(doc.get("stub", false)) else doc
	return {}


## Le abilita' fuse di quel percorso, gia' risolte (id/name_i18n/primitive/
## tag_sinergia). [] se il percorso non esiste o e' stub.
func abilita_fuse(pathway_x: String, pathway_y: String) -> Array:
	var p: Dictionary = percorso(pathway_x, pathway_y)
	var fuse: Variant = p.get("abilita_fuse", [])
	return fuse if typeof(fuse) == TYPE_ARRAY else []


## Chiamato da PathwayChange.cambia: concede al giocatore (grant_permanente) le
## abilita' fuse del percorso e le registra in endgame.fusioni. [] se stub.
func applica_al_cambio(vecchio_pathway: String, nuovo_pathway: String) -> Array:
	var p: Dictionary = percorso(vecchio_pathway, nuovo_pathway)
	if p.is_empty():
		return []
	var ae: Node = get_node_or_null("/root/AbilityEngine")
	var eg: Node = get_node_or_null("/root/EndgameState")
	var concesse: Array = []
	for ab in p.get("abilita_fuse", []):
		var aid: String = str((ab as Dictionary).get("id", ""))
		if aid.is_empty():
			continue
		if ae != null and ae.call("grant_permanente", aid):
			concesse.append(aid)
		if eg != null:
			eg.call("aggiungi_fusione", aid)
	if not concesse.is_empty():
		fusione_concessa.emit(str(p.get("id", "")), concesse)
	return concesse


func _gd() -> Node:
	return get_node_or_null("/root/GameData")
