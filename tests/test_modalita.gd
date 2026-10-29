extends "res://tests/test_case.gd"
## Modalita' di gioco (decisione 2026-10-20): scelta a inizio partita, fissa,
## nel salvataggio; i numeri vengono da data/modalita.json.

const SLOT := 912


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func prepara() -> void:
	if _n("/root/GameState") != null:
		_n("/root/GameState").set("_partita_attiva", false)


func _fine() -> void:
	_n("/root/SaveSystem").call("cancella", SLOT)
	_n("/root/GameState").set("_partita_attiva", false)
	_n("/root/GameState").set("modalita", "facile")


func test_i_dati_hanno_le_due_modalita() -> void:
	var gd: Node = _n("/root/GameData")
	assert_true("facile" in (gd.call("modalita_ids") as Array), "facile nei dati")
	assert_true("difficile" in (gd.call("modalita_ids") as Array), "difficile nei dati")
	assert_eq(str((gd.call("get_modalita", "difficile") as Dictionary).get("tema_arte")), "cupo", "difficile = arte cupa")


func test_la_modalita_scelta_resta_e_dice_i_numeri() -> void:
	var gs: Node = _n("/root/GameState")
	gs.call("nuova_partita", "Enel", SLOT, [], "", "difficile")
	assert_eq(str(gs.get("modalita")), "difficile", "modalita' scelta")
	assert_eq(str(gs.call("tema_arte")), "cupo", "tema dell'arte dai dati")
	var atteso: float = float(((_n("/root/GameData").call("get_modalita", "difficile") as Dictionary)
		.get("moltiplicatori", {}) as Dictionary).get("danno_al_giocatore", 1.0))
	assert_almost_eq(float(gs.call("moltiplicatore", "danno_al_giocatore")), atteso, "numero dai dati")
	assert_almost_eq(float(gs.call("moltiplicatore", "numero_che_non_esiste")), 1.0, "nome assente = 1")
	_fine()


func test_facile_non_cambia_niente() -> void:
	var gs: Node = _n("/root/GameState")
	gs.call("nuova_partita", "Enel", SLOT, [], "", "facile")
	for nome in ["danno_al_giocatore", "danno_ai_nemici", "cure"]:
		assert_almost_eq(float(gs.call("moltiplicatore", nome)), 1.0, "facile: %s = 1" % nome)
	assert_eq(str(gs.call("tema_arte")), "luminoso", "facile = arte luminosa")
	_fine()


func test_la_modalita_si_salva_e_si_ricarica() -> void:
	var gs: Node = _n("/root/GameState")
	var s: Node = _n("/root/SaveSystem")
	gs.call("nuova_partita", "Enel", SLOT, [], "", "difficile")
	gs.set("modalita", "facile")
	var r: Dictionary = s.call("carica", SLOT)
	gs.call("applica", r["dati"])
	assert_eq(str(gs.get("modalita")), "difficile", "torna dal save")
	_fine()


func test_save_vecchio_e_modalita_sconosciuta_diventano_il_default() -> void:
	var gs: Node = _n("/root/GameState")
	gs.set("modalita", "difficile")
	gs.call("applica", {"nome_personaggio": "Enel"})
	assert_eq(str(gs.get("modalita")), "facile", "save senza il campo -> default dei dati")
	gs.call("nuova_partita", "Enel", SLOT, [], "impossibile")
	assert_eq(str(gs.get("modalita")), "facile", "modalita' che non esiste -> default")
	_fine()


# --- Story 2: i numeri si applicano -----------------------------------------

const Hurtbox := preload("res://scripts/hurtbox.gd")
const Stats := preload("res://scripts/stats_component.gd")


func _entita(giocatore: bool) -> Dictionary:
	var host := CharacterBody2D.new()
	if giocatore:
		host.add_to_group("player")
	var s: Node = Stats.new()
	s.name = "StatsComponent"
	host.add_child(s)
	var hb: Area2D = Hurtbox.new()
	host.add_child(hb)
	Engine.get_main_loop().root.add_child(host)
	s.call("configure_from_balance", 9)
	s.set("hp", 100.0)
	return {"host": host, "stats": s, "hurtbox": hb}


func _numero(nome: String) -> float:
	return float(((_n("/root/GameData").call("get_modalita", "difficile") as Dictionary)
		.get("moltiplicatori", {}) as Dictionary).get(nome, 1.0))


func _colpo(giocatore: bool, modalita: String) -> float:
	_n("/root/GameState").set("modalita", modalita)
	var e: Dictionary = _entita(giocatore)
	e["hurtbox"].subisci(10.0, 0.0, null)
	var tolto: float = 100.0 - float(e["stats"].get("hp"))
	e["host"].free()
	return tolto


func test_in_difficile_il_danno_segue_i_numeri() -> void:
	assert_almost_eq(_colpo(true, "difficile"), 10.0 * _numero("danno_al_giocatore"), "danno al giocatore")
	assert_almost_eq(_colpo(false, "difficile"), 10.0 * _numero("danno_ai_nemici"), "danno ai nemici")
	_n("/root/GameState").set("modalita", "facile")


func test_in_facile_il_danno_e_quello_di_sempre() -> void:
	assert_almost_eq(_colpo(true, "facile"), 10.0, "giocatore: 10")
	assert_almost_eq(_colpo(false, "facile"), 10.0, "nemico: 10")


func _cura(giocatore: bool, modalita: String) -> float:
	_n("/root/GameState").set("modalita", modalita)
	var e: Dictionary = _entita(giocatore)
	e["stats"].set("hp", 40.0)
	_n("/root/AbilityEngine").call("esegui_primitiva", "heal", {"quantita": 20.0, "istantaneo": true}, e["host"])
	var dato: float = float(e["stats"].get("hp")) - 40.0
	e["host"].free()
	_n("/root/GameState").set("modalita", "facile")
	return dato


func test_le_cure_del_giocatore_seguono_i_numeri() -> void:
	assert_almost_eq(_cura(true, "difficile"), 20.0 * _numero("cure"), "cura del giocatore in difficile")
	assert_almost_eq(_cura(true, "facile"), 20.0, "cura del giocatore in facile")
	assert_almost_eq(_cura(false, "difficile"), 20.0, "la cura di un altro non cambia")


# --- Story 3: la scelta nel frontespizio ------------------------------------

const OverlayScene := preload("res://scenes/book_overlay.tscn")


func _pagina_creazione() -> Array:
	var ov: CanvasLayer = OverlayScene.instantiate()
	Engine.get_main_loop().root.add_child(ov)
	var b: Node = _n("/root/Book")
	b.call("apri")
	b.call("vai_a", "frontespizio")
	for i in 5:
		ov.call("_process", 0.2)
	return [ov, ov.get_node("Pagina/Contenuto").get_child(0)]


func _bottoni(nodo: Node, out: Array) -> Array:
	for c in nodo.get_children():
		if c is Button and str(c.name).begins_with("Modalita_"):
			out.append(c)
		_bottoni(c, out)
	return out


func test_il_frontespizio_offre_le_modalita_e_parte_con_quella_scelta() -> void:
	if bool(_n("/root/GameState").call("partita_in_corso")):
		return  # un'altra suite ha lasciato una partita attiva: il path dati e' coperto sopra
	var res: Array = _pagina_creazione()
	var pag: Node = res[1]
	var bottoni: Array = _bottoni(pag, [])
	assert_eq(bottoni.size(), (_n("/root/GameData").call("modalita_ids") as Array).size(), "un bottone per modalita'")
	var premuti: Array = bottoni.filter(func(b: Button) -> bool: return b.button_pressed)
	assert_eq(premuti.size(), 1, "uno solo premuto")
	assert_eq(str(premuti[0].name), "Modalita_facile", "premuto il default dei dati")
	for b in bottoni:
		if str(b.name) == "Modalita_difficile":
			b.button_pressed = true
			b.pressed.emit()
	_n("/root/GameState").call("scegli_slot", SLOT)
	pag.call("conferma")
	assert_eq(str(_n("/root/GameState").get("modalita")), "difficile", "la partita parte in difficile")
	res[0].free()
	_fine()


func test_ogni_modalita_ha_i_suoi_testi() -> void:
	for lingua in ["it", "en"]:
		TranslationServer.set_locale(lingua)
		for mid in _n("/root/GameData").call("modalita_ids"):
			for k in ["MODALITA_%s" % str(mid).to_upper(), "MODALITA_%s_DESCR" % str(mid).to_upper()]:
				assert_true(tr(k) != k, "%s ha il testo in %s" % [k, lingua])
	TranslationServer.set_locale("it")
