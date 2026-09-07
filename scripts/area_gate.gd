extends Area2D
## US-611 — una barriera che legge un blocco di regions.json.gating[] e si apre
## o chiude secondo uno dei 6 modi di data/schema/gate_types.json. Il ramo e'
## sul TIPO (vocabolario chiuso), MAI sulla regione o sull'area: un modo nuovo
## e' una voce in gate_types.json + un ramo qui (discussione, come le primitive).
##
## terrain_modify permanente:true che la tocca la apre PER SEMPRE
## (WorldState.gate_aperti, serializzato nel save) — design-world.md cap. 4.
##
## NIENTE class_name: coerente col resto del progetto (si usa con preload()).

signal stato_cambiato(aperto: bool)

const LARGH := 96.0
const ALT := 160.0

var _region_id: String = ""
var _gate: Dictionary = {}
var _aperto: bool = false
var _barriera: CollisionShape2D
var _marker: ColorRect


func configura(region_id: String, gate: Dictionary) -> void:
	_region_id = region_id
	_gate = gate if typeof(gate) == TYPE_DICTIONARY else {}


func _ready() -> void:
	# rilevamento del giocatore (per un tell futuro) + forma dell'Area2D
	var forma := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(LARGH, ALT)
	forma.shape = rs
	add_child(forma)

	# blocco fisico quando chiusa: uno StaticBody2D che il player non attraversa
	var corpo := StaticBody2D.new()
	corpo.name = "Barriera"
	_barriera = CollisionShape2D.new()
	var rs2 := RectangleShape2D.new()
	rs2.size = Vector2(LARGH, ALT)
	_barriera.shape = rs2
	corpo.add_child(_barriera)
	add_child(corpo)

	_marker = ColorRect.new()
	_marker.size = Vector2(LARGH, ALT)
	_marker.position = -0.5 * Vector2(LARGH, ALT)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marker)

	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null and ws.has_signal("terreno_modificato"):
		ws.terreno_modificato.connect(_su_terreno)

	_aggiorna()


func _process(_delta: float) -> void:
	_aggiorna()


## id stabile della barriera: <regione>/<area>. Lo usa WorldState.gate_aperti
## per l'apertura permanente da terrain_modify.
func id() -> String:
	return "%s/%s" % [_region_id, str(_gate.get("area", ""))]


## true se il passaggio e' aperto ORA (o aperto per sempre da un terrain_modify).
func e_aperto() -> bool:
	return valuta_gate(_region_id, _gate, get_tree().root if is_inside_tree() else null)


func _aggiorna() -> void:
	var ap: bool = e_aperto()
	if _barriera != null:
		_barriera.set_deferred("disabled", ap)
	if _marker != null:
		_marker.color = Color(0.3, 0.85, 0.4, 0.28) if ap else Color(0.85, 0.22, 0.22, 0.45)
	if ap != _aperto:
		_aperto = ap
		stato_cambiato.emit(ap)


## Un terrain_modify permanente (WorldState.registra_terreno emette il segnale
## solo in quel caso) che copre la barriera la apre per sempre.
func _su_terreno(_tipo: String, posizione: Vector2, raggio: float) -> void:
	if global_position.distance_to(posizione) <= maxf(raggio, 1.0):
		var ws: Node = get_node_or_null("/root/WorldState")
		if ws != null:
			ws.call("apri_gate", id())


## Valutazione pura, senza nodo: la usano sia la barriera in scena sia il
## controllo dei passaggi fra regioni (region_scene). 'root' e' /root.
static func valuta_gate(region_id: String, gate: Dictionary, root: Node) -> bool:
	if typeof(gate) != TYPE_DICTIONARY or root == null:
		return true
	var gid: String = "%s/%s" % [region_id, str(gate.get("area", ""))]
	var ws: Node = root.get_node_or_null("WorldState")
	if ws != null and bool(ws.call("gate_e_aperto", gid)):
		return true

	match str(gate.get("tipo", "")):
		"momento":
			var ts: Node = root.get_node_or_null("TimeSystem")
			return ts != null and str(ts.call("momento")) == str(gate.get("valore"))
		"fase_lunare":
			var ts2: Node = root.get_node_or_null("TimeSystem")
			return ts2 != null and str(ts2.call("fase_lunare")) == str(gate.get("valore"))
		"sequenza":
			# La Frontiera "respinge chi e' sopra la Sequenza N": piu' avanti =
			# numero piu' basso. Aperto se la Sequenza corrente e' >= N.
			var pr: Node = root.get_node_or_null("Progression")
			return pr == null or int(pr.call("sequence")) >= int(gate.get("valore", 0))
		"primitiva":
			return _possiede_primitiva(root, str(gate.get("primitiva", "")))
		"conoscenza":
			var ks: Node = root.get_node_or_null("KnowledgeStore")
			return ks != null and bool(ks.call("conosce", str(gate.get("valore"))))
		"npc":
			# US-612: NpcSystem porta influenza(id, modo) -> npc_influenced.
			var ns: Node = root.get_node_or_null("NpcSystem")
			return ns != null and ns.has_method("ha_influenza") and bool(ns.call("ha_influenza", str(gate.get("valore"))))
	return false


## Il giocatore "possiede" una primitiva se una delle abilita' delle Sequenze
## che ha gia' raggiunto (9 -> corrente) la compone. Nessun nome di Pathway:
## si legge la spina dorsale dai dati.
static func _possiede_primitiva(root: Node, prim: String) -> bool:
	if prim.is_empty():
		return false
	var pr: Node = root.get_node_or_null("Progression")
	var gd: Node = root.get_node_or_null("GameData")
	if pr == null or gd == null:
		return false
	var pathway_id: String = str(pr.call("pathway"))
	if pathway_id.is_empty():
		return false
	for n in range(9, int(pr.call("sequence")) - 1, -1):
		var sd: Dictionary = gd.call("get_sequence", "%s_%d" % [pathway_id, n])
		for aid in sd.get("abilities", []):
			var ab: Dictionary = gd.call("get_ability", str(aid))
			for p in ab.get("primitive", []):
				if typeof(p) == TYPE_DICTIONARY and str((p as Dictionary).get("tipo", "")) == prim:
					return true
	return false
