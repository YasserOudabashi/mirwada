extends "res://tests/test_case.gd"
## US-805 — formato dei layout disegnati a mano: loader, dipintura fisica,
## zone/passaggi da dati, fallback invariato per le regioni senza layout.
## US-806 — nemici/boss/oggetti a terra dichiarati nel layout.nemici/oggetti.
## US-807a — Marche del Crepuscolo: stesso formato, seconda regione, zero
## codice dedicato (solo test dedicati che leggono il suo layout).
## US-807b — Valle Madre: terza regione, stesso schema.
## US-807c — Archivio Sepolto: quarta regione, stesso schema.
## US-807d — Frontiera delle Porte: quinta e ultima regione, chiude il
## Blocco B (tutte e 5 le regioni hanno un layout da qui in poi).
## US-1002B (fase 10, mondo continuo) — non c'e' piu' una scena per regione:
## world_scene.gd dipinge tutte e 5 le regioni nella stessa TileMapLayer,
## ognuna al proprio world_offset (US-1001). Ogni assert di cella/zona/spawn
## qui sotto somma l'offset della regione in questione - letto da
## GameData, mai un numero scritto a mano nel test. I vecchi nodi
## "Passaggio_X" non esistono piu' (sostituiti dal confine + corridoio,
## tests/test_world_scene.gd); quei test sono stati tolti.

const TILE := 32  # world_scene.gd::TILE

## Colonne di tileset.png (US-813, world_scene.gd::_COLONNA_PER_CARATTERE),
## stesso ordine di generate_sprites.py.TILESET_COLONNE.
const COL_PAVIMENTO := 0
const COL_MURO := 1
const COL_ACQUA := 3
const COL_SENTIERO := 5
const COL_PORTA := 7

## Righe di tileset.png: 0 = neutra, poi 1 + indice della palette_visiva in
## data/vfx.json.pathway_palette_visiva (world_scene.gd::_riga_tileset()).
## mirwada e' "neutra"; le altre 4 regioni con layout hanno palette diverse
## -> righe diverse, verificato una volta in test_riga_tileset_per_palette.
const RIGA_NEUTRA := 0


func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")
func _ws() -> Node: return _root().get_node("WorldState")
func _et() -> Node: return _root().get_node("EventTracker")


func prepara() -> void:
	_ws().call("pulisci")
	_et().call("azzera")


## world_offset dichiarato in data/world/regions.json (US-1001) per una
## regione - mai un numero scritto a mano qui, sempre letto dai dati.
func _offset(region_id: String) -> Vector2i:
	var reg: Dictionary = _gd().call("get_region", region_id)
	var wo: Array = reg.get("world_offset", [0, 0])
	return Vector2i(int(wo[0]), int(wo[1])) if wo.size() == 2 else Vector2i.ZERO


## Istanzia il mondo continuo con un Player fittizio come fratello, cosi'
## world_scene.gd si comporta come in main.tscn (Player e mondo sono
## fratelli). Ritorna anche l'offset della regione richiesta, per gli
## assert di cella/posizione dei test che seguono.
func _istanzia_con_player(region_id: String) -> Dictionary:
	var cont := Node2D.new()
	_root().add_child(cont)
	var player := Node2D.new()
	player.name = "Player"
	player.add_to_group("player")
	cont.add_child(player)
	var scena: Node = load("res://scenes/world_scene.tscn").instantiate()
	cont.add_child(scena)
	return {"cont": cont, "player": player, "scena": scena, "offset": _offset(region_id)}


func test_get_layout_presente_e_assente() -> void:
	assert_false(_gd().call("get_layout", "mirwada").is_empty(), "mirwada ha un layout")
	assert_false(_gd().call("get_layout", "marche_crepuscolo").is_empty(), "marche_crepuscolo ha un layout")
	assert_false(_gd().call("get_layout", "valle_madre").is_empty(), "valle_madre ha un layout")
	assert_false(_gd().call("get_layout", "archivio_sepolto").is_empty(), "archivio_sepolto ha un layout")
	assert_false(_gd().call("get_layout", "frontiera_porte").is_empty(), "frontiera_porte ha un layout")
	assert_true(_gd().call("get_layout", "nonesiste").is_empty(), "id ignoto -> {}")


func test_mirwada_dipinta_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("mirwada")
	var scena: TileMapLayer = r["scena"]
	var o: Vector2i = r["offset"]

	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(0, 0)), Vector2i(COL_MURO, RIGA_NEUTRA), "bordo esterno solido")
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(1, 1)), Vector2i(COL_PAVIMENTO, RIGA_NEUTRA), "cella '.' interna non solida")
	# specchio d'acqua del porto (US-1005: zone['porto'] = [45, 28, 15, 11], la
	# banchina d'acqua ne occupa le ultime 4 righe - (50, 36) ci ricade dentro).
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(50, 36)), Vector2i(COL_ACQUA, RIGA_NEUTRA),
		"cella '~' (acqua) usa la colonna acqua ed e' solida (US-813)")

	(r["cont"] as Node2D).free()


func test_mirwada_spawn_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("mirwada")
	var scena: TileMapLayer = r["scena"]
	var o: Vector2i = r["offset"]

	var atteso: Vector2 = scena.to_global(scena.map_to_local(o + Vector2i(4, 4)))
	assert_eq(scena.call("punto_spawn", "mirwada"),
		atteso, "punto_spawn('mirwada') usa la cella spawn del layout, offset incluso")

	(r["cont"] as Node2D).free()


func test_mirwada_zona_dal_rettangolo_del_layout() -> void:
	var r: Dictionary = _istanzia_con_player("mirwada")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var zona: Node2D = scena.get_node_or_null("Zona_mirwada_porto")
	assert_false(zona == null, "Zona_mirwada_porto esiste")
	# rettangolo letto dai dati (data/world/layouts/mirwada.json.zone.porto),
	# mai scritto a mano qui: US-1005 lo ha spostato ridisegnando la mappa.
	var rect: Array = (_gd().call("get_layout", "mirwada").get("zone", {}) as Dictionary).get("porto", [])
	assert_eq(rect.size(), 4, "zone.porto e' un rettangolo [x, y, w, h]")
	var origine: Vector2 = scena.map_to_local(o)
	var min_atteso: Vector2 = origine + Vector2(rect[0], rect[1]) * TILE
	var max_atteso: Vector2 = origine + Vector2(rect[0] + rect[2], rect[1] + rect[3]) * TILE
	assert_true(zona.position.x >= min_atteso.x and zona.position.x <= max_atteso.x,
		"Zona_mirwada_porto.x dentro il rettangolo dichiarato (offset incluso)")
	assert_true(zona.position.y >= min_atteso.y and zona.position.y <= max_atteso.y,
		"Zona_mirwada_porto.y dentro il rettangolo dichiarato (offset incluso)")

	(r["cont"] as Node2D).free()


## US-807d: chiusura del Blocco B — tutte e 5 le regioni hanno un layout
## disegnato a mano (nessuna resta piu' sul fallback piatto). Sostituisce
## il vecchio test "regione senza layout resta invariata": non esiste piu'
## una regione simile fra le 5 attive per dimostrarlo.
func test_tutte_le_regioni_hanno_un_layout() -> void:
	for r in _gd().call("get_regions"):
		var rid: String = str((r as Dictionary).get("id", ""))
		assert_false(_gd().call("get_layout", rid).is_empty(),
			"la regione '%s' ha un layout disegnato a mano" % rid)


## Dimensione VERA di un layout (righe x colonne della sua mappa, US-1005:
## dimensione libera - non piu' 48x36 fisso per ogni regione). Stesso calcolo
## di world_scene.gd::_dimensioni_layout, letto dai dati qui nel test.
func _dim(region_id: String) -> Vector2i:
	var mappa: Array = (_gd().call("get_layout", region_id).get("mappa", []) as Array)
	if mappa.is_empty():
		return Vector2i(48, 36)
	return Vector2i(str(mappa[0]).length(), mappa.size())


## Trova i nemici/pickup spawnati DENTRO il rettangolo di una regione (non
## l'intero mondo continuo: world_scene.gd ospita le 5 regioni nello stesso
## nodo, world_offset le separa nello spazio - US-1002B).
func _nemici_di(scena: Node, offset: Vector2i, region_id: String) -> Array:
	var rett := Rect2(scena.map_to_local(offset), Vector2(_dim(region_id)) * TILE)
	var out: Array = []
	for c in scena.get_children():
		if c.is_in_group("nemici") and rett.has_point(c.global_position):
			out.append(c)
	return out


func _pickup_di(scena: Node, offset: Vector2i, region_id: String) -> Array:
	var rett := Rect2(scena.map_to_local(offset), Vector2(_dim(region_id)) * TILE)
	var out: Array = []
	for c in scena.get_children():
		if c.get_script() == preload("res://scripts/item_pickup.gd") and rett.has_point(c.global_position):
			out.append(c)
	return out


func test_mirwada_nemici_dal_layout_sequenza_e_boss() -> void:
	var r: Dictionary = _istanzia_con_player("mirwada")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var nemici: Array = _nemici_di(scena, o, "mirwada")
	assert_eq(nemici.size(), 7, "6 nemici di Sequenza 9 + 1 boss dal layout")

	var boss = null
	var normale = null
	for e in nemici:
		if float(e.scale.x) > 1.0:
			boss = e
		elif normale == null:
			normale = e
	assert_false(boss == null, "il boss (scala 1.5) esiste fra i nemici spawnati")
	assert_almost_eq(float(boss.scale.x), 1.5, "scala del boss")
	assert_eq(int(boss.sequenza), 8, "il boss e' di Sequenza 8, non il default 9")
	assert_eq(int(normale.sequenza), 9, "un nemico senza override resta di Sequenza 9")

	var hp_atteso_boss: float = float(_gd().call("curve_value", "hp_curve", 8, 0.0))
	var hp_boss: float = float(boss.get_node("StatsComponent").call("get_stat", "hp_max"))
	assert_almost_eq(hp_boss, hp_atteso_boss, "StatsComponent.configure_from_balance(8) applicata al boss")

	var cfg_boss: Dictionary = boss.get("_cfg")
	assert_almost_eq(float(cfg_boss.get("danno_attacco", -1.0)), 15.0, "override.danno_attacco mergiato in _cfg")
	assert_eq(str(cfg_boss.get("tag", "")), "bestia", "override.tag mergiato in _cfg")

	(r["cont"] as Node2D).free()


func test_mirwada_oggetti_a_terra_raccolti_finiscono_in_inventory() -> void:
	var r: Dictionary = _istanzia_con_player("mirwada")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var pickup_list: Array = _pickup_di(scena, o, "mirwada")
	# 10 originali + 3 ingredienti di formula_darkness_9 + 3 di
	# formula_paragon_9 (006_PRD/prd-vslice-livello-b-batch-2.md).
	assert_eq(pickup_list.size(), 16, "16 oggetti a terra dal layout")

	var inv: Node = _root().get_node("Inventory")
	var uno = pickup_list[0]
	var item_id: String = str(uno.char_id)
	var prima: int = int(inv.call("conta", item_id))
	var q: int = int(uno.quantita)
	assert_true(bool(uno.call("raccogli")), "raccogli() riesce la prima volta")
	assert_eq(int(inv.call("conta", item_id)), prima + q, "Inventory.conta cresce della quantita' del dato")
	assert_false(bool(uno.call("raccogli")), "raccogli() e' idempotente (gia' raccolto)")

	(r["cont"] as Node2D).free()


func test_mirwada_area_cleared_alla_morte_dell_ultimo_nemico() -> void:
	var r: Dictionary = _istanzia_con_player("mirwada")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var nemici: Array = _nemici_di(scena, o, "mirwada")
	assert_eq(nemici.size(), 7, "setup: 7 nemici")
	for i in nemici.size() - 1:
		nemici[i].get_node("StatsComponent").set("hp", 0.0)
	assert_almost_eq(_et().call("count", "area_cleared", {}), 0.0,
		"nessun area_cleared finche' resta almeno un nemico vivo")

	nemici[nemici.size() - 1].get_node("StatsComponent").set("hp", 0.0)
	assert_almost_eq(_et().call("count", "area_cleared",
		{"senza_alleati_caduti": true, "senza_uccidere": false}), 1.0,
		"area_cleared emesso una volta sola, coi filtri del contratto US-804")

	(r["cont"] as Node2D).free()


## US-806: nemici spawnati SENZA un Player in scena (test headless) devono
## restare inerti, non esplodere. enemy.gd tollera gia' _bersaglio nullo
## (dist=INF): qui lo si dimostra per i nemici veri di Mirwada.
func test_nemici_di_mirwada_senza_player_restano_inerti() -> void:
	var cont := Node2D.new()
	_root().add_child(cont)
	var scena: Node = load("res://scenes/world_scene.tscn").instantiate()
	cont.add_child(scena)

	var nemici: Array = _nemici_di(scena, _offset("mirwada"), "mirwada")
	assert_eq(nemici.size(), 7, "i nemici si spawnano comunque senza Player")
	for e in nemici:
		e.call("_physics_process", 0.016)
		assert_eq(str(e.call("stato")), "IDLE", "nessun bersaglio -> resta IDLE, nessun crash")

	cont.free()


## --- US-807a: Marche del Crepuscolo (seconda regione con layout) ---


func test_marche_dipinta_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("marche_crepuscolo")
	var scena: TileMapLayer = r["scena"]
	var o: Vector2i = r["offset"]

	var riga: int = scena.get_cell_atlas_coords(o + Vector2i(1, 1)).y
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(0, 0)), Vector2i(COL_MURO, riga), "bordo esterno solido")
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(1, 1)), Vector2i(COL_PAVIMENTO, riga), "cella '.' di brughiera non solida")
	# muro della cripta (US-1006: data/world/layouts/marche_crepuscolo.json,
	# l'edificio murato dentro la zona 'cripta' [30, 24, 13, 20])
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(33, 30)), Vector2i(COL_MURO, riga), "muro della cripta solido")
	# la porta della cripta e' calpestabile (colonna '+' del tileset)
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(36, 38)), Vector2i(COL_PORTA, riga), "la porta della cripta e' calpestabile")

	(r["cont"] as Node2D).free()


func test_marche_spawn_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("marche_crepuscolo")
	var scena: Node = r["scena"]
	var player: Node2D = r["player"]
	var o: Vector2i = r["offset"]

	var atteso_spawn: Vector2 = scena.to_global(scena.map_to_local(o + Vector2i(4, 4)))
	assert_eq(scena.call("punto_spawn", "marche_crepuscolo"), atteso_spawn,
		"punto_spawn('marche_crepuscolo') usa la cella spawn del layout, offset incluso")
	assert_true(player != null, "il player fittizio esiste (contratto della scena)")

	(r["cont"] as Node2D).free()


func test_marche_nemici_dal_layout_sequenza_e_boss() -> void:
	var r: Dictionary = _istanzia_con_player("marche_crepuscolo")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var nemici: Array = _nemici_di(scena, o, "marche_crepuscolo")
	assert_eq(nemici.size(), 7, "6 nemici di Sequenza 9/8 + 1 boss dal layout")

	var boss = null
	for e in nemici:
		if float(e.scale.x) > 1.0:
			boss = e
	assert_false(boss == null, "il boss (scala 1.5) esiste fra i nemici spawnati")
	assert_almost_eq(float(boss.scale.x), 1.5, "scala del boss")
	assert_eq(int(boss.sequenza), 7, "il boss di Marche e' di Sequenza 7")

	var hp_atteso_boss: float = float(_gd().call("curve_value", "hp_curve", 7, 0.0))
	var hp_boss: float = float(boss.get_node("StatsComponent").call("get_stat", "hp_max"))
	assert_almost_eq(hp_boss, hp_atteso_boss, "StatsComponent.configure_from_balance(7) applicata al boss")

	var cfg_boss: Dictionary = boss.get("_cfg")
	assert_almost_eq(float(cfg_boss.get("danno_attacco", -1.0)), 15.0, "override.danno_attacco mergiato in _cfg")
	assert_eq(str(cfg_boss.get("tag", "")), "non_morto", "override.tag mergiato in _cfg")
	var car: Dictionary = cfg_boss.get("caratteristica", {})
	assert_eq(str(car.get("pathway_id", "")), "twilight_giant", "Caratteristica del gruppo garantita al boss")

	(r["cont"] as Node2D).free()


func test_marche_oggetti_a_terra_raccolti_finiscono_in_inventory() -> void:
	var r: Dictionary = _istanzia_con_player("marche_crepuscolo")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var pickup_list: Array = _pickup_di(scena, o, "marche_crepuscolo")
	# 8 originali + 3 ingredienti di formula_death_9
	# (006_PRD/prd-vslice-livello-b-batch-2.md).
	assert_eq(pickup_list.size(), 11, "11 oggetti a terra dal layout")

	var inv: Node = _root().get_node("Inventory")
	var uno = pickup_list[0]
	var item_id: String = str(uno.char_id)
	var prima: int = int(inv.call("conta", item_id))
	var q: int = int(uno.quantita)
	assert_true(bool(uno.call("raccogli")), "raccogli() riesce la prima volta")
	assert_eq(int(inv.call("conta", item_id)), prima + q, "Inventory.conta cresce della quantita' del dato")

	(r["cont"] as Node2D).free()


func test_marche_area_cleared_alla_morte_dell_ultimo_nemico() -> void:
	var r: Dictionary = _istanzia_con_player("marche_crepuscolo")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var nemici: Array = _nemici_di(scena, o, "marche_crepuscolo")
	assert_eq(nemici.size(), 7, "setup: 7 nemici")
	for e in nemici:
		e.get_node("StatsComponent").set("hp", 0.0)
	assert_almost_eq(_et().call("count", "area_cleared",
		{"senza_alleati_caduti": true, "senza_uccidere": false}), 1.0,
		"area_cleared emesso una volta sola alla morte dell'ultimo nemico")

	(r["cont"] as Node2D).free()


func test_nemici_di_marche_senza_player_restano_inerti() -> void:
	var cont := Node2D.new()
	_root().add_child(cont)
	var scena: Node = load("res://scenes/world_scene.tscn").instantiate()
	cont.add_child(scena)

	var nemici: Array = _nemici_di(scena, _offset("marche_crepuscolo"), "marche_crepuscolo")
	assert_eq(nemici.size(), 7, "i nemici si spawnano comunque senza Player")
	for e in nemici:
		e.call("_physics_process", 0.016)
		assert_eq(str(e.call("stato")), "IDLE", "nessun bersaglio -> resta IDLE, nessun crash")

	cont.free()


## --- US-807b: Valle Madre (quarta regione con layout) ---


func test_valle_dipinta_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("valle_madre")
	var scena: TileMapLayer = r["scena"]
	var o: Vector2i = r["offset"]

	var riga: int = scena.get_cell_atlas_coords(o + Vector2i(1, 1)).y
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(0, 0)), Vector2i(COL_MURO, riga), "bordo esterno solido")
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(1, 1)), Vector2i(COL_PAVIMENTO, riga), "cella '.' del bosco non solida")
	# US-1007: acqua '~' nella zona grotta_di_marea (data/world/layouts/
	# valle_madre.json.zone.grotta_di_marea, [44,2,19,21])
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(50, 7)), Vector2i(COL_ACQUA, riga),
		"cella '~' della grotta di marea usa la colonna acqua ed e' solida (US-813)")
	# i sentieri di radici '=' dell'altare_di_radici ([23,26,19,21]) restano calpestabili
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(32, 28)), Vector2i(COL_SENTIERO, riga),
		"i sentieri di radici ('=') dell'altare sono calpestabili")

	(r["cont"] as Node2D).free()


func test_valle_spawn_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("valle_madre")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var atteso_spawn: Vector2 = scena.to_global(scena.map_to_local(o + Vector2i(4, 4)))
	assert_eq(scena.call("punto_spawn", "valle_madre"), atteso_spawn,
		"punto_spawn('valle_madre') usa la cella spawn del layout, offset incluso")

	(r["cont"] as Node2D).free()


func test_valle_nemici_dal_layout_sequenza_e_boss() -> void:
	var r: Dictionary = _istanzia_con_player("valle_madre")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var nemici: Array = _nemici_di(scena, o, "valle_madre")
	assert_eq(nemici.size(), 7, "6 nemici di Sequenza 9/8 + 1 boss dal layout")

	var boss = null
	for e in nemici:
		if float(e.scale.x) > 1.0:
			boss = e
	assert_false(boss == null, "il boss (scala 1.5) esiste fra i nemici spawnati")
	assert_almost_eq(float(boss.scale.x), 1.5, "scala del boss")
	assert_eq(int(boss.sequenza), 7, "il boss della Valle e' di Sequenza 7")

	var hp_atteso_boss: float = float(_gd().call("curve_value", "hp_curve", 7, 0.0))
	var hp_boss: float = float(boss.get_node("StatsComponent").call("get_stat", "hp_max"))
	assert_almost_eq(hp_boss, hp_atteso_boss, "StatsComponent.configure_from_balance(7) applicata al boss")

	var cfg_boss: Dictionary = boss.get("_cfg")
	assert_almost_eq(float(cfg_boss.get("danno_attacco", -1.0)), 15.0, "override.danno_attacco mergiato in _cfg")
	assert_eq(str(cfg_boss.get("tag", "")), "bestia", "override.tag mergiato in _cfg")
	var car: Dictionary = cfg_boss.get("caratteristica", {})
	assert_eq(str(car.get("pathway_id", "")), "mother", "Caratteristica del gruppo garantita al boss")

	(r["cont"] as Node2D).free()


func test_valle_oggetti_a_terra_raccolti_finiscono_in_inventory() -> void:
	var r: Dictionary = _istanzia_con_player("valle_madre")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var pickup_list: Array = _pickup_di(scena, o, "valle_madre")
	# 7 originali + 3 ingredienti di formula_moon_9
	# (006_PRD/prd-vslice-livello-b-batch-2.md).
	assert_eq(pickup_list.size(), 10, "10 oggetti a terra dal layout")

	var inv: Node = _root().get_node("Inventory")
	var uno = pickup_list[0]
	var item_id: String = str(uno.char_id)
	var prima: int = int(inv.call("conta", item_id))
	var q: int = int(uno.quantita)
	assert_true(bool(uno.call("raccogli")), "raccogli() riesce la prima volta")
	assert_eq(int(inv.call("conta", item_id)), prima + q, "Inventory.conta cresce della quantita' del dato")

	(r["cont"] as Node2D).free()


func test_valle_area_cleared_alla_morte_dell_ultimo_nemico() -> void:
	var r: Dictionary = _istanzia_con_player("valle_madre")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var nemici: Array = _nemici_di(scena, o, "valle_madre")
	assert_eq(nemici.size(), 7, "setup: 7 nemici")
	for e in nemici:
		e.get_node("StatsComponent").set("hp", 0.0)
	assert_almost_eq(_et().call("count", "area_cleared",
		{"senza_alleati_caduti": true, "senza_uccidere": false}), 1.0,
		"area_cleared emesso una volta sola alla morte dell'ultimo nemico")

	(r["cont"] as Node2D).free()


func test_nemici_di_valle_senza_player_restano_inerti() -> void:
	var cont := Node2D.new()
	_root().add_child(cont)
	var scena: Node = load("res://scenes/world_scene.tscn").instantiate()
	cont.add_child(scena)

	var nemici: Array = _nemici_di(scena, _offset("valle_madre"), "valle_madre")
	assert_eq(nemici.size(), 7, "i nemici si spawnano comunque senza Player")
	for e in nemici:
		e.call("_physics_process", 0.016)
		assert_eq(str(e.call("stato")), "IDLE", "nessun bersaglio -> resta IDLE, nessun crash")

	cont.free()


## --- US-807c: Archivio Sepolto (quinta regione con layout) ---


func test_archivio_dipinta_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("archivio_sepolto")
	var scena: TileMapLayer = r["scena"]
	var o: Vector2i = r["offset"]

	var riga: int = scena.get_cell_atlas_coords(o + Vector2i(36, 4)).y
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(0, 0)), Vector2i(COL_MURO, riga), "bordo esterno solido")
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(36, 4)), Vector2i(COL_PAVIMENTO, riga), "spawn sulla spina centrale, calpestabile")
	# data/world/layouts/archivio_sepolto.json: muro del santuario biblioteca_di_tutto
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(41, 36)), Vector2i(COL_MURO, riga), "muro interno di una sala solido")
	# porta del santuario biblioteca_di_tutto (sito rituale di Sequenza 0 di Hermit/Paragon)
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(55, 35)), Vector2i(COL_PORTA, riga), "la porta del santuario e' una porta")
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(54, 35)), Vector2i(COL_PAVIMENTO, riga), "il corridoio davanti alla porta e' calpestabile")

	(r["cont"] as Node2D).free()


func test_archivio_spawn_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("archivio_sepolto")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var atteso_spawn: Vector2 = scena.to_global(scena.map_to_local(o + Vector2i(36, 4)))
	assert_eq(scena.call("punto_spawn", "archivio_sepolto"), atteso_spawn,
		"punto_spawn('archivio_sepolto') usa la cella spawn del layout, offset incluso")

	(r["cont"] as Node2D).free()


func test_archivio_nemici_dal_layout_sequenza_e_boss() -> void:
	var r: Dictionary = _istanzia_con_player("archivio_sepolto")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var nemici: Array = _nemici_di(scena, o, "archivio_sepolto")
	assert_eq(nemici.size(), 7, "6 nemici di Sequenza 8/7 + 1 boss dal layout")

	var boss = null
	for e in nemici:
		if float(e.scale.x) > 1.0:
			boss = e
	assert_false(boss == null, "il boss (scala 1.5) esiste fra i nemici spawnati")
	assert_almost_eq(float(boss.scale.x), 1.5, "scala del boss")
	assert_eq(int(boss.sequenza), 6, "il boss dell'Archivio e' di Sequenza 6")

	var hp_atteso_boss: float = float(_gd().call("curve_value", "hp_curve", 6, 0.0))
	var hp_boss: float = float(boss.get_node("StatsComponent").call("get_stat", "hp_max"))
	assert_almost_eq(hp_boss, hp_atteso_boss, "StatsComponent.configure_from_balance(6) applicata al boss")

	var cfg_boss: Dictionary = boss.get("_cfg")
	assert_almost_eq(float(cfg_boss.get("danno_attacco", -1.0)), 15.0, "override.danno_attacco mergiato in _cfg")
	assert_eq(str(cfg_boss.get("tag", "")), "spirito", "override.tag mergiato in _cfg")
	var car: Dictionary = cfg_boss.get("caratteristica", {})
	assert_eq(str(car.get("pathway_id", "")), "hermit", "Caratteristica del gruppo garantita al boss")

	(r["cont"] as Node2D).free()


func test_archivio_oggetti_a_terra_raccolti_finiscono_in_inventory() -> void:
	var r: Dictionary = _istanzia_con_player("archivio_sepolto")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var pickup_list: Array = _pickup_di(scena, o, "archivio_sepolto")
	# 6 originali (US-805/US-809c) + 3 ingredienti di formula_error_9
	# (006_PRD/prd-vslice-livello-b-batch-1.md, VS-B1-03: non esistevano in
	# nessun layout prima, servono al Livello B reale del Pathway Error).
	assert_eq(pickup_list.size(), 9, "9 oggetti a terra dal layout")

	var inv: Node = _root().get_node("Inventory")
	var uno = pickup_list[0]
	var item_id: String = str(uno.char_id)
	var prima: int = int(inv.call("conta", item_id))
	var q: int = int(uno.quantita)
	assert_true(bool(uno.call("raccogli")), "raccogli() riesce la prima volta")
	assert_eq(int(inv.call("conta", item_id)), prima + q, "Inventory.conta cresce della quantita' del dato")

	(r["cont"] as Node2D).free()


func test_archivio_area_cleared_alla_morte_dell_ultimo_nemico() -> void:
	var r: Dictionary = _istanzia_con_player("archivio_sepolto")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var nemici: Array = _nemici_di(scena, o, "archivio_sepolto")
	assert_eq(nemici.size(), 7, "setup: 7 nemici")
	for e in nemici:
		e.get_node("StatsComponent").set("hp", 0.0)
	assert_almost_eq(_et().call("count", "area_cleared",
		{"senza_alleati_caduti": true, "senza_uccidere": false}), 1.0,
		"area_cleared emesso una volta sola alla morte dell'ultimo nemico")

	(r["cont"] as Node2D).free()


func test_nemici_di_archivio_senza_player_restano_inerti() -> void:
	var cont := Node2D.new()
	_root().add_child(cont)
	var scena: Node = load("res://scenes/world_scene.tscn").instantiate()
	cont.add_child(scena)

	var nemici: Array = _nemici_di(scena, _offset("archivio_sepolto"), "archivio_sepolto")
	assert_eq(nemici.size(), 7, "i nemici si spawnano comunque senza Player")
	for e in nemici:
		e.call("_physics_process", 0.016)
		assert_eq(str(e.call("stato")), "IDLE", "nessun bersaglio -> resta IDLE, nessun crash")

	cont.free()


## --- US-807d: Frontiera delle Porte (sesta e ultima regione con layout) ---


## US-1009 (Frontiera delle Porte cresce): layout ridisegnato piu' grande
## (72x44 -> 72x48) con le 6 location_tags come zone fisicamente distinte
## (soglia santuario murato, teatro/palco strutture gemelle, nebbia_grigia
## isole scollegate da ponti, crocevia aperta, porta_senza_stanza una
## soglia isolata senza stanza). Spawn spostato nel santuario di soglia.
func test_frontiera_dipinta_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("frontiera_porte")
	var scena: TileMapLayer = r["scena"]
	var o: Vector2i = r["offset"]

	var riga: int = scena.get_cell_atlas_coords(o + Vector2i(11, 15)).y
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(0, 0)), Vector2i(COL_MURO, riga), "bordo esterno solido")
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(5, 26)), Vector2i(COL_ACQUA, riga),
		"cella '~' (nebbia) fuori da un'isola usa la colonna acqua ed e' solida (US-813)")
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(11, 15)), Vector2i(COL_PAVIMENTO, riga), "spawn davanti al santuario di soglia, calpestabile")
	# ponte '=' che collega le isole della nebbia grigia
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(12, 32)), Vector2i(COL_SENTIERO, riga), "il ponte ('=') fra isole e' calpestabile")

	(r["cont"] as Node2D).free()


func test_frontiera_spawn_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("frontiera_porte")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var atteso_spawn: Vector2 = scena.to_global(scena.map_to_local(o + Vector2i(11, 15)))
	assert_eq(scena.call("punto_spawn", "frontiera_porte"), atteso_spawn,
		"punto_spawn('frontiera_porte') usa la cella spawn del layout, offset incluso")

	(r["cont"] as Node2D).free()


func test_frontiera_nemici_dal_layout_sequenza_e_boss() -> void:
	var r: Dictionary = _istanzia_con_player("frontiera_porte")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var nemici: Array = _nemici_di(scena, o, "frontiera_porte")
	assert_eq(nemici.size(), 7, "6 nemici di Sequenza 7/6 + 1 boss dal layout")

	var boss = null
	for e in nemici:
		if float(e.scale.x) > 1.0:
			boss = e
	assert_false(boss == null, "il boss (scala 1.5) esiste fra i nemici spawnati")
	assert_almost_eq(float(boss.scale.x), 1.5, "scala del boss")
	assert_eq(int(boss.sequenza), 5, "il boss della Frontiera e' di Sequenza 5")

	var hp_atteso_boss: float = float(_gd().call("curve_value", "hp_curve", 5, 0.0))
	var hp_boss: float = float(boss.get_node("StatsComponent").call("get_stat", "hp_max"))
	assert_almost_eq(hp_boss, hp_atteso_boss, "StatsComponent.configure_from_balance(5) applicata al boss")

	var cfg_boss: Dictionary = boss.get("_cfg")
	assert_almost_eq(float(cfg_boss.get("danno_attacco", -1.0)), 15.0, "override.danno_attacco mergiato in _cfg")
	assert_eq(str(cfg_boss.get("tag", "")), "ombra", "override.tag mergiato in _cfg")
	var car: Dictionary = cfg_boss.get("caratteristica", {})
	assert_eq(str(car.get("pathway_id", "")), "fool", "Caratteristica del gruppo garantita al boss")

	(r["cont"] as Node2D).free()


func test_frontiera_oggetti_a_terra_raccolti_finiscono_in_inventory() -> void:
	var r: Dictionary = _istanzia_con_player("frontiera_porte")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var pickup_list: Array = _pickup_di(scena, o, "frontiera_porte")
	# 6 originali (US-805/US-809c) + 3 ingredienti di formula_door_9
	# (006_PRD/prd-vslice-livello-b-batch-1.md, VS-B1-02: non esistevano in
	# nessun layout prima, servono al Livello B reale del Pathway Door).
	assert_eq(pickup_list.size(), 9, "9 oggetti a terra dal layout")

	var inv: Node = _root().get_node("Inventory")
	var uno = pickup_list[0]
	var item_id: String = str(uno.char_id)
	var prima: int = int(inv.call("conta", item_id))
	var q: int = int(uno.quantita)
	assert_true(bool(uno.call("raccogli")), "raccogli() riesce la prima volta")
	assert_eq(int(inv.call("conta", item_id)), prima + q, "Inventory.conta cresce della quantita' del dato")

	(r["cont"] as Node2D).free()


func test_frontiera_area_cleared_alla_morte_dell_ultimo_nemico() -> void:
	var r: Dictionary = _istanzia_con_player("frontiera_porte")
	var scena: Node = r["scena"]
	var o: Vector2i = r["offset"]

	var nemici: Array = _nemici_di(scena, o, "frontiera_porte")
	assert_eq(nemici.size(), 7, "setup: 7 nemici")
	for e in nemici:
		e.get_node("StatsComponent").set("hp", 0.0)
	assert_almost_eq(_et().call("count", "area_cleared",
		{"senza_alleati_caduti": true, "senza_uccidere": false}), 1.0,
		"area_cleared emesso una volta sola alla morte dell'ultimo nemico")

	(r["cont"] as Node2D).free()


func test_nemici_di_frontiera_senza_player_restano_inerti() -> void:
	var cont := Node2D.new()
	_root().add_child(cont)
	var scena: Node = load("res://scenes/world_scene.tscn").instantiate()
	cont.add_child(scena)

	var nemici: Array = _nemici_di(scena, _offset("frontiera_porte"), "frontiera_porte")
	assert_eq(nemici.size(), 7, "i nemici si spawnano comunque senza Player")
	for e in nemici:
		e.call("_physics_process", 0.016)
		assert_eq(str(e.call("stato")), "IDLE", "nessun bersaglio -> resta IDLE, nessun crash")

	cont.free()


## --- US-813: tileset a righe-per-palette, NPC con sprite + nome ---


## Verifica diretta (non auto-consistente come i test sopra) che la riga
## scelta da world_scene.gd::_riga_tileset() sia proprio 1 + l'indice della
## palette_visiva della regione in vfx.json.pathway_palette_visiva, non solo
## una riga qualunque diversa da 0.
func test_riga_tileset_per_palette_non_neutra() -> void:
	var pal_id: String = str(_gd().call("get_region", "marche_crepuscolo").get("palette_visiva", ""))
	var attesa: int = 1 + (_gd().call("vfx_palette_ids") as Array).find(pal_id)
	assert_true(attesa > 0, "marche_crepuscolo ha una palette_visiva non neutra")

	var r: Dictionary = _istanzia_con_player("marche_crepuscolo")
	var scena: TileMapLayer = r["scena"]
	var o: Vector2i = r["offset"]
	assert_eq(scena.get_cell_atlas_coords(o + Vector2i(1, 1)).y, attesa,
		"la riga del tileset e' 1 + l'indice della palette della regione")

	(r["cont"] as Node2D).free()


## Un NPC presente in scena e' uno Sprite2D (da npc_popolano.png) con sopra
## una Label che mostra il nome tradotto (US-813), non piu' un ColorRect
## anonimo.
func test_npc_ha_sprite_e_nome_tradotto() -> void:
	var r: Dictionary = _istanzia_con_player("mirwada")
	var scena: Node = r["scena"]

	var npc: Node = scena.get_node_or_null("Npc_npc_mirco")
	assert_false(npc == null, "npc_mirco e' presente in piazza all'alba")

	var sprite: Sprite2D = null
	for c in npc.get_children():
		if c is Sprite2D:
			sprite = c
	var label: Label = npc.get_node_or_null("Nome")
	assert_false(sprite == null, "l'NPC ha uno Sprite2D")
	assert_true(sprite.texture != null and sprite.texture.resource_path.ends_with("npc_popolano.png"),
		"lo sprite usa npc_popolano.png")

	assert_false(label == null, "l'NPC ha una Label 'Nome' col nome")
	var atteso: String = str(_gd().call("tr_data", _gd().call("get_npc", "npc_mirco").get("name_i18n", "")))
	assert_eq(label.text, atteso, "il testo della Label e' il nome tradotto (GameData.tr_data)")

	(r["cont"] as Node2D).free()


## Onboarding: un NPC con dialogo mostra il prompt "[F] Parla" solo mentre il
## giocatore e' nel suo raggio.
func test_npc_prompt_interazione_appare_e_sparisce_col_player() -> void:
	var r: Dictionary = _istanzia_con_player("mirwada")
	var scena: Node = r["scena"]
	var player: Node = r["player"]

	var npc: Node = scena.get_node_or_null("Npc_npc_mirco")
	assert_false(npc == null, "npc_mirco e' in piazza all'alba")
	var prompt: Label = npc.get_node_or_null("Prompt")
	assert_false(prompt == null, "npc_mirco ha un dialogo -> ha un prompt")
	assert_false(prompt.visible, "il prompt e' nascosto finche' non ci si avvicina")

	scena.call("_npc_avvicinato", player, "npc_mirco")
	assert_true(prompt.visible, "avvicinandosi il prompt compare")
	var atteso: String = scena.tr("HUD_PROMPT_INTERAGISCI").format(
		{"tasto": scena.call("_tasto_interagisci")})
	assert_eq(prompt.text, atteso, "il prompt nomina il tasto legato a 'interagisci'")

	scena.call("_npc_allontanato", player, "npc_mirco")
	assert_false(prompt.visible, "allontanandosi il prompt sparisce")

	# col libro aperto sopra, il prompt non deve restare a schermo
	var book: Node = _root().get_node("Book")
	book.call("azzera")
	scena.call("_npc_avvicinato", player, "npc_mirco")
	assert_true(prompt.visible, "prompt visibile prima di aprire il libro")
	book.call("apri")
	assert_true(bool(book.call("e_aperto")), "il libro si e' aperto")
	assert_false(prompt.visible, "il prompt sparisce quando si apre il libro")
	book.call("chiudi")
	assert_true(prompt.visible, "il prompt torna quando il libro si chiude (ancora vicino)")
	book.call("azzera")

	(r["cont"] as Node2D).free()
