extends "res://tests/test_case.gd"
## US-810 — sezione Avanzamento nel diagramma: Prepara/Bevi la pozione.

const OverlayScene := preload("res://scenes/book_overlay.tscn")
## Ingredienti di formula_twilight_giant_9 (soglia_parziale: 2), stesso caso
## reale gia' usato in tests/test_advancement_gate.gd (US-212).
const ING9 := ["ferro_temperato", "sangue_di_toro", "radice_di_quercia"]


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	var b: Node = _n("/root/Book")
	if b != null:
		b.call("azzera")
	Engine.get_main_loop().root.get_tree().paused = false
	_n("/root/TribulationSystem").call("marca_superate_tutte")
	_n("/root/Progression").call("configura", "twilight_giant", 9)
	_n("/root/CharacteristicStore").call("pulisci")
	_n("/root/Inventory").call("pulisci")
	_n("/root/EventTracker").call("azzera")
	_n("/root/Acting").call("_riparti")
	_n("/root/Foundation").call("da_salvataggio", {})
	_n("/root/Madness").call("azzera")
	_n("/root/PotionSystem").call("scarta_pozione")
	var kn: Node = _n("/root/KnowledgeStore")
	if kn != null:
		kn.call("dimentica_tutto")


func _pagina() -> Node:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var b: Node = _n("/root/Book")
	b.call("apri")
	b.call("vai_a", "diagramma")
	for i in 4:
		ov.call("_process", 0.2)
	return ov


## tg_9_protettore (US-804): 3x enemy_defeated senza abilita' + un colpo
## fisico >= 2000 + 12x perfect_parry -> acting_progress() a 1.0. Stesso
## identico pattern di test_advancement_gate.gd::_recita_completa().
func _recita_completa() -> void:
	var et: Node = _n("/root/EventTracker")
	for i in 3:
		et.call("emit_event", "enemy_defeated", {"senza_abilita": true})
	et.call("emit_event", "damage_dealt", {"tag_danno": "fisico", "quantita": 2000})
	for i in 12:
		et.call("emit_event", "perfect_parry", {})


func test_prepara_pozione_con_caratteristica_e_ingredienti() -> void:
	var ov: CanvasLayer = _pagina()
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)

	_n("/root/CharacteristicStore").call("aggiungi", "char_twilight_giant_9")
	var inv: Node = _n("/root/Inventory")
	for iid in ING9:
		inv.call("aggiungi", iid, 1)

	var res: Dictionary = pag.call("prepara_pozione")
	assert_true(bool(res.get("ok", false)), "prepara riuscita con Caratteristica + 3/3 ingredienti")
	assert_false((_n("/root/PotionSystem").call("pozione_pronta") as Dictionary).is_empty(), "pozione pronta")
	for iid in ING9:
		assert_eq(int(inv.call("conta", iid)), 0, "%s scalato dall'Inventory" % iid)

	_n("/root/Book").call("chiudi")
	ov.free()


func test_bevi_con_recitazione_completa_avanza() -> void:
	var ov: CanvasLayer = _pagina()
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)

	_n("/root/CharacteristicStore").call("aggiungi", "char_twilight_giant_9")
	var inv: Node = _n("/root/Inventory")
	for iid in ING9:
		inv.call("aggiungi", iid, 1)
	pag.call("prepara_pozione")
	_recita_completa()

	var res: Dictionary = pag.call("bevi_pozione", false)
	assert_true(bool(res.get("avanzato", false)), "bevuta con recitazione completa -> avanzato")
	assert_eq(int(_n("/root/Progression").call("sequence")), 8, "9 -> 8")

	_n("/root/Book").call("chiudi")
	ov.free()
	_n("/root/Progression").call("configura", "twilight_giant", 9)


func test_prepara_parziale_bevi_completo_aggiunge_follia_extra() -> void:
	var ov: CanvasLayer = _pagina()
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)

	_n("/root/CharacteristicStore").call("aggiungi", "char_twilight_giant_9")
	var inv: Node = _n("/root/Inventory")
	# solo 2 dei 3: formula_twilight_giant_9.soglia_parziale e' 2 -> riesce
	# comunque, ma parziale (penalita_parziale.follia_extra alla bevuta).
	inv.call("aggiungi", ING9[0], 1)
	inv.call("aggiungi", ING9[1], 1)

	var res_prepara: Dictionary = pag.call("prepara_pozione")
	assert_true(bool(res_prepara.get("ok", false)), "prepara riuscita: soglia_parziale della formula e' 2")

	_recita_completa()
	var madness: Node = _n("/root/Madness")
	var prima: float = float(madness.call("valore"))
	var res: Dictionary = pag.call("bevi_pozione", false)
	assert_true(bool(res.get("avanzato", false)), "avanza comunque (recitazione completa)")
	assert_true(float(madness.call("valore")) > prima, "follia extra per la pozione parziale")

	_n("/root/Book").call("chiudi")
	ov.free()
	_n("/root/Progression").call("configura", "twilight_giant", 9)


func test_senza_caratteristica_prepara_e_rifiutata() -> void:
	var ov: CanvasLayer = _pagina()
	var pag: Node = ov.get_node("Pagina/Contenuto").get_child(0)

	var inv: Node = _n("/root/Inventory")
	for iid in ING9:
		inv.call("aggiungi", iid, 1)
	# NESSUNA Caratteristica in CharacteristicStore.

	var stato: Dictionary = pag.call("avanzamento_stato")
	assert_false(bool(stato.get("caratteristica_posseduta", true)), "sezione: Caratteristica mancante")
	assert_false(bool(stato.get("prepara_attivo", true)), "bottone Prepara disabilitato")

	var res: Dictionary = pag.call("prepara_pozione")
	assert_false(bool(res.get("ok", false)), "prepara rifiutata senza Caratteristica")
	assert_eq(str(res.get("reason", "")), "caratteristica_mancante", "motivo del rifiuto")

	_n("/root/Book").call("chiudi")
	ov.free()
