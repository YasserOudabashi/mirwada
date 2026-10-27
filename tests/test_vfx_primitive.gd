extends "res://tests/test_case.gd"
## US-8B41..43 — i VFX delle primitive (tools/art/build_vfx.py): un foglio per primitiva, attorno a chi lancia.

const GRUPPO_1 := ["buff_stat", "summon", "aura", "heal", "reveal_info", "teleport", "debuff_stat", "illusion"]
const GRUPPO_2 := ["curse", "terrain_modify", "fear", "steal", "dot", "shadow_meld", "time_rewind", "plant_growth"]
const GRUPPO_3 := ["mind_read", "shield", "light_purify", "possess", "transform", "soul_detach", "resurrect", "decay"]


func _root() -> Node:
	return Engine.get_main_loop().root


func test_il_gruppo_1_ha_i_fogli_con_i_frame_dei_dati() -> void:
	_fogli(GRUPPO_1)


func test_il_gruppo_2_ha_i_fogli_con_i_frame_dei_dati() -> void:
	_fogli(GRUPPO_2)


func test_il_gruppo_3_ha_i_fogli_con_i_frame_dei_dati() -> void:
	_fogli(GRUPPO_3)


func test_ogni_primitiva_implementata_ha_il_suo_foglio() -> void:
	var gd: Node = _root().get_node("GameData")
	for tipo in _root().get_node("AbilityEngine").call("tipi_primitiva_implementati"):
		var pv: Dictionary = gd.call("get_primitive_vfx", tipo)
		assert_true(FileAccess.file_exists("res://assets/vfx/%s.png" % pv.get("sprite", "")),
			"%s non usa piu' il segnaposto" % tipo)


func _fogli(tipi: Array) -> void:
	var gd: Node = _root().get_node("GameData")
	for tipo in tipi:
		var pv: Dictionary = gd.call("get_primitive_vfx", tipo)
		var path: String = "res://assets/vfx/%s.png" % pv["sprite"]
		assert_true(FileAccess.file_exists(path), "%s ha il foglio %s" % [tipo, path])
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_eq(img.get_width(), img.get_height() * int(pv["frames"]), "%s: %d frame quadrati in colonna" % [tipo, int(pv["frames"])])


func test_gli_effetti_attorno_a_chi_lancia_non_girano_col_lo_sguardo() -> void:
	var madre := Node2D.new()
	_root().add_child(madre)
	var p: Node = preload("res://scenes/player.tscn").instantiate()
	madre.add_child(p)
	p.set("_dir_sguardo", "right")
	_root().get_node("Progression").call("configura", "twilight_giant", 9)
	var vfx: Node = _root().get_node("Vfx")
	vfx.call("gioca_per", "aura", p)
	vfx.call("gioca_per", "melee_arc", p)
	var effetti: Array = madre.get_children().filter(func(n: Node) -> bool: return n is Sprite2D)
	assert_eq(effetti.size(), 2, "due effetti")
	assert_eq((effetti[0] as Sprite2D).rotation, 0.0, "l'anello dell'aura sta dritto")
	assert_eq((effetti[1] as Sprite2D).rotation, Vector2.RIGHT.angle(), "il fendente si gira con lo sguardo")
	assert_eq((effetti[0] as Sprite2D).hframes, 4, "il foglio dell'aura, non il segnaposto")
	madre.free()
