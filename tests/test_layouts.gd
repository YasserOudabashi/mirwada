extends "res://tests/test_case.gd"
## US-805 — formato dei layout disegnati a mano: loader, dipintura fisica,
## zone/passaggi da dati, fallback invariato per le regioni senza layout.

const TILE := 32  # region_scene.gd::TILE
const PAVIMENTO := Vector2i(0, 0)  # region_scene.gd::PAVIMENTO
const MURO := Vector2i(1, 0)       # region_scene.gd::MURO


func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")
func _ws() -> Node: return _root().get_node("WorldState")


func prepara() -> void:
	_ws().call("pulisci")


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
