extends "res://tests/test_case.gd"
## US-8B20c — l'orto fuori dalla sede della base: il cantiere finche' il giardino non c'e', poi un appezzamento per
## ogni appezzamento del giardino col disegno della sua crescita; vicino alla porta della sede, su caselle libere e
## visibili; si sposta con la sede; vicino all'orto "interagisci" apre la pagina Base.

const Mondo := preload("res://scripts/world/mondo.gd")
const BaseFuori := preload("res://scripts/world/base_fuori.gd")
const PageInventario := preload("res://scripts/pages/page_inventario.gd")


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func prepara() -> void:
	for a in ["/root/Inventory", "/root/BaseSystem", "/root/StructureRegistry"]:
		if _n(a) != null:
			_n(a).call("pulisci")
	if _n("/root/Book") != null:
		_n("/root/Book").call("azzera")
	PageInventario.prossima_sezione = ""


## Il mondo nella scena (il suo _ready mette le porte e l'orto) e il suo orto.
func _mondo() -> Array:
	var m: Node2D = Mondo.new()
	m.set("tema", "luminoso")
	assert_true(m.call("carica"), "mondo caricato")
	Engine.get_main_loop().root.add_child(m)
	var fuori: Node2D = m.get_node("BaseFuori")
	assert_eq(fuori.get_script(), BaseFuori, "il mondo ha l'orto della base")
	return [m, fuori]


func _disegni(fuori: Node, prefisso: String = "Orto_") -> Array:
	var ids: Array = []
	for c in fuori.get_children():
		if c is Sprite2D and not c.is_queued_for_deletion() and str(c.name).begins_with(prefisso):
			ids.append(str(c.name).trim_prefix(prefisso).rsplit("_", true, 2)[0])
	return ids


func _costruisci_struttura(sid: String) -> void:
	var costo: Dictionary = _n("/root/GameData").call("get_structure", sid)["costo"]
	for item_id in costo:
		_n("/root/Inventory").call("aggiungi", item_id, int(costo[item_id]))
	assert_true(bool(_n("/root/BaseSystem").call("costruisci_struttura", sid)), "%s costruita" % sid)


func _costruisci_giardino() -> void:
	var bs: Node = _n("/root/BaseSystem")
	var costo: Dictionary = bs.call("costo_prossimo", "giardino")
	for item_id in costo:
		_n("/root/Inventory").call("aggiungi", item_id, int(costo[item_id]))
	assert_true(bool(bs.call("costruisci", "giardino") if int(bs.call("livello", "giardino")) == 0
			else bs.call("potenzia", "giardino")), "giardino costruito o potenziato")


func _coltivabile() -> String:
	for it in _n("/root/GameData").call("items_per_categoria", "ingrediente"):
		if bool((it as Dictionary).get("coltivabile", false)):
			return str((it as Dictionary)["id"])
	return ""


func test_l_orto_cresce_fuori_dalla_sede() -> void:
	var mf: Array = _mondo()
	var m: Node2D = mf[0]
	var fuori: Node2D = mf[1]
	var c: Vector2i = fuori.call("cella_orto")
	var porta: Node2D = m.get_node("Porta_base_casa")
	var p := Vector2i(int(porta.position.x / m.tile), int(porta.position.y / m.tile))
	assert_true(c.x >= 0, "l'orto ha un posto")
	assert_true(Vector2(c).distance_to(Vector2(p)) < 8.0, "vicino alla porta della casa base (%s, porta %s)" % [c, p])
	for i in 2:
		for dy in 4:
			assert_false(m.call("bloccata", c.x + i, c.y + dy), "casella %d libera e non sotto un tetto" % i)
	assert_eq(_disegni(fuori), ["cantiere"], "senza giardino il cantiere")
	_costruisci_giardino()
	assert_eq(_disegni(fuori), ["orto_vuoto"], "giardino al livello 1: un appezzamento vuoto")
	var seme: String = _coltivabile()
	_n("/root/Inventory").call("aggiungi", seme, 1)
	assert_eq(int(_n("/root/BaseSystem").call("pianta", seme)), 0, "piantato")
	fuori.call("disegna")
	assert_eq(_disegni(fuori), ["orto_germoglio"], "appena piantato: il germoglio")
	var t: float = float(_n("/root/GameData").call("get_balance", "giardino")["tempo_crescita_s"])
	_n("/root/BaseSystem").call("_process", t * 0.6)
	fuori.call("disegna")
	assert_eq(_disegni(fuori), ["orto_pianta"], "oltre pianta_da: la pianta")
	_n("/root/BaseSystem").call("_process", t)
	assert_eq(_disegni(fuori), ["orto_maturo"], "pronto: maturo (si ridisegna da solo)")
	_costruisci_giardino()
	var due: Array = _disegni(fuori)
	due.sort()
	assert_eq(due, ["orto_maturo", "orto_vuoto"], "al livello 2 un appezzamento in piu' accanto")
	assert_eq(fuori.call("cella_orto"), c, "l'orto non si sposta potenziando")
	m.free()


func test_l_orto_va_con_la_sede() -> void:
	var mf: Array = _mondo()
	var m: Node2D = mf[0]
	var fuori: Node2D = mf[1]
	assert_true(bool(_n("/root/BaseSystem").call("sposta", "base_capanna")), "base spostata nella Valle")
	var porta: Node2D = m.get_node("Porta_base_capanna")
	var c: Vector2i = fuori.call("cella_orto")
	assert_true(Vector2(c).distance_to(porta.position / m.tile) < 8.0, "l'orto ora sta vicino alla capanna")
	assert_eq(str(m.call("regione_a", c.x, c.y)), str(m.call("regione_a", int(porta.position.x / m.tile),
			int(porta.position.y / m.tile))), "nella stessa regione")
	assert_true(bool(_n("/root/BaseSystem").call("sposta", "base_nave")), "base spostata sulla nave")
	if m.get_node_or_null("Porta_base_nave") == null:
		assert_eq((fuori.call("cella_orto") as Vector2i).x, -1, "una sede senza porta nel mondo non ha l'orto")
		assert_eq(_disegni(fuori), [], "ne' disegni")
		assert_true(fuori.get_node_or_null("Orto") == null, "ne' prompt")
	m.free()


func test_vicino_all_orto_si_apre_la_pagina_base() -> void:
	var mf: Array = _mondo()
	var m: Node2D = mf[0]
	var fuori: Node2D = mf[1]
	var prompt: Label = fuori.get_node("Orto/Prompt")
	assert_false(prompt.visible, "lontano niente prompt")
	assert_true(bool(fuori.call("apri_base")), "il libro si apre")
	assert_eq(str(_n("/root/Book").call("pagina_corrente")), "inventario", "sull'inventario")
	assert_eq(PageInventario.prossima_sezione, "base", "alla sezione Base")
	_n("/root/Book").call("azzera")
	PageInventario.prossima_sezione = ""
	m.free()


# --- US-8B20e: le strutture ---------------------------------------------------------

func test_una_struttura_per_tipo_col_suo_costo() -> void:
	var bs: Node = _n("/root/BaseSystem")
	assert_false(bool(bs.call("costruisci_struttura", "palizzata")), "senza materiali no")
	assert_false(bool(bs.call("costruisci_struttura", "torre_inventata")), "un tipo che non c'e' no")
	_costruisci_struttura("palizzata")
	assert_eq(int(_n("/root/Inventory").call("conta", "lingotto_ferro")), 0, "il costo si paga")
	_n("/root/Inventory").call("aggiungi", "lingotto_ferro", 9)
	_n("/root/Inventory").call("aggiungi", "moneta_comune", 99)
	assert_false(bool(bs.call("costruisci_struttura", "palizzata")), "una sola per tipo")
	assert_eq(int(_n("/root/StructureRegistry").call("conta")), 1, "nel registro una")


func test_le_strutture_stanno_fuori_dalla_sede_e_la_seguono() -> void:
	var mf: Array = _mondo()
	var m: Node2D = mf[0]
	var fuori: Node2D = mf[1]
	for sid in ["palizzata", "totem_veglia", "deposito"]:
		_costruisci_struttura(sid)
	var disegni: Array = _disegni(fuori, "Struttura_")
	disegni.sort()
	assert_eq(disegni, ["deposito", "palizzata", "totem_veglia"], "tutte e tre disegnate")
	var prese: Dictionary = {}
	var orto: Vector2i = fuori.call("cella_orto")
	for i in 2:
		prese[orto + Vector2i(i, 0)] = "giardino"
	var porta: Node2D = m.get_node("Porta_base_casa")
	for sid in ["palizzata", "totem_veglia", "deposito"]:
		var c: Vector2i = fuori.call("cella_struttura", sid)
		assert_true(c.x >= 0 and Vector2(c).distance_to(porta.position / m.tile) < 10.0, "%s vicino alla casa base" % sid)
		var lato: int = int((_n("/root/GameData").call("get_arredo", sid)["misura"] as Array)[0])
		for i in lato:
			var q := c + Vector2i(i, 0)
			assert_false(m.call("bloccata", q.x, q.y), "%s su una casella libera" % sid)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					assert_false(prese.has(q + Vector2i(dx, dy)) and prese[q + Vector2i(dx, dy)] != sid,
							"%s staccata da %s" % [sid, prese.get(q + Vector2i(dx, dy), "")])
		for i in lato:
			prese[c + Vector2i(i, 0)] = sid
	var e: Dictionary = (_n("/root/StructureRegistry").call("attive") as Array)[0]
	var p: Array = e["posizione"]
	assert_true(Vector2(p[0], p[1]).distance_to(porta.position) < 10.0 * m.tile, "nel registro sta li' (le abilita' d'area)")
	assert_true(bool(_n("/root/BaseSystem").call("sposta", "base_rifugio")), "base spostata nelle Marche")
	var rifugio: Node2D = m.get_node("Porta_base_rifugio")
	e = (_n("/root/StructureRegistry").call("attive") as Array)[0]
	p = e["posizione"]
	assert_true(Vector2(p[0], p[1]).distance_to(rifugio.position) < 10.0 * m.tile, "e segue la sede")
	m.free()

