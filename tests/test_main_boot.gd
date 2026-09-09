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
	if bool(_n("/root/SaveSystem").call("esiste", SLOT)):
		_n("/root/SaveSystem").call("cancella", SLOT)


## Come test_creazione_talenti.gd: una suite che apre il libro o attiva una
## partita non deve trascinarsi nei test successivi (alfabeticamente,
## test_page_scaffale si aspetta lo stato di boot).
func _fine() -> void:
	_n("/root/Book").call("chiudi")
	_n("/root/GameState").set("_partita_attiva", false)
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


func test_su_partita_iniziata_ricostruisce_la_regione() -> void:
	var cont := Node2D.new()
	cont.set_script(load("res://scripts/main.gd"))
	_root().add_child(cont)

	var vecchia: Node = load("res://scenes/regioni/mirwada.tscn").instantiate()
	cont.add_child(vecchia)
	assert_false(vecchia.is_queued_for_deletion(), "la vecchia regione e' viva prima del cambio")

	cont.call("_su_partita_iniziata", "Tester")

	assert_true(vecchia.is_queued_for_deletion(), "la vecchia regione viene liberata")
	var nuova: Node = cont.get_child(cont.get_child_count() - 1)
	assert_ne(nuova, vecchia, "una nuova istanza prende il posto della vecchia")
	assert_true(nuova.has_method("viaggia_a"), "la nuova istanza e' una region_scene")
	assert_eq(str(nuova.get("region_id")), "mirwada",
		"stessa scena ricaricata: nessun id di regione hardcoded in main.gd")

	cont.free()
	_fine()
