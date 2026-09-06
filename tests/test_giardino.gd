extends "res://tests/test_case.gd"
## US-328 — il giardino: pianta un ingrediente coltivabile, cresce col tempo di
## gioco, raccoglilo in piu' copie. La crescita si ferma col mondo in pausa
## (BaseSystem e' PROCESS_MODE_PAUSABLE).

const SLOT := 909


func _bs() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("BaseSystem")


func _inv() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Inventory")


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SaveSystem")


func prepara() -> void:
	if _bs() != null:
		_bs().call("pulisci")
	if _inv() != null:
		_inv().call("pulisci")


func _costruisci_giardino(livello: int) -> void:
	for _i in livello:
		var costo: Dictionary = _bs().call("costo_prossimo", "giardino")
		for item_id in costo:
			_inv().call("aggiungi", item_id, int(costo[item_id]))
		if _bs().call("livello", "giardino") == 0:
			_bs().call("costruisci", "giardino")
		else:
			_bs().call("potenzia", "giardino")
	_inv().call("pulisci")


func test_appezzamenti_scalano_col_livello_del_giardino() -> void:
	assert_eq(_bs().call("numero_appezzamenti"), 0, "senza giardino nessun appezzamento")
	_costruisci_giardino(1)
	assert_eq(_bs().call("numero_appezzamenti"), 1, "giardino lv1 -> 1 appezzamento")
	_costruisci_giardino(1)
	assert_eq(_bs().call("numero_appezzamenti"), 2, "giardino lv2 -> 2 appezzamenti")


func test_pianta_solo_ingredienti_coltivabili() -> void:
	_costruisci_giardino(1)
	_inv().call("aggiungi", "polvere_ossa", 1)   # ingrediente NON coltivabile
	assert_eq(_bs().call("pianta", "polvere_ossa"), -1, "polvere_ossa non e' coltivabile")
	_inv().call("aggiungi", "lingotto_ferro", 1) # nemmeno un ingrediente
	assert_eq(_bs().call("pianta", "lingotto_ferro"), -1, "un materiale non si pianta")


func test_pianta_consuma_il_seme_e_l_appezzamento_non_e_pronto_subito() -> void:
	_costruisci_giardino(1)
	_inv().call("aggiungi", "erba_lunare", 2)
	var idx: int = _bs().call("pianta", "erba_lunare")
	assert_eq(idx, 0, "piantata nel primo appezzamento")
	assert_eq(int(_inv().call("conta", "erba_lunare")), 1, "consumato 1 seme")
	assert_false(bool((_bs().call("appezzamenti")[0] as Dictionary)["pronto"]),
		"appena piantata non e' pronta")


func test_niente_appezzamenti_liberi() -> void:
	_costruisci_giardino(1)  # 1 solo appezzamento
	_inv().call("aggiungi", "erba_lunare", 3)
	assert_ne(_bs().call("pianta", "erba_lunare"), -1, "prima semina ok")
	assert_eq(_bs().call("pianta", "erba_lunare"), -1, "nessun appezzamento libero")


func test_cresce_col_tempo_e_si_raccoglie_in_piu_copie() -> void:
	_costruisci_giardino(2)  # resa_raccolto +2, resa_base 2 -> raccolta 4
	_inv().call("aggiungi", "petalo_solare", 1)
	var idx: int = _bs().call("pianta", "petalo_solare")
	_bs().call("_process", 10.0)
	assert_false(bool((_bs().call("appezzamenti")[idx] as Dictionary)["pronto"]),
		"a meta' crescita non e' pronta")
	_bs().call("_process", 30.0)  # oltre tempo_crescita_s (30)
	assert_true(bool((_bs().call("appezzamenti")[idx] as Dictionary)["pronto"]),
		"passato il tempo di crescita e' pronta")

	var n: int = _bs().call("raccogli", idx)
	assert_eq(n, 4, "resa_base 2 + resa_raccolto 2 del giardino lv2")
	assert_eq(int(_inv().call("conta", "petalo_solare")), 4, "4 petali nello zaino")
	assert_eq(str((_bs().call("appezzamenti")[idx] as Dictionary)["item_id"]), "",
		"l'appezzamento e' di nuovo libero")


func test_raccogli_un_appezzamento_non_pronto_non_da_nulla() -> void:
	_costruisci_giardino(1)
	_inv().call("aggiungi", "erba_lunare", 1)
	var idx: int = _bs().call("pianta", "erba_lunare")
	assert_eq(_bs().call("raccogli", idx), 0, "non pronto -> 0")
	assert_eq(_bs().call("raccogli", 5), 0, "indice fuori range -> 0")


func test_round_trip_a_meta_crescita() -> void:
	var s: Node = _save()
	if s.esiste(SLOT):
		s.cancella(SLOT)
	_costruisci_giardino(1)
	_inv().call("aggiungi", "fungo_cavernicolo", 1)
	_bs().call("pianta", "fungo_cavernicolo")
	_bs().call("_process", 12.0)  # crescita rimasta ~18
	var snap: Dictionary = {"nome_personaggio": "Enel", "base": _bs().call("per_salvataggio")}
	s.salva(SLOT, snap)
	_bs().call("pulisci")

	var caricato: Dictionary = s.carica(SLOT)
	_bs().call("da_salvataggio", (caricato["dati"] as Dictionary)["base"])
	assert_eq(_bs().call("livello", "giardino"), 1, "giardino ripristinato")
	var a: Dictionary = _bs().call("appezzamenti")[0]
	assert_eq(str(a["item_id"]), "fungo_cavernicolo", "coltura ripristinata")
	assert_false(bool(a["pronto"]), "ancora a meta' crescita dopo il load")
	assert_almost_eq(float(a["crescita"]), 18.0, "crescita rimasta conservata", 0.5)
	s.cancella(SLOT)


func test_da_salvataggio_legge_anche_il_vecchio_formato_piatto() -> void:
	# un save v18 pre-giardino aveva base = { tipo: livello }
	_bs().call("da_salvataggio", {"biblioteca": 1, "giardino": 2})
	assert_eq(_bs().call("livello", "biblioteca"), 1, "formato piatto: stanze lette")
	assert_eq(_bs().call("livello", "giardino"), 2, "formato piatto: giardino letto")
	assert_eq(_bs().call("appezzamenti").size(), 2, "0 colture, 2 appezzamenti liberi")
