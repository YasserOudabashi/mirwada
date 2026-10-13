extends "res://tests/test_case.gd"
## US-709/720 — IL CHECKPOINT DELLA FASE 7. Blocco A (cambio Pathway +
## fusione) e blocco E (ciclo completo: + tribolazione superata + finale
## valutato + eredita' compilata e riapplicata a un nuovo personaggio).
##
## Un personaggio Error a Sequenza 4 cambia Pathway verso Door (vicino dello
## stesso gruppo): resta alla stessa Sequenza numerica, conserva le abilita'
## delle Sequenze basse di Error, riceve le abilita' fuse del percorso
## door_error. Se qualcosa qui richiede un `if` per una coppia di Pathway,
## il cambio non e' dati e va corretto PRIMA di andare avanti.
##
## Ogni id (il vicino di gruppo, la tribolazione, il finale, l'Ancora/oggetto
## ereditato) e' SCOPERTO dai dati dentro il test, mai scritto a mano: e'
## quello che il checkpoint deve dimostrare. La verifica che nessun id sia
## hardcoded nel MOTORE (scripts/, scripts/pages/) resta il secondo test
## sotto - i test stessi non sono soggetti a quel grep (design del
## checkpoint gia' da US-709: qui si legge, li' si vieta di scrivere).

const Stats := preload("res://scripts/stats_component.gd")
const SLOT := 903

var _player: Node2D = null


func _root() -> Node: return Engine.get_main_loop().root
func _gd() -> Node: return _root().get_node("GameData")
func _prog() -> Node: return _root().get_node("Progression")
func _pc() -> Node: return _root().get_node("PathwayChange")
func _fe() -> Node: return _root().get_node("FusionEngine")
func _engine() -> Node: return _root().get_node("AbilityEngine")
func _endgame() -> Node: return _root().get_node("EndgameState")
func _ts() -> Node: return _root().get_node("TribulationSystem")
func _et() -> Node: return _root().get_node("EventTracker")
func _ks() -> Node: return _root().get_node("KnowledgeStore")
func _madness() -> Node: return _root().get_node("Madness")
func _anc() -> Node: return _root().get_node("AnchorSystem")
func _fs() -> Node: return _root().get_node("FactionSystem")
func _inv() -> Node: return _root().get_node("Inventory")
func _es() -> Node: return _root().get_node("EndingSystem")
func _gs() -> Node: return _root().get_node("GameState")
func _save() -> Node: return _root().get_node("SaveSystem")
func _book() -> Node: return _root().get_node("Book")


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
	_ts().call("azzera")
	_et().call("azzera")
	_ks().call("dimentica_tutto")
	_madness().call("azzera")
	_anc().call("pulisci")
	_fs().call("pulisci")
	_inv().call("pulisci")
	if bool(_save().call("esiste", SLOT)):
		_save().call("cancella", SLOT)
	if bool(_book().call("e_aperto")):
		_book().call("chiudi")
	_prog().configura("error", 4)


func _fine() -> void:
	_prog().configura("", 9)
	_engine().call("clear_granted")
	_endgame().call("pulisci")
	_ts().call("azzera")
	_et().call("azzera")
	_ks().call("dimentica_tutto")
	_madness().call("azzera")
	_anc().call("pulisci")
	_fs().call("pulisci")
	_inv().call("pulisci")
	if bool(_save().call("esiste", SLOT)):
		_save().call("cancella", SLOT)
	if bool(_book().call("e_aperto")):
		_book().call("chiudi")
	_gs().set("_partita_attiva", false)
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


## US-720 — il checkpoint di CHIUSURA: lo stesso personaggio, dopo il cambio
## Pathway sopra, attraversa anche una tribolazione, raggiunge un finale ed
## eredita' viene compilata, scelta e riapplicata a un nuovo personaggio.
## Ogni id (la tribolazione, il finale, l'Ancora, l'oggetto) e' SCOPERTO dai
## dati dentro il test - se uno di questi passaggi richiedesse di scrivere un
## id a mano nel motore, l'endgame non sarebbe dati.
func test_ciclo_completo_endgame_zero_codice_dedicato() -> void:
	# --- 1. cambio Pathway + fusione (come sopra) ---
	var gruppo: String = str(_gd().call("get_pathway", "error").get("group", ""))
	var vicino: String = ""
	for pid in _gd().call("pathway_ids"):
		if pid != "error" and str(_gd().call("get_pathway", pid).get("group", "")) == gruppo \
				and not _fe().call("percorso", "error", pid).is_empty():
			vicino = pid
			break
	assert_ne(vicino, "", "vicino di gruppo trovato")
	var camb: Dictionary = _pc().call("cambia", vicino)
	assert_true(bool(camb.get("ok", false)), "cambio Pathway riuscito")

	# --- 2. una tribolazione superata (scoperta dai dati) ---
	var trib_ids: Array = _gd().call("tribulation_ids")
	assert_gt(float(trib_ids.size()), 0.0, "ci sono tribolazioni nei dati")
	var t: Dictionary = _gd().call("get_tribulation", str(trib_ids[0]))
	var salto_da: int = int((t.get("salto", {}) as Dictionary).get("da", -1))
	var salto_a: int = int((t.get("salto", {}) as Dictionary).get("a", -1))
	assert_true(salto_da >= 0 and salto_a >= 0, "il salto della tribolazione scoperta e' valido")

	_prog().configura(vicino, salto_da)
	_ts().call("attiva", salto_da)
	assert_false(bool(_prog().call("avanza")), "il salto di fascia e' bloccato senza superamento")

	var sup: Dictionary = t.get("superamento", {})
	if sup.has("flag"):
		_ks().call("impara", str(sup["flag"]))
	elif sup.has("evento"):
		var target: int = int(maxf(float(sup.get("target", 1)), 1.0))
		for i in target:
			_et().call("emit_event", str(sup["evento"]), {})
	assert_true(bool(_endgame().call("tribolazione_superata", salto_da)), "superamento registrato in endgame")
	assert_true(bool(_prog().call("avanza")), "l'avanzamento passa dopo il superamento")
	assert_eq(int(_prog().call("sequence")), salto_a, "sequenza coerente col salto della tribolazione")

	# --- 3. un'Ancora e un oggetto da poter ereditare (scoperti dai dati) ---
	var anchor_ids: Array = _gd().call("get_anchors")
	if anchor_ids.size() > 0:
		_anc().call("register", str((anchor_ids[0] as Dictionary).get("id", "")))
	var oggetto_id: String = ""
	for iid in _gd().call("item_ids"):
		if bool(_gd().call("get_item", str(iid)).get("impilabile", false)):
			oggetto_id = str(iid)
			break
	if not oggetto_id.is_empty():
		_inv().call("aggiungi", oggetto_id, 1)

	# --- 4. un finale valutato (soglia generica di Madness, non un id di finale) ---
	_madness().call("add", 100.0, "checkpoint", false)
	var finale_id: String = str(_endgame().get("finale"))
	assert_false(finale_id.is_empty(), "un finale e' stato raggiunto")
	assert_false(_gd().call("get_ending", finale_id).is_empty(),
		"il finale raggiunto e' uno di quelli dichiarati nei dati")

	# --- 5. eredita' compilata, scelta e riapplicata a un nuovo personaggio ---
	var eredita: Dictionary = _endgame().get("eredita")
	assert_true(eredita.has("conoscenza"), "la conoscenza e' sempre compilata")

	var attive: Array = _anc().call("active")
	if attive.size() > 0:
		assert_true(bool(_es().call("scegli_ancora", str(attive[0]))), "l'Ancora attiva scoperta puo' essere scelta")
	var stack: Dictionary = (_inv().call("tutto") as Dictionary).get("stack", {})
	if stack.size() > 0:
		assert_true(bool(_es().call("scegli_oggetto", str(stack.keys()[0]))), "l'oggetto posseduto scoperto puo' essere scelto")

	var salvato: Dictionary = _gs().call("salva_slot", SLOT)
	assert_true(bool(salvato.get("ok", false)), "lo slot col finale e l'eredita' si salva")

	var res: Dictionary = _gs().call("nuova_partita", "Checkpoint", SLOT, [])
	assert_true(bool(res.get("ok", false)), "il nuovo personaggio si crea sullo stesso slot")
	assert_eq(int(_prog().call("sequence")), 9, "il nuovo personaggio riparte dalla Sequenza 9")
	assert_almost_eq(float(_madness().call("valore")), 0.0, "follia azzerata nel nuovo personaggio", 0.01)
	assert_eq(str(_endgame().get("finale")), "", "il nuovo personaggio non ha (ancora) un finale")

	_fine()


func test_nessun_codice_nomina_un_pathway_o_una_fusione() -> void:
	# grep di res://scripts e res://scripts/pages: nessun id di Pathway come
	# stringa, nessun "fus_" / "door_error" / "error_door", nessuna
	# tribolazione o finale specifico, fuori dai commenti (US-720: il
	# checkpoint copre anche i motori del blocco B/D).
	var vietati: Array = [
		"\"twilight_giant\"", "\"darkness\"", "\"death\"", "\"moon\"", "\"mother\"",
		"\"paragon\"", "\"hermit\"", "\"fool\"", "\"error\"", "\"door\"",
		"fus_", "door_error", "error_door",
		"trib_1_0", "trib_3_2", "trib_5_4", "trib_7_6",
		"\"apoteosi\"", "\"consumazione\"", "\"rinuncia\"",
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
