extends "res://tests/test_case.gd"
## US-801 — scripts/main.gd apre il libro sullo scaffale all'avvio e
## ricostruisce la regione corrente su GameState.partita_iniziata;
## GameState.nuova_partita accetta ora un Pathway esplicito (con "" usa il
## default, compatibilita' coi chiamanti/test esistenti).

const SLOT := 921


func _root() -> Node: return Engine.get_main_loop().root
func _n(s: String) -> Node: return _root().get_node_or_null(s)


func prepara() -> void:
	_n("/root/Book").call("azzera")
	_n("/root/GameState").set("_partita_attiva", false)
	_n("/root/GameState").set("da_salvataggio", false)
	_n("/root/GameState").set("modalita", "facile")
	if bool(_n("/root/SaveSystem").call("esiste", SLOT)):
		_n("/root/SaveSystem").call("cancella", SLOT)


## Come test_creazione_talenti.gd: una suite che apre il libro o attiva una
## partita non deve trascinarsi nei test successivi (alfabeticamente,
## test_page_scaffale si aspetta lo stato di boot).
func _fine() -> void:
	_n("/root/Book").call("chiudi")
	_n("/root/GameState").set("_partita_attiva", false)
	_n("/root/GameState").set("da_salvataggio", false)
	_n("/root/GameState").set("modalita", "facile")
	if bool(_n("/root/SaveSystem").call("esiste", SLOT)):
		_n("/root/SaveSystem").call("cancella", SLOT)


func test_ready_apre_il_libro_sullo_scaffale() -> void:
	var cont := Node2D.new()
	cont.set_script(load("res://scripts/main.gd"))
	_root().add_child(cont)

	var book: Node = _n("/root/Book")
	assert_true(bool(book.call("e_aperto")), "main.gd apre il libro all'avvio")
	var pag_id: String = str(book.call("pagina_corrente"))
	var pag: Dictionary = book.call("pagina", pag_id)
	assert_eq(str(pag.get("tipo", "")), "menu_principale",
		"si apre sulla pagina di ordine piu' basso: lo scaffale (menu_principale)")

	cont.free()
	_fine()


func test_nuova_partita_con_pathway_esplicito_configura_progression() -> void:
	var gs: Node = _n("/root/GameState")
	var prog: Node = _n("/root/Progression")
	var gd: Node = _n("/root/GameData")
	var ids: Array = gd.call("pathway_ids")
	assert_true(ids.size() > 1, "servono almeno 2 Pathway attivi per questo test")
	var default_id: String = str(
		(gd.call("get_balance", "progressione") as Dictionary).get("pathway_default", ""))
	# Un id DIVERSO dal default: senza, il test non proverebbe nulla di
	# distinto dal comportamento a "" del test successivo.
	var scelto: String = ""
	for pid in ids:
		if str(pid) != default_id:
			scelto = str(pid)
			break
	assert_ne(scelto, "", "esiste almeno un Pathway diverso dal default")
	assert_ne(scelto, default_id, "il Pathway scelto per il test non e' il default")

	gs.call("nuova_partita", "Tester", SLOT, [], scelto)
	assert_eq(str(prog.call("pathway")), scelto,
		"Progression.configura riceve il Pathway scelto in creazione")
	assert_eq(int(prog.call("sequence")), 9, "si parte sempre dalla Sequenza 9")

	_fine()


func test_nuova_partita_senza_pathway_usa_il_default() -> void:
	var gs: Node = _n("/root/GameState")
	var prog: Node = _n("/root/Progression")
	var gd: Node = _n("/root/GameData")
	var default_id: String = str(
		(gd.call("get_balance", "progressione") as Dictionary).get("pathway_default", ""))

	gs.call("nuova_partita", "Tester", SLOT, [])
	assert_eq(str(prog.call("pathway")), default_id,
		"senza pathway_id esplicito il comportamento non cambia: usa il default")

	_fine()


## US-1002B (fase 10, mondo continuo): il mondo non si ricarica piu' su
## partita_iniziata - resta lo stesso nodo, solo il giocatore viene
## riposizionato a Mirwada (world_scene.gd::viaggia_a).
func test_su_partita_iniziata_riposiziona_senza_ricaricare() -> void:
	var cont := Node2D.new()
	cont.set_script(load("res://scripts/main.gd"))
	_root().add_child(cont)

	var mondo: Node = load("res://scenes/world_scene.tscn").instantiate()
	cont.add_child(mondo)
	var player := Node2D.new()
	player.name = "Player"
	player.add_to_group("player")
	cont.add_child(player)
	player.global_position = Vector2(-999, -999)

	cont.call("_su_partita_iniziata", "Tester")

	assert_false(mondo.is_queued_for_deletion(), "il mondo NON viene ricaricato: stesso nodo di prima")
	assert_eq(player.global_position, mondo.call("punto_spawn", "mirwada"),
		"il player e' riposizionato alla cella di spawn di Mirwada")

	cont.free()
	_fine()


## Controllo del 2026-11-10: il mondo nasce all'avvio con le immagini luminose; una partita difficile (nuova o
## caricata) lo rifa' con quelle cupe, e una partita caricata resta dove si era salvato.
func _main_col_mondo() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	return main


func test_la_partita_difficile_rifa_il_mondo_cupo() -> void:
	var main: Node = _main_col_mondo()
	var gs: Node = _n("/root/GameState")
	assert_eq(str(main.get_node("Mondo").call("tema_caricato")), "luminoso", "all'avvio il mondo e' luminoso")
	gs.call("nuova_partita", "Tester", SLOT, [], "", "difficile")
	var mondo: Node2D = main.get_node("Mondo")
	assert_eq(str(mondo.call("tema_caricato")), "cupo", "con la partita difficile il mondo e' cupo")
	var player: Node2D = mondo.get_node_or_null("Player")
	assert_true(player != null, "il giocatore e' dentro il mondo nuovo")
	assert_eq(player.position, mondo.call("punto_spawn", "mirwada"), "e parte dal punto di partenza")
	assert_eq(_root().get_tree().get_nodes_in_group("mondo").size(), 1, "un mondo solo")
	var st: Node = player.get_node("StatsComponent")
	assert_eq(float(st.get("hp")), float(st.call("get_stat", "hp_max")), "si comincia in piena salute")
	gs.call("nuova_partita", "Tester", SLOT, [], "", "facile")
	assert_eq(str(main.get_node("Mondo").call("tema_caricato")), "luminoso", "e torna luminoso con una partita facile")
	main.free()
	_fine()


func test_la_partita_caricata_resta_dove_si_era_salvato() -> void:
	var main: Node = _main_col_mondo()
	var gs: Node = _n("/root/GameState")
	gs.call("nuova_partita", "Tester", SLOT, [], "", "difficile")
	var mondo: Node2D = main.get_node("Mondo")
	var c: Array = (mondo.get("dati")["luoghi"] as Dictionary)["piazza_mercato"]
	var q: Vector2i = mondo.call("cella_libera", Vector2i(int(c[0]), int(c[1])))
	var dove := Vector2((q.x + 0.5) * 32, (q.y + 0.5) * 32)
	mondo.call("colloca", mondo.get_node("Player"), dove)
	gs.call("salva_slot", SLOT)
	gs.call("nuova_partita", "Altro", SLOT + 1, [], "", "facile")     # un'altra partita, luminosa, alla partenza
	assert_true(bool(gs.call("carica_slot", SLOT).get("ok", false)), "slot caricato")
	mondo = main.get_node("Mondo")
	assert_eq(str(mondo.call("tema_caricato")), "cupo", "la partita difficile caricata ha il mondo cupo")
	assert_eq((mondo.get_node("Player") as Node2D).position, dove, "e il giocatore sta dove aveva salvato")
	_n("/root/SaveSystem").call("cancella", SLOT + 1)
	main.free()
	_fine()
