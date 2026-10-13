extends "res://tests/test_case.gd"
## US-615 — FactionSystem: reputazione numerica + livello dalle soglie; il
## sospetto di Doran sale a ogni ability_used in citta'; usare un potere davanti
## a Vesna costa reputazione al quartiere; reputazione_min gating nei dialoghi.

func _root() -> Node: return Engine.get_main_loop().root
func _fs() -> Node: return _root().get_node("FactionSystem")
func _ws() -> Node: return _root().get_node("WorldState")
func _ks() -> Node: return _root().get_node("KnowledgeStore")
func _ns() -> Node: return _root().get_node("NpcSystem")
func _ts() -> Node: return _root().get_node("TimeSystem")
func _et() -> Node: return _root().get_node("EventTracker")
func _de() -> Node: return _root().get_node("DialogueEngine")
func _ae() -> Node: return _root().get_node("AbilityEngine")


func prepara() -> void:
	_fs().call("pulisci")
	_ws().call("pulisci")
	_ks().call("dimentica_tutto")
	_ns().call("pulisci")
	_ts().call("da_salvataggio", {})
	_de().call("termina")


func test_modifica_cambia_il_livello() -> void:
	var fs: Node = _fs()
	assert_eq(str(fs.call("livello", "porto")), "neutrale", "si parte a neutrale (rep 0)")
	fs.call("modifica", "porto", 25.0, "test")
	assert_eq(str(fs.call("livello", "porto")), "amichevole", "rep 25 -> amichevole (soglia 20)")
	fs.call("modifica", "porto", -60.0, "test")
	assert_eq(str(fs.call("livello", "porto")), "ostile", "rep -35 -> ostile (soglia -30)")
	assert_almost_eq(fs.call("reputazione", "porto"), -35.0, "reputazione numerica")


func test_giustizia_ha_le_soglie_invertite() -> void:
	var fs: Node = _fs()
	assert_eq(str(fs.call("livello", "giustizia")), "alleato", "sospetto 0 -> Doran si fida (alleato)")
	fs.call("modifica", "giustizia", 30.0, "test")
	assert_eq(str(fs.call("livello", "giustizia")), "neutrale", "sospetto 30 -> neutrale")


func test_sospetto_di_doran_sale_solo_in_citta() -> void:
	var fs: Node = _fs()
	_ws().call("entra_regione", "mirwada")
	for i in 10:
		_et().call("emit_event", "ability_used", {"ability_id": "x"})
	assert_almost_eq(fs.call("reputazione", "giustizia"), 30.0, "10 poteri in citta' -> +30 di sospetto")
	assert_true(_ks().call("conosce", "doran_sospetto_alto"), "a soglia 30 scatta il flag di caccia")

	var prima: float = fs.call("reputazione", "giustizia")
	_ws().call("entra_regione", "marche_crepuscolo")
	_et().call("emit_event", "ability_used", {"ability_id": "x"})
	assert_almost_eq(fs.call("reputazione", "giustizia"), prima, "fuori citta' il sospetto non sale")


func test_potere_davanti_a_vesna_abbassa_il_quartiere() -> void:
	var fs: Node = _fs()
	_ws().call("entra_regione", "mirwada")
	_ws().call("imposta_zona", "vicolo")           # all'alba Vesna e' in "vicolo"
	var player := Node2D.new()
	player.add_to_group("player")
	_root().add_child(player)
	_ae().ability_executed.emit("una_abilita", player, {})
	assert_almost_eq(fs.call("reputazione", "quartiere"), -5.0, "potere visto da Vesna -> -5 quartiere")

	# in un'altra zona Vesna non vede
	_ws().call("imposta_zona", "porto")
	_ae().ability_executed.emit("una_abilita", player, {})
	assert_almost_eq(fs.call("reputazione", "quartiere"), -5.0, "in un'altra zona nessun costo")
	player.free()


func test_reputazione_min_nasconde_una_scelta_di_dialogo() -> void:
	var fs: Node = _fs()
	# dlg_vesna: la scelta "cura" chiede reputazione_min ["quartiere", 0]
	fs.call("modifica", "quartiere", -5.0, "test")
	_de().call("avvia", "dlg_vesna", "npc_vesna")
	for sc in (_de().call("scelte_valide") as Array):
		assert_false(str(sc["text_i18n"]).ends_with(".cura"), "sotto soglia: 'cura' nascosta")
	_de().call("termina")
	fs.call("modifica", "quartiere", 10.0, "test")   # ora rep 5 >= 0
	_de().call("avvia", "dlg_vesna", "npc_vesna")
	var ha_cura := false
	for sc in (_de().call("scelte_valide") as Array):
		if str(sc["text_i18n"]).ends_with(".cura"):
			ha_cura = true
	assert_true(ha_cura, "sopra soglia: 'cura' disponibile")


func test_round_trip_del_save() -> void:
	var fs: Node = _fs()
	fs.call("modifica", "porto", 15.0, "test")
	fs.call("modifica", "ordine_minore", -8.0, "test")
	var snap: Dictionary = fs.call("per_salvataggio")
	fs.call("pulisci")
	assert_almost_eq(fs.call("reputazione", "porto"), 0.0, "pulisci azzera")
	fs.call("da_salvataggio", snap)
	assert_almost_eq(fs.call("reputazione", "porto"), 15.0, "porto round-trip")
	assert_almost_eq(fs.call("reputazione", "ordine_minore"), -8.0, "ordine_minore round-trip")
	fs.call("da_salvataggio", {"porto": "non_un_numero"})
	assert_almost_eq(fs.call("reputazione", "porto"), 0.0, "valore non numerico scartato")
