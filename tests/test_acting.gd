extends "res://tests/test_case.gd"
## US-211 — Acting Method: la barra acting_progress della Sequenza corrente.
## Gli eventi sono costruiti a mano (i filtri ricchi dei dati veri non sono
## ancora popolati dagli emettitori: US-219).

const SLOT := 905


func _acting() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Acting")


func _et() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("EventTracker")


func _prog() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Progression")


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SaveSystem")


func prepara() -> void:
	if _et() != null:
		_et().call("azzera")
	if _prog() != null:
		_prog().configura("", 9)  # twilight_giant, Sequenza 9
	if _acting() != null:
		_acting().call("_riparti")


## Riempie del tutto la recitazione della Sequenza 9 del Twilight Giant.
func _recita_seq9_completa() -> void:
	var et: Node = _et()
	# tg_9_duello_puro: 3 nemici senza abilita' (progresso 0.35)
	for i in 3:
		et.call("emit_event", "enemy_defeated", {"senza_abilita": true})
	# tg_9_allenamento: 2000 danni fisici (progresso 0.30)
	et.call("emit_event", "damage_dealt", {"tag_danno": "fisico", "quantita": 2000})
	# tg_9_protettore (US-804, riscritta da damage_absorbed_for_ally --
	# nessun alleato in scena in questa fase -- a perfect_parry): 12 parate
	# perfette (progresso 0.35)
	for i in 12:
		et.call("emit_event", "perfect_parry", {})


func test_accumulo_da_eventi() -> void:
	var a: Node = _acting()
	assert_almost_eq(a.call("acting_progress"), 0.0, "si parte da zero")
	for i in 3:
		_et().call("emit_event", "enemy_defeated", {"senza_abilita": true})
	# solo tg_9_duello_puro completata: contributo = 0.35
	assert_almost_eq(a.call("acting_progress"), 0.35, "una acting_action completata")


## US-804: tg_9_duello_puro (filtro senza_abilita:true) e' l'esempio
## concreto di come i filtri booleani espliciti (enemy.gd non emette piu'
## {}) fanno davvero la differenza -- il caso "l'ho ucciso con un'abilita'"
## e' testato a livello enemy.gd in test_enemy_payload.gd; qui si prova
## che Acting/EventTracker rispettano il filtro sull'evento cosi' com'e'.
func test_tg_9_duello_puro_avanza_solo_coi_kill_senza_abilita() -> void:
	var a: Node = _acting()
	for i in 3:
		_et().call("emit_event", "enemy_defeated", {"senza_abilita": false})
	assert_almost_eq(a.call("acting_progress"), 0.0,
		"3 kill CON abilita' (senza_abilita:false) non contano per tg_9_duello_puro")

	for i in 3:
		_et().call("emit_event", "enemy_defeated", {"senza_abilita": true})
	assert_almost_eq(a.call("acting_progress"), 0.35,
		"3 kill senza abilita' completano tg_9_duello_puro (0.35)")


func test_frazione_parziale() -> void:
	var a: Node = _acting()
	# 1 nemico su 3 -> 1/3 * 0.35
	_et().call("emit_event", "enemy_defeated", {"senza_abilita": true})
	assert_almost_eq(a.call("acting_progress"), 0.35 / 3.0, "un terzo del contributo", 0.001)


func test_cap_a_uno() -> void:
	var a: Node = _acting()
	_recita_seq9_completa()
	assert_almost_eq(a.call("acting_progress"), 1.0, "somma dei contributi = 1.0")
	# oltre il target non si sfora
	for i in 10:
		_et().call("emit_event", "enemy_defeated", {"senza_abilita": true})
	assert_almost_eq(a.call("acting_progress"), 1.0, "cap a 1.0")
	assert_true(a.call("e_completo"), "recitazione completa")


func test_decadimento_azione_incoerente() -> void:
	var a: Node = _acting()
	for i in 3:
		_et().call("emit_event", "enemy_defeated", {"senza_abilita": true})
	assert_almost_eq(a.call("acting_progress"), 0.35, "prima dell'incoerenza")

	# usare un'abilita' mentre si recita "duello puro" (senza_abilita) decade
	_et().call("emit_event", "ability_used", {"ability_id": "qualcosa"})
	assert_almost_eq(a.call("decadimento"), 0.05, "decadimento_azione_incoerente da balance.json")
	assert_almost_eq(a.call("acting_progress"), 0.30, "progresso decurtato")


func test_reset_su_avanzamento() -> void:
	var a: Node = _acting()
	_recita_seq9_completa()
	assert_almost_eq(a.call("acting_progress"), 1.0, "Sequenza 9 completa")

	_prog().avanza()  # -> Sequenza 8, emette sequence_changed -> _riparti
	assert_eq(_prog().sequence(), 8, "avanzato a Sequenza 8")
	# le acting_actions di Seq 8 hanno filtri diversi (tipo_arma, perfect_parry,
	# damage_taken): gli eventi di Seq 9 non le toccano
	assert_true(a.call("acting_progress") < 0.05, "recitazione ripartita da ~0")
	assert_almost_eq(a.call("decadimento"), 0.0, "decadimento azzerato")


func test_persistenza_nel_save() -> void:
	var a: Node = _acting()
	var s: Node = _save()
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	for i in 3:
		_et().call("emit_event", "enemy_defeated", {"senza_abilita": true})
	var atteso: float = a.call("acting_progress")
	assert_almost_eq(atteso, 0.35, "progresso da salvare")

	if s.esiste(SLOT):
		s.cancella(SLOT)
	assert_true(s.salva(SLOT, gs.snapshot())["ok"], "salva ok")

	# reset totale, poi reload
	_et().call("azzera")
	a.call("_riparti")
	assert_almost_eq(a.call("acting_progress"), 0.0, "azzerato")

	var c: Dictionary = s.carica(SLOT)
	gs.applica(c["dati"])
	assert_almost_eq(a.call("acting_progress"), atteso, "progresso ripristinato dal save")
	s.cancella(SLOT)
