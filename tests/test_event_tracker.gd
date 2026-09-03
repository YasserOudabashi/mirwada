extends "res://tests/test_case.gd"
## US-210 — EventTracker generico: contatori sui 12 eventi chiusi, con filtri.

const SLOT := 904


func _et() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("EventTracker")


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SaveSystem")


func prepara() -> void:
	if _et() != null:
		_et().call("azzera")


func test_emit_e_conteggio_base() -> void:
	var et: Node = _et()
	et.call("emit_event", "enemy_defeated", {})
	et.call("emit_event", "enemy_defeated", {})
	assert_almost_eq(et.call("count", "enemy_defeated", {}), 2.0, "due nemici sconfitti")
	assert_eq(et.call("eventi_totali"), 2, "due voci nel log")


func test_evento_fuori_vocabolario_non_crasha() -> void:
	var et: Node = _et()
	# push_error atteso: l'evento non e' nei 12
	et.call("emit_event", "giocatore_ha_starnutito", {})
	assert_eq(et.call("eventi_totali"), 0, "l'evento fuori vocabolario non e' registrato")
	assert_almost_eq(et.call("count", "enemy_defeated", {}), 0.0, "nessun conteggio, nessun crash")


func test_filtro_di_uguaglianza() -> void:
	var et: Node = _et()
	et.call("emit_event", "damage_dealt", {"tag_danno": "fisico", "quantita": 10})
	et.call("emit_event", "damage_dealt", {"tag_danno": "luce", "quantita": 5})
	et.call("emit_event", "damage_dealt", {"tag_danno": "fisico", "quantita": 7})
	# misura "somma": totale di quantita sulle voci che matchano
	assert_almost_eq(et.call("count", "damage_dealt", {"tag_danno": "fisico"}), 17.0, "somma dei danni fisici")
	assert_almost_eq(et.call("count", "damage_dealt", {}), 22.0, "somma di tutti i danni")


func test_filtro_max() -> void:
	var et: Node = _et()
	et.call("emit_event", "enemy_defeated", {"sequenza_bersaglio": 9})
	et.call("emit_event", "enemy_defeated", {"sequenza_bersaglio": 6})
	et.call("emit_event", "enemy_defeated", {"sequenza_bersaglio": 3})
	# sequenza_bersaglio_max 6 = conta solo bersagli di potenza pari o superiore
	# (numero di Sequenza <= 6)
	assert_almost_eq(et.call("count", "enemy_defeated", {"sequenza_bersaglio_max": 6}), 2.0,
		"due bersagli con Sequenza <= 6")


func test_filtro_booleano() -> void:
	var et: Node = _et()
	et.call("emit_event", "enemy_defeated", {"senza_abilita": true})
	et.call("emit_event", "enemy_defeated", {"senza_abilita": false})
	et.call("emit_event", "enemy_defeated", {})
	assert_almost_eq(et.call("count", "enemy_defeated", {"senza_abilita": true}), 1.0,
		"solo la sconfitta senza abilita'")


func test_filtro_non_ammesso_e_errore_gestito() -> void:
	var et: Node = _et()
	et.call("emit_event", "enemy_defeated", {})
	# 'tag_danno' non e' un filtro di enemy_defeated
	assert_almost_eq(et.call("count", "enemy_defeated", {"tag_danno": "fisico"}), 0.0,
		"filtro non ammesso -> 0, push_error, nessun crash")


func test_persistenza_nel_save() -> void:
	var et: Node = _et()
	var s: Node = _save()
	et.call("emit_event", "perfect_parry", {})
	et.call("emit_event", "damage_taken", {"quantita": 30})

	if s.esiste(SLOT):
		s.cancella(SLOT)
	var snap: Dictionary = {"nome_personaggio": "Enel", "eventi": et.call("per_salvataggio")}
	assert_true(s.salva(SLOT, snap)["ok"], "salva ok")

	et.call("azzera")
	assert_eq(et.call("eventi_totali"), 0, "log azzerato")

	var c: Dictionary = s.carica(SLOT)
	et.call("da_salvataggio", (c["dati"] as Dictionary)["eventi"])
	assert_eq(et.call("eventi_totali"), 2, "log ripristinato dal save")
	assert_almost_eq(et.call("count", "perfect_parry", {}), 1.0, "parata perfetta contata dopo il load")
	assert_almost_eq(et.call("count", "damage_taken", {}), 30.0, "danno subito ripristinato")
	s.cancella(SLOT)


func test_migrazione_da_v4() -> void:
	var s: Node = _save()
	if s.esiste(SLOT):
		s.cancella(SLOT)
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open("user://saves/slot_%d.json" % SLOT, FileAccess.WRITE)
	f.store_string('{"schema_version": 4, "nome_personaggio": "v4", "posizione": [0,0], "statistiche": {}, "evocazioni": [], "progressione": {"pathway_id": "", "sequence": 9}, "mondo": {"terrain_mods": []}}')
	f.close()
	var c: Dictionary = s.carica(SLOT)
	assert_true(c["ok"] and c["migrato"], "migrazione applicata")
	assert_eq(((c["dati"] as Dictionary)["eventi"] as Dictionary)["log"], [], "campo eventi aggiunto vuoto")
	s.cancella(SLOT)
