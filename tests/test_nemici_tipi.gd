extends "res://tests/test_case.gd"
## US-1501 — Un tipo di nemico e' un dato (balance.json nemici_tipi): il nemico parte da nemico_base, ci mette sopra
## il tipo e poi l'override dell'istanza. Ogni nemico posato nel mondo ha un tipo.

func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")


func _nemico(tipo: String, override: Dictionary = {}) -> Node:
	var e: Node = preload("res://scenes/enemy.tscn").instantiate()
	e.set("tipo", tipo)
	e.set("override", override)
	_root().add_child(e)
	return e


func test_il_tipo_sta_fra_la_base_e_l_override() -> void:
	var tipi: Dictionary = _gd().call("get_balance", "nemici_tipi")
	var base: Dictionary = _gd().call("get_balance", "nemico_base")
	var e: Node = _nemico("colosso_arrugginito")
	var cfg: Dictionary = e.get("_cfg")
	assert_eq(cfg["danno_attacco"], tipi["colosso_arrugginito"]["danno_attacco"], "il danno e' quello del tipo")
	assert_eq(cfg["angolo_arco"], base["angolo_arco"], "quello che il tipo non dice resta di nemico_base")
	assert_eq(str(e.call("nome")), str(_gd().call("tr_data", "enemy.colosso_arrugginito")), "e il nome e' del tipo")
	e.free()
	var f: Node = _nemico("colosso_arrugginito", {"danno_attacco": 1})
	assert_eq((f.get("_cfg") as Dictionary)["danno_attacco"], 1, "l'override dell'istanza vince sul tipo")
	f.free()
	var g: Node = _nemico("")
	assert_eq((g.get("_cfg") as Dictionary)["danno_attacco"], base["danno_attacco"], "senza tipo: nemico_base come prima")
	assert_false((_gd().call("get_balance", "nemico_base") as Dictionary).has("rarita"), "il tipo non sporca nemico_base")
	g.free()


func test_i_comuni_si_leggono_meglio_dei_rari() -> void:
	var tipi: Dictionary = _gd().call("get_balance", "nemici_tipi")
	var tell: Dictionary = _gd().call("get_audio", "telegraph")
	var n := 0
	for tid in tipi:
		if str(tid).begins_with("_"):
			continue
		n += 1
		var t: Dictionary = tipi[tid]
		var ms: float = float((tell.get(str(t["telegraph"]), {}) as Dictionary).get("anticipo_ms", 0))
		if str(t["rarita"]) == "comune":
			assert_true(ms >= 600.0, "%s comune: tell lungo, leggibile (%d ms)" % [tid, ms])
		else:
			assert_true(ms < 600.0, "%s %s: tell corto, teso (%d ms)" % [tid, t["rarita"], ms])
	assert_true(n >= 36, "il bestiario dell'utente: almeno 36 tipi (%d)" % n)


func test_ogni_nemico_posato_ha_il_suo_tipo() -> void:
	var tipi: Dictionary = _gd().call("get_balance", "nemici_tipi")
	var file: Array = ["res://data/world/campagna.json"]
	for d in ["res://data/world/layouts", "res://data/world/interni"]:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".json"):
				file.append(d + "/" + f)
	var visti := 0
	for f in file:
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(f))
		for nm in doc.get("nemici", []):
			visti += 1
			assert_true(tipi.has(str((nm as Dictionary).get("tipo", ""))), "%s: il nemico in (%s, %s) ha un tipo" % [f, nm.get("x"), nm.get("y")])
	assert_true(visti >= 70, "i nemici del mondo (%d)" % visti)
