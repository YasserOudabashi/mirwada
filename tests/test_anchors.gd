extends "res://tests/test_case.gd"
## US-216 — Ancore: registrazione, buffering della follia, distruzione, save.

const SLOT := 908


func _as() -> Node: return Engine.get_main_loop().root.get_node_or_null("AnchorSystem")
func _m() -> Node: return Engine.get_main_loop().root.get_node_or_null("Madness")
func _save() -> Node: return Engine.get_main_loop().root.get_node_or_null("SaveSystem")
func _gd() -> Node: return Engine.get_main_loop().root.get_node("GameData")


func prepara() -> void:
	if _as() != null:
		_as().call("pulisci")
	if _m() != null:
		_m().call("azzera")


func test_ancore_caricate_dai_dati() -> void:
	var a: Dictionary = _gd().call("get_anchor", "anchor_mirco")
	assert_false(a.is_empty(), "anchor_mirco caricata")
	assert_gt(float(a["forza"]), 0.0, "forza")


func test_register_e_active() -> void:
	var s: Node = _as()
	assert_true(s.call("register", "anchor_mirco"), "registra")
	assert_false(s.call("register", "anchor_mirco"), "non due volte")
	assert_false(s.call("register", "anchor_inventata"), "id inesistente rifiutato")
	assert_eq((s.call("active") as Array).size(), 1, "una attiva")


func test_le_ancore_bufferizzano_la_follia_in_arrivo() -> void:
	var s: Node = _as()
	var m: Node = _m()
	# senza ancore: colpo pieno
	m.call("add", 20.0, "avanzamento_forzato")
	assert_almost_eq(m.call("valore"), 20.0, "colpo pieno senza ancore")
	m.call("azzera")

	# anchor_mirco forza 10: assorbe min(10, 0.60*20=12) = 10 -> ne passano 10
	s.call("register", "anchor_mirco")
	m.call("add", 20.0, "avanzamento_forzato")
	assert_almost_eq(m.call("valore"), 10.0, "10 punti bufferizzati da un'Ancora forza 10")


func test_cap_frazionario_sul_colpo() -> void:
	var s: Node = _as()
	var m: Node = _m()
	# forza totale alta, ma il cap e' 0.60 del colpo
	s.call("register", "anchor_mirco")     # 10
	s.call("register", "anchor_promessa")  # 12 -> totale 22
	m.call("add", 10.0, "x")
	# assorbito = min(22, 0.60*10 = 6) = 6 -> ne passano 4
	assert_almost_eq(m.call("valore"), 4.0, "mai piu' del 60% di un colpo")


func test_destroy_emette_segnale_e_aggiunge_follia_non_bufferizzata() -> void:
	var s: Node = _as()
	var m: Node = _m()
	s.call("register", "anchor_mirco")
	s.call("register", "anchor_sidon")
	var persi: Array = []
	s.anchor_lost.connect(func(id: String) -> void: persi.append(id))

	assert_true(s.call("destroy", "anchor_sidon"), "distrutta")
	assert_eq(persi, ["anchor_sidon"], "segnale anchor_lost")
	assert_eq((s.call("active") as Array), ["anchor_mirco"], "resta solo mirco")
	# penalita di anchor_sidon (14), NON bufferizzata da anchor_mirco
	assert_almost_eq(m.call("valore"), 14.0, "il colpo di perdita non e' bufferizzato")


func test_persistenza_nel_save() -> void:
	var s: Node = _as()
	var save: Node = _save()
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	s.call("register", "anchor_mirco")
	s.call("register", "anchor_dimora")

	if save.esiste(SLOT):
		save.cancella(SLOT)
	assert_true(save.salva(SLOT, gs.snapshot())["ok"], "salva ok")
	s.call("pulisci")
	assert_eq((s.call("active") as Array).size(), 0, "azzerate")

	var c: Dictionary = save.carica(SLOT)
	gs.applica(c["dati"])
	assert_eq((s.call("active") as Array).size(), 2, "due Ancore ripristinate")
	save.cancella(SLOT)


func test_i_nomi_dei_sussurri_seguono_le_ancore() -> void:
	# US-214: i sussurri di soglia 55 usano i nomi delle Ancore attive.
	var s: Node = _as()
	var am: Node = Engine.get_main_loop().root.get_node_or_null("AudioManager")
	s.call("register", "anchor_mirco")
	assert_true("anchor.mirco" in (am.call("nomi_sussurro") as Array), "il nome dell'Ancora e' fra i sussurri")
	s.call("destroy", "anchor_mirco")
	assert_false("anchor.mirco" in (am.call("nomi_sussurro") as Array), "sparisce quando l'Ancora cade")
