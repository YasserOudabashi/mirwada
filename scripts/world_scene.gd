extends TileMapLayer
## Mondo continuo (fase 10, US-1002). Sostituisce region_scene.gd come UNICA
## scena caricata da main.gd: dipinge OGNI regione di GameData.get_regions()
## nella stessa TileMapLayer, ciascuna al proprio world_offset (US-1001).
## Lo spazio condiviso fuori da ogni regione non resta vuoto: e' campagna
## vera, dipinta da _riempi_campagna e raggiungibile attraverso le brecce
## che _apri_brecce_perimetro apre nel muro di ogni regione (addendum
## US-1015, sostituisce i vecchi corridoi punto-a-punto). Le funzioni per
## regione sono le stesse di region_scene.gd (_dipingi/_crea_zone/
## _crea_nemici/_crea_oggetti/_crea_npc/_crea_gate) - qui prendono un id di
## regione + un offset invece di leggere un @export unico, e girano in un
## ciclo invece che una volta per scena.
##
## Zero caricamenti di scena tra regioni: WorldState.regione_corrente() si
## aggiorna quando il giocatore entra nel rettangolo di un'altra regione
## (una Area2D per regione, grande quanto il suo rettangolo) - mai un
## reload. Entrare in un edificio (US-1010) resta un caricamento di scena
## LOCALE: world_scene.gd si nasconde/ferma (mai liberato) mentre
## scenes/interior_scene.tscn prende il suo posto - vedi _crea_edifici/
## _su_porta_edificio/_su_uscita_edificio.
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
## Edifici visitabili (US-1010): l'interno attualmente in scena (null =
## siamo fuori), la porta da cui vi si e' entrati (per sapere dove
## riposizionare il giocatore uscendo) e una guardia contro un doppio
## attraversamento nello stesso frame fisico.
var _interno_attivo: Node = null
var _porta_attiva: Area2D = null
var _in_transizione_edificio: bool = false


func _ready() -> void:
	tile_set = load("res://assets/placeholder/tileset.tres")
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return
	var regioni: Array = gd.call("get_regions")
	_riempi_campagna(regioni)
	for reg in regioni:
		_prepara_regione(reg as Dictionary)
	var campagna: Dictionary = gd.call("get_campagna")
	_crea_nemici("campagna", campagna, Vector2i.ZERO)
	_crea_oggetti(campagna, Vector2i.ZERO)
	_disegna_capanne_campagna(campagna.get("edifici", []) as Array)
	_crea_edifici("campagna", campagna, Vector2i.ZERO)
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

	var t := Timer.new()
	t.wait_time = _INTERVALLO_PRESTAZIONI
	t.autostart = true
	t.timeout.connect(_aggiorna_prestazioni)
	add_child(t)


func _camera_giocatore() -> Node:
	var player: Node = get_parent().get_node_or_null("Player") if get_parent() != null else null
	return player.get_node_or_null("Camera2D") if player != null else null


# --- prestazioni (US-1003, fase 10): con 5 regioni vive nello stesso nodo, -
# nemici/NPC lontani dal giocatore non devono girare fisica/IA a vuoto -----

## Ogni quanto ricontrollare le distanze - dettaglio tecnico, non di
## bilanciamento (a differenza del raggio, che vive nei dati: balance.json
## [mondo.raggio_attivo_entita]).
const _INTERVALLO_PRESTAZIONI := 0.4


## Disattiva (process_mode = DISABLED, riusa il meccanismo nativo di Godot -
## ferma script + fisica dell'intero sotto-albero, Hitbox/Hurtbox incluse)
## ogni nemico/NPC fuori dal raggio dal giocatore; riattiva chi ci rientra.
## "nemici" e' un gruppo globale (tutte le regioni condividono lo stesso
## nodo, US-1002): un nemico di una regione lontana viene disattivato tanto
## quanto uno della stessa regione ma fuori raggio.
func _aggiorna_prestazioni() -> void:
	var player: Node2D = get_parent().get_node_or_null("Player") as Node2D if get_parent() != null else null
	if player == null:
		return
	var gd: Node = get_node_or_null("/root/GameData")
	var raggio: float = float((gd.call("get_balance", "mondo") as Dictionary).get(
		"raggio_attivo_entita", 600.0)) if gd != null else 600.0
	var raggio2: float = raggio * raggio

	for e in get_tree().get_nodes_in_group("nemici"):
		if not (e is Node2D) or (e as Node).is_queued_for_deletion():
			continue
		var vicino: bool = (e as Node2D).global_position.distance_squared_to(player.global_position) <= raggio2
		(e as Node).process_mode = Node.PROCESS_MODE_INHERIT if vicino else Node.PROCESS_MODE_DISABLED

	for c in get_children():
		if c is Area2D and c.has_meta("npc_id"):
			var vicino_npc: bool = (c as Node2D).global_position.distance_squared_to(player.global_position) <= raggio2
			c.process_mode = Node.PROCESS_MODE_INHERIT if vicino_npc else Node.PROCESS_MODE_DISABLED


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
	_apri_brecce_perimetro(offset, dim)
	_tinta_di_fondo(reg, offset, dim)
	_crea_confine(rid, offset, dim)
	_crea_zone(reg, layout, offset, dim)
	_crea_gate(reg, offset, dim)
	_crea_nemici(rid, layout, offset)
	_crea_oggetti(layout, offset)
	_crea_edifici(rid, layout, offset)


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


# --- edifici visitabili (US-1010, Blocco B): una porta sulla mappa esterna
# che carica un interno - resta un caricamento di scena LOCALE, la stessa
# tecnica dei passaggi fra regioni PRIMA di US-1002 (mai un sistema nuovo).
# world_scene.gd non viene MAI liberato mentre si e' dentro (l'invariante di
# US-1002B): si nasconde e si ferma (process_mode = DISABLED, lo stesso
# meccanismo gia' in uso per la culling di US-1003), poi torna.

func _crea_edifici(rid: String, layout: Dictionary, offset: Vector2i) -> void:
	var edifici: Array = (layout.get("edifici", []) as Array)
	for i in edifici.size():
		var spec: Dictionary = edifici[i] as Dictionary
		var iid: String = str(spec.get("interno_id", ""))
		if iid.is_empty():
			continue
		var cella: Vector2i = offset + Vector2i(int(spec.get("x", 0)), int(spec.get("y", 0)))
		var area := Area2D.new()
		area.name = "Porta_%s_%s_%d" % [rid, iid, i]
		area.position = map_to_local(cella)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE, TILE)
		shape.shape = rect
		area.add_child(shape)
		area.set_meta("interno_id", iid)
		area.body_entered.connect(_su_porta_edificio.bind(area))
		add_child(area)


## Entra nell'interno referenziato dalla porta. Il vero lavoro (sotto, in
## _entra_edificio) e' rimandato con call_deferred(): Godot vieta di
## disabilitare un CollisionObject2D (qui: l'intero sotto-albero di
## world_scene, via process_mode) DENTRO il callback di fisica che ci ha
## portati qui (body_entered) - "Disabling a CollisionObject node during a
## physics callback is not allowed", scoperto camminando per davvero contro
## la porta con Xvfb (i test headless, che chiamano l'handler a mano fuori
## da un vero callback, non lo vedevano).
func _su_porta_edificio(body: Node, porta: Area2D) -> void:
	if _in_transizione_edificio or not body.is_in_group("player"):
		return
	# La stessa porta si ri-attiva un istante dopo essere usciti (l'area
	# torna monitorabile con il player gia' sopra: Godot la considera un
	# ingresso nuovo) - ignorato una sola volta, vedi _esci_edificio.
	if bool(porta.get_meta("ignora_prossimo_ingresso", false)):
		porta.set_meta("ignora_prossimo_ingresso", false)
		return
	_in_transizione_edificio = true
	_entra_edificio.call_deferred(porta)


## Nasconde/ferma world_scene (MAI liberarlo, l'invariante di US-1002B),
## istanzia scenes/interior_scene.tscn come fratello di Main, riposiziona il
## giocatore al suo spawn. Sincrona e sicura se chiamata direttamente (fuori
## da un callback di fisica reale) - i test la chiamano cosi'.
func _entra_edificio(porta: Area2D) -> void:
	var padre: Node = get_parent()
	var player: Node2D = padre.get_node_or_null("Player") as Node2D if padre != null else null
	if padre == null or player == null:
		_in_transizione_edificio = false
		return
	_porta_attiva = porta
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	var interno: Node = load("res://scenes/interior_scene.tscn").instantiate()
	interno.set("interno_id", str(porta.get_meta("interno_id", "")))
	padre.add_child(interno)
	interno.connect("uscita", _su_uscita_edificio)
	_interno_attivo = interno
	player.global_position = interno.call("punto_spawn")
	_in_transizione_edificio = false


## Segnale dell'interno (a sua volta un body_entered sull'Area2D "Uscita",
## stesso motivo di sopra): rimanda a _esci_edificio con call_deferred().
func _su_uscita_edificio() -> void:
	if _interno_attivo != null:
		_esci_edificio.call_deferred()


## Libera l'interno (era una scena locale, non il mondo persistente),
## riaccende world_scene, riposiziona il giocatore alla cella della porta
## da cui si era entrati.
func _esci_edificio() -> void:
	if _interno_attivo == null:
		return
	var padre: Node = get_parent()
	var player: Node2D = padre.get_node_or_null("Player") as Node2D if padre != null else null
	_interno_attivo.queue_free()
	_interno_attivo = null
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if _porta_attiva != null:
		_porta_attiva.set_meta("ignora_prossimo_ingresso", true)
		if player != null:
			player.global_position = _porta_attiva.global_position
	_porta_attiva = null


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


# --- campagna (addendum fase 10, US-1015) -----------------------------------
#
# I vecchi corridoi (US-1002) erano un percorso a L largo 3 celle fra due
# punti scelti a mano, con il resto del mondo condiviso lasciato vuoto: da
# fuori si vedeva un rettangolo per regione unito da un ponte, non un mondo
# unico (feedback diretto dell'utente). Sostituiti da: (1) _riempi_campagna,
# che dipinge di terreno vero OGNI cella del rettangolo che contiene tutte
# le regioni e non appartiene a nessuna di esse - non piu' vuoto; (2)
# _apri_brecce_perimetro, che smette di trattare il muro perimetrale di ogni
# layout come una scatola sigillata: lo interrompe a intervalli regolari
# sui 4 lati, cosi' si esce dalla regione verso la campagna in molti punti
# invece che da un solo varco a coordinate fisse. Entrambe generiche: nessun
## nome di regione, nessuna coppia scelta a mano.

## Densita' degli alberi sparsi nella campagna (formula deterministica sulla
## cella via hash() - stessa mappa a ogni avvio, senza salvare un seed).
const _DENSITA_ALBERI_CAMPAGNA := 6
const _LARGH_BRECCIA := 3
const _PASSO_BRECCIA := 11


func _riempi_campagna(regioni: Array) -> void:
	var rettangoli: Array = []
	var minv := Vector2i(2000000, 2000000)
	var maxv := Vector2i(-2000000, -2000000)
	for reg in regioni:
		var r: Dictionary = reg as Dictionary
		var offset: Vector2i = _offset_di(r)
		var dim: Vector2i = _dimensioni_layout(_layout_dati(str(r.get("id", ""))))
		rettangoli.append(Rect2i(offset, dim))
		minv = minv.min(offset)
		maxv = maxv.max(offset + dim)

	for x in range(minv.x, maxv.x):
		for y in range(minv.y, maxv.y):
			var cella := Vector2i(x, y)
			var dentro_regione := false
			for rect in rettangoli:
				if (rect as Rect2i).has_point(cella):
					dentro_regione = true
					break
			if dentro_regione:
				continue
			var albero: bool = absi(hash(cella)) % 100 < _DENSITA_ALBERI_CAMPAGNA
			var col: int = _COLONNA_PER_CARATTERE["t"] if albero else _COLONNA_PAVIMENTO
			set_cell(cella, SORGENTE, Vector2i(col, 0))


## Villaggi nella campagna (fase 11, US-1111/1112): campagna.json non ha una
## mappa ASCII disegnata a mano come i layout di regione, quindi le sue
## capanne non possono nascere da un carattere '#' gia' scritto da qualche
## parte - servono dipinte qui. Template FISSO 5x4 (stessa forma per ogni
## voce di campagna.edifici[], mai una forma per villaggio specifico):
## muro perimetrale, pavimento dentro, un varco al centro del lato sud dove
## _crea_edifici (gia' generico, invariato) mette la porta vera. (x,y) di
## ogni voce e' la cella del varco, stessa convenzione di layout.edifici[]
## (vedi mirwada_bottega_del_fabbro: porta sul lato sud del rettangolo).
const _CAPANNA_LARGH := 5
const _CAPANNA_ALT := 4


func _disegna_capanne_campagna(edifici: Array) -> void:
	for spec in edifici:
		var porta: Vector2i = Vector2i(int((spec as Dictionary).get("x", 0)), int((spec as Dictionary).get("y", 0)))
		var origine: Vector2i = porta - Vector2i(_CAPANNA_LARGH / 2, _CAPANNA_ALT - 1)
		for ry in _CAPANNA_ALT:
			for rx in _CAPANNA_LARGH:
				var cella: Vector2i = origine + Vector2i(rx, ry)
				var e_muro: bool = ry == 0 or rx == 0 or rx == _CAPANNA_LARGH - 1 \
					or (ry == _CAPANNA_ALT - 1 and cella != porta)
				var col: int = _COLONNA_MURO if e_muro else _COLONNA_PAVIMENTO
				set_cell(cella, SORGENTE, Vector2i(col, 0))


## Il perimetro che _dipingi ha appena disegnato (il muro '#' del layout)
## smette di essere una scatola sigillata: si apre una breccia larga
## _LARGH_BRECCIA ogni _PASSO_BRECCIA celle sui 4 lati, verso la campagna
## gia' dipinta da _riempi_campagna. Il muro (1 cella di spessore, come ogni
## layout di questo progetto) resta visibile fra una breccia e l'altra -
## legge come un'antica cinta muraria in rovina, non un confine invisibile.
func _apri_brecce_perimetro(offset: Vector2i, dim: Vector2i) -> void:
	var meta: int = int(_LARGH_BRECCIA / 2.0)
	var x: int = meta + 1
	while x < dim.x - meta - 1:
		_scava_breccia(offset + Vector2i(x, 0), meta, true)
		_scava_breccia(offset + Vector2i(x, dim.y - 1), meta, true)
		x += _PASSO_BRECCIA
	var y: int = meta + 1
	while y < dim.y - meta - 1:
		_scava_breccia(offset + Vector2i(0, y), meta, false)
		_scava_breccia(offset + Vector2i(dim.x - 1, y), meta, false)
		y += _PASSO_BRECCIA


func _scava_breccia(centro: Vector2i, meta: int, orizzontale: bool) -> void:
	for d in range(-meta, meta + 1):
		var cella: Vector2i = centro + (Vector2i(d, 0) if orizzontale else Vector2i(0, d))
		set_cell(cella, SORGENTE, Vector2i(_COLONNA_PAVIMENTO, 0))


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
