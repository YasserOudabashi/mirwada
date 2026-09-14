extends SceneTree
## US-906 — verifica a schermo della sezione "Dono" nel diagramma:
## screenshot con i requisiti parzialmente soddisfatti, poi dopo aver
## ricevuto il Boon (Sequenza scesa). Stesso overlay del test headless
## tests/test_page_dono.gd (book_overlay.tscn instanziato direttamente,
## nessun bisogno della scena Main/mondo: qui si verifica solo la pagina).
##
## Lancio:
##   Xvfb :99 -screen 0 1280x720x24 &
##   DISPLAY=:99 godot --display-driver x11 --rendering-driver opengl3 \
##     --path . --script res://tests/manual/qa_dono_diagramma.gd

const OverlayScene := preload("res://scenes/book_overlay.tscn")
const OUT := "/tmp/qa_dono_diagramma"
var _ok: bool = true
var _ov: CanvasLayer


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	await process_frame
	TranslationServer.set_locale("it")
	# La pagina diagramma (griglia 10x10 + dettaglio) non sta nei 360px di
	# altezza del design (nessuno ScrollContainer, limite gia' presente
	# prima di questa story): solo per QUESTO script di verifica, ingrandisco
	# la RISOLUZIONE INTERNA (content_scale_size, quella che conta con lo
	# stretch mode "viewport" di project.godot - la finestra da sola non
	# basta) per far entrare anche la sezione "Il Dono" nello screenshot,
	# senza toccare project.godot / la risoluzione vera del gioco.
	get_root().content_scale_size = Vector2i(640, 900)
	get_root().size = Vector2i(640, 900)

	await _passo_1_apri_su_eternal_aeon_5()
	await _passo_2_soddisfa_i_requisiti()
	await _passo_3_ricevi_il_dono()

	if _ok:
		print("=== qa_dono_diagramma: TUTTI I PASSI OK ===")
		quit(0)
	else:
		printerr("=== qa_dono_diagramma: FALLITO ===")
		quit(1)


func _assert(cond: bool, msg: String) -> bool:
	if cond:
		print("  ok: ", msg)
	else:
		printerr("  FALLITO: ", msg)
		_ok = false
	return cond


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


func _pagina() -> Node:
	return _ov.get_node("Pagina/Contenuto").get_child(0)


func _passo_1_apri_su_eternal_aeon_5() -> void:
	print("=== passo 1: apri il diagramma su Eternal Aeon, Sequenza 5 ===")
	# Sequenza 5 e' anche uno dei 4 "salti di fascia" di TribulationSystem
	# (fase 7, Pathway-agnostico, data/tribulations/trib_5_4.json): senza
	# superarla Progression.avanza() resta bloccato anche a Boon soddisfatto.
	_n("/root/TribulationSystem").call("marca_superate_tutte")
	_n("/root/Progression").call("configura", "eternal_aeon", 5)
	_n("/root/BoonSystem").call("_riparti")
	_n("/root/EventTracker").call("azzera")
	_n("/root/Inventory").call("pulisci")

	_n("/root/Book").call("azzera")
	_ov = OverlayScene.instantiate()
	_ov.name = "Overlay"
	get_root().add_child(_ov)
	await process_frame
	_n("/root/Book").call("apri")
	_n("/root/Book").call("vai_a", "diagramma")
	# la voltata pagina e' un contatore avanzato in _process(delta), non un
	# Tween (l'overlay vive col mondo in pausa): serve spingerla a mano oltre
	# la meta' (t>=0.5, dove _rendi() monta la pagina vera) prima che
	# aggiornare i dati sotto abbia un senso - stesso schema gia' in uso in
	# tests/test_page_avanzamento.gd/test_page_diagramma.gd (ov.call("_process", 0.2)).
	for i in 4:
		_ov.call("_process", 0.2)
	# la logica e' avanzata a mano sopra (_process chiamato direttamente), ma
	# il frame va comunque RESO davvero prima di uno screenshot: senza
	# almeno un process_frame reale la texture catturata resta quella
	# dell'ultimo frame effettivamente disegnato (vuoto).
	await process_frame
	await process_frame

	var pag: Node = _pagina()
	var stato: Dictionary = pag.call("avanzamento_stato")
	_assert(bool(stato.get("boon", false)), "il ramo 'boon' e' attivo per Eternal Aeon")
	_assert((stato.get("requisiti", []) as Array).size() == 3, "eternal_aeon_5: tre requisiti")
	_assert(not bool(stato.get("puo_ricevere", true)), "nessun requisito ancora soddisfatto")
	_screenshot("01_dono_requisiti_parziali")


func _passo_2_soddisfa_i_requisiti() -> void:
	print("=== passo 2: soddisfa i tre requisiti (quest, comportamento, sacrificio) ===")
	(_n("/root/QuestSystem").get("_completate") as Array).append("q_vesna_01")
	for i in 4:
		_n("/root/EventTracker").call("emit_event", "ability_used",
			{"ability_id": "ea_richiamo_del_momento_perduto"})
	_n("/root/Inventory").call("aggiungi", "memoria_cristallizzata", 2)

	var pag: Node = _pagina()
	pag.call("aggiorna")
	for i in 3:
		await process_frame
	var stato: Dictionary = pag.call("avanzamento_stato")
	_assert(bool(stato.get("puo_ricevere", false)), "tutti e tre i requisiti ora soddisfatti")
	_screenshot("02_dono_requisiti_soddisfatti")


func _passo_3_ricevi_il_dono() -> void:
	print("=== passo 3: Ricevi il Dono ===")
	var pag: Node = _pagina()
	var res: Dictionary = pag.call("ricevi_dono")
	_assert(bool(res.get("ok", false)), "ricevi_dono ok")
	_assert(bool(res.get("avanzato", false)), "Sequenza avanzata")
	_assert(int(_n("/root/Progression").call("sequence")) == 4, "eternal_aeon: 5 -> 4")
	for i in 3:
		await process_frame
	_screenshot("03_dono_ricevuto_sequenza_scesa")
