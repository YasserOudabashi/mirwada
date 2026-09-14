extends "res://tests/test_case.gd"
## US-217 — motore del rituale di avanzamento: prerequisiti, interruzione,
## completamento, sacrificio dell'Ancora.

const SLOT := 909


func _rs() -> Node: return Engine.get_main_loop().root.get_node_or_null("RitualSystem")
func _prog() -> Node: return Engine.get_main_loop().root.get_node_or_null("Progression")
func _et() -> Node: return Engine.get_main_loop().root.get_node_or_null("EventTracker")
func _acting() -> Node: return Engine.get_main_loop().root.get_node_or_null("Acting")
func _m() -> Node: return Engine.get_main_loop().root.get_node_or_null("Madness")
func _f() -> Node: return Engine.get_main_loop().root.get_node_or_null("Foundation")
func _as() -> Node: return Engine.get_main_loop().root.get_node_or_null("AnchorSystem")
func _gd() -> Node: return Engine.get_main_loop().root.get_node("GameData")


func prepara() -> void:
	var rs: Node = _rs()
	if rs != null:
		rs.da_salvataggio({})            # sigilli/sacrifici vuoti
		rs.imposta_luogo([])
		rs.imposta_tempo("", "")
		if rs.in_corso():
			rs.interrompi("reset")
	_prog().configura("", 9)
	_et().call("azzera")
	_acting().call("_riparti")
	_m().call("azzera")
	_f().call("da_salvataggio", {})
	_as().call("pulisci")


func _recita_seq9() -> void:
	for i in 3:
		_et().call("emit_event", "enemy_defeated", {"senza_abilita": true})
	_et().call("emit_event", "damage_dealt", {"tag_danno": "fisico", "quantita": 2000})
	# tg_9_protettore (US-804): riscritta da damage_absorbed_for_ally a
	# perfect_parry x12 (nessun alleato in scena in questa fase).
	for i in 12:
		_et().call("emit_event", "perfect_parry", {})


func test_prerequisiti_dal_rituale_dei_dati() -> void:
	var rs: Node = _rs()
	var rit: Dictionary = {}
	for s in _gd().call("get_pathway", "twilight_giant").get("sequences", []):
		if (s as Dictionary).get("id") == "twilight_giant_4":
			rit = (s as Dictionary).get("advancement_ritual", {})
	assert_false(rit.is_empty(), "rituale di Sequenza 4 nei dati")

	var pre: Dictionary = rs.prerequisiti(rit)
	assert_false(pre["ok"], "prerequisiti non soddisfatti all'inizio")
	assert_gt(float((pre["mancanti"] as PackedStringArray).size()), 0.0, "elenca cosa manca")

	rs.imposta_luogo(rit["location_tags"])
	rs.imposta_tempo(str(rit.get("momento", "")), str(rit.get("fase_lunare", "")))
	for sig in rit["sigils"]:
		rs.aggiungi_sigillo(sig)
	for sac in rit["sacrifices"]:
		rs.fornisci_sacrificio(sac)
	var pre2: Dictionary = rs.prerequisiti(rit)
	assert_true(pre2["ok"], "tutti i prerequisiti soddisfatti: %s" % pre2.get("mancanti"))


func test_avvio_richiede_prerequisiti_e_recitazione() -> void:
	var rs: Node = _rs()
	var rit: Dictionary = {"location_tags": [], "sacrifices": [], "sigils": []}

	# recitazione incompleta
	assert_eq(rs.avvia(rit)["reason"], "recitazione_incompleta", "serve acting completo")

	_recita_seq9()
	# prerequisiti mancanti
	assert_eq(rs.avvia({"location_tags": ["vetta"], "sacrifices": [], "sigils": []})["reason"],
		"prerequisiti_mancanti", "serve il luogo giusto")

	# ok
	assert_true(rs.avvia(rit)["ok"], "avvio riuscito")
	assert_true(rs.in_corso(), "rituale in corso")


func test_completamento_avanza_di_sequenza() -> void:
	var rs: Node = _rs()
	_recita_seq9()
	var completati: Array = []
	rs.rituale_completato.connect(func(seq: int) -> void: completati.append(seq))
	rs.avvia({"location_tags": [], "sacrifices": [], "sigils": []})
	rs.call("_process", 50.0)   # supera i 45s di build
	assert_false(rs.in_corso(), "rituale finito")
	assert_eq(completati.size(), 1, "segnale rituale_completato")
	assert_eq(_prog().call("sequence"), 8, "Sequenza 9 -> 8")


func test_interruzione_fallisce_con_penalita() -> void:
	var rs: Node = _rs()
	_recita_seq9()
	rs.avvia({"location_tags": [], "sacrifices": [], "sigils": []})
	var f0: float = _f().call("valore")
	var interrotti: Array = []
	rs.rituale_interrotto.connect(func(motivo: String) -> void: interrotti.append(motivo))

	rs.interrompi("danno")
	assert_eq(interrotti, ["danno"], "segnale rituale_interrotto")
	assert_false(rs.in_corso(), "rituale abortito")
	assert_eq(_prog().call("sequence"), 9, "nessun avanzamento")
	assert_almost_eq(_m().call("valore"), 15.0, "penalita di follia (non bufferizzata)")
	assert_almost_eq(_f().call("valore"), f0 - 8.0, "malus alle fondamenta")


func test_sacrificio_dell_ancora() -> void:
	var rs: Node = _rs()
	_as().call("register", "anchor_mirco")
	_recita_seq9()
	rs.avvia({"location_tags": [], "sacrifices": ["ancora_del_giocatore"], "sigils": []})
	rs.call("_process", 50.0)
	assert_eq((_as().call("active") as Array).size(), 0, "l'Ancora e' stata sacrificata")
	assert_eq(_prog().call("sequence"), 8, "avanzato")


func test_persistenza_di_sigilli_e_sacrifici() -> void:
	var rs: Node = _rs()
	var save: Node = Engine.get_main_loop().root.get_node("SaveSystem")
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	rs.aggiungi_sigillo("sigillo_del_guardiano")
	rs.fornisci_sacrificio("arma_spezzata_di_un_nemico_ucciso")

	if save.esiste(SLOT):
		save.cancella(SLOT)
	save.salva(SLOT, gs.snapshot())
	rs.da_salvataggio({})
	assert_eq((rs.sigilli() as Array).size(), 0, "azzerato")

	var c: Dictionary = save.carica(SLOT)
	gs.applica(c["dati"])
	assert_true("sigillo_del_guardiano" in (rs.sigilli() as Array), "sigillo ripristinato dal save")
	save.cancella(SLOT)
