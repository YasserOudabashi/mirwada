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


## Il dettaglio per fonte: { nome_fonte: { tag: conteggio } }.
func per_fonte() -> Dictionary:
	var out: Dictionary = {}
	for nome in _FONTI:
		var n: Node = get_node_or_null(_FONTI[nome])
		out[nome] = (n.call("tag_attivi") as Dictionary).duplicate() if n != null and n.has_method("tag_attivi") else {}
	return out


## { tag: conteggio_totale } su tutte le fonti.
func tag_sinergia_globali() -> Dictionary:
	var out: Dictionary = {}
	for fonte in per_fonte().values():
		for t in fonte:
			out[str(t)] = int(out.get(str(t), 0)) + int(fonte[t])
	return out
