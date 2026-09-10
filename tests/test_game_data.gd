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
	# 10 Pathway STANDARD attivi: e' lo scope deciso in SETUP-2, pathway_ids()
	# resta scoped ai soli standard anche dopo fase 9 (US-902/US-903). Se
	# questo numero cambia senza una decisione esplicita, e' un bug.
	assert_eq(gd.call("pathway_ids").size(), 10, "pathway STANDARD caricati")
	# sequence_count() somma anche le Sequenze dei Pathway non_standard
	# (data/pathways_non_standard/, servono a Progression/BoonSystem): 100
	# standard + le 10 di Eternal Aeon (US-904) = 110. Se questo numero
	# cambia senza una decisione esplicita (un nuovo Pathway, standard o
	# non_standard), e' un bug.
	assert_eq(gd.call("sequence_count"), 110, "sequenze totali (standard + non_standard)")


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
	var riferite: Dictionary = {}
	for pid in gd.call("pathway_ids"):
		var p: Dictionary = gd.call("get_pathway", pid)
		for entry in (p.get("sequences", []) as Array):
			var seq: Dictionary = entry
			for aid in (seq.get("abilities", []) as Array):
				riferite[str(aid)] = true
				if (gd.call("get_ability", str(aid)) as Dictionary).is_empty():
					mancanti.append(str(aid))
	# Ogni id elencato da una Sequenza DEVE risolvere. Se in futuro si aggiunge
	# un riferimento senza scrivere l'abilita', questo test lo becca (prima la
	# lista 'mancanti' veniva costruita e mai controllata).
	assert_eq(mancanti.size(), 0, "abilita' riferite ma non caricate: %s" % [mancanti])
	assert_gt(float(gd.call("ability_count")), 0.0, "almeno un'abilita' caricata")
	assert_gt(float(riferite.size()), 0.0, "almeno un'abilita' riferita dalle Sequenze")


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
	# Il loader ha caricato TUTTE le voci del file, non un sottoinsieme. Il
	# numero e' derivato da tags.json, non scritto qui: che il vocabolario
	# chiuso non cresca di nascosto lo controlla il validator Python.
	var f := FileAccess.open("res://data/tags.json", FileAccess.READ)
	var doc: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	assert_eq(gd.call("tag_count"), (doc["tags"] as Array).size(), "tutte le voci di tags.json caricate")
