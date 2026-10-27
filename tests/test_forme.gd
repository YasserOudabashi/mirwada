extends "res://tests/test_case.gd"
## US-8B50 — forme di Enel: una forma con "aspetto" (data/forms.json) ha i suoi fogli del personaggio
## (tools/art/build_forme.py), con celle piu' grandi lette dal foglio; la transform li mette e li toglie.

const AnimMachine := preload("res://scripts/animation_machine.gd")


func _root() -> Node:
	return Engine.get_main_loop().root


func _cella(m: AnimatedSprite2D) -> Vector2:
	var at: AtlasTexture = m.sprite_frames.get_frame_texture("idle_down", 0)
	return at.region.size


func test_le_forme_con_aspetto_hanno_tutti_i_fogli() -> void:
	var gd: Node = _root().get_node("GameData")
	var forma: Dictionary = gd.call("get_form", "tg_forma_gigante")
	var aspetto: String = str(forma.get("aspetto", ""))
	assert_false(aspetto.is_empty(), "la forma gigante ha il suo aspetto nei dati")
	for nome in gd.call("animation_names", "personaggio"):
		var path := "res://assets/placeholder/personaggio_%s_%s.png" % [aspetto, nome]
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_true(img != null and not img.is_empty(), "%s c'e'" % path)
		if img != null and not img.is_empty():
			var frames: int = int((gd.call("get_animation", "personaggio", nome) as Dictionary).get("frames", 1))
			assert_eq(img.get_width() % frames, 0, "%s: %d frame in colonne" % [nome, frames])


func test_la_cella_si_legge_dal_foglio_e_la_grana_resta_quella() -> void:
	var enel: AnimatedSprite2D = AnimMachine.new()
	enel.call("configura", "personaggio")
	var gigante: AnimatedSprite2D = AnimMachine.new()
	gigante.call("configura", "personaggio", "gigante")
	assert_eq(_cella(enel), Vector2(64, 64), "Enel a 64")
	assert_eq(_cella(gigante), Vector2(96, 96), "il gigante a 96, dal suo foglio")
	assert_eq(gigante.scale, enel.scale, "stessa scala: i pixel hanno la stessa grana")
	assert_almost_eq(gigante.offset.y, enel.offset.y * 1.5, "i piedi restano sull'origine", 0.01)
	enel.free()
	gigante.free()
