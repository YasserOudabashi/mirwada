extends "res://tests/test_case.gd"
## US-1013 — IL CHECKPOINT DELLA FASE 10. Stesso schema dei checkpoint di
## fase 8/9 (tests/test_slice_fase_8.gd, tests/test_fase_9_checkpoint.gd):
## la lista degli id proibiti nel MOTORE (res://scripts, res://scripts/
## pages) e' SCOPERTA dai dati stessi - le 4 regioni oltre a "mirwada"
## (gia' hardcoded da world_scene.gd::HUB fin dalla fase 6, la citta' e'
## l'hub per design, non una svista di questa fase) e ogni interno_id
## referenziato da edifici[] in QUALUNQUE layout (i villaggi/strutture
## grandi nuovi di questa fase inclusi: le 4 case di Mirwada, le 4 capanne
## dell'avamposto di Valle, la torre dell'Archivio). Se uno di questi
## compare nel motore, e' un caso speciale scritto a mano dove doveva
## esserci un dato: world_scene.gd/interior_scene.gd leggono edifici[] in
## un ciclo generico (_crea_edifici), mai un id specifico.
##
## tests/manual/qa_mondo_continuo.gd (US-1013) era il compagno di questo checkpoint: tolto il 2026-11-18 insieme a
## world_scene.gd, il mondo a layout sostituito dal mondo generato.

func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")


func test_nessun_codice_nomina_una_regione_un_villaggio_o_un_interno_specifico() -> void:
	var vietati: Array = []

	var regioni: Array = _gd().call("get_regions")
	for r in regioni:
		var rid: String = str((r as Dictionary).get("id", ""))
		if not rid.is_empty() and rid != "mirwada":
			vietati.append("\"%s\"" % rid)
	assert_eq(regioni.size(), 5, "5 regioni (letto dai dati)")

	var interni_attesi := 0
	for r in regioni:
		var rid: String = str((r as Dictionary).get("id", ""))
		var layout: Dictionary = _gd().call("get_layout", rid)
		for spec in (layout.get("edifici", []) as Array):
			var iid: String = str((spec as Dictionary).get("interno_id", ""))
			if not iid.is_empty():
				vietati.append("\"%s\"" % iid)
				interni_attesi += 1
	assert_true(interni_attesi >= 9,
		"almeno i 9 interni gia' noti (4 Mirwada + 4 avamposto di Valle + 1 torre, letto dai dati): %d" % interni_attesi)

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
		"nessun nome di regione/villaggio/interno specifico nel codice (checkpoint fase 10): %s" % colpevoli)
