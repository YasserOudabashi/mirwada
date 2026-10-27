extends TileMapLayer
## US-1010 (fase 10, Blocco B): l'interno di un edificio - un layout piccolo
## e standalone (niente world_offset/campagna/confine/gating/NPC a orario:
## quella complessita' e' solo per il mondo esterno continuo, US-1002). Un
## interno e' sempre indipendente, mai parte della griglia condivisa:
## entrarci e uscirne resta un caricamento di scena locale
## (world_scene.gd::_su_porta_edificio/_su_uscita_edificio), esattamente
## come funzionavano i passaggi fra regioni PRIMA di US-1002. world_scene.gd
## non viene MAI liberato mentre si e' dentro (resta lo stesso nodo
## persistente di US-1002B): si nasconde e ferma, poi torna.
##
## Painting/nemici/oggetti riusano lo stesso linguaggio dati di
## world_scene.gd (stessa legenda di caratteri, stesso formato nemici/
## oggetti) ma sono una copia minima apposta: un interno non ha bisogno di
## _crea_zone/_crea_gate/_crea_npc/_crea_confine/_riempi_campagna (nessuna
## di quelle nozioni si applica a una stanza), quindi non vale la pena
## condividere codice con world_scene.gd oltre alla legenda.
##
## NIENTE class_name: coerente col resto del progetto.

signal uscita

const TILE := 32
const SORGENTE := 0
const _COLONNA_PER_CARATTERE := {
	".": 0, "#": 1, "o": 2, "~": 3, ",": 4, "=": 5, "t": 6, "+": 7,
}
const _COLONNA_PAVIMENTO := 0
const CALPESTABILI := [".", ",", "=", "+"]

## Impostato da chi istanzia questa scena (world_scene.gd) PRIMA di
## aggiungerla all'albero, cosi' _ready() lo trova gia' pronto.
var interno_id: String = ""
## US-8B21b: il contenuto della zona del layout dietro un varco (mondo.gd ospiti_del_varco),
## impostato prima di aggiungere la stanza all'albero. {rect, nemici, oggetti}
var ospiti: Dictionary = {}

## US-1108 (fase 11): l'npc_id vicino al giocatore ("" = nessuno) - stesso
## principio di world_scene.gd::_npc_vicino, per _unhandled_input.
var _npc_vicino: String = ""


func _ready() -> void:
	tile_set = load("res://assets/placeholder/tileset.tres")
	if interno_id.is_empty():
		return
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return
	var layout: Dictionary = gd.call("get_interno", interno_id)
	if layout.is_empty():
		return
	y_sort_enabled = true                          # il giocatore (figlio della stanza) passa dietro gli arredi alti
	_dipingi(layout)
	_arte()
	_crea_arredi(layout)
	_crea_forzieri(layout)
	_crea_uscita(layout)
	_crea_nemici(layout)
	_crea_oggetti(layout)
	_crea_npc(layout)
	_crea_ospiti(layout)


func _dipingi(layout: Dictionary) -> void:
	var mappa: Array = (layout.get("mappa", []) as Array)
	for y in mappa.size():
		var riga: String = str(mappa[y])
		for x in riga.length():
			var col: int = int(_COLONNA_PER_CARATTERE.get(riga[x], _COLONNA_PAVIMENTO))
			set_cell(Vector2i(x, y), SORGENTE, Vector2i(col, 0))


## US-8B18c: l'immagine dell'interno (tools/art/build_interni.py, una per modalita') sotto
## NPC, nemici e oggetti; le celle restano per le collisioni, trasparenti.
func _arte() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	var tema: String = str(gs.call("tema_arte")) if gs != null else "luminoso"
	var path: String = "res://assets/interni/%s/%s.png" % [tema, interno_id]
	if not FileAccess.file_exists(path):
		return
	var spr := Sprite2D.new()
	spr.name = "Arte"
	spr.texture = preload("res://scripts/world/mondo.gd")._texture(path)
	spr.centered = false
	spr.z_index = -2                               # sotto tutto, anche sotto i tappeti (-1)
	add_child(spr)
	self_modulate = Color(1, 1, 1, 0)


## US-8B18d: gli arredi dei dati (data/world/arredi.json), disegni di build_interni.py
## con i piedi in basso al centro; le caselle di un arredo che blocca diventano muro.
func _crea_arredi(layout: Dictionary) -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	var gs: Node = get_node_or_null("/root/GameState")
	var cartella: String = "res://assets/interni/%s/arredi" % (str(gs.call("tema_arte")) if gs != null else "luminoso")
	var f := FileAccess.open("res://assets/interni/arredi.json", FileAccess.READ)
	var ancore: Dictionary = (JSON.parse_string(f.get_as_text()) as Dictionary) if f != null else {}
	for a in (layout.get("arredi", []) as Array):
		var spec: Dictionary = a
		var id: String = str(spec.get("id", ""))
		var voce: Dictionary = gd.call("get_arredo", id) if gd != null else {}
		var path: String = cartella.path_join(id + ".png")
		if voce.is_empty() or not FileAccess.file_exists(path):
			continue
		var m: Array = voce["misura"]
		var c := Vector2i(int(spec.get("x", 0)), int(spec.get("y", 0)))
		if bool(voce.get("blocca", true)):
			for dy in int(m[1]):
				for dx in int(m[0]):
					set_cell(c + Vector2i(dx, dy), SORGENTE, Vector2i(_COLONNA_PER_CARATTERE["#"], 0))
		var spr := Sprite2D.new()
		spr.name = "Arredo_%s_%d_%d" % [id, c.x, c.y]
		spr.texture = preload("res://scripts/world/mondo.gd")._texture(path)
		spr.centered = false
		var an: Array = ancore.get(id, [0, 0])
		spr.offset = -Vector2(float(an[0]), float(an[1]))
		spr.position = Vector2((c.x + float(m[0]) / 2.0) * TILE, (c.y + int(m[1])) * TILE)
		if bool(voce.get("a_terra", false)):
			spr.z_index = -1                          # i tappeti stanno sotto chi ci passa
		add_child(spr)


## US-8B22: i forzieri dei dati (scripts/forziere.gd); la loro casella diventa muro come quella di un arredo,
## cosi' gli ospiti del varco non ci finiscono sopra.
func _crea_forzieri(layout: Dictionary) -> void:
	for spec in (layout.get("forzieri", []) as Array):
		var c := Vector2i(int(spec.get("x", 0)), int(spec.get("y", 0)))
		set_cell(c, SORGENTE, Vector2i(_COLONNA_PER_CARATTERE["#"], 0))
		var f: Area2D = preload("res://scripts/forziere.gd").new()
		f.call("setup", str(spec.get("id", "")), str(spec.get("tabella", "")), map_to_local(c))
		add_child(f)


## Nemici e oggetti della zona dietro il varco alla stessa posizione relativa nella stanza,
## sulla casella libera piu' vicina (mai sopra arredi, NPC, oggetti; i nemici non accanto
## all'ingresso).
func _crea_ospiti(layout: Dictionary) -> void:
	if ospiti.is_empty():
		return
	var r: Array = ospiti.get("rect", [0, 0, 1, 1])
	var mappa: Array = layout.get("mappa", [])
	var w: int = str(mappa[0]).length()
	var h: int = mappa.size()
	var sp: Vector2i = _cella_spawn(layout)
	var prese: Dictionary = {}
	for k in ["npcs", "oggetti", "nemici"]:
		for e in layout.get(k, []):
			prese[Vector2i(int(e.get("x", 0)), int(e.get("y", 0)))] = true
	var dentro: Dictionary = {"nemici": [], "oggetti": []}
	for k in ["oggetti", "nemici"]:
		for e in ospiti.get(k, []):
			var u: float = (float(e.get("x", 0)) - float(r[0]) + 0.5) / maxf(float(r[2]), 1.0)
			var v: float = (float(e.get("y", 0)) - float(r[1]) + 0.5) / maxf(float(r[3]), 1.0)
			var c: Vector2i = _libera_vicina(Vector2i(1 + int(u * (w - 2)), 1 + int(v * (h - 2))), prese, sp,
					2 if k == "nemici" else 0)
			prese[c] = true
			var spec: Dictionary = (e as Dictionary).duplicate(true)
			spec["x"] = c.x
			spec["y"] = c.y
			(dentro[k] as Array).append(spec)
	_crea_nemici(dentro)
	_crea_oggetti(dentro)


func _libera_vicina(c: Vector2i, prese: Dictionary, spawn: Vector2i, distanza_spawn: int) -> Vector2i:
	var passi: Array = CALPESTABILI.map(func(ch): return _COLONNA_PER_CARATTERE[ch])
	for raggio in range(0, 12):
		for dy in range(-raggio, raggio + 1):
			for dx in range(-raggio, raggio + 1):
				var q := c + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == raggio and get_cell_source_id(q) >= 0 \
						and get_cell_atlas_coords(q).x in passi and not prese.has(q) and q != spawn \
						and maxi(absi(q.x - spawn.x), absi(q.y - spawn.y)) > distanza_spawn:
					return q
	return c


func _cella_spawn(layout: Dictionary) -> Vector2i:
	var sp: Array = (layout.get("spawn", []) as Array)
	return Vector2i(int(sp[0]), int(sp[1])) if sp.size() == 2 else Vector2i(1, 1)


## Posizione globale di spawn - dove il giocatore appare entrando dalla
## porta esterna.
func punto_spawn() -> Vector2:
	var gd: Node = get_node_or_null("/root/GameData")
	var layout: Dictionary = gd.call("get_interno", interno_id) if gd != null else {}
	return to_global(map_to_local(_cella_spawn(layout)))


## L'uscita coincide con la cella di spawn (si rientra dalla stessa porta da
## cui si e' entrati): tornarci vicino riporta alla mappa esterna.
func _crea_uscita(layout: Dictionary) -> void:
	var area := Area2D.new()
	area.name = "Uscita"
	area.position = map_to_local(_cella_spawn(layout))
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	shape.shape = rect
	area.add_child(shape)
	# Il player appare GIA' su questa cella entrando (e' anche lo spawn):
	# il primo body_entered che l'Area2D vede, appena aggiunta all'albero,
	# e' quel corpo gia' presente - non un vero ritorno alla porta. Stesso
	# problema (e stessa soluzione) della porta esterna, world_scene.gd::
	# _su_porta_edificio/ignora_prossimo_ingresso.
	area.set_meta("ignora_primo_ingresso", true)
	area.body_entered.connect(_su_ingresso_uscita.bind(area))
	add_child(area)


func _su_ingresso_uscita(body: Node, area: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	if bool(area.get_meta("ignora_primo_ingresso", false)):
		area.set_meta("ignora_primo_ingresso", false)
		return
	uscita.emit()


func _crea_nemici(layout: Dictionary) -> void:
	for n in (layout.get("nemici", []) as Array):
		var spec: Dictionary = n as Dictionary
		var sequenza: int = int(spec.get("sequenza", 9))
		var e: Node = preload("res://scenes/enemy.tscn").instantiate()
		e.set("override", (spec.get("override", {}) as Dictionary).duplicate(true))
		e.set("scale", Vector2.ONE * float(spec.get("scala", 1.0)))
		add_child(e)
		e.set("global_position", to_global(map_to_local(
			Vector2i(int(spec.get("x", 0)), int(spec.get("y", 0))))))
		e.set("sequenza", sequenza)
		e.get_node("StatsComponent").call("configure_from_balance", sequenza)


func _crea_oggetti(layout: Dictionary) -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	var inv: Node = get_node_or_null("/root/Inventory")
	for o in (layout.get("oggetti", []) as Array):
		var spec: Dictionary = o as Dictionary
		var it: Dictionary = gd.call("get_item", str(spec.get("item_id", ""))) if gd != null else {}
		if not bool(it.get("vendibile", true)) and inv != null and bool(inv.call("possiede", str(spec["item_id"]))):
			continue                                   # una chiave del mondo che si ha gia' non ricompare
		var pickup := preload("res://scripts/item_pickup.gd").new()
		add_child(pickup)
		pickup.call("setup", str(spec.get("item_id", "")), to_global(map_to_local(
			Vector2i(int(spec.get("x", 0)), int(spec.get("y", 0))))))
		pickup.set("quantita", int(spec.get("quantita", 1)))


# --- NPC (US-1108, fase 11) -------------------------------------------
## Un fabbro/alchimista dentro la sua bottega. Stessa forma minima di
## world_scene.gd::_crea_un_npc MA senza schedule/orario: un NPC dentro una
## stanza e' sempre li', non gira fra location_tag per momento del giorno -
## duplicata apposta, non condivisa (stessa scelta gia' fatta per
## _crea_nemici/_crea_oggetti, vedi il commento di testa del file).

func _crea_npc(layout: Dictionary) -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return
	for spec in (layout.get("npcs", []) as Array):
		var s: Dictionary = spec as Dictionary
		var id: String = str(s.get("npc_id", ""))
		if id.is_empty():
			continue
		_crea_un_npc(id, gd, map_to_local(Vector2i(int(s.get("x", 0)), int(s.get("y", 0)))))


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

	var npc_dati: Dictionary = gd.call("get_npc", id)
	var aspetto: Dictionary = npc_dati.get("aspetto", {})
	var foglio: String = "res://assets/placeholder/personaggio_%s_idle.png" % str(aspetto.get("sprite", ""))
	if aspetto.has("sprite") and FileAccess.file_exists(foglio):
		# l'aspetto sprite-forge dell'NPC (tools/art/build_npc.py), come nel mondo generato
		var anim: AnimatedSprite2D = preload("res://scripts/animation_machine.gd").new()
		anim.name = "AnimationMachine"
		area.add_child(anim)
		anim.call("configura", "personaggio", str(aspetto["sprite"]))
		anim.call("riproduci", "idle", "down")
	else:
		var variante: int = int(aspetto.get("variante", 0))
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/placeholder/npc_popolano.png")
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, variante * TILE, TILE, TILE)
		area.add_child(sprite)

	var nome := Label.new()
	nome.name = "Nome"
	nome.text = str(gd.call("tr_data", npc_dati.get("name_i18n", id)))
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
