extends SceneTree
## US-1310 / US-1311 — l'Atto III giocato per davvero, con Xvfb: dalla Sequenza 4 alla 0 col Pathway di default,
## con le due tribolazioni dell'Atto III (Doran, l'antagonista alla soglia), i rituali nei loro luoghi veri, i
## sacrifici pagati (arma spezzata, armatura, struttura, l'Ancora) e il finale.
## NON fa parte della suite headless. Lancio (MAI --headless: gli screenshot sarebbero nulli):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --display-driver x11 --rendering-driver opengl3 \
##     --path . --script res://tests/manual/qa_atto_3.gd -- <cartella delle foto>
##
## Scorciatoie dichiarate (il resto passa dai sistemi veri: dialoghi, quest, libro, rituale, tribolazioni):
## - si parte alla Sequenza 4 (l'Atto II e' di qa_atto_2);
## - Caratteristiche, ingredienti, sigilli, arma spezzata, armatura e materiali della palizzata sono concessi;
## - la recitazione si riempie emettendo gli eventi delle sue azioni;
## - si va nei luoghi collocando Enel, l'ora e l'eclissi si forzano, i 45 secondi del rituale si saltano;
## - si parla con gli NPC senza camminare fino a loro (tranne l'antagonista, raggiunto alla soglia).
## Esce 0 se ogni passo passa, 1 al primo fallimento.

var OUT := "/tmp/qa_atto_3"
var _main: Node
var _ok: bool = true


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		OUT = args[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	TranslationServer.set_locale("it")
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	await _aspetta(30)
	_n("/root/GameState").call("nuova_partita", "Enel", 0, [], str(_n("/root/Progression").call("pathway")), "facile")
	_n("/root/Book").call("chiudi")
	await _aspetta(30)
	var prog: Node = _n("/root/Progression")
	prog.call("configura", str(prog.call("pathway")), 4)

	await _passo_0_un_ancora()
	if _ok: await _passo_1_dalla_4_alla_3()
	if _ok: await _passo_2_dalla_3_alla_2()
	if _ok: await _passo_3_dalla_2_alla_1()
	if _ok: await _passo_4_la_soglia()
	if _ok: await _passo_5_dalla_1_alla_0()
	if _ok:
		print("=== qa_atto_3: TUTTI I PASSI OK ===")
		quit(0)
	else:
		printerr("=== qa_atto_3: FALLITO ===")
		quit(1)


func _passo_0_un_ancora() -> void:
	print("=== 0. Lena diventa un'Ancora (servira' al rituale della Sequenza 1) ===")
	_parla("dlg_lena", "npc_lena", ["dialogue.lena.n1.gioca"])
	_assert("anchor_lena" in _n("/root/AnchorSystem").call("active"), "giocare con Lena la rende un'Ancora")
	_chiudi()
	await _aspetta(10)


func _passo_1_dalla_4_alla_3() -> void:
	print("=== 1. Sequenza 4 -> 3: campo di battaglia all'alba, si sacrifica l'arma spezzata ===")
	_n("/root/Inventory").call("aggiungi", "arma_spezzata", 1)
	await _rituale("campo_di_battaglia", "marche_crepuscolo", "alba", false, "01")
	_assert(int(_n("/root/Progression").call("sequence")) == 3, "Sequenza 3")
	_assert(int(_n("/root/Inventory").call("conta", "arma_spezzata")) == 0, "l'arma spezzata e' data")


func _passo_2_dalla_3_alla_2() -> void:
	print("=== 2. Sequenza 3 -> 2: Doran sa (tribolazione 3 -> 2), poi l'altura all'alba con l'armatura ===")
	var trib: Node = _n("/root/TribulationSystem")
	_assert(not bool(trib.call("superata", 3)), "la tribolazione del salto 3 -> 2 e' aperta")
	_parla("dlg_doran", "npc_doran", ["dialogue.doran.n1.affronta"])
	await _aspetta(30)
	_screenshot("02a_doran")
	_scegli("dialogue.doran.n4.patto")
	_chiudi()
	_assert(bool(trib.call("superata", 3)), "affrontato Doran, la tribolazione e' superata")
	var armatura := "corazza_cuoio"                       # un'armatura di data/items/equip.json
	var creati: Array = _n("/root/Inventory").call("aggiungi", armatura, 1)
	_assert(not creati.is_empty() and bool(_n("/root/Equipment").call("equipaggia", str(creati[0]))), "Enel indossa un'armatura")
	await _rituale("passo_tra_rupi", "marche_crepuscolo", "alba", false, "02")
	_assert(int(_n("/root/Progression").call("sequence")) == 2, "Sequenza 2")
	_assert((_n("/root/Equipment").call("equipaggiato", "armatura") as Dictionary).is_empty(), "l'armatura e' data")


func _passo_3_dalla_2_alla_1() -> void:
	print("=== 3. Sequenza 2 -> 1: la palizzata della base, poi la cripta al crepuscolo ===")
	var inv: Node = _n("/root/Inventory")
	var tipo: Dictionary = _n("/root/GameData").call("get_structure", "palizzata")
	for iid in (tipo.get("costo", {}) as Dictionary):
		inv.call("aggiungi", str(iid), int(tipo["costo"][iid]))
	_assert(bool(_n("/root/BaseSystem").call("costruisci_struttura", "palizzata")), "Enel costruisce la palizzata della base")
	# la cripta si apre solo a notte fonda: si entra, si aspetta il crepuscolo dentro
	_n("/root/TimeSystem").call("forza_momento", "notte_fonda")
	var mondo: Node = _main.get_node("Mondo")
	var varco: Area2D = mondo.get_node_or_null("Varco_cripte")
	if not _assert(varco != null, "la cripta delle Marche ha il suo ingresso"):
		return
	await _vai(varco.position + Vector2(0, 48))
	_assert(bool(mondo.call("entra", varco)), "a notte fonda si entra nella cripta")
	await _aspetta(60)
	_assert(str(_n("/root/WorldState").call("zona_corrente")) == "cripta", "dentro si e' nella cripta")
	_n("/root/TimeSystem").call("forza_momento", "crepuscolo")
	await _rituale("", "", "crepuscolo", false, "03")
	_assert(int(_n("/root/Progression").call("sequence")) == 1, "Sequenza 1")
	_assert(int(_n("/root/StructureRegistry").call("conta")) == 0, "la palizzata e' data")
	mondo.call("esci")
	await _aspetta(30)


func _passo_4_la_soglia() -> void:
	print("=== 4. la tribolazione 1 -> 0: l'antagonista alla soglia della Frontiera, di notte ===")
	var trib: Node = _n("/root/TribulationSystem")
	_assert(not bool(trib.call("superata", 1)), "la prova finale e' aperta")
	_n("/root/TimeSystem").call("forza_momento", "notte_fonda")
	var mondo: Node = _main.get_node("Mondo")
	mondo.call("crea_npc")
	await _aspetta(5)
	var a: Node2D = mondo.get_node_or_null("Npc_npc_antagonista")
	if not _assert(a != null, "di notte l'antagonista e' alla soglia"):
		return
	await _vai(a.position + Vector2(-40, 8))
	_assert(str(_n("/root/WorldState").call("regione_corrente")) == "frontiera_porte", "Enel e' nella Frontiera")
	_screenshot("04a_soglia")
	_parla("dlg_antagonista", "npc_antagonista", ["dialogue.antagonista.n1.varca"])
	await _aspetta(30)
	_screenshot("04b_antagonista")
	_chiudi()
	_assert(bool(trib.call("superata", 1)), "la prova finale e' superata")


func _passo_5_dalla_1_alla_0() -> void:
	print("=== 5. Sequenza 1 -> 0: il campo di battaglia durante l'eclissi, si sacrifica l'Ancora ===")
	var follia: float = float(_n("/root/Madness").call("valore"))
	_n("/root/TimeSystem").call("forza_eclissi")
	await _rituale("campo_di_battaglia", "marche_crepuscolo", "", true, "05")
	_assert(int(_n("/root/Progression").call("sequence")) == 0, "Sequenza 0")
	_assert(not ("anchor_lena" in _n("/root/AnchorSystem").call("active")), "l'Ancora (Lena) e' sacrificata")
	_assert(float(_n("/root/Madness").call("valore")) > follia, "perderla pesa sulla mente")
	_assert(bool(_n("/root/KnowledgeStore").call("conosce", "rituale_sequenza_0_completato")), "il rituale della Sequenza 0 e' compiuto")
	await _aspetta(60)
	_screenshot("06_finale")
	print("  finale: ", _n("/root/EndgameState").get("finale") if _n("/root/EndgameState") != null else "?")


# --- il rituale per la via vera del libro -------------------------------

## Prepara la pozione, va nel luogo (vuoto = dove si e'), offre i sacrifici, compie il rituale e lo porta a fine.
func _rituale(luogo: String, regione: String, momento: String, _eclissi: bool, foto: String) -> void:
	var prog: Node = _n("/root/Progression")
	var gd: Node = _n("/root/GameData")
	var rs: Node = _n("/root/RitualSystem")
	var prima: int = int(prog.call("sequence"))
	var rituale: Dictionary = rs.call("rituale_corrente")
	_assert(not rituale.is_empty(), "la Sequenza %d avanza con un rituale" % prima)
	var potion: Dictionary = prog.call("sequence_data").get("potion", {})
	var car: Dictionary = gd.call("characteristic_for", str(prog.call("pathway")), int(potion.get("characteristic_sequence", -1)))
	_n("/root/CharacteristicStore").call("aggiungi", str(car.get("id", "")))
	for iid in potion.get("ingredients", []):
		_n("/root/Inventory").call("aggiungi", str(iid), 1)
	for s in rituale.get("sigils", []):
		if int(_n("/root/Inventory").call("conta", str(s))) == 0:
			_n("/root/Inventory").call("aggiungi", str(s), 1)
	_recita()
	if not luogo.is_empty():
		var mondo: Node = _main.get_node("Mondo")
		var l: Array = (mondo.get("dati")["luoghi"] as Dictionary)[luogo]
		var c: Vector2i = mondo.call("cella_libera", Vector2i(int(l[0]), int(l[1])), {}, "", regione)
		await _vai(Vector2((c.x + 0.5) * 32, (c.y + 0.5) * 32))
	if not momento.is_empty():
		_n("/root/TimeSystem").call("forza_momento", momento)
	await _aspetta(10)
	var book: Node = _n("/root/Book")
	book.call("apri_a", "diagramma")
	await _aspetta(50)
	var pagina: Node = _pagina()
	_assert(bool(pagina.call("prepara_pozione").get("ok", false)), "la pozione si prepara")
	for r in rs.call("richieste", rituale):
		if bool((r as Dictionary).get("da_offrire", false)):
			_assert(bool(pagina.call("offri_sacrificio", str(r["id"]))), "si offre: %s" % r["id"])
	await _aspetta(10)
	for sc in _main.get_node("BookOverlay").find_children("*", "ScrollContainer", true, false):
		(sc as ScrollContainer).scroll_vertical = 100000
	await _aspetta(10)
	_screenshot(foto + "a_rituale_nel_libro")
	var esito: Dictionary = pagina.call("compi_rituale")
	if not _assert(bool(esito.get("ok", false)), "il rituale comincia (%s)" % str(esito)):
		print("  richieste: ", rs.call("richieste", rituale), " zona ", _n("/root/WorldState").call("zona_corrente"))
		return
	await _aspetta(40)
	_screenshot(foto + "b_rituale_in_corso")
	rs.call("_process", 500.0)
	await _aspetta(20)


func _recita() -> void:
	var gd: Node = _n("/root/GameData")
	_n("/root/Acting").call("_riparti")
	for a in (_n("/root/Progression").call("sequence_data").get("acting_actions", []) as Array):
		var dati: Dictionary = {}
		for k in ((a as Dictionary).get("filtri", {}) as Dictionary):
			dati[str(k).trim_suffix("_max").trim_suffix("_min")] = (a as Dictionary)["filtri"][k]
		var ev: String = str((a as Dictionary).get("evento", ""))
		if str(gd.call("get_tracked_event", ev).get("misura", "conteggio")) == "conteggio":
			for _i in int(ceil(float((a as Dictionary).get("target", 1)))):
				_n("/root/EventTracker").call("emit_event", ev, dati.duplicate())
		else:
			dati["quantita"] = float((a as Dictionary).get("target", 1))
			_n("/root/EventTracker").call("emit_event", ev, dati)


# --- helper -----------------------------------------------------------

func _vai(pos: Vector2) -> void:
	var mondo: Node = _main.get_node("Mondo")
	mondo.call("colloca", get_first_node_in_group("player"), pos)
	await _aspetta(120)


func _pagina() -> Node:
	return _main.get_node("BookOverlay/Pagina/Contenuto").get_child(0)


func _chiudi() -> void:
	_n("/root/DialogueEngine").call("termina")
	_n("/root/Book").call("chiudi")


func _parla(dialogo: String, npc: String, scelte: Array) -> void:
	var de: Node = _n("/root/DialogueEngine")
	de.call("termina")
	_assert(bool(de.call("avvia", dialogo, npc)), "si parla con %s" % npc)
	for s in scelte:
		_scegli(str(s))


func _scegli(chiave: String) -> void:
	var de: Node = _n("/root/DialogueEngine")
	var valide: Array = de.call("scelte_valide")
	for i in valide.size():
		if str(valide[i]["text_i18n"]) == chiave:
			de.call("scegli", i)
			return
	_assert(false, "la scelta %s si vede" % chiave)


func _assert(cond: bool, msg: String) -> bool:
	if cond:
		print("  ok: ", msg)
	else:
		printerr("  FALLITO: ", msg)
		_ok = false
	return cond


func _aspetta(n: int) -> void:
	for _i in n:
		await process_frame


func _screenshot(nome: String) -> void:
	var img: Image = get_root().get_texture().get_image()
	if img == null:
		printerr("  screenshot NULLO per ", nome, " (lanciato con --headless?)")
		return
	img.save_png("%s/%s.png" % [OUT, nome])


func _n(path: String) -> Node:
	return get_root().get_node_or_null(path)
