extends SceneTree
## US-1306 — l'Atto II giocato per davvero, con Xvfb: dalla Sequenza 7 alla 4 passando per il duello con Aldo
## (US-1304), la quest di fazione (US-1303) e la tribolazione del salto 5 -> 4.
## NON fa parte della suite headless. Lancio (MAI --headless: gli screenshot sarebbero nulli):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --display-driver x11 --rendering-driver opengl3 \
##     --path . --script res://tests/manual/qa_atto_2.gd -- <cartella delle foto>
##
## Scorciatoie dichiarate (il resto passa dai sistemi veri: dialoghi, quest, pozioni, tribolazione):
## - si parte gia' alla Sequenza 7 (l'Atto I e' di qa_vslice);
## - ingredienti e Caratteristica di ogni pozione sono concessi, non raccolti;
## - la recitazione si riempie emettendo gli eventi delle sue azioni, come in qa_vslice;
## - il colpo che chiude il duello e' dato azzerando la salute dell'avversario (il combattimento ha i suoi test).
## Esce 0 se ogni passo passa, 1 al primo fallimento.

var OUT := "/tmp/qa_atto_2"
var _main: Node
var _ok: bool = true


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		OUT = args[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	TranslationServer.set_locale("it")
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	await _aspetta(30)
	_n("/root/GameState").call("nuova_partita", "Enel", 0, [], str(_n("/root/Progression").call("pathway")), "facile")
	_n("/root/Book").call("chiudi")
	await _aspetta(30)
	var prog: Node = _n("/root/Progression")
	prog.call("configura", str(prog.call("pathway")), 7)

	await _passo_1_salto_di_tier()
	if _ok: await _passo_2_duello()
	if _ok: await _passo_3_quest_di_fazione()
	if _ok: await _passo_4_fino_alla_tribolazione()
	if _ok: await _passo_5_sequenza_4()
	if _ok:
		print("=== qa_atto_2: TUTTI I PASSI OK ===")
		quit(0)
	else:
		printerr("=== qa_atto_2: FALLITO ===")
		quit(1)


func _passo_1_salto_di_tier() -> void:
	print("=== 1. Sequenza 7 -> 6: il salto di tier, Aldo offre il duello ===")
	_assert(await _avanza_con_la_pozione() == 6, "con la pozione si arriva alla Sequenza 6")
	_assert(str(_n("/root/Progression").call("tier")) == "mid", "tier mid: comincia l'Atto II")
	_assert(bool(_n("/root/KnowledgeStore").call("conosce", "aldo_duello_disponibile")), "Aldo ha il duello da offrire")


func _passo_2_duello() -> void:
	print("=== 2. il duello con Aldo in piazza ===")
	_n("/root/TimeSystem").call("forza_momento", "mezzogiorno")
	await _aspetta(10)
	var mondo: Node = _main.get_node("Mondo")
	var aldo: Node2D = mondo.get_node_or_null("Npc_npc_aldo")
	if not _assert(aldo != null, "a mezzogiorno Aldo e' in piazza"):
		return
	mondo.call("colloca", get_first_node_in_group("player"), aldo.position + Vector2(48, 24))
	await _aspetta(150)
	_parla("dlg_aldo", "npc_aldo", ["dialogue.aldo.n1.sfida", "dialogue.aldo.n2.inizia"])
	await _aspetta(90)
	var avversario: Node = null
	for c in mondo.get_children():
		if c.has_meta("duello"):
			avversario = c
	if not _assert(avversario != null, "accettato il duello, Aldo e' un avversario sul campo"):
		return
	_screenshot("01_duello")
	avversario.get_node("StatsComponent").set("hp", 0.0)
	await _aspetta(150)                                  # la pausa dei dati, poi il dialogo della vittoria
	_assert(str(_n("/root/DialogueEngine").call("dialogue_id")) == "dlg_aldo_vinto", "battuto, Aldo parla da sconfitto")
	_screenshot("02_duello_vinto")
	_scegli("dialogue.aldo_vinto.n1.rispetto")
	_assert(bool(_n("/root/KnowledgeStore").call("conosce", "aldo_duello_vinto")), "la vittoria e' scritta")
	_n("/root/Book").call("chiudi")
	await _aspetta(20)


func _passo_3_quest_di_fazione() -> void:
	print("=== 3. la quest di fazione: le carte fra l'Ordine e il porto ===")
	var qs: Node = _n("/root/QuestSystem")
	var fs: Node = _n("/root/FactionSystem")
	_parla("dlg_ottavia", "npc_ottavia", ["dialogue.ottavia.n1.chiedi", "dialogue.ottavia.n2.accetta"])
	_parla("dlg_ottavia", "npc_ottavia", ["dialogue.ottavia.n1.ordine", "dialogue.ottavia.n3.accetta"])
	_assert(str(qs.call("stato", "q_ottavia_02")) == "attiva", "Ottavia affida la ricerca delle carte")
	_n("/root/Book").call("apri_a", "journal")
	await _aspetta(50)
	_screenshot("03_diario")
	_n("/root/Book").call("chiudi")
	_n("/root/TimeSystem").call("forza_momento", "notte_fonda")
	await _aspetta(10)
	_parla("dlg_bruno", "npc_bruno", ["dialogue.bruno.n1.aiuta"])
	_parla("dlg_bruno", "npc_bruno", ["dialogue.bruno.n1.carte"])
	await _aspetta(40)
	_screenshot("04_la_scelta")
	_scegli("dialogue.bruno.n3.ordine")
	_assert(str(qs.call("stato", "q_ottavia_02")) == "completata", "le carte tornano all'Archivio")
	_assert(float(fs.call("reputazione", "ordine_minore")) > float(fs.call("reputazione", "porto")), "l'Ordine ora ti stima piu' del porto")
	_n("/root/DialogueEngine").call("termina")
	_n("/root/Book").call("chiudi")
	await _aspetta(20)


func _passo_4_fino_alla_tribolazione() -> void:
	print("=== 4. Sequenza 6 -> 5, e la tribolazione del salto 5 -> 4 ===")
	_assert(await _avanza_con_la_pozione() == 5, "con la pozione si arriva alla Sequenza 5")
	var trib: Node = _n("/root/TribulationSystem")
	_assert(not (trib.call("tribolazione_per", 5) as Dictionary).is_empty(), "il salto 5 -> 4 ha la sua tribolazione")
	# la prova chiede di aver smosso tre persone: Ottavia, Bruno e Aldo lo sono gia' stati in questo cammino
	if not bool(trib.call("superata", 5)):
		_parla("dlg_doran", "npc_doran", ["dialogue.doran.n1.collabora"])
		_parla("dlg_bruno", "npc_bruno", ["dialogue.bruno.n1.aiuta"])
	_assert(bool(trib.call("superata", 5)), "la tribolazione e' superata parlando con la gente di Mirwada")
	_n("/root/DialogueEngine").call("termina")
	_n("/root/Book").call("chiudi")
	await _aspetta(20)


func _passo_5_sequenza_4() -> void:
	print("=== 5. Sequenza 5 -> 4: fine dell'Atto II ===")
	_assert(await _avanza_con_la_pozione() == 4, "con la pozione si arriva alla Sequenza 4")
	_assert(str(_n("/root/Progression").call("tier")) == "saint", "tier saint: comincia l'Atto III")
	_n("/root/Book").call("chiudi")
	await _aspetta(40)
	_screenshot("06_sequenza_4")


# --- helper -----------------------------------------------------------

## Una Sequenza avanti per la via vera della pagina del diagramma: Prepara e Bevi. Torna la Sequenza d'arrivo.
func _avanza_con_la_pozione() -> int:
	var prog: Node = _n("/root/Progression")
	var gd: Node = _n("/root/GameData")
	var et: Node = _n("/root/EventTracker")
	var potion: Dictionary = prog.call("sequence_data").get("potion", {})
	var car: Dictionary = gd.call("characteristic_for", str(prog.call("pathway")), int(potion.get("characteristic_sequence", -1)))
	_n("/root/CharacteristicStore").call("aggiungi", str(car.get("id", "")))
	for iid in potion.get("ingredients", []):
		_n("/root/Inventory").call("aggiungi", str(iid), 1)
	for a in (prog.call("sequence_data").get("acting_actions", []) as Array):
		var filtri: Dictionary = ((a as Dictionary).get("filtri", {}) as Dictionary).duplicate()
		var ev: String = str((a as Dictionary).get("evento", ""))
		var target: float = float((a as Dictionary).get("target", 1))
		if str(gd.call("get_tracked_event", ev).get("misura", "conteggio")) == "conteggio":
			for _i in int(ceil(target)):
				et.call("emit_event", ev, filtri.duplicate())
		else:
			filtri["quantita"] = target
			et.call("emit_event", ev, filtri)
	var book: Node = _n("/root/Book")
	if bool(book.call("e_aperto")):
		book.call("vai_a", "diagramma")
	else:
		book.call("apri_a", "diagramma")
	await _aspetta(50)
	var pagina: Node = _main.get_node("BookOverlay/Pagina/Contenuto").get_child(0)
	var prep: Dictionary = pagina.call("prepara_pozione")
	_assert(bool(prep.get("ok", false)), "la pozione si prepara (%s)" % prep.get("reason", ""))
	var prima: int = int(prog.call("sequence"))
	var bevi: Dictionary = pagina.call("bevi_pozione", not bool(_n("/root/Acting").call("e_completo")))
	_assert(bool(bevi.get("avanzato", false)), "bevuta la pozione si avanza dalla Sequenza %d (%s)" % [prima, bevi.get("reason", "")])
	await _aspetta(20)
	_screenshot("seq_%d" % int(prog.call("sequence")))
	book.call("chiudi")
	await _aspetta(10)
	return int(prog.call("sequence"))


## Apre un dialogo e fa le scelte date (chiavi i18n), una dopo l'altra.
func _parla(dialogo: String, npc: String, scelte: Array) -> void:
	var de: Node = _n("/root/DialogueEngine")
	de.call("termina")
	_assert(bool(de.call("avvia", dialogo, npc)), "si parla con %s" % npc)
	for s in scelte:
		_scegli(str(s))


func _scegli(chiave: String) -> void:
	var de: Node = _n("/root/DialogueEngine")
	var valide: Array = de.call("scelte_valide")
	for i in valide.size():
		if str(valide[i]["text_i18n"]) == chiave:
			de.call("scegli", i)
			return
	_assert(false, "la scelta %s si vede" % chiave)


func _assert(cond: bool, msg: String) -> bool:
	if cond:
		print("  ok: ", msg)
	else:
		printerr("  FALLITO: ", msg)
		_ok = false
	return cond


func _aspetta(n: int) -> void:
	for _i in n:
		await process_frame


func _screenshot(nome: String) -> void:
	var img: Image = get_root().get_texture().get_image()
	if img == null:
		printerr("  screenshot NULLO per ", nome, " (lanciato con --headless?)")
		return
	img.save_png("%s/%s.png" % [OUT, nome])


func _n(path: String) -> Node:
	return get_root().get_node_or_null(path)
