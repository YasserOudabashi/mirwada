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


# --- US-8B23b: nel gioco (data/world/fauna.json, scripts/world/fauna.gd) ------------------------------------------

const Mondo := preload("res://scripts/world/mondo.gd")
const Fauna := preload("res://scripts/world/fauna.gd")


func _mondo() -> Node2D:
	var m: Node2D = Mondo.new()
	m.set("tema", "luminoso")
	assert_true(m.call("carica"), "mondo caricato")
	return m


## Popola i blocchi del riquadro di una regione (al momento dato) e rende gli animali.
func _popola(m: Node2D, f: Node, rid: String, momento: String) -> Array:
	var ts: Node = _root().get_node("TimeSystem")
	ts.call("forza_momento", momento)
	var r: Array = (m.get("dati") as Dictionary)["riquadri"][rid]
	for by in range(int(r[1]) / 16, int(r[3]) / 16, 3):
		for bx in range(int(r[0]) / 16, int(r[2]) / 16, 3):
			f.call("popola", Vector2i(bx, by))
	ts.call("libera_momento")
	return f.call("animali")


func test_gli_animali_rispettano_regioni_momenti_e_caselle_libere() -> void:
	var m := _mondo()
	var f: Node = Fauna.new()
	f.set("_mondo", m)
	var specie: Dictionary = _root().get_node("GameData").call("get_fauna")
	var giorno: Array = _popola(m, f, "valle_madre", "mezzogiorno")
	assert_gt(giorno.size(), 10, "nella valle di giorno ci sono animali")
	var visti: Dictionary = {}
	for a in giorno:
		var sid: String = str(a.get_meta("specie"))
		visti[sid] = true
		var c := Vector2i(floori(a.position.x / m.tile), floori(a.position.y / m.tile))
		assert_false(bool(m.call("bloccata", c.x, c.y)), "%s su una casella libera" % sid)
		assert_true("mezzogiorno" in (specie[sid]["momenti"] as Array), "%s e' un animale del giorno" % sid)
		assert_true(str(m.call("regione_a", c.x, c.y)) in (specie[sid]["regioni"] as Array), "%s nella sua regione" % sid)
	assert_false(visti.has("lucciola"), "di giorno niente lucciole")
	assert_true(visti.has("uccello") and visti.has("cervo"), "uccelli e cervi nella valle")
	var prima: Array = giorno.map(func(a): return [a.get_meta("specie"), a.position])
	for b in (f.get("_animali") as Dictionary).keys():
		f.call("togli", b)
	var di_nuovo: Array = _popola(m, f, "valle_madre", "mezzogiorno").map(func(a): return [a.get_meta("specie"), a.position])
	assert_eq(di_nuovo, prima, "tornando: gli stessi animali negli stessi posti")
	for b in (f.get("_animali") as Dictionary).keys():
		f.call("togli", b)
	var notte: Array = _popola(m, f, "valle_madre", "notte_fonda")
	assert_true(notte.size() > 0 and notte.all(func(a): return a.get_meta("specie") == "lucciola"), "di notte solo lucciole")
	for b in (f.get("_animali") as Dictionary).keys():
		f.call("togli", b)
	var cervi_in_citta: Array = _popola(m, f, "mirwada", "mezzogiorno").filter(func(a): return a.get_meta("specie") == "cervo" \
			and m.call("regione_a", floori(a.position.x / m.tile), floori(a.position.y / m.tile)) == "mirwada")
	assert_eq(cervi_in_citta.size(), 0, "in citta' niente cervi")
	f.free()
	m.free()


func test_chi_si_avvicina_li_fa_scappare() -> void:
	var m := _mondo()
	var f: Node = Fauna.new()
	f.set("_mondo", m)
	_root().add_child(f)
	var animali: Array = _popola(m, f, "valle_madre", "mezzogiorno")
	var uccello: AnimatedSprite2D = animali.filter(func(a): return a.get_meta("specie") == "uccello")[0]
	var cervo: AnimatedSprite2D = animali.filter(func(a): return a.get_meta("specie") == "cervo")[0]
	var p := Node2D.new()
	p.add_to_group("player")
	_root().add_child(p)
	p.position = uccello.position + Vector2(20, 20)
	var dove: Vector2 = uccello.position
	f.call("_process", 0.1)
	assert_ne(uccello.get_meta("fuga"), Vector2.ZERO, "l'uccello vicino scappa")
	assert_eq(str(uccello.call("stato_corrente")), "fuga", "e vola")
	f.call("_process", 0.3)
	assert_true(uccello.position.y < dove.y, "verso nord")
	assert_gt(uccello.position.distance_to(p.position), dove.distance_to(p.position), "lontano da chi arriva")
	assert_eq(cervo.get_meta("fuga"), Vector2.ZERO, "il cervo lontano resta a brucare")
	for _i in 30:
		f.call("_process", 0.1)
	assert_true(uccello.is_queued_for_deletion(), "svanito, se ne va")
	p.free()
	f.free()
	m.free()


func test_a_notte_arrivano_le_lucciole() -> void:
	var m := _mondo()
	var f: Node = Fauna.new()
	f.set("_mondo", m)
	var giorno: Array = _popola(m, f, "valle_madre", "mezzogiorno")
	f.call("_su_momento", "notte_fonda")
	assert_true(giorno.all(func(a): return a.get_meta("fuga") != Vector2.ZERO), "gli animali del giorno se ne vanno")
	var lucciole: Array = (f.call("animali") as Array).filter(func(a): return a.get_meta("specie") == "lucciola")
	assert_gt(lucciole.size(), 0, "e arrivano le lucciole")
	f.free()
	m.free()
