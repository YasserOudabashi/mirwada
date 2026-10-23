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


# --- US-8B12b: regione e zona dalla posizione ---------------------------------

func _ws() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("WorldState")


func _vai(m: Node2D, luogo: String, dx: float = 0.0, dy: float = 0.0) -> void:
	var p: Array = (m.dati["luoghi"] as Dictionary)[luogo]
	m.call("aggiorna_regione", Vector2((float(p[0]) + dx + 0.5) * m.tile, (float(p[1]) + dy + 0.5) * m.tile))


func test_la_regione_viene_dalla_posizione() -> void:
	var prima: Dictionary = _ws().call("per_salvataggio")
	var m: Node2D = _mondo()
	_vai(m, "porto")
	assert_eq(str(_ws().call("regione_corrente")), "mirwada", "al porto: Mirwada")
	assert_eq(str(_ws().call("zona_corrente")), "porto", "zona: il porto")
	_vai(m, "trono_del_gigante")
	assert_eq(str(_ws().call("regione_corrente")), "marche_crepuscolo", "al trono: le Marche")
	assert_eq(str(_ws().call("zona_corrente")), "trono_del_gigante", "zona: il trono")
	assert_true(_ws().call("e_scoperta", "marche_crepuscolo"), "le Marche risultano scoperte")
	_vai(m, "campo_di_battaglia")
	assert_eq(str(_ws().call("zona_corrente")), "luogo_di_battaglia", "luoghi_mondo abbina il nome della mappa al tag")
	_vai(m, "rovine_del_boss")
	assert_eq(str(_ws().call("regione_corrente")), "", "terra di mezzo: nessuna regione dei dati")
	assert_almost_eq(float(_ws().call("densita_mistica_corrente")), 0.2, "densita' di default fuori dalle regioni")
	m.free()
	_ws().call("pulisci")
	_ws().call("da_salvataggio", prima)


func test_lontano_dai_luoghi_la_zona_e_vuota() -> void:
	var prima: Dictionary = _ws().call("per_salvataggio")
	var m: Node2D = _mondo()
	_vai(m, "trono_del_gigante")
	_vai(m, "trono_del_gigante", 0.0, 60.0)
	assert_eq(str(_ws().call("regione_corrente")), "marche_crepuscolo", "ancora nelle Marche")
	assert_eq(str(_ws().call("zona_corrente")), "", "nessun luogo vicino")
	m.free()
	_ws().call("pulisci")
	_ws().call("da_salvataggio", prima)


# --- US-8B12c: main nel mondo unico, NPC e passaggi -----------------------------

func _pr() -> Node:
	return Engine.get_main_loop().root.get_node("Progression")


func test_gli_npc_stanno_al_luogo_del_loro_tag() -> void:
	var m: Node2D = _mondo()
	m.call("crea_npc")
	var presenti: Dictionary = Engine.get_main_loop().root.get_node("NpcSystem").call("presenti", "mirwada")
	assert_true(not presenti.is_empty(), "a Mirwada c'e' qualcuno in questo momento")
	var viste: Dictionary = {}
	for id in presenti:
		var a: Node2D = m.get_node_or_null("Npc_%s" % id)
		assert_true(a != null, "NPC %s nel mondo" % id)
		if a == null:
			continue
		var c: Vector2i = _cella(m, a.position)
		var l: Vector2i = m.call("luogo_del_tag", "mirwada", str(presenti[id]))
		assert_true(Vector2(c).distance_to(Vector2(l)) <= 12.0, "%s vicino al suo luogo" % id)
		assert_false(m.call("bloccata", c.x, c.y), "%s su una casella calpestabile" % id)
		assert_false(viste.has(c), "%s non sta sopra un altro NPC" % id)
		viste[c] = true
		assert_true(a.get_node("AnimationMachine").sprite_frames != null, "%s ha il disegno" % id)
	m.free()


func test_la_frontiera_respinge_chi_e_troppo_avanti() -> void:
	var prima: Dictionary = _pr().call("per_salvataggio")
	var m: Node2D = _mondo()
	_pr().call("configura", "twilight_giant", 2)
	assert_false(m.call("ingresso_aperto", "frontiera_porte"), "sopra la Sequenza 4 la Frontiera e' chiusa")
	var f: Array = (m.dati["luoghi"] as Dictionary)["approdo_frontiera"]
	assert_false(m.call("aggiorna_regione", Vector2((float(f[0]) + 0.5) * m.tile, (float(f[1]) + 0.5) * m.tile)),
		"entrare nella Frontiera e' respinto")
	assert_false(m.call("viaggia_a", "frontiera_porte"), "nemmeno col viaggio veloce")
	_pr().call("configura", "twilight_giant", 9)
	assert_true(m.call("ingresso_aperto", "frontiera_porte"), "alla Sequenza 9 si entra")
	assert_true(m.call("ingresso_aperto", "mirwada"), "Mirwada non ha gating d'ingresso")
	m.free()
	_ws().call("pulisci")
	_pr().call("da_salvataggio", prima)


func test_il_viaggio_veloce_porta_al_primo_luogo_della_regione() -> void:
	var prima: Dictionary = _ws().call("per_salvataggio")
	var m: Node2D = _mondo()
	var p := Node2D.new()
	p.add_to_group("player")
	m.add_child(p)
	Engine.get_main_loop().root.add_child(m)
	assert_true(m.call("viaggia_a", "marche_crepuscolo"), "si viaggia verso le Marche")
	var c: Vector2i = _cella(m, p.position)
	assert_eq(str(m.call("regione_a", c.x, c.y)), "marche_crepuscolo", "arrivato nelle Marche")
	assert_false(m.call("bloccata", c.x, c.y), "su una casella calpestabile")
	assert_eq(str(_ws().call("regione_corrente")), "marche_crepuscolo", "WorldState aggiornato")
	assert_false(m.call("viaggia_a", "marche_crepuscolo"), "gia' qui: niente viaggio")
	m.free()
	_ws().call("pulisci")
	_ws().call("da_salvataggio", prima)


func test_il_main_parte_dal_mondo_unico() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	var m: Node2D = main.get_node("Mondo")
	assert_true(m.get_script() == Mondo, "il main usa il mondo unico")
	assert_true(m.get_node_or_null("Player") != null, "il giocatore e' dentro il mondo (y_sort)")
	var e: Node2D = m.get_node("Enemy")
	m.call("carica")
	var c: Vector2i = _cella(m, e.position)
	assert_false(m.call("bloccata", c.x, c.y), "il nemico sta su una casella calpestabile")
	assert_eq(str(m.call("regione_a", c.x, c.y)), "mirwada", "il nemico e' a Mirwada, vicino alla partenza")
	main.free()
