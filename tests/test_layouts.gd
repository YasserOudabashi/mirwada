extends "res://tests/test_case.gd"
## US-805 — formato dei layout disegnati a mano: loader, dipintura fisica,
## zone/passaggi da dati, fallback invariato per le regioni senza layout.
## US-806 — nemici/boss/oggetti a terra dichiarati nel layout.nemici/oggetti.

const TILE := 32  # region_scene.gd::TILE
const PAVIMENTO := Vector2i(0, 0)  # region_scene.gd::PAVIMENTO
const MURO := Vector2i(1, 0)       # region_scene.gd::MURO


func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")
func _ws() -> Node: return _root().get_node("WorldState")
func _et() -> Node: return _root().get_node("EventTracker")


func prepara() -> void:
	_ws().call("pulisci")
	_et().call("azzera")


## Istanzia una regione con un Player fittizio come fratello, cosi'
## _colloca_giocatore() (region_scene.gd) lo posiziona davvero: stesso
## contratto di main.tscn (Player e regione sono fratelli).
func _istanzia_con_player(region_id: String) -> Dictionary:
	var cont := Node2D.new()
	_root().add_child(cont)
	var player := Node2D.new()
	player.name = "Player"
	player.add_to_group("player")
	cont.add_child(player)
	var scena: Node = load("res://scenes/regioni/%s.tscn" % region_id).instantiate()
	cont.add_child(scena)
	return {"cont": cont, "player": player, "scena": scena}


func test_get_layout_presente_e_assente() -> void:
	assert_false(_gd().call("get_layout", "mirwada").is_empty(), "mirwada ha un layout")
	assert_true(_gd().call("get_layout", "nonesiste").is_empty(), "id ignoto -> {}")
	assert_true(_gd().call("get_layout", "valle_madre").is_empty(),
		"regione senza layout (fino a US-807) -> {}")


func test_mirwada_dipinta_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("mirwada")
	var scena: TileMapLayer = r["scena"]

	assert_eq(scena.get_cell_atlas_coords(Vector2i(0, 0)), MURO, "bordo esterno solido")
	assert_eq(scena.get_cell_atlas_coords(Vector2i(1, 1)), PAVIMENTO, "cella '.' interna non solida")
	assert_eq(scena.get_cell_atlas_coords(Vector2i(44, 29)), MURO,
		"cella '~' (acqua) e' solida in questa story (US-813 le da' la resa vera)")

	(r["cont"] as Node2D).free()


func test_mirwada_spawn_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("mirwada")
	var scena: TileMapLayer = r["scena"]
	var player: Node2D = r["player"]

	var atteso: Vector2 = scena.to_global(scena.map_to_local(Vector2i(4, 4)))
	assert_eq(player.global_position, atteso, "il player compare sulla cella spawn del layout")

	(r["cont"] as Node2D).free()


func test_mirwada_zona_dal_rettangolo_del_layout() -> void:
	var r: Dictionary = _istanzia_con_player("mirwada")
	var scena: Node = r["scena"]

	var zona: Node2D = scena.get_node_or_null("Zona_porto")
	assert_false(zona == null, "Zona_porto esiste")
	# rettangolo dichiarato in data/world/layouts/mirwada.json: [36, 26, 10, 8]
	var min_atteso := Vector2(36, 26) * TILE
	var max_atteso := Vector2(36 + 10, 26 + 8) * TILE
	assert_true(zona.position.x >= min_atteso.x and zona.position.x <= max_atteso.x,
		"Zona_porto.x dentro il rettangolo dichiarato")
	assert_true(zona.position.y >= min_atteso.y and zona.position.y <= max_atteso.y,
		"Zona_porto.y dentro il rettangolo dichiarato")

	(r["cont"] as Node2D).free()


func test_mirwada_passaggio_dalla_cella_del_layout() -> void:
	var r: Dictionary = _istanzia_con_player("mirwada")
	var scena: Node = r["scena"]

	# data/world/layouts/mirwada.json: passaggi.marche_crepuscolo = [44, 5]
	var passaggio: Node2D = scena.get_node_or_null("Passaggio_marche_crepuscolo")
	assert_false(passaggio == null, "Passaggio_marche_crepuscolo esiste")
	var atteso := Vector2(44.5, 5.5) * TILE
	assert_almost_eq(passaggio.position.x, atteso.x, "passaggio.x dalla cella del layout")
	assert_almost_eq(passaggio.position.y, atteso.y, "passaggio.y dalla cella del layout")

	(r["cont"] as Node2D).free()


func test_regione_senza_layout_resta_invariata() -> void:
	var r: Dictionary = _istanzia_con_player("valle_madre")
	var scena: TileMapLayer = r["scena"]
	var player: Node2D = r["player"]

	assert_eq(scena.get_cell_atlas_coords(Vector2i(0, 0)), MURO, "bordo pieno (fallback piatto)")
	assert_eq(scena.get_cell_atlas_coords(Vector2i(1, 1)), PAVIMENTO, "interno calpestabile (fallback piatto)")
	var atteso: Vector2 = scena.to_global(scena.map_to_local(Vector2i(4, 4)))
	assert_eq(player.global_position, atteso, "spawn di default (4,4) invariato senza layout")

	(r["cont"] as Node2D).free()


## Trova i nemici/pickup spawnati DENTRO la scena regione (non l'intero
## gruppo globale: altre suite possono lasciarne in giro fra un test e
## l'altro se qualcosa fallisce a meta').
func _nemici_di(scena: Node) -> Array:
	var out: Array = []
	for c in scena.get_children():
		if c.is_in_group("nemici"):
			out.append(c)
	return out


func _pickup_di(scena: Node) -> Array:
	var out: Array = []
	for c in scena.get_children():
		if c.get_script() == preload("res://scripts/item_pickup.gd"):
			out.append(c)
	return out


func test_mirwada_nemici_dal_layout_sequenza_e_boss() -> void:
	var r: Dictionary = _istanzia_con_player("mirwada")
	var scena: Node = r["scena"]

	var nemici: Array = _nemici_di(scena)
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

	var pickup_list: Array = _pickup_di(scena)
	assert_eq(pickup_list.size(), 10, "10 oggetti a terra dal layout")

	var inv: Node = _root().get_node("Inventory")
	var prima: int = int(inv.call("conta", "moneta_comune"))
	var uno = pickup_list[0]
	var q: int = int(uno.quantita)
	assert_true(bool(uno.call("raccogli")), "raccogli() riesce la prima volta")
	assert_eq(int(inv.call("conta", "moneta_comune")), prima + q, "Inventory.conta cresce della quantita' del dato")
	assert_false(bool(uno.call("raccogli")), "raccogli() e' idempotente (gia' raccolto)")

	(r["cont"] as Node2D).free()


func test_mirwada_area_cleared_alla_morte_dell_ultimo_nemico() -> void:
	var r: Dictionary = _istanzia_con_player("mirwada")
	var scena: Node = r["scena"]

	var nemici: Array = _nemici_di(scena)
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
	var scena: Node = load("res://scenes/regioni/mirwada.tscn").instantiate()
	cont.add_child(scena)

	var nemici: Array = _nemici_di(scena)
	assert_eq(nemici.size(), 7, "i nemici si spawnano comunque senza Player")
	for e in nemici:
		e.call("_physics_process", 0.016)
		assert_eq(str(e.call("stato")), "IDLE", "nessun bersaglio -> resta IDLE, nessun crash")

	cont.free()
