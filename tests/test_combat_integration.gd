extends "res://tests/test_case.gd"
## US-218B — integrazione combat: il tag di danno lungo la pipeline e il tiro
## di schivata/precisione.

const Hurtbox := preload("res://scripts/hurtbox.gd")
const Hitbox := preload("res://scripts/hitbox.gd")
const Stats := preload("res://scripts/stats_component.gd")


func _bersaglio(evasione: float) -> Dictionary:
	var host := Node2D.new()
	var s: Node = Stats.new()
	s.name = "StatsComponent"
	host.add_child(s)
	var hb: Area2D = Hurtbox.new()
	host.add_child(hb)
	Engine.get_main_loop().root.add_child(host)
	s.call("configure_from_balance", 9)
	if evasione != 0.0:
		s.call("apply_modifier", "test:evasione", {"evasione": evasione})
	# rng deterministico
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	hb.call("set_rng", rng)
	return {"host": host, "stats": s, "hurtbox": hb}


func _attaccante(precisione: float) -> Node:
	var a := Node2D.new()
	var s: Node = Stats.new()
	s.name = "StatsComponent"
	a.add_child(s)
	Engine.get_main_loop().root.add_child(a)
	s.call("configure_from_balance", 9)
	if precisione != 0.0:
		s.call("apply_modifier", "test:precisione", {"precisione": precisione})
	return a


func test_lo_scudo_blocca_solo_i_tag_elencati() -> void:
	var e: Dictionary = _bersaglio(0.0)
	var s: Node = e["stats"]
	s.call("aggiungi_scudo", 100.0, 0.0, ["fisico"])
	var hp0: float = float(s.get("hp"))

	e["hurtbox"].subisci(30.0, 0.0, null, {"tag_danno": "fisico"})
	assert_almost_eq(float(s.get("hp")), hp0, "danno fisico assorbito dallo scudo (tag_bloccati)")

	e["hurtbox"].subisci(30.0, 0.0, null, {"tag_danno": "luce"})
	assert_almost_eq(float(s.get("hp")), hp0 - 30.0, "danno luce NON bloccato: passa agli hp")
	e["host"].free()


func test_alta_evasione_fa_mancare_molti_colpi() -> void:
	var e: Dictionary = _bersaglio(0.6)  # evasione 0.6
	# le lambda catturano le locali PER VALORE: si raccoglie in un Dictionary.
	var conta := {"schivati": 0}
	e["hurtbox"].schivato.connect(func(_da: Node) -> void: conta["schivati"] += 1)
	var s: Node = e["stats"]
	for i in 200:
		s.set("hp", 100.0)
		e["hurtbox"].subisci(10.0, 0.0, null, {"tag_danno": "fisico"})
	# prob ~0.6 su 200 -> attorno a 120, largamente > 0 e < 200
	assert_gt(float(conta["schivati"]), 60.0, "molti colpi mancati con evasione 0.6")
	assert_true(conta["schivati"] < 200, "non tutti (prob < 1)")
	e["host"].free()


func test_precisione_alta_annulla_l_evasione() -> void:
	var e: Dictionary = _bersaglio(0.5)   # evasione 0.5
	var att: Node = _attaccante(0.9)      # precisione 0.9
	var conta := {"schivati": 0}
	e["hurtbox"].schivato.connect(func(_da: Node) -> void: conta["schivati"] += 1)
	var s: Node = e["stats"]
	for i in 100:
		s.set("hp", 100.0)
		e["hurtbox"].subisci(10.0, 0.0, att, {"tag_danno": "fisico"})
	assert_eq(conta["schivati"], 0, "prob = clamp(0.5 - 0.9, 0, cap) = 0: nessuna schivata")
	att.free()
	e["host"].free()


func test_damage_dealt_emesso_col_tag_dal_player() -> void:
	var et: Node = Engine.get_main_loop().root.get_node_or_null("EventTracker")
	et.call("azzera")
	var player: Node = preload("res://scripts/player.gd").new()
	player.call("_su_colpo_inflitto", null, 12.0, "fisico")
	assert_almost_eq(et.call("count", "damage_dealt", {"tag_danno": "fisico"}), 12.0,
		"damage_dealt contato col filtro tag_danno")
	assert_almost_eq(et.call("count", "damage_dealt", {"tag_danno": "luce"}), 0.0,
		"non conta sotto un altro tag")
	player.free()
