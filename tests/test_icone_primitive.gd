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
	var ic: TextureRect = hud.get_node("Root/Hotbar/Slot0/Glifo")
	var ab: Dictionary = _gd().call("get_ability", str(owned[0]))
	var tipo: String = str((ab["primitive"][0] as Dictionary)["tipo"])
	assert_true(ic.visible and ic.texture == _gd().call("icona_primitiva", tipo), "il glifo della prima primitiva")
	var pal: Dictionary = _gd().call("get_vfx_palette", "twilight_giant")
	var mat: ShaderMaterial = ic.material
	assert_eq(mat.get_shader_parameter("primario"), Color.from_string(str(pal["primario"]), Color.BLACK),
		"i colori dalla palette del Pathway in data/vfx.json")
	if owned.size() < 4:
		assert_false(hud.get_node("Root/Hotbar/Slot3/Glifo").visible, "lo slot vuoto non ha glifo")
	hud.free()
	host.free()


## US-8B75d: la hotbar sta in basso al centro, dentro lo schermo, e l'HUD dice quanto occupa sopra e sotto (per la
## camera degli interni). In alto resta piccolo: meno di un quinto dello schermo.
func test_la_hotbar_sta_in_basso_al_centro() -> void:
	var hud: CanvasLayer = HudScene.instantiate()
	Engine.get_main_loop().root.add_child(hud)
	var schermo := Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width")),
			float(ProjectSettings.get_setting("display/window/size/viewport_height"))) \
			/ float(ProjectSettings.get_setting("display/window/stretch/scale"))
	var barra: Control = hud.get_node("Root/Hotbar")
	var r: Rect2 = barra.get_global_rect()
	assert_true(r.position.x >= 0.0 and r.end.x <= schermo.x and r.end.y <= schermo.y, "dentro lo schermo: %s" % r)
	assert_almost_eq(r.get_center().x, schermo.x / 2.0, "al centro", 1.0)
	assert_gt(r.position.y, schermo.y * 0.8, "in basso")
	assert_gt(float(hud.call("altezza")), 15.0, "l'HUD dice quanto e' alto in cima")
	assert_true(float(hud.call("altezza")) < schermo.y / 5.0, "e resta piccolo (%d unita')" % int(hud.call("altezza")))
	assert_gt(float(hud.call("altezza_sotto")), 20.0, "e quanto occupa in basso")
	hud.free()


## 2026-11-11: gli status del giocatore stanno anche nell'HUD (US-8B75d: solo l'icona e la linea del tempo); ogni status ha un nome tradotto.
func test_gli_status_del_giocatore_stanno_nell_hud_col_nome() -> void:
	var gd: Node = _gd()
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/status_effects.json"))
	for id in doc["statuses"]:
		var k: String = str((doc["statuses"][id] as Dictionary).get("name_i18n", ""))
		assert_true(not k.is_empty() and str(gd.call("tr_data", k)) != k, "lo status %s ha un nome" % id)
	var host := Node.new()
	host.add_to_group("player")
	var stats: Node = StatsComponent.new()
	stats.name = "StatsComponent"
	stats.configure_from_balance(9)
	host.add_child(stats)
	var root: Node = Engine.get_main_loop().root
	root.add_child(host)
	var hud: CanvasLayer = HudScene.instantiate()
	root.add_child(hud)
	var riga: Control = hud.get_node("Root/Vitali/Stati")
	assert_false(riga.visible, "senza status la riga non c'e'")
	stats.call("applica_status", "paura", 6.0)
	assert_true(riga.visible, "con uno status compare")
	var ic: TextureRect = riga.get_node("paura/Icona")
	assert_true(ic.texture == gd.call("icona_stato", "paura"), "con la sua icona, senza scritte (US-8B75d)")
	hud.call("_process", 0.1)
	assert_true((riga.get_node("paura/Tempo") as Control).visible, "e sotto la linea del tempo che resta")
	assert_eq(riga.find_children("*", "Label", true, false).size(), 0, "nessun nome")
	hud.free()
	host.free()
