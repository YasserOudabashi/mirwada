extends "res://tests/test_case.gd"
## US-805..807 — i layout disegnati a mano (data/world/layouts/) restano come dati: la fonte di nemici, boss,
## oggetti, zone ed edifici che mondo.gd popola() riporta sul mondo generato. 2026-11-18: tolto world_scene.gd (il
## mondo a layout della fase 10, sostituito dal mondo generato) e i test che lo istanziavano; il loro contenuto e'
## provato sul mondo vero in tests/test_mondo.gd (nemici e oggetti dei layout, varchi, viaggio, NPC).

func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")
func _et() -> Node: return _root().get_node("EventTracker")


func test_get_layout_presente_e_assente() -> void:
	assert_false(_gd().call("get_layout", "mirwada").is_empty(), "mirwada ha un layout")
	assert_false(_gd().call("get_layout", "marche_crepuscolo").is_empty(), "marche_crepuscolo ha un layout")
	assert_false(_gd().call("get_layout", "valle_madre").is_empty(), "valle_madre ha un layout")
	assert_false(_gd().call("get_layout", "archivio_sepolto").is_empty(), "archivio_sepolto ha un layout")
	assert_false(_gd().call("get_layout", "frontiera_porte").is_empty(), "frontiera_porte ha un layout")
	assert_true(_gd().call("get_layout", "nonesiste").is_empty(), "id ignoto -> {}")


func test_tutte_le_regioni_hanno_un_layout() -> void:
	for r in _gd().call("get_regions"):
		var rid: String = str((r as Dictionary).get("id", ""))
		assert_false(_gd().call("get_layout", rid).is_empty(),
			"la regione '%s' ha un layout disegnato a mano" % rid)


## Ripreso da world_scene sul mondo vero: quando muore l'ultimo nemico della regione si registra area_cleared.
func test_area_cleared_alla_morte_dell_ultimo_nemico_della_regione() -> void:
	var m: Node2D = preload("res://scripts/world/mondo.gd").new()
	_root().add_child(m)
	_et().call("azzera")
	var nemici: Array = m.get_children().filter(func(c): return c.is_in_group("nemici") and str(c.get_meta("regione_layout", "")) == "mirwada")
	assert_gt(float(nemici.size()), 0.0, "Mirwada ha i suoi nemici dal layout")
	for e in nemici:
		e.emit_signal("morto", e)
	assert_eq(int(_et().call("count", "area_cleared", {})), 1, "l'ultimo che muore: area_cleared una volta")
	m.free()
	_et().call("azzera")
