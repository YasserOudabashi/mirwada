extends "res://tests/test_case.gd"
## US-335 — vertical slice della fase 3: giardino, alchimia, forgia, sigilli,
## pet, talenti e sinergie compongono in un solo test, SENZA una riga di
## codice dedicata a un contenuto specifico. E' il verdetto sull'architettura
## (come US-219 per il Twilight Giant).

const StatsComponent := preload("res://scripts/stats_component.gd")

var _p: Node2D = null


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func prepara() -> void:
	for a in ["/root/Inventory", "/root/Equipment", "/root/BaseSystem", "/root/PetSystem",
			"/root/TalentSystem", "/root/SynergyEngine"]:
		if _n(a) != null:
			_n(a).call("pulisci")
	for a in ["/root/TalentTracker", "/root/EventTracker"]:
		if _n(a) != null:
			_n(a).call("azzera")
	if _n("/root/KnowledgeStore") != null:
		_n("/root/KnowledgeStore").call("dimentica_tutto")
	# via ogni giocatore lasciato da un test precedente (mio o altrui): le suite
	# successive (test_vertical_slice) si aspettano un solo player in scena.
	for vecchio in Engine.get_main_loop().root.get_tree().get_nodes_in_group("player"):
		vecchio.free()
	_p = Node2D.new()
	_p.add_to_group("player")
	var st: Node = StatsComponent.new()
	st.name = "StatsComponent"
	st.call("configure_from_balance", 9)
	_p.add_child(st)
	Engine.get_main_loop().root.add_child(_p)


func _fine() -> void:
	if is_instance_valid(_p):
		_p.free()


func _stats() -> Node:
	return _p.get_node("StatsComponent")


func _rifornisci(costo: Dictionary, extra: int = 0) -> void:
	for item_id in costo:
		_n("/root/Inventory").call("aggiungi", item_id, int(costo[item_id]) + extra)


func _costruisci(tipo: String, livelli: int) -> void:
	var bs: Node = _n("/root/BaseSystem")
	for _i in livelli:
		_rifornisci(bs.call("costo_prossimo", tipo))
		if bs.call("livello", tipo) == 0:
			bs.call("costruisci", tipo)
		else:
			bs.call("potenzia", tipo)


func _prima_istanza(item_id: String) -> String:
	var creati: Array = _n("/root/Inventory").call("aggiungi", item_id, 1)
	return str(creati[0]) if not creati.is_empty() else ""


func test_la_fase_3_compone_senza_codice_dedicato() -> void:
	var inv: Node = _n("/root/Inventory")
	var gd: Node = _n("/root/GameData")

	# 1. GIARDINO: costruisci, pianta un coltivabile, avanza il tempo, raccogli
	_costruisci("giardino", 1)
	var coltivabile := ""
	for cat_it in gd.call("items_per_categoria", "ingrediente"):
		if bool((cat_it as Dictionary).get("coltivabile", false)):
			coltivabile = str((cat_it as Dictionary).get("id", ""))
			break
	assert_ne(coltivabile, "", "esiste un ingrediente coltivabile nei dati")
	inv.call("aggiungi", coltivabile, 1)
	var appz: int = _n("/root/BaseSystem").call("pianta", coltivabile)
	_n("/root/BaseSystem").call("_process", 999.0)
	assert_gt(float(_n("/root/BaseSystem").call("raccogli", appz)), 0.0, "1. il giardino rende")

	# 2. ALCHIMIA: laboratorio, sperimenta una combinazione = ricetta avanzata
	_costruisci("laboratorio", 2)  # qualita_pozione +1
	var avanzata: String = (gd.call("recipes_per_tier", "avanzata") as Array).back()  # la 2a: non nota dalla biblioteca
	var ric: Dictionary = gd.call("get_recipe", avanzata)
	var combo: Array = []
	for ing in ric.get("ingredienti", {}):
		for _k in int(ric["ingredienti"][ing]):
			combo.append(ing)
			inv.call("aggiungi", ing, 1)
	var esito: Dictionary = _n("/root/PotionSystem").call("sperimenta", combo)
	assert_eq(str(esito.get("esito")), "scoperta", "2. la combinazione ignota E' la ricetta avanzata -> scoperta")
	# prepara: la qualita' e' migliorata dal laboratorio
	for ing in ric.get("ingredienti", {}):
		inv.call("aggiungi", ing, int(ric["ingredienti"][ing]))
	var prep: Dictionary = _n("/root/PotionSystem").call("prepara", avanzata)
	var scala: Array = gd.call("potion_quality")
	assert_true(scala.find(str(prep.get("qualita"))) > scala.find(str(ric.get("qualita_base"))),
		"2. la pozione preparata col laboratorio e' di qualita' migliore della base")

	# 3. FORGIA: un equip dai materiali, equipaggialo
	var bp_id: String = (gd.call("blueprint_ids") as Array)[0]
	var bp: Dictionary = gd.call("get_blueprint", bp_id)
	for mat in bp.get("materiali", {}):
		inv.call("aggiungi", mat, int(bp["materiali"][mat]))
	var forgia: Dictionary = _n("/root/Forge").call("forgia", bp_id)
	assert_true(forgia.get("ok", false), "3. la forgia riesce")
	_n("/root/Equipment").call("equipaggia", str(forgia.get("instance_id")))
	assert_false((_n("/root/Equipment").call("slot_pieni") as Dictionary).is_empty(), "3. equip indossato")

	# 4. SIGILLO con effetto_collaterale: incastonalo, verifica effetto + collaterale
	var mount := ""
	var slot_sig := 0
	for m in (_n("/root/Equipment").call("slot_pieni") as Dictionary):
		var d: Dictionary = gd.call("get_item", str((_n("/root/Equipment").call("slot_pieni") as Dictionary)[m]))
		if int(d.get("slot_sigilli", 0)) > 0:
			mount = m
			break
	if mount == "":
		# l'equip forgiato non ha slot sigilli: equipaggia un accessorio che ne ha
		_n("/root/Equipment").call("equipaggia", _prima_istanza("amuleto_lunare"))
		for m in (_n("/root/Equipment").call("slot_pieni") as Dictionary):
			var d2: Dictionary = gd.call("get_item", str((_n("/root/Equipment").call("slot_pieni") as Dictionary)[m]))
			if int(d2.get("slot_sigilli", 0)) > 0:
				mount = m
	var sig_item := ""
	for sit in gd.call("items_per_categoria", "sigillo"):
		var sdef: Dictionary = gd.call("get_sigil", str((sit as Dictionary).get("sigillo_ref", "")))
		if not sdef.get("effetto_collaterale", {}).is_empty():
			sig_item = str((sit as Dictionary).get("id", ""))
			break
	assert_ne(sig_item, "", "esiste un sigillo con effetto_collaterale nei dati")
	var sig_iid: String = _prima_istanza(sig_item)
	assert_true(_n("/root/Equipment").call("incastona", mount, sig_iid), "4. sigillo incastonato")
	assert_true(_stats().call("has_modifier", "sigillo:" + sig_iid), "4. effetto del sigillo attivo")
	assert_true(_stats().call("has_modifier", "sigillo:" + sig_iid + ":collaterale"),
		"4. anche l'effetto_collaterale e' attivo (il prezzo dichiarato nei dati)")

	# 5. PET: doma (seed fortunato), il bond sale con enemy_defeated, sblocca un comportamento
	var pet_id := ""
	for pid in gd.call("pet_ids"):
		if not (gd.call("get_pet", pid) as Dictionary).get("comportamenti", []).is_empty():
			pet_id = str(pid)
			break
	assert_true(_n("/root/PetSystem").call("doma", pet_id, 1.0), "5. pet domato")
	var soglia_min := 999
	for c in (gd.call("get_pet", pet_id) as Dictionary).get("comportamenti", []):
		soglia_min = mini(soglia_min, int((c as Dictionary).get("bond", 999)))
	var peso: int = int((gd.call("get_balance", "pet_bond") as Dictionary).get("per_nemico_sconfitto", 1))
	for _i in int(ceil(float(soglia_min) / float(peso))) + 1:
		_n("/root/EventTracker").call("emit_event", "enemy_defeated", {})
	assert_gt(float((_n("/root/PetSystem").call("comportamenti_sbloccati") as Array).size()), 0.0,
		"5. il bond dagli enemy_defeated ha sbloccato un comportamento del pet")

	# 6. TALENTO acquisito: supera la soglia di un comportamento-talento
	var tal_acq := ""
	for tid in gd.call("talents_per_tipo", "acquisito"):
		var sb: Dictionary = (gd.call("get_talent", tid) as Dictionary).get("sblocco", {})
		if gd.call("tracked_talents").has(str(sb.get("evento", ""))):
			tal_acq = str(tid)
			_n("/root/TalentTracker").call("registra", str(sb.get("evento")), float(sb.get("target", 1)) + 1.0)
			break
	assert_ne(tal_acq, "", "esiste un talento acquisito su un comportamento-talento")
	_n("/root/TalentSystem").call("_process", 0.0)
	assert_true(_n("/root/TalentSystem").call("possiede", tal_acq), "6. il talento acquisito si e' sbloccato")

	# 7. SYNERGY SOURCES: i tag di tutte le fonti confluiscono
	var g: Dictionary = _n("/root/SynergySources").call("tag_sinergia_globali")
	var per_fonte: Dictionary = _n("/root/SynergySources").call("per_fonte")
	assert_false((per_fonte.get("pet", {}) as Dictionary).is_empty(), "7. il pet contribuisce tag")
	assert_false((per_fonte.get("base", {}) as Dictionary).is_empty(), "7. la base contribuisce tag")
	assert_false((per_fonte.get("inventario", {}) as Dictionary).is_empty(), "7. l'equip contribuisce tag")
	assert_gt(float(g.size()), 3.0, "7. tag_sinergia_globali somma piu' fonti")

	_fine()


func test_nessun_codice_nomina_un_contenuto_specifico() -> void:
	# grep di scripts/ per gli id di item / ricette / pet / strutture / sigilli /
	# blueprint. Zero occorrenze fuori dai commenti: nessun `if` per un
	# contenuto. Come US-219 per il Twilight Giant.
	var gd: Node = _n("/root/GameData")
	var vietati: Array = []
	for cat in ["ingrediente", "equip", "sigillo", "pergamena", "materiale", "valuta", "consumabile"]:
		for it in gd.call("items_per_categoria", cat):
			vietati.append(str((it as Dictionary).get("id", "")))
	for pid in gd.call("pet_ids"):
		vietati.append(str(pid))
	for sid in gd.call("sigil_ids"):
		vietati.append(str(sid))
	for bid in gd.call("blueprint_ids"):
		vietati.append(str(bid))
	for rid in gd.call("recipe_ids"):
		vietati.append(str(rid))

	var colpevoli: PackedStringArray = []
	for f in DirAccess.get_files_at("res://scripts"):
		_scan_gd("res://scripts/" + f, vietati, colpevoli)
	for f in DirAccess.get_files_at("res://scripts/pages"):
		_scan_gd("res://scripts/pages/" + f, vietati, colpevoli)
	assert_eq(colpevoli.size(), 0,
		"nessun nome di contenuto specifico nel codice: %s" % colpevoli)
	_fine()


func _scan_gd(path: String, vietati: Array, fuori: PackedStringArray) -> void:
	if not path.ends_with(".gd"):
		return
	var righe: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	for riga in righe:
		var codice: String = riga.split("#")[0]
		for v in vietati:
			if v != "" and codice.contains("\"%s\"" % v):
				fuori.append("%s: %s" % [path.get_file(), riga.strip_edges()])
