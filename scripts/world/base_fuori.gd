extends Node2D
## US-8B20c: fuori dalla sede della base (BaseSystem.sede(), la porta di quell'interno nel mondo) l'orto: un
## appezzamento per ogni appezzamento del giardino (rooms.json, bonus del livello), col disegno del suo stato (vuoto,
## germoglio, pianta, maturo: data/balance.json giardino.pianta_da); finche' il giardino non e' costruito, il
## cantiere. Dove: "esterno" dell'interno della base (caselle dalla porta; la libera piu' vicina che non stia sotto
## un tetto o una chioma ne' davanti alla porta). Vicino all'orto "interagisci" apre la pagina Base del libro. Va con la sede.
##
## NIENTE class_name: coerente col progetto.

const PageInventario := preload("res://scripts/pages/page_inventario.gd")
const AGGIORNA := 1.0                         # secondi fra un controllo della crescita e l'altro

var _mondo: Node2D
var _cella := Vector2i(-1, -1)                # la prima casella dell'orto ((-1, -1) = la sede non ha porta fuori)
var _area: Area2D
var _prompt: Label
var _vicino := false
var _tempo := 0.0


func _ready() -> void:
	name = "BaseFuori"
	y_sort_enabled = true                     # i disegni si ordinano col giocatore
	set_meta("livello", "superficie")
	if _mondo == null:
		_mondo = get_parent()
	var bs: Node = _auto("BaseSystem")
	if bs != null:
		for sig in ["stanza_costruita", "stanza_potenziata", "raccolto", "appezzamento_pronto"]:
			bs.connect(sig, _su_base)
		bs.connect("sede_cambiata", _su_sede)
	_su_sede()


func _process(delta: float) -> void:
	_tempo += delta
	if _tempo >= AGGIORNA:
		_tempo = 0.0
		disegna()


## La casella dove comincia l'orto ((-1, -1) se la sede non ha una porta nel mondo).
func cella_orto() -> Vector2i:
	return _cella


func _su_sede(_a: Variant = null) -> void:
	_cella = _posto("giardino", _larghezza_orto())
	_crea_area()
	disegna()


func _su_base(_a: Variant = null, _b: Variant = null) -> void:
	disegna()


## Rifa' i disegni dell'orto dallo stato del giardino.
func disegna() -> void:
	for c in get_children():
		if c is Sprite2D:
			remove_child(c)
			c.queue_free()
	if _cella.x < 0:
		return
	var bs: Node = _auto("BaseSystem")
	if bs == null:
		return
	if int(bs.call("livello", "giardino")) <= 0:
		_metti("cantiere", _cella)
		return
	var stato: Array = bs.call("appezzamenti")
	for i in stato.size():
		_metti("orto_" + _stadio(stato[i]), _cella + Vector2i(i, 0))


## vuoto, germoglio, pianta (da giardino.pianta_da della crescita) o maturo.
func _stadio(a: Dictionary) -> String:
	if str(a.get("item_id", "")).is_empty():
		return "vuoto"
	if bool(a.get("pronto", false)):
		return "maturo"
	var g: Dictionary = _auto("GameData").call("get_balance", "giardino")
	var fatta: float = 1.0 - float(a.get("crescita", 0.0)) / maxf(float(g.get("tempo_crescita_s", 30.0)), 0.1)
	return "pianta" if fatta >= float(g.get("pianta_da", 0.5)) else "germoglio"


func _metti(id: String, c: Vector2i) -> void:
	var gs: Node = _auto("GameState")
	var path := "res://assets/interni/%s/arredi/%s.png" % [str(gs.call("tema_arte")) if gs != null else "luminoso", id]
	var voce: Dictionary = _auto("GameData").call("get_arredo", id)
	if voce.is_empty() or not FileAccess.file_exists(path):
		return
	var f := FileAccess.open("res://assets/interni/arredi.json", FileAccess.READ)
	var an: Array = ((JSON.parse_string(f.get_as_text()) as Dictionary).get(id, [0, 0]) as Array) if f != null else [0, 0]
	var m: Array = voce["misura"]
	var tile: float = float(_mondo.get("tile"))
	var spr := Sprite2D.new()
	spr.name = "Orto_%s_%d_%d" % [id, c.x, c.y]
	spr.texture = preload("res://scripts/world/mondo.gd")._texture(path)
	spr.centered = false
	spr.offset = -Vector2(float(an[0]), float(an[1]))
	spr.position = Vector2((c.x + float(m[0]) / 2.0) * tile, (c.y + int(m[1])) * tile)
	add_child(spr)


## Quante caselle in fila servono all'orto: il massimo degli appezzamenti del giardino, almeno quelle del cantiere.
func _larghezza_orto() -> int:
	var gd: Node = _auto("GameData")
	var n: int = int((gd.call("get_arredo", "cantiere") as Dictionary).get("misura", [2, 1])[0]) if gd != null else 2
	for lv in (gd.call("room_levels", "giardino") if gd != null else []):
		n = maxi(n, int(((lv as Dictionary).get("bonus", {}) as Dictionary).get("appezzamenti", 0)))
	return n


## La casella da cui parte una fila di n caselle per la voce "esterno" della sede: vicino alla porta + lo scostamento
## dei dati, tutte libere, nella regione della porta, non sotto il tetto di una casa ne' sul passaggio della porta.
func _posto(chiave: String, n: int) -> Vector2i:
	var bs: Node = _auto("BaseSystem")
	var sede: String = str(bs.call("sede")) if bs != null else ""
	var porta: Node2D = _mondo.get_node_or_null("Porta_" + sede) as Node2D
	if porta == null:
		return Vector2i(-1, -1)
	var tile: float = float(_mondo.get("tile"))
	var p := Vector2i(floori(porta.position.x / tile), floori(porta.position.y / tile))
	var s: Array = ((_auto("GameData").call("get_interno", sede) as Dictionary).get("esterno", {}) as Dictionary) \
			.get(chiave, [2, 1])
	var c := p + Vector2i(int(s[0]), int(s[1]))
	var rid: String = str(_mondo.call("regione_a", p.x, p.y))
	for r in 12:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := c + Vector2i(dx, dy)
				var ok := true
				for i in n:
					if not _libera(q + Vector2i(i, 0), p, rid):
						ok = false
						break
				if ok:
					return q
	return Vector2i(-1, -1)


func _libera(q: Vector2i, porta: Vector2i, rid: String) -> bool:
	if absi(q.x - porta.x) <= 1 and q.y >= porta.y - 1 and q.y <= porta.y + 3:
		return false                          # il passaggio davanti alla porta resta libero
	if str(_mondo.call("regione_a", q.x, q.y)) != rid:
		return false
	for dy in 4:                              # una casa sotto coprirebbe la casella col suo tetto
		if _mondo.call("bloccata", q.x, q.y + dy):
			return false
	var tile: float = float(_mondo.get("tile"))
	for fy in [0.25, 0.75]:                   # ne' la chioma di un albero piu' a sud
		if _mondo.call("coperto", Vector2((q.x + 0.5) * tile, (q.y + fy) * tile)):
			return false
	return true


func _crea_area() -> void:
	if _area != null:
		remove_child(_area)
		_area.queue_free()
		_area = null
	_vicino = false
	if _cella.x < 0:
		return
	var tile: float = float(_mondo.get("tile"))
	var n: int = _larghezza_orto()
	_area = Area2D.new()
	_area.name = "Orto"
	_area.position = Vector2((_cella.x + n / 2.0) * tile, (_cella.y + 0.5) * tile)
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(n + 2, 3) * tile
	forma.shape = rect
	_area.add_child(forma)
	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.add_theme_font_size_override("font_size", 10)
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt.add_theme_color_override("font_outline_color", Color("#181425"))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(6 * tile, tile * 0.5)
	_prompt.position = Vector2(-3 * tile, -tile * 1.0)          # sopra le cassette, non su Enel
	_prompt.z_index = 10
	_prompt.text = tr("HUD_PROMPT_ORTO").format({"tasto": _tasto()})
	_prompt.hide()
	_area.add_child(_prompt)
	_area.body_entered.connect(func(b: Node) -> void:
		if b.is_in_group("player"):
			_vicino = true
			_prompt.show())
	_area.body_exited.connect(func(b: Node) -> void:
		if b.is_in_group("player"):
			_vicino = false
			_prompt.hide())
	add_child(_area)


## Il libro sulla pagina Base (inventario, sezione base), dove si pianta e si raccoglie.
func apri_base() -> bool:
	var book: Node = _auto("Book")
	if book == null or bool(book.call("e_aperto")):
		return false
	PageInventario.prossima_sezione = "base"
	book.call("apri_a", "inventario")
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _vicino or not event.is_action_pressed("interagisci"):
		return
	var de: Node = _auto("DialogueEngine")
	if de != null and bool(de.call("in_corso")):
		return
	if apri_base():
		get_viewport().set_input_as_handled()


func _tasto() -> String:
	for ev in InputMap.action_get_events("interagisci"):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return "F"


func _auto(nome: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(nome)
