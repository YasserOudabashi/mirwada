extends Area2D
## US-8B22: un forziere. Sta nei dati del luogo ('forzieri' [{id, x, y, tabella}] di un interno); la tabella di
## bottino e' in data/world/bottino.json. "interagisci" vicino: si apre una volta sola (WorldState, nel salvataggio),
## il bottino tirato dalla tabella va nello zaino e una scritta sopra dice cosa c'era. Disegni: gli arredi
## forziere / forziere_aperto (tools/art/build_interni.py), con i piedi in basso al centro della casella.
## La casella non si attraversa (un corpo sul livello dei muri).
##
## NIENTE class_name: coerente col progetto.

signal aperto(bottino: Array)

const TILE := 32
const DURATA_SCRITTA := 3.0

var forziere_id: String = ""
var tabella: String = ""
var rng := RandomNumberGenerator.new()

var _vicino := false
var _chi: Node2D = null                          # chi sta accanto (il giocatore): la scritta va sotto di lui
var _sprite: Sprite2D
var _prompt: Label
var _scritta: Label


func _init() -> void:
	rng.randomize()


## Prima di aggiungerlo all'albero: id del forziere (per il salvataggio), tabella, centro della casella.
func setup(id: String, tab: String, posizione: Vector2) -> void:
	forziere_id = id
	tabella = tab
	position = posizione


func _ready() -> void:
	name = "Forziere_%s" % forziere_id
	var area := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(TILE, TILE) * 2.4                  # fino alle caselle accanto, dove sta chi lo apre
	area.shape = r
	add_child(area)
	var corpo := StaticBody2D.new()                 # la casella del forziere e' piena, come un arredo
	var forma := CollisionShape2D.new()
	var rc := RectangleShape2D.new()
	rc.size = Vector2(TILE, TILE) * 0.8
	forma.shape = rc
	corpo.add_child(forma)
	add_child(corpo)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.position = Vector2(0, TILE / 2.0)
	add_child(_sprite)
	_prompt = _etichetta(Vector2(-TILE * 1.5, -TILE * 1.45))   # sopra: sotto c'e' chi lo apre, col suo nome
	_prompt.text = tr("HUD_PROMPT_APRI").format({"tasto": _tasto_interagisci()})
	_prompt.hide()
	_scritta = _etichetta(Vector2(-TILE * 3, TILE * 0.5))
	_scritta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scritta.hide()
	_disegna()
	body_entered.connect(_su_corpo.bind(true))
	body_exited.connect(_su_corpo.bind(false))


func e_aperto() -> bool:
	var ws: Node = get_node_or_null("/root/WorldState")
	return ws != null and bool(ws.call("forziere_aperto", forziere_id))


## Apre il forziere: il bottino nello zaino, il forziere segnato aperto. [] se era gia' aperto.
func apri() -> Array:
	if e_aperto():
		return []
	var gd: Node = get_node_or_null("/root/GameData")
	var bottino: Array = tira(gd.call("get_tabella_bottino", tabella) if gd != null else {}, rng)
	var inv: Node = get_node_or_null("/root/Inventory")
	var nomi: PackedStringArray = []
	for voce in bottino:
		if inv != null:
			inv.call("aggiungi", voce["item_id"], voce["quantita"])
		var it: Dictionary = gd.call("get_item", voce["item_id"]) if gd != null else {}
		var nome: String = str(gd.call("tr_data", it.get("name_i18n", voce["item_id"]))) if gd != null else str(voce["item_id"])
		nomi.append("%d %s" % [voce["quantita"], nome])
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		ws.call("apri_forziere", forziere_id)
	_disegna()
	_prompt.hide()
	_scritta.text = tr("HUD_FORZIERE_TROVATO").format({"oggetti": ", ".join(nomi)})
	# sotto chi lo apre, come gli avvisi del mondo (mondo._mostra_avviso): sopra c'e' la barra dell'HUD
	var piedi: Vector2 = (_chi.global_position - global_position) if is_instance_valid(_chi) else Vector2.ZERO
	_scritta.position = piedi + Vector2(-TILE * 3, TILE * 0.5)
	_scritta.show()
	get_tree().create_timer(DURATA_SCRITTA).timeout.connect(func() -> void:
		if is_instance_valid(_scritta):
			_scritta.hide())
	aperto.emit(bottino)
	return bottino


## Da tiri[0] a tiri[1] estrazioni pesate dalla tabella; ogni voce estratta da' da quantita[0] a quantita[1] pezzi.
## Le voci uguali si sommano. -> [{item_id, quantita}] nell'ordine della prima estrazione.
static func tira(tab: Dictionary, generatore: RandomNumberGenerator) -> Array:
	var voci: Array = tab.get("voci", [])
	var tiri: Array = tab.get("tiri", [1, 1])
	var totale := 0.0
	for v in voci:
		totale += float((v as Dictionary).get("peso", 0))
	var out: Array = []
	var indice: Dictionary = {}
	if voci.is_empty() or totale <= 0.0:
		return out
	for _i in generatore.randi_range(int(tiri[0]), int(tiri[1])):
		var x: float = generatore.randf() * totale
		var scelta: Dictionary = voci[-1]
		for v in voci:
			x -= float((v as Dictionary).get("peso", 0))
			if x < 0.0:
				scelta = v
				break
		var q: Array = scelta.get("quantita", [1, 1])
		var n: int = generatore.randi_range(int(q[0]), int(q[1]))
		var id: String = str(scelta.get("item_id", ""))
		if indice.has(id):
			out[indice[id]]["quantita"] += n
		else:
			indice[id] = out.size()
			out.append({"item_id": id, "quantita": n})
	return out


func _unhandled_input(event: InputEvent) -> void:
	if not _vicino or not event.is_action_pressed("interagisci") or e_aperto():
		return
	var book: Node = get_node_or_null("/root/Book")
	var de: Node = get_node_or_null("/root/DialogueEngine")
	if (book != null and bool(book.call("e_aperto"))) or (de != null and bool(de.call("in_corso"))):
		return
	apri()
	get_viewport().set_input_as_handled()


func _su_corpo(body: Node, dentro: bool) -> void:
	if not body.is_in_group("player"):
		return
	_vicino = dentro
	_chi = body as Node2D if dentro else null
	_prompt.visible = dentro and not e_aperto()


func _disegna() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	var tema: String = str(gs.call("tema_arte")) if gs != null else "luminoso"
	var id: String = "forziere_aperto" if e_aperto() else "forziere"
	var path: String = "res://assets/interni/%s/arredi/%s.png" % [tema, id]
	if not FileAccess.file_exists(path):
		return
	_sprite.texture = preload("res://scripts/world/mondo.gd")._texture(path)
	var f := FileAccess.open("res://assets/interni/arredi.json", FileAccess.READ)
	var ancore: Dictionary = (JSON.parse_string(f.get_as_text()) as Dictionary) if f != null else {}
	var an: Array = ancore.get(id, [0, 0])
	_sprite.offset = -Vector2(float(an[0]), float(an[1]))


func _etichetta(pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color("#181425"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(-pos.x * 2, TILE * 0.5)
	l.position = pos
	l.z_index = 10
	add_child(l)
	return l


func _tasto_interagisci() -> String:
	for ev in InputMap.action_get_events("interagisci"):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return "F"
