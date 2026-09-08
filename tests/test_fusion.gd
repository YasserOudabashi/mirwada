extends "res://tests/test_case.gd"
## US-702+ — i percorsi di fusione (data/fusions/): 8 file, uno per coppia di
## Pathway vicini in un gruppo attivo. In US-702 sono tutti stub tranne
## door_error (US-706); FusionEngine li legge in US-705.

const PERCORSI := [
	"door_error", "door_fool", "error_fool",
	"darkness_death", "darkness_twilight_giant", "death_twilight_giant",
	"hermit_paragon", "moon_mother",
]


func test_esistono_tutti_e_8_i_percorsi() -> void:
	for fid in PERCORSI:
		var path: String = "res://data/fusions/%s.json" % fid
		assert_true(FileAccess.file_exists(path), "esiste data/fusions/%s.json" % fid)
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_eq(typeof(doc), TYPE_DICTIONARY, "%s: json valido" % fid)
		assert_eq(str((doc as Dictionary).get("id")), fid, "%s: id coerente" % fid)
		var a: String = str((doc as Dictionary).get("pathway_a"))
		var b: String = str((doc as Dictionary).get("pathway_b"))
		assert_true(a < b, "%s: pathway_a < pathway_b alfabetico" % fid)


func test_id_alfabetico_e_dentro_un_gruppo() -> void:
	# i due Pathway di ogni percorso hanno lo stesso 'group'.
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	for fid in PERCORSI:
		var doc: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/fusions/%s.json" % fid))
		var ga: String = str(gd.call("get_pathway", str(doc["pathway_a"])).get("group", ""))
		var gb: String = str(gd.call("get_pathway", str(doc["pathway_b"])).get("group", ""))
		assert_eq(ga, gb, "%s: i due Pathway sono dello stesso gruppo" % fid)
		assert_eq(str(doc.get("gruppo")), ga, "%s: campo gruppo coerente" % fid)
