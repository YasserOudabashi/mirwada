extends "res://tests/test_case.gd"
## US-207 — Caratteristica Beyonder come oggetto: dati, drop, raccolta, save.

const EnemyScene := preload("res://scenes/enemy.tscn")
const Pickup := preload("res://scripts/characteristic_pickup.gd")

const SLOT := 906


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node("GameData")


func _store() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("CharacteristicStore")


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SaveSystem")


func prepara() -> void:
	if _store() != null:
		_store().call("pulisci")


func _root() -> Node:
	return Engine.get_main_loop().root


func test_caratteristiche_caricate_dai_dati() -> void:
	var c: Dictionary = _gd().call("get_characteristic", "char_twilight_giant_9")
	assert_false(c.is_empty(), "char_twilight_giant_9 caricata")
	assert_eq(c["pathway_id"], "twilight_giant", "pathway_id")
	assert_eq(int(c["sequence"]), 9, "sequence")
	var per_ps: Dictionary = _gd().call("characteristic_for", "twilight_giant", 5)
	assert_eq(per_ps.get("id"), "char_twilight_giant_5", "lookup per (Pathway, Sequenza)")


func test_store_aggiungi_consuma_conta() -> void:
	var s: Node = _store()
	s.call("aggiungi", "char_twilight_giant_9")
	s.call("aggiungi", "char_twilight_giant_9")
	s.call("aggiungi", "char_twilight_giant_8")
	assert_eq(s.call("conta"), 3, "tre in totale")
	assert_eq(s.call("conta", "char_twilight_giant_9"), 2, "due uguali")
	assert_true(s.call("possiede", "char_twilight_giant_8"), "possiede la 8")

	assert_true(s.call("consuma", "char_twilight_giant_9"), "consuma una occorrenza")
	assert_eq(s.call("conta", "char_twilight_giant_9"), 1, "ne resta una")
	assert_false(s.call("consuma", "char_twilight_giant_0"), "consuma cio' che non c'e' -> false")


func test_nemico_lascia_la_caratteristica_alla_morte() -> void:
	var enemy: Node = EnemyScene.instantiate()
	_root().add_child(enemy)
	await Engine.get_main_loop().process_frame
	enemy.get_node("StatsComponent").set("hp", 0.0)  # -> died -> _su_morte
	await Engine.get_main_loop().process_frame

	var pickup: Node = null
	for n in _root().get_children():
		if n.get("char_id") != null and str(n.get("char_id")) == "char_twilight_giant_9":
			pickup = n
	assert_true(pickup != null, "una Caratteristica a terra (drop garantito, probabilita 1.0)")

	if pickup != null:
		assert_true(pickup.call("raccogli"), "raccolta")
		assert_eq(_store().call("conta", "char_twilight_giant_9"), 1, "entrata nel magazzino")
		assert_false(pickup.call("raccogli"), "non si raccoglie due volte")
	_root().remove_child(enemy)
	enemy.free()


func test_persistenza_nel_save() -> void:
	var s: Node = _save()
	var gs: Node = _root().get_node("GameState")
	_store().call("aggiungi", "char_twilight_giant_7")
	_store().call("aggiungi", "char_twilight_giant_7")

	if s.esiste(SLOT):
		s.cancella(SLOT)
	assert_true(s.salva(SLOT, gs.snapshot())["ok"], "salva ok")

	_store().call("pulisci")
	assert_eq(_store().call("conta"), 0, "magazzino azzerato")

	var c: Dictionary = s.carica(SLOT)
	gs.applica(c["dati"])
	assert_eq(_store().call("conta", "char_twilight_giant_7"), 2, "ripristinate dal save")
	s.cancella(SLOT)


func test_migrazione_da_v6() -> void:
	var s: Node = _save()
	if s.esiste(SLOT):
		s.cancella(SLOT)
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open("user://saves/slot_%d.json" % SLOT, FileAccess.WRITE)
	f.store_string('{"schema_version": 6, "nome_personaggio": "v6", "posizione": [0,0], "statistiche": {}, "evocazioni": [], "progressione": {"pathway_id": "", "sequence": 9}, "mondo": {"terrain_mods": []}, "eventi": {"log": []}, "acting": {}}')
	f.close()
	var c: Dictionary = s.carica(SLOT)
	assert_true(c["ok"] and c["migrato"], "migrazione applicata")
	assert_eq((c["dati"] as Dictionary)["caratteristiche"], [], "campo caratteristiche aggiunto vuoto")
	s.cancella(SLOT)


func test_da_salvataggio_scarta_le_voci_non_stringa() -> void:
	var s: Node = _store()
	s.call("da_salvataggio", ["char_twilight_giant_9", 42, {"x": 1}, "", "char_twilight_giant_8"])
	assert_eq(s.call("conta"), 2, "solo le stringhe non vuote")
	s.call("da_salvataggio", "non una lista")
	assert_eq(s.call("conta"), 0, "raw non-lista -> vuoto")
