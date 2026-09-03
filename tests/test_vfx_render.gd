extends "res://tests/test_case.gd"
## US-227 — renderer VFX per primitiva: impact frame, nero di scena, agganci.

const OverlayScene := preload("res://scenes/vfx_overlay.tscn")
const StatsComponent := preload("res://scripts/stats_component.gd")


func _root() -> Window:
	return Engine.get_main_loop().root


func _n(p: String) -> Node:
	return _root().get_node_or_null(p)


func _overlay() -> CanvasLayer:
	var ov: CanvasLayer = OverlayScene.instantiate()
	_root().add_child(ov)
	return ov


func _caster() -> Node2D:
	var madre := Node2D.new()
	_root().add_child(madre)
	var c := Node2D.new()
	var st: Node = StatsComponent.new()
	st.name = "StatsComponent"
	c.add_child(st)
	madre.add_child(c)
	st.call("configure_from_balance", 0)   # pool ampi: nessun blocco per costo
	return c


func _avanza(ov: CanvasLayer, n: int = 6) -> void:
	for i in n:
		ov.call("_process", 0.05)


func test_impact_frame_ha_durata_finita() -> void:
	var ov: CanvasLayer = _overlay()
	ov.call("impatto")
	assert_true(ov.call("impatto_attivo"), "l'impact frame parte")
	_avanza(ov)
	assert_false(ov.call("impatto_attivo"), "e finisce dopo durata_frames")
	ov.free()


func test_nero_di_scena_ha_durata_finita() -> void:
	var ov: CanvasLayer = _overlay()
	ov.call("nero", 250.0)
	assert_gt(ov.call("alpha_nero"), 0.0, "il nero di scena si attiva")
	for i in 8:
		ov.call("_process", 0.05)
	assert_eq(ov.call("alpha_nero"), 0.0, "e si spegne dopo durata_ms")
	ov.free()


func test_abilita_offensiva_scatena_l_impact_frame() -> void:
	var ov: CanvasLayer = _overlay()
	var c: Node2D = _caster()
	var eng: Node = _n("/root/AbilityEngine")
	# tg_fendente_pesante: melee_arc (impact_frame true nei dati vfx), Seq 9
	eng.call("execute", "tg_fendente_pesante", c)
	assert_true(ov.call("impatto_attivo"), "l'abilita' con impact_frame scatena il lampo")
	assert_eq(ov.call("alpha_nero"), 0.0, "Seq 9: nessun nero di scena")
	c.get_parent().free()
	ov.free()


func test_abilita_di_sequenza_bassa_mangia_lo_sfondo() -> void:
	var ov: CanvasLayer = _overlay()
	var c: Node2D = _caster()
	var eng: Node = _n("/root/AbilityEngine")
	# tg_caccia_spirituale: sequence_id twilight_giant_4 -> trigger abilita_sequenza_max_4
	eng.call("execute", "tg_caccia_spirituale", c)
	assert_gt(ov.call("alpha_nero"), 0.0, "un'abilita' di Sequenza <= 4 attiva il nero di scena")
	c.get_parent().free()
	ov.free()


func test_vfx_spawna_lo_sprite_placeholder() -> void:
	var ov: CanvasLayer = _overlay()
	var c: Node2D = _caster()
	var madre: Node = c.get_parent()
	var prima: int = madre.get_child_count()
	_n("/root/AbilityEngine").call("execute", "tg_fendente_pesante", c)
	assert_gt(float(madre.get_child_count()), float(prima), "un nodo VFX placeholder e' comparso accanto al caster")
	madre.free()
	ov.free()


func test_riduci_flash_non_toglie_l_informazione() -> void:
	var am: Node = _n("/root/AudioManager")
	am.call("imposta_accessibilita", "riduci_flash", true)
	var ov: CanvasLayer = _overlay()
	ov.call("impatto")
	assert_true(ov.call("impatto_attivo"), "con riduci_flash l'impact frame c'e' comunque (come bordo)")
	am.call("imposta_accessibilita", "riduci_flash", false)
	ov.free()
