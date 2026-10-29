extends SceneTree
## Verifica a schermo dell'onboarding minimale: la Label col nome sopra il
## giocatore e il prompt "[F] Parla" che compare avvicinandosi a un NPC.
##
## NON fa parte della suite (tests/run_tests.gd non guarda in tests/manual/).
## Lancio su Windows (MAI --headless: il renderer dummy da' screenshot nulli):
##   Godot_v4.3-stable_win64_console.exe --path . --script res://tests/manual/qa_onboarding.gd
##
## Esce 0 se ogni passo passa, 1 al primo fallimento.

const OUT := "user://qa_onboarding"

var _main: Node
var _player: Node
var _ok: bool = true


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	await process_frame
	TranslationServer.set_locale("it")

	await _avvia_e_crea()
	if _ok: _verifica_nome()
	if _ok: await _verifica_prompt_npc()
	if _ok: await _verifica_colophon_comandi()

	if _ok:
		print("=== qa_onboarding: TUTTI I PASSI OK (", ProjectSettings.globalize_path(OUT), ") ===")
		quit(0)
	else:
		printerr("=== qa_onboarding: FALLITO ===")
		quit(1)


func _assert(cond: bool, msg: String) -> bool:
	print(("  ok: " if cond else "  FALLITO: ") + msg)
	if not cond:
		_ok = false
	return cond


func _screenshot(nome: String) -> void:
	var img: Image = get_root().get_texture().get_image()
	if img == null:
		printerr("  screenshot NULLO per ", nome, " (lanciato con --headless?)")
		return
	img.save_png("%s/%s.png" % [OUT, nome])
	print("  screenshot -> ", ProjectSettings.globalize_path("%s/%s.png" % [OUT, nome]))


func _n(path: String) -> Node:
	return get_root().get_node_or_null(path)


func _regione() -> Node:
	for c in _main.get_children():
		if c.has_method("viaggia_a"):
			return c
	return null


func _avvia_e_crea() -> void:
	print("=== avvio main.tscn + creazione 'Tester' ===")
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	await process_frame
	await process_frame
	var book: Node = _n("/root/Book")
	_n("/root/GameState").call("scegli_slot", 0)
	book.call("vai_a", "frontespizio")
	for _i in 40:
		await process_frame
	var overlay: Node = _main.get_node_or_null("BookOverlay")
	var pagina: Node = overlay.get_node_or_null("Pagina/Contenuto").get_child(0)
	if not _assert(pagina != null and pagina.has_method("conferma"), "pagina di creazione viva"):
		return
	pagina.get("_campo").text = "Tester"
	pagina.call("conferma")
	for _i in 40:
		await process_frame
	_player = _main.get_node_or_null("Player")
	_assert(_player != null, "il nodo Player esiste")
	_assert(not bool(book.call("e_aperto")), "libro chiuso dopo la conferma")


func _verifica_nome() -> void:
	print("=== la Label col nome sopra il giocatore ===")
	var lbl: Label = _player.get_node_or_null("Nome")
	_assert(lbl != null, "il giocatore ha una Label 'Nome'")
	if lbl != null:
		_assert(lbl.text == "Tester", "mostra il nome del personaggio: '%s'" % lbl.text)
	_screenshot("01_nome_giocatore")


func _verifica_prompt_npc() -> void:
	print("=== il prompt [F] Parla avvicinandosi a un NPC ===")
	var regione: Node = _regione()
	if not _assert(regione != null, "regione in scena"):
		return
	var npc: Node = null
	for c in regione.get_children():
		if c is Area2D and c.has_meta("npc_id") and c.get_node_or_null("Prompt") != null:
			npc = c
			break
	if not _assert(npc != null, "c'e' almeno un NPC con dialogo (e prompt) in scena"):
		return
	var prompt: CanvasItem = npc.get_node("Prompt")
	_assert(not prompt.visible, "il prompt parte nascosto")

	# porta il giocatore sull'NPC (il cammino reale e' coperto da qa_vslice;
	# qui interessa solo che il prompt scatti sull'overlap) e centra la camera.
	var cam: Camera2D = _player.get_node_or_null("Camera2D")
	if cam != null:
		cam.make_current()
	_player.global_position = npc.global_position
	for _i in 8:
		await get_root().get_tree().physics_frame
	await process_frame

	_assert(str(regione.get("_npc_vicino")) == str(npc.get_meta("npc_id")),
		"il giocatore e' registrato vicino all'NPC")
	_assert(prompt.visible, "il prompt e' visibile")
	_assert(String(prompt.get("text")).contains("Parla"),
		"il prompt dice 'Parla': '%s'" % prompt.get("text"))
	_screenshot("02_prompt_npc")


func _verifica_colophon_comandi() -> void:
	print("=== il colophon elenca i tasti abilita' e interagisci ===")
	var book: Node = _n("/root/Book")
	book.call("apri")
	book.call("vai_a", "colophon")
	for _i in 60:
		await process_frame
	var overlay: Node = _main.get_node_or_null("BookOverlay")
	var pag: Node = overlay.get_node_or_null("Pagina/Contenuto")
	var page: Node = pag.get_child(0) if pag != null and pag.get_child_count() > 0 else null
	if not _assert(page != null and str(page.call("testo_visibile")) == "impostazioni",
			"la pagina colophon e' viva"):
		return
	var testi: Array = []
	var stack: Array = [page]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c in nd.get_children():
			stack.append(c)
			if c is Label:
				testi.append((c as Label).text)
	_assert(testi.has(TranslationServer.translate("COLOPHON_AZIONE_INTERAGISCI")),
		"c'e' la riga 'Interagisci / parla'")
	_assert(testi.has(TranslationServer.translate("COLOPHON_AZIONE_ABILITA_1")),
		"c'e' la riga 'Abilità 1'")
	# scorri fino alla sezione Comandi per lo screenshot
	if page is ScrollContainer:
		await process_frame
		(page as ScrollContainer).scroll_vertical = 620
		for _i in 6:
			await process_frame
	_screenshot("03_colophon_comandi")
	book.call("chiudi")
