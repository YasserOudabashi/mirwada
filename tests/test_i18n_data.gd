extends "res://tests/test_case.gd"
## US-220 — cataloghi di stringhe DEI DATI (data/i18n/), distinti dal tr() di
## Godot per la UI chrome. Vedi CLAUDE.md sez. i18n.


func _data() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


func test_catalogo_it_caricato() -> void:
	var gd: Node = _data()
	assert_gt(float((gd.call("i18n_keys") as Array).size()), 100.0,
		"data/i18n/it.json ha una voce per ogni chiave dei dati attivi")


func test_chiave_presente_traduce() -> void:
	var gd: Node = _data()
	# Chiave canonica di un'acting_action del Twilight Giant: seed dal campo
	# 'descrizione' gia' in chiaro nei dati.
	var s: String = gd.call("tr_data", "acting.twilight_giant.tg_9_duello_puro")
	assert_ne(s, "acting.twilight_giant.tg_9_duello_puro", "risolve, non torna la chiave")
	assert_false(s.begins_with("TODO "), "e' testo vero, non uno stub")


## Nessuna voce di it.json e' ancora uno stub "TODO ..." (it.json copre solo
## i dati attivi - pathways_deferred esclusi dal generatore). Il giocatore
## non deve mai vedere "TODO ability.xxx" a schermo.
func test_nessuno_stub_todo_in_it() -> void:
	var gd: Node = _data()
	var stub: Array = []
	for k in gd.call("i18n_keys"):
		if str(gd.call("tr_data", str(k), "it")).begins_with("TODO "):
			stub.append(k)
	assert_eq(stub.size(), 0, "chiavi ancora da tradurre in it.json: %s" % [stub])


func test_chiave_mancante_torna_la_chiave() -> void:
	var gd: Node = _data()
	assert_eq(gd.call("tr_data", "chiave.inventata.xyz"), "chiave.inventata.xyz",
		"chiave ignota -> se stessa, mai vuoto, mai crash")
	assert_eq(gd.call("tr_data", ""), "", "chiave vuota -> stringa vuota")


func test_fallback_en_su_it() -> void:
	var gd: Node = _data()
	# en.json e' incompleto per scelta: una chiave assente in en ricade su it.
	var it_s: String = gd.call("tr_data", "acting.twilight_giant.tg_9_duello_puro", "it")
	var en_s: String = gd.call("tr_data", "acting.twilight_giant.tg_9_duello_puro", "en")
	assert_eq(en_s, it_s, "en manca la voce -> stesso testo di it")


func test_ogni_chiave_i18n_dei_pathway_attivi_risolve() -> void:
	# Lo stesso invariante del validator, ma dentro il motore: nessuna chiave
	# *_i18n referenziata da un Pathway/Sequenza/abilita' attiva punta nel vuoto.
	var gd: Node = _data()
	var rotte: Array = []
	for pid in gd.call("pathway_ids"):
		var p: Dictionary = gd.call("get_pathway", pid)
		_controlla(gd, p.get("name_i18n", ""), pid, rotte)
		for seq in p.get("sequences", []):
			_controlla(gd, (seq as Dictionary).get("name_i18n", ""), pid, rotte)
			for act in (seq as Dictionary).get("acting_actions", []):
				_controlla(gd, (act as Dictionary).get("descrizione_i18n", ""), pid, rotte)
	assert_eq(rotte.size(), 0, "chiavi i18n che non risolvono: %s" % [rotte])


func _controlla(gd: Node, key: String, dove: String, rotte: Array) -> void:
	if key.is_empty():
		return
	if gd.call("tr_data", key) == key and not gd.call("has_translation", key):
		rotte.append("%s (%s)" % [key, dove])
