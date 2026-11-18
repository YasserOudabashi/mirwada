extends "res://tests/test_case.gd"
## US-8C02 — attacco pesante caricato: tenendo premuto il tasto l'animazione si ferma sul frame della carica, la
## carica cresce fino al massimo, al rilascio il colpo riparte; danno e area crescono con la carica
## (data/balance.json combattimento.attacco_pesante).


func _root() -> Node:
	return Engine.get_main_loop().root


func _player() -> CharacterBody2D:
	var p: CharacterBody2D = preload("res://scenes/player.tscn").instantiate()
	_root().add_child(p)
	return p


func _numeri() -> Dictionary:
	return (_root().get_node("GameData").call("get_balance", "combattimento") as Dictionary)["attacco_pesante"]


func test_tenere_premuto_ferma_sul_frame_della_carica_e_carica() -> void:
	var p := _player()
	var anim: AnimatedSprite2D = p.get_node("AnimationMachine")
	p.call("inizia_pesante")
	assert_eq(str(anim.call("stato_corrente")), "attack_heavy", "parte l'attacco pesante")
	anim.frame = int(_numeri()["frame_carica"])
	p.call("_tieni_carica", 0.5, true)
	assert_false(anim.is_playing(), "tenuto: l'animazione resta ferma sulla carica")
	assert_almost_eq(float(p.call("carica_pesante")), 0.5 / float(_numeri()["carica_max_s"]), "la carica cresce col tempo")
	p.call("_tieni_carica", 10.0, true)
	assert_almost_eq(float(p.call("carica_pesante")), 1.0, "non va oltre il massimo")
	p.call("_tieni_carica", 0.1, false)
	assert_true(anim.is_playing(), "rilasciato: il colpo riparte")
	p.free()


func test_piu_carica_piu_danno_e_area() -> void:
	var p := _player()
	var hb: Area2D = p.get_node("Hitbox")
	var n := _numeri()
	p.call("inizia_pesante")
	p.call("_su_evento_anim", "hitbox_on")
	var danno_scarico: float = float(hb.get("_danno"))
	assert_almost_eq(danno_scarico, float(n["danno"]), "senza carica: il danno di base")
	p.call("_su_evento_anim", "hitbox_off")
	p.get_node("AnimationMachine").frame = int(n["frame_carica"])
	p.call("_tieni_carica", 99.0, true)
	p.call("_su_evento_anim", "hitbox_on")
	assert_almost_eq(float(hb.get("_danno")), float(n["danno"]) * float(n["danno_x"]), "carica piena: danno x danno_x")
	p.get_node("AnimationMachine").animazione_finita.emit("attack_heavy")
	assert_false(bool(p.call("sta_attaccando")), "finita l'animazione si puo' attaccare di nuovo")
	assert_almost_eq(float(p.call("carica_pesante")), 0.0, "la carica si azzera")
	p.free()
