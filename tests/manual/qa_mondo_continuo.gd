extends SceneTree
## US-1013 (fase 10, checkpoint) — il mondo continuo giocato per davvero con
## Xvfb: si cammina da Mirwada a una regione adiacente attraversando il
## confine SENZA alcuna schermata di caricamento (nessun
## get_tree().change_scene_to_* durante l'attraversamento - solo
## all'avvio, per caricare main.tscn), si entra ed esce da un edificio del
## villaggio (US-1011) e dalla struttura grande (US-1012). Compagno di
## tests/test_fase_10_checkpoint.gd (che prova, staticamente, che nessun
## codice del motore nomini una regione/un villaggio/un interno specifico).
##
## Lancio:
##   Xvfb :99 -screen 0 1280x720x24 &
##   DISPLAY=:99 godot --display-driver x11 --rendering-driver opengl3 \
##     --path . --script res://tests/manual/qa_mondo_continuo.gd

const OUT := "/tmp/qa_mondo_continuo"

var _main: Node
var _player: Node2D
var _mondo: Node
var _ok: bool = true


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	await process_frame
	TranslationServer.set_locale("it")

	await _passo_1_avvio()
	if _ok: await _passo_2_attraversa_il_confine_camminando()
	if _ok: await _passo_3_entra_ed_esce_dal_villaggio()
	if _ok: await _passo_4_entra_ed_esce_dalla_struttura_grande()

	if _ok:
		print("=== qa_mondo_continuo: TUTTI I PASSI OK ===")
		quit(0)
	else:
		printerr("=== qa_mondo_continuo: FALLITO ===")
		quit(1)


# --- helper -----------------------------------------------------------------

func _assert(cond: bool, msg: String) -> bool:
	if cond:
		print("  ok: ", msg)
	else:
		printerr("  FALLITO: ", msg)
		_ok = false
	return cond


func _n(path: String) -> Node:
	return get_root().get_node_or_null(path)


func _screenshot(nome: String) -> void:
	var img: Image = get_root().get_texture().get_image()
	if img == null:
		printerr("  screenshot NULLO per ", nome,
			" (lanciato con --headless? serve --display-driver x11 --rendering-driver opengl3)")
		return
	img.save_png("%s/%s.png" % [OUT, nome])
	print("  screenshot -> %s/%s.png" % [OUT, nome])


func _porta_per_interno(interno_id: String) -> Area2D:
	for c in _mondo.get_children():
		if c is Area2D and str(c.get_meta("interno_id", "")) == interno_id:
			return c
	return null


## Cammino reale verso un punto, un frame di fisica alla volta (Input reale)
## - stesso principio di tests/manual/qa_vslice_door.gd::_cammina_verso.
func _cammina_verso(target: Vector2, soglia_px: float = 8.0, max_frame: int = 240) -> bool:
	var arrivato := false
	for _i in max_frame:
		var delta: Vector2 = target - _player.global_position
		if delta.length() <= soglia_px:
			arrivato = true
			break
		var azioni: Array = []
		if delta.x > soglia_px * 0.5:
			azioni.append("move_right")
		elif delta.x < -soglia_px * 0.5:
			azioni.append("move_left")
		if delta.y > soglia_px * 0.5:
			azioni.append("move_down")
		elif delta.y < -soglia_px * 0.5:
			azioni.append("move_up")
		for a in azioni:
			Input.action_press(a)
		await get_root().get_tree().physics_frame
		for a in azioni:
			Input.action_release(a)
	await process_frame
	return arrivato


# --- passi --------------------------------------------------------------

func _passo_1_avvio() -> void:
	print("=== 1. avvio: main.tscn, creazione del personaggio ===")
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	await process_frame
	await process_frame

	var gs: Node = _n("/root/GameState")
	gs.call("scegli_slot", 0)
	var book: Node = _n("/root/Book")
	book.call("vai_a", "frontespizio")
	for _i in 40: await process_frame
	var overlay: Node = _main.get_node("BookOverlay")
	var pagina: Node = overlay.get_node("Pagina/Contenuto").get_child(0)
	_assert(pagina != null and pagina.has_method("conferma"), "la pagina di creazione e' viva")
	pagina.get("_campo").text = "QA Mondo Continuo"
	var pathway_ids: Array = pagina.get("_pathway_ids")
	(pagina.get("_pathway") as OptionButton).selected = pathway_ids.find("twilight_giant")
	pagina.call("conferma")
	for _i in 40: await process_frame

	_player = _main.get_node_or_null("Player")
	_assert(_player != null, "il nodo Player esiste")
	for c in _main.get_children():
		if c.has_method("viaggia_a"):
			_mondo = c
	_assert(_mondo != null, "il nodo del mondo continuo esiste")

	var cam: Camera2D = _player.get_node_or_null("Camera2D")
	if cam != null:
		cam.call("clear_zone_limits")
	_screenshot("01_scaffale_dopo_creazione")


## Addendum fase 10 (US-1015): i vecchi corridoi punto-a-punto sono ritirati
## - la campagna vera fuori da ogni regione e' ora terreno calpestabile, e il
## muro perimetrale di ogni regione si apre in molte brecce periodiche
## (world_scene.gd::_apri_brecce_perimetro), non piu' un solo varco a
## coordinate fisse. Qui il punto NON e' percorrere tutta la campagna, ma
## dimostrare che ATTRAVERSARE per davvero (Input reale) il confine di una
## regione non scatena mai una change_scene_to_*: un salto diretto avvicina
## il personaggio alla PRIMA breccia nota del muro est di Marche (stesso
## principio "salto diretto poi cammina l'ultimo tratto" di
## tests/manual/qa_vslice_door.gd), poi il confine stesso si attraversa
## camminando.
func _passo_2_attraversa_il_confine_camminando() -> void:
	print("=== 2. cammina attraverso il confine di Marche del Crepuscolo (Input reale, nessun caricamento) ===")
	var id_mondo_prima: int = _mondo.get_instance_id()
	var ws: Node = _n("/root/WorldState")
	_assert(str(ws.call("regione_corrente")) == "mirwada", "si parte da Mirwada")

	var gd: Node = _n("/root/GameData")
	var offset_marche: Array = (gd.call("get_region", "marche_crepuscolo") as Dictionary).get("world_offset", [0, 0])
	var mappa_marche: Array = (gd.call("get_layout", "marche_crepuscolo").get("mappa", []) as Array)
	var larghezza_marche: int = str(mappa_marche[0]).length() if not mappa_marche.is_empty() else 76

	# la prima breccia del muro est di Marche (world_scene.gd::
	# _apri_brecce_perimetro: meta=1, passo=11 -> la prima e' a y locale 2) -
	# lo stesso ruolo del vecchio aggancio_b del corridoio, ora uno fra tanti.
	var y_breccia := 2
	var punto_confine := Vector2(offset_marche[0] + larghezza_marche - 1, offset_marche[1] + y_breccia) * 32.0

	# un salto diretto fino a poco fuori dal rettangolo di Marche (nella
	# campagna vera), poi il confine si attraversa camminando.
	_player.global_position = punto_confine + Vector2(80, 0)
	await process_frame
	_screenshot("02a_appena_fuori_dal_confine_di_marche")

	var arrivato: bool = await _cammina_verso(punto_confine - Vector2(60, 0), 10.0, 300)
	_assert(arrivato, "il personaggio ha camminato attraverso il confine (Input reale)")

	_assert(str(ws.call("regione_corrente")) == "marche_crepuscolo",
		"WorldState.regione_corrente() e' ora 'marche_crepuscolo' - nessuna change_scene_to_* nel mezzo")
	_assert(_mondo.get_instance_id() == id_mondo_prima,
		"lo stesso nodo world_scene di prima - MAI liberato/ricaricato (US-1002B)")
	_assert(not _mondo.is_queued_for_deletion(), "world_scene non e' in coda per la liberazione")
	_screenshot("02b_dentro_marche_del_crepuscolo")


func _passo_3_entra_ed_esce_dal_villaggio() -> void:
	print("=== 3. entra ed esce da una capanna dell'avamposto (Valle della Madre, US-1011) ===")
	var porta: Area2D = _porta_per_interno("valle_avamposto_vedetta")
	_assert(porta != null, "la porta della capanna del vedetta esiste")
	if porta == null:
		return

	_player.global_position = porta.global_position + Vector2(0, 60)
	await process_frame
	# "arrivato" non e' affidabile qui: appena l'ingresso scatta (Input
	# reale, a meta' del ciclo) il target smette di avere senso nello
	# spazio di coordinate dell'interno - lo stesso avvertimento gia'
	# documentato in qa_vslice_door.gd::_cammina_verso. Il vero criterio
	# di successo e' il cambio di visibilita' sotto, non il valore di
	# ritorno del cammino.
	await _cammina_verso(porta.global_position, 8.0, 200)
	await process_frame
	await process_frame
	_screenshot("03a_dentro_la_capanna_del_villaggio")
	_assert(not _mondo.visible, "world_scene si nasconde entrando nella capanna")

	var interno: Node = null
	for c in _main.get_children():
		if str(c.get("interno_id")) == "valle_avamposto_vedetta":
			interno = c
	_assert(interno != null, "l'interno della capanna e' stato istanziato")
	if interno != null:
		# la porta di uscita coincide con lo spawn (interior_scene.gd::
		# _crea_uscita) e ignora il primo ingresso: ci si allontana per
		# davvero (verso l'interno della stanza, l'unica direzione libera
		# - lo spawn di una capanna e' vicino al muro sud) prima di
		# camminare indietro, altrimenti l'Area2D non vede mai un vero
		# attraversamento.
		var spawn: Vector2 = interno.call("punto_spawn")
		_player.global_position = spawn + Vector2(0, -40)
		await process_frame
		await _cammina_verso(spawn, 8.0, 90)
		await process_frame
		await process_frame
		if not _mondo.visible:
			# un solo giro non sempre basta a rientrare esattamente nella
			# piccola area di uscita: un secondo tentativo, stesso schema.
			_player.global_position = spawn + Vector2(0, -40)
			await process_frame
			await _cammina_verso(spawn, 8.0, 90)
			await process_frame
			await process_frame
	_assert(_mondo.visible, "world_scene torna visibile uscendo dalla capanna")
	_screenshot("03b_uscito_dalla_capanna")


func _passo_4_entra_ed_esce_dalla_struttura_grande() -> void:
	print("=== 4. entra ed esce dalla torre d'osservazione (Archivio Sepolto, US-1012) ===")
	# viaggia_a riposiziona il giocatore senza mai ricaricare il mondo
	# (US-1002B) - stesso meccanismo gia' provato al passo 2, qui usato
	# per raggiungere in fretta la regione della struttura grande.
	var raggiunta: bool = _mondo.call("viaggia_a", "archivio_sepolto")
	_assert(raggiunta, "viaggia_a('archivio_sepolto') riesce (nessun gating d'ingresso)")
	await process_frame

	var porta: Area2D = _porta_per_interno("archivio_torre_osservazione")
	_assert(porta != null, "la porta della torre esiste")
	if porta == null:
		return

	_player.global_position = porta.global_position + Vector2(-60, 0)
	await process_frame
	# stesso avvertimento del passo 3: "arrivato" non e' affidabile a
	# ingresso avvenuto, il vero criterio e' la visibilita' sotto.
	await _cammina_verso(porta.global_position, 8.0, 200)
	await process_frame
	await process_frame
	_screenshot("04a_dentro_la_torre")
	_assert(not _mondo.visible, "world_scene si nasconde entrando nella torre")

	var interno: Node = null
	for c in _main.get_children():
		if str(c.get("interno_id")) == "archivio_torre_osservazione":
			interno = c
	_assert(interno != null, "l'interno della torre e' stato istanziato")
	if interno != null:
		var spawn: Vector2 = interno.call("punto_spawn")
		_player.global_position = spawn + Vector2(80, 0)
		await process_frame
		await _cammina_verso(spawn, 8.0, 90)
		await process_frame
		await process_frame
		if not _mondo.visible:
			_player.global_position = spawn + Vector2(80, 0)
			await process_frame
			await _cammina_verso(spawn, 8.0, 90)
			await process_frame
			await process_frame
	_assert(_mondo.visible, "world_scene torna visibile uscendo dalla torre")
	_screenshot("04b_uscito_dalla_torre")
