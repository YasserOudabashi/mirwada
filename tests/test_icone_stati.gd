extends "res://tests/test_case.gd"
## US-8B71 — le icone degli status (assets/icone/stati/, tools/art/build_stati.py) sopra la testa.

const EnemyScene := preload("res://scenes/enemy.tscn")


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node("GameData")


func test_ogni_status_ha_la_sua_icona_16() -> void:
	var stati: Dictionary = _gd().call("get_status_effect", "paura")
	assert_false(stati.is_empty(), "lo status paura esiste")
	for id in ["sfortuna", "taunt", "decadimento", "autorita_decadimento", "comando_non_morti", "paura", "anima_recisa",
			"affascinato", "area_viva", "gravita_alterata", "destino_segnato", "occultato", "varco_sigillato", "posseduto"]:
		var tex: Texture2D = _gd().call("icona_stato", id)
		assert_true(tex != null, "%s ha l'icona" % id)
		if tex != null:
			assert_eq(tex.get_size(), Vector2(16, 16), "%s: 16 x 16" % id)


func test_le_icone_seguono_gli_status_del_nemico() -> void:
	var e: Node2D = EnemyScene.instantiate()
	Engine.get_main_loop().root.add_child(e)
	var icone: Node2D = e.get_node("IconeStato")
	assert_eq(icone.get_child_count(), 0, "senza status nessuna icona")
	var st: Node = e.get_node("StatsComponent")
	st.call("applica_status", "paura")
	st.call("applica_status", "decadimento")
	assert_eq(icone.get_child_count(), 2, "due status, due icone")
	var a: Sprite2D = icone.get_node("decadimento")
	var b: Sprite2D = icone.get_node("paura")
	assert_eq(a.position, Vector2(-5, 0), "in fila, centrate sopra la testa")
	assert_eq(b.position, Vector2(5, 0), "")
	assert_eq(a.scale, Vector2(0.5, 0.5), "a mezza grandezza: 8 unita', i 16 pixel a schermo")
	assert_eq(icone.position.y, -26.0, "2 unita' sopra la testa (alta 20)")
	st.call("rimuovi_status", "paura")
	assert_eq(icone.get_child_count(), 1, "tolto uno status, sparisce la sua icona")
	e.free()


func test_negli_ultimi_secondi_l_icona_lampeggia() -> void:
	var e: Node2D = EnemyScene.instantiate()
	Engine.get_main_loop().root.add_child(e)
	var st: Node = e.get_node("StatsComponent")
	st.call("applica_status", "paura", 1.0)
	var icone: Node2D = e.get_node("IconeStato")
	var visto_spento := false
	for i in 12:
		icone.call("_process", 0.0)
		visto_spento = visto_spento or (icone.get_node("paura") as Sprite2D).modulate.a < 1.0
		OS.delay_msec(60)
	assert_true(visto_spento, "a meno di 2 secondi dalla fine l'icona si spegne a tratti")
	st.call("applica_status", "comando_non_morti")
	for i in 12:
		icone.call("_process", 0.0)
		assert_eq((icone.get_node("comando_non_morti") as Sprite2D).modulate.a, 1.0, "uno status permanente non lampeggia")
		OS.delay_msec(30)
	e.free()


func test_il_giocatore_ha_le_icone_sopra_il_nome() -> void:
	var p: Node = preload("res://scenes/player.tscn").instantiate()
	Engine.get_main_loop().root.add_child(p)
	var icone: Node2D = p.get_node_or_null("IconeStato")
	assert_true(icone != null, "il giocatore ha la fila delle icone")
	var nome: Label = p.get_node_or_null("Nome")
	if nome != null:
		nome.text = "Asso"
		p.call("_posiziona_sopra")
		assert_true(icone.position.y + 4.0 <= nome.position.y, "con il nome, sopra il nome senza coprirlo")
		nome.text = ""
		p.call("_posiziona_sopra")
	assert_eq(icone.position.y, -26.0, "senza nome, subito sopra la testa come i nemici")
	p.call("imposta_volo", true)
	assert_eq(icone.position.y, -26.0 - 14.0, "in volo sale con il disegno")
	p.call("imposta_volo", false)
	assert_eq(icone.position.y, -26.0, "e riscende")
	p.free()
