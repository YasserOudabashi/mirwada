extends Node
## La materia prima delle sinergie (US-334): somma i tag di TUTTE le fonti che
## il giocatore porta — equip indossato + sigilli incastonati, pet attivo,
## talenti posseduti, stanze costruite.
##
## NON risolve nessuna regola di sinergia: quello e' fase 4. Qui c'e' solo
## l'aggregazione. Nessuna delle fonti conosce le sinergie; nessuna sinergia
## e' nominata qui.
##
## NIENTE class_name: coerente col resto del progetto.

const _FONTI := {
	"inventario": "/root/Inventory",
	"pet": "/root/PetSystem",
	"talenti": "/root/TalentSystem",
	"base": "/root/BaseSystem",
}


## Il dettaglio per fonte: { nome_fonte: { tag: conteggio } }. Le 4 fonti con
## tag_attivi() + 'sequenza' (i tag del Pathway attivo, US-401). 'ingrediente'
## e' nell'enum dello schema ma non ha una fonte in fase 4.
func per_fonte() -> Dictionary:
	var out: Dictionary = {}
	for nome in _FONTI:
		var n: Node = get_node_or_null(_FONTI[nome])
		out[nome] = (n.call("tag_attivi") as Dictionary).duplicate() if n != null and n.has_method("tag_attivi") else {}
	out["sequenza"] = _tag_sequenza()
	return out


## I tag del Pathway attualmente attivo (Progression + GameData). {} se non
## c'e' una partita in corso.
func _tag_sequenza() -> Dictionary:
	var prog: Node = get_node_or_null("/root/Progression")
	var gd: Node = get_node_or_null("/root/GameData")
	if prog == null or gd == null:
		return {}
	var pw: Dictionary = gd.call("get_pathway", str(prog.call("pathway")))
	var out: Dictionary = {}
	for t in pw.get("tags", []):
		out[str(t)] = int(out.get(str(t), 0)) + 1
	return out


## { tag: conteggio_totale } su tutte le fonti.
func tag_sinergia_globali() -> Dictionary:
	var out: Dictionary = {}
	for fonte in per_fonte().values():
		for t in fonte:
			out[str(t)] = int(out.get(str(t), 0)) + int(fonte[t])
	return out
