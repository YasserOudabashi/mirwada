extends "res://tests/test_case.gd"
## US-814 — IL CHECKPOINT DELLA FASE 8. A differenza dei checkpoint delle fasi
## 5/5b/7 (liste "vietati" scritte a mano), qui la lista degli id proibiti nel
## MOTORE (res://scripts, res://scripts/pages) e' SCOPERTA dai dati stessi:
## ogni Pathway, ogni regione (eccetto "mirwada", gia' hardcoded da
## region_scene.gd::HUB fin dalla fase 6 - la citta' e' l'hub per design, non
## una svista di questa fase), ogni NPC, ogni formula del Twilight Giant e gli
## ingredienti della sua formula di Sequenza 9. Se uno di questi compare nel
## motore, e' un caso speciale scritto a mano dove doveva esserci un dato.
##
## tests/manual/qa_vslice.gd (US-814) e' il compagno di questo checkpoint: la
## partita giocata per davvero con Xvfb, screenshot alla mano. Non e' raccolto
## dalla suite headless (run_tests.gd legge solo res://tests, non ricorsivo) -
## il secondo test qui sotto lo conferma.

func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")


func _json_di(path: String) -> Variant:
	assert_true(FileAccess.file_exists(path), "%s esiste" % path)
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func test_nessun_codice_nomina_pathway_regione_npc_formula_o_ingrediente() -> void:
	var vietati: Array = []

	for pid in _gd().call("pathway_ids"):
		vietati.append("\"%s\"" % str(pid))

	var regioni: Dictionary = _json_di("res://data/world/regions.json")
	for r in (regioni.get("regions", []) as Array):
		var rid: String = str((r as Dictionary).get("id", ""))
		if not rid.is_empty() and rid != "mirwada":
			vietati.append("\"%s\"" % rid)

	var roster: Dictionary = _json_di("res://data/npc/roster.json")
	for n in (roster.get("npcs", []) as Array):
		var nid: String = str((n as Dictionary).get("id", ""))
		if not nid.is_empty():
			vietati.append("\"%s\"" % nid)

	var formule: Dictionary = _json_di("res://data/potions/formulas.json")
	var tg9_ingredienti: Array = []
	for fid in (formule.get("formulas", {}) as Dictionary):
		var fid_s: String = str(fid)
		if fid_s.begins_with("formula_twilight_giant_"):
			vietati.append("\"%s\"" % fid_s)
		if fid_s == "formula_twilight_giant_9":
			tg9_ingredienti = ((formule["formulas"] as Dictionary)[fid_s] as Dictionary).get("ingredients", [])
	assert_eq(tg9_ingredienti.size(), 3, "formula_twilight_giant_9 ha 3 ingredienti (letti dai dati)")
	for ing in tg9_ingredienti:
		vietati.append("\"%s\"" % str(ing))

	var colpevoli: PackedStringArray = []
	for dir in ["res://scripts", "res://scripts/pages"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var righe: PackedStringArray = FileAccess.get_file_as_string(dir + "/" + f).split("\n")
			for i in righe.size():
				var codice: String = righe[i].split("#")[0]
				for v in vietati:
					if not codice.contains(v):
						continue
					# eccezione gia' ammessa dal checkpoint di fase 7: enemy.gd
					# riproduce l'ANIMAZIONE "death" (data/animations.json), non
					# il Pathway.
					if v == "\"death\"" and codice.contains("riproduci"):
						continue
					colpevoli.append("%s:%d %s" % [f, i + 1, righe[i].strip_edges()])
	assert_eq(colpevoli.size(), 0,
		"nessun nome di Pathway/regione/NPC/formula/ingrediente nel codice (checkpoint fase 8): %s" % colpevoli)


## tests/manual/qa_vslice.gd si gioca con Xvfb a parte (non ha senso in
## headless: usa lo schermo vero). Qui si conferma solo che esista e che
## run_tests.gd non lo raccolga mai (legge solo res://tests, non le
## sottocartelle - DirAccess.get_files_at non e' ricorsivo).
func test_qa_vslice_esiste_ed_e_uno_script_manuale() -> void:
	assert_true(FileAccess.file_exists("res://tests/manual/qa_vslice.gd"),
		"tests/manual/qa_vslice.gd esiste")
	var raccolti: PackedStringArray = DirAccess.get_files_at("res://tests")
	assert_false("manual" in raccolti, "res://tests/manual e' una sottocartella, non un file")
	for f in raccolti:
		assert_false(f == "qa_vslice.gd",
			"qa_vslice.gd non e' raccolto direttamente da res://tests (vive in tests/manual/)")
