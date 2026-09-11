extends TileMapLayer
## Mondo continuo (fase 10, US-1002). Sostituisce region_scene.gd come UNICA
## scena caricata da main.gd: dipinge OGNI regione di GameData.get_regions()
## nella stessa TileMapLayer, ciascuna al proprio world_offset (US-1001),
## piu' i corridoi di raccordo (data/world/corridoi.json). Le funzioni per
## regione sono le stesse di region_scene.gd (_dipingi/_crea_zone/
## _crea_nemici/_crea_oggetti/_crea_npc/_crea_gate) - qui prendono un id di
## regione + un offset invece di leggere un @export unico, e girano in un
## ciclo invece che una volta per scena.
##
## Zero caricamenti di scena tra regioni: WorldState.regione_corrente() si
## aggiorna quando il giocatore entra nel rettangolo di un'altra regione
## (una Area2D per regione, grande quanto il suo rettangolo) - mai un
## reload. Entrare in un edificio resta un caricamento di scena locale
## (US-1010, non questa story).
##
## NIENTE class_name: coerente col resto del progetto.

signal zona_cambiata(location_tag: String)

const AreaGate := preload("res://scripts/area_gate.gd")

const TILE := 32
## Dimensione di fallback per una regione senza layout disegnato a mano
## (stessa costante di region_scene.gd, ora per-regione invece che globale).
const W_FALLBACK := 48
const H_FALLBACK := 36
const SORGENTE := 0
const HUB := "mirwada"

const _COLONNA_PER_CARATTERE := {
	".": 0, "#": 1, "o": 2, "~": 3, ",": 4, "=": 5, "t": 6, "+": 7,
}
const _COLONNA_MURO := 1
const _COLONNA_PAVIMENTO := 0

var _tag_corrente: String = ""
var _npc_vicino: String = ""
## dimensione reale (celle) di ogni regione, calcolata una volta in _ready
## dal suo layout (o il fallback 48x36) - riusata da tutto il resto.
var _dim_per_regione: Dictionary = {}
## id regione -> conteggio nemici vivi/aggregato "senza abilita'" per
## l'evento area_cleared (US-806), ora scoped per regione invece che
## globale a scena (una sola TileMapLayer ospita tutte e 5).
var _nemici_vivi_per_regione: Dictionary = {}
var _area_nemici_senza_abilita_per_regione: Dictionary = {}


func _ready() -> void:
	tile_set = load("res://assets/placeholder/tileset.tres")
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return
	for reg in gd.call("get_regions"):
		_prepara_regione(reg as Dictionary)
	_disegna_corridoi()
	_ricrea_tutti_npc()

	var cam: Node = _camera_giocatore()
	if cam != null and cam.has_method("clear_zone_limits"):
		cam.call("clear_zone_limits")

	var ts: Node = get_node_or_null("/root/TimeSystem")
	if ts != null and ts.has_signal("momento_cambiato"):
		ts.momento_cambiato.connect(func(_m): _ricrea_tutti_npc())

	# il prompt "[F] Parla" non deve restare a schermo col libro aperto sopra.
	var book: Node = get_node_or_null("/root/Book")
	if book != null:
		book.libro_aperto.connect(func(_p): _mostra_prompt(_npc_vicino, false))
		book.libro_chiuso.connect(func(): _mostra_prompt(_npc_vicino, not _npc_vicino.is_empty()))


func _camera_giocatore() -> Node:
	var player: Node = get_parent().get_node_or_null("Player") if get_parent() != null else null
	return player.get_node_or_null("Camera2D") if player != null else null


# --- per-regione: dipingere + popolare -------------------------------------

func _offset_di(reg: Dictionary) -> Vector2i:
	var wo: Array = reg.get("world_offset", [])
	if wo.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(wo[0]), int(wo[1]))


func _layout_dati(rid: String) -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("get_layout", rid) if gd != null else {}


func _dimensioni_layout(layout: Dictionary) -> Vector2i:
	var mappa: Array = (layout.get("mappa", []) as Array)
	if mappa.size() > 0 and str(mappa[0]).length() > 0:
		return Vector2i(str(mappa[0]).length(), mappa.size())
	return Vector2i(W_FALLBACK, H_FALLBACK)


func _prepara_regione(reg: Dictionary) -> void:
	var rid: String = str(reg.get("id", ""))
	if rid.is_empty():
		return
	var offset: Vector2i = _offset_di(reg)
	var layout: Dictionary = _layout_dati(rid)
	var dim: Vector2i = _dimensioni_layout(layout)
	_dim_per_regione[rid] = dim
	_dipingi(reg, layout, offset, dim)
	_tinta_di_fondo(reg, offset, dim)
	_crea_confine(rid, offset, dim)
	_crea_zone(reg, layout, offset, dim)
	_crea_gate(reg, offset, dim)
	_crea_nemici(rid, layout, offset)
	_crea_oggetti(layout, offset)


func _riga_tileset(reg: Dictionary) -> int:
	var pal_id: String = str(reg.get("palette_visiva", ""))
	if pal_id.is_empty() or pal_id == "neutra":
		return 0
	var gd: Node = get_node_or_null("/root/GameData")
	var ids: Array = gd.call("vfx_palette_ids") if gd != null else []
	var i: int = ids.find(pal_id)
	return 1 + i if i >= 0 else 0


func _dipingi(reg: Dictionary, layout: Dictionary, offset: Vector2i, dim: Vector2i) -> void:
	var riga: int = _riga_tileset(reg)
	var mappa: Array = (layout.get("mappa", []) as Array)
	if mappa.size() == dim.y:
		for y in dim.y:
			var stringa: String = str(mappa[y])
			if stringa.length() != dim.x:
				continue
			for x in dim.x:
				var col: int = int(_COLONNA_PER_CARATTERE.get(stringa[x], _COLONNA_PAVIMENTO))
				set_cell(offset + Vector2i(x, y), SORGENTE, Vector2i(col, riga))
		return
	for x in dim.x:
		for y in dim.y:
			var bordo: bool = x == 0 or y == 0 or x == dim.x - 1 or y == dim.y - 1
			var col: int = _COLONNA_MURO if bordo else _COLONNA_PAVIMENTO
			set_cell(offset + Vector2i(x, y), SORGENTE, Vector2i(col, riga))


func _tinta_di_fondo(reg: Dictionary, offset: Vector2i, dim: Vector2i) -> void:
	var pal_id: String = str(reg.get("palette_visiva", ""))
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
	rect.name = "Tinta_%s" % str(reg.get("id", ""))
	rect.color = c
	rect.position = map_to_local(offset)
	rect.size = Vector2(dim) * TILE
	rect.z_index = -100
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


## Una Area2D grande quanto il rettangolo della regione: quando il player la
## attraversa, WorldState.regione_corrente() si aggiorna. Sostituisce
## semanticamente il vecchio "passaggio" (US-602..): stesso principio (una
## Area2D di confine), comportamento diverso (aggiorna solo lo stato, MAI
## ricarica una scena).
func _crea_confine(rid: String, offset: Vector2i, dim: Vector2i) -> void:
	var area := Area2D.new()
	area.name = "Confine_%s" % rid
	area.position = map_to_local(offset) + Vector2(dim) * TILE * 0.5
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(dim) * TILE
	shape.shape = rect
	area.add_child(shape)
	area.body_entered.connect(_su_ingresso_regione.bind(rid))
	add_child(area)


func _su_ingresso_regione(body: Node, rid: String) -> void:
	if not body.is_in_group("player"):
		return
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		ws.call("entra_regione", rid)


func _crea_zone(reg: Dictionary, layout: Dictionary, offset: Vector2i, dim: Vector2i) -> void:
	var rid: String = str(reg.get("id", ""))
	var tags: Array = (reg.get("location_tags", []) as Array)
	if tags.is_empty():
		return
	var zone: Dictionary = (layout.get("zone", {}) as Dictionary)
	var cols: int = int(ceil(sqrt(float(tags.size()))))
	var righe: int = int(ceil(float(tags.size()) / float(cols)))
	var cell_w: float = float(dim.x - 2) * TILE / float(cols)
	var cell_h: float = float(dim.y - 2) * TILE / float(righe)
	var origine: Vector2 = map_to_local(offset)

	for i in tags.size():
		var tag: String = str(tags[i])
		var centro: Vector2
		var dimz: Vector2
		if zone.has(tag):
			var r: Array = (zone[tag] as Array)
			dimz = Vector2(float(r[2]), float(r[3])) * TILE
			centro = origine + Vector2(float(r[0]), float(r[1])) * TILE + dimz * 0.5
		else:
			var col: int = i % cols
			var row: int = i / cols
			dimz = Vector2(cell_w, cell_h)
			centro = origine + Vector2(TILE + cell_w * (col + 0.5), TILE + cell_h * (row + 0.5))
		var area := Area2D.new()
		area.name = "Zona_%s_%s" % [rid, tag]
		area.set_meta("location_tag", tag)
		area.position = centro
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = dimz
		shape.shape = rect
		area.add_child(shape)
		area.body_entered.connect(_su_ingresso_zona.bind(tag))
		add_child(area)


func _crea_gate(reg: Dictionary, offset: Vector2i, dim: Vector2i) -> void:
	var rid: String = str(reg.get("id", ""))
	var gates: Array = (reg.get("gating", []) as Array)
	var origine: Vector2 = map_to_local(offset)
	for i in gates.size():
		var g: Variant = gates[i]
		if typeof(g) != TYPE_DICTIONARY:
			continue
		var ag: Area2D = AreaGate.new()
		ag.name = "Gate_%s_%s" % [rid, str((g as Dictionary).get("area", i))]
		ag.position = origine + Vector2(
			float(dim.x) * 0.5 * TILE,
			TILE * 4 + (float(dim.y - 8) * TILE) * (float(i) + 0.5) / float(maxi(gates.size(), 1)))
		ag.call("configura", rid, g)
		add_child(ag)


func _crea_nemici(rid: String, layout: Dictionary, offset: Vector2i) -> void:
	var nemici: Array = (layout.get("nemici", []) as Array)
	var drop: Dictionary = (layout.get("drop", {}) as Dictionary)
	_nemici_vivi_per_regione[rid] = nemici.size()
	_area_nemici_senza_abilita_per_regione[rid] = true
	for n in nemici:
		var spec: Dictionary = n as Dictionary
		var sequenza: int = int(spec.get("sequenza", 9))
		var override: Dictionary = (spec.get("override", {}) as Dictionary).duplicate(true)
		if drop.has(str(sequenza)):
			override["oggetti_a_morte"] = drop[str(sequenza)]
		var e: Node = preload("res://scenes/enemy.tscn").instantiate()
		e.set("override", override)
		e.set("scale", Vector2.ONE * float(spec.get("scala", 1.0)))
		add_child(e)
		e.set("global_position", to_global(map_to_local(
			offset + Vector2i(int(spec.get("x", 0)), int(spec.get("y", 0))))))
		e.set("sequenza", sequenza)
		e.get_node("StatsComponent").call("configure_from_balance", sequenza)
		e.connect("morto", _su_nemico_morto.bind(rid))


func _su_nemico_morto(chi: Node, rid: String) -> void:
	if not bool(chi.call("senza_abilita")):
		_area_nemici_senza_abilita_per_regione[rid] = false
	_nemici_vivi_per_regione[rid] = int(_nemici_vivi_per_regione.get(rid, 1)) - 1
	if int(_nemici_vivi_per_regione.get(rid, 0)) > 0:
		return
	var et: Node = get_node_or_null("/root/EventTracker")
	if et != null:
		et.call("emit_event", "area_cleared", {
			"senza_alleati_caduti": true,
			"senza_abilita": bool(_area_nemici_senza_abilita_per_regione.get(rid, true)),
			"senza_uccidere": false,
		})


func _crea_oggetti(layout: Dictionary, offset: Vector2i) -> void:
	var oggetti: Array = (layout.get("oggetti", []) as Array)
	for o in oggetti:
		var spec: Dictionary = o as Dictionary
		var pickup := preload("res://scripts/item_pickup.gd").new()
		add_child(pickup)
		pickup.call("setup", str(spec.get("item_id", "")), to_global(map_to_local(
			offset + Vector2i(int(spec.get("x", 0)), int(spec.get("y", 0))))))
		pickup.set("quantita", int(spec.get("quantita", 1)))


# --- NPC (globali a tutte le regioni, ricostruiti a ogni momento) ---------

func _ricrea_tutti_npc() -> void:
	for c in get_children():
		if c is Area2D and c.has_meta("npc_id"):
			c.queue_free()
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return
	for reg in gd.call("get_regions"):
		_crea_npc_regione(reg as Dictionary, gd)


func _crea_npc_regione(reg: Dictionary, gd: Node) -> void:
	var rid: String = str(reg.get("id", ""))
	var offset: Vector2i = _offset_di(reg)
	var dim: Vector2i = _dim_per_regione.get(rid, Vector2i(W_FALLBACK, H_FALLBACK))
	var ns: Node = get_node_or_null("/root/NpcSystem")
	if ns == null:
		return
	var presenti: Dictionary = ns.call("presenti", rid)
	var per_zona: Dictionary = {}
	for id in presenti:
		var tag: String = str(presenti[id])
		if not per_zona.has(tag):
			per_zona[tag] = []
		(per_zona[tag] as Array).append(str(id))

	for tag in per_zona:
		var ids: Array = per_zona[tag]
		var zona: Node2D = get_node_or_null("Zona_%s_%s" % [rid, tag]) as Node2D
		var centro: Vector2 = zona.position if zona != null \
			else map_to_local(offset) + Vector2(dim) * TILE * 0.5
		for i in ids.size():
			_crea_un_npc(str(ids[i]), gd,
				centro + Vector2((float(i) - (ids.size() - 1) * 0.5) * TILE * 1.5, 0))


func _crea_un_npc(id: String, gd: Node, posizione: Vector2) -> void:
	var area := Area2D.new()
	area.name = "Npc_%s" % id
	area.set_meta("npc_id", id)
	area.position = posizione
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE) * 1.2
	shape.shape = rect
	area.add_child(shape)

	var npc_dati: Dictionary = gd.call("get_npc", id) if gd != null else {}
	var variante: int = int((npc_dati.get("aspetto", {}) as Dictionary).get("variante", 0))
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/placeholder/npc_popolano.png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, variante * TILE, TILE, TILE)
	area.add_child(sprite)

	var nome := Label.new()
	nome.name = "Nome"
	nome.text = str(gd.call("tr_data", npc_dati.get("name_i18n", id))) if gd != null else id
	nome.add_theme_font_size_override("font_size", 10)
	nome.position = Vector2(-TILE, -TILE * 0.95)
	area.add_child(nome)

	if not str(npc_dati.get("dialogue_id", "")).is_empty():
		var prompt := Label.new()
		prompt.name = "Prompt"
		prompt.add_theme_font_size_override("font_size", 10)
		prompt.position = Vector2(-TILE, TILE * 0.7)
		prompt.text = tr("HUD_PROMPT_INTERAGISCI").format({"tasto": _tasto_interagisci()})
		prompt.hide()
		area.add_child(prompt)

	area.body_entered.connect(_npc_avvicinato.bind(id))
	area.body_exited.connect(_npc_allontanato.bind(id))
	add_child(area)


func _npc_avvicinato(body: Node, id: String) -> void:
	if not body.is_in_group("player"):
		return
	var ns: Node = get_node_or_null("/root/NpcSystem")
	if ns != null:
		ns.call("incontra", id)
	_npc_vicino = id
	_mostra_prompt(id, true)


func _npc_allontanato(body: Node, id: String) -> void:
	if body.is_in_group("player") and _npc_vicino == id:
		_npc_vicino = ""
		_mostra_prompt(id, false)


func _mostra_prompt(id: String, visibile: bool) -> void:
	var p: Node = get_node_or_null("Npc_%s/Prompt" % id)
	if p != null:
		p.visible = visibile


func _tasto_interagisci() -> String:
	for ev in InputMap.action_get_events("interagisci"):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return "F"


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


func tag_corrente() -> String:
	return _tag_corrente


# --- corridoi di raccordo (US-1002) -----------------------------------------

## Un percorso a L (un segmento orizzontale + uno verticale, il gomito su
## (b.x, a.y)) tra il punto di aggancio di due regioni, con una piccola
## apertura scavata su ognuno dei due bordi. Non deve essere bello (i tile
## restano procedurali/placeholder): deve solo esistere ed essere
## calpestabile - la topologia (quali regioni si collegano) e' dato
## (data/world/corridoi.json), l'algoritmo non conosce nomi di regione.
func _disegna_corridoi() -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return
	for c in gd.call("get_corridoi"):
		var spec: Dictionary = c as Dictionary
		var pa: Vector2i = _punto_aggancio(gd, str(spec.get("a", "")), spec.get("aggancio_a", []))
		var pb: Vector2i = _punto_aggancio(gd, str(spec.get("b", "")), spec.get("aggancio_b", []))
		var larghezza: int = maxi(int(spec.get("larghezza", 3)), 1)
		_scava_apertura(pa, larghezza)
		_scava_apertura(pb, larghezza)
		_disegna_percorso_a_elle(pa, pb, larghezza)


func _punto_aggancio(gd: Node, rid: String, aggancio: Array) -> Vector2i:
	var reg: Dictionary = gd.call("get_region", rid)
	var offset: Vector2i = _offset_di(reg)
	var ax: int = int(aggancio[0]) if aggancio.size() > 0 else 0
	var ay: int = int(aggancio[1]) if aggancio.size() > 1 else 0
	return offset + Vector2i(ax, ay)


func _scava_apertura(centro: Vector2i, larghezza: int) -> void:
	var raggio: int = int(larghezza / 2.0)
	for dx in range(-raggio, raggio + 1):
		for dy in range(-raggio, raggio + 1):
			set_cell(centro + Vector2i(dx, dy), SORGENTE, Vector2i(_COLONNA_PAVIMENTO, 0))


func _disegna_percorso_a_elle(a: Vector2i, b: Vector2i, larghezza: int) -> void:
	var meta: int = int(larghezza / 2.0)
	var x0: int = mini(a.x, b.x)
	var x1: int = maxi(a.x, b.x)
	for x in range(x0, x1 + 1):
		for dy in range(-meta, meta + 1):
			set_cell(Vector2i(x, a.y + dy), SORGENTE, Vector2i(_COLONNA_PAVIMENTO, 0))
	var y0: int = mini(a.y, b.y)
	var y1: int = maxi(a.y, b.y)
	for y in range(y0, y1 + 1):
		for dx in range(-meta, meta + 1):
			set_cell(Vector2i(b.x + dx, y), SORGENTE, Vector2i(_COLONNA_PAVIMENTO, 0))


# --- viaggio e spawn (fast travel dalla pagina mappa, US-617; niente piu'
# un caricamento di scena: solo un riposizionamento del giocatore) --------

## Punto di spawn di una regione in coordinate globali. rid vuoto usa la
## regione corrente di WorldState (contratto invariato per player.gd::
## _respawn, che continua a chiamare punto_spawn() senza argomenti).
func punto_spawn(rid: String = "") -> Vector2:
	var id: String = rid
	if id.is_empty():
		var ws: Node = get_node_or_null("/root/WorldState")
		id = str(ws.call("regione_corrente")) if ws != null else ""
	if id.is_empty():
		id = HUB
	var gd: Node = get_node_or_null("/root/GameData")
	var reg: Dictionary = gd.call("get_region", id) if gd != null else {}
	var offset: Vector2i = _offset_di(reg)
	var layout: Dictionary = _layout_dati(id)
	var sp: Array = (layout.get("spawn", []) as Array)
	var cella: Vector2i = Vector2i(int(sp[0]), int(sp[1])) if sp.size() == 2 else Vector2i(4, 4)
	return to_global(map_to_local(offset + cella))


## Un gating con area "ingresso" chiude la regione stessa (US-611): la
## convenzione e' nel dato, non un caso per una regione specifica. Nel
## mondo continuo la barriera fisica vera (US-1009) resta da costruire per
## la Frontiera; questo controllo resta per non regredire su viaggia_a().
func _ingresso_aperto(target: String) -> bool:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return true
	for g in (gd.call("get_region", target).get("gating", []) as Array):
		if typeof(g) == TYPE_DICTIONARY and str((g as Dictionary).get("area", "")) == "ingresso":
			return AreaGate.valuta_gate(target, g, get_tree().root)
	return true


## Riposiziona il giocatore alla cella di spawn di target - fast travel
## (pagina mappa) e avvio di una nuova partita (main.gd). Non c'e' piu' una
## scena da caricare: il mondo e' sempre lo stesso nodo.
func viaggia_a(target: String) -> bool:
	if not _dim_per_regione.has(target) or not _ingresso_aperto(target):
		return false
	var player := get_parent().get_node_or_null("Player") as Node2D
	if player == null:
		return false
	player.global_position = punto_spawn(target)
	return true


## Gli id di regione raggiungibili "a piedi" da qui - nel mondo continuo
## sono tutte, dato che non ci sono piu' passaggi discreti (US-1002); usato
## solo da chi controllava passaggi_verso() prima (test/pagina mappa
## continuano a funzionare leggendo GameData.get_regions() direttamente
## per l'elenco completo).
func passaggi_verso() -> Array:
	var out: Array = []
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return out
	for r in gd.call("get_regions"):
		var rid: String = str((r as Dictionary).get("id", ""))
		if not rid.is_empty():
			out.append(rid)
	return out
