extends "res://tests/test_case.gd"
## US-226 — data/vfx.json: palette visive per Pathway + renderer per primitiva.


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


func test_palette_per_ogni_pathway_attivo() -> void:
	var gd: Node = _gd()
	for pid in gd.call("pathway_ids"):
		var pal: Dictionary = gd.call("get_vfx_palette", pid)
		assert_false(pal.is_empty(), "palette visiva per %s" % pid)
		for c in ["inchiostro", "primario", "accento"]:
			var v: String = str(pal.get(c, ""))
			assert_true(v.begins_with("#") and v.length() == 7, "%s.%s e' #rrggbb" % [pid, c])
		assert_false(str(pal.get("tratto", "")).is_empty(), "%s ha un tratto" % pid)


func test_tratto_unico_per_pathway() -> void:
	var gd: Node = _gd()
	var visti: Array = []
	for pid in gd.call("pathway_ids"):
		var t: String = str(gd.call("get_vfx_palette", pid).get("tratto", ""))
		assert_false(visti.has(t), "il tratto '%s' e' la firma di un solo Pathway" % t)
		visti.append(t)


func test_primitive_vfx_lookup() -> void:
	var gd: Node = _gd()
	var e: Dictionary = gd.call("get_primitive_vfx", "melee_arc")
	assert_false(e.is_empty(), "melee_arc ha una voce primitive_vfx")
	assert_gt(float(e.get("frames", 0)), 0.0, "frames > 0")
	assert_eq(typeof(e.get("impact_frame")), TYPE_BOOL, "impact_frame e' un bool")
	assert_true(gd.call("get_primitive_vfx", "primitiva_inventata").is_empty(),
		"primitiva ignota -> {}")


func test_ogni_primitiva_implementata_ha_un_vfx() -> void:
	var gd: Node = _gd()
	var eng: Node = Engine.get_main_loop().root.get_node_or_null("AbilityEngine")
	for tipo in eng.call("tipi_primitiva_implementati"):
		assert_false(gd.call("get_primitive_vfx", tipo).is_empty(),
			"la primitiva implementata '%s' ha un VFX" % tipo)


func test_sezioni_di_supporto() -> void:
	var gd: Node = _gd()
	assert_false(gd.call("get_vfx", "impact_frames").is_empty(), "impact_frames presente")
	assert_false(gd.call("get_vfx", "nero_di_scena").is_empty(), "nero_di_scena presente")
