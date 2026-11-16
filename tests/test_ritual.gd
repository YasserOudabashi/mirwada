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


## US-1301: il rituale di Sequenza 1 di ogni Pathway attivo chiede un'Ancora del giocatore.
func test_ogni_rituale_di_sequenza_1_chiede_un_ancora() -> void:
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	var ids: Array = gd.call("pathway_ids")
	assert_eq(ids.size(), 10, "10 Pathway attivi")
	for pid in ids:
		var s: Dictionary = gd.call("get_sequence", "%s_1" % pid)
		var sac: Array = (s.get("advancement_ritual", {}) as Dictionary).get("sacrifices", [])
		assert_true("ancora_del_giocatore" in sac, "%s: il rituale di Sequenza 1 sacrifica un'Ancora" % pid)


# --- US-1305b: il rituale nel mondo (decisioni dell'utente del 2026-11-16) ---

func _root() -> Node: return Engine.get_main_loop().root


## Alla Sequenza 4 col rituale dei dati: pozione pronta, recitazione completa, sigilli e sacrifici dati.
func _pronto_alla_4() -> Dictionary:
	var pid: String = str(_prog().call("pathway"))
	_prog().configura(pid, 4)
	_root().get_node("EndgameState").call("da_salvataggio", {})
	var rituale: Dictionary = _rs().call("rituale_corrente")
	var potion: Dictionary = _prog().call("sequence_data").get("potion", {})
	var car: Dictionary = _gd().call("characteristic_for", pid, int(potion.get("characteristic_sequence", -1)))
	_root().get_node("CharacteristicStore").call("aggiungi", str(car.get("id", "")))
	_root().get_node("PotionSystem").call("concoct", str(potion.get("formula_id", "")), str(car.get("id", "")), potion.get("ingredients", []))
	_acting().call("_riparti")
	for a in (_prog().call("sequence_data").get("acting_actions", []) as Array):
		var dati: Dictionary = {}                     # come i test di slice: un filtro _min/_max diventa il dato
		for k in ((a as Dictionary).get("filtri", {}) as Dictionary):
			dati[str(k).trim_suffix("_max").trim_suffix("_min")] = (a as Dictionary)["filtri"][k]
		var ev: String = str((a as Dictionary).get("evento", ""))
		if str(_gd().call("get_tracked_event", ev).get("misura", "conteggio")) == "conteggio":
			for _i in int(ceil(float((a as Dictionary).get("target", 1)))):
				_et().call("emit_event", ev, dati.duplicate())
		else:
			dati["quantita"] = float((a as Dictionary).get("target", 1))
			_et().call("emit_event", ev, dati)
	for s in rituale.get("sigils", []):
		_rs().call("aggiungi_sigillo", s)
	for s in rituale.get("sacrifices", []):
		_rs().call("fornisci_sacrificio", s)
	return rituale


func _fine_mondo() -> void:
	_root().get_node("WorldState").call("imposta_zona", "")
	_root().get_node("TimeSystem").call("libera_momento")
	_root().get_node("PotionSystem").call("scarta_pozione")
	prepara()


func test_dei_luoghi_ne_basta_uno() -> void:
	var rs: Node = _rs()
	var r := {"location_tags": ["cripta", "vetta"], "sacrifices": [], "sigils": []}
	assert_false(rs.prerequisiti(r)["ok"], "in nessuno dei due luoghi: no")
	rs.imposta_luogo(["vetta"])
	assert_true(rs.prerequisiti(r)["ok"], "in uno dei due: basta")


func test_il_luogo_e_l_ora_vengono_dal_mondo() -> void:
	var rs: Node = _rs()
	var r := {"location_tags": ["altura"], "momento": "alba", "sacrifices": [], "sigils": []}
	_root().get_node("TimeSystem").call("forza_momento", "mezzogiorno")
	_root().get_node("WorldState").call("imposta_zona", "piazza")
	assert_eq(Array(rs.prerequisiti(r)["mancanti"]), ["luogo:altura", "momento:alba"], "in piazza a mezzogiorno mancano luogo e ora")
	_root().get_node("WorldState").call("imposta_zona", "altura")
	_root().get_node("TimeSystem").call("forza_momento", "alba")
	assert_true(rs.prerequisiti(r)["ok"], "sull'altura all'alba il mondo basta, senza dirlo a mano al rituale")
	_fine_mondo()


func test_dalla_4_la_pozione_si_beve_solo_nel_rituale() -> void:
	var rituale: Dictionary = _pronto_alla_4()
	assert_false(rituale.is_empty(), "la Sequenza 4 ha il suo rituale")
	var ps: Node = _root().get_node("PotionSystem")
	var e: Dictionary = ps.call("bevi", false)
	assert_eq(str(e.get("reason", "")), "serve_il_rituale", "fuori dal rituale la pozione non si beve")
	assert_eq(_prog().call("sequence"), 4, "e non si avanza")
	assert_false((ps.call("pozione_pronta") as Dictionary).is_empty(), "la pozione non va sprecata")
	_fine_mondo()


func test_compiere_il_rituale_nel_posto_giusto_fa_avanzare() -> void:
	var rituale: Dictionary = _pronto_alla_4()
	var rs: Node = _rs()
	assert_eq(str(rs.call("compi").get("reason", "")), "prerequisiti_mancanti", "nel posto sbagliato non parte")
	_root().get_node("WorldState").call("imposta_zona", str((rituale.get("location_tags", [""]) as Array)[-1]))
	if rituale.get("momento") != null:
		_root().get_node("TimeSystem").call("forza_momento", str(rituale["momento"]))
	if rituale.get("fase_lunare") != null:
		rs.imposta_tempo(str(rituale.get("momento", "")), str(rituale["fase_lunare"]))
	var esito: Dictionary = rs.call("compi")
	assert_true(esito["ok"], "nel secondo dei suoi luoghi, all'ora giusta, comincia (%s)" % str(esito))
	rs.call("_process", 500.0)
	assert_eq(_prog().call("sequence"), 3, "finito il rituale la pozione e' bevuta: Sequenza 3")
	assert_true((_root().get_node("PotionSystem").call("pozione_pronta") as Dictionary).is_empty(), "la pozione e' consumata")
	_fine_mondo()


func test_senza_pozione_il_rituale_non_si_compie() -> void:
	_pronto_alla_4()
	_root().get_node("PotionSystem").call("scarta_pozione")
	assert_eq(str(_rs().call("compi").get("reason", "")), "manca_la_pozione", "prima la pozione")
	_fine_mondo()
