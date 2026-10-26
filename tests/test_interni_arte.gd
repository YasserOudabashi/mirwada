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
	assert_eq(_interni().size(), 14, "14 interni")
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
