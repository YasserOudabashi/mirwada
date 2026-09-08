extends "res://tests/test_case.gd"
## US-709 — IL CHECKPOINT DELLA FASE 7 (blocco A: cambio Pathway + fusione).
## US-720 lo estende col ciclo completo (tribolazione, finale, eredita').
##
## Un personaggio Error a Sequenza 4 cambia Pathway verso Door (vicino dello
## stesso gruppo): resta alla stessa Sequenza numerica, conserva le abilita'
## delle Sequenze basse di Error, riceve le abilita' fuse del percorso
## door_error. Se qualcosa qui richiede un `if` per una coppia di Pathway,
## il cambio non e' dati e va corretto PRIMA di andare avanti.

const Stats := preload("res://scripts/stats_component.gd")

var _player: Node2D = null


func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")
func _prog() -> Node: return _root().get_node("Progression")
func _pc() -> Node: return _root().get_node("PathwayChange")
func _fe() -> Node: return _root().get_node("FusionEngine")
func _engine() -> Node: return _root().get_node("AbilityEngine")
func _endgame() -> Node: return _root().get_node("EndgameState")


func prepara() -> void:
	if _player != null and is_instance_valid(_player):
		_player.free()
	# Altri suite possono aver lasciato un nodo nel gruppo "player":
	# grant_permanente aggancia get_first_node_in_group("player"), quindi il
	# checkpoint deve partire da un ambiente pulito.
	for stale in _root().get_tree().get_nodes_in_group("player"):
		stale.remove_from_group("player")
	_player = Node2D.new()
	_player.add_to_group("player")
	var s: Node = Stats.new()
	s.name = "StatsComponent"
	_player.add_child(s)
	_root().add_child(_player)
	s.call("configure_from_balance", 4)
	s.set("spiritualita", 9999.0)

	_engine().call("flush_effects")
	_engine().call("clear_cooldowns")
	_engine().call("clear_granted")
	_endgame().call("pulisci")
	_prog().configura("error", 4)


func _fine() -> void:
	_prog().configura("", 9)
	_engine().call("clear_granted")
	_endgame().call("pulisci")
	if is_instance_valid(_player):
		_player.free()


func test_error_seq4_diventa_door_seq4_con_abilita_basse_e_fuse() -> void:
	# grep di sicurezza: il test NON nomina "door" a mano, lo prende dal gruppo.
	var gruppo: String = str(_gd().call("get_pathway", "error").get("group", ""))
	var vicino: String = ""
	for pid in _gd().call("pathway_ids"):
		if pid != "error" and str(_gd().call("get_pathway", pid).get("group", "")) == gruppo \
				and not _fe().call("percorso", "error", pid).is_empty():
			vicino = pid
			break
	assert_ne(vicino, "", "c'e' un vicino di gruppo con un percorso di fusione scritto")

	var res: Dictionary = _pc().call("cambia", vicino)
	assert_true(res["ok"], "cambio riuscito verso il vicino")
	assert_eq(_prog().call("pathway"), vicino, "ora sul Pathway vicino")
	assert_eq(int(_prog().call("sequence")), 4, "stessa Sequenza numerica")

	# un'abilita' delle Sequenze basse del vecchio Pathway (Error Seq 9)
	var r1: Dictionary = _engine().call("execute", "error_scasso", _player)
	assert_ne(r1["reason"], "abilita_non_posseduta", "abilita' bassa del vecchio Pathway conservata")

	# le abilita' fuse del percorso, concesse e registrate
	var fuse: Array = _fe().call("abilita_fuse", "error", vicino)
	assert_gt(float(fuse.size()), 0.0, "il percorso ha abilita' fuse")
	var una: String = str((fuse[0] as Dictionary)["id"])
	assert_true(una in (_endgame().get("fusioni") as Array), "l'abilita' fusa e' in endgame.fusioni")
	var r2: Dictionary = _engine().call("execute", una, _player)
	assert_true(r2["ok"], "l'abilita' fusa esegue")
	for w in (r2["warnings"] as PackedStringArray):
		assert_false(str(w).begins_with("primitiva fuori registro"),
			"abilita' fusa: nessuna primitiva fuori registro (%s)" % w)
	_fine()


func test_nessun_codice_nomina_un_pathway_o_una_fusione() -> void:
	# grep di res://scripts e res://scripts/pages: nessun id di Pathway come
	# stringa, nessun "fus_" / "door_error" / "error_door" fuori dai commenti.
	var vietati: Array = [
		"\"twilight_giant\"", "\"darkness\"", "\"death\"", "\"moon\"", "\"mother\"",
		"\"paragon\"", "\"hermit\"", "\"fool\"", "\"error\"", "\"door\"",
		"fus_", "door_error", "error_door",
	]
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
					# eccezione: enemy.gd riproduce l'ANIMAZIONE "death", non il Pathway
					if v == "\"death\"" and codice.contains("riproduci"):
						continue
					colpevoli.append("%s:%d %s" % [f, i + 1, righe[i].strip_edges()])
	assert_eq(colpevoli.size(), 0,
		"nessun nome di Pathway/fusione nel codice (checkpoint fase 7): %s" % colpevoli)
