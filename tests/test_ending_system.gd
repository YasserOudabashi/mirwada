extends "res://tests/test_case.gd"
## US-717 — EndingSystem: valuta() sceglie, tra i finali con condizioni tutte
## soddisfatte, quello con priorita' piu' alta; ascolta Madness/RitualSystem/
## KnowledgeStore per rivalutare live e scrivere endgame.finale.

func _root() -> Node: return Engine.get_main_loop().root
func _es() -> Node: return _root().get_node("EndingSystem")
func _prog() -> Node: return _root().get_node("Progression")
func _madness() -> Node: return _root().get_node("Madness")
func _ks() -> Node: return _root().get_node("KnowledgeStore")
func _anc() -> Node: return _root().get_node("AnchorSystem")
func _eg() -> Node: return _root().get_node("EndgameState")
func _rs() -> Node: return _root().get_node("RitualSystem")
func _book() -> Node: return _root().get_node("Book")


func prepara() -> void:
	_madness().call("azzera")
	_ks().call("dimentica_tutto")
	_anc().call("pulisci")
	_eg().call("pulisci")
	if bool(_book().call("e_aperto")):
		_book().call("chiudi")
	_prog().call("configura", "twilight_giant", 5)


## _rivaluta() e' agganciata ai segnali di Madness/RitualSystem/KnowledgeStore:
## ogni test che spinge una condizione a soddisfatta puo' far scattare
## _raggiungi() (pausa dell'albero + libro aperto). Va SEMPRE chiamata a fine
## test, altrimenti l'albero in pausa filtra nelle suite successive.
func _fine() -> void:
	_madness().call("azzera")
	_ks().call("dimentica_tutto")
	_anc().call("pulisci")
	_eg().call("pulisci")
	if bool(_book().call("e_aperto")):
		_book().call("chiudi")
	_prog().call("configura", "", 9)


func test_nessuna_condizione_soddisfatta() -> void:
	assert_eq(str(_es().call("valuta")), "", "niente e' soddisfatto all'inizio")
	_fine()


func test_follia_100_e_consumazione() -> void:
	_madness().call("add", 100.0, "test", false)
	assert_eq(str(_es().call("valuta")), "consumazione", "madness_min 100 -> consumazione")
	_fine()


func test_sequenza_0_piu_rituale_e_apoteosi() -> void:
	_prog().call("configura", "twilight_giant", 0)
	assert_eq(str(_es().call("valuta")), "", "tier god da solo non basta: manca il rituale")
	_rs().emit_signal("rituale_completato", 1)   # 1 = Sequenza di partenza del rituale
	assert_true(bool(_ks().call("conosce", "rituale_sequenza_0_completato")),
		"il flag e' posto quando dopo il rituale si e' a Sequenza 0")
	assert_eq(str(_es().call("valuta")), "apoteosi", "tier god + rituale -> apoteosi")
	_fine()


func test_priorita_consumazione_vince_su_apoteosi() -> void:
	_prog().call("configura", "twilight_giant", 0)
	_rs().emit_signal("rituale_completato", 1)
	_madness().call("add", 100.0, "test", false)
	assert_eq(str(_es().call("valuta")), "consumazione",
		"entrambe soddisfatte insieme: vince la priorita' piu' alta (FR-10)")
	_fine()


func test_rinuncia_richiede_flag_e_ancora_viva() -> void:
	_ks().call("imposta", "pozione_distrutta", true)
	assert_eq(str(_es().call("valuta")), "",
		"il flag da solo non basta: eredita_profilo 'ancore' richiede un'Ancora viva")
	var anchor_ids: Array = _root().get_node("GameData").call("get_anchors")
	assert_gt(float(anchor_ids.size()), 0.0, "servono Ancore nei dati per questo test")
	_anc().call("register", str((anchor_ids[0] as Dictionary).get("id")))
	assert_eq(str(_es().call("valuta")), "rinuncia", "flag + Ancora viva -> rinuncia")
	_fine()


func test_finale_raggiunto_scrive_endgame_e_apre_il_libro() -> void:
	var visti: Array = []
	var cb := func(id: String, gruppo: String) -> void: visti.append([id, gruppo])
	_es().connect("finale_raggiunto", cb)
	_madness().call("add", 100.0, "test", false)   # madness_changed -> _rivaluta live
	_es().disconnect("finale_raggiunto", cb)
	assert_eq(visti.size(), 1, "il segnale e' emesso una volta")
	assert_eq(str(visti[0][0]), "consumazione", "id del finale")
	assert_eq(str(visti[0][1]), "eternal_darkness", "gruppo del Pathway corrente")
	assert_eq(str(_eg().call("get", "finale")), "consumazione", "endgame.finale scritto")
	assert_true(bool(_book().call("e_aperto")), "il libro si apre sul finale")
	_fine()


func test_un_finale_gia_raggiunto_non_si_sovrascrive() -> void:
	_madness().call("add", 100.0, "test", false)
	assert_eq(str(_eg().call("get", "finale")), "consumazione", "consumazione gia' raggiunta")
	_ks().call("imposta", "pozione_distrutta", true)   # non dovrebbe cambiare nulla
	assert_eq(str(_eg().call("get", "finale")), "consumazione", "il finale resta quello raggiunto per primo")
	_fine()
