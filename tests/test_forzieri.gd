extends "res://tests/test_case.gd"
## US-8B22 — forzieri: tabelle di bottino nei dati (data/world/bottino.json), il forziere si apre una volta sola
## (WorldState, nel salvataggio) e il bottino va nello zaino.

const Forziere := preload("res://scripts/forziere.gd")
const InteriorScene := preload("res://scenes/interior_scene.tscn")


func _root() -> Node:
	return Engine.get_main_loop().root


func _dimentica(id: String) -> void:
	(_root().get_node("WorldState").get("_forzieri_aperti") as Array).erase(id)


func test_il_bottino_viene_dalla_sua_tabella() -> void:
	var tab: Dictionary = _root().get_node("GameData").call("get_tabella_bottino", "grotta")
	assert_false(tab.is_empty(), "la tabella della grotta c'e'")
	var ammessi: Dictionary = {}
	var q_max := 0
	for v in tab["voci"]:
		ammessi[v["item_id"]] = true
		q_max = maxi(q_max, int(v["quantita"][1]))
	var rng := RandomNumberGenerator.new()
	for s in 30:
		rng.seed = s
		var bottino: Array = Forziere.tira(tab, rng)
		assert_true(bottino.size() >= 1 and bottino.size() <= int(tab["tiri"][1]), "da 1 a %d voci" % tab["tiri"][1])
		for b in bottino:
			assert_true(ammessi.has(b["item_id"]), "%s e' nella tabella" % b["item_id"])
			assert_true(int(b["quantita"]) >= 1 and int(b["quantita"]) <= q_max * int(tab["tiri"][1]), "quantita' nei limiti")
	rng.seed = 7
	var a: Array = Forziere.tira(tab, rng)
	rng.seed = 7
	assert_eq(Forziere.tira(tab, rng), a, "stesso seme, stesso bottino")
	assert_eq(Forziere.tira({}, rng), [], "una tabella che non c'e' non da' niente")


func test_si_apre_una_volta_sola_e_il_bottino_va_nello_zaino() -> void:
	var inv: Node = _root().get_node("Inventory")
	var f: Area2D = Forziere.new()
	f.call("setup", "prova_forziere", "fogne", Vector2(64, 64))
	f.get("rng").seed = 3
	_root().add_child(f)
	assert_false(bool(f.call("e_aperto")), "chiuso all'inizio")
	var prima: Dictionary = {}
	for v in (_root().get_node("GameData").call("get_tabella_bottino", "fogne") as Dictionary)["voci"]:
		prima[v["item_id"]] = int(inv.call("conta", v["item_id"]))
	var bottino: Array = f.call("apri")
	assert_false(bottino.is_empty(), "dentro c'era qualcosa")
	for b in bottino:
		assert_eq(int(inv.call("conta", b["item_id"])), prima[b["item_id"]] + int(b["quantita"]), "%s nello zaino" % b["item_id"])
	assert_true(bool(f.call("e_aperto")), "ora e' aperto")
	assert_true(bool(_root().get_node("WorldState").call("forziere_aperto", "prova_forziere")), "e lo sa il mondo")
	assert_true(str((f.get("_scritta") as Label).text).length() > 0 and (f.get("_scritta") as Label).visible, "dice cosa c'era")
	assert_eq(f.call("apri"), [], "una seconda volta e' vuoto")
	f.free()
	var di_nuovo: Area2D = Forziere.new()
	di_nuovo.call("setup", "prova_forziere", "fogne", Vector2(64, 64))
	_root().add_child(di_nuovo)
	var aperto := Image.load_from_file(ProjectSettings.globalize_path("res://assets/interni/luminoso/arredi/forziere_aperto.png"))
	assert_eq((di_nuovo.get("_sprite") as Sprite2D).texture.get_image().get_data(), aperto.get_data(), "si vede aperto")
	assert_eq(di_nuovo.call("apri"), [], "rientrando resta aperto")
	di_nuovo.free()
	for b in bottino:
		inv.call("rimuovi", b["item_id"], int(b["quantita"]))
	_dimentica("prova_forziere")


func test_i_forzieri_aperti_vanno_nel_salvataggio() -> void:
	var ws: Node = _root().get_node("WorldState")
	ws.call("apri_forziere", "prova_salvataggio")
	var dati: Dictionary = ws.call("per_salvataggio")
	assert_true("prova_salvataggio" in (dati.get("forzieri_aperti", []) as Array), "salvato")
	_dimentica("prova_salvataggio")
	dati["forzieri_aperti"].append(42)
	ws.call("da_salvataggio", dati)
	assert_true(bool(ws.call("forziere_aperto", "prova_salvataggio")), "riletto")
	assert_false(42 in (ws.get("_forzieri_aperti") as Array), "le voci malformate si scartano")
	_dimentica("prova_salvataggio")


func test_gli_interni_mettono_i_forzieri_dei_dati() -> void:
	var cripta: TileMapLayer = InteriorScene.instantiate()
	cripta.set("interno_id", "marche_cripta")
	_root().add_child(cripta)
	var f: Area2D = cripta.get_node_or_null("Forziere_marche_cripta_1")
	assert_true(f != null, "il forziere della cripta c'e'")
	assert_eq(f.position, cripta.map_to_local(Vector2i(6, 1)), "dove dicono i dati")
	assert_eq(str(f.get("tabella")), "cripta", "con la sua tabella")
	assert_eq(cripta.get_cell_atlas_coords(Vector2i(6, 1)), Vector2i(1, 0), "la sua casella non si attraversa")
	var spr: Sprite2D = f.get("_sprite")
	assert_true(spr.texture != null, "si vede il disegno del forziere")
	cripta.free()
