extends "res://tests/test_case.gd"
## US-8B22 — forzieri: tabelle di bottino nei dati (data/world/bottino.json), il forziere si apre una volta sola
## (WorldState, nel salvataggio) e il bottino va nello zaino.

const Forziere := preload("res://scripts/forziere.gd")
const InteriorScene := preload("res://scenes/interior_scene.tscn")


func _root() -> Node:
	return Engine.get_main_loop().root


func _dimentica(id: String) -> void:
	(_root().get_node("WorldState").get("_forzieri_aperti") as Array).erase(id)


func test_il_bottino_viene_dalla_sua_tabella() -> void:
	var tab: Dictionary = _root().get_node("GameData").call("get_tabella_bottino", "grotta")
	assert_false(tab.is_empty(), "la tabella della grotta c'e'")
	var ammessi: Dictionary = {}
	var q_max := 0
	for v in tab["voci"]:
		ammessi[v["item_id"]] = true
		q_max = maxi(q_max, int(v["quantita"][1]))
	var rng := RandomNumberGenerator.new()
	for s in 30:
		rng.seed = s
		var bottino: Array = Forziere.tira(tab, rng)
		assert_true(bottino.size() >= 1 and bottino.size() <= int(tab["tiri"][1]), "da 1 a %d voci" % tab["tiri"][1])
		for b in bottino:
			assert_true(ammessi.has(b["item_id"]), "%s e' nella tabella" % b["item_id"])
			assert_true(int(b["quantita"]) >= 1 and int(b["quantita"]) <= q_max * int(tab["tiri"][1]), "quantita' nei limiti")
	rng.seed = 7
	var a: Array = Forziere.tira(tab, rng)
	rng.seed = 7
	assert_eq(Forziere.tira(tab, rng), a, "stesso seme, stesso bottino")
	assert_eq(Forziere.tira({}, rng), [], "una tabella che non c'e' non da' niente")


func test_si_apre_una_volta_sola_e_il_bottino_va_nello_zaino() -> void:
	var inv: Node = _root().get_node("Inventory")
	var f: Area2D = Forziere.new()
	f.call("setup", "prova_forziere", "fogne", Vector2(64, 64))
	f.get("rng").seed = 3
	_root().add_child(f)
	assert_false(bool(f.call("e_aperto")), "chiuso all'inizio")
	var prima: Dictionary = {}
	for v in (_root().get_node("GameData").call("get_tabella_bottino", "fogne") as Dictionary)["voci"]:
		prima[v["item_id"]] = int(inv.call("conta", v["item_id"]))
	var bottino: Array = f.call("apri")
	assert_false(bottino.is_empty(), "dentro c'era qualcosa")
	for b in bottino:
		assert_eq(int(inv.call("conta", b["item_id"])), prima[b["item_id"]] + int(b["quantita"]), "%s nello zaino" % b["item_id"])
	assert_true(bool(f.call("e_aperto")), "ora e' aperto")
	assert_true(bool(_root().get_node("WorldState").call("forziere_aperto", "prova_forziere")), "e lo sa il mondo")
	assert_true(str((f.get("_scritta") as Label).text).length() > 0 and (f.get("_scritta") as Label).visible, "dice cosa c'era")
	assert_eq(f.call("apri"), [], "una seconda volta e' vuoto")
	f.free()
	var di_nuovo: Area2D = Forziere.new()
	di_nuovo.call("setup", "prova_forziere", "fogne", Vector2(64, 64))
	_root().add_child(di_nuovo)
	var aperto := Image.load_from_file(ProjectSettings.globalize_path("res://assets/interni/luminoso/arredi/forziere_aperto.png"))
	assert_eq((di_nuovo.get("_sprite") as Sprite2D).texture.get_image().get_data(), aperto.get_data(), "si vede aperto")
	assert_eq(di_nuovo.call("apri"), [], "rientrando resta aperto")
	di_nuovo.free()
	for b in bottino:
		inv.call("rimuovi", b["item_id"], int(b["quantita"]))
	_dimentica("prova_forziere")


func test_i_forzieri_aperti_vanno_nel_salvataggio() -> void:
	var ws: Node = _root().get_node("WorldState")
	ws.call("apri_forziere", "prova_salvataggio")
	var dati: Dictionary = ws.call("per_salvataggio")
	assert_true("prova_salvataggio" in (dati.get("forzieri_aperti", []) as Array), "salvato")
	_dimentica("prova_salvataggio")
	dati["forzieri_aperti"].append(42)
	ws.call("da_salvataggio", dati)
	assert_true(bool(ws.call("forziere_aperto", "prova_salvataggio")), "riletto")
	assert_false(42 in (ws.get("_forzieri_aperti") as Array), "le voci malformate si scartano")
	_dimentica("prova_salvataggio")


func test_gli_interni_mettono_i_forzieri_dei_dati() -> void:
	var cripta: TileMapLayer = InteriorScene.instantiate()
	cripta.set("interno_id", "marche_cripta")
	_root().add_child(cripta)
	var f: Area2D = cripta.get_node_or_null("Forziere_marche_cripta_1")
	assert_true(f != null, "il forziere della cripta c'e'")
	assert_eq(f.position, cripta.map_to_local(Vector2i(6, 1)), "dove dicono i dati")
	assert_eq(str(f.get("tabella")), "cripta", "con la sua tabella")
	assert_eq(cripta.get_cell_atlas_coords(Vector2i(6, 1)), Vector2i(1, 0), "la sua casella non si attraversa")
	var spr: Sprite2D = f.get("_sprite")
	assert_true(spr.texture != null, "si vede il disegno del forziere")
	cripta.free()


## US-8B22b: i forzieri del sottosuolo (bottino.json forzieri_mondo) vicino ai loro punti, in un vicolo cieco o in uno
## spiazzo (il forziere e' pieno: in un corridoio chiuderebbe il passaggio), visibili solo sotto terra.
func test_i_forzieri_del_sottosuolo() -> void:
	var m: Node2D = preload("res://scripts/world/mondo.gd").new()
	m.set("tema", "luminoso")
	assert_true(m.call("carica"), "mondo caricato")
	m.call("crea_forzieri")
	var attesi: Array = _root().get_node("GameData").call("get_forzieri_mondo")
	var forzieri: Array = m.get_children().filter(func(c): return c.get_script() == Forziere)
	assert_eq(forzieri.size(), attesi.size(), "uno per voce dei dati")
	assert_gt(forzieri.size(), 5, "nelle fogne, nelle catacombe, nelle grotte e nelle miniere")
	var b: PackedByteArray = (m.get("_livelli") as Dictionary)["sottosuolo"]["blocchi"]
	var w: int = m.larghezza
	var libera := func(q: Vector2i) -> bool: return b[q.y * w + q.x] == 0
	for f in forzieri:
		var c := Vector2i(int(f.position.x / m.tile), int(f.position.y / m.tile))
		assert_true(libera.call(c), "%s su una casella libera del sottosuolo" % f.get("forziere_id"))
		var lati: int = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP].filter(
				func(d): return libera.call(c + d)).size()
		var otto := 0
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				otto += 1 if libera.call(c + Vector2i(dx, dy)) else 0
		assert_true(lati == 1 or otto == 9, "%s in un vicolo cieco o in uno spiazzo: non chiude passaggi" % f.get("forziere_id"))
		assert_eq(str(f.get_meta("livello")), "sottosuolo", "sta sotto terra")
		assert_false((f as CanvasItem).visible, "in superficie non si vede")
		assert_eq(f.process_mode, Node.PROCESS_MODE_DISABLED, "ne' blocca il passo")
	m.call("cambia_livello", "sottosuolo")
	assert_true(forzieri.all(func(f): return (f as CanvasItem).visible), "sotto terra si vedono")
	m.free()


# --- US-8B22c: oggetti a caso nelle casette -----------------------------------------

func _casa(iid: String) -> TileMapLayer:
	var c: TileMapLayer = InteriorScene.instantiate()
	c.set("interno_id", iid)
	_root().add_child(c)
	return c


func _casuali(casa: Node) -> Array:
	return casa.get_children().filter(func(n): return str(n.name).begins_with("Casuale_"))


func _firma(casa: Node) -> Array:
	return _casuali(casa).map(func(n): return [n.get("char_id"), n.get("quantita"), n.global_position])


func test_le_casette_hanno_oggetti_a_caso_sempre_gli_stessi() -> void:
	var a := _casa("mirwada_casa_di_lena")
	var prima: Array = _firma(a)
	assert_gt(prima.size(), 0, "qualcosa a terra")
	var tab: Dictionary = _root().get_node("GameData").call("get_tabella_bottino", "casa")
	var ammessi: Array = (tab["voci"] as Array).map(func(v): return v["item_id"])
	var sp: Array = (_root().get_node("GameData").call("get_interno", "mirwada_casa_di_lena") as Dictionary)["spawn"]
	for n in _casuali(a):
		var c: Vector2i = a.local_to_map(a.to_local(n.global_position))
		assert_eq(a.get_cell_atlas_coords(c), Vector2i(0, 0), "sul pavimento libero (%s)" % c)
		assert_true(maxi(absi(c.x - int(sp[0])), absi(c.y - int(sp[1]))) > 1, "non sulla soglia")
		assert_true(str(n.get("char_id")) in ammessi, "%s dalla tabella della casa" % n.get("char_id"))
	a.free()
	var b := _casa("mirwada_casa_di_lena")
	assert_eq(_firma(b), prima, "rientrando: gli stessi oggetti negli stessi posti")
	b.free()


func test_un_oggetto_a_caso_preso_non_ricompare() -> void:
	var ws: Node = _root().get_node("WorldState")
	var inv: Node = _root().get_node("Inventory")
	var a := _casa("valle_avamposto_focolare")
	var tutti: int = _casuali(a).size()
	var primo: Node = _casuali(a)[0]
	var id: String = str(primo.get("char_id"))
	var q: int = int(primo.get("quantita"))
	assert_true(bool(primo.call("raccogli")), "si raccoglie")
	a.free()
	assert_true(bool(ws.call("preso", "valle_avamposto_focolare#0")), "il mondo sa che e' stato preso")
	assert_true("valle_avamposto_focolare#0" in (ws.call("per_salvataggio") as Dictionary)["presi"], "nel salvataggio")
	var b := _casa("valle_avamposto_focolare")
	assert_eq(_casuali(b).size(), tutti - 1, "non ricompare, gli altri si'")
	assert_true(b.get_node_or_null("Casuale_0") == null, "proprio quello")
	b.free()
	inv.call("rimuovi", id, q)
	(ws.get("_presi") as Array).erase("valle_avamposto_focolare#0")
