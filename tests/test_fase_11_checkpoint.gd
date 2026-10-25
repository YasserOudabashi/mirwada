extends "res://tests/test_case.gd"
## US-1114 — IL CHECKPOINT DELLA FASE 11. Stesso schema dei checkpoint di
## fase 9/10 (tests/test_fase_9_checkpoint.gd, tests/test_fase_10_checkpoint.gd):
## la lista degli id proibiti nel MOTORE (res://scripts, res://scripts/pages)
## e' SCOPERTA dai dati stessi - ogni NPC del roster, ogni blueprint di
## data/forge/blueprints.json, ogni ricetta di data/potions/recipes.json e
## ogni interno_id referenziato da campagna.json.edifici[]. Se uno di questi
## compare nel motore, e' un caso speciale scritto a mano dove doveva
## esserci un dato: Forge.forgia/PotionSystem.prepara prendono un id come
## parametro, page_dialogo.gd itera crafter.blueprints/ricette in un ciclo
## generico, mai un id specifico.

func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")


func test_nessun_codice_nomina_un_npc_un_villaggio_un_blueprint_o_una_ricetta_specifici() -> void:
	var vietati: Array = []

	var npcs: Array = _gd().call("get_npcs")
	assert_true(npcs.size() >= 21, "almeno gli NPC gia' noti dal roster (letto dai dati): %d" % npcs.size())
	for n in npcs:
		var nid: String = str((n as Dictionary).get("id", ""))
		if not nid.is_empty():
			vietati.append("\"%s\"" % nid)

	var campagna: Dictionary = _gd().call("get_campagna")
	var villaggi_attesi := 0
	for ed in (campagna.get("edifici", []) as Array):
		var iid: String = str((ed as Dictionary).get("interno_id", ""))
		if not iid.is_empty():
			vietati.append("\"%s\"" % iid)
			villaggi_attesi += 1
	assert_true(villaggi_attesi >= 4,
		"almeno i 4 edifici di villaggio gia' noti in campagna (letto dai dati): %d" % villaggi_attesi)

	var blueprints: Array = _gd().call("blueprint_ids")
	for bid in blueprints:
		vietati.append("\"%s\"" % str(bid))
	assert_true(blueprints.size() >= 4, "almeno i 4 blueprint gia' noti (letto dai dati): %d" % blueprints.size())

	var recipes: Array = _gd().call("recipe_ids")
	for rid in recipes:
		vietati.append("\"%s\"" % str(rid))

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
		"nessun nome di npc/villaggio/blueprint/ricetta specifico nel codice (checkpoint fase 11): %s" % colpevoli)
