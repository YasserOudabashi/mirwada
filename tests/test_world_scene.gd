extends "res://tests/test_case.gd"
## US-1002 (fase 10, mondo continuo) — world_scene.gd sostituisce
## region_scene.gd come motore che dipinge il mondo: qui si prova il
## meccanismo in isolamento (dipintura per-regione al proprio world_offset,
## corridoio di raccordo, aggiornamento di WorldState.regione_corrente() a
## un attraversamento, viaggia_a senza ricaricare una scena). Il collegamento
## reale a main.tscn/page_mappa.gd e il ritiro di region_scene.gd (con la
## migrazione di test_layouts.gd/test_area_gate.gd/test_page_mappa.gd/
## test_main_boot.gd, che oggi testano ancora l'architettura a scena singola)
## sono US-1002B: la story si spezza qui perche' quella migrazione da sola
## tocca ~800 righe di test in un file solo (CLAUDE.md: "se superi ~200
## righe di diff la story era troppo grande, segnalalo e proponi di
## spezzarla" - segnalato in progress.txt).

const WorldScene := preload("res://scenes/world_scene.tscn")

const TILE := 32
const COL_PAVIMENTO := 0
const COL_MURO := 1
const COL_ALBERO := 6

# world_offset di data/world/regions.json (US-1001).
const OFFSET_MIRWADA := Vector2i(220, 180)
const OFFSET_MARCHE := Vector2i(0, 0)


func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")
func _ws() -> Node: return _root().get_node("WorldState")
func _pr() -> Node: return _root().get_node("Progression")


## Dimensione VERA di un layout (righe x colonne della sua mappa, US-1005:
## dimensione libera - non piu' 48x36 fisso per ogni regione).
func _dim(region_id: String) -> Vector2i:
	var mappa: Array = (_gd().call("get_layout", region_id).get("mappa", []) as Array)
	if mappa.is_empty():
		return Vector2i(48, 36)
	return Vector2i(str(mappa[0]).length(), mappa.size())


func prepara() -> void:
	_ws().call("pulisci")


## Istanzia il mondo con un Player fittizio come fratello, stesso contratto
## di main.tscn (Player e mondo sono fratelli) gia' usato da region_scene.gd.
func _istanzia_con_player() -> Dictionary:
	var cont := Node2D.new()
	_root().add_child(cont)
	var player := Node2D.new()
	player.name = "Player"
	player.add_to_group("player")
	cont.add_child(player)
	var mondo: Node = WorldScene.instantiate()
	cont.add_child(mondo)
	return {"cont": cont, "player": player, "mondo": mondo}


func test_dipinge_ogni_regione_al_proprio_offset() -> void:
	var r: Dictionary = _istanzia_con_player()
	var mondo: TileMapLayer = r["mondo"]

	# bordo esterno di Mirwada, al suo offset
	assert_eq(mondo.get_cell_atlas_coords(OFFSET_MIRWADA), Vector2i(COL_MURO, 0),
		"bordo esterno di Mirwada solido, al proprio world_offset")
	assert_eq(mondo.get_cell_atlas_coords(OFFSET_MIRWADA + Vector2i(1, 1)), Vector2i(COL_PAVIMENTO, 0),
		"cella interna di Mirwada calpestabile")

	# bordo esterno di Marche, al SUO offset (diverso da Mirwada)
	var riga_marche: int = mondo.get_cell_atlas_coords(OFFSET_MARCHE + Vector2i(1, 1)).y
	assert_eq(mondo.get_cell_atlas_coords(OFFSET_MARCHE), Vector2i(COL_MURO, riga_marche),
		"bordo esterno di Marche solido, al proprio world_offset")
	assert_eq(mondo.get_cell_atlas_coords(OFFSET_MARCHE + Vector2i(1, 1)), Vector2i(COL_PAVIMENTO, riga_marche),
		"cella interna di Marche calpestabile")
	assert_ne(riga_marche, 0, "Marche ha una palette_visiva non neutra -> riga diversa da Mirwada")

	(r["cont"] as Node2D).free()


func test_spawn_per_regione_rispetta_l_offset() -> void:
	var r: Dictionary = _istanzia_con_player()
	var mondo: TileMapLayer = r["mondo"]

	var layout_m: Dictionary = _gd().call("get_layout", "mirwada")
	var sp: Array = layout_m.get("spawn", [4, 4])
	var atteso: Vector2 = mondo.to_global(mondo.map_to_local(OFFSET_MIRWADA + Vector2i(int(sp[0]), int(sp[1]))))
	assert_eq(mondo.call("punto_spawn", "mirwada"), atteso, "punto_spawn('mirwada') usa il world_offset")

	var layout_march: Dictionary = _gd().call("get_layout", "marche_crepuscolo")
	var sp2: Array = layout_march.get("spawn", [4, 4])
	var atteso2: Vector2 = mondo.to_global(mondo.map_to_local(OFFSET_MARCHE + Vector2i(int(sp2[0]), int(sp2[1]))))
	assert_eq(mondo.call("punto_spawn", "marche_crepuscolo"), atteso2, "punto_spawn('marche_crepuscolo') usa il proprio world_offset")
	assert_ne(atteso, atteso2, "due regioni diverse hanno uno spawn diverso nel mondo continuo")

	(r["cont"] as Node2D).free()


## punto_spawn() senza argomenti usa WorldState.regione_corrente() - stesso
## contratto che player.gd::_respawn() gia' chiama a zero argomenti.
func test_punto_spawn_senza_argomenti_usa_la_regione_corrente() -> void:
	var r: Dictionary = _istanzia_con_player()
	var mondo: TileMapLayer = r["mondo"]

	_ws().call("entra_regione", "marche_crepuscolo")
	assert_eq(mondo.call("punto_spawn"), mondo.call("punto_spawn", "marche_crepuscolo"),
		"punto_spawn() a vuoto risolve sulla regione corrente")

	(r["cont"] as Node2D).free()


func test_confine_di_regione_aggiorna_worldstate() -> void:
	var r: Dictionary = _istanzia_con_player()
	var mondo: Node = r["mondo"]
	var player: Node = r["player"]

	# stesso pattern gia' in uso nel resto del progetto per i test headless:
	# si chiama l'handler direttamente invece di aspettare la fisica reale
	# (Area2D.body_entered non e' affidabile in un test senza frame fisici).
	mondo.call("_su_ingresso_regione", player, "mirwada")
	assert_eq(str(_ws().call("regione_corrente")), "mirwada", "attraversare il confine registra la regione")
	mondo.call("_su_ingresso_regione", player, "marche_crepuscolo")
	assert_eq(str(_ws().call("regione_corrente")), "marche_crepuscolo",
		"un secondo attraversamento aggiorna la regione, senza ricaricare nulla")

	(r["cont"] as Node2D).free()


func test_confine_ignora_corpi_che_non_sono_il_player() -> void:
	var r: Dictionary = _istanzia_con_player()
	var mondo: Node = r["mondo"]
	_ws().call("entra_regione", "marche_crepuscolo")

	var estraneo := Node2D.new()
	mondo.call("_su_ingresso_regione", estraneo, "mirwada")
	assert_eq(str(_ws().call("regione_corrente")), "marche_crepuscolo",
		"un corpo che non e' nel gruppo 'player' non sposta la regione corrente")
	estraneo.free()

	(r["cont"] as Node2D).free()


func _offset_regione(rid: String) -> Vector2i:
	var wo: Array = (_gd().call("get_region", rid) as Dictionary).get("world_offset", [0, 0])
	return Vector2i(int(wo[0]), int(wo[1]))


## Addendum fase 10 (US-1015): i vecchi corridoi punto-a-punto (un solo
## varco a coordinate fisse fra due regioni scelte a mano) sono ritirati -
## feedback diretto dell'utente: da fuori si vedevano rettangoli isolati
## uniti da un ponte, non un mondo unico. Sostituiti da due meccanismi
## generici, provati qui: (1) _riempi_campagna dipinge di terreno vero
## OGNI cella condivisa fuori da ogni regione (non piu' vuoto); (2)
## _apri_brecce_perimetro smette di trattare il muro di ogni layout come
## una scatola sigillata, aprendolo a intervalli su tutti e 4 i lati.
## Nessuna coppia di regioni hardcoded: si scandisce il muro vero cercando
## un varco, qualunque regione esista.
func _lato_ha_una_breccia(mondo: TileMapLayer, offset: Vector2i, dim: Vector2i, orizzontale: bool, fisso: int) -> bool:
	var lunghezza: int = dim.x if orizzontale else dim.y
	for i in range(1, lunghezza - 1):
		var cella: Vector2i = offset + (Vector2i(i, fisso) if orizzontale else Vector2i(fisso, i))
		if mondo.get_cell_atlas_coords(cella).x == COL_PAVIMENTO:
			return true
	return false


func test_il_perimetro_di_ogni_regione_ha_almeno_una_breccia_per_lato() -> void:
	var r: Dictionary = _istanzia_con_player()
	var mondo: TileMapLayer = r["mondo"]
	for reg in (_gd().call("get_regions") as Array):
		var rid: String = str((reg as Dictionary).get("id", ""))
		var offset: Vector2i = _offset_regione(rid)
		var dim: Vector2i = _dim(rid)
		assert_true(_lato_ha_una_breccia(mondo, offset, dim, true, 0), "%s: il lato nord ha una breccia" % rid)
		assert_true(_lato_ha_una_breccia(mondo, offset, dim, true, dim.y - 1), "%s: il lato sud ha una breccia" % rid)
		assert_true(_lato_ha_una_breccia(mondo, offset, dim, false, 0), "%s: il lato ovest ha una breccia" % rid)
		assert_true(_lato_ha_una_breccia(mondo, offset, dim, false, dim.x - 1), "%s: il lato est ha una breccia" % rid)
	(r["cont"] as Node2D).free()


## La campagna (lo spazio comune fuori dal rettangolo di ogni regione) e'
## terreno vero, non piu' vuoto: si prova appena fuori dal muro nord di
## Mirwada, gia' bucato da una breccia (test sopra) - deve essere dipinta
## (pavimento o un albero sparso), mai una cella senza tile.
func test_la_campagna_fuori_da_ogni_regione_e_terreno_vero() -> void:
	var r: Dictionary = _istanzia_con_player()
	var mondo: TileMapLayer = r["mondo"]
	var offset: Vector2i = _offset_regione("mirwada")
	var fuori: Vector2i = offset + Vector2i(2, -3)
	var col: int = mondo.get_cell_atlas_coords(fuori).x
	assert_true(col == COL_PAVIMENTO or col == COL_ALBERO,
		"la campagna fuori da mirwada e' terreno dipinto (pavimento o albero), non vuoto")
	(r["cont"] as Node2D).free()


## Il popolamento della campagna (data/world/campagna.json, coordinate
## assolute, offset Vector2i.ZERO): almeno un nemico dichiarato spawna alla
## posizione globale giusta, stesso principio gia' provato per i nemici di
## una regione (test_nemici_di_mirwada_spawnano_alla_posizione_globale_giusta).
func test_un_nemico_della_campagna_spawna_alla_posizione_giusta() -> void:
	var r: Dictionary = _istanzia_con_player()
	var mondo: TileMapLayer = r["mondo"]
	var campagna: Dictionary = _gd().call("get_campagna")
	var nemici: Array = (campagna.get("nemici", []) as Array)
	assert_true(nemici.size() > 0, "la campagna ha nemici dichiarati")
	if nemici.is_empty():
		(r["cont"] as Node2D).free()
		return
	var spec: Dictionary = nemici[0] as Dictionary
	var atteso: Vector2 = mondo.to_global(mondo.map_to_local(Vector2i(int(spec["x"]), int(spec["y"]))))
	var trovato := false
	for c in mondo.get_children():
		if c.is_in_group("nemici") and (c as Node2D).global_position.distance_to(atteso) < 1.0:
			trovato = true
			break
	assert_true(trovato, "il primo nemico della campagna e' istanziato alla cella dichiarata")
	(r["cont"] as Node2D).free()


## US-1008 (AC "il gating d'ingresso ... si applica come barriera fisica al
## confine, non piu' come rifiuto di caricamento"): il meccanismo e' generico
## e gia' esisteva (_crea_gate, richiamato per OGNI regione da _prepara_regione
## - US-1002/US-1006/US-1007 lo hanno gia' attraversato senza test dedicato).
## Qui si prova per la prima volta che il Gate_ dell'Archivio (conoscenza:
## testi_ordine_minore) esiste per davvero nel mondo continuo, e' chiuso senza
## il flag e si apre quando KnowledgeStore lo registra - la stessa AreaGate
## gia' provata a livello di dialogo in test_dialoghi_roster.gd, qui verificata
## viva dentro world_scene.
func test_gate_dell_archivio_e_una_barriera_fisica_nel_mondo_continuo() -> void:
	var r: Dictionary = _istanzia_con_player()
	var mondo: TileMapLayer = r["mondo"]
	var ks: Node = _root().get_node("KnowledgeStore")
	ks.call("dimentica_tutto")

	var gate: Area2D = mondo.get_node_or_null("Gate_archivio_sepolto_ali_interne")
	assert_true(gate != null, "il Gate dell'Archivio esiste nel mondo continuo")
	if gate == null:
		(r["cont"] as Node2D).free()
		return
	assert_false(bool(gate.call("e_aperto")), "senza il flag, l'ala interna resta chiusa")

	ks.call("impara", "testi_ordine_minore")
	assert_true(bool(gate.call("e_aperto")), "col flag, l'ala interna si apre")

	(r["cont"] as Node2D).free()


## US-1009 (AC "il gating d'ingresso della regione si applica come barriera
## fisica al confine, non piu' come rifiuto di caricamento - verificato che
## un personaggio sotto soglia viene fermato fisicamente e uno sopra soglia
## passa"): la Frontiera e' la PRIMA regione con un gating area=="ingresso"
## (chiude l'intera regione, non un'ala interna come l'Archivio) - lo stesso
## meccanismo generico di _crea_gate copre anche questo caso (nessuna
## modifica al codice: e' proprio il punto della story), qui verificato per
## la prima volta con la StaticBody2D viva dentro world_scene invece che
## solo a livello di dato (test_area_gate.gd) o di fast travel
## (test_page_mappa.gd::test_viaggia_a_rispetta_il_gating_d_ingresso).
func test_gate_ingresso_della_frontiera_e_una_barriera_fisica_nel_mondo_continuo() -> void:
	var r: Dictionary = _istanzia_con_player()
	var mondo: TileMapLayer = r["mondo"]

	var gate: Area2D = mondo.get_node_or_null("Gate_frontiera_porte_ingresso")
	assert_true(gate != null, "il Gate d'ingresso della Frontiera esiste nel mondo continuo")
	if gate == null:
		(r["cont"] as Node2D).free()
		return

	_pr().call("configura", "twilight_giant", 2)   # "sopra" la Sequenza 4: respinto
	assert_false(bool(gate.call("e_aperto")), "Sequenza 2 (alta) e' fermata: il gate (e la sua StaticBody2D, US-611) resta chiuso")

	_pr().call("configura", "twilight_giant", 9)   # sotto soglia: passa
	assert_true(bool(gate.call("e_aperto")), "Sequenza 9 (bassa) passa: il gate si apre")

	(r["cont"] as Node2D).free()


func test_viaggia_a_riposiziona_senza_ricaricare_nulla() -> void:
	var r: Dictionary = _istanzia_con_player()
	var mondo: Node = r["mondo"]
	var player: Node2D = r["player"]

	var ok: bool = mondo.call("viaggia_a", "marche_crepuscolo")
	assert_true(ok, "viaggia_a riesce verso una regione senza gating d'ingresso")
	assert_eq(player.global_position, mondo.call("punto_spawn", "marche_crepuscolo"),
		"il player e' alla cella di spawn della regione target")
	assert_false(mondo.is_queued_for_deletion(), "il mondo NON viene ricaricato: stesso nodo di prima")

	(r["cont"] as Node2D).free()


func test_viaggia_a_verso_una_regione_inesistente_fallisce() -> void:
	var r: Dictionary = _istanzia_con_player()
	var mondo: Node = r["mondo"]
	assert_false(bool(mondo.call("viaggia_a", "nonesiste")), "id inesistente -> false, nessun crash")
	(r["cont"] as Node2D).free()


## Nemici/oggetti del layout di Mirwada continuano a spawnare correttamente
## nel mondo continuo, alla posizione GLOBALE giusta (offset incluso) -
## stessa attesa gia' provata per region_scene.gd in test_layouts.gd.
func test_nemici_di_mirwada_spawnano_alla_posizione_globale_giusta() -> void:
	var r: Dictionary = _istanzia_con_player()
	var mondo: Node = r["mondo"]

	# il mondo continuo ospita i nemici di TUTTE e 5 le regioni nello stesso
	# nodo: si filtrano quelli dentro il rettangolo di Mirwada (offset
	# incluso), non semplicemente "ogni nemico in scena".
	var rett := Rect2(Vector2(OFFSET_MIRWADA) * TILE, Vector2(_dim("mirwada")) * TILE)
	var nemici_mirwada: Array = []
	var totale: int = 0
	for c in mondo.get_children():
		if not c.is_in_group("nemici"):
			continue
		totale += 1
		if rett.has_point(c.global_position):
			nemici_mirwada.append(c)
	assert_eq(nemici_mirwada.size(), 7, "6 nemici di Sequenza 9 + 1 boss dal layout di Mirwada")
	# 7 nemici per ognuna delle 5 regioni + i nemici sparsi della campagna
	# (addendum US-1015, data/world/campagna.json), tutti nello stesso mondo
	# continuo - il conteggio della campagna si legge dai dati, non a mano.
	var attesi_campagna: int = ((_gd().call("get_campagna") as Dictionary).get("nemici", []) as Array).size()
	assert_eq(totale, 35 + attesi_campagna, "7 nemici per regione + i nemici della campagna")

	(r["cont"] as Node2D).free()


## US-1003 (fase 10, prestazioni): con 5 regioni vive nello stesso nodo,
## nemici/NPC fuori dal raggio (data/balance.json [mondo.raggio_attivo_entita],
## non hardcoded) vengono disattivati (process_mode = DISABLED, il
## meccanismo nativo di Godot - ferma script E fisica del sotto-albero) -
## quelli dentro il raggio restano esattamente come sempre (PROCESS_MODE_
## INHERIT, il default). Il player fittizio di _istanzia_con_player() resta
## alla sua posizione di default (0,0): dentro Marche del Crepuscolo
## (offset [0,0]), abbastanza lontano da ogni nemico di Mirwada (offset
## [220,180], >7000px) da provare entrambi i casi con gli stessi dati veri.
func test_nemici_vicini_restano_attivi_e_lontani_si_disattivano() -> void:
	var r: Dictionary = _istanzia_con_player()
	var mondo: Node = r["mondo"]
	var player: Node2D = r["player"]

	mondo.call("_aggiorna_prestazioni")

	var raggio: float = float((_gd().call("get_balance", "mondo") as Dictionary).get("raggio_attivo_entita", 600.0))
	var trovato_vicino := false
	var trovato_lontano := false
	for e in mondo.get_tree().get_nodes_in_group("nemici"):
		var dist: float = (e as Node2D).global_position.distance_to(player.global_position)
		if dist <= raggio:
			assert_eq(int((e as Node).process_mode), int(Node.PROCESS_MODE_INHERIT),
				"nemico a %.0fpx (dentro il raggio %.0f) resta attivo" % [dist, raggio])
			trovato_vicino = true
		else:
			assert_eq(int((e as Node).process_mode), int(Node.PROCESS_MODE_DISABLED),
				"nemico a %.0fpx (fuori dal raggio %.0f) e' disattivato" % [dist, raggio])
			trovato_lontano = true
	assert_true(trovato_vicino, "il player ha almeno un nemico dentro il raggio")
	assert_true(trovato_lontano, "il player ha almeno un nemico fuori dal raggio")

	(r["cont"] as Node2D).free()


## Stesso meccanismo per gli NPC (Area2D con meta "npc_id", world_scene.gd::
## _crea_un_npc) - non sono un sistema separato, la stessa _aggiorna_prestazioni
## li tratta allo stesso modo. Gli NPC di roster.json stanno quasi tutti a
## Mirwada: invece di sperare che il player di default ne trovi uno per caso
## dentro/fuori raggio (dipenderebbe dal layout), lo si sposta esplicitamente
## sul primo NPC trovato e poi lontano, come per il nemico di riattivazione.
func test_npc_vicini_restano_attivi_e_lontani_si_disattivano() -> void:
	var r: Dictionary = _istanzia_con_player()
	var mondo: Node = r["mondo"]
	var player: Node2D = r["player"]

	var npc: Node2D = null
	for c in mondo.get_children():
		if c is Area2D and c.has_meta("npc_id"):
			npc = c as Node2D
			break
	assert_true(npc != null, "esiste almeno un npc da usare per la prova")
	if npc == null:
		(r["cont"] as Node2D).free()
		return

	player.global_position = npc.global_position
	mondo.call("_aggiorna_prestazioni")
	assert_eq(int((npc as Node).process_mode), int(Node.PROCESS_MODE_INHERIT),
		"il player e' sull'npc: resta attivo")

	player.global_position = npc.global_position + Vector2(100000, 100000)
	mondo.call("_aggiorna_prestazioni")
	assert_eq(int((npc as Node).process_mode), int(Node.PROCESS_MODE_DISABLED),
		"il player si e' allontanato molto: l'npc si disattiva")

	(r["cont"] as Node2D).free()


## Riavvicinandosi un nemico disattivato torna attivo - non e' uno stato
## permanente deciso allo spawn, si rivaluta ad ogni tick (qui: chiamato a
## mano, senza aspettare il Timer reale).
func test_riavvicinandosi_un_nemico_disattivato_si_riattiva() -> void:
	var r: Dictionary = _istanzia_con_player()
	var mondo: Node = r["mondo"]
	var player: Node2D = r["player"]

	mondo.call("_aggiorna_prestazioni")
	var rett_mirwada := Rect2(Vector2(OFFSET_MIRWADA) * TILE, Vector2(_dim("mirwada")) * TILE)
	var nemico_lontano: Node2D = null
	for e in mondo.get_tree().get_nodes_in_group("nemici"):
		if rett_mirwada.has_point((e as Node2D).global_position):
			nemico_lontano = e as Node2D
			break
	assert_true(nemico_lontano != null, "esiste un nemico di Mirwada da usare per la prova")
	if nemico_lontano == null:
		(r["cont"] as Node2D).free()
		return
	assert_eq(int((nemico_lontano as Node).process_mode), int(Node.PROCESS_MODE_DISABLED),
		"partenza: il nemico di Mirwada e' disattivato, il player e' a Marche")

	player.global_position = nemico_lontano.global_position
	mondo.call("_aggiorna_prestazioni")
	assert_eq(int((nemico_lontano as Node).process_mode), int(Node.PROCESS_MODE_INHERIT),
		"il player si e' avvicinato: lo stesso nemico torna attivo")

	(r["cont"] as Node2D).free()


## US-1010 (fase 10, Blocco B): entrare in un edificio carica il suo interno
## SENZA mai liberare il mondo persistente (world_scene.gd si nasconde e si
## ferma, l'invariante di US-1002B resta valida) - provato sul primo
## edificio davvero visitabile (il sotterraneo di Mirwada, gia' disegnato
## cosmeticamente in US-1005, ora referenziato da un vero data/world/
## interni/mirwada_sotterraneo.json).
##
## I test chiamano _entra_edificio/_esci_edificio DIRETTAMENTE (non i
## wrapper _su_porta_edificio/_su_uscita_edificio, che le schedulano con
## call_deferred() - necessario per la fisica reale, scoperto con Xvfb:
## Godot vieta di disabilitare un CollisionObject2D dentro il callback di
## fisica che ci porta li'). Stesso principio gia' in uso nel resto della
## suite: si chiama l'handler/la logica direttamente invece di dipendere
## dal timing della fisica o, qui, di call_deferred().
const InteriorScript := preload("res://scripts/interior_scene.gd")


## Cerca la porta per interno_id (meta, world_scene.gd::_crea_edifici) invece
## che per nome esatto del nodo - il nome include l'indice nell'array
## edifici[], che cambia se altre story ne aggiungono altri prima o dopo.
func _porta_per_interno(mondo: Node, interno_id: String) -> Area2D:
	for c in mondo.get_children():
		if c is Area2D and str(c.get_meta("interno_id", "")) == interno_id:
			return c
	return null


func _porta_sotterraneo(mondo: Node) -> Area2D:
	return _porta_per_interno(mondo, "mirwada_sotterraneo")


func test_edificio_mirwada_sotterraneo_ha_una_porta() -> void:
	var r: Dictionary = _istanzia_con_player()
	var porta: Area2D = _porta_sotterraneo(r["mondo"])
	assert_false(porta == null, "la porta del sotterraneo di Mirwada esiste in scena")
	(r["cont"] as Node2D).free()


func test_entrare_in_un_edificio_carica_l_interno_senza_liberare_il_mondo() -> void:
	var r: Dictionary = _istanzia_con_player()
	var cont: Node2D = r["cont"]
	var mondo: Node = r["mondo"]
	var player: Node2D = r["player"]
	var porta: Area2D = _porta_sotterraneo(mondo)
	assert_false(porta == null, "la porta esiste")
	if porta == null:
		cont.free()
		return

	mondo.call("_entra_edificio", porta)

	assert_false(mondo.visible, "world_scene si nasconde mentre si e' dentro")
	assert_eq(int(mondo.process_mode), int(Node.PROCESS_MODE_DISABLED),
		"world_scene si ferma mentre si e' dentro")
	assert_false(mondo.is_queued_for_deletion(), "world_scene NON viene mai liberato (US-1002B)")

	var interno: Node = null
	for c in cont.get_children():
		if c.get_script() == InteriorScript:
			interno = c
	assert_false(interno == null, "l'interno e' stato istanziato come fratello del mondo")
	if interno != null:
		assert_eq(str(interno.get("interno_id")), "mirwada_sotterraneo", "e' l'interno giusto")
		assert_eq(player.global_position, interno.call("punto_spawn"),
			"il player e' alla cella di spawn dell'interno")

	cont.free()


func test_uscire_dall_edificio_ripristina_il_mondo_alla_porta() -> void:
	var r: Dictionary = _istanzia_con_player()
	var cont: Node2D = r["cont"]
	var mondo: Node = r["mondo"]
	var player: Node2D = r["player"]
	var porta: Area2D = _porta_sotterraneo(mondo)
	assert_false(porta == null, "la porta esiste")
	if porta == null:
		cont.free()
		return

	mondo.call("_entra_edificio", porta)
	mondo.call("_esci_edificio")

	assert_true(mondo.visible, "world_scene torna visibile uscendo")
	assert_eq(int(mondo.process_mode), int(Node.PROCESS_MODE_INHERIT), "world_scene torna attivo uscendo")
	assert_eq(player.global_position, porta.global_position, "il player torna alla cella della porta")

	var interno_ancora_in_scena := false
	for c in cont.get_children():
		if c.get_script() == InteriorScript and not c.is_queued_for_deletion():
			interno_ancora_in_scena = true
	assert_false(interno_ancora_in_scena, "l'interno e' stato liberato all'uscita")

	cont.free()


## Rientrare nella stessa porta subito dopo essere usciti non deve ri-aprire
## l'interno all'istante: _esci_edificio marca la porta ("ignora_prossimo_
## ingresso"), _su_porta_edificio la consuma senza schedulare un nuovo
## ingresso - solo il secondo, genuino tentativo funziona. Qui si prova la
## logica della guardia stessa (sul wrapper _su_porta_edificio, dove vive);
## il secondo ingresso genuino e' provato chiamando _entra_edificio in
## isolamento (stesso principio del resto della suite, non si dipende dal
## timing reale di call_deferred()).
func test_rientrare_subito_dopo_l_uscita_non_riapre_l_interno() -> void:
	var r: Dictionary = _istanzia_con_player()
	var cont: Node2D = r["cont"]
	var mondo: Node = r["mondo"]
	var player: Node2D = r["player"]
	var porta: Area2D = _porta_sotterraneo(mondo)
	assert_false(porta == null, "la porta esiste")
	if porta == null:
		cont.free()
		return

	mondo.call("_entra_edificio", porta)
	mondo.call("_esci_edificio")
	assert_true(bool(porta.get_meta("ignora_prossimo_ingresso", false)),
		"uscire marca la porta per ignorare il prossimo ingresso spurio")

	mondo.call("_su_porta_edificio", player, porta)
	assert_false(bool(porta.get_meta("ignora_prossimo_ingresso", false)),
		"il flag e' stato consumato dal primo re-ingresso spurio")
	assert_true(mondo.visible, "quel primo re-ingresso spurio non ha aperto nulla")

	mondo.call("_entra_edificio", porta)
	assert_false(mondo.visible, "un secondo ingresso vero funziona normalmente")

	cont.free()


## US-1005B: i 3 edifici promessi dall'AC originale di US-1005 (casa di
## Lena, archivio di Ottavia, bettola del porto), usando lo stesso motore
## generico gia' provato sul sotterraneo - una porta a testa, un interno
## vero con un elemento riconoscibile (un oggetto coerente col personaggio/
## luogo), zero codice dedicato oltre ai dati.
func test_i_3_edifici_di_us1005b_hanno_una_porta_e_un_interno_vero() -> void:
	var r: Dictionary = _istanzia_con_player()
	var cont: Node2D = r["cont"]
	var mondo: Node = r["mondo"]
	var gd: Node = _gd()

	var attesi := {
		"mirwada_casa_di_lena": "trottola_di_legno_intagliata",
		"mirwada_archivio_ottavia": "libro_ordine_minore",
		"mirwada_bettola_del_porto": "boccale_dei_contrabbandieri",
	}
	for iid in attesi:
		var porta: Area2D = _porta_per_interno(mondo, iid)
		assert_false(porta == null, "la porta di '%s' esiste in scena" % iid)

		var interno: Dictionary = gd.call("get_interno", iid)
		assert_false(interno.is_empty(), "'%s' risolve a un interno vero nei dati" % iid)
		var item_atteso: String = attesi[iid]
		var trovato := false
		for o in (interno.get("oggetti", []) as Array):
			if str((o as Dictionary).get("item_id", "")) == item_atteso:
				trovato = true
		assert_true(trovato, "'%s' contiene davvero '%s' (non uno stub vuoto)" % [iid, item_atteso])

	cont.free()


## L'archivio di Ottavia (US-1005B AC #3): la porta gia' disegnata in
## US-1005 come struttura murata cosmetica punta ora a un interno vero -
## stessa porta, stessa posizione, comportamento diverso.
func test_porta_dell_archivio_e_quella_gia_disegnata_in_us1005() -> void:
	var r: Dictionary = _istanzia_con_player()
	var mondo: Node = r["mondo"]
	var porta: Area2D = _porta_per_interno(mondo, "mirwada_archivio_ottavia")
	assert_false(porta == null, "la porta dell'archivio esiste")
	if porta != null:
		var rect: Array = (_gd().call("get_layout", "mirwada").get("zone", {}) as Dictionary).get("archivio", [])
		var origine: Vector2 = mondo.map_to_local(OFFSET_MIRWADA)
		var dentro_zona_archivio: bool = (
			porta.position.x >= origine.x + rect[0] * TILE and
			porta.position.x <= origine.x + (rect[0] + rect[2]) * TILE and
			porta.position.y >= origine.y + rect[1] * TILE and
			porta.position.y <= origine.y + (rect[1] + rect[3]) * TILE)
		assert_true(dentro_zona_archivio, "la porta e' dentro il rettangolo della zona 'archivio'")
	(r["cont"] as Node2D).free()


## US-1011 (fase 10, "il primo villaggio vero"): l'avamposto della sorgente
## in Valle della Madre, 4 capanne usando lo STESSO motore generico di
## US-1010/US-1005B (edifici[] + data/world/interni/*.json) - zero codice
## dedicato al villaggio, solo dati. Nessuna nuova voce nel vocabolario
## chiuso location_tags.json e' servita: un edificio non e' legato a un
## location_tag (US-1010), quindi le 4 capanne vivono semplicemente dentro
## il rettangolo gia' esistente della zona "sorgente" senza bisogno di un
## tag "villaggio" dedicato - stessa decisione presa (e qui dichiarata
## esplicitamente, come richiede l'AC) per il sotterraneo/le case di
## Mirwada in fase 10 Blocco B.
func test_le_4_capanne_dell_avamposto_di_valle_hanno_una_porta_e_un_interno_vero() -> void:
	var r: Dictionary = _istanzia_con_player()
	var cont: Node2D = r["cont"]
	var mondo: Node = r["mondo"]
	var gd: Node = _gd()

	var attesi := {
		"valle_avamposto_vedetta": "corno_da_richiamo_intagliato",
		"valle_avamposto_deposito": "cesto_di_vimini_intrecciato",
		"valle_avamposto_focolare": "campanaccio_di_capra_smarrita",
		"valle_avamposto_erborista": "quaderno_di_appunti_sulle_maree",
	}
	for iid in attesi:
		var porta: Area2D = _porta_per_interno(mondo, iid)
		assert_false(porta == null, "la porta di '%s' esiste in scena" % iid)

		var interno: Dictionary = gd.call("get_interno", iid)
		assert_false(interno.is_empty(), "'%s' risolve a un interno vero nei dati" % iid)
		var item_atteso: String = attesi[iid]
		var trovato := false
		for o in (interno.get("oggetti", []) as Array):
			if str((o as Dictionary).get("item_id", "")) == item_atteso:
				trovato = true
		assert_true(trovato, "'%s' contiene davvero '%s' (non uno stub vuoto)" % [iid, item_atteso])

	cont.free()


## AC "si entra ed esce da almeno 2 edifici diversi nello stesso villaggio":
## qui con lo stesso meccanismo diretto (_entra_edificio/_esci_edificio, non
## i wrapper con call_deferred()) gia' usato per il sotterraneo di Mirwada -
## provato su 2 capanne diverse, non solo una, per coprire davvero l'AC.
func test_si_entra_ed_esce_da_almeno_2_capanne_dell_avamposto() -> void:
	var r: Dictionary = _istanzia_con_player()
	var cont: Node2D = r["cont"]
	var mondo: Node = r["mondo"]
	var player: Node2D = r["player"]

	for iid in ["valle_avamposto_vedetta", "valle_avamposto_deposito"]:
		var porta: Area2D = _porta_per_interno(mondo, iid)
		assert_false(porta == null, "la porta di '%s' esiste" % iid)
		if porta == null:
			continue

		mondo.call("_entra_edificio", porta)
		assert_false(mondo.visible, "world_scene si nasconde entrando in '%s'" % iid)
		var interno: Node = null
		for c in cont.get_children():
			if c.get_script() == InteriorScript:
				interno = c
		assert_false(interno == null, "l'interno di '%s' e' stato istanziato" % iid)

		mondo.call("_esci_edificio")
		assert_true(mondo.visible, "world_scene torna visibile uscendo da '%s'" % iid)
		assert_eq(player.global_position, porta.global_position,
			"il player torna alla porta di '%s' uscendo" % iid)

	cont.free()


## US-1012 (fase 10, "la prima struttura grande"): la torre d'osservazione
## dell'Archivio Sepolto - stesso motore di edificio di US-1010, ma
## l'interno referenziato (data/world/interni/archivio_torre_osservazione.
## json) e' un layout a 3 stanze collegate da corridoi NELLA STESSA mappa
## (nessuna catena di caricamenti aggiuntivi: interior_scene.gd non sa
## nulla di "stanze", disegna semplicemente un layout piu' grande del
## solito). Nessuna nuova voce in location_tags.json e' servita: la torre
## vive dentro il rettangolo gia' esistente della zona
## "torre_di_osservazione" (data/world/layouts/archivio_sepolto.json.zone),
## stessa decisione di US-1010/US-1005B/US-1011.
func test_torre_di_osservazione_ha_una_porta_e_un_interno_a_3_stanze() -> void:
	var r: Dictionary = _istanzia_con_player()
	var cont: Node2D = r["cont"]
	var mondo: Node = r["mondo"]
	var gd: Node = _gd()

	var porta: Area2D = _porta_per_interno(mondo, "archivio_torre_osservazione")
	assert_false(porta == null, "la porta della torre esiste in scena")

	var interno: Dictionary = gd.call("get_interno", "archivio_torre_osservazione")
	assert_false(interno.is_empty(), "l'interno della torre risolve a un layout vero")
	if interno.is_empty():
		cont.free()
		return

	var mappa: Array = (interno.get("mappa", []) as Array)
	# le 3 sale (basamento, biblioteca astrale, osservatorio) e i 2 corridoi
	# che le collegano, tutti sulla riga y=5 dello stesso file - nessuna
	# porta esterna aggiuntiva, nessun'altra scena da caricare.
	for x in [3, 8, 13, 17, 22]:
		var riga: String = str(mappa[5])
		assert_eq(riga[x], ".", "cella (%d,5) calpestabile: le 3 sale sono collegate nella stessa mappa" % x)

	var nemici: Array = (interno.get("nemici", []) as Array)
	var oggetti: Array = (interno.get("oggetti", []) as Array)
	assert_true(nemici.size() > 0 or oggetti.size() > 0,
		"contenuto reale in almeno una sala (nemico o oggetto, non uno stub vuoto)")

	cont.free()
