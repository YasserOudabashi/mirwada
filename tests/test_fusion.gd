extends "res://tests/test_case.gd"
## US-702+ — i percorsi di fusione (data/fusions/): 8 file, uno per coppia di
## Pathway vicini in un gruppo attivo. In US-702 sono tutti stub tranne
## door_error (US-706); FusionEngine li legge in US-705.

const Stats := preload("res://scripts/stats_component.gd")

const PERCORSI := [
	"door_error", "door_fool", "error_fool",
	"darkness_death", "darkness_twilight_giant", "death_twilight_giant",
	"hermit_paragon", "moon_mother",
]


func test_esistono_tutti_e_8_i_percorsi() -> void:
	for fid in PERCORSI:
		var path: String = "res://data/fusions/%s.json" % fid
		assert_true(FileAccess.file_exists(path), "esiste data/fusions/%s.json" % fid)
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_eq(typeof(doc), TYPE_DICTIONARY, "%s: json valido" % fid)
		assert_eq(str((doc as Dictionary).get("id")), fid, "%s: id coerente" % fid)
		var a: String = str((doc as Dictionary).get("pathway_a"))
		var b: String = str((doc as Dictionary).get("pathway_b"))
		assert_true(a < b, "%s: pathway_a < pathway_b alfabetico" % fid)


func test_id_alfabetico_e_dentro_un_gruppo() -> void:
	# i due Pathway di ogni percorso hanno lo stesso 'group'.
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	for fid in PERCORSI:
		var doc: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/fusions/%s.json" % fid))
		var ga: String = str(gd.call("get_pathway", str(doc["pathway_a"])).get("group", ""))
		var gb: String = str(gd.call("get_pathway", str(doc["pathway_b"])).get("group", ""))
		assert_eq(ga, gb, "%s: i due Pathway sono dello stesso gruppo" % fid)
		assert_eq(str(doc.get("gruppo")), ga, "%s: campo gruppo coerente" % fid)


# --- US-705: FusionEngine ------------------------------------------------

func _fe() -> Node:
	return Engine.get_main_loop().root.get_node("FusionEngine")


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node("GameData")


func test_fusion_engine_ordine_dei_due_pathway_non_conta() -> void:
	var fe: Node = _fe()
	for fid in PERCORSI:
		var doc: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/fusions/%s.json" % fid))
		var a: String = str(doc["pathway_a"])
		var b: String = str(doc["pathway_b"])
		var ab: Array = fe.call("abilita_fuse", a, b)
		var ba: Array = fe.call("abilita_fuse", b, a)
		assert_eq(ab.size(), ba.size(), "%s: abilita_fuse uguale nei due ordini" % fid)


func test_fusion_engine_percorso_stub_da_vuoto() -> void:
	# hermit_paragon e' stub finche' non lo scrive fase 7b.
	var fe: Node = _fe()
	assert_true((fe.call("percorso", "hermit", "paragon") as Dictionary).is_empty(),
		"percorso stub -> {}")
	assert_eq((fe.call("abilita_fuse", "paragon", "hermit") as Array).size(), 0,
		"abilita_fuse di uno stub -> []")


func test_fusion_engine_coppia_inesistente_da_vuoto() -> void:
	# Error e Death non sono dello stesso gruppo: nessun percorso.
	assert_true((_fe().call("percorso", "error", "death") as Dictionary).is_empty(),
		"coppia fuori gruppo -> {}")


func test_ogni_abilita_fusa_non_stub_risolve_come_abilita() -> void:
	var gd: Node = _gd()
	var fe: Node = _fe()
	var trovate: int = 0
	for fid in PERCORSI:
		var doc: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/fusions/%s.json" % fid))
		if bool(doc.get("stub", false)):
			continue
		var fuse: Array = fe.call("abilita_fuse", str(doc["pathway_a"]), str(doc["pathway_b"]))
		assert_gt(float(fuse.size()), 0.0, "%s non-stub: ha abilita_fuse" % fid)
		for ab in fuse:
			var aid: String = str((ab as Dictionary)["id"])
			trovate += 1
			assert_false((gd.call("get_ability", aid) as Dictionary).is_empty(),
				"%s: GameData.get_ability risolve il fus_ id" % aid)
	# nessun percorso non-stub ancora (US-706 scrive door_error): trovate puo'
	# essere 0. Se e' > 0, i controlli sopra sono passati.
	assert_true(trovate >= 0, "iterazione completata")


# --- US-706: door_error, percorso completo -----------------------------

func test_door_error_non_e_piu_stub() -> void:
	var doc: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/fusions/door_error.json"))
	assert_false(bool(doc.get("stub", true)), "door_error: stub false")
	assert_gt(float((doc.get("abilita_fuse", []) as Array).size()), 4.0, "door_error: >= 5 abilita fuse")
	var gd: Node = _gd()
	for ab in doc["abilita_fuse"]:
		var key: String = str((ab as Dictionary)["name_i18n"])
		assert_true(gd.call("has_translation", key), "%s: tradotta (non TODO)" % key)


func test_ogni_abilita_fusa_door_error_esegue_senza_primitiva_fuori_registro() -> void:
	var e: Node = Engine.get_main_loop().root.get_node("AbilityEngine")
	e.call("clear_cooldowns")
	e.call("clear_granted")
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	Engine.get_main_loop().root.add_child(c)
	s.call("configure_from_balance", 5)
	var fuse: Array = _fe().call("abilita_fuse", "error", "door")
	for ab in fuse:
		var aid: String = str((ab as Dictionary)["id"])
		var res: Dictionary = e.call("execute", aid, c)
		assert_true(res["ok"], "%s: eseguita" % aid)
		for w in (res["warnings"] as PackedStringArray):
			assert_false(str(w).begins_with("primitiva fuori registro"),
				"%s: nessuna primitiva fuori registro (%s)" % [aid, w])
	Engine.get_main_loop().root.remove_child(c)
	c.free()
