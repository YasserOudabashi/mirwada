extends "res://tests/test_case.gd"
## US-8B40 — VFX degli attacchi base (tools/art/build_vfx.py): fendente, proiettile in volo e scoppio, scatto.

const ItemNode := preload("res://scripts/projectile.gd")


func _root() -> Node:
	return Engine.get_main_loop().root


func _caster() -> Node2D:
	var c := Node2D.new()
	c.add_to_group("player")
	var madre := Node2D.new()
	madre.name = "MadreVfx"
	_root().add_child(madre)
	madre.add_child(c)
	_root().get_node("Progression").call("configura", "twilight_giant", 9)
	return c


func _effetti(madre: Node) -> Array:
	return madre.get_children().filter(func(n: Node) -> bool: return n is Sprite2D)


func test_i_fogli_hanno_i_frame_dei_dati() -> void:
	var gd: Node = _root().get_node("GameData")
	var attesi := {"melee_arc": Vector2i(96, 96), "projectile": Vector2i(48, 32), "dash": Vector2i(64, 32)}
	for tipo in attesi:
		var pv: Dictionary = gd.call("get_primitive_vfx", tipo)
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/vfx/%s.png" % pv["sprite"]))
		assert_eq(img.get_size(), Vector2i(attesi[tipo].x * int(pv["frames"]), attesi[tipo].y),
			"%s: %d frame in colonne" % [pv["sprite"], int(pv["frames"])])
	var sc: Dictionary = (gd.call("get_primitive_vfx", "projectile") as Dictionary)["scoppio"]
	var img2 := Image.load_from_file(ProjectSettings.globalize_path("res://assets/vfx/%s.png" % sc["sprite"]))
	assert_eq(img2.get_size(), Vector2i(48 * int(sc["frames"]), 48), "lo scoppio")
	assert_true(int((gd.call("get_primitive_vfx", "melee_arc") as Dictionary)["frames"]) >= 4,
		"impatto 1 frame + 3-4 di dissolvenza")


func test_il_fendente_lampeggia_bianco_poi_si_dissolve() -> void:
	var am: Node = _root().get_node("AudioManager")
	var prima: Variant = am.call("accessibilita", "riduci_flash")
	am.call("imposta_accessibilita", "riduci_flash", false)
	var c := _caster()
	_root().get_node("Vfx").call("gioca_per", "melee_arc", c)
	var e: Array = _effetti(c.get_parent())
	assert_eq(e.size(), 1, "il fendente c'e'")
	var s: Sprite2D = e[0]
	assert_eq(s.hframes, 5, "5 frame")
	assert_eq(s.frame, 0, "parte dal frame d'impatto")
	assert_eq(s.scale, Vector2(0.5, 0.5), "a mezza grandezza come gli altri sprite")
	var m: ShaderMaterial = s.material
	assert_eq(m.get_shader_parameter("lampo"), 1.0, "il primo frame e' bianco")
	var pal: Dictionary = _root().get_node("GameData").call("get_vfx_palette", "twilight_giant")
	assert_eq(m.get_shader_parameter("primario"), Color.from_string(str(pal["primario"]), Color.BLACK),
		"colorato dalla palette del Pathway")
	am.call("imposta_accessibilita", "riduci_flash", true)
	_root().get_node("Vfx").call("gioca_per", "melee_arc", c)
	var m2: ShaderMaterial = (_effetti(c.get_parent())[1] as Sprite2D).material
	assert_eq(m2.get_shader_parameter("lampo"), 0.0, "con riduci_flash niente lampo bianco")
	am.call("imposta_accessibilita", "riduci_flash", prima)
	c.get_parent().free()


func test_il_proiettile_si_vede_e_scoppia() -> void:
	var c := _caster()
	var p: Area2D = ItemNode.new()
	p.call("setup", {"danno": 1.0, "velocita": 100.0, "gittata": 50.0}, Vector2(10, 10), Vector2.LEFT, c)
	var disegno: Sprite2D = null
	for n in p.get_children():
		if n is Sprite2D:
			disegno = n
	assert_true(disegno != null, "il proiettile in volo ha il suo disegno")
	assert_eq(disegno.rotation, Vector2.LEFT.angle(), "girato nella direzione di tiro")
	c.get_parent().add_child(p)
	var prima: int = _effetti(c.get_parent()).size()
	p.call("_finisci")
	assert_eq(_effetti(c.get_parent()).size(), prima + 1, "a fine corsa lo scoppio")
	c.get_parent().free()


func test_l_attacco_base_del_giocatore_ha_il_fendente() -> void:
	var madre := Node2D.new()
	_root().add_child(madre)
	var p: Node = preload("res://scenes/player.tscn").instantiate()
	madre.add_child(p)
	_root().get_node("Progression").call("configura", "twilight_giant", 9)
	p.call("_su_evento_anim", "hitbox_on")
	var e: Array = _effetti(madre)
	assert_eq(e.size(), 1, "quando l'attacco base colpisce compare il fendente")
	if e.size() == 1:
		assert_eq((e[0] as Sprite2D).hframes, 5, "il foglio del fendente")
	madre.free()
