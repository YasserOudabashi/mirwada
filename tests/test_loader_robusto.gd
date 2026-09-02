extends "res://tests/test_case.gd"
## US-022 — il loader regge ai dati strutturalmente storti senza crashare.
##
## I JSON restano in chiaro nell'export: un file sintatticamente valido ma con
## la forma sbagliata (una lista dov'era atteso un oggetto, un elemento
## non-oggetto in una lista, una radice-lista) deve produrre un errore
## registrato e il file scartato, MAI un crash su un'assegnazione tipata.
##
## Le fixture in tests/fixtures/ non matchano test_*.gd (il runner non le
## esegue) e stanno fuori da data/ (il loader non le scansiona): i test
## chiamano gli helper del loader direttamente, poi reload() per riportare
## GameData allo stato pulito — gli helper appesi a _errors lo sporcano.

const FIX := "res://tests/fixtures/"
const Stats := preload("res://scripts/stats_component.gd")


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


func _pulisci(gd: Node) -> void:
	gd.call("reload")


func test_radice_non_oggetto_scartata() -> void:
	var gd: Node = _gd()
	var doc: Dictionary = gd.call("_read_json", FIX + "radice_lista.json")
	assert_true(doc.is_empty(), "radice-lista -> documento vuoto, non un crash")
	assert_gt(gd.call("last_errors").size(), 0, "errore registrato, non silenzioso")
	_pulisci(gd)


func test_lista_attesa_ma_e_oggetto() -> void:
	var gd: Node = _gd()
	var doc: Dictionary = gd.call("_read_json", FIX + "sequences_oggetto.json")
	var items: Array = gd.call("_object_list", doc, "sequences", "fixture")
	assert_eq(items.size(), 0, "'sequences' come oggetto -> nessun elemento estratto")
	assert_gt(gd.call("last_errors").size(), 0, "errore registrato")
	_pulisci(gd)


func test_elementi_non_oggetto_saltati_uno_a_uno() -> void:
	var gd: Node = _gd()
	var doc: Dictionary = gd.call("_read_json", FIX + "elementi_non_oggetto.json")
	var items: Array = gd.call("_object_list", doc, "abilities", "fixture")
	assert_eq(items.size(), 1, "sopravvive solo l'unico elemento-oggetto")
	assert_eq((items[0] as Dictionary).get("id", ""), "buona", "ed e' quello giusto")
	# stringa, numero e lista scartati: almeno 3 errori.
	assert_gt(gd.call("last_errors").size(), 2, "un errore per ogni elemento scartato")
	_pulisci(gd)


func test_single_file_con_chiave_di_forma_sbagliata_scartato() -> void:
	var gd: Node = _gd()
	var target: Dictionary = {}
	gd.call("_load_single", FIX + "tags_oggetto.json", "tags", target, TYPE_ARRAY)
	assert_true(target.is_empty(), "'tags' come oggetto invece che lista: file non caricato")
	assert_gt(gd.call("last_errors").size(), 0, "errore registrato")
	_pulisci(gd)


func test_getter_non_esplodono_su_chiave_ignota() -> void:
	# I getter fanno assegnazioni tipate su valori letti dai JSON: una chiave
	# assente o del tipo sbagliato deve dare il default, non interrompere.
	var gd: Node = _gd()
	assert_true((gd.call("get_balance", "sezione_XZ") as Dictionary).is_empty(), "get_balance ignoto -> {}")
	assert_true((gd.call("get_audio", "sezione_XZ") as Dictionary).is_empty(), "get_audio ignoto -> {}")
	assert_true((gd.call("get_animation", "cat_XZ", "anim_XZ") as Dictionary).is_empty(), "get_animation ignoto -> {}")
	assert_false(gd.call("has_tag", "tag_XZ"), "has_tag ignoto -> false, mai crash")
	assert_almost_eq(gd.call("curve_value", "curva_XZ", 9, 3.0), 3.0, "curve_value ignota -> fallback")
	# I dati veri non sono stati toccati.
	assert_eq(gd.call("last_errors").size(), 0, "nessun errore: i getter non sporcano lo stato")


func _caster_di_prova() -> Node2D:
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	Engine.get_main_loop().root.add_child(c)
	s.call("configure_from_balance", 9)
	return c


func test_ability_engine_primitive_non_e_una_lista() -> void:
	var gd: Node = _gd()
	var eng: Node = _engine()
	var abilities: Dictionary = gd.get("_abilities")
	abilities["_fix_bad"] = {"id": "_fix_bad", "costo_spiritualita": 0, "primitive": {"non": "lista"}}

	var c: Node2D = _caster_di_prova()
	eng.call("clear_cooldowns")
	var r: Dictionary = eng.call("execute", "_fix_bad", c)
	assert_true(r["ok"], "'primitive' non-lista: l'abilita' prosegue senza effetti, nessun crash")
	assert_gt((r["warnings"] as PackedStringArray).size(), 0, "avviso registrato")
	assert_eq((r["effects"] as Array).size(), 0, "nessun effetto")

	abilities.erase("_fix_bad")
	Engine.get_main_loop().root.remove_child(c)
	c.free()


func test_ability_engine_costo_di_tipo_sbagliato() -> void:
	var gd: Node = _gd()
	var eng: Node = _engine()
	var abilities: Dictionary = gd.get("_abilities")
	# costo come oggetto: float() ci solleva "Nonexistent constructor" sopra.
	abilities["_fix_cost"] = {"id": "_fix_cost", "costo_spiritualita": {"x": 1}, "primitive": []}

	var c: Node2D = _caster_di_prova()
	eng.call("clear_cooldowns")
	var r: Dictionary = eng.call("execute", "_fix_cost", c)
	assert_true(r["ok"], "costo non numerico -> trattato come 0, nessun crash")

	abilities.erase("_fix_cost")
	Engine.get_main_loop().root.remove_child(c)
	c.free()
