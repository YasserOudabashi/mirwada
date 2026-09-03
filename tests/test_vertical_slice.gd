extends "res://tests/test_case.gd"
## US-219 — IL VERDETTO SULL'ARCHITETTURA.
##
## Il Twilight Giant dalla Sequenza 9 alla 5, giocato in codice, esercitando
## per ogni salto: Caratteristica -> concoct -> recitazione via EventTracker
## -> bere -> avanzamento. Il tutto leggendo i DATI: la recitazione si
## riempie interrogando le acting_actions della Sequenza, non con numeri
## scritti nel test.
##
## Se qualcosa qui richiede un `if` per il Twilight Giant, l'architettura va
## corretta PRIMA di proseguire (checkpoint di fase 5).

const Stats := preload("res://scripts/stats_component.gd")

var _player: Node2D = null


func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")
func _prog() -> Node: return _root().get_node("Progression")
func _et() -> Node: return _root().get_node("EventTracker")
func _acting() -> Node: return _root().get_node("Acting")
func _ps() -> Node: return _root().get_node("PotionSystem")
func _store() -> Node: return _root().get_node("CharacteristicStore")
func _engine() -> Node: return _root().get_node("AbilityEngine")
func _madness() -> Node: return _root().get_node("Madness")


func prepara() -> void:
	# giocatore finto nel gruppo "player" cosi' i stat_modifiers di Sequenza
	# si applicano davvero
	if _player != null and is_instance_valid(_player):
		_player.free()
	_player = Node2D.new()
	_player.add_to_group("player")
	var s: Node = Stats.new()
	s.name = "StatsComponent"
	_player.add_child(s)
	_root().add_child(_player)
	s.call("configure_from_balance", 9)

	_store().call("pulisci")
	_et().call("azzera")
	_madness().call("azzera")
	_engine().call("flush_effects")
	_engine().call("clear_cooldowns")
	_prog().configura("", 9)
	_acting().call("_riparti")
	_ps().call("scarta_pozione")


## Riempie la recitazione della Sequenza CORRENTE interrogando le sue
## acting_actions dai dati. Nessun numero del Twilight Giant nel test.
func _recita_sequenza_corrente() -> void:
	for a in (_prog().call("sequence_data").get("acting_actions", []) as Array):
		var azione: Dictionary = a
		var ev: String = str(azione.get("evento", ""))
		var filtri: Dictionary = (azione.get("filtri", {}) as Dictionary)
		var target: float = float(azione.get("target", 1))
		var misura: String = str(_gd().call("get_tracked_event", ev).get("misura", "conteggio"))
		if misura == "conteggio":
			for i in int(ceil(target)):
				_et().call("emit_event", ev, filtri.duplicate())
		else:
			var d: Dictionary = filtri.duplicate()
			d["quantita"] = target
			_et().call("emit_event", ev, d)


func test_twilight_giant_dalla_sequenza_9_alla_5() -> void:
	var s: Node = _player.get_node("StatsComponent")

	for seq in [9, 8, 7, 6, 5]:
		assert_eq(_prog().call("sequence"), seq, "siamo alla Sequenza %d" % seq)

		# --- stat_modifiers della Sequenza applicati al giocatore ---
		var mods: Dictionary = _prog().call("stat_modifiers")
		if mods.has("hp_max"):
			assert_true(s.call("has_modifier", "sequence:%d" % seq), "modificatore di Sequenza %d" % seq)
			assert_almost_eq(
				s.call("get_stat", "hp_max"),
				s.call("get_base", "hp_max") + float(mods["hp_max"]),
				"hp_max di Sequenza %d dai dati" % seq)

		if seq == 5:
			break  # arrivati: la Sequenza 5 non si beve, si raccoglie e basta

		# --- 1. raccolta Caratteristica ---
		var cid: String = "char_twilight_giant_%d" % seq
		_store().call("aggiungi", cid)
		assert_true(_store().call("possiede", cid), "Caratteristica di Sequenza %d raccolta" % seq)

		# --- 2. concoct ---
		var formula: Dictionary = _gd().call("get_formula", "formula_twilight_giant_%d" % seq)
		var r: Dictionary = _ps().call("concoct",
			"formula_twilight_giant_%d" % seq, cid, formula["ingredients"])
		assert_true(r["ok"], "concoct alla Sequenza %d: %s" % [seq, r.get("reason")])
		assert_eq(_store().call("conta", cid), 0, "Caratteristica consumata dalla concoct")

		# --- 3. recitazione via EventTracker (dai dati) ---
		_recita_sequenza_corrente()
		assert_true(_acting().call("e_completo"),
			"recitazione completa a Sequenza %d (acting_progress %.3f)" % [seq, _acting().call("acting_progress")])

		# --- 4. bere -> avanzamento ---
		var follia_prima: float = _madness().call("valore")
		var e: Dictionary = _ps().call("bevi", false)
		assert_true(e["avanzato"], "avanzato dalla Sequenza %d" % seq)
		assert_false(e["forzato"], "avanzamento NORMALE, non forzato (recitazione completa)")
		assert_almost_eq(_madness().call("valore"), follia_prima,
			"recitazione completa -> niente follia da forzatura alla Sequenza %d" % seq)
		assert_eq(_prog().call("sequence"), seq - 1, "avanzato a Sequenza %d" % (seq - 1))
		assert_true(_acting().call("acting_progress") < 0.05, "recitazione ripartita da zero")

	assert_eq(_prog().call("sequence"), 5, "9 -> 8 -> 7 -> 6 -> 5 con dati e zero codice dedicato")


func test_ogni_abilita_del_twilight_giant_9_5_si_esegue_senza_warning() -> void:
	var caster := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	caster.add_child(s)
	_root().add_child(caster)
	s.call("configure_from_balance", 9)
	s.set("spiritualita", 999.0)

	var pathway: Dictionary = _gd().call("get_pathway", "twilight_giant")
	var provate := 0
	for seqd in (pathway.get("sequences", []) as Array):
		var sd: Dictionary = seqd
		if int(sd.get("sequence", -1)) < 5 or int(sd.get("sequence", -1)) > 9:
			continue
		for aid in (sd.get("abilities", []) as Array):
			_engine().call("clear_cooldowns")
			s.set("spiritualita", 999.0)
			var r: Dictionary = _engine().call("execute", str(aid), caster)
			assert_true(r["ok"], "%s eseguita" % aid)
			for w in (r["warnings"] as PackedStringArray):
				assert_false(str(w).contains("non implementata"), "%s: nessuna primitiva non implementata (%s)" % [aid, w])
				assert_false(str(w).contains("fuori registro"), "%s: nessuna primitiva fuori registro (%s)" % [aid, w])
			provate += 1

	assert_true(provate >= 11, "provate tutte le abilita' delle Sequenze 9-5 (%d)" % provate)
	caster.free()


func test_nessun_codice_nomina_il_twilight_giant() -> void:
	# grep di scripts/ per 'twilight_giant' e per i nomi di Sequenza: nessun
	# `if` per il Pathway. Un commento che rimanda ai dati e' tollerato.
	var vietati := ["twilight_giant", "Warrior", "Pugilist", "\"tg_"]
	var colpevoli: PackedStringArray = []
	for f in DirAccess.get_files_at("res://scripts"):
		if not f.ends_with(".gd"):
			continue
		var testo: String = FileAccess.get_file_as_string("res://scripts/" + f)
		for riga_n in testo.split("\n").size():
			var riga: String = testo.split("\n")[riga_n]
			var codice: String = riga.split("##")[0].split("#")[0]  # via i commenti
			for v in vietati:
				if codice.contains(v):
					colpevoli.append("%s: %s" % [f, riga.strip_edges()])
	assert_eq(colpevoli.size(), 0, "nessun nome del Twilight Giant nel codice: %s" % colpevoli)
