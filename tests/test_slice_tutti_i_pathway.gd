extends "res://tests/test_case.gd"
## Copertura orizzontale: OGNI Pathway attivo (GameData.pathway_ids(), mai
## scritti a mano) dalla Sequenza 9 alla 0, giocato in codice come i
## checkpoint gia' esistenti (test_vertical_slice.gd 9->5 Twilight Giant,
## test_slice_fase_5.gd 8->2 Death, test_slice_fase_5b.gd 8->2 Error) ma fino
## in fondo e per tutti e 10, in un solo posto generico invece di dieci file
## quasi identici: la stessa dimostrazione ("giocato con dati, zero righe
## dedicate al Pathway") vale per definizione anche per un Pathway nuovo
## aggiunto domani, senza toccare questo file.
##
## Per ogni salto di Sequenza: Caratteristica (dai dati) -> concoct (formula +
## ingredienti dai dati) -> recitazione via EventTracker (dalle acting_actions
## della Sequenza) -> bevi -> avanzamento NORMALE (mai forzato: la recitazione
## e' sempre completa per costruzione, come negli altri checkpoint).
##
## NOTA sul "gioco reale": questo e' il Livello A (motore pilotato in codice,
## come i checkpoint di fase 5/5b/7), non il Livello B (Input da tastiera,
## camminata fisica, Xvfb - vedi tests/manual/qa_vslice.gd). Il Livello B per
## tutti i 10 Pathway richiede prima di piazzare nel mondo gli ingredienti e i
## nemici di ogni Sequenza: gap documentato in
## 006_PRD/prd-copertura-vertical-slice.md, non risolvibile da un test.

const Stats := preload("res://scripts/stats_component.gd")

var _player: Node2D = null


func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")
func _prog() -> Node: return _root().get_node("Progression")
func _et() -> Node: return _root().get_node("EventTracker")
func _acting() -> Node: return _root().get_node("Acting")
func _ps() -> Node: return _root().get_node("PotionSystem")
func _store() -> Node: return _root().get_node("CharacteristicStore")
func _madness() -> Node: return _root().get_node("Madness")
func _trib() -> Node: return _root().get_node("TribulationSystem")
func _found() -> Node: return _root().get_node_or_null("Foundation")
func _engine() -> Node: return _root().get_node("AbilityEngine")


func prepara() -> void:
	for stale in _root().get_tree().get_nodes_in_group("player"):
		stale.remove_from_group("player")
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
	_trib().call("marca_superate_tutte")
	_engine().call("flush_effects")
	_engine().call("clear_cooldowns")
	_ps().call("scarta_pozione")
	_acting().call("_riparti")
	if _found() != null:
		_found().call("da_salvataggio", {"valore": 50.0})


func _fine() -> void:
	_prog().call("configura", "", 9)
	if _found() != null:
		_found().call("da_salvataggio", {"valore": 50.0})
	_madness().call("azzera")
	if is_instance_valid(_player):
		_player.free()


## Traduce i filtri di un'acting_action (che possono usare i suffissi
## "_max"/"_min" di EventTracker._corrisponde, es. "qualita_min") nei campi
## GREZZI che un evento deve portare per soddisfarli: il campo senza
## suffisso, valorizzato con la soglia stessa (soddisfa sia >= che <=). Gli
## altri filtri (uguaglianza esatta, booleani) passano invariati. Senza
## questa traduzione un'acting_action con un filtro _min/_max non
## conterebbe MAI (bug scoperto proprio da questo test: i checkpoint
## esistenti - Twilight Giant 9-5, Death 8-2, Error 8-2 - non arrivavano
## mai a una Sequenza che ne usa uno).
func _dati_evento_da_filtri(filtri: Dictionary) -> Dictionary:
	var d: Dictionary = {}
	for k in filtri:
		var chiave: String = str(k)
		if chiave.ends_with("_max"):
			d[chiave.trim_suffix("_max")] = filtri[k]
		elif chiave.ends_with("_min"):
			d[chiave.trim_suffix("_min")] = filtri[k]
		else:
			d[chiave] = filtri[k]
	return d


## Riempie la recitazione della Sequenza CORRENTE del Pathway corrente
## interrogando le sue acting_actions dai dati. Nessun id di Pathway qui.
func _recita_sequenza_corrente() -> void:
	for a in (_prog().call("sequence_data").get("acting_actions", []) as Array):
		var azione: Dictionary = a
		var ev: String = str(azione.get("evento", ""))
		var filtri: Dictionary = (azione.get("filtri", {}) as Dictionary)
		var target: float = float(azione.get("target", 1))
		var misura: String = str(_gd().call("get_tracked_event", ev).get("misura", "conteggio"))
		if misura == "conteggio":
			for i in int(ceil(target)):
				_et().call("emit_event", ev, _dati_evento_da_filtri(filtri))
		else:
			var d: Dictionary = _dati_evento_da_filtri(filtri)
			d["quantita"] = target
			_et().call("emit_event", ev, d)


func _gioca_pathway_dal_9_allo_0(pid: String) -> void:
	prepara()
	_prog().call("configura", pid, 9)
	_acting().call("_riparti")

	for seq in [9, 8, 7, 6, 5, 4, 3, 2, 1]:
		assert_eq(_prog().call("sequence"), seq, "%s: siamo alla Sequenza %d" % [pid, seq])

		var cid: String = "char_%s_%d" % [pid, seq]
		_store().call("aggiungi", cid)
		assert_true(_store().call("possiede", cid),
			"%s: Caratteristica di Sequenza %d raccolta" % [pid, seq])

		var fid: String = "formula_%s_%d" % [pid, seq]
		var formula: Dictionary = _gd().call("get_formula", fid)
		assert_false(formula.is_empty(), "%s: la formula %s esiste" % [pid, fid])
		var r: Dictionary = _ps().call("concoct", fid, cid, formula.get("ingredients", []))
		assert_true(bool(r.get("ok", false)),
			"%s: concoct alla Sequenza %d: %s" % [pid, seq, r.get("reason")])

		_recita_sequenza_corrente()
		assert_true(bool(_acting().call("e_completo")),
			"%s: recitazione completa a Sequenza %d (progress %.3f)" %
				[pid, seq, float(_acting().call("acting_progress"))])

		var follia_prima: float = _madness().call("valore")
		var e: Dictionary = _ps().call("bevi", false)
		assert_true(bool(e.get("avanzato", false)), "%s: avanzato dalla Sequenza %d" % [pid, seq])
		assert_false(bool(e.get("forzato", true)),
			"%s: avanzamento NORMALE (recitazione completa) alla Sequenza %d" % [pid, seq])
		assert_almost_eq(_madness().call("valore"), follia_prima,
			"%s: niente follia da forzatura alla Sequenza %d" % [pid, seq])
		assert_eq(_prog().call("sequence"), seq - 1, "%s: avanzato a Sequenza %d" % [pid, seq - 1])
		assert_true(float(_acting().call("acting_progress")) < 0.05,
			"%s: recitazione ripartita da zero dopo l'avanzamento" % pid)

	assert_eq(_prog().call("sequence"), 0,
		"%s: 9 -> 0 con dati e zero codice dedicato al Pathway" % pid)


func test_ogni_pathway_attivo_si_completa_dalla_sequenza_9_allo_0() -> void:
	var pids: Array = _gd().call("pathway_ids")
	assert_true(pids.size() >= 10, "almeno 10 Pathway attivi (pathway_ids())")
	for pid in pids:
		_gioca_pathway_dal_9_allo_0(str(pid))
	_fine()


## Ogni abilita' di ogni Pathway attivo si esegue senza warning di primitiva,
## a qualunque Sequenza (i test per-Pathway gia' esistenti lo verificano a
## bande separate 9-7/6-4/3-0: qui si ripete su tutte le Sequenze in un solo
## posto generico, per ogni Pathway).
func test_ogni_abilita_di_ogni_pathway_attivo_si_esegue_senza_warning() -> void:
	var caster := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	caster.add_child(s)
	_root().add_child(caster)

	var provate := 0
	for pid in (_gd().call("pathway_ids") as Array):
		var pathway: Dictionary = _gd().call("get_pathway", str(pid))
		for seqd in (pathway.get("sequences", []) as Array):
			# Il costo in spiritualita' cresce scendendo di Sequenza: un caster
			# configurato SEMPRE alla Sequenza 9 (spiritualita_max piu' basso)
			# non potrebbe permettersi le abilita' costose delle Sequenze basse
			# anche impostando spiritualita a un numero enorme, perche' il
			# setter di StatsComponent la clampa subito a spiritualita_max
			# (scoperto proprio da questo test su darkness_1/darkness_0).
			s.call("configure_from_balance", int((seqd as Dictionary).get("sequence", 9)))
			for aid in ((seqd as Dictionary).get("abilities", []) as Array):
				_engine().call("clear_cooldowns")
				s.set("spiritualita", 9999.0)
				var r: Dictionary = _engine().call("execute", str(aid), caster)
				assert_true(bool(r.get("ok", false)), "%s eseguita: %s" % [aid, r.get("reason")])
				for w in (r.get("warnings", PackedStringArray()) as PackedStringArray):
					assert_false(str(w).contains("non implementata"),
						"%s: nessuna primitiva non implementata (%s)" % [aid, w])
					assert_false(str(w).contains("fuori registro"),
						"%s: nessuna primitiva fuori registro (%s)" % [aid, w])
				provate += 1
	assert_true(provate >= 90, "provate tutte le abilita' di tutti i Pathway attivi (%d)" % provate)
	caster.free()
