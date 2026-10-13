extends Node
## Cambio di Pathway (fase 7, US-704). Il cambio funziona SOLO tra Pathway
## vicini dello stesso gruppo (design-pathways.md): la relazione "vicini" e'
## il campo `group` dei dati, MAI un id hardcoded qui dentro.
##
## Cambiare non azzera il personaggio: la Sequenza numerica resta la stessa e
## le abilita' delle Sequenze basse (conservate_da_sequenza..9) del vecchio
## Pathway restano disponibili al giocatore (AbilityEngine.grant_permanente).
## Le abilita' fuse del percorso (data/fusions/) le concede FusionEngine
## (US-705), agganciato in coda a cambia().
##
## NIENTE class_name: coerente col resto del progetto.

signal pathway_cambiato(vecchio: String, nuovo: String, sequenza: int)

const _SOGLIA_FALLBACK := 4
const _CONSERVATE_DA_FALLBACK := 7


## true se si puo' cambiare verso `nuovo_pathway`: esiste, e' un altro Pathway
## dello STESSO gruppo di quello corrente, e la Sequenza raggiunta e' <= soglia.
func puo_cambiare(nuovo_pathway: String) -> bool:
	return _motivo_rifiuto(nuovo_pathway).is_empty()


## Esegue il cambio. { ok: true, da, a, sequenza, conservate: [ability_id] }
## oppure { ok: false, reason } senza toccare niente.
func cambia(nuovo_pathway: String) -> Dictionary:
	var reason: String = _motivo_rifiuto(nuovo_pathway)
	if not reason.is_empty():
		return {"ok": false, "reason": reason}

	var prog: Node = _prog()
	var vecchio: String = str(prog.call("pathway"))
	var seq: int = int(prog.call("sequence"))

	var eg: Node = _endgame()
	if eg != null:
		eg.call("registra_cambio", vecchio)

	prog.call("configura", nuovo_pathway, seq)

	var conservate: Array = _conserva_abilita_basse(vecchio)

	# Le abilita' fuse del percorso: FusionEngine (US-705). Assente in US-704.
	var fe: Node = get_node_or_null("/root/FusionEngine")
	if fe != null and fe.has_method("applica_al_cambio"):
		fe.call("applica_al_cambio", vecchio, nuovo_pathway)

	pathway_cambiato.emit(vecchio, nuovo_pathway, seq)
	return {"ok": true, "da": vecchio, "a": nuovo_pathway, "sequenza": seq,
		"conservate": conservate}


# --- Interno --------------------------------------------------------------

## "" se il cambio e' lecito, altrimenti il codice del motivo.
func _motivo_rifiuto(nuovo_pathway: String) -> String:
	var prog: Node = _prog()
	if prog == null:
		return "no_progression"
	var corrente: String = str(prog.call("pathway"))
	if nuovo_pathway.is_empty() or nuovo_pathway == corrente:
		return "stesso_pathway"

	var gd: Node = _gd()
	if gd == null:
		return "no_gamedata"
	var dati_nuovo: Dictionary = gd.call("get_pathway", nuovo_pathway)
	if dati_nuovo.is_empty():
		return "pathway_inesistente"

	var gruppo_corrente: String = str(gd.call("get_pathway", corrente).get("group", ""))
	if gruppo_corrente.is_empty() or str(dati_nuovo.get("group", "")) != gruppo_corrente:
		return "gruppo_diverso"

	if int(prog.call("sequence")) > _soglia_sequenza():
		return "troppo_presto"

	return ""


## Concede in permanenza al giocatore le abilita' delle Sequenze
## conservate_da_sequenza..9 del Pathway lasciato.
func _conserva_abilita_basse(vecchio_pathway: String) -> Array:
	var out: Array = []
	var gd: Node = _gd()
	var ae: Node = get_node_or_null("/root/AbilityEngine")
	if gd == null or ae == null or vecchio_pathway.is_empty():
		return out
	for s in range(_conservate_da_sequenza(), 10):
		var sd: Dictionary = gd.call("get_sequence", "%s_%d" % [vecchio_pathway, s])
		for a in sd.get("abilities", []):
			var aid: String = str(a)
			if ae.call("grant_permanente", aid):
				out.append(aid)
	return out


func _soglia_sequenza() -> int:
	var gd: Node = _gd()
	if gd == null:
		return _SOGLIA_FALLBACK
	return int(gd.call("get_balance", "cambio_pathway").get("soglia_sequenza", _SOGLIA_FALLBACK))


func _conservate_da_sequenza() -> int:
	var gd: Node = _gd()
	if gd == null:
		return _CONSERVATE_DA_FALLBACK
	return int(gd.call("get_balance", "cambio_pathway").get("conservate_da_sequenza", _CONSERVATE_DA_FALLBACK))


func _prog() -> Node:
	return get_node_or_null("/root/Progression")


func _gd() -> Node:
	return get_node_or_null("/root/GameData")


func _endgame() -> Node:
	return get_node_or_null("/root/EndgameState")
