extends "res://tests/test_case.gd"
## US-8B35 — ritratti (tools/art/build_ritratti.py): un mezzobusto 64x80 per aspetto, nella pagina del dialogo.

const PageDialogo := preload("res://scenes/pages/page_dialogo.tscn")


func _root() -> Node:
	return Engine.get_main_loop().root


func _gd() -> Node:
	return _root().get_node("GameData")


func test_ogni_npc_con_un_aspetto_ha_il_ritratto() -> void:
	var n := 0
	for npc in _gd().call("get_npcs"):
		var id: String = str((npc as Dictionary).get("id", ""))
		if str(((npc as Dictionary).get("aspetto", {}) as Dictionary).get("sprite", "")).is_empty():
			continue
		var tex: Texture2D = _gd().call("ritratto", id)
		assert_true(tex != null, "%s ha il ritratto" % id)
		if tex != null:
			assert_eq(tex.get_size(), Vector2(64, 80), "%s: mezzobusto 64x80" % id)
		n += 1
	assert_gt(n, 8, "almeno gli 8 NPC con nome")
	assert_true(FileAccess.file_exists("res://assets/ritratti/personaggio.png"), "anche il giocatore")
	assert_true(_gd().call("ritratto", "npc_che_non_esiste") == null, "senza NPC niente ritratto")


func test_la_pagina_del_dialogo_mostra_chi_parla() -> void:
	var de: Node = _root().get_node("DialogueEngine")
	de.call("termina")
	_root().get_node("Progression").call("configura", "twilight_giant", 9)
	var p: Node = PageDialogo.instantiate()
	_root().add_child(p)
	de.call("avvia", "dlg_mirco", "npc_mirco")
	p.call("aggiorna")
	var riquadro: Node = p.get_node_or_null("ConRitratto")
	assert_true(riquadro != null, "il ritratto in cima alla pagina")
	if riquadro != null:
		var t: TextureRect = riquadro.get_node("Ritratto")
		assert_eq(t.texture, _gd().call("ritratto", "npc_mirco"), "il ritratto di chi parla")
		assert_eq(t.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "pixel netti")
		var testi: Array = riquadro.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
		assert_true(testi.has(str(_gd().call("tr_data", "npc.mirco.name"))), "il nome accanto al ritratto")
	assert_eq(p.call("scelte_a_schermo"), 2, "le scelte restano sotto, come prima")
	de.call("termina")
	p.free()
