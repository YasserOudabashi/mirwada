extends "res://tests/test_case.gd"
## US-215 — effetti visivi della follia: vignetta a soglia 15, distorsione a
## 40, nero di scena a 70; riduci_flash rende tutto statico ma mai assente.

const Overlay := preload("res://scenes/madness_overlay.tscn")


func _m() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Madness")


func _am() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AudioManager")


func prepara() -> void:
	if _m() != null:
		_m().call("azzera")
	if _am() != null:
		_am().call("imposta_accessibilita", "riduci_flash", false)
		_am().call("imposta_accessibilita", "riduci_distorsione", false)


func _overlay() -> Node:
	var o: Node = Overlay.instantiate()
	Engine.get_main_loop().root.add_child(o)
	return o


func _via(o: Node) -> void:
	Engine.get_main_loop().root.remove_child(o)
	o.free()


func test_vignetta_solo_sopra_soglia_distorsioni() -> void:
	var o: Node = _overlay()
	_m().call("add", 10.0, "x")   # sotto 15
	o.call("_aggiorna", 0.0)
	assert_almost_eq(o.call("intensita_vignetta"), 0.0, "sotto soglia 15: nessuna vignetta")

	_m().call("add", 40.0, "x")   # -> 50
	o.call("_aggiorna", 0.0)
	assert_gt(o.call("intensita_vignetta"), 0.0, "sopra soglia 15: vignetta attiva")
	_via(o)


func test_vignetta_cresce_con_la_follia() -> void:
	var o: Node = _overlay()
	_am().call("imposta_accessibilita", "riduci_flash", true)  # niente respiro: confronto stabile
	_m().call("add", 40.0, "x")
	o.call("_aggiorna", 0.0)
	var a50: float = o.call("intensita_vignetta")
	_m().call("add", 45.0, "x")   # -> 85
	o.call("_aggiorna", 0.0)
	assert_gt(o.call("intensita_vignetta"), a50, "vignetta piu' intensa a follia piu' alta")
	_via(o)


func test_nero_di_scena_solo_sopra_soglia_70() -> void:
	var o: Node = _overlay()
	_m().call("add", 50.0, "x")   # sotto 70
	o.call("forza_scatto_nero")
	o.call("_aggiorna", 0.0)
	assert_almost_eq(o.call("alpha_nero"), 0.0, "sotto soglia 70: niente nero anche forzando")

	_m().call("add", 25.0, "x")   # -> 75
	o.call("forza_scatto_nero")
	o.call("_aggiorna", 0.0)
	assert_gt(o.call("alpha_nero"), 0.0, "sopra 70: il nero di scena si attiva")
	_via(o)


func test_riduci_flash_nero_statico_mai_assente() -> void:
	var o: Node = _overlay()
	_am().call("imposta_accessibilita", "riduci_flash", true)
	_m().call("add", 80.0, "x")   # sopra 70
	o.call("_aggiorna", 0.0)
	var n1: float = o.call("alpha_nero")
	assert_gt(n1, 0.0, "con riduci_flash il nero c'e' comunque (FR-8: mai assente)")
	# e resta costante: nessun lampeggio
	for i in 30:
		o.call("_process", 0.1)
	assert_almost_eq(o.call("alpha_nero"), n1, "resta statico, non lampeggia")
	_via(o)


func test_distorsione_disattivabile() -> void:
	var o: Node = _overlay()
	_m().call("add", 60.0, "x")   # sopra 40
	o.call("forza_scatto_distorsione")
	o.call("_aggiorna", 0.0)
	assert_gt(o.call("get_node", "Distorsione").color.a, 0.0, "scatto di distorsione visibile")
	_via(o)
