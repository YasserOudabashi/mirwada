extends Node2D
## Mondo unico (US-8B12): carica il mondo esportato da tools/art/esporta_mondo.py
## (assets/world/) e costruisce solo il pezzo attorno al giocatore.
##   - terreno: le tessere 32x32 gia' composte in Python (pareti, bordi e
##     varianti compresi), un TileMapLayer con un atlante per foglio;
##   - ostacoli: blocchi.png (255 = non si passa), un TileMapLayer invisibile con
##     una tessera quadrata di collisione;
##   - oggetti (alberi, rocce, trono...): Sprite2D figli di questo nodo, che ha
##     l'ordinamento per profondita' (y_sort): il giocatore va messo qui dentro.
## La modalita' (luminoso | cupo) viene da GameState.tema_arte(): stessi dati,
## altri fogli e altri sprite.
## Due livelli sulla stessa griglia: la superficie e il sottosuolo (fogne,
## catacombe, grotte, miniere, citta' sotterranea). Un ingresso ha le stesse
## coordinate sopra e sotto: "interagisci" sull'ingresso cambia livello.
##
## NIENTE class_name: coerente col progetto.

const AreaGate := preload("res://scripts/area_gate.gd")
const AnimationMachine := preload("res://scripts/animation_machine.gd")

const BLOCCO := 16                       # caselle per lato di un blocco caricato
const STRATO_COLLISIONE := 1             # acqua e vuoto: lo stesso strato dei muri (bit 1)
## Dislivelli (blocchi.png = 128): strato 5 (bit 16). Giocatore e nemici lo hanno
## nella maschera; chi vola lo toglie e passa (decisione 2026-10-25: alle Marche si
## arriva solo volando o dal sottosuolo). L'acqua resta invalicabile anche in volo.
const STRATO_DISLIVELLI := 16
const DISLIVELLO := 128

@export var cartella: String = "res://assets/world"
## "" = quello della modalita' della partita (GameState.tema_arte()).
@export var tema: String = ""
## Blocchi caricati attorno al giocatore, per lato (2 -> 5x5 blocchi = 80x80 caselle).
@export var raggio_blocchi: int = 2

var dati: Dictionary = {}
var larghezza: int = 0
var altezza: int = 0
var tile: int = 32

var _indici: PackedByteArray        # RGB per casella: R + 256 * G = tessera
var _blocchi: PackedByteArray       # 1 byte per casella
var _regioni: PackedByteArray       # 1 byte per casella
var _per_foglio: int = 8192
var _colonne: int = 64
var _terreno: TileMapLayer
var _ostacoli: TileMapLayer
var _caricati: Dictionary = {}      # Vector2i blocco -> Array di Sprite2D
var _oggetti_per_blocco: Dictionary = {}
var _texture_oggetti: Dictionary = {}
var _blocco_centro := Vector2i(-9999, -9999)
var _tema_caricato: String = ""
var _cella_regione := Vector2i(-9999, -9999)
## Ultima posizione del giocatore in una regione che lo accetta: chi tocca una
## regione col gating d'ingresso chiuso torna qui (la Frontiera respinge).
var _ultima_ammessa := Vector2.INF
## L'NPC nel cui raggio si trova il giocatore ("" = nessuno), come region_scene.
var _npc_vicino: String = ""
## Livello mostrato: "superficie" o "sottosuolo" (2026-10-25: alle Marche si arriva
## anche dal sottosuolo, uscendo dalle catacombe).
var livello: String = "superficie"
var _livelli: Dictionary = {}       # nome -> {indici, blocchi, tileset, oggetti}
var _ingresso_vicino: String = ""
var _porta_vicina: Area2D = null
var _interno: Node = null                   # l'interno caricato (US-8B18b), null fuori
var _ritorno := Vector2.ZERO                # dove si torna uscendo

signal livello_cambiato(nuovo: String)
## US-8B23b: un blocco attorno al giocatore e' stato costruito / tolto (la fauna ci mette e ci toglie gli animali).
signal blocco_costruito(b: Vector2i)
signal blocco_scaricato(b: Vector2i)


func _ready() -> void:
	y_sort_enabled = true
	add_to_group("mondo")                          # GameState: posizione e livello nel salvataggio
	if dati.is_empty() and not carica():
		return
	for c in get_children():                       # il giocatore della scena parte dalla casa al porto
		if c.is_in_group("player") and c is Node2D:
			colloca(c as Node2D, partenza())
			var cam: Node = c.get_node_or_null("Camera2D")
			if cam != null and cam.has_method("apply_zone_limits"):
				cam.call("apply_zone_limits", Rect2(Vector2.ZERO, Vector2(larghezza, altezza) * tile))
	segui(partenza())
	crea_npc()
	crea_ingressi()
	popola()
	crea_porte()
	crea_varchi()
	crea_barca()
	crea_nave()
	crea_forzieri()
	crea_cannocchiali()
	add_child(preload("res://scripts/world/fauna.gd").new())
	add_child(preload("res://scripts/world/base_fuori.gd").new())   # US-8B20c: l'orto fuori dalla sede della base
	add_child(preload("res://scripts/world/luce.gd").new())
	var t := Timer.new()
	t.wait_time = INTERVALLO_ATTIVITA
	t.autostart = true
	t.timeout.connect(_aggiorna_attivita)
	add_child(t)
	var ts: Node = get_node_or_null("/root/TimeSystem")
	if ts != null and ts.has_signal("momento_cambiato"):
		ts.momento_cambiato.connect(func(_m): crea_npc())


## Mette un nodo (il giocatore) in una posizione e porta subito li' la sua
## telecamera: con lo scorrimento morbido scivolerebbe da (0, 0) attraverso la mappa.
func colloca(nodo: Node2D, pos: Vector2) -> void:
	nodo.position = pos
	for cam in nodo.find_children("*", "Camera2D", true, false):
		(cam as Camera2D).reset_smoothing()
	segui(pos)


## Legge i dati e prepara i livelli; i blocchi si costruiscono con segui().
func carica() -> bool:
	var f := FileAccess.open(cartella.path_join("mondo.json"), FileAccess.READ)
	if f == null:
		push_error("[Mondo] manca %s: lancia tools/art/esporta_mondo.py" % cartella.path_join("mondo.json"))
		return false
	dati = JSON.parse_string(f.get_as_text())
	larghezza = int(dati["larghezza"])
	altezza = int(dati["altezza"])
	tile = int(dati["tile"])
	_colonne = int(dati["colonne_foglio"])
	_per_foglio = _colonne * int(dati["righe_foglio"])
	_tema_caricato = tema if not tema.is_empty() else _tema_partita()
	_regioni = _immagine(cartella.path_join("regioni.png"), Image.FORMAT_L8)
	var sup: Dictionary = {"indici": _immagine(cartella.path_join(_tema_caricato).path_join("indici.png"), Image.FORMAT_RGB8),
		"blocchi": _immagine(cartella.path_join("blocchi.png"), Image.FORMAT_L8),
		"tileset": _tileset(cartella.path_join(_tema_caricato), int((dati["fogli"] as Dictionary).get(_tema_caricato, 0))),
		"oggetti": {}}
	_livelli["superficie"] = sup
	_indici = sup["indici"]
	_blocchi = sup["blocchi"]

	_terreno = TileMapLayer.new()
	_terreno.name = "Terreno"
	_terreno.tile_set = sup["tileset"]
	_terreno.z_index = -10                    # sotto gli oggetti e il giocatore
	add_child(_terreno)

	# due tessere quadrate di collisione: (0, 0) acqua/vuoto sullo strato dei muri,
	# (1, 0) dislivello sullo strato dei dislivelli
	var ts_ost := TileSet.new()
	ts_ost.tile_size = Vector2i(tile, tile)
	ts_ost.add_physics_layer()
	ts_ost.set_physics_layer_collision_layer(0, STRATO_COLLISIONE)
	ts_ost.add_physics_layer()
	ts_ost.set_physics_layer_collision_layer(1, STRATO_DISLIVELLI)
	var vuota := Image.create(tile * 2, tile, false, Image.FORMAT_RGBA8)
	var src_ost := TileSetAtlasSource.new()
	src_ost.texture = ImageTexture.create_from_image(vuota)
	src_ost.texture_region_size = Vector2i(tile, tile)
	ts_ost.add_source(src_ost, 0)
	var h: float = tile / 2.0
	for strato in 2:
		src_ost.create_tile(Vector2i(strato, 0))
		var td: TileData = src_ost.get_tile_data(Vector2i(strato, 0), 0)
		td.add_collision_polygon(strato)
		td.set_collision_polygon_points(strato, 0, PackedVector2Array([
			Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
	_ostacoli = TileMapLayer.new()
	_ostacoli.name = "Ostacoli"
	_ostacoli.tile_set = ts_ost
	_ostacoli.visible = false
	add_child(_ostacoli)

	for o in dati["oggetti"]:
		var b := Vector2i(int(float(o[1]) / BLOCCO), int(float(o[2]) / BLOCCO))
		if not _oggetti_per_blocco.has(b):
			_oggetti_per_blocco[b] = []
		_oggetti_per_blocco[b].append(o)
	sup["oggetti"] = _oggetti_per_blocco
	return true


## Un atlante per foglio di tessere (tessere_<k>.png); le tessere si creano quando servono.
func _tileset(cart: String, fogli: int) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile, tile)
	for k in fogli:
		var src := TileSetAtlasSource.new()
		src.texture = _texture(cart.path_join("tessere_%d.png" % k))
		src.texture_region_size = Vector2i(tile, tile)
		ts.add_source(src, k)
	return ts


## Il sottosuolo si legge la prima volta che serve. false se non e' stato esportato.
func _prepara_sottosuolo() -> bool:
	if _livelli.has("sottosuolo"):
		return true
	var s: Dictionary = dati.get("sottosuolo", {})
	var fogli: int = int((s.get("fogli", {}) as Dictionary).get(_tema_caricato, 0))
	if fogli <= 0:
		return false
	var cart: String = cartella.path_join(_tema_caricato).path_join("sotto")
	_livelli["sottosuolo"] = {"indici": _immagine(cart.path_join("indici.png"), Image.FORMAT_RGB8),
		"blocchi": _immagine(cartella.path_join("sotto").path_join("blocchi.png"), Image.FORMAT_L8),
		"tileset": _tileset(cart, fogli), "oggetti": {}}
	return true


## Posizione (unita' di gioco) dove comincia la partita: la casa al porto.
func partenza() -> Vector2:
	var p: Array = dati.get("partenza", [0, 0])
	return Vector2((float(p[0]) + 0.5) * tile, (float(p[1]) + 0.5) * tile)


## Punto di comparsa in una regione (contratto di world_scene.gd, usato da
## main.gd): la partenza dei dati se e' in quella regione (o rid vuoto),
## altrimenti il primo luogo della regione sulla mappa, come viaggia_a.
func punto_spawn(rid: String = "") -> Vector2:
	var p: Vector2 = partenza()
	if rid.is_empty() or regione_a(floori(p.x / tile), floori(p.y / tile)) == rid:
		return p
	var c: Vector2i = arrivo_in(rid)
	return Vector2((c.x + 0.5) * tile, (c.y + 0.5) * tile) if c.x >= 0 else p


## Costruisce i blocchi attorno a una posizione e libera quelli lontani.
func segui(pos: Vector2) -> void:
	var c := Vector2i(floori(pos.x / (tile * BLOCCO)), floori(pos.y / (tile * BLOCCO)))
	if c == _blocco_centro:
		return
	_blocco_centro = c
	var voluti: Dictionary = {}
	for by in range(c.y - raggio_blocchi, c.y + raggio_blocchi + 1):
		for bx in range(c.x - raggio_blocchi, c.x + raggio_blocchi + 1):
			if bx >= 0 and by >= 0 and bx * BLOCCO < larghezza and by * BLOCCO < altezza:
				voluti[Vector2i(bx, by)] = true
	for b in _caricati.keys():
		if not voluti.has(b):
			_scarica(b)
	for b in voluti:
		if not _caricati.has(b):
			_costruisci(b)


func _process(_delta: float) -> void:
	var p: Node = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if p is Node2D and not dati.is_empty():
		var pos: Vector2 = (p as Node2D).global_position - global_position
		# US-8B24: una telecamera del mondo (il cannocchiale) guarda lontano: si costruisce attorno a cio' che si vede
		var cam: Camera2D = get_viewport().get_camera_2d()
		segui(cam.global_position - global_position if cam != null and cam.get_parent() == self else pos)
		_aggiorna_barca(p as Node2D)
		if aggiorna_regione(pos):
			_ultima_ammessa = pos
		elif _ultima_ammessa != Vector2.INF:
			(p as Node2D).position = _ultima_ammessa
			_cella_regione = Vector2i(-9999, -9999)


## Regione e zona dalla posizione (US-8B12b): la regione della casella
## (regioni.png) se e' una regione dei dati, altrimenti nessuna (mare, terra di
## mezzo, isole); la zona e' il location_tag del luogo della mappa piu' vicino
## entro RAGGIO_ZONA caselle (regions.json luoghi_mondo abbina i nomi diversi).
const RAGGIO_ZONA := 12.0


## false = la regione respinge il giocatore (gating d'ingresso chiuso).
func aggiorna_regione(pos: Vector2) -> bool:
	var c := Vector2i(floori(pos.x / tile), floori(pos.y / tile))
	if c == _cella_regione:
		return true
	_cella_regione = c
	var ws: Node = Engine.get_main_loop().root.get_node_or_null("WorldState")
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	if ws == null or gd == null:
		return true
	var rid: String = regione_a(c.x, c.y)
	var reg: Dictionary = gd.call("get_region", rid)
	if reg.is_empty():
		ws.call("esci_regione")
		return true
	if not ingresso_aperto(rid):
		return false
	if str(ws.call("regione_corrente")) != rid:
		ws.call("entra_regione", rid)
	var tag: String = _zona(c, reg)
	if str(ws.call("zona_corrente")) != tag:
		ws.call("imposta_zona", tag)
	return true


## Un gating con area "ingresso" chiude la regione stessa (US-611), come nelle
## scene di regione: la convenzione e' nel dato.
func ingresso_aperto(rid: String) -> bool:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	if gd == null:
		return true
	for g in (gd.call("get_region", rid).get("gating", []) as Array):
		if typeof(g) == TYPE_DICTIONARY and str((g as Dictionary).get("area", "")) == "ingresso":
			return AreaGate.valuta_gate(rid, g, Engine.get_main_loop().root)
	return true


## La casella (luogo della mappa) di un location_tag della regione, attraverso
## luoghi_mondo; Vector2i(-1, -1) se sulla mappa non c'e'.
## I luoghi del sottosuolo (mondo.json sottosuolo.boss: i boss di zona) con lo
## stesso abbinamento a un location_tag (luoghi_mondo: "boss_fogne": "sotterraneo").
func luogo_sotto_del_tag(rid: String, tag: String) -> Vector2i:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	var alias: Dictionary = gd.call("get_region", rid).get("luoghi_mondo", {}) if gd != null else {}
	var boss: Dictionary = (dati.get("sottosuolo", {}) as Dictionary).get("boss", {})
	for luogo in boss:
		var p: Array = boss[luogo]
		if str(alias.get(luogo, "")) == tag and regione_a(int(p[0]), int(p[1])) == rid:
			return Vector2i(int(p[0]), int(p[1]))
	return Vector2i(-1, -1)


func luogo_del_tag(rid: String, tag: String) -> Vector2i:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	var alias: Dictionary = gd.call("get_region", rid).get("luoghi_mondo", {}) if gd != null else {}
	for luogo in (dati.get("luoghi", {}) as Dictionary):
		if str(alias.get(luogo, luogo)) == tag and regione_a(int(dati["luoghi"][luogo][0]), int(dati["luoghi"][luogo][1])) == rid:
			var p: Array = dati["luoghi"][luogo]
			return Vector2i(int(p[0]), int(p[1]))
	return Vector2i(-1, -1)


# --- Contenuto dei layout della fase 10/11 sul mondo generato (2026-10-25) -----------
# I layout (data/world/layouts/<regione>.json, data/world/campagna.json) restano la
# fonte: nemici, boss e oggetti si riportano sulla mappa generata. Un elemento dentro
# una zona del layout va vicino al luogo di quella zona sulla mappa (luoghi_mondo),
# spostato come nel layout (x SCALA_LAYOUT); gli altri nella stessa posizione
# relativa dentro il riquadro della regione. Poi la casella libera piu' vicina della
# stessa regione. La campagna (fuori dalle regioni) finisce nella terra di mezzo.

const SCALA_LAYOUT := 2.0
const REGIONE_CAMPAGNA := "terra_di_mezzo"
const INTERVALLO_ATTIVITA := 0.4
const SOGLIA_LIBERA := [0, 1, 2, 3]          # la soglia di una porta e le 3 caselle sotto (_casa_piu_vicina)

var _nemici_vivi: Dictionary = {}           # rid -> nemici ancora vivi
var _senza_abilita: Dictionary = {}         # rid -> nessun nemico ucciso con un'abilita'


func popola() -> void:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	if gd == null:
		return
	var occupate: Dictionary = {}
	# i nemici non compaiono vicino alla partenza (balance.json mondo.raggio_partenza_senza_nemici)
	var vietate: Dictionary = {}
	var r: int = int((gd.call("get_balance", "mondo") as Dictionary).get("raggio_partenza_senza_nemici", 0))
	var p: Vector2 = partenza()
	var c0 := Vector2i(floori(p.x / tile), floori(p.y / tile))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				vietate[c0 + Vector2i(dx, dy)] = true
	for reg in gd.call("get_regions"):
		var rid: String = str((reg as Dictionary).get("id", ""))
		var layout: Dictionary = gd.call("get_layout", rid)
		if not layout.is_empty() and (dati.get("riquadri", {}) as Dictionary).has(rid):
			_popola_da(rid, rid, layout, occupate, vietate)
	var campagna: Dictionary = gd.call("get_campagna")
	if not campagna.is_empty():
		_popola_da("campagna", REGIONE_CAMPAGNA, campagna, occupate, vietate)


## rid_eventi: la chiave dell'evento area_cleared (la regione, o "campagna").
## vietate: caselle dove non mettere nemici (attorno alla partenza); vi si aggiunge
## ogni casella occupata, cosi' resta l'insieme da evitare per i nemici.
func _popola_da(rid_eventi: String, rid: String, layout: Dictionary, occupate: Dictionary, vietate: Dictionary) -> void:
	var dietro: Array = (_zone_dei_varchi().get(rid, {}) as Dictionary).values()   # quelle stanno negli interni
	var nemici: Array = (layout.get("nemici", []) as Array).filter(func(n): return not _in_rect(n, dietro))
	var drop: Dictionary = layout.get("drop", {})
	_nemici_vivi[rid_eventi] = nemici.size()
	_senza_abilita[rid_eventi] = true
	for n in nemici:
		var spec: Dictionary = n
		var posto: Dictionary = posto_dal_layout(rid, layout, int(spec.get("x", 0)), int(spec.get("y", 0)), vietate)
		var c: Vector2i = posto["cella"]
		occupate[c] = true
		vietate[c] = true
		var sequenza: int = int(spec.get("sequenza", 9))
		var override: Dictionary = (spec.get("override", {}) as Dictionary).duplicate(true)
		if drop.has(str(sequenza)):
			override["oggetti_a_morte"] = drop[str(sequenza)]
		var e: Node2D = preload("res://scenes/enemy.tscn").instantiate()
		e.set("override", override)
		e.scale = Vector2.ONE * float(spec.get("scala", 1.0))
		e.position = Vector2((c.x + 0.5) * tile, (c.y + 0.5) * tile)
		e.set_meta("regione_layout", rid_eventi)
		e.set_meta("livello", posto["livello"])
		add_child(e)
		_mostra(e, posto["livello"] == livello)
		e.set("sequenza", sequenza)
		e.get_node("StatsComponent").call("configure_from_balance", sequenza)
		e.connect("morto", _su_nemico_morto.bind(rid_eventi))
	var ws: Node = Engine.get_main_loop().root.get_node_or_null("WorldState")
	var oggetti: Array = layout.get("oggetti", [])
	for i in oggetti.size():
		var spec_o: Dictionary = oggetti[i]
		var chiave: String = "%s@%d" % [rid_eventi, i]          # stabile: preso una volta, non ricompare
		if _in_rect(spec_o, dietro) or (ws != null and bool(ws.call("preso", chiave))):
			continue
		var posto_o: Dictionary = posto_dal_layout(rid, layout, int(spec_o.get("x", 0)), int(spec_o.get("y", 0)), occupate)
		var c_o: Vector2i = posto_o["cella"]
		occupate[c_o] = true
		vietate[c_o] = true
		var pickup: Node2D = preload("res://scripts/item_pickup.gd").new()
		add_child(pickup)
		pickup.call("setup", str(spec_o.get("item_id", "")), Vector2((c_o.x + 0.5) * tile, (c_o.y + 0.5) * tile))
		pickup.set("quantita", int(spec_o.get("quantita", 1)))
		pickup.set_meta("regione_layout", rid_eventi)
		pickup.set_meta("livello", posto_o["livello"])
		pickup.set_meta("preso_id", chiave)
		pickup.tree_exiting.connect(func() -> void:
			if bool(pickup.get("_raccolta")) and ws != null:
				ws.call("prendi", chiave))
		_mostra(pickup, posto_o["livello"] == livello)


## La casella del mondo generato per (x, y) di un layout (vedi sopra), con il suo
## livello: una zona che sulla mappa e' un luogo del sottosuolo (il "sotterraneo" di
## Mirwada = il boss delle fogne) porta l'elemento sotto terra.
## -> {"cella": Vector2i, "livello": "superficie" | "sottosuolo"}
func posto_dal_layout(rid: String, layout: Dictionary, x: int, y: int, occupate: Dictionary = {}) -> Dictionary:
	var mappa: Array = layout.get("mappa", [])
	var dim := Vector2(float(str(mappa[0]).length()), float(mappa.size())) if not mappa.is_empty() else Vector2.ZERO
	var zone: Dictionary = layout.get("zone", {})
	for tag in zone:                             # zona = [x, y, larghezza, altezza]
		var r: Array = zone[tag]
		if x < int(r[0]) or y < int(r[1]) or x >= int(r[0]) + int(r[2]) or y >= int(r[1]) + int(r[3]):
			continue
		var centro := Vector2(float(r[0]) + float(r[2]) / 2.0, float(r[1]) + float(r[3]) / 2.0)
		var d: Vector2 = (Vector2(x, y) - centro) * SCALA_LAYOUT
		var l: Vector2i = luogo_del_tag(rid, str(tag))
		if l.x >= 0:
			return {"cella": _libera_nella_regione(l + Vector2i(roundi(d.x), roundi(d.y)), occupate, rid), "livello": "superficie"}
		var ls: Vector2i = luogo_sotto_del_tag(rid, str(tag))
		if ls.x >= 0 and _prepara_sottosuolo():
			var b: PackedByteArray = _livelli["sottosuolo"]["blocchi"]
			return {"cella": _libera_nella_regione(ls + Vector2i(roundi(d.x), roundi(d.y)), occupate, rid, b), "livello": "sottosuolo"}
	var box: Array = (dati.get("riquadri", {}) as Dictionary).get(rid, [0, 0, larghezza, altezza])
	if dim == Vector2.ZERO:                      # campagna: senza mappa, le coordinate del vecchio mondo
		dim = _estensione_campagna(layout)
	var u: float = (float(x) + 0.5) / maxf(dim.x, 1.0)
	var v: float = (float(y) + 0.5) / maxf(dim.y, 1.0)
	var c := Vector2i(roundi(lerpf(float(box[0]), float(box[2]), u)), roundi(lerpf(float(box[1]), float(box[3]), v)))
	return {"cella": _libera_nella_regione(c, occupate, rid), "livello": "superficie"}


## La casella libera piu' vicina dentro la regione: prima vicino, poi allargando
## (un punto del riquadro puo' cadere in un'altra regione o in mare).
func _libera_nella_regione(c: Vector2i, occupate: Dictionary, rid: String,
		blocchi: PackedByteArray = PackedByteArray()) -> Vector2i:
	var b: PackedByteArray = _blocchi if blocchi.is_empty() else blocchi
	for raggio in [40, 120, 300]:
		var q: Vector2i = cella_libera(c, occupate, "", rid, raggio, b)
		if regione_a(q.x, q.y) == rid and b[q.y * larghezza + q.x] == 0:
			return q
	return c


func _estensione_campagna(layout: Dictionary) -> Vector2:
	var m := Vector2.ONE
	for k in ["nemici", "oggetti", "edifici"]:
		for e in layout.get(k, []):
			m = Vector2(maxf(m.x, float((e as Dictionary).get("x", 0)) + 1.0), maxf(m.y, float((e as Dictionary).get("y", 0)) + 1.0))
	return m


func _su_nemico_morto(chi: Node, rid: String) -> void:
	if not bool(chi.call("senza_abilita")):
		_senza_abilita[rid] = false
	_nemici_vivi[rid] = int(_nemici_vivi.get(rid, 1)) - 1
	if int(_nemici_vivi.get(rid, 0)) > 0:
		return
	var et: Node = Engine.get_main_loop().root.get_node_or_null("EventTracker")
	if et != null:
		et.call("emit_event", "area_cleared", {
			"senza_alleati_caduti": true,
			"senza_abilita": bool(_senza_abilita.get(rid, true)),
			"senza_uccidere": false,
		})


## Nemici e NPC lontani dal giocatore fermi (balance.json mondo.raggio_attivo_entita),
## come in world_scene.gd: qui serve anche perche' lontano dal giocatore le collisioni
## del terreno non sono costruite (si costruiscono solo i blocchi vicini).
func _aggiorna_attivita() -> void:
	_aggiorna_varchi()
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	if p == null:
		return
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	var raggio: float = float((gd.call("get_balance", "mondo") as Dictionary).get("raggio_attivo_entita", 600.0)) if gd != null else 600.0
	var r2: float = raggio * raggio
	for e in get_tree().get_nodes_in_group("nemici"):
		if not (e is Node2D) or (e as Node).is_queued_for_deletion() or not (e as CanvasItem).visible:
			continue
		var vicino: bool = (e as Node2D).global_position.distance_squared_to(p.global_position) <= r2
		(e as Node).process_mode = Node.PROCESS_MODE_INHERIT if vicino else Node.PROCESS_MODE_DISABLED
	for c in get_children():
		if c is Area2D and c.has_meta("npc_id") and (c as CanvasItem).visible:
			var vicino_npc: bool = (c as Node2D).global_position.distance_squared_to(p.global_position) <= r2
			c.process_mode = Node.PROCESS_MODE_INHERIT if vicino_npc else Node.PROCESS_MODE_DISABLED


# --- Porte verso gli interni (US-8B18b) --------------------------------------------
# Gli edifici dei layout (data/world/layouts, campagna.json: edifici [{x, y, interno_id}])
# vanno sulla casa del mondo generato (mondo.json "edifici") piu' vicina al posto che
# la regola dei layout calcola (posto_dal_layout), nella stessa regione; un edificio con
# "villaggio" (un gruppo di case nei dati, come l'avamposto della Valle) va a una casa di
# quel villaggio del mondo generato; una zona del sottosuolo mette la porta nella roccia.
# "interagisci" davanti alla porta carica scenes/interior_scene.tscn; uscendo si torna
# davanti alla porta.

func crea_porte() -> void:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	if gd == null:
		return
	var prese: Dictionary = {}
	for reg in gd.call("get_regions"):
		var rid: String = str((reg as Dictionary).get("id", ""))
		_porte_da(rid, gd.call("get_layout", rid), prese)
	_porte_da(REGIONE_CAMPAGNA, gd.call("get_campagna"), prese)


func _porte_da(rid: String, layout: Dictionary, prese: Dictionary) -> void:
	for e in layout.get("edifici", []):
		var spec: Dictionary = e
		var iid: String = str(spec.get("interno_id", ""))
		if iid.is_empty() or not (dati.get("riquadri", {}) as Dictionary).has(rid):
			continue
		var vid: String = str(spec.get("villaggio", ""))           # un villaggio, o un luogo (la casa della base, US-8B20b)
		var vil: Array = (dati.get("villaggi", {}) as Dictionary).get(vid, (dati.get("luoghi", {}) as Dictionary).get(vid, []))
		var posto: Dictionary = posto_dal_layout(rid, layout, int(spec.get("x", 0)), int(spec.get("y", 0))) \
				if vil.is_empty() else {"cella": Vector2i(int(vil[0]), int(vil[1])), "livello": "superficie"}
		var c: Vector2i = posto["cella"]
		if posto["livello"] == "superficie":
			var i: int = _casa_piu_vicina(c, rid if vil.is_empty() else "", prese)   # un villaggio puo' stare sul confine
			if i < 0:
				continue
			prese[i] = true
			var ed: Array = dati["edifici"][i]
			c = Vector2i(int(ed[0]) + int(ed[2]) / 2, int(ed[1]) + int(ed[3]))      # davanti alla porta
		add_child(_porta(iid, c, posto["livello"]))


## L'indice della casa (mondo.json edifici [x, y, larghezza, altezza, tipo]) libera piu'
## vicina a c, con la porta nella regione rid ("" = qualunque); -1 se nessuna. La soglia e le caselle
## sotto devono essere libere: il tetto di una casa davanti sporge fino a ~3 caselle
## (esporta_mondo.py sporgenza) e nasconderebbe il giocatore sulla soglia.
func _casa_piu_vicina(c: Vector2i, rid: String, prese: Dictionary) -> int:
	var migliore: int = -1
	var dist: float = INF
	var ed: Array = dati.get("edifici", [])
	for i in ed.size():
		if prese.has(i):
			continue
		var p := Vector2i(int(ed[i][0]) + int(ed[i][2]) / 2, int(ed[i][1]) + int(ed[i][3]))
		if (not rid.is_empty() and regione_a(p.x, p.y) != rid) or not _soglia_visibile(p):
			continue
		var d: float = Vector2(p).distance_squared_to(Vector2(c))
		if d < dist:
			dist = d
			migliore = i
	return migliore


func _soglia_visibile(p: Vector2i) -> bool:
	for dy in SOGLIA_LIBERA:
		if bloccata(p.x, p.y + dy):
			return false
	return true


func _porta(iid: String, c: Vector2i, liv: String) -> Area2D:
	var area := Area2D.new()
	area.name = "Porta_%s" % iid
	area.set_meta("interno_id", iid)
	area.set_meta("livello", liv)
	area.position = Vector2((c.x + 0.5) * tile, (c.y + 0.5) * tile)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tile, tile) * 1.4
	shape.shape = rect
	area.add_child(shape)
	if liv == "sottosuolo":                      # nel sottosuolo non c'e' una casa: una porta nella roccia
		var meta: Dictionary = (dati["sprite"] as Dictionary).get("ingresso_porta", {})
		var spr := Sprite2D.new()
		spr.texture = _texture_oggetto("ingresso_porta")
		spr.centered = false
		spr.offset = Vector2(-float(meta.get("ax", 0)), -float(meta.get("ay", 0)))
		area.add_child(spr)
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.add_theme_font_size_override("font_size", 10)
	prompt.size = Vector2(tile * 6, tile * 0.5)                # centrata sotto la porta, sopra rocce e alberi
	prompt.position = Vector2(-tile * 3, tile * 0.4)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.z_index = 10
	prompt.add_theme_constant_override("outline_size", 4)    # si legge anche sulla neve
	prompt.add_theme_color_override("font_outline_color", Color("#181425"))
	prompt.text = tr("HUD_PROMPT_ENTRA").format({"tasto": _tasto_interagisci()})
	prompt.hide()
	area.add_child(prompt)
	area.body_entered.connect(_su_porta.bind(area, true))
	area.body_exited.connect(_su_porta.bind(area, false))
	_mostra(area, liv == livello)
	return area


func _su_porta(body: Node, area: Area2D, dentro: bool) -> void:
	if not body.is_in_group("player"):
		return
	if dentro:
		_porta_vicina = area
	elif _porta_vicina == area:
		_porta_vicina = null
	(area.get_node("Prompt") as CanvasItem).visible = dentro


## Entra nell'interno della porta: il giocatore esce dal nodo mondo (che si nasconde e
## si ferma, mai liberato) ed entra nella stanza, aggiunta accanto al mondo.
func entra(porta: Area2D) -> bool:
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	if p == null or _interno != null or get_parent() == null or not varco_aperto(porta) or in_barca() or in_volo():
		return false
	if porta.has_meta("arrivo"):                     # una soglia: si passa dall'altra parte, non in una stanza
		var a: Vector2i = porta.get_meta("arrivo")
		_porta_vicina = null
		colloca(p, Vector2((a.x + 0.5) * tile, (a.y + 0.5) * tile))
		return true
	var interno: Node = load("res://scenes/interior_scene.tscn").instantiate()
	interno.set("interno_id", str(porta.get_meta("interno_id")))
	if porta.has_meta("gate"):
		interno.set("ospiti", ospiti_del_varco(porta))
	_ritorno = porta.position
	_porta_vicina = null
	(porta.get_node("Prompt") as CanvasItem).visible = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	get_parent().add_child(interno)
	p.reparent(interno)                            # dentro la stanza: ordinato con gli arredi (y_sort)
	interno.connect("uscita", func() -> void: esci.call_deferred())
	_interno = interno
	p.global_position = interno.call("punto_spawn")
	for cam in p.find_children("*", "Camera2D", true, false):
		if cam.has_method("inquadra_stanza"):
			cam.call("inquadra_stanza", interno.call("riquadro"))   # US-8B18e: la stanza ferma, sotto l'HUD
		(cam as Camera2D).reset_smoothing()
	return true


## Torna dal'interno alla porta da cui si era entrati.
func esci() -> void:
	if _interno == null:
		return
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	_interno.queue_free()
	_interno = null
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if p != null:
		p.reparent(self)
		for cam in p.find_children("*", "Camera2D", true, false):
			if cam.has_method("apply_zone_limits"):
				cam.call("apply_zone_limits", Rect2(Vector2.ZERO, Vector2(larghezza, altezza) * tile))
		colloca(p, _ritorno)


func in_un_interno() -> bool:
	return _interno != null


## Salvataggio (GameState): dentro un interno conta la porta da cui si e' entrati, non
## le coordinate della stanza (al caricamento si finirebbe in un angolo della mappa).
func posizione_da_salvare() -> Vector2:
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	return _ritorno if _interno != null else (p.position if p != null else partenza())


## Caricamento: fuori da un eventuale interno, sul livello salvato, nel punto salvato; la
## barca dove era rimasta, e a bordo se si era salvato in barca (stato_barca()).
func riprendi(liv: String, pos: Vector2, barca: Dictionary = {}, volo: bool = false) -> void:
	esci()
	cambia_livello(liv)
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if p != null:
		colloca(p, pos)
	var c: Array = barca.get("cella", [])
	if _barca != null and c.size() == 2:
		metti_barca(Vector2i(int(c[0]), int(c[1])))
	if p != null and p.has_method("imposta_barca"):
		_a_bordo = bool(barca.get("a_bordo", false)) and not volo
		if volo:
			p.call("imposta_volo", true, _nella_mappa)
		elif _a_bordo:
			p.call("imposta_barca", true, _solo_acqua)
		else:
			p.call("imposta_barca", false)


## Per il salvataggio (GameState, mondo.barca): dove sta la barca e se si e' a bordo.
func stato_barca() -> Dictionary:
	if _barca == null:
		return {}
	var c := Vector2i(floori(_barca.position.x / tile), floori(_barca.position.y / tile))
	return {"cella": [c.x, c.y], "a_bordo": in_barca()}


# --- Varchi verso le sotto-aree (US-8B21a) ----------------------------------------
# Un'area del gating di regions.json con "varco" {luogo, scostamento, interno, aspetto} e'
# un ingresso sulla mappa verso il suo interno (decisione dell'utente 2026-10-26): la porta
# si apre solo se AreaGate.valuta_gate lo dice. Il varco si appoggia a una parete vicina
# (roccia, acqua) se c'e', altrimenti sta in piedi da solo, con la sua collisione.

const RAGGIO_PARETE := 12
var _spiazzi: Array = []                    # Rect2i attorno ai varchi: niente alberi o rocce davanti

func crea_varchi() -> void:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	if gd == null:
		return
	for reg in gd.call("get_regions"):
		var rid: String = str((reg as Dictionary).get("id", ""))
		for g in (reg as Dictionary).get("gating", []):
			var v: Dictionary = (g as Dictionary).get("varco", {})
			if v.is_empty():
				continue
			var porta: Area2D = _varco_sulla_mappa(v, str(v["interno"]), "Varco_%s" % str((g as Dictionary).get("area", "")), rid)
			if porta != null:
				porta.set_meta("gate", g)
				porta.set_meta("regione", rid)
	crea_soglie()
	for b in _caricati.keys():                                # i blocchi gia' costruiti si rifanno senza
		_scarica(b)
	_blocco_centro = Vector2i(-9999, -9999)
	_aggiorna_varchi()


## Un ingresso sulla mappa (varco o soglia) da spec {luogo, scostamento, aspetto}, nella regione
## rid (vuota: quella del luogo): la porta, i disegni chiuso e aperto sulla casella dietro, la
## collisione se sta in piedi da sola, uno spiazzo senza alberi davanti. null se il luogo non c'e'.
func _varco_sulla_mappa(spec: Dictionary, iid: String, nome: String, rid: String = "") -> Area2D:
	var base: Vector2i = _luogo_varco(str(spec.get("luogo", "")))
	if base.x < 0:
		return null
	if rid.is_empty():
		rid = regione_a(base.x, base.y)
	var sc: Array = spec.get("scostamento", [0, 0])
	var posto: Dictionary = posto_del_varco(base + Vector2i(int(sc[0]), int(sc[1])), rid)
	var porta: Area2D = _porta(iid, posto["cella"], "superficie")
	porta.name = nome
	for stato in ["chiuso", "aperto"]:
		var chiave: String = "varco_%s_%s" % [str(spec.get("aspetto", "")), stato]
		var meta: Dictionary = (dati["sprite"] as Dictionary).get(chiave, {})
		var spr := Sprite2D.new()
		spr.name = stato.capitalize()
		spr.texture = _texture_oggetto(chiave)
		spr.centered = false
		spr.offset = Vector2(-float(meta.get("ax", 0)), -float(meta.get("ay", 0)) - tile * 0.5)
		porta.add_child(spr)
	if not posto["parete"]:                                  # in piedi da solo: non ci si passa attraverso
		var corpo := StaticBody2D.new()
		corpo.collision_layer = STRATO_COLLISIONE
		var forma := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(tile * 3, tile)
		forma.shape = rect
		forma.position = Vector2(0, -tile)
		corpo.add_child(forma)
		porta.add_child(corpo)
	add_child(porta)
	var cv: Vector2i = posto["cella"]
	_spiazzi.append(Rect2i(cv.x - 3, cv.y - 2, 7, 7))       # le chiome davanti coprirebbero varco e soglia
	return porta


## US-8B95: le soglie (data/world/mezzi.json con "arrivo"): un ingresso che porta all'arrivo,
## aperto solo con la chiave nello zaino; la chiave sta a terra in chiave_luogo finche' non la
## si prende. La soglia del faro porta all'approdo della Frontiera (decisione 2026-10-26).
func crea_soglie() -> void:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	var inv: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	if gd == null:
		return
	for id in gd.call("get_mezzi"):
		var spec: Dictionary = gd.call("get_mezzo", id)
		var arrivo: Vector2i = _luogo_varco(str(spec.get("arrivo", "")))
		if arrivo.x < 0:
			continue
		var sa: Array = spec.get("scostamento_arrivo", [0, 0])            # non sulla soglia di un altro varco
		arrivo += Vector2i(int(sa[0]), int(sa[1]))
		var porta: Area2D = _varco_sulla_mappa(spec, str(id), "Soglia_%s" % str(id).trim_prefix("soglia_"))
		if porta == null:
			continue
		porta.set_meta("chiave", str(spec.get("chiave", "")))
		porta.set_meta("arrivo", cella_libera(arrivo, {}, "", regione_a(arrivo.x, arrivo.y)))
		var dove: Vector2i = _luogo_varco(str(spec.get("chiave_luogo", "")))
		if dove.x >= 0 and not (inv != null and bool(inv.call("possiede", str(spec.get("chiave", ""))))):
			var c: Vector2i = cella_libera(dove, {}, "", regione_a(dove.x, dove.y))
			var pickup: Node2D = preload("res://scripts/item_pickup.gd").new()
			add_child(pickup)
			pickup.name = "Chiave_%s" % str(id).trim_prefix("soglia_")
			pickup.call("setup", str(spec["chiave"]), Vector2((c.x + 0.5) * tile, (c.y + 0.5) * tile))
			pickup.set_meta("livello", "superficie")


## La casella del varco vicino a c nella regione rid: davanti a una parete (le 3 caselle
## a nord bloccate, non una casa) entro RAGGIO_PARETE; se non c'e', la casella libera piu'
## vicina con libere anche le 3 caselle a nord (ci sta il disegno). Sempre con le 2 sotto
## libere. -> {cella, parete}
func posto_del_varco(c: Vector2i, rid: String) -> Dictionary:
	for parete in [true, false]:
		for r in range(0, RAGGIO_PARETE if parete else 120):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dy)) != r:
						continue
					var q := Vector2i(c.x + dx, c.y + dy)
					if _varco_sta(q, rid, parete):
						return {"cella": q, "parete": parete}
	return {"cella": c, "parete": false}


func _varco_sta(q: Vector2i, rid: String, parete: bool) -> bool:
	if q.x < 1 or q.y < 1 or q.x >= larghezza - 1 or q.y >= altezza - 3 or regione_a(q.x, q.y) != rid:
		return false
	if bloccata(q.x, q.y) or bloccata(q.x, q.y + 1) or bloccata(q.x, q.y + 2):
		return false
	for dx in [-1, 0, 1]:
		if bloccata(q.x + dx, q.y - 1) != parete or (parete and _in_una_casa(q.x + dx, q.y - 1)):
			return false
	return true


## Un punto coperto da un oggetto di scena che gli sta davanti (un albero piu' a sud, con la chioma sopra il punto):
## il disegno dell'oggetto non e' trasparente li'. La fauna (US-8B23b) e l'orto della base (US-8B20c) non ci si mettono.
func coperto(punto: Vector2) -> bool:
	var lato: int = BLOCCO
	var meta: Dictionary = dati.get("sprite", {})
	var per_blocco: Dictionary = _oggetti_per_blocco
	var c := Vector2i(floori(punto.x / tile / lato), floori(punto.y / tile / lato))
	for dy in range(0, 2):                                  # chi copre sta allo stesso blocco o a quello sotto
		for dx in range(-1, 2):
			for o in per_blocco.get(c + Vector2i(dx, dy), []):
				var base := Vector2(float(o[1]) * tile, float(o[2]) * tile)
				if base.y <= punto.y:
					continue
				var img: Image = _immagine_oggetto(str(o[0]))
				var m: Dictionary = meta.get(str(o[0]), {})
				var t: Vector2i = Vector2i(punto - base + Vector2(float(m.get("ax", 0)), float(m.get("ay", 0))))
				if img != null and t.x >= 0 and t.y >= 0 and t.x < img.get_width() and t.y < img.get_height() \
						and img.get_pixel(t.x, t.y).a > 0.5:
					return true
	return false


var _immagini_oggetti: Dictionary = {}


func _immagine_oggetto(chiave: String) -> Image:
	if not _immagini_oggetti.has(chiave):
		var tex: Texture2D = _texture_oggetto(chiave)
		_immagini_oggetti[chiave] = tex.get_image() if tex != null else null
	return _immagini_oggetti[chiave]


func _in_una_casa(x: int, y: int) -> bool:
	for e in dati.get("edifici", []):
		if x >= int(e[0]) and y >= int(e[1]) and x < int(e[0]) + int(e[2]) and y < int(e[1]) + int(e[3]):
			return true
	return false


## Un luogo della mappa (mondo.json luoghi) o un punto del sottosuolo (sottosuolo.boss).
## Le zone dei layout dietro un varco (gating[].varco.zona, US-8B21b): il loro contenuto
## non sta all'aperto ma nell'interno del varco. -> {rid: {zona: Rect2i}}
func _zone_dei_varchi() -> Dictionary:
	var out: Dictionary = {}
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	if gd == null:
		return out
	for reg in gd.call("get_regions"):
		var rid: String = str((reg as Dictionary).get("id", ""))
		var zone: Dictionary = (gd.call("get_layout", rid) as Dictionary).get("zone", {})
		for g in (reg as Dictionary).get("gating", []):
			var z: String = str(((g as Dictionary).get("varco", {}) as Dictionary).get("zona", ""))
			var r: Array = zone.get(z, [])
			if r.size() == 4:
				if not out.has(rid):
					out[rid] = {}
				out[rid][z] = Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
	return out


func _in_rect(spec: Dictionary, rects: Array) -> bool:
	var c := Vector2i(int(spec.get("x", 0)), int(spec.get("y", 0)))
	for r in rects:
		if (r as Rect2i).has_point(c):
			return true
	return false


## Nemici (con il drop del layout) e oggetti della zona dietro il varco, per l'interno
## (interior_scene.gd ospiti): {rect: [x, y, w, h], nemici, oggetti}; {} senza zona.
func ospiti_del_varco(porta: Area2D) -> Dictionary:
	var rid: String = str(porta.get_meta("regione", ""))
	var z: String = str(((porta.get_meta("gate", {}) as Dictionary).get("varco", {}) as Dictionary).get("zona", ""))
	var r: Variant = (_zone_dei_varchi().get(rid, {}) as Dictionary).get(z)
	if r == null:
		return {}
	var layout: Dictionary = Engine.get_main_loop().root.get_node("GameData").call("get_layout", rid)
	var drop: Dictionary = layout.get("drop", {})
	var nemici: Array = []
	for n in (layout.get("nemici", []) as Array).filter(func(e): return _in_rect(e, [r])):
		var spec: Dictionary = (n as Dictionary).duplicate(true)
		var seq: String = str(int(spec.get("sequenza", 9)))
		if drop.has(seq):
			var ov: Dictionary = spec.get("override", {})
			ov["oggetti_a_morte"] = drop[seq]
			spec["override"] = ov
		nemici.append(spec)
	var rect: Rect2i = r
	return {"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "nemici": nemici,
			"oggetti": (layout.get("oggetti", []) as Array).filter(func(e): return _in_rect(e, [r]))}


func _luogo_varco(nome: String) -> Vector2i:
	var p: Array = (dati.get("luoghi", {}) as Dictionary).get(nome, ((dati.get("sottosuolo", {}) as Dictionary).get("boss", {}) as Dictionary).get(nome, []))
	return Vector2i(int(p[0]), int(p[1])) if p.size() == 2 else Vector2i(-1, -1)


## true per una porta senza varco o con il varco aperto ora (una soglia: con la sua chiave).
func varco_aperto(porta: Area2D) -> bool:
	if porta.has_meta("chiave"):
		var inv: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
		return inv != null and bool(inv.call("possiede", str(porta.get_meta("chiave"))))
	return not porta.has_meta("gate") or AreaGate.valuta_gate(str(porta.get_meta("regione")),
			porta.get_meta("gate"), Engine.get_main_loop().root)


func _aggiorna_varchi() -> void:
	for c in get_children():
		if c is Area2D and (c.has_meta("gate") or c.has_meta("chiave")):
			var ap: bool = varco_aperto(c)
			(c.get_node("Chiuso") as CanvasItem).visible = not ap
			(c.get_node("Aperto") as CanvasItem).visible = ap
			(c.get_node("Prompt") as Label).text = tr("HUD_PROMPT_ENTRA" if ap else "HUD_VARCO_CHIUSO").format(
					{"tasto": _tasto_interagisci()})


# --- Barca (US-8B91) -----------------------------------------------------------------
# Decisione dell'utente 2026-10-26: una barca libera ormeggiata al porto (data/world/mezzi.json).
# "interagisci" accanto alla barca: si sale, l'acqua si attraversa e la terra no (vincolo del
# giocatore); accanto a una costa libera si scende e la barca resta li'. Non si sbarca in una
# regione con "accesso" senza "barca" ne' "a_piedi" (le Marche: solo volo o sottosuolo).

var _barca: Node2D = null
var _barca_vicina := false
var _a_bordo := false                       # per accorgersi di una rinascita in barca
var _ormeggio_iniziale := Vector2i(-1, -1)


func crea_barca() -> void:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	var spec: Dictionary = gd.call("get_mezzo", "barca") if gd != null else {}
	var base: Vector2i = _luogo_varco(str(spec.get("luogo", "")))
	if spec.is_empty() or base.x < 0 or not (dati["sprite"] as Dictionary).has("barca"):
		return
	var sc: Array = spec.get("scostamento", [0, 0])
	_ormeggio_iniziale = ormeggio(base + Vector2i(int(sc[0]), int(sc[1])))
	_barca = Node2D.new()
	_barca.name = "Barca"
	_barca.set_meta("livello", "superficie")
	var meta: Dictionary = dati["sprite"]["barca"]
	var spr := Sprite2D.new()
	spr.name = "Disegno"
	spr.texture = _texture_oggetto("barca")
	spr.centered = false
	spr.offset = Vector2(-float(meta.get("ax", 0)), -float(meta.get("ay", 0)) + tile * 0.25)
	_barca.add_child(spr)
	var area := Area2D.new()
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tile * 2.4, tile * 2.0)
	forma.shape = rect
	area.add_child(forma)
	area.body_entered.connect(func(b: Node) -> void: if b.is_in_group("player"): _barca_vicina = true)
	area.body_exited.connect(func(b: Node) -> void: if b.is_in_group("player"): _barca_vicina = false)
	_barca.add_child(area)
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.add_theme_font_size_override("font_size", 10)
	prompt.size = Vector2(tile * 6, tile * 0.5)
	prompt.position = Vector2(-tile * 3, tile * 0.5)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.z_index = 10
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.add_theme_color_override("font_outline_color", Color("#181425"))
	prompt.hide()
	_barca.add_child(prompt)
	add_child(_barca)
	metti_barca(_ormeggio_iniziale)


## US-8B20d: la nave della base (mezzi.json "nave"), ormeggiata e ferma: nell'acqua vicina al luogo un tratto largo
## quanto lei (NAVE_CASELLE x 2 caselle) con terra libera accanto, a sud (davanti, si vede) o se no a nord, collegata
## a piedi al resto della terra (_a_terra); su quella terra la passerella e' la porta verso il suo interno.
const NAVE_CASELLE := 6


func crea_nave() -> void:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	var spec: Dictionary = gd.call("get_mezzo", "nave") if gd != null else {}
	var base: Vector2i = _luogo_varco(str(spec.get("luogo", "")))
	if spec.is_empty() or base.x < 0 or not (dati["sprite"] as Dictionary).has("nave"):
		return
	var sc: Array = spec.get("scostamento", [0, 0])
	var c := base + Vector2i(int(sc[0]), int(sc[1]))
	var posto: Array = []
	for lato in [1, -2]:                           # terra a sud della nave, se no a nord
		for r in range(0, 40):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if not posto.is_empty() or maxi(absi(dx), absi(dy)) != r:
						continue
					var q := Vector2i(c.x + dx, c.y + dy)
					var passerella: Vector2i = _passerella(q, lato)
					if passerella.x >= 0:
						posto = [q, passerella]
		if not posto.is_empty():
			break
	if posto.is_empty():
		return
	var q: Vector2i = posto[0]
	var meta: Dictionary = dati["sprite"]["nave"]
	var nave := Sprite2D.new()
	nave.name = "Nave"
	nave.set_meta("livello", "superficie")
	nave.texture = _texture_oggetto("nave")
	nave.centered = false
	nave.offset = Vector2(-float(meta.get("ax", 0)), -float(meta.get("ay", 0)))
	nave.position = Vector2(q.x * tile, (q.y + 0.75) * tile)       # il pelo dell'acqua nella riga q.y
	add_child(nave)
	add_child(_porta(str(spec.get("interno", "")), posto[1], "superficie"))


## La casella della passerella per la nave nella fila q.y (caselle q.x - 3 .. q.x + 2, e la riga sopra): tutta
## acqua, e terra libera accanto (lato 1 = la riga sotto, -2 = la riga sopra la nave). (-1, -1) se non va.
func _passerella(q: Vector2i, lato: int) -> Vector2i:
	for dy in [-1, 0]:
		for dx in range(-NAVE_CASELLE / 2, NAVE_CASELLE / 2):
			if not acqua(q.x + dx, q.y + dy):
				return Vector2i(-1, -1)
	for dx in [-1, 0, 1, -2]:
		var t := Vector2i(q.x + dx, q.y + lato)
		if _dentro(t.x, t.y) and not bloccata(t.x, t.y) and not acqua(t.x, t.y) and _a_terra(t):
			return t
	return Vector2i(-1, -1)


## Da t si arriva a piedi ad almeno TERRA_MINIMA caselle: non un pezzo di pontile chiuso da un dislivello.
const TERRA_MINIMA := 60


func _a_terra(t: Vector2i) -> bool:
	var visti: Dictionary = {t: true}
	var coda: Array = [t]
	while not coda.is_empty() and visti.size() < TERRA_MINIMA:
		var q: Vector2i = coda.pop_front()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = q + d
			if not visti.has(n) and _dentro(n.x, n.y) and not bloccata(n.x, n.y):
				visti[n] = true
				coda.append(n)
	return visti.size() >= TERRA_MINIMA


func metti_barca(c: Vector2i) -> void:
	_barca.position = Vector2((c.x + 0.5) * tile, (c.y + 0.5) * tile)


## L'acqua piu' vicina a c che tocca una costa libera: dove si ormeggia.
func ormeggio(c: Vector2i) -> Vector2i:
	for r in range(0, 60):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := Vector2i(c.x + dx, c.y + dy)
				if maxi(absi(dx), absi(dy)) == r and acqua(q.x, q.y) and _costa_vicina(q).x >= 0:
					return q
	return c


## Acqua (o il vuoto della nebbia) in superficie: blocchi.png 255.
func acqua(x: int, y: int) -> bool:
	var b: PackedByteArray = _livelli.get("superficie", {}).get("blocchi", _blocchi)
	return _dentro(x, y) and b[y * larghezza + x] == 255


func _solo_acqua(pos: Vector2) -> bool:
	return acqua(floori(pos.x / tile), floori(pos.y / tile))


func in_barca() -> bool:
	var p: Node = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	return p != null and p.has_method("in_barca") and bool(p.call("in_barca"))


func sali_in_barca() -> bool:
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	if p == null or _barca == null or in_barca() or livello != "superficie":
		return false
	p.call("imposta_barca", true, _solo_acqua)
	_a_bordo = true
	colloca(p, _barca.position)
	return true


func scendi_dalla_barca() -> bool:
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	if p == null or not in_barca():
		return false
	var c := Vector2i(floori(p.position.x / tile), floori(p.position.y / tile))
	var t: Vector2i = _costa_vicina(c)
	if t.x < 0:
		return false
	metti_barca(c)
	_a_bordo = false
	p.call("imposta_barca", false)
	colloca(p, Vector2((t.x + 0.5) * tile, (t.y + 0.5) * tile))
	return true


## Una casella di terra libera accanto a c dove si puo' sbarcare; (-1, -1) se nessuna.
func _costa_vicina(c: Vector2i) -> Vector2i:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var q: Vector2i = c + d
		if _dentro(q.x, q.y) and not acqua(q.x, q.y) and not bloccata(q.x, q.y) and _si_sbarca(q):
			return q
	return Vector2i(-1, -1)


func _si_sbarca(q: Vector2i) -> bool:
	return _si_arriva(q, "barca")


## Si arriva in q con quel modo (barca, volo): la regione non ha "accesso", o lo ha con il
## modo o con "a_piedi" (le Marche: volo e sottosuolo).
func _si_arriva(q: Vector2i, modo: String) -> bool:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	var reg: Dictionary = gd.call("get_region", regione_a(q.x, q.y)) if gd != null else {}
	if not reg.has("accesso"):
		return true
	var acc: Array = reg["accesso"]
	return modo in acc or "a_piedi" in acc


## In barca la barca segue il giocatore (sotto di lui, rivolta dove va); a terra la scritta
## "sali" accanto alla barca. Rinato a terra mentre era in barca: la barca torna all'ormeggio.
func _aggiorna_barca(p: Node2D) -> void:
	if _barca == null:
		return
	var prompt: Label = _barca.get_node("Prompt")
	if in_barca():
		_barca.position = p.position - Vector2(0, 0.5)
		var f: Vector2 = p.call("get_facing") if p.has_method("get_facing") else Vector2.LEFT
		if f.x != 0.0:
			(_barca.get_node("Disegno") as Sprite2D).flip_h = f.x > 0.0
		var c := Vector2i(floori(p.position.x / tile), floori(p.position.y / tile))
		prompt.visible = _costa_vicina(c).x >= 0
		prompt.text = tr("HUD_PROMPT_SCENDI_BARCA").format({"tasto": _tasto_interagisci()})
		return
	if _a_bordo:
		_a_bordo = false
		metti_barca(_ormeggio_iniziale)
	prompt.visible = _barca_vicina and livello == "superficie"
	prompt.text = tr("HUD_PROMPT_SALI_BARCA").format({"tasto": _tasto_interagisci()})


# --- Volo (US-8B93) ------------------------------------------------------------------
# Decisione dell'utente 2026-10-26: il volo si sblocca con una chiave del mondo
# (data/world/mezzi.json volo.chiave: un oggetto da trovare, che non si vende), per tutti i
# Pathway. "vola" decolla e atterra; in volo si passa sopra tutto restando nella mappa; si
# atterra su terra libera di una regione che lo ammette (_si_arriva "volo").

var _avviso: Label = null


func puo_volare() -> bool:
	var root: Node = Engine.get_main_loop().root
	var gd: Node = root.get_node_or_null("GameData")
	var inv: Node = root.get_node_or_null("Inventory")
	var chiave: String = str((gd.call("get_mezzo", "volo") as Dictionary).get("chiave", "")) if gd != null else ""
	return not chiave.is_empty() and inv != null and bool(inv.call("possiede", chiave))


func in_volo() -> bool:
	var p: Node = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	return p != null and p.has_method("in_volo") and bool(p.call("in_volo"))


func decolla() -> bool:
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	if p == null or in_volo() or in_barca() or _interno != null or livello != "superficie" or not puo_volare():
		return false
	p.call("imposta_volo", true, _nella_mappa)
	return true


func atterra() -> bool:
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	if p == null or not in_volo():
		return false
	var c := Vector2i(floori(p.position.x / tile), floori(p.position.y / tile))
	if bloccata(c.x, c.y) or not _si_arriva(c, "volo"):
		_mostra_avviso(p, tr("HUD_VOLO_NON_ATTERRA"))
		return false
	p.call("imposta_volo", false)
	return true


func _nella_mappa(pos: Vector2) -> bool:
	var c := Vector2i(floori(pos.x / tile), floori(pos.y / tile))
	return c.x >= 1 and c.y >= 1 and c.x < larghezza - 1 and c.y < altezza - 1


## Una scritta sotto il giocatore per un attimo (non si atterra qui).
func _mostra_avviso(p: Node2D, testo: String) -> void:
	if _avviso == null:
		_avviso = Label.new()
		_avviso.add_theme_font_size_override("font_size", 10)
		_avviso.size = Vector2(tile * 6, tile * 0.5)
		_avviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_avviso.z_index = 10
		_avviso.add_theme_constant_override("outline_size", 4)
		_avviso.add_theme_color_override("font_outline_color", Color("#181425"))
		add_child(_avviso)
	_avviso.text = testo
	_avviso.position = p.position + Vector2(-tile * 3, tile * 0.5)
	_avviso.show()
	get_tree().create_timer(1.5).timeout.connect(func() -> void: if is_instance_valid(_avviso): _avviso.hide())


# --- Cannocchiali (US-8B24) -------------------------------------------------------

## I cannocchiali di data/world/cannocchiali.json vicino al loro luogo (mai sopra o accanto a una soglia).
func crea_cannocchiali() -> void:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	if gd == null:
		return
	var luoghi: Dictionary = dati.get("luoghi", {})
	var soglie: Dictionary = {}
	for c in get_children():
		if c is Area2D and (str(c.name).begins_with("Soglia_") or str(c.name).begins_with("Varco_")):
			soglie[Vector2i(floori(c.position.x / tile), floori(c.position.y / tile))] = true
	var vista: Dictionary = gd.call("get_vista_cannocchiale")
	var tutti: Dictionary = gd.call("get_cannocchiali")
	for id in tutti:
		var spec: Dictionary = tutti[id]
		var l: Variant = luoghi.get(str(spec.get("luogo", "")))
		var b: Variant = luoghi.get(str(spec.get("bersaglio", "")))
		if not (l is Array and b is Array):
			continue
		var s: Array = spec.get("scostamento", [0, 0])
		var sb: Array = spec.get("scostamento_bersaglio", [0, 0])
		var c := Vector2i(int(l[0]) + int(s[0]), int(l[1]) + int(s[1]))
		var q: Vector2i = cella_libera(c, soglie, "", regione_a(c.x, c.y))
		var verso := Vector2((float(b[0]) + float(sb[0]) + 0.5) * tile, (float(b[1]) + float(sb[1]) + 0.5) * tile)
		var n: Area2D = preload("res://scripts/cannocchiale.gd").new()
		n.call("setup", str(id), Vector2((q.x + 0.5) * tile, (q.y + 0.5) * tile), verso, vista)
		n.set_meta("livello", "superficie")
		add_child(n)


# --- Forzieri del sottosuolo (US-8B22b) --------------------------------------------

## I forzieri di data/world/bottino.json "forzieri_mondo", vicino a un punto del sottosuolo (un ingresso o un boss).
func crea_forzieri() -> void:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	if gd == null or not _prepara_sottosuolo():
		return
	var s: Dictionary = dati.get("sottosuolo", {})
	var b: PackedByteArray = _livelli["sottosuolo"]["blocchi"]
	var presi: Dictionary = {}
	for spec in gd.call("get_forzieri_mondo"):
		var vicino: String = str((spec as Dictionary).get("vicino", ""))
		var p: Variant = (s.get("boss", {}) as Dictionary).get(vicino, (s.get("ingressi", {}) as Dictionary).get(vicino))
		if not p is Array:
			continue
		var c: Vector2i = posto_del_forziere(Vector2i(int(p[0]), int(p[1])), b, presi)
		presi[c] = true
		var f: Area2D = preload("res://scripts/forziere.gd").new()
		f.call("setup", str(spec.get("id", "")), str(spec.get("tabella", "")), Vector2((c.x + 0.5) * tile, (c.y + 0.5) * tile))
		f.set_meta("livello", "sottosuolo")
		add_child(f)
		_mostra(f, livello == "sottosuolo")


## Il forziere e' pieno: in un corridoio chiuderebbe il passaggio. Dal punto c si cammina (caselle libere di b, al piu'
## 16 passi) e si prende il primo vicolo cieco ad almeno 3 passi; se non c'e', il primo spiazzo (8 vicine libere).
func posto_del_forziere(c: Vector2i, b: PackedByteArray, presi: Dictionary = {}) -> Vector2i:
	var passi: Dictionary = {c: 0}
	var coda: Array = [c]
	var spiazzo := Vector2i(-1, -1)
	var lati: Array = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	while not coda.is_empty():
		var q: Vector2i = coda.pop_front()
		var n: int = passi[q]
		if n >= 3 and not presi.has(q):
			var liberi: int = lati.filter(func(d): return _libera_in(q + d, b)).size()
			if liberi == 1:
				return q
			if spiazzo.x < 0 and _spiazzo_in(q, b):
				spiazzo = q
		if n >= 16:
			continue
		for d in lati:
			var v: Vector2i = q + d
			if _libera_in(v, b) and not passi.has(v):
				passi[v] = n + 1
				coda.append(v)
	return spiazzo if spiazzo.x >= 0 else c


func _libera_in(q: Vector2i, b: PackedByteArray) -> bool:
	return _dentro(q.x, q.y) and b[q.y * larghezza + q.x] == 0


func _spiazzo_in(q: Vector2i, b: PackedByteArray) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not _libera_in(q + Vector2i(dx, dy), b):
				return false
	return true


# --- Sottosuolo: ingressi e cambio di livello (2026-10-25) ------------------------

## Un'Area2D per ingresso (mondo.json sottosuolo.ingressi), con il disegno del
## livello mostrato: botola o scale in superficie, scala a pioli sotto.
func crea_ingressi() -> void:
	var ing: Dictionary = (dati.get("sottosuolo", {}) as Dictionary).get("ingressi", {})
	for nome in ing:
		var v: Array = ing[nome]
		var area := Area2D.new()
		area.name = "Ingresso_%s" % nome
		area.set_meta("ingresso", nome)
		area.position = Vector2((float(v[0]) + 0.5) * tile, (float(v[1]) + 0.5) * tile)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(tile, tile) * 1.6
		shape.shape = rect
		area.add_child(shape)
		var spr := Sprite2D.new()
		spr.name = "Disegno"
		spr.centered = false
		area.add_child(spr)
		var prompt := Label.new()
		prompt.name = "Prompt"
		prompt.add_theme_font_size_override("font_size", 10)
		prompt.position = Vector2(-tile, tile * 0.6)
		prompt.hide()
		area.add_child(prompt)
		area.body_entered.connect(_su_ingresso.bind(str(nome), true))
		area.body_exited.connect(_su_ingresso.bind(str(nome), false))
		add_child(area)
	_aggiorna_ingressi()


func _aggiorna_ingressi() -> void:
	var s: Dictionary = dati.get("sottosuolo", {})
	var per_zona: Dictionary = s.get("sprite_ingresso", {})
	for c in get_children():
		if not c.has_meta("ingresso"):
			continue
		var zona: String = str((s["ingressi"][c.get_meta("ingresso")] as Array)[2])
		var chiave: String = "ingresso_%s" % (str(per_zona.get(zona, "scale")) if livello == "superficie" else "risalita")
		var meta: Dictionary = (dati["sprite"] as Dictionary).get(chiave, {})
		var spr: Sprite2D = c.get_node("Disegno")
		spr.texture = _texture_oggetto(chiave)
		spr.offset = Vector2(-float(meta.get("ax", 0)), -float(meta.get("ay", 0))) + Vector2(0, tile * 0.5)
		spr.z_index = -5 if livello == "superficie" else 0      # botola e scale stanno a terra: sotto chi ci passa
		var chiave_testo: String = "HUD_PROMPT_SCENDI" if livello == "superficie" else "HUD_PROMPT_SALI"
		(c.get_node("Prompt") as Label).text = tr(chiave_testo).format({"tasto": _tasto_interagisci()})


func _su_ingresso(body: Node, nome: String, dentro: bool) -> void:
	if not body.is_in_group("player"):
		return
	if dentro:
		_ingresso_vicino = nome
	elif _ingresso_vicino == nome:
		_ingresso_vicino = ""
	var a: Node = get_node_or_null("Ingresso_%s/Prompt" % nome)
	if a != null:
		a.visible = dentro


func _tasto_interagisci() -> String:
	for ev in InputMap.action_get_events("interagisci"):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return "F"


## Passa all'altro livello dall'ingresso 'nome': il giocatore resta nello stesso
## punto (la casella libera piu' vicina della stessa regione, se quella esatta e'
## bloccata sull'altro livello). false se il sottosuolo non e' esportato.
func attraversa(nome: String) -> bool:
	var ing: Dictionary = (dati.get("sottosuolo", {}) as Dictionary).get("ingressi", {})
	if not ing.has(nome):
		return false
	var nuovo: String = "sottosuolo" if livello == "superficie" else "superficie"
	if not cambia_livello(nuovo):
		return false
	var v: Array = ing[nome]
	var c := Vector2i(int(v[0]), int(v[1]))
	var q: Vector2i = cella_libera(c, {}, "", regione_a(c.x, c.y))
	var pos := Vector2((q.x + 0.5) * tile, (q.y + 0.5) * tile)
	var p: Node = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if p is Node2D:
		colloca(p as Node2D, pos)
	_ultima_ammessa = pos
	_cella_regione = Vector2i(-9999, -9999)
	aggiorna_regione(pos)
	return true


## Mostra un livello: libera i blocchi costruiti, cambia tessere, collisioni e
## oggetti; NPC e nemici della superficie spariscono (e si fermano) sotto terra.
func cambia_livello(nuovo: String) -> bool:
	if nuovo == livello:
		return true
	if nuovo == "sottosuolo" and not _prepara_sottosuolo():
		return false
	for b in _caricati.keys():
		_scarica(b)
	var l: Dictionary = _livelli[nuovo]
	_indici = l["indici"]
	_blocchi = l["blocchi"]
	_oggetti_per_blocco = l["oggetti"]
	_terreno.tile_set = l["tileset"]
	livello = nuovo
	_blocco_centro = Vector2i(-9999, -9999)
	var sopra: bool = livello == "superficie"
	for c in get_children():
		if c is Area2D and c.has_meta("npc_id"):
			_mostra(c, sopra)
		elif c.has_meta("livello") or c.is_in_group("nemici"):
			_mostra(c, str(c.get_meta("livello", "superficie")) == livello)
	_ingresso_vicino = ""
	_aggiorna_ingressi()
	livello_cambiato.emit(livello)
	return true


func _mostra(n: Node, si: bool) -> void:
	(n as CanvasItem).visible = si
	n.process_mode = Node.PROCESS_MODE_INHERIT if si else Node.PROCESS_MODE_DISABLED
	if n is Area2D:                         # un'area dell'altro livello non si tocca (raccolta, incontri)
		n.set_deferred("monitoring", si)
		n.set_deferred("monitorable", si)


## Una casella libera vicino a c, lontana almeno 2 caselle da quelle occupate
## (e, se data, nella stessa regione). Senza chiave: la piu' vicina. Con una chiave (l'id di un NPC): una a caso ma
## sempre la stessa (hash della chiave) fra le libere entro 4 anelli dalla prima,
## cosi' un gruppo di NPC non sta in fila come una griglia.
## blocchi: le collisioni di un altro livello (default: quelle mostrate).
func cella_libera(c: Vector2i, occupate: Dictionary = {}, chiave: String = "", regione: String = "",
		raggio_max: int = 24, blocchi: PackedByteArray = PackedByteArray()) -> Vector2i:
	var bl: PackedByteArray = _blocchi if blocchi.is_empty() else blocchi
	var scelta := c
	var punteggio: int = 0
	var primo: int = -1
	var idx: int = (dati.get("regioni", []) as Array).find(regione) if not regione.is_empty() else -1
	for r in range(0, raggio_max):
		if primo >= 0 and r > primo + 4:
			break
		for dy in range(-r, r + 1):                   # solo l'anello, riga per riga (stesso ordine di sempre)
			var passo: int = 1 if absi(dy) == r else maxi(2 * r, 1)
			for dx in range(-r, r + 1, passo):
				var q := Vector2i(c.x + dx, c.y + dy)
				if q.x < 0 or q.y < 0 or q.x >= larghezza or q.y >= altezza:
					continue
				var i: int = q.y * larghezza + q.x
				if bl[i] > 0 or (idx >= 0 and _regioni[i] != idx) or _vicino_occupato(q, occupate):
					continue
				if chiave.is_empty():
					return q
				var h: int = hash(chiave + str(q))
				if primo < 0 or h < punteggio:
					scelta = q
					punteggio = h
				if primo < 0:
					primo = r
	return scelta


func _vicino_occupato(q: Vector2i, occupate: Dictionary) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if occupate.has(q + Vector2i(dx, dy)):
				return true
	return false


## US-617: fast travel dalla pagina mappa del libro. Si arriva al primo luogo
## della regione che c'e' sulla mappa (ordine di location_tags), sempre
## rispettando il gating d'ingresso.
func viaggia_a(target: String) -> bool:
	var ws: Node = Engine.get_main_loop().root.get_node_or_null("WorldState")
	if (ws != null and str(ws.call("regione_corrente")) == target) or not ingresso_aperto(target):
		return false
	var q: Vector2i = arrivo_in(target)
	if q.x < 0:
		return false
	var pos := Vector2((q.x + 0.5) * tile, (q.y + 0.5) * tile)
	var p: Node = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if p is Node2D:
		colloca(p as Node2D, pos)
	_ultima_ammessa = pos
	aggiorna_regione(pos)
	return true


## La casella d'arrivo in una regione: il primo luogo dei suoi location_tags
## presente sulla mappa, poi la casella libera piu' vicina. (-1, -1) se nessuno.
func arrivo_in(rid: String) -> Vector2i:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	if gd == null:
		return Vector2i(-1, -1)
	for tag in (gd.call("get_region", rid).get("location_tags", []) as Array):
		var c: Vector2i = luogo_del_tag(rid, str(tag))
		if c.x >= 0:
			return cella_libera(c)
	return Vector2i(-1, -1)


# --- NPC (US-612/613b nel mondo unico) -------------------------------------------

## Gli NPC presenti ORA (schedule + momento, NpcSystem.presenti) di tutte le
## regioni, al luogo della mappa del loro location_tag. Ricostruiti a ogni
## momento_cambiato. Il disegno e' l'aspetto del roster (tools/art/build_npc.py).
func crea_npc() -> void:
	for c in get_children():
		if c is Area2D and c.has_meta("npc_id"):
			remove_child(c)
			c.queue_free()
	var ns: Node = Engine.get_main_loop().root.get_node_or_null("NpcSystem")
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	if ns == null or gd == null:
		return
	var occupate: Dictionary = {}
	for r in gd.call("get_regions"):
		var rid: String = str((r as Dictionary).get("id", ""))
		var presenti: Dictionary = ns.call("presenti", rid)
		var ids: Array = presenti.keys()
		ids.sort()
		for id in ids:
			var c: Vector2i = luogo_del_tag(rid, str(presenti[id]))
			if c.x < 0:
				continue
			var q: Vector2i = cella_libera(c, occupate, str(id))
			occupate[q] = true
			var asp: Variant = gd.call("get_npc", str(id)).get("aspetto", {})
			var aspetto: String = str((asp as Dictionary).get("sprite", "")) if asp is Dictionary else ""
			add_child(_npc(str(id), Vector2((q.x + 0.5) * tile, (q.y + 0.5) * tile), aspetto))


func _npc(id: String, pos: Vector2, aspetto: String = "") -> Area2D:
	var area := Area2D.new()
	area.name = "Npc_%s" % id
	area.set_meta("npc_id", id)
	area.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tile, tile) * 1.2
	shape.shape = rect
	area.add_child(shape)
	var anim: AnimatedSprite2D = AnimationMachine.new()
	anim.name = "AnimationMachine"
	area.add_child(anim)
	anim.call("configura", "personaggio", aspetto)
	anim.call("riproduci", "idle", "down")
	area.body_entered.connect(_npc_avvicinato.bind(id))
	area.body_exited.connect(_npc_allontanato.bind(id))
	return area


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


## "interagisci" vicino a un NPC -> il suo dialogo (dialogue_id dal roster);
## davanti a una porta -> l'interno; sopra un ingresso del sottosuolo -> l'altro livello.
func _unhandled_input(event: InputEvent) -> void:
	var book: Node = get_node_or_null("/root/Book")
	if book != null and bool(book.call("e_aperto")):
		return
	if event.is_action_pressed("vola"):
		if (atterra() if in_volo() else decolla()):
			get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("interagisci") or in_volo():   # in volo si atterra prima
		return
	if _npc_vicino.is_empty():
		if in_barca():
			if scendi_dalla_barca():
				get_viewport().set_input_as_handled()
		elif _porta_vicina != null and _interno == null and entra(_porta_vicina):
			get_viewport().set_input_as_handled()
		elif not _ingresso_vicino.is_empty() and attraversa(_ingresso_vicino):
			get_viewport().set_input_as_handled()
		elif _barca_vicina and sali_in_barca():
			get_viewport().set_input_as_handled()
		return
	var de: Node = get_node_or_null("/root/DialogueEngine")
	if de == null or bool(de.call("in_corso")):
		return
	var gd: Node = get_node_or_null("/root/GameData")
	var did: String = str(gd.call("get_npc", _npc_vicino).get("dialogue_id", "")) if gd != null else ""
	if not did.is_empty() and de.call("avvia", did, _npc_vicino):
		get_viewport().set_input_as_handled()


func _zona(c: Vector2i, reg: Dictionary) -> String:
	var tags: Array = reg.get("location_tags", [])
	var alias: Dictionary = reg.get("luoghi_mondo", {})
	var migliore: String = ""
	var dist: float = RAGGIO_ZONA
	for luogo in (dati.get("luoghi", {}) as Dictionary):
		var tag: String = str(alias.get(luogo, luogo))
		if tag not in tags:
			continue
		var p: Array = dati["luoghi"][luogo]
		var d: float = Vector2(c).distance_to(Vector2(float(p[0]), float(p[1])))
		if d <= dist:
			dist = d
			migliore = tag
	return migliore


# --- Interrogabile (giocatore, test, regioni) ---------------------------------

func tessera_a(x: int, y: int) -> int:
	if not _dentro(x, y):
		return -1
	var i: int = (y * larghezza + x) * 3
	return _indici[i] + 256 * _indici[i + 1]


func bloccata(x: int, y: int) -> bool:
	return not _dentro(x, y) or _blocchi[y * larghezza + x] > 0


## Un dislivello (parete senza scala, bordo alto di un gradone): a piedi no, in volo si'.
func dislivello(x: int, y: int) -> bool:
	return _dentro(x, y) and _blocchi[y * larghezza + x] == DISLIVELLO


func regione_a(x: int, y: int) -> String:
	if not _dentro(x, y):
		return ""
	return str((dati["regioni"] as Array)[_regioni[y * larghezza + x]])


## blocchi.png grezzo (1 byte per casella: 0 libera, 128 dislivello, 255 acqua/vuoto).
func blocchi_grezzi() -> PackedByteArray:
	return _blocchi


func blocchi_caricati() -> int:
	return _caricati.size()


func tema_caricato() -> String:
	return _tema_caricato


# --- Interno -------------------------------------------------------------------

func _costruisci(b: Vector2i) -> void:
	for y in range(b.y * BLOCCO, mini((b.y + 1) * BLOCCO, altezza)):
		for x in range(b.x * BLOCCO, mini((b.x + 1) * BLOCCO, larghezza)):
			var t: int = tessera_a(x, y)
			var foglio: int = t / _per_foglio
			var r: int = t % _per_foglio
			var at := Vector2i(r % _colonne, r / _colonne)
			var src := _terreno.tile_set.get_source(foglio) as TileSetAtlasSource
			if not src.has_tile(at):
				src.create_tile(at)
			_terreno.set_cell(Vector2i(x, y), foglio, at)
			if bloccata(x, y):
				_ostacoli.set_cell(Vector2i(x, y), 0, Vector2i(1, 0) if dislivello(x, y) else Vector2i.ZERO)
	var sprite: Array = []
	for o in _oggetti_per_blocco.get(b, []):
		if livello == "superficie" and _nello_spiazzo(Vector2i(int(o[1]), int(o[2]))):
			continue
		var chiave: String = str(o[0])
		var meta: Dictionary = (dati["sprite"] as Dictionary).get(chiave, {})
		var s := Sprite2D.new()
		s.texture = _texture_oggetto(chiave)
		s.centered = false
		s.offset = Vector2(-float(meta.get("ax", 0)), -float(meta.get("ay", 0)))
		s.position = Vector2(float(o[1]) * tile, float(o[2]) * tile)
		add_child(s)
		sprite.append(s)
	_caricati[b] = sprite
	blocco_costruito.emit(b)


func _nello_spiazzo(c: Vector2i) -> bool:
	for r in _spiazzi:
		if (r as Rect2i).has_point(c):
			return true
	return false


func _scarica(b: Vector2i) -> void:
	for y in range(b.y * BLOCCO, mini((b.y + 1) * BLOCCO, altezza)):
		for x in range(b.x * BLOCCO, mini((b.x + 1) * BLOCCO, larghezza)):
			_terreno.erase_cell(Vector2i(x, y))
			_ostacoli.erase_cell(Vector2i(x, y))
	for s in _caricati[b]:
		(s as Node).queue_free()
	_caricati.erase(b)
	blocco_scaricato.emit(b)


func _texture_oggetto(chiave: String) -> Texture2D:
	if not _texture_oggetti.has(chiave):
		_texture_oggetti[chiave] = _texture(cartella.path_join(_tema_caricato).path_join("oggetti/%s.png" % chiave))
	return _texture_oggetti[chiave]


func _dentro(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < larghezza and y < altezza


## Le PNG si leggono dal disco, senza l'import dell'editor (vale anche headless).
static func _texture(path: String) -> Texture2D:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		push_error("[Mondo] PNG non leggibile: " + path)
		return null
	return ImageTexture.create_from_image(img)


static func _immagine(path: String, formato: int) -> PackedByteArray:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		push_error("[Mondo] PNG non leggibile: " + path)
		return PackedByteArray()
	if img.get_format() != formato:
		img.convert(formato)
	return img.get_data()


func _tema_partita() -> String:
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("GameState")
	return str(gs.call("tema_arte")) if gs != null else "luminoso"
