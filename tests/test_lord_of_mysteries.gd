extends "res://tests/test_case.gd"
## US-5B11 — il gruppo Lord of Mysteries (Fool / Error / Door) partecipa a
## sinergie e creazione personaggio come gli altri Pathway: le 30 Caratteristiche
## esistono e sono tradotte; le sinergie di batch_5 sono tutte raggiungibili;
## l'anti-sinergia anti_due_bugiardi neutralizza sinergia_ladro_di_poteri.

const Stats := preload("res://scripts/stats_component.gd")


func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")
func _se() -> Node: return _root().get_node("SynergyEngine")
func _prog() -> Node: return _root().get_node("Progression")


func prepara() -> void:
	if _se() != null:
		_se().call("pulisci")
		_se().call("imposta_override_tag", {})


func _fine() -> void:
	if _se() != null:
		_se().call("imposta_override_tag", {})
		_se().call("pulisci")


func test_le_30_caratteristiche_del_gruppo_esistono_e_sono_tradotte() -> void:
	var gd: Node = _gd()
	var mancanti: Array = []
	for pid in ["fool", "error", "door"]:
		for n in range(10):
			var cid: String = "char_%s_%d" % [pid, n]
			var c: Dictionary = gd.call("get_characteristic", cid)
			if c.is_empty():
				mancanti.append(cid)
				continue
			var key: String = str(c.get("name_i18n", ""))
			var tr: String = gd.call("tr_data", key)
			if tr == key or tr.begins_with("TODO "):
				mancanti.append("%s (i18n non tradotto)" % cid)
	assert_eq(mancanti.size(), 0,
		"le 30 Caratteristiche di Fool/Error/Door esistono e sono tradotte: %s" % [mancanti])


func test_fool_error_door_senza_sequenze_stub() -> void:
	var gd: Node = _gd()
	for pid in ["fool", "error", "door"]:
		var pw: Dictionary = gd.call("get_pathway", pid)
		for seq in (pw.get("sequences", []) as Array):
			assert_false(bool((seq as Dictionary).get("stub", false)),
				"%s non ha Sequenze stub" % pid)


func test_si_crea_un_personaggio_su_ognuno_dei_tre() -> void:
	var gd: Node = _gd()
	for pid in ["fool", "error", "door"]:
		_prog().configura(pid, 9)
		assert_eq(str(_prog().call("pathway")), pid, "personaggio creato su %s" % pid)
		var sd: Dictionary = gd.call("get_sequence", "%s_9" % pid)
		assert_gt(float((sd.get("abilities", []) as Array).size()), 0.0,
			"%s Seq 9 ha abilita' giocabili dalla creazione" % pid)
	_prog().configura("", 9)


func test_batch_5_sinergie_tutte_raggiungibili() -> void:
	var gd: Node = _gd()
	# unione dei tag ottenibili: pathway attivi + abilita' + stanze + pet + talenti.
	var ott: Dictionary = {}
	for pid in gd.call("pathway_ids"):
		for t in (gd.call("get_pathway", pid).get("tags", []) as Array):
			ott[str(t)] = true
	for aid in gd.call("ability_ids"):
		for t in (gd.call("get_ability", aid).get("tag_sinergia", []) as Array):
			ott[str(t)] = true
	# fonti di fase 3 note (US-334): talenti furto/notte/non_letale, stanze
	# conoscenza/rituale/..., pet bestia/divinazione/difesa/...
	for t in ["furto", "notte", "non_letale", "conoscenza", "rituale", "occulto",
			"crescita", "pozione", "scienza", "bestia", "divinazione", "difesa", "guerra"]:
		ott[t] = true

	var batch_5: Array = []
	for sid in gd.call("synergy_ids"):
		var syn: Dictionary = gd.call("get_synergy", sid)
		if not str(syn.get("note", "")).contains("BATCH 5") and not sid in [
				"sinergia_ladro_di_poteri", "sinergia_teatro_di_ombre", "sinergia_rete_di_porte",
				"sinergia_debito_temporale", "sinergia_archivio_fotocopiato", "anti_due_bugiardi"]:
			continue
		batch_5.append(sid)
		for t in syn.get("richiede_tag", {}):
			assert_true(ott.has(str(t)),
				"batch_5 [%s]: il tag '%s' e' ottenibile dai sistemi attivi" % [sid, t])
	assert_true(batch_5.size() >= 4,
		"batch_5 ha almeno 4 sinergie nuove (trovate %d)" % batch_5.size())


func test_anti_due_bugiardi_neutralizza_ladro_di_poteri() -> void:
	var se: Node = _se()
	# solo furto: ladro_di_poteri soddisfatta e attiva.
	se.call("imposta_override_tag", {"furto": 3, "singolo": 1})
	se.call("rivaluta")
	assert_true(se.call("e_attiva", "sinergia_ladro_di_poteri"),
		"con furto+singolo la sinergia del ladro e' attiva")

	# aggiungo inganno: l'Error che mente a se stesso -> anti_due_bugiardi
	# soddisfatta, e neutralizza il ladro.
	se.call("imposta_override_tag", {"furto": 3, "singolo": 1, "inganno": 2})
	se.call("rivaluta")
	assert_true("anti_due_bugiardi" in (se.call("soddisfatte") as Array),
		"inganno + furto -> anti_due_bugiardi soddisfatta")
	assert_true("sinergia_ladro_di_poteri" in (se.call("neutralizzate") as Array),
		"anti_due_bugiardi neutralizza sinergia_ladro_di_poteri")
	assert_false(se.call("e_attiva", "sinergia_ladro_di_poteri"),
		"con l'anti-sinergia attiva, il ladro non applica piu' il suo effetto")
	_fine()
