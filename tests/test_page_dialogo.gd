extends "res://tests/test_case.gd"
## US-613b — la pagina "dialogo" del libro: un dialogo che parte apre il libro
## su questa pagina, che mostra un bottone per ogni scelta valida; chiudere il
## libro termina il dialogo.

const OverlayScene := preload("res://scenes/book_overlay.tscn")
const PageDialogo := preload("res://scenes/pages/page_dialogo.tscn")


func _root() -> Node: return Engine.get_main_loop().root
func _book() -> Node: return _root().get_node("Book")
func _de() -> Node: return _root().get_node("DialogueEngine")
func _pr() -> Node: return _root().get_node("Progression")


func prepara() -> void:
	_de().call("termina")
	_book().call("azzera")
	_root().get_tree().paused = false
	_pr().call("configura", "twilight_giant", 9)
	_root().get_node("KnowledgeStore").call("dimentica_tutto")


func _monta_overlay() -> CanvasLayer:
	var ov: CanvasLayer = OverlayScene.instantiate()
	_root().add_child(ov)
	return ov


func _monta_pagina() -> Node:
	var p: Node = PageDialogo.instantiate()
	_root().add_child(p)
	return p


func test_book_json_dichiara_la_pagina_dialogo() -> void:
	var pt: Array = (_root().get_node("GameData").call("get_ui_book") as Dictionary).get("pages", [])
	var trovate: int = 0
	for p in pt:
		if str((p as Dictionary).get("tipo", "")) == "page_dialogo":
			trovate += 1
	assert_eq(trovate, 1, "una pagina di tipo page_dialogo in data/ui/book.json")


func test_dialogo_apre_il_libro_sulla_pagina_dialogo() -> void:
	var ov: CanvasLayer = _monta_overlay()
	_de().call("avvia", "dlg_mirco", "npc_mirco")
	assert_true(_book().call("e_aperto"), "il libro si apre quando parte un dialogo")
	assert_eq(_book().call("pagina_corrente"), "dialogo", "sulla pagina del dialogo")
	assert_true(ov.call("e_visibile"), "overlay visibile")
	_de().call("termina")
	assert_false(_book().call("e_aperto"), "a dialogo finito il libro si chiude")
	ov.free()


func test_un_bottone_per_scelta_valida() -> void:
	var p: Node = _monta_pagina()
	_de().call("avvia", "dlg_mirco", "npc_mirco")
	p.call("aggiorna")
	assert_eq(p.call("scelte_a_schermo"), 2, "a tier low: 2 scelte (la tier_min:mid e' nascosta)")
	_de().call("termina")
	_pr().call("configura", "twilight_giant", 6)
	_de().call("avvia", "dlg_mirco", "npc_mirco")
	p.call("aggiorna")
	assert_eq(p.call("scelte_a_schermo"), 3, "a tier mid compaiono 3 bottoni")
	p.free()


func test_il_bottone_fa_avanzare_il_dialogo() -> void:
	var p: Node = _monta_pagina()
	_de().call("avvia", "dlg_mirco", "npc_mirco")
	p.call("aggiorna")
	var primo: Button = null
	for c in p.get_children():
		if c is Button:
			primo = c
			break
	assert_true(primo != null, "c'e' almeno un bottone")
	primo.pressed.emit()
	assert_eq(str(_de().call("nodo_corrente").get("text_i18n")), "dialogue.mirco.n2",
		"premere la prima scelta segue il goto -> n2")
	p.free()


## US-1106 (fase 11): apri_creazione mette la pagina in modalita' "crea per
## te". npc_mirco esiste ma non ha ancora un campo 'crafter' (nessun NPC del
## roster ce l'ha finche' US-1108 non scrive il primo fabbro/alchimista): qui
## si prova lo stato vuoto + il bottone Chiudi, non una creazione vera (quella
## end-to-end con ingredienti reali e' l'AC di US-1108).
func test_apri_creazione_mostra_lo_stato_vuoto_senza_un_crafter() -> void:
	var p: Node = _monta_pagina()
	_de().call("avvia", "dlg_mirco", "npc_mirco")
	_de().apri_creazione.emit("npc_mirco")
	assert_true(p.call("in_creazione"), "la pagina e' in modalita' creazione")

	var chiudi: Button = null
	var testo := ""
	for c in p.get_children():
		if c is Label:
			testo += " " + c.text
		if c is Button and str(c.text) == tr("BOOK_NEGOZIO_CHIUDI"):
			chiudi = c
	assert_true(testo.contains(tr("BOOK_CREAZIONE_VUOTO")),
		"npc_mirco non sa creare nulla - stato vuoto mostrato")
	assert_true(chiudi != null, "il bottone Chiudi e' a schermo")
	chiudi.pressed.emit()
	assert_false(p.call("in_creazione"), "Chiudi esce dalla modalita' creazione")
	p.free()


## US-1108B (fase 11): il primo NPC crafter vero, end-to-end. Rosalba
## (erborista di Valle) offre ric_cura_maggiore (avanzata, NON nota al
## giocatore - la trappola che ignora_scoperta risolve). Senza ingredienti
## il bottone Crea resta disabilitato (AC di US-1108B, non un messaggio di
## fallimento dinamico); con gli ingredienti produce davvero la pozione e la
## ricetta resta ignota al giocatore dopo (il bypass e' dell'NPC, non suo).
func test_creazione_con_rosalba_produce_la_pozione_avanzata() -> void:
	var gd: Node = _root().get_node("GameData")
	var inv: Node = _root().get_node("Inventory")
	var ps: Node = _root().get_node("PotionSystem")
	inv.call("pulisci")
	var p: Node = _monta_pagina()
	assert_true(_de().call("avvia", "dlg_rosalba", "npc_rosalba"), "dlg_rosalba parte")
	assert_true(_de().call("scegli", 0), "sceglie 'Fammi vedere cosa sai preparare'")
	assert_true(p.call("in_creazione"), "si apre la modalita' creazione")

	var bottone_crea: Button = _bottone_crea(p)
	assert_true(bottone_crea != null, "il bottone Crea e' a schermo")
	assert_true(bottone_crea.disabled, "senza ingredienti il bottone resta disabilitato")

	var ingr: Dictionary = (gd.call("get_recipe", "ric_cura_maggiore") as Dictionary).get("ingredienti", {})
	assert_false(bool(ps.call("ricetta_nota", "ric_cura_maggiore")), "il giocatore non conosce questa ricetta")
	for ing in ingr:
		inv.call("aggiungi", ing, int(ingr[ing]))
	p.call("aggiorna")

	bottone_crea = _bottone_crea(p)
	assert_false(bottone_crea.disabled, "con gli ingredienti il bottone si abilita")
	bottone_crea.pressed.emit()

	assert_eq(int(inv.call("conta", "pozione_cura_maggiore")), 1, "la pozione avanzata e' stata creata")
	for ing in ingr:
		assert_eq(int(inv.call("conta", ing)), 0, "l'ingrediente '%s' e' stato consumato" % ing)
	assert_false(bool(ps.call("ricetta_nota", "ric_cura_maggiore")),
		"il bypass e' dell'NPC: la ricetta resta ignota al giocatore")
	p.free()


## US-1109 (fase 11): il secondo NPC crafter, dentro Mirwada - un fabbro
## invece di un alchimista, blueprint invece di ricetta. Stesso schema del
## test di Rosalba, ma su Forge.forgia.
func test_creazione_con_bram_forgia_la_spada() -> void:
	var inv: Node = _root().get_node("Inventory")
	inv.call("pulisci")
	var p: Node = _monta_pagina()
	assert_true(_de().call("avvia", "dlg_bram", "npc_bram"), "dlg_bram parte")
	assert_true(_de().call("scegli", 0), "sceglie 'Fammi vedere cosa sai forgiare'")
	assert_true(p.call("in_creazione"), "si apre la modalita' creazione")

	var bottone_crea: Button = _bottone_crea(p)
	assert_true(bottone_crea != null, "il bottone Crea e' a schermo")
	assert_true(bottone_crea.disabled, "senza materiali il bottone resta disabilitato")

	inv.call("aggiungi", "lingotto_ferro", 3)
	p.call("aggiorna")
	bottone_crea = _bottone_crea(p)
	assert_false(bottone_crea.disabled, "con i materiali il bottone si abilita")
	bottone_crea.pressed.emit()

	assert_eq(int(inv.call("conta", "spada_ferrea")), 1, "la spada e' stata forgiata")
	assert_eq(int(inv.call("conta", "lingotto_ferro")), 0, "il materiale e' stato consumato")
	p.free()


## US-1110: bp_anello_di_cristallo e' il primo blueprint con
## nota_da_subito:false assegnato a un crafter (Bram) - il bottone Crea deve
## restare disponibile (l'NPC "conosce il suo mestiere" a prescindere) mentre
## la forgiatura diretta del giocatore, senza bypass, resta bloccata.
func test_bram_forgia_l_anello_anche_se_il_giocatore_non_lo_conosce() -> void:
	var forge: Node = _root().get_node("Forge")
	var inv: Node = _root().get_node("Inventory")
	inv.call("pulisci")
	assert_false(bool(forge.call("blueprint_noto", "bp_anello_di_cristallo")),
		"il giocatore non conosce ancora bp_anello_di_cristallo (nota_da_subito:false)")
	var senza_bypass: Dictionary = forge.call("forgia", "bp_anello_di_cristallo")
	assert_false(bool(senza_bypass.get("ok")), "senza bypass la forgiatura diretta fallisce")

	var p: Node = _monta_pagina()
	assert_true(_de().call("avvia", "dlg_bram", "npc_bram"), "dlg_bram parte")
	assert_true(_de().call("scegli", 0), "sceglie 'Fammi vedere cosa sai forgiare'")
	assert_true(p.call("in_creazione"), "si apre la modalita' creazione")

	var ingr: Dictionary = (_root().get_node("GameData").call("get_blueprint", "bp_anello_di_cristallo") as Dictionary).get("materiali", {})
	for mat in ingr:
		inv.call("aggiungi", mat, int(ingr[mat]))
	p.call("aggiorna")

	var bottoni: Array = []
	for c in p.get_children():
		if c is HBoxContainer:
			for cc in c.get_children():
				if cc is Button and str(cc.text) == tr("BOOK_CREAZIONE_CREA"):
					bottoni.append(cc)
	assert_eq(bottoni.size(), 2, "Bram ha 2 blueprint: spada_ferrea + anello_di_cristallo")
	var bottone_anello: Button = bottoni[1]
	assert_false(bottone_anello.disabled, "con i materiali il bottone dell'anello e' attivo (bypass dell'NPC)")
	bottone_anello.pressed.emit()

	assert_eq(int(inv.call("conta", "anello_di_cristallo")), 1, "l'anello e' stato forgiato tramite Bram")
	assert_false(bool(forge.call("blueprint_noto", "bp_anello_di_cristallo")),
		"il bypass e' dell'NPC: il giocatore resta senza conoscere il blueprint")
	p.free()


func _bottone_crea(p: Node) -> Button:
	for c in p.get_children():
		if c is HBoxContainer:
			for cc in c.get_children():
				if cc is Button and str(cc.text) == tr("BOOK_CREAZIONE_CREA"):
					return cc
	return null


func test_chiudere_il_libro_termina_il_dialogo() -> void:
	var ov: CanvasLayer = _monta_overlay()
	_de().call("avvia", "dlg_mirco", "npc_mirco")
	assert_true(_de().call("in_corso"), "dialogo in corso")
	_book().call("chiudi")
	assert_false(_de().call("in_corso"), "chiudere il libro a mano termina il dialogo")
	ov.free()
