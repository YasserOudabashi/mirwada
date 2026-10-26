extends "res://tests/test_case.gd"
## US-8B72 — i glifi delle primitive (tools/art/build_primitive.py), colorati dalla palette del Pathway nella hotbar.

const HudScene := preload("res://scenes/hud.tscn")
const StatsComponent := preload("res://scripts/stats_component.gd")


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node("GameData")


func test_ogni_primitiva_attiva_ha_il_suo_glifo_a_4_toni() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/schema/primitives.json"))
	var attive: Array = (doc["primitives"] as Dictionary).keys().filter(func(k: String) -> bool:
		return not bool((doc["primitives"][k] as Dictionary).get("deferred", false)))
	assert_eq(attive.size(), 28, "28 primitive attive")
	for pid in attive:
		var tex: Texture2D = _gd().call("icona_primitiva", pid)
		assert_true(tex != null, "%s ha il glifo" % pid)
		if tex == null:
			continue
		assert_eq(tex.get_size(), Vector2(32, 32), "%s: 32 x 32" % pid)
		var img: Image = tex.get_image()
		var grigi := {}
		for y in 32:
			for x in 32:
				var c: Color = img.get_pixel(x, y)
				if c.a > 0.0:
					grigi[roundi(c.r8 / 85.0)] = true
					assert_true(c.r8 % 85 == 0 and c.r8 == c.g8 and c.g8 == c.b8, "%s: solo i 4 grigi della rampa" % pid)
		assert_true(grigi.has(0), "%s ha il contorno" % pid)


func test_la_hotbar_mostra_il_glifo_colorato_dal_pathway() -> void:
	var host := Node.new()
	host.add_to_group("player")
	var stats: Node = StatsComponent.new()
	stats.name = "StatsComponent"
	stats.configure_from_balance(9)
	host.add_child(stats)
	var root: Node = Engine.get_main_loop().root
	root.add_child(host)
	root.get_node("Progression").call("configura", "twilight_giant", 9)
	var owned: Array = root.get_node("AbilityEngine").call("owned_abilities", host)
	var hud: CanvasLayer = HudScene.instantiate()
	root.add_child(hud)
	var ic: TextureRect = hud.get_node("Root/VBox/Hotbar/Icona0")
	var ab: Dictionary = _gd().call("get_ability", str(owned[0]))
	var tipo: String = str((ab["primitive"][0] as Dictionary)["tipo"])
	assert_true(ic.visible and ic.texture == _gd().call("icona_primitiva", tipo), "il glifo della prima primitiva")
	assert_eq(ic.get_index() + 1, hud.get_node("Root/VBox/Hotbar/Slot0").get_index(), "prima del nome")
	var pal: Dictionary = _gd().call("get_vfx_palette", "twilight_giant")
	var mat: ShaderMaterial = ic.material
	assert_eq(mat.get_shader_parameter("primario"), Color.from_string(str(pal["primario"]), Color.BLACK),
		"i colori dalla palette del Pathway in data/vfx.json")
	assert_false(hud.get_node("Root/VBox/Hotbar/Icona3").visible, "lo slot vuoto non ha glifo")
	hud.free()
	host.free()
