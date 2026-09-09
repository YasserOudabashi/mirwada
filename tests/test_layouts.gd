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
	assert_false(_gd().call("get_layout", "marche_crepuscolo").is_empty(), "marche_crepuscolo ha un layout")
	assert_false(_gd().call("get_layout", "valle_madre").is_empty(), "valle_madre ha un layout")
	assert_false(_gd().call("get_layout", "archivio_sepolto").is_empty(), "archivio_sepolto ha un layout")
	assert_false(_gd().call("get_layout", "frontiera_porte").is_empty(), "frontiera_porte ha un layout")
	assert_true(_gd().call("get_layout", "nonesiste").is_empty(), "id ignoto -> {}")


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


## US-807d: chiusura del Blocco B — tutte e 5 le regioni hanno un layout
## disegnato a mano (nessuna resta piu' sul fallback piatto). Sostituisce
## il vecchio test "regione senza layout resta invariata": non esiste piu'
## una regione simile fra le 5 attive per dimostrarlo.
func test_tutte_le_regioni_hanno_un_layout() -> void:
	for r in _gd().call("get_regions"):
		var rid: String = str((r as Dictionary).get("id", ""))
		assert_false(_gd().call("get_layout", rid).is_empty(),
			"la regione '%s' ha un layout disegnato a mano" % rid)


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


## --- US-807a: Marche del Crepuscolo (seconda regione con layout) ---


func test_marche_dipinta_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("marche_crepuscolo")
	var scena: TileMapLayer = r["scena"]

	assert_eq(scena.get_cell_atlas_coords(Vector2i(0, 0)), MURO, "bordo esterno solido")
	assert_eq(scena.get_cell_atlas_coords(Vector2i(1, 1)), PAVIMENTO, "cella '.' di brughiera non solida")
	# muro della cripta (data/world/layouts/marche_crepuscolo.json: zona cripta [20,19,8,8])
	assert_eq(scena.get_cell_atlas_coords(Vector2i(20, 19)), MURO, "muro della cripta solido")
	# varco della cripta sul lato sud (riga 26, colonne 23-24 libere)
	assert_eq(scena.get_cell_atlas_coords(Vector2i(23, 26)), PAVIMENTO, "il varco della cripta e' calpestabile")

	(r["cont"] as Node2D).free()


func test_marche_spawn_e_passaggio_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("marche_crepuscolo")
	var scena: Node = r["scena"]
	var player: Node2D = r["player"]

	var atteso_spawn: Vector2 = scena.to_global(scena.map_to_local(Vector2i(4, 4)))
	assert_eq(player.global_position, atteso_spawn, "il player compare sulla cella spawn del layout")

	var passaggio: Node2D = scena.get_node_or_null("Passaggio_mirwada")
	assert_false(passaggio == null, "Passaggio_mirwada esiste (unica destinazione di una regione a raggio)")
	var atteso_pass := Vector2(4.5, 6.5) * TILE
	assert_almost_eq(passaggio.position.x, atteso_pass.x, "passaggio.x dalla cella del layout")
	assert_almost_eq(passaggio.position.y, atteso_pass.y, "passaggio.y dalla cella del layout")

	(r["cont"] as Node2D).free()


func test_marche_nemici_dal_layout_sequenza_e_boss() -> void:
	var r: Dictionary = _istanzia_con_player("marche_crepuscolo")
	var scena: Node = r["scena"]

	var nemici: Array = _nemici_di(scena)
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

	var pickup_list: Array = _pickup_di(scena)
	assert_eq(pickup_list.size(), 8, "8 oggetti a terra dal layout")

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

	var nemici: Array = _nemici_di(scena)
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
	var scena: Node = load("res://scenes/regioni/marche_crepuscolo.tscn").instantiate()
	cont.add_child(scena)

	var nemici: Array = _nemici_di(scena)
	assert_eq(nemici.size(), 7, "i nemici si spawnano comunque senza Player")
	for e in nemici:
		e.call("_physics_process", 0.016)
		assert_eq(str(e.call("stato")), "IDLE", "nessun bersaglio -> resta IDLE, nessun crash")

	cont.free()


## --- US-807b: Valle Madre (quarta regione con layout) ---


func test_valle_dipinta_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("valle_madre")
	var scena: TileMapLayer = r["scena"]

	assert_eq(scena.get_cell_atlas_coords(Vector2i(0, 0)), MURO, "bordo esterno solido")
	assert_eq(scena.get_cell_atlas_coords(Vector2i(1, 1)), PAVIMENTO, "cella '.' del bosco non solida")
	# data/world/layouts/valle_madre.json: acqua '~' nella zona grotta_di_marea, es. (40,5)
	assert_eq(scena.get_cell_atlas_coords(Vector2i(40, 5)), MURO,
		"cella '~' della grotta di marea e' solida in questa story (US-813 le da' la resa vera)")
	# il ponte di radici '=' che attraversa l'acqua, es. (41,5), resta calpestabile
	assert_eq(scena.get_cell_atlas_coords(Vector2i(41, 5)), PAVIMENTO,
		"il ponte di radici che attraversa la grotta di marea e' calpestabile")

	(r["cont"] as Node2D).free()


func test_valle_spawn_e_passaggio_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("valle_madre")
	var scena: Node = r["scena"]
	var player: Node2D = r["player"]

	var atteso_spawn: Vector2 = scena.to_global(scena.map_to_local(Vector2i(4, 4)))
	assert_eq(player.global_position, atteso_spawn, "il player compare sulla cella spawn del layout")

	var passaggio: Node2D = scena.get_node_or_null("Passaggio_mirwada")
	assert_false(passaggio == null, "Passaggio_mirwada esiste (unica destinazione di una regione a raggio)")
	var atteso_pass := Vector2(4.5, 6.5) * TILE
	assert_almost_eq(passaggio.position.x, atteso_pass.x, "passaggio.x dalla cella del layout")
	assert_almost_eq(passaggio.position.y, atteso_pass.y, "passaggio.y dalla cella del layout")

	(r["cont"] as Node2D).free()


func test_valle_nemici_dal_layout_sequenza_e_boss() -> void:
	var r: Dictionary = _istanzia_con_player("valle_madre")
	var scena: Node = r["scena"]

	var nemici: Array = _nemici_di(scena)
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

	var pickup_list: Array = _pickup_di(scena)
	assert_eq(pickup_list.size(), 7, "7 oggetti a terra dal layout")

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

	var nemici: Array = _nemici_di(scena)
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
	var scena: Node = load("res://scenes/regioni/valle_madre.tscn").instantiate()
	cont.add_child(scena)

	var nemici: Array = _nemici_di(scena)
	assert_eq(nemici.size(), 7, "i nemici si spawnano comunque senza Player")
	for e in nemici:
		e.call("_physics_process", 0.016)
		assert_eq(str(e.call("stato")), "IDLE", "nessun bersaglio -> resta IDLE, nessun crash")

	cont.free()


## --- US-807c: Archivio Sepolto (quinta regione con layout) ---


func test_archivio_dipinta_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("archivio_sepolto")
	var scena: TileMapLayer = r["scena"]

	assert_eq(scena.get_cell_atlas_coords(Vector2i(0, 0)), MURO, "bordo esterno solido")
	assert_eq(scena.get_cell_atlas_coords(Vector2i(4, 4)), PAVIMENTO, "spawn dentro la sala biblioteca, calpestabile")
	# data/world/layouts/archivio_sepolto.json: muro interno della sala officina
	assert_eq(scena.get_cell_atlas_coords(Vector2i(17, 5)), MURO, "muro interno di una sala solido")
	# varco fra biblioteca e officina sul corridoio y=9
	assert_eq(scena.get_cell_atlas_coords(Vector2i(16, 9)), PAVIMENTO, "varco fra le sale e' calpestabile")

	(r["cont"] as Node2D).free()


func test_archivio_spawn_e_passaggio_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("archivio_sepolto")
	var scena: Node = r["scena"]
	var player: Node2D = r["player"]

	var atteso_spawn: Vector2 = scena.to_global(scena.map_to_local(Vector2i(4, 4)))
	assert_eq(player.global_position, atteso_spawn, "il player compare sulla cella spawn del layout")

	var passaggio: Node2D = scena.get_node_or_null("Passaggio_mirwada")
	assert_false(passaggio == null, "Passaggio_mirwada esiste (unica destinazione di una regione a raggio)")
	var atteso_pass := Vector2(4.5, 6.5) * TILE
	assert_almost_eq(passaggio.position.x, atteso_pass.x, "passaggio.x dalla cella del layout")
	assert_almost_eq(passaggio.position.y, atteso_pass.y, "passaggio.y dalla cella del layout")

	(r["cont"] as Node2D).free()


func test_archivio_nemici_dal_layout_sequenza_e_boss() -> void:
	var r: Dictionary = _istanzia_con_player("archivio_sepolto")
	var scena: Node = r["scena"]

	var nemici: Array = _nemici_di(scena)
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

	var pickup_list: Array = _pickup_di(scena)
	assert_eq(pickup_list.size(), 6, "6 oggetti a terra dal layout")

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

	var nemici: Array = _nemici_di(scena)
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
	var scena: Node = load("res://scenes/regioni/archivio_sepolto.tscn").instantiate()
	cont.add_child(scena)

	var nemici: Array = _nemici_di(scena)
	assert_eq(nemici.size(), 7, "i nemici si spawnano comunque senza Player")
	for e in nemici:
		e.call("_physics_process", 0.016)
		assert_eq(str(e.call("stato")), "IDLE", "nessun bersaglio -> resta IDLE, nessun crash")

	cont.free()


## --- US-807d: Frontiera delle Porte (sesta e ultima regione con layout) ---


func test_frontiera_dipinta_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("frontiera_porte")
	var scena: TileMapLayer = r["scena"]

	assert_eq(scena.get_cell_atlas_coords(Vector2i(0, 0)), MURO, "bordo esterno solido")
	assert_eq(scena.get_cell_atlas_coords(Vector2i(15, 4)), MURO,
		"cella '~' (nebbia) fuori da un'isola e' solida in questa story (US-813 le da' la resa vera)")
	assert_eq(scena.get_cell_atlas_coords(Vector2i(7, 7)), PAVIMENTO, "spawn sull'isola soglia, calpestabile")
	# ponte '=' che collega la crocevia centrale alle isole
	assert_eq(scena.get_cell_atlas_coords(Vector2i(24, 12)), PAVIMENTO, "il ponte fra isole e' calpestabile")

	(r["cont"] as Node2D).free()


func test_frontiera_spawn_e_passaggio_dal_layout() -> void:
	var r: Dictionary = _istanzia_con_player("frontiera_porte")
	var scena: Node = r["scena"]
	var player: Node2D = r["player"]

	var atteso_spawn: Vector2 = scena.to_global(scena.map_to_local(Vector2i(7, 7)))
	assert_eq(player.global_position, atteso_spawn, "il player compare sulla cella spawn del layout")

	var passaggio: Node2D = scena.get_node_or_null("Passaggio_mirwada")
	assert_false(passaggio == null, "Passaggio_mirwada esiste (unica destinazione di una regione a raggio)")
	var atteso_pass := Vector2(7.5, 9.5) * TILE
	assert_almost_eq(passaggio.position.x, atteso_pass.x, "passaggio.x dalla cella del layout")
	assert_almost_eq(passaggio.position.y, atteso_pass.y, "passaggio.y dalla cella del layout")

	(r["cont"] as Node2D).free()


func test_frontiera_nemici_dal_layout_sequenza_e_boss() -> void:
	var r: Dictionary = _istanzia_con_player("frontiera_porte")
	var scena: Node = r["scena"]

	var nemici: Array = _nemici_di(scena)
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

	var pickup_list: Array = _pickup_di(scena)
	assert_eq(pickup_list.size(), 6, "6 oggetti a terra dal layout")

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

	var nemici: Array = _nemici_di(scena)
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
	var scena: Node = load("res://scenes/regioni/frontiera_porte.tscn").instantiate()
	cont.add_child(scena)

	var nemici: Array = _nemici_di(scena)
	assert_eq(nemici.size(), 7, "i nemici si spawnano comunque senza Player")
	for e in nemici:
		e.call("_physics_process", 0.016)
		assert_eq(str(e.call("stato")), "IDLE", "nessun bersaglio -> resta IDLE, nessun crash")

	cont.free()
