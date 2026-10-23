extends "res://tests/test_case.gd"
## US-8B12 — mondo unico: carica assets/world/ (tools/art/esporta_mondo.py) e
## costruisce solo i blocchi attorno al giocatore.

const Mondo := preload("res://scripts/world/mondo.gd")


func _mondo(tema: String = "luminoso") -> Node2D:
	var m: Node2D = Mondo.new()
	m.tema = tema
	assert_true(m.call("carica"), "mondo caricato")
	return m


func _cella(m: Node2D, p: Vector2) -> Vector2i:
	return Vector2i(int(p.x / m.tile), int(p.y / m.tile))


func test_carica_le_misure_e_la_partenza() -> void:
	var m: Node2D = _mondo()
	assert_eq(m.larghezza, 1200, "larghezza dai dati")
	assert_eq(m.altezza, 1000, "altezza dai dati")
	var c: Vector2i = _cella(m, m.call("partenza"))
	assert_false(m.call("bloccata", c.x, c.y), "la partenza e' calpestabile")
	assert_eq(str(m.call("regione_a", c.x, c.y)), "mirwada", "si parte a Mirwada")
	m.free()


func test_il_mare_aperto_e_il_fuori_mappa_non_si_passano() -> void:
	var m: Node2D = _mondo()
	assert_true(m.call("bloccata", 1199, 999), "mare aperto nell'angolo")
	assert_true(m.call("bloccata", -1, 5), "fuori mappa")
	m.free()


func test_costruisce_solo_attorno_al_giocatore() -> void:
	var m: Node2D = _mondo()
	var p: Vector2 = m.call("partenza")
	m.call("segui", p)
	var lato: int = 2 * int(m.raggio_blocchi) + 1
	assert_eq(int(m.call("blocchi_caricati")), lato * lato, "blocchi attorno al giocatore")
	var terreno: TileMapLayer = m.get_node("Terreno")
	var c: Vector2i = _cella(m, p)
	assert_true(terreno.get_cell_source_id(c) >= 0, "la casella della partenza ha la sua tessera")
	assert_eq(terreno.get_cell_source_id(Vector2i(c.x + 200, c.y)), -1, "lontano non c'e' niente")
	m.call("segui", p + Vector2(200, 0) * m.tile)
	assert_eq(terreno.get_cell_source_id(c), -1, "spostandosi lontano il vecchio pezzo si libera")
	assert_eq(int(m.call("blocchi_caricati")), lato * lato, "sempre lo stesso numero di blocchi")
	m.free()


func test_le_caselle_bloccate_hanno_la_collisione() -> void:
	var m: Node2D = _mondo()
	var p: Vector2 = m.call("partenza")
	m.call("segui", p)
	var ost: TileMapLayer = m.get_node("Ostacoli")
	var c: Vector2i = _cella(m, p)
	var trovate: int = 0
	for y in range(c.y - 30, c.y + 30):
		for x in range(c.x - 30, c.x + 30):
			assert_eq(ost.get_cell_source_id(Vector2i(x, y)) >= 0, bool(m.call("bloccata", x, y)),
				"ostacolo dove i dati dicono bloccato (%d, %d)" % [x, y])
			if m.call("bloccata", x, y):
				trovate += 1
	assert_true(trovate > 0, "attorno al porto c'e' qualcosa che non si passa (il mare)")
	m.free()


func test_gli_oggetti_arrivano_col_loro_blocco() -> void:
	var m: Node2D = _mondo()
	var t: Array = (m.dati["luoghi"] as Dictionary)["trono_del_gigante"]
	m.call("segui", Vector2(float(t[0]) * m.tile, float(t[1]) * m.tile))
	var trono: int = 0
	for c in m.get_children():
		if c is Sprite2D and (c as Sprite2D).texture != null and (c as Sprite2D).position.distance_to(
				Vector2(float(t[0]) + 0.5, float(t[1]) + 0.2) * m.tile) < 1.0:
			trono += 1
	assert_eq(trono, 1, "il trono sulla vetta")
	m.free()


func test_la_modalita_cupa_usa_i_suoi_fogli() -> void:
	var lum: Node2D = _mondo("luminoso")
	var cup: Node2D = _mondo("cupo")
	assert_eq(str(cup.call("tema_caricato")), "cupo", "tema cupo")
	var p: Vector2 = lum.call("partenza")
	lum.call("segui", p)
	cup.call("segui", p)
	var c: Vector2i = _cella(lum, p)
	var a: TileSetAtlasSource = lum.get_node("Terreno").tile_set.get_source(0)
	var b: TileSetAtlasSource = cup.get_node("Terreno").tile_set.get_source(0)
	assert_true(a.texture != b.texture and a.texture.get_image().get_data() != b.texture.get_image().get_data(),
		"fogli diversi")
	assert_eq(lum.call("bloccata", c.x, c.y), cup.call("bloccata", c.x, c.y), "stessi dati di gioco")
	lum.free()
	cup.free()
