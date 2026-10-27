extends "res://tests/test_case.gd"
## US-8B40b — feedback del colpo (vfx.json feedback_colpo, tools/art/build_vfx.py): scintilla del colpo, parata
## perfetta, rottura della postura, polvere dello scatto.


func _root() -> Node:
	return Engine.get_main_loop().root


func _effetti(madre: Node) -> Array:
	return madre.get_children().filter(func(n: Node) -> bool: return n is Sprite2D and n.material is ShaderMaterial)


func _accenti() -> Array:
	var strato: Node = _root().get_node("Vfx").get_node_or_null("Accenti")
	return _effetti(strato) if strato != null else []


func _fb(nome: String) -> Dictionary:
	return (_root().get_node("GameData").call("get_vfx", "feedback_colpo") as Dictionary).get(nome, {})


func test_ogni_momento_ha_il_suo_foglio() -> void:
	var momenti: Dictionary = _root().get_node("GameData").call("get_vfx", "feedback_colpo")
	for nome in ["hit_light", "parry_perfect", "posture_break", "dash"]:
		var fb: Dictionary = momenti.get(nome, {})
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/vfx/%s.png" % fb.get("sprite")))
		assert_true(img != null and not img.is_empty(), "%s: il foglio c'e'" % nome)
		if img != null and not img.is_empty():
			assert_eq(img.get_width() % int(fb["frames"]), 0, "%s: %d frame in colonne" % [nome, int(fb["frames"])])


func test_la_scintilla_va_nel_mondo_sopra_la_hurtbox_colpita() -> void:
	var am: Node = _root().get_node("AudioManager")
	var prima: Variant = am.call("accessibilita", "riduci_flash")
	am.call("imposta_accessibilita", "riduci_flash", false)
	var mondo := Node2D.new()
	_root().add_child(mondo)
	var corpo := CharacterBody2D.new()
	corpo.position = Vector2(40, 30)
	mondo.add_child(corpo)
	var hurtbox := Area2D.new()
	corpo.add_child(hurtbox)
	_root().get_node("Vfx").call("evento_combat", "hit_light", hurtbox)
	assert_eq(_effetti(corpo).size(), 0, "non segue il bersaglio")
	var e: Array = _effetti(mondo)
	assert_eq(e.size(), 1, "la scintilla c'e'")
	if e.size() == 1:
		var s: Sprite2D = e[0]
		assert_eq(s.hframes, int(_fb("hit_light")["frames"]), "i frame dei dati")
		assert_eq(s.global_position, Vector2(40, 30 - float(_fb("hit_light")["alto"])), "sopra il punto colpito")
		var m: ShaderMaterial = s.material
		assert_eq(m.get_shader_parameter("lampo"), 1.0, "il colpo e' un frame d'impatto")
		assert_eq(m.get_shader_parameter("primario"), Color(str(_fb("hit_light")["colori"]["primario"])),
			"colori suoi, non del Pathway")
	am.call("imposta_accessibilita", "riduci_flash", true)
	_root().get_node("Vfx").call("evento_combat", "hit_light", hurtbox)
	var m2: ShaderMaterial = (_effetti(mondo)[-1] as Sprite2D).material
	assert_eq(m2.get_shader_parameter("lampo"), 0.0, "con riduci_flash niente lampo bianco")
	am.call("imposta_accessibilita", "riduci_flash", prima)
	mondo.free()


func test_senza_posto_niente_foglio() -> void:
	var mondo := Node2D.new()
	_root().add_child(mondo)
	_root().get_node("Vfx").call("evento_combat", "hit_light")
	assert_eq(_effetti(mondo).size(), 0, "senza un posto resta solo l'audio e il nero di scena")
	mondo.free()


func test_giocatore_colpo_parata_e_scatto() -> void:
	var mondo := Node2D.new()
	_root().add_child(mondo)
	var p: Node2D = preload("res://scenes/player.tscn").instantiate()
	mondo.add_child(p)
	var bersaglio := Node2D.new()
	bersaglio.position = Vector2(20, 0)
	mondo.add_child(bersaglio)
	p.call("_su_colpo_inflitto", bersaglio, 5.0)
	var colpo: Array = _effetti(mondo)
	assert_eq(colpo.size(), 1, "la scintilla sul bersaglio, nel mondo")
	if colpo.size() == 1:
		assert_eq((colpo[0] as Sprite2D).global_position.x, 20.0, "sul bersaglio")
	var prima: int = _accenti().size()
	p.call("_su_parata_riuscita", true, null)
	p.call("_su_parata_riuscita", false, null)
	var parata: Array = _accenti()
	assert_eq(parata.size(), prima + 1, "il lampo della parata perfetta (la parata normale no)")
	if parata.size() == prima + 1:
		assert_eq((parata[-1] as Sprite2D).hframes, int(_fb("parry_perfect")["frames"]), "il foglio della parata")
		assert_eq((parata[-1] as Sprite2D).global_position,
			p.global_position - Vector2(0, float(_fb("parry_perfect")["alto"])), "sul giocatore")
		var strato: CanvasLayer = _root().get_node("Vfx").get_node("Accenti")
		assert_true(strato.follow_viewport_enabled, "lo strato segue la camera: lo stesso punto del mondo")
		var ov: Node = _root().find_child("VfxOverlay", true, false)
		if ov is CanvasLayer:
			assert_gt(strato.layer, (ov as CanvasLayer).layer, "sopra il nero di scena")
		(parata[-1] as Node).free()
	p.call("_su_colpo_inflitto", null, 5.0)
	assert_eq(_effetti(mondo).size(), 1, "senza bersaglio niente scintilla")
	p.call("start_dash", {})
	var dash: Array = _effetti(mondo)
	assert_eq(dash.size(), 2, "la polvere dello scatto")
	if dash.size() == 2:
		assert_eq((dash[1] as Sprite2D).global_position, p.global_position, "ai piedi")
		assert_eq(((dash[1] as Sprite2D).material as ShaderMaterial).get_shader_parameter("lampo"), 0.0,
			"la polvere non lampeggia")
	mondo.free()


func test_nemico_postura_rotta() -> void:
	var mondo := Node2D.new()
	_root().add_child(mondo)
	var n: Node2D = preload("res://scenes/enemy.tscn").instantiate()
	mondo.add_child(n)
	var prima: int = _accenti().size()
	n.call("_su_postura_rotta")
	var e: Array = _accenti()
	assert_eq(e.size(), prima + 1, "le schegge della postura, sopra il nero di scena")
	if e.size() == prima + 1:
		assert_eq((e[-1] as Sprite2D).hframes, int(_fb("posture_break")["frames"]), "il foglio della postura")
		(e[-1] as Node).free()
	mondo.free()
