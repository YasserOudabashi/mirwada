extends "res://tests/test_case.gd"
## US-327 — le stanze alimentano i loro sistemi: PotionSystem legge
## bonus("laboratorio"), Forge bonus("stanza_rituale"), la biblioteca rende
## note le prime ricette avanzate. Nessun sistema hardcoda il nome di una
## stanza: legge bonus(tipo) per chiave.


func _bs() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("BaseSystem")


func _ps() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("PotionSystem")


func _forge() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Forge")


func _inv() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Inventory")


func _kn() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("KnowledgeStore")


func prepara() -> void:
	if _bs() != null:
		_bs().call("pulisci")
	if _inv() != null:
		_inv().call("pulisci")
	if _kn() != null and _kn().has_method("dimentica_tutto"):
		_kn().call("dimentica_tutto")


func _costruisci_livello(tipo: String, livello: int) -> void:
	for _i in livello:
		var costo: Dictionary = _bs().call("costo_prossimo", tipo)
		for item_id in costo:
			_inv().call("aggiungi", item_id, int(costo[item_id]))
		if _bs().call("livello", tipo) == 0:
			_bs().call("costruisci", tipo)
		else:
			_bs().call("potenzia", tipo)
	_inv().call("pulisci")  # via i materiali di costruzione, restano solo gli item dei test


func test_laboratorio_alza_la_qualita_della_pozione() -> void:
	_inv().call("aggiungi", "petalo_solare", 1)
	_inv().call("aggiungi", "acqua_sorgiva", 1)
	var senza: Dictionary = _ps().call("prepara", "ric_cura_minore")  # qualita_base "pura"
	assert_eq(str(senza.get("qualita")), "pura", "senza laboratorio: qualita di base")

	_costruisci_livello("laboratorio", 2)  # bonus qualita_pozione +1
	_inv().call("aggiungi", "petalo_solare", 1)
	_inv().call("aggiungi", "acqua_sorgiva", 1)
	var con: Dictionary = _ps().call("prepara", "ric_cura_minore")
	assert_eq(str(con.get("qualita")), "eccelsa", "laboratorio lv2: +1 sulla scala -> eccelsa")


func test_laboratorio_riduce_il_rischio_degli_esperimenti() -> void:
	assert_almost_eq(float(_ps().call("_riduzione_rischio")), 0.0,
		"senza laboratorio: nessuna riduzione del rischio")
	_costruisci_livello("laboratorio", 2)  # rischio_esperimento -20 (punti %)
	assert_almost_eq(float(_ps().call("_riduzione_rischio")), 0.20,
		"laboratorio lv2: -20 punti -> riduzione 0.20")


func test_laboratorio_abbassa_il_peso_dei_fallimenti_mostruosi() -> void:
	# statistico ma deterministico: stesso seed, combo che non matcha nessuna
	# ricetta -> sempre _fallimento, pesato.
	var senza := _conta_aberrazioni(false)
	var con := _conta_aberrazioni(true)
	assert_true(con < senza,
		"con laboratorio lv2 meno aberrazioni (%d) che senza (%d)" % [con, senza])


func _conta_aberrazioni(con_lab: bool) -> int:
	_bs().call("pulisci")
	_inv().call("pulisci")
	if con_lab:
		_costruisci_livello("laboratorio", 2)
	_inv().call("aggiungi", "polvere_ossa", 400)
	_ps().call("imposta_seed", 4242)
	var n := 0
	for _i in 100:
		var r: Dictionary = _ps().call("sperimenta", ["polvere_ossa", "polvere_ossa"])
		if str(r.get("esito")) == "aberrazione":
			n += 1
	return n


func test_stanza_rituale_alza_la_qualita_della_forgia() -> void:
	_inv().call("aggiungi", "cristallo_grezzo", 2)
	_inv().call("aggiungi", "lingotto_ferro", 1)
	var senza: Dictionary = _forge().call("forgia", "bp_amuleto_lunare")  # qualita_base "instabile"
	assert_eq(str(senza.get("qualita")), "instabile", "senza stanza rituale: qualita di base")

	_costruisci_livello("stanza_rituale", 2)  # qualita_forgia +2
	_inv().call("aggiungi", "cristallo_grezzo", 2)
	_inv().call("aggiungi", "lingotto_ferro", 1)
	var con: Dictionary = _forge().call("forgia", "bp_amuleto_lunare")
	assert_eq(str(con.get("qualita")), "eccelsa", "stanza rituale lv2: +2 -> eccelsa (clamp)")


func test_biblioteca_rende_note_le_prime_ricette_avanzate() -> void:
	# avanzate in ordine: ric_cura_maggiore, ric_elisir_ombra
	assert_false(_ps().call("ricetta_nota", "ric_cura_maggiore"),
		"senza biblioteca: la ricetta avanzata non e' nota")

	_costruisci_livello("biblioteca", 1)  # ricette_avanzate_note = 1
	assert_true(_ps().call("ricetta_nota", "ric_cura_maggiore"),
		"biblioteca lv1: la 1a avanzata e' nota")
	assert_false(_ps().call("ricetta_nota", "ric_elisir_ombra"),
		"biblioteca lv1: la 2a avanzata NON e' ancora nota")

	_costruisci_livello("biblioteca", 1)  # ora lv2, ricette_avanzate_note = 2
	assert_true(_ps().call("ricetta_nota", "ric_elisir_ombra"),
		"biblioteca lv2: anche la 2a avanzata e' nota")
