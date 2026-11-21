extends SceneTree
## Dashboard del progetto (tools/dashboard): le foto dal gioco vero. Ogni luogo e ogni villaggio di mondo.json, ogni
## interno con una porta nel mondo, ogni pagina del libro e l'HUD in combattimento. NON fa parte della suite.
## Lancio (mai --headless), cartella di uscita dopo "--" (la crea build.py, che poi le legge):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --display-driver x11 --rendering-driver opengl3 \
##     --path . --script res://tests/manual/qa_dashboard_foto.gd -- build/dashboard/foto
## Scrive <tipo>_<id>.jpg (1280x720) e foto.json con l'elenco e dove il giocatore e' davvero finito.

var OUT := ""
var main: Node
var mondo: Node
var p: Node2D
var book: Node
var elenco: Array = []


func _n(path: String) -> Node:
	return get_root().get_node_or_null(path)


func _aspetta(n: int) -> void:
	for _i in n:
		await process_frame


func _foto(tipo: String, id: String, extra: Dictionary = {}) -> void:
	await _aspetta(3)
	var img: Image = get_root().get_texture().get_image()
	var nome := "%s_%s.jpg" % [tipo, id]
	img.save_jpg("%s/%s" % [OUT, nome], 0.88)
	var voce := {"tipo": tipo, "id": id, "file": nome}
	voce.merge(extra)
	elenco.append(voce)
	print("FOTO ", nome)


func _vai(cella: Vector2i, attesa: int = 70) -> Vector2i:
	var q: Vector2i = mondo.call("cella_libera", cella)
	mondo.call("colloca", p, Vector2((q.x + 0.5) * 32, (q.y + 0.5) * 32))
	await _aspetta(attesa)
	return Vector2i(floori(p.global_position.x / 32), floori(p.global_position.y / 32))


func _initialize() -> void:
	OUT = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	TranslationServer.set_locale("it")
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	book = _n("Book")
	await _aspetta(60)
	var gs: Node = _n("GameState")
	gs.call("scegli_slot", 0)
	gs.call("nuova_partita", "Enel", 0, [], "twilight_giant", "facile")
	book.call("chiudi")
	await _aspetta(120)
	mondo = main.get_node("Mondo")
	p = get_first_node_in_group("player")
	_n("Progression").set("_sequence", 0)          # nessuna regione respinge (solo per le foto)
	var st: Node = p.get_node("StatsComponent")
	st.call("set_base", "hp_max", 999999.0)
	st.set("hp", 999999.0)
	_n("TimeSystem").call("forza_momento", "mezzogiorno")
	var dati: Dictionary = mondo.get("dati")
	for tipo in ["luoghi", "villaggi"]:
		var d: Dictionary = dati.get(tipo, {})
		for id in d:
			var c := Vector2i(int(d[id][0]), int(d[id][1]))
			var dove: Vector2i = await _vai(c)
			await _foto("luogo" if tipo == "luoghi" else "villaggio", str(id),
				{"cella": [c.x, c.y], "arrivato": [dove.x, dove.y]})
	# interni: ogni porta del mondo verso un interno
	var porte: Dictionary = {}
	for a in mondo.find_children("*", "Area2D", true, false):
		if a.has_meta("interno_id") and not a.has_meta("arrivo") and not porte.has(a.get_meta("interno_id")):
			porte[a.get_meta("interno_id")] = a
	for iid in porte:
		var porta: Area2D = porte[iid]
		mondo.call("colloca", p, porta.global_position)
		await _aspetta(20)
		if bool(mondo.call("entra", porta)):
			await _aspetta(70)
			await _foto("interno", str(iid))
			mondo.call("esci")
			await _aspetta(30)
	# HUD in combattimento: vicino a un nemico
	await _vai(Vector2i(int(dati["luoghi"]["porto"][0]), int(dati["luoghi"]["porto"][1])), 30)
	var vicino: Node2D = null
	var dd := INF
	for e in get_nodes_in_group("nemici"):
		var x: float = (e as Node2D).global_position.distance_to(p.global_position)
		if x < dd:
			dd = x
			vicino = e
	if vicino != null:
		mondo.call("colloca", p, vicino.global_position + Vector2(-40, 10))
		await _aspetta(50)
		Input.action_press("attacco")
		await _aspetta(6)
		Input.action_release("attacco")
		await _aspetta(6)
		await _foto("hud", "combattimento")
	# libro: ogni pagina dei dati che si apre in partita, e le sezioni dell'inventario
	var pagine: Array = (_n("GameData").call("get_ui_book") as Dictionary).get("pages", [])
	book.call("apri_a", "mappa")
	await _aspetta(60)
	for pg in pagine:
		var pid: String = str((pg as Dictionary).get("id", ""))
		if pid in ["copertina", "frontespizio"]:
			continue
		book.call("vai_a", pid)
		await _aspetta(60)
		await _foto("libro", pid)
	var ov: Node = main.get_node_or_null("BookOverlay")
	book.call("vai_a", "inventario")
	await _aspetta(40)
	if ov != null and ov.get_node_or_null("Pagina/Contenuto") != null and ov.get_node("Pagina/Contenuto").get_child_count() > 0:
		var cont: Node = ov.get_node("Pagina/Contenuto").get_child(0)
		for s in ["indosso", "ricettario", "talenti", "base"]:
			cont.set("_sezione", s)
			cont.call("aggiorna")
			await _aspetta(40)
			await _foto("libro", "inventario_" + s)
	book.call("chiudi")
	var f := FileAccess.open(OUT + "/foto.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(elenco, " "))
	f.close()
	quit(0)
