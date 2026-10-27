extends "res://tests/test_case.gd"
## US-8B23 — fauna d'atmosfera: una specie = un aspetto della categoria "fauna" (data/animations.json), fogli di
## tools/art/build_fauna.py con la cella letta dal foglio (32 i piccoli, 64 il cervo) e la stessa grana degli altri.

const AnimMachine := preload("res://scripts/animation_machine.gd")
const SPECIE := {"cervo": 64, "lepre": 32, "uccello": 32, "farfalla": 32, "lucciola": 32}


func _root() -> Node:
	return Engine.get_main_loop().root


func test_ogni_specie_ha_i_suoi_fogli_con_la_sua_cella() -> void:
	var gd: Node = _root().get_node("GameData")
	var nomi: Array = gd.call("animation_names", "fauna")
	assert_eq(nomi.size(), 2, "idle e fuga")
	var umano: AnimatedSprite2D = AnimMachine.new()
	umano.call("configura", "personaggio")
	for specie in SPECIE:
		var m: AnimatedSprite2D = AnimMachine.new()
		m.call("configura", "fauna", specie)
		for nome in nomi:
			var frames: int = int((gd.call("get_animation", "fauna", nome) as Dictionary)["frames"])
			for dir in ["down", "up", "left", "right"]:
				var k: String = "%s_%s" % [nome, dir]
				assert_true(m.sprite_frames.has_animation(k), "%s: %s" % [specie, k])
				assert_eq(m.sprite_frames.get_frame_count(k), frames, "%s: %d frame" % [specie, frames])
		var at: AtlasTexture = m.sprite_frames.get_frame_texture("idle_down", 0)
		assert_eq(at.region.size, Vector2(SPECIE[specie], SPECIE[specie]), "%s: cella dal foglio" % specie)
		assert_eq(m.scale, umano.scale, "%s: stessa grana dei personaggi" % specie)
		m.free()
	umano.free()
