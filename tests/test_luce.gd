extends "res://tests/test_case.gd"
## US-8B25 — la luce del mondo (data/world/luce.json): di notte il mondo si scurisce, sotto terra no, le lucciole
## stanno sopra il buio.

const Luce := preload("res://scripts/world/luce.gd")
const Mondo := preload("res://scripts/world/mondo.gd")


func _root() -> Node:
	return Engine.get_main_loop().root


func test_il_colore_viene_dal_momento_e_dal_livello() -> void:
	var dati: Dictionary = _root().get_node("GameData").call("get_luce")
	var m: Node2D = Mondo.new()
	var l: CanvasModulate = Luce.new()
	l.set("_mondo", m)
	var ts: Node = _root().get_node("TimeSystem")
	ts.call("forza_momento", "notte_fonda")
	var notte := Color(str(dati["momenti"]["luminoso"]["notte_fonda"]))
	assert_eq(l.call("colore_voluto"), notte, "di notte il colore della notte")
	assert_true(notte.v < 0.7, "e la notte e' scura")
	ts.call("forza_momento", "mezzogiorno")
	assert_eq(l.call("colore_voluto"), Color.WHITE, "a mezzogiorno il mondo e' com'e'")
	ts.call("forza_momento", "notte_fonda")
	m.set("livello", "sottosuolo")
	assert_eq(l.call("colore_voluto"), Color(str(dati["sottosuolo"])), "sotto terra la luce del sottosuolo")
	ts.call("libera_momento")
	l.free()
	m.free()


func test_la_luce_passa_piano_da_un_momento_all_altro() -> void:
	var m: Node2D = Mondo.new()
	var l: CanvasModulate = Luce.new()
	l.set("_mondo", m)
	var ts: Node = _root().get_node("TimeSystem")
	ts.call("forza_momento", "mezzogiorno")
	l.color = Color.WHITE
	ts.call("forza_momento", "notte_fonda")
	l.call("_process", 0.1)
	var meta: Color = l.color
	assert_true(meta != Color.WHITE and meta != l.call("colore_voluto"), "a meta' strada dopo un attimo")
	for _i in 200:
		l.call("_process", 0.1)
	assert_true(l.color.is_equal_approx(l.call("colore_voluto")), "poi arriva")
	ts.call("libera_momento")
	l.free()
	m.free()


func test_le_lucciole_stanno_sopra_il_buio() -> void:
	var m: Node2D = Mondo.new()
	m.set("tema", "luminoso")
	assert_true(m.call("carica"), "mondo caricato")
	var f: Node = preload("res://scripts/world/fauna.gd").new()
	f.set("_mondo", m)
	var ts: Node = _root().get_node("TimeSystem")
	ts.call("forza_momento", "notte_fonda")
	var r: Array = (m.get("dati") as Dictionary)["riquadri"]["valle_madre"]
	for by in range(int(r[1]) / 16, int(r[3]) / 16, 3):
		for bx in range(int(r[0]) / 16, int(r[2]) / 16, 3):
			f.call("popola", Vector2i(bx, by))
	ts.call("libera_momento")
	var lucciole: Array = f.call("animali")
	assert_gt(lucciole.size(), 0, "di notte nella valle ci sono lucciole")
	assert_true(lucciole.all(func(a): return a.get_parent() is CanvasLayer), "su uno strato loro, non nel mondo")
	assert_true((lucciole[0].get_parent() as CanvasLayer).follow_viewport_enabled, "che segue la telecamera")
	f.free()
	m.free()


## US-8B27: di notte finestre e faro accesi, di giorno spenti; le case accese sono sempre le stesse.
func test_di_notte_finestre_e_faro_sono_accesi() -> void:
	var ts: Node = _root().get_node("TimeSystem")
	var main := Node2D.new()
	var m: Node2D = Mondo.new()
	main.add_child(m)
	_root().add_child(main)
	var luci: Node = m.get_node("LuciNotte")
	ts.call("forza_momento", "mezzogiorno")
	assert_eq(float(luci.call("forza_voluta")), 0.0, "di giorno le luci sono spente")
	ts.call("forza_momento", "notte_fonda")
	assert_eq(float(luci.call("forza_voluta")), 1.0, "di notte piene")
	var accese := 0
	var tot := 0
	for e in (m.get("dati") as Dictionary)["edifici"]:
		tot += 1
		if luci.call("accesa", int(e[0]), int(e[1])):
			accese += 1
		assert_eq(luci.call("accesa", int(e[0]), int(e[1])), luci.call("accesa", int(e[0]), int(e[1])), "sempre la stessa risposta")
	assert_true(accese > tot / 4 and accese < tot, "una parte delle case e' accesa (%d su %d)" % [accese, tot])
	var p: Vector2 = m.call("partenza")
	m.call("segui", p)
	var nel_mondo := 0
	for b in luci.get("_per_blocco"):
		nel_mondo += (luci.call("luci_del_blocco", b) as Array).size()
	assert_gt(float(nel_mondo), 0.0, "attorno alla casa al porto ci sono finestre accese")
	luci.call("_monta_faro")
	var faro: Node2D = luci.call("faro")
	assert_true(faro != null, "il faro ha la sua luce")
	if faro != null:
		var soglia: Node2D = m.get_node("Soglia_faro")
		assert_true(faro.position.y < soglia.position.y - 60.0, "in alto, alla lanterna")
		var prima: float = (faro.get_node("Fascio") as Node2D).rotation
		luci.call("_process", 1.0)
		assert_true((faro.get_node("Fascio") as Node2D).rotation > prima, "il fascio gira")
	ts.call("libera_momento")
	main.free()
