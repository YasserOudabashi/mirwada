extends SceneTree
## Verifica a schermo: il giocatore SI VEDE mentre gioca e l'uso di
## un'abilita' da' feedback (lampo del VFX + lampeggio dello slot hotbar).
## Regressione del bug: main.gd ricaricava la regione come ultimo figlio,
## coprendo il giocatore col tilemap.
##
## NON fa parte della suite. Lancio su Windows (MAI --headless):
##   Godot_v4.3-stable_win64_console.exe --path . --script res://tests/manual/qa_giocabilita.gd
## Esce 0 se ogni passo passa, 1 al primo fallimento.

const OUT := "user://qa_giocabilita"

var _ok: bool = true


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	await process_frame
	TranslationServer.set_locale("it")

	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	for _i in 3: await process_frame

	# creazione personaggio
	var book: Node = get_root().get_node("Book")
	get_root().get_node("GameState").call("scegli_slot", 0)
	book.call("vai_a", "frontespizio")
	for _i in 40: await process_frame
	var pagina: Node = main.get_node("BookOverlay/Pagina/Contenuto").get_child(0)
	pagina.get("_campo").text = "Tester"
	pagina.call("conferma")
	for _i in 60: await process_frame   # anche il tempo che la camera si assesti

	var p: Node2D = main.get_node("Player")
	var anim: AnimatedSprite2D = p.get_node("AnimationMachine")
	var cam: Camera2D = p.get_node("Camera2D")

	# --- il giocatore si vede ---
	print("=== il giocatore e' visibile ===")
	var regione: Node = null
	for c in main.get_children():
		if c.has_method("viaggia_a"):
			regione = c
	_assert(regione != null, "regione in scena")
	_assert(regione.get_index() < p.get_index(),
		"la regione sta SOTTO il Player nell'ordine di disegno (indici %d < %d)"
		% [regione.get_index() if regione else -1, p.get_index()])
	_assert(p.visible and anim.visible and anim.sprite_frames != null,
		"nodo Player e AnimationMachine visibili, sprite_frames costruiti")
	# il player e' dentro il rettangolo inquadrato dalla camera
	var vis: Rect2 = Rect2(cam.get_screen_center_position()
		- get_root().get_visible_rect().size * 0.5, get_root().get_visible_rect().size)
	_assert(vis.has_point(p.global_position),
		"il giocatore e' dentro l'inquadratura (%s in %s)" % [p.global_position, vis])
	# lo sprite del giocatore e' davvero dipinto al centro: campiono i pixel
	# attorno al centro schermo e verifico che NON siano tutti il colore del
	# pavimento (se la regione lo coprisse, lo sarebbero)
	await process_frame
	var img: Image = get_root().get_texture().get_image()
	if img != null:
		var centro := Vector2i(img.get_width() / 2, img.get_height() / 2)
		var colori := {}
		for dx in range(-10, 11, 2):
			for dy in range(-10, 11, 2):
				var col: Color = img.get_pixelv(centro + Vector2i(dx, dy))
				colori[col.to_html()] = true
		_assert(colori.size() >= 3,
			"al centro schermo ci sono piu' colori (lo sprite, non solo il pavimento): %d" % colori.size())
		img.save_png("%s/01_giocatore_visibile.png" % OUT)
		print("  screenshot -> ", ProjectSettings.globalize_path("%s/01_giocatore_visibile.png" % OUT))

	# --- feedback dell'abilita' ---
	print("=== l'abilita' da' feedback ===")
	var hud: Node = main.get_node("HUD")
	var slot0: Label = hud.get_node("Root/VBox/Hotbar/Slot0")
	var vfxov: Node = main.get_node("VfxOverlay")
	slot0.modulate = Color.WHITE
	var madre: Node = p.get_parent()   # dove Vfx.gioca_primitiva mette lo sprite
	var figli_prima: int = madre.get_child_count()
	var sp_prima: float = float(p.get_node("StatsComponent").get("spiritualita"))
	var r: Dictionary = p.call("lancia_abilita_slot", 0)
	_assert(bool(r.get("ok", false)), "abilita' slot 0 eseguita")
	await process_frame
	_assert(slot0.modulate != Color.WHITE, "lo slot 0 della hotbar lampeggia")
	_assert(madre.get_child_count() > figli_prima,
		"un nodo VFX e' comparso nel mondo accanto al giocatore")
	_assert(float(p.get_node("StatsComponent").get("spiritualita")) < sp_prima,
		"la spiritualita' e' calata")
	_assert(str(anim.animation).begins_with("cast"), "il giocatore fa la posa di lancio")
	for _i in 3: await process_frame
	if img != null:
		var img2: Image = get_root().get_texture().get_image()
		if img2 != null:
			img2.save_png("%s/02_abilita_feedback.png" % OUT)
			print("  screenshot -> ", ProjectSettings.globalize_path("%s/02_abilita_feedback.png" % OUT))

	# --- il giocatore si vede ANCHE dopo un cambio regione ---
	print("=== dopo un cambio regione il giocatore si vede ancora ===")
	var altre: Array = regione.call("passaggi_verso")
	_assert(altre.size() > 0, "Mirwada ha almeno un passaggio")
	if altre.size() > 0:
		_assert(regione.call("viaggia_a", str(altre[0])), "viaggio verso %s avviato" % altre[0])
		for _i in 90: await process_frame
		var nuova_reg: Node = null
		for c in main.get_children():
			if c.has_method("viaggia_a"):
				nuova_reg = c
		_assert(nuova_reg != null and nuova_reg != regione, "nuova regione caricata")
		_assert(nuova_reg.get_index() < p.get_index(),
			"la nuova regione sta sotto il Player (indici %d < %d)"
			% [nuova_reg.get_index() if nuova_reg else -1, p.get_index()])
		var img3: Image = get_root().get_texture().get_image()
		if img3 != null:
			var cc := Vector2i(img3.get_width() / 2, img3.get_height() / 2)
			var cols := {}
			for dx in range(-10, 11, 2):
				for dy in range(-10, 11, 2):
					cols[img3.get_pixelv(cc + Vector2i(dx, dy)).to_html()] = true
			_assert(cols.size() >= 3,
				"al centro schermo, nella nuova regione, si vede lo sprite: %d colori" % cols.size())
			img3.save_png("%s/03_dopo_cambio_regione.png" % OUT)
			print("  screenshot -> ", ProjectSettings.globalize_path("%s/03_dopo_cambio_regione.png" % OUT))

	if _ok:
		print("=== qa_giocabilita: TUTTI I PASSI OK ===")
		quit(0)
	else:
		printerr("=== qa_giocabilita: FALLITO ===")
		quit(1)


func _assert(cond: bool, msg: String) -> void:
	print(("  ok: " if cond else "  FALLITO: ") + msg)
	if not cond:
		_ok = false
