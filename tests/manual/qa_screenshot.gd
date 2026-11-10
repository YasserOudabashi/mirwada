extends SceneTree
## Giro di screenshot del gioco vero (controllo del 2026-11-10): avvio, nuova partita, le regioni, combattimento,
## notte, un interno e tutte le pagine del libro. NON fa parte della suite.
## Lancio (mai --headless), cartella di uscita e modalita' (facile | difficile) dopo "--":
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --display-driver x11 --rendering-driver opengl3 \
##     --path . --script res://tests/manual/qa_screenshot.gd -- /tmp/foto facile

var OUT := ""
var main: Node
var mondo: Node
var p: Node2D
var book: Node

func _n(path: String) -> Node:
	return get_root().get_node_or_null(path)

func _aspetta(n: int) -> void:
	for _i in n:
		await process_frame

func _foto(nome: String) -> void:
	await _aspetta(3)
	var img: Image = get_root().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT, nome])
	print("FOTO ", nome)

func _vai(luogo: String, attesa: int = 90) -> void:
	var c: Array = mondo.get("dati")["luoghi"][luogo]
	var q: Vector2i = mondo.call("cella_libera", Vector2i(int(c[0]), int(c[1])))
	mondo.call("colloca", p, Vector2((q.x + 0.5) * 32, (q.y + 0.5) * 32))
	await _aspetta(attesa)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	OUT = args[0]
	var mod: String = args[1] if args.size() > 1 else "facile"
	TranslationServer.set_locale("it")
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	book = _n("Book")
	await _aspetta(60)
	if mod == "facile":
		await _foto("01_avvio_libro_panorama")
	var gs: Node = _n("GameState")
	gs.call("scegli_slot", 0)
	book.call("vai_a", "frontespizio")
	await _aspetta(40)
	if mod == "facile":
		await _foto("02_nuova_partita")
	gs.call("nuova_partita", "Enel", 0, [], "twilight_giant", mod)
	book.call("chiudi")
	await _aspetta(120)
	mondo = main.get_node("Mondo")
	p = get_first_node_in_group("player")
	var inv: Node = _n("Inventory")
	for it in ["pozione_cura_minore", "pozione_cura_minore", "elisir_del_vigore", "spada_ferrea", "corazza_cuoio",
			"amuleto_lunare", "lingotto_ferro", "cristallo_grezzo", "sigillo_forza_minore", "acqua_di_fonte_benedetta"]:
		inv.call("aggiungi", it, 1)
	inv.call("aggiungi", "moneta_comune", 120)
	var ts: Node = _n("TimeSystem")
	ts.call("forza_momento", "mezzogiorno")
	var pre := "" if mod == "facile" else "cupo_"
	await _aspetta(60)
	await _foto(pre + "03_partenza_casa_al_porto")
	await _vai("piazza_mercato")
	await _foto(pre + "04_piazza_del_mercato")
	await _vai("porto")
	await _foto(pre + "05_porto")
	await _vai("cattedrale")
	await _foto(pre + "06_cattedrale")
	if mod != "facile":
		await _vai("galleria_di_alberi")
		await _foto(pre + "07_valle_galleria_di_alberi")
		await _vai("scalinata_archivio")
		await _foto(pre + "08_archivio")
		await _vai("approdo_frontiera")
		await _foto(pre + "09_frontiera")
		await _vai("faro", 20)
		ts.call("forza_momento", "notte_fonda")
		await _aspetta(240)
		await _foto(pre + "13_notte_al_faro")
		quit(0)
		return
	await _vai("galleria_di_alberi")
	await _foto("07_valle_galleria_di_alberi")
	await _vai("scalinata_archivio")
	await _foto("08_archivio")
	await _vai("approdo_frontiera")
	await _foto("09_frontiera")
	await _vai("trono_del_gigante")
	await _foto("10_marche_trono_del_gigante")
	# combattimento: vicino al nemico piu' vicino alla partenza
	await _vai("porto", 30)
	var vicino: Node2D = null
	var d := INF
	for e in get_nodes_in_group("nemici"):
		var dd: float = (e as Node2D).global_position.distance_to(p.global_position)
		if dd < d:
			d = dd
			vicino = e
	if vicino != null:
		mondo.call("colloca", p, vicino.global_position + Vector2(-40, 10))
		await _aspetta(50)
		Input.action_press("attacco")
		await _aspetta(6)
		Input.action_release("attacco")
		await _aspetta(4)
		await _foto("11_combattimento")
		await _aspetta(40)
		await _foto("12_combattimento_dopo")
	# notte
	await _vai("faro", 20)
	ts.call("forza_momento", "notte_fonda")
	await _aspetta(240)
	await _foto("13_notte_al_faro")
	await _vai("piazza_mercato", 20)
	await _aspetta(60)
	await _foto("14_notte_in_citta")
	ts.call("forza_momento", "crepuscolo")
	await _vai("porto", 20)
	await _aspetta(240)
	await _foto("15_crepuscolo_al_porto")
	ts.call("forza_momento", "mezzogiorno")
	await _aspetta(60)
	# interno: la porta piu' vicina al mercato
	var porta: Area2D = null
	d = INF
	for a in mondo.find_children("*", "Area2D", true, false):
		if a.has_meta("interno_id") and not a.has_meta("gate") and not a.has_meta("arrivo"):
			var dd: float = (a as Node2D).global_position.distance_to(p.global_position)
			if dd < d:
				d = dd
				porta = a
	if porta != null:
		print("interno ", porta.get_meta("interno_id"))
		mondo.call("colloca", p, porta.global_position)
		await _aspetta(20)
		mondo.call("entra", porta)
		await _aspetta(80)
		await _foto("16_interno_" + str(porta.get_meta("interno_id")))
		mondo.call("esci")
		await _aspetta(40)
	# libro in partita
	book.call("apri_a", "mappa")
	await _aspetta(90)
	await _foto("17_libro_mappa")
	var ov: Node = main.get_node("BookOverlay")
	var n := 18
	for pg in ["diagramma", "inventario", "sinergie", "journal", "colophon"]:
		book.call("vai_a", pg)
		await _aspetta(90)
		await _foto("%d_libro_%s" % [n, pg])
		n += 1
		if pg == "inventario":
			var cont: Node = ov.get_node("Pagina/Contenuto").get_child(0)
			for s in ["indosso", "ricettario", "talenti", "base", "sinergie", "journal"]:
				if s == "zaino":
					continue
				cont.set("_sezione", s)
				cont.call("aggiorna")
				await _aspetta(40)
				await _foto("%d_libro_inventario_%s" % [n, s])
				n += 1
	book.call("chiudi")
	quit(0)
