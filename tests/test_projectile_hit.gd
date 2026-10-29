extends "res://tests/test_case.gd"
## US-803 — projectile.gd e melee_arc.gd colpiscono davvero: stessa firma di
## subisci() gia' usata da hitbox.gd, un bersaglio una sola volta, la
## hurtbox del caster esclusa, il pierce rispettato, l'arco filtra per
## angolo. _su_area_entrata e' chiamato direttamente (come dentro_arco/
## colpi_residui in test_ability_engine.gd): l'overlap fisico vero lo
## verifica il motore, non serve un tick di fisica per provare la logica.

const Projectile := preload("res://scripts/projectile.gd")
const MeleeArc := preload("res://scripts/melee_arc.gd")
const Hurtbox := preload("res://scripts/hurtbox.gd")


## Un bersaglio minimo: un host con una sola Hurtbox figlia, nessuno
## StatsComponent (subisci() salta evasione/scudo/postura se non lo trova:
## il colpo arriva sempre, deterministico, niente RNG da seedare).
func _bersaglio() -> Dictionary:
	var host := Node2D.new()
	var hb: Area2D = Hurtbox.new()
	host.add_child(hb)
	Engine.get_main_loop().root.add_child(host)
	return {"host": host, "hurtbox": hb}


func test_projectile_colpisce_una_hurtbox_col_tag_della_primitiva() -> void:
	var b: Dictionary = _bersaglio()
	var colpi := {"n": 0, "tag": ""}
	b["hurtbox"].colpito.connect(func(_d, _s, _da, tag): colpi["n"] += 1; colpi["tag"] = tag)

	var p: Area2D = Projectile.new()
	p.setup({"danno": 10.0, "tag_danno": "spirito"}, Vector2.ZERO, Vector2.RIGHT)
	Engine.get_main_loop().root.add_child(p)
	p.call("_su_area_entrata", b["hurtbox"])

	assert_eq(colpi["n"], 1, "un colpo registrato")
	assert_eq(colpi["tag"], "spirito", "il tag della primitiva arriva a subisci()")

	p.free()
	b["host"].free()


func test_projectile_non_colpisce_due_volte_lo_stesso_bersaglio() -> void:
	var b: Dictionary = _bersaglio()
	var n := {"v": 0}
	b["hurtbox"].colpito.connect(func(_d, _s, _da, _t): n["v"] += 1)

	var p: Area2D = Projectile.new()
	p.setup({"danno": 5.0}, Vector2.ZERO, Vector2.RIGHT)
	Engine.get_main_loop().root.add_child(p)
	p.call("_su_area_entrata", b["hurtbox"])
	p.call("_su_area_entrata", b["hurtbox"])

	assert_eq(n["v"], 1, "lo stesso bersaglio e' colpito una volta sola (registra_colpo)")
	p.free()
	b["host"].free()


func test_projectile_con_pierce_attraversa_n_bersagli_poi_si_libera() -> void:
	var p: Area2D = Projectile.new()
	p.setup({"danno": 5.0, "pierce": 2}, Vector2.ZERO, Vector2.RIGHT)
	Engine.get_main_loop().root.add_child(p)

	var bersagli: Array = []
	for i in 2:
		var b: Dictionary = _bersaglio()
		bersagli.append(b)
		p.call("_su_area_entrata", b["hurtbox"])
		assert_false(p.is_queued_for_deletion(), "ancora colpi residui dopo il bersaglio %d" % i)

	var ultimo: Dictionary = _bersaglio()
	bersagli.append(ultimo)
	p.call("_su_area_entrata", ultimo["hurtbox"])
	assert_true(p.is_queued_for_deletion(), "pierce 2 = 3 colpi totali, poi si libera")

	for b in bersagli:
		b["host"].free()


func test_projectile_non_colpisce_la_hurtbox_del_caster() -> void:
	var caster := Node2D.new()
	var hb_caster: Area2D = Hurtbox.new()
	caster.add_child(hb_caster)
	Engine.get_main_loop().root.add_child(caster)
	var n := {"v": 0}
	hb_caster.colpito.connect(func(_d, _s, _da, _t): n["v"] += 1)

	var p: Area2D = Projectile.new()
	p.setup({"danno": 5.0}, Vector2.ZERO, Vector2.RIGHT, caster)
	Engine.get_main_loop().root.add_child(p)
	p.call("_su_area_entrata", hb_caster)

	assert_eq(n["v"], 0, "la propria hurtbox non viene colpita")
	p.free()
	caster.free()


func test_melee_arc_colpisce_solo_dentro_l_angolo() -> void:
	var arc: Area2D = MeleeArc.new()
	arc.setup({"danno": 8.0, "angolo": 90.0, "raggio": 40.0, "tag_danno": "fisico"}, Vector2.RIGHT)
	Engine.get_main_loop().root.add_child(arc)

	var davanti: Dictionary = _bersaglio()
	davanti["host"].global_position = Vector2(20, 0)
	var dietro: Dictionary = _bersaglio()
	dietro["host"].global_position = Vector2(-20, 0)

	var colpi := {"n": 0}
	davanti["hurtbox"].colpito.connect(func(_d, _s, _da, _t): colpi["n"] += 1)
	dietro["hurtbox"].colpito.connect(func(_d, _s, _da, _t): colpi["n"] += 1)

	arc.call("_su_area_entrata", davanti["hurtbox"])
	arc.call("_su_area_entrata", dietro["hurtbox"])

	assert_eq(colpi["n"], 1, "solo il bersaglio dentro l'angolo (davanti) viene colpito")

	arc.free()
	davanti["host"].free()
	dietro["host"].free()
