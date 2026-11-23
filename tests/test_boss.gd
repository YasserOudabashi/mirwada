extends "res://tests/test_case.gd"
## US-1505 — Un boss e' un dato (balance.json boss): vita moltiplicata, fasi a soglie di vita con la loro cfg e i
## gregari, l'arena che si chiude all'ingaggio e si riapre alla morte o alla fuga. Ogni boss sta in un layout.

func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")

var _madre: Node2D = null
var _player: Node2D = null


func _boss(id: String, tipo: String) -> Node:
	_madre = Node2D.new()
	_root().add_child(_madre)
	_player = Node2D.new()
	_player.add_to_group("player")
	_player.position = Vector2(60, 0)
	_madre.add_child(_player)
	var e: Node2D = preload("res://scenes/enemy.tscn").instantiate()
	e.set("tipo", tipo)
	_madre.add_child(e)
	e.get_node("StatsComponent").call("configure_from_balance", 7)
	var b: Node2D = preload("res://scripts/boss.gd").new()
	b.set("boss_id", id)
	e.add_child(b)
	b.set("_player", _player)
	return b


func _fine() -> void:
	for g in _root().get_tree().get_nodes_in_group("gregari"):
		g.free()
	_madre.free()


func test_le_fasi_cambiano_il_boss_e_chiamano_i_gregari() -> void:
	var dati: Dictionary = (_gd().call("get_balance", "boss") as Dictionary)["re_dei_ratti"]
	var b: Node = _boss("re_dei_ratti", "scaricatore_ubriaco")
	var e: Node = b.get_parent()
	var st: Node = e.get_node("StatsComponent")
	var base: float = float(_gd().call("curve_value", "hp_curve", 7, 100.0))
	assert_almost_eq(st.get_stat("hp_max"), base * float(dati["vita_x"]), "la vita e' moltiplicata", 0.01)
	assert_eq(str(e.call("nome")), str(_gd().call("tr_data", "boss.re_dei_ratti")), "il nome e' quello del boss")
	assert_eq(int(b.get("fase")), -1, "prima dell'arena nessuna fase")
	b.call("_chiudi")
	assert_eq(int(b.get("fase")), 0, "all'ingaggio la prima fase")
	st.set("hp", st.get_stat("hp_max") * 0.6)
	assert_eq(int(b.get("fase")), 1, "sotto i due terzi la seconda")
	assert_eq(_root().get_tree().get_nodes_in_group("gregari").size(), 3, "con i suoi gregari")
	assert_almost_eq(float((e.get("_cfg") as Dictionary)["recupero_s"]), 0.45, "e la sua cfg", 0.001)
	assert_eq(str(_root().get_tree().get_nodes_in_group("gregari")[0].get("tipo")), "ratto_delle_fogne", "del tipo dei dati")
	st.set("hp", st.get_stat("hp_max") * 0.1)
	assert_eq(int(b.get("fase")), 2, "un colpo grosso arriva all'ultima")
	assert_eq(int((e.get("_cfg") as Dictionary)["danno_attacco"]), 18, "che picchia piu' forte")
	assert_eq(_root().get_tree().get_nodes_in_group("gregari").size(), 7, "e chiama gli altri gregari")
	_fine()


func test_l_arena_non_si_lascia_e_si_riapre_alla_morte() -> void:
	var b: Node = _boss("custode_senza_nome", "custode_della_cripta")
	var e: Node2D = b.get_parent()
	var raggio: float = float(((b.get("dati") as Dictionary)["arena"] as Dictionary)["raggio"])
	b.call("_chiudi")
	assert_true(bool(b.get("arena_chiusa")), "chiusa all'ingaggio")
	_player.global_position = e.global_position + Vector2(raggio + 30.0, 0)
	b.call("_physics_process", 0.016)
	assert_almost_eq(_player.global_position.distance_to(e.global_position), raggio, "il bordo non si passa", 0.5)
	e.get_node("StatsComponent").set("hp", 0.0)
	assert_false(bool(b.get("arena_chiusa")), "si riapre alla morte del boss")
	_fine()


func test_l_arena_si_riapre_se_si_finisce_lontano() -> void:
	var b: Node = _boss("burattinaio", "burattinaio")
	var e: Node2D = b.get_parent()
	b.call("_chiudi")
	assert_eq(_root().get_tree().get_nodes_in_group("gregari").size(), 2, "il Burattinaio ha gregari gia' nella prima fase")
	_player.global_position = e.global_position + Vector2(5000, 0)       # una porta, un teletrasporto
	b.call("_physics_process", 0.016)
	assert_false(bool(b.get("arena_chiusa")), "lontano: l'arena si riapre")
	_fine()


func test_ogni_boss_sta_in_un_layout_e_ha_tre_o_quattro_fasi() -> void:
	var boss: Dictionary = _gd().call("get_balance", "boss")
	var posati: Dictionary = {}
	for reg in _gd().call("get_regions"):
		for n in (_gd().call("get_layout", str((reg as Dictionary)["id"])) as Dictionary).get("nemici", []):
			if (n as Dictionary).has("boss"):
				posati[str(n["boss"])] = int(posati.get(str(n["boss"]), 0)) + 1
	var n_boss := 0
	for id in boss:
		if str(id).begins_with("_"):
			continue
		n_boss += 1
		assert_eq(int(posati.get(id, 0)), 1, "%s e' posato una volta" % id)
		var nf: int = ((boss[id] as Dictionary)["fasi"] as Array).size()
		assert_true(nf == 3 or nf == 4, "%s ha 3 o 4 fasi (%d)" % [id, nf])
	assert_eq(n_boss, 6, "i sei boss decisi dall'utente")


func test_un_boss_battuto_non_torna() -> void:
	var Boss: GDScript = preload("res://scripts/boss.gd")
	var ws: Node = _root().get_node("WorldState")
	var spec := {"tipo": "burattinaio", "boss": "burattinaio"}
	var prima: bool = bool(ws.call("preso", "boss:burattinaio"))
	assert_false(bool(Boss.call("vinto", {"tipo": "burattinaio"})), "un nemico senza boss non e' mai vinto")
	var b: Node = _boss("burattinaio", "burattinaio")
	b.get_parent().get_node("StatsComponent").set("hp", 0.0)
	assert_true(bool(Boss.call("vinto", spec)), "morto, WorldState lo ricorda e il mondo non lo rimette")
	if not prima:
		(ws.get("_presi") as Array).erase("boss:burattinaio")
	_fine()
