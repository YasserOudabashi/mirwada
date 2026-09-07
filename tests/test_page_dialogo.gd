extends "res://tests/test_case.gd"
## US-613b — la pagina "dialogo" del libro: un dialogo che parte apre il libro
## su questa pagina, che mostra un bottone per ogni scelta valida; chiudere il
## libro termina il dialogo.

const OverlayScene := preload("res://scenes/book_overlay.tscn")
const PageDialogo := preload("res://scenes/pages/page_dialogo.tscn")


func _root() -> Node: return Engine.get_main_loop().root
func _book() -> Node: return _root().get_node("Book")
func _de() -> Node: return _root().get_node("DialogueEngine")
func _pr() -> Node: return _root().get_node("Progression")


func prepara() -> void:
	_de().call("termina")
	_book().call("azzera")
	_root().get_tree().paused = false
	_pr().call("configura", "twilight_giant", 9)
	_root().get_node("KnowledgeStore").call("dimentica_tutto")


func _monta_overlay() -> CanvasLayer:
	var ov: CanvasLayer = OverlayScene.instantiate()
	_root().add_child(ov)
	return ov


func _monta_pagina() -> Node:
	var p: Node = PageDialogo.instantiate()
	_root().add_child(p)
	return p


func test_book_json_dichiara_la_pagina_dialogo() -> void:
	var pt: Array = (_root().get_node("GameData").call("get_ui_book") as Dictionary).get("pages", [])
	var trovate: int = 0
	for p in pt:
		if str((p as Dictionary).get("tipo", "")) == "page_dialogo":
			trovate += 1
	assert_eq(trovate, 1, "una pagina di tipo page_dialogo in data/ui/book.json")


func test_dialogo_apre_il_libro_sulla_pagina_dialogo() -> void:
	var ov: CanvasLayer = _monta_overlay()
	_de().call("avvia", "dlg_mirco", "npc_mirco")
	assert_true(_book().call("e_aperto"), "il libro si apre quando parte un dialogo")
	assert_eq(_book().call("pagina_corrente"), "dialogo", "sulla pagina del dialogo")
	assert_true(ov.call("e_visibile"), "overlay visibile")
	_de().call("termina")
	assert_false(_book().call("e_aperto"), "a dialogo finito il libro si chiude")
	ov.free()


func test_un_bottone_per_scelta_valida() -> void:
	var p: Node = _monta_pagina()
	_de().call("avvia", "dlg_mirco", "npc_mirco")
	p.call("aggiorna")
	assert_eq(p.call("scelte_a_schermo"), 2, "a tier low: 2 scelte (la tier_min:mid e' nascosta)")
	_de().call("termina")
	_pr().call("configura", "twilight_giant", 6)
	_de().call("avvia", "dlg_mirco", "npc_mirco")
	p.call("aggiorna")
	assert_eq(p.call("scelte_a_schermo"), 3, "a tier mid compaiono 3 bottoni")
	p.free()


func test_il_bottone_fa_avanzare_il_dialogo() -> void:
	var p: Node = _monta_pagina()
	_de().call("avvia", "dlg_mirco", "npc_mirco")
	p.call("aggiorna")
	var primo: Button = null
	for c in p.get_children():
		if c is Button:
			primo = c
			break
	assert_true(primo != null, "c'e' almeno un bottone")
	primo.pressed.emit()
	assert_eq(str(_de().call("nodo_corrente").get("text_i18n")), "dialogue.mirco.n2",
		"premere la prima scelta segue il goto -> n2")
	p.free()


func test_chiudere_il_libro_termina_il_dialogo() -> void:
	var ov: CanvasLayer = _monta_overlay()
	_de().call("avvia", "dlg_mirco", "npc_mirco")
	assert_true(_de().call("in_corso"), "dialogo in corso")
	_book().call("chiudi")
	assert_false(_de().call("in_corso"), "chiudere il libro a mano termina il dialogo")
	ov.free()
