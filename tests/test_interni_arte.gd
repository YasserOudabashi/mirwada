extends "res://tests/test_case.gd"
## US-8B18c — gli interni con l'arte vera: un'immagine per interno e per modalita'
## (tools/art/build_interni.py), grande quanto la sua mappa, sotto NPC e oggetti.

const InteriorScene := preload("res://scenes/interior_scene.tscn")


func _interni() -> Array:
	var ids: Array = []
	for f in DirAccess.get_files_at("res://data/world/interni"):
		if f.ends_with(".json"):
			ids.append(f.get_basename())
	return ids


func test_ogni_interno_ha_la_sua_immagine_nelle_due_modalita() -> void:
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	assert_eq(_interni().size(), 20, "20 interni: 14 delle case e 6 delle sotto-aree (US-8B21a)")
	for iid in _interni():
		var mappa: Array = (gd.call("get_interno", iid) as Dictionary).get("mappa", [])
		for tema in ["luminoso", "cupo"]:
			var path: String = "res://assets/interni/%s/%s.png" % [tema, iid]
			assert_true(FileAccess.file_exists(path), "%s esiste" % path)
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			assert_eq(img.get_size(), Vector2i(str(mappa[0]).length(), mappa.size()) * 32, "%s grande quanto la mappa" % path)


func test_l_interno_mostra_l_immagine_e_tiene_le_collisioni() -> void:
	var interno: TileMapLayer = InteriorScene.instantiate()
	interno.set("interno_id", "mirwada_bettola_del_porto")
	Engine.get_main_loop().root.add_child(interno)
	var arte: Sprite2D = interno.get_node_or_null("Arte")
	assert_true(arte != null, "l'immagine dell'interno c'e'")
	assert_eq(arte.get_index(), 0, "sotto NPC, nemici e oggetti")
	assert_eq(interno.self_modulate.a, 0.0, "le celle segnaposto non si vedono")
	assert_eq(interno.get_cell_source_id(Vector2i(0, 0)), 0, "ma ci sono ancora (collisioni dei muri)")
	interno.free()


# --- US-8B18d: arredi ---------------------------------------------------------------

func test_ogni_arredo_dei_dati_ha_il_suo_disegno() -> void:
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	for iid in _interni():
		for a in (gd.call("get_interno", iid) as Dictionary).get("arredi", []):
			assert_false((gd.call("get_arredo", str(a["id"])) as Dictionary).is_empty(), "%s e' nel vocabolario" % a["id"])
			for tema in ["luminoso", "cupo"]:
				assert_true(FileAccess.file_exists("res://assets/interni/%s/arredi/%s.png" % [tema, a["id"]]), "%s/%s" % [tema, a["id"]])


func test_gli_arredi_si_vedono_e_bloccano_tranne_i_tappeti() -> void:
	var bettola: TileMapLayer = InteriorScene.instantiate()
	bettola.set("interno_id", "mirwada_bettola_del_porto")
	Engine.get_main_loop().root.add_child(bettola)
	assert_true(bettola.y_sort_enabled, "la stanza ordina per profondita'")
	var bancone: Sprite2D = bettola.get_node_or_null("Arredo_bancone_1_1")
	assert_true(bancone != null, "il bancone c'e'")
	assert_eq(bancone.position, Vector2(2.5, 2.0) * 32, "con i piedi in basso al centro del suo rettangolo")
	for x in [1, 2, 3]:
		assert_eq(bettola.get_cell_atlas_coords(Vector2i(x, 1)), Vector2i(1, 0), "il bancone blocca (%d, 1)" % x)
	bettola.free()
	var archivio: TileMapLayer = InteriorScene.instantiate()
	archivio.set("interno_id", "mirwada_archivio_ottavia")
	Engine.get_main_loop().root.add_child(archivio)
	var tappeto: Sprite2D = archivio.get_node_or_null("Arredo_tappeto_4_3")
	assert_true(tappeto != null and tappeto.z_index < 0, "il tappeto sta sotto chi ci passa")
	assert_true(tappeto.z_index > (archivio.get_node("Arte") as Sprite2D).z_index, "ma sopra il pavimento (si vede)")
	assert_eq(archivio.get_cell_atlas_coords(Vector2i(4, 3)), Vector2i(0, 0), "e non blocca")
	archivio.free()
