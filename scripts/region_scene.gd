extends TileMapLayer
## Scena placeholder di una regione (US-602/603). UNA sola implementazione per
## tutte e 5 le regioni: il contenuto (id, location_tags, palette) viene dai
## dati (data/world/regions.json via GameData). Una scena .tscn per regione
## imposta solo region_id nell'inspector.
##
## Come la zona di test di US-006, e' un tilemap diagnostico: bordo di muri e
## un pavimento, con una Area2D per ogni location_tag della regione (marcata
## col tag, cosi' entrando ci si legge dove si e') e i passaggi verso le altre
## regioni (hub-and-spoke: la citta' e' collegata a tutte, ognuna torna alla
## citta'). L'arte vera e i biomi disegnati a mano sono un non-goal di questa
## fase; il gating dei passaggi si applica in US-611.
##
## NIENTE class_name: coerente col resto del progetto.

signal zona_cambiata(location_tag: String)

const AreaGate := preload("res://scripts/area_gate.gd")

const TILE := 32
const W := 48
const H := 36

const SORGENTE := 0
const PAVIMENTO := Vector2i(0, 0)
const MURO := Vector2i(1, 0)

## Cella di comparsa del giocatore.
const SPAWN := Vector2i(4, 4)
## La regione hub: collegata a tutte le altre (design-world cap. 2.1).
const HUB := "mirwada"

## Regione da caricare. Le .tscn in scenes/regioni/ lo impostano.
@export var region_id: String = ""

var _tag_corrente: String = ""
var _in_viaggio: bool = false
## L'NPC nel cui raggio si trova il giocatore ("" = nessuno). Premere
## "interagisci" qui sopra avvia il suo dialogo (US-613b).
var _npc_vicino: String = ""


func _ready() -> void:
	tile_set = load("res://assets/placeholder/tileset.tres")
	_dipingi()
	_tinta_di_fondo()
	_crea_zone()
	_crea_passaggi()
	_crea_gate()
	_crea_npc()
	_colloca_giocatore()
	_registra_regione()
	var ts: Node = get_node_or_null("/root/TimeSystem")
	if ts != null and ts.has_signal("momento_cambiato"):
		ts.momento_cambiato.connect(func(_m): _crea_npc())


func _regione_dati() -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("get_region", region_id) if gd != null else {}


func _dipingi() -> void:
	for x in W:
		for y in H:
			var bordo: bool = x == 0 or y == 0 or x == W - 1 or y == H - 1
			set_cell(Vector2i(x, y), SORGENTE, MURO if bordo else PAVIMENTO)


## Densita' mistica visiva minima: una tinta di sfondo dalla palette_visiva
## della regione (design-world cap. 2). 'neutra' non ha palette -> niente
## tinta (la citta' resta piatta).
func _tinta_di_fondo() -> void:
	var pal_id: String = str(_regione_dati().get("palette_visiva", ""))
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null or pal_id.is_empty() or pal_id == "neutra":
		return
	var pal: Dictionary = gd.call("get_vfx_palette", pal_id)
	var hex: String = str(pal.get("primario", ""))
	if not hex.begins_with("#"):
		return
	var c := Color(hex)
	c.a = 0.14
	var rect := ColorRect.new()
	rect.name = "TintaRegione"
	rect.color = c
	rect.position = Vector2.ZERO
	rect.size = Vector2(W * TILE, H * TILE)
	rect.z_index = -100
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


## Una Area2D per location_tag, disposte a griglia nell'interno. Ogni zona
## porta il proprio tag come meta: entrando, il giocatore "legge" dove si
## trova (US-602). La grafica e' assente: e' un rettangolo invisibile.
func _crea_zone() -> void:
	var tags: Array = (_regione_dati().get("location_tags", []) as Array)
	if tags.is_empty():
		return

	# griglia di celle-zona nell'area interna (dentro il bordo di muri)
	var cols: int = int(ceil(sqrt(float(tags.size()))))
	var righe: int = int(ceil(float(tags.size()) / float(cols)))
	var cell_w: float = float(W - 2) * TILE / float(cols)
	var cell_h: float = float(H - 2) * TILE / float(righe)

	for i in tags.size():
		var col: int = i % cols
		var row: int = i / cols
		var centro := Vector2(
			TILE + cell_w * (col + 0.5),
			TILE + cell_h * (row + 0.5))
		var area := Area2D.new()
		area.name = "Zona_%s" % str(tags[i])
		area.set_meta("location_tag", str(tags[i]))
		area.position = centro
		# monitora il corpo del giocatore (layer 1): mask di default 1 basta.
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(cell_w, cell_h)
		shape.shape = rect
		area.add_child(shape)
		area.body_entered.connect(_su_ingresso_zona.bind(str(tags[i])))
		add_child(area)


## I passaggi verso le altre regioni. Hub-and-spoke: la citta' ha un passaggio
## per ogni altra regione lungo il bordo destro; ogni altra regione ne ha uno
## verso la citta' lungo il bordo sinistro. Gli id di destinazione escono dai
## dati (GameData.get_regions), nessun nome hardcoded.
func _crea_passaggi() -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return
	var destinazioni: Array = []
	if region_id == HUB:
		for r in gd.call("get_regions"):
			var rid: String = str((r as Dictionary).get("id", ""))
			if rid != HUB and not rid.is_empty():
				destinazioni.append(rid)
	elif not region_id.is_empty():
		destinazioni.append(HUB)

	for i in destinazioni.size():
		var lato_destro: bool = region_id == HUB
		var x: float = float(W - 3) * TILE if lato_destro else 3.0 * TILE
		var y: float = TILE * 3 + (float(H - 6) * TILE) * (float(i) + 0.5) / float(maxi(destinazioni.size(), 1))
		var area := Area2D.new()
		area.name = "Passaggio_%s" % destinazioni[i]
		area.set_meta("target_region", destinazioni[i])
		area.position = Vector2(x, y)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE * 1.5, TILE * 2)
		shape.shape = rect
		area.add_child(shape)
		var marker := ColorRect.new()
		marker.color = Color(0.9, 0.85, 0.3, 0.5)
		marker.position = -rect.size * 0.5
		marker.size = rect.size
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.add_child(marker)
		area.body_entered.connect(_su_passaggio.bind(str(destinazioni[i])))
		add_child(area)


## Una AreaGate per ogni voce di regions.json.gating[]: una barriera che si
## apre/chiude coi 6 modi di gate_types.json (US-611). Disposte in colonna
## nell'interno; l'arte vera e la geometria sono un non-goal di fase 6.
func _crea_gate() -> void:
	var gates: Array = (_regione_dati().get("gating", []) as Array)
	for i in gates.size():
		var g: Variant = gates[i]
		if typeof(g) != TYPE_DICTIONARY:
			continue
		var ag: Area2D = AreaGate.new()
		ag.name = "Gate_%s" % str((g as Dictionary).get("area", i))
		ag.position = Vector2(
			float(W) * 0.5 * TILE,
			TILE * 4 + (float(H - 8) * TILE) * (float(i) + 0.5) / float(maxi(gates.size(), 1)))
		ag.call("configura", region_id, g)
		add_child(ag)


## Gli NPC presenti ORA (schedule + momento corrente, US-612): un marker nella
## zona del loro location_tag. Ricostruito a ogni momento_cambiato - Bruno
## compare solo di notte, Mirco sparisce a notte_fonda. Entrarci = "incontrato".
func _crea_npc() -> void:
	for c in get_children():
		if c is Area2D and c.has_meta("npc_id"):
			c.queue_free()
	var ns: Node = get_node_or_null("/root/NpcSystem")
	if ns == null:
		return
	var presenti: Dictionary = ns.call("presenti", region_id)
	for id in presenti:
		var zona: Node2D = get_node_or_null("Zona_%s" % str(presenti[id])) as Node2D
		var area := Area2D.new()
		area.name = "Npc_%s" % str(id)
		area.set_meta("npc_id", str(id))
		area.position = zona.position if zona != null else Vector2(W, H) * TILE * 0.5
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE, TILE) * 1.2
		shape.shape = rect
		area.add_child(shape)
		var m := ColorRect.new()
		m.color = Color(0.4, 0.6, 0.95, 0.8)
		m.size = Vector2(TILE, TILE)
		m.position = -0.5 * m.size
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.add_child(m)
		area.body_entered.connect(_npc_avvicinato.bind(str(id)))
		area.body_exited.connect(_npc_allontanato.bind(str(id)))
		add_child(area)


func _npc_avvicinato(body: Node, id: String) -> void:
	if not body.is_in_group("player"):
		return
	var ns: Node = get_node_or_null("/root/NpcSystem")
	if ns != null:
		ns.call("incontra", id)
	_npc_vicino = id


func _npc_allontanato(body: Node, id: String) -> void:
	if body.is_in_group("player") and _npc_vicino == id:
		_npc_vicino = ""


## "interagisci" vicino a un NPC -> avvia il suo dialogo (nessun if per un NPC:
## dialogue_id viene dal roster). No-op se il libro e' gia' aperto o un dialogo
## e' in corso.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interagisci") or _npc_vicino.is_empty():
		return
	var de: Node = get_node_or_null("/root/DialogueEngine")
	var book: Node = get_node_or_null("/root/Book")
	if de == null or bool(de.call("in_corso")) or (book != null and bool(book.call("e_aperto"))):
		return
	var gd: Node = get_node_or_null("/root/GameData")
	var did: String = str(gd.call("get_npc", _npc_vicino).get("dialogue_id", "")) if gd != null else ""
	if not did.is_empty() and de.call("avvia", did, _npc_vicino):
		get_viewport().set_input_as_handled()


func _su_ingresso_zona(body: Node, location_tag: String) -> void:
	if not body.is_in_group("player"):
		return
	if location_tag == _tag_corrente:
		return
	_tag_corrente = location_tag
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		ws.call("imposta_zona", location_tag)
	zona_cambiata.emit(location_tag)


func _su_passaggio(body: Node, target: String) -> void:
	if _in_viaggio or not body.is_in_group("player"):
		return
	if not _ingresso_aperto(target):
		return  # la regione respinge (es. la Frontiera oltre la Sequenza 4)
	_in_viaggio = true
	_viaggia_verso.call_deferred(target)


## Un gating con area "ingresso" chiude la regione stessa (US-611): la
## convenzione e' nel dato, non un caso per una regione. Le altre aree di
## gating sono barriere interne (AreaGate in scena).
func _ingresso_aperto(target: String) -> bool:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return true
	for g in (gd.call("get_region", target).get("gating", []) as Array):
		if typeof(g) == TYPE_DICTIONARY and str((g as Dictionary).get("area", "")) == "ingresso":
			return AreaGate.valuta_gate(target, g, get_tree().root)
	return true


## US-617: fast travel dalla pagina mappa del libro. Come _su_passaggio ma
## senza l'Area2D di confine (il "mezzo" lo verifica la pagina). Rispetta
## comunque il gating d'ingresso. false se un viaggio e' gia' in corso o la
## regione respinge.
func viaggia_a(target: String) -> bool:
	if _in_viaggio or target == region_id or not _ingresso_aperto(target):
		return false
	if not ResourceLoader.exists("res://scenes/regioni/%s.tscn" % target):
		return false
	_in_viaggio = true
	_viaggia_verso.call_deferred(target)
	return true


## Sostituisce questa scena di regione con quella della destinazione. Il player
## e gli overlay vivono in main.tscn (fratelli): restano, la nuova regione li
## riposiziona nel suo _ready. Finche' il gating (US-611) non c'e', ogni
## passaggio e' aperto.
func _viaggia_verso(target: String) -> void:
	var scena_path: String = "res://scenes/regioni/%s.tscn" % target
	var padre: Node = get_parent()
	if padre == null or not ResourceLoader.exists(scena_path):
		_in_viaggio = false
		return
	var nuova: Node = load(scena_path).instantiate()
	padre.add_child(nuova)
	queue_free()


## Il location_tag della zona in cui si trova il giocatore ("" fuori da ogni
## zona nominata). Lo leggeranno il gating (US-611) e le condizioni
## in_zona_tag delle abilita' (US-605).
func tag_corrente() -> String:
	return _tag_corrente


## Gli id di regione raggiungibili da un passaggio di questa scena.
func passaggi_verso() -> Array:
	var out: Array = []
	for c in get_children():
		if c is Area2D and c.has_meta("target_region"):
			out.append(str(c.get_meta("target_region")))
	return out


func _colloca_giocatore() -> void:
	var player := get_parent().get_node_or_null("Player") as Node2D
	if player == null:
		return
	player.global_position = to_global(map_to_local(SPAWN))
	var cam := player.get_node_or_null("Camera2D")
	if cam != null and cam.has_method("apply_zone_limits"):
		cam.call("apply_zone_limits", Rect2(global_position, Vector2(W * TILE, H * TILE)))


func _registra_regione() -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null and not region_id.is_empty():
		ws.call("entra_regione", region_id)
