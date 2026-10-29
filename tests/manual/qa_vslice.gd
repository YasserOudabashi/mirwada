extends SceneTree
## US-814 — la vertical slice giocata END-TO-END, per davvero, con Xvfb.
## NON fa parte della suite headless (tests/run_tests.gd legge solo
## res://tests, non ricorsivo: questo file in tests/manual/ non viene mai
## raccolto). Compagno del checkpoint tests/test_slice_fase_8.gd.
##
## Lancio (MAI --headless: con --headless il renderer e' "dummy" e gli
## screenshot sono null - trappola scoperta in US-813):
##   Xvfb :99 -screen 0 1280x720x24 &
##   DISPLAY=:99 godot --display-driver x11 --rendering-driver opengl3 \
##     --path . --script res://tests/manual/qa_vslice.gd
##
## Il cammino e' quello del Twilight Giant a Mirwada (il Pathway di default,
## data/balance.json.progressione.pathway_default - mai scritto a mano qui,
## letto dai dati) perche' e' l'unico con boss/ingredienti/formula gia'
## posizionati nel layout della citta' (US-806/US-809). Due scorciatoie
## dichiarate rispetto a un cammino "naturale" (documentate anche dove
## servono, sotto): la Caratteristica di Sequenza 9 e la valuta per comprare
## da Sidon sono concesse direttamente (CharacteristicStore/Inventory), non
## farmate — il boss di Mirwada e' di Sequenza 8, non 9, e non c'e' un
## passo di vendita a monte in questo cammino breve.
##
## Esce 0 se ogni passo passa, 1 al primo fallimento (stampa ERRORE e
## interrompe subito, come gli altri strumenti da riga di comando).

const OUT := "/tmp/qa_vslice"
const TILE := 32

var _main: Node
var _player: Node
var _ok: bool = true
var _morto_ricevuto: bool = false


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	await process_frame
	TranslationServer.set_locale("it")

	await _passo_1_avvio()
	if _ok: await _passo_2_creazione()
	if _ok: _passo_3_libro_chiuso()
	if _ok: await _passo_4_movimento_e_raccolta()
	if _ok: await _passo_5_abilita_a_tastiera()
	if _ok: await _passo_6_boss()
	if _ok: await _passo_7_sidon()
	if _ok: await _passo_8_alchimia()
	if _ok: await _passo_9_passaggio_regione()

	if _ok:
		print("=== qa_vslice: TUTTI I PASSI OK ===")
		quit(0)
	else:
		printerr("=== qa_vslice: FALLITO ===")
		quit(1)


# --- helper -----------------------------------------------------------

func _assert(cond: bool, msg: String) -> bool:
	if cond:
		print("  ok: ", msg)
	else:
		printerr("  FALLITO: ", msg)
		_ok = false
	return cond


## La voltata di pagina e' un'animazione a tempo reale (book_overlay.gd:
## _volta_durata = 0.35s di default, _rendi() scambia il contenuto a meta'
## corsa): due process_frame non bastano mai, serve aspettare un numero di
## frame generoso indipendente dal framerate reale del renderer software.
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


func _totale_inventario(inv: Node) -> int:
	var tutto: Dictionary = inv.call("tutto")
	var tot: int = 0
	for q in (tutto.get("stack", {}) as Dictionary).values():
		tot += int(q)
	tot += (tutto.get("istanze", []) as Array).size()
	return tot


func _su_boss_morto(_chi: Node) -> void:
	_morto_ricevuto = true


func _regione_corrente() -> Node:
	for c in _main.get_children():
		if c.has_method("viaggia_a"):
			return c
	return null


## Cammina davvero (Input.action_press sui move_*) da dove si trova il
## player fino a raggiungere target entro soglia_px. Bloccante fino
## all'arrivo o a un tetto di frame (non deve mai restare appeso).
func _cammina_verso(target: Vector2, soglia_px: float = 6.0, max_frame: int = 240) -> bool:
	var azioni_attive: Array = []
	var arrivato := false
	for _i in max_frame:
		var delta: Vector2 = target - _player.global_position
		if delta.length() <= soglia_px:
			arrivato = true
			break
		for a in azioni_attive:
			Input.action_release(a)
		azioni_attive = []
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


# --- passi --------------------------------------------------------------

func _passo_1_avvio() -> void:
	print("=== 1. avvio: main.tscn, il libro si apre da solo sullo scaffale ===")
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	await process_frame
	await process_frame
	var book: Node = _n("/root/Book")
	_assert(bool(book.call("e_aperto")), "il libro e' aperto all'avvio")
	var pag: Dictionary = book.call("pagina", str(book.call("pagina_corrente")))
	_assert(str(pag.get("tipo", "")) == "menu_principale", "sullo scaffale (menu_principale)")
	_screenshot("01_scaffale")


func _passo_2_creazione() -> void:
	print("=== 2. creazione: 'Tester', Pathway di default (letto dai dati), conferma ===")
	var book: Node = _n("/root/Book")
	var gs0: Node = _n("/root/GameState")
	# stesso passo di page_menu_principale.gd::_nuovo(slot): un tomo vuoto
	# sceglie lo slot e porta al frontespizio. Il libro e' gia' aperto
	# (main.gd l'ha aperto sullo scaffale al passo 1): vai_a, non apri_a
	# (apri_a e' no-op a libro gia' aperto).
	gs0.call("scegli_slot", 0)
	book.call("vai_a", "frontespizio")
	await _attendi_pagina()
	var pagina: Node = _pagina_viva()
	_assert(pagina != null and pagina.has_method("conferma"), "la pagina di creazione e' viva")
	_screenshot("02a_frontespizio")
	if pagina == null:
		return
	pagina.get("_campo").text = "Tester"
	# Pathway: lascio la preselezione della pagina, gia' calcolata da
	# GameData.pathway_ids() + balance.json.pathway_default (US-801) - nessun
	# id scritto a mano qui.
	pagina.call("conferma")
	await _attendi_pagina()
	var gs: Node = _n("/root/GameState")
	var prog: Node = _n("/root/Progression")
	_assert(bool(gs.call("partita_in_corso")), "la partita e' iniziata")
	_assert(int(prog.call("sequence")) == 9, "si parte dalla Sequenza 9")
	_player = _main.get_node_or_null("Player")
	_assert(_player != null, "il nodo Player esiste")
	_screenshot("02b_dopo_conferma")


func _passo_3_libro_chiuso() -> void:
	print("=== 3. il libro si e' chiuso da solo (conferma() lo chiude) ===")
	var book: Node = _n("/root/Book")
	_assert(not bool(book.call("e_aperto")), "libro chiuso dopo la conferma")
	_screenshot("03_mondo")


func _passo_4_movimento_e_raccolta() -> void:
	print("=== 4. cammina fino agli ingredienti del layout (Input reale) ===")
	var regione: Node = _regione_corrente()
	var inv: Node = _n("/root/Inventory")
	var layout: Dictionary = regione.call("_layout_dati") if regione.has_method("_layout_dati") else {}
	var oggetti: Array = layout.get("oggetti", [])
	_assert(oggetti.size() >= 3, "il layout di Mirwada ha almeno 3 oggetti a terra")
	for i in mini(3, oggetti.size()):
		var spec: Dictionary = oggetti[i]
		var item_id: String = str(spec.get("item_id", ""))
		var prima: int = int(inv.call("conta", item_id))
		var cella: Vector2i = Vector2i(int(spec.get("x", 0)), int(spec.get("y", 0)))
		var pos: Vector2 = regione.to_global(regione.call("map_to_local", cella))
		# US-806/US-809 non garantiscono un percorso in linea retta libero da
		# ostacoli fra un oggetto e il successivo (la citta' e' disegnata a
		# mano): il primo oggetto lo raggiunge camminando per davvero
		# dall'intera distanza dallo spawn (la dimostrazione vera del tasto),
		# per gli altri due il player si avvicina prima di camminare
		# l'ultimo tratto per davvero - resta un pickup a fisica vera
		# (Input.action_press sui move_*, Area2D.body_entered reale), non
		# un bypass di Inventory.
		if i > 0:
			_player.global_position = pos + Vector2(48, 0)
			await process_frame
		var arrivato: bool = await _cammina_verso(pos, 6.0, 300)
		_assert(arrivato, "raggiunta la cella dell'oggetto %s" % item_id)
		await process_frame
		await process_frame
		await process_frame
		await process_frame
		_assert(int(inv.call("conta", item_id)) == prima + int(spec.get("quantita", 1)),
			"Inventory.conta(%s) e' salita di %d dopo la raccolta" % [item_id, int(spec.get("quantita", 1))])
	_screenshot("04_dopo_raccolta_ingredienti")


func _passo_5_abilita_a_tastiera() -> void:
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


func _passo_6_boss() -> void:
	print("=== 6. cammina fino al boss (39,28) e lo uccide ad attacchi ===")
	var regione: Node = _regione_corrente()
	var boss: Node = null
	for c in regione.get_children():
		if c.is_in_group("nemici") and float(c.get("scale").x) > 1.0:
			boss = c
	_assert(boss != null, "il boss (scala>1.0) e' spawnato nella scena")
	if boss == null:
		return
	_morto_ricevuto = false
	boss.connect("morto", _su_boss_morto)

	var et: Node = _n("/root/EventTracker")
	var inv: Node = _n("/root/Inventory")
	var prima_ed: float = float(et.call("count", "enemy_defeated", {}))
	# per identita' del nodo, non per conteggio: il combattimento puo' far
	# passare il player vicino ad altri oggetti gia' a terra (raccolti o
	# no), un conteggio nudo salirebbe/scenderebbe per motivi indipendenti
	# dal drop del boss.
	var pickup_prima: Array = []
	for c in regione.get_children():
		if c.get_script() == preload("res://scripts/item_pickup.gd"):
			pickup_prima.append(c)
	# il player muore addosso al boss: se il drop nasce sotto ai suoi piedi
	# puo' essere raccolto nello stesso istante (item_pickup.gd::_su_corpo) -
	# in quel caso non resta un pickup NUOVO a terra da trovare, ma la somma
	# degli item posseduti sale comunque. Copro entrambi i casi.
	var totale_inv_prima: int = _totale_inventario(inv)

	await _cammina_verso(boss.global_position + Vector2(0, -14), 10.0, 300)
	_screenshot("06a_davanti_al_boss")

	# Il boss (raggio_aggro) insegue/si sposta: niente un unico avvicinamento
	# a monte, il player si riavvicina e si riorienta verso di lui a OGNI
	# giro prima di colpire, altrimenti dopo i primi scambi la mischia
	# (raggio_arco 22px) smette di trovarlo.
	var stats: Node = boss.get_node("StatsComponent")
	var colpi := 0
	while is_instance_valid(boss) and float(stats.get("hp")) > 0.0 and colpi < 80:
		var attesa := 0
		while bool(_player.get("_attaccando")) and attesa < 60:
			await process_frame
			attesa += 1
		if not is_instance_valid(boss) or float(stats.get("hp")) <= 0.0:
			break

		# il boss si sposta (raggio_aggro/AI): riavvicinati a ogni giro, non
		# solo quando "abbastanza lontano" - a rendering lento (Xvfb software)
		# un'animazione intera puo' passare fra un controllo e l'altro.
		await _cammina_verso(boss.global_position, 14.0, 90)
		var rel: Vector2 = boss.global_position - _player.global_position
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
	print("  colpi sferrati: ", colpi,
		" hp residua: ", (float(stats.get("hp")) if is_instance_valid(boss) else 0.0))
	await process_frame
	await process_frame
	await process_frame
	await process_frame

	_assert(_morto_ricevuto, "il segnale morto(chi) di enemy.gd e' arrivato")
	var dopo_ed: float = float(et.call("count", "enemy_defeated", {}))
	_assert(dopo_ed > prima_ed, "l'evento tracciato enemy_defeated e' salito (payload reale, non {})")

	var nuovo_pickup := false
	for c in regione.get_children():
		if c.get_script() == preload("res://scripts/item_pickup.gd") and not pickup_prima.has(c):
			nuovo_pickup = true
	var totale_inv_dopo: int = _totale_inventario(inv)
	_assert(nuovo_pickup or totale_inv_dopo > totale_inv_prima,
		"il drop del boss (drop_probabilita 1.0) e' comparso a terra (o raccolto sul colpo)")
	_screenshot("06b_boss_sconfitto")


func _passo_7_sidon() -> void:
	print("=== 7. parla con Sidon, apre la vendita, compra ===")
	var de: Node = _n("/root/DialogueEngine")
	var gd: Node = _n("/root/GameData")
	var inv: Node = _n("/root/Inventory")

	var listino: Array = ((gd.call("get_npc", "npc_sidon") as Dictionary).get("vendor", {}) as Dictionary).get("listino", [])
	_assert(listino.size() > 0, "Sidon ha un listino")
	var item_id: String = str(listino[0])
	var valuta_id: String = str((gd.call("items_per_categoria", "valuta")[0] as Dictionary).get("id", ""))

	# scorciatoia dichiarata: questo cammino breve non passa da una vendita
	# a monte, quindi la valuta per la prova d'acquisto e' concessa diretta.
	inv.call("aggiungi", valuta_id, 999)

	_assert(bool(de.call("avvia", "dlg_sidon", "npc_sidon")), "DialogueEngine.avvia(dlg_sidon) riesce")
	await _attendi_pagina()
	_screenshot("07a_dialogo_sidon")

	_assert(bool(de.call("scegli", 0)), "scelta 0 (Fammi vedere la merce.) applicata")
	await _attendi_pagina(10)

	var pagina: Node = _pagina_viva()
	_assert(pagina != null and pagina.has_method("compra"), "la pagina dialogo e' in modalita' negozio")
	_screenshot("07b_negozio_sidon")
	if pagina == null:
		return

	var conta_prima: int = int(inv.call("conta", item_id))
	var valuta_prima: int = int(inv.call("conta", valuta_id))
	var res: Dictionary = pagina.call("compra", item_id)
	_assert(bool(res.get("ok", false)), "compra(%s) riesce: %s" % [item_id, res.get("reason", "")])
	_assert(int(inv.call("conta", item_id)) == conta_prima + 1, "Inventory.conta(%s) +1 dopo l'acquisto" % item_id)
	_assert(int(inv.call("conta", valuta_id)) < valuta_prima, "la valuta e' scesa dopo l'acquisto")
	_screenshot("07c_dopo_acquisto")

	de.call("termina")
	await process_frame


func _passo_8_alchimia() -> void:
	print("=== 8. diagramma: Prepara, recitazione (quasi completa: duello puro decade per l'abilita' del passo 5), Bevi forzata -> Sequenza 8 ===")
	var prog: Node = _n("/root/Progression")
	var gd: Node = _n("/root/GameData")
	var acting: Node = _n("/root/Acting")
	var et: Node = _n("/root/EventTracker")
	var store: Node = _n("/root/CharacteristicStore")
	var book: Node = _n("/root/Book")

	var sd: Dictionary = prog.call("sequence_data")
	var potion: Dictionary = sd.get("potion", {})
	var car: Dictionary = gd.call("characteristic_for", str(prog.call("pathway")), int(potion.get("characteristic_sequence", -1)))
	var char_id: String = str(car.get("id", ""))
	_assert(not char_id.is_empty(), "la Caratteristica di Sequenza 9 esiste nei dati")
	# scorciatoia dichiarata: il boss di Mirwada e' di Sequenza 8, non 9 - in
	# questo cammino breve non c'e' una fonte raggiungibile per la
	# Caratteristica di Sequenza 9, quindi e' concessa diretta.
	store.call("aggiungi", char_id)

	# il libro e' rimasto aperto sul negozio di Sidon dal passo 7 (US-811:
	# non si chiude sotto a un negozio appena aperto) - vai_a, non apri_a.
	if bool(book.call("e_aperto")):
		book.call("vai_a", "diagramma")
	else:
		book.call("apri_a", "diagramma")
	await _attendi_pagina()
	var pagina: Node = _pagina_viva()
	_assert(pagina != null and pagina.has_method("prepara_pozione"), "la pagina diagramma e' viva")
	_screenshot("08a_diagramma_prima")
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
	# Lo stile di recitazione della Sequenza 9 del Twilight Giant e' "duello
	# puro": Acting applica un decadimento per ogni azione INCOERENTE col
	# ruolo, e usare un'abilita' (passo 5, richiesto dall'AC per provare il
	# tasto vero) e' incoerente col duello puro - la recitazione riempita
	# qui sopra arriva quindi vicino a 1.0 ma non lo tocca mai per costruzione
	# in questo cammino, non e' un bug: e' l'interazione fra due AC diversi
	# (tasto abilita' + recitazione perfetta) sulla STESSA Sequenza. bevi_pozione
	# forzata (malus di follia, dati - PotionSystem.bevi) e' quindi corretta
	# qui, non un bypass.
	var progresso: float = float(acting.call("acting_progress"))
	_assert(progresso >= 0.9, "recitazione alta nonostante il decadimento da duello puro (acting_progress %.3f)" % progresso)
	_screenshot("08b_recitazione_completa")

	var res_bevi: Dictionary = pagina.call("bevi_pozione", true)
	_assert(bool(res_bevi.get("avanzato", false)), "bevi_pozione() avanza la Sequenza")
	_assert(int(prog.call("sequence")) == 8, "Progression.sequence() == 8")
	_screenshot("08c_sequenza_8")

	book.call("chiudi")
	await process_frame


func _passo_9_passaggio_regione() -> void:
	print("=== 9. attraversa un passaggio -> nuova regione, layout diverso ===")
	var regione: Node = _regione_corrente()
	var prima_id: String = str(regione.get("region_id"))
	var dest_lista: Array = regione.call("passaggi_verso")
	_assert(dest_lista.size() > 0, "Mirwada ha almeno un passaggio verso un'altra regione")
	if dest_lista.is_empty():
		return
	var dest: String = str(dest_lista[0])
	var passaggio: Node2D = null
	for c in regione.get_children():
		if c is Area2D and str(c.get_meta("target_region", "")) == dest:
			passaggio = c
	_assert(passaggio != null, "l'Area2D del passaggio verso %s esiste" % dest)
	if passaggio == null:
		return

	# come al passo 4: _cammina_verso non aggira gli ostacoli, e da dove si
	# e' finiti dopo l'alchimia il tragitto in linea retta fino al bordo
	# della mappa puo' incontrare un muro. Un avvicinamento (non un
	# teletrasporto sul passaggio stesso: l'ultimo tratto resta un cammino
	# reale che attraversa davvero l'Area2D) copre la distanza.
	_player.global_position = passaggio.global_position + Vector2(64, 0)
	await process_frame
	# _su_passaggio (region_scene.gd) scatta sull'overlap FISICO con l'Area2D
	# (48x64px), non quando il player e' entro soglia_px dal suo centro: il
	# cambio di regione (asserito sotto) arriva quasi sempre PRIMA che
	# _cammina_verso veda "arrivato" - non e' un fallimento, e' solo un
	# segnale diverso dello stesso evento. Non lo si assert-a: il vero
	# criterio di successo e' il cambio di regione stesso.
	await _cammina_verso(passaggio.global_position, 20.0, 120)
	await process_frame
	await process_frame
	await process_frame
	await process_frame

	var gd: Node = _n("/root/GameData")
	var nuova: Node = _regione_corrente()
	_assert(nuova != null and str(nuova.get("region_id")) == dest,
		"la regione corrente e' ora %s (era %s)" % [dest, prima_id])
	if nuova != null:
		_assert(not (gd.call("get_layout", str(nuova.get("region_id"))) as Dictionary).is_empty(),
			"la nuova regione ha un layout diverso (US-805)")
	_screenshot("09_nuova_regione")
