extends Node
## Materia prima del motore sinergie (US-334). Somma i tag attivi da ogni
## fonte del gioco che espone gia' un tag_attivi(): Inventory (che a sua
## volta e' equip indossato + sigilli incastonati, US-306/317), PetSystem,
## TalentSystem, BaseSystem. NON risolve sinergie (richiede_tag, effetti):
## quello e' fase 4, questo e' solo "quali tag sono attivi ORA e quanti".
##
## NIENTE class_name: coerente col resto del progetto.

const FONTI := ["/root/Inventory", "/root/PetSystem", "/root/TalentSystem", "/root/BaseSystem"]


func tag_sinergia_globali() -> Dictionary:
	var out: Dictionary = {}
	for path in FONTI:
		var fonte: Node = get_node_or_null(path)
		if fonte == null:
			continue
		var tag: Dictionary = fonte.call("tag_attivi")
		for t in tag:
			out[t] = int(out.get(t, 0)) + int(tag[t])
	return out
