extends "res://tests/test_case.gd"
## US-224 — pagina diagramma dei Pathway con fog of war.

const OverlayScene := preload("res://scenes/book_overlay.tscn")


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	var b: Node = _n("/root/Book")
	if b != null:
		b.call("azzera")
	Engine.get_main_loop().root.get_tree().paused = false
	var prog: Node = _n("/root/Progression")
	if prog != null:
		prog.call("configura", prog.call("pathway"), 9)
	var kn: Node = _n("/root/KnowledgeStore")
	if kn != null:
		kn.call("dimentica_tutto")


func _pagina() -> Node:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var b: Node = _n("/root/Book")
	b.call("apri")
	b.call("vai_a", "diagramma")
	for i in 4:
		ov.call("_process", 0.2)
	return ov


func test_griglia_10x10_generata_dai_dati() -> void:
	var ov: CanvasLayer = _pagina()
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)
	var gd: Node = _n("/root/GameData")
	var ids: Array = gd.call("pathway_ids")
	assert_eq(ids.size(), 10, "10 Pathway attivi = 10 colonne")
	# ogni cella (pathway, sequenza 9..0) ha uno stato
	var mancano: int = 0
	for pid in ids:
		for n in range(9, -1, -1):
			if pag.call("cella_stato", pid, n) == "":
				mancano += 1
	assert_eq(mancano, 0, "100 celle, tutte con uno stato")
	_n("/root/Book").call("chiudi")
	ov.free()


func test_la_propria_colonna_e_nota_fino_alla_sequenza_corrente() -> void:
	var prog: Node = _n("/root/Progression")
	prog.call("configura", prog.call("pathway"), 7)   # 9 -> 7: vissute 9,8,7
	var ov: CanvasLayer = _pagina()
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)
	var mio: String = str(prog.call("pathway"))
	assert_eq(pag.call("cella_stato", mio, 9), "noto", "Sequenza gia' passata: nota")
	assert_eq(pag.call("cella_stato", mio, 7), "corrente", "Sequenza corrente: evidenziata")
	assert_eq(pag.call("cella_stato", mio, 4), "ignoto", "Sequenza non ancora raggiunta: offuscata")
	_n("/root/Book").call("chiudi")
	ov.free()


func test_fog_of_war_sugli_altri_pathway() -> void:
	var gd: Node = _n("/root/GameData")
	var prog: Node = _n("/root/Progression")
	var altro: String = ""
	for pid in gd.call("pathway_ids"):
		if pid != str(prog.call("pathway")):
			altro = pid
			break
	var ov: CanvasLayer = _pagina()
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)
	assert_eq(pag.call("cella_stato", altro, 3), "ignoto", "un altro Pathway parte offuscato")

	_n("/root/KnowledgeStore").call("impara", "sequenza:%s:3" % altro)
	pag.call("aggiorna")
	assert_eq(pag.call("cella_stato", altro, 3), "noto", "impari quella Sequenza -> si rivela")
	assert_eq(pag.call("cella_stato", altro, 2), "ignoto", "solo quella, non le vicine")

	_n("/root/KnowledgeStore").call("impara", "pathway:%s" % altro)
	pag.call("aggiorna")
	assert_eq(pag.call("cella_stato", altro, 2), "noto", "conoscere il Pathway rivela la colonna")
	_n("/root/Book").call("chiudi")
	ov.free()


func test_abilita_della_sequenza_corrente_elencate() -> void:
	var ov: CanvasLayer = _pagina()   # Sequenza 9 del Pathway di default
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)
	assert_gt(float((pag.call("abilita_elencate") as Array).size()), 0.0,
		"le abilita' della Sequenza corrente sono elencate")
	_n("/root/Book").call("chiudi")
	ov.free()


func test_conoscenza_nel_save() -> void:
	var kn: Node = _n("/root/KnowledgeStore")
	kn.call("impara", "pathway:fool")
	var gs: Node = _n("/root/GameState")
	var snap: Dictionary = gs.call("snapshot")
	assert_true((snap.get("conoscenza", []) as Array).has("pathway:fool"), "la conoscenza va nello snapshot")
	kn.call("dimentica_tutto")
	gs.call("applica", snap)
	assert_true(bool(kn.call("conosce", "pathway:fool")), "e torna dopo applica")
