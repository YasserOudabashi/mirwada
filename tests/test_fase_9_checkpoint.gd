extends "res://tests/test_case.gd"
## US-907 — IL CHECKPOINT DELLA FASE 9. Stesso schema del checkpoint di fase 8
## (tests/test_slice_fase_8.gd): la lista degli id vietati nel MOTORE
## (res://scripts, res://scripts/pages) e' SCOPERTA dai dati stessi
## (GameData.get_pathway("eternal_aeon")), mai scritta a mano - l'id del
## Pathway, delle sue 10 Sequenze, delle sue 10 abilita'. Se uno di questi
## compare nel motore, e' un caso speciale scritto a mano dove doveva
## esserci un dato (BoonSystem/PathwayChange/FusionEngine/la pagina
## diagramma non sanno nulla di "Eternal Aeon", solo del campo 'boon').
##
## tests/manual/qa_vslice_eternal_aeon.gd (US-907) e' il compagno di questo
## checkpoint: la partita giocata per davvero con Xvfb, screenshot alla
## mano. Non e' raccolto dalla suite headless (run_tests.gd legge solo
## res://tests, non le sottocartelle) - il secondo test qui sotto lo conferma.

func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")


func test_nessun_codice_nomina_eternal_aeon_le_sue_sequenze_o_abilita() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "eternal_aeon")
	assert_false(pw.is_empty(), "eternal_aeon si carica")

	var vietati: Array = ["\"eternal_aeon\""]
	var seqs: Array = pw.get("sequences", [])
	assert_eq(seqs.size(), 10, "10 Sequenze (letto dai dati)")
	for seq in seqs:
		var d: Dictionary = seq
		vietati.append("\"%s\"" % str(d.get("id", "")))
		for aid in (d.get("abilities", []) as Array):
			vietati.append("\"%s\"" % str(aid))
	assert_eq(vietati.size(), 1 + 10 + 10, "1 Pathway + 10 Sequenze + 10 abilita' (letto dai dati)")

	var colpevoli: PackedStringArray = []
	for dir in ["res://scripts", "res://scripts/pages"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var righe: PackedStringArray = FileAccess.get_file_as_string(dir + "/" + f).split("\n")
			for i in righe.size():
				var codice: String = righe[i].split("#")[0]
				for v in vietati:
					if codice.contains(v):
						colpevoli.append("%s:%d %s" % [f, i + 1, righe[i].strip_edges()])
	assert_eq(colpevoli.size(), 0,
		"nessun nome di Eternal Aeon/Sequenza/abilita' nel codice (checkpoint fase 9): %s" % colpevoli)


## qa_vslice_eternal_aeon.gd si gioca con Xvfb a parte (non ha senso in
## headless: usa lo schermo vero). Qui si conferma solo che esista e che
## run_tests.gd non lo raccolga mai (legge solo res://tests, non le
## sottocartelle - DirAccess.get_files_at non e' ricorsivo).
func test_qa_vslice_eternal_aeon_esiste_ed_e_uno_script_manuale() -> void:
	assert_true(FileAccess.file_exists("res://tests/manual/qa_vslice_eternal_aeon.gd"),
		"tests/manual/qa_vslice_eternal_aeon.gd esiste")
	var raccolti: PackedStringArray = DirAccess.get_files_at("res://tests")
	assert_false("manual" in raccolti, "res://tests/manual e' una sottocartella, non un file")
	for f in raccolti:
		assert_false(f == "qa_vslice_eternal_aeon.gd",
			"qa_vslice_eternal_aeon.gd non e' raccolto direttamente da res://tests (vive in tests/manual/)")
