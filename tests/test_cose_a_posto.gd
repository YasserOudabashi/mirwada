extends "res://tests/test_case.gd"
## 2026-11-18 — Le cose aperte messe a posto: il nome solo sul nemico che ti affronta, i tiri colorati dal tipo, la
## vita che cresce in proporzione salendo di Sequenza, le Ancore-persona dei salvataggi vecchi.

func _root() -> Node: return Engine.get_main_loop().root


func test_il_nome_solo_sul_nemico_che_ti_affronta_piu_vicino() -> void:
	var madre := Node2D.new()
	_root().add_child(madre)
	var bersaglio := Node2D.new()
	madre.add_child(bersaglio)
	var vicino: Node2D = preload("res://scenes/enemy.tscn").instantiate()
	vicino.set("tipo", "soldato_caduto")
	vicino.position = Vector2(30, 0)
	var lontano: Node2D = preload("res://scenes/enemy.tscn").instantiate()
	lontano.set("tipo", "soldato_caduto")
	lontano.position = Vector2(60, 0)
	madre.add_child(vicino)
	madre.add_child(lontano)
	for e in [vicino, lontano]:
		e.set("_bersaglio", bersaglio)
	assert_false(bool(vicino.call("_nome_visibile")), "fermo, senza nome")
	vicino.call("_vai", 1)
	lontano.call("_vai", 1)
	assert_true(bool(vicino.call("_nome_visibile")), "il piu' vicino che ti affronta ha il nome")
	assert_false(bool(lontano.call("_nome_visibile")), "l'altro no: i nomi non si accavallano")
	madre.free()


func test_i_tiri_dei_nemici_hanno_il_colore_del_tipo() -> void:
	var e: Node = preload("res://scenes/enemy.tscn").instantiate()
	e.set("tipo", "scrivano_di_carta")
	_root().add_child(e)
	var tipi: Dictionary = _root().get_node("GameData").call("get_balance", "nemici_tipi")
	assert_eq(str(_root().get_node("Vfx").call("_pathway_di", e)), str(tipi["scrivano_di_carta"]["palette"]), "palette del tipo")
	e.free()


func test_salendo_di_sequenza_la_vita_resta_in_proporzione() -> void:
	var p: Node = preload("res://scenes/player.tscn").instantiate()
	_root().add_child(p)
	var prog: Node = _root().get_node("Progression")
	prog.call("configura", "twilight_giant", 7)
	var st: Node = p.get_node("StatsComponent")
	prog.call("riapplica_al_giocatore")
	st.set("hp", float(st.get_stat("hp_max")) * 0.5)
	prog.call("avanza")
	assert_almost_eq(float(st.get("hp")) / float(st.get_stat("hp_max")), 0.5, "meta' vita resta meta' vita", 0.02)
	p.free()
	prog.call("configura", "twilight_giant", 9)


func test_le_ancore_dei_salvataggi_vecchi_tornano_vere() -> void:
	var ns: Node = _root().get_node("NpcSystem")
	var anc: Node = _root().get_node("AnchorSystem")
	anc.call("pulisci")
	ns.call("da_salvataggio", {"ancore": ["npc_lena"]})
	assert_false("anchor_lena" in anc.call("active"), "un salvataggio di prima: Lena era solo un nome")
	ns.call("riallinea_ancore")
	assert_true("anchor_lena" in anc.call("active"), "ora e' un'Ancora vera")
	anc.call("pulisci")
	ns.call("pulisci")
