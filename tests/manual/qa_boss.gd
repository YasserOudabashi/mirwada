extends SceneTree
## US-1505: un boss vero nel mondo (arena, barra col nome, seconda fase coi gregari, bordo dell'arena, morte).
## NON fa parte della suite. Lancio (mai --headless), cartella delle foto e id del boss dopo "--":
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --display-driver x11 --rendering-driver opengl3 \
##     --path . --script res://tests/manual/qa_boss.gd -- /tmp/foto madre_delle_radici
func _aspetta(n: int) -> void:
	for _i in n:
		await process_frame
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	TranslationServer.set_locale("it")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await _aspetta(60)
	var gs: Node = get_root().get_node("GameState")
	gs.call("scegli_slot", 0)
	gs.call("nuova_partita", "Enel", 0, [], "twilight_giant", "facile")
	get_root().get_node("Book").call("chiudi")
	await _aspetta(120)
	var mondo: Node = main.get_node("Mondo")
	var p: Node2D = get_first_node_in_group("player")
	p.get_node("StatsComponent").call("set_base", "hp_max", 99999.0)
	p.get_node("StatsComponent").set("hp", 99999.0)
	var b: Node2D = null
	for x in get_nodes_in_group("boss"):
		if x.get_node("Boss").get("boss_id") == OS.get_cmdline_user_args()[1]:
			b = x
	mondo.call("colloca", p, b.position + Vector2(0, 70))
	await _aspetta(150)
	get_root().get_texture().get_image().save_png(out + "/boss_1.png")
	var st: Node = b.get_node("StatsComponent")
	st.set("hp", st.get_stat("hp_max") * 0.6)
	await _aspetta(40)
	get_root().get_texture().get_image().save_png(out + "/boss_2.png")
	var an = b.get_node("Boss").get("_anello")
	print("ANELLO ", an, " vis ", an.is_visible_in_tree(), " pos ", an.global_position, " parent ", an.get_parent().name, " z ", an.z_index, " r ", an.get("raggio"))
	for g in get_nodes_in_group("gregari"):
		print("GREG ", g.get("tipo"), " ", g.global_position, " vis ", g.is_visible_in_tree())
	print("BOSSPOS ", b.global_position, " P ", p.global_position)
	mondo.call("colloca", p, b.get_node("Boss").get("centro") + Vector2(400, 0))
	await _aspetta(5)
	print("BORDO ", p.global_position.distance_to(b.get_node("Boss").get("centro")))
	st.set("hp", 0.0)
	await _aspetta(30)
	print("DOPO chiusa ", b.get_node("Boss").get("arena_chiusa"), " vinto ", get_root().get_node("WorldState").call("preso", "boss:" + OS.get_cmdline_user_args()[1]))
	quit()
