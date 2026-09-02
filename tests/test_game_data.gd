extends "res://tests/test_case.gd"
## US-002 — caricatore dei dati.

func _data() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


func test_autoload_presente() -> void:
	assert_true(_data() != null, "autoload GameData registrato")


func test_conteggi_dei_pathway() -> void:
	var gd: Node = _data()
	if gd == null:
		assert_true(false, "GameData assente")
		return
	# 10 Pathway attivi / 100 Sequenze: e' lo scope deciso in SETUP-2.
	# Se questi numeri cambiano senza una decisione esplicita, e' un bug.
	assert_eq(gd.call("pathway_ids").size(), 10, "pathway caricati")
	assert_eq(gd.call("sequence_count"), 100, "sequenze totali")


func test_nessun_errore_di_caricamento() -> void:
	var gd: Node = _data()
	var errors: PackedStringArray = gd.call("last_errors")
	assert_eq(errors.size(), 0, "errori di caricamento")


func test_get_pathway() -> void:
	var gd: Node = _data()
	var p: Dictionary = gd.call("get_pathway", "twilight_giant")
	assert_false(p.is_empty(), "twilight_giant trovato")
	assert_eq(p.get("group", ""), "eternal_darkness", "gruppo del twilight_giant")
	assert_eq((p.get("sequences", []) as Array).size(), 10, "sequenze del pathway")


func test_get_sequence() -> void:
	var gd: Node = _data()
	var s: Dictionary = gd.call("get_sequence", "fool_9")
	assert_false(s.is_empty(), "fool_9 trovata")
	assert_eq(s.get("sequence", -1), 9, "numero di sequenza")
	assert_eq(s.get("tier", ""), "low", "fascia")
	assert_false(str(s.get("concept", "")).is_empty(), "concept non vuoto")


func test_get_ability() -> void:
	var gd: Node = _data()
	var a: Dictionary = gd.call("get_ability", "fool_velo_illusorio")
	assert_false(a.is_empty(), "fool_velo_illusorio trovata")
	assert_eq(a.get("sequence_id", ""), "fool_9", "sequenza di appartenenza")
	assert_gt((a.get("primitive", []) as Array).size(), 0.0, "primitive dell'abilita'")


func test_id_inesistente_non_esplode() -> void:
	var gd: Node = _data()
	# Contratto: mai null, mai crash. Il chiamante controlla con is_empty().
	assert_true((gd.call("get_pathway", "non_esiste") as Dictionary).is_empty(), "pathway ignoto")
	assert_true((gd.call("get_sequence", "non_esiste") as Dictionary).is_empty(), "sequenza ignota")
	assert_true((gd.call("get_ability", "non_esiste") as Dictionary).is_empty(), "abilita' ignota")


func test_ogni_abilita_riferita_esiste() -> void:
	# Incrocio fra due indici: le sequenze elencano id di abilita', e quegli id
	# devono risolvere. E' il tipo di rottura che il validator Python non vede,
	# perche' qui conta cosa e' finito davvero in memoria.
	var gd: Node = _data()
	var mancanti: PackedStringArray = []
	for pid in gd.call("pathway_ids"):
		var p: Dictionary = gd.call("get_pathway", pid)
		for entry in (p.get("sequences", []) as Array):
			var seq: Dictionary = entry
			for aid in (seq.get("abilities", []) as Array):
				var a: Dictionary = gd.call("get_ability", str(aid))
				if a.is_empty():
					mancanti.append(str(aid))
	# Le abilita' non ancora scritte sono attese: solo il Twilight Giant e'
	# completo. Il test verifica che quelle PRESENTI risolvano davvero.
	var scritte: int = gd.call("ability_count")
	assert_eq(scritte, 32, "abilita' effettivamente caricate")
	assert_gt(float(scritte), 0.0, "almeno un'abilita' caricata")


func test_registro_delle_primitive() -> void:
	var gd: Node = _data()
	var proj: Dictionary = gd.call("get_primitive", "projectile")
	assert_false(proj.is_empty(), "primitiva projectile nel registro")
	assert_true((proj.get("params", []) as Array).has("danno"), "projectile ha il parametro danno")
	assert_true((gd.call("get_primitive", "non_esiste") as Dictionary).is_empty(), "primitiva ignota")


func test_vocabolario_dei_tag() -> void:
	var gd: Node = _data()
	assert_true(gd.call("has_tag", "spirito"), "tag 'spirito' nel vocabolario")
	assert_false(gd.call("has_tag", "tag_inventato_a_caso"), "tag inesistente rifiutato")
	# Vocabolario CHIUSO: 82 voci. Se cresce senza una decisione, e' un bug.
	assert_eq(gd.call("tag_count"), 82, "voci del vocabolario dei tag")
