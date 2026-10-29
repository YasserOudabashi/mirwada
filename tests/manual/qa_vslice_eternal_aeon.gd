extends SceneTree
## US-907 — verifica giocata per davvero del primo Pathway Non-Standard:
## crea un personaggio Eternal Aeon dal selettore REALE di creazione (US-907
## ha appena esteso _pathway_scelta() a includere anche i Pathway
## non_standard, non solo GameData.pathway_ids()), poi soddisfa un Boon con
## tutte e tre le fonti insieme (quest completata, comportamento contato,
## sacrificio pagato - eternal_aeon Sequenza 5, US-904/905) e lo riceve
## dalla pagina diagramma vera (US-906), verificando che
## Progression.sequence() sia sceso. Stesso schema di
## tests/manual/qa_vslice_darkness.gd (avvio reale di main.tscn, creazione
## dal selettore) + tests/manual/qa_dono_diagramma.gd (la parte Dono).
##
## Salta deliberatamente il cammino 9->6 (non richiesto dall'AC di US-907,
## che chiede solo "soddisfa i requisiti di un Boon... e lo riceve"):
## Progression.configura() porta dritto alla Sequenza 5, stessa scorciatoia
## gia' documentata in tests/manual/qa_vslice.gd per la Caratteristica.
##
## Lancio:
##   Xvfb :99 -screen 0 1280x720x24 &
##   DISPLAY=:99 godot --display-driver x11 --rendering-driver opengl3 \
##     --path . --script res://tests/manual/qa_vslice_eternal_aeon.gd

const OUT := "/tmp/qa_vslice_eternal_aeon"
const PID := "eternal_aeon"
var _main: Node
var _ok: bool = true


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	await process_frame
	TranslationServer.set_locale("it")

	await _passo_1_avvio()
	if _ok: await _passo_2_creazione()
	if _ok: await _passo_3_salta_a_sequenza_5()
	if _ok: await _passo_4_soddisfa_il_boon()
	if _ok: await _passo_5_ricevi_il_dono()

	if _ok:
		print("=== qa_vslice_eternal_aeon: TUTTI I PASSI OK ===")
		quit(0)
	else:
		printerr("=== qa_vslice_eternal_aeon: FALLITO ===")
		quit(1)


# --- helper (stessi di tests/manual/qa_vslice_darkness.gd) --------------

func _assert(cond: bool, msg: String) -> bool:
	if cond:
		print("  ok: ", msg)
	else:
		printerr("  FALLITO: ", msg)
		_ok = false
	return cond


func _attendi_pagina(frame: int = 40) -> void:
	for _i in frame:
		await process_frame


func _screenshot(nome: String) -> void:
	var img: Image = get_root().get_texture().get_image()
	if img == null:
		printerr("  screenshot NULLO per ", nome,
			" (lanciato con --headless? serve --display-driver x11 --rendering-driver opengl3)")
		return
	img.save_png("%s/%s.png" % [OUT, nome])
	print("  screenshot -> %s/%s.png" % [OUT, nome])


func _n(path: String) -> Node:
	return get_root().get_node_or_null(path)


func _pagina_viva() -> Node:
	var overlay: Node = _main.get_node_or_null("BookOverlay")
	if overlay == null:
		return null
	var contenuto: Node = overlay.get_node_or_null("Pagina/Contenuto")
	if contenuto == null or contenuto.get_child_count() == 0:
		return null
	return contenuto.get_child(0)


func _passo_1_avvio() -> void:
	print("=== 1. avvio: main.tscn, il libro si apre da solo sullo scaffale ===")
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	await process_frame
	await process_frame
	var book: Node = _n("/root/Book")
	_assert(bool(book.call("e_aperto")), "il libro e' aperto all'avvio")
	_screenshot("01_scaffale")


func _passo_2_creazione() -> void:
	print("=== 2. creazione: Eternal Aeon scelto dal selettore REALE, conferma ===")
	var book: Node = _n("/root/Book")
	var gs0: Node = _n("/root/GameState")
	gs0.call("scegli_slot", 0)
	book.call("vai_a", "frontespizio")
	await _attendi_pagina()
	var pagina: Node = _pagina_viva()
	_assert(pagina != null and pagina.has_method("conferma"), "la pagina di creazione e' viva")
	if pagina == null:
		return
	pagina.get("_campo").text = "Tester Eternal Aeon"
	var pathway_ids: Array = pagina.get("_pathway_ids")
	# US-907: _pathway_ids ora e' pathway_ids() + pathway_ids_non_standard() -
	# la prova diretta che Eternal Aeon e' selezionabile col ciclo standard
	# di creazione (deciso con l'utente, PRD fase 9 §5), non solo che
	# Progression accetta l'id se gia' passato a mano.
	var idx: int = pathway_ids.find(PID)
	_assert(idx >= 0, "'%s' e' fra i Pathway del selettore (non solo gli standard)" % PID)
	if idx >= 0:
		(pagina.get("_pathway") as OptionButton).selected = idx
	pagina.call("conferma")
	await _attendi_pagina()
	var gs: Node = _n("/root/GameState")
	var prog: Node = _n("/root/Progression")
	_assert(bool(gs.call("partita_in_corso")), "la partita e' iniziata")
	_assert(str(prog.call("pathway")) == PID, "Progression.pathway() == '%s'" % PID)
	_assert(int(prog.call("sequence")) == 9, "si parte dalla Sequenza 9")
	_screenshot("02_dopo_conferma_eternal_aeon")


## Scorciatoia dichiarata (vedi commento in testa al file): il cammino
## 9->6 non e' richiesto dall'AC di questa story.
func _passo_3_salta_a_sequenza_5() -> void:
	print("=== 3. scorciatoia dichiarata: Progression.configura() -> Sequenza 5 ===")
	_n("/root/TribulationSystem").call("marca_superate_tutte")
	_n("/root/Progression").call("configura", PID, 5)
	_n("/root/BoonSystem").call("_riparti")
	_assert(int(_n("/root/Progression").call("sequence")) == 5, "Sequenza 5")


func _passo_4_soddisfa_il_boon() -> void:
	print("=== 4. soddisfa il Boon di eternal_aeon_5: quest + comportamento + sacrificio ===")
	# La pagina diagramma (griglia 10x10 + dettaglio) non sta nei 360px di
	# altezza del design (nessuno ScrollContainer, limite gia' presente,
	# segnalato in US-906): solo per gli screenshot dei passi 4/5, ingrandisco
	# la risoluzione interna per far entrare la sezione "Il Dono" nello
	# screenshot, senza toccare project.godot / la risoluzione vera del gioco.
	get_root().content_scale_size = Vector2i(640, 900)
	get_root().size = Vector2i(640, 900)
	(_n("/root/QuestSystem").get("_completate") as Array).append("q_vesna_01")
	for i in 4:
		_n("/root/EventTracker").call("emit_event", "ability_used",
			{"ability_id": "ea_richiamo_del_momento_perduto"})
	_n("/root/Inventory").call("aggiungi", "memoria_cristallizzata", 2)

	var book: Node = _n("/root/Book")
	# conferma() alla creazione ha chiuso il libro (si torna nel mondo):
	# va riaperto prima di poter cambiare pagina.
	book.call("apri_a", "diagramma")
	await _attendi_pagina()
	var pag: Node = _pagina_viva()
	_assert(pag != null and pag.has_method("ricevi_dono"), "la pagina diagramma e' viva")
	if pag == null:
		return
	var stato: Dictionary = pag.call("avanzamento_stato")
	_assert(bool(stato.get("boon", false)), "il ramo 'boon' e' attivo per Eternal Aeon")
	_assert((stato.get("requisiti", []) as Array).size() == 3, "eternal_aeon_5: tre requisiti")
	_assert(bool(stato.get("puo_ricevere", false)), "tutti e tre i requisiti soddisfatti")
	_screenshot("03_boon_soddisfatto")


func _passo_5_ricevi_il_dono() -> void:
	print("=== 5. Ricevi il Dono: la Sequenza scende ===")
	var pag: Node = _pagina_viva()
	if pag == null:
		_assert(false, "pagina diagramma assente al momento di ricevere il Dono")
		return
	var res: Dictionary = pag.call("ricevi_dono")
	_assert(bool(res.get("ok", false)), "ricevi_dono ok")
	_assert(bool(res.get("avanzato", false)), "Sequenza avanzata")
	_assert(int(_n("/root/Progression").call("sequence")) == 4, "eternal_aeon: 5 -> 4")
	await _attendi_pagina()
	_screenshot("04_dono_ricevuto_sequenza_scesa")
