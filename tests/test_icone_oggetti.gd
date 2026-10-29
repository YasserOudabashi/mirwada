extends "res://tests/test_case.gd"
## US-8B70 — le icone degli oggetti (data/ui/icone.json, tools/art/build_icone.py): a terra e nello zaino.

const ItemPickup := preload("res://scripts/item_pickup.gd")


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node("GameData")


func test_ogni_oggetto_ha_la_sua_icona_32() -> void:
	var gd: Node = _gd()
	var ids: Array = gd.call("item_ids")
	assert_true(ids.size() > 300, "tutti gli oggetti dei dati")
	for iid in ids:
		var tex: Texture2D = gd.call("icona_oggetto", str(iid))
		assert_true(tex != null, "%s ha l'icona" % iid)
		if tex != null:
			assert_eq(tex.get_size(), Vector2(32, 32), "%s: 32 x 32" % iid)


func test_la_stessa_icona_si_legge_una_volta() -> void:
	var gd: Node = _gd()
	assert_true(gd.call("icona_oggetto", "pozione_cura_minore") == gd.call("icona_oggetto", "pozione_cura_maggiore"),
		"due oggetti con la stessa icona (fiala rossa) condividono la texture")


func test_a_terra_l_icona_e_a_mezza_grandezza() -> void:
	var p: Area2D = ItemPickup.new()
	p.call("setup", "piuma_dei_venti", Vector2(10, 20))
	var spr: Sprite2D = null
	for c in p.get_children():
		if c is Sprite2D:
			spr = c
	assert_true(spr != null, "l'oggetto a terra mostra un'icona")
	assert_true(spr.texture == _gd().call("icona_oggetto", "piuma_dei_venti"), "quella dell'oggetto")
	assert_eq(spr.scale, Vector2(0.5, 0.5), "a mezza grandezza: 16 unita', tutti i 32 pixel a schermo")
	p.free()


func test_senza_icona_resta_il_rombo() -> void:
	var p: Area2D = ItemPickup.new()
	p.call("setup", "oggetto_che_non_esiste", Vector2.ZERO)
	var rombo := false
	for c in p.get_children():
		rombo = rombo or c is Polygon2D
	assert_true(rombo, "un id senza icona non rompe niente: il segnaposto di characteristic_pickup")
	p.free()
