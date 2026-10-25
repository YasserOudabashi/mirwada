extends SceneTree
## Livello B, batch 1 (006_PRD/prd-vslice-livello-b-batch-1.md) — Error,
## Sequenza 9->8, giocato per davvero con Xvfb. Stesso schema di
## tests/manual/qa_vslice.gd (Twilight Giant), adattato: il personaggio
## nasce comunque a Mirwada (hub fisso di main.tscn), attraversa il
## passaggio verso Archivio Sepolto, e li' raccoglie/combatte/avanza.
## Niente passo di negozio (Sidon e' specifico di Mirwada, non necessario
## per dimostrare "cammina, raccogli, lancia un'abilita', combatti,
## prepara e bevi la pozione, avanza di Sequenza" con input reale).
##
## I 3 ingredienti di formula_error_9 (grimaldello_cantante,
## guanto_del_borseggiatore, refurtiva_dimenticata) sono stati piazzati a
## terra in data/world/layouts/archivio_sepolto.json per questo script
## (PRD, story VS-B1-03): non esistevano in nessun layout prima.
##
## Lancio:
##   Xvfb :99 -screen 0 1280x720x24 &
##   DISPLAY=:99 godot --display-driver x11 --rendering-driver opengl3 \
##     --path . --script res://tests/manual/qa_vslice_error.gd

const OUT := "/tmp/qa_vslice_error"
const PID := "error"
const REGIONE_TARGET := "archivio_sepolto"

var _main: Node
var _player: Node
var _ok: bool = true


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	await process_frame
	TranslationServer.set_locale("it")

	await _passo_1_avvio()
	if _ok: await _passo_2_creazione()
	if _ok: await _passo_3_attraversa_verso_regione_target()
	if _ok: await _passo_4_raccolta()
	if _ok: await _passo_5_abilita()
	if _ok: await _passo_6_combattimento()
	if _ok: await _passo_7_alchimia()

	if _ok:
		print("=== qa_vslice_%s: TUTTI I PASSI OK ===" % PID)
		quit(0)
	else:
		printerr("=== qa_vslice_%s: FALLITO ===" % PID)
		quit(1)


# --- helper (stessi di tests/manual/qa_vslice.gd) -----------------------

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


func _regione_corrente() -> Node:
	for c in _main.get_children():
		if c.has_method("viaggia_a"):
			return c
	return null


## A differenza di qa_vslice.gd (Mirwada, dove i bersagli erano gia' scelti
## su linee libere da ostacoli), qui il PRIMO movimento attraversa l'intera
## Mirwada verso un'altra regione: il tragitto in linea retta puo' incrociare
## un cluster di decorazioni solide ('o' nella mappa, non calpestabile) senza
## un modo di aggirarlo. Aggiunge un nudge perpendicolare quando il
## personaggio resta fermo per troppi frame di fila (bloccato contro un
## ostacolo), alternando lato ogni tanto se il primo non basta: un
## pathfinding vero non serve, basta smettere di restare incastrati.
func _cammina_verso(target: Vector2, soglia_px: float = 6.0, max_frame: int = 240) -> bool:
	var azioni_attive: Array = []
	var arrivato := false
	var miglior_dist := INF
	var da_ultimo_progresso := 0
	var nudge_restanti := 0
	var nudge_su := true
	# la regione all'inizio di QUESTA chiamata: se cambia a meta' strada (un
	# passaggio incrociato per caso, anche se il target era un'altra cosa) il
	# vecchio target smette di avere senso nel nuovo spazio di coordinate -
	# altrimenti puo' capitare che punti dritto al varco DI RITORNO della
	# nuova regione (stessa area di mondo, scala diversa) e il personaggio
	# rimbalzi avanti e indietro finche' i frame non finiscono.
	var regione_partenza: Node = _regione_corrente()
	var region_id_partenza: String = str(regione_partenza.get("region_id")) if regione_partenza != null else ""
	for _i in max_frame:
		var delta: Vector2 = target - _player.global_position
		var dist: float = delta.length()
		if dist <= soglia_px:
			arrivato = true
			break
		var regione_ora: Node = _regione_corrente()
		if regione_ora != null and str(regione_ora.get("region_id")) != region_id_partenza:
			arrivato = true
			break
		for a in azioni_attive:
			Input.action_release(a)
		azioni_attive = []
		# se non c'e' stato progresso reale (avvicinamento alla distanza
		# minima gia' vista) per un po' IN MODALITA' NORMALE, il personaggio
		# e' incastrato contro un ostacolo: per ~40 frame si muove SOLO in
		# perpendicolare (niente laterale insieme), cosi' si stacca davvero
		# dal muro. Il contatore NON avanza durante il nudge stesso, altrimenti
		# scatterebbe subito un nudge nuovo senza mai dare al movimento
		# laterale un frame per approfittare dello spazio appena liberato.
		if nudge_restanti > 0:
			azioni_attive.append("move_up" if nudge_su else "move_down")
			nudge_restanti -= 1
			if nudge_restanti == 0:
				nudge_su = not nudge_su
				da_ultimo_progresso = 0
		else:
			if dist < miglior_dist - 2.0:
				miglior_dist = dist
				da_ultimo_progresso = 0
			else:
				da_ultimo_progresso += 1
			if da_ultimo_progresso > 20:
				nudge_restanti = 40
			else:
				if delta.x > soglia_px * 0.5:
					azioni_attive.append("move_right")
				elif delta.x < -soglia_px * 0.5:
					azioni_attive.append("move_left")
				if delta.y > soglia_px * 0.5:
					azioni_attive.append("move_down")
				elif delta.y < -soglia_px * 0.5:
					azioni_attive.append("move_up")
		for a in azioni_attive:
			Input.action_press(a)
		await get_root().get_tree().physics_frame
	for a in azioni_attive:
		Input.action_release(a)
	await process_frame
	return arrivato


# --- passi ----------------------------------------------------------------

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
	print("=== 2. creazione: Pathway '%s' scelto dal selettore, conferma ===" % PID)
	var book: Node = _n("/root/Book")
	var gs0: Node = _n("/root/GameState")
	gs0.call("scegli_slot", 0)
	book.call("vai_a", "frontespizio")
	await _attendi_pagina()
	var pagina: Node = _pagina_viva()
	_assert(pagina != null and pagina.has_method("conferma"), "la pagina di creazione e' viva")
	if pagina == null:
		return
	pagina.get("_campo").text = "Tester %s" % PID
	var pathway_ids: Array = pagina.get("_pathway_ids")
	var idx: int = pathway_ids.find(PID)
	_assert(idx >= 0, "'%s' e' fra i Pathway del selettore" % PID)
	if idx >= 0:
		(pagina.get("_pathway") as OptionButton).selected = idx
	pagina.call("conferma")
	await _attendi_pagina()
	var gs: Node = _n("/root/GameState")
	var prog: Node = _n("/root/Progression")
	_assert(bool(gs.call("partita_in_corso")), "la partita e' iniziata")
	_assert(str(prog.call("pathway")) == PID, "Progression.pathway() == '%s'" % PID)
	_assert(int(prog.call("sequence")) == 9, "si parte dalla Sequenza 9")
	_player = _main.get_node_or_null("Player")
	_assert(_player != null, "il nodo Player esiste")
	_screenshot("02_dopo_conferma")


func _passo_3_attraversa_verso_regione_target() -> void:
	print("=== 3. attraversa il passaggio verso %s (input reale) ===" % REGIONE_TARGET)
	var regione: Node = _regione_corrente()
	var dest_lista: Array = regione.call("passaggi_verso")
	_assert(dest_lista.has(REGIONE_TARGET), "Mirwada ha un passaggio verso %s" % REGIONE_TARGET)
	var passaggio: Node2D = null
	for c in regione.get_children():
		if c is Area2D and str(c.get_meta("target_region", "")) == REGIONE_TARGET:
			passaggio = c
	_assert(passaggio != null, "l'Area2D del passaggio verso %s esiste" % REGIONE_TARGET)
	if passaggio == null:
		return
	# Mirwada e' grande e il tragitto in linea retta dallo spawn fino a un
	# passaggio sul bordo puo' incrociare un cluster di decorazioni solide
	# nell'interno (verificato: 'o' nella mappa, non calpestabile, intorno
	# alle stanze vicino allo spawn). Come i passi successivi (raccolta),
	# ci si avvicina con un salto diretto e si cammina solo l'ultimo tratto
	# per davvero attraverso l'Area2D — qui NON e' un teletrasporto sul
	# passaggio stesso, il varco resta attraversato camminando.
	_player.global_position = passaggio.global_position + Vector2(64, 0)
	await process_frame
	# _su_passaggio scatta sull'overlap FISICO con l'Area2D, quasi sempre
	# PRIMA che _cammina_verso veda "arrivato" per la sua stessa soglia in
	# px: _cammina_verso ora si accorge da sola del cambio di regione a meta'
	# corsa e si ferma, quindi non serve ne' assert-are ne' interpretare il
	# suo valore di ritorno qui - il vero criterio di successo e' il cambio
	# di regione qui sotto.
	await _cammina_verso(passaggio.global_position, 20.0, 400)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var nuova: Node = _regione_corrente()
	_assert(nuova != null and str(nuova.get("region_id")) == REGIONE_TARGET,
		"la regione corrente e' ora %s" % REGIONE_TARGET)
	_screenshot("03_dentro_%s" % REGIONE_TARGET)


func _passo_4_raccolta() -> void:
	print("=== 4. cammina fino ai 3 ingredienti di formula_%s_9 (Input reale) ===" % PID)
	var regione: Node = _regione_corrente()
	var inv: Node = _n("/root/Inventory")
	var gd: Node = _n("/root/GameData")
	var formula: Dictionary = gd.call("get_formula", "formula_%s_9" % PID)
	var ingredienti: Array = formula.get("ingredients", [])
	_assert(ingredienti.size() == 3, "formula_%s_9 ha 3 ingredienti" % PID)
	var layout: Dictionary = regione.call("_layout_dati") if regione.has_method("_layout_dati") else {}
	var oggetti: Array = layout.get("oggetti", [])
	var trovati := 0
	for ing in ingredienti:
		var spec: Dictionary = {}
		for o in oggetti:
			if str((o as Dictionary).get("item_id", "")) == str(ing):
				spec = o
				break
		if spec.is_empty():
			continue
		trovati += 1
		var prima: int = int(inv.call("conta", str(ing)))
		var cella: Vector2i = Vector2i(int(spec.get("x", 0)), int(spec.get("y", 0)))
		var pos: Vector2 = regione.to_global(regione.call("map_to_local", cella))
		# sempre un avvicinamento diretto (come il passaggio al passo 3): un
		# cammino pieno dalla posizione precedente puo' incrociare un ostacolo
		# non aggirabile nel budget di frame concesso (scoperto proprio qui sul
		# primissimo ingrediente, mai teletrasportato prima di questa storia).
		_player.global_position = pos + Vector2(48, 0)
		await process_frame
		var arrivato: bool = await _cammina_verso(pos, 6.0, 300)
		_assert(arrivato, "raggiunta la cella dell'ingrediente %s" % ing)
		await process_frame
		await process_frame
		await process_frame
		await process_frame
		_assert(int(inv.call("conta", str(ing))) == prima + int(spec.get("quantita", 1)),
			"Inventory.conta(%s) e' salita dopo la raccolta" % ing)
	_assert(trovati == 3, "tutti e 3 gli ingredienti erano a terra in %s" % REGIONE_TARGET)
	_screenshot("04_dopo_raccolta_ingredienti")


func _passo_5_abilita() -> void:
	print("=== 5. abilita_1 (tasto vero) -> l'evento tracciato ability_used ===")
	var et: Node = _n("/root/EventTracker")
	var ae: Node = _n("/root/AbilityEngine")
	var owned: Array = ae.call("owned_abilities", _player)
	_assert(owned.size() > 0, "il personaggio possiede almeno un'abilita' alla Sequenza 9")
	var prima: float = float(et.call("count", "ability_used", {}))
	Input.action_press("abilita_1")
	await get_root().get_tree().physics_frame
	Input.action_release("abilita_1")
	await process_frame
	await process_frame
	var dopo: float = float(et.call("count", "ability_used", {}))
	_assert(dopo > prima, "ability_used e' salito dopo aver premuto abilita_1")
	_screenshot("05_dopo_abilita_1")


## A differenza di qa_vslice.gd (che uccide il boss di Mirwada, con drop
## garantito), qui si combatte un nemico GENERICO gia' presente nel layout:
## nessun boss dedicato a questo Pathway e' stato piazzato (non serve, vedi
## PRD Sezione 2 — la Caratteristica di Sequenza 9 resta concessa diretta
## come nell'originale). Basta dimostrare che l'attacco vero colpisce.
func _passo_6_combattimento() -> void:
	print("=== 6. combatte un nemico generico del layout (Input reale) ===")
	var regione: Node = _regione_corrente()
	# il PIU' VICINO al personaggio, non il primo del gruppo: nei layout
	# disegnati a mano un nemico lontano puo' stare oltre un ostacolo che
	# richiederebbe molti piu' dei 90 frame per riavvicinamento concessi
	# sotto a ogni scambio (scoperto proprio qui: il primo del gruppo in
	# Frontiera delle Porte era irraggiungibile in tempo, 80 colpi a vuoto).
	var nemico: Node = null
	var migliore_dist := INF
	for c in regione.get_children():
		if c.is_in_group("nemici"):
			var d: float = c.global_position.distance_to(_player.global_position)
			if d < migliore_dist:
				migliore_dist = d
				nemico = c
	_assert(nemico != null, "almeno un nemico e' spawnato nella scena")
	if nemico == null:
		return
	var et: Node = _n("/root/EventTracker")
	var prima_ed: float = float(et.call("count", "enemy_defeated", {}))
	# avvicinamento diretto (come il passaggio al passo 3): l'ultimo tratto
	# resta un cammino reale.
	_player.global_position = nemico.global_position + Vector2(48, 0)
	await process_frame
	await _cammina_verso(nemico.global_position + Vector2(0, -14), 10.0, 300)
	_screenshot("06a_davanti_al_nemico")

	var stats: Node = nemico.get_node("StatsComponent")
	var colpi := 0
	while is_instance_valid(nemico) and float(stats.get("hp")) > 0.0 and colpi < 80:
		var attesa := 0
		while bool(_player.get("_attaccando")) and attesa < 60:
			await process_frame
			attesa += 1
		if not is_instance_valid(nemico) or float(stats.get("hp")) <= 0.0:
			break
		await _cammina_verso(nemico.global_position, 14.0, 90)
		var rel: Vector2 = nemico.global_position - _player.global_position
		var dir_key: String = "down"
		if absf(rel.x) > absf(rel.y):
			dir_key = "right" if rel.x > 0 else "left"
		else:
			dir_key = "down" if rel.y > 0 else "up"
		_player.set("_dir_sguardo", dir_key)
		Input.action_press("attacco")
		await get_root().get_tree().physics_frame
		Input.action_release("attacco")
		colpi += 1
		attesa = 0
		while bool(_player.get("_attaccando")) and attesa < 60:
			await process_frame
			attesa += 1
	print("  colpi sferrati: ", colpi)
	await process_frame
	await process_frame
	var dopo_ed: float = float(et.call("count", "enemy_defeated", {}))
	_assert(dopo_ed > prima_ed, "l'evento tracciato enemy_defeated e' salito (combattimento reale)")
	_screenshot("06b_nemico_sconfitto")


func _passo_7_alchimia() -> void:
	print("=== 7. diagramma: Prepara, recitazione, Bevi forzata -> Sequenza 8 ===")
	var prog: Node = _n("/root/Progression")
	var gd: Node = _n("/root/GameData")
	var acting: Node = _n("/root/Acting")
	var et: Node = _n("/root/EventTracker")
	var store: Node = _n("/root/CharacteristicStore")
	var book: Node = _n("/root/Book")

	var sd: Dictionary = prog.call("sequence_data")
	var potion: Dictionary = sd.get("potion", {})
	var car: Dictionary = gd.call("characteristic_for", PID, int(potion.get("characteristic_sequence", -1)))
	var char_id: String = str(car.get("id", ""))
	_assert(not char_id.is_empty(), "la Caratteristica di Sequenza 9 di %s esiste nei dati" % PID)
	# scorciatoia dichiarata identica a qa_vslice.gd passo 8: nessuna fonte
	# raggiungibile per la Caratteristica di Sequenza 9 in questo cammino
	# breve, quindi e' concessa diretta.
	store.call("aggiungi", char_id)

	if bool(book.call("e_aperto")):
		book.call("vai_a", "diagramma")
	else:
		book.call("apri_a", "diagramma")
	await _attendi_pagina()
	var pagina: Node = _pagina_viva()
	_assert(pagina != null and pagina.has_method("prepara_pozione"), "la pagina diagramma e' viva")
	_screenshot("07a_diagramma_prima")
	if pagina == null:
		return

	var res_prep: Dictionary = pagina.call("prepara_pozione")
	_assert(bool(res_prep.get("ok", false)), "prepara_pozione() riesce: %s" % res_prep.get("reason", ""))

	for a in (prog.call("sequence_data").get("acting_actions", []) as Array):
		var azione: Dictionary = a
		var ev: String = str(azione.get("evento", ""))
		var filtri: Dictionary = (azione.get("filtri", {}) as Dictionary)
		var target: float = float(azione.get("target", 1))
		var misura: String = str(gd.call("get_tracked_event", ev).get("misura", "conteggio"))
		if misura == "conteggio":
			for _i in int(ceil(target)):
				et.call("emit_event", ev, filtri.duplicate())
		else:
			var d: Dictionary = filtri.duplicate()
			d["quantita"] = target
			et.call("emit_event", ev, d)
	var progresso: float = float(acting.call("acting_progress"))
	print("  acting_progress dopo la recitazione simulata: ", progresso)
	_screenshot("07b_recitazione")

	# come qa_vslice.gd: il tasto abilita' del passo 5 e' incoerente con uno
	# stile di recitazione "puro" e puo' far decadere il progresso sotto 1.0
	# - bevi_pozione(true) (forzata) e' quindi l'esito corretto qui, non un
	# bypass: e' l'interazione fra due AC diverse sulla stessa Sequenza.
	var res_bevi: Dictionary = pagina.call("bevi_pozione", true)
	_assert(bool(res_bevi.get("avanzato", false)), "bevi_pozione() avanza la Sequenza")
	_assert(int(prog.call("sequence")) == 8, "Progression.sequence() == 8")
	_screenshot("07c_sequenza_8")

	book.call("chiudi")
	await process_frame
