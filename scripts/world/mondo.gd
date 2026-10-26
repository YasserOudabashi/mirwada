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
		segui(pos)
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
	var nemici: Array = layout.get("nemici", [])
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
	for o in layout.get("oggetti", []):
		var spec_o: Dictionary = o
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
		var vil: Array = (dati.get("villaggi", {}) as Dictionary).get(str(spec.get("villaggio", "")), [])
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
	prompt.position = Vector2(-tile, tile * 0.4)
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
	if p == null or _interno != null or get_parent() == null:
		return false
	var interno: Node = load("res://scenes/interior_scene.tscn").instantiate()
	interno.set("interno_id", str(porta.get_meta("interno_id")))
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
		if cam.has_method("clear_zone_limits"):
			cam.call("clear_zone_limits")              # la stanza resta al centro dello schermo
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


## Caricamento: fuori da un eventuale interno, sul livello salvato, nel punto salvato.
func riprendi(liv: String, pos: Vector2) -> void:
	esci()
	cambia_livello(liv)
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if p != null:
		colloca(p, pos)


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
	if not event.is_action_pressed("interagisci"):
		return
	var book: Node = get_node_or_null("/root/Book")
	if book != null and bool(book.call("e_aperto")):
		return
	if _npc_vicino.is_empty():
		if _porta_vicina != null and _interno == null and entra(_porta_vicina):
			get_viewport().set_input_as_handled()
		elif not _ingresso_vicino.is_empty() and attraversa(_ingresso_vicino):
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


func _scarica(b: Vector2i) -> void:
	for y in range(b.y * BLOCCO, mini((b.y + 1) * BLOCCO, altezza)):
		for x in range(b.x * BLOCCO, mini((b.x + 1) * BLOCCO, larghezza)):
			_terreno.erase_cell(Vector2i(x, y))
			_ostacoli.erase_cell(Vector2i(x, y))
	for s in _caricati[b]:
		(s as Node).queue_free()
	_caricati.erase(b)


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
