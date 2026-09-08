extends "res://tests/test_case.gd"
## US-508 — IL CHECKPOINT DELLA FASE 5.
##
## Death dalla Sequenza 8 alla 2, giocato in codice: per ogni salto
## Caratteristica -> concoct -> recitazione via EventTracker (dai dati) ->
## bere -> avanzamento. Come test_vertical_slice per il Twilight Giant (US-219),
## ma su un Pathway SCRITTO IN FASE 5. Se qualcosa qui richiede un `if` per
## "death", l'architettura della fase 2 va corretta PRIMA degli altri 4 Pathway.

const Stats := preload("res://scripts/stats_component.gd")
const PID := "death"

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
	if _player != null and is_instance_valid(_player):
		_player.free()
	_player = Node2D.new()
	_player.add_to_group("player")
	var s: Node = Stats.new()
	s.name = "StatsComponent"
	_player.add_child(s)
	_root().add_child(_player)
	s.call("configure_from_balance", 8)

	_store().call("pulisci")
	_et().call("azzera")
	_madness().call("azzera")
	# US-711: lo slice della fase 5 (Death 8->2) non e' sulle tribolazioni.
	_root().get_node("TribulationSystem").call("marca_superate_tutte")
	_engine().call("flush_effects")
	_engine().call("clear_cooldowns")
	_prog().configura(PID, 8)
	_acting().call("_riparti")
	_ps().call("scarta_pozione")
	_reset_fondamenta()  # bevi() alza le fondamenta: non contaminare test_stanze
	var reg: Node = _root().get_node_or_null("SummonRegistry")
	if reg != null:
		reg.call("pulisci")  # death_legione lascia 8 legionari persistenti


func _reset_fondamenta() -> void:
	var f: Node = _root().get_node_or_null("Foundation")
	if f != null:
		f.call("da_salvataggio", {"valore": 50.0})


func _fine() -> void:
	_prog().configura("", 9)
	_reset_fondamenta()
	_madness().call("azzera")
	var reg: Node = _root().get_node_or_null("SummonRegistry")
	if reg != null:
		reg.call("pulisci")
	if is_instance_valid(_player):
		_player.free()


## Recitazione della Sequenza corrente interrogando le sue acting_actions dai
## dati. Nessun numero di Death nel test.
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


func test_death_dalla_sequenza_8_alla_2() -> void:
	for seq in [8, 7, 6, 5, 4, 3, 2]:
		assert_eq(_prog().call("sequence"), seq, "siamo alla Sequenza %d" % seq)

		if seq == 2:
			break  # arrivati

		# 1. Caratteristica (dai dati)
		var cid: String = "char_%s_%d" % [PID, seq]
		_store().call("aggiungi", cid)
		assert_true(_store().call("possiede", cid), "Caratteristica di Sequenza %d raccolta" % seq)

		# 2. concoct (formula + ingredienti dai dati)
		var fid: String = "formula_%s_%d" % [PID, seq]
		var formula: Dictionary = _gd().call("get_formula", fid)
		assert_false(formula.is_empty(), "la formula %s esiste" % fid)
		var r: Dictionary = _ps().call("concoct", fid, cid, formula["ingredients"])
		assert_true(r["ok"], "concoct alla Sequenza %d: %s" % [seq, r.get("reason")])

		# 3. recitazione via EventTracker (dai dati)
		_recita_sequenza_corrente()
		assert_true(_acting().call("e_completo"),
			"recitazione completa a Sequenza %d (progress %.3f)" % [seq, _acting().call("acting_progress")])

		# 4. bere -> avanzamento NORMALE (recitazione completa = zero follia da forzatura)
		var follia_prima: float = _madness().call("valore")
		var e: Dictionary = _ps().call("bevi", false)
		assert_true(e["avanzato"], "avanzato dalla Sequenza %d" % seq)
		assert_false(e["forzato"], "avanzamento NORMALE alla Sequenza %d" % seq)
		assert_almost_eq(_madness().call("valore"), follia_prima,
			"recitazione completa -> niente follia da forzatura alla Sequenza %d" % seq)
		assert_eq(_prog().call("sequence"), seq - 1, "avanzato a Sequenza %d" % (seq - 1))

	assert_eq(_prog().call("sequence"), 2,
		"8 -> 7 -> 6 -> 5 -> 4 -> 3 -> 2 con DATI e zero codice dedicato a Death")
	_fine()


func test_ogni_abilita_death_si_esegue_senza_warning() -> void:
	var caster := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	caster.add_child(s)
	_root().add_child(caster)
	s.call("configure_from_balance", 8)

	var pathway: Dictionary = _gd().call("get_pathway", PID)
	var provate := 0
	for seqd in (pathway.get("sequences", []) as Array):
		for aid in ((seqd as Dictionary).get("abilities", []) as Array):
			_engine().call("clear_cooldowns")
			s.set("spiritualita", 9999.0)
			var r: Dictionary = _engine().call("execute", str(aid), caster)
			assert_true(r["ok"], "%s eseguita" % aid)
			for w in (r["warnings"] as PackedStringArray):
				assert_false(str(w).contains("non implementata"),
					"%s: nessuna primitiva non implementata (%s)" % [aid, w])
				assert_false(str(w).contains("fuori registro"),
					"%s: nessuna primitiva fuori registro (%s)" % [aid, w])
			provate += 1
	assert_eq(provate, 20, "tutte e 20 le abilita' di Death (2 per Sequenza) eseguite")
	_fine()
	caster.free()


func test_nessun_codice_nomina_death() -> void:
	# grep di res://scripts e res://scripts/pages per gli id di Sequenza/abilita'
	# di Death e per i nomi di Sequenza. Zero occorrenze fuori dai commenti.
	var vietati: Array = ["death_", "\"death\"",
		"Corpse Collector", "Gravedigger", "Spirit Medium", "Spirit Guide",
		"Gatekeeper", "Undying", "Ferryman", "Death Consul", "Pale Emperor"]
	# eccezione legittima: enemy.gd usa "death" come STATO di animazione (una
	# entita' che muore), non il Pathway. Il pattern "death_" non la tocca;
	# "\"death\"" si -> si esclude enemy.gd riga dell'animazione.
	var colpevoli: PackedStringArray = []
	for dir in ["res://scripts", "res://scripts/pages"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var testo: String = FileAccess.get_file_as_string(dir + "/" + f)
			var righe: PackedStringArray = testo.split("\n")
			for i in righe.size():
				var codice: String = righe[i].split("##")[0].split("#")[0]
				for v in vietati:
					if not codice.contains(v):
						continue
					if v == "\"death\"" and codice.contains("riproduci"):
						continue  # stato di animazione di enemy.gd, non il Pathway
					colpevoli.append("%s:%d %s" % [f, i + 1, righe[i].strip_edges()])
	assert_eq(colpevoli.size(), 0,
		"nessun nome di Death nel codice (checkpoint fase 5): %s" % colpevoli)
