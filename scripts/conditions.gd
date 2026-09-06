extends RefCounted
## Valutatore condiviso delle condizioni (US-605, FR-3). Una lista di
## { tipo, valore } valutata contro lo stato globale di gioco. Un solo posto
## in cui vive la semantica di e_notte / fase_lunare / in_zona_tag /
## foundation_min / tier_min / madness_min / madness_max / acting_progress_min
## (+ follia_min / reputazione_min / flag per i dialoghi, US-613).
##
## AbilityEngine.execute la chiama prima di pagare il costo; DialogueEngine
## (US-613) per nascondere le scelte non disponibili. Il CHIAMANTE decide se
## applicarla: AbilityEngine lo fa solo col giocatore in scena (un caster
## senza contesto - nemici, test isolati - non e' soggetto alle condizioni,
## come per l'ownership).
##
## NIENTE class_name: coerente col progetto. Si usa con preload().

const ORDINE_TIER := ["low", "mid", "saint", "angel", "god"]


static func _root() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	return (loop as SceneTree).root if loop is SceneTree else null


## true se OGNI condizione della lista e' soddisfatta (lista vuota -> true).
static func tutte_soddisfatte(lista: Variant) -> bool:
	if typeof(lista) != TYPE_ARRAY:
		return true
	for c in lista:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		if not soddisfatta(str((c as Dictionary).get("tipo", "")), (c as Dictionary).get("valore")):
			return false
	return true


static func soddisfatta(tipo: String, valore: Variant) -> bool:
	var root: Node = _root()
	if root == null:
		return true
	match tipo:
		"e_notte":
			var ts: Node = root.get_node_or_null("TimeSystem")
			var atteso: bool = bool(valore) if typeof(valore) == TYPE_BOOL else true
			return ts == null or bool(ts.call("e_notte")) == atteso
		"fase_lunare":
			var ts: Node = root.get_node_or_null("TimeSystem")
			return ts == null or str(ts.call("fase_lunare")) == str(valore)
		"in_zona_tag":
			var ws: Node = root.get_node_or_null("WorldState")
			return ws == null or str(ws.call("zona_corrente")) == str(valore)
		"foundation_min":
			var f: Node = root.get_node_or_null("Foundation")
			return f == null or float(f.call("valore")) >= _num(valore)
		"tier_min":
			var p: Node = root.get_node_or_null("Progression")
			if p == null:
				return true
			return ORDINE_TIER.find(str(p.call("tier"))) >= ORDINE_TIER.find(str(valore))
		"madness_min", "follia_min":
			var m: Node = root.get_node_or_null("Madness")
			return m == null or float(m.call("valore")) >= _num(valore)
		"madness_max":
			var m: Node = root.get_node_or_null("Madness")
			return m == null or float(m.call("valore")) <= _num(valore)
		"acting_progress_min":
			var a: Node = root.get_node_or_null("Acting")
			return a == null or float(a.call("acting_progress")) >= _num(valore)
		"reputazione_min":
			# US-615: FactionSystem non esiste ancora -> non blocca.
			var fs: Node = root.get_node_or_null("FactionSystem")
			if fs == null or typeof(valore) != TYPE_ARRAY or (valore as Array).size() < 2:
				return true
			return float(fs.call("reputazione", str(valore[0]))) >= _num(valore[1])
		"flag":
			# US-613: FlagStore/KnowledgeStore.
			var ks: Node = root.get_node_or_null("KnowledgeStore")
			return ks == null or bool(ks.call("conosce", str(valore)))
	return true


static func _num(v: Variant) -> float:
	return float(v) if typeof(v) in [TYPE_FLOAT, TYPE_INT] else 0.0
