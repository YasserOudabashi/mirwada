extends "res://tests/test_case.gd"
## US-8B20b — la base nel gioco: le stanze di una base (interni base_*.json "stanze") hanno gli arredi del livello
## costruito in BaseSystem; nelle basi che non sono la sede sono cantieri; dall'ingresso di un'altra base ci si sposta
## la base (nel salvataggio); stando in una stanza "interagisci" apre la pagina Base del libro.

const InteriorScene := preload("res://scenes/interior_scene.tscn")
const PageInventario := preload("res://scripts/pages/page_inventario.gd")


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func prepara() -> void:
	for a in ["/root/Inventory", "/root/BaseSystem"]:
		if _n(a) != null:
			_n(a).call("pulisci")
	if _n("/root/Book") != null:
		_n("/root/Book").call("azzera")
	PageInventario.prossima_sezione = ""


func _base(iid: String) -> TileMapLayer:
	var b: TileMapLayer = InteriorScene.instantiate()
	b.set("interno_id", iid)
	Engine.get_main_loop().root.add_child(b)
	return b


## Gli id degli arredi della stanza, in ordine di nome.
func _arredi(base: Node, tipo: String) -> Array:
	var ids: Array = []
	for c in base.get_children():
		if c.has_meta("stanza") and str(c.get_meta("stanza")) == tipo and not c.is_queued_for_deletion():
			ids.append(str(c.name).trim_prefix("Arredo_").rsplit("_", true, 2)[0])
	ids.sort()
	return ids


func _costruisci(tipo: String) -> void:
	var bs: Node = _n("/root/BaseSystem")
	var costo: Dictionary = bs.call("costo_prossimo", tipo)
	for item_id in costo:
		_n("/root/Inventory").call("aggiungi", item_id, int(costo[item_id]))
	assert_true(bool(bs.call("costruisci", tipo) if int(bs.call("livello", tipo)) == 0 else bs.call("potenzia", tipo)),
			"%s costruita o potenziata" % tipo)


func test_la_sede_iniziale_e_la_casa() -> void:
	assert_eq(str(_n("/root/BaseSystem").call("sede")), str(_n("/root/GameData").call("base_sede_iniziale")),
			"si comincia dalla base dei dati")
	assert_false(str(_n("/root/BaseSystem").call("sede")).is_empty(), "che c'e'")


func test_le_stanze_si_arredano_col_livello() -> void:
	var casa: TileMapLayer = _base("base_casa")
	var doc: Dictionary = _n("/root/GameData").call("get_interno", "base_casa")
	var livelli: Array = doc["stanze"]["laboratorio"]["livelli"]
	var attesi := func(lv: int) -> Array:
		var a: Array = (livelli[lv] as Array).map(func(v): return str(v["id"]))
		a.sort()
		return a
	assert_eq(_arredi(casa, "laboratorio"), attesi.call(0), "non costruita: il cantiere")
	_costruisci("laboratorio")
	assert_eq(_arredi(casa, "laboratorio"), attesi.call(1), "al livello 1 i suoi arredi")
	var c: Dictionary = (livelli[0] as Array)[0]
	assert_eq(casa.get_cell_atlas_coords(Vector2i(int(c["x"]), int(c["y"]))), Vector2i(0, 0),
			"dove stava il cantiere si torna a passare")
	_costruisci("laboratorio")
	assert_eq(_arredi(casa, "laboratorio"), attesi.call(2), "al livello 2 piu' arredata")
	assert_eq(_arredi(casa, "biblioteca"), ["cantiere"], "le altre stanze restano cantieri")
	casa.free()


func test_una_base_che_non_e_la_sede_ha_solo_cantieri() -> void:
	_costruisci("biblioteca")
	var capanna: TileMapLayer = _base("base_capanna")
	for tipo in (_n("/root/GameData").call("get_interno", "base_capanna")["stanze"] as Dictionary):
		assert_eq(_arredi(capanna, tipo), ["cantiere"], "%s: un cantiere" % tipo)
	capanna.free()


func test_dall_ingresso_si_sposta_la_base() -> void:
	var bs: Node = _n("/root/BaseSystem")
	_costruisci("biblioteca")
	var capanna: TileMapLayer = _base("base_capanna")
	var prompt: Label = capanna.get_node("Sposta_base/Prompt")
	capanna.set("_sposta_vicino", true)
	capanna.set("_stanza_vicina", "biblioteca")
	capanna.call("_aggiorna_prompt_base")
	assert_true(prompt.visible, "nell'ingresso di un'altra base si puo' spostarla qui")
	assert_false((capanna.get_node("Stanza_biblioteca/Prompt") as Label).visible, "le stanze di un'altra base non aprono la base")
	assert_true(bool(bs.call("sposta", "base_capanna")), "spostata")
	assert_eq(str(bs.call("sede")), "base_capanna", "la sede e' la capanna")
	assert_false(prompt.visible, "qui non serve piu' il prompt")
	assert_true((capanna.get_node("Stanza_biblioteca/Prompt") as Label).visible, "ora la biblioteca apre la base")
	assert_ne(_arredi(capanna, "biblioteca"), ["cantiere"], "la biblioteca costruita e' venuta con lei")
	assert_false(bool(bs.call("sposta", "base_capanna")), "gia' qui")
	assert_false(bool(bs.call("sposta", "mirwada_casa_di_lena")), "una casa qualunque non e' una base")
	var dati: Dictionary = bs.call("per_salvataggio")
	bs.call("pulisci")
	assert_eq(str(bs.call("sede")), "base_casa", "pulita torna alla sede iniziale")
	bs.call("da_salvataggio", dati)
	assert_eq(str(bs.call("sede")), "base_capanna", "la sede e' nel salvataggio")
	dati["sede"] = "mirwada_casa_di_lena"
	bs.call("da_salvataggio", dati)
	assert_eq(str(bs.call("sede")), "base_casa", "una sede che non e' una base si scarta")
	capanna.free()


func test_dalla_stanza_si_apre_la_pagina_base() -> void:
	var casa: TileMapLayer = _base("base_casa")
	var prompt: Label = casa.get_node("Stanza_laboratorio/Prompt")
	casa.set("_stanza_vicina", "laboratorio")
	casa.call("_aggiorna_prompt_base")
	assert_true(prompt.visible, "nella stanza il prompt della base")
	assert_false((casa.get_node("Stanza_biblioteca/Prompt") as Label).visible, "solo quello della stanza in cui si sta")
	assert_false((casa.get_node("Sposta_base/Prompt") as Label).visible, "la casa e' gia' la sede")
	assert_true(bool(casa.call("apri_base")), "il libro si apre")
	assert_true(bool(_n("/root/Book").call("e_aperto")), "aperto")
	assert_eq(str(_n("/root/Book").call("pagina_corrente")), "inventario", "sulla pagina dell'inventario")
	assert_eq(PageInventario.prossima_sezione, "base", "alla sezione Base")
	assert_false(bool(casa.call("apri_base")), "gia' aperto: niente")
	_n("/root/Book").call("azzera")
	PageInventario.prossima_sezione = ""
	casa.free()


## Le quattro basi hanno una porta nel mondo: la casa al porto di Mirwada, la capanna nella Valle, il rifugio nelle
## Marche, la passerella della nave ormeggiata al cantiere navale (US-8B20d).
func test_le_basi_hanno_una_porta_nel_mondo() -> void:
	var m: Node2D = preload("res://scripts/world/mondo.gd").new()
	m.set("tema", "luminoso")
	assert_true(m.call("carica"), "mondo caricato")
	m.call("crea_porte")
	m.call("crea_nave")
	var dati: Dictionary = m.get("dati")
	for coppia in [["base_casa", "casa_base_porto", "luoghi"], ["base_capanna", "capanna_base_valle", "villaggi"],
			["base_rifugio", "rifugio_base_marche", "villaggi"], ["base_nave", "cantiere_navale", "luoghi"]]:
		var porta: Node2D = m.get_node_or_null("Porta_" + coppia[0])
		assert_true(porta != null, "la porta di %s c'e'" % coppia[0])
		if porta == null:
			continue
		var p: Array = (dati[coppia[2]] as Dictionary)[coppia[1]]
		var vicino: float = porta.position.distance_to(Vector2(float(p[0]) + 0.5, float(p[1]) + 0.5) * m.tile)
		assert_true(vicino < 16.0 * m.tile, "%s vicino a %s (%.0f unita')" % [coppia[0], coppia[1], vicino])
	m.free()


## US-8B20d: la nave sta nell'acqua (tutte le sue caselle), la passerella su terra libera accanto.
func test_la_nave_e_ormeggiata_con_la_passerella() -> void:
	var m: Node2D = preload("res://scripts/world/mondo.gd").new()
	m.set("tema", "luminoso")
	assert_true(m.call("carica"), "mondo caricato")
	m.call("crea_nave")
	var nave: Sprite2D = m.get_node_or_null("Nave")
	var porta: Area2D = m.get_node_or_null("Porta_base_nave")
	assert_true(nave != null and porta != null, "la nave e la sua passerella")
	if nave == null or porta == null:
		m.free()
		return
	assert_true(nave.texture != null, "col suo disegno")
	var q := Vector2i(roundi(nave.position.x / m.tile), floori(nave.position.y / m.tile))
	for dy in [-1, 0]:
		for dx in range(-3, 3):
			assert_true(m.call("acqua", q.x + dx, q.y + dy), "la nave sta sull'acqua (%d, %d)" % [dx, dy])
	var p := Vector2i(floori(porta.position.x / m.tile), floori(porta.position.y / m.tile))
	assert_false(m.call("bloccata", p.x, p.y) or m.call("acqua", p.x, p.y), "la passerella sta su terra libera")
	assert_true(m.call("_a_terra", p), "collegata a piedi alla banchina, non un pontile chiuso")
	assert_true(absi(p.y - q.y) <= 2 and absi(p.x - q.x) <= 3, "accanto alla nave")
	assert_eq(str(porta.get_meta("interno_id")), "base_nave", "porta all'interno della nave")
	m.free()

